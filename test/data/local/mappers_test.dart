import 'package:flutter_test/flutter_test.dart';
import 'package:snapsync/core/error/failure.dart';
import 'package:snapsync/data/local/mappers/batch_mapper.dart';
import 'package:snapsync/data/local/mappers/captured_image_mapper.dart';
import 'package:snapsync/data/local/models/batch_model.dart';
import 'package:snapsync/data/local/models/captured_image_model.dart';
import 'package:snapsync/domain/entities/capture_batch.dart';
import 'package:snapsync/domain/entities/captured_image.dart';
import 'package:snapsync/domain/entities/upload_status.dart';

void main() {
  final capturedAt = DateTime.utc(2026, 2, 3, 4, 5, 6, 7);

  group('image mapper', () {
    test('round trips every field, including all optional ones', () {
      final image = CapturedImage(
        id: 'i1',
        batchId: 'b1',
        filePath: '/fake/i1.jpg',
        fileSizeBytes: 1234,
        capturedAt: capturedAt,
        status: UploadStatus.retrying,
        attemptCount: 2,
        lastError: 'timed out',
        nextRetryAt: capturedAt.add(const Duration(minutes: 1)),
        uploadedAt: capturedAt.add(const Duration(hours: 1)),
      );

      final map = image.toModel(updatedAt: capturedAt).toMap();
      final restored = CapturedImageModel.fromMap(map).toEntity();

      expect(restored, image);
      expect(restored.capturedAt.isUtc, isTrue);
    });

    test('round trips null optional fields', () {
      final image = CapturedImage(
        id: 'i1',
        batchId: 'b1',
        filePath: '/fake/i1.jpg',
        fileSizeBytes: 1,
        capturedAt: capturedAt,
      );

      final restored = CapturedImageModel.fromMap(
        image.toModel(updatedAt: capturedAt).toMap(),
      ).toEntity();

      expect(restored, image);
      expect(restored.lastError, isNull);
      expect(restored.nextRetryAt, isNull);
    });

    test('every status survives storage', () {
      for (final status in UploadStatus.values) {
        final image = CapturedImage(
          id: 'i',
          batchId: 'b',
          filePath: '/f',
          fileSizeBytes: 1,
          capturedAt: capturedAt,
          status: status,
        );
        final restored = CapturedImageModel.fromMap(
          image.toModel(updatedAt: capturedAt).toMap(),
        ).toEntity();
        expect(restored.status, status);
      }
    });

    test('stores timestamps as UTC epoch milliseconds', () {
      final model = CapturedImage(
        id: 'i',
        batchId: 'b',
        filePath: '/f',
        fileSizeBytes: 1,
        capturedAt: capturedAt,
      ).toModel(updatedAt: capturedAt);

      expect(model.capturedAtMillis, capturedAt.millisecondsSinceEpoch);
      expect(model.toMap()['captured_at'], capturedAt.millisecondsSinceEpoch);
    });

    test('an unknown stored status fails loudly', () {
      const model = CapturedImageModel(
        id: 'i',
        batchId: 'b',
        filePath: '/f',
        fileSizeBytes: 1,
        capturedAtMillis: 0,
        status: 'bogus',
        attemptCount: 0,
        updatedAtMillis: 0,
      );

      expect(model.toEntity, throwsA(isA<DatabaseFailure>()));
    });
  });

  group('batch mapper', () {
    test('round trips a submitted batch with its images', () {
      final image = CapturedImage(
        id: 'i1',
        batchId: 'b1',
        filePath: '/f',
        fileSizeBytes: 1,
        capturedAt: capturedAt,
      );
      final batch = CaptureBatch(
        id: 'b1',
        createdAt: capturedAt,
        submittedAt: capturedAt.add(const Duration(minutes: 5)),
        images: [image],
      );

      final restored = BatchModel.fromMap(batch.toModel().toMap())
          .toEntity([image]);

      expect(restored, batch);
    });

    test('an open batch keeps a null submittedAt', () {
      final batch = CaptureBatch(id: 'b1', createdAt: capturedAt);
      final restored = BatchModel.fromMap(batch.toModel().toMap()).toEntity([]);
      expect(restored.submittedAt, isNull);
      expect(restored.isSubmitted, isFalse);
    });
  });
}
