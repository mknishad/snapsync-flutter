import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:snapsync/core/constants/app_constants.dart';
import 'package:snapsync/core/error/failure.dart';
import 'package:snapsync/core/utils/clock.dart';
import 'package:snapsync/core/utils/safe_log.dart';
import 'package:snapsync/core/utils/timer_factory.dart';
import 'package:snapsync/domain/entities/capture_batch.dart';
import 'package:snapsync/domain/entities/link_quality.dart';
import 'package:snapsync/domain/entities/sync_pass_result.dart';
import 'package:snapsync/domain/entities/sync_progress.dart';
import 'package:snapsync/domain/entities/upload_status.dart';
import 'package:snapsync/domain/errors/domain_errors.dart';
import 'package:snapsync/domain/repositories/batch_repository.dart';
import 'package:snapsync/domain/repositories/connectivity_monitor.dart';
import 'package:snapsync/domain/repositories/sync_scheduler.dart';
import 'package:snapsync/domain/repositories/sync_settings_repository.dart';
import 'package:snapsync/domain/services/sync_engine.dart';
import 'package:snapsync/presentation/upload_manager/cubit/sync_message.dart';
import 'package:snapsync/presentation/upload_manager/cubit/sync_state.dart';
import 'package:snapsync/presentation/upload_manager/models/batch_summary.dart';
import 'package:snapsync/presentation/upload_manager/models/upload_item_view_model.dart';

/// Drives the Upload Manager: shows the queue, reacts to connectivity, runs
/// foreground sync passes and falls back to a background task.
///
/// Call [start] once after creating it.
class SyncCubit extends Cubit<SyncState> {
  SyncCubit({
    required this.repository,
    required this.engine,
    required this.connectivity,
    required this.settings,
    required this.scheduler,
    required this._now,
    this.maxAttempts = AppConstants.maxUploadRetries,
    TimerFactory? timerFactory,
  }) : _timer = timerFactory ?? realTimer,
       super(const SyncState());

  final BatchRepository repository;
  final SyncEngine engine;
  final ConnectivityMonitor connectivity;
  final SyncSettingsRepository settings;
  final SyncScheduler scheduler;
  final int maxAttempts;
  final Clock _now;
  final TimerFactory _timer;

  final StreamController<SyncMessage> _messages =
      StreamController<SyncMessage>.broadcast();

  StreamSubscription<List<CaptureBatch>>? _batchesSub;
  StreamSubscription<SyncProgress>? _progressSub;
  StreamSubscription<LinkQuality>? _linkSub;
  Timer? _retryTimer;

  List<CaptureBatch> _batches = const [];
  final Map<String, double> _liveProgress = {};

  /// Queued images already seen, so only newly queued work starts a pass.
  final Set<String> _seenQueued = {};

  /// One-off messages for snackbars.
  Stream<SyncMessage> get messages => _messages.stream;

  Future<void> start() async {
    try {
      emit(state.copyWith(isPaused: await settings.isPaused()));
    } on Failure catch (failure) {
      _report(failure);
    }
    _batchesSub = repository.watchSubmittedBatches().listen(
      _onBatches,
      onError: (Object error) => _reportError(error),
    );
    _progressSub = engine.progress.listen(_onProgress);
    _linkSub = connectivity.onLinkQualityChanged.listen(_onLinkQuality);
  }

  // ---- user actions ------------------------------------------------------

  /// Moves one failed image back to the queue and syncs.
  Future<void> retryItem(String imageId) async {
    final item = state.items.where((i) => i.id == imageId).firstOrNull;
    if (item == null || item.status != UploadStatus.failed) return;
    if (await _requeue([imageId])) await _requestSync();
  }

  Future<void> retryAllFailed() async {
    final ids = [
      for (final item in state.items)
        if (item.status == UploadStatus.failed) item.id,
    ];
    if (ids.isEmpty) return;
    if (await _requeue(ids)) await _requestSync();
  }

  Future<void> pauseAll() async {
    try {
      await settings.setPaused(paused: true);
      emit(state.copyWith(isPaused: true));
      _messages.add(const SyncMessage('Uploads paused'));
    } on Failure catch (failure) {
      _report(failure);
    }
  }

  Future<void> resumeAll() async {
    try {
      await settings.setPaused(paused: false);
      emit(state.copyWith(isPaused: false));
    } on Failure catch (failure) {
      _report(failure);
      return;
    }
    await _requestSync();
  }

  Future<void> removeItem(String imageId) async {
    try {
      await repository.removeImage(imageId);
    } on Failure catch (failure) {
      _report(failure);
    } on IllegalBatchStateError {
      _messages.add(
        const SyncMessage(
          'Cannot remove an image while it uploads',
          isError: true,
        ),
      );
    }
  }

  /// Runs a pass now (the engine decides whether the link is good enough) and
  /// asks for a background run as a fallback.
  Future<void> startSyncNow() => _requestSync();

  /// Re-reads the database. Writes made by the background isolate do not
  /// notify this isolate, so call this when the app resumes and on a timer
  /// while the Upload Manager is visible.
  void refresh() => repository.refresh();

  Future<void> onAppResumed() async {
    refresh();
    if (state.linkQuality == LinkQuality.stable) await _runPass();
  }

  // ---- reactions ---------------------------------------------------------

  void _onBatches(List<CaptureBatch> batches) {
    _batches = batches;
    _rebuild();
    if (_hasNewQueuedWork(batches) &&
        state.linkQuality == LinkQuality.stable &&
        !state.isPaused) {
      unawaited(_runPass());
    }
  }

  void _onProgress(SyncProgress progress) {
    _liveProgress[progress.imageId] = progress.fraction;
    _rebuild();
  }

  void _onLinkQuality(LinkQuality quality) {
    if (quality == state.linkQuality) return;
    emit(state.copyWith(linkQuality: quality));
    switch (quality) {
      case LinkQuality.offline:
        // Show why nothing moves; nothing is lost.
        unawaited(_markWaiting());
      case LinkQuality.stable:
        if (!state.isPaused) unawaited(_requestSync());
      case LinkQuality.unstable:
        break;
    }
  }

  /// True if a queued or waiting image appeared that no earlier emission had.
  bool _hasNewQueuedWork(List<CaptureBatch> batches) {
    var found = false;
    for (final batch in batches) {
      for (final image in batch.images) {
        final waiting =
            image.status == UploadStatus.queued ||
            image.status == UploadStatus.waitingForConnection;
        if (waiting && _seenQueued.add(image.id)) found = true;
      }
    }
    return found;
  }

  // ---- passes ------------------------------------------------------------

  Future<void> _requestSync() async {
    if (state.isPaused) return;
    unawaited(_enqueueBackground());
    await _runPass();
  }

  Future<void> _runPass() async {
    if (state.isSyncing || isClosed) return;
    emit(state.copyWith(isSyncing: true));
    try {
      _afterPass(await engine.runPass());
    } on Failure catch (failure) {
      _report(failure);
    } finally {
      _liveProgress.clear();
      if (!isClosed) {
        emit(state.copyWith(isSyncing: false));
        _rebuild();
      }
    }
  }

  void _afterPass(SyncPassResult result) {
    if (result.failed > 0) {
      _messages.add(
        SyncMessage('${result.failed} upload(s) failed', isError: true),
      );
    } else if (result.uploaded > 0 && !result.hasWorkRemaining) {
      _messages.add(const SyncMessage('All uploads complete'));
    }

    final retryAt = result.nextRetryAt;
    if (retryAt != null) {
      // Keep going in the foreground when the retry is due, and make sure a
      // background run exists in case the app goes away first.
      final delay = retryAt.difference(_now());
      _retryTimer?.cancel();
      _retryTimer = _timer(
        delay.isNegative ? Duration.zero : delay,
        () => unawaited(_runPass()),
      );
      unawaited(_enqueueBackground());
    }
  }

  Future<void> _enqueueBackground() async {
    try {
      await scheduler.enqueueSyncNow();
    } on Object catch (error, stack) {
      // The periodic task is still a safety net, so this is not fatal.
      logProblem(
        'snapsync.sync',
        'Could not enqueue background sync',
        error: error,
        stackTrace: stack,
        level: 1000,
      );
    }
  }

  Future<void> _markWaiting() async {
    try {
      await repository.markWaitingForConnection();
    } on Failure catch (failure) {
      _report(failure);
    }
  }

  Future<bool> _requeue(List<String> imageIds) async {
    try {
      for (final id in imageIds) {
        await repository.updateImageStatus(
          imageId: id,
          status: UploadStatus.queued,
          attemptCount: 0,
        );
      }
      return true;
    } on Failure catch (failure) {
      _report(failure);
      return false;
    }
  }

  // ---- state -------------------------------------------------------------

  void _rebuild() {
    if (isClosed) return;
    final items = <UploadItemViewModel>[];
    var queueBytes = 0;
    var queueDoneBytes = 0.0;

    for (final batch in _batches) {
      final active = batch.aggregateStatus != UploadStatus.uploaded;
      for (final image in batch.images) {
        final live = image.status == UploadStatus.uploading
            ? _liveProgress[image.id]
            : null;
        items.add(
          UploadItemViewModel.fromImage(
            image,
            maxAttempts: maxAttempts,
            liveProgress: live,
          ),
        );
        if (active) {
          queueBytes += image.fileSizeBytes;
          queueDoneBytes += image.status == UploadStatus.uploaded
              ? image.fileSizeBytes
              : (live ?? 0) * image.fileSizeBytes;
        }
      }
    }

    emit(
      state.copyWith(
        items: items,
        batches: _batches.map(BatchSummary.fromBatch).toList(),
        totalBytes: queueBytes,
        uploadedBytes: queueDoneBytes.round(),
        overallProgress: queueBytes == 0 ? 0 : queueDoneBytes / queueBytes,
      ),
    );
  }

  void _report(Failure failure) {
    _messages.add(SyncMessage(_userMessage(failure), isError: true));
  }

  /// Database and storage messages can contain SQL or file paths, so they are
  /// not shown on screen.
  String _userMessage(Failure failure) {
    return switch (failure) {
      DatabaseFailure() => 'Could not access local data',
      StorageFailure() ||
      FileMissingFailure() => 'Could not access a stored photo',
      _ => failure.message,
    };
  }

  void _reportError(Object error) {
    if (error is Failure) {
      _report(error);
    } else {
      logProblem(
        'snapsync.sync',
        'Unexpected error from the batch stream',
        error: error,
        level: 1000,
      );
      _messages.add(const SyncMessage('Something went wrong', isError: true));
    }
  }

  @override
  Future<void> close() async {
    _retryTimer?.cancel();
    await _batchesSub?.cancel();
    await _progressSub?.cancel();
    await _linkSub?.cancel();
    await _messages.close();
    return super.close();
  }
}
