import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snapsync/core/error/failure.dart';
import 'package:snapsync/domain/entities/capture_batch.dart';
import 'package:snapsync/domain/entities/captured_image.dart';
import 'package:snapsync/domain/errors/domain_errors.dart';
import 'package:snapsync/domain/repositories/batch_repository.dart';
import 'package:snapsync/domain/usecases/add_captured_image.dart';
import 'package:snapsync/domain/usecases/remove_image.dart';
import 'package:snapsync/domain/usecases/submit_batch.dart';
import 'package:snapsync/presentation/batch/cubit/batch_cubit.dart';
import 'package:snapsync/presentation/batch/cubit/batch_state.dart';

import '../support/fakes.dart';

class MockBatchRepository extends Mock implements BatchRepository {}

class MockAddCapturedImage extends Mock implements AddCapturedImage {}

class MockRemoveImage extends Mock implements RemoveImage {}

class MockSubmitBatch extends Mock implements SubmitBatch {}

CapturedImage image(String id) => CapturedImage(
      id: id,
      batchId: 'b1',
      filePath: '/fake/$id.jpg',
      fileSizeBytes: 10,
      capturedAt: DateTime.utc(2026),
    );

CaptureBatch batch(List<CapturedImage> images) =>
    CaptureBatch(id: 'b1', createdAt: DateTime.utc(2026), images: images);

Future<void> settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late MockBatchRepository repository;
  late MockAddCapturedImage addCapturedImage;
  late MockRemoveImage removeImage;
  late MockSubmitBatch submitBatch;
  late FakeSyncScheduler scheduler;
  late StreamController<CaptureBatch?> openBatch;

  BatchCubit build() => BatchCubit(
        repository: repository,
        addCapturedImage: addCapturedImage,
        removeImage: removeImage,
        submitBatchUseCase: submitBatch,
        scheduler: scheduler,
      );

  setUp(() {
    repository = MockBatchRepository();
    addCapturedImage = MockAddCapturedImage();
    removeImage = MockRemoveImage();
    submitBatch = MockSubmitBatch();
    scheduler = FakeSyncScheduler();
    openBatch = StreamController<CaptureBatch?>.broadcast();
    when(() => repository.watchOpenBatch()).thenAnswer((_) => openBatch.stream);
    when(() => submitBatch(any())).thenAnswer((_) async {});
  });

  tearDown(() => openBatch.close());

  blocTest<BatchCubit, BatchState>(
    'follows the open batch and exposes its image count',
    build: build,
    act: (cubit) async {
      await cubit.start();
      openBatch.add(null);
      await settle();
      openBatch.add(batch([image('a'), image('b')]));
      await settle();
    },
    verify: (cubit) {
      expect(cubit.state.status, BatchStatus.ready);
      expect(cubit.state.imageCount, 2);
    },
  );

  blocTest<BatchCubit, BatchState>(
    'captureImage adds the file through the use case',
    build: () {
      when(() => addCapturedImage('/tmp/shot.jpg'))
          .thenAnswer((_) async => image('a'));
      return build();
    },
    act: (cubit) async {
      await cubit.start();
      await cubit.captureImage('/tmp/shot.jpg');
    },
    verify: (cubit) => verify(() => addCapturedImage('/tmp/shot.jpg')).called(1),
  );

  blocTest<BatchCubit, BatchState>(
    'a storage failure while capturing is reported in state',
    build: () {
      when(() => addCapturedImage(any()))
          .thenThrow(const StorageFailure('disk full'));
      return build();
    },
    act: (cubit) async {
      await cubit.start();
      await cubit.captureImage('/tmp/shot.jpg');
    },
    verify: (cubit) {
      expect(cubit.state.status, BatchStatus.failure);
      expect(cubit.state.failure, const StorageFailure('disk full'));
    },
  );

  blocTest<BatchCubit, BatchState>(
    'deleteImage removes the image through the use case',
    build: () {
      when(() => removeImage('a')).thenAnswer((_) async {});
      return build();
    },
    act: (cubit) async {
      await cubit.start();
      await cubit.deleteImage('a');
    },
    verify: (cubit) => verify(() => removeImage('a')).called(1),
  );

  group('submitBatch', () {
    blocTest<BatchCubit, BatchState>(
      'submits the open batch, then enqueues one background sync',
      build: build,
      act: (cubit) async {
        await cubit.start();
        openBatch.add(batch([image('a'), image('b')]));
        await settle();

        await cubit.submitBatch();
        // The repository reports the batch is no longer open.
        openBatch.add(null);
        await settle();
      },
      verify: (cubit) {
        verify(() => submitBatch('b1')).called(1);
        expect(scheduler.enqueueCount, 1);
        expect(cubit.state.status, BatchStatus.ready);
        expect(cubit.state.imageCount, 0);
      },
    );

    blocTest<BatchCubit, BatchState>(
      'does nothing when there is no batch or it is empty',
      build: build,
      act: (cubit) async {
        await cubit.start();
        await cubit.submitBatch();
        openBatch.add(batch([]));
        await settle();
        await cubit.submitBatch();
      },
      verify: (cubit) {
        verifyNever(() => submitBatch(any()));
        expect(scheduler.enqueueCount, 0);
      },
    );

    blocTest<BatchCubit, BatchState>(
      'a failed submit is reported and nothing is scheduled',
      build: () {
        when(() => submitBatch(any()))
            .thenThrow(const DatabaseFailure('locked'));
        return build();
      },
      act: (cubit) async {
        await cubit.start();
        openBatch.add(batch([image('a')]));
        await settle();
        await cubit.submitBatch();
      },
      verify: (cubit) {
        expect(cubit.state.status, BatchStatus.failure);
        expect(scheduler.enqueueCount, 0);
      },
    );

    blocTest<BatchCubit, BatchState>(
      'a rule violation from the domain is reported too',
      build: () {
        when(() => submitBatch(any()))
            .thenThrow(IllegalBatchStateError('Cannot submit an empty batch'));
        return build();
      },
      act: (cubit) async {
        await cubit.start();
        openBatch.add(batch([image('a')]));
        await settle();
        await cubit.submitBatch();
      },
      verify: (cubit) {
        expect(cubit.state.status, BatchStatus.failure);
        expect(cubit.state.failure!.message, contains('empty batch'));
      },
    );

    blocTest<BatchCubit, BatchState>(
      'a scheduler problem does not undo a successful submit',
      build: () {
        scheduler.enqueueError = StateError('no plugin');
        return build();
      },
      act: (cubit) async {
        await cubit.start();
        openBatch.add(batch([image('a')]));
        await settle();
        await cubit.submitBatch();
        openBatch.add(null);
        await settle();
      },
      verify: (cubit) {
        verify(() => submitBatch('b1')).called(1);
        expect(scheduler.enqueueCount, 1);
        expect(cubit.state.status, BatchStatus.ready);
        expect(cubit.state.failure, isNull);
      },
    );
  });

  test('close cancels the batch subscription', () async {
    final cubit = build();
    await cubit.start();
    expect(openBatch.hasListener, isTrue);

    await cubit.close();

    expect(openBatch.hasListener, isFalse);
  });
}
