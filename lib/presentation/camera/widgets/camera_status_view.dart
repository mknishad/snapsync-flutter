import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:snapsync/presentation/camera/cubit/camera_cubit.dart';
import 'package:snapsync/presentation/camera/cubit/camera_state.dart';

/// Shown instead of the preview whenever the camera is not ready: every
/// permission and hardware state, with the right action. Text is fixed per
/// state; raw exception text is never shown.
class CameraStatusView extends StatelessWidget {
  const CameraStatusView({required this.state, super.key});

  final CameraState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CameraCubit>();
    final (text, actionLabel, action) = switch (state.status) {
      CameraStatus.initialising ||
      CameraStatus.paused ||
      CameraStatus.ready => ('Starting the camera...', null, null),
      CameraStatus.permissionDenied => (
        'SnapSync needs the camera to take photos. Without it, nothing can be captured.',
        'Allow camera',
        cubit.requestPermission,
      ),
      CameraStatus.permissionPermanentlyDenied => (
        'Camera access is turned off for SnapSync. Turn it on in the app settings, then come back.',
        'Open settings',
        cubit.openAppSettings,
      ),
      CameraStatus.noCameraAvailable => (
        'No camera was found on this device.',
        null,
        null,
      ),
      CameraStatus.cameraInUse => (
        'The camera is being used by another app. Close that app and try again.',
        'Try again',
        cubit.retry,
      ),
      CameraStatus.unavailable => (
        'The camera was disconnected or stopped working.',
        'Try again',
        cubit.retry,
      ),
      CameraStatus.error => (
        'Something went wrong with the camera.',
        'Try again',
        cubit.retry,
      ),
    };

    final loading = state.status == CameraStatus.initialising;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading) const CircularProgressIndicator(),
            if (loading) const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center),
            if (actionLabel != null &&
                (state.canRetry || state.status.isSettingsAction))
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: FilledButton(
                  onPressed: action,
                  child: Text(actionLabel),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

extension on CameraStatus {
  /// Statuses whose button is not a retry (so it shows even when canRetry is
  /// false).
  bool get isSettingsAction => this == CameraStatus.permissionPermanentlyDenied;
}
