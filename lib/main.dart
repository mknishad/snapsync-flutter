import 'package:flutter/material.dart';
import 'package:snapsync/app/app.dart';
import 'package:snapsync/background/callback_dispatcher.dart';
import 'package:snapsync/core/di/injection.dart';
import 'package:snapsync/core/error/failure.dart';
import 'package:snapsync/core/utils/safe_log.dart';
import 'package:snapsync/domain/repositories/sync_scheduler.dart';
import 'package:snapsync/domain/usecases/recover_interrupted_uploads.dart';
import 'package:workmanager/workmanager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await configureDependencies();
  await _recoverInterruptedUploads();
  await Workmanager().initialize(callbackDispatcher);
  await _registerPeriodicSync();

  runApp(const SnapSyncApp());
}

/// Images left in `uploading` by a killed process go back to the queue. A
/// failure here must not stop the app from starting.
Future<void> _recoverInterruptedUploads() async {
  try {
    await getIt<RecoverInterruptedUploads>()();
  } on Failure catch (failure) {
    logProblem(
      'snapsync.startup',
      'Could not recover interrupted uploads',
      error: failure,
    );
  }
}

/// Registers the 15-minute safety-net task. Event-driven one-off syncs are
/// enqueued later, when a batch is submitted or a retryable failure happens.
Future<void> _registerPeriodicSync() async {
  try {
    await getIt<SyncScheduler>().registerPeriodicSync();
  } on Object catch (error, stack) {
    logProblem(
      'snapsync.startup',
      'Could not register the periodic sync',
      error: error,
      stackTrace: stack,
      level: 1000,
    );
  }
}
