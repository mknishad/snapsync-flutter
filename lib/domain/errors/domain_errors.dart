import 'package:snapsync/domain/entities/upload_status.dart';

/// A status change that the transition table forbids. This is a programming
/// error (or a lost race), not an expected runtime failure.
class IllegalStatusTransitionError extends Error {
  IllegalStatusTransitionError(this.from, this.to);

  final UploadStatus from;
  final UploadStatus to;

  @override
  String toString() => 'IllegalStatusTransitionError: ${from.name} -> ${to.name}';
}

/// An operation that the batch's current state does not allow, for example
/// adding an image to a submitted batch or submitting an empty one.
class IllegalBatchStateError extends Error {
  IllegalBatchStateError(this.message);

  final String message;

  @override
  String toString() => 'IllegalBatchStateError: $message';
}
