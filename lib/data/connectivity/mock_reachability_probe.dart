import 'dart:math';

import 'package:snapsync/core/constants/mock_upload_mode.dart';
import 'package:snapsync/data/remote/mock_upload_config.dart';
import 'package:snapsync/domain/entities/probe_result.dart';
import 'package:snapsync/domain/repositories/reachability_probe.dart';

/// Reachability probe driven by the same [MockUploadConfig] as the mock API, so
/// the mock modes behave consistently across connectivity and uploads:
///
/// - `alwaysNoInternet`: nothing answers, so the link is unstable and no upload
///   is attempted.
/// - `alwaysSuccess`, `alwaysServerError`, `alwaysLowBandwidth`: the small
///   probe answers quickly. A tiny request can pass on a poor link while a
///   real upload stalls, which is exactly what `alwaysLowBandwidth` shows; a
///   server error is the server's problem, not the link's.
/// - `flaky`: with the configured probability the probe answers quickly,
///   otherwise it is unanswered or slow.
class MockReachabilityProbe implements ReachabilityProbe {
  MockReachabilityProbe(this.config, {Random? random})
    : _random = random ?? Random();

  final MockUploadConfig config;
  final Random _random;

  @override
  Future<ProbeResult> probe() async {
    final mode = await config.currentMode();
    await Future<void>.delayed(config.probeDelay);
    return switch (mode) {
      MockUploadMode.alwaysNoInternet => const ProbeResult.unreachable(),
      MockUploadMode.alwaysSuccess ||
      MockUploadMode.alwaysServerError ||
      MockUploadMode.alwaysLowBandwidth => ProbeResult.reachable(
        config.fastProbeLatency,
      ),
      MockUploadMode.flaky => _flaky(),
    };
  }

  ProbeResult _flaky() {
    if (_random.nextDouble() < config.flakySuccessProbability) {
      return ProbeResult.reachable(config.fastProbeLatency);
    }
    return _random.nextBool()
        ? const ProbeResult.unreachable()
        : ProbeResult.reachable(config.slowProbeLatency);
  }
}
