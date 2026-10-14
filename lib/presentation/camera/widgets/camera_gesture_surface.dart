import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:snapsync/presentation/camera/cubit/camera_cubit.dart';
import 'package:snapsync/presentation/camera/cubit/camera_state.dart';
import 'package:snapsync/presentation/camera/widgets/camera_preview_view.dart';
import 'package:snapsync/presentation/camera/widgets/focus_indicator_view.dart';

/// The area that catches pinch, tap and long-press, with the preview centred
/// inside it (letterboxed when the shapes differ) and the focus ring on top.
/// Tap positions are passed to the cubit with this area's size; the cubit
/// works out where the preview sits within it.
class CameraGestureSurface extends StatelessWidget {
  const CameraGestureSurface({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CameraCubit>();
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: (_) => cubit.onPinchStart(),
          onScaleUpdate: (details) {
            if (details.pointerCount >= 2) cubit.onPinchUpdate(details.scale);
          },
          onScaleEnd: (_) => cubit.onPinchEnd(),
          onTapUp: (details) => cubit.onTapToFocus(details.localPosition, size),
          onLongPressStart: (details) =>
              cubit.onLongPressToLockFocus(details.localPosition, size),
          child: BlocBuilder<CameraCubit, CameraState>(
            buildWhen: (a, b) =>
                a.status != b.status ||
                a.activeLensId != b.activeLensId ||
                a.focusIndicator != b.focusIndicator,
            builder: (context, state) {
              final indicator = state.focusIndicator;
              return Stack(
                fit: StackFit.expand,
                children: [
                  const Center(child: CameraPreviewView()),
                  if (indicator != null)
                    FocusIndicatorView(indicator: indicator),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
