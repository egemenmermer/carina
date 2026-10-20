import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/features/guide/guide_api.dart';
import 'package:carina/features/guide/guide_screen.dart';
import 'package:carina/features/guide/src/guide_controller.dart';
import 'package:carina/features/guide/src/guide_grid.dart';
import 'package:carina/features/guide/src/guide_info_panel.dart';
import 'package:carina/features/guide/src/programme_details_sheet.dart';
import 'package:carina/player/player_api.dart';

import 'guide_test_support.dart';

GuideFocus _focus(WidgetTester tester) =>
    tester.widget<GuideInfoPanel>(find.byType(GuideInfoPanel)).focus!;

ScrollPosition _scroll(WidgetTester tester, {required bool vertical}) {
  final scrollables = find.descendant(
    of: find.byType(GuideGrid),
    matching: find.byType(Scrollable),
  );
  final state = tester.state<ScrollableState>(
    vertical ? scrollables.first : scrollables.at(1),
  );
  return state.position;
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await settleDrift(tester, rounds: 4);
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('keyboard: arrows move by cell, focus follows, Home = now', (
    tester,
  ) async {
    final fx = await importGuideFixture(tester);
    final now = fixedNow();
    final nowMs = now.millisecondsSinceEpoch;
    await pumpGuide(tester, fx, now: now);

    var f = _focus(tester);
    expect(f.row, 0);
    expect(f.channel.providerId, '${MockFixtures.trt1Hd}');
    expect(f.cell.isOnAirAt(nowMs), isTrue);
    final onAir = f.cell;

    await _key(tester, LogicalKeyboardKey.arrowDown);
    expect(_focus(tester).row, 1);
    expect(_focus(tester).cell.isOnAirAt(nowMs), isTrue);

    await _key(tester, LogicalKeyboardKey.arrowUp);
    await _key(tester, LogicalKeyboardKey.arrowRight);
    f = _focus(tester);
    expect(f.row, 0);
    expect(f.cell.startMs, onAir.stopMs);
    expect(f.cell.isUpcomingAt(nowMs), isTrue);
    // The info panel follows the focus.
    expect(find.text(f.cell.programme!.title), findsWidgets);

    await _key(tester, LogicalKeyboardKey.arrowLeft);
    expect(_focus(tester).cell, onAir);
    await _key(tester, LogicalKeyboardKey.arrowLeft);
    f = _focus(tester);
    expect(f.cell.stopMs, onAir.startMs);
    expect(f.cell.hasEndedAt(nowMs), isTrue);

    await _key(tester, LogicalKeyboardKey.home);
    expect(_focus(tester).cell, onAir);

    await _key(tester, LogicalKeyboardKey.pageDown);
    expect(_focus(tester).row, greaterThan(3));
    final v = _scroll(tester, vertical: true);
    expect(v.pixels, greaterThan(0), reason: 'the grid follows the focus');
    await finishGuide(tester, fx);
  });

  testWidgets('cell routing: on air → live, archive → catch-up, future → '
      'details; channel name → channel actions', (tester) async {
    final fx = await importGuideFixture(tester);
    final now = fixedNow();
    final actions = RecordingGuideActions();
    await pumpGuide(tester, fx, now: now, actions: actions);
    final grid = tester.getTopLeft(find.byType(GuideGrid));

    // Click the on-air cell of the first row (TRT 1).
    await tester.tapAt(grid + const Offset(260 + 60, 34 + 30));
    await settleDrift(tester, rounds: 4);
    expect(actions.played, hasLength(1));
    final live = actions.played.single as LivePlayRequest;
    expect(live.channelId, '${MockFixtures.trt1Hd}');
    expect(live.zapChannelIds, contains('${MockFixtures.showTvFhd}'));

    // A past programme of TRT 1 (3 days of archive) → catch-up.
    await _key(tester, LogicalKeyboardKey.arrowLeft);
    final past = _focus(tester).cell;
    await _key(tester, LogicalKeyboardKey.enter);
    final catchup = actions.played.last as CatchupPlayRequest;
    expect(catchup.channelId, '${MockFixtures.trt1Hd}');
    expect(catchup.startUtc, past.start);
    expect(catchup.endUtc, past.stop);

    // An upcoming one → the details sheet.
    await _key(tester, LogicalKeyboardKey.home);
    await _key(tester, LogicalKeyboardKey.arrowRight);
    await _key(tester, LogicalKeyboardKey.enter);
    await settleDrift(tester, rounds: 10);
    expect(find.byType(ProgrammeDetailsSheet), findsOneWidget);
    expect(actions.played, hasLength(2));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settleDrift(tester, rounds: 10);
    expect(find.byType(ProgrammeDetailsSheet), findsNothing);

    // Channel name → the channel actions of TRT 1.
    await tester.tap(
      find.byKey(ValueKey('guide-channel-${MockFixtures.trt1Hd}')),
    );
    await settleDrift(tester, rounds: 4);
    expect(actions.channelActions.single.channelId, '${MockFixtures.trt1Hd}');
    await finishGuide(tester, fx);
  });

  testWidgets('wheel scrolls rows, Shift+wheel and middle drag scroll time', (
    tester,
  ) async {
    final fx = await importGuideFixture(tester);
    await pumpGuide(tester, fx, now: fixedNow());
    final v = _scroll(tester, vertical: true);
    final h = _scroll(tester, vertical: false);
    final center = tester.getCenter(find.byType(GuideGrid));
    final mouse = TestPointer(7, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(center));

    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 140)));
    await tester.pump();
    expect(v.pixels, 140);
    final h0 = h.pixels;

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 100)));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(h.pixels, h0 + 100);
    expect(v.pixels, 140);

    final drag = await tester.startGesture(
      center,
      kind: PointerDeviceKind.mouse,
      buttons: kMiddleMouseButton,
    );
    await drag.moveBy(const Offset(-200, -70));
    await drag.up();
    await tester.pump();
    expect(h.pixels, h0 + 300);
    expect(v.pixels, 210);
    await finishGuide(tester, fx);
  });

  testWidgets('reminder toggle from the details sheet', (tester) async {
    final fx = await importGuideFixture(tester);
    await pumpGuide(tester, fx, now: fixedNow());
    await _key(tester, LogicalKeyboardKey.arrowRight);
    final upcoming = _focus(tester).cell;
    await _key(tester, LogicalKeyboardKey.enter);
    await settleDrift(tester, rounds: 10);

    await tester.tap(find.text('Remind me'));
    await settleDrift(tester, rounds: 10);
    final rows = (await tester.runAsync(
      () => fx.db.select(fx.db.reminders).get(),
    ))!;
    expect(rows, hasLength(1));
    expect(rows.single.channelId, '${MockFixtures.trt1Hd}');
    expect(rows.single.start, upcoming.startMs);
    expect(find.text('Reminder set — keep Carina running to get it'), findsOne);
    expect(find.text('Reminder set'), findsOneWidget);

    await tester.tap(find.text('Reminder set'));
    await settleDrift(tester, rounds: 10);
    final after = (await tester.runAsync(
      () => fx.db.select(fx.db.reminders).get(),
    ))!;
    expect(after, isEmpty);
    expect(find.text('Reminder removed'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await finishGuide(tester, fx);
  });

  testWidgets('archive sheet: days, ON AIR row, a row plays the catch-up', (
    tester,
  ) async {
    final fx = await importGuideFixture(tester);
    final actions = RecordingGuideActions();
    await pumpGuide(tester, fx, now: fixedNow(), actions: actions);
    final context = tester.element(find.byType(GuideScreen));
    showArchiveSheet(
      context,
      playlistId: fx.playlistId,
      channelId: '${MockFixtures.trt1Hd}',
    );
    await settleDrift(tester, rounds: 20);
    expect(find.text('TV ARCHIVE • CATCH-UP'), findsOneWidget);
    expect(find.textContaining('– ON AIR'), findsOneWidget);
    final now = fixedNow();
    final weekday = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ][now.weekday - 1];
    expect(find.textContaining(weekday), findsWidgets);

    // The second row is a finished programme.
    final rows = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('archive-'),
    );
    await tester.tap(rows.at(1));
    await settleDrift(tester, rounds: 10);
    final request = actions.played.single as CatchupPlayRequest;
    expect(request.channelId, '${MockFixtures.trt1Hd}');
    expect(request.endUtc.isBefore(now.toUtc()), isTrue);
    expect(find.text('TV ARCHIVE • CATCH-UP'), findsNothing);

    // A channel without archive.
    showArchiveSheet(
      context,
      playlistId: fx.playlistId,
      channelId: '${MockFixtures.showTvFhd}',
    );
    await settleDrift(tester, rounds: 20);
    expect(find.text('This channel has no TV archive.'), findsOneWidget);
    await finishGuide(tester, fx);
  });
}
