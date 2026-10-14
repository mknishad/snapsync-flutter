import 'package:flutter_test/flutter_test.dart';
import 'package:snapsync/core/error/failure.dart';

void main() {
  group('isRetryable', () {
    test('network and unknown failures are retryable', () {
      expect(const NoInternetFailure('x').isRetryable, isTrue);
      expect(const LowBandwidthFailure('x').isRetryable, isTrue);
      expect(const UnknownFailure('x').isRetryable, isTrue);
    });

    test('local failures are not retryable', () {
      expect(const StorageFailure('x').isRetryable, isFalse);
      expect(const FileMissingFailure('x').isRetryable, isFalse);
      expect(const DatabaseFailure('x').isRetryable, isFalse);
    });

    test('server codes: 5xx, 408 and 429 retry; other 4xx do not', () {
      for (final code in [500, 502, 503, 408, 429]) {
        expect(
          ServerFailure('x', code: code).isRetryable,
          isTrue,
          reason: '$code',
        );
      }
      for (final code in [400, 401, 403, 404, 413, 422]) {
        expect(
          ServerFailure('x', code: code).isRetryable,
          isFalse,
          reason: '$code',
        );
      }
    });
  });

  group('consumesAttempt', () {
    test('no internet does not use up a retry', () {
      expect(const NoInternetFailure('x').consumesAttempt, isFalse);
    });

    test('other retryable failures do', () {
      expect(const LowBandwidthFailure('x').consumesAttempt, isTrue);
      expect(const ServerFailure('x', code: 503).consumesAttempt, isTrue);
      expect(const UnknownFailure('x').consumesAttempt, isTrue);
    });
  });

  test('failures with the same data are equal', () {
    expect(
      const ServerFailure('x', code: 500),
      const ServerFailure('x', code: 500),
    );
    expect(
      const ServerFailure('x', code: 500) ==
          const ServerFailure('x', code: 501),
      isFalse,
    );
  });
}
