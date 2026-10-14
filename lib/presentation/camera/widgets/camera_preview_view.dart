import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:snapsync/presentation/camera/cubit/camera_cubit.dart';

/// The live preview. The cubit hands over an opaque handle; this widget is the
/// one place in the UI that knows it is the camera plugin's controller.
class CameraPreviewView extends StatelessWidget {
  const CameraPreviewView({super.key});

  @override
  Widget build(BuildContext context) {
    final handle = context.read<CameraCubit>().previewHandle;
    if (handle is CameraController && handle.value.isInitialized) {
      return CameraPreview(handle);
    }
    return const SizedBox.shrink();
  }
}
