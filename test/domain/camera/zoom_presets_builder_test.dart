import 'package:flutter_test/flutter_test.dart';
import 'package:snapsync/domain/camera/camera_lens.dart';
import 'package:snapsync/domain/camera/zoom_preset.dart';
import 'package:snapsync/domain/camera/zoom_presets_builder.dart';

const main0 = CameraLens(id: '0', direction: LensDirection.back);
const back2 = CameraLens(id: '2', direction: LensDirection.back);
const back3 = CameraLens(id: '3', direction: LensDirection.back);
const front = CameraLens(id: '1', direction: LensDirection.front);

ZoomPresets build({
  CameraLens? active,
  List<CameraLens> back = const [main0],
  double min = 1,
  double max = 8,
  bool allowUnverified = true,
}) {
  return ZoomPresetsBuilder.build(
    activeLens: active ?? main0,
    backCameras: back,
    minZoom: min,
    maxZoom: max,
    allowUnverifiedUltraWide: allowUnverified,
  );
}

List<String> labels(ZoomPresets presets) =>
    presets.presets.map((p) => p.label).toList();

void main() {
  group('single back camera', () {
    test('min 1.0 and max 8.0 gives 1x and 2x only', () {
      final presets = build();

      expect(labels(presets), ['1x', '2x']);
      expect(presets.hasUltraWide, isFalse);
      expect(presets.presets.every((p) => p.cameraToSwitchTo == null), isTrue);
    });

    test('min 0.6 adds 0.5x, reached by zooming out', () {
      final presets = build(min: 0.6);

      expect(labels(presets), ['0.5x', '1x', '2x']);
      expect(
        presets.presets.first.targetZoom,
        0.6,
        reason: 'the widest zoom the camera really reaches',
      );
      expect(presets.presets.first.cameraToSwitchTo, isNull);
    });

    test('min 0.5 reaches exactly 0.5x', () {
      expect(build(min: 0.5).presets.first.targetZoom, 0.5);
    });

    test('a minimum below 0.5 is not offered as wider than 0.5x', () {
      expect(build(min: 0.3).presets.first.targetZoom, 0.5);
    });

    test('a minimum barely below 1.0 does not earn a 0.5x button', () {
      expect(labels(build(min: 0.95)), ['1x', '2x']);
    });

    test('max below 2.0 omits 2x', () {
      expect(labels(build(max: 1.5)), ['1x']);
      expect(labels(build(min: 0.6, max: 1.9)), ['0.5x', '1x']);
    });

    test('max exactly 2.0 includes 2x', () {
      expect(labels(build(max: 2)), ['1x', '2x']);
    });

    test('1x is always present, even with no zoom at all', () {
      expect(labels(build(min: 1, max: 1)), ['1x']);
    });
  });

  group('two back cameras', () {
    test('adds 0.5x with a camera switch, and 1x and 2x switch back', () {
      final presets = build(back: [main0, back2]);

      expect(labels(presets), ['0.5x', '1x', '2x']);
      expect(presets.ultraWideLens, back2);
      expect(presets.mainLens, main0);
      final byLabel = {for (final p in presets.presets) p.label: p};
      expect(byLabel['0.5x']!.cameraToSwitchTo, back2);
      expect(byLabel['0.5x']!.targetZoom, 0.5);
      expect(byLabel['1x']!.cameraToSwitchTo, main0);
      expect(byLabel['2x']!.cameraToSwitchTo, main0);
    });

    test(
      'a camera that already zooms below 1.0 is used instead of switching',
      () {
        final presets = build(back: [main0, back2], min: 0.5);

        expect(presets.ultraWideLens, isNull);
        expect(
          presets.presets.every((p) => p.cameraToSwitchTo == null),
          isTrue,
        );
      },
    );

    test('with the guess turned off, no 0.5x is offered', () {
      expect(labels(build(back: [main0, back2], allowUnverified: false)), [
        '1x',
        '2x',
      ]);
    });

    test('a platform-reported ultra-wide is used even with the guess off', () {
      const ultra = CameraLens(
        id: '2',
        direction: LensDirection.back,
        kind: LensKind.ultraWide,
      );
      final presets = build(back: [main0, ultra], allowUnverified: false);

      expect(labels(presets), ['0.5x', '1x', '2x']);
      expect(presets.ultraWideLens, ultra);
    });

    test('a second camera reported as telephoto is never the ultra-wide', () {
      const tele = CameraLens(
        id: '2',
        direction: LensDirection.back,
        kind: LensKind.telephoto,
      );

      expect(labels(build(back: [main0, tele])), ['1x', '2x']);
    });
  });

  group('three or more back cameras', () {
    test('unknown kinds are ambiguous, so no 0.5x switch is guessed', () {
      expect(labels(build(back: [main0, back2, back3])), ['1x', '2x']);
    });

    test('a reported ultra-wide among them is found', () {
      const ultra = CameraLens(
        id: '3',
        direction: LensDirection.back,
        kind: LensKind.ultraWide,
      );
      final presets = build(back: [main0, back2, ultra]);

      expect(presets.ultraWideLens, ultra);
    });

    test('a reported wide camera is the main one even if not first', () {
      const wide = CameraLens(
        id: '5',
        direction: LensDirection.back,
        kind: LensKind.wide,
      );
      final presets = build(back: [back2, wide]);

      expect(presets.mainLens, wide);
    });
  });

  group('front camera', () {
    test('offers 1x and 2x but never 0.5x', () {
      final presets = build(active: front, back: [main0, back2], max: 4);

      expect(labels(presets), ['1x', '2x']);
      expect(presets.ultraWideLens, isNull);
      expect(presets.mainLens, front);
    });

    test('a front camera that zooms out is not offered 0.5x either', () {
      expect(labels(build(active: front, min: 0.5)), ['1x', '2x']);
    });
  });

  test('presets are ordered from widest to narrowest', () {
    final presets = build(back: [main0, back2]);
    final targets = presets.presets
        .map((ZoomPreset p) => p.targetZoom)
        .toList();

    expect(targets, [...targets]..sort());
  });
}
