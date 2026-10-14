import 'package:snapsync/data/local/daos/batch_dao.dart';
import 'package:snapsync/data/local/daos/image_dao.dart';
import 'package:snapsync/data/storage/image_storage_service.dart';
import 'package:snapsync/domain/entities/capture_batch.dart';
import 'package:snapsync/domain/entities/captured_image.dart';
import 'package:snapsync/domain/entities/upload_status.dart';
import 'package:snapsync/domain/repositories/batch_repository.dart';

class BatchRepositoryImpl implements BatchRepository {
  const BatchRepositoryImpl({
    required this.batchDao,
    required this.imageDao,
    required this.storage,
  });

  final BatchDao batchDao;
  final ImageDao imageDao;
  final ImageStorageService storage;

  @override
  Future<CaptureBatch> createBatch() {
    // TODO: generate an id with uuid and insert via batchDao.
    throw UnimplementedError('TODO: createBatch');
  }

  @override
  Future<CapturedImage> addImage({
    required String batchId,
    required String sourcePath,
  }) {
    // TODO: store the file, then insert via imageDao.
    throw UnimplementedError('TODO: addImage');
  }

  @override
  Stream<List<CaptureBatch>> watchPendingBatches() {
    // TODO: emit on every change to batches or images.
    throw UnimplementedError('TODO: watchPendingBatches');
  }

  @override
  Future<void> updateImageStatus(
    String imageId,
    UploadStatus status, {
    int? retryCount,
    String? lastError,
  }) {
    // TODO: update via imageDao.
    throw UnimplementedError('TODO: updateImageStatus');
  }
}
