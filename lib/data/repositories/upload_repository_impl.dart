import 'package:snapsync/domain/repositories/batch_repository.dart';
import 'package:snapsync/domain/repositories/connectivity_monitor.dart';
import 'package:snapsync/domain/repositories/upload_api.dart';
import 'package:snapsync/domain/repositories/upload_repository.dart';

class UploadRepositoryImpl implements UploadRepository {
  const UploadRepositoryImpl({
    required this.batchRepository,
    required this.uploadApi,
    required this.connectivityMonitor,
  });

  final BatchRepository batchRepository;
  final UploadApi uploadApi;
  final ConnectivityMonitor connectivityMonitor;

  @override
  Future<void> syncPendingUploads() {
    // TODO: wait for a stable connection, upload each queued image, apply
    // backoff and the retry limit from AppConstants, record every status
    // change through batchRepository.
    throw UnimplementedError('TODO: syncPendingUploads');
  }
}
