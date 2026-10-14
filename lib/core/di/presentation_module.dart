import 'package:get_it/get_it.dart';
import 'package:snapsync/core/utils/clock.dart';
import 'package:snapsync/presentation/batch/cubit/batch_cubit.dart';
import 'package:snapsync/presentation/camera/cubit/camera_cubit.dart';
import 'package:snapsync/presentation/upload_manager/cubit/sync_cubit.dart';

void registerPresentationModule(GetIt getIt) {
  if (getIt.isRegistered<CameraCubit>()) return;

  getIt
    ..registerFactory<CameraCubit>(CameraCubit.new)
    ..registerFactory<BatchCubit>(
      () => BatchCubit(
        repository: getIt(),
        addCapturedImage: getIt(),
        removeImage: getIt(),
        submitBatchUseCase: getIt(),
        scheduler: getIt(),
      ),
    )
    ..registerFactory<SyncCubit>(
      () => SyncCubit(
        repository: getIt(),
        engine: getIt(),
        connectivity: getIt(),
        settings: getIt(),
        scheduler: getIt(),
        now: utcNow,
      ),
    );
}
