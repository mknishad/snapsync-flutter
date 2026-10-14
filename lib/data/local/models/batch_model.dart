import 'package:snapsync/core/utils/typedefs.dart';
import 'package:snapsync/data/local/database_schema.dart';

/// Database row shape for a batch (without its images).
class BatchModel {
  const BatchModel({
    required this.id,
    required this.createdAtMillis,
    this.submittedAtMillis,
  });

  factory BatchModel.fromMap(DbRow map) {
    return BatchModel(
      id: map[DatabaseSchema.colId]! as String,
      createdAtMillis: map[DatabaseSchema.colCreatedAt]! as int,
      submittedAtMillis: map[DatabaseSchema.colSubmittedAt] as int?,
    );
  }

  final String id;
  final int createdAtMillis;
  final int? submittedAtMillis;

  DbRow toMap() => {
        DatabaseSchema.colId: id,
        DatabaseSchema.colCreatedAt: createdAtMillis,
        DatabaseSchema.colSubmittedAt: submittedAtMillis,
      };
}
