import 'dart:io';

import 'package:flutter/material.dart';
import 'package:snapsync/core/theme/app_semantic_colors.dart';
import 'package:snapsync/core/theme/app_spacing.dart';

/// A photo from a local file, decoded at a reduced size.
///
/// Decoding a full-resolution photo for a 56 dp thumbnail wastes tens of
/// megabytes per image, and a list of them exhausts memory. [logicalSize] is
/// the largest side the image is shown at; the decode width is that times the
/// device pixel ratio. A missing or unreadable file shows a placeholder.
class PhotoThumbnail extends StatelessWidget {
  const PhotoThumbnail({
    required this.path,
    required this.logicalSize,
    this.borderRadius = AppRadius.md,
    this.semanticLabel,
    this.dimmed = false,
    super.key,
  });

  /// Null means there is no file (for example after a successful upload).
  final String? path;
  final double logicalSize;
  final double borderRadius;
  final String? semanticLabel;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final placeholder = ColoredBox(
      color: semantic.surfaceHigh,
      child: Icon(
        Icons.image_outlined,
        color: semantic.textSecondary,
        size: logicalSize / 2.5,
      ),
    );

    final file = path;
    return Semantics(
      image: true,
      label: semanticLabel ?? 'Photo',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Opacity(
          opacity: dimmed ? 0.5 : 1,
          child: file == null
              ? placeholder
              : Image.file(
                  File(file),
                  fit: BoxFit.cover,
                  cacheWidth: (logicalSize * pixelRatio).round(),
                  gaplessPlayback: true,
                  // Show the placeholder until the first frame, so the slot is
                  // never an empty hole while a photo decodes.
                  frameBuilder: (context, child, frame, loadedSync) {
                    if (frame == null && !loadedSync) return placeholder;
                    return child;
                  },
                  // A deleted or corrupt file must not crash the list.
                  errorBuilder: (context, error, stack) => placeholder,
                ),
        ),
      ),
    );
  }
}
