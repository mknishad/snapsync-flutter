import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:snapsync/core/utils/clock.dart';
import 'package:snapsync/domain/repositories/batch_repository.dart';
import 'package:snapsync/domain/repositories/connectivity_monitor.dart';
import 'package:snapsync/domain/repositories/sync_scheduler.dart';
import 'package:snapsync/domain/repositories/sync_settings_repository.dart';
import 'package:snapsync/domain/services/sync_engine.dart';
import 'package:snapsync/presentation/upload_manager/cubit/sync_cubit.dart';
import 'package:snapsync/presentation/upload_manager/cubit/sync_message.dart';
import 'package:snapsync/presentation/upload_manager/cubit/sync_state.dart';

class _MockRepository extends Mock implements BatchRepository {}

class _MockEngine extends Mock implements SyncEngine {}

class _MockConnectivity extends Mock implements ConnectivityMonitor {}

class _MockSettings extends Mock implements SyncSettingsRepository {}

class _MockScheduler extends Mock implements SyncScheduler {}

/// A real [SyncCubit] (so streams and state behave exactly as in the app) whose
/// actions are recorded instead of performed. Tests set its state with [push].
class FakeSyncCubit extends SyncCubit {
  FakeSyncCubit(SyncState initial)
    : super(
        repository: _MockRepository(),
        engine: _MockEngine(),
        connectivity: _MockConnectivity(),
        settings: _MockSettings(),
        scheduler: _MockScheduler(),
        now: utcNow,
      ) {
    emit(initial);
  }

  /// What the UI asked for, for example `retry:abc` or `pauseAll`.
  final List<String> calls = [];

  final StreamController<SyncMessage> _fakeMessages =
      StreamController<SyncMessage>.broadcast();

  void push(SyncState state) => emit(state);

  void say(SyncMessage message) => _fakeMessages.add(message);

  @override
  Stream<SyncMessage> get messages => _fakeMessages.stream;

  @override
  Future<void> retryItem(String imageId) async => calls.add('retry:$imageId');

  @override
  Future<void> retryAllFailed() async => calls.add('retryAllFailed');

  @override
  Future<void> removeItem(String imageId) async => calls.add('remove:$imageId');

  @override
  Future<void> pauseAll() async => calls.add('pauseAll');

  @override
  Future<void> resumeAll() async => calls.add('resumeAll');

  @override
  Future<void> startSyncNow() async => calls.add('startSyncNow');

  @override
  void refresh() => calls.add('refresh');

  @override
  Future<void> onAppResumed() async => calls.add('resumed');

  @override
  Future<void> close() async {
    await _fakeMessages.close();
    return super.close();
  }
}
