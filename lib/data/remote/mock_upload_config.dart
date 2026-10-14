import 'package:snapsync/core/constants/app_constants.dart';
import 'package:snapsync/core/constants/mock_upload_mode.dart';
import 'package:snapsync/data/local/settings_store.dart';

/// Runtime settings shared by [MockUploadApi] and `MockReachabilityProbe`, so
/// the upload and the connectivity check always agree. Mutable on purpose:
/// change the mode at runtime to exercise the retry path. Held in get_it.
///
/// Each isolate has its own instance. When a [store] is given, the mode is
/// persisted there, so a mode chosen in the UI is also seen by background
/// runs. Without a store (tests), the in-memory [mode] is used.
class MockUploadConfig {
  MockUploadConfig({
    this.store,
    this.mode = AppConstants.mockUploadDefaultMode,
    this.flakySuccessProbability = AppConstants.mockFlakySuccessProbability,
    this.minLatency = AppConstants.mockMinLatency,
    this.maxLatency = AppConstants.mockMaxLatency,
    this.progressSteps = AppConstants.mockProgressSteps,
    this.probeDelay = AppConstants.mockProbeDelay,
    this.fastProbeLatency = AppConstants.mockFastProbeLatency,
    this.slowProbeLatency = AppConstants.mockSlowProbeLatency,
  });

  static const modeKey = 'mock.upload.mode';

  final SettingsStore? store;

  /// In-memory mode, and the default when nothing is stored.
  MockUploadMode mode;

  /// Chance of success in [MockUploadMode.flaky], from 0.0 to 1.0.
  double flakySuccessProbability;

  /// A simulated upload lasts a random time between these two values.
  Duration minLatency;
  Duration maxLatency;

  /// How many progress callbacks one simulated upload emits.
  int progressSteps;

  /// How long a mock reachability probe takes, and the latency it reports for
  /// a healthy and for a slow link.
  Duration probeDelay;
  Duration fastProbeLatency;
  Duration slowProbeLatency;

  /// The mode to use right now: the stored one if there is a store.
  Future<MockUploadMode> currentMode() async {
    final stored = await store?.read(modeKey);
    if (stored == null) return mode;
    return MockUploadMode.values.firstWhere(
      (m) => m.name == stored,
      orElse: () => mode,
    );
  }

  Future<void> setMode(MockUploadMode newMode) async {
    mode = newMode;
    await store?.write(modeKey, newMode.name);
  }
}
