import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:snapsync/domain/camera/preview_geometry.dart';

math.Point<double> p(double x, double y) => math.Point(x, y);

void expectPoint(math.Point<double>? actual, double x, double y) {
  expect(actual, isNotNull);
  expect(actual!.x, closeTo(x, 1e-9));
  expect(actual.y, closeTo(y, 1e-9));
}

math.Point<double>? tap(
  double x,
  double y, {
  required double width,
  required double height,
  required double ratio,
  PreviewFit fit = PreviewFit.contain,
}) {
  return PreviewGeometry.toNormalizedPoint(
    local: p(x, y),
    containerWidth: width,
    containerHeight: height,
    aspectRatio: ratio,
    fit: fit,
  );
}

void main() {
  group('previewRect', () {
    test('an exact fit fills the container', () {
      final rect = PreviewGeometry.previewRect(
        containerWidth: 360,
        containerHeight: 640,
        aspectRatio: 9 / 16,
      );

      expect(rect.left, closeTo(0, 1e-9));
      expect(rect.top, closeTo(0, 1e-9));
      expect(rect.width, closeTo(360, 1e-9));
      expect(rect.height, closeTo(640, 1e-9));
    });

    test('a container taller than the frame is letterboxed top and bottom', () {
      final rect = PreviewGeometry.previewRect(
        containerWidth: 400,
        containerHeight: 800,
        aspectRatio: 3 / 4,
      );

      expect(rect.width, closeTo(400, 1e-9));
      expect(rect.height, closeTo(533.3333333, 1e-6));
      expect(rect.top, closeTo(133.3333333, 1e-6));
      expect(rect.left, closeTo(0, 1e-9));
    });

    test('a container wider than the frame is pillarboxed left and right', () {
      final rect = PreviewGeometry.previewRect(
        containerWidth: 800,
        containerHeight: 400,
        aspectRatio: 9 / 16,
      );

      expect(rect.height, closeTo(400, 1e-9));
      expect(rect.width, closeTo(225, 1e-9));
      expect(rect.left, closeTo(287.5, 1e-9));
    });

    test('cover fills the container and crops the frame', () {
      final rect = PreviewGeometry.previewRect(
        containerWidth: 400,
        containerHeight: 800,
        aspectRatio: 3 / 4,
        fit: PreviewFit.cover,
      );

      expect(rect.height, closeTo(800, 1e-9));
      expect(rect.width, closeTo(600, 1e-9));
      expect(rect.left, closeTo(-100, 1e-9));
    });
  });

  group('toNormalizedPoint, exact fit', () {
    const w = 360.0;
    const h = 640.0;
    const r = 9 / 16;

    test('the four corners and the centre', () {
      expectPoint(tap(0, 0, width: w, height: h, ratio: r), 0, 0);
      expectPoint(tap(w, 0, width: w, height: h, ratio: r), 1, 0);
      expectPoint(tap(0, h, width: w, height: h, ratio: r), 0, 1);
      expectPoint(tap(w, h, width: w, height: h, ratio: r), 1, 1);
      expectPoint(tap(w / 2, h / 2, width: w, height: h, ratio: r), 0.5, 0.5);
    });

    test('an arbitrary point', () {
      expectPoint(tap(90, 160, width: w, height: h, ratio: r), 0.25, 0.25);
    });
  });

  group('toNormalizedPoint, letterboxed (bars top and bottom)', () {
    const w = 400.0;
    const h = 800.0;
    const r = 3 / 4; // preview occupies y from 133.33 to 666.67

    test('the centre is the centre of the frame', () {
      expectPoint(tap(200, 400, width: w, height: h, ratio: r), 0.5, 0.5);
    });

    test('the corners of the preview are the corners of the frame', () {
      expectPoint(tap(0, 133.3333333333, width: w, height: h, ratio: r), 0, 0);
      expectPoint(
        tap(400, 666.6666666667, width: w, height: h, ratio: r),
        1,
        1,
      );
    });

    test('a tap on a letterbox bar is ignored', () {
      expect(tap(200, 50, width: w, height: h, ratio: r), isNull);
      expect(tap(200, 750, width: w, height: h, ratio: r), isNull);
      expect(
        tap(200, 133, width: w, height: h, ratio: r),
        isNull,
        reason: 'just above the preview',
      );
    });

    test(
      'vertical position is measured from the preview, not the container',
      () {
        // A quarter of the way down the preview.
        expectPoint(
          tap(
            100,
            133.3333333 + 533.3333333 / 4,
            width: w,
            height: h,
            ratio: r,
          ),
          0.25,
          0.25,
        );
      },
    );
  });

  group('toNormalizedPoint, pillarboxed (bars left and right)', () {
    const w = 800.0;
    const h = 400.0;
    const r = 9 / 16; // preview occupies x from 287.5 to 512.5

    test('the centre', () {
      expectPoint(tap(400, 200, width: w, height: h, ratio: r), 0.5, 0.5);
    });

    test('left and right edges of the preview', () {
      expectPoint(tap(287.5, 0, width: w, height: h, ratio: r), 0, 0);
      expectPoint(tap(512.5, 400, width: w, height: h, ratio: r), 1, 1);
    });

    test('taps on the side bars are ignored', () {
      expect(tap(100, 200, width: w, height: h, ratio: r), isNull);
      expect(tap(700, 200, width: w, height: h, ratio: r), isNull);
    });
  });

  group('landscape frames (device rotated)', () {
    test('a wide frame in a wide container maps the same way', () {
      const w = 640.0;
      const h = 360.0;
      const r = 16 / 9;

      expectPoint(tap(320, 180, width: w, height: h, ratio: r), 0.5, 0.5);
      expectPoint(tap(640, 360, width: w, height: h, ratio: r), 1, 1);
    });

    test('the same container with a portrait frame is pillarboxed', () {
      const w = 640.0;
      const h = 360.0;
      const r = 9 / 16;

      expect(tap(10, 180, width: w, height: h, ratio: r), isNull);
      expectPoint(tap(320, 180, width: w, height: h, ratio: r), 0.5, 0.5);
    });

    test('rotating swaps the shape of the frame, which changes the bars', () {
      const w = 400.0;
      const h = 800.0;
      final portrait = tap(200, 100, width: w, height: h, ratio: 3 / 4);
      final landscape = tap(200, 100, width: w, height: h, ratio: 4 / 3);

      expect(portrait, isNull, reason: 'bar above a 3:4 frame');
      expect(landscape, isNull, reason: 'a 4:3 frame has even bigger bars');
      expectPoint(tap(200, 400, width: w, height: h, ratio: 4 / 3), 0.5, 0.5);
    });
  });

  group('toNormalizedPoint, cover (cropped)', () {
    test('every tap inside the container lands inside the frame', () {
      for (final point in [p(0, 0), p(400, 800), p(200, 400), p(399, 1)]) {
        final result = PreviewGeometry.toNormalizedPoint(
          local: point,
          containerWidth: 400,
          containerHeight: 800,
          aspectRatio: 3 / 4,
          fit: PreviewFit.cover,
        );
        expect(result, isNotNull, reason: '$point');
      }
    });

    test('the container edge maps inside the frame because of the crop', () {
      final result = PreviewGeometry.toNormalizedPoint(
        local: p(0, 400),
        containerWidth: 400,
        containerHeight: 800,
        aspectRatio: 3 / 4,
        fit: PreviewFit.cover,
      );

      expect(result!.x, closeTo(100 / 600, 1e-9));
      expect(result.y, closeTo(0.5, 1e-9));
    });
  });

  group('taps outside the container and bad input', () {
    test('outside the container is ignored', () {
      expect(tap(-1, 100, width: 360, height: 640, ratio: 9 / 16), isNull);
      expect(tap(100, -0.5, width: 360, height: 640, ratio: 9 / 16), isNull);
      expect(tap(361, 100, width: 360, height: 640, ratio: 9 / 16), isNull);
      expect(tap(100, 641, width: 360, height: 640, ratio: 9 / 16), isNull);
    });

    test('unusable sizes and ratios give null instead of NaN', () {
      expect(tap(1, 1, width: 0, height: 640, ratio: 0.5), isNull);
      expect(tap(1, 1, width: 360, height: 0, ratio: 0.5), isNull);
      expect(tap(1, 1, width: 360, height: 640, ratio: 0), isNull);
      expect(tap(1, 1, width: 360, height: 640, ratio: -1), isNull);
      expect(
        tap(1, 1, width: 360, height: 640, ratio: double.infinity),
        isNull,
      );
      expect(tap(double.nan, 1, width: 360, height: 640, ratio: 0.5), isNull);
    });

    test('results never leave 0..1 despite float error', () {
      final result = tap(
        400,
        666.6666666667,
        width: 400,
        height: 800,
        ratio: 0.75,
      );
      expect(result!.x, inInclusiveRange(0, 1));
      expect(result.y, inInclusiveRange(0, 1));
    });
  });
}
