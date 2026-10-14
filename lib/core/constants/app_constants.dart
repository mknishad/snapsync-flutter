import 'package:snapsync/core/constants/mock_upload_mode.dart';

/// Single place for tunable values. Change these rather than hard-coding
/// numbers elsewhere.
abstract final class AppConstants {
  static const String appName = 'SnapSync';

  // Local storage
  static const String databaseName = 'snapsync.db';
  static const int databaseVersion = 2;
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

  // Upload claims
  /// A claim (an image set to `uploading`) that has not been renewed for this
  /// long is assumed to belong to a killed process and is released by
  /// RecoverInterruptedUploads. Must comfortably exceed
  /// [uploadClaimRenewInterval].
  static const Duration uploadClaimTimeout = Duration(minutes: 5);

  /// How often a running upload refreshes its claim.
  static const Duration uploadClaimRenewInterval = Duration(seconds: 30);

  /// Images uploaded at the same time by one engine. 1 is deliberate: on a weak
  /// link, finishing one file at a time beats spreading bandwidth over several
  /// that all stall, progress is easier to read, and failures stay isolated.
  static const int syncConcurrency = 1;

  // Stable-connection check
  // A link is stable when the network interface has been up without a break
  // for [stableDebounce] AND a lightweight reachability probe then succeeds
  // within [probeMaxLatency].
  static const Duration stableDebounce = Duration(seconds: 3);
  static const Duration probeTimeout = Duration(seconds: 5);
  static const Duration probeMaxLatency = Duration(seconds: 2);

  /// While stable, the probe is repeated this often to notice a degrading link.
  static const Duration linkRecheckInterval = Duration(seconds: 15);

  /// While connected but not yet stable, the probe is repeated this often.
  static const Duration unstableRecheckInterval = Duration(seconds: 5);

  // Background work
  /// Android enforces a minimum periodic interval of 15 minutes.
  static const Duration periodicSyncInterval = Duration(minutes: 15);

  // Upload Manager
  /// How often the Upload Manager re-reads the database while visible, to pick
  /// up changes made by the background isolate.
  static const Duration uploadManagerRefreshInterval = Duration(seconds: 3);

  // Mock upload API
  static const MockUploadMode mockUploadDefaultMode =
      MockUploadMode.alwaysSuccess;

  /// Success probability used by [MockUploadMode.flaky].
  static const double mockFlakySuccessProbability = 0.6;
  static const Duration mockMinLatency = Duration(milliseconds: 600);
  static const Duration mockMaxLatency = Duration(milliseconds: 1800);

  /// Number of progress callbacks emitted over one simulated upload.
  static const int mockProgressSteps = 10;

  /// Time the mock reachability probe takes, and the latency it reports.
  static const Duration mockProbeDelay = Duration(milliseconds: 50);
  static const Duration mockFastProbeLatency = Duration(milliseconds: 80);
  static const Duration mockSlowProbeLatency = Duration(seconds: 5);

  // Camera
  /// Opening the camera must finish within this time.
  static const Duration cameraInitTimeout = Duration(seconds: 10);

  /// Pause before the one automatic re-initialisation attempt.
  static const Duration cameraRetryDelay = Duration(milliseconds: 500);

  /// Minimum time between the end of one capture and the start of the next.
  static const Duration cameraMinCaptureGap = Duration(milliseconds: 600);

  /// How long the tap-to-focus indicator stays on screen.
  static const Duration focusIndicatorDuration = Duration(milliseconds: 1500);

  /// A preset button counts as active when the zoom is within this fraction of
  /// its target (0.05 = 5 percent).
  static const double zoomPresetSnapTolerance = 0.05;

  /// The back camera counts as reaching ultra-wide when its minimum zoom is at
  /// or below this value.
  static const double ultraWideMinZoomThreshold = 0.9;

  /// Zoom factor of an ultra-wide camera relative to the main one, assumed
  /// when switching cameras to reach 0.5x.
  static const double ultraWideBaseFactor = 0.5;

  /// Offer 0.5x by switching to a second back camera even though Android does
  /// not say which lens it is (see `UltraWideFinder`). Set to false to offer
  /// 0.5x only where the camera itself zooms below 1.0 or reports an
  /// ultra-wide lens.
  static const bool cameraAllowUnverifiedUltraWideSwitch = true;
}
