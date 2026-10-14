import 'package:snapsync/data/local/database_helper.dart';
import 'package:snapsync/data/local/models/captured_image_model.dart';

class ImageDao {
  const ImageDao(this.databaseHelper);

  final DatabaseHelper databaseHelper;

  Future<void> insert(CapturedImageModel image) {
    // TODO: insert into the images table.
    throw UnimplementedError('TODO: ImageDao.insert');
  }

  Future<List<CapturedImageModel>> getByBatch(String batchId) {
    // TODO: query images for a batch.
    throw UnimplementedError('TODO: ImageDao.getByBatch');
  }

  Future<void> updateStatus(
    String imageId,
    String status, {
    int? retryCount,
    String? lastError,
  }) {
    // TODO: update status columns for one image.
    throw UnimplementedError('TODO: ImageDao.updateStatus');
  }
}
