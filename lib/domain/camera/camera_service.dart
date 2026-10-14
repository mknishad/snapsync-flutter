import 'dart:math' as math;

import 'package:snapsync/core/error/failure.dart';
import 'package:snapsync/domain/camera/camera_lens.dart';
import 'package:snapsync/domain/camera/camera_session_info.dart';
import 'package:snapsync/domain/camera/flash_setting.dart';

/// The camera hardware, behind an interface so the cubit can be tested with a
/// fake. One service owns one camera controller at a time.
///
/// Every method throws a [CameraFailure] (never a raw plugin exception).
/// Opening and closing are serialised, so a [dispose] that arrives while an
/// [open] is in flight waits for it and then releases it; nothing leaks.
abstract interface class CameraService {
  /// Back and front cameras. Read from the platform once and remembered.
  Future<List<CameraLens>> listCameras();

  /// Opens [lens], closing any camera that is open. Starts at a high resolution
  /// and falls back to lower ones if that fails. Times out after
  /// `AppConstants.cameraInitTimeout`.
  Future<CameraSessionInfo> open(CameraLens lens);

  /// Releases the camera. Safe to call at any time, including during [open] and
  /// more than once.
  Future<void> dispose();

  /// An opaque handle for the preview widget, or null when no camera is open.
  /// Only the matching preview widget in the presentation layer understands it.
  Object? get previewHandle;

  /// Width over height of the frame as displayed right now (below 1 in
  /// portrait), or null when no camera is open. Follows device orientation.
  double? get previewAspectRatio;

  /// Failures that happen while previewing (camera closed, disconnected, taken
  /// by another app).
  Stream<CameraFailure> get errors;

  /// [controllerZoom] is in the plugin's own units and must be inside the range
  /// from [CameraSessionInfo].
  Future<void> setZoom(double controllerZoom);

  /// Normalised (0..1) point over the displayed preview.
  Future<void> setFocusPoint(math.Point<double> point);
  Future<void> setExposurePoint(math.Point<double> point);

  /// Locks or unlocks autofocus and auto-exposure at their current values.
  Future<void> setFocusLocked({required bool locked});

  Future<void> setFlash(FlashSetting setting);

  /// Takes a picture and returns the path of the temporary JPEG.
  Future<String> capture();

  /// Deletes a file returned by [capture]. Does nothing if it is already gone.
  Future<void> discardTemporary(String path);
}
