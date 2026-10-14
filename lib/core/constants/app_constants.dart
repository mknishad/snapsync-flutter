/// Single place for tunable values. Change these rather than hard-coding
/// numbers elsewhere.
abstract final class AppConstants {
  static const String appName = 'SnapSync';

  // Local storage
  static const String databaseName = 'snapsync.db';
  static const int databaseVersion = 1;
  static const String imageDirectoryName = 'captures';

  // Upload retries
  /// Attempts before an image is marked failed (the reference UI shows
  /// "attempt n/3").
  static const int maxUploadRetries = 3;

  /// Delay before the first retry. Later retries grow from this value.
  static const Duration backoffBaseDelay = Duration(seconds: 30);

  /// Multiplier applied to the delay after each failed attempt.
  static const double backoffMultiplier = 2;

  /// Upper bound for the backoff delay.
  static const Duration backoffMaxDelay = Duration(minutes: 10);

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
  /// Initial value of the mock API failure switch. `true` makes every mock
  /// upload fail.
  static const bool mockUploadShouldFailByDefault = false;
  static const Duration mockUploadLatency = Duration(milliseconds: 800);
}
