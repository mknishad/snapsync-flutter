import 'package:snapsync/data/local/database_schema.dart';
import 'package:snapsync/data/local/models/batch_model.dart';
import 'package:sqflite/sqflite.dart';

/// SQL for the batches table. Every method takes the executor so the
/// repository can run several of them in one transaction.
class BatchDao {
  const BatchDao();

  static const _table = DatabaseSchema.batchesTable;

  Future<void> insert(DatabaseExecutor db, BatchModel batch) async {
    await db.insert(_table, batch.toMap());
  }

  Future<BatchModel?> getById(DatabaseExecutor db, String id) async {
    final rows = await db.query(
      _table,
      where: '${DatabaseSchema.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : BatchModel.fromMap(rows.first);
  }

  /// The most recently created batch that has not been submitted.
  Future<BatchModel?> getOpen(DatabaseExecutor db) async {
    final rows = await db.query(
      _table,
      where: '${DatabaseSchema.colSubmittedAt} IS NULL',
      orderBy: '${DatabaseSchema.colCreatedAt} DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : BatchModel.fromMap(rows.first);
  }

  /// Submitted batches, newest submission first.
  Future<List<BatchModel>> getSubmitted(DatabaseExecutor db) async {
    final rows = await db.query(
      _table,
      where: '${DatabaseSchema.colSubmittedAt} IS NOT NULL',
      orderBy: '${DatabaseSchema.colSubmittedAt} DESC',
    );
    return rows.map(BatchModel.fromMap).toList();
  }

  Future<void> markSubmitted(
    DatabaseExecutor db,
    String id,
    int submittedAtMillis,
  ) async {
    await db.update(
      _table,
      {DatabaseSchema.colSubmittedAt: submittedAtMillis},
      where: '${DatabaseSchema.colId} = ?',
      whereArgs: [id],
    );
  }

  /// Images are removed by the foreign key's ON DELETE CASCADE.
  Future<void> delete(DatabaseExecutor db, String id) async {
    await db.delete(
      _table,
      where: '${DatabaseSchema.colId} = ?',
      whereArgs: [id],
    );
  }
}
