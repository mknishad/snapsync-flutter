import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:snapsync/domain/entities/captured_image.dart';
import 'package:snapsync/domain/entities/upload_status.dart';

/// One row of the Pending Uploads list, ready for display.
class UploadItemViewModel extends Equatable {
  const UploadItemViewModel({
    required this.id,
    required this.batchId,
    required this.displayName,
    required this.sizeBytes,
    required this.status,
    required this.progress,
    this.thumbnailPath,
    this.attemptText,
    this.lastError,
  });

  factory UploadItemViewModel.fromImage(
    CapturedImage image, {
    required int maxAttempts,
    double? liveProgress,
  }) {
    final stamp = DateFormat('yyyyMMdd_HHmmss')
        .format(image.capturedAt.toLocal());
    final progress = switch (image.status) {
      UploadStatus.uploaded => 1.0,
      UploadStatus.uploading => liveProgress ?? 0.0,
      _ => 0.0,
    };
    return UploadItemViewModel(
      id: image.id,
      batchId: image.batchId,
      displayName: 'IMG_$stamp${p.extension(image.filePath)}',
      sizeBytes: image.fileSizeBytes,
      status: image.status,
      progress: progress,
      // The file is deleted after a successful upload.
      thumbnailPath: image.status == UploadStatus.uploaded
          ? null
          : image.filePath,
      attemptText: image.status == UploadStatus.retrying
          ? 'Retrying... (attempt ${_nextAttempt(image, maxAttempts)}/$maxAttempts)'
          : null,
      lastError: image.lastError,
    );
  }

  /// The attempt that will run next: failed attempts so far, plus one.
  static int _nextAttempt(CapturedImage image, int maxAttempts) {
    final next = image.attemptCount + 1;
    return next > maxAttempts ? maxAttempts : next;
  }

  final String id;
  final String batchId;
  final String displayName;
  final int sizeBytes;
  final UploadStatus status;

  /// 0.0 to 1.0.
  final double progress;
  final String? thumbnailPath;

  /// For example "Retrying... (attempt 2/3)"; null unless retrying.
  final String? attemptText;
  final String? lastError;

  @override
  List<Object?> get props => [
    id,
    batchId,
    displayName,
    sizeBytes,
    status,
    progress,
    thumbnailPath,
    attemptText,
    lastError,
  ];
}
