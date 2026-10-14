import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:snapsync/core/constants/app_constants.dart';
import 'package:snapsync/core/error/failure.dart';
import 'package:snapsync/core/utils/clock.dart';
import 'package:snapsync/core/utils/safe_log.dart';
import 'package:snapsync/core/utils/timer_factory.dart';
import 'package:snapsync/domain/camera/camera_lens.dart';
import 'package:snapsync/domain/camera/camera_permission_service.dart';
import 'package:snapsync/domain/camera/camera_service.dart';
import 'package:snapsync/domain/camera/camera_session_info.dart';
import 'package:snapsync/domain/camera/flash_setting.dart';
import 'package:snapsync/domain/camera/preview_geometry.dart';
import 'package:snapsync/domain/camera/ultra_wide_finder.dart';
import 'package:snapsync/domain/camera/zoom_controller.dart';
import 'package:snapsync/domain/camera/zoom_lens_mapping.dart';
import 'package:snapsync/domain/camera/zoom_preset.dart';
import 'package:snapsync/domain/camera/zoom_presets_builder.dart';
import 'package:snapsync/domain/usecases/add_captured_image.dart';
import 'package:snapsync/presentation/camera/cubit/camera_message.dart';
import 'package:snapsync/presentation/camera/cubit/camera_state.dart';
import 'package:snapsync/presentation/camera/cubit/focus_indicator.dart';

/// Drives the camera screen: permission, opening the camera, zoom, focus, lens
/// switching and capturing into the open batch.
///
/// Every asynchronous step carries the "epoch" it started in. Anything that
/// changes the camera's situation (new init, pause, resume, lens switch,
/// close) bumps the epoch, so a result that arrives late is recognised as
/// stale and dropped instead of overwriting newer state. That is what keeps
/// rapid pause/resume cycles and disposal during initialisation safe.
class CameraCubit extends Cubit<CameraState> {
  CameraCubit({
    required this.service,
    required this.permissions,
    required this.addCapturedImage,
    required this._now,
    TimerFactory? timerFactory,
    Future<void> Function(Duration)? delay,
    this.retryDelay = AppConstants.cameraRetryDelay,
    this.minCaptureGap = AppConstants.cameraMinCaptureGap,
    this.focusIndicatorDuration = AppConstants.focusIndicatorDuration,
  }) : _timer = timerFactory ?? realTimer,
       _delay = delay ?? ((d) => Future<void>.delayed(d)),
       super(const CameraState()) {
    _zoom = ZoomController(
      apply: service.setZoom,
      onSettled: _onZoomSettled,
      onError: (_) => _message(CameraMessage.zoomFailed),
    );
    _errorSub = service.errors.listen(_onRuntimeError);
  }

  final CameraService service;
  final CameraPermissionService permissions;
  final AddCapturedImage addCapturedImage;
  final Duration retryDelay;
  final Duration minCaptureGap;
  final Duration focusIndicatorDuration;
  final Clock _now;
  final TimerFactory _timer;
  final Future<void> Function(Duration) _delay;

  late final ZoomController _zoom;
  late final StreamSubscription<CameraFailure> _errorSub;
  final StreamController<CameraMessage> _messages =
      StreamController<CameraMessage>.broadcast();

  /// One-off messages for snackbars.
  Stream<CameraMessage> get messages => _messages.stream;

  /// Opaque handle for the preview widget, and the shape of the displayed
  /// frame, straight from the service.
  Object? get previewHandle => service.previewHandle;

  List<CameraLens> _lenses = const [];
  ZoomPresets? _presets;
  CameraLens? _wantedLens;
  int _epoch = 0;
  bool _paused = false;
  int _recoveries = 0;
  int _focusId = 0;
  int _focusFailures = 0;
  Timer? _focusTimer;
  DateTime? _lastCaptureEnd;

  // ---- starting up -------------------------------------------------------

  /// Checks (and, the first time, asks for) the camera permission, then opens
  /// the camera.
  Future<void> initialise() async {
    _recoveries = 0;
    final epoch = _bump();
    _emit(
      state.copyWith(status: CameraStatus.initialising, clearFailure: true),
    );
    await _start(epoch, requestPermission: true);
  }

  /// For the "try again" button after a denial. Same flow as [initialise]: the
  /// system dialog is shown if the system still allows it.
  Future<void> requestPermission() => initialise();

  /// For the retry button after a camera error.
  Future<void> retry() => initialise();

  /// Opens this app's page in system settings. When the user comes back, the
  /// lifecycle observer calls [resume], which re-checks the permission.
  Future<void> openAppSettings() async {
    try {
      if (!await permissions.openSettings()) {
        _message(CameraMessage.settingsUnavailable);
      }
    } on Object catch (error, stack) {
      logProblem(
        'snapsync.camera',
        'Could not open settings',
        error: error,
        stackTrace: stack,
      );
      _message(CameraMessage.settingsUnavailable);
    }
  }

  Future<void> _start(int epoch, {required bool requestPermission}) async {
    try {
      final permission = await _checkPermission(requestPermission);
      if (_stale(epoch)) return;
      if (permission != CameraPermissionStatus.granted) {
        _showPermissionState(permission);
        return;
      }
      final lens = await _chooseLens();
      if (lens == null || _stale(epoch)) return;
      await _openWithRetry(lens, epoch, initialZoom: state.zoom);
    } on CameraFailure catch (failure) {
      _fail(failure, epoch);
    } on Object catch (error, stack) {
      logProblem(
        'snapsync.camera',
        'Unexpected error starting the camera',
        error: error,
        stackTrace: stack,
        level: 1000,
      );
      _fail(const CameraFailure('Unexpected error'), epoch);
    }
  }

  Future<CameraPermissionStatus> _checkPermission(bool ask) async {
    var status = await permissions.status();
    if (status == CameraPermissionStatus.denied && ask) {
      status = await permissions.request();
    } else if (status == CameraPermissionStatus.denied &&
        state.status == CameraStatus.permissionPermanentlyDenied) {
      // Android's status check cannot tell "denied for good" from "denied", so
      // keep what a request already told us until it is granted.
      status = CameraPermissionStatus.permanentlyDenied;
    }
    return status;
  }

  void _showPermissionState(CameraPermissionStatus status) {
    final permanent = status != CameraPermissionStatus.denied;
    _emit(
      state.copyWith(
        status: permanent
            ? CameraStatus.permissionPermanentlyDenied
            : CameraStatus.permissionDenied,
        canRetry: !permanent,
        clearFocusIndicator: true,
        isCapturing: false,
      ),
    );
  }

  Future<CameraLens?> _chooseLens() async {
    if (_lenses.isEmpty) _lenses = await service.listCameras();
    if (_lenses.isEmpty) {
      _emit(
        state.copyWith(
          status: CameraStatus.noCameraAvailable,
          failureReason: CameraFailureReason.noCameraAvailable,
          canRetry: false,
        ),
      );
      return null;
    }
    final wanted = _wantedLens;
    if (wanted != null && _lenses.contains(wanted)) return wanted;
    return _lensFor(state.lensDirection) ??
        _lensFor(
          state.lensDirection == LensDirection.back
              ? LensDirection.front
              : LensDirection.back,
        );
  }

  CameraLens? _lensFor(LensDirection direction) {
    final matching = _lenses.where((l) => l.direction == direction).toList();
    if (matching.isEmpty) return null;
    return direction == LensDirection.back
        ? UltraWideFinder.mainBack(matching)
        : matching.first;
  }

  /// Opens [lens], with one automatic second attempt after a pause for errors
  /// that may be temporary (camera busy, timed out, disconnected).
  Future<void> _openWithRetry(
    CameraLens lens,
    int epoch, {
    required double initialZoom,
  }) async {
    for (var attempt = 0; ; attempt++) {
      try {
        final info = await service.open(lens);
        if (_stale(epoch)) return; // pause/close releases it, nothing to emit
        _onOpened(info, initialZoom);
        return;
      } on CameraFailure catch (failure) {
        if (_stale(epoch)) return;
        if (attempt == 0 && failure.reason.isTransient) {
          await _delay(retryDelay);
          if (_stale(epoch)) return;
          continue;
        }
        _fail(failure, epoch);
        return;
      }
    }
  }

  void _onOpened(CameraSessionInfo info, double initialZoom) {
    final lens = info.lens;
    _wantedLens = lens;
    final isUltra = _presets?.ultraWideLens?.id == lens.id;
    if (!isUltra) {
      // Presets describe the main camera; opening the separate ultra-wide must
      // not replace them with its own (much narrower) range.
      _presets = ZoomPresetsBuilder.build(
        activeLens: lens,
        backCameras: _lenses
            .where((l) => l.direction == LensDirection.back)
            .toList(),
        minZoom: info.minZoom,
        maxZoom: info.maxZoom,
      );
    }
    _zoom.attach(
      isUltra
          ? ZoomLensMapping.ultraWide(min: info.minZoom, max: info.maxZoom)
          : ZoomLensMapping.standard(min: info.minZoom, max: info.maxZoom),
      initialZoom: initialZoom,
    );
    _focusFailures = 0;
    _emit(
      state.copyWith(
        status: CameraStatus.ready,
        clearFailure: true,
        canRetry: false,
        lensDirection: lens.direction,
        activeLensId: lens.id,
        canSwitchLens:
            _lensFor(
              lens.direction == LensDirection.back
                  ? LensDirection.front
                  : LensDirection.back,
            ) !=
            null,
        presets: _presets!.presets,
        zoom: _zoom.zoom,
        minZoom: _zoom.displayMin,
        maxZoom: _zoom.displayMax,
        supportsFlash: info.supportsFlash,
        supportsFocus: info.supportsFocus,
        focusLocked: false,
        clearFocusIndicator: true,
      ),
    );
    unawaited(_restoreFlash(info));
  }

  /// A newly opened camera starts with the flash off; put the user's choice
  /// back.
  Future<void> _restoreFlash(CameraSessionInfo info) async {
    if (!info.supportsFlash || state.flash == FlashSetting.off) return;
    await _applyFlash(state.flash);
  }

  // ---- failures ----------------------------------------------------------

  void _fail(CameraFailure failure, int epoch) {
    if (_stale(epoch)) return;
    logProblem('snapsync.camera', 'Camera failed', error: failure);
    switch (failure.reason) {
      case CameraFailureReason.permission:
        unawaited(_recheckPermission(epoch));
      case CameraFailureReason.noCameraAvailable:
        _emitFailure(CameraStatus.noCameraAvailable, failure, canRetry: false);
      case CameraFailureReason.inUse:
        _emitFailure(CameraStatus.cameraInUse, failure, canRetry: true);
      case CameraFailureReason.disconnected:
        _emitFailure(CameraStatus.unavailable, failure, canRetry: true);
      case _:
        _emitFailure(CameraStatus.error, failure, canRetry: true);
    }
  }

  void _emitFailure(
    CameraStatus status,
    CameraFailure failure, {
    required bool canRetry,
  }) {
    _zoom.detach();
    _emit(
      state.copyWith(
        status: status,
        failureReason: failure.reason,
        canRetry: canRetry,
        clearFocusIndicator: true,
        isCapturing: false,
      ),
    );
  }

  Future<void> _recheckPermission(int epoch) async {
    try {
      final status = await permissions.status();
      if (_stale(epoch)) return;
      if (status == CameraPermissionStatus.granted) {
        _emitFailure(
          CameraStatus.error,
          const CameraFailure('Camera refused access'),
          canRetry: true,
        );
      } else {
        _showPermissionState(status);
      }
    } on Object catch (error, stack) {
      logProblem(
        'snapsync.camera',
        'Permission check failed',
        error: error,
        stackTrace: stack,
      );
      _emitFailure(
        CameraStatus.error,
        const CameraFailure('Permission check'),
        canRetry: true,
      );
    }
  }

  /// A failure while previewing. One automatic re-initialisation for errors
  /// that may be temporary; after that the error is shown.
  void _onRuntimeError(CameraFailure failure) {
    if (state.status != CameraStatus.ready || _paused) return;
    if (failure.reason.isTransient && _recoveries < 1) {
      _recoveries++;
      unawaited(_recover());
    } else {
      _fail(failure, _epoch);
    }
  }

  Future<void> _recover() async {
    final epoch = _bump();
    _emit(
      state.copyWith(
        status: CameraStatus.initialising,
        clearFocusIndicator: true,
      ),
    );
    await _start(epoch, requestPermission: false);
  }

  // ---- app lifecycle -----------------------------------------------------

  /// Releases the camera (the app went to the background).
  Future<void> pause() async {
    if (_paused) return;
    _paused = true;
    _bump();
    _focusTimer?.cancel();
    _zoom.detach();
    if (state.status == CameraStatus.ready ||
        state.status == CameraStatus.initialising) {
      _emit(
        state.copyWith(
          status: CameraStatus.paused,
          clearFocusIndicator: true,
          isCapturing: false,
        ),
      );
    }
    await _releaseCamera();
  }

  /// Re-opens the camera, and re-checks the permission so a grant made in
  /// system settings is picked up. Never prompts.
  Future<void> resume() async {
    if (!_paused) return;
    _paused = false;
    final epoch = _bump();
    if (state.status == CameraStatus.paused) {
      _emit(state.copyWith(status: CameraStatus.initialising));
    }
    await _start(epoch, requestPermission: false);
  }

  Future<void> _releaseCamera() async {
    try {
      await service.dispose();
    } on Failure catch (failure) {
      logProblem(
        'snapsync.camera',
        'Could not release the camera',
        error: failure,
      );
    }
  }

  // ---- lens and zoom -----------------------------------------------------

  /// Switches between the back and front camera. Zoom goes back to 1x.
  Future<void> switchLens() async {
    if (!state.isReady) return;
    final target = _lensFor(
      state.lensDirection == LensDirection.back
          ? LensDirection.front
          : LensDirection.back,
    );
    if (target == null) {
      _message(CameraMessage.noOtherCamera);
      return;
    }
    await _switchTo(target, zoom: 1);
  }

  /// Applies a zoom button. Switches cameras first when the preset needs it.
  Future<void> selectPreset(ZoomPreset preset) async {
    if (!state.isReady) return;
    final target = preset.cameraToSwitchTo;
    if (target != null && target.id != state.activeLensId) {
      await _switchTo(target, zoom: preset.targetZoom);
    } else {
      _setZoom(preset.targetZoom);
    }
  }

  Future<void> _switchTo(CameraLens lens, {required double zoom}) async {
    _recoveries = 0;
    final epoch = _bump();
    _emit(
      state.copyWith(
        status: CameraStatus.initialising,
        clearFocusIndicator: true,
      ),
    );
    try {
      await _openWithRetry(lens, epoch, initialZoom: zoom);
    } on Object catch (error, stack) {
      logProblem(
        'snapsync.camera',
        'Unexpected error switching cameras',
        error: error,
        stackTrace: stack,
        level: 1000,
      );
      _fail(const CameraFailure('Unexpected error'), epoch);
    }
  }

  void onPinchStart() {
    if (state.isReady) _zoom.pinchStart();
  }

  void onPinchUpdate(double scale) {
    if (state.isReady) _setZoom(_zoom.pinchUpdate(scale));
  }

  void onPinchEnd() => _zoom.pinchEnd();

  /// [value] is the slider position from 0 to 1.
  void setZoomFromSlider(double value) {
    if (state.isReady) _setZoom(_zoom.setZoomFromSlider(value));
  }

  void _setZoom(double display) {
    final applied = _zoom.setZoom(display);
    _emit(state.copyWith(zoom: applied));
  }

  /// Only differs from the shown zoom when applying it failed.
  void _onZoomSettled(double actual) {
    if (isClosed || (state.zoom - actual).abs() < 1e-6) return;
    _zoom.reconcile(actual);
    _emit(state.copyWith(zoom: actual));
  }

  // ---- focus -------------------------------------------------------------

  /// A tap at [localPosition] inside a widget of [previewSize] (the area that
  /// catches gestures, which may be larger than the preview itself).
  Future<void> onTapToFocus(Offset localPosition, Size previewSize) async {
    final point = _focusPoint(localPosition, previewSize);
    if (point == null) return;
    final id = _startIndicator(localPosition, FocusPhase.focusing);
    final wasLocked = state.focusLocked;
    try {
      if (wasLocked) await service.setFocusLocked(locked: false);
      await _focusAt(point);
      if (id != _focusId) return;
      _focusFailures = 0;
      _emit(
        state.copyWith(
          focusLocked: false,
          focusIndicator: state.focusIndicator?.withPhase(FocusPhase.done),
        ),
      );
      _scheduleIndicatorClear(id);
    } on CameraFailure catch (failure) {
      if (id == _focusId) _onFocusFailure(failure);
    }
  }

  /// A long press locks focus and exposure at [localPosition]. A later tap, or
  /// [unlockFocus], releases it.
  Future<void> onLongPressToLockFocus(
    Offset localPosition,
    Size previewSize,
  ) async {
    final point = _focusPoint(localPosition, previewSize);
    if (point == null) return;
    final id = _startIndicator(localPosition, FocusPhase.focusing);
    try {
      await _focusAt(point);
      await service.setFocusLocked(locked: true);
      if (id != _focusId) return;
      _focusFailures = 0;
      _emit(
        state.copyWith(
          focusLocked: true,
          focusIndicator: state.focusIndicator?.withPhase(FocusPhase.locked),
        ),
      );
    } on CameraFailure catch (failure) {
      if (id == _focusId) _onFocusFailure(failure);
    }
  }

  Future<void> unlockFocus() async {
    if (!state.focusLocked) return;
    try {
      await service.setFocusLocked(locked: false);
    } on CameraFailure catch (failure) {
      logProblem('snapsync.camera', 'Could not unlock focus', error: failure);
    }
    _focusTimer?.cancel();
    _emit(state.copyWith(focusLocked: false, clearFocusIndicator: true));
  }

  math.Point<double>? _focusPoint(Offset local, Size size) {
    if (!state.isReady || !state.supportsFocus) return null;
    final ratio = service.previewAspectRatio;
    if (ratio == null) return null;
    return PreviewGeometry.toNormalizedPoint(
      local: math.Point(local.dx, local.dy),
      containerWidth: size.width,
      containerHeight: size.height,
      aspectRatio: ratio,
    );
  }

  Future<void> _focusAt(math.Point<double> point) async {
    await service.setFocusPoint(point);
    await service.setExposurePoint(point);
  }

  /// Shows the indicator immediately, replacing any earlier one.
  int _startIndicator(Offset position, FocusPhase phase) {
    final id = ++_focusId;
    _focusTimer?.cancel();
    _emit(
      state.copyWith(
        focusIndicator: FocusIndicator(
          id: id,
          position: position,
          phase: phase,
        ),
      ),
    );
    return id;
  }

  void _scheduleIndicatorClear(int id) {
    _focusTimer?.cancel();
    _focusTimer = _timer(focusIndicatorDuration, () {
      if (id == _focusId) _emit(state.copyWith(clearFocusIndicator: true));
    });
  }

  /// One rejected request shows a failed ring. Repeated rejections mean the
  /// camera does not take focus points, so the feature is switched off and
  /// nothing is shown.
  void _onFocusFailure(CameraFailure failure) {
    logProblem('snapsync.camera', 'Focus request rejected', error: failure);
    _focusFailures++;
    if (_focusFailures >= 2) {
      _focusTimer?.cancel();
      _emit(state.copyWith(supportsFocus: false, clearFocusIndicator: true));
      return;
    }
    _emit(
      state.copyWith(
        focusIndicator: state.focusIndicator?.withPhase(FocusPhase.failed),
      ),
    );
    _scheduleIndicatorClear(_focusId);
  }

  // ---- flash -------------------------------------------------------------

  Future<void> cycleFlash() async {
    if (!state.isReady) return;
    if (!state.supportsFlash) {
      _message(CameraMessage.flashUnavailable);
      return;
    }
    await _applyFlash(state.flash.next);
  }

  Future<void> _applyFlash(FlashSetting setting) async {
    try {
      await service.setFlash(setting);
      _emit(state.copyWith(flash: setting));
    } on CameraFailure catch (failure) {
      logProblem('snapsync.camera', 'Flash change rejected', error: failure);
      _message(CameraMessage.flashUnavailable);
      if (failure.reason == CameraFailureReason.flashUnsupported) {
        _emit(state.copyWith(supportsFlash: false, flash: FlashSetting.off));
      }
    }
  }

  // ---- capture -----------------------------------------------------------

  /// Takes a picture and adds it to the open batch. Ignored while another
  /// capture is running or too soon after the last one.
  Future<void> capture() async {
    if (!state.isReady || state.isCapturing || _tooSoonAfterLastCapture()) {
      return;
    }
    _emit(state.copyWith(isCapturing: true));
    String? temporaryPath;
    try {
      temporaryPath = await service.capture();
      await addCapturedImage(temporaryPath);
    } on CameraFailure catch (failure) {
      logProblem('snapsync.camera', 'Capture failed', error: failure);
      _message(CameraMessage.captureFailed);
    } on Failure catch (failure) {
      // Storage or database: the shot could not be saved. The camera is fine.
      logProblem('snapsync.camera', 'Saving the photo failed', error: failure);
      _message(
        failure is StorageFailure || failure is DatabaseFailure
            ? CameraMessage.storageFailed
            : CameraMessage.captureFailed,
      );
    } on Object catch (error, stack) {
      logProblem(
        'snapsync.camera',
        'Unexpected capture error',
        error: error,
        stackTrace: stack,
        level: 1000,
      );
      _message(CameraMessage.captureFailed);
    } finally {
      if (temporaryPath != null) await _discard(temporaryPath);
      _lastCaptureEnd = _now();
      _emit(state.copyWith(isCapturing: false));
    }
  }

  bool _tooSoonAfterLastCapture() {
    final last = _lastCaptureEnd;
    return last != null && _now().difference(last) < minCaptureGap;
  }

  /// The photo now lives in app storage, so the camera's temporary copy goes.
  Future<void> _discard(String path) async {
    try {
      await service.discardTemporary(path);
    } on Failure catch (failure) {
      logProblem(
        'snapsync.camera',
        'Could not delete a temporary photo',
        error: failure,
      );
    }
  }

  // ---- plumbing ----------------------------------------------------------

  int _bump() => ++_epoch;

  bool _stale(int epoch) => isClosed || epoch != _epoch;

  void _emit(CameraState next) {
    if (!isClosed) emit(next);
  }

  void _message(CameraMessage message) {
    if (!_messages.isClosed) _messages.add(message);
  }

  @override
  Future<void> close() async {
    _bump();
    _focusTimer?.cancel();
    _zoom.dispose();
    // The listener is removed at once; nothing depends on the future, and
    // waiting for it must not hold up releasing the camera.
    unawaited(_errorSub.cancel());
    // Waits for an open that is still in flight, then releases the camera.
    await _releaseCamera();
    await _messages.close();
    return super.close();
  }
}
