import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:snapsync/core/error/failure.dart';
import 'package:snapsync/domain/camera/camera_lens.dart';
import 'package:snapsync/domain/camera/camera_permission_service.dart';
import 'package:snapsync/domain/camera/camera_service.dart';
import 'package:snapsync/domain/camera/camera_session_info.dart';
import 'package:snapsync/domain/camera/flash_setting.dart';

const backLens = CameraLens(id: '0', direction: LensDirection.back);
const frontLens = CameraLens(id: '1', direction: LensDirection.front);
const secondBackLens = CameraLens(id: '2', direction: LensDirection.back);

/// A camera the test controls. Behaves like the real service where it matters:
/// a [dispose] that arrives while an [open] is in flight waits for it and then
/// releases it.
class FakeCameraService implements CameraService {
  FakeCameraService({
    List<CameraLens>? lenses,
    this.minZoom = 1,
    this.maxZoom = 8,
  }) : lenses = lenses ?? [backLens, frontLens];

  List<CameraLens> lenses;
  double minZoom;
  double maxZoom;

  /// Overrides what [open] does. Return an info, or throw a [CameraFailure].
  Future<CameraSessionInfo> Function(CameraLens lens)? onOpen;

  /// Holds every [open] until completed, to test things that happen mid-open.
  Completer<void>? openGate;

  Future<String> Function()? onCapture;
  Future<void> Function(double zoom)? onSetZoom;
  Future<void> Function()? onSetFocus;
  Future<void> Function(FlashSetting setting)? onSetFlash;

  double? aspectRatio = 0.75;
  bool supportsFocus = true;
  bool supportsFlash = true;

  final List<String> openedLensIds = [];
  final List<double> zoomCalls = [];
  final List<math.Point<double>> focusPoints = [];
  final List<math.Point<double>> exposurePoints = [];
  final List<bool> lockCalls = [];
  final List<FlashSetting> flashCalls = [];
  final List<String> discarded = [];
  Object? discardError;
  int listCalls = 0;
  int disposeCalls = 0;
  int captureCalls = 0;
  bool isOpen = false;

  /// open and dispose run one after another, like the real service.
  Future<void> _queue = Future<void>.value();
  final StreamController<CameraFailure> _errors =
      StreamController<CameraFailure>.broadcast();

  bool get hasErrorListener => _errors.hasListener;

  void emitError(CameraFailure failure) => _errors.add(failure);

  @override
  Future<List<CameraLens>> listCameras() async {
    listCalls++;
    return lenses;
  }

  Future<T> _serialised<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  @override
  Future<CameraSessionInfo> open(CameraLens lens) =>
      _serialised(() => _open(lens));

  Future<CameraSessionInfo> _open(CameraLens lens) async {
    openedLensIds.add(lens.id);
    isOpen = false;
    await openGate?.future;
    if (onOpen != null) {
      final info = await onOpen!(lens);
      isOpen = true;
      return info;
    }
    isOpen = true;
    final isBack = lens.direction == LensDirection.back;
    return CameraSessionInfo(
      lens: lens,
      minZoom: minZoom,
      maxZoom: maxZoom,
      supportsFocus: supportsFocus && isBack,
      supportsFlash: supportsFlash && isBack,
    );
  }

  @override
  Future<void> dispose() {
    return _serialised(() async {
      disposeCalls++;
      isOpen = false;
    });
  }

  @override
  Object? get previewHandle => isOpen ? this : null;

  @override
  double? get previewAspectRatio => isOpen ? aspectRatio : null;

  @override
  Stream<CameraFailure> get errors => _errors.stream;

  @override
  Future<void> setZoom(double controllerZoom) async {
    zoomCalls.add(controllerZoom);
    await onSetZoom?.call(controllerZoom);
  }

  @override
  Future<void> setFocusPoint(math.Point<double> point) async {
    focusPoints.add(point);
    await onSetFocus?.call();
  }

  @override
  Future<void> setExposurePoint(math.Point<double> point) async {
    exposurePoints.add(point);
  }

  @override
  Future<void> setFocusLocked({required bool locked}) async {
    lockCalls.add(locked);
  }

  @override
  Future<void> setFlash(FlashSetting setting) async {
    flashCalls.add(setting);
    await onSetFlash?.call(setting);
  }

  @override
  Future<String> capture() async {
    captureCalls++;
    final handler = onCapture;
    if (handler == null) throw StateError('onCapture not set');
    return handler();
  }

  @override
  Future<void> discardTemporary(String path) async {
    discarded.add(path);
    if (discardError != null) throw discardError!;
    final file = File(path);
    if (file.existsSync()) file.deleteSync();
  }
}

class FakeCameraPermissions implements CameraPermissionService {
  FakeCameraPermissions([this.current = CameraPermissionStatus.granted]);

  CameraPermissionStatus current;

  /// What a request returns. When null, the request returns [current].
  CameraPermissionStatus? requestResult;

  bool settingsResult = true;
  int statusCalls = 0;
  int requestCalls = 0;
  int settingsCalls = 0;

  @override
  Future<CameraPermissionStatus> status() async {
    statusCalls++;
    return current;
  }

  @override
  Future<CameraPermissionStatus> request() async {
    requestCalls++;
    // On Android the status check never says "permanently denied"; only the
    // request can. Mirror that: the request reports it, status reports denied.
    final result = requestResult ?? current;
    current = result == CameraPermissionStatus.permanentlyDenied
        ? CameraPermissionStatus.denied
        : result;
    return result;
  }

  @override
  Future<bool> openSettings() async {
    settingsCalls++;
    return settingsResult;
  }
}
