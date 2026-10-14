import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapsync/core/theme/app_semantic_colors.dart';
import 'package:snapsync/presentation/camera/widgets/batch_thumbnail.dart';
import 'package:snapsync/presentation/common/widgets/photo_thumbnail.dart';

import '../../../support/ui_support.dart';

Future<void> pump(
  WidgetTester tester, {
  required int count,
  String? path = '/x.jpg',
  VoidCallback? onTap,
}) {
  return tester.pumpWidget(
    testApp(
      Center(
        child: BatchThumbnail(
          count: count,
          latestPath: path,
          onTap: onTap ?? () {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the latest photo with a blue count badge', (tester) async {
    await pump(tester, count: 12);

    expect(find.byType(PhotoThumbnail), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    final badge = tester.widget<Container>(
      find
          .ancestor(of: find.text('12'), matching: find.byType(Container))
          .first,
    );
    expect(
      (badge.decoration as BoxDecoration).color,
      AppSemanticColors.dark.info,
    );
  });

  testWidgets('with no photos it is an empty slot with no badge', (
    tester,
  ) async {
    await pump(tester, count: 0, path: null);

    expect(find.byType(PhotoThumbnail), findsNothing);
    expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('tapping opens the review only when there are photos', (
    tester,
  ) async {
    var taps = 0;
    await pump(tester, count: 3, onTap: () => taps++);
    await tester.tap(find.byType(BatchThumbnail));
    expect(taps, 1);

    await pump(tester, count: 0, path: null, onTap: () => taps++);
    await tester.tap(find.byType(BatchThumbnail));
    expect(taps, 1, reason: 'an empty slot does nothing');
  });

  testWidgets('is announced with the count, singular and plural', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, count: 1);
    expect(
      find.bySemanticsLabel('Review 1 photo in this batch'),
      findsOneWidget,
    );

    await pump(tester, count: 12);
    expect(
      find.bySemanticsLabel('Review 12 photos in this batch'),
      findsOneWidget,
    );

    await pump(tester, count: 0, path: null);
    expect(
      find.bySemanticsLabel('No photos in this batch yet'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('a large count does not overflow', (tester) async {
    await pump(tester, count: 1234);

    expect(find.text('1234'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('has a 48 dp touch target', (tester) async {
    await pump(tester, count: 2);

    final size = tester.getSize(find.byType(BatchThumbnail));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });
}
