import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:snapsync/core/constants/app_constants.dart';
import 'package:snapsync/data/local/daos/settings_dao.dart';
import 'package:snapsync/data/local/database_schema.dart';
import 'package:snapsync/data/local/database_helper.dart';
import 'package:snapsync/data/local/settings_store.dart';
import 'package:snapsync/data/repositories/sync_settings_repository_impl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/test_support.dart';

void main() {
  late Directory directory;
  late String path;

  setUp(() {
    directory = createTempDir('snapsync_settings_');
    path = p.join(directory.path, 'shared.db');
  });

  tearDown(() => directory.deleteSync(recursive: true));

  SyncSettingsRepositoryImpl settingsOn(DatabaseHelper helper) {
    return SyncSettingsRepositoryImpl(SettingsStore(helper, const SettingsDao()));
  }

  group('paused flag', () {
    test('defaults to not paused', () async {
      expect(await settingsOn(createTestDatabaseHelper()).isPaused(), isFalse);
    });

    test('can be set and cleared', () async {
      final settings = settingsOn(createTestDatabaseHelper());

      await settings.setPaused(paused: true);
      expect(await settings.isPaused(), isTrue);

      await settings.setPaused(paused: false);
      expect(await settings.isPaused(), isFalse);
    });

    test('is shared between two connections (the two isolates)', () async {
      final ui = settingsOn(createTestDatabaseHelper(path: path));
      final background = settingsOn(createTestDatabaseHelper(path: path));

      await ui.setPaused(paused: true);

      expect(await background.isPaused(), isTrue);
    });
  });

  group('migration from version 1', () {
    test('adds the settings table and keeps existing data', () async {
      sqfliteFfiInit();
      // Build a version 1 database exactly as the first release did: the
      // current schema without the settings table.
      final v1 = await databaseFactoryFfiNoIsolate.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            for (final statement in DatabaseSchema.createStatements) {
              if (statement != DatabaseSchema.createSettingsTable) {
                await db.execute(statement);
              }
            }
          },
        ),
      );
      await v1.insert(DatabaseSchema.batchesTable, {'id': 'old-batch', 'created_at': 1});
      await v1.insert(DatabaseSchema.imagesTable, {
        'id': 'old-image',
        'batch_id': 'old-batch',
        'file_path': '/f',
        'file_size_bytes': 7,
        'captured_at': 2,
        'status': 'queued',
        'updated_at': 3,
      });
      expect(
        await v1.query('sqlite_master', where: "name = 'settings'"),
        isEmpty,
      );
      await v1.close();

      final helper = createTestDatabaseHelper(path: path);
      final db = await helper.database;
      addTearDown(db.close);

      expect(await db.getVersion(), AppConstants.databaseVersion);
      expect(
        await db.query('sqlite_master', where: "name = 'settings'"),
        hasLength(1),
      );
      expect(await db.query(DatabaseSchema.batchesTable), hasLength(1));
      final images = await db.query(DatabaseSchema.imagesTable);
      expect(images.single['id'], 'old-image');
      expect(images.single['file_size_bytes'], 7);

      // And the new table works.
      await settingsOn(helper).setPaused(paused: true);
      expect(await settingsOn(helper).isPaused(), isTrue);
    });

    test('a fresh install is created directly at the current version', () async {
      final db = await createTestDatabaseHelper().database;
      addTearDown(db.close);

      expect(await db.getVersion(), AppConstants.databaseVersion);
      expect(AppConstants.databaseVersion, 2);
      expect(
        await db.query('sqlite_master', where: "name = 'settings'"),
        hasLength(1),
      );
    });
  });
}
