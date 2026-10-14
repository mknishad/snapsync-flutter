import 'package:camera/camera.dart';
import 'package:snapsync/domain/camera/camera_lens.dart';

extension CameraDescriptionMapper on CameraDescription {
  /// Null for cameras the app does not use.
  CameraLens? toLens() {
    final direction = switch (lensDirection) {
      CameraLensDirection.back => LensDirection.back,
      CameraLensDirection.front => LensDirection.front,
      CameraLensDirection.external => LensDirection.external,
    };
    final kind = switch (lensType) {
      CameraLensType.wide => LensKind.wide,
      CameraLensType.ultraWide => LensKind.ultraWide,
      CameraLensType.telephoto => LensKind.telephoto,
      CameraLensType.unknown => LensKind.unknown,
    };
    return CameraLens(
      id: name,
      direction: direction,
      sensorOrientation: sensorOrientation,
      kind: kind,
    );
  }
}
