import 'package:snapsync/core/error/failure.dart';

/// Turns the camera plugin's errors into typed [CameraFailure]s.
///
/// The plugin has no error enum: on Android, `CameraException.code` is a free
/// string and runtime errors arrive as English descriptions written by the
/// CameraX layer; iOS uses different codes. Matching is therefore by lowercase
/// substring and deliberately tolerant. An unrecognised error is `unknown`,
/// never hidden, and its text stays in [CameraFailure.message] for debug logs
/// only.
abstract final class CameraErrorMapper {
  static CameraFailure fromException(String code, String? description) {
    final text = '$code ${description ?? ''}'.toLowerCase();
    return CameraFailure(
      'Camera error [$code]: ${description ?? 'no description'}',
      reason: _reasonOf(text),
    );
  }

  /// For errors reported while previewing (`CameraValue.errorDescription`).
  static CameraFailure fromRuntimeError(String? description) {
    return fromException('runtime', description);
  }

  static CameraFailureReason _reasonOf(String text) {
    bool has(List<String> parts) => parts.any(text.contains);

    if (has(['accessdenied', 'access denied', 'permission'])) {
      return CameraFailureReason.permission;
    }
    if (has([
      'already in use',
      'in use',
      'cameraincuse',
      'limit number of open',
    ])) {
      return CameraFailureReason.inUse;
    }
    if (has([
      'fatal error',
      'disconnected',
      'device policy',
      'camera was closed',
      'cameradisabled',
      'closed',
    ])) {
      return CameraFailureReason.disconnected;
    }
    if (has(['disposed'])) return CameraFailureReason.disposed;
    if (has(['no camera', 'cameranotfound', 'not found'])) {
      return CameraFailureReason.noCameraAvailable;
    }
    return CameraFailureReason.unknown;
  }
}
