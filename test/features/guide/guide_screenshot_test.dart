import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/settings/settings_store.dart';

import 'guide_test_support.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('guide_grid: TV Guide tab with the mock EPG', (tester) async {
    final fx = await importGuideFixture(tester);
    final now = fixedNow();
    await pumpGuide(tester, fx, now: now);
    await saveScreen(tester, 'guide_grid');
    await finishGuide(tester, fx);
  });

  testWidgets('guide_grid_focus_future: focus moved to an upcoming cell', (
    tester,
  ) async {
    final fx = await importGuideFixture(tester);
    final now = fixedNow();
    await pumpGuide(tester, fx, now: now);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settleDrift(tester, rounds: 20);
    await saveScreen(tester, 'guide_grid_focus_future');
    await finishGuide(tester, fx);
  });

  testWidgets('guide_grid_tr: Turkish, 24 h, reminder bell on a cell', (
    tester,
  ) async {
    final fx = await importGuideFixture(tester);
    final now = fixedNow();
    await tester.runAsync(() async {
      await fx.settings.set(AppSettings.language, 'tr');
      final channel =
          await (fx.db.select(fx.db.channels)
                ..where((c) => c.providerId.equals('${MockFixtures.trt1Hd}')))
              .getSingle();
      final key = channel.matchedEpgId ?? channel.epgId!;
      final next =
          await (fx.db.select(fx.db.programmes)
                ..where(
                  (p) =>
                      p.epgChannelId.equals(key) &
                      p.start.isBiggerThanValue(now.millisecondsSinceEpoch),
                )
                ..orderBy([(p) => OrderingTerm(expression: p.start)])
                ..limit(1))
              .getSingle();
      await fx.db
          .into(fx.db.reminders)
          .insert(
            RemindersCompanion.insert(
              playlistId: fx.playlistId,
              channelId: channel.providerId,
              channelName: 'TRT 1',
              title: next.title,
              start: next.start,
              stop: next.stop,
              createdAt: now,
            ),
          );
    });
    await pumpGuide(tester, fx, now: now, locale: const Locale('tr'));
    expect(find.text('Bugün'), findsWidgets);
    await saveScreen(tester, 'guide_grid_tr');
    await finishGuide(tester, fx);
  });
}
