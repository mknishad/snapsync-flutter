import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapsync/presentation/camera/widgets/upload_batch_button.dart';

import '../../../support/ui_support.dart';

Future<void> pump(
  WidgetTester tester,
  int count, {
  VoidCallback? onPressed,
  double textScale = 1,
}) {
  return tester.pumpWidget(
    testApp(
      UploadBatchButton(count: count, onPressed: onPressed ?? () {}),
      textScale: textScale,
    ),
  );
}

void main() {
  testWidgets('is disabled when the batch is empty', (tester) async {
    var taps = 0;
    await pump(tester, 0, onPressed: () => taps++);

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    expect(taps, 0);
  });

  testWidgets('is enabled with photos and shows the count', (tester) async {
    var taps = 0;
    await pump(tester, 12, onPressed: () => taps++);

    expect(find.text('UPLOAD BATCH (12)'), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    expect(taps, 1);
  });

  testWidgets('shows the zero count too', (tester) async {
    await pump(tester, 0);

    expect(find.text('UPLOAD BATCH (0)'), findsOneWidget);
  });

  testWidgets('is full width', (tester) async {
    await pump(tester, 3);

    expect(tester.getSize(find.byType(FilledButton)).width, 800);
  });

  testWidgets('is announced with the count and the disabled state', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, 1);
    expect(find.bySemanticsLabel('Upload batch, 1 photo'), findsOneWidget);

    await pump(tester, 5);
    expect(find.bySemanticsLabel('Upload batch, 5 photos'), findsOneWidget);

    await pump(tester, 0);
    expect(
      find.bySemanticsLabel('Upload batch, no photos yet'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('survives 200 percent text', (tester) async {
    await pump(tester, 123, textScale: 2);

    expect(tester.takeException(), isNull);
  });
}
