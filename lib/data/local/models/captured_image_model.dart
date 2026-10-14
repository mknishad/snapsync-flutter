import 'package:snapsync/core/utils/typedefs.dart';

/// Database row shape for a captured image. Status is stored by name.
class CapturedImageModel {
  const CapturedImageModel({
    required this.id,
    required this.batchId,
    required this.filePath,
    required this.createdAtMillis,
    required this.sizeBytes,
    required this.status,
    required this.retryCount,
    this.lastError,
  });

  factory CapturedImageModel.fromMap(DbRow map) {
    // TODO: read columns from DatabaseSchema.
    throw UnimplementedError('TODO: CapturedImageModel.fromMap');
  }

  final String id;
  final String batchId;
  final String filePath;
  final int createdAtMillis;
  final int sizeBytes;
  final String status;
  final int retryCount;
  final String? lastError;

  DbRow toMap() {
    // TODO: write columns from DatabaseSchema.
    throw UnimplementedError('TODO: CapturedImageModel.toMap');
  }
}
