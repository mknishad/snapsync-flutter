import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:snapsync/core/theme/app_semantic_colors.dart';
import 'package:snapsync/core/theme/app_spacing.dart';
import 'package:snapsync/domain/entities/upload_status.dart';
import 'package:snapsync/presentation/common/widgets/confirm_dialog.dart';
import 'package:snapsync/presentation/upload_manager/cubit/sync_cubit.dart';
import 'package:snapsync/presentation/upload_manager/cubit/sync_state.dart';
import 'package:snapsync/presentation/upload_manager/models/upload_item_view_model.dart';
import 'package:snapsync/presentation/upload_manager/widgets/upload_item_card.dart';

/// One list row wired to the cubit. It selects only its own item, so a
/// progress tick rebuilds just the card that is uploading, not the whole list.
class UploadItemTile extends StatelessWidget {
  const UploadItemTile({required this.itemId, super.key});

  final String itemId;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SyncCubit, SyncState, UploadItemViewModel?>(
      selector: (state) {
        for (final item in state.items) {
          if (item.id == itemId) return item;
        }
        return null;
      },
      builder: (context, item) {
        if (item == null) return const SizedBox.shrink();
        return _SwipeToRemove(item: item);
      },
    );
  }
}

class _SwipeToRemove extends StatelessWidget {
  const _SwipeToRemove({required this.item});

  final UploadItemViewModel item;

  /// An image that is uploading right now cannot be removed.
  bool get _removable => item.status != UploadStatus.uploading;

  /// Asks first, then removes. Returns false either way: the list updates from
  /// the cubit's state, and a Dismissible that is told "dismissed" must leave
  /// the tree immediately, which a stream-driven list cannot guarantee.
  Future<bool> _confirmAndRemove(BuildContext context) async {
    final cubit = context.read<SyncCubit>();
    final synced = item.status == UploadStatus.uploaded;
    final confirmed = await showConfirmDialog(
      context,
      title: synced ? 'Remove from history?' : 'Remove this photo?',
      message: synced
          ? 'It is already uploaded. This only clears it from the list.'
          : 'It will be deleted from this device and will not be uploaded.',
      confirmLabel: 'Remove',
    );
    if (confirmed) await cubit.removeItem(item.id);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final card = UploadItemCard(
      item: item,
      now: DateTime.now(),
      onRetry: () => context.read<SyncCubit>().retryItem(item.id),
      onRemove: () => _confirmAndRemove(context),
    );
    if (!_removable) return card;

    final semantic = context.semantic;
    return Semantics(
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'Remove'): () =>
            _confirmAndRemove(context),
      },
      child: Dismissible(
        key: ValueKey('dismiss-${item.id}'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => _confirmAndRemove(context),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          decoration: BoxDecoration(
            color: semantic.danger.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Icon(Icons.delete_outline_rounded, color: semantic.danger),
        ),
        child: card,
      ),
    );
  }
}
