import 'package:snapsync/domain/entities/upload_status.dart';
import 'package:snapsync/presentation/upload_manager/models/upload_item_view_model.dart';

/// Display order of the Pending Uploads list: uploading first, then retrying
/// and waiting, then queued, failed, and finally synced. Items in the same
/// group keep the order they came in (newest batch first, capture order).
List<UploadItemViewModel> orderUploadItems(List<UploadItemViewModel> items) {
  final indexed =
      [for (var i = 0; i < items.length; i++) (index: i, item: items[i])]
        ..sort((a, b) {
          final byGroup = _rank(a.item.status).compareTo(_rank(b.item.status));
          return byGroup != 0 ? byGroup : a.index.compareTo(b.index);
        });
  return [for (final entry in indexed) entry.item];
}

int _rank(UploadStatus status) => switch (status) {
  UploadStatus.uploading => 0,
  UploadStatus.retrying || UploadStatus.waitingForConnection => 1,
  UploadStatus.queued => 2,
  UploadStatus.failed => 3,
  UploadStatus.uploaded => 4,
};

/// How many items are not synced yet.
int pendingCount(List<UploadItemViewModel> items) =>
    items.where((i) => i.status != UploadStatus.uploaded).length;
