import 'package:flutter/material.dart';
import 'package:snapsync/core/theme/app_colors.dart';

/// Semantic colour roles and text styles that Material's ColorScheme does not
/// have. Widgets read these from the theme instead of using raw colours.
///
/// Status is never carried by colour alone: every use pairs these colours with
/// an icon or text.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.surfaceLow,
    required this.surface,
    required this.surfaceHigh,
    required this.outline,
    required this.overlay,
    required this.overlayStrong,
    required this.onOverlay,
    required this.cameraBackground,
    required this.textPrimary,
    required this.textSecondary,
    required this.caption,
    required this.statusLabel,
    required this.metric,
    required this.small,
    required this.overlayLabel,
  });

  /// Stable link, synced.
  final Color success;

  /// Waiting, retrying, unstable link.
  final Color warning;

  /// Failed, offline.
  final Color danger;

  /// Uploading, informational.
  final Color info;

  /// Surface levels, darkest first.
  final Color surfaceLow;
  final Color surface;
  final Color surfaceHigh;
  final Color outline;

  /// Translucent controls over the camera preview, and what is drawn on them.
  final Color overlay;
  final Color overlayStrong;
  final Color onOverlay;

  /// Behind the live preview.
  final Color cameraBackground;

  final Color textPrimary;
  final Color textSecondary;

  /// Small uppercase label with letter spacing ("BATCH SYNC PROGRESS").
  final TextStyle caption;

  /// Bold status text on a card ("WAITING FOR CONNECTION").
  final TextStyle statusLabel;

  /// Large figures (percentages, zoom value).
  final TextStyle metric;

  /// Small secondary text (retry hints, times).
  final TextStyle small;

  /// Bold small text drawn over the camera preview (zoom labels, badges).
  final TextStyle overlayLabel;

  static const AppSemanticColors dark = AppSemanticColors(
    success: AppColors.success,
    warning: AppColors.warning,
    danger: AppColors.error,
    info: AppColors.info,
    surfaceLow: AppColors.surfaceLow,
    surface: AppColors.surface,
    surfaceHigh: AppColors.surfaceHigh,
    outline: AppColors.outline,
    overlay: AppColors.overlay,
    overlayStrong: AppColors.overlayStrong,
    onOverlay: AppColors.onOverlay,
    cameraBackground: AppColors.cameraBackground,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    caption: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.2,
      color: AppColors.textSecondary,
    ),
    statusLabel: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
    ),
    metric: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    ),
    small: TextStyle(fontSize: 12, color: AppColors.textSecondary),
    overlayLabel: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: AppColors.onOverlay,
    ),
  );

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? surfaceLow,
    Color? surface,
    Color? surfaceHigh,
    Color? outline,
    Color? overlay,
    Color? overlayStrong,
    Color? onOverlay,
    Color? cameraBackground,
    Color? textPrimary,
    Color? textSecondary,
    TextStyle? caption,
    TextStyle? statusLabel,
    TextStyle? metric,
    TextStyle? small,
    TextStyle? overlayLabel,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      surfaceLow: surfaceLow ?? this.surfaceLow,
      surface: surface ?? this.surface,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      outline: outline ?? this.outline,
      overlay: overlay ?? this.overlay,
      overlayStrong: overlayStrong ?? this.overlayStrong,
      onOverlay: onOverlay ?? this.onOverlay,
      cameraBackground: cameraBackground ?? this.cameraBackground,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      caption: caption ?? this.caption,
      statusLabel: statusLabel ?? this.statusLabel,
      metric: metric ?? this.metric,
      small: small ?? this.small,
      overlayLabel: overlayLabel ?? this.overlayLabel,
    );
  }

  @override
  AppSemanticColors lerp(AppSemanticColors? other, double t) {
    if (other == null) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
      surfaceLow: Color.lerp(surfaceLow, other.surfaceLow, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      overlayStrong: Color.lerp(overlayStrong, other.overlayStrong, t)!,
      onOverlay: Color.lerp(onOverlay, other.onOverlay, t)!,
      cameraBackground: Color.lerp(
        cameraBackground,
        other.cameraBackground,
        t,
      )!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      caption: TextStyle.lerp(caption, other.caption, t)!,
      statusLabel: TextStyle.lerp(statusLabel, other.statusLabel, t)!,
      metric: TextStyle.lerp(metric, other.metric, t)!,
      small: TextStyle.lerp(small, other.small, t)!,
      overlayLabel: TextStyle.lerp(overlayLabel, other.overlayLabel, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  /// The app's semantic colours and text styles. Falls back to the dark set so
  /// a widget placed in a bare MaterialApp (for example in a test) still works.
  AppSemanticColors get semantic =>
      Theme.of(this).extension<AppSemanticColors>() ?? AppSemanticColors.dark;
}
