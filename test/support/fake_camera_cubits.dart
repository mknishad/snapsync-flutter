import 'dart:ui';

import 'package:mocktail/mocktail.dart';
import 'package:snapsync/core/utils/clock.dart';
import 'package:snapsync/domain/camera/zoom_preset.dart';
import 'package:snapsync/domain/repositories/batch_repository.dart';
import 'package:snapsync/domain/repositories/sync_scheduler.dart';
import 'package:snapsync/domain/usecases/add_captured_image.dart';
import 'package:snapsync/domain/usecases/remove_image.dart';
import 'package:snapsync/domain/usecases/submit_batch.dart';
import 'package:snapsync/presentation/batch/cubit/batch_cubit.dart';
import 'package:snapsync/presentation/batch/cubit/batch_state.dart';
import 'package:snapsync/presentation/camera/cubit/camera_cubit.dart';
import 'package:snapsync/presentation/camera/cubit/camera_state.dart';

import 'camera_fakes.dart';

class _MockAdd extends Mock implements AddCapturedImage {}

class _MockRemove extends Mock implements RemoveImage {}

class _MockSubmit extends Mock implements SubmitBatch {}

class _MockRepository extends Mock implements BatchRepository {}

class _MockScheduler extends Mock implements SyncScheduler {}

/// A real [CameraCubit] on a fake camera whose actions are recorded instead of
/// performed. Tests set its state with [push].
class FakeCameraCubit extends CameraCubit {
  FakeCameraCubit(CameraState initial)
    : super(
        service: FakeCameraService(),
        permissions: FakeCameraPermissions(),
        addCapturedImage: _MockAdd(),
        now: utcNow,
      ) {
    emit(initial);
  }

  final List<String> calls = [];
  Offset? lastTap;
  Size? lastTapArea;

  void push(CameraState state) => emit(state);

  @override
  Future<void> capture() async => calls.add('capture');

  @override
  Future<void> cycleFlash() async => calls.add('cycleFlash');

  @override
  Future<void> switchLens() async => calls.add('switchLens');

  @override
  Future<void> retry() async => calls.add('retry');

  @override
  Future<void> requestPermission() async => calls.add('requestPermission');

  @override
  Future<void> openAppSettings() async => calls.add('openAppSettings');

  @override
  Future<void> selectPreset(ZoomPreset preset) async =>
      calls.add('preset:${preset.label}');

  @override
  void setZoomFromSlider(double value) => calls.add('slider');

  @override
  Future<void> onTapToFocus(Offset localPosition, Size previewSize) async {
    lastTap = localPosition;
    lastTapArea = previewSize;
    calls.add('tap');
  }

  @override
  Future<void> onLongPressToLockFocus(
    Offset localPosition,
    Size previewSize,
  ) async {
    lastTap = localPosition;
    lastTapArea = previewSize;
    calls.add('longPress');
  }

  @override
  void onPinchStart() => calls.add('pinchStart');

  @override
  void onPinchUpdate(double scale) => calls.add('pinch');

  @override
  void onPinchEnd() => calls.add('pinchEnd');
}

/// A real [BatchCubit] whose actions are recorded. Set [failSubmit] to make the
/// next submit fail.
class FakeBatchCubit extends BatchCubit {
  FakeBatchCubit(BatchState initial)
    : super(
        repository: _MockRepository(),
        addCapturedImage: _MockAdd(),
        removeImage: _MockRemove(),
        submitBatchUseCase: _MockSubmit(),
        scheduler: _MockScheduler(),
      ) {
    emit(initial);
  }

  final List<String> calls = [];
  bool failSubmit = false;

  void push(BatchState state) => emit(state);

  @override
  Future<void> start() async {}

  @override
  Future<void> submitBatch() async {
    calls.add('submit');
    emit(
      BatchState(
        status: failSubmit ? BatchStatus.failure : BatchStatus.submitting,
        currentBatch: state.currentBatch,
      ),
    );
  }

  @override
  Future<void> deleteImage(String imageId) async =>
      calls.add('delete:$imageId');

  @override
  Future<void> discardBatch() async => calls.add('discard');
}
