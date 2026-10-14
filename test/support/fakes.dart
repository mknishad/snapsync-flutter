import 'dart:async';

import 'package:snapsync/domain/entities/captured_image.dart';
import 'package:snapsync/domain/entities/link_quality.dart';
import 'package:snapsync/domain/entities/probe_result.dart';
import 'package:snapsync/domain/entities/upload_result.dart';
import 'package:snapsync/domain/repositories/connectivity_monitor.dart';
import 'package:snapsync/domain/repositories/reachability_probe.dart';
import 'package:snapsync/domain/repositories/sync_scheduler.dart';
import 'package:snapsync/domain/repositories/upload_api.dart';

/// A [ConnectivityMonitor] the test controls. `checkNow` answers from
/// [script] first (one value per call), then from [quality].
class FakeConnectivityMonitor implements ConnectivityMonitor {
  FakeConnectivityMonitor([this.quality = LinkQuality.stable]);

  LinkQuality quality;
  final List<LinkQuality> script = [];
  int checkNowCount = 0;
  final List<MultiStreamController<LinkQuality>> _listeners = [];

  bool get hasListeners => _listeners.isNotEmpty;

  /// Changes the link and tells every listener.
  void emit(LinkQuality next) {
    quality = next;
    for (final listener in List.of(_listeners)) {
      listener.add(next);
    }
  }

  @override
  Stream<LinkQuality> get onLinkQualityChanged {
    return Stream<LinkQuality>.multi((controller) {
      _listeners.add(controller);
      controller.add(quality);
      controller.onCancel = () => _listeners.remove(controller);
    });
  }

  @override
  Future<LinkQuality> checkNow() async {
    checkNowCount++;
    return script.isNotEmpty ? script.removeAt(0) : quality;
  }
}

/// An [UploadApi] that records every call and answers from [handler].
class ScriptedUploadApi implements UploadApi {
  ScriptedUploadApi({this.handler});

  /// Decides the result for an image. Defaults to success.
  UploadResult Function(CapturedImage image)? handler;

  /// Runs while the upload is "in flight", before it returns. Use it to hold
  /// an upload open with a Completer or to change state mid-upload.
  Future<void> Function(CapturedImage image)? whileUploading;

  /// Progress values reported before the result.
  List<double> progressSteps = const [0.5, 1];

  /// Runs just before each progress value is reported.
  void Function(double step)? onEachStep;

  final List<String> calls = [];
  int inFlight = 0;
  int maxInFlight = 0;

  @override
  Future<UploadResult> upload(
    CapturedImage image, {
    void Function(double progress)? onProgress,
  }) async {
    calls.add(image.id);
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    try {
      for (final step in progressSteps) {
        onEachStep?.call(step);
        onProgress?.call(step);
      }
      await whileUploading?.call(image);
      await Future<void>.delayed(Duration.zero);
      return handler?.call(image) ??
          UploadSuccess(serverReference: 'ref-${image.id}');
    } finally {
      inFlight--;
    }
  }
}

/// Reachability probe whose answers the test scripts.
class FakeReachabilityProbe implements ReachabilityProbe {
  /// Answers handed out in order; when empty, [defaultResult] is used.
  final List<Future<ProbeResult> Function()> script = [];
  ProbeResult defaultResult = const ProbeResult.reachable(
    Duration(milliseconds: 50),
  );
  int probeCount = 0;

  @override
  Future<ProbeResult> probe() {
    probeCount++;
    if (script.isNotEmpty) return script.removeAt(0)();
    return Future.value(defaultResult);
  }
}

class FakeSyncScheduler implements SyncScheduler {
  int periodicRegistrations = 0;
  int enqueueCount = 0;
  int debugRuns = 0;
  Object? enqueueError;

  @override
  Future<void> registerPeriodicSync() async => periodicRegistrations++;

  @override
  Future<void> enqueueSyncNow() async {
    enqueueCount++;
    if (enqueueError != null) throw enqueueError!;
  }

  @override
  Future<void> debugRunNow() async => debugRuns++;
}

/// A timer that only fires when the test says so.
class FakeTimer implements Timer {
  FakeTimer(this.duration, this._callback);

  final Duration duration;
  final void Function() _callback;
  bool _active = true;
  bool fired = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => fired ? 1 : 0;

  @override
  void cancel() => _active = false;

  /// Runs the callback if the timer was not cancelled.
  void fire() {
    if (!_active) return;
    _active = false;
    fired = true;
    _callback();
  }
}

class FakeTimerFactory {
  final List<FakeTimer> timers = [];

  Timer create(Duration duration, void Function() run) {
    final timer = FakeTimer(duration, run);
    timers.add(timer);
    return timer;
  }

  Iterable<FakeTimer> get active => timers.where((t) => t.isActive);
  FakeTimer get last => timers.last;
}
