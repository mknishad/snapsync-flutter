import 'package:snapsync/background/task_names.dart';
import 'package:snapsync/core/error/failure.dart';
import 'package:snapsync/core/utils/safe_log.dart';
import 'package:snapsync/domain/entities/sync_pass_result.dart';
import 'package:snapsync/domain/services/sync_engine.dart';

/// What a background task does, separated from the plugin so it can be tested.
///
/// The returned bool is Workmanager's own contract (Android): `true` means the
/// task is finished, `false` asks WorkManager to retry it with the backoff the
/// task was registered with. A Dart exception that escapes the handler is
/// turned into a permanent failure by the plugin, so nothing may escape here.
class BackgroundSyncRunner {
  const BackgroundSyncRunner(this.engine);

  final SyncEngine engine;

  Future<bool> run(String taskName) async {
    if (!TaskNames.isSyncTask(taskName)) {
      logProblem('snapsync.bg', 'Ignoring an unknown task name');
      return true;
    }
    try {
      return _shouldFinish(await engine.runPass());
    } on Failure catch (failure) {
      logProblem(
        'snapsync.bg',
        'Sync pass failed',
        error: failure,
        level: 1000,
      );
      return false; // transient (for example the database was busy): retry
    } on Object catch (error, stack) {
      logProblem(
        'snapsync.bg',
        'Sync pass crashed',
        error: error,
        stackTrace: stack,
        level: 1000,
      );
      return false;
    }
  }

  /// True when nothing more should be scheduled.
  ///
  /// - Paused: nothing to do; resuming schedules a new run.
  /// - Interrupted by connectivity or cancelled: retry (the registered network
  ///   constraint makes WorkManager wait for a connection first).
  /// - Completed with work still pending (images waiting for their retry
  ///   time): retry, so a later run picks them up when due.
  bool _shouldFinish(SyncPassResult result) {
    return switch (result.outcome) {
      SyncPassOutcome.pausedByUser => true,
      SyncPassOutcome.interruptedByConnectivity ||
      SyncPassOutcome.cancelled =>
        false,
      SyncPassOutcome.completed => !result.hasWorkRemaining,
    };
  }

  /// Called when the platform stops the task early.
  Future<void> onStopped() async {
    try {
      await engine.cancelPass();
    } on Object catch (error, stack) {
      logProblem(
        'snapsync.bg',
        'Could not release claims on stop',
        error: error,
        stackTrace: stack,
        level: 1000,
      );
    }
  }
}
