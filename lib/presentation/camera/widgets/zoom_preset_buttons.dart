import 'package:flutter/material.dart';
import 'package:snapsync/core/constants/app_constants.dart';
import 'package:snapsync/core/theme/app_semantic_colors.dart';
import 'package:snapsync/core/theme/app_spacing.dart';
import 'package:snapsync/core/utils/format_utils.dart';
import 'package:snapsync/domain/camera/zoom_math.dart';
import 'package:snapsync/domain/camera/zoom_preset.dart';

/// Small round zoom buttons (0.5x, 1x, 2x...). Shows exactly the presets it is
/// given; the one nearest the current zoom is highlighted, and while the zoom
/// sits between presets (pinching) that button shows the live value.
class ZoomPresetButtons extends StatelessWidget {
  const ZoomPresetButtons({
    required this.presets,
    required this.zoom,
    required this.onSelected,
    super.key,
  });

  final List<ZoomPreset> presets;
  final double zoom;
  final ValueChanged<ZoomPreset> onSelected;

  @override
  Widget build(BuildContext context) {
    if (presets.isEmpty) return const SizedBox.shrink();

    // The preset the zoom is on, if any; otherwise the nearest one, which then
    // shows the live number.
    final onPreset = ZoomMath.snapToPreset(
      zoom,
      presets,
      tolerance: AppConstants.zoomPresetSnapTolerance,
    );
    final selected =
        onPreset ??
        ZoomMath.snapToPreset(zoom, presets, tolerance: double.maxFinite);

    // Wraps instead of overflowing when the space is narrow (the landscape rail).
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        for (final preset in presets)
          _PresetButton(
            label: preset == selected && onPreset == null
                ? FormatUtils.zoom(zoom)
                : preset.label,
            spoken: 'Zoom ${preset.label}',
            selected: preset == selected,
            onTap: () => onSelected(preset),
          ),
      ],
    );
  }
}

class _PresetButton extends StatelessWidget {
  const _PresetButton({
    required this.label,
    required this.spoken,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String spoken;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    return Semantics(
      button: true,
      selected: selected,
      label: spoken,
      excludeSemantics: true,
      onTap: onTap,
      child: InkResponse(
        onTap: onTap,
        radius: AppSizes.minTapTarget / 2,
        child: SizedBox(
          width: AppSizes.minTapTarget,
          height: AppSizes.minTapTarget,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              alignment: Alignment.center,
              // Wide enough for "0.5x" and the live "1.7x" without clipping.
              constraints: const BoxConstraints(
                minWidth: AppSizes.presetButton,
                minHeight: AppSizes.presetButton,
              ),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? semantic.onOverlay : semantic.overlay,
              ),
              child: Text(
                label,
                maxLines: 1,
                style: semantic.overlayLabel.copyWith(
                  color: selected
                      ? semantic.cameraBackground
                      : semantic.onOverlay,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
