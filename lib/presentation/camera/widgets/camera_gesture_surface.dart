import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:snapsync/presentation/camera/cubit/camera_cubit.dart';
import 'package:snapsync/presentation/camera/cubit/camera_state.dart';
import 'package:snapsync/presentation/camera/cubit/focus_indicator.dart';
import 'package:snapsync/presentation/camera/widgets/camera_preview_view.dart';
import 'package:snapsync/presentation/camera/widgets/focus_indicator_view.dart';
import 'package:snapsync/presentation/camera/widgets/grid_overlay.dart';

/// The area that catches pinch, tap and long-press, with the preview centred
/// inside it (letterboxed when the shapes differ, so tap-to-focus maps through
/// the cubit's existing conversion) and the focus ring on top.
///
/// Only the status, lens and focus indicator rebuild this subtree. Zoom changes
/// do not, so the preview itself is not rebuilt while pinching.
class CameraGestureSurface extends StatelessWidget {
  const CameraGestureSurface({required this.showGrid, super.key});

  final bool showGrid;

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
          child: BlocSelector<CameraCubit, CameraState, _SurfaceData>(
            selector: (state) => _SurfaceData(
              status: state.status,
              lensId: state.activeLensId,
              indicator: state.focusIndicator,
            ),
            builder: (context, data) {
              final indicator = data.indicator;
              return Stack(
                fit: StackFit.expand,
                children: [
                  const Center(child: CameraPreviewView()),
                  if (showGrid)
                    GridOverlay(aspectRatio: cubit.service.previewAspectRatio),
                  if (indicator != null)
                    FocusIndicatorView(
                      key: ValueKey(indicator.id),
                      indicator: indicator,
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// What this surface depends on, so BlocSelector can skip other changes.
@immutable
class _SurfaceData {
  const _SurfaceData({
    required this.status,
    required this.lensId,
    required this.indicator,
  });

  final CameraStatus status;
  final String? lensId;
  final FocusIndicator? indicator;

  @override
  bool operator ==(Object other) =>
      other is _SurfaceData &&
      other.status == status &&
      other.lensId == lensId &&
      other.indicator == indicator;

  @override
  int get hashCode => Object.hash(status, lensId, indicator);
}
