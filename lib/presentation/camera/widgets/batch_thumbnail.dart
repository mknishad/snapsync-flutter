import 'package:flutter/material.dart';
import 'package:snapsync/core/theme/app_semantic_colors.dart';
import 'package:snapsync/core/theme/app_spacing.dart';
import 'package:snapsync/presentation/common/widgets/photo_thumbnail.dart';

/// Rounded thumbnail of the latest photo with a blue count badge. With no
/// photos it is an empty outlined slot with no badge and does nothing.
class BatchThumbnail extends StatelessWidget {
  const BatchThumbnail({
    required this.count,
    required this.latestPath,
    required this.onTap,
    super.key,
  });

  final int count;
  final String? latestPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final hasPhotos = count > 0;

    return Semantics(
      button: hasPhotos,
      label: hasPhotos
          ? 'Review $count ${count == 1 ? 'photo' : 'photos'} in this batch'
          : 'No photos in this batch yet',
      excludeSemantics: true,
      onTap: hasPhotos ? onTap : null,
      child: GestureDetector(
        onTap: hasPhotos ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: AppSizes.minTapTarget + AppSpacing.md,
          height: AppSizes.minTapTarget + AppSpacing.md,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (hasPhotos)
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: semantic.onOverlay, width: 2),
                  ),
                  child: PhotoThumbnail(
                    key: ValueKey(latestPath),
                    path: latestPath,
                    logicalSize: AppSizes.thumbnail,
                    semanticLabel: 'Latest photo',
                  ),
                )
              else
                Container(
                  width: AppSizes.thumbnail,
                  height: AppSizes.thumbnail,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    color: semantic.overlay,
                    border: Border.all(
                      color: semantic.onOverlay.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Icon(
                    Icons.photo_library_outlined,
                    color: semantic.onOverlay.withValues(alpha: 0.7),
                  ),
                ),
              if (hasPhotos)
                Positioned(
                  top: -AppSpacing.xs,
                  right: -AppSpacing.xs,
                  child: _CountBadge(count: count),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs + 1),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: semantic.info,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text('$count', maxLines: 1, style: semantic.overlayLabel),
    );
  }
}
