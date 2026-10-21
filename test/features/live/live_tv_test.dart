import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/app/platform/form_factor.dart';
import 'package:carina/data/settings/settings_store.dart';
import 'package:carina/features/live/preview/live_preview_view.dart';
import 'package:carina/features/live/widgets/channel_cards.dart';
import 'package:carina/player/engine/fake_engine.dart';
import 'package:carina/player/player_api.dart';

import '../../support/drift_widgets.dart';
import '../../support/mock_import.dart';
import '../../support/screenshot.dart';
import 'live_test_support.dart';

void main() {
  setUpAll(loadAppFonts);

  Future<(MockImportFixture, RecordingExternals, FakeEngineFactory)> open(
    WidgetTester tester, {
    bool tv = true,
    Map<SettingKey<Object?>, Object?> settings = const {},
  }) async {
    final now = liveTestNow();
    final fx = (await tester.runAsync(importMockPlaylist))!;
    await tester.runAsync(() async {
      for (final e in settings.entries) {
        await fx.settings.set(e.key, e.value, playlistId: fx.playlistId);
      }
    });
    final engines = FakeEngineFactory(autoTick: false);
    final externals = RecordingExternals();
    await pumpScreen(
      tester,
      liveInShell(fx.playlistId),
      overrides: [
        ...liveOverrides(fx, engines: engines, externals: externals, now: now),
        if (tv) formFactorProvider.overrideWithValue(FormFactor.tv),
      ],
    );
    await settleDrift(tester, rounds: 20);
    return (fx, externals, engines);
  }

  Future<void> close(WidgetTester tester, MockImportFixture fx) async {
    await unmountAndFlush(tester);
    await tester.runAsync(fx.dispose);
  }

  Future<void> key(WidgetTester tester, LogicalKeyboardKey k) async {
    await tester.sendKeyEvent(k);
    await settleDrift(tester, rounds: 3);
  }

  String? primary() => FocusManager.instance.primaryFocus?.debugLabel;

  double moreOpacity(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(
        find
            .descendant(
              of: find.byType(LiveMoreButton),
              matching: find.byType(AnimatedOpacity),
            )
            .first,
      )
      .opacity;

  testWidgets('TV: OK commits typed channel digits at once', (tester) async {
    final (fx, _, engines) = await open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit6);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('6'), findsOneWidget);
    // Enter is what the remote's OK sends: no waiting for the 1.5 s timer.
    await key(tester, LogicalKeyboardKey.enter);
    expect(find.text('6'), findsNothing);
    expect(engines.last.openedSources.last.url, endsWith('/1004.ts'));
    await close(tester, fx);
  });

  testWidgets('TV: Right reaches the preview, OK plays it, Left comes back', (
    tester,
  ) async {
    final (fx, externals, _) = await open(tester);
    expect(primary(), startsWith('live-card-'));
    await key(tester, LogicalKeyboardKey.arrowRight);
    expect(primary(), 'live-preview');
    await key(tester, LogicalKeyboardKey.arrowDown);
    expect(primary(), 'live-upcoming');
    await key(tester, LogicalKeyboardKey.arrowUp);
    expect(primary(), 'live-preview');
    await key(tester, LogicalKeyboardKey.arrowLeft);
    expect(primary(), startsWith('live-card-'));

    await key(tester, LogicalKeyboardKey.arrowRight);
    await key(tester, LogicalKeyboardKey.enter);
    expect((externals.played.single as LivePlayRequest).channelId, '1001');
    await close(tester, fx);
  });

  testWidgets('TV: the focused card shows the "more" cue, the others do not', (
    tester,
  ) async {
    final (fx, _, _) = await open(tester);
    expect(
      tester.widgetList(find.byType(LiveMoreButton)).length,
      greaterThan(1),
    );
    final opacities = [
      for (final e in tester.widgetList<AnimatedOpacity>(
        find.descendant(
          of: find.byType(LiveMoreButton),
          matching: find.byType(AnimatedOpacity),
        ),
      ))
        e.opacity,
    ];
    expect(opacities.where((o) => o == 1), hasLength(1));
    await key(tester, LogicalKeyboardKey.arrowDown);
    expect(moreOpacity(tester), 0, reason: 'the first card lost focus');
    await close(tester, fx);
  });

  testWidgets('desktop: a focused card shows no "more" button', (tester) async {
    final (fx, _, _) = await open(tester, tv: false);
    expect(
      [
        for (final e in tester.widgetList<AnimatedOpacity>(
          find.descendant(
            of: find.byType(LiveMoreButton),
            matching: find.byType(AnimatedOpacity),
          ),
        ))
          e.opacity,
      ].where((o) => o == 1),
      isEmpty,
    );
    // The preview is not a focus target on desktop.
    await key(tester, LogicalKeyboardKey.arrowRight);
    expect(primary(), isNot('live-preview'));
    expect(find.byType(LivePreviewView), findsOneWidget);
    await close(tester, fx);
  });
}
