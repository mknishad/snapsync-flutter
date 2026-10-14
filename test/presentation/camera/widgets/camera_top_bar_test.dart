import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapsync/domain/camera/flash_setting.dart';
import 'package:snapsync/presentation/camera/widgets/camera_top_bar.dart';

import '../../../support/ui_support.dart';

Future<void> pump(
  WidgetTester tester, {
  FlashSetting flash = FlashSetting.off,
  bool supportsFlash = true,
  bool grid = false,
  VoidCallback? onClose,
  VoidCallback? onFlash,
  VoidCallback? onGrid,
}) {
  return tester.pumpWidget(
    testApp(
      CameraTopBar(
        flash: flash,
        supportsFlash: supportsFlash,
        gridEnabled: grid,
        onClose: onClose ?? () {},
        onFlash: onFlash ?? () {},
        onGrid: onGrid ?? () {},
      ),
    ),
  );
}

void main() {
  testWidgets('the flash button is hidden when the camera has no flash', (
    tester,
  ) async {
    await pump(tester, supportsFlash: false);

    expect(find.byIcon(Icons.flash_off_rounded), findsNothing);
    expect(find.byIcon(Icons.flash_auto_rounded), findsNothing);
    expect(find.byIcon(Icons.flash_on_rounded), findsNothing);
    expect(find.byIcon(Icons.grid_3x3_rounded), findsOneWidget);
  });

  testWidgets('the flash icon reflects the current mode', (tester) async {
    final icons = {
      FlashSetting.off: Icons.flash_off_rounded,
      FlashSetting.auto: Icons.flash_auto_rounded,
      FlashSetting.always: Icons.flash_on_rounded,
    };
    for (final entry in icons.entries) {
      await pump(tester, flash: entry.key);
      expect(find.byIcon(entry.value), findsOneWidget, reason: entry.key.name);
    }
  });

  testWidgets('buttons call their callbacks', (tester) async {
    final calls = <String>[];
    await pump(
      tester,
      onClose: () => calls.add('close'),
      onFlash: () => calls.add('flash'),
      onGrid: () => calls.add('grid'),
    );

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.tap(find.byIcon(Icons.flash_off_rounded));
    await tester.tap(find.byIcon(Icons.grid_3x3_rounded));

    expect(calls, ['close', 'flash', 'grid']);
  });

  testWidgets('every icon button has a spoken label', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, flash: FlashSetting.auto);

    expect(find.bySemanticsLabel('Close camera'), findsOneWidget);
    expect(find.bySemanticsLabel('Flash: auto. Tap to change'), findsOneWidget);
    expect(find.bySemanticsLabel('Show grid'), findsOneWidget);

    await pump(tester, grid: true);
    expect(find.bySemanticsLabel('Hide grid'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('the grid toggle looks switched on when enabled', (tester) async {
    await pump(tester);
    final offColour = _fill(tester, Icons.grid_3x3_rounded);
    await pump(tester, grid: true);
    final onColour = _fill(tester, Icons.grid_3x3_rounded);

    expect(onColour, isNot(offColour));
  });

  testWidgets('each button has a 48 dp touch target', (tester) async {
    await pump(tester);

    for (final icon in [
      Icons.close_rounded,
      Icons.flash_off_rounded,
      Icons.grid_3x3_rounded,
    ]) {
      final target = find.ancestor(
        of: find.byIcon(icon),
        matching: find.byType(InkResponse),
      );
      expect(tester.getSize(target).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
    }
  });
}

Color? _fill(WidgetTester tester, IconData icon) {
  final box = tester.widget<DecoratedBox>(
    find
        .ancestor(of: find.byIcon(icon), matching: find.byType(DecoratedBox))
        .first,
  );
  return (box.decoration as BoxDecoration).color;
}
