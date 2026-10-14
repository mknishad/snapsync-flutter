import 'package:snapsync/core/constants/app_constants.dart';
import 'package:snapsync/core/error/failure.dart';
import 'package:snapsync/data/local/database_schema.dart';
import 'package:sqflite/sqflite.dart';

/// Opens the shared SQLite database.
///
/// Two isolates use this file: the UI isolate and the Workmanager background
/// isolate. They do not share memory or get_it state, so this class resolves
/// its own path and each isolate builds its own instance. Following the
/// sqflite guidance for multi-isolate access:
/// - `singleInstance: false`, so each isolate gets its own connection and
///   SQLite's file locking arbitrates between them (a shared in-memory
///   transaction lock would not work across isolates);
/// - the database is never closed;
/// - WAL lets one isolate read while the other writes, and `busy_timeout`
///   makes a blocked writer wait instead of failing at once;
/// - every multi-row change runs in `transaction`, which sqflite starts as
///   `BEGIN IMMEDIATE`, so a read-check-write sequence is serialised across
///   isolates.
class DatabaseHelper {
  DatabaseHelper({
    this._factory,
    this._path,
    this.singleInstance = false,
  });

  final DatabaseFactory? _factory;
  final String? _path;
  final bool singleInstance;

  Future<Database>? _database;

  Future<Database> get database => _database ??= _open();

  Future<Database> _open() async {
    try {
      final factory = _factory ?? databaseFactory;
      final path = _path ?? await _defaultPath(factory);
      return await factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: AppConstants.databaseVersion,
          singleInstance: singleInstance,
          onConfigure: _onConfigure,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        ),
      );
    } on DatabaseException catch (e) {
      _database = null;
      throw DatabaseFailure('Could not open the database: $e');
    }
  }

  Future<String> _defaultPath(DatabaseFactory factory) async {
    final directory = await factory.getDatabasesPath();
    return '$directory/${AppConstants.databaseName}';
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
    // Returns a row, so it must be a query on some platforms.
    await db.rawQuery('PRAGMA busy_timeout = 5000');
    await db.setJournalMode('WAL');
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    DatabaseSchema.createStatements.forEach(batch.execute);
    await batch.commit(noResult: true);
  }

  /// One `if (oldVersion < N)` block per schema version, run in order, so any
  /// older database reaches the current schema. Bump
  /// `AppConstants.databaseVersion` when adding one.
  ///
  /// - v2: the `settings` key-value table (pause flag, mock mode).
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    final batch = db.batch();
    if (oldVersion < 2) {
      DatabaseSchema.upgradeToV2.forEach(batch.execute);
    }
    await batch.commit(noResult: true);
  }
}
