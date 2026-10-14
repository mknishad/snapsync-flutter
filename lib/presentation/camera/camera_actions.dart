import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:snapsync/presentation/batch/cubit/batch_cubit.dart';
import 'package:snapsync/presentation/batch/cubit/batch_state.dart';

/// Back to the Upload Manager, which is the root screen.
void goToUploadManager(BuildContext context) {
  Navigator.of(context).popUntil((route) => route.isFirst);
}

/// Submits the open batch, confirms briefly, and returns to the Upload Manager.
/// If the submit fails, the user stays on the camera and is told so.
Future<void> submitBatchAndOpenUploads(BuildContext context) async {
  final batch = context.read<BatchCubit>();
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  final count = batch.state.imageCount;

  await batch.submitBatch();

  if (batch.state.status == BatchStatus.failure) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Could not submit the batch. Try again.')),
      );
    return;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          '$count ${count == 1 ? 'photo' : 'photos'} queued. Uploading...',
        ),
      ),
    );
  navigator.popUntil((route) => route.isFirst);
}
