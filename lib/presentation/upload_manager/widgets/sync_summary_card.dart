import 'package:flutter/material.dart';
import 'package:snapsync/core/theme/app_semantic_colors.dart';
import 'package:snapsync/core/theme/app_spacing.dart';
import 'package:snapsync/core/utils/format_utils.dart';

/// "BATCH SYNC PROGRESS": overall percentage, a thick progress bar, bytes
/// uploaded over bytes in the queue, and the pause/resume button.
class SyncSummaryCard extends StatelessWidget {
  const SyncSummaryCard({
    required this.progress,
    required this.uploadedBytes,
    required this.totalBytes,
    required this.isPaused,
    required this.onTogglePause,
    super.key,
  });

  /// 0.0 to 1.0.
  final double progress;
  final int uploadedBytes;
  final int totalBytes;
  final bool isPaused;
  final VoidCallback onTogglePause;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final clamped = progress.isNaN ? 0.0 : progress.clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text('BATCH SYNC PROGRESS', style: semantic.caption),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  FormatUtils.percent(clamped),
                  style: semantic.metric.copyWith(color: semantic.info),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              container: true,
              label: 'Batch sync progress',
              value: '${(clamped * 100).round()} percent',
              excludeSemantics: true,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: clamped),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                builder: (context, value, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(value: value),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${FormatUtils.bytes(uploadedBytes)} / '
                    '${FormatUtils.bytes(totalBytes)} Uploaded',
                    style: TextStyle(color: semantic.textSecondary),
                  ),
                ),
                TextButton(
                  onPressed: onTogglePause,
                  child: Text(isPaused ? 'RESUME ALL' : 'PAUSE ALL'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
