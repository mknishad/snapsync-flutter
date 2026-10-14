import 'package:equatable/equatable.dart';
import 'package:snapsync/core/error/failure.dart';
import 'package:snapsync/domain/entities/capture_batch.dart';

enum BatchStatus { initial, loading, ready, failure }

class BatchState extends Equatable {
  const BatchState({
    this.status = BatchStatus.initial,
    this.currentBatch,
    this.failure,
  });

  final BatchStatus status;

  /// The batch new captures are added to.
  final CaptureBatch? currentBatch;
  final Failure? failure;

  @override
  List<Object?> get props => [status, currentBatch, failure];
}
