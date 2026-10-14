import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:snapsync/core/error/failure.dart';
import 'package:snapsync/data/local/daos/batch_dao.dart';
import 'package:snapsync/data/local/daos/image_dao.dart';
import 'package:snapsync/data/local/database_helper.dart';
import 'package:snapsync/data/local/database_schema.dart';
import 'package:snapsync/data/repositories/batch_repository_impl.dart';
import 'package:snapsync/data/storage/image_file_storage.dart';
import 'package:snapsync/domain/entities/capture_batch.dart';
import 'package:snapsync/domain/entities/captured_image.dart';
import 'package:snapsync/domain/entities/upload_result.dart';
import 'package:snapsync/domain/entities/upload_status.dart';
import 'package:snapsync/domain/errors/domain_errors.dart';
import 'package:snapsync/domain/services/exponential_backoff.dart';
import 'package:snapsync/domain/usecases/record_upload_result.dart';
import 'package:sqflite/sqflite.dart';

import '../../support/test_support.dart';

void main() {
  late Directory root;
  late Directory appDir;
  late Directory cameraDir;
  late DatabaseHelper helper;
  late Database db;
  late BatchRepositoryImpl repository;
  late List<String> idQueue;
  late DateTime now;

  int idCounter = 0;

  String nextId() {
    if (idQueue.isNotEmpty) return idQueue.removeAt(0);
    return 'id-${++idCounter}';
  }

  File cameraFile(String name, {int bytes = 4}) {
    return File(p.join(cameraDir.path, name))
      ..writeAsBytesSync(List.filled(bytes, 7));
  }

  void advance(Duration d) => now = now.add(d);

  /// Adds one image to a fresh or existing open batch and returns it.
  Future<CapturedImage> addImage({String name = 'shot.jpg', int bytes = 4}) async {
    final batch = await repository.getOrCreateOpenBatch();
    return repository.addImage(batch.id, cameraFile(name, bytes: bytes).path);
  }

  /// Captures [count] images and submits the batch.
  Future<(CaptureBatch, List<CapturedImage>)> submittedBatch(int count) async {
    final images = <CapturedImage>[];
    for (var i = 0; i < count; i++) {
      images.add(await addImage(name: 'shot$i.jpg'));
      advance(const Duration(seconds: 1));
    }
    await repository.submitBatch(images.first.batchId);
    final batch = (await repository.watchSubmittedBatches().first).single;
    return (batch, images);
  }

  Future<void> toUploading(String imageId, {int attempts = 0}) {
    return repository.updateImageStatus(
      imageId: imageId,
      status: UploadStatus.uploading,
      attemptCount: attempts,
    );
  }

  setUp(() async {
    idCounter = 0;
    idQueue = [];
    now = DateTime.utc(2026, 4, 1, 9);
    root = createTempDir('snapsync_repo_');
    appDir = Directory(p.join(root.path, 'app'))..createSync();
    cameraDir = Directory(p.join(root.path, 'camera'))..createSync();
    helper = createTestDatabaseHelper();
    db = await helper.database;
    repository = BatchRepositoryImpl(
      databaseHelper: helper,
      batchDao: const BatchDao(),
      imageDao: const ImageDao(),
      storage: ImageFileStorage(baseDirectory: () async => appDir),
      generateId: nextId,
      clock: () => now,
    );
  });

  tearDown(() async {
    await repository.dispose();
    await db.close();
    root.deleteSync(recursive: true);
  });

  group('open batch', () {
    test('getOrCreateOpenBatch creates one batch and then reuses it', () async {
      final first = await repository.getOrCreateOpenBatch();
      final second = await repository.getOrCreateOpenBatch();

      expect(second.id, first.id);
      expect(first.isSubmitted, isFalse);
      expect(first.createdAt, now);
      expect(await db.query(DatabaseSchema.batchesTable), hasLength(1));
    });

    test('after submitting, the next call starts a new batch', () async {
      final image = await addImage();
      await repository.submitBatch(image.batchId);

      final next = await repository.getOrCreateOpenBatch();

      expect(next.id, isNot(image.batchId));
    });
  });

  group('addImage', () {
    test('copies the file into app storage and records size and time',
        () async {
      final image = await addImage(name: 'a.png', bytes: 9);

      expect(image.fileSizeBytes, 9);
      expect(image.status, UploadStatus.queued);
      expect(image.attemptCount, 0);
      expect(image.capturedAt, now);
      expect(File(image.filePath).existsSync(), isTrue);
      expect(image.filePath, startsWith(appDir.path));
      expect(p.extension(image.filePath), '.png');

      final open = (await repository.watchOpenBatch().first)!;
      expect(open.images, [image]);
    });

    test('a missing source file throws FileMissingFailure and records nothing',
        () async {
      final batch = await repository.getOrCreateOpenBatch();

      await expectLater(
        repository.addImage(batch.id, p.join(cameraDir.path, 'nope.jpg')),
        throwsA(isA<FileMissingFailure>()),
      );
      expect(await db.query(DatabaseSchema.imagesTable), isEmpty);
    });

    test('a failing insert removes the stored file (no orphans)', () async {
      idQueue = ['batch-1', 'dup', 'dup'];
      final first = await addImage(name: 'a.jpg');
      final batchDir = Directory(p.dirname(first.filePath));

      // The second image reuses the id 'dup', so the primary key rejects it.
      await expectLater(
        addImage(name: 'b.png'),
        throwsA(isA<DatabaseFailure>()),
      );

      expect(
        batchDir.listSync().map((e) => p.basename(e.path)),
        ['dup.jpg'],
      );
      expect(await db.query(DatabaseSchema.imagesTable), hasLength(1));
    });

    test('adding to a submitted batch is rejected and stores nothing',
        () async {
      final image = await addImage();
      await repository.submitBatch(image.batchId);
      final filesBefore = Directory(appDir.path).listSync(recursive: true).length;

      await expectLater(
        repository.addImage(image.batchId, cameraFile('late.jpg').path),
        throwsA(isA<IllegalBatchStateError>()),
      );

      expect(Directory(appDir.path).listSync(recursive: true).length, filesBefore);
    });

    test('adding to an unknown batch throws DatabaseFailure', () async {
      await expectLater(
        repository.addImage('ghost', cameraFile('a.jpg').path),
        throwsA(isA<DatabaseFailure>()),
      );
    });
  });

  group('submitBatch', () {
    test('sets submittedAt and queues every image', () async {
      final (batch, images) = await submittedBatch(3);

      expect(batch.isSubmitted, isTrue);
      expect(batch.submittedAt, isNotNull);
      expect(batch.images.map((i) => i.id), images.map((i) => i.id));
      expect(
        batch.images.every((i) => i.status == UploadStatus.queued),
        isTrue,
      );
    });

    test('an empty batch is rejected', () async {
      final batch = await repository.getOrCreateOpenBatch();

      await expectLater(
        repository.submitBatch(batch.id),
        throwsA(isA<IllegalBatchStateError>()),
      );
    });

    test('submitting twice keeps the first submittedAt', () async {
      final (batch, _) = await submittedBatch(1);
      advance(const Duration(hours: 1));

      await repository.submitBatch(batch.id);
      final again = (await repository.watchSubmittedBatches().first).single;

      expect(again.submittedAt, batch.submittedAt);
    });
  });

  group('getUploadable', () {
    test('ignores images in an open batch', () async {
      await addImage();
      expect(await repository.getUploadable(now), isEmpty);
    });

    test('returns queued images of submitted batches, oldest first', () async {
      final (_, images) = await submittedBatch(3);

      final uploadable = await repository.getUploadable(now);

      expect(uploadable.map((i) => i.id), images.map((i) => i.id));
    });

    test('only queued, waitingForConnection and retrying are included',
        () async {
      final (_, images) = await submittedBatch(5);
      // queued stays as images[0]
      await repository.updateImageStatus(
        imageId: images[1].id,
        status: UploadStatus.waitingForConnection,
        attemptCount: 0,
      );
      await toUploading(images[2].id);
      await toUploading(images[3].id);
      await repository.markUploaded(images[3].id);
      await toUploading(images[4].id);
      await repository.updateImageStatus(
        imageId: images[4].id,
        status: UploadStatus.failed,
        attemptCount: 3,
      );
      // images[2] is uploading, images[3] uploaded, images[4] failed.

      final ids = (await repository.getUploadable(now)).map((i) => i.id);

      expect(ids, [images[0].id, images[1].id]);
    });

    test('respects nextRetryAt: not due is hidden, due is returned', () async {
      final (_, images) = await submittedBatch(2);
      final due = now.add(const Duration(minutes: 5));
      for (final image in images) {
        await toUploading(image.id);
        await repository.updateImageStatus(
          imageId: image.id,
          status: UploadStatus.retrying,
          attemptCount: 1,
          nextRetryAt: image == images.first ? due : null,
        );
      }

      expect(
        (await repository.getUploadable(now)).map((i) => i.id),
        [images.last.id],
      );
      expect(
        (await repository.getUploadable(due.subtract(const Duration(milliseconds: 1))))
            .map((i) => i.id),
        [images.last.id],
      );
      expect(
        (await repository.getUploadable(due)).map((i) => i.id),
        containsAll(images.map((i) => i.id)),
      );
    });
  });

  group('updateImageStatus', () {
    test('writes status, attempts, error and nextRetryAt', () async {
      final (_, images) = await submittedBatch(1);
      final retryAt = now.add(const Duration(minutes: 1));
      await toUploading(images.single.id);

      await repository.updateImageStatus(
        imageId: images.single.id,
        status: UploadStatus.retrying,
        attemptCount: 1,
        lastError: 'timed out',
        nextRetryAt: retryAt,
      );

      final stored = (await repository.getImage(images.single.id))!;
      expect(stored.status, UploadStatus.retrying);
      expect(stored.attemptCount, 1);
      expect(stored.lastError, 'timed out');
      expect(stored.nextRetryAt, retryAt);
    });

    test('null error and nextRetryAt clear the stored values', () async {
      final (_, images) = await submittedBatch(1);
      final id = images.single.id;
      await toUploading(id);
      await repository.updateImageStatus(
        imageId: id,
        status: UploadStatus.retrying,
        attemptCount: 1,
        lastError: 'x',
        nextRetryAt: now,
      );

      await toUploading(id, attempts: 1);

      final stored = (await repository.getImage(id))!;
      expect(stored.lastError, isNull);
      expect(stored.nextRetryAt, isNull);
    });

    test('illegal transitions throw and leave the row unchanged', () async {
      final (_, images) = await submittedBatch(1);

      await expectLater(
        repository.updateImageStatus(
          imageId: images.single.id,
          status: UploadStatus.failed,
          attemptCount: 0,
        ),
        throwsA(isA<IllegalStatusTransitionError>()),
      );
      expect((await repository.getImage(images.single.id))!.status, UploadStatus.queued);
    });

    test('uploaded cannot be set here', () async {
      final (_, images) = await submittedBatch(1);
      await toUploading(images.single.id);

      await expectLater(
        repository.updateImageStatus(
          imageId: images.single.id,
          status: UploadStatus.uploaded,
          attemptCount: 0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('an unknown image throws DatabaseFailure', () async {
      await expectLater(
        repository.updateImageStatus(
          imageId: 'ghost',
          status: UploadStatus.uploading,
          attemptCount: 0,
        ),
        throwsA(isA<DatabaseFailure>()),
      );
    });

    test('a stored status the app does not know throws DatabaseFailure',
        () async {
      final (_, images) = await submittedBatch(1);
      await db.update(
        DatabaseSchema.imagesTable,
        {'status': 'bogus'},
        where: 'id = ?',
        whereArgs: [images.single.id],
      );

      await expectLater(
        repository.getImage(images.single.id),
        throwsA(isA<DatabaseFailure>()),
      );
    });
  });

  group('markUploaded', () {
    test('deletes the local file but keeps the row as synced history',
        () async {
      final (_, images) = await submittedBatch(1);
      final image = images.single;
      await toUploading(image.id);
      advance(const Duration(seconds: 30));

      await repository.markUploaded(image.id);

      expect(File(image.filePath).existsSync(), isFalse);
      final stored = (await repository.getImage(image.id))!;
      expect(stored.status, UploadStatus.uploaded);
      expect(stored.uploadedAt, now);
      expect(stored.nextRetryAt, isNull);
      expect(stored.fileSizeBytes, image.fileSizeBytes);
      expect(await db.query(DatabaseSchema.imagesTable), hasLength(1));
    });

    test('an uploaded image is no longer uploadable', () async {
      final (_, images) = await submittedBatch(1);
      await toUploading(images.single.id);
      await repository.markUploaded(images.single.id);

      expect(await repository.getUploadable(now), isEmpty);
    });

    test('only an uploading image can be marked uploaded', () async {
      final (_, images) = await submittedBatch(1);

      await expectLater(
        repository.markUploaded(images.single.id),
        throwsA(isA<IllegalStatusTransitionError>()),
      );
      expect(File(images.single.filePath).existsSync(), isTrue);
    });

    test('an already deleted file does not turn the upload into an error',
        () async {
      final (_, images) = await submittedBatch(1);
      await toUploading(images.single.id);
      File(images.single.filePath).deleteSync();

      await repository.markUploaded(images.single.id);

      expect((await repository.getImage(images.single.id))!.status, UploadStatus.uploaded);
    });
  });

  group('removeImage and deleteBatch', () {
    test('removeImage deletes the row and the file', () async {
      final image = await addImage();

      await repository.removeImage(image.id);

      expect(await repository.getImage(image.id), isNull);
      expect(File(image.filePath).existsSync(), isFalse);
    });

    test('removeImage of an unknown id does nothing', () async {
      await repository.removeImage('ghost');
    });

    test('an uploading image cannot be removed', () async {
      final (_, images) = await submittedBatch(1);
      await toUploading(images.single.id);

      await expectLater(
        repository.removeImage(images.single.id),
        throwsA(isA<IllegalBatchStateError>()),
      );
    });

    test('deleteBatch removes rows (by cascade) and the batch folder',
        () async {
      final (batch, images) = await submittedBatch(2);

      await repository.deleteBatch(batch.id);

      expect(await db.query(DatabaseSchema.batchesTable), isEmpty);
      expect(await db.query(DatabaseSchema.imagesTable), isEmpty);
      expect(Directory(p.dirname(images.first.filePath)).existsSync(), isFalse);
    });

    test('a batch with an uploading image cannot be deleted', () async {
      final (batch, images) = await submittedBatch(2);
      await toUploading(images.first.id);

      await expectLater(
        repository.deleteBatch(batch.id),
        throwsA(isA<IllegalBatchStateError>()),
      );
      expect(await db.query(DatabaseSchema.batchesTable), hasLength(1));
    });
  });

  group('resetInterruptedUploads', () {
    test('requeues images stuck in uploading', () async {
      final (_, images) = await submittedBatch(3);
      await toUploading(images[0].id);
      await toUploading(images[1].id);

      final count = await repository.resetInterruptedUploads();

      expect(count, 2);
      expect((await repository.getImage(images[0].id))!.status, UploadStatus.queued);
      expect((await repository.getImage(images[1].id))!.status, UploadStatus.queued);
      expect((await repository.getImage(images[2].id))!.status, UploadStatus.queued);
      expect(await repository.getUploadable(now), hasLength(3));
    });

    test('leaves other statuses alone', () async {
      final (_, images) = await submittedBatch(2);
      await repository.updateImageStatus(
        imageId: images[0].id,
        status: UploadStatus.waitingForConnection,
        attemptCount: 1,
      );
      await toUploading(images[1].id);
      await repository.markUploaded(images[1].id);

      expect(await repository.resetInterruptedUploads(), 0);
      expect(
        (await repository.getImage(images[0].id))!.status,
        UploadStatus.waitingForConnection,
      );
      expect((await repository.getImage(images[1].id))!.status, UploadStatus.uploaded);
    });

    test('a staleness window spares an upload that is still fresh', () async {
      final (_, images) = await submittedBatch(2);
      await toUploading(images[0].id);
      advance(const Duration(minutes: 20));
      await toUploading(images[1].id);
      advance(const Duration(minutes: 1));

      final count = await repository.resetInterruptedUploads(
        staleAfter: const Duration(minutes: 10),
      );

      expect(count, 1);
      expect((await repository.getImage(images[0].id))!.status, UploadStatus.queued);
      expect((await repository.getImage(images[1].id))!.status, UploadStatus.uploading);
    });

    test('keeps the attempt count of the interrupted image', () async {
      final (_, images) = await submittedBatch(1);
      await toUploading(images.single.id, attempts: 2);

      await repository.resetInterruptedUploads();

      expect((await repository.getImage(images.single.id))!.attemptCount, 2);
    });
  });


  group('claimImage', () {
    test('moves a queued image to uploading and returns it', () async {
      final (_, images) = await submittedBatch(1);

      final claimed = await repository.claimImage(images.single.id);

      expect(claimed, isNotNull);
      expect(claimed!.status, UploadStatus.uploading);
      expect(claimed.id, images.single.id);
      expect((await repository.getImage(images.single.id))!.status,
          UploadStatus.uploading);
    });

    test('a second claim of the same image fails', () async {
      final (_, images) = await submittedBatch(1);

      expect(await repository.claimImage(images.single.id), isNotNull);
      expect(await repository.claimImage(images.single.id), isNull);
    });

    test('works for waitingForConnection and a due retrying image', () async {
      final (_, images) = await submittedBatch(2);
      await repository.updateImageStatus(
        imageId: images[0].id,
        status: UploadStatus.waitingForConnection,
        attemptCount: 0,
      );
      await toUploading(images[1].id);
      await repository.updateImageStatus(
        imageId: images[1].id,
        status: UploadStatus.retrying,
        attemptCount: 1,
        nextRetryAt: now.add(const Duration(seconds: 30)),
      );

      expect(await repository.claimImage(images[0].id), isNotNull);
      expect(await repository.claimImage(images[1].id), isNull,
          reason: 'retry not due yet');
      advance(const Duration(seconds: 31));
      expect(await repository.claimImage(images[1].id), isNotNull);
    });

    test('refuses images that are uploaded, failed or in an open batch',
        () async {
      final open = await addImage(name: 'open.jpg');
      expect(await repository.claimImage(open.id), isNull);

      final (_, images) = await submittedBatch(2);
      await toUploading(images[0].id);
      await repository.markUploaded(images[0].id);
      await toUploading(images[1].id);
      await repository.updateImageStatus(
        imageId: images[1].id,
        status: UploadStatus.failed,
        attemptCount: 3,
      );

      expect(await repository.claimImage(images[0].id), isNull);
      expect(await repository.claimImage(images[1].id), isNull);
    });

    test('an unknown image cannot be claimed', () async {
      expect(await repository.claimImage('ghost'), isNull);
    });
  });

  group('renewClaim', () {
    Future<int> updatedAt(String id) async {
      final rows = await db.query(
        DatabaseSchema.imagesTable,
        columns: ['updated_at'],
        where: 'id = ?',
        whereArgs: [id],
      );
      return rows.single['updated_at']! as int;
    }

    test('refreshes the timestamp of an uploading image', () async {
      final (_, images) = await submittedBatch(1);
      await repository.claimImage(images.single.id);
      final before = await updatedAt(images.single.id);

      advance(const Duration(minutes: 1));
      await repository.renewClaim(images.single.id);

      expect(await updatedAt(images.single.id), before + 60000);
    });

    test('does nothing for an image that is no longer uploading', () async {
      final (_, images) = await submittedBatch(1);
      final before = await updatedAt(images.single.id);

      advance(const Duration(minutes: 1));
      await repository.renewClaim(images.single.id);

      expect(await updatedAt(images.single.id), before);
    });

    test('a renewed claim is not requeued by the staleness window', () async {
      final (_, images) = await submittedBatch(1);
      await repository.claimImage(images.single.id);
      advance(const Duration(minutes: 8));
      await repository.renewClaim(images.single.id);
      advance(const Duration(minutes: 3));

      final reset = await repository.resetInterruptedUploads(
        staleAfter: const Duration(minutes: 5),
      );

      expect(reset, 0);
      expect((await repository.getImage(images.single.id))!.status,
          UploadStatus.uploading);
    });
  });

  group('markWaitingForConnection', () {
    test('moves queued and retrying images, keeps retry times', () async {
      final (_, images) = await submittedBatch(4);
      final retryAt = now.add(const Duration(minutes: 1));
      await toUploading(images[1].id);
      await repository.updateImageStatus(
        imageId: images[1].id,
        status: UploadStatus.retrying,
        attemptCount: 1,
        nextRetryAt: retryAt,
      );
      await toUploading(images[2].id); // stays uploading
      await toUploading(images[3].id);
      await repository.markUploaded(images[3].id); // stays uploaded

      final changed = await repository.markWaitingForConnection();

      expect(changed, 2);
      final queued = (await repository.getImage(images[0].id))!;
      final retrying = (await repository.getImage(images[1].id))!;
      expect(queued.status, UploadStatus.waitingForConnection);
      expect(retrying.status, UploadStatus.waitingForConnection);
      expect(retrying.nextRetryAt, retryAt);
      expect(retrying.attemptCount, 1);
      expect((await repository.getImage(images[2].id))!.status,
          UploadStatus.uploading);
      expect((await repository.getImage(images[3].id))!.status,
          UploadStatus.uploaded);
    });

    test('ignores images in an open batch', () async {
      final open = await addImage();

      expect(await repository.markWaitingForConnection(), 0);
      expect((await repository.getImage(open.id))!.status, UploadStatus.queued);
    });

    test('notifies the watch streams', () async {
      await submittedBatch(1);
      final emissions = <List<CaptureBatch>>[];
      final sub = repository.watchSubmittedBatches().listen(emissions.add);
      addTearDown(sub.cancel);
      await eventually(() => emissions.isNotEmpty);

      await repository.markWaitingForConnection();

      await eventually(
        () => emissions.last.single.images.single.status ==
            UploadStatus.waitingForConnection,
      );
    });
  });

  group('getUnfinished', () {
    test('lists queued, waiting, uploading and retrying images only',
        () async {
      final (_, images) = await submittedBatch(5);
      await repository.updateImageStatus(
        imageId: images[1].id,
        status: UploadStatus.waitingForConnection,
        attemptCount: 0,
      );
      await toUploading(images[2].id);
      await toUploading(images[3].id);
      await repository.markUploaded(images[3].id);
      await toUploading(images[4].id);
      await repository.updateImageStatus(
        imageId: images[4].id,
        status: UploadStatus.failed,
        attemptCount: 3,
      );
      await addImage(name: 'open.jpg'); // open batch: excluded

      final ids = (await repository.getUnfinished()).map((i) => i.id);

      expect(ids, [images[0].id, images[1].id, images[2].id]);
    });
  });

  group('watch streams and refresh', () {
    test('watchOpenBatch emits null, then updates as images are added',
        () async {
      final emissions = <CaptureBatch?>[];
      final sub = repository.watchOpenBatch().listen(emissions.add);
      addTearDown(sub.cancel);

      await eventually(() => emissions.length == 1);
      expect(emissions.single, isNull);

      final image = await addImage();
      await eventually(() => emissions.any((b) => b?.images.length == 1));
      expect(emissions.last!.images.single.id, image.id);
    });

    test('watchSubmittedBatches re-emits after a submit and a status change',
        () async {
      final emissions = <List<CaptureBatch>>[];
      final sub = repository.watchSubmittedBatches().listen(emissions.add);
      addTearDown(sub.cancel);
      await eventually(() => emissions.isNotEmpty);
      expect(emissions.last, isEmpty);

      final image = await addImage();
      await repository.submitBatch(image.batchId);
      await eventually(() => emissions.last.length == 1);

      await toUploading(image.id);
      await eventually(
        () => emissions.last.single.images.single.status == UploadStatus.uploading,
      );
    });

    test('a write made outside this repository is only seen after refresh()',
        () async {
      final (_, images) = await submittedBatch(1);
      final emissions = <List<CaptureBatch>>[];
      final sub = repository.watchSubmittedBatches().listen(emissions.add);
      addTearDown(sub.cancel);
      await eventually(() => emissions.isNotEmpty);
      final countBefore = emissions.length;

      // Simulates the background isolate: a different connection, no signal.
      await db.update(
        DatabaseSchema.imagesTable,
        {'status': UploadStatus.waitingForConnection.name},
        where: 'id = ?',
        whereArgs: [images.single.id],
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(emissions.length, countBefore, reason: 'no signal, no emission');

      repository.refresh();
      await eventually(() => emissions.length > countBefore);

      expect(
        emissions.last.single.images.single.status,
        UploadStatus.waitingForConnection,
      );
    });

    test('a new listener gets the current state immediately', () async {
      await addImage();

      final batch = await repository.watchOpenBatch().first;

      expect(batch!.images, hasLength(1));
    });
  });

  group('RecordUploadResult against the real repository', () {
    RecordUploadResult useCase({int maxAttempts = 3}) {
      return RecordUploadResult(
        repository,
        backoff: ExponentialBackoff(
          baseDelay: const Duration(seconds: 30),
          multiplier: 2,
          maxDelay: const Duration(minutes: 10),
          jitterRatio: 0,
          random: Random(1),
        ),
        now: () => now,
        maxAttempts: maxAttempts,
      );
    }

    test('a retryable failure schedules a retry, then fails at the limit',
        () async {
      final (_, images) = await submittedBatch(1);
      final id = images.single.id;
      const slow = UploadFailed(LowBandwidthFailure('slow'));

      await toUploading(id);
      await useCase()((await repository.getImage(id))!, slow);
      var stored = (await repository.getImage(id))!;
      expect(stored.status, UploadStatus.retrying);
      expect(stored.attemptCount, 1);
      expect(stored.nextRetryAt, now.add(const Duration(seconds: 30)));

      await toUploading(id, attempts: 1);
      await useCase()((await repository.getImage(id))!, slow);
      stored = (await repository.getImage(id))!;
      expect(stored.nextRetryAt, now.add(const Duration(seconds: 60)));

      await toUploading(id, attempts: 2);
      await useCase()((await repository.getImage(id))!, slow);
      stored = (await repository.getImage(id))!;
      expect(stored.status, UploadStatus.failed);
      expect(stored.attemptCount, 3);
      expect(stored.nextRetryAt, isNull);
    });

    test('success deletes the file and keeps the row', () async {
      final (_, images) = await submittedBatch(1);
      await toUploading(images.single.id);

      await useCase()(
        (await repository.getImage(images.single.id))!,
        const UploadSuccess(serverReference: 'ref'),
      );

      expect(File(images.single.filePath).existsSync(), isFalse);
      expect((await repository.getImage(images.single.id))!.status, UploadStatus.uploaded);
    });

    test('recording a result for an image that is not uploading throws',
        () async {
      final (_, images) = await submittedBatch(1);

      await expectLater(
        useCase()(
          images.single,
          const UploadFailed(LowBandwidthFailure('slow')),
        ),
        throwsA(isA<IllegalStatusTransitionError>()),
      );
    });
  });
}
