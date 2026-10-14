import 'dart:async';

import 'package:snapsync/core/error/failure.dart';
import 'package:snapsync/core/utils/clock.dart';
import 'package:snapsync/core/utils/safe_log.dart';
import 'package:snapsync/data/local/daos/batch_dao.dart';
import 'package:snapsync/data/local/daos/image_dao.dart';
import 'package:snapsync/data/local/database_helper.dart';
import 'package:snapsync/data/local/mappers/batch_mapper.dart';
import 'package:snapsync/data/local/mappers/captured_image_mapper.dart';
import 'package:snapsync/data/local/models/batch_model.dart';
import 'package:snapsync/data/local/models/captured_image_model.dart';
import 'package:snapsync/data/storage/image_file_storage.dart';
import 'package:snapsync/domain/entities/capture_batch.dart';
import 'package:snapsync/domain/entities/captured_image.dart';
import 'package:snapsync/domain/entities/upload_status.dart';
import 'package:snapsync/domain/errors/domain_errors.dart';
import 'package:snapsync/domain/repositories/batch_repository.dart';
import 'package:sqflite/sqflite.dart';

class BatchRepositoryImpl implements BatchRepository {
  BatchRepositoryImpl({
    required this.databaseHelper,
    required this.batchDao,
    required this.imageDao,
    required this.storage,
    required this._generateId,
    Clock? clock,
  }) : _clock = clock ?? utcNow;

  final DatabaseHelper databaseHelper;
  final BatchDao batchDao;
  final ImageDao imageDao;
  final ImageFileStorage storage;
  final String Function() _generateId;
  final Clock _clock;

  /// Fires after every write made through this instance, and on [refresh].
  /// Writes made by another isolate do not fire it.
  final StreamController<void> _changes = StreamController<void>.broadcast();

  DateTime _now() => _clock().truncateToMillis();

  // ---- batches -----------------------------------------------------------

  @override
  Future<CaptureBatch> getOrCreateOpenBatch() {
    return _guard(() async {
      final db = await databaseHelper.database;
      final batch = await db.transaction((txn) async {
        final open = await batchDao.getOpen(txn);
        if (open != null) return open;
        final created = BatchModel(
          id: _generateId(),
          createdAtMillis: _now().millisecondsSinceEpoch,
        );
        await batchDao.insert(txn, created);
        return created;
      });
      _notify();
      return batch.toEntity(await _imagesOf(db, batch.id));
    });
  }

  @override
  Future<void> submitBatch(String batchId) {
    return _guard(() async {
      final db = await databaseHelper.database;
      await db.transaction((txn) async {
        final batch = await _requireBatch(txn, batchId);
        if (batch.submittedAtMillis != null) return;
        final images = await imageDao.getByBatch(txn, batchId);
        if (images.isEmpty) {
          throw IllegalBatchStateError('Cannot submit an empty batch');
        }
        final now = _now().millisecondsSinceEpoch;
        await batchDao.markSubmitted(txn, batchId, now);
        await imageDao.queueAllInBatch(txn, batchId, now);
      });
      _notify();
    });
  }

  @override
  Future<void> deleteBatch(String batchId) {
    return _guard(() async {
      final db = await databaseHelper.database;
      await db.transaction((txn) async {
        await _requireBatch(txn, batchId);
        final images = await imageDao.getByBatch(txn, batchId);
        if (images.any((i) => i.status == UploadStatus.uploading.name)) {
          throw IllegalBatchStateError('Cannot delete a batch while uploading');
        }
        await batchDao.delete(txn, batchId); // cascades to its images
      });
      _notify();
      await storage.deleteBatchDirectory(batchId);
    });
  }

  // ---- images ------------------------------------------------------------

  @override
  Future<CapturedImage> addImage(String batchId, String capturedFilePath) {
    return _guard(() async {
      final db = await databaseHelper.database;
      final batch = await _requireBatch(db, batchId);
      if (batch.submittedAtMillis != null) {
        throw IllegalBatchStateError(
          'Cannot add an image to a submitted batch',
        );
      }

      final imageId = _generateId();
      final stored = await storage.store(
        sourcePath: capturedFilePath,
        batchId: batchId,
        imageId: imageId,
      );
      final image = CapturedImage(
        id: imageId,
        batchId: batchId,
        filePath: stored.path,
        fileSizeBytes: stored.sizeBytes,
        capturedAt: _now(),
      );
      try {
        await imageDao.insert(db, image.toModel(updatedAt: _now()));
      } on DatabaseException catch (e) {
        // Do not leave a file behind that no row points to.
        await _deleteQuietly(stored.path);
        throw DatabaseFailure('Could not record the image: $e');
      }
      _notify();
      return image;
    });
  }

  @override
  Future<void> removeImage(String imageId) {
    return _guard(() async {
      final db = await databaseHelper.database;
      final image = await db.transaction((txn) async {
        final model = await imageDao.getById(txn, imageId);
        if (model == null) return null;
        if (model.status == UploadStatus.uploading.name) {
          throw IllegalBatchStateError(
            'Cannot remove an image while uploading',
          );
        }
        await imageDao.delete(txn, imageId);
        return model;
      });
      if (image == null) return;
      _notify();
      await storage.deleteFile(image.filePath);
    });
  }

  @override
  Future<CapturedImage?> getImage(String imageId) {
    return _guard(() async {
      final db = await databaseHelper.database;
      final model = await imageDao.getById(db, imageId);
      return model?.toEntity();
    });
  }

  @override
  Future<List<CapturedImage>> getUploadable(DateTime now) {
    return _guard(() async {
      final db = await databaseHelper.database;
      final models = await imageDao.getUploadable(
        db,
        now.millisecondsSinceEpoch,
      );
      return models.map((m) => m.toEntity()).toList();
    });
  }

  @override
  Future<List<CapturedImage>> getUnfinished() {
    return _guard(() async {
      final db = await databaseHelper.database;
      final models = await imageDao.getUnfinished(db);
      return models.map((m) => m.toEntity()).toList();
    });
  }

  @override
  Future<CapturedImage?> claimImage(String imageId) {
    return _guard(() async {
      final db = await databaseHelper.database;
      final claimed = await imageDao.claim(
        db,
        imageId,
        _now().millisecondsSinceEpoch,
      );
      if (!claimed) return null;
      _notify();
      final model = await imageDao.getById(db, imageId);
      return model?.toEntity();
    });
  }

  @override
  Future<void> renewClaim(String imageId) {
    return _guard(() async {
      final db = await databaseHelper.database;
      await imageDao.renewClaim(db, imageId, _now().millisecondsSinceEpoch);
    });
  }

  @override
  Future<int> markWaitingForConnection() {
    return _guard(() async {
      final db = await databaseHelper.database;
      final count = await imageDao.markWaitingForConnection(
        db,
        _now().millisecondsSinceEpoch,
      );
      if (count > 0) _notify();
      return count;
    });
  }

  @override
  Future<void> updateImageStatus({
    required String imageId,
    required UploadStatus status,
    required int attemptCount,
    String? lastError,
    DateTime? nextRetryAt,
  }) {
    return _guard(() async {
      if (status == UploadStatus.uploaded) {
        throw ArgumentError.value(status, 'status', 'use markUploaded');
      }
      final db = await databaseHelper.database;
      await db.transaction((txn) async {
        final current = await _requireImage(txn, imageId);
        _statusOf(current.status).ensureCanTransitionTo(status);
        await imageDao.updateStatus(
          txn,
          id: imageId,
          status: status.name,
          attemptCount: attemptCount,
          lastError: lastError,
          nextRetryAtMillis: nextRetryAt?.millisecondsSinceEpoch,
          uploadedAtMillis: current.uploadedAtMillis,
          updatedAtMillis: _now().millisecondsSinceEpoch,
        );
      });
      _notify();
    });
  }

  @override
  Future<void> markUploaded(String imageId) {
    return _guard(() async {
      final db = await databaseHelper.database;
      final filePath = await db.transaction((txn) async {
        final current = await _requireImage(txn, imageId);
        _statusOf(current.status).ensureCanTransitionTo(UploadStatus.uploaded);
        final now = _now().millisecondsSinceEpoch;
        await imageDao.updateStatus(
          txn,
          id: imageId,
          status: UploadStatus.uploaded.name,
          attemptCount: current.attemptCount,
          uploadedAtMillis: now,
          updatedAtMillis: now,
        );
        return current.filePath;
      });
      _notify();
      // The upload already succeeded, so a cleanup problem must not turn it
      // into an error. It is logged instead of swallowed.
      await _deleteQuietly(filePath);
    });
  }

  @override
  Future<int> resetInterruptedUploads({Duration staleAfter = Duration.zero}) {
    return _guard(() async {
      final db = await databaseHelper.database;
      final now = _now();
      final count = await imageDao.resetStaleUploading(
        db,
        staleBeforeMillis: now.subtract(staleAfter).millisecondsSinceEpoch,
        updatedAtMillis: now.millisecondsSinceEpoch,
      );
      if (count > 0) _notify();
      return count;
    });
  }

  // ---- streams -----------------------------------------------------------

  @override
  Stream<CaptureBatch?> watchOpenBatch() {
    return _watch(() async {
      final db = await databaseHelper.database;
      final open = await batchDao.getOpen(db);
      return open?.toEntity(await _imagesOf(db, open.id));
    });
  }

  @override
  Stream<List<CaptureBatch>> watchSubmittedBatches() {
    return _watch(() async {
      final db = await databaseHelper.database;
      final models = await batchDao.getSubmitted(db);
      return [
        for (final model in models)
          model.toEntity(await _imagesOf(db, model.id)),
      ];
    });
  }

  @override
  void refresh() => _notify();

  Future<void> dispose() => _changes.close();

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  /// Emits the query result on listen and again after every change signal.
  /// Queries are chained so results are never emitted out of order.
  Stream<T> _watch<T>(Future<T> Function() query) {
    late final StreamController<T> controller;
    StreamSubscription<void>? subscription;
    var tail = Future<void>.value();

    void emit() {
      tail = tail.then((_) async {
        if (controller.isClosed || !controller.hasListener) return;
        try {
          controller.add(await _guard(query));
        } on Object catch (error, stack) {
          controller.addError(error, stack);
        }
      });
    }

    controller = StreamController<T>(
      onListen: () {
        subscription = _changes.stream.listen((_) => emit());
        emit();
      },
      onCancel: () async {
        await subscription?.cancel();
        await controller.close();
      },
    );
    return controller.stream;
  }

  // ---- helpers -----------------------------------------------------------

  Future<List<CapturedImage>> _imagesOf(
    DatabaseExecutor db,
    String batchId,
  ) async {
    final models = await imageDao.getByBatch(db, batchId);
    return models.map((m) => m.toEntity()).toList();
  }

  Future<BatchModel> _requireBatch(DatabaseExecutor db, String id) async {
    final batch = await batchDao.getById(db, id);
    if (batch == null) throw DatabaseFailure('Batch $id does not exist');
    return batch;
  }

  Future<CapturedImageModel> _requireImage(
    DatabaseExecutor db,
    String id,
  ) async {
    final image = await imageDao.getById(db, id);
    if (image == null) throw DatabaseFailure('Image $id does not exist');
    return image;
  }

  UploadStatus _statusOf(String stored) {
    return UploadStatus.values.firstWhere(
      (s) => s.name == stored,
      orElse: () => throw DatabaseFailure('Unknown stored status "$stored"'),
    );
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      await storage.deleteFile(path);
    } on Failure catch (failure) {
      logProblem(
        'snapsync.storage',
        'Could not delete a stored file',
        error: failure,
      );
    }
  }

  /// Turns sqflite errors into [DatabaseFailure]. Failures and domain errors
  /// pass through untouched.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DatabaseException catch (e) {
      throw DatabaseFailure('Database error: $e');
    }
  }
}
