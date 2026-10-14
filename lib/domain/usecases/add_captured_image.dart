import 'package:snapsync/domain/entities/captured_image.dart';
import 'package:snapsync/domain/repositories/batch_repository.dart';

/// Adds a freshly captured file to the open batch, creating the batch first
/// if needed.
class AddCapturedImage {
  const AddCapturedImage(this.repository);

  final BatchRepository repository;

  Future<CapturedImage> call(String capturedFilePath) async {
    final batch = await repository.getOrCreateOpenBatch();
    return repository.addImage(batch.id, capturedFilePath);
  }
}
