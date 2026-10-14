import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:snapsync/app/app.dart';
import 'package:snapsync/background/callback_dispatcher.dart';
import 'package:snapsync/core/di/injection.dart';
import 'package:snapsync/core/error/failure.dart';
import 'package:snapsync/domain/usecases/recover_interrupted_uploads.dart';
import 'package:workmanager/workmanager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await configureDependencies();
  await _recoverInterruptedUploads();
  await Workmanager().initialize(callbackDispatcher);

  // TODO: register the periodic sync task and the connectivity-constrained
  // one-off task here (names in background/task_names.dart).

  runApp(const SnapSyncApp());
}

/// Images left in `uploading` by a killed process go back to the queue. A
/// failure here must not stop the app from starting.
Future<void> _recoverInterruptedUploads() async {
  try {
    await getIt<RecoverInterruptedUploads>()();
  } on Failure catch (failure) {
    developer.log(
      'Could not recover interrupted uploads: ${failure.message}',
      name: 'snapsync.startup',
      level: 900,
    );
  }
}
