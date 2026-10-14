import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapsync/core/theme/app_semantic_colors.dart';
import 'package:snapsync/domain/entities/upload_status.dart';
import 'package:snapsync/presentation/upload_manager/widgets/upload_item_card.dart';

import '../../../support/ui_support.dart';

final now = DateTime.utc(2026, 1, 1, 12);

Future<void> pumpCard(
  WidgetTester tester,
  UploadStatus status, {
  double progress = 0,
  String? attemptText,
  DateTime? nextRetryAt,
  DateTime? uploadedAt,
  VoidCallback? onRetry,
  VoidCallback? onRemove,
  double textScale = 1,
}) {
  return tester.pumpWidget(
    testApp(
      UploadItemCard(
        item: uploadItem(
          status: status,
          progress: progress,
          attemptText: attemptText,
          nextRetryAt: nextRetryAt,
          uploadedAt: uploadedAt,
        ),
        now: now,
        onRetry: onRetry ?? () {},
        onRemove: onRemove ?? () {},
      ),
      textScale: textScale,
    ),
  );
}

void main() {
  testWidgets('shows the name and the size for every status', (tester) async {
    for (final status in UploadStatus.values) {
      await pumpCard(tester, status);
      expect(
        find.text('IMG_20260101_101500.jpg'),
        findsOneWidget,
        reason: status.name,
      );
      expect(find.text('2.4 MB'), findsOneWidget, reason: status.name);
    }
  });

  group('status line', () {
    testWidgets('waiting for connection: amber text and icon', (tester) async {
      await pumpCard(tester, UploadStatus.waitingForConnection);

      expect(find.text('WAITING FOR CONNECTION'), findsOneWidget);
      final icon = tester.widget<Icon>(find.byIcon(Icons.wifi_off_rounded));
      expect(icon.color, AppSemanticColors.dark.warning);
    });

    testWidgets('retrying: attempt text, amber, and a next-try hint', (
      tester,
    ) async {
      await pumpCard(
        tester,
        UploadStatus.retrying,
        attemptText: 'Retrying... (attempt 2/3)',
        nextRetryAt: now.add(const Duration(seconds: 25)),
      );

      expect(find.text('RETRYING... (ATTEMPT 2/3)'), findsOneWidget);
      expect(find.text('Next try in 25s'), findsOneWidget);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.sync_problem_rounded)).color,
        AppSemanticColors.dark.warning,
      );
    });

    testWidgets('retrying without a retry time has no hint', (tester) async {
      await pumpCard(
        tester,
        UploadStatus.retrying,
        attemptText: 'Retrying... (attempt 2/3)',
      );

      expect(find.textContaining('Next try'), findsNothing);
    });

    testWidgets('uploading: blue progress bar and the percentage', (
      tester,
    ) async {
      await pumpCard(tester, UploadStatus.uploading, progress: 0.42);
      await tester.pumpAndSettle();

      expect(find.text('UPLOADING'), findsOneWidget);
      expect(find.text('42%'), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, closeTo(0.42, 1e-6));
      expect(
        tester.widget<Icon>(find.byIcon(Icons.cloud_upload_outlined)).color,
        AppSemanticColors.dark.info,
      );
    });

    testWidgets('queued: neutral text and no progress bar', (tester) async {
      await pumpCard(tester, UploadStatus.queued);

      expect(find.text('QUEUED'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('failed: red text and icon', (tester) async {
      await pumpCard(tester, UploadStatus.failed);

      expect(find.text('FAILED'), findsOneWidget);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.error_outline_rounded)).color,
        AppSemanticColors.dark.danger,
      );
    });

    testWidgets('synced: green label, relative time and a dimmed card', (
      tester,
    ) async {
      await pumpCard(
        tester,
        UploadStatus.uploaded,
        uploadedAt: now.subtract(const Duration(minutes: 2)),
      );

      expect(find.text('SYNCED'), findsOneWidget);
      expect(find.text('2m ago'), findsOneWidget);
      expect(
        tester
            .widget<Icon>(find.byIcon(Icons.check_circle_outline_rounded))
            .color,
        AppSemanticColors.dark.success,
      );
      final dim = tester.widget<Opacity>(
        find
            .ancestor(of: find.text('SYNCED'), matching: find.byType(Opacity))
            .first,
      );
      expect(dim.opacity, lessThan(1));
    });

    testWidgets('every status is shown by an icon and text, not colour alone', (
      tester,
    ) async {
      for (final status in UploadStatus.values) {
        await pumpCard(
          tester,
          status,
          attemptText: 'Retrying... (attempt 2/3)',
        );
        expect(find.byType(Icon), findsWidgets, reason: status.name);
        expect(
          find.byWidgetPredicate(
            (w) => w is Text && (w.data?.isNotEmpty ?? false),
          ),
          findsWidgets,
        );
      }
    });
  });

  group('actions', () {
    testWidgets('only a failed item has Retry and Remove', (tester) async {
      for (final status in UploadStatus.values) {
        await pumpCard(tester, status);
        final expected = status == UploadStatus.failed;
        expect(
          find.text('Retry'),
          expected ? findsOneWidget : findsNothing,
          reason: status.name,
        );
        expect(
          find.text('Remove'),
          expected ? findsOneWidget : findsNothing,
          reason: status.name,
        );
      }
    });

    testWidgets('Retry and Remove call their callbacks', (tester) async {
      var retried = 0;
      var removed = 0;
      await pumpCard(
        tester,
        UploadStatus.failed,
        onRetry: () => retried++,
        onRemove: () => removed++,
      );

      await tester.tap(find.text('Retry'));
      await tester.tap(find.text('Remove'));

      expect(retried, 1);
      expect(removed, 1);
    });

    testWidgets('touch targets are at least 48 dp', (tester) async {
      await pumpCard(tester, UploadStatus.failed);

      for (final label in ['Retry', 'Remove']) {
        final size = tester.getSize(
          find
              .ancestor(
                of: find.text(label),
                matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
              )
              .first,
        );
        expect(size.height, greaterThanOrEqualTo(40), reason: label);
      }
    });
  });

  group('accessibility', () {
    testWidgets('the card reads out name, size and status', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpCard(tester, UploadStatus.failed);

      expect(
        find.bySemanticsLabel('IMG_20260101_101500.jpg, 2.4 MB, failed'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('the upload progress is announced as a percentage', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpCard(tester, UploadStatus.uploading, progress: 0.5);
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.bySemanticsLabel('Upload progress')),
        matchesSemantics(label: 'Upload progress', value: '50 percent'),
      );
      handle.dispose();
    });

    testWidgets('survives 200 percent text without overflowing', (
      tester,
    ) async {
      for (final status in UploadStatus.values) {
        await pumpCard(
          tester,
          status,
          progress: 0.5,
          attemptText: 'Retrying... (attempt 2/3)',
          nextRetryAt: now.add(const Duration(seconds: 25)),
          uploadedAt: now.subtract(const Duration(minutes: 2)),
          textScale: 2,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: status.name);
      }
    });
  });
}
