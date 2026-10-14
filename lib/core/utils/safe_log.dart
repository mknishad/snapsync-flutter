import 'dart:developer' as developer;

/// True in release builds (pure Dart, so the domain layer can use it).
const bool _isRelease = bool.fromEnvironment('dart.vm.product');

/// Logs a problem without leaking details outside debug builds.
///
/// Exception messages can contain file paths (from the file system) or SQL
/// with bound values (from sqflite), so in release builds only [summary] and
/// the exception's type are logged. Keep [summary] free of paths and other
/// user data. Debug builds also get the full error and stack trace.
void logProblem(
  String logger,
  String summary, {
  Object? error,
  StackTrace? stackTrace,
  int level = 900,
}) {
  if (_isRelease) {
    developer.log(
      error == null ? summary : '$summary (${error.runtimeType})',
      name: logger,
      level: level,
    );
    return;
  }
  developer.log(
    summary,
    name: logger,
    level: level,
    error: error,
    stackTrace: stackTrace,
  );
}
