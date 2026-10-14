import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapsync/core/constants/app_constants.dart';
import 'package:snapsync/core/theme/app_semantic_colors.dart';
import 'package:snapsync/presentation/camera/cubit/focus_indicator.dart';
import 'package:snapsync/presentation/camera/widgets/focus_indicator_view.dart';

import '../../../support/ui_support.dart';

FocusIndicator indicator(
  Offset position, [
  FocusPhase phase = FocusPhase.focusing,
  int id = 1,
]) {
  return FocusIndicator(id: id, position: position, phase: phase);
}

Future<void> pump(WidgetTester tester, FocusIndicator value) {
  return tester.pumpWidget(
    testApp(
      Stack(
        children: [
          FocusIndicatorView(key: ValueKey(value.id), indicator: value),
        ],
      ),
    ),
  );
}

double opacityOf(WidgetTester tester) => tester
    .widget<Opacity>(
      find.descendant(
        of: find.byType(FocusIndicatorView),
        matching: find.byType(Opacity),
      ),
    )
    .opacity;

double scaleOf(WidgetTester tester) => tester
    .widget<Transform>(
      find.descendant(
        of: find.byType(FocusIndicatorView),
        matching: find.byType(Transform),
      ),
    )
    .transform
    .getMaxScaleOnAxis();

Color? borderColour(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find
        .descendant(
          of: find.byType(FocusIndicatorView),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  return ((box.decoration as BoxDecoration).border! as Border).top.color;
}

void main() {
  group('position', () {
    testWidgets('is centred exactly on the tapped coordinates', (tester) async {
      for (final point in const [
        Offset(100, 200),
        Offset(0, 0),
        Offset(333.5, 417.25),
        Offset(780, 580),
      ]) {
        await pump(tester, indicator(point));

        expect(
          tester.getCenter(find.byType(FocusIndicatorView)),
          point,
          reason: '$point',
        );
      }
    });

    testWidgets('has the indicator size', (tester) async {
      await pump(tester, indicator(const Offset(200, 200)));

      expect(
        tester.getSize(find.byType(FocusIndicatorView)),
        const Size(FocusIndicatorView.size, FocusIndicatorView.size),
      );
    });

    testWidgets('a new tap moves it to the new position', (tester) async {
      await pump(
        tester,
        indicator(const Offset(100, 100), FocusPhase.focusing, 1),
      );
      await pump(
        tester,
        indicator(const Offset(300, 250), FocusPhase.focusing, 2),
      );

      expect(
        tester.getCenter(find.byType(FocusIndicatorView)),
        const Offset(300, 250),
      );
    });

    testWidgets('does not intercept touches', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        testApp(
          Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
                child: const SizedBox.expand(),
              ),
              FocusIndicatorView(indicator: indicator(const Offset(200, 200))),
            ],
          ),
        ),
      );

      await tester.tapAt(const Offset(200, 200));

      expect(taps, 1);
    });
  });

  group('animation', () {
    testWidgets('scales in, holds, then fades out and ends transparent', (
      tester,
    ) async {
      await pump(tester, indicator(const Offset(200, 200)));
      expect(scaleOf(tester), closeTo(1.5, 0.01), reason: 'starts large');

      await tester.pump(const Duration(milliseconds: 200));
      expect(
        scaleOf(tester),
        closeTo(1, 0.01),
        reason: 'settled to normal size',
      );
      expect(opacityOf(tester), 1, reason: 'held');

      await tester.pump(
        AppConstants.focusIndicatorDuration - const Duration(milliseconds: 200),
      );
      expect(opacityOf(tester), closeTo(0, 0.01), reason: 'faded out');
    });

    testWidgets('is fully visible through the hold', (tester) async {
      await pump(tester, indicator(const Offset(200, 200)));

      await tester.pump(const Duration(milliseconds: 700));

      expect(opacityOf(tester), 1);
    });

    testWidgets('a locked mark stays on screen', (tester) async {
      await pump(tester, indicator(const Offset(200, 200), FocusPhase.locked));

      await tester.pump(AppConstants.focusIndicatorDuration * 3);

      expect(opacityOf(tester), 1);
      expect(scaleOf(tester), 1);
    });

    testWidgets('locking mid-flight stops the fade', (tester) async {
      await pump(tester, indicator(const Offset(200, 200), FocusPhase.done));
      await tester.pump(const Duration(milliseconds: 1300));
      expect(opacityOf(tester), lessThan(1), reason: 'already fading');

      await tester.pumpWidget(
        testApp(
          Stack(
            children: [
              FocusIndicatorView(
                key: const ValueKey(1),
                indicator: indicator(const Offset(200, 200), FocusPhase.locked),
              ),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(opacityOf(tester), 1);
    });
  });

  group('looks', () {
    testWidgets('focusing is a ring, done is a square', (tester) async {
      await pump(tester, indicator(const Offset(200, 200)));
      var box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(FocusIndicatorView),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect((box.decoration as BoxDecoration).shape, BoxShape.circle);

      await pump(tester, indicator(const Offset(200, 200), FocusPhase.done, 2));
      box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(FocusIndicatorView),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect((box.decoration as BoxDecoration).shape, BoxShape.rectangle);
    });

    testWidgets('locked is amber with a lock', (tester) async {
      await pump(tester, indicator(const Offset(200, 200), FocusPhase.locked));

      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
      expect(borderColour(tester), AppSemanticColors.dark.warning);
    });

    testWidgets('failed is red with a cross', (tester) async {
      await pump(tester, indicator(const Offset(200, 200), FocusPhase.failed));

      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(borderColour(tester), AppSemanticColors.dark.danger);
    });

    testWidgets('focusing and done are white', (tester) async {
      for (final phase in [FocusPhase.focusing, FocusPhase.done]) {
        await pump(tester, indicator(const Offset(200, 200), phase));
        expect(
          borderColour(tester),
          AppSemanticColors.dark.onOverlay,
          reason: phase.name,
        );
      }
    });

    testWidgets('the four phases are visually distinct', (tester) async {
      final looks = <String>{};
      for (final phase in FocusPhase.values) {
        await pump(
          tester,
          indicator(const Offset(200, 200), phase, phase.index + 1),
        );
        final box = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(FocusIndicatorView),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        final decoration = box.decoration as BoxDecoration;
        looks.add(
          '${decoration.shape}|${borderColour(tester)}|'
          '${find.byIcon(Icons.lock_rounded).evaluate().length}|'
          '${find.byIcon(Icons.close_rounded).evaluate().length}',
        );
      }
      // focusing (ring) and done (square) differ by shape; locked and failed by
      // colour and icon.
      expect(looks, hasLength(4));
    });
  });
}
