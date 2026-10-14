import 'package:equatable/equatable.dart';
import 'package:snapsync/domain/camera/camera_lens.dart';

/// A zoom button, ready to render.
class ZoomPreset extends Equatable {
  const ZoomPreset({
    required this.label,
    required this.targetZoom,
    this.cameraToSwitchTo,
  });

  /// Text on the button, for example "0.5x".
  final String label;

  /// Zoom to apply, in display units (1.0 is the main camera at no zoom).
  final double targetZoom;

  /// The camera that must be active for this preset, when reaching it means
  /// switching cameras. Null when the current camera can zoom there itself.
  final CameraLens? cameraToSwitchTo;

  @override
  List<Object?> get props => [label, targetZoom, cameraToSwitchTo];
}

/// The presets offered for the current camera, and the lenses behind them.
class ZoomPresets extends Equatable {
  const ZoomPresets({required this.presets, this.mainLens, this.ultraWideLens});

  final List<ZoomPreset> presets;

  /// The camera used for 1x and above (back camera).
  final CameraLens? mainLens;

  /// The separate camera behind the 0.5x preset, if one is used.
  final CameraLens? ultraWideLens;

  bool get hasUltraWide => presets.any((p) => p.targetZoom < 1);

  @override
  List<Object?> get props => [presets, mainLens, ultraWideLens];
}
