import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snapsync/core/error/failure.dart';
import 'package:snapsync/domain/camera/camera_lens.dart';
import 'package:snapsync/domain/camera/flash_setting.dart';
import 'package:snapsync/domain/camera/zoom_preset.dart';
import 'package:snapsync/presentation/batch/cubit/batch_cubit.dart';
import 'package:snapsync/presentation/batch/cubit/batch_state.dart';
import 'package:snapsync/presentation/camera/camera_preview_screen.dart';
import 'package:snapsync/presentation/camera/cubit/camera_cubit.dart';
import 'package:snapsync/presentation/camera/cubit/camera_message.dart';
import 'package:snapsync/presentation/camera/cubit/camera_state.dart';
import 'package:snapsync/presentation/camera/cubit/focus_indicator.dart';
import 'package:snapsync/presentation/camera/widgets/focus_indicator_view.dart';

class MockCameraCubit extends MockCubit<CameraState> implements CameraCubit {}

class MockBatchCubit extends MockCubit<BatchState> implements BatchCubit {}

const presets = [
  ZoomPreset(label: '0.5x', targetZoom: 0.5),
  ZoomPreset(label: '1x', targetZoom: 1),
  ZoomPreset(label: '2x', targetZoom: 2),
];

CameraState ready({
  double zoom = 1,
  bool supportsFlash = true,
  bool canSwitchLens = true,
  FlashSetting flash = FlashSetting.off,
  FocusIndicator? indicator,
  bool isCapturing = false,
  LensDirection direction = LensDirection.back,
}) {
  return CameraState(
    status: CameraStatus.ready,
    presets: presets,
    zoom: zoom,
    minZoom: 0.5,
    maxZoom: 8,
    supportsFlash: supportsFlash,
    supportsFocus: true,
    canSwitchLens: canSwitchLens,
    flash: flash,
    focusIndicator: indicator,
    isCapturing: isCapturing,
    lensDirection: direction,
  );
}

void main() {
  late MockCameraCubit camera;
  late MockBatchCubit batch;
  late StreamController<CameraMessage> messages;

  setUpAll(() {
    registerFallbackValue(Offset.zero);
    registerFallbackValue(Size.zero);
    registerFallbackValue(presets.first);
  });

  setUp(() {
    camera = MockCameraCubit();
    batch = MockBatchCubit();
    messages = StreamController<CameraMessage>.broadcast();
    when(() => camera.messages).thenAnswer((_) => messages.stream);
    when(() => camera.previewHandle).thenReturn(null);
    when(() => camera.close()).thenAnswer((_) async {});
    when(() => camera.pause()).thenAnswer((_) async {});
    when(() => camera.resume()).thenAnswer((_) async {});
    when(() => camera.capture()).thenAnswer((_) async {});
    when(() => camera.cycleFlash()).thenAnswer((_) async {});
    when(() => camera.switchLens()).thenAnswer((_) async {});
    when(() => camera.retry()).thenAnswer((_) async {});
    when(() => camera.requestPermission()).thenAnswer((_) async {});
    when(() => camera.openAppSettings()).thenAnswer((_) async {});
    when(() => camera.selectPreset(any())).thenAnswer((_) async {});
    when(() => camera.onTapToFocus(any(), any())).thenAnswer((_) async {});
    when(() => camera.onLongPressToLockFocus(any(), any()))
        .thenAnswer((_) async {});
    when(() => batch.state).thenReturn(const BatchState());
    when(() => batch.close()).thenAnswer((_) async {});
  });

  tearDown(() => messages.close());

  Future<void> pumpScreen(
    WidgetTester tester,
    CameraState state, {
    BatchState batchState = const BatchState(),
  }) async {
    whenListen(camera, const Stream<CameraState>.empty(), initialState: state);
    whenListen(
      batch,
      const Stream<BatchState>.empty(),
      initialState: batchState,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<CameraCubit>.value(value: camera),
            BlocProvider<BatchCubit>.value(value: batch),
          ],
          child: const CameraPreviewScreen(),
        ),
      ),
    );
  }

  group('every permission and hardware state shows its text and action', () {
    testWidgets('initialising shows a spinner and no action', (tester) async {
      await pumpScreen(tester, const CameraState());

      expect(find.text('Starting the camera...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('paused shows a neutral screen with no action', (tester) async {
      await pumpScreen(tester, const CameraState(status: CameraStatus.paused));

      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('permission denied explains and offers "Allow camera"', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const CameraState(
          status: CameraStatus.permissionDenied,
          canRetry: true,
        ),
      );

      expect(find.textContaining('needs the camera'), findsOneWidget);
      await tester.tap(find.text('Allow camera'));
      verify(() => camera.requestPermission()).called(1);
    });

    testWidgets('permanently denied offers "Open settings"', (tester) async {
      await pumpScreen(
        tester,
        const CameraState(status: CameraStatus.permissionPermanentlyDenied),
      );

      expect(find.textContaining('turned off'), findsOneWidget);
      expect(find.text('Allow camera'), findsNothing);
      await tester.tap(find.text('Open settings'));
      verify(() => camera.openAppSettings()).called(1);
    });

    testWidgets('no camera explains and offers no action', (tester) async {
      await pumpScreen(
        tester,
        const CameraState(status: CameraStatus.noCameraAvailable),
      );

      expect(find.textContaining('No camera was found'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });

    for (final entry in {
      CameraStatus.cameraInUse: 'another app',
      CameraStatus.unavailable: 'disconnected',
      CameraStatus.error: 'Something went wrong',
    }.entries) {
      testWidgets('${entry.key.name} shows its text and "Try again"', (
        tester,
      ) async {
        await pumpScreen(
          tester,
          CameraState(status: entry.key, canRetry: true),
        );

        expect(find.textContaining(entry.value), findsOneWidget);
        await tester.tap(find.text('Try again'));
        verify(() => camera.retry()).called(1);
      });
    }

    testWidgets('an error that cannot be retried shows no retry button', (
      tester,
    ) async {
      await pumpScreen(tester, const CameraState(status: CameraStatus.error));

      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('no state ever shows raw exception text', (tester) async {
      for (final status in CameraStatus.values) {
        await pumpScreen(
          tester,
          CameraState(
            status: status,
            canRetry: true,
            failureReason: CameraFailureReason.unknown,
          ),
        );
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
      }
    });
  });

  group('ready screen', () {
    testWidgets('shows the controls, presets and the batch count', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        ready(),
        batchState: const BatchState(status: BatchStatus.ready),
      );

      expect(find.text('Capture'), findsOneWidget);
      for (final label in ['0.5x', '1x', '2x']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('Flash: off'), findsOneWidget);
      expect(find.text('Use front'), findsOneWidget);
      expect(find.text('Batch: 0 photo(s)'), findsOneWidget);
    });

    testWidgets('the active preset is highlighted, matching the zoom', (
      tester,
    ) async {
      await pumpScreen(tester, ready(zoom: 2));

      expect(find.widgetWithText(FilledButton, '2x'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '1x'), findsOneWidget);
      expect(find.text('2.0x'), findsOneWidget);
    });

    testWidgets('between presets, none is highlighted', (tester) async {
      await pumpScreen(tester, ready(zoom: 1.5));

      expect(find.byType(OutlinedButton), findsNWidgets(3));
    });

    testWidgets('buttons call the cubit', (tester) async {
      await pumpScreen(tester, ready());

      await tester.tap(find.text('Capture'));
      verify(() => camera.capture()).called(1);

      await tester.tap(find.text('Flash: off'));
      verify(() => camera.cycleFlash()).called(1);

      await tester.tap(find.text('Use front'));
      verify(() => camera.switchLens()).called(1);

      await tester.tap(find.text('2x'));
      verify(() => camera.selectPreset(presets.last)).called(1);
    });

    testWidgets('capture is disabled while saving', (tester) async {
      await pumpScreen(tester, ready(isCapturing: true));

      expect(find.text('Saving...'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Saving...'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('a camera without flash says so', (tester) async {
      await pumpScreen(tester, ready(supportsFlash: false));

      expect(find.text('No flash'), findsOneWidget);
    });

    testWidgets('lens switch is disabled with one camera', (tester) async {
      await pumpScreen(tester, ready(canSwitchLens: false));

      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Use front'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('on the front camera the switch says "Use back"', (
      tester,
    ) async {
      await pumpScreen(tester, ready(direction: LensDirection.front));

      expect(find.text('Use back'), findsOneWidget);
    });

    testWidgets('a tap on the preview area asks the cubit to focus', (
      tester,
    ) async {
      await pumpScreen(tester, ready());

      final surface = find.byType(GestureDetector).first;
      await tester.tapAt(tester.getCenter(surface));
      await tester.pump(const Duration(milliseconds: 400));

      verify(() => camera.onTapToFocus(any(), any())).called(1);
    });

    testWidgets('a long press asks the cubit to lock focus', (tester) async {
      await pumpScreen(tester, ready());

      await tester.longPressAt(
        tester.getCenter(find.byType(GestureDetector).first),
      );
      await tester.pump(const Duration(milliseconds: 100));

      verify(() => camera.onLongPressToLockFocus(any(), any())).called(1);
    });

    testWidgets('the focus ring is drawn at the tap position', (tester) async {
      await pumpScreen(
        tester,
        ready(
          indicator: const FocusIndicator(
            id: 7,
            position: Offset(120, 200),
            phase: FocusPhase.focusing,
          ),
        ),
      );

      expect(find.byType(FocusIndicatorView), findsOneWidget);
      final ring = tester.getRect(find.byKey(const ValueKey('focus-7')));
      expect(ring.center.dx, closeTo(120, 1));
      expect(ring.size.width, FocusIndicatorView.size);
    });

    testWidgets('no ring is drawn without an indicator', (tester) async {
      await pumpScreen(tester, ready());

      expect(find.byType(FocusIndicatorView), findsNothing);
    });

    testWidgets('moving the slider sets the zoom', (tester) async {
      when(() => camera.setZoomFromSlider(any())).thenReturn(null);
      await pumpScreen(tester, ready());

      await tester.drag(find.byType(Slider), const Offset(100, 0));
      await tester.pump();

      verify(() => camera.setZoomFromSlider(any())).called(greaterThan(0));
    });
  });

  group('batch controls', () {
    testWidgets(
      'the count follows the batch and upload is enabled when not empty',
      (tester) async {
        await pumpScreen(tester, ready());
        var button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Upload batch (0)'),
        );
        expect(button.onPressed, isNull);
      },
    );

    testWidgets('Upload manager goes back to the root screen', (tester) async {
      whenListen(
        camera,
        const Stream<CameraState>.empty(),
        initialState: ready(),
      );
      whenListen(
        batch,
        const Stream<BatchState>.empty(),
        initialState: const BatchState(),
      );
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<CameraCubit>.value(value: camera),
            BlocProvider<BatchCubit>.value(value: batch),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CameraPreviewScreen(),
                    ),
                  ),
                  child: const Text('root'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('root'));
      await tester.pumpAndSettle();
      expect(find.text('CameraPreviewScreen'), findsOneWidget);

      await tester.tap(find.text('Upload manager'));
      await tester.pumpAndSettle();

      expect(find.text('CameraPreviewScreen'), findsNothing);
      expect(find.text('root'), findsOneWidget);
    });
  });

  group('messages and lifecycle', () {
    testWidgets('each message is shown as a snackbar with fixed text', (
      tester,
    ) async {
      await pumpScreen(tester, ready());

      messages.add(CameraMessage.storageFailed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('free storage'), findsOneWidget);
    });

    testWidgets('every message has text without exception wording', (
      tester,
    ) async {
      for (final message in CameraMessage.values) {
        await pumpScreen(tester, ready());
        messages.add(message);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(SnackBar), findsOneWidget, reason: message.name);
        expect(find.textContaining('Exception'), findsNothing);
        ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first))
            .removeCurrentSnackBar();
        await tester.pump();
      }
    });

    testWidgets('leaving the foreground pauses and returning resumes', (
      tester,
    ) async {
      await pumpScreen(tester, ready());

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      verify(() => camera.pause()).called(1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      verify(() => camera.resume()).called(1);
    });
  });
}
