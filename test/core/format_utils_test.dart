import 'package:flutter_test/flutter_test.dart';
import 'package:snapsync/core/utils/format_utils.dart';

void main() {
  group('bytes', () {
    test('small values are whole bytes', () {
      expect(FormatUtils.bytes(0), '0 B');
      expect(FormatUtils.bytes(1), '1 B');
      expect(FormatUtils.bytes(512), '512 B');
      expect(FormatUtils.bytes(1023), '1023 B');
    });

    test('kilobytes, megabytes and gigabytes use one decimal', () {
      expect(FormatUtils.bytes(1024), '1.0 KB');
      expect(FormatUtils.bytes(1536), '1.5 KB');
      expect(FormatUtils.bytes(2516582), '2.4 MB');
      expect(FormatUtils.bytes(3 * 1024 * 1024), '3.0 MB');
      expect(FormatUtils.bytes(3.2 * 1024 * 1024 * 1024), '3.2 GB');
      expect(FormatUtils.bytes(5 * 1024 * 1024 * 1024 * 1024), '5.0 TB');
    });

    test('a value that rounds up to the next unit is shown in that unit', () {
      expect(FormatUtils.bytes(1024 * 1024 - 1), '1.0 MB');
      expect(FormatUtils.bytes(1024 * 1024 * 1024 - 1), '1.0 GB');
    });

    test('negative and non-finite values are 0 B', () {
      expect(FormatUtils.bytes(-5), '0 B');
      expect(FormatUtils.bytes(double.nan), '0 B');
      expect(FormatUtils.bytes(double.infinity), '0 B');
    });

    test('beyond terabytes stays in terabytes', () {
      expect(
        FormatUtils.bytes(2048.0 * 1024 * 1024 * 1024 * 1024),
        '2048.0 TB',
      );
    });
  });

  group('timeAgo', () {
    final now = DateTime.utc(2026, 1, 1, 12);

    test('under a minute is just now, including the future', () {
      expect(FormatUtils.timeAgo(now, now), 'just now');
      expect(
        FormatUtils.timeAgo(now.subtract(const Duration(seconds: 59)), now),
        'just now',
      );
      expect(
        FormatUtils.timeAgo(now.add(const Duration(minutes: 5)), now),
        'just now',
      );
    });

    test('minutes, hours and days', () {
      expect(
        FormatUtils.timeAgo(now.subtract(const Duration(minutes: 1)), now),
        '1m ago',
      );
      expect(
        FormatUtils.timeAgo(
          now.subtract(const Duration(minutes: 2, seconds: 30)),
          now,
        ),
        '2m ago',
      );
      expect(
        FormatUtils.timeAgo(now.subtract(const Duration(minutes: 59)), now),
        '59m ago',
      );
      expect(
        FormatUtils.timeAgo(now.subtract(const Duration(hours: 1)), now),
        '1h ago',
      );
      expect(
        FormatUtils.timeAgo(now.subtract(const Duration(hours: 23)), now),
        '23h ago',
      );
      expect(
        FormatUtils.timeAgo(now.subtract(const Duration(hours: 24)), now),
        '1d ago',
      );
      expect(
        FormatUtils.timeAgo(now.subtract(const Duration(days: 10)), now),
        '10d ago',
      );
    });
  });

  group('timeUntil', () {
    final now = DateTime.utc(2026, 1, 1, 12);

    test('a time already reached is now', () {
      expect(FormatUtils.timeUntil(now, now), 'now');
      expect(
        FormatUtils.timeUntil(now.subtract(const Duration(seconds: 5)), now),
        'now',
      );
    });

    test('seconds, minutes and hours', () {
      expect(
        FormatUtils.timeUntil(now.add(const Duration(seconds: 25)), now),
        'in 25s',
      );
      expect(
        FormatUtils.timeUntil(now.add(const Duration(seconds: 59)), now),
        'in 59s',
      );
      expect(
        FormatUtils.timeUntil(now.add(const Duration(seconds: 90)), now),
        'in 2m',
      );
      expect(
        FormatUtils.timeUntil(now.add(const Duration(minutes: 10)), now),
        'in 10m',
      );
      expect(
        FormatUtils.timeUntil(now.add(const Duration(hours: 2)), now),
        'in 2h',
      );
    });
  });

  group('zoom', () {
    test('whole numbers drop the decimal', () {
      expect(FormatUtils.zoom(1), '1x');
      expect(FormatUtils.zoom(3), '3x');
      expect(FormatUtils.zoom(2.0), '2x');
    });

    test('other values have one decimal', () {
      expect(FormatUtils.zoom(0.5), '0.5x');
      expect(FormatUtils.zoom(1.74), '1.7x');
      expect(FormatUtils.zoom(2.96), '3x', reason: 'rounds to a whole number');
    });
  });

  group('percent', () {
    test('rounds and clamps', () {
      expect(FormatUtils.percent(0), '0%');
      expect(FormatUtils.percent(0.734), '73%');
      expect(FormatUtils.percent(1), '100%');
      expect(FormatUtils.percent(1.5), '100%');
      expect(FormatUtils.percent(-0.2), '0%');
      expect(FormatUtils.percent(double.nan), '0%');
    });
  });
}
