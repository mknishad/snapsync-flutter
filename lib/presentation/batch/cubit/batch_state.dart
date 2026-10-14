import 'package:equatable/equatable.dart';
import 'package:snapsync/core/error/failure.dart';
import 'package:snapsync/domain/entities/capture_batch.dart';

enum BatchStatus { initial, ready, submitting, failure }

class BatchState extends Equatable {
  const BatchState({
    this.status = BatchStatus.initial,
    this.currentBatch,
    this.failure,
  });

  final BatchStatus status;

  /// The open batch new captures are added to; null until the first capture.
  final CaptureBatch? currentBatch;
  final Failure? failure;

  int get imageCount => currentBatch?.totalCount ?? 0;

  @override
  List<Object?> get props => [status, currentBatch, failure];
}
