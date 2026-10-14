import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snapsync/core/error/failure.dart';
import 'package:snapsync/domain/entities/captured_image.dart';
import 'package:snapsync/domain/entities/upload_result.dart';
import 'package:snapsync/domain/entities/upload_status.dart';
import 'package:snapsync/domain/errors/domain_errors.dart';
import 'package:snapsync/domain/repositories/batch_repository.dart';
import 'package:snapsync/domain/services/exponential_backoff.dart';
import 'package:snapsync/domain/usecases/record_upload_result.dart';

class MockBatchRepository extends Mock implements BatchRepository {}

void main() {
  final fixedNow = DateTime.utc(2026, 3, 1, 12);
  late MockBatchRepository repository;
  late RecordUploadResult useCase;

  CapturedImage uploading({int attempts = 0}) => CapturedImage(
        id: 'img-1',
        batchId: 'b',
        filePath: '/fake/img-1.jpg',
        fileSizeBytes: 10,
        capturedAt: DateTime.utc(2026, 3, 1),
        status: UploadStatus.uploading,
        attemptCount: attempts,
      );

  Future<void> stubUpdate() async {}

  void verifyUpdate({
    required UploadStatus status,
    required int attempts,
    required String error,
    DateTime? nextRetryAt,
  }) {
    verify(
      () => repository.updateImageStatus(
        imageId: 'img-1',
        status: status,
        attemptCount: attempts,
        lastError: error,
        nextRetryAt: nextRetryAt,
      ),
    ).called(1);
    verifyNever(() => repository.markUploaded(any()));
  }

  setUpAll(() {
    registerFallbackValue(UploadStatus.queued);
  });

  setUp(() {
    repository = MockBatchRepository();
    when(
      () => repository.updateImageStatus(
        imageId: any(named: 'imageId'),
        status: any(named: 'status'),
        attemptCount: any(named: 'attemptCount'),
        lastError: any(named: 'lastError'),
        nextRetryAt: any(named: 'nextRetryAt'),
      ),
    ).thenAnswer((_) => stubUpdate());
    when(() => repository.markUploaded(any())).thenAnswer((_) async {});

    useCase = RecordUploadResult(
      repository,
      backoff: ExponentialBackoff(
        baseDelay: const Duration(seconds: 30),
        multiplier: 2,
        maxDelay: const Duration(minutes: 10),
        jitterRatio: 0,
        random: Random(1),
      ),
      now: () => fixedNow,
      maxAttempts: 3,
    );
  });

  test('success marks the image uploaded', () async {
    await useCase(uploading(), const UploadSuccess(serverReference: 'ref'));

    verify(() => repository.markUploaded('img-1')).called(1);
    verifyNever(
      () => repository.updateImageStatus(
        imageId: any(named: 'imageId'),
        status: any(named: 'status'),
        attemptCount: any(named: 'attemptCount'),
      ),
    );
  });

  test('a retryable failure counts an attempt and schedules a retry', () async {
    await useCase(
      uploading(),
      const UploadFailed(LowBandwidthFailure('slow')),
    );

    verifyUpdate(
      status: UploadStatus.retrying,
      attempts: 1,
      error: 'slow',
      nextRetryAt: fixedNow.add(const Duration(seconds: 30)),
    );
  });

  test('the retry delay grows with each attempt', () async {
    await useCase(
      uploading(attempts: 1),
      const UploadFailed(ServerFailure('busy', code: 503)),
    );

    verifyUpdate(
      status: UploadStatus.retrying,
      attempts: 2,
      error: 'busy',
      nextRetryAt: fixedNow.add(const Duration(seconds: 60)),
    );
  });

  test('reaching the maximum attempts moves to failed', () async {
    await useCase(
      uploading(attempts: 2),
      const UploadFailed(LowBandwidthFailure('slow')),
    );

    verifyUpdate(status: UploadStatus.failed, attempts: 3, error: 'slow');
  });

  test('a non-retryable failure fails immediately', () async {
    await useCase(
      uploading(),
      const UploadFailed(ServerFailure('bad request', code: 400)),
    );

    verifyUpdate(status: UploadStatus.failed, attempts: 0, error: 'bad request');
  });

  test('a missing file fails immediately', () async {
    await useCase(
      uploading(),
      const UploadFailed(FileMissingFailure('gone')),
    );

    verifyUpdate(status: UploadStatus.failed, attempts: 0, error: 'gone');
  });

  test('no internet waits for connectivity without using up an attempt',
      () async {
    await useCase(
      uploading(attempts: 2),
      const UploadFailed(NoInternetFailure('offline')),
    );

    verifyUpdate(
      status: UploadStatus.waitingForConnection,
      attempts: 2,
      error: 'offline',
    );
  });

  test('an unknown failure is retried like a slow connection', () async {
    await useCase(uploading(), const UploadFailed(UnknownFailure('odd')));

    verifyUpdate(
      status: UploadStatus.retrying,
      attempts: 1,
      error: 'odd',
      nextRetryAt: fixedNow.add(const Duration(seconds: 30)),
    );
  });

  group('returns the status the image ended in', () {
    test('uploaded, retrying, failed and waitingForConnection', () async {
      expect(
        await useCase(uploading(), const UploadSuccess(serverReference: 'r')),
        UploadStatus.uploaded,
      );
      expect(
        await useCase(uploading(), const UploadFailed(LowBandwidthFailure('s'))),
        UploadStatus.retrying,
      );
      expect(
        await useCase(
          uploading(attempts: 2),
          const UploadFailed(LowBandwidthFailure('s')),
        ),
        UploadStatus.failed,
      );
      expect(
        await useCase(
          uploading(),
          const UploadFailed(ServerFailure('x', code: 404)),
        ),
        UploadStatus.failed,
      );
      expect(
        await useCase(uploading(), const UploadFailed(NoInternetFailure('o'))),
        UploadStatus.waitingForConnection,
      );
    });
  });

  test('an illegal transition from the repository is not swallowed', () async {
    when(
      () => repository.updateImageStatus(
        imageId: any(named: 'imageId'),
        status: any(named: 'status'),
        attemptCount: any(named: 'attemptCount'),
        lastError: any(named: 'lastError'),
        nextRetryAt: any(named: 'nextRetryAt'),
      ),
    ).thenThrow(
      IllegalStatusTransitionError(UploadStatus.uploaded, UploadStatus.retrying),
    );

    await expectLater(
      useCase(uploading(), const UploadFailed(LowBandwidthFailure('slow'))),
      throwsA(isA<IllegalStatusTransitionError>()),
    );
  });
}
