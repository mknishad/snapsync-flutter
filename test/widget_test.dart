import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snapsync/app/app.dart';
import 'package:snapsync/core/di/injection.dart';
import 'package:snapsync/core/utils/clock.dart';
import 'package:snapsync/data/remote/mock_upload_config.dart';
import 'package:snapsync/domain/repositories/sync_scheduler.dart';
import 'package:snapsync/domain/usecases/add_captured_image.dart';
import 'package:snapsync/presentation/batch/cubit/batch_cubit.dart';
import 'package:snapsync/presentation/batch/cubit/batch_state.dart';
import 'package:snapsync/presentation/camera/cubit/camera_cubit.dart';
import 'package:snapsync/presentation/upload_manager/cubit/sync_cubit.dart';
import 'package:snapsync/presentation/upload_manager/cubit/sync_message.dart';
import 'package:snapsync/presentation/upload_manager/cubit/sync_state.dart';

import 'support/camera_fakes.dart';
import 'support/fakes.dart';

class MockSyncCubit extends MockCubit<SyncState> implements SyncCubit {}

class MockBatchCubit extends MockCubit<BatchState> implements BatchCubit {}

class MockAddCapturedImage extends Mock implements AddCapturedImage {}

void main() {
  late FakeCameraService cameraService;

  setUp(() async {
    await getIt.reset();

    final sync = MockSyncCubit();
    when(() => sync.state).thenReturn(const SyncState());
    when(sync.start).thenAnswer((_) async {});
    when(() => sync.messages)
        .thenAnswer((_) => const Stream<SyncMessage>.empty());
    when(sync.close).thenAnswer((_) async {});

    final batch = MockBatchCubit();
    when(() => batch.state).thenReturn(const BatchState());
    when(batch.start).thenAnswer((_) async {});
    when(batch.close).thenAnswer((_) async {});

    getIt
      ..registerFactory<SyncCubit>(() => sync)
      ..registerFactory<BatchCubit>(() => batch)
      // The real camera cubit, on a fake camera and fake permissions. The fake
      // is created here, inside the test's fake-async zone (setUp runs outside
      // it, which would leave the camera's futures on the real event loop).
      ..registerFactory<CameraCubit>(
        () => CameraCubit(
          service: cameraService = FakeCameraService(),
          permissions: FakeCameraPermissions(),
          addCapturedImage: MockAddCapturedImage(),
          now: utcNow,
        ),
      )
      ..registerSingleton<MockUploadConfig>(MockUploadConfig())
      ..registerSingleton<SyncScheduler>(FakeSyncScheduler());
  });

  tearDown(() => getIt.reset());

  testWidgets('app starts on the Upload Manager screen', (tester) async {
    await tester.pumpWidget(const SnapSyncApp());

    expect(find.text('Upload Manager'), findsOneWidget);
    expect(find.text('Nothing to upload yet'), findsOneWidget);
    expect(find.byIcon(Icons.flip_camera_android_rounded), findsNothing);
  });

  testWidgets('the shared cubits are started when the app builds', (
    tester,
  ) async {
    await tester.pumpWidget(const SnapSyncApp());

    verify(() => getIt<SyncCubit>().start()).called(1);
    verify(() => getIt<BatchCubit>().start()).called(1);
  });

  testWidgets('start new upload batch opens the camera screen and the camera', (
    tester,
  ) async {
    await tester.pumpWidget(const SnapSyncApp());

    await tester.tap(find.text('START NEW UPLOAD BATCH').last);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.flip_camera_android_rounded), findsOneWidget);
    expect(find.text('UPLOAD BATCH (0)'), findsOneWidget);
    expect(cameraService.openedLensIds, ['0'], reason: 'the camera was opened');
  });

  testWidgets(
    'closing the camera returns to the Upload Manager and releases it',
    (tester) async {
      await tester.pumpWidget(const SnapSyncApp());
      await tester.tap(find.text('START NEW UPLOAD BATCH').last);
      await tester.pumpAndSettle();
      expect(cameraService.isOpen, isTrue);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Upload Manager'), findsOneWidget);
      expect(cameraService.isOpen, isFalse);
    },
  );

  testWidgets('the Upload Manager shows its controls', (tester) async {
    await tester.pumpWidget(const SnapSyncApp());

    expect(find.text('BATCH SYNC PROGRESS'), findsOneWidget);
    expect(find.text('PAUSE ALL'), findsOneWidget);
    expect(find.text('PENDING UPLOADS (0)'), findsOneWidget);
    expect(find.text('OFFLINE'), findsOneWidget);
  });
}
