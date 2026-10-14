import 'package:snapsync/domain/camera/latest_value_coalescer.dart';
import 'package:snapsync/domain/camera/zoom_lens_mapping.dart';
import 'package:snapsync/domain/camera/zoom_math.dart';

/// Holds the current zoom in display units and sends changes to the camera.
///
/// Pinch, slider and preset buttons all go through [setZoom], so they cannot
/// disagree. Changes reach the camera through a [LatestValueCoalescer].
class ZoomController {
  ZoomController({
    required Future<void> Function(double controllerZoom) apply,
    this.onSettled,
    this.onError,
  }) {
    _coalescer = LatestValueCoalescer<double>(
      (controllerZoom) async {
        final generation = _generation;
        final mapping = _mapping;
        await apply(controllerZoom);
        // A call that finishes after the camera was released or replaced says
        // nothing about the current camera, so it must not change [_applied].
        if (generation == _generation && mapping != null) {
          _applied = mapping.toDisplay(controllerZoom);
        }
      },
      onError: (error, stack) => onError?.call(error),
      onIdle: () {
        if (_mapping != null) onSettled?.call(_applied);
      },
    );
  }

  /// Called when all pending zoom changes have been applied (or failed), with
  /// the zoom the camera really has. Differs from [zoom] only after a failure.
  final void Function(double actualDisplayZoom)? onSettled;
  final void Function(Object error)? onError;

  late final LatestValueCoalescer<double> _coalescer;
  ZoomLensMapping? _mapping;

  /// Changes whenever the camera is attached or detached.
  int _generation = 0;
  double _zoom = 1;
  double _applied = 1;
  double? _pinchBase;

  bool get isAttached => _mapping != null;

  /// What the user sees; updates immediately.
  double get zoom => _zoom;

  /// What the camera last confirmed.
  double get appliedZoom => _applied;

  double get displayMin => _mapping?.displayMin ?? 1;
  double get displayMax => _mapping?.displayMax ?? 1;

  Future<void> whenSettled() => _coalescer.whenIdle();

  /// Binds to a newly opened camera and sets its starting zoom (display
  /// units), which is clamped to what the camera can do.
  void attach(ZoomLensMapping mapping, {double initialZoom = 1}) {
    _generation++;
    _mapping = mapping;
    _pinchBase = null;
    _applied = mapping.toDisplay(
      1.0.clamp(mapping.controllerMin, mapping.controllerMax),
    );
    _zoom = ZoomMath.clamp(initialZoom, mapping.displayMin, mapping.displayMax);
    _coalescer.submit(mapping.toController(_zoom));
  }

  /// Forgets the camera, for example when it is released.
  void detach() {
    _generation++;
    _mapping = null;
    _pinchBase = null;
  }

  /// Sets the zoom (display units), clamped. Returns the value used.
  double setZoom(double display) {
    final mapping = _mapping;
    if (mapping == null) return _zoom;
    _zoom = ZoomMath.clamp(display, mapping.displayMin, mapping.displayMax);
    _coalescer.submit(mapping.toController(_zoom));
    return _zoom;
  }

  void pinchStart() => _pinchBase = _zoom;

  double pinchUpdate(double scale) {
    final mapping = _mapping;
    final base = _pinchBase;
    if (mapping == null || base == null) return _zoom;
    return setZoom(
      ZoomMath.pinch(
        baseZoom: base,
        scale: scale,
        min: mapping.displayMin,
        max: mapping.displayMax,
      ),
    );
  }

  void pinchEnd() => _pinchBase = null;

  /// Slider position (0 to 1) to zoom, applied.
  double setZoomFromSlider(double t) {
    final mapping = _mapping;
    if (mapping == null) return _zoom;
    return setZoom(
      ZoomMath.sliderToZoom(
        t,
        min: mapping.displayMin,
        max: mapping.displayMax,
      ),
    );
  }

  double get sliderValue {
    final mapping = _mapping;
    if (mapping == null) return 0;
    return ZoomMath.zoomToSlider(
      _zoom,
      min: mapping.displayMin,
      max: mapping.displayMax,
    );
  }

  /// Makes [zoom] match what the camera confirmed (after a failed apply).
  void reconcile(double actual) => _zoom = actual;

  void dispose() {
    _coalescer.dispose();
    detach();
  }
}
