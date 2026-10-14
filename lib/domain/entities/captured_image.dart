import 'package:equatable/equatable.dart';
import 'package:snapsync/domain/entities/upload_status.dart';

class CapturedImage extends Equatable {
  const CapturedImage({
    required this.id,
    required this.batchId,
    required this.filePath,
    required this.createdAt,
    this.sizeBytes = 0,
    this.status = UploadStatus.queued,
    this.retryCount = 0,
    this.lastError,
  });

  final String id;
  final String batchId;
  final String filePath;
  final DateTime createdAt;
  final int sizeBytes;
  final UploadStatus status;
  final int retryCount;
  final String? lastError;

  CapturedImage copyWith({
    UploadStatus? status,
    int? retryCount,
    String? lastError,
  }) {
    return CapturedImage(
      id: id,
      batchId: batchId,
      filePath: filePath,
      createdAt: createdAt,
      sizeBytes: sizeBytes,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  List<Object?> get props => [
        id,
        batchId,
        filePath,
        createdAt,
        sizeBytes,
        status,
        retryCount,
        lastError,
      ];
}
