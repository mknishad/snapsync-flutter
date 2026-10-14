/// Schedules background sync work with the operating system. The rest of the
/// app depends on this interface, not on the Workmanager plugin.
abstract interface class SyncScheduler {
  /// Registers the periodic safety-net sync. Call once at startup.
  Future<void> registerPeriodicSync();

  /// Asks for a background sync as soon as the network is available.
  Future<void> enqueueSyncNow();

  /// Debug builds only: runs a background sync immediately, ignoring the
  /// network constraint. Does nothing in release builds.
  Future<void> debugRunNow();
}
