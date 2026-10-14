import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapsync/presentation/batch/widgets/batch_review_sheet.dart';

import '../../support/camera_ui_support.dart';
import '../../support/fake_camera_cubits.dart';

void main() {
  late FakeCameraCubit camera;
  late FakeBatchCubit batch;

  setUp(() {
    camera = FakeCameraCubit(readyState());
    batch = FakeBatchCubit(batchWith(4));
  });

  tearDown(() async {
    await camera.close();
    await batch.close();
  });

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      cameraHost(
        camera: camera,
        batch: batch,
        child: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showBatchReviewSheet(context),
              child: const Text('review'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('review'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the count and a tile per photo', (tester) async {
    await openSheet(tester);

    expect(find.text('4 photos in this batch'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsNWidgets(4));
  });

  testWidgets('uses the singular for one photo', (tester) async {
    batch.push(batchWith(1));
    await openSheet(tester);

    expect(find.text('1 photo in this batch'), findsOneWidget);
  });

  testWidgets('deleting asks first, then deletes only that photo', (
    tester,
  ) async {
    await openSheet(tester);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded).at(1));
    await tester.pumpAndSettle();
    expect(find.text('Delete this photo?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(batch.calls, isEmpty);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(batch.calls, ['delete:p2']);
  });

  testWidgets('Discard batch asks first, then discards', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text('Discard batch'));
    await tester.pumpAndSettle();
    expect(find.text('Discard this batch?'), findsOneWidget);
    expect(find.textContaining('All 4 photos'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(batch.calls, isEmpty);

    await tester.tap(find.text('Discard batch'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
    await tester.pumpAndSettle();

    expect(batch.calls, ['discard']);
  });

  testWidgets('the close button closes the sheet', (tester) async {
    await openSheet(tester);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.textContaining('in this batch'), findsNothing);
  });

  testWidgets('closes itself when the batch becomes empty', (tester) async {
    await openSheet(tester);

    batch.push(batchWith(0));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.textContaining('in this batch'), findsNothing);
  });

  testWidgets('a photo disappears when it is deleted from the batch', (
    tester,
  ) async {
    await openSheet(tester);

    batch.push(batchWith(3));
    await tester.pump();
    await tester.pump();

    expect(find.text('3 photos in this batch'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsNWidgets(3));
  });

  testWidgets('a large batch builds only the visible tiles', (tester) async {
    batch.push(batchWith(400));
    await openSheet(tester);

    expect(find.byType(GridView), findsOneWidget);
    expect(
      find.byIcon(Icons.delete_outline_rounded).evaluate().length,
      lessThan(60),
    );
  });

  testWidgets('photos are decoded at a reduced size', (tester) async {
    await openSheet(tester);

    final image = tester.widgetList<Image>(find.byType(Image)).first;
    expect(image.image, isA<ResizeImage>());
  });

  testWidgets('every delete button is labelled and 48 dp', (tester) async {
    final handle = tester.ensureSemantics();
    await openSheet(tester);

    expect(find.bySemanticsLabel(RegExp('Delete photo 1')), findsOneWidget);
    final target = find.ancestor(
      of: find.byIcon(Icons.delete_outline_rounded).first,
      matching: find.byType(InkResponse),
    );
    expect(tester.getSize(target).width, greaterThanOrEqualTo(48));
    handle.dispose();
  });

  testWidgets('survives 200 percent text', (tester) async {
    await tester.pumpWidget(
      cameraHost(
        camera: camera,
        batch: batch,
        textScale: 2,
        child: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showBatchReviewSheet(context),
              child: const Text('review'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('review'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
