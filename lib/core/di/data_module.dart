import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get_it/get_it.dart';
import 'package:snapsync/data/connectivity/connectivity_monitor_impl.dart';
import 'package:snapsync/data/connectivity/mock_reachability_probe.dart';
import 'package:snapsync/data/local/daos/batch_dao.dart';
import 'package:snapsync/data/local/daos/image_dao.dart';
import 'package:snapsync/data/local/daos/settings_dao.dart';
import 'package:snapsync/data/local/database_helper.dart';
import 'package:snapsync/data/local/settings_store.dart';
import 'package:snapsync/data/remote/mock_upload_api.dart';
import 'package:snapsync/data/remote/mock_upload_config.dart';
import 'package:snapsync/data/repositories/batch_repository_impl.dart';
import 'package:snapsync/data/repositories/sync_settings_repository_impl.dart';
import 'package:snapsync/data/storage/image_file_storage.dart';
import 'package:snapsync/domain/repositories/batch_repository.dart';
import 'package:snapsync/domain/repositories/connectivity_monitor.dart';
import 'package:snapsync/domain/repositories/reachability_probe.dart';
import 'package:snapsync/domain/repositories/sync_settings_repository.dart';
import 'package:snapsync/domain/repositories/upload_api.dart';
import 'package:uuid/uuid.dart';

/// Safe to call from either isolate and more than once. Each isolate has its
/// own get_it instance, so nothing here may rely on state from the other.
void registerDataModule(GetIt getIt) {
  if (getIt.isRegistered<DatabaseHelper>()) return;

  getIt
    ..registerLazySingleton<DatabaseHelper>(DatabaseHelper.new)
    ..registerLazySingleton<BatchDao>(BatchDao.new)
    ..registerLazySingleton<ImageDao>(ImageDao.new)
    ..registerLazySingleton<SettingsDao>(SettingsDao.new)
    ..registerLazySingleton<SettingsStore>(
      () => SettingsStore(getIt(), getIt()),
    )
    ..registerLazySingleton<SyncSettingsRepository>(
      () => SyncSettingsRepositoryImpl(getIt()),
    )
    ..registerLazySingleton<ImageFileStorage>(ImageFileStorage.new)
    // The mock modes are stored in the database so the UI isolate and the
    // background isolate always agree.
    ..registerLazySingleton<MockUploadConfig>(
      () => MockUploadConfig(store: getIt()),
    )
    // Swap the mocks for the real implementations (see the commented sketches
    // in data/remote and data/connectivity) once an endpoint exists.
    ..registerLazySingleton<UploadApi>(
      () => MockUploadApi(getIt<MockUploadConfig>(), random: Random()),
    )
    ..registerLazySingleton<ReachabilityProbe>(
      () => MockReachabilityProbe(getIt<MockUploadConfig>(), random: Random()),
    )
    ..registerLazySingleton<ConnectivityMonitor>(
      () => ConnectivityMonitorImpl(
        connectivity: Connectivity(),
        probe: getIt(),
      ),
    )
    ..registerLazySingleton<BatchRepository>(
      () => BatchRepositoryImpl(
        databaseHelper: getIt(),
        batchDao: getIt(),
        imageDao: getIt(),
        storage: getIt(),
        generateId: const Uuid().v4,
      ),
    );
}
