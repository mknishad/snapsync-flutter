import 'package:snapsync/data/local/database_schema.dart';
import 'package:snapsync/data/local/models/captured_image_model.dart';
import 'package:snapsync/domain/entities/upload_status.dart';
import 'package:sqflite/sqflite.dart';

/// SQL for the images table. Every method takes the executor so the
/// repository can run several of them in one transaction.
class ImageDao {
  const ImageDao();

  static const _table = DatabaseSchema.imagesTable;

  Future<void> insert(DatabaseExecutor db, CapturedImageModel image) async {
    await db.insert(_table, image.toMap());
  }

  Future<CapturedImageModel?> getById(DatabaseExecutor db, String id) async {
    final rows = await db.query(
      _table,
      where: '${DatabaseSchema.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : CapturedImageModel.fromMap(rows.first);
  }

  Future<List<CapturedImageModel>> getByBatch(
    DatabaseExecutor db,
    String batchId,
  ) async {
    final rows = await db.query(
      _table,
      where: '${DatabaseSchema.colBatchId} = ?',
      whereArgs: [batchId],
      orderBy: '${DatabaseSchema.colCapturedAt} ASC, ${DatabaseSchema.colId}',
    );
    return rows.map(CapturedImageModel.fromMap).toList();
  }

  /// Uploadable images of submitted batches that are due at [nowMillis],
  /// oldest capture first.
  Future<List<CapturedImageModel>> getUploadable(
    DatabaseExecutor db,
    int nowMillis,
  ) async {
    final statuses = UploadStatus.values
        .where((s) => s.isUploadable)
        .map((s) => "'${s.name}'")
        .join(', ');
    final rows = await db.rawQuery(
      '''
SELECT i.* FROM ${DatabaseSchema.imagesTable} i
JOIN ${DatabaseSchema.batchesTable} b
  ON b.${DatabaseSchema.colId} = i.${DatabaseSchema.colBatchId}
WHERE b.${DatabaseSchema.colSubmittedAt} IS NOT NULL
  AND i.${DatabaseSchema.colStatus} IN ($statuses)
  AND (i.${DatabaseSchema.colNextRetryAt} IS NULL
       OR i.${DatabaseSchema.colNextRetryAt} <= ?)
ORDER BY i.${DatabaseSchema.colCapturedAt} ASC, i.${DatabaseSchema.colId}
''',
      [nowMillis],
    );
    return rows.map(CapturedImageModel.fromMap).toList();
  }

  /// Writes the status and the retry bookkeeping together. A null
  /// [lastError] or [nextRetryAtMillis] clears the stored value.
  Future<void> updateStatus(
    DatabaseExecutor db, {
    required String id,
    required String status,
    required int attemptCount,
    required int updatedAtMillis,
    String? lastError,
    int? nextRetryAtMillis,
    int? uploadedAtMillis,
  }) async {
    await db.update(
      _table,
      {
        DatabaseSchema.colStatus: status,
        DatabaseSchema.colAttemptCount: attemptCount,
        DatabaseSchema.colLastError: lastError,
        DatabaseSchema.colNextRetryAt: nextRetryAtMillis,
        DatabaseSchema.colUploadedAt: uploadedAtMillis,
        DatabaseSchema.colUpdatedAt: updatedAtMillis,
      },
      where: '${DatabaseSchema.colId} = ?',
      whereArgs: [id],
    );
  }

  /// Sets every image of the batch to queued.
  Future<void> queueAllInBatch(
    DatabaseExecutor db,
    String batchId,
    int updatedAtMillis,
  ) async {
    await db.update(
      _table,
      {
        DatabaseSchema.colStatus: UploadStatus.queued.name,
        DatabaseSchema.colUpdatedAt: updatedAtMillis,
      },
      where: '${DatabaseSchema.colBatchId} = ?',
      whereArgs: [batchId],
    );
  }

  /// Requeues `uploading` rows last touched at or before [staleBeforeMillis].
  /// Returns the number of rows changed.
  Future<int> resetStaleUploading(
    DatabaseExecutor db, {
    required int staleBeforeMillis,
    required int updatedAtMillis,
  }) {
    return db.update(
      _table,
      {
        DatabaseSchema.colStatus: UploadStatus.queued.name,
        DatabaseSchema.colUpdatedAt: updatedAtMillis,
      },
      where: '${DatabaseSchema.colStatus} = ? '
          'AND ${DatabaseSchema.colUpdatedAt} <= ?',
      whereArgs: [UploadStatus.uploading.name, staleBeforeMillis],
    );
  }

  Future<void> delete(DatabaseExecutor db, String id) async {
    await db.delete(
      _table,
      where: '${DatabaseSchema.colId} = ?',
      whereArgs: [id],
    );
  }
}
