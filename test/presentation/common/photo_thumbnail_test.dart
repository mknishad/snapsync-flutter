import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapsync/presentation/common/widgets/photo_thumbnail.dart';

import '../../support/test_support.dart';
import '../../support/ui_support.dart';

void main() {
  testWidgets('no path shows the placeholder', (tester) async {
    await tester.pumpWidget(
      testApp(const PhotoThumbnail(path: null, logicalSize: 56)),
    );

    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('a missing file shows the placeholder and does not crash', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        const PhotoThumbnail(path: '/definitely/not/here.jpg', logicalSize: 56),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a corrupt file shows the placeholder', (tester) async {
    final dir = createTempDir('snapsync_thumb_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/bad.jpg')
      ..writeAsBytesSync(Uint8List.fromList([1, 2, 3]));

    await tester.pumpWidget(
      testApp(PhotoThumbnail(path: file.path, logicalSize: 56)),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();

    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('decodes at a reduced size, not at full resolution', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(const PhotoThumbnail(path: '/x.jpg', logicalSize: 56)),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image;
    expect(provider, isA<ResizeImage>());
    expect((provider as ResizeImage).width, 112, reason: '56 dp at 2x');
  });

  testWidgets('a dimmed thumbnail is semi-transparent', (tester) async {
    await tester.pumpWidget(
      testApp(const PhotoThumbnail(path: null, logicalSize: 56, dimmed: true)),
    );

    final opacity = tester.widget<Opacity>(find.byType(Opacity));
    expect(opacity.opacity, lessThan(1));
  });

  testWidgets('has an image semantics label', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      testApp(
        const PhotoThumbnail(
          path: null,
          logicalSize: 56,
          semanticLabel: 'Latest photo',
        ),
      ),
    );

    expect(find.bySemanticsLabel('Latest photo'), findsOneWidget);
    handle.dispose();
  });
}
