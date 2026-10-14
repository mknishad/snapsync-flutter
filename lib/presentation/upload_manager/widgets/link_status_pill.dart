import 'package:flutter/material.dart';
import 'package:snapsync/core/theme/app_semantic_colors.dart';
import 'package:snapsync/core/theme/app_spacing.dart';
import 'package:snapsync/domain/entities/link_quality.dart';

/// "STABLE LINK", "UNSTABLE" or "OFFLINE", with an icon so the state is not
/// carried by colour alone.
class LinkStatusPill extends StatelessWidget {
  const LinkStatusPill({required this.quality, super.key});

  final LinkQuality quality;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final (color, icon, label, spoken) = switch (quality) {
      LinkQuality.stable => (
        semantic.success,
        Icons.check_circle_rounded,
        'STABLE LINK',
        'Connection stable',
      ),
      LinkQuality.unstable => (
        semantic.warning,
        Icons.network_check_rounded,
        'UNSTABLE',
        'Connection unstable',
      ),
      LinkQuality.offline => (
        semantic.danger,
        Icons.cloud_off_rounded,
        'OFFLINE',
        'Device offline',
      ),
    };

    return Semantics(
      label: spoken,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs + 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: semantic.statusLabel.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
