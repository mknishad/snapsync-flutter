import 'package:permission_handler/permission_handler.dart';
import 'package:snapsync/domain/camera/camera_permission_service.dart';

/// [CameraPermissionService] on permission_handler (13.x; android 14.x).
///
/// API used: `Permission.camera.status`, `Permission.camera.request()` and
/// `openAppSettings()`. On Android 14.x of the plugin, `status` never reports
/// `permanentlyDenied`; only the result of `request()` can.
class PermissionHandlerCameraPermissions implements CameraPermissionService {
  const PermissionHandlerCameraPermissions();

  @override
  Future<CameraPermissionStatus> status() async {
    return _map(await Permission.camera.status);
  }

  @override
  Future<CameraPermissionStatus> request() async {
    return _map(await Permission.camera.request());
  }

  @override
  Future<bool> openSettings() => openAppSettings();

  static CameraPermissionStatus _map(PermissionStatus status) {
    return switch (status) {
      PermissionStatus.granted ||
      PermissionStatus.limited ||
      PermissionStatus.provisional => CameraPermissionStatus.granted,
      PermissionStatus.denied => CameraPermissionStatus.denied,
      PermissionStatus.permanentlyDenied =>
        CameraPermissionStatus.permanentlyDenied,
      PermissionStatus.restricted => CameraPermissionStatus.restricted,
    };
  }
}
