import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapsync/core/constants/mock_upload_mode.dart';
import 'package:snapsync/data/remote/mock_upload_config.dart';
import 'package:snapsync/presentation/upload_manager/widgets/mock_network_sheet.dart';

import '../../../support/ui_support.dart';

void main() {
  testWidgets('is clearly labelled as a demo control', (tester) async {
    await tester.pumpWidget(
      testApp(MockNetworkSheet(config: MockUploadConfig())),
    );
    await tester.pump();

    expect(find.text('Mock network (assessment demo)'), findsOneWidget);
    expect(find.textContaining('no real server'), findsOneWidget);
  });

  testWidgets('lists every mode with a one-line description', (tester) async {
    await tester.pumpWidget(
      testApp(MockNetworkSheet(config: MockUploadConfig())),
    );
    await tester.pump();

    for (final label in [
      'Always succeed',
      'Offline (no internet)',
      'Low bandwidth',
      'Server error',
      'Flaky',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Every upload completes.'), findsOneWidget);
    expect(find.textContaining('wait for a connection'), findsOneWidget);
  });

  testWidgets('shows the current mode as selected', (tester) async {
    final config = MockUploadConfig(mode: MockUploadMode.alwaysLowBandwidth);
    await tester.pumpWidget(testApp(MockNetworkSheet(config: config)));
    await tester.pump();

    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(4));
    final selectedTile = find.ancestor(
      of: find.text('Low bandwidth'),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(
        of: selectedTile,
        matching: find.byIcon(Icons.radio_button_checked),
      ),
      findsOneWidget,
    );
  });

  testWidgets('choosing a mode updates the config immediately', (tester) async {
    final config = MockUploadConfig();
    await tester.pumpWidget(testApp(MockNetworkSheet(config: config)));
    await tester.pump();

    for (final entry in {
      'Offline (no internet)': MockUploadMode.alwaysNoInternet,
      'Server error': MockUploadMode.alwaysServerError,
      'Flaky': MockUploadMode.flaky,
      'Always succeed': MockUploadMode.alwaysSuccess,
      'Low bandwidth': MockUploadMode.alwaysLowBandwidth,
    }.entries) {
      await tester.tap(find.text(entry.key));
      await tester.pump();

      expect(config.mode, entry.value, reason: entry.key);
      expect(await config.currentMode(), entry.value);
    }
  });

  testWidgets('the selection moves with the tap', (tester) async {
    final config = MockUploadConfig();
    await tester.pumpWidget(testApp(MockNetworkSheet(config: config)));
    await tester.pump();

    await tester.tap(find.text('Flaky'));
    await tester.pump();

    final flaky = find.ancestor(
      of: find.text('Flaky'),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(
        of: flaky,
        matching: find.byIcon(Icons.radio_button_checked),
      ),
      findsOneWidget,
    );
  });

  testWidgets('modes are announced as one mutually exclusive group', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      testApp(MockNetworkSheet(config: MockUploadConfig())),
    );
    await tester.pump();

    final node = tester.getSemantics(
      find.bySemanticsLabel(RegExp('^Always succeed')),
    );
    expect(node.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
    handle.dispose();
  });

  testWidgets('opens as a bottom sheet from showMockNetworkSheet', (
    tester,
  ) async {
    final config = MockUploadConfig();
    await tester.pumpWidget(
      testApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showMockNetworkSheet(context, config),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Mock network (assessment demo)'), findsOneWidget);
  });

  testWidgets('survives 200 percent text', (tester) async {
    await tester.pumpWidget(
      testApp(MockNetworkSheet(config: MockUploadConfig()), textScale: 2),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
