import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:snapsync/domain/services/exponential_backoff.dart';

ExponentialBackoff backoff({double jitter = 0, Random? random}) {
  return ExponentialBackoff(
    baseDelay: const Duration(seconds: 30),
    multiplier: 2,
    maxDelay: const Duration(minutes: 10),
    jitterRatio: jitter,
    random: random,
  );
}

void main() {
  test('grows exponentially without jitter', () {
    final b = backoff();
    expect(b.delayFor(1), const Duration(seconds: 30));
    expect(b.delayFor(2), const Duration(seconds: 60));
    expect(b.delayFor(3), const Duration(seconds: 120));
    expect(b.delayFor(4), const Duration(seconds: 240));
  });

  test('is capped at maxDelay', () {
    final b = backoff();
    expect(b.delayFor(6), const Duration(minutes: 10));
    expect(b.delayFor(50), const Duration(minutes: 10));
  });

  test('treats attempt numbers below 1 as the first retry', () {
    expect(backoff().delayFor(0), const Duration(seconds: 30));
  });

  test('jitter stays within bounds and never exceeds the cap', () {
    final b = backoff(jitter: 0.2, random: Random(7));
    for (var attempt = 1; attempt <= 12; attempt++) {
      final raw = min(30000 * pow(2, attempt - 1), 600000).toDouble();
      for (var sample = 0; sample < 50; sample++) {
        final ms = b.delayFor(attempt).inMilliseconds;
        expect(ms, greaterThanOrEqualTo((raw * 0.8).floor()));
        expect(ms, lessThanOrEqualTo(min(raw * 1.2, 600000).ceil()));
      }
    }
  });

  test('a seeded random source gives a repeatable sequence', () {
    final a = backoff(jitter: 0.2, random: Random(42));
    final b = backoff(jitter: 0.2, random: Random(42));
    expect(
      [for (var i = 1; i <= 10; i++) a.delayFor(i)],
      [for (var i = 1; i <= 10; i++) b.delayFor(i)],
    );
  });

  test('different seeds give different jitter', () {
    final a = backoff(jitter: 0.2, random: Random(1)).delayFor(3);
    final b = backoff(jitter: 0.2, random: Random(2)).delayFor(3);
    expect(a, isNot(b));
  });
}
