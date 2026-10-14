import 'package:snapsync/domain/repositories/batch_repository.dart';

/// Requeues images left in `uploading` by a process that was killed mid-upload.
///
/// Call it on app start and at the start of every background task. Pass
/// `AppConstants.uploadClaimTimeout` from a background task so an upload
/// that is genuinely running in another isolate is not requeued; the default
/// (zero) resets every `uploading` image and suits a cold app start.
class RecoverInterruptedUploads {
  const RecoverInterruptedUploads(this.repository);

  final BatchRepository repository;

  /// Returns how many images were reset.
  Future<int> call({Duration staleAfter = Duration.zero}) {
    return repository.resetInterruptedUploads(staleAfter: staleAfter);
  }
}
