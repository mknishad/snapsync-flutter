import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:snapsync/core/error/failure.dart';
import 'package:snapsync/core/utils/safe_log.dart';
import 'package:snapsync/domain/entities/capture_batch.dart';
import 'package:snapsync/domain/errors/domain_errors.dart';
import 'package:snapsync/domain/repositories/batch_repository.dart';
import 'package:snapsync/domain/repositories/sync_scheduler.dart';
import 'package:snapsync/domain/usecases/add_captured_image.dart';
import 'package:snapsync/domain/usecases/remove_image.dart';
import 'package:snapsync/domain/usecases/submit_batch.dart';
import 'package:snapsync/presentation/batch/cubit/batch_state.dart';

/// The batch being captured into. Call [start] once after creating it.
class BatchCubit extends Cubit<BatchState> {
  BatchCubit({
    required this.repository,
    required this.addCapturedImage,
    required this.removeImage,
    required this.submitBatchUseCase,
    required this.scheduler,
  }) : super(const BatchState());

  final BatchRepository repository;
  final AddCapturedImage addCapturedImage;
  final RemoveImage removeImage;
  final SubmitBatch submitBatchUseCase;
  final SyncScheduler scheduler;

  StreamSubscription<CaptureBatch?>? _subscription;

  Future<void> start() async {
    await _subscription?.cancel();
    _subscription = repository.watchOpenBatch().listen(
      (batch) => emit(BatchState(status: BatchStatus.ready, currentBatch: batch)),
      onError: (Object error) => emit(
        BatchState(
          status: BatchStatus.failure,
          currentBatch: state.currentBatch,
          failure: error is Failure
              ? error
              : const UnknownFailure('Could not load the batch'),
        ),
      ),
    );
  }

  /// Adds a captured file to the open batch.
  Future<void> captureImage(String capturedFilePath) {
    return _guard(() => addCapturedImage(capturedFilePath));
  }

  Future<void> deleteImage(String imageId) {
    return _guard(() => removeImage(imageId));
  }

  /// Submits the open batch, then asks for a background sync so the upload
  /// continues even if the app goes away.
  Future<void> submitBatch() async {
    final batch = state.currentBatch;
    if (batch == null || batch.images.isEmpty) return;

    emit(BatchState(status: BatchStatus.submitting, currentBatch: batch));
    final submitted = await _guard(() => submitBatchUseCase(batch.id));
    if (!submitted) return;

    try {
      await scheduler.enqueueSyncNow();
    } on Object catch (error, stack) {
      // The batch is safely submitted; the periodic task still picks it up.
      logProblem(
        'snapsync.batch',
        'Could not enqueue background sync',
        error: error,
        stackTrace: stack,
        level: 1000,
      );
    }
  }

  Future<bool> _guard(Future<Object?> Function() action) async {
    try {
      await action();
      return true;
    } on Failure catch (failure) {
      emit(
        BatchState(
          status: BatchStatus.failure,
          currentBatch: state.currentBatch,
          failure: failure,
        ),
      );
    } on IllegalBatchStateError catch (error) {
      emit(
        BatchState(
          status: BatchStatus.failure,
          currentBatch: state.currentBatch,
          failure: UnknownFailure(error.message),
        ),
      );
    }
    return false;
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
