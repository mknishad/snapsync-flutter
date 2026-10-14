import 'package:get_it/get_it.dart';
import 'package:snapsync/background/workmanager_sync_scheduler.dart';
import 'package:snapsync/domain/repositories/sync_scheduler.dart';
import 'package:workmanager/workmanager.dart';

/// The scheduler is only needed by the UI isolate, which enqueues work; the
/// background isolate just runs it.
void registerBackgroundModule(GetIt getIt) {
  if (getIt.isRegistered<SyncScheduler>()) return;

  getIt.registerLazySingleton<SyncScheduler>(
    () => WorkmanagerSyncScheduler(Workmanager()),
  );
}
