/// Settings shared by the UI isolate and the background isolate.
abstract interface class SyncSettingsRepository {
  /// Whether the user paused uploading. While true, sync passes do nothing.
  Future<bool> isPaused();

  Future<void> setPaused({required bool paused});
}
