import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snapsync/domain/entities/capture_batch.dart';
import 'package:snapsync/domain/entities/captured_image.dart';
import 'package:snapsync/domain/repositories/batch_repository.dart';
import 'package:snapsync/domain/usecases/add_captured_image.dart';
import 'package:snapsync/domain/usecases/get_uploadable_images.dart';
import 'package:snapsync/domain/usecases/recover_interrupted_uploads.dart';
import 'package:snapsync/domain/usecases/remove_image.dart';
import 'package:snapsync/domain/usecases/submit_batch.dart';

class MockBatchRepository extends Mock implements BatchRepository {}

void main() {
  late MockBatchRepository repository;

  setUp(() => repository = MockBatchRepository());

  test('AddCapturedImage adds to the open batch', () async {
    final batch = CaptureBatch(id: 'b1', createdAt: DateTime.utc(2026));
    final image = CapturedImage(
      id: 'i1',
      batchId: 'b1',
      filePath: '/fake/i1.jpg',
      fileSizeBytes: 1,
      capturedAt: DateTime.utc(2026),
    );
    when(() => repository.getOrCreateOpenBatch())
        .thenAnswer((_) async => batch);
    when(() => repository.addImage('b1', '/tmp/shot.jpg'))
        .thenAnswer((_) async => image);

    expect(await AddCapturedImage(repository)('/tmp/shot.jpg'), image);
  });

  test('SubmitBatch and RemoveImage delegate to the repository', () async {
    when(() => repository.submitBatch('b1')).thenAnswer((_) async {});
    when(() => repository.removeImage('i1')).thenAnswer((_) async {});

    await SubmitBatch(repository)('b1');
    await RemoveImage(repository)('i1');

    verify(() => repository.submitBatch('b1')).called(1);
    verify(() => repository.removeImage('i1')).called(1);
  });

  test('GetUploadableImages passes the injected time', () async {
    final now = DateTime.utc(2026, 5, 5);
    when(() => repository.getUploadable(now)).thenAnswer((_) async => []);

    await GetUploadableImages(repository, now: () => now)();

    verify(() => repository.getUploadable(now)).called(1);
  });

  test('RecoverInterruptedUploads forwards the staleness window', () async {
    when(
      () => repository.resetInterruptedUploads(
        staleAfter: const Duration(minutes: 10),
      ),
    ).thenAnswer((_) async => 2);

    final count = await RecoverInterruptedUploads(repository)(
      staleAfter: const Duration(minutes: 10),
    );

    expect(count, 2);
    verify(
      () => repository.resetInterruptedUploads(
        staleAfter: const Duration(minutes: 10),
      ),
    ).called(1);
  });
}
