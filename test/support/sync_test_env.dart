import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:snapsync/data/local/daos/batch_dao.dart';
import 'package:snapsync/data/local/daos/image_dao.dart';
import 'package:snapsync/data/local/daos/settings_dao.dart';
import 'package:snapsync/data/local/database_helper.dart';
import 'package:snapsync/data/local/settings_store.dart';
import 'package:snapsync/data/repositories/batch_repository_impl.dart';
import 'package:snapsync/data/repositories/sync_settings_repository_impl.dart';
import 'package:snapsync/data/storage/image_file_storage.dart';
import 'package:snapsync/domain/entities/captured_image.dart';
import 'package:snapsync/domain/services/exponential_backoff.dart';
import 'package:snapsync/domain/services/sync_engine.dart';
import 'package:snapsync/domain/usecases/recover_interrupted_uploads.dart';
import 'package:snapsync/domain/usecases/record_upload_result.dart';
import 'package:sqflite/sqflite.dart';

import 'fakes.dart';
import 'test_support.dart';

/// A real repository, settings store and sync engine on a real SQLite database
/// (in memory, or a temp file when [fileDatabase] is set), with a fake clock,
/// fake link monitor and a scripted upload API.
class SyncTestEnv {
  SyncTestEnv._(this.fileDatabase);

  static Future<SyncTestEnv> create({
    bool fileDatabase = false,
    int concurrency = 1,
    Duration claimTimeout = const Duration(minutes: 5),
    Duration claimRenewInterval = const Duration(seconds: 30),
    int maxAttempts = 3,
  }) async {
    final env = SyncTestEnv._(fileDatabase);
    env.root = createTempDir('snapsync_sync_');
    env.appDir = Directory(p.join(env.root.path, 'app'))..createSync();
    env.cameraDir = Directory(p.join(env.root.path, 'camera'))..createSync();
    env.dbPath = fileDatabase ? p.join(env.root.path, 'shared.db') : null;
    env.now = DateTime.utc(2026, 6, 1, 8);
    env.concurrency = concurrency;
    env.claimTimeout = claimTimeout;
    env.claimRenewInterval = claimRenewInterval;
    env.maxAttempts = maxAttempts;

    env.helper = createTestDatabaseHelper(path: env.dbPath);
    env.db = await env.helper.database;
    env.repository = env.newRepository(env.helper, idPrefix: 'a');
    env.settings = env._settingsFor(env.helper);
    env.engine = env.newEngine(
      repository: env.repository,
      settings: env.settings,
      monitor: env.monitor,
    );
    return env;
  }

  final bool fileDatabase;
  late Directory root;
  late Directory appDir;
  late Directory cameraDir;
  String? dbPath;
  late DateTime now;
  late int concurrency;
  late Duration claimTimeout;
  late Duration claimRenewInterval;
  late int maxAttempts;

  late DatabaseHelper helper;
  late Database db;
  late BatchRepositoryImpl repository;
  late SyncSettingsRepositoryImpl settings;
  late SyncEngine engine;

  final FakeConnectivityMonitor monitor = FakeConnectivityMonitor();
  final ScriptedUploadApi api = ScriptedUploadApi();
  final List<DatabaseHelper> _extraHelpers = [];
  final List<BatchRepositoryImpl> _extraRepositories = [];
  final List<SyncEngine> _extraEngines = [];
  int _fileCounter = 0;

  void advance(Duration d) => now = now.add(d);

  ImageFileStorage get storage =>
      ImageFileStorage(baseDirectory: () async => appDir);

  /// Another repository on its own connection to the same database file, like
  /// the background isolate would have. Requires [fileDatabase].
  BatchRepositoryImpl newRepository(
    DatabaseHelper databaseHelper, {
    required String idPrefix,
  }) {
    var counter = 0;
    final repo = BatchRepositoryImpl(
      databaseHelper: databaseHelper,
      batchDao: const BatchDao(),
      imageDao: const ImageDao(),
      storage: storage,
      generateId: () => '$idPrefix-${++counter}',
      clock: () => now,
    );
    _extraRepositories.add(repo);
    return repo;
  }

  SyncSettingsRepositoryImpl _settingsFor(DatabaseHelper databaseHelper) {
    return SyncSettingsRepositoryImpl(
      SettingsStore(databaseHelper, const SettingsDao()),
    );
  }

  SyncEngine newEngine({
    required BatchRepositoryImpl repository,
    required SyncSettingsRepositoryImpl settings,
    required FakeConnectivityMonitor monitor,
    ScriptedUploadApi? uploadApi,
  }) {
    final engine = SyncEngine(
      repository: repository,
      uploadApi: uploadApi ?? api,
      recordResult: RecordUploadResult(
        repository,
        backoff: ExponentialBackoff(
          baseDelay: const Duration(seconds: 30),
          multiplier: 2,
          maxDelay: const Duration(minutes: 10),
          jitterRatio: 0,
          random: Random(1),
        ),
        now: () => now,
        maxAttempts: maxAttempts,
      ),
      recoverInterrupted: RecoverInterruptedUploads(repository),
      connectivity: monitor,
      settings: settings,
      now: () => now,
      concurrency: concurrency,
      claimTimeout: claimTimeout,
      claimRenewInterval: claimRenewInterval,
    );
    _extraEngines.add(engine);
    return engine;
  }

  /// A second engine with its own connection to the same database file.
  Future<({SyncEngine engine, BatchRepositoryImpl repository})>
  newSecondEngine({
    required FakeConnectivityMonitor monitor,
    ScriptedUploadApi? uploadApi,
  }) async {
    assert(fileDatabase, 'a second connection needs a file database');
    final second = createTestDatabaseHelper(path: dbPath);
    _extraHelpers.add(second);
    await second.database;
    final repo = newRepository(second, idPrefix: 'b');
    final engine = newEngine(
      repository: repo,
      settings: _settingsFor(second),
      monitor: monitor,
      uploadApi: uploadApi,
    );
    return (engine: engine, repository: repo);
  }

  File cameraFile({int bytes = 100}) {
    return File(p.join(cameraDir.path, 'shot_${++_fileCounter}.jpg'))
      ..writeAsBytesSync(List.filled(bytes, 1));
  }

  /// Captures [count] images (one second apart) and submits their batch.
  Future<List<CapturedImage>> submitImages(
    int count, {
    BatchRepositoryImpl? into,
    int bytes = 100,
  }) async {
    final repo = into ?? repository;
    final batch = await repo.getOrCreateOpenBatch();
    final images = <CapturedImage>[];
    for (var i = 0; i < count; i++) {
      images.add(await repo.addImage(batch.id, cameraFile(bytes: bytes).path));
      advance(const Duration(seconds: 1));
    }
    await repo.submitBatch(batch.id);
    return images;
  }

  Future<CapturedImage> image(String id) async =>
      (await repository.getImage(id))!;

  Future<void> dispose() async {
    for (final engine in _extraEngines) {
      await engine.dispose();
    }
    for (final repo in _extraRepositories) {
      await repo.dispose();
    }
    for (final extra in _extraHelpers) {
      await (await extra.database).close();
    }
    await db.close();
    root.deleteSync(recursive: true);
  }
}
