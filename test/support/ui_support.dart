import 'package:flutter/material.dart';
import 'package:snapsync/core/theme/app_theme.dart';
import 'package:snapsync/domain/entities/upload_status.dart';
import 'package:snapsync/presentation/upload_manager/models/upload_item_view_model.dart';

/// Hosts a widget in the app theme, with an optional text scale.
Widget testApp(Widget child, {double textScale = 1, bool scaffold = true}) {
  return MaterialApp(
    theme: AppTheme.dark,
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: app!,
    ),
    home: scaffold ? Scaffold(body: child) : child,
  );
}

UploadItemViewModel uploadItem({
  String id = 'i1',
  UploadStatus status = UploadStatus.queued,
  double progress = 0,
  String name = 'IMG_20260101_101500.jpg',
  int size = 2516582,
  String? thumbnail,
  String? attemptText,
  String? lastError,
  DateTime? nextRetryAt,
  DateTime? uploadedAt,
}) {
  return UploadItemViewModel(
    id: id,
    batchId: 'b1',
    displayName: name,
    sizeBytes: size,
    status: status,
    progress: progress,
    thumbnailPath: thumbnail,
    attemptText: attemptText,
    lastError: lastError,
    nextRetryAt: nextRetryAt,
    uploadedAt: uploadedAt,
  );
}
