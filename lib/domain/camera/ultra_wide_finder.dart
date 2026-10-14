import 'package:snapsync/domain/camera/camera_lens.dart';

/// Decides which back camera, if any, to treat as the ultra-wide.
///
/// Limits, stated plainly:
/// - Android's camera plugin gives no lens type or focal length, so for most
///   Android devices every back camera is [LensKind.unknown].
/// - Many phones expose only one logical back camera that already zooms below
///   1.0; those never reach this code, because the minimum zoom is used first.
/// - When a phone lists several physical back cameras, the second one is
///   usually the ultra-wide, but it can be a telephoto or macro lens. With
///   exactly two back cameras and nothing else known, the non-main one is
///   treated as "plausibly" ultra-wide. With three or more unknown cameras the
///   choice is a guess, so none is picked.
/// - A wrong guess shows a "0.5x" button that zooms in instead of out, so the
///   manual device test must check it. `AppConstants.cameraAllowUnverified
///   UltraWideSwitch` turns the guess off.
abstract final class UltraWideFinder {
  /// The camera used as the main (1x) back camera: one reported as wide, else
  /// the first in the platform's order (on Android, the lowest camera id).
  static CameraLens? mainBack(List<CameraLens> backCameras) {
    if (backCameras.isEmpty) return null;
    for (final lens in backCameras) {
      if (lens.kind == LensKind.wide) return lens;
    }
    return backCameras.first;
  }

  static CameraLens? find(
    List<CameraLens> backCameras, {
    required bool allowUnverified,
  }) {
    final main = mainBack(backCameras);
    if (main == null) return null;

    // A lens the platform itself calls ultra-wide is certain.
    for (final lens in backCameras) {
      if (lens.kind == LensKind.ultraWide && lens.id != main.id) return lens;
    }
    if (!allowUnverified) return null;

    final others = backCameras
        .where((l) => l.id != main.id && l.kind != LensKind.telephoto)
        .toList();
    final allUnknown = backCameras.every((l) => l.kind == LensKind.unknown);
    return allUnknown && others.length == 1 ? others.single : null;
  }
}
