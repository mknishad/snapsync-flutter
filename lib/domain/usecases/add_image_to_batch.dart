import 'package:snapsync/domain/entities/captured_image.dart';
import 'package:snapsync/domain/repositories/batch_repository.dart';

class AddImageToBatch {
  const AddImageToBatch(this.repository);

  final BatchRepository repository;

  Future<CapturedImage> call({
    required String batchId,
    required String sourcePath,
  }) {
    return repository.addImage(batchId: batchId, sourcePath: sourcePath);
  }
}
