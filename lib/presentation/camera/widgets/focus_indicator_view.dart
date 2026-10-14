import 'package:flutter/material.dart';
import 'package:snapsync/core/theme/app_colors.dart';
import 'package:snapsync/presentation/camera/cubit/focus_indicator.dart';

/// Ring drawn at the tap point during tap-to-focus. Colour shows the phase.
class FocusIndicatorView extends StatelessWidget {
  const FocusIndicatorView({required this.indicator, super.key});

  final FocusIndicator indicator;

  static const double size = 72;

  @override
  Widget build(BuildContext context) {
    final color = switch (indicator.phase) {
      FocusPhase.focusing => Colors.white,
      FocusPhase.done => AppColors.success,
      FocusPhase.locked => AppColors.warning,
      FocusPhase.failed => AppColors.error,
    };
    return Positioned(
      left: indicator.position.dx - size / 2,
      top: indicator.position.dy - size / 2,
      width: size,
      height: size,
      child: IgnorePointer(
        child: DecoratedBox(
          key: ValueKey('focus-${indicator.id}'),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
        ),
      ),
    );
  }
}
