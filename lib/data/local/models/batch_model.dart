import 'package:snapsync/core/utils/typedefs.dart';

/// Database row shape for a batch (without its images).
class BatchModel {
  const BatchModel({required this.id, required this.createdAtMillis});

  factory BatchModel.fromMap(DbRow map) {
    // TODO: read columns from DatabaseSchema.
    throw UnimplementedError('TODO: BatchModel.fromMap');
  }

  final String id;
  final int createdAtMillis;

  DbRow toMap() {
    // TODO: write columns from DatabaseSchema.
    throw UnimplementedError('TODO: BatchModel.toMap');
  }
}
