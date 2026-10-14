import 'package:snapsync/domain/entities/captured_image.dart';

/// Remote upload endpoint. Implementations throw a `Failure` when the upload
/// does not succeed.
abstract interface class UploadApi {
  Future<void> uploadImage(CapturedImage image);
}
