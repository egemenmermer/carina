import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/repositories/watch_state_repository.dart';
import 'package:carina/data/settings/settings_store.dart';

import 'r2_fixtures.dart';

const _min = Duration(minutes: 1);

void main() {
  late R2Env env;
  late WatchStateRepository repo;
  late int pid;

  setUp(() async {
    env = await R2Env.create();
    repo = WatchStateRepository(
      db: env.db,
      settings: env.settings,
      clock: env.clock,
    );
    pid = await env.playlist();
  });

  tearDown(() => env.close());

  void tick([int minutes = 1]) =>
      env.now = env.now.add(Duration(minutes: minutes));

  Future<WatchState> play(
    ItemType type,
    String id,
    double fraction, {
    int totalMinutes = 100,
    String? seriesId,
  }) {
    tick();
    final total = Duration(minutes: totalMinutes);
    return repo.save(
      pid,
      type,
      id,
      total * fraction,
      total,
      seriesId: seriesId,
    );
  }

  group('thresholds and resume', () {
    test(
      'watched from 95%, in progress from 2%, sticky watched flag',
      () async {
        expect((await play(ItemType.movie, 'm', 0.01)).inProgress, isFalse);
        expect((await play(ItemType.movie, 'm', 0.5)).inProgress, isTrue);
        final done = await play(ItemType.movie, 'm', 0.96);
        expect(done.watched, isTrue);
        expect(done.inProgress, isFalse);
        // Rewatching from the start keeps the watched flag.
        final again = await play(ItemType.movie, 'm', 0.3);
        expect(again.watched, isTrue);
        expect(again.position, const Duration(minutes: 30));
        // A zero duration keeps the stored one.
        final unknown = await repo.save(
          pid,
          ItemType.movie,
          'm',
          const Duration(minutes: 40),
          Duration.zero,
        );
        expect(unknown.duration, const Duration(minutes: 100));
        expect((await repo.get(pid, ItemType.movie, 'm'))!.position, _min * 40);
      },
    );

    test('resumeFor offers between 2% and 95%', () async {
      expect(repo.resumeFor(null), const ResumeDecision.none());
      final early = await play(ItemType.movie, 'a', 0.019);
      expect(repo.resumeFor(early).kind, ResumeKind.none);
      final mid = await play(ItemType.movie, 'b', 0.5);
      expect(repo.resumeFor(mid), ResumeDecision.offer(mid.position));
      expect(
        repo.resumeFor(mid, alwaysResume: true),
        const ResumeDecision.resume(Duration(minutes: 50)),
      );
      final edge = await play(ItemType.movie, 'c', 0.02);
      expect(repo.resumeFor(edge).kind, ResumeKind.offer);
      final late = await play(ItemType.movie, 'd', 0.95);
      expect(repo.resumeFor(late).kind, ResumeKind.none);
      expect(late.watched, isTrue);
      final noDuration = await repo.save(
        pid,
        ItemType.movie,
        'e',
        const Duration(minutes: 5),
        Duration.zero,
      );
      expect(repo.resumeFor(noDuration).kind, ResumeKind.none);
    });

    test('watch() streams changes; setWatched resets the position', () async {
      final emissions = Emissions(repo.watch(pid, ItemType.movie, 'm'));
      expect(await emissions.next(), isNull);
      await play(ItemType.movie, 'm', 0.4);
      expect((await emissions.next((s) => s != null))!.inProgress, isTrue);
      await repo.setWatched(pid, ItemType.movie, 'm', true);
      final watched = await emissions.next((s) => s?.watched ?? false);
      expect(watched!.position, Duration.zero);
      expect(watched.duration, const Duration(minutes: 100));
      await repo.setWatched(pid, ItemType.movie, 'm', false);
      final unwatched = await emissions.next((s) => !(s?.watched ?? true));
      expect(unwatched!.inProgress, isFalse);
      await repo.clear(pid, ItemType.movie, 'm');
      expect(await emissions.next((s) => s == null), isNull);
      await emissions.cancel();
    });

    test('episode saves look up their series id', () async {
      await env.episode(pid, '5001', 'e1', 1, 1);
      final s = await play(ItemType.episode, 'e1', 0.3);
      expect(s.seriesId, '5001');
      expect(
        (await play(ItemType.episode, 'x', 0.3, seriesId: '77')).seriesId,
        '77',
      );
    });
  });

  group('continue watching movies', () {
    setUp(() async {
      await env.movie(pid, 'a', 'Zeplin', added: DateTime(2026, 1, 1));
      await env.movie(pid, 'b', 'Ayna', added: DateTime(2026, 5, 1));
      await env.movie(pid, 'c', 'Çember', added: DateTime(2026, 3, 1));
      await env.movie(pid, 'd', 'Bitti');
      await env.movie(pid, 'e', 'Başladı');
      await env.movie(pid, 'h', 'Gizli', hidden: true);
      await play(ItemType.movie, 'a', 0.3);
      await play(ItemType.movie, 'b', 0.5);
      await play(ItemType.movie, 'c', 0.2);
      await play(ItemType.movie, 'd', 0.99);
      await play(ItemType.movie, 'e', 0.01);
      await play(ItemType.movie, 'h', 0.5);
      await play(ItemType.movie, 'not-in-library', 0.5);
    });

    Future<List<String>> ids(ContinueWatchingOrder order) async =>
        (await repo.continueWatchingMovies(
          pid,
          order: order,
        )).map((e) => e.item.providerId).toList();

    test('only in-progress, visible movies in the chosen order', () async {
      expect(await ids(ContinueWatchingOrder.lastUpdated), ['c', 'b', 'a']);
      expect(await ids(ContinueWatchingOrder.lastAdded), ['b', 'c', 'a']);
      expect(await ids(ContinueWatchingOrder.name), ['b', 'c', 'a']);
      final first = (await repo.continueWatchingMovies(pid)).first;
      expect(first.progress, closeTo(0.2, 0.001));
      expect(first.episode, isNull);
      expect(first.playId, 'c');
    });

    test('order setting and live updates', () async {
      await env.settings.set(
        PlaylistSettings.continueWatchingOrder,
        'name',
        playlistId: pid,
      );
      expect((await repo.continueWatchingMovies(pid)).map((e) => e.item.name), [
        'Ayna',
        'Çember',
        'Zeplin',
      ]);
      final emissions = Emissions(
        repo.watchContinueWatchingMovies(
          pid,
          order: ContinueWatchingOrder.lastUpdated,
        ),
      );
      expect((await emissions.next()).first.item.providerId, 'c');
      await play(ItemType.movie, 'a', 0.6);
      expect(
        (await emissions.next((l) => l.first.item.providerId == 'a'))
            .first
            .position,
        const Duration(minutes: 60),
      );
      await play(ItemType.movie, 'a', 0.97);
      await emissions.next((l) => l.every((e) => e.item.providerId != 'a'));
      await emissions.cancel();
    });
  });

  group('continue watching shows', () {
    setUp(() async {
      await env.series(
        pid,
        'S',
        'Sıcak Kafa',
        lastModified: DateTime(2026, 9, 1),
      );
      await env.episode(
        pid,
        'S',
        's11',
        1,
        1,
        title: 'Pilot',
        durationSecs: 2700,
      );
      await env.episode(
        pid,
        'S',
        's12',
        1,
        2,
        title: 'İkinci',
        durationSecs: 2700,
      );
      await env.episode(
        pid,
        'S',
        's21',
        2,
        1,
        title: 'Dönüş',
        durationSecs: 3000,
      );
      await env.episode(pid, 'S', 's01', 0, 1, title: 'Özel');
      await env.series(pid, 'T', 'Avlu', lastModified: DateTime(2026, 10, 1));
      await env.episode(pid, 'T', 't11', 1, 1, title: 'Bir');
      await env.episode(pid, 'T', 't12', 1, 2, title: 'İki');
    });

    Future<List<ContinueWatchingEntry>> shows([
      ContinueWatchingOrder order = ContinueWatchingOrder.lastUpdated,
    ]) => repo.continueWatchingShows(pid, order: order);

    test('in-progress episode with label and progress', () async {
      await play(ItemType.episode, 's12', 0.4, seriesId: 'S');
      final entry = (await shows()).single;
      expect(entry.item.providerId, 'S');
      expect(entry.item.name, 'Sıcak Kafa');
      expect(entry.episode!.providerId, 's12');
      expect(entry.episodeLabel, 'S1 E2 · İkinci');
      expect(entry.isNextEpisode, isFalse);
      expect(entry.progress, closeTo(0.4, 0.001));
      expect(entry.playId, 's12');
    });

    test('next episode after a finished one, across seasons', () async {
      await play(ItemType.episode, 's11', 0.97, seriesId: 'S');
      var entry = (await shows()).single;
      expect(entry.episode!.providerId, 's12');
      expect(entry.isNextEpisode, isTrue);
      expect(entry.position, Duration.zero);
      expect(entry.duration, const Duration(seconds: 2700));

      await play(ItemType.episode, 's12', 1.0, seriesId: 'S');
      entry = (await shows()).single;
      expect(entry.episode!.providerId, 's21');
      expect(entry.episodeLabel, 'S2 E1 · Dönüş');

      // The last regular episode finished: no entry (specials are skipped).
      await play(ItemType.episode, 's21', 0.99, seriesId: 'S');
      expect(await shows(), isEmpty);
    });

    test('a barely started episode does not hide the next-up entry', () async {
      await play(ItemType.episode, 's11', 0.99, seriesId: 'S');
      await play(ItemType.episode, 's12', 0.01, seriesId: 'S');
      final entry = (await shows()).single;
      expect(entry.episode!.providerId, 's12');
      expect(entry.isNextEpisode, isTrue);
      expect(entry.position, const Duration(minutes: 1)); // 1% of 100 min
    });

    test('next episode skips episodes already watched', () async {
      await repo.setWatched(pid, ItemType.episode, 's12', true);
      await play(ItemType.episode, 's11', 0.99, seriesId: 'S');
      expect((await shows()).single.episode!.providerId, 's21');
    });

    test('one entry per series, ordered by setting', () async {
      await play(ItemType.episode, 't11', 0.5, seriesId: 'T');
      await play(ItemType.episode, 's11', 0.5, seriesId: 'S');
      await play(ItemType.episode, 's12', 0.3, seriesId: 'S');
      final byUpdate = await shows();
      expect(byUpdate.map((e) => e.item.providerId), ['S', 'T']);
      expect(byUpdate.first.episode!.providerId, 's12');
      expect(
        (await shows(ContinueWatchingOrder.lastAdded))
            .map((e) => e.item.providerId),
        ['T', 'S'],
      );
      expect(
        (await shows(ContinueWatchingOrder.name)).map((e) => e.item.name),
        ['Avlu', 'Sıcak Kafa'],
      );
    });

    test('series marked watched or hidden are left out', () async {
      await play(ItemType.episode, 's11', 0.5, seriesId: 'S');
      await play(ItemType.episode, 't11', 0.5, seriesId: 'T');
      await repo.setWatched(pid, ItemType.series, 'S', true);
      expect((await shows()).map((e) => e.item.providerId), ['T']);
      // Marking the series watched marked its episodes too.
      expect(await repo.watchedEpisodeIds(pid, 'S'), {
        's11',
        's12',
        's21',
        's01',
      });
      await (env.db.update(env.db.series)
            ..where((s) => s.providerId.equals('T')))
          .write(const SeriesCompanion(hidden: Value(true)));
      expect(await shows(), isEmpty);
    });

    test('stream updates as episodes are played', () async {
      final emissions = Emissions(repo.watchContinueWatchingShows(pid));
      expect(await emissions.next(), isEmpty);
      await play(ItemType.episode, 't11', 0.5, seriesId: 'T');
      final first = await emissions.next((l) => l.isNotEmpty);
      expect(first.single.episode!.providerId, 't11');
      await play(ItemType.episode, 't11', 0.99, seriesId: 'T');
      final next = await emissions.next(
        (l) => l.isNotEmpty && l.single.episode!.providerId == 't12',
      );
      expect(next.single.isNextEpisode, isTrue);
      await emissions.cancel();
    });
  });

  group('episode marks', () {
    setUp(() async {
      for (final (id, s, e) in [
        ('a1', 1, 1),
        ('a2', 1, 2),
        ('a3', 1, 3),
        ('b1', 2, 1),
        ('b2', 2, 2),
        ('x1', 0, 1),
        ('x2', 0, 2),
      ]) {
        await env.episode(pid, 'S', id, s, e);
      }
    });

    test('markPreviousWatched marks earlier episodes only', () async {
      expect(await repo.markPreviousWatched(pid, 'S', 2, 2), 4);
      expect(await repo.watchedEpisodeIds(pid, 'S'), {'a1', 'a2', 'a3', 'b1'});
      expect(await repo.markPreviousWatched(pid, 'S', 0, 2), 1);
      expect(await repo.watchedEpisodeIds(pid, 'S'), {
        'a1',
        'a2',
        'a3',
        'b1',
        'x1',
      });
      expect(await repo.markPreviousWatched(pid, 'S', 1, 1), 0);
    });

    test('episode states stream with progress and watched flags', () async {
      final emissions = Emissions(repo.watchEpisodeStates(pid, 'S'));
      expect(await emissions.next(), isEmpty);
      await play(ItemType.episode, 'a2', 0.5);
      final states = await emissions.next((m) => m.containsKey('a2'));
      expect(states['a2']!.inProgress, isTrue);
      final watched = Emissions(repo.watchWatchedEpisodeIds(pid, 'S'));
      expect(await watched.next(), isEmpty);
      await repo.setWatched(pid, ItemType.episode, 'a1', true);
      expect(await watched.next((s) => s.isNotEmpty), {'a1'});
      await emissions.cancel();
      await watched.cancel();
    });
  });
}
