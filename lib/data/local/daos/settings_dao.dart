import 'package:snapsync/data/local/database_schema.dart';
import 'package:sqflite/sqflite.dart';

class SettingsDao {
  const SettingsDao();

  static const _table = DatabaseSchema.settingsTable;

  Future<String?> get(DatabaseExecutor db, String key) async {
    final rows = await db.query(
      _table,
      columns: [DatabaseSchema.colValue],
      where: '${DatabaseSchema.colKey} = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first[DatabaseSchema.colValue] as String?;
  }

  Future<void> put(DatabaseExecutor db, String key, String value) async {
    await db.insert(
      _table,
      {DatabaseSchema.colKey: key, DatabaseSchema.colValue: value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
