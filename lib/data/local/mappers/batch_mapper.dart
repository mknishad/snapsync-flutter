import 'package:snapsync/data/local/models/batch_model.dart';
import 'package:snapsync/domain/entities/capture_batch.dart';
import 'package:snapsync/domain/entities/captured_image.dart';

DateTime _fromMillis(int millis) =>
    DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);

extension BatchModelMapper on BatchModel {
  /// Images live in their own table, so the caller supplies them.
  CaptureBatch toEntity(List<CapturedImage> images) {
    return CaptureBatch(
      id: id,
      createdAt: _fromMillis(createdAtMillis),
      submittedAt:
          submittedAtMillis == null ? null : _fromMillis(submittedAtMillis!),
      images: images,
    );
  }
}

extension CaptureBatchMapper on CaptureBatch {
  BatchModel toModel() {
    return BatchModel(
      id: id,
      createdAtMillis: createdAt.millisecondsSinceEpoch,
      submittedAtMillis: submittedAt?.millisecondsSinceEpoch,
    );
  }
}
