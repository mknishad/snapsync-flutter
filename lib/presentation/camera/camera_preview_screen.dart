import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:snapsync/core/theme/app_semantic_colors.dart';
import 'package:snapsync/presentation/camera/camera_actions.dart';
import 'package:snapsync/presentation/camera/cubit/camera_cubit.dart';
import 'package:snapsync/presentation/camera/cubit/camera_state.dart';
import 'package:snapsync/presentation/camera/widgets/camera_gesture_surface.dart';
import 'package:snapsync/presentation/camera/widgets/camera_lifecycle_observer.dart';
import 'package:snapsync/presentation/camera/widgets/camera_message_listener.dart';
import 'package:snapsync/presentation/camera/widgets/camera_overlay.dart';
import 'package:snapsync/presentation/camera/widgets/camera_status_screen.dart';
import 'package:snapsync/presentation/camera/widgets/capture_flash_overlay.dart';

/// Full-screen camera. Thin: it picks between the live view and the status
/// screen and wires the cubit to small widgets. The camera's lifecycle is
/// handled by [CameraLifecycleObserver] and the cubit, not here.
class CameraPreviewScreen extends StatefulWidget {
  const CameraPreviewScreen({super.key});

  @override
  State<CameraPreviewScreen> createState() => _CameraPreviewScreenState();
}

class _CameraPreviewScreenState extends State<CameraPreviewScreen> {
  // The grid guide is a view preference, not camera state.
  final ValueNotifier<bool> _gridEnabled = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _gridEnabled.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    return CameraLifecycleObserver(
      child: CameraMessageListener(
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          // Light icons over the dark preview; bars see through to it.
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.light,
          ),
          child: Scaffold(
            backgroundColor: semantic.cameraBackground,
            body: BlocBuilder<CameraCubit, CameraState>(
              buildWhen: (a, b) =>
                  a.status != b.status || a.canRetry != b.canRetry,
              builder: (context, state) {
                if (!state.isReady) return _statusScreen(context, state);
                return _LiveView(gridEnabled: _gridEnabled);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusScreen(BuildContext context, CameraState state) {
    final cubit = context.read<CameraCubit>();
    return CameraStatusScreen(
      status: state.status,
      canRetry: state.canRetry,
      onRequestPermission: cubit.requestPermission,
      onOpenSettings: cubit.openAppSettings,
      onRetry: cubit.retry,
      onGoToUploads: () => goToUploadManager(context),
    );
  }
}

class _LiveView extends StatelessWidget {
  const _LiveView({required this.gridEnabled});

  final ValueNotifier<bool> gridEnabled;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: gridEnabled,
          builder: (context, grid, _) => CameraGestureSurface(showGrid: grid),
        ),
        BlocSelector<CameraCubit, CameraState, bool>(
          selector: (s) => s.isCapturing,
          builder: (context, capturing) =>
              CaptureFlashOverlay(isCapturing: capturing),
        ),
        CameraOverlay(gridEnabled: gridEnabled),
      ],
    );
  }
}
