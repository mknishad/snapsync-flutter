import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snapsync/app/app.dart';
import 'package:snapsync/core/di/injection.dart';
import 'package:snapsync/data/remote/mock_upload_config.dart';
import 'package:snapsync/domain/repositories/sync_scheduler.dart';
import 'package:snapsync/presentation/batch/cubit/batch_cubit.dart';
import 'package:snapsync/presentation/batch/cubit/batch_state.dart';
import 'package:snapsync/presentation/camera/cubit/camera_cubit.dart';
import 'package:snapsync/presentation/upload_manager/cubit/sync_cubit.dart';
import 'package:snapsync/presentation/upload_manager/cubit/sync_message.dart';
import 'package:snapsync/presentation/upload_manager/cubit/sync_state.dart';

import 'support/fakes.dart';

class MockSyncCubit extends MockCubit<SyncState> implements SyncCubit {}

class MockBatchCubit extends MockCubit<BatchState> implements BatchCubit {}

void main() {
  setUp(() async {
    await getIt.reset();

    final sync = MockSyncCubit();
    when(() => sync.state).thenReturn(const SyncState());
    when(sync.start).thenAnswer((_) async {});
    when(() => sync.messages).thenAnswer((_) => const Stream<SyncMessage>.empty());
    when(sync.close).thenAnswer((_) async {});

    final batch = MockBatchCubit();
    when(() => batch.state).thenReturn(const BatchState());
    when(batch.start).thenAnswer((_) async {});
    when(batch.close).thenAnswer((_) async {});

    getIt
      ..registerFactory<SyncCubit>(() => sync)
      ..registerFactory<BatchCubit>(() => batch)
      ..registerFactory<CameraCubit>(CameraCubit.new)
      ..registerSingleton<MockUploadConfig>(MockUploadConfig())
      ..registerSingleton<SyncScheduler>(FakeSyncScheduler());
  });

  tearDown(() => getIt.reset());

  testWidgets('app starts on the Upload Manager screen', (tester) async {
    await tester.pumpWidget(const SnapSyncApp());

    expect(find.text('UploadManagerScreen'), findsOneWidget);
    expect(find.text('CameraPreviewScreen'), findsNothing);
  });

  testWidgets('the cubits are started when the app builds', (tester) async {
    await tester.pumpWidget(const SnapSyncApp());

    verify(() => getIt<SyncCubit>().start()).called(1);
    verify(() => getIt<BatchCubit>().start()).called(1);
  });

  testWidgets('start new upload batch opens the camera screen', (tester) async {
    await tester.pumpWidget(const SnapSyncApp());

    await tester.ensureVisible(find.text('START NEW UPLOAD BATCH'));
    await tester.tap(find.text('START NEW UPLOAD BATCH'));
    await tester.pumpAndSettle();

    expect(find.text('CameraPreviewScreen'), findsOneWidget);
  });

  testWidgets('shows the raw sync state for manual testing', (tester) async {
    await tester.pumpWidget(const SnapSyncApp());

    expect(find.textContaining('link: offline'), findsOneWidget);
    expect(find.text('No uploads yet.'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);
  });
}
