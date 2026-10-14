import 'package:get_it/get_it.dart';
import 'package:snapsync/domain/usecases/add_image_to_batch.dart';
import 'package:snapsync/domain/usecases/create_batch.dart';
import 'package:snapsync/domain/usecases/sync_pending_uploads.dart';
import 'package:snapsync/domain/usecases/watch_pending_batches.dart';

void registerDomainModule(GetIt getIt) {
  if (getIt.isRegistered<CreateBatch>()) return;

  getIt
    ..registerLazySingleton<CreateBatch>(() => CreateBatch(getIt()))
    ..registerLazySingleton<AddImageToBatch>(() => AddImageToBatch(getIt()))
    ..registerLazySingleton<WatchPendingBatches>(
      () => WatchPendingBatches(getIt()),
    )
    ..registerLazySingleton<SyncPendingUploads>(
      () => SyncPendingUploads(getIt()),
    );
}
