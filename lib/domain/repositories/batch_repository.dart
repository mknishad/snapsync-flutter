import 'package:snapsync/domain/entities/capture_batch.dart';
import 'package:snapsync/domain/entities/captured_image.dart';
import 'package:snapsync/domain/entities/upload_status.dart';

/// Local persistence of batches and their images.
///
/// Methods throw a `Failure` for expected problems (database, storage) and an
/// `IllegalStatusTransitionError` / `IllegalBatchStateError` for operations the
/// domain rules forbid.
abstract interface class BatchRepository {
  /// The batch currently being captured into, created if none exists.
  Future<CaptureBatch> getOrCreateOpenBatch();

  /// Copies [capturedFilePath] into app storage and records it in [batchId].
  /// The batch must be open.
  Future<CapturedImage> addImage(String batchId, String capturedFilePath);

  /// Removes an image and its file. Not allowed while it is uploading.
  Future<void> removeImage(String imageId);

  /// Closes the batch for capture and queues every image in it. Submitting an
  /// already submitted batch does nothing; an empty batch is rejected.
  Future<void> submitBatch(String batchId);

  /// The open batch, or null when there is none. Emits on every change.
  Stream<CaptureBatch?> watchOpenBatch();

  /// Submitted batches, newest first. Emits on every change.
  Stream<List<CaptureBatch>> watchSubmittedBatches();

  Future<CapturedImage?> getImage(String imageId);

  /// Images in submitted batches that are queued, waiting for a connection or
  /// retrying, and not waiting for a future `nextRetryAt`. Oldest first.
  Future<List<CapturedImage>> getUploadable(DateTime now);

  /// Applies a status change, enforcing the transition table. The three
  /// retry fields are written exactly as given, so a null [lastError] or
  /// [nextRetryAt] clears the stored value. Use [markUploaded] for `uploaded`.
  Future<void> updateImageStatus({
    required String imageId,
    required UploadStatus status,
    required int attemptCount,
    String? lastError,
    DateTime? nextRetryAt,
  });

  /// Images of submitted batches that are not finished (queued, waiting,
  /// uploading or retrying), oldest first.
  Future<List<CapturedImage>> getUnfinished();

  /// Atomically takes the image for upload by moving it to `uploading`.
  /// Returns the claimed image, or null if it is no longer uploadable, not yet
  /// due, or another isolate claimed it first. This is what guarantees an
  /// image is never uploaded twice.
  Future<CapturedImage?> claimImage(String imageId);

  /// Keeps a claim alive while its upload is still running.
  Future<void> renewClaim(String imageId);

  /// Marks queued and retrying images as waiting for a connection, so the
  /// queue shows why nothing is moving. Returns how many were changed.
  Future<int> markWaitingForConnection();

  /// Marks the image uploaded, deletes its local file and keeps its row as
  /// synced history.
  Future<void> markUploaded(String imageId);

  /// Deletes a batch, its rows and its files. Not allowed while any of its
  /// images is uploading.
  Future<void> deleteBatch(String batchId);

  /// Puts images that have been `uploading` for longer than [staleAfter] back
  /// in the queue (their process was killed). Returns how many were reset.
  Future<int> resetInterruptedUploads({Duration staleAfter = Duration.zero});

  /// Re-reads the database and re-emits on the watch streams. Writes made by
  /// the background isolate do not notify this isolate, so call this on app
  /// resume and on a timer.
  void refresh();
}
