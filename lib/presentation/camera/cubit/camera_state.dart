import 'package:equatable/equatable.dart';
import 'package:snapsync/core/error/failure.dart';

enum CameraStatus { initial, initialising, ready, permissionDenied, failure }

class CameraState extends Equatable {
  const CameraState({this.status = CameraStatus.initial, this.failure});

  final CameraStatus status;
  final Failure? failure;

  // TODO: zoom level, zoom range, available lenses, focus point, flash mode.

  @override
  List<Object?> get props => [status, failure];
}
