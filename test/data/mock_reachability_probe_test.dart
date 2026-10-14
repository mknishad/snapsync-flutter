import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:snapsync/core/constants/mock_upload_mode.dart';
import 'package:snapsync/data/connectivity/mock_reachability_probe.dart';
import 'package:snapsync/data/local/daos/settings_dao.dart';
import 'package:snapsync/data/local/settings_store.dart';
import 'package:snapsync/data/remote/mock_upload_api.dart';
import 'package:snapsync/data/remote/mock_upload_config.dart';
import 'package:snapsync/domain/entities/captured_image.dart';
import 'package:snapsync/domain/entities/upload_result.dart';
import 'package:snapsync/core/error/failure.dart';

import '../support/test_support.dart';

MockUploadConfig config(MockUploadMode mode, {double probability = 0.5}) {
  return MockUploadConfig(
    mode: mode,
    flakySuccessProbability: probability,
    minLatency: Duration.zero,
    maxLatency: Duration.zero,
    probeDelay: Duration.zero,
    progressSteps: 2,
  );
}

final image = CapturedImage(
  id: 'img-1',
  batchId: 'b',
  filePath: '/fake/img-1.jpg',
  fileSizeBytes: 10,
  capturedAt: DateTime.utc(2026),
);

void main() {
  const maxLatency = Duration(seconds: 2);

  group('MockReachabilityProbe', () {
    test(
      'success, server-error and low-bandwidth modes answer quickly',
      () async {
        for (final mode in [
          MockUploadMode.alwaysSuccess,
          MockUploadMode.alwaysServerError,
          MockUploadMode.alwaysLowBandwidth,
        ]) {
          final result = await MockReachabilityProbe(config(mode)).probe();
          expect(result.isFast(maxLatency), isTrue, reason: mode.name);
        }
      },
    );

    test('no internet leaves the probe unanswered', () async {
      final result = await MockReachabilityProbe(
        config(MockUploadMode.alwaysNoInternet),
      ).probe();

      expect(result.reachable, isFalse);
    });

    test('flaky is reproducible with a seed and mixes outcomes', () async {
      Future<List<bool>> run(int seed) async {
        final probe = MockReachabilityProbe(
          config(MockUploadMode.flaky),
          random: Random(seed),
        );
        return [
          for (var i = 0; i < 30; i++) (await probe.probe()).isFast(maxLatency),
        ];
      }

      expect(await run(9), await run(9));
      final outcomes = await run(9);
      expect(outcomes, contains(true));
      expect(outcomes, contains(false));
    });

    test('flaky probability 1 is always fast and 0 never is', () async {
      final always = MockReachabilityProbe(
        config(MockUploadMode.flaky, probability: 1),
        random: Random(1),
      );
      final never = MockReachabilityProbe(
        config(MockUploadMode.flaky, probability: 0),
        random: Random(1),
      );

      for (var i = 0; i < 10; i++) {
        expect((await always.probe()).isFast(maxLatency), isTrue);
        expect((await never.probe()).isFast(maxLatency), isFalse);
      }
    });

    test('follows a mode change made at runtime', () async {
      final cfg = config(MockUploadMode.alwaysSuccess);
      final probe = MockReachabilityProbe(cfg);
      expect((await probe.probe()).reachable, isTrue);

      cfg.mode = MockUploadMode.alwaysNoInternet;

      expect((await probe.probe()).reachable, isFalse);
    });

    test(
      'agrees with the mock upload API for the same configuration',
      () async {
        final cfg = config(MockUploadMode.alwaysNoInternet);
        final probe = MockReachabilityProbe(cfg);
        final api = MockUploadApi(cfg);

        final probeResult = await probe.probe();
        final upload = await api.upload(image);

        expect(probeResult.reachable, isFalse);
        expect((upload as UploadFailed).failure, isA<NoInternetFailure>());

        cfg.mode = MockUploadMode.alwaysSuccess;
        expect((await probe.probe()).isFast(maxLatency), isTrue);
        expect(await api.upload(image), isA<UploadSuccess>());
      },
    );
  });

  group('MockUploadConfig persistence', () {
    late Directory directory;
    late String path;

    setUp(() {
      directory = createTempDir('snapsync_mock_cfg_');
      path = p.join(directory.path, 'shared.db');
    });

    tearDown(() => directory.deleteSync(recursive: true));

    MockUploadConfig configOn(String dbPath) {
      final helper = createTestDatabaseHelper(path: dbPath);
      return MockUploadConfig(
        store: SettingsStore(helper, const SettingsDao()),
      );
    }

    test('defaults to the constant when nothing is stored', () async {
      expect(await configOn(path).currentMode(), MockUploadMode.alwaysSuccess);
    });

    test('a mode set on one connection is seen by another', () async {
      final ui = configOn(path);
      final background = configOn(path);

      await ui.setMode(MockUploadMode.alwaysLowBandwidth);

      expect(await background.currentMode(), MockUploadMode.alwaysLowBandwidth);
    });

    test('an unknown stored value falls back to the in-memory mode', () async {
      final cfg = configOn(path);
      await cfg.store!.write(MockUploadConfig.modeKey, 'not-a-mode');

      expect(await cfg.currentMode(), MockUploadMode.alwaysSuccess);
    });
  });
}
