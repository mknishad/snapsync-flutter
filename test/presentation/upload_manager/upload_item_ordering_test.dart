import 'package:flutter_test/flutter_test.dart';
import 'package:snapsync/domain/entities/upload_status.dart';
import 'package:snapsync/presentation/upload_manager/models/upload_item_ordering.dart';

import '../../support/ui_support.dart';

void main() {
  test(
    'uploading first, then retrying and waiting, queued, failed, synced',
    () {
      final items = [
        uploadItem(id: 'synced', status: UploadStatus.uploaded),
        uploadItem(id: 'failed', status: UploadStatus.failed),
        uploadItem(id: 'queued', status: UploadStatus.queued),
        uploadItem(id: 'waiting', status: UploadStatus.waitingForConnection),
        uploadItem(id: 'uploading', status: UploadStatus.uploading),
        uploadItem(id: 'retrying', status: UploadStatus.retrying),
      ];

      expect(orderUploadItems(items).map((i) => i.id), [
        'uploading',
        'waiting',
        'retrying',
        'queued',
        'failed',
        'synced',
      ]);
    },
  );

  test('items in the same group keep their original order', () {
    final items = [
      for (final id in ['a', 'b', 'c', 'd'])
        uploadItem(id: id, status: UploadStatus.queued),
    ];

    expect(orderUploadItems(items).map((i) => i.id), ['a', 'b', 'c', 'd']);
  });

  test('retrying and waiting share a group and keep their relative order', () {
    final items = [
      uploadItem(id: 'r1', status: UploadStatus.retrying),
      uploadItem(id: 'w1', status: UploadStatus.waitingForConnection),
      uploadItem(id: 'r2', status: UploadStatus.retrying),
    ];

    expect(orderUploadItems(items).map((i) => i.id), ['r1', 'w1', 'r2']);
  });

  test('does not change its input and handles empty', () {
    final items = [
      uploadItem(id: 'b', status: UploadStatus.uploaded),
      uploadItem(id: 'a', status: UploadStatus.uploading),
    ];

    orderUploadItems(items);

    expect(items.map((i) => i.id), ['b', 'a']);
    expect(orderUploadItems(const []), isEmpty);
  });

  test('pendingCount excludes synced items', () {
    final items = [
      uploadItem(id: '1', status: UploadStatus.uploaded),
      uploadItem(id: '2', status: UploadStatus.failed),
      uploadItem(id: '3', status: UploadStatus.queued),
    ];

    expect(pendingCount(items), 2);
    expect(pendingCount(const []), 0);
  });
}
