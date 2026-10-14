/// Network state as the sync engine needs it.
///
/// A connectivity type alone does not prove the link is usable, so stability
/// is checked separately with a probe.
abstract interface class ConnectivityMonitor {
  /// Emits `true` when any network transport is available.
  Stream<bool> get onConnectivityChanged;

  Future<bool> get isConnected;

  /// True when the stable-connection criteria in `AppConstants` are met.
  Future<bool> hasStableConnection();
}
