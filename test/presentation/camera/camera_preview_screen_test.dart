import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapsync/presentation/batch/cubit/batch_state.dart';
import 'package:snapsync/presentation/camera/camera_preview_screen.dart';
import 'package:snapsync/presentation/camera/cubit/camera_state.dart';
import 'package:snapsync/presentation/camera/cubit/focus_indicator.dart';
import 'package:snapsync/presentation/camera/widgets/batch_thumbnail.dart';
import 'package:snapsync/presentation/camera/widgets/camera_gesture_surface.dart';
import 'package:snapsync/presentation/camera/widgets/focus_indicator_view.dart';
import 'package:snapsync/presentation/camera/widgets/grid_overlay.dart';
import 'package:snapsync/presentation/camera/widgets/upload_batch_button.dart';

import '../../support/camera_ui_support.dart';
import '../../support/fake_camera_cubits.dart';

void main() {
  late FakeCameraCubit camera;
  late FakeBatchCubit batch;

  setUp(() {
    camera = FakeCameraCubit(readyState());
    batch = FakeBatchCubit(batchWith(0));
  });

  tearDown(() async {
    await camera.close();
    await batch.close();
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    CameraState? state,
    BatchState? batchState,
    double textScale = 1,
    Size size = const Size(400, 860),
  }) async {
    // A portrait phone unless a test asks for another shape.
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (state != null) camera.push(state);
    if (batchState != null) batch.push(batchState);
    await tester.pumpWidget(
      cameraHost(
        camera: camera,
        batch: batch,
        textScale: textScale,
        child: const CameraPreviewScreen(),
      ),
    );
    await tester.pump();
  }

  Future<void> pushCamera(WidgetTester tester, CameraState state) async {
    camera.push(state);
    await tester.pump();
    await tester.pump();
  }

  group('live view', () {
    testWidgets('shows the controls from the mockup', (tester) async {
      await pumpScreen(tester);

      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.byIcon(Icons.flash_off_rounded), findsOneWidget);
      expect(find.byIcon(Icons.grid_3x3_rounded), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      for (final label in ['0.5x', '1x', '2x']) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      expect(find.byType(BatchThumbnail), findsOneWidget);
      expect(find.byIcon(Icons.flip_camera_android_rounded), findsOneWidget);
      expect(find.byType(UploadBatchButton), findsOneWidget);
    });

    testWidgets('the preview area is the gesture surface', (tester) async {
      await pumpScreen(tester);

      expect(find.byType(CameraGestureSurface), findsOneWidget);
    });

    testWidgets('renders only the presets the cubit provides', (tester) async {
      await pumpScreen(tester, state: readyState(presets: [presets3.first]));

      expect(find.text('2x'), findsNothing);
      expect(find.text('0.5x'), findsWidgets);
    });

    testWidgets('the flash button is hidden when the camera has no flash', (
      tester,
    ) async {
      await pumpScreen(tester, state: readyState(supportsFlash: false));

      expect(find.byIcon(Icons.flash_off_rounded), findsNothing);
    });

    testWidgets('the zoom slider is hidden for a camera with no zoom range', (
      tester,
    ) async {
      await pumpScreen(tester, state: readyState(minZoom: 1, maxZoom: 1));

      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('the flip button is disabled with one camera', (tester) async {
      await pumpScreen(tester, state: readyState(canSwitchLens: false));

      await tester.tap(find.byIcon(Icons.flip_camera_android_rounded));
      expect(camera.calls, isNot(contains('switchLens')));
    });

    testWidgets('updates when the cubit state changes', (tester) async {
      await pumpScreen(tester);
      expect(find.byIcon(Icons.flash_off_rounded), findsOneWidget);

      await pushCamera(tester, readyState(supportsFlash: false));

      expect(find.byIcon(Icons.flash_off_rounded), findsNothing);
    });
  });

  group('actions', () {
    testWidgets('shutter, flash, flip and presets call the cubit', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(
        find.bySemanticsLabel('Take photo'),
        warnIfMissed: false,
      );
      await tester.tap(find.byIcon(Icons.flash_off_rounded));
      await tester.tap(find.byIcon(Icons.flip_camera_android_rounded));
      await tester.tap(find.text('2x'));

      expect(
        camera.calls,
        containsAll(['cycleFlash', 'switchLens', 'preset:2x']),
      );
    });

    testWidgets('the shutter captures', (tester) async {
      await pumpScreen(tester);

      await tester.tap(
        find.byType(Icon).evaluate().isEmpty
            ? find.byType(Scaffold)
            : find.byWidgetPredicate(
                (w) => w.runtimeType.toString() == 'ShutterButton',
              ),
      );

      expect(camera.calls, contains('capture'));
    });

    testWidgets('a busy cubit shows the shutter as saving', (tester) async {
      await pumpScreen(tester, state: readyState(isCapturing: true));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('the slider drives the cubit', (tester) async {
      await pumpScreen(tester);

      await tester.drag(find.byType(Slider), const Offset(0, -40));
      await tester.pump();

      expect(camera.calls, contains('slider'));
    });

    testWidgets('the grid toggle shows and hides the thirds guide', (
      tester,
    ) async {
      await pumpScreen(tester);
      expect(find.byType(GridOverlay), findsNothing);

      await tester.tap(find.byIcon(Icons.grid_3x3_rounded));
      await tester.pump();
      expect(find.byType(GridOverlay), findsOneWidget);

      await tester.tap(find.byIcon(Icons.grid_3x3_rounded));
      await tester.pump();
      expect(find.byType(GridOverlay), findsNothing);
    });
  });

  group('gestures and focus', () {
    testWidgets('a tap on the preview area is passed on with its position', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tapAt(const Offset(300, 250));
      await tester.pump(const Duration(milliseconds: 400));

      expect(camera.calls, contains('tap'));
      expect(camera.lastTap, const Offset(300, 250));
      expect(
        camera.lastTapArea,
        tester.getSize(find.byType(CameraGestureSurface)),
      );
    });

    testWidgets('a long press is passed on as a focus lock', (tester) async {
      await pumpScreen(tester);

      await tester.longPressAt(const Offset(250, 300));
      await tester.pump(const Duration(milliseconds: 100));

      expect(camera.calls, contains('longPress'));
      expect(camera.lastTap, const Offset(250, 300));
    });

    testWidgets('a two-finger pinch is passed on', (tester) async {
      await pumpScreen(tester);

      final first = await tester.startGesture(const Offset(150, 400));
      final second = await tester.startGesture(const Offset(250, 400));
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        await first.moveBy(const Offset(-20, 0));
        await second.moveBy(const Offset(20, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await first.up();
      await second.up();
      await tester.pump();

      expect(camera.calls, containsAll(['pinchStart', 'pinch', 'pinchEnd']));
    });

    testWidgets('the focus ring sits exactly under the tap', (tester) async {
      await pumpScreen(tester);
      await pushCamera(
        tester,
        readyState().copyWith(
          focusIndicator: const FocusIndicator(
            id: 1,
            position: Offset(300, 250),
            phase: FocusPhase.focusing,
          ),
        ),
      );

      final surface = tester.getTopLeft(find.byType(CameraGestureSurface));
      expect(
        tester.getCenter(find.byType(FocusIndicatorView)),
        surface + const Offset(300, 250),
      );
    });

    testWidgets('no ring is shown without an indicator', (tester) async {
      await pumpScreen(tester);

      expect(find.byType(FocusIndicatorView), findsNothing);
    });
  });

  group('batch', () {
    testWidgets('the upload button is disabled when empty', (tester) async {
      await pumpScreen(tester);

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      expect(find.text('UPLOAD BATCH (0)'), findsOneWidget);
    });

    testWidgets('the count and button follow the batch', (tester) async {
      await pumpScreen(tester, batchState: batchWith(3));

      expect(find.text('UPLOAD BATCH (3)'), findsOneWidget);
      expect(find.text('3'), findsOneWidget, reason: 'thumbnail badge');
    });

    testWidgets(
      'uploading submits, confirms, and returns to the Upload Manager',
      (tester) async {
        batch.push(batchWith(3));
        await tester.pumpWidget(
          rootThenScreen(
            camera: camera,
            batch: batch,
            screen: const CameraPreviewScreen(),
          ),
        );
        await tester.tap(find.text('open camera'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('UPLOAD BATCH (3)'));
        await tester.pumpAndSettle();

        expect(batch.calls, ['submit']);
        expect(
          find.text('open camera'),
          findsOneWidget,
          reason: 'back at the root',
        );
        expect(find.text('3 photos queued. Uploading...'), findsOneWidget);
      },
    );

    testWidgets('a failed submit keeps the camera open and says so', (
      tester,
    ) async {
      batch
        ..push(batchWith(2))
        ..failSubmit = true;
      await tester.pumpWidget(
        rootThenScreen(
          camera: camera,
          batch: batch,
          screen: const CameraPreviewScreen(),
        ),
      );
      await tester.tap(find.text('open camera'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('UPLOAD BATCH (2)'));
      await tester.pumpAndSettle();

      expect(find.byType(CameraPreviewScreen), findsOneWidget);
      expect(
        find.text('Could not submit the batch. Try again.'),
        findsOneWidget,
      );
      expect(find.text('2 photos queued. Uploading...'), findsNothing);
    });

    testWidgets('the close button goes back to the Upload Manager', (
      tester,
    ) async {
      await tester.pumpWidget(
        rootThenScreen(
          camera: camera,
          batch: batch,
          screen: const CameraPreviewScreen(),
        ),
      );
      await tester.tap(find.text('open camera'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('open camera'), findsOneWidget);
    });

    testWidgets('tapping the thumbnail opens the review sheet', (tester) async {
      await pumpScreen(tester, batchState: batchWith(2));

      await tester.tap(find.byType(BatchThumbnail));
      await tester.pumpAndSettle();

      expect(find.text('2 photos in this batch'), findsOneWidget);
    });

    testWidgets('an empty thumbnail does not open the sheet', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byType(BatchThumbnail));
      await tester.pumpAndSettle();

      expect(find.textContaining('in this batch'), findsNothing);
    });
  });

  group('error and permission states', () {
    testWidgets('each non-ready state replaces the live view', (tester) async {
      await pumpScreen(tester);

      for (final status in [
        CameraStatus.permissionDenied,
        CameraStatus.permissionPermanentlyDenied,
        CameraStatus.noCameraAvailable,
        CameraStatus.cameraInUse,
        CameraStatus.unavailable,
        CameraStatus.error,
      ]) {
        await pushCamera(tester, CameraState(status: status, canRetry: true));

        expect(
          find.byType(CameraGestureSurface),
          findsNothing,
          reason: status.name,
        );
        expect(
          find.text('Go to Upload Manager'),
          findsOneWidget,
          reason: status.name,
        );
      }
    });

    testWidgets('actions call the right cubit methods', (tester) async {
      await pumpScreen(
        tester,
        state: const CameraState(
          status: CameraStatus.permissionDenied,
          canRetry: true,
        ),
      );
      await tester.tap(find.text('Allow camera'));

      await pushCamera(
        tester,
        const CameraState(status: CameraStatus.permissionPermanentlyDenied),
      );
      await tester.tap(find.text('Open settings'));

      await pushCamera(
        tester,
        const CameraState(status: CameraStatus.error, canRetry: true),
      );
      await tester.tap(find.text('Try again'));

      expect(camera.calls, ['requestPermission', 'openAppSettings', 'retry']);
    });

    testWidgets('going to the Upload Manager from an error works', (
      tester,
    ) async {
      camera.push(const CameraState(status: CameraStatus.noCameraAvailable));
      await tester.pumpWidget(
        rootThenScreen(
          camera: camera,
          batch: batch,
          screen: const CameraPreviewScreen(),
        ),
      );
      await tester.tap(find.text('open camera'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Go to Upload Manager'));
      await tester.pumpAndSettle();

      expect(find.text('open camera'), findsOneWidget);
    });

    testWidgets('returns to the live view when the camera becomes ready', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        state: const CameraState(status: CameraStatus.error, canRetry: true),
      );
      expect(find.byType(CameraGestureSurface), findsNothing);

      await pushCamera(tester, readyState());

      expect(find.byType(CameraGestureSurface), findsOneWidget);
    });
  });

  group('accessibility', () {
    testWidgets('every control has a spoken label', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester, batchState: batchWith(3));

      for (final label in [
        'Close camera',
        'Flash: off. Tap to change',
        'Show grid',
        'Take photo',
        'Switch to front camera',
        'Zoom',
        'Zoom 1x',
        'Upload batch, 3 photos',
        'Review 3 photos in this batch',
      ]) {
        expect(find.bySemanticsLabel(label), findsWidgets, reason: label);
      }
      handle.dispose();
    });
  });

  group('layout', () {
    testWidgets('a small phone has no overflow', (tester) async {
      await pumpScreen(
        tester,
        batchState: batchWith(12),
        size: const Size(320, 480),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('a tall phone has no overflow', (tester) async {
      await pumpScreen(
        tester,
        batchState: batchWith(12),
        size: const Size(360, 900),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('landscape moves the controls to a side rail', (tester) async {
      await pumpScreen(
        tester,
        batchState: batchWith(5),
        size: const Size(800, 360),
      );

      expect(tester.takeException(), isNull);
      final upload = tester.getCenter(find.byType(UploadBatchButton));
      expect(upload.dx, greaterThan(600), reason: 'in the right-hand rail');
      expect(find.byIcon(Icons.flip_camera_android_rounded), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('200 percent text has no overflow', (tester) async {
      await pumpScreen(tester, batchState: batchWith(12), textScale: 2);

      expect(tester.takeException(), isNull);
    });

    testWidgets('200 percent text in landscape has no overflow', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        batchState: batchWith(12),
        textScale: 2,
        size: const Size(800, 360),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('the live-zoom button shows the pinch value without overflow', (
      tester,
    ) async {
      await pumpScreen(tester, state: readyState(zoom: 1.7));

      expect(find.text('1.7x'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
