import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/app/platform/form_factor.dart';
import 'package:carina/core/core.dart';
import 'package:carina/features/guide/src/guide_controller.dart';
import 'package:carina/features/guide/src/guide_grid.dart';
import 'package:carina/features/guide/src/guide_info_panel.dart';
import 'package:carina/player/player_api.dart';

import 'guide_test_support.dart';

GuideFocus _focus(WidgetTester tester) =>
    tester.widget<GuideInfoPanel>(find.byType(GuideInfoPanel)).focus!;

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await settleDrift(tester, rounds: 4);
}

/// The widget that owns primary focus sits inside [T].
bool _focusIn<T extends Widget>() {
  final context = FocusManager.instance.primaryFocus?.context;
  return context != null &&
      (context.widget is T ||
          context.findAncestorWidgetOfExactType<T>() != null);
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('TV: D-pad walks the grid, scrolls time, OK plays', (
    tester,
  ) async {
    final fx = await importGuideFixture(tester);
    final now = fixedNow();
    final actions = RecordingGuideActions();
    await pumpGuide(
      tester,
      fx,
      now: now,
      actions: actions,
      extra: [formFactorProvider.overrideWithValue(FormFactor.tv)],
    );
    expect(_focusIn<GuideGrid>(), isTrue);
    final scrollables = find.descendant(
      of: find.byType(GuideGrid),
      matching: find.byType(Scrollable),
    );
    final h = tester.state<ScrollableState>(scrollables.at(1)).position;
    final start = h.pixels;

    await _key(tester, LogicalKeyboardKey.arrowDown);
    expect(_focus(tester).row, 1);
    for (var i = 0; i < 8; i++) {
      await _key(tester, LogicalKeyboardKey.arrowRight);
    }
    expect(h.pixels, greaterThan(start), reason: 'time scrolls with focus');
    await _key(tester, LogicalKeyboardKey.arrowLeft);

    // OK on the focused cell acts like a click on it.
    await _key(tester, LogicalKeyboardKey.arrowUp);
    expect(_focus(tester).row, 0);
    await _key(tester, LogicalKeyboardKey.home);
    await _key(tester, LogicalKeyboardKey.enter);
    expect(actions.played, hasLength(1));
    expect(actions.played.single, isA<LivePlayRequest>());
    await finishGuide(tester, fx);
  });

  testWidgets('TV: Up from the first row reaches the toolbar, Down returns', (
    tester,
  ) async {
    final fx = await importGuideFixture(tester);
    await pumpGuide(
      tester,
      fx,
      now: fixedNow(),
      extra: [formFactorProvider.overrideWithValue(FormFactor.tv)],
    );
    await _key(tester, LogicalKeyboardKey.arrowUp);
    expect(_focusIn<KButton>(), isTrue);
    await _key(tester, LogicalKeyboardKey.arrowDown);
    expect(_focusIn<GuideGrid>(), isTrue);
    expect(_focus(tester).row, 0);
    await finishGuide(tester, fx);
  });

  testWidgets('desktop: Up on the first row stays in the grid', (tester) async {
    final fx = await importGuideFixture(tester);
    await pumpGuide(tester, fx, now: fixedNow());
    await _key(tester, LogicalKeyboardKey.arrowUp);
    expect(_focusIn<GuideGrid>(), isTrue);
    await finishGuide(tester, fx);
  });
}
