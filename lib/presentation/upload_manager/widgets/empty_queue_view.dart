import 'package:flutter/material.dart';
import 'package:snapsync/core/theme/app_semantic_colors.dart';
import 'package:snapsync/core/theme/app_spacing.dart';

/// Shown when nothing has been captured or queued yet.
class EmptyQueueView extends StatelessWidget {
  const EmptyQueueView({required this.onStart, super.key});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_upload_outlined,
              size: 64,
              color: semantic.textSecondary,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Nothing to upload yet',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Capture a batch of photos and they will sync automatically, '
              'even if the connection drops.',
              textAlign: TextAlign.center,
              style: TextStyle(color: semantic.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('START NEW UPLOAD BATCH'),
            ),
          ],
        ),
      ),
    );
  }
}
