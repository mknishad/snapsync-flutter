import 'package:snapsync/domain/errors/domain_errors.dart';

/// Where an image is in the upload lifecycle.
///
/// Allowed transitions (anything else throws [IllegalStatusTransitionError]):
///
/// | from                 | to                                                     |
/// |----------------------|--------------------------------------------------------|
/// | queued               | uploading, waitingForConnection                        |
/// | waitingForConnection | uploading, queued                                      |
/// | uploading            | uploaded, retrying, waitingForConnection, failed, queued |
/// | retrying             | uploading, waitingForConnection, queued                |
/// | failed               | queued (explicit user retry)                           |
/// | uploaded             | none (terminal)                                        |
///
/// `uploading -> queued` exists for recovery after a killed process.
/// New images start as `queued`; the batch's `submittedAt` is what makes them
/// eligible for upload.
enum UploadStatus {
  /// Captured and stored locally, not yet attempted.
  queued,

  /// No usable connection; waits for connectivity, not for a timer.
  waitingForConnection,

  /// An upload is in flight.
  uploading,

  /// A previous attempt failed and another is scheduled (`nextRetryAt`).
  retrying,

  /// The server accepted the image.
  uploaded,

  /// Permanently failed: a non-retryable failure, or retries exhausted.
  failed;

  static const Map<UploadStatus, Set<UploadStatus>> _allowed = {
    queued: {uploading, waitingForConnection},
    waitingForConnection: {uploading, queued},
    uploading: {uploaded, retrying, waitingForConnection, failed, queued},
    retrying: {uploading, waitingForConnection, queued},
    failed: {queued},
    uploaded: {},
  };

  bool canTransitionTo(UploadStatus next) => _allowed[this]!.contains(next);

  /// The single place transitions are enforced.
  void ensureCanTransitionTo(UploadStatus next) {
    if (!canTransitionTo(next)) throw IllegalStatusTransitionError(this, next);
  }

  /// Statuses the sync engine may pick up (subject to `nextRetryAt`).
  bool get isUploadable =>
      this == queued || this == waitingForConnection || this == retrying;
}
