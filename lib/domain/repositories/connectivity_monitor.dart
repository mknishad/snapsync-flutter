import 'package:snapsync/domain/entities/link_quality.dart';

/// Network state as the sync engine and the UI need it.
///
/// connectivity_plus only reports which interfaces are up, not whether the
/// internet works, so "stable" means: the interface has been up without a break
/// for `AppConstants.stableDebounce` and a reachability probe then succeeds
/// within `AppConstants.probeMaxLatency`.
abstract interface class ConnectivityMonitor {
  /// Link quality over time. Monitoring starts with the first listener and
  /// stops with the last. Each new listener receives the current value as soon
  /// as it is known, then every change. `offline` is emitted immediately; a
  /// link that has just come up is `unstable` until it is verified.
  Stream<LinkQuality> get onLinkQualityChanged;

  /// Evaluates the link once, right now, without the debounce: `offline` if no
  /// interface is up, otherwise `stable` or `unstable` according to one probe.
  Future<LinkQuality> checkNow();
}
