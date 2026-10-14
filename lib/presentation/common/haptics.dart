import 'package:flutter/services.dart';
import 'package:snapsync/core/utils/safe_log.dart';

/// Light haptic feedback, using only the framework's own HapticFeedback.
abstract final class Haptics {
  /// Feedback is a nicety: if the device or platform cannot do it, the app
  /// carries on. The failure is logged, not hidden.
  static Future<void> light() async {
    try {
      await HapticFeedback.lightImpact();
    } on PlatformException catch (error) {
      logProblem('snapsync.haptics', 'Haptic feedback failed', error: error);
    } on MissingPluginException catch (error) {
      logProblem(
        'snapsync.haptics',
        'Haptic feedback unavailable',
        error: error,
      );
    }
  }
}
