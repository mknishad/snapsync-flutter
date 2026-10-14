import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapsync/core/theme/app_semantic_colors.dart';
import 'package:snapsync/domain/entities/link_quality.dart';
import 'package:snapsync/presentation/upload_manager/widgets/link_status_pill.dart';

import '../../../support/ui_support.dart';

void main() {
  final cases = {
    LinkQuality.stable: (
      'STABLE LINK',
      Icons.check_circle_rounded,
      AppSemanticColors.dark.success,
    ),
    LinkQuality.unstable: (
      'UNSTABLE',
      Icons.network_check_rounded,
      AppSemanticColors.dark.warning,
    ),
    LinkQuality.offline: (
      'OFFLINE',
      Icons.cloud_off_rounded,
      AppSemanticColors.dark.danger,
    ),
  };

  for (final entry in cases.entries) {
    testWidgets('${entry.key.name}: text, icon and colour', (tester) async {
      final (label, icon, color) = entry.value;
      await tester.pumpWidget(testApp(LinkStatusPill(quality: entry.key)));

      expect(find.text(label), findsOneWidget);
      expect(tester.widget<Icon>(find.byIcon(icon)).color, color);
      expect(tester.widget<Text>(find.text(label)).style?.color, color);
    });
  }

  testWidgets('each quality has a different icon and text (not colour alone)', (
    tester,
  ) async {
    final seen = <String>{};
    for (final quality in LinkQuality.values) {
      await tester.pumpWidget(testApp(LinkStatusPill(quality: quality)));
      seen.add(
        '${tester.widget<Icon>(find.byType(Icon)).icon}|'
        '${tester.widget<Text>(find.byType(Text)).data}',
      );
    }
    expect(seen, hasLength(3));
  });

  testWidgets('announces the connection state', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      testApp(const LinkStatusPill(quality: LinkQuality.offline)),
    );

    expect(find.bySemanticsLabel('Device offline'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('survives 200 percent text in a narrow space', (tester) async {
    await tester.pumpWidget(
      testApp(
        const SizedBox(
          width: 120,
          child: LinkStatusPill(quality: LinkQuality.stable),
        ),
        textScale: 2,
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
