import 'package:equatable/equatable.dart';
import 'package:snapsync/core/constants/app_constants.dart';
import 'package:snapsync/core/error/failure.dart';
import 'package:snapsync/domain/camera/camera_lens.dart';
import 'package:snapsync/domain/camera/flash_setting.dart';
import 'package:snapsync/domain/camera/zoom_math.dart';
import 'package:snapsync/domain/camera/zoom_preset.dart';
import 'package:snapsync/presentation/camera/cubit/focus_indicator.dart';

/// What the camera screen should show. One status enum plus plain fields,
/// rather than a sealed hierarchy: zoom, flash and lens must survive a pause or
/// a recoverable error, and most screens show the same controls whatever the
/// status, so separate state classes would copy these fields everywhere.
enum CameraStatus {
  initialising,

  /// Released because the app went to the background.
  paused,
  ready,

  /// Not granted; asking again may show the system dialog.
  permissionDenied,

  /// Only system settings can grant it now.
  permissionPermanentlyDenied,
  noCameraAvailable,

  /// Another app has the camera.
  cameraInUse,

  /// Disconnected, closed or hit a hardware error.
  unavailable,
  error,
}

class CameraState extends Equatable {
  const CameraState({
    this.status = CameraStatus.initialising,
    this.failureReason,
    this.canRetry = false,
    this.lensDirection = LensDirection.back,
    this.activeLensId,
    this.canSwitchLens = false,
    this.presets = const [],
    this.zoom = 1,
    this.minZoom = 1,
    this.maxZoom = 1,
    this.flash = FlashSetting.off,
    this.supportsFlash = false,
    this.supportsFocus = false,
    this.focusLocked = false,
    this.focusIndicator,
    this.isCapturing = false,
  });

  final CameraStatus status;

  /// Why the camera is not ready, for choosing the text. Null otherwise.
  final CameraFailureReason? failureReason;

  /// Whether a retry button makes sense.
  final bool canRetry;
  final LensDirection lensDirection;
  final String? activeLensId;
  final bool canSwitchLens;

  final List<ZoomPreset> presets;

  /// Display zoom (1.0 is the main camera at no zoom) and its range for the
  /// active camera.
  final double zoom;
  final double minZoom;
  final double maxZoom;

  final FlashSetting flash;
  final bool supportsFlash;
  final bool supportsFocus;
  final bool focusLocked;
  final FocusIndicator? focusIndicator;
  final bool isCapturing;

  bool get isReady => status == CameraStatus.ready;

  /// The preset button to highlight: the one the zoom is within tolerance of.
  ZoomPreset? get activePreset => ZoomMath.snapToPreset(
    zoom,
    presets,
    tolerance: AppConstants.zoomPresetSnapTolerance,
  );

  /// Slider position (0 to 1) matching [zoom].
  double get sliderValue =>
      ZoomMath.zoomToSlider(zoom, min: minZoom, max: maxZoom);

  CameraState copyWith({
    CameraStatus? status,
    CameraFailureReason? failureReason,
    bool clearFailure = false,
    bool? canRetry,
    LensDirection? lensDirection,
    String? activeLensId,
    bool? canSwitchLens,
    List<ZoomPreset>? presets,
    double? zoom,
    double? minZoom,
    double? maxZoom,
    FlashSetting? flash,
    bool? supportsFlash,
    bool? supportsFocus,
    bool? focusLocked,
    FocusIndicator? focusIndicator,
    bool clearFocusIndicator = false,
    bool? isCapturing,
  }) {
    return CameraState(
      status: status ?? this.status,
      failureReason: clearFailure
          ? null
          : (failureReason ?? this.failureReason),
      canRetry: canRetry ?? this.canRetry,
      lensDirection: lensDirection ?? this.lensDirection,
      activeLensId: activeLensId ?? this.activeLensId,
      canSwitchLens: canSwitchLens ?? this.canSwitchLens,
      presets: presets ?? this.presets,
      zoom: zoom ?? this.zoom,
      minZoom: minZoom ?? this.minZoom,
      maxZoom: maxZoom ?? this.maxZoom,
      flash: flash ?? this.flash,
      supportsFlash: supportsFlash ?? this.supportsFlash,
      supportsFocus: supportsFocus ?? this.supportsFocus,
      focusLocked: focusLocked ?? this.focusLocked,
      focusIndicator: clearFocusIndicator
          ? null
          : (focusIndicator ?? this.focusIndicator),
      isCapturing: isCapturing ?? this.isCapturing,
    );
  }

  @override
  List<Object?> get props => [
    status,
    failureReason,
    canRetry,
    lensDirection,
    activeLensId,
    canSwitchLens,
    presets,
    zoom,
    minZoom,
    maxZoom,
    flash,
    supportsFlash,
    supportsFocus,
    focusLocked,
    focusIndicator,
    isCapturing,
  ];
}
