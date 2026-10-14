import 'package:snapsync/core/constants/mock_upload_mode.dart';

/// Single place for tunable values. Change these rather than hard-coding
/// numbers elsewhere.
abstract final class AppConstants {
  static const String appName = 'SnapSync';

  // Local storage
  static const String databaseName = 'snapsync.db';
  static const int databaseVersion = 1;
  static const String imageDirectoryName = 'batches';

  // Upload retries
  /// Attempts before an image is marked failed (the reference UI shows
  /// "attempt n/3").
  static const int maxUploadRetries = 3;

  /// Delay before the first retry. Later retries grow from this value.
  static const Duration backoffBaseDelay = Duration(seconds: 30);

  /// Multiplier applied to the delay after each failed attempt.
  static const double backoffMultiplier = 2;

  /// Upper bound for the backoff delay (applied after jitter).
  static const Duration backoffMaxDelay = Duration(minutes: 10);

  /// Random spread applied to each delay: 0.2 means +/-20 percent.
  static const double backoffJitterRatio = 0.2;

  /// An image still marked `uploading` for longer than this is assumed to
  /// belong to a killed process and is put back in the queue. Must exceed the
  /// longest legitimate upload, otherwise a live upload could be requeued.
  static const Duration interruptedUploadTimeout = Duration(minutes: 10);

  // Stable-connection check
  // A connection counts as stable when [stableProbeCount] consecutive probes
  // succeed, [stableProbeInterval] apart, each within [stableProbeTimeout].
  static const int stableProbeCount = 3;
  static const Duration stableProbeInterval = Duration(seconds: 2);
  static const Duration stableProbeTimeout = Duration(seconds: 5);

  // Background work
  /// Android enforces a minimum periodic interval of 15 minutes.
  static const Duration periodicSyncInterval = Duration(minutes: 15);

  // Mock upload API
  static const MockUploadMode mockUploadDefaultMode =
      MockUploadMode.alwaysSuccess;

  /// Success probability used by [MockUploadMode.flaky].
  static const double mockFlakySuccessProbability = 0.6;
  static const Duration mockMinLatency = Duration(milliseconds: 600);
  static const Duration mockMaxLatency = Duration(milliseconds: 1800);

  /// Number of progress callbacks emitted over one simulated upload.
  static const int mockProgressSteps = 10;
}
