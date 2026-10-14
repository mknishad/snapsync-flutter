import 'package:equatable/equatable.dart';
import 'package:snapsync/domain/entities/capture_batch.dart';
import 'package:snapsync/domain/entities/upload_status.dart';

class BatchSummary extends Equatable {
  const BatchSummary({
    required this.id,
    required this.submittedAt,
    required this.totalCount,
    required this.uploadedCount,
    required this.totalBytes,
    required this.uploadedBytes,
    required this.status,
  });

  factory BatchSummary.fromBatch(CaptureBatch batch) {
    return BatchSummary(
      id: batch.id,
      submittedAt: batch.submittedAt,
      totalCount: batch.totalCount,
      uploadedCount: batch.uploadedCount,
      totalBytes: batch.totalBytes,
      uploadedBytes: batch.uploadedBytes,
      status: batch.aggregateStatus,
    );
  }

  final String id;
  final DateTime? submittedAt;
  final int totalCount;
  final int uploadedCount;
  final int totalBytes;
  final int uploadedBytes;
  final UploadStatus status;

  @override
  List<Object?> get props => [
    id,
    submittedAt,
    totalCount,
    uploadedCount,
    totalBytes,
    uploadedBytes,
    status,
  ];
}
