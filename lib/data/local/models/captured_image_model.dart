import 'package:snapsync/core/utils/typedefs.dart';
import 'package:snapsync/data/local/database_schema.dart';

/// Database row shape for a captured image. Status is stored by enum name.
class CapturedImageModel {
  const CapturedImageModel({
    required this.id,
    required this.batchId,
    required this.filePath,
    required this.fileSizeBytes,
    required this.capturedAtMillis,
    required this.status,
    required this.attemptCount,
    required this.updatedAtMillis,
    this.lastError,
    this.nextRetryAtMillis,
    this.uploadedAtMillis,
  });

  factory CapturedImageModel.fromMap(DbRow map) {
    return CapturedImageModel(
      id: map[DatabaseSchema.colId]! as String,
      batchId: map[DatabaseSchema.colBatchId]! as String,
      filePath: map[DatabaseSchema.colFilePath]! as String,
      fileSizeBytes: map[DatabaseSchema.colFileSizeBytes]! as int,
      capturedAtMillis: map[DatabaseSchema.colCapturedAt]! as int,
      status: map[DatabaseSchema.colStatus]! as String,
      attemptCount: map[DatabaseSchema.colAttemptCount]! as int,
      updatedAtMillis: map[DatabaseSchema.colUpdatedAt]! as int,
      lastError: map[DatabaseSchema.colLastError] as String?,
      nextRetryAtMillis: map[DatabaseSchema.colNextRetryAt] as int?,
      uploadedAtMillis: map[DatabaseSchema.colUploadedAt] as int?,
    );
  }

  final String id;
  final String batchId;
  final String filePath;
  final int fileSizeBytes;
  final int capturedAtMillis;
  final String status;
  final int attemptCount;
  final int updatedAtMillis;
  final String? lastError;
  final int? nextRetryAtMillis;
  final int? uploadedAtMillis;

  DbRow toMap() => {
        DatabaseSchema.colId: id,
        DatabaseSchema.colBatchId: batchId,
        DatabaseSchema.colFilePath: filePath,
        DatabaseSchema.colFileSizeBytes: fileSizeBytes,
        DatabaseSchema.colCapturedAt: capturedAtMillis,
        DatabaseSchema.colStatus: status,
        DatabaseSchema.colAttemptCount: attemptCount,
        DatabaseSchema.colLastError: lastError,
        DatabaseSchema.colNextRetryAt: nextRetryAtMillis,
        DatabaseSchema.colUploadedAt: uploadedAtMillis,
        DatabaseSchema.colUpdatedAt: updatedAtMillis,
      };
}
