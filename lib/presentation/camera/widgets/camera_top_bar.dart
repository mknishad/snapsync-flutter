import 'package:flutter/material.dart';
import 'package:snapsync/core/theme/app_spacing.dart';
import 'package:snapsync/domain/camera/flash_setting.dart';
import 'package:snapsync/presentation/camera/widgets/overlay_icon_button.dart';

/// Close on the left; flash (only if the camera has one) and the grid toggle on
/// the right.
class CameraTopBar extends StatelessWidget {
  const CameraTopBar({
    required this.flash,
    required this.supportsFlash,
    required this.gridEnabled,
    required this.onClose,
    required this.onFlash,
    required this.onGrid,
    super.key,
  });

  final FlashSetting flash;
  final bool supportsFlash;
  final bool gridEnabled;
  final VoidCallback onClose;
  final VoidCallback onFlash;
  final VoidCallback onGrid;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          OverlayIconButton(
            icon: Icons.close_rounded,
            label: 'Close camera',
            onPressed: onClose,
          ),
          const Spacer(),
          if (supportsFlash)
            OverlayIconButton(
              icon: _flashIcon(flash),
              label: 'Flash: ${_flashName(flash)}. Tap to change',
              onPressed: onFlash,
            ),
          OverlayIconButton(
            icon: Icons.grid_3x3_rounded,
            label: gridEnabled ? 'Hide grid' : 'Show grid',
            selected: gridEnabled,
            onPressed: onGrid,
          ),
        ],
      ),
    );
  }

  static IconData _flashIcon(FlashSetting flash) => switch (flash) {
    FlashSetting.off => Icons.flash_off_rounded,
    FlashSetting.auto => Icons.flash_auto_rounded,
    FlashSetting.always => Icons.flash_on_rounded,
  };

  static String _flashName(FlashSetting flash) => switch (flash) {
    FlashSetting.off => 'off',
    FlashSetting.auto => 'auto',
    FlashSetting.always => 'on',
  };
}
