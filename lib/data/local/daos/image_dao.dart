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

  static String get _uploadableStatuses => UploadStatus.values
      .where((s) => s.isUploadable)
      .map((s) => "'${s.name}'")
      .join(', ');

  static const _submittedBatchIds =
      'SELECT ${DatabaseSchema.colId} FROM ${DatabaseSchema.batchesTable} '
      'WHERE ${DatabaseSchema.colSubmittedAt} IS NOT NULL';

  /// Uploadable images of submitted batches that are due at [nowMillis],
  /// oldest capture first.
  Future<List<CapturedImageModel>> getUploadable(
    DatabaseExecutor db,
    int nowMillis,
  ) async {
    final statuses = _uploadableStatuses;
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

  /// Images of submitted batches that are not finished: queued, waiting,
  /// uploading or retrying.
  Future<List<CapturedImageModel>> getUnfinished(DatabaseExecutor db) async {
    final statuses = [
      ...UploadStatus.values.where((s) => s.isUploadable),
      UploadStatus.uploading,
    ].map((s) => "'${s.name}'").join(', ');
    final rows = await db.query(
      _table,
      where:
          '${DatabaseSchema.colStatus} IN ($statuses) '
          'AND ${DatabaseSchema.colBatchId} IN ($_submittedBatchIds)',
      orderBy: '${DatabaseSchema.colCapturedAt} ASC, ${DatabaseSchema.colId}',
    );
    return rows.map(CapturedImageModel.fromMap).toList();
  }

  /// Atomically takes an image for upload. One SQL statement, so when two
  /// isolates race for the same image exactly one sees a changed row.
  /// Succeeds only if the image is still uploadable, due, and in a submitted
  /// batch. Returns true when this caller now owns it.
  Future<bool> claim(DatabaseExecutor db, String id, int nowMillis) async {
    final changed = await db.rawUpdate(
      '''
UPDATE $_table
SET ${DatabaseSchema.colStatus} = ?, ${DatabaseSchema.colUpdatedAt} = ?
WHERE ${DatabaseSchema.colId} = ?
  AND ${DatabaseSchema.colStatus} IN ($_uploadableStatuses)
  AND (${DatabaseSchema.colNextRetryAt} IS NULL
       OR ${DatabaseSchema.colNextRetryAt} <= ?)
  AND ${DatabaseSchema.colBatchId} IN ($_submittedBatchIds)
''',
      [UploadStatus.uploading.name, nowMillis, id, nowMillis],
    );
    return changed == 1;
  }

  /// Refreshes the claim timestamp of an image that is still uploading, so a
  /// long upload is not mistaken for an abandoned one. Returns false when the
  /// image is no longer uploading.
  Future<bool> renewClaim(DatabaseExecutor db, String id, int nowMillis) async {
    final changed = await db.update(
      _table,
      {DatabaseSchema.colUpdatedAt: nowMillis},
      where: '${DatabaseSchema.colId} = ? AND ${DatabaseSchema.colStatus} = ?',
      whereArgs: [id, UploadStatus.uploading.name],
    );
    return changed == 1;
  }

  /// Marks queued and retrying images of submitted batches as waiting for a
  /// connection. Their retry times are kept. Returns the number changed.
  Future<int> markWaitingForConnection(DatabaseExecutor db, int nowMillis) {
    return db.rawUpdate(
      '''
UPDATE $_table
SET ${DatabaseSchema.colStatus} = ?, ${DatabaseSchema.colUpdatedAt} = ?
WHERE ${DatabaseSchema.colStatus} IN (?, ?)
  AND ${DatabaseSchema.colBatchId} IN ($_submittedBatchIds)
''',
      [
        UploadStatus.waitingForConnection.name,
        nowMillis,
        UploadStatus.queued.name,
        UploadStatus.retrying.name,
      ],
    );
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
      where:
          '${DatabaseSchema.colStatus} = ? '
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
