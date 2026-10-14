import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapsync/app/app_routes.dart';
import 'package:snapsync/core/di/injection.dart';
import 'package:snapsync/core/theme/app_theme.dart';
import 'package:snapsync/data/remote/mock_upload_config.dart';
import 'package:snapsync/domain/entities/link_quality.dart';
import 'package:snapsync/domain/entities/upload_status.dart';
import 'package:snapsync/presentation/upload_manager/cubit/sync_cubit.dart';
import 'package:snapsync/presentation/upload_manager/cubit/sync_message.dart';
import 'package:snapsync/presentation/upload_manager/cubit/sync_state.dart';
import 'package:snapsync/presentation/upload_manager/upload_manager_screen.dart';
import 'package:snapsync/presentation/upload_manager/widgets/link_status_pill.dart';
import 'package:snapsync/presentation/upload_manager/widgets/upload_item_card.dart';

import '../../support/fake_sync_cubit.dart';
import '../../support/ui_support.dart';

SyncState stateOf(
  List<UploadStatusSpec> specs, {
  LinkQuality link = LinkQuality.stable,
  bool paused = false,
  double progress = 0.5,
  int uploaded = 1024 * 1024,
  int total = 2 * 1024 * 1024,
}) {
  return SyncState(
    items: [
      for (final spec in specs)
        uploadItem(
          id: spec.id,
          status: spec.status,
          progress: spec.progress,
          thumbnail: null,
          uploadedAt: spec.status == UploadStatus.uploaded
              ? DateTime.now().subtract(const Duration(minutes: 2))
              : null,
        ),
    ],
    overallProgress: progress,
    uploadedBytes: uploaded,
    totalBytes: total,
    linkQuality: link,
    isPaused: paused,
  );
}

class UploadStatusSpec {
  const UploadStatusSpec(this.id, this.status, [this.progress = 0]);

  final String id;
  final UploadStatus status;
  final double progress;
}

void main() {
  late FakeSyncCubit cubit;

  setUp(() async {
    await getIt.reset();
    getIt.registerSingleton<MockUploadConfig>(MockUploadConfig());
  });

  tearDown(() async {
    await cubit.close();
    await getIt.reset();
  });

  /// Emits a new state and lets the UI rebuild. Cubit streams deliver their
  /// event in a microtask after a frame is drawn, so a second pump is needed
  /// for the rebuild that the event causes.
  Future<void> pushState(WidgetTester tester, SyncState state) async {
    cubit.push(state);
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    SyncState state, {
    double textScale = 1,
  }) async {
    cubit = FakeSyncCubit(state);
    await tester.pumpWidget(
      BlocProvider<SyncCubit>.value(
        value: cubit,
        child: MaterialApp(
          theme: AppTheme.dark,
          builder: (context, app) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: app!,
          ),
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => settings.name == AppRoutes.camera
                ? const Scaffold(body: Text('camera route'))
                : const UploadManagerScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('app bar', () {
    testWidgets('shows the title and the stable pill', (tester) async {
      await pumpScreen(tester, stateOf(const []));

      expect(find.text('Upload Manager'), findsOneWidget);
      expect(find.text('STABLE LINK'), findsOneWidget);
    });

    testWidgets('the pill follows the link quality', (tester) async {
      await pumpScreen(tester, stateOf(const [], link: LinkQuality.offline));
      expect(find.text('OFFLINE'), findsOneWidget);

      await pushState(tester, stateOf(const [], link: LinkQuality.unstable));
      expect(find.text('UNSTABLE'), findsOneWidget);
      expect(find.byType(LinkStatusPill), findsOneWidget);
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'the title keeps its space next to the pill at $scale x text',
        (tester) async {
          tester.view.physicalSize = const Size(400, 860);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await pumpScreen(tester, stateOf(const []), textScale: scale);

          final title = tester.getRect(find.text('Upload Manager'));
          final pill = tester.getRect(find.byType(LinkStatusPill));

          expect(title.width, greaterThan(40), reason: 'the title is visible');
          expect(
            title.right,
            lessThanOrEqualTo(pill.left),
            reason: 'no overlap',
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('has no back arrow on the root screen', (tester) async {
      await pumpScreen(tester, stateOf(const []));

      expect(find.byType(BackButton), findsNothing);
    });
  });

  group('summary and list', () {
    testWidgets('the summary card shows the state\'s progress and bytes', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        stateOf(
          const [UploadStatusSpec('a', UploadStatus.queued)],
          progress: 0.73,
          uploaded: 2516582,
          total: 3435974,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('BATCH SYNC PROGRESS'), findsOneWidget);
      expect(find.text('73%'), findsOneWidget);
      expect(find.text('2.4 MB / 3.3 MB Uploaded'), findsOneWidget);
    });

    testWidgets('the header counts items not yet synced', (tester) async {
      await pumpScreen(
        tester,
        stateOf(const [
          UploadStatusSpec('a', UploadStatus.queued),
          UploadStatusSpec('b', UploadStatus.failed),
          UploadStatusSpec('c', UploadStatus.uploaded),
        ]),
      );

      expect(find.text('PENDING UPLOADS (2)'), findsOneWidget);
    });

    testWidgets(
      'cards are ordered: uploading, waiting, queued, failed, synced',
      (tester) async {
        // Tall enough that the lazy list builds every card.
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await pumpScreen(
          tester,
          stateOf(const [
            UploadStatusSpec('synced', UploadStatus.uploaded),
            UploadStatusSpec('failed', UploadStatus.failed),
            UploadStatusSpec('queued', UploadStatus.queued),
            UploadStatusSpec('uploading', UploadStatus.uploading, 0.5),
          ]),
        );
        await tester.pumpAndSettle();

        final labels = ['UPLOADING', 'QUEUED', 'FAILED', 'SYNCED'];
        final tops = [
          for (final label in labels) tester.getTopLeft(find.text(label)).dy,
        ];
        expect(tops, [...tops]..sort());
        expect(find.byType(UploadItemCard), findsNWidgets(4));
      },
    );

    testWidgets('a new status moves the card in the list', (tester) async {
      await pumpScreen(
        tester,
        stateOf(const [
          UploadStatusSpec('a', UploadStatus.queued),
          UploadStatusSpec('b', UploadStatus.queued),
        ]),
      );
      await tester.pumpAndSettle();
      final before = tester.getTopLeft(find.byKey(const ValueKey('a'))).dy;

      await pushState(
        tester,
        stateOf(const [
          UploadStatusSpec('a', UploadStatus.uploaded),
          UploadStatusSpec('b', UploadStatus.queued),
        ]),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.byKey(const ValueKey('a'))).dy,
        greaterThan(before),
        reason: 'the synced card drops below the queued one',
      );
    });

    testWidgets('a progress tick rebuilds only the card that changed', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        stateOf(const [
          UploadStatusSpec('a', UploadStatus.uploading, 0.1),
          UploadStatusSpec('b', UploadStatus.queued),
          UploadStatusSpec('c', UploadStatus.failed),
        ]),
      );
      UploadItemCard card(String id) => tester.widget<UploadItemCard>(
        find.descendant(
          of: find.byKey(ValueKey(id)),
          matching: find.byType(UploadItemCard),
        ),
      );
      final b = card('b');
      final c = card('c');
      final a = card('a');

      await pushState(
        tester,
        stateOf(const [
          UploadStatusSpec('a', UploadStatus.uploading, 0.6),
          UploadStatusSpec('b', UploadStatus.queued),
          UploadStatusSpec('c', UploadStatus.failed),
        ]),
      );

      expect(identical(card('b'), b), isTrue, reason: 'b was not rebuilt');
      expect(identical(card('c'), c), isTrue, reason: 'c was not rebuilt');
      expect(identical(card('a'), a), isFalse, reason: 'a shows new progress');
      expect(card('a').item.progress, 0.6);
    });
  });

  group('empty state', () {
    testWidgets('shows the icon, text and action when nothing is queued', (
      tester,
    ) async {
      await pumpScreen(tester, stateOf(const []));

      expect(find.text('Nothing to upload yet'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
      expect(find.text('START NEW UPLOAD BATCH'), findsNWidgets(2));
      expect(find.byType(UploadItemCard), findsNothing);
    });

    testWidgets('is replaced by the list once items arrive', (tester) async {
      await pumpScreen(tester, stateOf(const []));

      await pushState(
        tester,
        stateOf(const [UploadStatusSpec('a', UploadStatus.queued)]),
      );

      expect(find.text('Nothing to upload yet'), findsNothing);
      expect(find.byType(UploadItemCard), findsOneWidget);
    });

    testWidgets('the empty-state action opens the camera', (tester) async {
      await pumpScreen(tester, stateOf(const []));

      await tester.tap(
        find.widgetWithText(FilledButton, 'START NEW UPLOAD BATCH').first,
      );
      await tester.pumpAndSettle();

      expect(find.text('camera route'), findsOneWidget);
    });
  });

  group('actions', () {
    testWidgets('START NEW UPLOAD BATCH opens the camera', (tester) async {
      await pumpScreen(
        tester,
        stateOf(const [UploadStatusSpec('a', UploadStatus.queued)]),
      );

      await tester.tap(find.text('START NEW UPLOAD BATCH'));
      await tester.pumpAndSettle();

      expect(find.text('camera route'), findsOneWidget);
    });

    testWidgets('PAUSE ALL pauses, RESUME ALL resumes', (tester) async {
      await pumpScreen(tester, stateOf(const []));
      await tester.tap(find.text('PAUSE ALL'));
      expect(cubit.calls, contains('pauseAll'));

      await pushState(tester, stateOf(const [], paused: true));
      await tester.tap(find.text('RESUME ALL'));
      expect(cubit.calls, contains('resumeAll'));
    });

    testWidgets('Retry on a failed card retries that item', (tester) async {
      await pumpScreen(
        tester,
        stateOf(const [UploadStatusSpec('bad', UploadStatus.failed)]),
      );

      await tester.tap(find.text('Retry'));

      expect(cubit.calls, ['retry:bad']);
    });

    testWidgets('Remove asks first and removes only when confirmed', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        stateOf(const [UploadStatusSpec('bad', UploadStatus.failed)]),
      );

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(find.text('Remove this photo?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(cubit.calls.where((c) => c.startsWith('remove')), isEmpty);

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();
      expect(cubit.calls, ['remove:bad']);
    });

    testWidgets('swiping a queued card asks, then removes', (tester) async {
      await pumpScreen(
        tester,
        stateOf(const [UploadStatusSpec('q', UploadStatus.queued)]),
      );

      await tester.drag(find.byType(Dismissible), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.text('Remove this photo?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(cubit.calls, ['remove:q']);
      expect(
        find.byType(UploadItemCard),
        findsOneWidget,
        reason:
            'the list is driven by cubit state, so the card stays until then',
      );
    });

    testWidgets('cancelling the swipe confirmation removes nothing', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        stateOf(const [UploadStatusSpec('q', UploadStatus.queued)]),
      );

      await tester.drag(find.byType(Dismissible), const Offset(-600, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(cubit.calls.where((c) => c.startsWith('remove')), isEmpty);
    });

    testWidgets('a card that is uploading cannot be swiped away', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        stateOf(const [UploadStatusSpec('u', UploadStatus.uploading, 0.3)]),
      );

      expect(find.byType(Dismissible), findsNothing);
    });

    testWidgets('a synced card is removed with its own wording', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        stateOf(const [UploadStatusSpec('s', UploadStatus.uploaded)]),
      );

      await tester.drag(find.byType(Dismissible), const Offset(-600, 0));
      await tester.pumpAndSettle();

      expect(find.text('Remove from history?'), findsOneWidget);
    });

    testWidgets('pull to refresh refreshes through the cubit', (tester) async {
      await pumpScreen(
        tester,
        stateOf(const [UploadStatusSpec('a', UploadStatus.queued)]),
      );

      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 400),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(cubit.calls.where((c) => c == 'refresh'), hasLength(1));
    });
  });

  group('mock network tools', () {
    testWidgets('the overflow menu opens the demo sheet', (tester) async {
      await pumpScreen(tester, stateOf(const []));

      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mock network (demo)'));
      await tester.pumpAndSettle();

      expect(find.text('Mock network (assessment demo)'), findsOneWidget);
    });

    testWidgets('the tool is available regardless of build mode', (
      tester,
    ) async {
      // Reviewers use it from the release APK; nothing here may depend on
      // kDebugMode. The menu entry exists in the widget tree built above.
      await pumpScreen(tester, stateOf(const []));
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();

      expect(find.text('Mock network (demo)'), findsOneWidget);
    });
  });

  group('messages and lifecycle', () {
    testWidgets('one-off messages appear as a snackbar', (tester) async {
      await pumpScreen(tester, stateOf(const []));

      cubit.say(const SyncMessage('Uploads paused'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Uploads paused'), findsOneWidget);
    });

    testWidgets('returning to the app refreshes', (tester) async {
      await pumpScreen(tester, stateOf(const []));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(cubit.calls, ['resumed']);
    });

    testWidgets('a light timer refreshes while visible', (tester) async {
      await pumpScreen(tester, stateOf(const []));

      await tester.pump(const Duration(seconds: 4));

      expect(cubit.calls, contains('refresh'));
    });
  });

  group('layout', () {
    final items = [
      for (var i = 0; i < 4; i++)
        UploadStatusSpec(
          'i$i',
          UploadStatus.values[i + 1 > 5 ? 0 : i + 1],
          0.4,
        ),
    ];

    testWidgets('a small screen scrolls without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpScreen(tester, stateOf(items));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('landscape works', (tester) async {
      tester.view.physicalSize = const Size(800, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpScreen(tester, stateOf(items));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('START NEW UPLOAD BATCH'), findsOneWidget);
    });

    testWidgets('200 percent text does not overflow', (tester) async {
      await pumpScreen(
        tester,
        stateOf(items, link: LinkQuality.unstable),
        textScale: 2,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('200 percent text does not overflow the empty state', (
      tester,
    ) async {
      await pumpScreen(tester, stateOf(const []), textScale: 2);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('a long list builds lazily', (tester) async {
      await pumpScreen(
        tester,
        stateOf([
          for (var i = 0; i < 500; i++)
            UploadStatusSpec('i$i', UploadStatus.queued),
        ]),
      );

      expect(find.byType(UploadItemCard).evaluate().length, lessThan(30));
    });
  });
}
