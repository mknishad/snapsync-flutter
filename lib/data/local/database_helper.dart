import 'package:sqflite/sqflite.dart';

/// Owns the sqflite database. Both the UI isolate and the background isolate
/// open the same file, so keep schema changes in migrations.
class DatabaseHelper {
  Future<Database> get database {
    // TODO: open lazily with AppConstants.databaseName/databaseVersion,
    // create tables in onCreate, enable foreign keys.
    throw UnimplementedError('TODO: open the database');
  }
}
