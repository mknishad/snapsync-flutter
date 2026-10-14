import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:snapsync/presentation/camera/cubit/camera_cubit.dart';

/// The live preview. The cubit hands over an opaque handle; this widget is the
/// one place in the UI that knows it is the camera plugin's controller. It sits
/// in its own repaint layer so overlays changing above it (zoom label, focus
/// ring) do not repaint the preview.
class CameraPreviewView extends StatelessWidget {
  const CameraPreviewView({super.key});

  @override
  Widget build(BuildContext context) {
    final handle = context.read<CameraCubit>().previewHandle;
    if (handle is CameraController && handle.value.isInitialized) {
      return RepaintBoundary(child: CameraPreview(handle));
    }
    return const SizedBox.shrink();
  }
}
