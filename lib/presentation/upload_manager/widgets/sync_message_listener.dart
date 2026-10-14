import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:snapsync/presentation/upload_manager/cubit/sync_cubit.dart';
import 'package:snapsync/presentation/upload_manager/cubit/sync_message.dart';

/// Shows each one-off [SyncMessage] as a snackbar.
class SyncMessageListener extends StatefulWidget {
  const SyncMessageListener({required this.child, super.key});

  final Widget child;

  @override
  State<SyncMessageListener> createState() => _SyncMessageListenerState();
}

class _SyncMessageListenerState extends State<SyncMessageListener> {
  StreamSubscription<SyncMessage>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = context.read<SyncCubit>().messages.listen((message) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message.text),
            backgroundColor:
                message.isError ? Theme.of(context).colorScheme.error : null,
          ),
        );
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
