import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/features/guide/guide_api.dart';
import 'package:carina/features/guide/src/guide_controller.dart';
import 'package:carina/features/guide/src/guide_info_panel.dart';

import 'guide_test_support.dart';

GuideFocus _focus(WidgetTester tester) =>
    tester.widget<GuideInfoPanel>(find.byType(GuideInfoPanel)).focus!;

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await settleDrift(tester, rounds: 4);
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('GuideOverlay: starts on the playing channel; on air tunes, '
      'archive plays catch-up, Esc closes', (tester) async {
    final fx = await importGuideFixture(tester);
    final now = fixedNow();
    final tuned = <String>[];
    final catchups = <(String, DateTime, DateTime)>[];
    var closed = 0;
    await pumpScreen(
      tester,
      GuideOverlay(
        playlistId: fx.playlistId,
        currentChannelId: '${MockFixtures.kanalDSd}',
        onTune: tuned.add,
        onClose: () => closed++,
        onCatchup: (id, s, e) => catchups.add((id, s, e)),
      ),
      overrides: guideOverrides(fx, now: now),
    );
    await settleDrift(tester, rounds: 30);

    final start = _focus(tester);
    expect(start.channel.providerId, '${MockFixtures.kanalDSd}');
    expect(start.cell.isOnAirAt(now.millisecondsSinceEpoch), isTrue);

    await _key(tester, LogicalKeyboardKey.arrowDown);
    final next = _focus(tester).channel.providerId;
    await _key(tester, LogicalKeyboardKey.enter);
    expect(tuned, [next]);

    // Up to TRT 1 (archive): a past programme → catch-up.
    final trtRow = tester
        .widget<GuideInfoPanel>(find.byType(GuideInfoPanel))
        .focus!
        .row;
    for (var i = 0; i < trtRow; i++) {
      await _key(tester, LogicalKeyboardKey.arrowUp);
    }
    expect(_focus(tester).channel.providerId, '${MockFixtures.trt1Hd}');
    await _key(tester, LogicalKeyboardKey.arrowLeft);
    final past = _focus(tester).cell;
    await _key(tester, LogicalKeyboardKey.enter);
    expect(catchups.single.$1, '${MockFixtures.trt1Hd}');
    expect(catchups.single.$2, past.start);

    await _key(tester, LogicalKeyboardKey.escape);
    expect(closed, 1);
    await finishGuide(tester, fx);
  });

  testWidgets('MiniGuideOverlay: arrows choose, Enter tunes, ← → cycle '
      'categories, Esc closes', (tester) async {
    final fx = await importGuideFixture(tester);
    final now = fixedNow();
    final tuned = <String>[];
    var closed = 0;
    await pumpScreen(
      tester,
      MiniGuideOverlay(
        playlistId: fx.playlistId,
        currentChannelId: '${MockFixtures.showTvFhd}',
        onTune: tuned.add,
        onClose: () => closed++,
      ),
      overrides: guideOverrides(fx, now: now),
    );
    await settleDrift(tester, rounds: 30);
    // The playing channel is selected first; ↓ moves to the next card.
    await _key(tester, LogicalKeyboardKey.arrowDown);
    await _key(tester, LogicalKeyboardKey.enter);
    expect(tuned, ['${MockFixtures.showTvHd}']);

    final header = find.textContaining('Ulusal');
    expect(header, findsWidgets);
    await _key(tester, LogicalKeyboardKey.arrowRight);
    await settleDrift(tester, rounds: 10);
    expect(find.textContaining('Ulusal'), findsNothing);
    await _key(tester, LogicalKeyboardKey.arrowLeft);
    await settleDrift(tester, rounds: 10);
    expect(find.textContaining('Ulusal'), findsWidgets);

    await _key(tester, LogicalKeyboardKey.escape);
    expect(closed, 1);
    await finishGuide(tester, fx);
  });
}
