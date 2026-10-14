import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:snapsync/domain/entities/captured_image.dart';
import 'package:snapsync/domain/entities/upload_status.dart';
import 'package:snapsync/presentation/upload_manager/models/upload_item_view_model.dart';

CapturedImage image(
  UploadStatus status, {
  int attempts = 0,
  String? lastError,
}) {
  return CapturedImage(
    id: 'img-1',
    batchId: 'b1',
    filePath: '/fake/img-1.png',
    fileSizeBytes: 2048,
    capturedAt: DateTime.utc(2026, 4, 1, 9, 5, 7),
    status: status,
    attemptCount: attempts,
    lastError: lastError,
  );
}

UploadItemViewModel map(CapturedImage image, {double? live}) =>
    UploadItemViewModel.fromImage(image, maxAttempts: 3, liveProgress: live);

void main() {
  test('display name is built from the capture time and keeps the extension',
      () {
    final expectedStamp = DateFormat('yyyyMMdd_HHmmss')
        .format(DateTime.utc(2026, 4, 1, 9, 5, 7).toLocal());

    expect(map(image(UploadStatus.queued)).displayName, 'IMG_$expectedStamp.png');
  });

  group('attempt text', () {
    test('shows the attempt that will run next', () {
      expect(
        map(image(UploadStatus.retrying, attempts: 1)).attemptText,
        'Retrying... (attempt 2/3)',
      );
      expect(
        map(image(UploadStatus.retrying, attempts: 2)).attemptText,
        'Retrying... (attempt 3/3)',
      );
    });

    test('never exceeds the maximum', () {
      expect(
        map(image(UploadStatus.retrying, attempts: 9)).attemptText,
        'Retrying... (attempt 3/3)',
      );
    });

    test('is absent for every other status', () {
      for (final status in UploadStatus.values) {
        if (status == UploadStatus.retrying) continue;
        expect(map(image(status)).attemptText, isNull, reason: status.name);
      }
    });
  });

  group('progress and thumbnail', () {
    test('uploaded is complete and has no local file', () {
      final item = map(image(UploadStatus.uploaded));
      expect(item.progress, 1);
      expect(item.thumbnailPath, isNull);
    });

    test('uploading uses the live progress, defaulting to zero', () {
      expect(map(image(UploadStatus.uploading), live: 0.4).progress, 0.4);
      expect(map(image(UploadStatus.uploading)).progress, 0);
    });

    test('other statuses show no progress and keep the thumbnail', () {
      for (final status in [
        UploadStatus.queued,
        UploadStatus.waitingForConnection,
        UploadStatus.retrying,
        UploadStatus.failed,
      ]) {
        final item = map(image(status), live: 0.9);
        expect(item.progress, 0, reason: status.name);
        expect(item.thumbnailPath, '/fake/img-1.png', reason: status.name);
      }
    });
  });

  test('carries size, status and the last error through', () {
    final item = map(image(UploadStatus.failed, lastError: 'rejected'));

    expect(item.sizeBytes, 2048);
    expect(item.status, UploadStatus.failed);
    expect(item.lastError, 'rejected');
    expect(item.batchId, 'b1');
  });
}
