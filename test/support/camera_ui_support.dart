import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:snapsync/domain/camera/zoom_preset.dart';
import 'package:snapsync/domain/entities/capture_batch.dart';
import 'package:snapsync/domain/entities/captured_image.dart';
import 'package:snapsync/presentation/batch/cubit/batch_cubit.dart';
import 'package:snapsync/presentation/batch/cubit/batch_state.dart';
import 'package:snapsync/presentation/camera/cubit/camera_cubit.dart';
import 'package:snapsync/presentation/camera/cubit/camera_state.dart';

import 'ui_support.dart';

const presets3 = [
  ZoomPreset(label: '0.5x', targetZoom: 0.5),
  ZoomPreset(label: '1x', targetZoom: 1),
  ZoomPreset(label: '2x', targetZoom: 2),
];

CameraState readyState({
  double zoom = 1,
  double minZoom = 0.5,
  double maxZoom = 8,
  bool supportsFlash = true,
  bool canSwitchLens = true,
  bool isCapturing = false,
  List<ZoomPreset> presets = presets3,
}) {
  return CameraState(
    status: CameraStatus.ready,
    presets: presets,
    zoom: zoom,
    minZoom: minZoom,
    maxZoom: maxZoom,
    supportsFlash: supportsFlash,
    supportsFocus: true,
    canSwitchLens: canSwitchLens,
    isCapturing: isCapturing,
  );
}

CapturedImage photo(int n) => CapturedImage(
  id: 'p$n',
  batchId: 'b',
  filePath: '/nonexistent/p$n.jpg',
  fileSizeBytes: 1000 * n,
  capturedAt: DateTime.utc(2026, 1, 1, 10, n),
);

BatchState batchWith(int count) {
  return BatchState(
    status: BatchStatus.ready,
    currentBatch: count == 0
        ? null
        : CaptureBatch(
            id: 'b',
            createdAt: DateTime.utc(2026),
            images: [for (var i = 1; i <= count; i++) photo(i)],
          ),
  );
}

/// Hosts a screen or widget with both cubits provided above the MaterialApp,
/// like the real app, plus a root route so navigation back can be observed.
Widget cameraHost({
  required CameraCubit camera,
  required BatchCubit batch,
  required Widget child,
  double textScale = 1,
}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<CameraCubit>.value(value: camera),
      BlocProvider<BatchCubit>.value(value: batch),
    ],
    child: testApp(child, textScale: textScale, scaffold: false),
  );
}

/// A root screen with a button that opens [screen], so popping back to the root
/// can be verified.
Widget rootThenScreen({
  required CameraCubit camera,
  required BatchCubit batch,
  required Widget screen,
}) {
  return cameraHost(
    camera: camera,
    batch: batch,
    child: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () =>
                Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => screen)),
            child: const Text('open camera'),
          ),
        ),
      ),
    ),
  );
}
