import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/app_paths.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/repositories/reminders_repository.dart';
import 'package:carina/data/repositories/repository_models.dart';
import 'package:carina/data/settings/settings_store.dart';

import 'fixtures.dart';

void main() {
  late R1Env env;
  late FakeClock clock;
  late RemindersRepository repo;
  late int pid;
  late ChannelRow channel;

  final t0 = DateTime.utc(2026, 10, 17, 20);

  ProgrammeView programme(
    String title,
    Duration startIn,
    Duration length, {
    String epg = 'trt1',
  }) => ProgrammeView(
    epgChannelId: epg,
    start: t0.add(startIn),
    stop: t0.add(startIn + length),
    title: title,
  );

  setUp(() async {
    env = await R1Env.create();
    clock = FakeClock(t0);
    repo = RemindersRepository(env.db, clock: clock.call);
    pid = await env.playlist();
    await env.channel(pid, '1001', 'TRT 1 HD', displayName: 'TRT 1');
    channel = (await env.db.select(env.db.channels).get()).single;
  });
  tearDown(() => env.dispose());

  test('add, isSet, toggle, remove', () async {
    final p = programme(
      'Haber',
      const Duration(hours: 1),
      const Duration(minutes: 30),
    );
    expect(await repo.isSet(pid, '1001', p.start), isFalse);
    final id = await repo.add(pid, channel, p);
    expect(await repo.add(pid, channel, p), id, reason: 'already set');
    expect(await repo.isSet(pid, '1001', p.start), isTrue);
    final row = (await repo.watchAll(pid).first).single;
    expect(row.channelName, 'TRT 1');
    expect(row.title, 'Haber');
    expect(row.epgChannelId, 'trt1');
    expect(row.start, p.startMs);
    expect(row.stop, p.stopMs);
    expect(row.fired, isFalse);
    expect(await repo.toggle(pid, channel, p), isFalse);
    expect(await repo.isSet(pid, '1001', p.start), isFalse);
    expect(await repo.toggle(pid, channel, p), isTrue);
    final again = (await repo.watchForChannel(pid, '1001').first).single;
    await repo.remove(again.id);
    expect(await repo.watchAll().first, isEmpty);
  });

  test('due: inside the lead time, not fired, not over', () async {
    final soon = await repo.add(
      pid,
      channel,
      programme('Soon', const Duration(seconds: 30), const Duration(hours: 1)),
    );
    final later = await repo.add(
      pid,
      channel,
      programme('Later', const Duration(minutes: 5), const Duration(hours: 1)),
    );
    final onAir = await repo.add(
      pid,
      channel,
      programme(
        'On air',
        const Duration(minutes: -10),
        const Duration(minutes: 30),
      ),
    );
    await repo.add(
      pid,
      channel,
      programme('Over', const Duration(hours: -2), const Duration(hours: 1)),
    );
    List<int> ids(List<ReminderRow> l) => [for (final r in l) r.id];
    expect(ids(await repo.due(t0, const Duration(minutes: 1))), [onAir, soon]);
    expect(ids(await repo.due(t0, const Duration(minutes: 5))), [
      onAir,
      soon,
      later,
    ]);
    await repo.markFired(soon);
    expect(ids(await repo.due(t0, const Duration(minutes: 1))), [onAir]);
    expect(await repo.deleteExpired(), 1);
    expect(await repo.watchAll(pid).first, hasLength(3));
  });

  group('scheduler', () {
    late Duration lead;
    late ReminderScheduler scheduler;

    setUp(() {
      lead = const Duration(minutes: 1);
      scheduler = ReminderScheduler(repo, lead: () => lead, clock: clock.call);
    });
    tearDown(() => scheduler.dispose());

    test('emits each due reminder once and skips finished ones', () async {
      await repo.add(
        pid,
        channel,
        programme(
          'Soon',
          const Duration(seconds: 50),
          const Duration(hours: 1),
        ),
      );
      await repo.add(
        pid,
        channel,
        programme(
          'Later',
          const Duration(minutes: 5),
          const Duration(hours: 1),
        ),
      );
      await repo.add(
        pid,
        channel,
        programme('Over', const Duration(hours: -2), const Duration(hours: 1)),
      );
      final emitted = <String>[];
      final sub = scheduler.dueReminders.listen((r) => emitted.add(r.title));

      final first = await scheduler.tick();
      expect(first.map((r) => r.title), ['Soon']);
      expect(first.single.fired, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(emitted, ['Soon']);
      expect((await repo.watchAll().first).map((r) => r.title), [
        'Soon',
        'Later',
      ], reason: 'the finished one is deleted');

      expect(await scheduler.tick(), isEmpty, reason: 'fired once');
      clock.advance(const Duration(minutes: 3));
      expect(await scheduler.tick(), isEmpty, reason: 'Later is 2 min away');
      lead = const Duration(minutes: 5);
      expect((await scheduler.tick()).map((r) => r.title), ['Later']);
      await Future<void>.delayed(Duration.zero);
      expect(emitted, ['Soon', 'Later']);

      // A reminder whose programme ended while the app was closed never
      // fires.
      await repo.add(
        pid,
        channel,
        programme(
          'Missed',
          const Duration(minutes: 1),
          const Duration(minutes: 1),
        ),
      );
      clock.advance(const Duration(minutes: 10));
      expect(await scheduler.tick(), isEmpty);
      await sub.cancel();
    });

    test('runs periodically', () async {
      final fast = ReminderScheduler(
        repo,
        lead: () => Duration.zero,
        clock: clock.call,
        interval: const Duration(milliseconds: 20),
      );
      addTearDown(fast.dispose);
      final got = Completer<ReminderRow>();
      fast.dueReminders.listen(got.complete);
      fast.start();
      expect(fast.isRunning, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(got.isCompleted, isFalse);
      await repo.add(
        pid,
        channel,
        programme('Now', Duration.zero, const Duration(minutes: 30)),
      );
      final row = await got.future.timeout(const Duration(seconds: 2));
      expect(row.title, 'Now');
      fast.stop();
      expect(fast.isRunning, isFalse);
    });
  });

  test('provider wiring uses the lead-time setting', () async {
    await env.settings.set(AppSettings.reminderLeadMinutes, 10);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(env.db),
        settingsStoreProvider.overrideWithValue(env.settings),
        remindersRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    // The provider's scheduler uses the real clock.
    final start = DateTime.now().toUtc().add(const Duration(minutes: 8));
    await repo.add(
      pid,
      channel,
      ProgrammeView(
        epgChannelId: 'trt1',
        start: start,
        stop: start.add(const Duration(minutes: 30)),
        title: 'In 8 min',
      ),
    );
    final scheduler = container.read(reminderSchedulerProvider);
    final emitted = <ReminderRow>[];
    scheduler.dueReminders.listen(emitted.add);
    expect(scheduler.isRunning, isTrue);
    await pumpUntil(() => emitted.isNotEmpty);
    expect(emitted.single.title, 'In 8 min', reason: 'lead 10 min');
    expect((await repo.watchAll().first).single.fired, isTrue);
  });
}
