import 'package:flutter/material.dart';

/// "UPLOAD BATCH (n)". Disabled while the batch is empty.
class UploadBatchButton extends StatelessWidget {
  const UploadBatchButton({
    required this.count,
    required this.onPressed,
    super.key,
  });

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: count > 0,
      label: count > 0
          ? 'Upload batch, $count ${count == 1 ? 'photo' : 'photos'}'
          : 'Upload batch, no photos yet',
      excludeSemantics: true,
      onTap: count > 0 ? onPressed : null,
      child: FilledButton.icon(
        onPressed: count > 0 ? onPressed : null,
        icon: const Icon(Icons.upload_rounded),
        label: Text(
          'UPLOAD BATCH ($count)',
          maxLines: 2,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
