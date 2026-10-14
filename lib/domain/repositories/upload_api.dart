import 'package:snapsync/domain/entities/captured_image.dart';
import 'package:snapsync/domain/entities/upload_result.dart';

/// Remote upload endpoint. Never throws for expected failures; they come back
/// as `UploadFailed`.
abstract interface class UploadApi {
  /// Uploads [image]. [onProgress] receives values from 0.0 to 1.0.
  ///
  /// Implementations must make retries safe: the same image id must never
  /// create a duplicate on the server.
  Future<UploadResult> upload(
    CapturedImage image, {
    void Function(double progress)? onProgress,
  });
}
