import 'package:flutter/foundation.dart';
import 'package:snapsync/background/task_names.dart';
import 'package:snapsync/core/constants/app_constants.dart';
import 'package:snapsync/domain/repositories/sync_scheduler.dart';
import 'package:workmanager/workmanager.dart';

/// [SyncScheduler] on top of the Workmanager plugin (0.10.x API: `Workmanager`,
/// `Constraints`, `ExistingWorkPolicy`, `ExistingPeriodicWorkPolicy`,
/// `BackoffPolicy`).
///
/// Platform limits worth knowing:
/// - Android never runs periodic work more often than every 15 minutes, and
///   asking for less is rounded up.
/// - Timing is not guaranteed. Doze mode, App Standby, battery saver and
///   vendor battery optimisation can delay or skip background work, and a
///   force-stopped app does not run background work until it is opened again.
/// - The network constraint makes WorkManager wait for a connection, but a
///   connection is not necessarily a working one; the sync engine verifies it.
class WorkmanagerSyncScheduler implements SyncScheduler {
  WorkmanagerSyncScheduler(this._workmanager);

  final Workmanager _workmanager;

  static final Constraints connectedConstraint = Constraints(
    networkType: NetworkType.connected,
  );

  @override
  Future<void> registerPeriodicSync() {
    return _workmanager.registerPeriodicTask(
      TaskNames.periodicSyncUniqueName,
      TaskNames.periodicSyncTask,
      frequency: AppConstants.periodicSyncInterval,
      constraints: connectedConstraint,
      // `update` changes the registration in place without cancelling a running
      // worker or restarting the 15-minute clock, so registering at every app
      // start is safe.
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: AppConstants.backoffBaseDelay,
    );
  }

  /// Existing-work policy is `update`, which the plugin maps to WorkManager's
  /// APPEND_OR_REPLACE. A sync pass is cheap and idempotent, so the only
  /// outcome that matters is a *lost* trigger, never a duplicate one:
  /// - `keep` could drop a trigger that arrives while a worker is finishing,
  ///   leaving a freshly submitted batch waiting for the periodic task;
  /// - `replace` would cancel an upload that is running right now;
  /// - `update` queues one more run after the current one and cannot be
  ///   poisoned by a failed predecessor.
  @override
  Future<void> enqueueSyncNow() => _enqueueOneOff();

  @override
  Future<void> debugRunNow() async {
    if (!kDebugMode) return;
    // No network constraint, so it runs even in airplane mode, which is what
    // the manual tests need.
    await _workmanager.registerOneOffTask(
      '${TaskNames.oneOffSyncUniqueName}.debug',
      TaskNames.oneOffSyncTask,
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }

  Future<void> _enqueueOneOff() {
    return _workmanager.registerOneOffTask(
      TaskNames.oneOffSyncUniqueName,
      TaskNames.oneOffSyncTask,
      constraints: connectedConstraint,
      existingWorkPolicy: ExistingWorkPolicy.update,
      // Used when the task returns false (retry): WorkManager waits 30 s, then
      // 60 s, 120 s and so on, in step with the app's own retry backoff.
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: AppConstants.backoffBaseDelay,
    );
  }
}
