import 'package:snapsync/domain/repositories/upload_repository.dart';

class SyncPendingUploads {
  const SyncPendingUploads(this.repository);

  final UploadRepository repository;

  Future<void> call() => repository.syncPendingUploads();
}
