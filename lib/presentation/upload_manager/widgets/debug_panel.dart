import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:snapsync/core/constants/mock_upload_mode.dart';
import 'package:snapsync/core/di/injection.dart';
import 'package:snapsync/data/remote/mock_upload_config.dart';
import 'package:snapsync/domain/repositories/sync_scheduler.dart';

/// Debug builds only: switch the mock mode and trigger a background run, for
/// manual testing on a device. The mode is stored in the shared database, so
/// the background isolate follows it too.
class DebugPanel extends StatefulWidget {
  const DebugPanel({super.key});

  @override
  State<DebugPanel> createState() => _DebugPanelState();
}

class _DebugPanelState extends State<DebugPanel> {
  MockUploadMode? _mode;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final mode = await getIt<MockUploadConfig>().currentMode();
    if (mounted) setState(() => _mode = mode);
  }

  Future<void> _setMode(MockUploadMode? mode) async {
    if (mode == null) return;
    await getIt<MockUploadConfig>().setMode(mode);
    if (mounted) setState(() => _mode = mode);
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('DEBUG'),
            Row(
              children: [
                const Text('Mock mode: '),
                DropdownButton<MockUploadMode>(
                  value: _mode,
                  items: [
                    for (final mode in MockUploadMode.values)
                      DropdownMenuItem(value: mode, child: Text(mode.name)),
                  ],
                  onChanged: _setMode,
                ),
              ],
            ),
            OutlinedButton(
              onPressed: () => unawaited(getIt<SyncScheduler>().debugRunNow()),
              child: const Text('Run background sync now'),
            ),
          ],
        ),
      ),
    );
  }
}
