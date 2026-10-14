import 'package:flutter/material.dart';
import 'package:snapsync/core/constants/app_constants.dart';
import 'package:snapsync/core/theme/app_semantic_colors.dart';
import 'package:snapsync/core/theme/app_spacing.dart';
import 'package:snapsync/presentation/camera/cubit/focus_indicator.dart';

/// The tap-to-focus mark, centred exactly on the tap position: it scales in,
/// holds, then fades out over the cubit's indicator lifetime. A locked mark
/// (long press) stays until released; a failed one looks different (red, with a
/// cross), as does a locked one (amber, with a lock).
///
/// Give it a key from the indicator's id, so a new tap starts a fresh animation.
class FocusIndicatorView extends StatefulWidget {
  const FocusIndicatorView({required this.indicator, super.key});

  final FocusIndicator indicator;

  static const double size = AppSizes.focusIndicator;

  @override
  State<FocusIndicatorView> createState() => _FocusIndicatorViewState();
}

class _FocusIndicatorViewState extends State<FocusIndicatorView>
    with SingleTickerProviderStateMixin {
  // Visual animation only; the indicator's data comes from the cubit.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppConstants.focusIndicatorDuration,
  );

  bool get _locked => widget.indicator.phase == FocusPhase.locked;

  @override
  void initState() {
    super.initState();
    if (!_locked) _controller.forward();
  }

  @override
  void didUpdateWidget(FocusIndicatorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Locking keeps the mark on screen for as long as the lock lasts.
    if (_locked) _controller.stop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final phase = widget.indicator.phase;
    final color = switch (phase) {
      FocusPhase.focusing || FocusPhase.done => semantic.onOverlay,
      FocusPhase.locked => semantic.warning,
      FocusPhase.failed => semantic.danger,
    };

    return Positioned(
      left: widget.indicator.position.dx - FocusIndicatorView.size / 2,
      top: widget.indicator.position.dy - FocusIndicatorView.size / 2,
      width: FocusIndicatorView.size,
      height: FocusIndicatorView.size,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final t = _controller.value;
              // Scale in during the first 12%, fade out during the last 25%.
              final scale = _locked
                  ? 1.0
                  : 1.5 -
                        0.5 *
                            Curves.easeOut.transform(
                              (t / 0.12).clamp(0.0, 1.0),
                            );
              final opacity = _locked
                  ? 1.0
                  : (1 - ((t - 0.75) / 0.25)).clamp(0.0, 1.0);
              return Opacity(
                opacity: opacity,
                child: Transform.scale(scale: scale, child: child),
              );
            },
            child: _Mark(phase: phase, color: color),
          ),
        ),
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark({required this.phase, required this.color});

  final FocusPhase phase;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // A ring while focusing; a square once the camera took the request.
    final shape = phase == FocusPhase.focusing
        ? BoxShape.circle
        : BoxShape.rectangle;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: shape == BoxShape.circle
            ? null
            : BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color, width: 2),
      ),
      child: switch (phase) {
        FocusPhase.locked => Icon(Icons.lock_rounded, color: color, size: 20),
        FocusPhase.failed => Icon(Icons.close_rounded, color: color, size: 24),
        _ => null,
      },
    );
  }
}
