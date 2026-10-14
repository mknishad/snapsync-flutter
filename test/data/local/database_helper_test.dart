import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:snapsync/data/local/database_schema.dart';
import 'package:sqflite/sqflite.dart';

import '../../support/test_support.dart';

void main() {
  group('schema', () {
    test('creates both tables and the status/retry/batch indexes', () async {
      final db = await createTestDatabaseHelper().database;
      addTearDown(db.close);

      final names = (await db.query(
        'sqlite_master',
        columns: ['name'],
        where: "type IN ('table', 'index')",
      )).map((r) => r['name']! as String).toSet();

      expect(
        names,
        containsAll([
          DatabaseSchema.batchesTable,
          DatabaseSchema.imagesTable,
          'idx_images_batch_id',
          'idx_images_status',
          'idx_images_next_retry_at',
        ]),
      );
    });

    test('foreign keys are enforced', () async {
      final db = await createTestDatabaseHelper().database;
      addTearDown(db.close);

      expect((await db.rawQuery('PRAGMA foreign_keys')).first.values.first, 1);
      await expectLater(
        db.insert(DatabaseSchema.imagesTable, {
          'id': 'orphan',
          'batch_id': 'missing',
          'file_path': '/f',
          'file_size_bytes': 1,
          'captured_at': 0,
          'status': 'queued',
          'updated_at': 0,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('deleting a batch cascades to its images', () async {
      final db = await createTestDatabaseHelper().database;
      addTearDown(db.close);

      await db.insert(DatabaseSchema.batchesTable, {
        'id': 'b',
        'created_at': 0,
      });
      await db.insert(DatabaseSchema.imagesTable, {
        'id': 'i',
        'batch_id': 'b',
        'file_path': '/f',
        'file_size_bytes': 1,
        'captured_at': 0,
        'status': 'queued',
        'updated_at': 0,
      });

      await db.delete(DatabaseSchema.batchesTable, where: "id = 'b'");

      expect(await db.query(DatabaseSchema.imagesTable), isEmpty);
    });
  });

  group('two connections to one file (stand-in for two isolates)', () {
    late Directory directory;
    late String path;

    setUp(() {
      directory = createTempDir('snapsync_db_');
      path = p.join(directory.path, 'shared.db');
    });

    tearDown(() => directory.deleteSync(recursive: true));

    test('each sees the other\'s committed writes', () async {
      final a = await createTestDatabaseHelper(path: path).database;
      final b = await createTestDatabaseHelper(path: path).database;
      addTearDown(a.close);
      addTearDown(b.close);

      await a.insert(DatabaseSchema.batchesTable, {
        'id': 'from-a',
        'created_at': 1,
      });
      await b.insert(DatabaseSchema.batchesTable, {
        'id': 'from-b',
        'created_at': 2,
      });

      final seenByA = (await a.query(DatabaseSchema.batchesTable)).length;
      final seenByB = (await b.query(DatabaseSchema.batchesTable)).length;
      expect(seenByA, 2);
      expect(seenByB, 2);
    });

    test('the file uses write-ahead logging', () async {
      final db = await createTestDatabaseHelper(path: path).database;
      addTearDown(db.close);

      final mode = (await db.rawQuery('PRAGMA journal_mode'))
          .first
          .values
          .first;
      expect(mode, 'wal');
    });
  });
}
