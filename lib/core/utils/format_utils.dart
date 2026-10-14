/// Human-readable sizes and times for the UI. Pure functions, no intl.
abstract final class FormatUtils {
  static const _units = ['B', 'KB', 'MB', 'GB', 'TB'];

  /// 512 -> "512 B", 1536 -> "1.5 KB", 2516582 -> "2.4 MB". Binary units
  /// (1 KB = 1024 B), one decimal from KB up. A value that rounds up to the next
  /// unit is shown in that unit ("1023.97 KB" is "1.0 MB"). Negative or
  /// non-finite input is shown as "0 B".
  static String bytes(num value) {
    if (!value.isFinite || value <= 0) return '0 B';
    var size = value.toDouble();
    var unit = 0;
    while (size >= 1024 && unit < _units.length - 1) {
      size /= 1024;
      unit++;
    }
    if (unit == 0) return '${size.round()} B';
    var text = size.toStringAsFixed(1);
    // 1023.96 rounds to "1024.0": step up a unit instead.
    if (text == '1024.0' && unit < _units.length - 1) {
      unit++;
      text = '1.0';
    }
    return '$text ${_units[unit]}';
  }

  /// "just now", "2m ago", "3h ago", "4d ago". Times in the future are "just
  /// now".
  static String timeAgo(DateTime then, DateTime now) {
    final seconds = now.difference(then).inSeconds;
    if (seconds < 60) return 'just now';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '${minutes}m ago';
    final hours = minutes ~/ 60;
    if (hours < 24) return '${hours}h ago';
    return '${hours ~/ 24}d ago';
  }

  /// "in 25s", "in 3m", "in 2h". A time already reached is "now".
  static String timeUntil(DateTime target, DateTime now) {
    final seconds = target.difference(now).inSeconds;
    if (seconds <= 0) return 'now';
    if (seconds < 60) return 'in ${seconds}s';
    final minutes = (seconds + 30) ~/ 60;
    if (minutes < 60) return 'in ${minutes}m';
    return 'in ${(minutes + 30) ~/ 60}h';
  }

  /// 0.5 -> "0.5x", 3 -> "3x", 1.74 -> "1.7x".
  static String zoom(double value) {
    final rounded = (value * 10).round() / 10;
    final text = rounded == rounded.roundToDouble()
        ? rounded.round().toString()
        : rounded.toStringAsFixed(1);
    return '${text}x';
  }

  /// 0.734 -> "73%". Clamped to 0..100.
  static String percent(double fraction) {
    final clamped = fraction.isNaN ? 0.0 : fraction.clamp(0.0, 1.0);
    return '${(clamped * 100).round()}%';
  }
}
