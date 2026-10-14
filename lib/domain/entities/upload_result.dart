import 'package:equatable/equatable.dart';
import 'package:snapsync/core/error/failure.dart';

/// Outcome of one upload attempt. The API returns this instead of throwing.
sealed class UploadResult extends Equatable {
  const UploadResult();
}

final class UploadSuccess extends UploadResult {
  const UploadSuccess({required this.serverReference});

  /// Identifier the server assigned to the stored image.
  final String serverReference;

  @override
  List<Object?> get props => [serverReference];
}

final class UploadFailed extends UploadResult {
  const UploadFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
