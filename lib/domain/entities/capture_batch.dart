import 'package:equatable/equatable.dart';
import 'package:snapsync/domain/entities/captured_image.dart';

class CaptureBatch extends Equatable {
  const CaptureBatch({
    required this.id,
    required this.createdAt,
    this.images = const [],
  });

  final String id;
  final DateTime createdAt;
  final List<CapturedImage> images;

  // TODO: derived values (overall status, progress) once sync logic exists.

  @override
  List<Object?> get props => [id, createdAt, images];
}
