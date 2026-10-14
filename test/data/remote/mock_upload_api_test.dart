import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:snapsync/core/constants/mock_upload_mode.dart';
import 'package:snapsync/core/error/failure.dart';
import 'package:snapsync/data/remote/mock_upload_api.dart';
import 'package:snapsync/data/remote/mock_upload_config.dart';
import 'package:snapsync/domain/entities/captured_image.dart';
import 'package:snapsync/domain/entities/upload_result.dart';

final image = CapturedImage(
  id: 'img-1',
  batchId: 'b',
  filePath: '/fake/img-1.jpg',
  fileSizeBytes: 10,
  capturedAt: DateTime.utc(2026),
);

MockUploadConfig config(MockUploadMode mode, {double probability = 0.5}) {
  return MockUploadConfig(
    mode: mode,
    flakySuccessProbability: probability,
    minLatency: Duration.zero,
    maxLatency: Duration.zero,
    progressSteps: 5,
  );
}

void main() {
  Future<(UploadResult, List<double>)> run(MockUploadApi api) async {
    final progress = <double>[];
    final result = await api.upload(image, onProgress: progress.add);
    return (result, progress);
  }

  test('alwaysSuccess succeeds, with monotonic progress ending at 1.0',
      () async {
    final (result, progress) =
        await run(MockUploadApi(config(MockUploadMode.alwaysSuccess)));

    expect(result, const UploadSuccess(serverReference: 'mock-ref-img-1'));
    expect(progress, [0.2, 0.4, 0.6, 0.8, 1.0]);
    for (var i = 1; i < progress.length; i++) {
      expect(progress[i], greaterThan(progress[i - 1]));
    }
  });

  test('alwaysNoInternet fails with NoInternetFailure and no progress',
      () async {
    final (result, progress) =
        await run(MockUploadApi(config(MockUploadMode.alwaysNoInternet)));

    expect(result, isA<UploadFailed>());
    expect((result as UploadFailed).failure, isA<NoInternetFailure>());
    expect(progress, isEmpty);
  });

  test('alwaysLowBandwidth stalls part-way and fails with LowBandwidthFailure',
      () async {
    final (result, progress) =
        await run(MockUploadApi(config(MockUploadMode.alwaysLowBandwidth)));

    expect((result as UploadFailed).failure, isA<LowBandwidthFailure>());
    expect(progress, isNotEmpty);
    expect(progress.last, lessThan(1));
  });

  test('alwaysServerError fails with a retryable 500', () async {
    final (result, _) =
        await run(MockUploadApi(config(MockUploadMode.alwaysServerError)));

    final failure = (result as UploadFailed).failure;
    expect(failure, isA<ServerFailure>());
    expect((failure as ServerFailure).code, 500);
    expect(failure.isRetryable, isTrue);
  });

  test('the mode can be switched at runtime', () async {
    final cfg = config(MockUploadMode.alwaysNoInternet);
    final api = MockUploadApi(cfg);

    expect((await api.upload(image)), isA<UploadFailed>());
    cfg.mode = MockUploadMode.alwaysSuccess;
    expect((await api.upload(image)), isA<UploadSuccess>());
  });

  group('flaky', () {
    Future<List<UploadResult>> sequence(int seed, {double probability = 0.5}) async {
      final api = MockUploadApi(
        config(MockUploadMode.flaky, probability: probability),
        random: Random(seed),
      );
      return [for (var i = 0; i < 30; i++) await api.upload(image)];
    }

    test('the same seed gives the same sequence', () async {
      expect(await sequence(42), await sequence(42));
    });

    test('different seeds differ', () async {
      expect(await sequence(1), isNot(await sequence(2)));
    });

    test('mixes successes and failures at 50 percent', () async {
      final results = await sequence(42);
      expect(results.whereType<UploadSuccess>(), isNotEmpty);
      expect(results.whereType<UploadFailed>(), isNotEmpty);
    });

    test('probability 1.0 always succeeds and 0.0 always fails', () async {
      expect((await sequence(3, probability: 1)).every((r) => r is UploadSuccess), isTrue);
      expect((await sequence(3, probability: 0)).every((r) => r is UploadFailed), isTrue);
    });
  });

  test('simulated latency is waited out, not skipped', () async {
    final api = MockUploadApi(
      MockUploadConfig(
        mode: MockUploadMode.alwaysSuccess,
        minLatency: const Duration(milliseconds: 100),
        maxLatency: const Duration(milliseconds: 100),
        progressSteps: 4,
      ),
    );
    final watch = Stopwatch()..start();
    await api.upload(image);
    expect(watch.elapsedMilliseconds, greaterThanOrEqualTo(90));
  });
}
