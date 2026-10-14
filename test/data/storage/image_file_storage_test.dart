import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:snapsync/core/error/failure.dart';
import 'package:snapsync/data/storage/image_file_storage.dart';

import '../../support/test_support.dart';

void main() {
  late Directory root;
  late Directory appDir;
  late Directory cameraDir;
  late ImageFileStorage storage;

  File cameraFile(String name, {List<int> bytes = const [1, 2, 3, 4, 5]}) {
    return File(p.join(cameraDir.path, name))..writeAsBytesSync(bytes);
  }

  setUp(() {
    root = createTempDir('snapsync_storage_');
    appDir = Directory(p.join(root.path, 'app'))..createSync();
    cameraDir = Directory(p.join(root.path, 'camera_cache'))..createSync();
    storage = ImageFileStorage(baseDirectory: () async => appDir);
  });

  tearDown(() => root.deleteSync(recursive: true));

  group('store', () {
    test('copies into batches/<batchId>/<imageId>.<ext> and reports the size',
        () async {
      final source = cameraFile('IMG_1.png');

      final stored = await storage.store(
        sourcePath: source.path,
        batchId: 'batch-1',
        imageId: 'img-1',
      );

      expect(
        stored.path,
        p.join(appDir.path, 'batches', 'batch-1', 'img-1.png'),
      );
      expect(stored.sizeBytes, 5);
      expect(File(stored.path).readAsBytesSync(), [1, 2, 3, 4, 5]);
    });

    test('leaves the source in place', () async {
      final source = cameraFile('IMG_1.jpg');
      await storage.store(
        sourcePath: source.path,
        batchId: 'b',
        imageId: 'i',
      );
      expect(source.existsSync(), isTrue);
    });

    test('defaults to .jpg when the source has no extension', () async {
      final source = cameraFile('capture');
      final stored = await storage.store(
        sourcePath: source.path,
        batchId: 'b',
        imageId: 'i',
      );
      expect(p.extension(stored.path), '.jpg');
    });

    test('a missing source is a FileMissingFailure', () async {
      await expectLater(
        storage.store(
          sourcePath: p.join(cameraDir.path, 'nope.jpg'),
          batchId: 'b',
          imageId: 'i',
        ),
        throwsA(isA<FileMissingFailure>()),
      );
    });

    test('an I/O error becomes a StorageFailure, not a raw exception',
        () async {
      // A file where the "batches" directory should be makes create() fail.
      File(p.join(appDir.path, 'batches')).writeAsStringSync('in the way');
      final source = cameraFile('IMG_1.jpg');

      await expectLater(
        storage.store(sourcePath: source.path, batchId: 'b', imageId: 'i'),
        throwsA(isA<StorageFailure>()),
      );
    });

    test('rejects identifiers that could escape the batch folder', () async {
      final source = cameraFile('IMG_1.jpg');
      for (final bad in ['../evil', 'a/b', '', '..']) {
        await expectLater(
          storage.store(sourcePath: source.path, batchId: bad, imageId: 'i'),
          throwsA(isA<StorageFailure>()),
          reason: 'batchId "$bad"',
        );
      }
    });
  });

  group('sizeOf and exists', () {
    test('sizeOf reads the size', () async {
      expect(await storage.sizeOf(cameraFile('a.jpg').path), 5);
    });

    test('sizeOf on a missing file is a FileMissingFailure', () async {
      await expectLater(
        storage.sizeOf(p.join(cameraDir.path, 'nope.jpg')),
        throwsA(isA<FileMissingFailure>()),
      );
    });

    test('exists reports both cases', () async {
      expect(await storage.exists(cameraFile('a.jpg').path), isTrue);
      expect(await storage.exists(p.join(cameraDir.path, 'nope.jpg')), isFalse);
    });
  });

  group('delete', () {
    test('deleteFile removes the file and tolerates a missing one', () async {
      final file = cameraFile('a.jpg');
      await storage.deleteFile(file.path);
      expect(file.existsSync(), isFalse);
      await storage.deleteFile(file.path);
    });

    test('deleteBatchDirectory removes the whole batch folder', () async {
      final source = cameraFile('a.jpg');
      final one = await storage.store(sourcePath: source.path, batchId: 'b1', imageId: 'i1');
      final two = await storage.store(sourcePath: source.path, batchId: 'b1', imageId: 'i2');
      final other = await storage.store(sourcePath: source.path, batchId: 'b2', imageId: 'i3');

      await storage.deleteBatchDirectory('b1');

      expect(File(one.path).existsSync(), isFalse);
      expect(File(two.path).existsSync(), isFalse);
      expect(File(other.path).existsSync(), isTrue);
    });

    test('deleteBatchDirectory tolerates a batch with no folder', () async {
      await storage.deleteBatchDirectory('never-stored');
    });
  });
}
