import 'package:equatable/equatable.dart';
import 'package:snapsync/domain/camera/camera_lens.dart';

/// What the service learned when it opened a camera.
class CameraSessionInfo extends Equatable {
  const CameraSessionInfo({
    required this.lens,
    required this.minZoom,
    required this.maxZoom,
    required this.supportsFocus,
    required this.supportsFlash,
  });

  final CameraLens lens;

  /// The camera's own zoom range (ratios, 1.0 is no zoom). Can start below 1.0
  /// on cameras that zoom out to an ultra-wide lens.
  final double minZoom;
  final double maxZoom;

  /// The camera plugin has no query for these, so they are inferred: back
  /// cameras are assumed to support focus points and flash, front cameras not.
  /// A call that the platform rejects turns the feature off at runtime.
  final bool supportsFocus;
  final bool supportsFlash;

  @override
  List<Object?> get props => [
    lens,
    minZoom,
    maxZoom,
    supportsFocus,
    supportsFlash,
  ];
}
