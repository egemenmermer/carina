import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/import/import.dart';
import 'package:carina/data/text/normalize.dart';
import 'package:carina/data/text/quality.dart';

import 'import_harness.dart';

void main() {
  late ImportHarness h;
  late int pid;
  late List<ImportProgress> events;

  setUpAll(() async {
    h = await ImportHarness.create();
    pid = await h.addXtream();
    events = await h.runImport(pid);
  });

  tearDownAll(() => h.dispose());

  test('completes with the stepper steps in order', () {
    final last = events.last;
    expect(last.step, ImportStep.completed, reason: '$last');
    expect(last.done, isTrue);
    expect(last.error, isNull);
    expect(last.epgError, isNull);
    expect(last.warnings, isEmpty);
    expect(stepsOf(events), [
      ImportStep.connecting,
      ImportStep.liveCategories,
      ImportStep.liveChannels,
      ImportStep.movies,
      ImportStep.series,
      ImportStep.epgCleaning,
      ImportStep.epgDownloading,
      ImportStep.epgParsing,
      ImportStep.completed,
    ]);
    expect(last.plannedSteps, [
      ...ImportStep.contentSteps,
      ...ImportStep.epgSteps,
      ImportStep.completed,
    ]);
    expect(last.skippedSteps, isEmpty);
    for (final s in last.plannedSteps) {
      expect(last.statusOf(s), ImportStepStatus.done, reason: s.name);
    }
    expect(events.where((e) => e.done), hasLength(1));
    expect(last.stepDurations.keys, containsAll(ImportStep.contentSteps));
    // Byte progress while downloading the guide.
    expect(
      events.any(
        (e) =>
            e.step == ImportStep.epgDownloading && (e.receivedBytes ?? 0) > 0,
      ),
      isTrue,
    );
  });

  test('counts match the mock catalog', () async {
    final c = h.catalog;
    final last = events.last;
    expect(last.counts[ImportStep.liveCategories], c.liveCategories.length);
    expect(last.counts[ImportStep.liveChannels], c.channels.length);
    expect(last.counts[ImportStep.movies], c.movies.length);
    expect(last.counts[ImportStep.series], c.series.length);
    expect(last.counts[ImportStep.epgParsing], greaterThan(0));

    final p = await h.playlist(pid);
    expect(p.liveCount, c.channels.length);
    expect(p.movieCount, 2000);
    expect(p.seriesCount, 200);
    expect(await h.count('channels', pid), c.channels.length);
    expect(await h.count('movies', pid), c.movies.length);
    expect(await h.count('series', pid), c.series.length);
    expect(
      await h.count('categories', pid, 'kind = ${SectionKind.live.index}'),
      c.liveCategories.length,
    );
    expect(
      await h.count('categories', pid, 'kind = ${SectionKind.movie.index}'),
      c.vodCategories.length,
    );
    expect(
      await h.count('categories', pid, 'kind = ${SectionKind.series.index}'),
      c.seriesCategories.length,
    );
    expect(await h.count('channels', pid, 'removed = 1'), 0);
    expect(p.lastReloadAt, isNotNull);
    expect(p.lastEpgReloadAt, isNotNull);

    final account = jsonDecode(p.accountJson!) as Map<String, Object?>;
    expect((account['user_info'] as Map)['status'], 'Active');
    expect(p.accountJson, isNot(contains(MockFixtures.password)));
  });

  test('fixture channels are mapped per ARCHITECTURE 2.11', () async {
    final c = h.catalog;
    final trt1 = (await h.channel(pid, 1001))!;
    expect(trt1.name, 'TRT 1 HD');
    expect(trt1.displayName, 'TRT 1');
    expect(trt1.quality, 'HD');
    expect(trt1.archiveDays, 3);
    expect(trt1.categoryId, MockFixtures.ulusalCategoryId);
    expect(trt1.epgId, c.channelById(1001)!.epgChannelId);
    expect(trt1.streamUrl, isNull);
    expect(trt1.added, isNotNull);
    expect(trt1.num, c.channelById(1001)!.num);

    final show = (await h.channel(pid, 1002))!;
    expect(
      (show.displayName, show.quality, show.archiveDays),
      ('Show TV', 'FHD', 0),
    );
    final uhd = (await h.channel(pid, 1003))!;
    final uhdParsed = parseQuality('UHD Test 4K');
    expect(uhd.displayName, uhdParsed.displayName);
    expect(uhd.quality, '4K');
    final kanalD = (await h.channel(pid, 1004))!;
    expect((kanalD.displayName, kanalD.quality), ('Kanal D', 'SD'));
    final hls = (await h.channel(pid, 1005))!;
    expect((hls.displayName, hls.quality), ('Haber Canlı HLS', null));
    final kids = (await h.channel(pid, 1006))!;
    final kidsCategory = c.liveCategories.firstWhere(
      (cat) => cat.name == MockFixtures.cocukCategoryName,
    );
    expect(kids.displayName, 'Çocuk Kilitli');
    expect(kids.categoryId, kidsCategory.id);
    final trtHaber = (await h.channel(pid, 1010))!;
    expect(trtHaber.archiveDays, 7);

    final ulusal = (await h.category(
      pid,
      SectionKind.live,
      MockFixtures.ulusalCategoryId,
    ))!;
    expect(ulusal.name, MockFixtures.ulusalCategoryName);
  });

  test('channels with a direct source keep only absolute URLs', () async {
    final withDirect = h.catalog.channels.where(
      (ch) => ch.directSourcePath != null,
    );
    for (final ch in withDirect) {
      final row = (await h.channel(pid, ch.streamId))!;
      expect(row.directSource, '${h.base}${ch.directSourcePath}');
    }
    expect(await h.count('channels', pid, "direct_source = ''"), 0);
  });

  test('movie 3001 and series 5001 carry their metadata', () async {
    final c = h.catalog;
    final movie = (await h.movie(pid, MockFixtures.kisUykusu))!;
    final mock = c.movieById(MockFixtures.kisUykusu)!;
    expect(movie.name, MockFixtures.kisUykusuName);
    expect(movie.containerExt, 'mkv');
    expect(movie.categoryId, mock.categoryId);
    expect(movie.year, mock.year);
    expect(movie.tmdbId, mock.tmdbId);
    expect(movie.added, isNotNull);
    expect(movie.poster, mock.posterPath == null ? isNull : contains('/img/'));
    if (mock.rating != null) {
      expect(movie.rating, closeTo(mock.rating!, 0.051));
    }

    final series = (await h.series(pid, MockFixtures.sicakKafa))!;
    final mockSeries = c.seriesById(MockFixtures.sicakKafa)!;
    expect(series.name, MockFixtures.sicakKafaName);
    expect(series.categoryId, mockSeries.categoryId);
    expect(series.year, mockSeries.year);
    expect(series.releaseDate, mockSeries.releaseDate);
    expect(series.cast, contains(MockFixtures.sharedActor));
    expect(series.lastModified, isNotNull);
    expect(series.plot, isNotEmpty);
    if (mockSeries.backdropPaths.isNotEmpty) {
      final backdrops = jsonDecode(series.backdropsJson!) as List<Object?>;
      expect(backdrops, hasLength(mockSeries.backdropPaths.length));
    }
    // Xtream seasons and episodes are fetched lazily by the repositories.
    expect(await h.count('episodes', pid), 0);
  });

  test('search_index finds titles without diacritics, and people', () async {
    final hits = await h.search(pid, ftsQuery('sicak kafa'));
    expect(
      hits,
      contains((
        title: MockFixtures.sicakKafaName,
        kind: 'series',
        ref: '${MockFixtures.sicakKafa}',
      )),
    );
    final movies = await h.search(pid, ftsQuery('kis uykusu'));
    expect(movies.map((r) => (r.kind, r.ref)), contains(('movie', '3001')));
    final channels = await h.search(pid, ftsQuery('trt 1'));
    expect(channels.map((r) => (r.kind, r.ref)), contains(('channel', '1001')));
    final people = await h.search(pid, ftsQuery('nehir aydin'));
    expect(
      people,
      contains((
        title: MockFixtures.sharedActor,
        kind: 'person',
        ref: MockFixtures.sharedActor,
      )),
    );
    // One row per person.
    expect(people.where((r) => r.kind == 'person'), hasLength(1));
    // playlist_id is an INTEGER.
    final other = await h.db
        .customSelect(
          'SELECT COUNT(*) AS n FROM search_index WHERE playlist_id = ?',
          variables: [Variable.withInt(pid + 1)],
        )
        .getSingle();
    expect(other.read<int>('n'), 0);
  });

  test(
    'EPG: programmes, EPG channels, matching and programme_search',
    () async {
      final c = h.catalog;
      final p = await h.playlist(pid);
      final programmes = await h.count('programmes', pid);
      expect(programmes, greaterThan(1000));
      expect(p.programmeCount, programmes);
      expect(events.last.counts[ImportStep.epgParsing], programmes);

      final declared = c.epgChannels.where((e) => e.declared).length;
      final orphans = c.epgChannels.where((e) => !e.declared).length;
      expect(await h.count('epg_channels', pid), declared + orphans);

      Future<String?> matched(int id) async =>
          (await h.channel(pid, id))!.matchedEpgId;
      // Exact id, case-insensitive id, name only, none.
      expect(await matched(1001), c.channelById(1001)!.xmltvId);
      expect(await matched(1010), c.channelById(1010)!.xmltvId);
      expect(c.channelById(1012)!.epgChannelId, isEmpty);
      expect(await matched(1012), c.channelById(1012)!.xmltvId);
      expect(await matched(1008), isNull);
      expect(await matched(1009), isNull);

      final expected = c.channels
          .where((ch) => ch.epgMatch != EpgMatchKind.none)
          .length;
      final matchedCount = await h.count(
        'channels',
        pid,
        'matched_epg_id IS NOT NULL',
      );
      expect(matchedCount, greaterThan(c.channels.length ~/ 2));
      expect(matchedCount, greaterThanOrEqualTo((expected * 0.95).floor()));
      expect(await h.count('channels', pid, 'custom_epg_id IS NOT NULL'), 0);

      // Times are UTC epoch ms inside the window (max archive 7 days).
      final now = DateTime.now().millisecondsSinceEpoch;
      final range = await h.db
          .customSelect(
            'SELECT MIN(stop) AS lo, MAX(start) AS hi FROM programmes '
            'WHERE playlist_id = ?',
            variables: [Variable.withInt(pid)],
          )
          .getSingle();
      expect(range.read<int>('lo'), greaterThan(now - 8 * 86400000));
      expect(range.read<int>('hi'), lessThan(now + 7 * 86400000 + 60000));

      final search = await h.count('programme_search', pid);
      expect(search, greaterThan(0));
      final window = await h.db
          .customSelect(
            'SELECT COUNT(*) AS n FROM programme_search s '
            'JOIN programmes p ON p.id = s.programme_id '
            'WHERE s.playlist_id = ? AND (p.stop <= ? OR p.start >= ?)',
            variables: [
              Variable.withInt(pid),
              Variable.withInt(now - 60000),
              Variable.withInt(now + 48 * 3600000 + 60000),
            ],
          )
          .getSingle();
      expect(window.read<int>('n'), 0);
    },
  );

  test('epgUrl null: the default XMLTV is imported, never stored', () async {
    final p = await h.playlist(pid);
    expect(p.epgUrl, isNull);
    expect(p.programmeCount, greaterThan(0));
    expect(
      h.server.requestLog,
      contains('/xmltv.php?username=$user&password=$pass'),
    );
    final settings = await h.db.select(h.db.settings).get();
    expect(
      settings.map((s) => s.json).join(),
      isNot(contains(MockFixtures.password)),
    );
  });

  test("epgUrl '': the guide is switched off", () async {
    final id = await h.addXtream(epg: false, name: 'No guide');
    expect((await h.playlist(id)).epgUrl, '');
    h.server.clearRequestLog();
    final p = await h.service.run(id);
    expect(p.step, ImportStep.completed, reason: '$p');
    expect(p.plannedSteps, [...ImportStep.contentSteps, ImportStep.completed]);
    expect(p.skippedSteps, containsAll(ImportStep.epgSteps));
    expect(p.statusOf(ImportStep.epgDownloading), ImportStepStatus.skipped);
    expect(h.server.requestLog.where((r) => r.contains('xmltv')), isEmpty);
    expect(await h.count('programmes', id), 0);
    final row = await h.playlist(id);
    expect(row.epgUrl, '');
    expect(row.lastEpgReloadAt, isNull);
    // An EPG-only import has nothing to do.
    final epgOnly = await h.service.run(id, scope: ImportScope.epg);
    expect(epgOnly.step, ImportStep.completed);
    expect(epgOnly.plannedSteps, [ImportStep.completed]);
  });

  test('a second start joins the running import', () async {
    final id = await h.addXtream(epg: false, name: 'Second');
    final first = h.service.start(id, scope: ImportScope.content);
    expect(h.service.isRunning(id), isTrue);
    final second = h.service.start(id, scope: ImportScope.epg);
    final results = await Future.wait([first.toList(), second.toList()]);
    expect(results[0].last.step, ImportStep.completed);
    expect(results[1].last.step, ImportStep.completed);
    expect(results[1].last.scope, ImportScope.content);
    expect(h.service.isRunning(id), isFalse);
    expect(h.service.lastResult(id)?.succeeded, isTrue);
    // EPG skipped: no EPG URL.
    expect(results[0].last.skippedSteps, containsAll(ImportStep.epgSteps));
    expect(
      results[0].last.statusOf(ImportStep.epgParsing),
      ImportStepStatus.skipped,
    );
  });

  test('watch reports the run, then null', () async {
    final id = await h.addXtream(epg: false, name: 'Watched');
    final seen = <ImportProgress?>[];
    final sub = h.service.watch(id).listen(seen.add);
    await pumpEventQueue();
    expect(seen, [null]);
    final result = await h.service.run(id, scope: ImportScope.content);
    await pumpEventQueue();
    await sub.cancel();
    expect(result.succeeded, isTrue);
    expect(seen.first, isNull);
    expect(seen.last, isNull);
    final progress = seen.whereType<ImportProgress>().toList();
    expect(progress.first.step, ImportStep.connecting);
    expect(progress.last.step, ImportStep.completed);
  });

  test('a late listener gets the latest snapshot', () async {
    final id = await h.addXtream(epg: false, name: 'Late');
    final stream = h.service.start(id, scope: ImportScope.content);
    // Wait until the import is well under way, then subscribe.
    await stream.firstWhere((e) => e.step == ImportStep.movies);
    final late = await h.service.start(id).first;
    expect(late.step.index, greaterThanOrEqualTo(ImportStep.movies.index));
    await stream.last;
  });
}
