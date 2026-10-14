import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:snapsync/domain/camera/latest_value_coalescer.dart';
import 'package:snapsync/domain/camera/zoom_controller.dart';
import 'package:snapsync/domain/camera/zoom_lens_mapping.dart';

Future<void> settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('LatestValueCoalescer', () {
    test('applies a single value', () async {
      final applied = <int>[];
      final coalescer = LatestValueCoalescer<int>((v) async => applied.add(v));

      coalescer.submit(1);
      await coalescer.whenIdle();

      expect(applied, [1]);
      expect(coalescer.isIdle, isTrue);
    });

    test('never queues a backlog: only the latest value waits', () async {
      final applied = <int>[];
      final gate = Completer<void>();
      var first = true;
      final coalescer = LatestValueCoalescer<int>((v) async {
        applied.add(v);
        if (first) {
          first = false;
          await gate.future; // the slow first call
        }
      });

      coalescer.submit(1);
      for (var i = 2; i <= 100; i++) {
        coalescer.submit(i);
      }
      gate.complete();
      await coalescer.whenIdle();

      expect(applied, [
        1,
        100,
      ], reason: 'one in flight, one latest, nothing else');
    });

    test('submit never blocks, even while a call is stuck', () async {
      final gate = Completer<void>();
      final coalescer = LatestValueCoalescer<int>((v) => gate.future);

      final watch = Stopwatch()..start();
      for (var i = 0; i < 1000; i++) {
        coalescer.submit(i);
      }
      watch.stop();

      expect(watch.elapsedMilliseconds, lessThan(100));
      gate.complete();
      await coalescer.whenIdle();
    });

    test('an error is reported and does not stop later values', () async {
      final errors = <Object>[];
      final applied = <int>[];
      final coalescer = LatestValueCoalescer<int>((v) async {
        if (v == 1) throw StateError('boom');
        applied.add(v);
      }, onError: (e, _) => errors.add(e));

      coalescer.submit(1);
      await coalescer.whenIdle();
      coalescer.submit(2);
      await coalescer.whenIdle();

      expect(errors, hasLength(1));
      expect(applied, [2]);
    });

    test('onIdle fires when the queue empties', () async {
      var idle = 0;
      final coalescer = LatestValueCoalescer<int>(
        (v) async {},
        onIdle: () => idle++,
      );

      coalescer.submit(1);
      coalescer.submit(2);
      await coalescer.whenIdle();

      expect(idle, 1);
    });

    test('after dispose, nothing more is applied', () async {
      final applied = <int>[];
      final coalescer = LatestValueCoalescer<int>((v) async => applied.add(v));

      coalescer.dispose();
      coalescer.submit(1);
      await settle();

      expect(applied, isEmpty);
    });
  });

  group('ZoomController', () {
    late List<double> applied;
    late List<double> settled;
    late List<Object> errors;
    late ZoomController zoom;
    Future<void> Function(double)? hook;

    setUp(() {
      applied = [];
      settled = [];
      errors = [];
      hook = null;
      zoom = ZoomController(
        apply: (value) async {
          applied.add(value);
          await hook?.call(value);
        },
        onSettled: settled.add,
        onError: errors.add,
      );
      zoom.attach(const ZoomLensMapping.standard(min: 1, max: 8));
    });

    test('attach sets the starting zoom and applies it', () async {
      await zoom.whenSettled();

      expect(zoom.zoom, 1);
      expect(applied, [1]);
      expect(zoom.displayMin, 1);
      expect(zoom.displayMax, 8);
    });

    test('attach clamps the starting zoom to what the camera can do', () async {
      zoom.attach(
        const ZoomLensMapping.standard(min: 1, max: 4),
        initialZoom: 9,
      );
      await zoom.whenSettled();

      expect(zoom.zoom, 4);
    });

    test('setZoom updates at once and clamps', () async {
      expect(zoom.setZoom(3), 3);
      expect(zoom.zoom, 3);
      expect(zoom.setZoom(100), 8);
      expect(zoom.setZoom(0.1), 1);
    });

    test('rapid updates while a call is slow collapse to the latest', () async {
      final gate = Completer<void>();
      await zoom.whenSettled();
      applied.clear();
      hook = (_) => gate.future;

      for (var i = 1; i <= 50; i++) {
        zoom.setZoom(1 + i / 10);
      }
      gate.complete();
      await zoom.whenSettled();

      expect(applied.length, lessThanOrEqualTo(2));
      expect(applied.last, closeTo(6, 1e-9));
    });

    test('pinch multiplies the zoom at the start of the gesture', () async {
      zoom.setZoom(2);
      zoom.pinchStart();

      expect(zoom.pinchUpdate(1.5), closeTo(3, 1e-9));
      expect(
        zoom.pinchUpdate(2),
        closeTo(4, 1e-9),
        reason: 'scale is relative to the start, not to the last update',
      );
      expect(zoom.pinchUpdate(100), 8);
      zoom.pinchEnd();

      expect(zoom.pinchUpdate(2), 8, reason: 'ignored after the pinch ended');
    });

    test('the slider and presets move the same zoom as pinch', () async {
      zoom.setZoomFromSlider(0.5);
      expect(zoom.zoom, closeTo(2.828, 1e-3));
      expect(zoom.sliderValue, closeTo(0.5, 1e-9));

      zoom.setZoom(4);
      expect(zoom.sliderValue, closeTo(2 / 3, 1e-9));
    });

    test('onSettled reports the real zoom after a failure', () async {
      await zoom.whenSettled();
      settled.clear();
      applied.clear();
      hook = (_) async => throw StateError('camera busy');

      zoom.setZoom(5);
      await zoom.whenSettled();

      expect(errors, hasLength(1));
      expect(settled.last, 1, reason: 'the camera is still at 1x');
      expect(zoom.appliedZoom, 1);
    });

    test('onSettled reports the new zoom after success', () async {
      await zoom.whenSettled();
      settled.clear();

      zoom.setZoom(2.5);
      await zoom.whenSettled();

      expect(settled.last, closeTo(2.5, 1e-9));
    });

    test('an ultra-wide mapping starts at 0.5x and stops at 1x', () async {
      zoom.attach(
        const ZoomLensMapping.ultraWide(min: 1, max: 4),
        initialZoom: 0.5,
      );
      await zoom.whenSettled();

      expect(zoom.zoom, 0.5);
      expect(applied.last, 1, reason: 'the plugin gets its own units');
      expect(zoom.setZoom(3), 1);
      expect(applied.last, closeTo(2, 1e-9));
    });

    test(
      'a call that finishes after detach does not become the applied zoom',
      () async {
        await zoom.whenSettled();
        settled.clear();
        final gate = Completer<void>();
        hook = (_) => gate.future;

        zoom.setZoom(4); // in flight
        zoom.detach(); // the camera is released meanwhile
        gate.complete();
        await zoom.whenSettled();

        expect(zoom.appliedZoom, 1, reason: 'the old camera is gone');
        expect(settled, isEmpty, reason: 'nothing to report with no camera');
      },
    );

    test('a call that finishes after a new attach is ignored', () async {
      await zoom.whenSettled();
      final gate = Completer<void>();
      hook = (_) => gate.future;
      zoom.setZoom(4);

      zoom.attach(
        const ZoomLensMapping.standard(min: 1, max: 8),
        initialZoom: 2,
      );
      hook = null;
      gate.complete();
      await zoom.whenSettled();

      expect(zoom.appliedZoom, closeTo(2, 1e-9));
    });

    test('detach ignores further changes', () async {
      zoom.detach();

      expect(zoom.setZoom(5), 1);
      expect(zoom.isAttached, isFalse);
    });

    test('dispose stops applying', () async {
      await zoom.whenSettled();
      applied.clear();
      zoom.dispose();

      zoom.setZoom(3);
      await settle();

      expect(applied, isEmpty);
    });
  });
}
