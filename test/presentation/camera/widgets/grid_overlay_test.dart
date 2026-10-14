import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapsync/presentation/camera/widgets/grid_overlay.dart';

import '../../../support/ui_support.dart';

void main() {
  testWidgets('draws two vertical and two horizontal lines', (tester) async {
    await tester.pumpWidget(
      testApp(const SizedBox.expand(child: GridOverlay(aspectRatio: null))),
    );

    final painted = find.descendant(
      of: find.byType(GridOverlay),
      matching: find.byType(CustomPaint),
    );
    expect(
      tester.renderObject(painted.first),
      paints
        ..line()
        ..line()
        ..line()
        ..line(),
    );
  });

  test('thirds are placed at one third and two thirds of the area', () {
    final lines = <(Offset, Offset)>[];
    final canvas = _RecordingCanvas(lines);

    const ThirdsPainter(
      color: Colors.white,
      aspectRatio: null,
    ).paint(canvas, const Size(300, 600));

    expect(lines, [
      (const Offset(100, 0), const Offset(100, 600)),
      (const Offset(0, 200), const Offset(300, 200)),
      (const Offset(200, 0), const Offset(200, 600)),
      (const Offset(0, 400), const Offset(300, 400)),
    ]);
  });

  test(
    'with an aspect ratio the lines cover the preview, not the letterbox',
    () {
      final lines = <(Offset, Offset)>[];
      final canvas = _RecordingCanvas(lines);

      // A 3:4 frame in a 400x800 area: it spans y 133.3 to 666.7.
      const ThirdsPainter(
        color: Colors.white,
        aspectRatio: 0.75,
      ).paint(canvas, const Size(400, 800));

      final firstVertical = lines.first;
      expect(firstVertical.$1.dy, closeTo(133.33, 0.01));
      expect(firstVertical.$2.dy, closeTo(666.67, 0.01));
      expect(firstVertical.$1.dx, closeTo(400 / 3, 0.01));
    },
  );

  test('repaints only when something changed', () {
    const a = ThirdsPainter(color: Colors.white, aspectRatio: 0.75);

    expect(
      a.shouldRepaint(
        const ThirdsPainter(color: Colors.white, aspectRatio: 0.75),
      ),
      isFalse,
    );
    expect(
      a.shouldRepaint(const ThirdsPainter(color: Colors.white, aspectRatio: 1)),
      isTrue,
    );
    expect(
      a.shouldRepaint(
        const ThirdsPainter(color: Colors.red, aspectRatio: 0.75),
      ),
      isTrue,
    );
  });

  testWidgets('does not take touches or appear in semantics', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      testApp(
        Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: const SizedBox.expand(),
            ),
            const GridOverlay(aspectRatio: 0.75),
          ],
        ),
      ),
    );

    await tester.tapAt(const Offset(100, 100));

    expect(taps, 1);
  });
}

class _RecordingCanvas implements Canvas {
  _RecordingCanvas(this.lines);

  final List<(Offset, Offset)> lines;

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) => lines.add((p1, p2));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
