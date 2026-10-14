import 'dart:math' as math;

/// How the preview fills its container.
enum PreviewFit {
  /// Whole frame visible, bars around it if the shapes differ (letterbox).
  contain,

  /// Container filled, frame cropped if the shapes differ.
  cover,
}

/// Where the displayed preview sits inside its container.
typedef PreviewRect = ({double left, double top, double width, double height});

/// Tap-to-focus geometry. Pure, no Flutter.
///
/// The camera wants focus points as (0..1, 0..1) over the whole preview frame
/// as displayed (on Android, CameraX's display-oriented point factory). A tap
/// arrives in the coordinates of whatever widget catches it, which may be
/// bigger than the preview. [aspectRatio] is the displayed frame's width over
/// height for the current orientation (portrait is below 1), so rotation is
/// already accounted for by the caller; this maps the tap onto that frame.
abstract final class PreviewGeometry {
  static PreviewRect previewRect({
    required double containerWidth,
    required double containerHeight,
    required double aspectRatio,
    PreviewFit fit = PreviewFit.contain,
  }) {
    final containerRatio = containerWidth / containerHeight;
    // Whether the frame is limited by the container's width or its height.
    final limitedByHeight = fit == PreviewFit.contain
        ? containerRatio > aspectRatio
        : containerRatio <= aspectRatio;
    final width = limitedByHeight
        ? containerHeight * aspectRatio
        : containerWidth;
    final height = limitedByHeight
        ? containerHeight
        : containerWidth / aspectRatio;
    return (
      left: (containerWidth - width) / 2,
      top: (containerHeight - height) / 2,
      width: width,
      height: height,
    );
  }

  /// The normalised focus point for a tap, or null when the tap is outside the
  /// preview (on a letterbox bar, outside the container) or the sizes are
  /// unusable.
  static math.Point<double>? toNormalizedPoint({
    required math.Point<double> local,
    required double containerWidth,
    required double containerHeight,
    required double aspectRatio,
    PreviewFit fit = PreviewFit.contain,
  }) {
    final valid =
        containerWidth > 0 &&
        containerHeight > 0 &&
        aspectRatio > 0 &&
        aspectRatio.isFinite &&
        local.x.isFinite &&
        local.y.isFinite;
    if (!valid) return null;
    // A tap outside the container is not on the preview in either fit mode.
    if (local.x < 0 ||
        local.y < 0 ||
        local.x > containerWidth ||
        local.y > containerHeight) {
      return null;
    }

    final rect = previewRect(
      containerWidth: containerWidth,
      containerHeight: containerHeight,
      aspectRatio: aspectRatio,
      fit: fit,
    );
    final x = (local.x - rect.left) / rect.width;
    final y = (local.y - rect.top) / rect.height;

    const epsilon = 1e-9;
    if (x < -epsilon || x > 1 + epsilon || y < -epsilon || y > 1 + epsilon) {
      return null;
    }
    return math.Point(x.clamp(0.0, 1.0), y.clamp(0.0, 1.0));
  }
}
