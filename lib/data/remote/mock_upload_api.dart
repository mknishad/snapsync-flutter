import 'dart:math';

import 'package:snapsync/core/constants/mock_upload_mode.dart';
import 'package:snapsync/core/error/failure.dart';
import 'package:snapsync/data/remote/mock_upload_config.dart';
import 'package:snapsync/domain/entities/captured_image.dart';
import 'package:snapsync/domain/entities/upload_result.dart';
import 'package:snapsync/domain/repositories/upload_api.dart';

/// Stand-in for the real API, which is not available for this assessment.
///
/// Behaviour is read from [MockUploadConfig] on every call. Each call waits out
/// its simulated duration in sequential awaited delays, so no timer outlives
/// the returned future and nothing needs cancelling; a cancelled caller simply
/// stops listening.
class MockUploadApi implements UploadApi {
  MockUploadApi(this.config, {Random? random}) : _random = random ?? Random();

  final MockUploadConfig config;
  final Random _random;

  @override
  Future<UploadResult> upload(
    CapturedImage image, {
    void Function(double progress)? onProgress,
  }) async {
    final outcome = await _decideOutcome();
    final steps = max(config.progressSteps, 1);
    final stepDelay = _latency() ~/ steps;

    // How far the upload gets: all the way on success, part-way when it fails
    // mid-transfer, nowhere when there is no connection.
    final reachedSteps = switch (outcome) {
      MockUploadMode.alwaysSuccess => steps,
      MockUploadMode.alwaysNoInternet => 0,
      MockUploadMode.alwaysLowBandwidth => max(steps ~/ 3, 1),
      MockUploadMode.alwaysServerError => steps,
      MockUploadMode.flaky => steps,
    };

    if (reachedSteps == 0) await Future<void>.delayed(stepDelay);
    for (var step = 1; step <= reachedSteps; step++) {
      await Future<void>.delayed(stepDelay);
      onProgress?.call(step / steps);
    }

    return switch (outcome) {
      MockUploadMode.alwaysSuccess ||
      MockUploadMode.flaky =>
        UploadSuccess(serverReference: 'mock-ref-${image.id}'),
      MockUploadMode.alwaysNoInternet =>
        const UploadFailed(NoInternetFailure('Mock: no internet connection')),
      MockUploadMode.alwaysLowBandwidth =>
        const UploadFailed(LowBandwidthFailure('Mock: upload timed out')),
      MockUploadMode.alwaysServerError =>
        const UploadFailed(ServerFailure('Mock: server error', code: 500)),
    };
  }

  /// Resolves the configured mode to a concrete outcome. For `flaky` that is
  /// one random draw: success, or one of the failure modes.
  Future<MockUploadMode> _decideOutcome() async {
    final mode = await config.currentMode();
    if (mode != MockUploadMode.flaky) return mode;
    if (_random.nextDouble() < config.flakySuccessProbability) {
      return MockUploadMode.flaky;
    }
    const failures = [
      MockUploadMode.alwaysNoInternet,
      MockUploadMode.alwaysLowBandwidth,
      MockUploadMode.alwaysServerError,
    ];
    return failures[_random.nextInt(failures.length)];
  }

  Duration _latency() {
    final min = config.minLatency.inMicroseconds;
    final max = config.maxLatency.inMicroseconds;
    if (max <= min) return config.minLatency;
    return Duration(microseconds: min + _random.nextInt(max - min + 1));
  }
}
