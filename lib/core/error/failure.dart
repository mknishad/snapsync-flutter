import 'package:equatable/equatable.dart';

/// Base type for every expected error in the app.
///
/// Repositories and data sources throw a [Failure]; cubits catch it and map it
/// to state. Anything else is treated as a bug and becomes [UnexpectedFailure].
sealed class Failure extends Equatable implements Exception {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// A required runtime permission (camera) was denied.
final class PermissionDeniedFailure extends Failure {
  const PermissionDeniedFailure(
    super.message, {
    this.permanentlyDenied = false,
  });

  /// When true the user must enable the permission from system settings.
  final bool permanentlyDenied;

  @override
  List<Object?> get props => [message, permanentlyDenied];
}

/// The camera hardware is missing, in use, or failed to initialise.
final class CameraFailure extends Failure {
  const CameraFailure(super.message);
}

/// A file could not be written, read or deleted.
final class StorageFailure extends Failure {
  const StorageFailure(super.message);
}

/// The local database failed.
final class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message);
}

/// There is no usable network connection.
final class NetworkUnavailableFailure extends Failure {
  const NetworkUnavailableFailure(super.message);
}

/// A connection exists but is too slow or flaky to upload reliably.
final class UnstableConnectionFailure extends Failure {
  const UnstableConnectionFailure(super.message);
}

/// The server rejected or failed the request.
final class ServerFailure extends Failure {
  const ServerFailure(super.message, {this.statusCode});

  final int? statusCode;

  @override
  List<Object?> get props => [message, statusCode];
}

/// Anything that was not anticipated.
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message);
}
