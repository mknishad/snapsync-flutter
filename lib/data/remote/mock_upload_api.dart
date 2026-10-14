import 'package:snapsync/core/constants/app_constants.dart';
import 'package:snapsync/core/error/failure.dart';
import 'package:snapsync/domain/entities/captured_image.dart';
import 'package:snapsync/domain/repositories/upload_api.dart';

/// Stand-in for the real API, which is not available for this assessment.
///
/// Every call either succeeds or fails, decided by [shouldFail]. The switch can
/// be flipped at runtime to exercise the retry path.
class MockUploadApi implements UploadApi {
  MockUploadApi({this.shouldFail = AppConstants.mockUploadShouldFailByDefault});

  bool shouldFail;

  @override
  Future<void> uploadImage(CapturedImage image) async {
    await Future<void>.delayed(AppConstants.mockUploadLatency);
    if (shouldFail) {
      throw const NetworkUnavailableFailure('Mock upload failure');
    }
  }
}
