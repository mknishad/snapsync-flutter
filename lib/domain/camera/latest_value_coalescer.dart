import 'dart:async';

/// Applies a stream of values with an async function, keeping only the latest.
///
/// Zoom updates arrive many times per second while the platform call takes
/// longer. Queueing them would replay a backlog and lag behind the user's
/// fingers. Here at most one call is in flight and at most one value waits:
/// a newer value replaces the waiting one. [submit] never blocks, so a slow
/// call cannot freeze the UI.
class LatestValueCoalescer<T> {
  LatestValueCoalescer(this._apply, {this.onError, this.onIdle});

  final Future<void> Function(T value) _apply;

  /// Called when an apply throws. The value is dropped, not retried.
  final void Function(Object error, StackTrace stack)? onError;

  /// Called each time the queue empties and no call is in flight.
  final void Function()? onIdle;

  bool _running = false;
  bool _hasPending = false;
  bool _disposed = false;
  T? _pending;
  Completer<void>? _idle;

  bool get isIdle => !_running;

  /// Completes when nothing is in flight or waiting.
  Future<void> whenIdle() =>
      _running ? (_idle ??= Completer<void>()).future : Future.value();

  void submit(T value) {
    if (_disposed) return;
    _pending = value;
    _hasPending = true;
    if (!_running) unawaited(_drain());
  }

  /// Drops any waiting value. A call already in flight is not interrupted.
  void dispose() {
    _disposed = true;
    _hasPending = false;
    _pending = null;
  }

  Future<void> _drain() async {
    _running = true;
    try {
      while (_hasPending && !_disposed) {
        final value = _pending as T;
        _hasPending = false;
        _pending = null;
        try {
          await _apply(value);
        } on Object catch (error, stack) {
          onError?.call(error, stack);
        }
      }
    } finally {
      _running = false;
      final idle = _idle;
      _idle = null;
      idle?.complete();
      if (!_disposed) onIdle?.call();
    }
  }
}
