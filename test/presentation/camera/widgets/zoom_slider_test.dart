import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapsync/presentation/camera/widgets/zoom_slider.dart';

import '../../../support/ui_support.dart';

Future<void> pump(
  WidgetTester tester, {
  double zoom = 3,
  double minZoom = 1,
  double value = 0.5,
  ValueChanged<double>? onChanged,
  double textScale = 1,
}) {
  return tester.pumpWidget(
    testApp(
      Center(
        child: ZoomSlider(
          zoom: zoom,
          minZoom: minZoom,
          value: value,
          onChanged: onChanged ?? (_) {},
        ),
      ),
      textScale: textScale,
    ),
  );
}

void main() {
  testWidgets('shows the current zoom on top and the minimum at the bottom', (
    tester,
  ) async {
    await pump(tester, zoom: 3, minZoom: 1);

    final top = tester.getTopLeft(find.text('3x')).dy;
    final bottom = tester.getTopLeft(find.text('1x')).dy;
    expect(top, lessThan(bottom));
  });

  testWidgets('the bottom label follows the camera\'s minimum', (tester) async {
    await pump(tester, zoom: 1.2, minZoom: 0.5);

    expect(find.text('0.5x'), findsOneWidget);
    expect(find.text('1.2x'), findsOneWidget);
  });

  testWidgets('is a vertical slider: taller than wide', (tester) async {
    await pump(tester);

    final size = tester.getSize(find.byType(RotatedBox));
    expect(size.height, greaterThan(size.width));
  });

  testWidgets('dragging up zooms in, dragging down zooms out', (tester) async {
    final values = <double>[];
    await pump(tester, value: 0.5, onChanged: values.add);

    await tester.drag(find.byType(Slider), const Offset(0, -40));
    await tester.pump();
    expect(values, isNotEmpty);
    expect(values.last, greaterThan(0.5));

    values.clear();
    await tester.drag(find.byType(Slider), const Offset(0, 40));
    await tester.pump();
    expect(values.last, lessThan(0.5));
  });

  testWidgets('the thumb sits where the cubit\'s slider value says', (
    tester,
  ) async {
    await pump(tester, value: 0.25);
    final low = tester.widget<Slider>(find.byType(Slider)).value;
    await pump(tester, value: 0.9);
    final high = tester.widget<Slider>(find.byType(Slider)).value;

    expect(low, 0.25);
    expect(high, 0.9);
  });

  testWidgets('out-of-range values are clamped instead of asserting', (
    tester,
  ) async {
    await pump(tester, value: 1.4);
    expect(tester.widget<Slider>(find.byType(Slider)).value, 1);

    await pump(tester, value: double.nan);
    expect(tester.widget<Slider>(find.byType(Slider)).value, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('announces the zoom level', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, zoom: 2);

    expect(find.bySemanticsLabel('Zoom'), findsOneWidget);
    expect(tester.getSemantics(find.bySemanticsLabel('Zoom')).value, '2x');
    handle.dispose();
  });

  testWidgets('has a 48 dp wide touch area', (tester) async {
    await pump(tester);

    expect(
      tester.getSize(find.byType(RotatedBox)).width,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('survives 200 percent text', (tester) async {
    await pump(tester, textScale: 2);

    expect(tester.takeException(), isNull);
  });
}
