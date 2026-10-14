/// Names used to register and recognise workmanager tasks.
///
/// The unique name identifies the registration (and is how one registration
/// replaces or keeps another); the task name is what the callback dispatcher
/// receives.
abstract final class TaskNames {
  /// Safety-net task that runs about every 15 minutes.
  static const String periodicSyncUniqueName = 'snapsync.sync.periodic';
  static const String periodicSyncTask = 'snapsync.task.periodicSync';

  /// Event-driven task: batch submitted, retryable failure, connectivity back.
  static const String oneOffSyncUniqueName = 'snapsync.sync.now';
  static const String oneOffSyncTask = 'snapsync.task.syncNow';

  static bool isSyncTask(String taskName) =>
      taskName == periodicSyncTask || taskName == oneOffSyncTask;
}
