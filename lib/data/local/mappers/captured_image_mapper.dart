import 'package:snapsync/core/error/failure.dart';
import 'package:snapsync/data/local/models/captured_image_model.dart';
import 'package:snapsync/domain/entities/captured_image.dart';
import 'package:snapsync/domain/entities/upload_status.dart';

DateTime _fromMillis(int millis) =>
    DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);

extension CapturedImageModelMapper on CapturedImageModel {
  /// Throws [DatabaseFailure] for an unknown stored status instead of
  /// guessing, because a wrong status could re-upload or lose an image.
  CapturedImage toEntity() {
    return CapturedImage(
      id: id,
      batchId: batchId,
      filePath: filePath,
      fileSizeBytes: fileSizeBytes,
      capturedAt: _fromMillis(capturedAtMillis),
      status: _parseStatus(status),
      attemptCount: attemptCount,
      lastError: lastError,
      nextRetryAt:
          nextRetryAtMillis == null ? null : _fromMillis(nextRetryAtMillis!),
      uploadedAt:
          uploadedAtMillis == null ? null : _fromMillis(uploadedAtMillis!),
    );
  }

  static UploadStatus _parseStatus(String stored) {
    for (final status in UploadStatus.values) {
      if (status.name == stored) return status;
    }
    throw DatabaseFailure('Unknown stored upload status "$stored"');
  }
}

extension CapturedImageMapper on CapturedImage {
  /// [updatedAt] is persistence bookkeeping supplied by the repository.
  CapturedImageModel toModel({required DateTime updatedAt}) {
    return CapturedImageModel(
      id: id,
      batchId: batchId,
      filePath: filePath,
      fileSizeBytes: fileSizeBytes,
      capturedAtMillis: capturedAt.millisecondsSinceEpoch,
      status: status.name,
      attemptCount: attemptCount,
      updatedAtMillis: updatedAt.millisecondsSinceEpoch,
      lastError: lastError,
      nextRetryAtMillis: nextRetryAt?.millisecondsSinceEpoch,
      uploadedAtMillis: uploadedAt?.millisecondsSinceEpoch,
    );
  }
}
