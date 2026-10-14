import 'package:snapsync/data/local/models/captured_image_model.dart';
import 'package:snapsync/domain/entities/captured_image.dart';

extension CapturedImageModelMapper on CapturedImageModel {
  CapturedImage toEntity() {
    // TODO: map fields, parse status by name.
    throw UnimplementedError('TODO: CapturedImageModel.toEntity');
  }
}

extension CapturedImageMapper on CapturedImage {
  CapturedImageModel toModel() {
    // TODO: map fields, store status by name.
    throw UnimplementedError('TODO: CapturedImage.toModel');
  }
}
