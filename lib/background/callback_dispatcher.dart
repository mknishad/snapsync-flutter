import 'package:snapsync/background/task_names.dart';
import 'package:snapsync/core/di/injection.dart';
import 'package:workmanager/workmanager.dart';

/// Entry point invoked by the OS for every scheduled task. Must stay a
/// top-level function.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    await configureBackgroundDependencies();

    switch (taskName) {
      case TaskNames.periodicSyncTask:
      case TaskNames.oneOffSyncTask:
        // TODO: resolve SyncPendingUploads from getIt and run it. Return
        // false when uploads should be retried by workmanager's backoff.
        return true;
      default:
        return true;
    }
  });
}
