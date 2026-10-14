import 'dart:math';

/// Retry delay that doubles (or grows by [multiplier]) with every failed
/// attempt, spread by random jitter and capped at [maxDelay].
///
/// Pure: the random source is injected, so a seeded [Random] gives repeatable
/// results in tests.
class ExponentialBackoff {
  ExponentialBackoff({
    required this.baseDelay,
    required this.multiplier,
    required this.maxDelay,
    required this.jitterRatio,
    Random? random,
  })  : assert(jitterRatio >= 0 && jitterRatio < 1, 'jitterRatio in [0, 1)'),
        assert(multiplier >= 1, 'multiplier must not shrink the delay'),
        _random = random ?? Random();

  final Duration baseDelay;
  final double multiplier;
  final Duration maxDelay;
  final double jitterRatio;
  final Random _random;

  /// Delay before retry number [attempt], where 1 is the first retry.
  /// The result never exceeds [maxDelay], jitter included.
  Duration delayFor(int attempt) {
    final exponent = max(attempt, 1) - 1;
    final raw = baseDelay.inMilliseconds * pow(multiplier, exponent);
    final capped = min(raw, maxDelay.inMilliseconds.toDouble());
    final jitter = 1 + (_random.nextDouble() * 2 - 1) * jitterRatio;
    final jittered = min(capped * jitter, maxDelay.inMilliseconds.toDouble());
    return Duration(milliseconds: jittered.round());
  }
}
