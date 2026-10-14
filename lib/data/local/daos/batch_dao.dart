import 'package:snapsync/data/local/database_helper.dart';
import 'package:snapsync/data/local/models/batch_model.dart';

class BatchDao {
  const BatchDao(this.databaseHelper);

  final DatabaseHelper databaseHelper;

  Future<void> insert(BatchModel batch) {
    // TODO: insert into the batches table.
    throw UnimplementedError('TODO: BatchDao.insert');
  }

  Future<List<BatchModel>> getAll() {
    // TODO: query the batches table, newest first.
    throw UnimplementedError('TODO: BatchDao.getAll');
  }
}
