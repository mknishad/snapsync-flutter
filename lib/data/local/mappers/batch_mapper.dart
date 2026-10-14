import 'package:snapsync/data/local/models/batch_model.dart';
import 'package:snapsync/domain/entities/capture_batch.dart';
import 'package:snapsync/domain/entities/captured_image.dart';

extension BatchModelMapper on BatchModel {
  /// Images live in their own table, so the caller supplies them.
  CaptureBatch toEntity(List<CapturedImage> images) {
    // TODO: map fields.
    throw UnimplementedError('TODO: BatchModel.toEntity');
  }
}

extension CaptureBatchMapper on CaptureBatch {
  BatchModel toModel() {
    // TODO: map fields.
    throw UnimplementedError('TODO: CaptureBatch.toModel');
  }
}
