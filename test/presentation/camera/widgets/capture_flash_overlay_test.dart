import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapsync/presentation/camera/widgets/capture_flash_overlay.dart';

import '../../../support/ui_support.dart';

Future<void> pump(
  WidgetTester tester,
  bool capturing, {
  bool disableAnimations = false,
}) {
  return tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: testApp(
        CaptureFlashOverlay(isCapturing: capturing),
        scaffold: false,
      ),
    ),
  );
}

double flashAlpha(WidgetTester tester) {
  final box = tester.widget<ColoredBox>(
    find.descendant(
      of: find.byType(CaptureFlashOverlay),
      matching: find.byType(ColoredBox),
    ),
  );
  return box.color.a;
}

void main() {
  testWidgets('is invisible while idle', (tester) async {
    await pump(tester, false);

    expect(flashAlpha(tester), 0);
  });

  testWidgets('flashes white when a capture starts, then fades away', (
    tester,
  ) async {
    await pump(tester, false);
    await pump(tester, true);

    await tester.pump(const Duration(milliseconds: 55));
    expect(flashAlpha(tester), greaterThan(0.3), reason: 'peak of the flash');

    await tester.pump(const Duration(milliseconds: 300));
    expect(flashAlpha(tester), 0, reason: 'finished');
  });

  testWidgets('flashes once per capture, not for as long as it is capturing', (
    tester,
  ) async {
    await pump(tester, false);
    await pump(tester, true);
    await tester.pump(const Duration(milliseconds: 400));

    await tester.pump(const Duration(seconds: 2));

    expect(flashAlpha(tester), 0);
  });

  testWidgets('does not flash when animations are turned off', (tester) async {
    await pump(tester, false, disableAnimations: true);
    await pump(tester, true, disableAnimations: true);
    await tester.pump(const Duration(milliseconds: 55));

    expect(flashAlpha(tester), 0);
  });

  testWidgets('flashes again for the next capture', (tester) async {
    await pump(tester, false);
    await pump(tester, true);
    await tester.pump(const Duration(milliseconds: 400));
    await pump(tester, false);
    await pump(tester, true);
    await tester.pump(const Duration(milliseconds: 55));

    expect(flashAlpha(tester), greaterThan(0.3));
  });

  testWidgets('does not block touches', (tester) async {
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
            const CaptureFlashOverlay(isCapturing: false),
          ],
        ),
      ),
    );

    await tester.tapAt(const Offset(50, 50));

    expect(taps, 1);
  });
}
