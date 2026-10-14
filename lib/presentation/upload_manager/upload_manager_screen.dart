import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:snapsync/app/app_routes.dart';
import 'package:snapsync/presentation/upload_manager/cubit/sync_cubit.dart';
import 'package:snapsync/presentation/upload_manager/cubit/sync_state.dart';
import 'package:snapsync/presentation/upload_manager/widgets/debug_panel.dart';
import 'package:snapsync/presentation/upload_manager/widgets/sync_message_listener.dart';
import 'package:snapsync/presentation/upload_manager/widgets/sync_refresher.dart';

class UploadManagerScreen extends StatelessWidget {
  const UploadManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: replace the raw-state body with the Upload Manager UI (see
    // reference screenshot). For now it shows the cubit state as plain text so
    // the sync engine can be tested by hand.
    return SyncMessageListener(
      child: SyncRefresher(
        child: Scaffold(
          appBar: AppBar(title: const Text('UploadManagerScreen')),
          body: BlocBuilder<SyncCubit, SyncState>(
            builder: (context, state) => _RawState(state: state),
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.camera),
              child: const Text('START NEW UPLOAD BATCH'),
            ),
          ),
        ),
      ),
    );
  }
}

class _RawState extends StatelessWidget {
  const _RawState({required this.state});

  final SyncState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SyncCubit>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'link: ${state.linkQuality.name}   paused: ${state.isPaused}   '
          'syncing: ${state.isSyncing}',
        ),
        Text(
          'overall: ${(state.overallProgress * 100).toStringAsFixed(0)}%  '
          '(${state.uploadedBytes}/${state.totalBytes} bytes)',
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: state.isPaused ? cubit.resumeAll : cubit.pauseAll,
              child: Text(state.isPaused ? 'Resume' : 'Pause'),
            ),
            OutlinedButton(
              onPressed: cubit.retryAllFailed,
              child: const Text('Retry failed'),
            ),
            OutlinedButton(
              onPressed: cubit.startSyncNow,
              child: const Text('Sync now'),
            ),
          ],
        ),
        const DebugPanel(),
        const Divider(),
        if (state.items.isEmpty) const Text('No uploads yet.'),
        for (final item in state.items)
          ListTile(
            dense: true,
            title: Text('${item.displayName}  [${item.status.name}]'),
            subtitle: Text(
              [
                '${(item.progress * 100).toStringAsFixed(0)}%',
                if (item.attemptText != null) item.attemptText!,
                if (item.lastError != null) item.lastError!,
              ].join('  |  '),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Retry',
                  onPressed: () => cubit.retryItem(item.id),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Remove',
                  onPressed: () => cubit.removeItem(item.id),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
