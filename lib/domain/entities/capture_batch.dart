import 'package:equatable/equatable.dart';
import 'package:snapsync/domain/entities/captured_image.dart';
import 'package:snapsync/domain/entities/upload_status.dart';

/// A group of images captured together. It is "open" while the user is still
/// capturing and "submitted" once they send it to the upload queue.
class CaptureBatch extends Equatable {
  const CaptureBatch({
    required this.id,
    required this.createdAt,
    this.submittedAt,
    this.images = const [],
  });

  final String id;
  final DateTime createdAt;
  final DateTime? submittedAt;
  final List<CapturedImage> images;

  bool get isSubmitted => submittedAt != null;
  int get totalCount => images.length;
  int get uploadedCount =>
      images.where((i) => i.status == UploadStatus.uploaded).length;
  int get totalBytes => images.fold(0, (sum, i) => sum + i.fileSizeBytes);
  int get uploadedBytes => images
      .where((i) => i.status == UploadStatus.uploaded)
      .fold(0, (sum, i) => sum + i.fileSizeBytes);

  /// One status for the whole batch. Work in progress wins over finished work,
  /// so the first match in this order is returned:
  /// uploading, retrying, waitingForConnection, queued, failed, uploaded.
  /// `failed` is therefore only reported once nothing is still pending. An
  /// empty batch reports `queued`.
  UploadStatus get aggregateStatus {
    if (images.isEmpty) return UploadStatus.queued;
    const precedence = [
      UploadStatus.uploading,
      UploadStatus.retrying,
      UploadStatus.waitingForConnection,
      UploadStatus.queued,
      UploadStatus.failed,
    ];
    for (final status in precedence) {
      if (images.any((i) => i.status == status)) return status;
    }
    return UploadStatus.uploaded;
  }

  @override
  List<Object?> get props => [id, createdAt, submittedAt, images];
}
