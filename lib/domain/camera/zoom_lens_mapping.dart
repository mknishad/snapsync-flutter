import 'dart:math' as math;

import 'package:snapsync/core/constants/app_constants.dart';

/// Converts between the zoom the user sees ("display" zoom, where 1x is the
/// main camera) and the zoom ratio the camera plugin takes for the active
/// camera ("controller" zoom).
///
/// For the main or a front camera they are the same. For a separate
/// ultra-wide camera, 1.0 on the plugin is about 0.5x on screen, and display
/// zoom is capped at 1x: beyond that the main camera takes over (the user taps
/// the 1x preset), rather than digitally zooming the ultra-wide sensor.
class ZoomLensMapping {
  const ZoomLensMapping({
    required this.controllerMin,
    required this.controllerMax,
    this.baseFactor = 1,
    this.displayCap,
  });

  /// Mapping for the main back camera or a front camera.
  const ZoomLensMapping.standard({required double min, required double max})
    : this(controllerMin: min, controllerMax: max);

  /// Mapping for a separate ultra-wide camera.
  const ZoomLensMapping.ultraWide({required double min, required double max})
    : this(
        controllerMin: min,
        controllerMax: max,
        baseFactor: AppConstants.ultraWideBaseFactor,
        displayCap: 1,
      );

  final double controllerMin;
  final double controllerMax;

  /// Display zoom of the plugin's zoom 1.0.
  final double baseFactor;
  final double? displayCap;

  double get displayMin => controllerMin * baseFactor;

  double get displayMax {
    final max = controllerMax * baseFactor;
    return displayCap == null ? max : math.min(max, displayCap!);
  }

  /// The plugin zoom for [display], always inside the camera's own range so the
  /// platform never receives an out-of-range value.
  double toController(double display) {
    final value = display / baseFactor;
    final low = controllerMin;
    final high = controllerMax;
    return value < low ? low : (value > high ? high : value);
  }

  double toDisplay(double controller) => controller * baseFactor;
}
