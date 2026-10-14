import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:snapsync/app/app_routes.dart';
import 'package:snapsync/core/di/injection.dart';
import 'package:snapsync/core/theme/app_semantic_colors.dart';
import 'package:snapsync/core/theme/app_spacing.dart';
import 'package:snapsync/data/remote/mock_upload_config.dart';
import 'package:snapsync/domain/entities/link_quality.dart';
import 'package:snapsync/presentation/upload_manager/cubit/sync_cubit.dart';
import 'package:snapsync/presentation/upload_manager/cubit/sync_state.dart';
import 'package:snapsync/presentation/upload_manager/models/upload_item_ordering.dart';
import 'package:snapsync/presentation/upload_manager/widgets/empty_queue_view.dart';
import 'package:snapsync/presentation/upload_manager/widgets/link_status_pill.dart';
import 'package:snapsync/presentation/upload_manager/widgets/mock_network_sheet.dart';
import 'package:snapsync/presentation/upload_manager/widgets/sync_message_listener.dart';
import 'package:snapsync/presentation/upload_manager/widgets/sync_refresher.dart';
import 'package:snapsync/presentation/upload_manager/widgets/sync_summary_card.dart';
import 'package:snapsync/presentation/upload_manager/widgets/upload_items_sliver.dart';

/// The root screen: sync progress and the list of pending uploads. Thin: it
/// wires the cubit to small widgets and holds no logic of its own.
class UploadManagerScreen extends StatelessWidget {
  const UploadManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SyncMessageListener(
      child: SyncRefresher(
        child: Scaffold(
          appBar: const _UploadManagerAppBar(),
          body: const _Body(),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.all(AppSpacing.lg),
            child: FilledButton(
              onPressed: () => _startBatch(context),
              child: const Text('START NEW UPLOAD BATCH'),
            ),
          ),
        ),
      ),
    );
  }
}

void _startBatch(BuildContext context) {
  Navigator.of(context).pushNamed(AppRoutes.camera);
}

class _UploadManagerAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _UploadManagerAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    // The Upload Manager is the root screen, so there is normally nothing to go
    // back to; the back arrow appears whenever there is.
    return AppBar(
      title: const Text(
        'Upload Manager',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        BlocSelector<SyncCubit, SyncState, LinkQuality>(
          selector: (state) => state.linkQuality,
          // widthFactor: 1 keeps the pill as wide as its content. A plain
          // Center would take all the width and squeeze the title away.
          // The pill may take at most 42 percent of the width, so large text
          // shortens its label (the icon and spoken label still say it all)
          // instead of pushing the title out.
          builder: (context, quality) => Center(
            widthFactor: 1,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.42,
              ),
              child: LinkStatusPill(quality: quality),
            ),
          ),
        ),
        PopupMenuButton<_MenuAction>(
          tooltip: 'More options',
          onSelected: (action) {
            switch (action) {
              case _MenuAction.mockNetwork:
                showMockNetworkSheet(context, getIt<MockUploadConfig>());
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: _MenuAction.mockNetwork,
              child: Text('Mock network (demo)'),
            ),
          ],
        ),
      ],
    );
  }
}

enum _MenuAction { mockNetwork }

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SyncCubit>();
    return RefreshIndicator(
      onRefresh: () async {
        cubit.refresh();
        // refresh() is fire-and-forget; give the list a moment to update so
        // the spinner does not vanish before anything can change.
        await Future<void>.delayed(const Duration(milliseconds: 600));
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              0,
            ),
            sliver: SliverToBoxAdapter(child: _Summary()),
          ),
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            sliver: SliverToBoxAdapter(child: _PendingHeader()),
          ),
          BlocSelector<SyncCubit, SyncState, bool>(
            selector: (state) => state.items.isEmpty,
            builder: (context, isEmpty) {
              if (isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyQueueView(onStart: () => _startBatch(context)),
                );
              }
              return const SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                sliver: UploadItemsSliver(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SyncCubit>();
    return BlocSelector<
      SyncCubit,
      SyncState,
      ({double progress, int uploaded, int total, bool paused})
    >(
      selector: (state) => (
        progress: state.overallProgress,
        uploaded: state.uploadedBytes,
        total: state.totalBytes,
        paused: state.isPaused,
      ),
      builder: (context, data) => SyncSummaryCard(
        progress: data.progress,
        uploadedBytes: data.uploaded,
        totalBytes: data.total,
        isPaused: data.paused,
        onTogglePause: data.paused ? cubit.resumeAll : cubit.pauseAll,
      ),
    );
  }
}

class _PendingHeader extends StatelessWidget {
  const _PendingHeader();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SyncCubit, SyncState, int>(
      selector: (state) => pendingCount(state.items),
      builder: (context, count) => Semantics(
        header: true,
        child: Text(
          'PENDING UPLOADS ($count)',
          style: context.semantic.caption,
        ),
      ),
    );
  }
}
