import 'dart:async';

/// Creates a one-shot timer. Inject it so tests can fire timers by hand.
typedef TimerFactory = Timer Function(Duration duration, void Function() run);

Timer realTimer(Duration duration, void Function() run) =>
    Timer(duration, run);
