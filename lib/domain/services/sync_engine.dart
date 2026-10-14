import 'dart:async';

import 'package:snapsync/core/constants/app_constants.dart';
import 'package:snapsync/core/error/failure.dart';
import 'package:snapsync/core/utils/clock.dart';
import 'package:snapsync/core/utils/safe_log.dart';
import 'package:snapsync/domain/entities/captured_image.dart';
import 'package:snapsync/domain/entities/link_quality.dart';
import 'package:snapsync/domain/entities/sync_pass_result.dart';
import 'package:snapsync/domain/entities/sync_progress.dart';
import 'package:snapsync/domain/entities/upload_result.dart';
import 'package:snapsync/domain/entities/upload_status.dart';
import 'package:snapsync/domain/errors/domain_errors.dart';
import 'package:snapsync/domain/repositories/batch_repository.dart';
import 'package:snapsync/domain/repositories/connectivity_monitor.dart';
import 'package:snapsync/domain/repositories/sync_settings_repository.dart';
import 'package:snapsync/domain/repositories/upload_api.dart';
import 'package:snapsync/domain/usecases/recover_interrupted_uploads.dart';
import 'package:snapsync/domain/usecases/record_upload_result.dart';

/// Uploads the queue. The same code runs in the UI isolate and in the
/// Workmanager isolate, possibly at the same time, so the only thing it trusts
/// is the database: an image is taken with an atomic claim, and every result
/// goes through [RecordUploadResult].
///
/// Database failures are not caught here; they propagate to the caller (the
/// cubit or the background runner), which decides what to do.
class SyncEngine {
  SyncEngine({
    required this.repository,
    required this.uploadApi,
    required this.recordResult,
    required this.recoverInterrupted,
    required this.connectivity,
    required this.settings,
    required this._now,
    this.concurrency = AppConstants.syncConcurrency,
    this.claimTimeout = AppConstants.uploadClaimTimeout,
    this.claimRenewInterval = AppConstants.uploadClaimRenewInterval,
  }) : assert(concurrency >= 1, 'concurrency must be at least 1');

  final BatchRepository repository;
  final UploadApi uploadApi;
  final RecordUploadResult recordResult;
  final RecoverInterruptedUploads recoverInterrupted;
  final ConnectivityMonitor connectivity;
  final SyncSettingsRepository settings;
  final int concurrency;
  final Duration claimTimeout;
  final Duration claimRenewInterval;
  final Clock _now;

  final StreamController<SyncProgress> _progress =
      StreamController<SyncProgress>.broadcast();

  /// Claims this engine currently holds, by image id.
  final Map<String, CapturedImage> _held = {};
  Future<SyncPassResult>? _inFlight;
  bool _cancelRequested = false;

  /// Progress of the upload in flight. Background runs have no listeners.
  Stream<SyncProgress> get progress => _progress.stream;

  /// Runs one pass. If a pass is already running in this isolate, returns that
  /// pass's result instead of starting a second one.
  Future<SyncPassResult> runPass() {
    return _inFlight ??= _run().whenComplete(() => _inFlight = null);
  }

  /// Called when the platform stops the task. Releases the claims this engine
  /// holds so the images are picked up again, and tells the running pass to
  /// stop. A late result from an interrupted upload is ignored.
  Future<void> cancelPass() async {
    _cancelRequested = true;
    for (final image in _held.values.toList()) {
      try {
        await repository.updateImageStatus(
          imageId: image.id,
          status: UploadStatus.waitingForConnection,
          attemptCount: image.attemptCount,
          lastError: image.lastError,
          nextRetryAt: image.nextRetryAt,
        );
      } on IllegalStatusTransitionError {
        // Already moved on (finished or released by someone else).
      }
    }
    _held.clear();
  }

  Future<void> dispose() => _progress.close();

  // ---- the pass ----------------------------------------------------------

  Future<SyncPassResult> _run() async {
    _cancelRequested = false;
    final counts = _Counts();

    if (await settings.isPaused()) {
      return _finish(SyncPassOutcome.pausedByUser, counts);
    }

    await recoverInterrupted(staleAfter: claimTimeout);

    final attempted = <String>{};
    var stopReason = SyncPassOutcome.completed;
    var checkedLink = false;

    while (stopReason == SyncPassOutcome.completed) {
      final due = (await repository.getUploadable(_now()))
          .where((image) => !attempted.contains(image.id))
          .toList();
      if (due.isEmpty) break;

      // Nothing was due when the pass started means no network use at all.
      if (!checkedLink) {
        checkedLink = true;
        if (await connectivity.checkNow() != LinkQuality.stable) {
          await repository.markWaitingForConnection();
          return _finish(SyncPassOutcome.interruptedByConnectivity, counts);
        }
      }

      attempted.addAll(due.map((image) => image.id));
      stopReason = await _uploadAll(due, counts);
    }
    return _finish(stopReason, counts);
  }

  /// Uploads [images] with up to [concurrency] at a time and returns why it
  /// stopped, or `completed` if it got through them all.
  Future<SyncPassOutcome> _uploadAll(
    List<CapturedImage> images,
    _Counts counts,
  ) async {
    final queue = List<CapturedImage>.of(images);
    SyncPassOutcome? stop;
    var started = 0;

    Future<void> worker() async {
      while (stop == null && queue.isNotEmpty) {
        if (_cancelRequested) {
          stop = SyncPassOutcome.cancelled;
          return;
        }
        if (await settings.isPaused()) {
          stop = SyncPassOutcome.pausedByUser;
          return;
        }
        // The link was verified at the start; re-check only between uploads.
        if (started > 0 &&
            await connectivity.checkNow() == LinkQuality.offline) {
          stop = SyncPassOutcome.interruptedByConnectivity;
          return;
        }
        started++;
        final image = queue.removeAt(0);
        final reason = await _uploadOne(image, counts);
        if (reason != null) stop ??= reason;
      }
    }

    await Future.wait([for (var i = 0; i < concurrency; i++) worker()]);
    return stop ?? SyncPassOutcome.completed;
  }

  /// Returns a reason to end the pass, or null to carry on.
  Future<SyncPassOutcome?> _uploadOne(
    CapturedImage image,
    _Counts counts,
  ) async {
    final claimed = await repository.claimImage(image.id);
    if (claimed == null) {
      counts.skippedClaimedByOther++;
      return null;
    }
    _held[claimed.id] = claimed;

    final result = await _upload(claimed);
    if (_cancelRequested || !_held.containsKey(claimed.id)) {
      // cancelPass already released this claim.
      return SyncPassOutcome.cancelled;
    }

    try {
      final status = await recordResult(claimed, result);
      counts.add(status);
    } finally {
      _held.remove(claimed.id);
    }

    final noInternet =
        result is UploadFailed && result.failure is NoInternetFailure;
    return noInternet ? SyncPassOutcome.interruptedByConnectivity : null;
  }

  Future<UploadResult> _upload(CapturedImage image) async {
    var lastRenewal = _now();
    _emit(
      SyncProgress(
        imageId: image.id,
        fraction: 0,
        totalBytes: image.fileSizeBytes,
      ),
    );

    void onProgress(double fraction) {
      _emit(
        SyncProgress(
          imageId: image.id,
          fraction: fraction.clamp(0, 1),
          totalBytes: image.fileSizeBytes,
        ),
      );
      final now = _now();
      if (now.difference(lastRenewal) >= claimRenewInterval) {
        lastRenewal = now;
        unawaited(_renewClaim(image.id));
      }
    }

    try {
      return await uploadApi.upload(image, onProgress: onProgress);
    } on Object catch (error, stack) {
      // The API contract says it does not throw. If it does, record it as an
      // unknown failure so the image is retried instead of stuck uploading.
      logProblem(
        'snapsync.sync',
        'Upload threw an unexpected exception',
        error: error,
        stackTrace: stack,
        level: 1000,
      );
      return UploadFailed(UnknownFailure('Unexpected ${error.runtimeType}'));
    }
  }

  Future<void> _renewClaim(String imageId) async {
    try {
      await repository.renewClaim(imageId);
    } on Failure catch (failure) {
      logProblem(
        'snapsync.sync',
        'Could not renew an upload claim',
        error: failure,
      );
    }
  }

  void _emit(SyncProgress event) {
    if (!_progress.isClosed) _progress.add(event);
  }

  Future<SyncPassResult> _finish(
    SyncPassOutcome outcome,
    _Counts counts,
  ) async {
    final unfinished = await repository.getUnfinished();
    DateTime? nextRetryAt;
    for (final image in unfinished) {
      final due = image.nextRetryAt;
      if (image.status == UploadStatus.retrying && due != null) {
        if (nextRetryAt == null || due.isBefore(nextRetryAt)) nextRetryAt = due;
      }
    }
    return SyncPassResult(
      outcome: outcome,
      uploaded: counts.uploaded,
      failed: counts.failed,
      retrying: counts.retrying,
      waitingForConnection: counts.waiting,
      skippedClaimedByOther: counts.skippedClaimedByOther,
      remaining: unfinished.length,
      nextRetryAt: nextRetryAt,
    );
  }
}

class _Counts {
  int uploaded = 0;
  int failed = 0;
  int retrying = 0;
  int waiting = 0;
  int skippedClaimedByOther = 0;

  void add(UploadStatus status) {
    switch (status) {
      case UploadStatus.uploaded:
        uploaded++;
      case UploadStatus.failed:
        failed++;
      case UploadStatus.retrying:
        retrying++;
      case UploadStatus.waitingForConnection:
        waiting++;
      case UploadStatus.queued || UploadStatus.uploading:
        break;
    }
  }
}
