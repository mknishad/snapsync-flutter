import 'package:flutter/material.dart';
import 'package:snapsync/core/theme/app_semantic_colors.dart';
import 'package:snapsync/core/utils/format_utils.dart';
import 'package:snapsync/domain/entities/upload_status.dart';
import 'package:snapsync/presentation/upload_manager/models/upload_item_view_model.dart';

/// How a status looks: always an icon and text as well as a colour.
class UploadStatusStyle {
  const UploadStatusStyle({
    required this.icon,
    required this.color,
    required this.label,
    this.detail,
  });

  final IconData icon;
  final Color color;

  /// Uppercase status text, for example "WAITING FOR CONNECTION".
  final String label;

  /// A second, quieter line (retry hint, "2m ago"), or null.
  final String? detail;

  /// Plain-language version for screen readers.
  String get spoken =>
      detail == null ? label.toLowerCase() : '${label.toLowerCase()}, $detail';

  static UploadStatusStyle of(
    BuildContext context,
    UploadItemViewModel item,
    DateTime now,
  ) {
    final semantic = context.semantic;
    return switch (item.status) {
      UploadStatus.waitingForConnection => UploadStatusStyle(
        icon: Icons.wifi_off_rounded,
        color: semantic.warning,
        label: 'WAITING FOR CONNECTION',
      ),
      UploadStatus.retrying => UploadStatusStyle(
        icon: Icons.sync_problem_rounded,
        color: semantic.warning,
        label: (item.attemptText ?? 'Retrying...').toUpperCase(),
        detail: item.nextRetryAt == null
            ? null
            : 'Next try ${FormatUtils.timeUntil(item.nextRetryAt!, now)}',
      ),
      UploadStatus.uploading => UploadStatusStyle(
        icon: Icons.cloud_upload_outlined,
        color: semantic.info,
        label: 'UPLOADING',
      ),
      UploadStatus.queued => UploadStatusStyle(
        icon: Icons.schedule_rounded,
        color: semantic.textSecondary,
        label: 'QUEUED',
      ),
      UploadStatus.failed => UploadStatusStyle(
        icon: Icons.error_outline_rounded,
        color: semantic.danger,
        label: 'FAILED',
      ),
      UploadStatus.uploaded => UploadStatusStyle(
        icon: Icons.check_circle_outline_rounded,
        color: semantic.success,
        label: 'SYNCED',
        detail: item.uploadedAt == null
            ? null
            : FormatUtils.timeAgo(item.uploadedAt!, now),
      ),
    };
  }
}
