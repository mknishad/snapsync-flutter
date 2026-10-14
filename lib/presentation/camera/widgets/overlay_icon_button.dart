import 'package:flutter/material.dart';
import 'package:snapsync/core/theme/app_semantic_colors.dart';
import 'package:snapsync/core/theme/app_spacing.dart';

/// Round translucent icon button drawn over the camera preview. The visible
/// circle is smaller than the 48 dp touch target around it.
class OverlayIconButton extends StatelessWidget {
  const OverlayIconButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
    super.key,
  });

  final IconData icon;

  /// Read out by screen readers, and shown as the long-press tooltip.
  final String label;
  final VoidCallback? onPressed;

  /// Draws the button as switched on (for toggles such as the grid).
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    return Semantics(
      button: true,
      label: label,
      selected: selected,
      enabled: onPressed != null,
      excludeSemantics: true,
      onTap: onPressed,
      child: Tooltip(
        message: label,
        child: InkResponse(
          onTap: onPressed,
          radius: AppSizes.minTapTarget / 2,
          child: SizedBox(
            width: AppSizes.minTapTarget,
            height: AppSizes.minTapTarget,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? semantic.onOverlay : semantic.overlay,
                ),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(
                    icon,
                    size: 22,
                    color: selected
                        ? semantic.cameraBackground
                        : semantic.onOverlay,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
