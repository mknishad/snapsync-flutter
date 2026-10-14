import 'package:snapsync/core/constants/app_constants.dart';
import 'package:snapsync/core/constants/mock_upload_mode.dart';

/// Runtime settings for [MockUploadApi]. Mutable on purpose: change [mode] at
/// runtime to exercise the retry path. Held in get_it.
class MockUploadConfig {
  MockUploadConfig({
    this.mode = AppConstants.mockUploadDefaultMode,
    this.flakySuccessProbability = AppConstants.mockFlakySuccessProbability,
    this.minLatency = AppConstants.mockMinLatency,
    this.maxLatency = AppConstants.mockMaxLatency,
    this.progressSteps = AppConstants.mockProgressSteps,
  });

  MockUploadMode mode;

  /// Chance of success in [MockUploadMode.flaky], from 0.0 to 1.0.
  double flakySuccessProbability;

  /// A simulated upload lasts a random time between these two values.
  Duration minLatency;
  Duration maxLatency;

  /// How many progress callbacks one simulated upload emits.
  int progressSteps;
}
