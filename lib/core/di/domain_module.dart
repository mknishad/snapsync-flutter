import 'package:get_it/get_it.dart';
import 'package:snapsync/core/constants/app_constants.dart';
import 'package:snapsync/core/utils/clock.dart';
import 'package:snapsync/domain/services/exponential_backoff.dart';
import 'package:snapsync/domain/services/sync_engine.dart';
import 'package:snapsync/domain/usecases/add_captured_image.dart';
import 'package:snapsync/domain/usecases/get_uploadable_images.dart';
import 'package:snapsync/domain/usecases/recover_interrupted_uploads.dart';
import 'package:snapsync/domain/usecases/record_upload_result.dart';
import 'package:snapsync/domain/usecases/remove_image.dart';
import 'package:snapsync/domain/usecases/submit_batch.dart';

/// Safe to call from either isolate and more than once.
void registerDomainModule(GetIt getIt) {
  if (getIt.isRegistered<AddCapturedImage>()) return;

  getIt
    ..registerLazySingleton<ExponentialBackoff>(
      () => ExponentialBackoff(
        baseDelay: AppConstants.backoffBaseDelay,
        multiplier: AppConstants.backoffMultiplier,
        maxDelay: AppConstants.backoffMaxDelay,
        jitterRatio: AppConstants.backoffJitterRatio,
      ),
    )
    ..registerLazySingleton<AddCapturedImage>(() => AddCapturedImage(getIt()))
    ..registerLazySingleton<SubmitBatch>(() => SubmitBatch(getIt()))
    ..registerLazySingleton<RemoveImage>(() => RemoveImage(getIt()))
    ..registerLazySingleton<GetUploadableImages>(
      () => GetUploadableImages(getIt(), now: utcNow),
    )
    ..registerLazySingleton<RecordUploadResult>(
      () => RecordUploadResult(getIt(), backoff: getIt(), now: utcNow),
    )
    ..registerLazySingleton<RecoverInterruptedUploads>(
      () => RecoverInterruptedUploads(getIt()),
    )
    ..registerLazySingleton<SyncEngine>(
      () => SyncEngine(
        repository: getIt(),
        uploadApi: getIt(),
        recordResult: getIt(),
        recoverInterrupted: getIt(),
        connectivity: getIt(),
        settings: getIt(),
        now: utcNow,
      ),
    );
}
