import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:snapsync/presentation/camera/cubit/camera_cubit.dart';

/// Releases the camera when the app leaves the foreground and re-opens it (and
/// re-checks the permission) when it returns.
///
/// `inactive` also fires for short interruptions such as the permission dialog
/// or the notification shade; the cubit's pause/resume handle that cheaply and
/// safely, so no special case is made here.
class CameraLifecycleObserver extends StatefulWidget {
  const CameraLifecycleObserver({required this.child, super.key});

  final Widget child;

  @override
  State<CameraLifecycleObserver> createState() =>
      _CameraLifecycleObserverState();
}

class _CameraLifecycleObserverState extends State<CameraLifecycleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cubit = context.read<CameraCubit>();
    switch (state) {
      case AppLifecycleState.inactive ||
          AppLifecycleState.paused ||
          AppLifecycleState.hidden:
        unawaited(cubit.pause());
      case AppLifecycleState.resumed:
        unawaited(cubit.resume());
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
