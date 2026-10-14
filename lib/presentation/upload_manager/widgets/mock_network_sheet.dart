import 'dart:async';

import 'package:flutter/material.dart';
import 'package:snapsync/core/constants/mock_upload_mode.dart';
import 'package:snapsync/core/error/failure.dart';
import 'package:snapsync/core/theme/app_semantic_colors.dart';
import 'package:snapsync/core/theme/app_spacing.dart';
import 'package:snapsync/data/remote/mock_upload_config.dart';

/// Demo control for choosing what the simulated network does.
///
/// This exists, and is available in release builds on purpose, because the
/// assessment provides no real API: reviewers need a way to see the offline,
/// low-bandwidth and retry behaviour in the APK. It is a labelled demo tool,
/// not a user feature, so it is tucked into the Upload Manager's overflow menu.
Future<void> showMockNetworkSheet(
  BuildContext context,
  MockUploadConfig config,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => MockNetworkSheet(config: config),
  );
}

class MockNetworkSheet extends StatefulWidget {
  const MockNetworkSheet({required this.config, super.key});

  final MockUploadConfig config;

  @override
  State<MockNetworkSheet> createState() => _MockNetworkSheetState();
}

class _MockNetworkSheetState extends State<MockNetworkSheet> {
  // Purely the sheet's own selection; the mode itself lives in MockUploadConfig.
  MockUploadMode? _selected;
  bool _failed = false;

  static const _descriptions = <MockUploadMode, (String, String)>{
    MockUploadMode.alwaysSuccess: ('Always succeed', 'Every upload completes.'),
    MockUploadMode.alwaysNoInternet: (
      'Offline (no internet)',
      'Nothing gets through; items wait for a connection.',
    ),
    MockUploadMode.alwaysLowBandwidth: (
      'Low bandwidth',
      'Uploads stall part-way and are retried with growing delays.',
    ),
    MockUploadMode.alwaysServerError: (
      'Server error',
      'The server answers with an error; uploads are retried.',
    ),
    MockUploadMode.flaky: ('Flaky', 'A random mix of successes and failures.'),
  };

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final mode = await widget.config.currentMode();
      if (mounted) setState(() => _selected = mode);
    } on Failure {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _choose(MockUploadMode mode) async {
    try {
      await widget.config.setMode(mode);
      if (mounted) {
        setState(() {
          _selected = mode;
          _failed = false;
        });
      }
    } on Failure {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Mock network (assessment demo)',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'There is no real server for this assessment, so uploads are '
            'simulated. Choose how the simulated network behaves. The change '
            'applies immediately, including to background syncs.',
            style: TextStyle(color: semantic.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_failed)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                'Could not read or save the setting.',
                style: TextStyle(color: semantic.danger),
              ),
            ),
          for (final mode in MockUploadMode.values)
            _ModeTile(
              label: _descriptions[mode]!.$1,
              description: _descriptions[mode]!.$2,
              selected: _selected == mode,
              onTap: () => _choose(mode),
            ),
        ],
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: '$label. $description',
      excludeSemantics: true,
      onTap: onTap,
      child: ListTile(
        onTap: onTap,
        contentPadding: EdgeInsets.zero,
        minVerticalPadding: AppSpacing.sm,
        leading: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: selected ? semantic.info : semantic.textSecondary,
        ),
        title: Text(label),
        subtitle: Text(
          description,
          style: TextStyle(color: semantic.textSecondary),
        ),
      ),
    );
  }
}
