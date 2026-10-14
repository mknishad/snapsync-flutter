import 'package:snapsync/core/error/failure.dart';
import 'package:snapsync/data/local/daos/settings_dao.dart';
import 'package:snapsync/data/local/database_helper.dart';
import 'package:sqflite/sqflite.dart';

/// Small persistent key-value store in the shared database, so a setting
/// written by one isolate is read by the other.
class SettingsStore {
  const SettingsStore(this.databaseHelper, this.dao);

  final DatabaseHelper databaseHelper;
  final SettingsDao dao;

  Future<String?> read(String key) async {
    try {
      return await dao.get(await databaseHelper.database, key);
    } on DatabaseException catch (e) {
      throw DatabaseFailure('Could not read setting "$key": $e');
    }
  }

  Future<void> write(String key, String value) async {
    try {
      await dao.put(await databaseHelper.database, key, value);
    } on DatabaseException catch (e) {
      throw DatabaseFailure('Could not write setting "$key": $e');
    }
  }
}
