import 'package:snapsync/core/constants/app_constants.dart';
import 'package:snapsync/domain/camera/camera_lens.dart';
import 'package:snapsync/domain/camera/ultra_wide_finder.dart';
import 'package:snapsync/domain/camera/zoom_preset.dart';

/// Builds the zoom buttons from what the device can really do.
///
/// - 1x is always offered.
/// - 0.5x only when it is achievable: the camera zooms below 1.0 by itself, or
///   a separate ultra-wide back camera exists (see [UltraWideFinder]). Never a
///   button that does nothing.
/// - 2x when the maximum zoom reaches 2.0, optical or digital.
abstract final class ZoomPresetsBuilder {
  /// [minZoom] and [maxZoom] are the plugin's own values for the main camera
  /// (zoom ratios, where 1.0 is no zoom). [backCameras] is every back camera
  /// on the device. For a front camera only 1x (and 2x) are offered.
  static ZoomPresets build({
    required CameraLens activeLens,
    required List<CameraLens> backCameras,
    required double minZoom,
    required double maxZoom,
    bool allowUnverifiedUltraWide =
        AppConstants.cameraAllowUnverifiedUltraWideSwitch,
  }) {
    final isBack = activeLens.direction == LensDirection.back;
    final main = isBack ? UltraWideFinder.mainBack(backCameras) : activeLens;

    final zoomsOutByItself =
        isBack && minZoom <= AppConstants.ultraWideMinZoomThreshold;
    final ultra = isBack && !zoomsOutByItself
        ? UltraWideFinder.find(
            backCameras,
            allowUnverified: allowUnverifiedUltraWide,
          )
        : null;
    // When 0.5x needs another camera, 1x and 2x must switch back to the main.
    final backTo = ultra != null ? main : null;

    return ZoomPresets(
      mainLens: main,
      ultraWideLens: ultra,
      presets: [
        if (zoomsOutByItself)
          // The label is nominal; the widest zoom the camera reaches is used.
          ZoomPreset(label: '0.5x', targetZoom: _widest(minZoom))
        else if (ultra != null)
          ZoomPreset(label: '0.5x', targetZoom: 0.5, cameraToSwitchTo: ultra),
        ZoomPreset(label: '1x', targetZoom: 1, cameraToSwitchTo: backTo),
        if (maxZoom >= 2)
          ZoomPreset(label: '2x', targetZoom: 2, cameraToSwitchTo: backTo),
      ],
    );
  }

  static double _widest(double minZoom) => minZoom < 0.5 ? 0.5 : minZoom;
}
