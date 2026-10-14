import 'package:equatable/equatable.dart';

enum LensDirection { back, front, external }

/// What kind of lens a camera has, when the platform says. Android's camera
/// plugin does not report it (always [unknown]); iOS does.
enum LensKind { wide, ultraWide, telephoto, unknown }

/// One camera on the device, independent of the camera plugin.
class CameraLens extends Equatable {
  const CameraLens({
    required this.id,
    required this.direction,
    this.sensorOrientation = 0,
    this.kind = LensKind.unknown,
  });

  /// Platform camera name; unique on the device.
  final String id;
  final LensDirection direction;
  final int sensorOrientation;
  final LensKind kind;

  @override
  List<Object?> get props => [id, direction, sensorOrientation, kind];
}
