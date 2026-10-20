import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/import/import.dart';
import 'package:carina/data/import/m3u_importer.dart';
import 'package:carina/data/sources/m3u/m3u.dart';
import 'package:carina/data/text/normalize.dart';

import 'import_harness.dart';

void main() {
  late ImportHarness h;
  late int pid;
  late ImportProgress result;

  setUpAll(() async {
    h = await ImportHarness.create();
    pid = await h.addM3u(
      url: '${h.base}/playlist.m3u',
      userAgent: 'CarinaTest/2.0',
    );
    result = await h.service.run(pid);
  });

  tearDownAll(() => h.dispose());

  Future<ChannelRow?> channelByUrl(String url) =>
      (h.db.select(h.db.channels)
            ..where((c) => c.playlistId.equals(pid) & c.streamUrl.equals(url)))
          .getSingleOrNull();

  Future<ChannelRow> channelByName(String name) => (h.db.select(
    h.db.channels,
  )..where((c) => c.playlistId.equals(pid) & c.name.equals(name))).getSingle();

  String live(int id) => '${h.base}/live/$user/$pass/$id.ts';

  test('completes and takes the EPG URL from url-tvg', () async {
    expect(result.step, ImportStep.completed, reason: '$result');
    expect(result.epgError, isNull);
    expect(result.warnings, isEmpty);
    final p = await h.playlist(pid);
    expect(p.epgUrl, '${h.base}/epg.xml.gz');
    final header = M3uHeader.fromJson(
      jsonDecode(p.m3uHeaderJson!) as Map<String, Object?>,
    );
    expect(header.tvgUrls, ['${h.base}/epg.xml.gz']);
    // The guide came from the header URL (gzip).
    expect(p.programmeCount, greaterThan(0));
    expect(p.lastEpgReloadAt, isNotNull);
    expect(result.plannedSteps, contains(ImportStep.epgParsing));
    expect(
      (await channelByUrl(live(1001)))!.matchedEpgId,
      h.catalog.channelById(1001)!.xmltvId,
    );
  });

  test('the playlist User-Agent is sent', () {
    final playlistRequests = h.server.requests.where(
      (r) => r.path.startsWith('/playlist.m3u'),
    );
    expect(playlistRequests, isNotEmpty);
    expect(
      playlistRequests.every((r) => r.userAgent == 'CarinaTest/2.0'),
      isTrue,
    );
    final guide = h.server.requests.where((r) => r.path == '/epg.xml.gz');
    expect(guide.every((r) => r.userAgent == 'CarinaTest/2.0'), isTrue);
  });

  test('live / movie / series split', () async {
    final c = h.catalog;
    // 11 hand-written live edge cases and one VOD-by-extension entry.
    expect(result.counts[ImportStep.liveChannels], c.channels.length + 11);
    expect(result.counts[ImportStep.movies], c.movies.length + 1);
    // A series without a name ("S01E02" entries) is named after its group.
    final groups = {for (final cat in c.seriesCategories) cat.id: cat.name};
    final seriesIds = {
      for (final s in c.series)
        if (c.episodesOf(s).isNotEmpty)
          m3uSeriesId(s.name.trim().isEmpty ? groups[s.categoryId]! : s.name),
    };
    expect(result.counts[ImportStep.series], seriesIds.length);
    expect(await h.count('episodes', pid), c.episodeCount);
    final p = await h.playlist(pid);
    expect(p.liveCount, c.channels.length + 11);
    expect(p.movieCount, c.movies.length + 1);
    expect(p.seriesCount, seriesIds.length);

    final film =
        (await (h.db.select(h.db.movies)..where(
              (m) =>
                  m.playlistId.equals(pid) & m.name.equals('Örnek Film (mp4)'),
            ))
            .getSingle());
    expect(film.containerExt, 'mp4');
    expect(film.categoryId, 'TEST | M3U');
    expect(film.streamUrl, '${h.base}/vod/ornek-film.mp4');

    final kis =
        await (h.db.select(h.db.movies)..where(
              (m) =>
                  m.playlistId.equals(pid) &
                  m.streamUrl.equals('${h.base}/movie/$user/$pass/3001.mkv'),
            ))
            .getSingle();
    expect(kis.name, MockFixtures.kisUykusuName);
    expect(kis.containerExt, 'mkv');
    final vodCategory = c.vodCategories.firstWhere(
      (cat) => cat.id == c.movieById(3001)!.categoryId,
    );
    expect(kis.categoryId, vodCategory.name);
    expect(
      await h.category(pid, SectionKind.movie, vodCategory.name),
      isNotNull,
    );
  });

  test('categories come from group titles per section', () async {
    final trt1 = (await channelByUrl(live(1001)))!;
    expect(trt1.categoryId, MockFixtures.ulusalCategoryName);
    expect(trt1.displayName, 'TRT 1');
    expect(trt1.quality, 'HD');
    expect(trt1.epgId, h.catalog.channelById(1001)!.epgChannelId);
    final ulusal = (await h.category(
      pid,
      SectionKind.live,
      MockFixtures.ulusalCategoryName,
    ))!;
    expect(ulusal.name, MockFixtures.ulusalCategoryName);
    expect(await h.category(pid, SectionKind.live, 'Spor, Canlı'), isNotNull);
    expect(await h.category(pid, SectionKind.live, 'Test'), isNotNull);
    // #EXTGRP only.
    expect(
      (await channelByName('Grup Testi (EXTGRP)')).categoryId,
      'TEST | M3U',
    );
  });

  test('series with seasons and episodes', () async {
    final c = h.catalog;
    final id = m3uSeriesId(MockFixtures.sicakKafaName);
    final series = (await h.series(pid, id))!;
    expect(series.name, MockFixtures.sicakKafaName);
    final mock = c.seriesById(MockFixtures.sicakKafa)!;
    final group = c.seriesCategories.firstWhere(
      (cat) => cat.id == mock.categoryId,
    );
    expect(series.categoryId, group.name);
    final sameName = c.series.where(
      (s) => m3uSeriesId(s.name) == id && c.episodesOf(s).isNotEmpty,
    );
    final expectedEpisodes = sameName.fold<int>(
      0,
      (n, s) => n + c.episodesOf(s).length,
    );
    expect(
      await h.count('episodes', pid, "series_id = '$id'"),
      expectedEpisodes,
    );
    final seasons =
        await (h.db.select(h.db.seasons)
              ..where((s) => s.playlistId.equals(pid) & s.seriesId.equals(id))
              ..orderBy([(s) => OrderingTerm(expression: s.seasonNumber)]))
            .get();
    expect(seasons.map((s) => s.seasonNumber), [
      for (final season in mock.seasons) season.number,
    ]);
    expect(
      seasons.fold<int>(0, (n, s) => n + (s.episodeCount ?? 0)),
      expectedEpisodes,
    );

    final firstId = MockFixtures.episodeId(MockFixtures.sicakKafa, 1, 1);
    final episode =
        await (h.db.select(h.db.episodes)..where(
              (e) =>
                  e.playlistId.equals(pid) &
                  e.streamUrl.like('%/series/$user/$pass/$firstId.%'),
            ))
            .getSingle();
    expect((episode.seriesId, episode.season, episode.episodeNum), (id, 1, 1));
    expect(episode.title, startsWith(MockFixtures.sicakKafaName));
    expect(episode.containerExt, isNotNull);

    final hits = await h.search(pid, ftsQuery('sicak kafa'));
    expect(hits.map((r) => (r.kind, r.ref)), contains(('series', id)));

    final names = await h.db.select(h.db.series).get();
    expect(names.where((s) => isSeriesMarkerOnly(s.name)), isEmpty);
  });

  test('per-entry HTTP headers are stored as JSON', () async {
    final show = (await channelByUrl(live(MockFixtures.showTvFhd)))!;
    expect(jsonDecode(show.headersJson!), {
      'User-Agent': 'CarinaMock/1.0',
      'Referer': '${h.base}/',
    });
    final exthttp = await channelByName('Header Test (EXTHTTP)');
    expect(jsonDecode(exthttp.headersJson!), {
      'User-Agent': 'CarinaMock/1.0',
      'Referer': '${h.base}/',
    });
    final ua = await channelByName('Header Test (User-Agent)');
    expect(jsonDecode(ua.headersJson!), {'User-Agent': 'CarinaMock/1.0'});
    expect(
      (await channelByUrl(live(MockFixtures.kanalDSd)))!.headersJson,
      isNull,
    );
  });

  test('catch-up modes, sources and archive days', () async {
    final c = h.catalog;
    final trt1 = (await channelByUrl(live(1001)))!;
    expect(trt1.catchupType, 'default');
    expect(
      trt1.catchupSource,
      '${h.base}/timeshift/$user/$pass/{duration:60}/{Y}-{m}-{d}:{H}-{M}/1001.ts',
    );
    expect(trt1.archiveDays, 3);
    final trtHaber = (await channelByUrl(live(1010)))!;
    expect((trtHaber.catchupType, trtHaber.archiveDays), ('xc', 7));

    for (final mode in ['append', 'shift', 'flussonic', 'xc', 'default']) {
      final mock = c.channels.firstWhere((ch) => ch.catchupMode == mode);
      final url = mode == 'flussonic'
          ? '${h.base}/fs/ch${mock.streamId}/mpegts'
          : live(mock.streamId);
      final row = (await channelByUrl(url))!;
      expect(row.catchupType, mode, reason: mode);
      expect(row.archiveDays, mock.archiveDays, reason: mode);
      if (mode == 'append') {
        expect(row.catchupSource, '?utc={utc}&lutc={lutc}');
      }
    }
    final shift = await channelByName('Catch-up Shift Test');
    expect((shift.catchupType, shift.archiveDays), ('shift', 3));
    final noArchive = (await channelByUrl(live(1002)))!;
    expect((noArchive.catchupType, noArchive.archiveDays), (null, 0));
  });

  test('a DRM entry is stored as unsupported', () async {
    final drm = await channelByName('DRM Test (Widevine)');
    expect(drm.unsupported, isTrue);
    expect(await h.count('channels', pid, 'unsupported = 1'), 1);
  });

  test('a reload keeps ids stable', () async {
    final before = await h.playlist(pid);
    final again = await h.service.run(pid, scope: ImportScope.content);
    expect(again.step, ImportStep.completed, reason: '$again');
    final after = await h.playlist(pid);
    expect(after.liveCount, before.liveCount);
    expect(after.movieCount, before.movieCount);
    expect(after.seriesCount, before.seriesCount);
    expect(await h.count('episodes', pid), h.catalog.episodeCount);
    // No item is new, so nothing was stamped as added.
    expect(await h.count('channels', pid, 'added IS NOT NULL'), 0);
  });

  test("epgUrl '' is not filled from url-tvg: no guide", () async {
    final id = await h.addM3u(url: '${h.base}/playlist.m3u', epgUrl: '');
    final p = await h.service.run(id);
    expect(p.step, ImportStep.completed, reason: '$p');
    expect(p.skippedSteps, containsAll(ImportStep.epgSteps));
    final row = await h.playlist(id);
    expect(row.epgUrl, '');
    expect(row.m3uHeaderJson, contains('epg.xml.gz'));
    expect(await h.count('programmes', id), 0);
  });

  test('a custom EPG URL is kept', () async {
    final custom = '${h.base}/xmltv.php?username=$user&password=$pass';
    final id = await h.addM3u(url: '${h.base}/playlist.m3u', epgUrl: custom);
    final p = await h.service.run(id);
    expect(p.step, ImportStep.completed, reason: '$p');
    expect((await h.playlist(id)).epgUrl, custom);
    expect(await h.count('programmes', id), greaterThan(0));
  });

  test('a local M3U file imports the same playlist', () async {
    final file = File('${h.tempDir.path}/local.m3u8');
    final client = HttpClient();
    final request = await client.getUrl(Uri.parse('${h.base}/playlist.m3u'));
    final response = await request.close();
    await response.pipe(file.openWrite());
    client.close();
    final id = await h.addM3u(url: file.path, type: PlaylistType.m3uFile);
    final p = await h.service.run(id, scope: ImportScope.content);
    expect(p.step, ImportStep.completed, reason: '$p');
    expect(p.counts[ImportStep.liveChannels], h.catalog.channels.length + 11);
    expect(await file.exists(), isTrue);
  });

  test('M3U reload: removed and added entries, stale episodes', () async {
    final file = File('${h.tempDir.path}/small.m3u');
    const head = '#EXTM3U\n';
    const a =
        '#EXTINF:-1 tvg-id="a.tr" group-title="Haber",A HD\n'
        'http://example.invalid/live/a.ts\n';
    const b =
        '#EXTINF:-1 tvg-id="b.tr" group-title="Haber",B\n'
        'http://example.invalid/live/b.ts\n';
    const c =
        '#EXTINF:-1 tvg-id="c.tr" group-title="Spor",C FHD\n'
        'http://example.invalid/live/c.ts\n';
    const film =
        '#EXTINF:-1 group-title="Filmler",Film Bir (2019)\n'
        'http://example.invalid/movie/u/p/1.mkv\n';
    const e11 =
        '#EXTINF:-1 group-title="Diziler",Dizi S01E01\n'
        'http://example.invalid/series/u/p/11.mp4\n';
    const e12 =
        '#EXTINF:-1 group-title="Diziler",Dizi S01E02 Final\n'
        'http://example.invalid/series/u/p/12.mp4\n';
    const e21 =
        '#EXTINF:-1 group-title="Diziler",Dizi S02E01\n'
        'http://example.invalid/series/u/p/21.mp4\n';
    await file.writeAsString('$head$a$b$film$e11$e12$e21');
    final id = await h.addM3u(url: file.path, type: PlaylistType.m3uFile);
    final first = await h.service.run(id);
    expect(first.step, ImportStep.completed, reason: '$first');
    expect(first.plannedSteps, isNot(contains(ImportStep.epgParsing)));
    expect(await h.count('seasons', id), 2);
    expect(await h.count('episodes', id), 3);
    final movie = await (h.db.select(
      h.db.movies,
    )..where((m) => m.playlistId.equals(id))).getSingle();
    expect(
      (movie.year, movie.containerExt, movie.categoryId),
      (2019, 'mkv', 'Filmler'),
    );
    final finale =
        await (h.db.select(h.db.episodes)
              ..where((e) => e.playlistId.equals(id) & e.episodeNum.equals(2)))
            .getSingle();
    expect(finale.title, 'Final');

    await h.db.customStatement(
      'UPDATE channels SET hidden = 1 WHERE playlist_id = $id',
    );
    await file.writeAsString('$head$a$c$film$e11$e12');
    final second = await h.service.run(id);
    expect(second.step, ImportStep.completed, reason: '$second');
    final names =
        await (h.db.select(h.db.channels)
              ..where((ch) => ch.playlistId.equals(id))
              ..orderBy([(ch) => OrderingTerm(expression: ch.sortIndex)]))
            .get();
    expect(names.map((ch) => (ch.displayName, ch.hidden, ch.added != null)), [
      ('A', true, false),
      ('C', false, true),
    ]);
    expect(await h.count('categories', id, "provider_id = 'Haber'"), 1);
    expect(await h.count('categories', id, "provider_id = 'Spor'"), 1);
    expect(await h.count('seasons', id), 1);
    expect(await h.count('episodes', id), 2);
    expect(await h.count('series', id), 1);
  });
}
