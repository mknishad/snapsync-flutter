/// Drains the local queue through the `UploadApi`, applying retry and
/// connectivity rules.
abstract interface class UploadRepository {
  /// Attempts to upload every pending image. Images that fail stay queued.
  Future<void> syncPendingUploads();
}
