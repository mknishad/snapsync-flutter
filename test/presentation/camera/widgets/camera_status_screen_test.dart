import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapsync/presentation/camera/cubit/camera_state.dart';
import 'package:snapsync/presentation/camera/widgets/camera_status_screen.dart';

import '../../../support/ui_support.dart';

Future<List<String>> pump(
  WidgetTester tester,
  CameraStatus status, {
  bool canRetry = true,
  double textScale = 1,
}) async {
  final calls = <String>[];
  await tester.pumpWidget(
    testApp(
      CameraStatusScreen(
        status: status,
        canRetry: canRetry,
        onRequestPermission: () => calls.add('permission'),
        onOpenSettings: () => calls.add('settings'),
        onRetry: () => calls.add('retry'),
        onGoToUploads: () => calls.add('uploads'),
      ),
      textScale: textScale,
    ),
  );
  return calls;
}

void main() {
  group('permission states', () {
    testWidgets('denied: explains and offers Allow camera', (tester) async {
      final calls = await pump(tester, CameraStatus.permissionDenied);

      expect(find.text('Camera access needed'), findsOneWidget);
      expect(find.textContaining('needs the camera'), findsOneWidget);
      expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);
      await tester.tap(find.text('Allow camera'));
      expect(calls, ['permission']);
    });

    testWidgets(
      'permanently denied: offers Open settings, not another prompt',
      (tester) async {
        final calls = await pump(
          tester,
          CameraStatus.permissionPermanentlyDenied,
          canRetry: false,
        );

        expect(find.text('Camera access is turned off'), findsOneWidget);
        expect(find.text('Allow camera'), findsNothing);
        await tester.tap(find.text('Open settings'));
        expect(calls, ['settings']);
      },
    );
  });

  group('hardware and error states', () {
    testWidgets('no camera: explains and offers no retry', (tester) async {
      await pump(tester, CameraStatus.noCameraAvailable, canRetry: false);

      expect(find.text('No camera found'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
      expect(find.text('Allow camera'), findsNothing);
      expect(find.text('Open settings'), findsNothing);
    });

    for (final entry in {
      CameraStatus.cameraInUse: (
        'Camera is in use',
        Icons.videocam_off_outlined,
      ),
      CameraStatus.unavailable: (
        'Camera unavailable',
        Icons.error_outline_rounded,
      ),
      CameraStatus.error: ('Something went wrong', Icons.error_outline_rounded),
    }.entries) {
      testWidgets('${entry.key.name}: title, icon and Try again', (
        tester,
      ) async {
        final calls = await pump(tester, entry.key);

        expect(find.text(entry.value.$1), findsOneWidget);
        expect(find.byIcon(entry.value.$2), findsOneWidget);
        await tester.tap(find.text('Try again'));
        expect(calls, ['retry']);
      });

      testWidgets('${entry.key.name}: no Try again when it cannot be retried', (
        tester,
      ) async {
        await pump(tester, entry.key, canRetry: false);

        expect(find.text('Try again'), findsNothing);
      });
    }
  });

  group('every state', () {
    testWidgets('offers a way back to the Upload Manager', (tester) async {
      for (final status in CameraStatus.values) {
        final calls = await pump(tester, status);
        if (status == CameraStatus.initialising ||
            status == CameraStatus.paused ||
            status == CameraStatus.ready) {
          continue;
        }
        await tester.tap(find.text('Go to Upload Manager'));
        expect(calls, ['uploads'], reason: status.name);
      }
    });

    testWidgets('the close button also goes back', (tester) async {
      final calls = await pump(tester, CameraStatus.error);

      await tester.tap(find.byIcon(Icons.close_rounded));

      expect(calls, ['uploads']);
    });

    testWidgets('never shows raw exception text', (tester) async {
      for (final status in CameraStatus.values) {
        await pump(tester, status);
        expect(
          find.textContaining('Exception'),
          findsNothing,
          reason: status.name,
        );
        expect(
          find.textContaining('CameraFailure'),
          findsNothing,
          reason: status.name,
        );
        expect(find.textContaining('null'), findsNothing, reason: status.name);
      }
    });

    testWidgets('the title is announced as a heading', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, CameraStatus.permissionDenied);

      expect(find.bySemanticsLabel('Camera access needed'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('initialising shows a spinner and no actions', (tester) async {
      await pump(tester, CameraStatus.initialising);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.text('Go to Upload Manager'), findsNothing);
    });

    testWidgets('buttons are at least 48 dp tall', (tester) async {
      await pump(tester, CameraStatus.permissionDenied);

      for (final label in ['Allow camera', 'Go to Upload Manager']) {
        final button = find
            .ancestor(
              of: find.text(label),
              matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
            )
            .first;
        expect(
          tester.getSize(button).height,
          greaterThanOrEqualTo(48),
          reason: label,
        );
      }
    });

    testWidgets('survives 200 percent text and a small screen', (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      for (final status in CameraStatus.values) {
        await pump(tester, status, textScale: 2);
        expect(tester.takeException(), isNull, reason: status.name);
      }
    });
  });
}
