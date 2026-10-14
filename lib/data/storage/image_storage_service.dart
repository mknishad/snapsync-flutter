/// Keeps captured files in app-private storage, so no storage permission is
/// needed.
class ImageStorageService {
  const ImageStorageService();

  /// Copies [sourcePath] into the captures directory and returns the new path.
  Future<String> saveImage(String sourcePath, {required String batchId}) {
    // TODO: use path_provider and path; throw StorageFailure on error.
    throw UnimplementedError('TODO: ImageStorageService.saveImage');
  }

  Future<void> deleteImage(String filePath) {
    // TODO: delete the file; ignore if already gone.
    throw UnimplementedError('TODO: ImageStorageService.deleteImage');
  }
}
