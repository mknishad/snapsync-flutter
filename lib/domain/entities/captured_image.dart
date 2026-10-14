import 'package:equatable/equatable.dart';
import 'package:snapsync/domain/entities/upload_status.dart';

class CapturedImage extends Equatable {
  const CapturedImage({
    required this.id,
    required this.batchId,
    required this.filePath,
    required this.fileSizeBytes,
    required this.capturedAt,
    this.status = UploadStatus.queued,
    this.attemptCount = 0,
    this.lastError,
    this.nextRetryAt,
    this.uploadedAt,
  });

  final String id;
  final String batchId;

  /// Local file. Deleted once the image is uploaded; the row is kept.
  final String filePath;
  final int fileSizeBytes;
  final DateTime capturedAt;
  final UploadStatus status;

  /// Failed attempts that count towards the retry limit.
  final int attemptCount;
  final String? lastError;

  /// When a retrying image becomes due. Null means "as soon as possible".
  final DateTime? nextRetryAt;
  final DateTime? uploadedAt;

  /// Null arguments keep the current value. Use the `clear` flags to set a
  /// field back to null.
  CapturedImage copyWith({
    UploadStatus? status,
    int? attemptCount,
    String? lastError,
    bool clearLastError = false,
    DateTime? nextRetryAt,
    bool clearNextRetryAt = false,
    DateTime? uploadedAt,
  }) {
    return CapturedImage(
      id: id,
      batchId: batchId,
      filePath: filePath,
      fileSizeBytes: fileSizeBytes,
      capturedAt: capturedAt,
      status: status ?? this.status,
      attemptCount: attemptCount ?? this.attemptCount,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      nextRetryAt: clearNextRetryAt ? null : (nextRetryAt ?? this.nextRetryAt),
      uploadedAt: uploadedAt ?? this.uploadedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    batchId,
    filePath,
    fileSizeBytes,
    capturedAt,
    status,
    attemptCount,
    lastError,
    nextRetryAt,
    uploadedAt,
  ];
}
