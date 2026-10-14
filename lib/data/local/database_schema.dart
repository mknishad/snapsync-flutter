/// Table and column names, and the DDL for the current schema version.
/// Timestamps are stored as UTC epoch milliseconds.
abstract final class DatabaseSchema {
  static const String batchesTable = 'batches';
  static const String imagesTable = 'images';

  // batches
  static const String colId = 'id';
  static const String colCreatedAt = 'created_at';
  static const String colSubmittedAt = 'submitted_at';

  // images
  static const String colBatchId = 'batch_id';
  static const String colFilePath = 'file_path';
  static const String colFileSizeBytes = 'file_size_bytes';
  static const String colCapturedAt = 'captured_at';
  static const String colStatus = 'status';
  static const String colAttemptCount = 'attempt_count';
  static const String colLastError = 'last_error';
  static const String colNextRetryAt = 'next_retry_at';
  static const String colUploadedAt = 'uploaded_at';

  /// Last time the row's status changed. Only used to tell a live upload from
  /// one left behind by a killed process; not part of the domain entity.
  static const String colUpdatedAt = 'updated_at';

  static const List<String> createStatements = [
    '''
CREATE TABLE $batchesTable (
  $colId TEXT PRIMARY KEY,
  $colCreatedAt INTEGER NOT NULL,
  $colSubmittedAt INTEGER
)''',
    '''
CREATE TABLE $imagesTable (
  $colId TEXT PRIMARY KEY,
  $colBatchId TEXT NOT NULL REFERENCES $batchesTable($colId) ON DELETE CASCADE,
  $colFilePath TEXT NOT NULL,
  $colFileSizeBytes INTEGER NOT NULL,
  $colCapturedAt INTEGER NOT NULL,
  $colStatus TEXT NOT NULL,
  $colAttemptCount INTEGER NOT NULL DEFAULT 0,
  $colLastError TEXT,
  $colNextRetryAt INTEGER,
  $colUploadedAt INTEGER,
  $colUpdatedAt INTEGER NOT NULL
)''',
    'CREATE INDEX idx_images_batch_id ON $imagesTable($colBatchId)',
    'CREATE INDEX idx_images_status ON $imagesTable($colStatus)',
    'CREATE INDEX idx_images_next_retry_at ON $imagesTable($colNextRetryAt)',
  ];
}
