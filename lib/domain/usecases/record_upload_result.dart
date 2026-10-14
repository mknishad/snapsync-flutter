import 'package:snapsync/core/constants/app_constants.dart';
import 'package:snapsync/core/error/failure.dart';
import 'package:snapsync/core/utils/clock.dart';
import 'package:snapsync/domain/entities/captured_image.dart';
import 'package:snapsync/domain/entities/upload_result.dart';
import 'package:snapsync/domain/entities/upload_status.dart';
import 'package:snapsync/domain/repositories/batch_repository.dart';
import 'package:snapsync/domain/services/exponential_backoff.dart';

/// Applies the outcome of one upload attempt to the stored image.
///
/// The image must be `uploading`; anything else throws
/// `IllegalStatusTransitionError` (the repository enforces the table).
///
/// - Success: marked uploaded.
/// - Non-retryable failure: failed at once.
/// - Failure that does not consume an attempt (no internet): waiting for
///   connection, attempt count unchanged, no timer. Connectivity wakes it.
/// - Other retryable failure: attempt count increases; failed once it reaches
///   the retry limit, otherwise retrying with an exponential-backoff
///   `nextRetryAt`.
class RecordUploadResult {
  const RecordUploadResult(
    this.repository, {
    required this.backoff,
    required this.now,
    this.maxAttempts = AppConstants.maxUploadRetries,
  });

  final BatchRepository repository;
  final ExponentialBackoff backoff;
  final Clock now;
  final int maxAttempts;

  /// Always reports problems through the returned future, never by throwing
  /// synchronously.
  Future<void> call(CapturedImage image, UploadResult result) async {
    await switch (result) {
      UploadSuccess() => repository.markUploaded(image.id),
      UploadFailed(:final failure) => _recordFailure(image, failure),
    };
  }

  Future<void> _recordFailure(CapturedImage image, Failure failure) {
    if (!failure.isRetryable) {
      return _update(image, UploadStatus.failed, image.attemptCount, failure);
    }
    if (!failure.consumesAttempt) {
      return _update(
        image,
        UploadStatus.waitingForConnection,
        image.attemptCount,
        failure,
      );
    }

    final attempts = image.attemptCount + 1;
    if (attempts >= maxAttempts) {
      return _update(image, UploadStatus.failed, attempts, failure);
    }
    return _update(
      image,
      UploadStatus.retrying,
      attempts,
      failure,
      nextRetryAt: now().add(backoff.delayFor(attempts)),
    );
  }

  Future<void> _update(
    CapturedImage image,
    UploadStatus status,
    int attempts,
    Failure failure, {
    DateTime? nextRetryAt,
  }) {
    return repository.updateImageStatus(
      imageId: image.id,
      status: status,
      attemptCount: attempts,
      lastError: failure.message,
      nextRetryAt: nextRetryAt,
    );
  }
}
