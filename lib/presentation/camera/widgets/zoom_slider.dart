import 'package:flutter/material.dart';
import 'package:snapsync/core/theme/app_semantic_colors.dart';
import 'package:snapsync/core/theme/app_spacing.dart';
import 'package:snapsync/core/utils/format_utils.dart';

/// Vertical zoom slider for the right edge: the current zoom on top, the
/// minimum at the bottom, a thin translucent track between them.
///
/// [value] and [onChanged] use the cubit's slider scale (0 to 1, logarithmic),
/// so this widget does no zoom maths. It is a Slider turned on its side, which
/// keeps keyboard and screen-reader adjustment working.
class ZoomSlider extends StatelessWidget {
  const ZoomSlider({
    required this.zoom,
    required this.minZoom,
    required this.value,
    required this.onChanged,
    this.height = AppSizes.zoomSliderHeight,
    super.key,
  });

  final double zoom;
  final double minZoom;
  final double value;
  final ValueChanged<double> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final labelStyle = semantic.overlayLabel.copyWith(
      shadows: [Shadow(color: semantic.overlayStrong, blurRadius: 4)],
    );

    return Semantics(
      container: true,
      label: 'Zoom',
      value: FormatUtils.zoom(zoom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Text(FormatUtils.zoom(zoom), style: labelStyle),
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            width: AppSizes.minTapTarget,
            height: height,
            // Turned a quarter-turn so the thumb moves up to zoom in.
            child: RotatedBox(
              quarterTurns: 3,
              child: Slider(
                value: value.isNaN ? 0 : value.clamp(0.0, 1.0),
                onChanged: onChanged,
                semanticFormatterCallback: (v) =>
                    'Zoom ${FormatUtils.zoom(zoom)}',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          ExcludeSemantics(
            child: Text(FormatUtils.zoom(minZoom), style: labelStyle),
          ),
        ],
      ),
    );
  }
}
