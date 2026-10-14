import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:snapsync/core/theme/app_spacing.dart';
import 'package:snapsync/presentation/upload_manager/cubit/sync_cubit.dart';
import 'package:snapsync/presentation/upload_manager/cubit/sync_state.dart';
import 'package:snapsync/presentation/upload_manager/models/upload_item_ordering.dart';
import 'package:snapsync/presentation/upload_manager/widgets/upload_item_tile.dart';

/// The ordered list of uploads. It rebuilds only when the set or order of items
/// changes (a status change moves a card), never on a progress tick.
class UploadItemsSliver extends StatelessWidget {
  const UploadItemsSliver({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SyncCubit, SyncState, _ItemOrder>(
      selector: (state) => _ItemOrder([
        for (final item in orderUploadItems(state.items)) item.id,
      ]),
      builder: (context, order) {
        return SliverList.separated(
          itemCount: order.ids.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) {
            final id = order.ids[index];
            return UploadItemTile(key: ValueKey(id), itemId: id);
          },
        );
      },
    );
  }
}

/// Value-comparable list of ids, so BlocSelector can tell "same order".
class _ItemOrder extends Equatable {
  const _ItemOrder(this.ids);

  final List<String> ids;

  @override
  List<Object?> get props => [ids];
}
