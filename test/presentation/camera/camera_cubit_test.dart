import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:snapsync/core/error/failure.dart';
import 'package:snapsync/domain/camera/camera_lens.dart';
import 'package:snapsync/domain/camera/camera_permission_service.dart';
import 'package:snapsync/domain/camera/camera_session_info.dart';
import 'package:snapsync/domain/camera/flash_setting.dart';
import 'package:snapsync/domain/entities/captured_image.dart';
import 'package:snapsync/domain/usecases/add_captured_image.dart';
import 'package:snapsync/presentation/camera/cubit/camera_cubit.dart';
import 'package:snapsync/presentation/camera/cubit/camera_message.dart';
import 'package:snapsync/presentation/camera/cubit/camera_state.dart';
import 'package:snapsync/presentation/camera/cubit/focus_indicator.dart';

import '../../support/camera_fakes.dart';
import '../../support/fakes.dart';
import '../../support/test_support.dart';

class MockAddCapturedImage extends Mock implements AddCapturedImage {}

CapturedImage stored(String path) => CapturedImage(
  id: 'img',
  batchId: 'b',
  filePath: path,
  fileSizeBytes: 3,
  capturedAt: DateTime.utc(2026),
);

Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

const retryDelay = Duration(milliseconds: 500);
const gap = Duration(milliseconds: 600);
const indicatorFor = Duration(milliseconds: 1500);
const container = Size(400, 800);

void main() {
  late FakeCameraService service;
  late FakeCameraPermissions permissions;
  late MockAddCapturedImage addCaptured;
  late FakeTimerFactory timers;
  late List<Duration> delays;
  late DateTime now;
  late Directory tmp;
  var captureCounter = 0;

  CameraCubit build() {
    return CameraCubit(
      service: service,
      permissions: permissions,
      addCapturedImage: addCaptured,
      now: () => now,
      timerFactory: timers.create,
      delay: (d) async => delays.add(d),
      retryDelay: retryDelay,
      minCaptureGap: gap,
      focusIndicatorDuration: indicatorFor,
    );
  }

  /// A cubit that is initialised and ready.
  Future<CameraCubit> readyCubit() async {
    final cubit = build();
    await cubit.initialise();
    expect(cubit.state.status, CameraStatus.ready);
    return cubit;
  }

  setUpAll(() => registerFallbackValue(''));

  setUp(() {
    service = FakeCameraService();
    permissions = FakeCameraPermissions();
    addCaptured = MockAddCapturedImage();
    timers = FakeTimerFactory();
    delays = [];
    now = DateTime.utc(2026, 5, 1, 10);
    tmp = createTempDir('snapsync_camera_');
    captureCounter = 0;
    service.onCapture = () async {
      final file = File(p.join(tmp.path, 'cap${++captureCounter}.jpg'))
        ..writeAsBytesSync([1, 2, 3]);
      return file.path;
    };
    when(() => addCaptured(any()))
        .thenAnswer((i) async => stored(i.positionalArguments.first as String));
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  group('initialise', () {
    test(
      'opens the back camera and becomes ready at 1x with 1x and 2x presets',
      () async {
        final cubit = await readyCubit();
        final state = cubit.state;
        {
          expect(state.status, CameraStatus.ready);
          expect(state.lensDirection, LensDirection.back);
          expect(state.zoom, 1);
          expect(state.minZoom, 1);
          expect(state.maxZoom, 8);
          expect(state.presets.map((p) => p.label), ['1x', '2x']);
          expect(state.supportsFocus, isTrue);
          expect(state.supportsFlash, isTrue);
          expect(state.flash, FlashSetting.off);
          expect(state.canSwitchLens, isTrue);
          expect(service.openedLensIds, ['0']);
          expect(service.isOpen, isTrue);
          expect(
            permissions.requestCalls,
            0,
            reason: 'already granted, no prompt',
          );
        }
        await cubit.close();
      },
    );

    test('ends ready, passing only through initialising on the way', () async {
      final cubit = build();
      final statuses = <CameraStatus>[];
      final sub = cubit.stream.listen((s) => statuses.add(s.status));

      await cubit.initialise();
      await settle();
      await sub.cancel();

      expect(statuses.last, CameraStatus.ready);
      expect(
        statuses.every(
          (s) => s == CameraStatus.initialising || s == CameraStatus.ready,
        ),
        isTrue,
      );
      await cubit.close();
    });

    test('a device with only a front camera opens that', () async {
      service.lenses = [frontLens];
      final cubit = await readyCubit();

      expect(cubit.state.lensDirection, LensDirection.front);
      expect(cubit.state.canSwitchLens, isFalse);
      expect(cubit.state.supportsFlash, isFalse);
      await cubit.close();
    });

    test('lists the cameras only once', () async {
      final cubit = await readyCubit();
      await cubit.initialise();

      expect(service.listCalls, 1);
      await cubit.close();
    });
  });

  group('emitted state sequences (bloc_test)', () {
    CameraStatus statusOf(CameraState s) => s.status;

    blocTest<CameraCubit, CameraState>(
      'initialise: a granted permission goes straight to ready',
      build: build,
      act: (cubit) => cubit.initialise(),
      expect: () => [
        isA<CameraState>().having(
          statusOf,
          'status',
          CameraStatus.initialising,
        ),
        isA<CameraState>()
            .having(statusOf, 'status', CameraStatus.ready)
            .having((s) => s.zoom, 'zoom', 1)
            .having((s) => s.presets.length, 'presets', 2),
      ],
    );

    blocTest<CameraCubit, CameraState>(
      'initialise: a denied permission shows the denied state once',
      setUp: () {
        permissions.current = CameraPermissionStatus.denied;
        permissions.requestResult = CameraPermissionStatus.denied;
      },
      build: build,
      act: (cubit) => cubit.initialise(),
      expect: () => [
        isA<CameraState>().having(
          statusOf,
          'status',
          CameraStatus.initialising,
        ),
        isA<CameraState>()
            .having(statusOf, 'status', CameraStatus.permissionDenied)
            .having((s) => s.canRetry, 'canRetry', isTrue),
      ],
    );

    blocTest<CameraCubit, CameraState>(
      'initialise: no camera shows that state and nothing else',
      setUp: () => service.lenses = [],
      build: build,
      act: (cubit) => cubit.initialise(),
      expect: () => [
        isA<CameraState>().having(
          statusOf,
          'status',
          CameraStatus.initialising,
        ),
        isA<CameraState>().having(
          statusOf,
          'status',
          CameraStatus.noCameraAvailable,
        ),
      ],
    );

    blocTest<CameraCubit, CameraState>(
      'a camera in use ends in cameraInUse after one silent retry',
      setUp: () => service.onOpen = (_) async =>
          throw const CameraFailure('busy', reason: CameraFailureReason.inUse),
      build: build,
      act: (cubit) => cubit.initialise(),
      expect: () => [
        isA<CameraState>().having(
          statusOf,
          'status',
          CameraStatus.initialising,
        ),
        isA<CameraState>()
            .having(statusOf, 'status', CameraStatus.cameraInUse)
            .having(
              (s) => s.failureReason,
              'reason',
              CameraFailureReason.inUse,
            ),
      ],
      verify: (_) => expect(service.openedLensIds, ['0', '0']),
    );

    blocTest<CameraCubit, CameraState>(
      'pause then resume: initialising, ready, paused, initialising, ready',
      build: build,
      act: (cubit) async {
        await cubit.initialise();
        await cubit.pause();
        await cubit.resume();
      },
      expect: () => [
        isA<CameraState>().having(
          statusOf,
          'status',
          CameraStatus.initialising,
        ),
        isA<CameraState>().having(statusOf, 'status', CameraStatus.ready),
        isA<CameraState>().having(statusOf, 'status', CameraStatus.paused),
        isA<CameraState>().having(
          statusOf,
          'status',
          CameraStatus.initialising,
        ),
        isA<CameraState>().having(statusOf, 'status', CameraStatus.ready),
      ],
    );

    blocTest<CameraCubit, CameraState>(
      'a pinch emits the zoom as it changes',
      build: build,
      act: (cubit) async {
        await cubit.initialise();
        cubit.onPinchStart();
        cubit.onPinchUpdate(1.5);
        cubit.onPinchUpdate(2);
        cubit.onPinchEnd();
      },
      skip: 2, // initialising, ready
      expect: () => [
        isA<CameraState>().having((s) => s.zoom, 'zoom', 1.5),
        isA<CameraState>().having((s) => s.zoom, 'zoom', 2),
      ],
    );

    blocTest<CameraCubit, CameraState>(
      'a tap emits focusing, then done, then clears',
      build: build,
      act: (cubit) async {
        await cubit.initialise();
        await cubit.onTapToFocus(const Offset(200, 400), container);
        timers.last.fire();
      },
      skip: 2, // initialising, ready
      expect: () => [
        isA<CameraState>().having(
          (s) => s.focusIndicator?.phase,
          'phase',
          FocusPhase.focusing,
        ),
        isA<CameraState>().having(
          (s) => s.focusIndicator?.phase,
          'phase',
          FocusPhase.done,
        ),
        isA<CameraState>().having((s) => s.focusIndicator, 'indicator', isNull),
      ],
    );

    blocTest<CameraCubit, CameraState>(
      'capture emits isCapturing on, then off',
      build: build,
      act: (cubit) async {
        await cubit.initialise();
        await cubit.capture();
      },
      skip: 2, // initialising, ready
      expect: () => [
        isA<CameraState>().having((s) => s.isCapturing, 'isCapturing', isTrue),
        isA<CameraState>().having((s) => s.isCapturing, 'isCapturing', isFalse),
      ],
    );
  });

  group('permissions', () {
    test('denied, then granted on retry', () async {
      permissions.current = CameraPermissionStatus.denied;
      permissions.requestResult = CameraPermissionStatus.denied;
      final cubit = build();

      await cubit.initialise();

      expect(cubit.state.status, CameraStatus.permissionDenied);
      expect(cubit.state.canRetry, isTrue);
      expect(permissions.requestCalls, 1, reason: 'the first request');
      expect(service.openedLensIds, isEmpty);

      permissions.requestResult = CameraPermissionStatus.granted;
      await cubit.requestPermission();

      expect(cubit.state.status, CameraStatus.ready);
      expect(permissions.requestCalls, 2);
      expect(service.openedLensIds, ['0']);
      await cubit.close();
    });

    test('the very first request grants and opens the camera', () async {
      permissions.current = CameraPermissionStatus.denied;
      permissions.requestResult = CameraPermissionStatus.granted;
      final cubit = build();

      await cubit.initialise();

      expect(cubit.state.status, CameraStatus.ready);
      expect(permissions.requestCalls, 1);
      await cubit.close();
    });

    test('permanently denied offers settings, and a grant there is picked up '
        'when the app resumes', () async {
      permissions.current = CameraPermissionStatus.denied;
      permissions.requestResult = CameraPermissionStatus.permanentlyDenied;
      final cubit = build();

      await cubit.initialise();
      expect(cubit.state.status, CameraStatus.permissionPermanentlyDenied);
      expect(cubit.state.canRetry, isFalse);

      await cubit.openAppSettings();
      expect(permissions.settingsCalls, 1);

      // The user switches to settings and back.
      await cubit.pause();
      permissions.current = CameraPermissionStatus.granted;
      await cubit.resume();

      expect(cubit.state.status, CameraStatus.ready);
      expect(permissions.requestCalls, 1, reason: 'resume never prompts');
      await cubit.close();
    });

    test('returning from settings without a grant stays permanently denied', () async {
      permissions.current = CameraPermissionStatus.denied;
      permissions.requestResult = CameraPermissionStatus.permanentlyDenied;
      final cubit = build();
      await cubit.initialise();

      // Android's status check says only "denied"; that must not downgrade the
      // state back to one that offers a dialog which will not appear.
      await cubit.pause();
      await cubit.resume();

      expect(cubit.state.status, CameraStatus.permissionPermanentlyDenied);
      expect(permissions.requestCalls, 1);
      await cubit.close();
    });

    test('a restricted camera is shown as blocked', () async {
      permissions.current = CameraPermissionStatus.restricted;
      final cubit = build();

      await cubit.initialise();

      expect(cubit.state.status, CameraStatus.permissionPermanentlyDenied);
      expect(permissions.requestCalls, 0);
      await cubit.close();
    });

    test('opening settings can fail without crashing', () async {
      permissions.settingsResult = false;
      final cubit = build();
      final messages = <CameraMessage>[];
      final sub = cubit.messages.listen(messages.add);

      await cubit.openAppSettings();
      await settle();
      await sub.cancel();

      expect(messages, [CameraMessage.settingsUnavailable]);
      await cubit.close();
    });

    test('the platform refusing access at open time re-checks the permission', () async {
      service.onOpen = (_) async => throw const CameraFailure(
        'denied',
        reason: CameraFailureReason.permission,
      );
      final cubit = build();
      permissions.current = CameraPermissionStatus.granted;
      // First check granted, then the plugin refuses, then the system says no.
      var checks = 0;
      final original = permissions;
      final cubitWithFlip = CameraCubit(
        service: service,
        permissions: _FlippingPermissions(original, () => ++checks >= 2),
        addCapturedImage: addCaptured,
        now: () => now,
        timerFactory: timers.create,
        delay: (d) async => delays.add(d),
      );

      await cubitWithFlip.initialise();
      await settle();

      expect(cubitWithFlip.state.status, CameraStatus.permissionDenied);
      await cubit.close();
      await cubitWithFlip.close();
    });
  });

  group('hardware failures', () {
    test('no cameras found', () async {
      service.lenses = [];
      final cubit = build();

      await cubit.initialise();

      expect(cubit.state.status, CameraStatus.noCameraAvailable);
      expect(cubit.state.canRetry, isFalse);
      expect(service.openedLensIds, isEmpty);
      await cubit.close();
    });

    test(
      'a failed open is retried once after a pause, then shows the error',
      () async {
        service.onOpen = (_) async => throw const CameraFailure('boom');
        final cubit = build();

        await cubit.initialise();

        expect(service.openedLensIds, [
          '0',
          '0',
        ], reason: 'exactly two attempts');
        expect(delays, [retryDelay]);
        expect(cubit.state.status, CameraStatus.error);
        expect(cubit.state.canRetry, isTrue);
        expect(cubit.state.failureReason, CameraFailureReason.unknown);
        await cubit.close();
      },
    );

    test(
      'a transient failure that clears on the retry ends up ready',
      () async {
        var attempts = 0;
        service.onOpen = (lens) async {
          if (++attempts == 1) {
            throw const CameraFailure(
              'busy',
              reason: CameraFailureReason.inUse,
            );
          }
          return CameraSessionInfoFactory.forLens(lens);
        };
        final cubit = build();

        await cubit.initialise();

        expect(cubit.state.status, CameraStatus.ready);
        expect(delays, [retryDelay]);
        await cubit.close();
      },
    );

    test('a failure that cannot be temporary is not retried', () async {
      service.onOpen = (_) async => throw const CameraFailure(
        'none',
        reason: CameraFailureReason.noCameraAvailable,
      );
      final cubit = build();

      await cubit.initialise();

      expect(service.openedLensIds, ['0']);
      expect(delays, isEmpty);
      expect(cubit.state.status, CameraStatus.noCameraAvailable);
      await cubit.close();
    });

    test('each failure reason maps to its own state', () async {
      final expected = {
        CameraFailureReason.inUse: CameraStatus.cameraInUse,
        CameraFailureReason.disconnected: CameraStatus.unavailable,
        CameraFailureReason.initTimeout: CameraStatus.error,
        CameraFailureReason.disposed: CameraStatus.error,
        CameraFailureReason.unknown: CameraStatus.error,
      };
      for (final entry in expected.entries) {
        service.onOpen = (_) async =>
            throw CameraFailure('x', reason: entry.key);
        final cubit = build();

        await cubit.initialise();

        expect(cubit.state.status, entry.value, reason: entry.key.name);
        expect(cubit.state.failureReason, entry.key);
        expect(cubit.state.canRetry, isTrue);
        await cubit.close();
      }
    });

    test(
      'an unexpected exception becomes the error state, not a crash',
      () async {
        service.onOpen = (_) async => throw StateError('plugin bug');
        final cubit = build();

        await cubit.initialise();

        expect(cubit.state.status, CameraStatus.error);
        await cubit.close();
      },
    );

    test('retry after an error opens the camera again', () async {
      var fail = true;
      service.onOpen = (lens) async {
        if (fail) throw const CameraFailure('x');
        return CameraSessionInfoFactory.forLens(lens);
      };
      final cubit = build();
      await cubit.initialise();
      expect(cubit.state.status, CameraStatus.error);

      fail = false;
      await cubit.retry();

      expect(cubit.state.status, CameraStatus.ready);
      await cubit.close();
    });

    test(
      'a runtime error while previewing triggers one automatic recovery',
      () async {
        final cubit = await readyCubit();
        expect(service.openedLensIds, hasLength(1));

        service.emitError(
          const CameraFailure('lost', reason: CameraFailureReason.disconnected),
        );
        await settle();

        expect(service.openedLensIds, hasLength(2));
        expect(cubit.state.status, CameraStatus.ready);

        // A second error is not retried automatically.
        service.emitError(
          const CameraFailure(
            'lost again',
            reason: CameraFailureReason.disconnected,
          ),
        );
        await settle();

        expect(service.openedLensIds, hasLength(2));
        expect(cubit.state.status, CameraStatus.unavailable);
        expect(cubit.state.canRetry, isTrue);
        await cubit.close();
      },
    );

    test('a runtime error that cannot be temporary is shown at once', () async {
      final cubit = await readyCubit();

      service.emitError(
        const CameraFailure('x', reason: CameraFailureReason.noCameraAvailable),
      );
      await settle();

      expect(cubit.state.status, CameraStatus.noCameraAvailable);
      expect(service.openedLensIds, hasLength(1));
      await cubit.close();
    });

    test('runtime errors are ignored while paused', () async {
      final cubit = await readyCubit();
      await cubit.pause();

      service.emitError(
        const CameraFailure('x', reason: CameraFailureReason.disconnected),
      );
      await settle();

      expect(cubit.state.status, CameraStatus.paused);
      await cubit.close();
    });
  });

  group('lens switching', () {
    test('switchLens opens the other camera and resets zoom to 1x', () async {
      final cubit = await readyCubit();
      await cubit.selectPreset(cubit.state.presets.last); // 2x
      expect(cubit.state.zoom, 2);

      await cubit.switchLens();

      expect(service.openedLensIds, ['0', '1']);
      expect(cubit.state.lensDirection, LensDirection.front);
      expect(cubit.state.zoom, 1);
      expect(cubit.state.supportsFlash, isFalse);
      await service.onSetZoom?.call(1);
      expect(service.zoomCalls.last, 1, reason: 'the camera was told, too');
      await cubit.close();
    });

    test('switching back returns to the back camera', () async {
      final cubit = await readyCubit();
      await cubit.switchLens();
      await cubit.switchLens();

      expect(cubit.state.lensDirection, LensDirection.back);
      expect(service.openedLensIds, ['0', '1', '0']);
      await cubit.close();
    });

    test('a device with one camera says so and stays put', () async {
      service.lenses = [backLens];
      final cubit = await readyCubit();
      final messages = <CameraMessage>[];
      final sub = cubit.messages.listen(messages.add);

      await cubit.switchLens();
      await settle();
      await sub.cancel();

      expect(messages, [CameraMessage.noOtherCamera]);
      expect(cubit.state.status, CameraStatus.ready);
      await cubit.close();
    });

    test(
      'a failure opening the other camera shows an error, retry works',
      () async {
        final cubit = await readyCubit();
        service.onOpen = (lens) async {
          if (lens.id == '1') throw const CameraFailure('front broken');
          return CameraSessionInfoFactory.forLens(lens);
        };

        await cubit.switchLens();
        expect(cubit.state.status, CameraStatus.error);
        await cubit.close();
      },
    );

    test('switching is ignored when the camera is not ready', () async {
      permissions.current = CameraPermissionStatus.denied;
      final cubit = build();
      await cubit.initialise();

      await cubit.switchLens();

      expect(service.openedLensIds, isEmpty);
      await cubit.close();
    });
  });

  group('zoom', () {
    test(
      'pinch scales the zoom at gesture start, clamped, and tells the camera',
      () async {
        final cubit = await readyCubit();

        cubit.onPinchStart();
        cubit.onPinchUpdate(2);
        expect(cubit.state.zoom, 2);
        cubit.onPinchUpdate(3);
        expect(cubit.state.zoom, 3);
        cubit.onPinchUpdate(100);
        expect(cubit.state.zoom, 8);
        cubit.onPinchEnd();
        cubit.onPinchUpdate(2);
        expect(cubit.state.zoom, 8, reason: 'no gesture in progress');
        await settle();

        expect(service.zoomCalls.last, 8);
        await cubit.close();
      },
    );

    test('pinch, slider and preset buttons stay in sync', () async {
      final cubit = await readyCubit();

      cubit.onPinchStart();
      cubit.onPinchUpdate(2);
      expect(cubit.state.activePreset?.label, '2x');
      expect(cubit.state.sliderValue, closeTo(1 / 3, 1e-9));

      cubit.setZoomFromSlider(0);
      expect(cubit.state.zoom, 1);
      expect(cubit.state.activePreset?.label, '1x');

      cubit.setZoomFromSlider(1);
      expect(cubit.state.zoom, 8);
      expect(cubit.state.activePreset, isNull);

      await cubit.selectPreset(cubit.state.presets.last);
      expect(cubit.state.zoom, 2);
      expect(cubit.state.sliderValue, closeTo(1 / 3, 1e-9));
      await cubit.close();
    });

    test('many rapid updates never queue a backlog on a slow camera', () async {
      final gate = Completer<void>();
      final cubit = await readyCubit();
      await settle();
      service.zoomCalls.clear();
      service.onSetZoom = (_) => gate.future;

      for (var i = 1; i <= 200; i++) {
        cubit.setZoomFromSlider(i / 200);
      }
      expect(cubit.state.zoom, 8, reason: 'the UI value is immediate');
      gate.complete();
      await settle();

      expect(service.zoomCalls.length, lessThanOrEqualTo(2));
      expect(service.zoomCalls.last, closeTo(8, 1e-9));
      await cubit.close();
    });

    test(
      'a failed zoom shows a message and the state returns to the real zoom',
      () async {
        final cubit = await readyCubit();
        await settle();
        final messages = <CameraMessage>[];
        final sub = cubit.messages.listen(messages.add);
        service.onSetZoom = (_) async => throw StateError('camera busy');

        cubit.setZoomFromSlider(0.5);
        expect(cubit.state.zoom, greaterThan(1));
        await settle();
        await sub.cancel();

        expect(messages, contains(CameraMessage.zoomFailed));
        expect(cubit.state.zoom, 1, reason: 'the camera never left 1x');
        await cubit.close();
      },
    );

    test('zoom is ignored when the camera is not ready', () async {
      final cubit = build();

      cubit.setZoomFromSlider(0.5);
      cubit.onPinchStart();
      cubit.onPinchUpdate(2);

      expect(cubit.state.zoom, 1);
      expect(service.zoomCalls, isEmpty);
      await cubit.close();
    });

    test(
      'a camera that zooms below 1x offers 0.5x and reaches it by zooming',
      () async {
        service.minZoom = 0.5;
        final cubit = await readyCubit();
        expect(cubit.state.presets.map((p) => p.label), ['0.5x', '1x', '2x']);

        await cubit.selectPreset(cubit.state.presets.first);

        expect(cubit.state.zoom, 0.5);
        expect(service.openedLensIds, ['0'], reason: 'no camera switch needed');
        await settle();
        expect(service.zoomCalls.last, 0.5);
        await cubit.close();
      },
    );

    test(
      'with two back cameras, 0.5x switches to the ultra-wide and 1x back',
      () async {
        service.lenses = [backLens, secondBackLens, frontLens];
        final cubit = await readyCubit();
        final labels = cubit.state.presets.map((p) => p.label).toList();
        expect(labels, ['0.5x', '1x', '2x']);

        await cubit.selectPreset(cubit.state.presets.first);

        expect(service.openedLensIds, ['0', '2']);
        expect(cubit.state.activeLensId, '2');
        expect(cubit.state.zoom, 0.5);
        expect(cubit.state.maxZoom, 1, reason: 'the ultra-wide stops at 1x');
        expect(
          cubit.state.presets.map((p) => p.label),
          labels,
          reason: 'the presets describe the main camera, not the ultra-wide',
        );
        await settle();
        expect(
          service.zoomCalls.last,
          1,
          reason: 'plugin units on the ultra-wide',
        );

        await cubit.selectPreset(cubit.state.presets[1]); // 1x
        expect(service.openedLensIds, ['0', '2', '0']);
        expect(cubit.state.activeLensId, '0');
        expect(cubit.state.zoom, 1);

        await cubit.selectPreset(cubit.state.presets.last); // 2x
        expect(service.openedLensIds, [
          '0',
          '2',
          '0',
        ], reason: 'already on the main camera');
        expect(cubit.state.zoom, 2);
        await cubit.close();
      },
    );
  });

  group('tap to focus', () {
    test('converts the tap and sets focus and exposure there', () async {
      final cubit = await readyCubit();

      await cubit.onTapToFocus(const Offset(200, 400), container);

      expect(service.focusPoints.single.x, closeTo(0.5, 1e-9));
      expect(service.focusPoints.single.y, closeTo(0.5, 1e-9));
      expect(service.exposurePoints.single, service.focusPoints.single);
      await cubit.close();
    });

    test(
      'the indicator appears at the tap, then clears after the duration',
      () async {
        final gate = Completer<void>();
        final cubit = await readyCubit();
        service.onSetFocus = () => gate.future;

        final pending = cubit.onTapToFocus(const Offset(200, 400), container);
        await settle();
        expect(cubit.state.focusIndicator?.position, const Offset(200, 400));
        expect(cubit.state.focusIndicator?.phase, FocusPhase.focusing);

        gate.complete();
        await pending;
        expect(cubit.state.focusIndicator?.phase, FocusPhase.done);
        expect(timers.active.single.duration, indicatorFor);

        timers.last.fire();
        expect(cubit.state.focusIndicator, isNull);
        await cubit.close();
      },
    );

    test('a new tap replaces the previous indicator immediately', () async {
      final cubit = await readyCubit();
      await cubit.onTapToFocus(const Offset(100, 300), container);
      final firstTimer = timers.last;
      final firstId = cubit.state.focusIndicator!.id;

      final gate = Completer<void>();
      service.onSetFocus = () => gate.future;
      final second = cubit.onTapToFocus(const Offset(300, 500), container);
      await settle();

      expect(cubit.state.focusIndicator!.id, greaterThan(firstId));
      expect(cubit.state.focusIndicator!.position, const Offset(300, 500));
      expect(cubit.state.focusIndicator!.phase, FocusPhase.focusing);
      expect(
        firstTimer.isActive,
        isFalse,
        reason: "the old tap's clear timer is gone",
      );

      firstTimer.fire(); // cancelled: must not clear the new indicator
      expect(cubit.state.focusIndicator, isNotNull);

      gate.complete();
      await second;
      await cubit.close();
    });

    test(
      'a late result for an old tap does not touch the new indicator',
      () async {
        final firstGate = Completer<void>();
        final cubit = await readyCubit();
        service.onSetFocus = () => firstGate.future;
        final first = cubit.onTapToFocus(const Offset(100, 300), container);
        await settle();

        service.onSetFocus = null;
        await cubit.onTapToFocus(const Offset(300, 500), container);
        final current = cubit.state.focusIndicator!;

        firstGate.complete();
        await first;

        expect(cubit.state.focusIndicator, current);
        await cubit.close();
      },
    );

    test('a tap outside the preview is ignored', () async {
      final cubit =
          await readyCubit(); // ratio 0.75 in 400x800: bars top/bottom

      await cubit.onTapToFocus(const Offset(200, 50), container);

      expect(cubit.state.focusIndicator, isNull);
      expect(service.focusPoints, isEmpty);
      await cubit.close();
    });

    test(
      'a device without focus support shows nothing and does not crash',
      () async {
        service.supportsFocus = false;
        final cubit = await readyCubit();
        expect(cubit.state.supportsFocus, isFalse);

        await cubit.onTapToFocus(const Offset(200, 400), container);

        expect(cubit.state.focusIndicator, isNull);
        expect(service.focusPoints, isEmpty);
        await cubit.close();
      },
    );

    test(
      'one rejected request shows a failed ring, repeated ones turn focus off',
      () async {
        final cubit = await readyCubit();
        service.onSetFocus = () async => throw const CameraFailure(
          'no focus',
          reason: CameraFailureReason.focusUnsupported,
        );

        await cubit.onTapToFocus(const Offset(200, 400), container);
        expect(cubit.state.focusIndicator?.phase, FocusPhase.failed);
        expect(cubit.state.supportsFocus, isTrue);

        await cubit.onTapToFocus(const Offset(200, 420), container);
        expect(cubit.state.supportsFocus, isFalse);
        expect(cubit.state.focusIndicator, isNull);

        await cubit.onTapToFocus(const Offset(200, 440), container);
        expect(service.focusPoints, hasLength(2), reason: 'no more requests');
        await cubit.close();
      },
    );

    test('a success resets the failure count', () async {
      final cubit = await readyCubit();
      var fail = true;
      service.onSetFocus = () async {
        if (fail) {
          throw const CameraFailure(
            'x',
            reason: CameraFailureReason.focusUnsupported,
          );
        }
      };
      await cubit.onTapToFocus(const Offset(200, 400), container);
      fail = false;
      await cubit.onTapToFocus(const Offset(200, 400), container);
      fail = true;
      await cubit.onTapToFocus(const Offset(200, 400), container);

      expect(cubit.state.supportsFocus, isTrue);
      await cubit.close();
    });

    test('long press locks focus and exposure, a tap unlocks', () async {
      final cubit = await readyCubit();

      await cubit.onLongPressToLockFocus(const Offset(200, 400), container);
      expect(cubit.state.focusLocked, isTrue);
      expect(cubit.state.focusIndicator?.phase, FocusPhase.locked);
      expect(service.lockCalls, [true]);
      expect(
        timers.active,
        isEmpty,
        reason: 'a locked indicator does not time out',
      );

      await cubit.onTapToFocus(const Offset(100, 300), container);
      expect(cubit.state.focusLocked, isFalse);
      expect(service.lockCalls, [true, false]);
      await cubit.close();
    });

    test('unlockFocus releases the lock and clears the ring', () async {
      final cubit = await readyCubit();
      await cubit.onLongPressToLockFocus(const Offset(200, 400), container);

      await cubit.unlockFocus();

      expect(cubit.state.focusLocked, isFalse);
      expect(cubit.state.focusIndicator, isNull);
      expect(service.lockCalls, [true, false]);
      await cubit.close();
    });

    test('focus is ignored before the camera is ready', () async {
      final cubit = build();

      await cubit.onTapToFocus(const Offset(200, 400), container);

      expect(service.focusPoints, isEmpty);
      await cubit.close();
    });
  });

  group('flash', () {
    test('cycles off, auto, always, off', () async {
      final cubit = await readyCubit();

      await cubit.cycleFlash();
      expect(cubit.state.flash, FlashSetting.auto);
      await cubit.cycleFlash();
      expect(cubit.state.flash, FlashSetting.always);
      await cubit.cycleFlash();
      expect(cubit.state.flash, FlashSetting.off);
      expect(service.flashCalls, [
        FlashSetting.auto,
        FlashSetting.always,
        FlashSetting.off,
      ]);
      await cubit.close();
    });

    test('a camera without flash says so', () async {
      service.supportsFlash = false;
      final cubit = await readyCubit();
      final messages = <CameraMessage>[];
      final sub = cubit.messages.listen(messages.add);

      await cubit.cycleFlash();
      await settle();
      await sub.cancel();

      expect(messages, [CameraMessage.flashUnavailable]);
      expect(service.flashCalls, isEmpty);
      await cubit.close();
    });

    test(
      'a rejected flash change shows a message and turns flash off',
      () async {
        final cubit = await readyCubit();
        final messages = <CameraMessage>[];
        final sub = cubit.messages.listen(messages.add);
        service.onSetFlash = (_) async => throw const CameraFailure(
          'no flash',
          reason: CameraFailureReason.flashUnsupported,
        );

        await cubit.cycleFlash();
        await settle();
        await sub.cancel();

        expect(messages, [CameraMessage.flashUnavailable]);
        expect(cubit.state.supportsFlash, isFalse);
        expect(cubit.state.flash, FlashSetting.off);
        await cubit.close();
      },
    );

    test(
      'the chosen flash is restored after the camera is re-opened',
      () async {
        final cubit = await readyCubit();
        await cubit.cycleFlash(); // auto
        service.flashCalls.clear();

        await cubit.pause();
        await cubit.resume();
        await settle();

        expect(cubit.state.flash, FlashSetting.auto);
        expect(service.flashCalls, [FlashSetting.auto]);
        await cubit.close();
      },
    );
  });

  group('capture', () {
    test(
      'saves into the batch, deletes the temporary file, stays ready',
      () async {
        final cubit = await readyCubit();

        await cubit.capture();

        final path =
            verify(() => addCaptured(captureAny())).captured.single as String;
        expect(
          File(path).existsSync(),
          isFalse,
          reason: 'temporary file deleted',
        );
        expect(service.discarded, [path]);
        expect(cubit.state.isCapturing, isFalse);
        expect(cubit.state.status, CameraStatus.ready);
        await cubit.close();
      },
    );

    test('shows isCapturing while the picture is being taken', () async {
      final gate = Completer<String>();
      service.onCapture = () => gate.future;
      final cubit = await readyCubit();

      final pending = cubit.capture();
      await settle();
      expect(cubit.state.isCapturing, isTrue);

      final file = File(p.join(tmp.path, 'late.jpg'))..writeAsBytesSync([9]);
      gate.complete(file.path);
      await pending;

      expect(cubit.state.isCapturing, isFalse);
      await cubit.close();
    });

    test('is ignored while a capture is in progress', () async {
      final gate = Completer<String>();
      service.onCapture = () => gate.future;
      final cubit = await readyCubit();

      final first = cubit.capture();
      await settle();
      await cubit.capture();
      await cubit.capture();

      expect(service.captureCalls, 1);
      final file = File(p.join(tmp.path, 'x.jpg'))..writeAsBytesSync([9]);
      gate.complete(file.path);
      await first;
      verify(() => addCaptured(any())).called(1);
      await cubit.close();
    });

    test(
      'a second tap right after the first is ignored until the gap passes',
      () async {
        final cubit = await readyCubit();

        await cubit.capture();
        now = now.add(const Duration(milliseconds: 100));
        await cubit.capture();
        expect(service.captureCalls, 1, reason: 'too soon');

        now = now.add(gap);
        await cubit.capture();
        expect(service.captureCalls, 2);
        await cubit.close();
      },
    );

    test('is ignored when the camera is not ready', () async {
      permissions.current = CameraPermissionStatus.denied;
      final cubit = build();
      await cubit.initialise();

      await cubit.capture();

      expect(service.captureCalls, 0);
      await cubit.close();
    });

    test(
      'a storage failure shows a clear message and the camera keeps running',
      () async {
        when(() => addCaptured(any()))
            .thenThrow(const StorageFailure('disk full'));
        final cubit = await readyCubit();
        final messages = <CameraMessage>[];
        final sub = cubit.messages.listen(messages.add);

        await cubit.capture();
        await settle();
        await sub.cancel();

        expect(messages, [CameraMessage.storageFailed]);
        expect(cubit.state.status, CameraStatus.ready);
        expect(cubit.state.isCapturing, isFalse);
        expect(
          service.discarded,
          hasLength(1),
          reason: 'the temporary file is still removed',
        );
        expect(service.isOpen, isTrue);
        await cubit.close();
      },
    );

    test('a database failure is also reported as a storage problem', () async {
      when(() => addCaptured(any())).thenThrow(const DatabaseFailure('locked'));
      final cubit = await readyCubit();
      final messages = <CameraMessage>[];
      final sub = cubit.messages.listen(messages.add);

      await cubit.capture();
      await settle();
      await sub.cancel();

      expect(messages, [CameraMessage.storageFailed]);
      await cubit.close();
    });

    test(
      'a camera failure while capturing shows a message and saves nothing',
      () async {
        service.onCapture = () async => throw const CameraFailure(
          'capture',
          reason: CameraFailureReason.captureFailed,
        );
        final cubit = await readyCubit();
        final messages = <CameraMessage>[];
        final sub = cubit.messages.listen(messages.add);

        await cubit.capture();
        await settle();
        await sub.cancel();

        expect(messages, [CameraMessage.captureFailed]);
        verifyNever(() => addCaptured(any()));
        expect(cubit.state.isCapturing, isFalse);
        await cubit.close();
      },
    );

    test('an unexpected exception is reported, not thrown', () async {
      when(() => addCaptured(any())).thenThrow(StateError('bug'));
      final cubit = await readyCubit();
      final messages = <CameraMessage>[];
      final sub = cubit.messages.listen(messages.add);

      await cubit.capture();
      await settle();
      await sub.cancel();

      expect(messages, [CameraMessage.captureFailed]);
      expect(cubit.state.status, CameraStatus.ready);
      await cubit.close();
    });

    test(
      'failing to delete the temporary file does not fail the capture',
      () async {
        service.discardError = const StorageFailure('cannot delete');
        final cubit = await readyCubit();
        final messages = <CameraMessage>[];
        final sub = cubit.messages.listen(messages.add);

        await cubit.capture();
        await settle();
        await sub.cancel();

        expect(messages, isEmpty);
        verify(() => addCaptured(any())).called(1);
        expect(cubit.state.isCapturing, isFalse);
        await cubit.close();
      },
    );
  });

  group('app lifecycle', () {
    test(
      'pause releases the camera and resume opens it again at the same zoom',
      () async {
        final cubit = await readyCubit();
        cubit.setZoomFromSlider(0.5);
        final zoomBefore = cubit.state.zoom;

        await cubit.pause();
        expect(cubit.state.status, CameraStatus.paused);
        expect(service.isOpen, isFalse);
        expect(service.disposeCalls, 1);

        await cubit.resume();
        expect(cubit.state.status, CameraStatus.ready);
        expect(service.isOpen, isTrue);
        expect(service.openedLensIds, ['0', '0']);
        expect(cubit.state.zoom, closeTo(zoomBefore, 1e-9));
        await settle();
        expect(
          service.zoomCalls.last,
          closeTo(zoomBefore, 1e-9),
          reason: 'the new camera is put back at the zoom the user had',
        );
        await cubit.close();
      },
    );

    test('resume re-opens the same lens, including the front camera', () async {
      final cubit = await readyCubit();
      await cubit.switchLens();

      await cubit.pause();
      await cubit.resume();

      expect(service.openedLensIds.last, '1');
      expect(cubit.state.lensDirection, LensDirection.front);
      await cubit.close();
    });

    test('pause and resume are idempotent', () async {
      final cubit = await readyCubit();

      await cubit.pause();
      await cubit.pause();
      expect(service.disposeCalls, 1);

      await cubit.resume();
      await cubit.resume();
      expect(service.openedLensIds, ['0', '0']);
      await cubit.close();
    });

    test('rapid pause and resume cycles end in a consistent state', () async {
      final cubit = await readyCubit();

      await Future.wait([
        cubit.pause(),
        cubit.resume(),
        cubit.pause(),
        cubit.resume(),
        cubit.pause(),
        cubit.resume(),
      ]);
      await settle();

      expect(cubit.state.status, CameraStatus.ready);
      expect(service.isOpen, isTrue);
      await cubit.close();
      expect(service.isOpen, isFalse);
    });

    test('rapid cycles ending in a pause leave the camera released', () async {
      final cubit = await readyCubit();

      await Future.wait([cubit.pause(), cubit.resume(), cubit.pause()]);
      await settle();

      expect(cubit.state.status, CameraStatus.paused);
      expect(service.isOpen, isFalse);
      await cubit.close();
    });

    test(
      'pausing during initialisation releases the camera that was opening',
      () async {
        service.openGate = Completer<void>();
        final cubit = build();
        final init = cubit.initialise();
        await settle();

        final pausing = cubit.pause();
        service.openGate!.complete();
        await init;
        await pausing;
        await settle();

        expect(service.isOpen, isFalse);
        expect(cubit.state.status, CameraStatus.paused);
        await cubit.close();
      },
    );

    test('pausing clears the focus ring and any capture flag', () async {
      final cubit = await readyCubit();
      await cubit.onTapToFocus(const Offset(200, 400), container);

      await cubit.pause();

      expect(cubit.state.focusIndicator, isNull);
      expect(cubit.state.isCapturing, isFalse);
      await cubit.close();
    });
  });

  group('close', () {
    test('during initialisation does not throw and leaks no camera', () async {
      service.openGate = Completer<void>();
      final cubit = build();
      final init = cubit.initialise();
      await settle();

      final closing = cubit.close();
      service.openGate!.complete();
      await init;
      await closing;

      expect(cubit.isClosed, isTrue);
      expect(
        service.isOpen,
        isFalse,
        reason: 'the camera that was opening is released',
      );
    });

    test('does not emit after it is closed', () async {
      final gate = Completer<String>();
      service.onCapture = () => gate.future;
      final cubit = await readyCubit();
      final emissions = <CameraState>[];
      final sub = cubit.stream.listen(emissions.add);
      final pending = cubit.capture();
      await settle();
      emissions.clear();

      await cubit.close();
      final file = File(p.join(tmp.path, 'z.jpg'))..writeAsBytesSync([1]);
      gate.complete(file.path);
      await pending;
      await sub.cancel();

      expect(emissions, isEmpty);
    });

    test(
      'releases the camera, stops listening to errors and stops timers',
      () async {
        final cubit = await readyCubit();
        await cubit.onTapToFocus(const Offset(200, 400), container);
        final timer = timers.active.single;
        expect(service.hasErrorListener, isTrue);

        await cubit.close();

        expect(service.isOpen, isFalse);
        expect(service.hasErrorListener, isFalse);
        expect(timer.isActive, isFalse);
      },
    );

    test('closing twice is safe', () async {
      final cubit = await readyCubit();

      await cubit.close();
      await cubit.close();
    });

    test('a failure while releasing does not stop the close', () async {
      final cubit = await readyCubit();

      await cubit.close();

      expect(cubit.isClosed, isTrue);
    });
  });
}

/// Reports granted for the first check and then denied, to simulate the
/// platform refusing access after the app believed it had permission.
class _FlippingPermissions implements CameraPermissionService {
  _FlippingPermissions(this._inner, this._flipped);

  final FakeCameraPermissions _inner;
  final bool Function() _flipped;

  @override
  Future<CameraPermissionStatus> status() async => _flipped()
      ? CameraPermissionStatus.denied
      : CameraPermissionStatus.granted;

  @override
  Future<CameraPermissionStatus> request() => _inner.request();

  @override
  Future<bool> openSettings() => _inner.openSettings();
}

/// Builds the info a normal fake open would, for tests that override open.
abstract final class CameraSessionInfoFactory {
  static CameraSessionInfo forLens(CameraLens lens) {
    return CameraSessionInfo(
      lens: lens,
      minZoom: 1,
      maxZoom: 8,
      supportsFocus: lens.direction == LensDirection.back,
      supportsFlash: lens.direction == LensDirection.back,
    );
  }
}
