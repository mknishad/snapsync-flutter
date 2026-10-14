import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapsync/presentation/upload_manager/widgets/sync_summary_card.dart';

import '../../../support/ui_support.dart';

Future<void> pumpCard(
  WidgetTester tester, {
  double progress = 0.73,
  int uploaded = 2516582,
  int total = 3435974,
  bool paused = false,
  VoidCallback? onToggle,
  double textScale = 1,
}) {
  return tester.pumpWidget(
    testApp(
      SyncSummaryCard(
        progress: progress,
        uploadedBytes: uploaded,
        totalBytes: total,
        isPaused: paused,
        onTogglePause: onToggle ?? () {},
      ),
      textScale: textScale,
    ),
  );
}

void main() {
  testWidgets('shows the caption, percentage and sizes', (tester) async {
    await pumpCard(tester);
    await tester.pumpAndSettle();

    expect(find.text('BATCH SYNC PROGRESS'), findsOneWidget);
    expect(find.text('73%'), findsOneWidget);
    expect(find.text('2.4 MB / 3.3 MB Uploaded'), findsOneWidget);
  });

  testWidgets('the bar follows the progress', (tester) async {
    await pumpCard(tester, progress: 0.4);
    await tester.pumpAndSettle();

    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, closeTo(0.4, 1e-6));
  });

  testWidgets('an empty queue shows zeros', (tester) async {
    await pumpCard(tester, progress: 0, uploaded: 0, total: 0);
    await tester.pumpAndSettle();

    expect(find.text('0%'), findsOneWidget);
    expect(find.text('0 B / 0 B Uploaded'), findsOneWidget);
  });

  testWidgets('out-of-range progress is clamped', (tester) async {
    await pumpCard(tester, progress: 1.7);
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);

    await pumpCard(tester, progress: double.nan);
    await tester.pumpAndSettle();
    expect(find.text('0%'), findsOneWidget);
  });

  testWidgets('PAUSE ALL becomes RESUME ALL when paused', (tester) async {
    await pumpCard(tester);
    expect(find.text('PAUSE ALL'), findsOneWidget);
    expect(find.text('RESUME ALL'), findsNothing);

    await pumpCard(tester, paused: true);
    expect(find.text('RESUME ALL'), findsOneWidget);
    expect(find.text('PAUSE ALL'), findsNothing);
  });

  testWidgets('the button calls onTogglePause', (tester) async {
    var toggled = 0;
    await pumpCard(tester, onToggle: () => toggled++);

    await tester.tap(find.text('PAUSE ALL'));

    expect(toggled, 1);
  });

  testWidgets('progress is announced as a percentage', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpCard(tester, progress: 0.5);
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.bySemanticsLabel('Batch sync progress')),
      matchesSemantics(label: 'Batch sync progress', value: '50 percent'),
    );
    handle.dispose();
  });

  testWidgets('survives 200 percent text', (tester) async {
    await pumpCard(tester, textScale: 2);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await pumpCard(tester, paused: true, textScale: 2);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
