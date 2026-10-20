import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/core/core.dart';
import 'package:carina/features/guide/guide_api.dart';
import 'package:carina/features/guide/guide_screen.dart';
import 'package:carina/features/guide/src/programme_details_sheet.dart';
import 'package:carina/player/engine/fake_engine.dart';

import 'guide_test_support.dart';

/// A stand-in for the live player behind the guide overlays: the fake
/// video, dimmed by the player the way `player_screen.dart` does.
Widget _player({required Widget overlay, bool dim = true}) => Stack(
  children: [
    Positioned.fill(child: FakeEngine().buildVideo()),
    Positioned.fill(
      child: dim
          ? ColoredBox(
              color: KColors.bg.withValues(alpha: 0.78),
              child: overlay,
            )
          : overlay,
    ),
  ],
);

void main() {
  setUpAll(loadAppFonts);

  testWidgets('guide_programme_details: upcoming programme', (tester) async {
    final fx = await importGuideFixture(tester);
    await pumpGuide(tester, fx, now: fixedNow());
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settleDrift(tester, rounds: 20);
    expect(find.byType(ProgrammeDetailsSheet), findsOneWidget);
    await saveScreen(tester, 'guide_programme_details');
    await finishGuide(tester, fx);
  });

  testWidgets('guide_archive_sheet: TRT 1 catch-up', (tester) async {
    final fx = await importGuideFixture(tester);
    await pumpGuide(tester, fx, now: fixedNow());
    final context = tester.element(find.byType(GuideScreen));
    showArchiveSheet(
      context,
      playlistId: fx.playlistId,
      channelId: '${MockFixtures.trt1Hd}',
    );
    await settleDrift(tester, rounds: 20);
    await saveScreen(tester, 'guide_archive_sheet');
    await finishGuide(tester, fx);
  });

  testWidgets('guide_day_picker: day menu', (tester) async {
    final fx = await importGuideFixture(tester);
    await pumpGuide(tester, fx, now: fixedNow());
    await tester.tap(find.text('Today').last);
    await settleDrift(tester, rounds: 10);
    await saveScreen(tester, 'guide_day_picker');
    await finishGuide(tester, fx);
  });

  testWidgets('guide_empty_epg: playlist without a guide', (tester) async {
    final fx = await importGuideFixture(tester, withEpg: false);
    await pumpGuide(tester, fx, now: fixedNow());
    await saveScreen(tester, 'guide_empty_epg');
    await finishGuide(tester, fx);
  });

  testWidgets('guide_overlay: Full TV Guide in the player', (tester) async {
    final fx = await importGuideFixture(tester);
    final now = fixedNow();
    await pumpScreen(
      tester,
      _player(
        overlay: GuideOverlay(
          playlistId: fx.playlistId,
          currentChannelId: '${MockFixtures.kanalDSd}',
          onTune: (_) {},
          onClose: () {},
        ),
      ),
      overrides: guideOverrides(fx, now: now),
    );
    await settleDrift(tester, rounds: 30);
    await saveScreen(tester, 'guide_overlay');
    await finishGuide(tester, fx);
  });

  testWidgets('guide_mini_overlay: Mini TV Guide in the player', (
    tester,
  ) async {
    final fx = await importGuideFixture(tester);
    final now = fixedNow();
    await pumpScreen(
      tester,
      _player(
        dim: false,
        overlay: MiniGuideOverlay(
          playlistId: fx.playlistId,
          currentChannelId: '${MockFixtures.showTvFhd}',
          onTune: (_) {},
          onClose: () {},
        ),
      ),
      overrides: guideOverrides(fx, now: now),
    );
    await settleDrift(tester, rounds: 30);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await settleDrift(tester, rounds: 5);
    await saveScreen(tester, 'guide_mini_overlay');
    await finishGuide(tester, fx);
  });
}
