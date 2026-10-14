import 'package:flutter/widgets.dart';
import 'package:snapsync/background/background_sync_runner.dart';
import 'package:snapsync/core/di/injection.dart';
import 'package:snapsync/domain/services/sync_engine.dart';
import 'package:workmanager/workmanager.dart';

/// Entry point invoked by the OS for every scheduled task. Must stay a
/// top-level function.
///
/// Runs in a separate isolate (or, for one-off work, possibly on the main
/// engine), so it builds its own dependencies instead of relying on anything
/// the UI isolate created.
@pragma('vm:entry-point')
void callbackDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();

  Workmanager().executeTask(
    (taskName, inputData) async {
      await configureBackgroundDependencies();
      return BackgroundSyncRunner(getIt<SyncEngine>()).run(taskName);
    },
    onTaskStopped: (taskName, stopReason) async {
      await configureBackgroundDependencies();
      await BackgroundSyncRunner(getIt<SyncEngine>()).onStopped();
    },
  );
}
