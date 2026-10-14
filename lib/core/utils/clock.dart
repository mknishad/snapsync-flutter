/// Source of the current time. Inject it so time-dependent logic can be tested.
typedef Clock = DateTime Function();

/// Current UTC time truncated to whole milliseconds, which is the precision
/// stored in the database.
DateTime utcNow() => DateTime.now().toUtc().truncateToMillis();

extension DateTimeMillis on DateTime {
  DateTime truncateToMillis() =>
      DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch, isUtc: true);
}
