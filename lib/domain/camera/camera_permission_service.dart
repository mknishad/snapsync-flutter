enum CameraPermissionStatus {
  granted,

  /// Not granted; asking may show the system dialog.
  denied,

  /// The system will not show its dialog again; only app settings can change it.
  permanentlyDenied,

  /// A device policy forbids it (for example parental controls on iOS).
  restricted,
}

/// The camera permission. Only the camera: no microphone, because audio is off.
abstract interface class CameraPermissionService {
  /// Current state, without prompting. On Android this reports `denied` for a
  /// permission that was never asked, denied once, or denied for good; only
  /// [request] can tell `permanentlyDenied`.
  Future<CameraPermissionStatus> status();

  /// Shows the system dialog if the system allows it.
  Future<CameraPermissionStatus> request();

  /// Opens this app's page in system settings. Returns false if it could not.
  Future<bool> openSettings();
}
