import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:snapsync/presentation/camera/cubit/camera_cubit.dart';
import 'package:snapsync/presentation/camera/cubit/camera_message.dart';

/// Shows each [CameraMessage] as a snackbar.
class CameraMessageListener extends StatefulWidget {
  const CameraMessageListener({required this.child, super.key});

  final Widget child;

  @override
  State<CameraMessageListener> createState() => _CameraMessageListenerState();
}

class _CameraMessageListenerState extends State<CameraMessageListener> {
  StreamSubscription<CameraMessage>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = context.read<CameraCubit>().messages.listen((message) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(cameraMessageText(message))));
    });
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// User-facing text. Never contains exception text.
String cameraMessageText(CameraMessage message) {
  return switch (message) {
    CameraMessage.captureFailed => 'Could not take the photo. Try again.',
    CameraMessage.storageFailed =>
      'Could not save the photo. Check that the device has free storage.',
    CameraMessage.flashUnavailable => 'Flash is not available on this camera.',
    CameraMessage.noOtherCamera => 'This device has no other camera.',
    CameraMessage.zoomFailed => 'Could not change the zoom.',
    CameraMessage.settingsUnavailable => 'Could not open settings.',
  };
}
