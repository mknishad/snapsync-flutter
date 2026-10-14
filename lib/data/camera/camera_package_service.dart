import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:snapsync/core/constants/app_constants.dart';
import 'package:snapsync/core/error/failure.dart';
import 'package:snapsync/core/utils/safe_log.dart';
import 'package:snapsync/data/camera/camera_error_mapper.dart';
import 'package:snapsync/data/camera/camera_lens_mapper.dart';
import 'package:snapsync/domain/camera/camera_lens.dart';
import 'package:snapsync/domain/camera/camera_service.dart';
import 'package:snapsync/domain/camera/camera_session_info.dart';
import 'package:snapsync/domain/camera/flash_setting.dart';

typedef CameraListLoader = Future<List<CameraDescription>> Function();
typedef CameraControllerFactory = CameraController Function(
  CameraDescription description,
  ResolutionPreset preset,
);

/// [CameraService] on the `camera` package (0.12.x, with the CameraX backend on
/// Android).
///
/// What differs between devices, and how it is handled:
/// - Camera list: Android lists one logical back camera on most phones, or
///   several physical ones on others; `lensType` is only filled on iOS.
/// - Zoom range: `getMinZoomLevel` can be below 1.0 (ultra-wide reached by
///   zoom) or exactly 1.0; the maximum varies a lot. Both are read per camera.
/// - Zoom errors: on Android `setZoomLevel` does not throw; a bad value is
///   reported later on the error stream. So values are always clamped first.
/// - Focus and flash: there is no "is supported" query. They are inferred from
///   the lens direction, and a plugin exception turns the feature off.
/// - Orientation: capture orientation is NOT locked. With the activity free to
///   rotate, CameraX sets the target rotation from the display at capture time,
///   so saved JPEGs come out upright; the preview widget rotates itself.
///   Locking portrait would save sideways images for landscape shots.
class CameraPackageService implements CameraService {
  CameraPackageService({
    CameraListLoader? loadCameras,
    CameraControllerFactory? controllerFactory,
    this.initTimeout = AppConstants.cameraInitTimeout,
  }) : _loadCameras = loadCameras ?? availableCameras,
       _controllerFactory = controllerFactory ?? _defaultFactory;

  final CameraListLoader _loadCameras;
  final CameraControllerFactory _controllerFactory;
  final Duration initTimeout;

  /// High first, then lower if the device cannot do it. JPEG, no audio.
  static const _resolutions = [
    ResolutionPreset.high,
    ResolutionPreset.medium,
    ResolutionPreset.low,
  ];

  static CameraController _defaultFactory(
    CameraDescription description,
    ResolutionPreset preset,
  ) {
    return CameraController(
      description,
      preset,
      enableAudio: false, // no microphone permission needed
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
  }

  final Map<String, CameraDescription> _descriptions = {};
  final StreamController<CameraFailure> _errors =
      StreamController<CameraFailure>.broadcast();

  List<CameraLens>? _lenses;
  CameraController? _controller;
  bool _reportedError = false;

  /// open and dispose run one after another, never overlapping.
  Future<void> _queue = Future<void>.value();

  // ---- discovery ---------------------------------------------------------

  @override
  Future<List<CameraLens>> listCameras() async {
    final known = _lenses;
    if (known != null) return known;
    try {
      final descriptions = await _loadCameras();
      _descriptions
        ..clear()
        ..addEntries(descriptions.map((d) => MapEntry(d.name, d)));
      final lenses = descriptions
          .map((d) => d.toLens())
          .whereType<CameraLens>()
          .where((l) => l.direction != LensDirection.external)
          .toList();
      return _lenses = lenses;
    } on CameraException catch (e) {
      throw CameraErrorMapper.fromException(e.code, e.description);
    }
  }

  // ---- lifecycle ---------------------------------------------------------

  @override
  Future<CameraSessionInfo> open(CameraLens lens) =>
      _serialised(() => _open(lens));

  @override
  Future<void> dispose() => _serialised(_release);

  Future<T> _serialised<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    // The queue keeps going even if this action fails.
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<CameraSessionInfo> _open(CameraLens lens) async {
    await _release();
    final description = _descriptions[lens.id];
    if (description == null) {
      throw const CameraFailure(
        'Requested camera is not in the list',
        reason: CameraFailureReason.noCameraAvailable,
      );
    }

    CameraFailure? last;
    for (final preset in _resolutions) {
      final controller = _controllerFactory(description, preset);
      try {
        await controller.initialize().timeout(initTimeout);
        return await _adopt(controller, lens);
      } on TimeoutException {
        await _disposeQuietly(controller);
        throw const CameraFailure(
          'Opening the camera timed out',
          reason: CameraFailureReason.initTimeout,
        );
      } on CameraException catch (e) {
        await _disposeQuietly(controller);
        last = CameraErrorMapper.fromException(e.code, e.description);
        // A lower resolution only helps with configuration problems.
        if (last.reason != CameraFailureReason.unknown) throw last;
      }
    }
    throw last ?? const CameraFailure('Could not open the camera');
  }

  Future<CameraSessionInfo> _adopt(
    CameraController controller,
    CameraLens lens,
  ) async {
    var min = 1.0;
    var max = 1.0;
    try {
      min = await controller.getMinZoomLevel();
      max = await controller.getMaxZoomLevel();
    } on CameraException catch (e) {
      // Fall back to "no zoom" rather than refusing to show the camera.
      logProblem('snapsync.camera', 'Could not read the zoom range', error: e);
    }
    _controller = controller;
    _reportedError = false;
    controller.addListener(_onControllerChanged);

    final isBack = lens.direction == LensDirection.back;
    return CameraSessionInfo(
      lens: lens,
      minZoom: min,
      maxZoom: max < min ? min : max,
      supportsFocus: isBack,
      supportsFlash: isBack,
    );
  }

  Future<void> _release() async {
    final controller = _controller;
    if (controller == null) return;
    _controller = null;
    controller.removeListener(_onControllerChanged);
    await _disposeQuietly(controller);
  }

  Future<void> _disposeQuietly(CameraController controller) async {
    try {
      await controller.dispose();
    } on CameraException catch (e) {
      logProblem('snapsync.camera', 'Could not dispose the camera', error: e);
    }
  }

  void _onControllerChanged() {
    final value = _controller?.value;
    if (value == null || !value.hasError) {
      _reportedError = false;
      return;
    }
    if (_reportedError) return; // one report per error episode
    _reportedError = true;
    if (!_errors.isClosed) {
      _errors.add(CameraErrorMapper.fromRuntimeError(value.errorDescription));
    }
  }

  // ---- preview -----------------------------------------------------------

  @override
  Object? get previewHandle {
    final controller = _controller;
    return controller != null && controller.value.isInitialized
        ? controller
        : null;
  }

  @override
  double? get previewAspectRatio {
    final value = _controller?.value;
    if (value == null || !value.isInitialized) return null;
    // Same rule the plugin's CameraPreview widget uses to shape the preview.
    final orientation =
        value.lockedCaptureOrientation ?? value.deviceOrientation;
    final landscape =
        orientation == DeviceOrientation.landscapeLeft ||
        orientation == DeviceOrientation.landscapeRight;
    return landscape ? value.aspectRatio : 1 / value.aspectRatio;
  }

  @override
  Stream<CameraFailure> get errors => _errors.stream;

  // ---- controls ----------------------------------------------------------

  @override
  Future<void> setZoom(double controllerZoom) {
    return _run(
      CameraFailureReason.zoomFailed,
      (c) => c.setZoomLevel(controllerZoom),
    );
  }

  @override
  Future<void> setFocusPoint(math.Point<double> point) {
    return _run(
      CameraFailureReason.focusUnsupported,
      (c) => c.setFocusPoint(Offset(point.x, point.y)),
    );
  }

  @override
  Future<void> setExposurePoint(math.Point<double> point) {
    return _run(
      CameraFailureReason.focusUnsupported,
      (c) => c.setExposurePoint(Offset(point.x, point.y)),
    );
  }

  @override
  Future<void> setFocusLocked({required bool locked}) {
    return _run(CameraFailureReason.focusUnsupported, (c) async {
      await c.setFocusMode(locked ? FocusMode.locked : FocusMode.auto);
      await c.setExposureMode(locked ? ExposureMode.locked : ExposureMode.auto);
    });
  }

  @override
  Future<void> setFlash(FlashSetting setting) {
    final mode = switch (setting) {
      FlashSetting.off => FlashMode.off,
      FlashSetting.auto => FlashMode.auto,
      FlashSetting.always => FlashMode.always,
    };
    return _run(
      CameraFailureReason.flashUnsupported,
      (c) => c.setFlashMode(mode),
    );
  }

  @override
  Future<String> capture() async {
    final controller = _requireController();
    try {
      final file = await controller.takePicture();
      return file.path;
    } on CameraException catch (e) {
      final mapped = CameraErrorMapper.fromException(e.code, e.description);
      // A closed or disconnected camera is a runtime problem, not a bad shot.
      final reason = mapped.reason == CameraFailureReason.unknown
          ? CameraFailureReason.captureFailed
          : mapped.reason;
      throw CameraFailure(mapped.message, reason: reason);
    }
  }

  @override
  Future<void> discardTemporary(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on FileSystemException catch (e) {
      throw StorageFailure('Could not delete a temporary photo: ${e.message}');
    }
  }

  // ---- helpers -----------------------------------------------------------

  CameraController _requireController() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      throw const CameraFailure(
        'The camera is not open',
        reason: CameraFailureReason.disposed,
      );
    }
    return controller;
  }

  Future<void> _run(
    CameraFailureReason fallback,
    Future<void> Function(CameraController controller) action,
  ) async {
    final controller = _requireController();
    try {
      await action(controller);
    } on CameraException catch (e) {
      final mapped = CameraErrorMapper.fromException(e.code, e.description);
      throw CameraFailure(
        mapped.message,
        reason: mapped.reason == CameraFailureReason.unknown
            ? fallback
            : mapped.reason,
      );
    } on ArgumentError catch (e) {
      throw CameraFailure(
        'Invalid camera argument: ${e.message}',
        reason: fallback,
      );
    }
  }
}
