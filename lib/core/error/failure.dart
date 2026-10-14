import 'package:equatable/equatable.dart';

/// Base type for every expected error in the app.
///
/// Repositories and data sources throw a [Failure]; cubits catch it and map it
/// to state. Anything else is treated as a bug.
sealed class Failure extends Equatable implements Exception {
  const Failure(this.message);

  final String message;

  /// Whether trying the same operation again later can succeed.
  bool get isRetryable => false;

  /// Whether a failed upload attempt with this failure counts towards the
  /// retry limit. Failures that only mean "no usable connection" do not, so a
  /// long offline period never exhausts an image's retries.
  bool get consumesAttempt => isRetryable;

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

/// There is no network connection. The upload waits for connectivity and does
/// not use up a retry.
final class NoInternetFailure extends Failure {
  const NoInternetFailure(super.message);

  @override
  bool get isRetryable => true;

  @override
  bool get consumesAttempt => false;
}

/// A connection exists but the request timed out or was too slow.
final class LowBandwidthFailure extends Failure {
  const LowBandwidthFailure(super.message);

  @override
  bool get isRetryable => true;
}

/// The server rejected or failed the request.
///
/// 5xx, 408 and 429 are worth retrying; other codes (for example 400, 401,
/// 413) will fail the same way again.
final class ServerFailure extends Failure {
  const ServerFailure(super.message, {required this.code});

  final int code;

  @override
  bool get isRetryable => code >= 500 || code == 408 || code == 429;

  @override
  List<Object?> get props => [message, code];
}

/// A file could not be written, read or deleted.
final class StorageFailure extends Failure {
  const StorageFailure(super.message);
}

/// A file that should exist does not.
final class FileMissingFailure extends Failure {
  const FileMissingFailure(super.message);
}

/// The local database failed.
final class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message);
}

/// Anything that was not anticipated. Treated as retryable because the retry
/// limit still bounds it.
final class UnknownFailure extends Failure {
  const UnknownFailure(super.message);

  @override
  bool get isRetryable => true;
}
