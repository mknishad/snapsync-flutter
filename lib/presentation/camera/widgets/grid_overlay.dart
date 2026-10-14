import 'package:flutter/material.dart';
import 'package:snapsync/core/theme/app_semantic_colors.dart';
import 'package:snapsync/domain/camera/preview_geometry.dart';

/// Rule-of-thirds guide lines, drawn over the preview only (not the letterbox
/// bars). [aspectRatio] is the displayed frame's width over height; without it
/// the lines cover the whole area.
class GridOverlay extends StatelessWidget {
  const GridOverlay({required this.aspectRatio, super.key});

  final double? aspectRatio;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: CustomPaint(
          painter: ThirdsPainter(
            color: context.semantic.onOverlay.withValues(alpha: 0.45),
            aspectRatio: aspectRatio,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class ThirdsPainter extends CustomPainter {
  const ThirdsPainter({required this.color, required this.aspectRatio});

  final Color color;
  final double? aspectRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final ratio = aspectRatio;
    final rect = ratio == null || ratio <= 0 || size.isEmpty
        ? Offset.zero & size
        : () {
            final r = PreviewGeometry.previewRect(
              containerWidth: size.width,
              containerHeight: size.height,
              aspectRatio: ratio,
            );
            return Rect.fromLTWH(r.left, r.top, r.width, r.height);
          }();

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var i = 1; i <= 2; i++) {
      final x = rect.left + rect.width * i / 3;
      final y = rect.top + rect.height * i / 3;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), paint);
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), paint);
    }
  }

  @override
  bool shouldRepaint(ThirdsPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.aspectRatio != aspectRatio;
}
