import 'package:snapsync/domain/repositories/batch_repository.dart';

class SubmitBatch {
  const SubmitBatch(this.repository);

  final BatchRepository repository;

  Future<void> call(String batchId) => repository.submitBatch(batchId);
}
