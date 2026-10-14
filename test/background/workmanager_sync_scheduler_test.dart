import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snapsync/background/task_names.dart';
import 'package:snapsync/background/workmanager_sync_scheduler.dart';
import 'package:snapsync/core/constants/app_constants.dart';
import 'package:snapsync/domain/repositories/sync_scheduler.dart';
import 'package:workmanager/workmanager.dart';

class MockWorkmanager extends Mock implements Workmanager {}

void main() {
  late MockWorkmanager workmanager;
  late SyncScheduler scheduler;

  setUp(() {
    workmanager = MockWorkmanager();
    scheduler = WorkmanagerSyncScheduler(workmanager);
    when(
      () => workmanager.registerOneOffTask(
        any(),
        any(),
        constraints: any(named: 'constraints'),
        existingWorkPolicy: any(named: 'existingWorkPolicy'),
        backoffPolicy: any(named: 'backoffPolicy'),
        backoffPolicyDelay: any(named: 'backoffPolicyDelay'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => workmanager.registerOneOffTask(
        any(),
        any(),
        existingWorkPolicy: any(named: 'existingWorkPolicy'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => workmanager.registerPeriodicTask(
        any(),
        any(),
        frequency: any(named: 'frequency'),
        constraints: any(named: 'constraints'),
        existingWorkPolicy: any(named: 'existingWorkPolicy'),
        backoffPolicy: any(named: 'backoffPolicy'),
        backoffPolicyDelay: any(named: 'backoffPolicyDelay'),
      ),
    ).thenAnswer((_) async {});
  });

  test('task names are distinct and recognised as sync tasks', () {
    expect(TaskNames.oneOffSyncUniqueName, 'snapsync.sync.now');
    expect(TaskNames.periodicSyncUniqueName, 'snapsync.sync.periodic');
    expect({
      TaskNames.oneOffSyncUniqueName,
      TaskNames.periodicSyncUniqueName,
      TaskNames.oneOffSyncTask,
      TaskNames.periodicSyncTask,
    }, hasLength(4));
    expect(TaskNames.isSyncTask(TaskNames.oneOffSyncTask), isTrue);
    expect(TaskNames.isSyncTask(TaskNames.periodicSyncTask), isTrue);
    expect(TaskNames.isSyncTask('something.else'), isFalse);
  });

  test('the shared constraint requires a network connection', () {
    expect(
      WorkmanagerSyncScheduler.connectedConstraint.networkType,
      NetworkType.connected,
    );
  });

  group('enqueueSyncNow', () {
    test('registers the unique one-off with a network constraint, the update '
        'policy and exponential backoff', () async {
      await scheduler.enqueueSyncNow();

      final captured = verify(
        () => workmanager.registerOneOffTask(
          captureAny(),
          captureAny(),
          constraints: captureAny(named: 'constraints'),
          existingWorkPolicy: captureAny(named: 'existingWorkPolicy'),
          backoffPolicy: captureAny(named: 'backoffPolicy'),
          backoffPolicyDelay: captureAny(named: 'backoffPolicyDelay'),
        ),
      ).captured;

      expect(captured[0], 'snapsync.sync.now');
      expect(captured[1], TaskNames.oneOffSyncTask);
      expect((captured[2] as Constraints).networkType, NetworkType.connected);
      expect(captured[3], ExistingWorkPolicy.update);
      expect(captured[4], BackoffPolicy.exponential);
      expect(captured[5], AppConstants.backoffBaseDelay);
    });
  });

  group('registerPeriodicSync', () {
    test('registers every 15 minutes with a network constraint', () async {
      await scheduler.registerPeriodicSync();

      final captured = verify(
        () => workmanager.registerPeriodicTask(
          captureAny(),
          captureAny(),
          frequency: captureAny(named: 'frequency'),
          constraints: captureAny(named: 'constraints'),
          existingWorkPolicy: captureAny(named: 'existingWorkPolicy'),
          backoffPolicy: captureAny(named: 'backoffPolicy'),
          backoffPolicyDelay: captureAny(named: 'backoffPolicyDelay'),
        ),
      ).captured;

      expect(captured[0], 'snapsync.sync.periodic');
      expect(captured[1], TaskNames.periodicSyncTask);
      expect(captured[2], const Duration(minutes: 15));
      expect((captured[3] as Constraints).networkType, NetworkType.connected);
      expect(
        captured[4],
        ExistingPeriodicWorkPolicy.update,
        reason: 'safe to register at every start',
      );
    });

    test('uses the platform minimum frequency', () {
      expect(AppConstants.periodicSyncInterval, const Duration(minutes: 15));
    });
  });

  group('debugRunNow', () {
    test('runs a separate, unconstrained task in debug builds', () async {
      expect(kDebugMode, isTrue, reason: 'tests run in debug mode');

      await scheduler.debugRunNow();

      final captured = verify(
        () => workmanager.registerOneOffTask(
          captureAny(),
          captureAny(),
          existingWorkPolicy: captureAny(named: 'existingWorkPolicy'),
        ),
      ).captured;

      expect(captured[0], 'snapsync.sync.now.debug');
      expect(captured[1], TaskNames.oneOffSyncTask);
      expect(captured[2], ExistingWorkPolicy.replace);
    });
  });
}
