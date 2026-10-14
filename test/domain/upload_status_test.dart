import 'package:flutter_test/flutter_test.dart';
import 'package:snapsync/domain/entities/upload_status.dart';
import 'package:snapsync/domain/errors/domain_errors.dart';

void main() {
  // Independent copy of the documented transition table.
  const legal = <UploadStatus, Set<UploadStatus>>{
    UploadStatus.queued: {
      UploadStatus.uploading,
      UploadStatus.waitingForConnection,
    },
    UploadStatus.waitingForConnection: {
      UploadStatus.uploading,
      UploadStatus.queued,
    },
    UploadStatus.uploading: {
      UploadStatus.uploaded,
      UploadStatus.retrying,
      UploadStatus.waitingForConnection,
      UploadStatus.failed,
      UploadStatus.queued,
    },
    UploadStatus.retrying: {
      UploadStatus.uploading,
      UploadStatus.waitingForConnection,
      UploadStatus.queued,
    },
    UploadStatus.failed: {UploadStatus.queued},
    UploadStatus.uploaded: <UploadStatus>{},
  };

  group('transitions', () {
    for (final from in UploadStatus.values) {
      for (final to in UploadStatus.values) {
        final isLegal = legal[from]!.contains(to);
        test(
          '${from.name} -> ${to.name} is ${isLegal ? 'legal' : 'illegal'}',
          () {
            if (isLegal) {
              expect(from.canTransitionTo(to), isTrue);
              expect(() => from.ensureCanTransitionTo(to), returnsNormally);
            } else {
              expect(from.canTransitionTo(to), isFalse);
              expect(
                () => from.ensureCanTransitionTo(to),
                throwsA(
                  isA<IllegalStatusTransitionError>()
                      .having((e) => e.from, 'from', from)
                      .having((e) => e.to, 'to', to),
                ),
              );
            }
          },
        );
      }
    }

    test('uploaded is terminal', () {
      for (final to in UploadStatus.values) {
        expect(UploadStatus.uploaded.canTransitionTo(to), isFalse);
      }
    });
  });

  test('isUploadable covers queued, waitingForConnection and retrying', () {
    expect(UploadStatus.values.where((s) => s.isUploadable).toSet(), {
      UploadStatus.queued,
      UploadStatus.waitingForConnection,
      UploadStatus.retrying,
    });
  });
}
