import 'dart:math' as math;

import 'package:snapsync/domain/camera/zoom_preset.dart';

/// Zoom calculations. Pure functions, no Flutter.
abstract final class ZoomMath {
  static double clamp(double zoom, double min, double max) {
    if (zoom.isNaN) return min;
    return zoom < min ? min : (zoom > max ? max : zoom);
  }

  /// Zoom while pinching: the zoom at gesture start times the gesture's scale.
  /// Multiplying (not adding) keeps the feel even at every zoom level.
  static double pinch({
    required double baseZoom,
    required double scale,
    required double min,
    required double max,
  }) {
    if (!(scale > 0)) return clamp(baseZoom, min, max);
    return clamp(baseZoom * scale, min, max);
  }

  /// Slider position (0 to 1) to zoom.
  ///
  /// Logarithmic, because people judge zoom in ratios: 0.5x to 1x and 1x to 2x
  /// should each take the same slider distance. A straight line would spend
  /// most of the travel on the high end. `zoom = min * (max / min) ^ t`.
  static double sliderToZoom(
    double t, {
    required double min,
    required double max,
  }) {
    if (min <= 0 || max <= min) return min;
    final position = t.isNaN ? 0.0 : (t < 0 ? 0.0 : (t > 1 ? 1.0 : t));
    return clamp(min * math.pow(max / min, position), min, max);
  }

  /// The inverse of [sliderToZoom].
  static double zoomToSlider(
    double zoom, {
    required double min,
    required double max,
  }) {
    if (min <= 0 || max <= min) return 0;
    final value = math.log(clamp(zoom, min, max) / min) / math.log(max / min);
    return value < 0 ? 0 : (value > 1 ? 1 : value);
  }

  /// The preset whose target is within [tolerance] (a fraction, 0.05 = 5
  /// percent) of [zoom], or null. If two qualify, the nearer one wins.
  ///
  /// Zoom is judged in ratios, like the slider: a zoom is "within 5 percent" of
  /// a target when the two differ by a factor of at most 1.05 either way, and
  /// "nearer" means the smaller ratio, so 1.4x is closer to 1x than to 2x.
  static ZoomPreset? snapToPreset(
    double zoom,
    List<ZoomPreset> presets, {
    required double tolerance,
  }) {
    // Float error must not push an exact edge (1.05 against 1.0) just outside.
    const epsilon = 1e-9;
    final window = 1 + tolerance;
    ZoomPreset? best;
    var bestDistance = double.infinity;
    for (final preset in presets) {
      if (preset.targetZoom <= 0) continue;
      final ratio = zoom / preset.targetZoom;
      if (!(ratio > 0) ||
          ratio > window + epsilon ||
          ratio < 1 / window - epsilon) {
        continue;
      }
      final distance = math.log(ratio).abs();
      if (distance < bestDistance) {
        best = preset;
        bestDistance = distance;
      }
    }
    return best;
  }
}
