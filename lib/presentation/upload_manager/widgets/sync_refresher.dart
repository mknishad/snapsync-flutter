import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:snapsync/core/constants/app_constants.dart';
import 'package:snapsync/presentation/upload_manager/cubit/sync_cubit.dart';

/// Keeps the Upload Manager current with changes made by the background
/// isolate, which cannot notify this isolate: it refreshes when the app comes
/// back to the foreground and on a light timer while this screen is the
/// current route.
class SyncRefresher extends StatefulWidget {
  const SyncRefresher({required this.child, super.key});

  final Widget child;

  @override
  State<SyncRefresher> createState() => _SyncRefresherState();
}

class _SyncRefresherState extends State<SyncRefresher>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(AppConstants.uploadManagerRefreshInterval, (_) {
      if (ModalRoute.of(context)?.isCurrent ?? true) {
        context.read<SyncCubit>().refresh();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(context.read<SyncCubit>().onAppResumed());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
