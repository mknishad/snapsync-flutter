import 'package:flutter/material.dart';
import 'package:snapsync/app/app.dart';
import 'package:snapsync/background/callback_dispatcher.dart';
import 'package:snapsync/core/di/injection.dart';
import 'package:workmanager/workmanager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await configureDependencies();
  await Workmanager().initialize(callbackDispatcher);

  // TODO: register the periodic sync task and the connectivity-constrained
  // one-off task here (names in background/task_names.dart).

  runApp(const SnapSyncApp());
}
