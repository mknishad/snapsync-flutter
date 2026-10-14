import 'dart:async';
import 'dart:io';

import 'package:snapsync/data/local/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A helper backed by an in-memory SQLite database (no isolate, so tests stay
/// deterministic). Each call returns an independent database.
DatabaseHelper createTestDatabaseHelper({String? path}) {
  sqfliteFfiInit();
  return DatabaseHelper(
    factory: databaseFactoryFfiNoIsolate,
    path: path ?? inMemoryDatabasePath,
  );
}

/// Polls until [condition] holds, failing the test after [timeout].
Future<void> eventually(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

Directory createTempDir(String prefix) =>
    Directory.systemTemp.createTempSync(prefix);

/// Like [eventually] for a condition that has to read from the database.
Future<void> eventuallyAsync(
  Future<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!await condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
