import 'package:flutter_test/flutter_test.dart';
import 'package:snapsync/domain/entities/capture_batch.dart';
import 'package:snapsync/domain/entities/captured_image.dart';
import 'package:snapsync/domain/entities/upload_status.dart';

CapturedImage image(UploadStatus status, {int bytes = 100, String id = 'i'}) {
  return CapturedImage(
    id: id,
    batchId: 'b',
    filePath: '/fake/$id.jpg',
    fileSizeBytes: bytes,
    capturedAt: DateTime.utc(2026, 1, 1),
    status: status,
  );
}

CaptureBatch batchOf(List<CapturedImage> images, {DateTime? submittedAt}) {
  return CaptureBatch(
    id: 'b',
    createdAt: DateTime.utc(2026, 1, 1),
    submittedAt: submittedAt,
    images: images,
  );
}

void main() {
  test('isSubmitted follows submittedAt', () {
    expect(batchOf([]).isSubmitted, isFalse);
    expect(batchOf([], submittedAt: DateTime.utc(2026, 1, 2)).isSubmitted,
        isTrue);
  });

  test('counts and byte totals', () {
    final batch = batchOf([
      image(UploadStatus.uploaded, bytes: 300, id: 'a'),
      image(UploadStatus.queued, bytes: 200, id: 'b'),
      image(UploadStatus.uploaded, bytes: 100, id: 'c'),
    ]);
    expect(batch.totalCount, 3);
    expect(batch.uploadedCount, 2);
    expect(batch.totalBytes, 600);
    expect(batch.uploadedBytes, 400);
  });

  group('aggregateStatus precedence', () {
    final cases = <String, (List<UploadStatus>, UploadStatus)>{
      'empty batch is queued': ([], UploadStatus.queued),
      'all uploaded': (
        [UploadStatus.uploaded, UploadStatus.uploaded],
        UploadStatus.uploaded,
      ),
      'uploading beats everything': (
        [
          UploadStatus.failed,
          UploadStatus.retrying,
          UploadStatus.uploading,
          UploadStatus.uploaded,
        ],
        UploadStatus.uploading,
      ),
      'retrying beats waiting, queued, failed': (
        [
          UploadStatus.failed,
          UploadStatus.queued,
          UploadStatus.waitingForConnection,
          UploadStatus.retrying,
        ],
        UploadStatus.retrying,
      ),
      'waiting beats queued and failed': (
        [
          UploadStatus.failed,
          UploadStatus.queued,
          UploadStatus.waitingForConnection,
        ],
        UploadStatus.waitingForConnection,
      ),
      'queued beats failed': (
        [UploadStatus.failed, UploadStatus.queued],
        UploadStatus.queued,
      ),
      'failed is reported once nothing is pending': (
        [UploadStatus.failed, UploadStatus.uploaded],
        UploadStatus.failed,
      ),
    };

    cases.forEach((name, spec) {
      test(name, () {
        final (statuses, expected) = spec;
        final batch = batchOf([
          for (var i = 0; i < statuses.length; i++)
            image(statuses[i], id: 'i$i'),
        ]);
        expect(batch.aggregateStatus, expected);
      });
    });
  });

  group('CapturedImage.copyWith', () {
    final base = image(UploadStatus.retrying).copyWith(
      lastError: 'boom',
      nextRetryAt: DateTime.utc(2026, 1, 3),
    );

    test('null keeps the current value', () {
      final copy = base.copyWith(status: UploadStatus.uploading);
      expect(copy.lastError, 'boom');
      expect(copy.nextRetryAt, DateTime.utc(2026, 1, 3));
    });

    test('clear flags reset a field to null', () {
      final copy = base.copyWith(clearLastError: true, clearNextRetryAt: true);
      expect(copy.lastError, isNull);
      expect(copy.nextRetryAt, isNull);
    });

    test('equal values compare equal', () {
      expect(base.copyWith(), base);
    });
  });
}
