import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:snapsync/core/error/failure.dart';
import 'package:snapsync/domain/entities/link_quality.dart';
import 'package:snapsync/domain/entities/sync_pass_result.dart';
import 'package:snapsync/domain/entities/sync_progress.dart';
import 'package:snapsync/domain/entities/upload_result.dart';
import 'package:snapsync/domain/entities/upload_status.dart';

import '../support/fakes.dart';
import '../support/sync_test_env.dart';
import '../support/test_support.dart';

void main() {
  late SyncTestEnv env;

  Future<SyncTestEnv> createEnv({
    bool fileDatabase = false,
    int concurrency = 1,
    Duration claimTimeout = const Duration(minutes: 5),
    Duration claimRenewInterval = const Duration(seconds: 30),
  }) async {
    env = await SyncTestEnv.create(
      fileDatabase: fileDatabase,
      concurrency: concurrency,
      claimTimeout: claimTimeout,
      claimRenewInterval: claimRenewInterval,
    );
    return env;
  }

  Future<void> recreateEnv({
    bool fileDatabase = false,
    int concurrency = 1,
    Duration claimRenewInterval = const Duration(seconds: 30),
  }) async {
    await env.dispose();
    await createEnv(
      fileDatabase: fileDatabase,
      concurrency: concurrency,
      claimRenewInterval: claimRenewInterval,
    );
  }

  Future<int> updatedAt(String imageId) async {
    final rows = await env.db.query(
      'images',
      columns: ['updated_at'],
      where: 'id = ?',
      whereArgs: [imageId],
    );
    return rows.single['updated_at']! as int;
  }

  setUp(() async => createEnv());
  tearDown(() => env.dispose());

  UploadFailed failed(Failure failure) => UploadFailed(failure);

  group('a successful pass', () {
    test('uploads everything in capture order and deletes the local files',
        () async {
      final images = await env.submitImages(3);

      final result = await env.engine.runPass();

      expect(env.api.calls, images.map((i) => i.id));
      expect(result.outcome, SyncPassOutcome.completed);
      expect(result.uploaded, 3);
      expect(result.failed, 0);
      expect(result.remaining, 0);
      expect(result.nextRetryAt, isNull);
      for (final image in images) {
        final stored = await env.image(image.id);
        expect(stored.status, UploadStatus.uploaded);
        expect(File(image.filePath).existsSync(), isFalse);
      }
    });

    test('emits monotonic progress for the foreground UI', () async {
      final images = await env.submitImages(1, bytes: 200);
      final events = <SyncProgress>[];
      final sub = env.engine.progress.listen(events.add);
      addTearDown(sub.cancel);

      await env.engine.runPass();
      await Future<void>.delayed(Duration.zero);

      expect(events.map((e) => e.imageId).toSet(), {images.single.id});
      final fractions = events.map((e) => e.fraction).toList();
      expect(fractions, [0, 0.5, 1]);
      expect(events.last.bytesUploaded, 200);
    });

    test('does nothing and never probes the network when nothing is due',
        () async {
      final result = await env.engine.runPass();

      expect(result.outcome, SyncPassOutcome.completed);
      expect(env.api.calls, isEmpty);
      expect(env.monitor.checkNowCount, 0);
    });

    test('images in an open batch are not uploaded', () async {
      final batch = await env.repository.getOrCreateOpenBatch();
      await env.repository.addImage(batch.id, env.cameraFile().path);

      await env.engine.runPass();

      expect(env.api.calls, isEmpty);
    });

    test('concurrent calls in one isolate share a single pass', () async {
      await env.submitImages(3);

      final results = await Future.wait([
        env.engine.runPass(),
        env.engine.runPass(),
      ]);

      expect(env.api.calls, hasLength(3));
      expect(identical(results[0], results[1]), isTrue);
    });
  });

  group('failures', () {
    test('no internet ends the pass without using up an attempt', () async {
      final images = await env.submitImages(3);
      env.api.handler = (_) => failed(const NoInternetFailure('offline'));

      final result = await env.engine.runPass();

      expect(result.outcome, SyncPassOutcome.interruptedByConnectivity);
      expect(env.api.calls, [images[0].id], reason: 'pass ended after one try');
      final first = await env.image(images[0].id);
      expect(first.status, UploadStatus.waitingForConnection);
      expect(first.attemptCount, 0);
      expect(first.nextRetryAt, isNull);
      expect((await env.image(images[1].id)).status, UploadStatus.queued);
      expect(result.waitingForConnection, 1);
      expect(result.remaining, 3);
    });

    test('a waiting image is picked up on the next pass', () async {
      final images = await env.submitImages(1);
      env.api.handler = (_) => failed(const NoInternetFailure('offline'));
      await env.engine.runPass();

      env.api.handler = null;
      await env.engine.runPass();

      expect((await env.image(images.single.id)).status, UploadStatus.uploaded);
    });

    test('low bandwidth schedules a retry with backoff', () async {
      final images = await env.submitImages(1);
      env.api.handler = (_) => failed(const LowBandwidthFailure('slow'));

      final result = await env.engine.runPass();

      final stored = await env.image(images.single.id);
      expect(stored.status, UploadStatus.retrying);
      expect(stored.attemptCount, 1);
      expect(stored.lastError, 'slow');
      expect(stored.nextRetryAt, env.now.add(const Duration(seconds: 30)));
      expect(result.retrying, 1);
      expect(result.nextRetryAt, stored.nextRetryAt);
      expect(result.outcome, SyncPassOutcome.completed);
    });

    test('a retry is not attempted before it is due, then succeeds', () async {
      final images = await env.submitImages(1);
      env.api.handler = (_) => failed(const LowBandwidthFailure('slow'));
      await env.engine.runPass();

      env.api.handler = null;
      await env.engine.runPass();
      expect(env.api.calls, hasLength(1), reason: 'not due yet');

      env.advance(const Duration(seconds: 31));
      await env.engine.runPass();

      expect(env.api.calls, hasLength(2));
      expect((await env.image(images.single.id)).status, UploadStatus.uploaded);
    });

    test('the retry delay doubles with each attempt', () async {
      final images = await env.submitImages(1);
      env.api.handler = (_) => failed(const LowBandwidthFailure('slow'));
      final delays = <Duration>[];

      for (var i = 0; i < 2; i++) {
        final before = env.now;
        await env.engine.runPass();
        delays.add((await env.image(images.single.id)).nextRetryAt!.difference(before));
        env.advance(const Duration(minutes: 5));
      }

      expect(delays, [const Duration(seconds: 30), const Duration(seconds: 60)]);
    });

    test('retries are exhausted after the maximum attempts', () async {
      final images = await env.submitImages(1);
      env.api.handler = (_) => failed(const LowBandwidthFailure('slow'));

      for (var i = 0; i < 3; i++) {
        await env.engine.runPass();
        env.advance(const Duration(minutes: 20));
      }

      final stored = await env.image(images.single.id);
      expect(stored.status, UploadStatus.failed);
      expect(stored.attemptCount, 3);
      expect(stored.nextRetryAt, isNull);
      expect(env.api.calls, hasLength(3));

      env.advance(const Duration(hours: 1));
      await env.engine.runPass();
      expect(env.api.calls, hasLength(3), reason: 'failed is never retried');
    });

    test('a non-retryable server error fails at once', () async {
      final images = await env.submitImages(2);
      env.api.handler = (image) => image.id == images[0].id
          ? failed(const ServerFailure('bad request', code: 400))
          : UploadSuccess(serverReference: 'ref');

      final result = await env.engine.runPass();

      final first = await env.image(images[0].id);
      expect(first.status, UploadStatus.failed);
      expect(first.attemptCount, 0);
      expect(first.lastError, 'bad request');
      expect((await env.image(images[1].id)).status, UploadStatus.uploaded);
      expect(result.failed, 1);
      expect(result.uploaded, 1);
      expect(result.outcome, SyncPassOutcome.completed);
    });

    test('a retryable server error is retried like a slow link', () async {
      final images = await env.submitImages(1);
      env.api.handler = (_) => failed(const ServerFailure('busy', code: 503));

      await env.engine.runPass();

      expect((await env.image(images.single.id)).status, UploadStatus.retrying);
    });

    test('a missing file fails and is never retried', () async {
      final images = await env.submitImages(1);
      env.api.handler = (_) => failed(const FileMissingFailure('gone'));

      await env.engine.runPass();
      env.advance(const Duration(hours: 1));
      await env.engine.runPass();

      final stored = await env.image(images.single.id);
      expect(stored.status, UploadStatus.failed);
      expect(stored.attemptCount, 0);
      expect(env.api.calls, hasLength(1));
    });

    test('an exception thrown by the API is recorded, not left uploading',
        () async {
      final images = await env.submitImages(1);
      env.api.whileUploading = (_) => throw StateError('boom');

      await env.engine.runPass();

      final stored = await env.image(images.single.id);
      expect(stored.status, UploadStatus.retrying);
      expect(stored.lastError, contains('StateError'));
    });
  });

  group('pause and connectivity', () {
    test('a paused engine returns at once and uploads nothing', () async {
      await env.submitImages(2);
      await env.settings.setPaused(paused: true);

      final result = await env.engine.runPass();

      expect(result.outcome, SyncPassOutcome.pausedByUser);
      expect(env.api.calls, isEmpty);
      expect(result.remaining, 2);
    });

    test('pausing mid-pass stops before the next image', () async {
      final images = await env.submitImages(3);
      env.api.whileUploading = (image) async {
        if (image.id == images[0].id) await env.settings.setPaused(paused: true);
      };

      final result = await env.engine.runPass();

      expect(result.outcome, SyncPassOutcome.pausedByUser);
      expect(env.api.calls, [images[0].id]);
      expect(result.uploaded, 1);
      expect(result.remaining, 2);
    });

    test('resuming lets the next pass finish the work', () async {
      await env.submitImages(2);
      await env.settings.setPaused(paused: true);
      await env.engine.runPass();

      await env.settings.setPaused(paused: false);
      final result = await env.engine.runPass();

      expect(result.uploaded, 2);
    });

    test('an unstable link at the start uploads nothing and shows waiting',
        () async {
      final images = await env.submitImages(2);
      env.monitor.quality = LinkQuality.unstable;

      final result = await env.engine.runPass();

      expect(result.outcome, SyncPassOutcome.interruptedByConnectivity);
      expect(env.api.calls, isEmpty);
      for (final image in images) {
        expect((await env.image(image.id)).status,
            UploadStatus.waitingForConnection);
      }
    });

    test('an offline link at the start is treated the same way', () async {
      await env.submitImages(1);
      env.monitor.quality = LinkQuality.offline;

      final result = await env.engine.runPass();

      expect(result.outcome, SyncPassOutcome.interruptedByConnectivity);
      expect(env.api.calls, isEmpty);
    });

    test('losing the connection mid-pass stops early', () async {
      final images = await env.submitImages(3);
      // First check (pass start) is stable; the check before image two is not.
      env.monitor.script.addAll([LinkQuality.stable, LinkQuality.offline]);

      final result = await env.engine.runPass();

      expect(result.outcome, SyncPassOutcome.interruptedByConnectivity);
      expect(env.api.calls, [images[0].id]);
      expect(result.uploaded, 1);
      expect(result.remaining, 2);
      expect((await env.image(images[1].id)).status, UploadStatus.queued);
    });

    test('a merely unstable link mid-pass does not stop the pass', () async {
      await env.submitImages(3);
      env.monitor.script.addAll([
        LinkQuality.stable,
        LinkQuality.unstable,
        LinkQuality.unstable,
      ]);

      final result = await env.engine.runPass();

      expect(result.uploaded, 3);
    });
  });

  group('claiming', () {
    test('two engines running at once never upload the same image twice',
        () async {
      await recreateEnv(fileDatabase: true);
      final images = await env.submitImages(12);
      // A second engine on its own connection to the same database file, like
      // the background isolate. Both report to the same recording API.
      final second = await env.newSecondEngine(monitor: FakeConnectivityMonitor());

      final results = await Future.wait([
        env.engine.runPass(),
        second.engine.runPass(),
      ]);

      final calls = env.api.calls;
      expect(calls.toSet(), hasLength(calls.length),
          reason: 'no image uploaded twice');
      expect(calls.toSet(), images.map((i) => i.id).toSet());
      expect(results.fold<int>(0, (sum, r) => sum + r.uploaded), 12);
      expect(
        results.fold<int>(0, (sum, r) => sum + r.skippedClaimedByOther),
        greaterThan(0),
        reason: 'the engines really did race for the same images',
      );
      for (final image in images) {
        expect((await env.image(image.id)).status, UploadStatus.uploaded);
      }
    });

    test('a claim is atomic: only one of two connections wins an image',
        () async {
      await recreateEnv(fileDatabase: true);
      final images = await env.submitImages(1);
      final other = await env.newSecondEngine(monitor: FakeConnectivityMonitor());

      final claims = await Future.wait([
        env.repository.claimImage(images.single.id),
        other.repository.claimImage(images.single.id),
      ]);

      expect(claims.where((c) => c != null), hasLength(1));
    });

    test('a claim abandoned by a killed process is released after the timeout',
        () async {
      final images = await env.submitImages(1);
      // A process claimed the image and died.
      expect(await env.repository.claimImage(images.single.id), isNotNull);
      expect((await env.image(images.single.id)).status, UploadStatus.uploading);

      env.advance(env.claimTimeout + const Duration(seconds: 1));
      final result = await env.engine.runPass();

      expect(result.uploaded, 1);
      expect(env.api.calls, [images.single.id]);
    });

    test('a fresh claim is left alone', () async {
      final images = await env.submitImages(1);
      await env.repository.claimImage(images.single.id);

      env.advance(env.claimTimeout - const Duration(seconds: 1));
      final result = await env.engine.runPass();

      expect(env.api.calls, isEmpty);
      expect((await env.image(images.single.id)).status, UploadStatus.uploading);
      expect(result.remaining, 1);
    });

    test('a long upload renews its claim so it is not mistaken for abandoned',
        () async {
      await recreateEnv(claimRenewInterval: const Duration(seconds: 10));
      final images = await env.submitImages(1);
      final id = images.single.id;
      final claimedAt = env.now.millisecondsSinceEpoch;
      final gate = Completer<void>();
      env.api.progressSteps = const [0.3];
      // The clock jumps 15 s before the progress report, past the 10 s renewal
      // interval; the upload then stays open.
      env.api.onEachStep = (_) => env.advance(const Duration(seconds: 15));
      env.api.whileUploading = (_) => gate.future;

      final pass = env.engine.runPass();
      await eventuallyAsync(() async => await updatedAt(id) > claimedAt);

      expect(await updatedAt(id), claimedAt + 15000);
      gate.complete();
      expect((await pass).uploaded, 1);
    });

    test('concurrency 2 uploads two images at the same time', () async {
      await recreateEnv(concurrency: 2);
      await env.submitImages(4);
      env.api.whileUploading = (_) => Future<void>.delayed(
            const Duration(milliseconds: 5),
          );

      final result = await env.engine.runPass();

      expect(result.uploaded, 4);
      expect(env.api.maxInFlight, 2);
    });

    test('concurrency 1 never overlaps uploads', () async {
      await env.submitImages(3);
      env.api.whileUploading = (_) => Future<void>.delayed(
            const Duration(milliseconds: 5),
          );

      await env.engine.runPass();

      expect(env.api.maxInFlight, 1);
    });
  });

  group('cancelPass (the platform stopped the task)', () {
    test('releases the claim and ignores the late result', () async {
      final images = await env.submitImages(2);
      final gate = Completer<void>();
      final started = Completer<void>();
      env.api.whileUploading = (_) {
        if (!started.isCompleted) started.complete();
        return gate.future;
      };

      final pass = env.engine.runPass();
      await started.future;
      expect((await env.image(images[0].id)).status, UploadStatus.uploading);

      await env.engine.cancelPass();
      expect((await env.image(images[0].id)).status,
          UploadStatus.waitingForConnection);

      gate.complete();
      final result = await pass;

      expect(result.outcome, SyncPassOutcome.cancelled);
      expect((await env.image(images[0].id)).status,
          UploadStatus.waitingForConnection,
          reason: 'the late result must not overwrite the released claim');
      expect(env.api.calls, [images[0].id], reason: 'second image never started');
    });

    test('the engine can run a fresh pass afterwards', () async {
      await env.submitImages(1);
      await env.engine.cancelPass();

      final result = await env.engine.runPass();

      expect(result.uploaded, 1);
    });
  });

}
