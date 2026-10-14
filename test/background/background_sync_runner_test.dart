import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snapsync/background/background_sync_runner.dart';
import 'package:snapsync/background/task_names.dart';
import 'package:snapsync/core/error/failure.dart';
import 'package:snapsync/domain/entities/sync_pass_result.dart';
import 'package:snapsync/domain/services/sync_engine.dart';

class MockSyncEngine extends Mock implements SyncEngine {}

void main() {
  late MockSyncEngine engine;
  late BackgroundSyncRunner runner;

  void passReturns(SyncPassResult result) {
    when(() => engine.runPass()).thenAnswer((_) async => result);
  }

  setUp(() {
    engine = MockSyncEngine();
    runner = BackgroundSyncRunner(engine);
  });

  // The returned bool is workmanager's: true = finished, false = retry.
  group('return value (true finishes the task, false asks for a retry)', () {
    test('everything done: finished', () async {
      passReturns(
        const SyncPassResult(outcome: SyncPassOutcome.completed, uploaded: 3),
      );

      expect(await runner.run(TaskNames.oneOffSyncTask), isTrue);
    });

    test('nothing to do: finished', () async {
      passReturns(const SyncPassResult(outcome: SyncPassOutcome.completed));

      expect(await runner.run(TaskNames.periodicSyncTask), isTrue);
    });

    test('work left waiting for its retry time: retry', () async {
      passReturns(
        SyncPassResult(
          outcome: SyncPassOutcome.completed,
          retrying: 1,
          remaining: 1,
          nextRetryAt: DateTime.utc(2026),
        ),
      );

      expect(await runner.run(TaskNames.oneOffSyncTask), isFalse);
    });

    test('interrupted by connectivity: retry', () async {
      passReturns(
        const SyncPassResult(
          outcome: SyncPassOutcome.interruptedByConnectivity,
          remaining: 2,
        ),
      );

      expect(await runner.run(TaskNames.oneOffSyncTask), isFalse);
    });

    test('cancelled by the platform: retry', () async {
      passReturns(
        const SyncPassResult(outcome: SyncPassOutcome.cancelled, remaining: 1),
      );

      expect(await runner.run(TaskNames.oneOffSyncTask), isFalse);
    });

    test('paused by the user: finished, resuming schedules a new run',
        () async {
      passReturns(
        const SyncPassResult(
          outcome: SyncPassOutcome.pausedByUser,
          remaining: 4,
        ),
      );

      expect(await runner.run(TaskNames.oneOffSyncTask), isTrue);
    });
  });

  group('errors never escape the handler', () {
    test('a Failure (for example a busy database) asks for a retry', () async {
      when(() => engine.runPass()).thenThrow(const DatabaseFailure('locked'));

      expect(await runner.run(TaskNames.oneOffSyncTask), isFalse);
    });

    test('an unexpected exception asks for a retry instead of killing the task',
        () async {
      when(() => engine.runPass()).thenThrow(StateError('boom'));

      expect(await runner.run(TaskNames.oneOffSyncTask), isFalse);
    });

    test('an asynchronous error is handled the same way', () async {
      when(() => engine.runPass()).thenAnswer((_) async => throw Exception('x'));

      expect(await runner.run(TaskNames.periodicSyncTask), isFalse);
    });
  });

  test('an unknown task name is ignored and finishes', () async {
    expect(await runner.run('not.ours'), isTrue);
    verifyNever(() => engine.runPass());
  });

  group('onStopped', () {
    test('asks the engine to release its claims', () async {
      when(() => engine.cancelPass()).thenAnswer((_) async {});

      await runner.onStopped();

      verify(() => engine.cancelPass()).called(1);
    });

    test('swallows (and logs) a failure while releasing', () async {
      when(() => engine.cancelPass()).thenThrow(const DatabaseFailure('locked'));

      await runner.onStopped();
    });
  });
}
