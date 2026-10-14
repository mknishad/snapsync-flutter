import 'package:snapsync/domain/repositories/batch_repository.dart';

class RemoveImage {
  const RemoveImage(this.repository);

  final BatchRepository repository;

  Future<void> call(String imageId) => repository.removeImage(imageId);
}
