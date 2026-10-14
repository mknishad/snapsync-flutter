import 'package:snapsync/domain/entities/capture_batch.dart';
import 'package:snapsync/domain/repositories/batch_repository.dart';

class CreateBatch {
  const CreateBatch(this.repository);

  final BatchRepository repository;

  Future<CaptureBatch> call() => repository.createBatch();
}
