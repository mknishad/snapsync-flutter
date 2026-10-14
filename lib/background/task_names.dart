/// Names used to register and recognise workmanager tasks.
///
/// The unique name identifies the registration; the task name is what the
/// callback dispatcher receives.
abstract final class TaskNames {
  static const String periodicSyncUniqueName = 'snapsync.sync.periodic';
  static const String periodicSyncTask = 'snapsync.task.periodicSync';

  static const String oneOffSyncUniqueName = 'snapsync.sync.oneOff';
  static const String oneOffSyncTask = 'snapsync.task.oneOffSync';
}
