import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:snapsync/presentation/camera/cubit/camera_cubit.dart';
import 'package:snapsync/presentation/camera/cubit/camera_state.dart';
import 'package:snapsync/presentation/camera/widgets/camera_controls.dart';
import 'package:snapsync/presentation/camera/widgets/camera_gesture_surface.dart';
import 'package:snapsync/presentation/camera/widgets/camera_lifecycle_observer.dart';
import 'package:snapsync/presentation/camera/widgets/camera_message_listener.dart';
import 'package:snapsync/presentation/camera/widgets/camera_status_view.dart';

/// Temporary camera screen: live preview with pinch, tap and long-press, plus
/// plain buttons to exercise every feature. The final design replaces this.
class CameraPreviewScreen extends StatelessWidget {
  const CameraPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: replace with the custom camera UI (see reference screenshot).
    return CameraLifecycleObserver(
      child: CameraMessageListener(
        child: Scaffold(
          appBar: AppBar(title: const Text('CameraPreviewScreen')),
          body: BlocBuilder<CameraCubit, CameraState>(
            buildWhen: (a, b) =>
                a.status != b.status || a.canRetry != b.canRetry,
            builder: (context, state) {
              if (!state.isReady) return CameraStatusView(state: state);
              return const Column(
                children: [
                  Expanded(child: CameraGestureSurface()),
                  CameraControls(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
