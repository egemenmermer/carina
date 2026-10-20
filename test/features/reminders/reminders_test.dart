import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/app/shell/playlist_shell.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/settings/settings_store.dart';
import 'package:carina/features/guide/guide_screen.dart';
import 'package:carina/features/reminders/reminders_api.dart';

import '../guide/guide_test_support.dart';

class _RecordingNotifier implements ReminderSystemNotifier {
  final List<({String title, String body})> shown = [];

  @override
  Future<void> show({
    required String title,
    required String body,
    VoidCallback? onClick,
  }) async => shown.add((title: title, body: body));
}

class _RecordingActions extends ReminderActions {
  final List<ReminderRow> watched = [];

  @override
  Future<void> watchNow(BuildContext context, ReminderRow reminder) async =>
      watched.add(reminder);
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('reminders_banner: a due reminder shows the OS notification '
      'and the banner; Watch now opens the channel', (tester) async {
    final fx = await importGuideFixture(tester);
    final now = fixedNow();
    final realNow = DateTime.now();
    await tester.runAsync(() async {
      await fx.settings.set(AppSettings.reminderLeadMinutes, 5);
      await fx.db
          .into(fx.db.reminders)
          .insert(
            RemindersCompanion.insert(
              playlistId: fx.playlistId,
              channelId: '${MockFixtures.trt1Hd}',
              channelName: 'TRT 1',
              title: 'Akşam Haberleri',
              start: realNow
                  .add(const Duration(minutes: 3))
                  .millisecondsSinceEpoch,
              stop: realNow
                  .add(const Duration(minutes: 45))
                  .millisecondsSinceEpoch,
              createdAt: realNow,
            ),
          );
    });
    final notifier = _RecordingNotifier();
    final actions = _RecordingActions();
    final navigatorKey = GlobalKey<NavigatorState>();
    await pumpScreen(
      tester,
      ReminderListener(
        navigatorKey: navigatorKey,
        child: PlaylistShell(
          playlistId: fx.playlistId,
          location: '/p/${fx.playlistId}/guide',
          child: GuideScreen(playlistId: fx.playlistId),
        ),
      ),
      navigatorKey: navigatorKey,
      overrides: [
        ...guideOverrides(fx, now: now),
        reminderSystemNotifierProvider.overrideWithValue(notifier),
        reminderActionsProvider.overrideWithValue(actions),
      ],
    );
    await settleDrift(tester, rounds: 30);

    expect(notifier.shown, hasLength(1));
    expect(notifier.shown.single.title, 'Akşam Haberleri');
    expect(notifier.shown.single.body, startsWith('TRT 1 · starts at'));
    expect(find.text('Akşam Haberleri'), findsOneWidget);
    expect(find.text('Watch now'), findsOneWidget);
    await saveScreen(tester, 'reminders_banner');

    await tester.tap(find.text('Watch now'));
    await settleDrift(tester, rounds: 10);
    expect(actions.watched.single.channelId, '${MockFixtures.trt1Hd}');
    expect(find.text('Watch now'), findsNothing);

    // Fired once: the reminder is marked and not shown again.
    final rows = (await tester.runAsync(
      () => fx.db.select(fx.db.reminders).get(),
    ))!;
    expect(rows.single.fired, isTrue);
    await finishGuide(tester, fx);
  });

  testWidgets('toggleReminder refuses programmes that already started', (
    tester,
  ) async {
    final fx = await importGuideFixture(tester);
    final now = fixedNow();
    await pumpGuide(tester, fx, now: now);
    final context = tester.element(find.byType(GuideScreen));
    // The programme on air on TRT 1.
    final onAir = (await tester.runAsync(() async {
      final rows =
          await (fx.db.select(fx.db.programmes)..where(
                (p) =>
                    p.start.isSmallerOrEqualValue(now.millisecondsSinceEpoch) &
                    p.stop.isBiggerThanValue(now.millisecondsSinceEpoch),
              ))
              .get();
      final channel =
          await (fx.db.select(fx.db.channels)
                ..where((c) => c.providerId.equals('${MockFixtures.trt1Hd}')))
              .getSingle();
      return rows.firstWhere(
        (p) => p.epgChannelId == (channel.matchedEpgId ?? channel.epgId),
      );
    }))!;
    final done = toggleReminder(
      context,
      playlistId: fx.playlistId,
      channelId: '${MockFixtures.trt1Hd}',
      startUtc: DateTime.fromMillisecondsSinceEpoch(onAir.start, isUtc: true),
    );
    await settleDrift(tester, rounds: 10);
    await tester.runAsync(() => done);
    await tester.pump();
    expect(find.text('This programme has already started'), findsOneWidget);
    final rows = (await tester.runAsync(
      () => fx.db.select(fx.db.reminders).get(),
    ))!;
    expect(rows, isEmpty);
    await tester.pump(const Duration(seconds: 3));
    await finishGuide(tester, fx);
  });
}
