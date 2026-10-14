import 'package:flutter/material.dart';
import 'package:snapsync/core/theme/app_semantic_colors.dart';
import 'package:snapsync/core/theme/app_spacing.dart';

/// The big white shutter. Shrinks while pressed and shows a spinner and a dimmed
/// centre while a capture is being saved.
class ShutterButton extends StatefulWidget {
  const ShutterButton({
    required this.isBusy,
    required this.onPressed,
    super.key,
  });

  final bool isBusy;
  final VoidCallback onPressed;

  @override
  State<ShutterButton> createState() => _ShutterButtonState();
}

class _ShutterButtonState extends State<ShutterButton> {
  // Only the press animation; whether a capture is running comes from the cubit.
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value && !widget.isBusy) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final enabled = !widget.isBusy;

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.isBusy ? 'Saving photo' : 'Take photo',
      excludeSemantics: true,
      onTap: enabled ? widget.onPressed : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: enabled ? widget.onPressed : null,
        child: SizedBox(
          width: AppSizes.shutterOuter,
          height: AppSizes.shutterOuter,
          child: Center(
            child: AnimatedScale(
              scale: _pressed ? 0.9 : 1,
              duration: const Duration(milliseconds: 90),
              child: Container(
                width: AppSizes.shutterOuter - AppSpacing.sm,
                height: AppSizes.shutterOuter - AppSpacing.sm,
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: semantic.onOverlay, width: 3),
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.isBusy
                        ? semantic.onOverlay.withValues(alpha: 0.5)
                        : semantic.onOverlay,
                  ),
                  child: widget.isBusy
                      ? Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: semantic.cameraBackground,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
