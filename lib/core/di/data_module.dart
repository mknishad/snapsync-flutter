import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get_it/get_it.dart';
import 'package:snapsync/data/connectivity/connectivity_monitor_impl.dart';
import 'package:snapsync/data/local/daos/batch_dao.dart';
import 'package:snapsync/data/local/daos/image_dao.dart';
import 'package:snapsync/data/local/database_helper.dart';
import 'package:snapsync/data/remote/mock_upload_api.dart';
import 'package:snapsync/data/repositories/batch_repository_impl.dart';
import 'package:snapsync/data/repositories/upload_repository_impl.dart';
import 'package:snapsync/data/storage/image_storage_service.dart';
import 'package:snapsync/domain/repositories/batch_repository.dart';
import 'package:snapsync/domain/repositories/connectivity_monitor.dart';
import 'package:snapsync/domain/repositories/upload_api.dart';
import 'package:snapsync/domain/repositories/upload_repository.dart';

void registerDataModule(GetIt getIt) {
  if (getIt.isRegistered<DatabaseHelper>()) return;

  getIt
    ..registerLazySingleton<DatabaseHelper>(DatabaseHelper.new)
    ..registerLazySingleton<BatchDao>(() => BatchDao(getIt()))
    ..registerLazySingleton<ImageDao>(() => ImageDao(getIt()))
    ..registerLazySingleton<ImageStorageService>(ImageStorageService.new)
    ..registerLazySingleton<ConnectivityMonitor>(
      () => ConnectivityMonitorImpl(Connectivity()),
    )
    // Swap for RealUploadApi (see data/remote/real_upload_api.dart) once an
    // endpoint exists.
    ..registerLazySingleton<UploadApi>(MockUploadApi.new)
    ..registerLazySingleton<BatchRepository>(
      () => BatchRepositoryImpl(
        batchDao: getIt(),
        imageDao: getIt(),
        storage: getIt(),
      ),
    )
    ..registerLazySingleton<UploadRepository>(
      () => UploadRepositoryImpl(
        batchRepository: getIt(),
        uploadApi: getIt(),
        connectivityMonitor: getIt(),
      ),
    );
}
