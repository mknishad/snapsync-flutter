import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:snapsync/core/theme/app_semantic_colors.dart';
import 'package:snapsync/core/theme/app_spacing.dart';
import 'package:snapsync/domain/entities/captured_image.dart';
import 'package:snapsync/presentation/batch/cubit/batch_cubit.dart';
import 'package:snapsync/presentation/batch/cubit/batch_state.dart';
import 'package:snapsync/presentation/camera/widgets/overlay_icon_button.dart';
import 'package:snapsync/presentation/common/widgets/confirm_dialog.dart';
import 'package:snapsync/presentation/common/widgets/photo_thumbnail.dart';

/// Opens the review sheet for the batch being captured.
Future<void> showBatchReviewSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => const BatchReviewSheet(),
  );
}

/// Grid of the open batch's photos, with per-photo delete and "Discard batch".
/// Closes itself when the batch becomes empty.
class BatchReviewSheet extends StatelessWidget {
  const BatchReviewSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BatchCubit, BatchState>(
      listenWhen: (previous, current) =>
          previous.imageCount > 0 && current.imageCount == 0,
      listener: (context, state) => Navigator.of(context).maybePop(),
      builder: (context, state) {
        final images = state.currentBatch?.images ?? const <CapturedImage>[];
        return FractionallySizedBox(
          heightFactor: 0.85,
          child: Column(
            children: [
              _Header(count: images.length),
              Expanded(child: _PhotoGrid(images: images)),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    '$count ${count == 1 ? 'photo' : 'photos'} in this batch',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          TextButton.icon(
            onPressed: count == 0 ? null : () => _discard(context, count),
            style: TextButton.styleFrom(foregroundColor: semantic.danger),
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text('Discard batch'),
          ),
        ],
      ),
    );
  }

  Future<void> _discard(BuildContext context, int count) async {
    final cubit = context.read<BatchCubit>();
    final confirmed = await showConfirmDialog(
      context,
      title: 'Discard this batch?',
      message:
          'All $count ${count == 1 ? 'photo' : 'photos'} will be deleted '
          'from this device. This cannot be undone.',
      confirmLabel: 'Discard',
    );
    if (confirmed) await cubit.discardBatch();
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.images});

  final List<CapturedImage> images;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return Center(
        child: Text(
          'No photos yet.',
          style: TextStyle(color: context.semantic.textSecondary),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 140,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        final image = images[index];
        return _PhotoTile(
          key: ValueKey(image.id),
          image: image,
          number: index + 1,
        );
      },
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.image, required this.number, super.key});

  final CapturedImage image;
  final int number;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PhotoThumbnail(
          path: image.filePath,
          logicalSize: 140,
          semanticLabel: 'Photo $number',
        ),
        Positioned(
          top: 0,
          right: 0,
          child: OverlayIconButton(
            icon: Icons.delete_outline_rounded,
            label: 'Delete photo $number',
            onPressed: () => _delete(context),
          ),
        ),
      ],
    );
  }

  Future<void> _delete(BuildContext context) async {
    final cubit = context.read<BatchCubit>();
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete this photo?',
      message: 'It will be removed from the batch.',
      confirmLabel: 'Delete',
    );
    if (confirmed) await cubit.deleteImage(image.id);
  }
}
