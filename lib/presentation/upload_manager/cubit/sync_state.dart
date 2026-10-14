import 'package:equatable/equatable.dart';
import 'package:snapsync/domain/entities/link_quality.dart';
import 'package:snapsync/presentation/upload_manager/models/batch_summary.dart';
import 'package:snapsync/presentation/upload_manager/models/upload_item_view_model.dart';

class SyncState extends Equatable {
  const SyncState({
    this.items = const [],
    this.batches = const [],
    this.overallProgress = 0,
    this.uploadedBytes = 0,
    this.totalBytes = 0,
    this.linkQuality = LinkQuality.offline,
    this.isPaused = false,
    this.isSyncing = false,
  });

  /// Every image in a submitted batch, newest batch first.
  final List<UploadItemViewModel> items;
  final List<BatchSummary> batches;

  /// 0.0 to 1.0: bytes uploaded over bytes in the queue (batches that still
  /// have unfinished work), including the part of the running upload done.
  final double overallProgress;
  final int uploadedBytes;
  final int totalBytes;
  final LinkQuality linkQuality;
  final bool isPaused;
  final bool isSyncing;

  SyncState copyWith({
    List<UploadItemViewModel>? items,
    List<BatchSummary>? batches,
    double? overallProgress,
    int? uploadedBytes,
    int? totalBytes,
    LinkQuality? linkQuality,
    bool? isPaused,
    bool? isSyncing,
  }) {
    return SyncState(
      items: items ?? this.items,
      batches: batches ?? this.batches,
      overallProgress: overallProgress ?? this.overallProgress,
      uploadedBytes: uploadedBytes ?? this.uploadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      linkQuality: linkQuality ?? this.linkQuality,
      isPaused: isPaused ?? this.isPaused,
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }

  @override
  List<Object?> get props => [
        items,
        batches,
        overallProgress,
        uploadedBytes,
        totalBytes,
        linkQuality,
        isPaused,
        isSyncing,
      ];
}
