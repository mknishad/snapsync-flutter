import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:snapsync/core/theme/app_spacing.dart';
import 'package:snapsync/domain/camera/camera_lens.dart';
import 'package:snapsync/domain/camera/flash_setting.dart';
import 'package:snapsync/domain/camera/zoom_preset.dart';
import 'package:snapsync/presentation/batch/cubit/batch_cubit.dart';
import 'package:snapsync/presentation/batch/cubit/batch_state.dart';
import 'package:snapsync/presentation/batch/widgets/batch_review_sheet.dart';
import 'package:snapsync/presentation/camera/camera_actions.dart';
import 'package:snapsync/presentation/camera/cubit/camera_cubit.dart';
import 'package:snapsync/presentation/camera/cubit/camera_state.dart';
import 'package:snapsync/presentation/camera/widgets/batch_thumbnail.dart';
import 'package:snapsync/presentation/camera/widgets/camera_top_bar.dart';
import 'package:snapsync/presentation/camera/widgets/overlay_icon_button.dart';
import 'package:snapsync/presentation/camera/widgets/shutter_button.dart';
import 'package:snapsync/presentation/camera/widgets/upload_batch_button.dart';
import 'package:snapsync/presentation/camera/widgets/zoom_preset_buttons.dart';
import 'package:snapsync/presentation/camera/widgets/zoom_slider.dart';
import 'package:snapsync/presentation/common/haptics.dart';

/// The controls drawn over the preview. In portrait the zoom slider is on the
/// right edge and the shutter row and upload button sit at the bottom. In
/// landscape a control rail runs down the right side and the slider moves to the
/// left edge, so nothing overlaps; the screen is not locked to portrait because
/// photos are saved upright only when the app can rotate with the device.
///
/// Each part selects only the state it shows, so a zoom change does not rebuild
/// the shutter, and a capture does not rebuild the slider.
class CameraOverlay extends StatelessWidget {
  const CameraOverlay({required this.gridEnabled, super.key});

  final ValueNotifier<bool> gridEnabled;

  static const double _railWidth = 176;

  @override
  Widget build(BuildContext context) {
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    return SafeArea(child: landscape ? _landscape() : _portrait());
  }

  Widget _portrait() {
    return Stack(
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: _TopBar(grid: gridEnabled),
        ),
        const Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.only(right: AppSpacing.xs),
            child: _ZoomSlider(),
          ),
        ),
        const Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Presets(),
                SizedBox(height: AppSpacing.sm),
                _ShutterRow(axis: Axis.horizontal),
                SizedBox(height: AppSpacing.md),
                _UploadButton(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _landscape() {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: _railWidth),
          child: Align(
            alignment: Alignment.topCenter,
            child: _TopBar(grid: gridEnabled),
          ),
        ),
        const Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(left: AppSpacing.xs),
            child: _ZoomSlider(height: 160),
          ),
        ),
        const Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: _railWidth,
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Presets(),
                  _ShutterRow(axis: Axis.vertical),
                  SizedBox(height: AppSpacing.sm),
                  _UploadButton(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.grid});

  final ValueNotifier<bool> grid;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CameraCubit>();
    return BlocSelector<
      CameraCubit,
      CameraState,
      ({FlashSetting flash, bool supportsFlash})
    >(
      selector: (s) => (flash: s.flash, supportsFlash: s.supportsFlash),
      builder: (context, data) => ValueListenableBuilder<bool>(
        valueListenable: grid,
        builder: (context, gridOn, _) => CameraTopBar(
          flash: data.flash,
          supportsFlash: data.supportsFlash,
          gridEnabled: gridOn,
          onClose: () => goToUploadManager(context),
          onFlash: cubit.cycleFlash,
          onGrid: () => grid.value = !gridOn,
        ),
      ),
    );
  }
}

class _ZoomSlider extends StatelessWidget {
  const _ZoomSlider({this.height = 220});

  final double height;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CameraCubit>();
    return BlocSelector<
      CameraCubit,
      CameraState,
      ({double zoom, double minZoom, double slider, bool zoomable})
    >(
      selector: (s) => (
        zoom: s.zoom,
        minZoom: s.minZoom,
        slider: s.sliderValue,
        // A camera with no zoom range has nothing to slide.
        zoomable: s.maxZoom > s.minZoom,
      ),
      builder: (context, data) {
        if (!data.zoomable) return const SizedBox.shrink();
        return ZoomSlider(
          zoom: data.zoom,
          minZoom: data.minZoom,
          value: data.slider,
          height: height,
          onChanged: cubit.setZoomFromSlider,
        );
      },
    );
  }
}

class _Presets extends StatelessWidget {
  const _Presets();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CameraCubit>();
    return BlocSelector<
      CameraCubit,
      CameraState,
      ({List<ZoomPreset> presets, double zoom})
    >(
      selector: (s) => (presets: s.presets, zoom: s.zoom),
      builder: (context, data) => ZoomPresetButtons(
        presets: data.presets,
        zoom: data.zoom,
        onSelected: cubit.selectPreset,
      ),
    );
  }
}

class _ShutterRow extends StatelessWidget {
  const _ShutterRow({required this.axis});

  final Axis axis;

  @override
  Widget build(BuildContext context) {
    final shutter = const _Shutter();
    const thumbnail = _Thumbnail();
    const flip = _FlipButton();

    if (axis == Axis.vertical) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [thumbnail, _Shutter(), flip],
      );
    }
    return Row(
      children: [
        const Expanded(
          child: Align(alignment: Alignment.centerLeft, child: thumbnail),
        ),
        shutter,
        const Expanded(
          child: Align(alignment: Alignment.centerRight, child: flip),
        ),
      ],
    );
  }
}

class _Shutter extends StatelessWidget {
  const _Shutter();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CameraCubit>();
    return BlocSelector<CameraCubit, CameraState, bool>(
      selector: (s) => s.isCapturing,
      builder: (context, busy) => ShutterButton(
        isBusy: busy,
        onPressed: () {
          Haptics.light();
          cubit.capture();
        },
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<BatchCubit, BatchState, ({int count, String? latest})>(
      selector: (s) => (
        count: s.imageCount,
        latest: s.currentBatch?.images.lastOrNull?.filePath,
      ),
      builder: (context, data) => BatchThumbnail(
        count: data.count,
        latestPath: data.latest,
        onTap: () => showBatchReviewSheet(context),
      ),
    );
  }
}

class _FlipButton extends StatelessWidget {
  const _FlipButton();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CameraCubit>();
    return BlocSelector<
      CameraCubit,
      CameraState,
      ({bool canSwitch, LensDirection direction})
    >(
      selector: (s) => (canSwitch: s.canSwitchLens, direction: s.lensDirection),
      builder: (context, data) => OverlayIconButton(
        icon: Icons.flip_camera_android_rounded,
        label: data.direction == LensDirection.back
            ? 'Switch to front camera'
            : 'Switch to back camera',
        onPressed: data.canSwitch ? cubit.switchLens : null,
      ),
    );
  }
}

class _UploadButton extends StatelessWidget {
  const _UploadButton();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<BatchCubit, BatchState, int>(
      selector: (s) => s.imageCount,
      builder: (context, count) => UploadBatchButton(
        count: count,
        onPressed: () => submitBatchAndOpenUploads(context),
      ),
    );
  }
}
