import 'package:snapsync/domain/entities/capture_batch.dart';
import 'package:snapsync/domain/repositories/batch_repository.dart';

class WatchPendingBatches {
  const WatchPendingBatches(this.repository);

  final BatchRepository repository;

  Stream<List<CaptureBatch>> call() => repository.watchPendingBatches();
}
