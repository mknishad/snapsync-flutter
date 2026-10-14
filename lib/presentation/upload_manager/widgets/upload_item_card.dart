import 'package:flutter/material.dart';
import 'package:snapsync/core/theme/app_semantic_colors.dart';
import 'package:snapsync/core/theme/app_spacing.dart';
import 'package:snapsync/core/utils/format_utils.dart';
import 'package:snapsync/domain/entities/upload_status.dart';
import 'package:snapsync/presentation/common/widgets/photo_thumbnail.dart';
import 'package:snapsync/presentation/upload_manager/models/upload_item_view_model.dart';
import 'package:snapsync/presentation/upload_manager/widgets/upload_status_style.dart';

/// One upload in the list: thumbnail, name, size and a status line. Plain data
/// in, callbacks out, so it can be tested on its own.
class UploadItemCard extends StatelessWidget {
  const UploadItemCard({
    required this.item,
    required this.now,
    required this.onRetry,
    required this.onRemove,
    super.key,
  });

  final UploadItemViewModel item;

  /// For relative times ("2m ago", "next try in 25s").
  final DateTime now;
  final VoidCallback onRetry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final style = UploadStatusStyle.of(context, item, now);
    final synced = item.status == UploadStatus.uploaded;
    final size = FormatUtils.bytes(item.sizeBytes);

    return Semantics(
      container: true,
      label: '${item.displayName}, $size, ${style.spoken}',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PhotoThumbnail(
                path: item.thumbnailPath,
                logicalSize: 56,
                dimmed: synced,
                semanticLabel: 'Photo ${item.displayName}',
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Opacity(
                  opacity: synced ? 0.65 : 1,
                  child: _Details(
                    item: item,
                    style: style,
                    size: size,
                    onRetry: onRetry,
                    onRemove: onRemove,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({
    required this.item,
    required this.style,
    required this.size,
    required this.onRetry,
    required this.onRemove,
  });

  final UploadItemViewModel item;
  final UploadStatusStyle style;
  final String size;
  final VoidCallback onRetry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Text(size, style: TextStyle(color: semantic.textSecondary)),
        const SizedBox(height: AppSpacing.xs),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _StatusLine(
            key: ValueKey('${item.status}-${item.attemptText}'),
            style: style,
          ),
        ),
        if (item.status == UploadStatus.uploading)
          _UploadProgress(progress: item.progress),
        if (item.status == UploadStatus.failed)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                ),
                TextButton.icon(
                  onPressed: onRemove,
                  style: TextButton.styleFrom(foregroundColor: semantic.danger),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Remove'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.style, super.key});

  final UploadStatusStyle style;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(style.icon, size: 14, color: style.color),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                style.label,
                style: semantic.statusLabel.copyWith(color: style.color),
              ),
            ),
          ],
        ),
        if (style.detail != null) Text(style.detail!, style: semantic.small),
      ],
    );
  }
}

class _UploadProgress extends StatelessWidget {
  const _UploadProgress({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final clamped = progress.isNaN ? 0.0 : progress.clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Semantics(
        container: true,
        label: 'Upload progress',
        value: '${(clamped * 100).round()} percent',
        excludeSemantics: true,
        child: Row(
          children: [
            Expanded(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: clamped),
                duration: const Duration(milliseconds: 250),
                builder: (context, value, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(value: value, minHeight: 6),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              FormatUtils.percent(clamped),
              style: context.semantic.statusLabel.copyWith(
                color: context.semantic.info,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
