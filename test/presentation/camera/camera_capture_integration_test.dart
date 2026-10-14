import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:snapsync/domain/usecases/add_captured_image.dart';
import 'package:snapsync/domain/usecases/remove_image.dart';
import 'package:snapsync/domain/usecases/submit_batch.dart';
import 'package:snapsync/presentation/batch/cubit/batch_cubit.dart';
import 'package:snapsync/presentation/camera/cubit/camera_cubit.dart';
import 'package:snapsync/presentation/camera/cubit/camera_message.dart';
import 'package:snapsync/presentation/camera/cubit/camera_state.dart';

import '../../support/camera_fakes.dart';
import '../../support/fakes.dart';
import '../../support/sync_test_env.dart';
import '../../support/test_support.dart';

/// The camera cubit, the real AddCapturedImage use case, a real repository,
/// real file storage and a real BatchCubit, on a real SQLite database.
void main() {
  late SyncTestEnv env;
  late FakeCameraService service;
  late CameraCubit camera;
  late BatchCubit batch;
  late List<String> temporaryFiles;

  setUp(() async {
    env = await SyncTestEnv.create();
    service = FakeCameraService();
    temporaryFiles = [];
    service.onCapture = () async {
      final file = env.cameraFile(bytes: 7);
      temporaryFiles.add(file.path);
      return file.path;
    };
    final addCaptured = AddCapturedImage(env.repository);
    batch = BatchCubit(
      repository: env.repository,
      addCapturedImage: addCaptured,
      removeImage: RemoveImage(env.repository),
      submitBatchUseCase: SubmitBatch(env.repository),
      scheduler: FakeSyncScheduler(),
    );
    await batch.start();
    camera = CameraCubit(
      service: service,
      permissions: FakeCameraPermissions(),
      addCapturedImage: addCaptured,
      now: () => env.now,
    );
    await camera.initialise();
    expect(camera.state.status, CameraStatus.ready);
  });

  tearDown(() async {
    await camera.close();
    await batch.close();
    await env.dispose();
  });

  Future<void> captureAfterGap() async {
    env.advance(const Duration(seconds: 1));
    await camera.capture();
  }

  test(
    'each capture adds an image to the open batch and updates the count',
    () async {
      await eventually(() => batch.state.status.name == 'ready');
      expect(batch.state.imageCount, 0);

      for (var i = 1; i <= 3; i++) {
        await captureAfterGap();
        await eventually(() => batch.state.imageCount == i);
      }

      final images = batch.state.currentBatch!.images;
      expect(images, hasLength(3));
      expect(images.map((i) => i.fileSizeBytes), everyElement(7));
    },
  );

  test(
    'the photo is copied into app storage and the temporary file is deleted',
    () async {
      await captureAfterGap();
      await eventually(() => batch.state.imageCount == 1);

      final image = batch.state.currentBatch!.images.single;
      expect(File(image.filePath).existsSync(), isTrue);
      expect(image.filePath, startsWith(p.join(env.appDir.path, 'batches')));
      expect(File(temporaryFiles.single).existsSync(), isFalse);
      expect(service.discarded, temporaryFiles);
    },
  );

  test('rapid taps save only one photo', () async {
    await Future.wait([camera.capture(), camera.capture(), camera.capture()]);
    await camera.capture();
    await eventually(() => batch.state.imageCount == 1);

    expect(service.captureCalls, 1);
    expect(batch.state.imageCount, 1);
  });

  test('a storage failure shows a message, saves nothing and keeps the camera '
      'running', () async {
    // Something is in the way of the batches folder, so storing must fail.
    File(p.join(env.appDir.path, 'batches')).writeAsStringSync('in the way');
    final messages = <CameraMessage>[];
    final sub = camera.messages.listen(messages.add);

    await captureAfterGap();
    await sub.cancel();

    expect(messages, [CameraMessage.storageFailed]);
    expect(camera.state.status, CameraStatus.ready);
    expect(camera.state.isCapturing, isFalse);
    expect(service.isOpen, isTrue);
    expect(batch.state.imageCount, 0);
    expect(
      File(temporaryFiles.single).existsSync(),
      isFalse,
      reason: 'the temporary file is removed even though saving failed',
    );

    // And once the problem is gone, capturing works again.
    File(p.join(env.appDir.path, 'batches')).deleteSync();
    await captureAfterGap();
    await eventually(() => batch.state.imageCount == 1);
  });

  test(
    'photos captured, then the batch submitted, become uploadable',
    () async {
      await captureAfterGap();
      await captureAfterGap();
      await eventually(() => batch.state.imageCount == 2);

      await batch.submitBatch();
      await eventually(() => batch.state.imageCount == 0);

      expect(await env.repository.getUploadable(env.now), hasLength(2));
    },
  );
}
