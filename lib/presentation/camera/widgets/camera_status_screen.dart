import 'package:flutter/material.dart';
import 'package:snapsync/core/theme/app_semantic_colors.dart';
import 'package:snapsync/core/theme/app_spacing.dart';
import 'package:snapsync/presentation/camera/cubit/camera_state.dart';
import 'package:snapsync/presentation/camera/widgets/overlay_icon_button.dart';

/// Full-screen state shown instead of the preview whenever the camera is not
/// ready: permission, hardware and error states, each with an icon, a plain
/// message and the right action. Raw exception text never appears here.
class CameraStatusScreen extends StatelessWidget {
  const CameraStatusScreen({
    required this.status,
    required this.canRetry,
    required this.onRequestPermission,
    required this.onOpenSettings,
    required this.onRetry,
    required this.onGoToUploads,
    super.key,
  });

  final CameraStatus status;
  final bool canRetry;
  final VoidCallback onRequestPermission;
  final VoidCallback onOpenSettings;
  final VoidCallback onRetry;

  /// Back to the Upload Manager; offered in every state.
  final VoidCallback onGoToUploads;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final content = _contentFor(status);

    return ColoredBox(
      color: semantic.cameraBackground,
      child: SafeArea(
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: OverlayIconButton(
                  icon: Icons.close_rounded,
                  label: 'Close camera',
                  onPressed: onGoToUploads,
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (content.loading)
                        const CircularProgressIndicator()
                      else if (content.icon != null)
                        Icon(
                          content.icon,
                          size: 56,
                          color: semantic.textSecondary,
                        ),
                      const SizedBox(height: AppSpacing.lg),
                      Semantics(
                        header: true,
                        liveRegion: true,
                        child: Text(
                          content.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      if (content.message != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          content.message!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: semantic.textSecondary),
                        ),
                      ],
                      if (content.action != null) ...[
                        const SizedBox(height: AppSpacing.xl),
                        FilledButton(
                          onPressed: _actionCallback(content.action!),
                          child: Text(content.actionLabel!),
                        ),
                      ],
                      if (!content.loading) ...[
                        const SizedBox(height: AppSpacing.md),
                        OutlinedButton(
                          onPressed: onGoToUploads,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(
                              AppSizes.minTapTarget,
                            ),
                          ),
                          child: const Text('Go to Upload Manager'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  VoidCallback _actionCallback(_Action action) => switch (action) {
    _Action.requestPermission => onRequestPermission,
    _Action.openSettings => onOpenSettings,
    _Action.retry => onRetry,
  };

  _Content _contentFor(CameraStatus status) {
    return switch (status) {
      CameraStatus.initialising || CameraStatus.paused || CameraStatus.ready =>
        const _Content(title: 'Starting the camera...', loading: true),
      CameraStatus.permissionDenied => const _Content(
        icon: Icons.photo_camera_outlined,
        title: 'Camera access needed',
        message: 'SnapSync needs the camera to take the photos you upload.',
        action: _Action.requestPermission,
        actionLabel: 'Allow camera',
      ),
      CameraStatus.permissionPermanentlyDenied => const _Content(
        icon: Icons.no_photography_outlined,
        title: 'Camera access is turned off',
        message: 'Turn it on in the app settings, then come back.',
        action: _Action.openSettings,
        actionLabel: 'Open settings',
      ),
      CameraStatus.noCameraAvailable => const _Content(
        icon: Icons.no_photography_outlined,
        title: 'No camera found',
        message: 'This device does not seem to have a camera SnapSync can use.',
      ),
      CameraStatus.cameraInUse => _Content(
        icon: Icons.videocam_off_outlined,
        title: 'Camera is in use',
        message: 'Another app is using the camera. Close it, then try again.',
        action: canRetry ? _Action.retry : null,
        actionLabel: 'Try again',
      ),
      CameraStatus.unavailable => _Content(
        icon: Icons.error_outline_rounded,
        title: 'Camera unavailable',
        message: 'The camera was disconnected or stopped working.',
        action: canRetry ? _Action.retry : null,
        actionLabel: 'Try again',
      ),
      CameraStatus.error => _Content(
        icon: Icons.error_outline_rounded,
        title: 'Something went wrong',
        message: 'The camera could not start.',
        action: canRetry ? _Action.retry : null,
        actionLabel: 'Try again',
      ),
    };
  }
}

enum _Action { requestPermission, openSettings, retry }

class _Content {
  const _Content({
    required this.title,
    this.icon,
    this.message,
    this.action,
    this.actionLabel,
    this.loading = false,
  });

  final IconData? icon;
  final String title;
  final String? message;
  final _Action? action;
  final String? actionLabel;
  final bool loading;
}
