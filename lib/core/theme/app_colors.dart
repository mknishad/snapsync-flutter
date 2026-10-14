import 'dart:ui';

/// Palette taken from the reference screenshots: dark navy surfaces, a blue
/// accent, and status colours.
abstract final class AppColors {
  // Surfaces
  static const Color background = Color(0xFF0A1020);
  static const Color surface = Color(0xFF111A2E);
  static const Color surfaceHigh = Color(0xFF1A2540);
  static const Color outline = Color(0xFF26324D);

  // Accent
  static const Color primary = Color(0xFF2F6BEE);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Text
  static const Color textPrimary = Color(0xFFE8ECF6);
  static const Color textSecondary = Color(0xFF8D99B3);

  // Status
  /// Stable link, uploaded.
  static const Color success = Color(0xFF22C55E);

  /// Retrying, waiting.
  static const Color warning = Color(0xFFF59E0B);

  /// Failed.
  static const Color error = Color(0xFFEF4444);
}
