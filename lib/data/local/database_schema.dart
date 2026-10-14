/// Table and column names. Keeping them here avoids string typos in DAOs.
abstract final class DatabaseSchema {
  static const String batchesTable = 'batches';
  static const String imagesTable = 'images';

  static const String colId = 'id';
  static const String colCreatedAt = 'created_at';

  // images
  static const String colBatchId = 'batch_id';
  static const String colFilePath = 'file_path';
  static const String colSizeBytes = 'size_bytes';
  static const String colStatus = 'status';
  static const String colRetryCount = 'retry_count';
  static const String colLastError = 'last_error';

  // TODO: CREATE TABLE statements and migrations.
}
