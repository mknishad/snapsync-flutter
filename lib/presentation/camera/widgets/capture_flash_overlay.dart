import 'package:flutter/material.dart';
import 'package:snapsync/core/theme/app_semantic_colors.dart';

/// A brief white flash when a capture starts. Does nothing if the user has
/// turned animations off.
class CaptureFlashOverlay extends StatefulWidget {
  const CaptureFlashOverlay({required this.isCapturing, super.key});

  final bool isCapturing;

  @override
  State<CaptureFlashOverlay> createState() => _CaptureFlashOverlayState();
}

class _CaptureFlashOverlayState extends State<CaptureFlashOverlay>
    with SingleTickerProviderStateMixin {
  // Visual animation only.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  @override
  void didUpdateWidget(CaptureFlashOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isCapturing &&
        widget.isCapturing &&
        !MediaQuery.disableAnimationsOf(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.semantic.onOverlay;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            // Up fast, down slower: 0 -> 0.8 -> 0.
            final t = _controller.value;
            final opacity = t < 0.25
                ? t / 0.25 * 0.8
                : 0.8 * (1 - (t - 0.25) / 0.75);
            return ColoredBox(
              color: color.withValues(
                alpha: _controller.isAnimating ? opacity : 0,
              ),
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    );
  }
}
