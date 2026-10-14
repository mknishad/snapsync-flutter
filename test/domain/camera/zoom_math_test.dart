import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:snapsync/domain/camera/zoom_lens_mapping.dart';
import 'package:snapsync/domain/camera/zoom_math.dart';
import 'package:snapsync/domain/camera/zoom_preset.dart';

const presets = [
  ZoomPreset(label: '0.5x', targetZoom: 0.5),
  ZoomPreset(label: '1x', targetZoom: 1),
  ZoomPreset(label: '2x', targetZoom: 2),
];

void main() {
  group('clamp', () {
    test('keeps values inside the range', () {
      expect(ZoomMath.clamp(3, 1, 8), 3);
      expect(ZoomMath.clamp(0.2, 0.5, 8), 0.5);
      expect(ZoomMath.clamp(20, 1, 8), 8);
    });

    test('NaN falls back to the minimum', () {
      expect(ZoomMath.clamp(double.nan, 1, 8), 1);
    });
  });

  group('pinch', () {
    test('multiplies the zoom at gesture start by the scale', () {
      expect(ZoomMath.pinch(baseZoom: 2, scale: 1.5, min: 1, max: 8), 3);
      expect(ZoomMath.pinch(baseZoom: 4, scale: 0.5, min: 1, max: 8), 2);
    });

    test('is clamped at both ends', () {
      expect(ZoomMath.pinch(baseZoom: 4, scale: 10, min: 1, max: 8), 8);
      expect(ZoomMath.pinch(baseZoom: 1.2, scale: 0.1, min: 1, max: 8), 1);
    });

    test('a scale of 1 changes nothing', () {
      expect(ZoomMath.pinch(baseZoom: 2.5, scale: 1, min: 1, max: 8), 2.5);
    });

    test('a non-positive scale leaves the zoom where it was', () {
      expect(ZoomMath.pinch(baseZoom: 2, scale: 0, min: 1, max: 8), 2);
      expect(ZoomMath.pinch(baseZoom: 2, scale: -1, min: 1, max: 8), 2);
    });
  });

  group('slider mapping', () {
    test('ends of the slider are the ends of the range', () {
      expect(ZoomMath.sliderToZoom(0, min: 0.5, max: 8), closeTo(0.5, 1e-9));
      expect(ZoomMath.sliderToZoom(1, min: 0.5, max: 8), closeTo(8, 1e-9));
    });

    test('doublings are evenly spaced: 0.5x to 1x equals 1x to 2x', () {
      double position(double zoom) =>
          ZoomMath.zoomToSlider(zoom, min: 0.5, max: 8);

      final first = position(1) - position(0.5);
      final second = position(2) - position(1);
      final third = position(4) - position(2);

      expect(first, closeTo(second, 1e-9));
      expect(second, closeTo(third, 1e-9));
      expect(
        first,
        closeTo(0.25, 1e-9),
        reason: 'four doublings across 0.5 to 8',
      );
    });

    test('round trips', () {
      for (final zoom in [0.5, 0.6, 1.0, 1.7, 2.0, 3.3, 8.0]) {
        final t = ZoomMath.zoomToSlider(zoom, min: 0.5, max: 8);
        expect(ZoomMath.sliderToZoom(t, min: 0.5, max: 8), closeTo(zoom, 1e-9));
      }
      for (final t in [0.0, 0.1, 0.25, 0.5, 0.9, 1.0]) {
        final zoom = ZoomMath.sliderToZoom(t, min: 1, max: 8);
        expect(ZoomMath.zoomToSlider(zoom, min: 1, max: 8), closeTo(t, 1e-9));
      }
    });

    test('is monotonic', () {
      var last = -1.0;
      for (var i = 0; i <= 100; i++) {
        final zoom = ZoomMath.sliderToZoom(i / 100, min: 1, max: 8);
        expect(zoom, greaterThanOrEqualTo(last));
        last = zoom;
      }
    });

    test('out-of-range slider values and zooms are clamped', () {
      expect(ZoomMath.sliderToZoom(-1, min: 1, max: 8), 1);
      expect(ZoomMath.sliderToZoom(2, min: 1, max: 8), closeTo(8, 1e-9));
      expect(ZoomMath.zoomToSlider(100, min: 1, max: 8), 1);
      expect(ZoomMath.zoomToSlider(0.1, min: 1, max: 8), 0);
      expect(ZoomMath.sliderToZoom(double.nan, min: 1, max: 8), 1);
    });

    test('a camera with no zoom range gives a stable answer', () {
      expect(ZoomMath.sliderToZoom(0.7, min: 1, max: 1), 1);
      expect(ZoomMath.zoomToSlider(1, min: 1, max: 1), 0);
      expect(ZoomMath.sliderToZoom(0.5, min: 0, max: 8), 0);
    });

    test('a straight line would not be even (why log is used)', () {
      const linearHalf = 0.5 + (8 - 0.5) * 0.25;
      expect(
        linearHalf,
        greaterThan(2),
        reason: 'a linear slider would be at ~2.4x a quarter of the way',
      );
      expect(ZoomMath.sliderToZoom(0.25, min: 0.5, max: 8), closeTo(1, 1e-9));
    });
  });

  group('snapToPreset', () {
    ZoomPreset? snap(double zoom, {double tolerance = 0.05}) =>
        ZoomMath.snapToPreset(zoom, presets, tolerance: tolerance);

    test('exact and near values snap', () {
      expect(snap(1)?.label, '1x');
      expect(snap(1.03)?.label, '1x');
      expect(snap(0.97)?.label, '1x');
      expect(snap(2.08)?.label, '2x');
      expect(snap(0.5)?.label, '0.5x');
    });

    test('values between presets snap to none', () {
      expect(snap(1.5), isNull);
      expect(snap(0.75), isNull);
      expect(snap(3), isNull);
    });

    test('the edge of the tolerance counts, just beyond does not', () {
      expect(snap(1.05)?.label, '1x');
      expect(snap(1.06), isNull);
    });

    test('with a wide tolerance the nearer preset wins', () {
      expect(snap(1.4, tolerance: 0.5)?.label, '1x');
      expect(snap(1.6, tolerance: 0.5)?.label, '2x');
    });

    test('no presets, no snap', () {
      expect(ZoomMath.snapToPreset(1, const [], tolerance: 0.05), isNull);
    });
  });

  group('ZoomLensMapping', () {
    test('a standard camera maps one to one', () {
      const mapping = ZoomLensMapping.standard(min: 1, max: 8);

      expect(mapping.displayMin, 1);
      expect(mapping.displayMax, 8);
      expect(mapping.toController(3), 3);
      expect(mapping.toDisplay(3), 3);
    });

    test('values are clamped to the camera range before reaching it', () {
      const mapping = ZoomLensMapping.standard(min: 1, max: 8);

      expect(mapping.toController(0.2), 1);
      expect(mapping.toController(99), 8);
    });

    test(
      'a logical camera that zooms out shows its minimum as display min',
      () {
        const mapping = ZoomLensMapping.standard(min: 0.5, max: 10);

        expect(mapping.displayMin, 0.5);
        expect(mapping.toController(0.5), 0.5);
      },
    );

    test(
      'a separate ultra-wide shows 0.5x at its zoom 1.0 and stops at 1x',
      () {
        const mapping = ZoomLensMapping.ultraWide(min: 1, max: 4);

        expect(mapping.displayMin, 0.5);
        expect(
          mapping.displayMax,
          1,
          reason: 'beyond 1x the main camera takes over',
        );
        expect(mapping.toController(0.5), 1);
        expect(mapping.toController(1), 2);
        expect(mapping.toDisplay(2), 1);
        expect(math.max(mapping.displayMax, 0), 1);
      },
    );
  });
}
