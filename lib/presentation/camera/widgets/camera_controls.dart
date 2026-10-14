import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:snapsync/domain/camera/camera_lens.dart';
import 'package:snapsync/domain/camera/flash_setting.dart';
import 'package:snapsync/presentation/batch/cubit/batch_cubit.dart';
import 'package:snapsync/presentation/batch/cubit/batch_state.dart';
import 'package:snapsync/presentation/camera/cubit/camera_cubit.dart';
import 'package:snapsync/presentation/camera/cubit/camera_state.dart';
import 'package:snapsync/presentation/camera/widgets/compact_button_style.dart';
import 'package:snapsync/presentation/camera/widgets/zoom_controls.dart';

/// Temporary plain controls: zoom, flash, capture, lens switch, batch count
/// and the way back to the Upload Manager.
class CameraControls extends StatelessWidget {
  const CameraControls({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CameraCubit>();
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ZoomControls(),
          BlocBuilder<CameraCubit, CameraState>(
            buildWhen: (a, b) =>
                a.flash != b.flash ||
                a.supportsFlash != b.supportsFlash ||
                a.isCapturing != b.isCapturing ||
                a.canSwitchLens != b.canSwitchLens ||
                a.lensDirection != b.lensDirection,
            builder: (context, state) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: cubit.cycleFlash,
                  child: Text(
                    state.supportsFlash
                        ? 'Flash: ${_flashLabel(state.flash)}'
                        : 'No flash',
                  ),
                ),
                FilledButton(
                  style: compactFilledStyle,
                  onPressed: state.isCapturing ? null : cubit.capture,
                  child: Text(state.isCapturing ? 'Saving...' : 'Capture'),
                ),
                TextButton(
                  onPressed: state.canSwitchLens ? cubit.switchLens : null,
                  child: Text(
                    state.lensDirection == LensDirection.back
                        ? 'Use front'
                        : 'Use back',
                  ),
                ),
              ],
            ),
          ),
          BlocBuilder<BatchCubit, BatchState>(
            builder: (context, batch) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Batch: ${batch.imageCount} photo(s)'),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => _backToUploadManager(context),
                      child: const Text('Upload manager'),
                    ),
                    FilledButton(
                      style: compactFilledStyle,
                      onPressed: batch.imageCount == 0
                          ? null
                          : () => _submit(context),
                      child: Text('Upload batch (${batch.imageCount})'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final navigator = Navigator.of(context);
    await context.read<BatchCubit>().submitBatch();
    navigator.popUntil((route) => route.isFirst);
  }

  void _backToUploadManager(BuildContext context) {
    // The Upload Manager is the root route, so going back to it is a pop.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  static String _flashLabel(FlashSetting setting) => switch (setting) {
    FlashSetting.off => 'off',
    FlashSetting.auto => 'auto',
    FlashSetting.always => 'on',
  };
}
