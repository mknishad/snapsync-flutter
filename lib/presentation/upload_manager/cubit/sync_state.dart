import 'package:equatable/equatable.dart';
import 'package:snapsync/core/error/failure.dart';
import 'package:snapsync/domain/entities/capture_batch.dart';

enum SyncStatus { idle, syncing, waitingForConnection, failure }

class SyncState extends Equatable {
  const SyncState({
    this.status = SyncStatus.idle,
    this.pendingBatches = const [],
    this.failure,
  });

  final SyncStatus status;
  final List<CaptureBatch> pendingBatches;
  final Failure? failure;

  // TODO: overall progress, bytes uploaded, stable-link indicator.

  @override
  List<Object?> get props => [status, pendingBatches, failure];
}
