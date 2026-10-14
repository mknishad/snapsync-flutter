import 'package:get_it/get_it.dart';
import 'package:snapsync/presentation/batch/cubit/batch_cubit.dart';
import 'package:snapsync/presentation/camera/cubit/camera_cubit.dart';
import 'package:snapsync/presentation/upload_manager/cubit/sync_cubit.dart';

void registerPresentationModule(GetIt getIt) {
  if (getIt.isRegistered<CameraCubit>()) return;

  getIt
    ..registerFactory<CameraCubit>(CameraCubit.new)
    ..registerFactory<BatchCubit>(BatchCubit.new)
    ..registerFactory<SyncCubit>(SyncCubit.new);
}
