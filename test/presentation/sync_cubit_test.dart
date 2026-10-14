import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snapsync/core/error/failure.dart';
import 'package:snapsync/domain/entities/capture_batch.dart';
import 'package:snapsync/domain/entities/captured_image.dart';
import 'package:snapsync/domain/entities/link_quality.dart';
import 'package:snapsync/domain/entities/sync_pass_result.dart';
import 'package:snapsync/domain/entities/sync_progress.dart';
import 'package:snapsync/domain/entities/upload_result.dart';
import 'package:snapsync/domain/entities/upload_status.dart';
import 'package:snapsync/domain/errors/domain_errors.dart';
import 'package:snapsync/domain/repositories/batch_repository.dart';
import 'package:snapsync/domain/repositories/sync_settings_repository.dart';
import 'package:snapsync/domain/services/sync_engine.dart';
import 'package:snapsync/presentation/upload_manager/cubit/sync_cubit.dart';
import 'package:snapsync/presentation/upload_manager/cubit/sync_message.dart';
import 'package:snapsync/presentation/upload_manager/cubit/sync_state.dart';

import '../support/fakes.dart';
import '../support/sync_test_env.dart';
import '../support/test_support.dart';

class MockBatchRepository extends Mock implements BatchRepository {}

class MockSyncEngine extends Mock implements SyncEngine {}

class MockSettings extends Mock implements SyncSettingsRepository {}

CapturedImage image(
  String id,
  UploadStatus status, {
  int bytes = 100,
  int attempts = 0,
}) {
  return CapturedImage(
    id: id,
    batchId: 'b1',
    filePath: '/fake/$id.jpg',
    fileSizeBytes: bytes,
    capturedAt: DateTime.utc(2026, 1, 1),
    status: status,
    attemptCount: attempts,
  );
}

CaptureBatch batch(String id, List<CapturedImage> images) {
  return CaptureBatch(
    id: id,
    createdAt: DateTime.utc(2026),
    submittedAt: DateTime.utc(2026, 1, 2),
    images: images,
  );
}

Future<void> settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

const completed = SyncPassResult(outcome: SyncPassOutcome.completed);

void main() {
  group('with mocked collaborators', () {
    late MockBatchRepository repository;
    late MockSyncEngine engine;
    late MockSettings settings;
    late FakeConnectivityMonitor monitor;
    late FakeSyncScheduler scheduler;
    late FakeTimerFactory timers;
    late StreamController<List<CaptureBatch>> batches;
    late StreamController<SyncProgress> progress;
    late DateTime now;

    SyncCubit build() {
      return SyncCubit(
        repository: repository,
        engine: engine,
        connectivity: monitor,
        settings: settings,
        scheduler: scheduler,
        now: () => now,
        timerFactory: timers.create,
      );
    }

    setUpAll(() {
      registerFallbackValue(UploadStatus.queued);
    });

    setUp(() {
      repository = MockBatchRepository();
      engine = MockSyncEngine();
      settings = MockSettings();
      monitor = FakeConnectivityMonitor(LinkQuality.offline);
      scheduler = FakeSyncScheduler();
      timers = FakeTimerFactory();
      batches = StreamController<List<CaptureBatch>>.broadcast();
      progress = StreamController<SyncProgress>.broadcast();
      now = DateTime.utc(2026, 3, 1, 12);

      when(() => repository.watchSubmittedBatches())
          .thenAnswer((_) => batches.stream);
      when(() => repository.markWaitingForConnection())
          .thenAnswer((_) async => 0);
      when(() => repository.refresh()).thenReturn(null);
      when(() => repository.removeImage(any())).thenAnswer((_) async {});
      when(
        () => repository.updateImageStatus(
          imageId: any(named: 'imageId'),
          status: any(named: 'status'),
          attemptCount: any(named: 'attemptCount'),
        ),
      ).thenAnswer((_) async {});
      when(() => engine.progress).thenAnswer((_) => progress.stream);
      when(() => engine.runPass()).thenAnswer((_) async => completed);
      when(() => settings.isPaused()).thenAnswer((_) async => false);
      when(() => settings.setPaused(paused: any(named: 'paused')))
          .thenAnswer((_) async {});
    });

    tearDown(() async {
      await batches.close();
      await progress.close();
    });

    blocTest<SyncCubit, SyncState>(
      'maps submitted batches to items, newest first, and tracks the queue',
      build: build,
      act: (cubit) async {
        await cubit.start();
        batches.add([
          batch('new', [
            image('a', UploadStatus.queued),
            image('b', UploadStatus.uploading),
          ]),
          batch('old', [image('c', UploadStatus.uploaded)]),
        ]);
        await settle();
        progress.add(
          const SyncProgress(imageId: 'b', fraction: 0.5, totalBytes: 100),
        );
        await settle();
      },
      verify: (cubit) {
        final state = cubit.state;
        expect(state.items.map((i) => i.id), ['a', 'b', 'c']);
        expect(state.batches.map((b) => b.id), ['new', 'old']);
        expect(state.items[1].progress, 0.5);
        // Queue = the batch that still has work: 200 bytes, 50 done.
        expect(state.totalBytes, 200);
        expect(state.uploadedBytes, 50);
        expect(state.overallProgress, 0.25);
      },
    );

    blocTest<SyncCubit, SyncState>(
      'a stable link runs a pass and asks for a background fallback',
      build: () {
        monitor.quality = LinkQuality.stable;
        return build();
      },
      act: (cubit) async {
        await cubit.start();
        await settle();
      },
      verify: (cubit) {
        verify(() => engine.runPass()).called(1);
        expect(scheduler.enqueueCount, 1);
        expect(cubit.state.linkQuality, LinkQuality.stable);
        expect(cubit.state.isSyncing, isFalse);
      },
    );

    blocTest<SyncCubit, SyncState>(
      'a pass with failures posts one error message',
      build: () {
        monitor.quality = LinkQuality.stable;
        when(() => engine.runPass()).thenAnswer(
          (_) async => const SyncPassResult(
            outcome: SyncPassOutcome.completed,
            failed: 2,
          ),
        );
        return build();
      },
      act: (cubit) async {
        final messages = <SyncMessage>[];
        final sub = cubit.messages.listen(messages.add);
        await cubit.start();
        await settle();
        await sub.cancel();
        expect(messages, hasLength(1));
        expect(messages.single.isError, isTrue);
        expect(messages.single.text, contains('2'));
      },
    );

    blocTest<SyncCubit, SyncState>(
      'a scheduled retry is run in the foreground when it falls due',
      build: () {
        monitor.quality = LinkQuality.stable;
        when(() => engine.runPass()).thenAnswer(
          (_) async => SyncPassResult(
            outcome: SyncPassOutcome.completed,
            retrying: 1,
            remaining: 1,
            nextRetryAt: now.add(const Duration(seconds: 45)),
          ),
        );
        return build();
      },
      act: (cubit) async {
        await cubit.start();
        await settle();

        expect(timers.active.single.duration, const Duration(seconds: 45));
        timers.last.fire();
        await settle();
      },
      verify: (cubit) {
        verify(() => engine.runPass()).called(2);
        expect(
          scheduler.enqueueCount,
          greaterThanOrEqualTo(2),
          reason: 'a background fallback is kept alive',
        );
      },
    );

    blocTest<SyncCubit, SyncState>(
      'newly queued work starts a pass when the link is stable, once',
      build: () {
        monitor.quality = LinkQuality.stable;
        return build();
      },
      act: (cubit) async {
        await cubit.start();
        await settle();
        clearInteractions(engine);

        batches.add([
          batch('b1', [image('a', UploadStatus.queued)]),
        ]);
        await settle();
        batches.add([
          batch('b1', [image('a', UploadStatus.queued)]),
        ]);
        await settle();
      },
      verify: (cubit) => verify(() => engine.runPass()).called(1),
    );

    blocTest<SyncCubit, SyncState>(
      'newly queued work waits while the link is offline',
      build: build,
      act: (cubit) async {
        await cubit.start();
        batches.add([
          batch('b1', [image('a', UploadStatus.queued)]),
        ]);
        await settle();
      },
      verify: (cubit) => verifyNever(() => engine.runPass()),
    );

    blocTest<SyncCubit, SyncState>(
      'going offline asks the repository to mark the queue as waiting',
      build: () {
        monitor.quality = LinkQuality.stable;
        return build();
      },
      act: (cubit) async {
        await cubit.start();
        await settle();
        monitor.emit(LinkQuality.offline);
        await settle();
      },
      verify: (cubit) {
        verify(() => repository.markWaitingForConnection()).called(1);
        expect(cubit.state.linkQuality, LinkQuality.offline);
      },
    );

    group('pause and resume', () {
      blocTest<SyncCubit, SyncState>(
        'pauseAll stores the flag, updates state and tells the user',
        build: build,
        act: (cubit) async {
          final messages = <SyncMessage>[];
          final sub = cubit.messages.listen(messages.add);
          await cubit.start();
          await cubit.pauseAll();
          await settle();
          await sub.cancel();
          expect(messages.map((m) => m.text), ['Uploads paused']);
        },
        verify: (cubit) {
          verify(() => settings.setPaused(paused: true)).called(1);
          expect(cubit.state.isPaused, isTrue);
        },
      );

      blocTest<SyncCubit, SyncState>(
        'a paused cubit does not start passes when the link becomes stable',
        build: () {
          when(() => settings.isPaused()).thenAnswer((_) async => true);
          return build();
        },
        act: (cubit) async {
          await cubit.start();
          monitor.emit(LinkQuality.stable);
          await settle();
        },
        verify: (cubit) {
          expect(cubit.state.isPaused, isTrue);
          verifyNever(() => engine.runPass());
          expect(scheduler.enqueueCount, 0);
        },
      );

      blocTest<SyncCubit, SyncState>(
        'resumeAll clears the flag and runs a pass',
        build: () {
          when(() => settings.isPaused()).thenAnswer((_) async => true);
          return build();
        },
        act: (cubit) async {
          await cubit.start();
          await cubit.resumeAll();
          await settle();
        },
        verify: (cubit) {
          verify(() => settings.setPaused(paused: false)).called(1);
          verify(() => engine.runPass()).called(1);
          expect(cubit.state.isPaused, isFalse);
        },
      );

      blocTest<SyncCubit, SyncState>(
        'a database failure while pausing is reported, not thrown',
        build: () {
          when(() => settings.setPaused(paused: any(named: 'paused')))
              .thenThrow(const DatabaseFailure('disk full'));
          return build();
        },
        act: (cubit) async {
          final messages = <SyncMessage>[];
          final sub = cubit.messages.listen(messages.add);
          await cubit.start();
          await cubit.pauseAll();
          await settle();
          await sub.cancel();
          expect(messages.single.isError, isTrue);
        },
        verify: (cubit) => expect(cubit.state.isPaused, isFalse),
      );
    });

    group('retry', () {
      void emitBatch() {
        batches.add([
          batch('b1', [
            image('failed-1', UploadStatus.failed, attempts: 3),
            image('failed-2', UploadStatus.failed, attempts: 3),
            image('done', UploadStatus.uploaded),
            image('wait', UploadStatus.waitingForConnection),
          ]),
        ]);
      }

      blocTest<SyncCubit, SyncState>(
        'retryAllFailed requeues only failed images with a fresh attempt count',
        build: build,
        act: (cubit) async {
          await cubit.start();
          emitBatch();
          await settle();
          await cubit.retryAllFailed();
        },
        verify: (cubit) {
          for (final id in ['failed-1', 'failed-2']) {
            verify(
              () => repository.updateImageStatus(
                imageId: id,
                status: UploadStatus.queued,
                attemptCount: 0,
              ),
            ).called(1);
          }
          verifyNever(
            () => repository.updateImageStatus(
              imageId: 'done',
              status: any(named: 'status'),
              attemptCount: any(named: 'attemptCount'),
            ),
          );
          verify(() => engine.runPass()).called(1);
        },
      );

      blocTest<SyncCubit, SyncState>(
        'retryItem only acts on a failed image',
        build: build,
        act: (cubit) async {
          await cubit.start();
          emitBatch();
          await settle();
          await cubit.retryItem('done');
          await cubit.retryItem('wait');
          await cubit.retryItem('nope');
          await cubit.retryItem('failed-1');
        },
        verify: (cubit) {
          verify(
            () => repository.updateImageStatus(
              imageId: 'failed-1',
              status: UploadStatus.queued,
              attemptCount: 0,
            ),
          ).called(1);
          verifyNever(
            () => repository.updateImageStatus(
              imageId: 'done',
              status: any(named: 'status'),
              attemptCount: any(named: 'attemptCount'),
            ),
          );
        },
      );

      blocTest<SyncCubit, SyncState>(
        'retryAllFailed with nothing failed does nothing',
        build: build,
        act: (cubit) async {
          await cubit.start();
          await cubit.retryAllFailed();
        },
        verify: (cubit) => verifyNever(() => engine.runPass()),
      );
    });

    group('removeItem', () {
      blocTest<SyncCubit, SyncState>(
        'removes the image',
        build: build,
        act: (cubit) async {
          await cubit.start();
          await cubit.removeItem('a');
        },
        verify: (cubit) => verify(() => repository.removeImage('a')).called(1),
      );

      blocTest<SyncCubit, SyncState>(
        'explains why an uploading image cannot be removed',
        build: () {
          when(() => repository.removeImage(any()))
              .thenThrow(IllegalBatchStateError('uploading'));
          return build();
        },
        act: (cubit) async {
          final messages = <SyncMessage>[];
          final sub = cubit.messages.listen(messages.add);
          await cubit.start();
          await cubit.removeItem('a');
          await sub.cancel();
          expect(messages.single.isError, isTrue);
        },
      );
    });

    blocTest<SyncCubit, SyncState>(
      'onAppResumed re-reads the database',
      build: build,
      act: (cubit) async {
        await cubit.start();
        await cubit.onAppResumed();
      },
      verify: (cubit) => verify(() => repository.refresh()).called(1),
    );

    test('close cancels every subscription and timer', () async {
      monitor.quality = LinkQuality.stable;
      when(() => engine.runPass()).thenAnswer(
        (_) async => SyncPassResult(
          outcome: SyncPassOutcome.completed,
          remaining: 1,
          nextRetryAt: now.add(const Duration(minutes: 1)),
        ),
      );
      final cubit = build();
      await cubit.start();
      await settle();
      expect(monitor.hasListeners, isTrue);
      expect(batches.hasListener, isTrue);
      expect(progress.hasListener, isTrue);
      final retryTimer = timers.active.single;

      await cubit.close();

      expect(monitor.hasListeners, isFalse);
      expect(batches.hasListener, isFalse);
      expect(progress.hasListener, isFalse);
      expect(retryTimer.isActive, isFalse);
    });
  });

  group('with a real repository, engine and database', () {
    late SyncTestEnv env;
    late FakeSyncScheduler scheduler;

    SyncCubit build({FakeConnectivityMonitor? monitor}) {
      return SyncCubit(
        repository: env.repository,
        engine: env.engine,
        connectivity: monitor ?? env.monitor,
        settings: env.settings,
        scheduler: scheduler,
        now: () => env.now,
      );
    }

    setUp(() async {
      env = await SyncTestEnv.create(fileDatabase: true);
      scheduler = FakeSyncScheduler();
    });

    tearDown(() => env.dispose());

    blocTest<SyncCubit, SyncState>(
      'offline: queued items show as waiting for connection and nothing is lost',
      build: () => build(monitor: FakeConnectivityMonitor(LinkQuality.offline)),
      act: (cubit) async {
        await env.submitImages(3);
        await cubit.start();
        await eventually(() => cubit.state.items.length == 3);
        expect(
          cubit.state.items.map((i) => i.status),
          everyElement(UploadStatus.queued),
        );

        // The link drop event.
        final monitor = cubit.connectivity as FakeConnectivityMonitor;
        monitor.emit(LinkQuality.unstable);
        monitor.emit(LinkQuality.offline);
        await eventually(
          () => cubit.state.items.every(
            (i) => i.status == UploadStatus.waitingForConnection,
          ),
        );
      },
      verify: (cubit) {
        expect(cubit.state.items, hasLength(3));
        expect(env.api.calls, isEmpty);
      },
    );

    blocTest<SyncCubit, SyncState>(
      'the link becoming stable triggers a pass and items move to uploaded',
      build: () => build(monitor: FakeConnectivityMonitor(LinkQuality.offline)),
      act: (cubit) async {
        final images = await env.submitImages(3);
        await cubit.start();
        await eventually(() => cubit.state.items.length == 3);

        (cubit.connectivity as FakeConnectivityMonitor).emit(
          LinkQuality.stable,
        );
        await eventually(
          () =>
              cubit.state.items.every((i) => i.status == UploadStatus.uploaded),
        );

        expect(env.api.calls, images.map((i) => i.id));
      },
      verify: (cubit) {
        expect(scheduler.enqueueCount, greaterThanOrEqualTo(1));
        expect(cubit.state.items.every((i) => i.progress == 1), isTrue);
        expect(cubit.state.thumbnailsGone, isTrue);
      },
    );

    blocTest<SyncCubit, SyncState>(
      'failures show retry text and a pending retry',
      build: () => build(monitor: FakeConnectivityMonitor(LinkQuality.stable)),
      act: (cubit) async {
        env.api.handler = (_) =>
            const UploadFailed(LowBandwidthFailure('slow'));
        await env.submitImages(1);
        await cubit.start();
        await eventually(
          () =>
              cubit.state.items.isNotEmpty &&
              cubit.state.items.single.status == UploadStatus.retrying,
        );
      },
      verify: (cubit) {
        final item = cubit.state.items.single;
        expect(item.attemptText, 'Retrying... (attempt 2/3)');
        expect(item.lastError, 'slow');
        expect(item.thumbnailPath, isNotNull);
      },
    );

    blocTest<SyncCubit, SyncState>(
      'pauseAll stops uploading and resumeAll finishes the work',
      build: () => build(monitor: FakeConnectivityMonitor(LinkQuality.offline)),
      act: (cubit) async {
        await env.submitImages(2);
        await cubit.start();
        await eventually(() => cubit.state.items.length == 2);

        await cubit.pauseAll();
        (cubit.connectivity as FakeConnectivityMonitor).emit(
          LinkQuality.stable,
        );
        await settle();
        expect(env.api.calls, isEmpty, reason: 'paused');

        await cubit.resumeAll();
        await eventually(
          () =>
              cubit.state.items.every((i) => i.status == UploadStatus.uploaded),
        );
      },
      verify: (cubit) => expect(cubit.state.isPaused, isFalse),
    );

    blocTest<SyncCubit, SyncState>(
      'retryAllFailed brings failed images back and uploads them',
      build: () => build(monitor: FakeConnectivityMonitor(LinkQuality.stable)),
      act: (cubit) async {
        env.api.handler = (_) =>
            const UploadFailed(ServerFailure('rejected', code: 400));
        await env.submitImages(2);
        await cubit.start();
        await eventually(
          () =>
              cubit.state.items.length == 2 &&
              cubit.state.items.every((i) => i.status == UploadStatus.failed),
        );

        env.api.handler = null;
        await cubit.retryAllFailed();
        await eventually(
          () =>
              cubit.state.items.every((i) => i.status == UploadStatus.uploaded),
        );
      },
    );

    blocTest<SyncCubit, SyncState>(
      'resuming the app picks up changes written by another connection',
      build: () => build(monitor: FakeConnectivityMonitor(LinkQuality.offline)),
      act: (cubit) async {
        final images = await env.submitImages(1);
        await cubit.start();
        await eventually(() => cubit.state.items.length == 1);

        // The background isolate: its own connection, no signal to this one.
        final background = await env.newSecondEngine(
          monitor: FakeConnectivityMonitor(),
        );
        await background.repository.updateImageStatus(
          imageId: images.single.id,
          status: UploadStatus.waitingForConnection,
          attemptCount: 0,
        );
        await settle();
        expect(
          cubit.state.items.single.status,
          UploadStatus.queued,
          reason: 'no signal yet',
        );

        await cubit.onAppResumed();
        await eventually(
          () =>
              cubit.state.items.single.status ==
              UploadStatus.waitingForConnection,
        );
      },
    );
  });
}

extension on SyncState {
  /// Uploaded items no longer point at a local file.
  bool get thumbnailsGone => items.every((i) => i.thumbnailPath == null);
}
