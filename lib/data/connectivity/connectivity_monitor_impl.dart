import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:snapsync/core/constants/app_constants.dart';
import 'package:snapsync/core/utils/timer_factory.dart';
import 'package:snapsync/domain/entities/link_quality.dart';
import 'package:snapsync/domain/repositories/connectivity_monitor.dart';
import 'package:snapsync/domain/repositories/reachability_probe.dart';

/// [ConnectivityMonitor] built on connectivity_plus and a [ReachabilityProbe].
///
/// connectivity_plus (7.x) reports a list of active results and says an empty
/// network is the single value `none`. Only the interface state is known from
/// it, so a link counts as stable only after it has stayed up for
/// [stableDebounce] and a probe then answers within [probeMaxLatency].
///
/// Flapping: every connectivity event starts a new verification. Going offline
/// is emitted at once and cancels any pending or in-flight check, so a stale
/// probe result can never promote a link that has since dropped.
///
/// Works in either isolate: it holds no global state and only needs the
/// plugin and the probe. Each isolate builds its own instance.
class ConnectivityMonitorImpl implements ConnectivityMonitor {
  ConnectivityMonitorImpl({
    required this.connectivity,
    required this.probe,
    this.stableDebounce = AppConstants.stableDebounce,
    this.probeTimeout = AppConstants.probeTimeout,
    this.probeMaxLatency = AppConstants.probeMaxLatency,
    this.linkRecheckInterval = AppConstants.linkRecheckInterval,
    this.unstableRecheckInterval = AppConstants.unstableRecheckInterval,
    TimerFactory? timerFactory,
  }) : _timer = timerFactory ?? realTimer;

  final Connectivity connectivity;
  final ReachabilityProbe probe;
  final Duration stableDebounce;
  final Duration probeTimeout;
  final Duration probeMaxLatency;
  final Duration linkRecheckInterval;
  final Duration unstableRecheckInterval;
  final TimerFactory _timer;

  final List<MultiStreamController<LinkQuality>> _listeners = [];
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _pending;
  LinkQuality? _current;

  /// Bumped whenever the link changes or monitoring stops. A check that
  /// finishes under an older generation is discarded.
  int _generation = 0;

  @override
  Stream<LinkQuality> get onLinkQualityChanged {
    return Stream<LinkQuality>.multi((controller) {
      _listeners.add(controller);
      if (_listeners.length == 1) {
        _start();
      } else if (_current != null) {
        controller.add(_current!);
      }
      controller.onCancel = () {
        _listeners.remove(controller);
        if (_listeners.isEmpty) _stop();
      };
    });
  }

  @override
  Future<LinkQuality> checkNow() async {
    final results = await connectivity.checkConnectivity();
    if (!_hasNetwork(results)) return LinkQuality.offline;
    return await _probeQuality();
  }

  // ---- monitoring --------------------------------------------------------

  void _start() {
    final generation = ++_generation;
    _subscription = connectivity.onConnectivityChanged.listen(_onResults);
    unawaited(
      connectivity.checkConnectivity().then((results) {
        // Ignore the initial read if an event already arrived or we stopped.
        if (generation == _generation) _onResults(results);
      }),
    );
  }

  void _stop() {
    _generation++;
    _pending?.cancel();
    _pending = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _current = null;
  }

  void _onResults(List<ConnectivityResult> results) {
    _pending?.cancel();
    final generation = ++_generation;

    if (!_hasNetwork(results)) {
      _emit(LinkQuality.offline);
      return;
    }

    // Interface is up (or changed, e.g. wifi to mobile): not trusted until it
    // has stayed up for the debounce period and a probe passes.
    _emit(LinkQuality.unstable);
    _pending = _timer(stableDebounce, () => unawaited(_verify(generation)));
  }

  Future<void> _verify(int generation) async {
    final quality = await _probeQuality();
    if (generation != _generation) return; // the link changed meanwhile

    _emit(quality);
    final next = quality == LinkQuality.stable
        ? linkRecheckInterval
        : unstableRecheckInterval;
    _pending = _timer(next, () => unawaited(_verify(generation)));
  }

  Future<LinkQuality> _probeQuality() async {
    try {
      final result = await probe.probe().timeout(probeTimeout);
      return result.isFast(probeMaxLatency)
          ? LinkQuality.stable
          : LinkQuality.unstable;
    } on TimeoutException {
      return LinkQuality.unstable;
    }
  }

  void _emit(LinkQuality quality) {
    if (quality == _current) return;
    _current = quality;
    for (final listener in List.of(_listeners)) {
      listener.add(quality);
    }
  }

  /// `none` is the only value present when there is no connection. Bluetooth
  /// alone cannot carry uploads.
  static bool _hasNetwork(List<ConnectivityResult> results) {
    return results.any(
      (r) => r != ConnectivityResult.none && r != ConnectivityResult.bluetooth,
    );
  }
}
