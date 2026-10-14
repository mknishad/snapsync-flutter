import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapsync/presentation/camera/widgets/shutter_button.dart';

import '../../../support/ui_support.dart';

Future<void> pump(
  WidgetTester tester, {
  bool busy = false,
  VoidCallback? onPressed,
}) {
  return tester.pumpWidget(
    testApp(
      Center(
        child: ShutterButton(isBusy: busy, onPressed: onPressed ?? () {}),
      ),
    ),
  );
}

double scaleOf(WidgetTester tester) =>
    tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

void main() {
  testWidgets('a tap calls onPressed', (tester) async {
    var taps = 0;
    await pump(tester, onPressed: () => taps++);

    await tester.tap(find.byType(ShutterButton));

    expect(taps, 1);
  });

  testWidgets('shrinks while pressed and returns on release', (tester) async {
    await pump(tester);
    expect(scaleOf(tester), 1);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ShutterButton)),
    );
    await tester.pump();
    expect(scaleOf(tester), lessThan(1));

    await gesture.up();
    await tester.pump();
    expect(scaleOf(tester), 1);
  });

  testWidgets('a cancelled press also returns to full size', (tester) async {
    await pump(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ShutterButton)),
    );
    await tester.pump();
    await gesture.moveBy(const Offset(0, 400));
    await gesture.cancel();
    await tester.pump();

    expect(scaleOf(tester), 1);
  });

  testWidgets('while busy it shows a spinner and ignores taps', (tester) async {
    var taps = 0;
    await pump(tester, busy: true, onPressed: () => taps++);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(ShutterButton));
    expect(taps, 0);
  });

  testWidgets('a busy button does not animate a press', (tester) async {
    await pump(tester, busy: true);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ShutterButton)),
    );
    await tester.pump();

    expect(scaleOf(tester), 1);
    await gesture.up();
  });

  testWidgets('is announced as Take photo, and Saving photo when busy', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    expect(find.bySemanticsLabel('Take photo'), findsOneWidget);

    await pump(tester, busy: true);
    expect(find.bySemanticsLabel('Saving photo'), findsOneWidget);
    expect(find.bySemanticsLabel('Take photo'), findsNothing);
    handle.dispose();
  });

  testWidgets('is a large touch target', (tester) async {
    await pump(tester);

    final size = tester.getSize(find.byType(ShutterButton));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });
}
