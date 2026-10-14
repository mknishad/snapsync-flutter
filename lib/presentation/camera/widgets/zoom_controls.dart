import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:snapsync/presentation/camera/cubit/camera_cubit.dart';
import 'package:snapsync/presentation/camera/cubit/camera_state.dart';
import 'package:snapsync/presentation/camera/widgets/compact_button_style.dart';

/// Zoom preset buttons and the zoom slider. Both read the same zoom from the
/// cubit, so they always agree with pinching.
class ZoomControls extends StatelessWidget {
  const ZoomControls({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CameraCubit>();
    return BlocBuilder<CameraCubit, CameraState>(
      buildWhen: (a, b) =>
          a.zoom != b.zoom ||
          a.presets != b.presets ||
          a.minZoom != b.minZoom ||
          a.maxZoom != b.maxZoom,
      builder: (context, state) {
        final active = state.activePreset;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final preset in state.presets)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: preset == active
                        ? FilledButton(
                            style: compactFilledStyle,
                            onPressed: () => cubit.selectPreset(preset),
                            child: Text(preset.label),
                          )
                        : OutlinedButton(
                            onPressed: () => cubit.selectPreset(preset),
                            child: Text(preset.label),
                          ),
                  ),
              ],
            ),
            Row(
              children: [
                Text('${state.zoom.toStringAsFixed(1)}x'),
                Expanded(
                  child: Slider(
                    value: state.sliderValue,
                    onChanged: cubit.setZoomFromSlider,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
