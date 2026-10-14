/// Spacing, corner radii and fixed sizes, so widgets never hard-code numbers.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double pill = 999;
}

abstract final class AppSizes {
  /// Smallest comfortable touch target (Material and Android guidance).
  static const double minTapTarget = 48;
  static const double shutterOuter = 80;
  static const double shutterInner = 64;
  static const double thumbnail = 56;
  static const double presetButton = 36;
  static const double focusIndicator = 76;
  static const double zoomSliderHeight = 220;
}
