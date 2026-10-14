import 'package:snapsync/domain/entities/capture_batch.dart';
import 'package:snapsync/domain/entities/captured_image.dart';
import 'package:snapsync/domain/entities/upload_status.dart';

/// Local persistence of batches and their images. Methods throw a `Failure`.
abstract interface class BatchRepository {
  Future<CaptureBatch> createBatch();

  /// Copies the captured file into app storage and records it in [batchId].
  Future<CapturedImage> addImage({
    required String batchId,
    required String sourcePath,
  });

  /// Batches that still contain images not yet uploaded.
  Stream<List<CaptureBatch>> watchPendingBatches();

  Future<void> updateImageStatus(
    String imageId,
    UploadStatus status, {
    int? retryCount,
    String? lastError,
  });
}
