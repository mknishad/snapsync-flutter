import 'package:snapsync/background/task_names.dart';
import 'package:snapsync/core/constants/app_constants.dart';
import 'package:snapsync/core/di/injection.dart';
import 'package:snapsync/core/error/failure.dart';
import 'package:snapsync/domain/usecases/recover_interrupted_uploads.dart';
import 'package:workmanager/workmanager.dart';

/// Entry point invoked by the OS for every scheduled task. Must stay a
/// top-level function.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    await configureBackgroundDependencies();

    try {
      // Only requeue uploads old enough to belong to a dead process; one that
      // is running in the UI isolate right now must be left alone.
      await getIt<RecoverInterruptedUploads>()(
        staleAfter: AppConstants.interruptedUploadTimeout,
      );
    } on Failure {
      // The database is unavailable, so there is nothing this task can do.
      // Ask workmanager to retry it with its own backoff.
      return false;
    }

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
