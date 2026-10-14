import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapsync/core/theme/app_semantic_colors.dart';
import 'package:snapsync/domain/camera/zoom_preset.dart';
import 'package:snapsync/presentation/camera/widgets/zoom_preset_buttons.dart';

import '../../../support/camera_ui_support.dart';
import '../../../support/ui_support.dart';

Future<void> pump(
  WidgetTester tester, {
  List<ZoomPreset> presets = presets3,
  double zoom = 1,
  ValueChanged<ZoomPreset>? onSelected,
}) {
  return tester.pumpWidget(
    testApp(
      ZoomPresetButtons(
        presets: presets,
        zoom: zoom,
        onSelected: onSelected ?? (_) {},
      ),
    ),
  );
}

/// The fill colour of the button showing [label].
Color? fillOf(WidgetTester tester, String label) {
  final container = tester.widget<AnimatedContainer>(
    find.ancestor(
      of: find.text(label),
      matching: find.byType(AnimatedContainer),
    ),
  );
  return (container.decoration as BoxDecoration?)?.color;
}

void main() {
  testWidgets('renders only the presets it is given', (tester) async {
    await pump(
      tester,
      presets: const [
        ZoomPreset(label: '1x', targetZoom: 1),
        ZoomPreset(label: '2x', targetZoom: 2),
      ],
    );

    expect(find.text('1x'), findsOneWidget);
    expect(find.text('2x'), findsOneWidget);
    expect(
      find.text('0.5x'),
      findsNothing,
      reason: 'unavailable presets do not appear',
    );
  });

  testWidgets('renders nothing without presets', (tester) async {
    await pump(tester, presets: const []);

    expect(find.byType(InkResponse), findsNothing);
  });

  testWidgets('highlights the selected preset in white', (tester) async {
    await pump(tester, zoom: 2);

    expect(fillOf(tester, '2x'), AppSemanticColors.dark.onOverlay);
    expect(fillOf(tester, '1x'), AppSemanticColors.dark.overlay);
    expect(fillOf(tester, '0.5x'), AppSemanticColors.dark.overlay);
  });

  testWidgets('exactly one preset is highlighted', (tester) async {
    for (final zoom in [0.5, 0.8, 1.0, 1.4, 2.0, 5.0]) {
      await pump(tester, zoom: zoom);
      final fills = [
        for (final container in tester.widgetList<AnimatedContainer>(
          find.byType(AnimatedContainer),
        ))
          (container.decoration! as BoxDecoration).color,
      ];
      expect(
        fills.where((c) => c == AppSemanticColors.dark.onOverlay),
        hasLength(1),
        reason: 'zoom $zoom',
      );
      expect(fills, hasLength(3));
    }
  });

  testWidgets('on a preset the button shows its own label', (tester) async {
    await pump(tester, zoom: 1.03);

    expect(find.text('1x'), findsOneWidget);
    expect(find.text('1x', findRichText: true), findsOneWidget);
  });

  testWidgets('between presets the nearest button shows the live zoom', (
    tester,
  ) async {
    await pump(tester, zoom: 1.7);

    expect(find.text('1.7x'), findsOneWidget);
    expect(
      find.text('2x'),
      findsNothing,
      reason: 'its label became the live value',
    );
    expect(fillOf(tester, '1.7x'), AppSemanticColors.dark.onOverlay);
  });

  testWidgets('tapping a preset reports it', (tester) async {
    ZoomPreset? tapped;
    await pump(tester, onSelected: (p) => tapped = p);

    await tester.tap(find.text('2x'));

    expect(tapped, presets3.last);
  });

  testWidgets('each button has a 48 dp touch target', (tester) async {
    await pump(tester);

    for (final label in ['0.5x', '1x', '2x']) {
      final target = find.ancestor(
        of: find.text(label),
        matching: find.byType(InkResponse),
      );
      expect(
        tester.getSize(target).width,
        greaterThanOrEqualTo(48),
        reason: label,
      );
      expect(
        tester.getSize(target).height,
        greaterThanOrEqualTo(48),
        reason: label,
      );
    }
  });

  testWidgets('buttons are announced with selection state', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, zoom: 2);

    expect(
      tester.getSemantics(find.bySemanticsLabel('Zoom 2x')),
      matchesSemantics(
        label: 'Zoom 2x',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('survives 200 percent text', (tester) async {
    await tester.pumpWidget(
      testApp(
        ZoomPresetButtons(presets: presets3, zoom: 1.7, onSelected: (_) {}),
        textScale: 2,
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
