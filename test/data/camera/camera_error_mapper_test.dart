import 'package:flutter_test/flutter_test.dart';
import 'package:snapsync/core/error/failure.dart';
import 'package:snapsync/data/camera/camera_error_mapper.dart';

void main() {
  CameraFailureReason reasonOf(String code, [String? description]) =>
      CameraErrorMapper.fromException(code, description).reason;

  group('exceptions', () {
    test('permission problems', () {
      expect(reasonOf('CameraAccessDenied'), CameraFailureReason.permission);
      expect(
        reasonOf('CameraAccessDeniedWithoutPrompt'),
        CameraFailureReason.permission,
      );
      expect(
        reasonOf('x', 'Camera permission was denied'),
        CameraFailureReason.permission,
      );
    });

    test('camera in use', () {
      expect(
        reasonOf(
          'x',
          'The camera was already in use, possibly by a higher-priority camera client.',
        ),
        CameraFailureReason.inUse,
      );
      expect(
        reasonOf('x', 'The limit number of open cameras has been reached'),
        CameraFailureReason.inUse,
      );
    });

    test('disconnected, closed and fatal errors', () {
      expect(
        reasonOf('x', 'The camera was closed due to a fatal error.'),
        CameraFailureReason.disconnected,
      );
      expect(
        reasonOf(
          'x',
          'The camera device could not be opened due to a device policy.',
        ),
        CameraFailureReason.disconnected,
      );
    });

    test('disposed controller', () {
      expect(
        reasonOf(
          'Disposed CameraController',
          'initialize was called on a disposed CameraController',
        ),
        CameraFailureReason.disposed,
      );
    });

    test('no camera', () {
      expect(
        reasonOf('cameraNotFound', 'Camera not found'),
        CameraFailureReason.noCameraAvailable,
      );
    });

    test('anything else is unknown, not hidden', () {
      expect(
        reasonOf('weird', 'something strange'),
        CameraFailureReason.unknown,
      );
      expect(reasonOf('x'), CameraFailureReason.unknown);
    });

    test('matching ignores case', () {
      expect(reasonOf('x', 'CAMERA ALREADY IN USE'), CameraFailureReason.inUse);
    });
  });

  test('runtime errors use the same mapping', () {
    expect(
      CameraErrorMapper.fromRuntimeError(
        'The camera was already in use, possibly by a higher-priority camera client.',
      ).reason,
      CameraFailureReason.inUse,
    );
    expect(
      CameraErrorMapper.fromRuntimeError(null).reason,
      CameraFailureReason.unknown,
    );
  });

  test('the technical text is kept for logs but is not the reason', () {
    final failure = CameraErrorMapper.fromException('code-x', 'details here');

    expect(failure.message, contains('code-x'));
    expect(failure.message, contains('details here'));
  });

  group('CameraFailureReason', () {
    test('which reasons are worth one automatic retry', () {
      for (final reason in [
        CameraFailureReason.inUse,
        CameraFailureReason.disconnected,
        CameraFailureReason.initTimeout,
        CameraFailureReason.disposed,
        CameraFailureReason.unknown,
      ]) {
        expect(reason.isTransient, isTrue, reason: reason.name);
      }
      for (final reason in [
        CameraFailureReason.noCameraAvailable,
        CameraFailureReason.permission,
        CameraFailureReason.captureFailed,
        CameraFailureReason.flashUnsupported,
        CameraFailureReason.focusUnsupported,
        CameraFailureReason.zoomFailed,
      ]) {
        expect(reason.isTransient, isFalse, reason: reason.name);
      }
    });

    test('no camera is the only reason a user retry cannot help', () {
      expect(
        const CameraFailure(
          'x',
          reason: CameraFailureReason.noCameraAvailable,
        ).isRetryable,
        isFalse,
      );
      expect(
        const CameraFailure('x', reason: CameraFailureReason.inUse).isRetryable,
        isTrue,
      );
    });

    test('failures with different reasons are not equal', () {
      expect(
        const CameraFailure('x', reason: CameraFailureReason.inUse) ==
            const CameraFailure('x', reason: CameraFailureReason.unknown),
        isFalse,
      );
    });
  });
}
