import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/repositories/playlist_repository.dart';
import 'package:carina/data/repositories/stream_url_resolver.dart';
import 'package:carina/data/settings/settings_store.dart';
import 'package:carina/data/sources/catchup/catchup.dart';

import 'fixtures.dart';

void main() {
  late R1Env env;
  late PlaylistRepository playlists;
  late StreamUrlResolver resolver;
  late FakeClock clock;

  setUp(() async {
    env = await R1Env.create();
    clock = FakeClock(DateTime.utc(2026, 10, 17, 19));
    playlists = PlaylistRepository(env.db, env.secrets, env.settings);
    resolver = StreamUrlResolver(playlists, env.settings, clock: clock.call);
  });
  tearDown(() => env.dispose());

  Future<ChannelRow> channelRow(int pid, String id) =>
      (env.db.select(env.db.channels)
            ..where((c) => c.playlistId.equals(pid) & c.providerId.equals(id)))
          .getSingle();

  group('Xtream', () {
    late int pid;

    Future<int> xtream({
      List<String> formats = const ['m3u8', 'ts', 'rtmp'],
      Duration offset = Duration.zero,
      String username = 'kanal',
      String password = 'test123',
    }) => env.playlist(
      server: 'http://panel.example:8080/',
      username: username,
      password: password,
      account: xtreamAccountJson(formats: formats, offset: offset),
    );

    setUp(() async {
      pid = await xtream();
      await env.channel(pid, '1001', 'TRT 1', archiveDays: 3);
    });

    test('live TS by default, live flag, masked URL', () async {
      final s = await resolver.live(pid, await channelRow(pid, '1001'));
      expect(s.url, 'http://panel.example:8080/live/kanal/test123/1001.ts');
      expect(s.isLive, isTrue);
      expect(s.userAgent, isNull, reason: 'engine default');
      expect(s.referer, isNull);
      expect(s.headers, isEmpty);
      expect(s.maskedUrl, isNot(contains('test123')));
      expect(s.toString(), isNot(contains('test123')));
    });

    test('output format follows the setting within allowed formats', () async {
      final ch = await channelRow(pid, '1001');
      await env.settings.set(
        PlaylistSettings.liveOutputFormat,
        'm3u8',
        playlistId: pid,
      );
      expect((await resolver.live(pid, ch)).url, endsWith('/1001.m3u8'));

      final onlyHls = await xtream(formats: ['m3u8']);
      await env.channel(onlyHls, '1001', 'TRT 1');
      expect(
        (await resolver.live(onlyHls, await channelRow(onlyHls, '1001'))).url,
        endsWith('/1001.m3u8'),
        reason: 'ts preferred but not allowed',
      );

      final onlyTs = await xtream(formats: ['ts']);
      await env.channel(onlyTs, '1001', 'TRT 1');
      await env.settings.set(
        PlaylistSettings.liveOutputFormat,
        'm3u8',
        playlistId: onlyTs,
      );
      expect(
        (await resolver.live(onlyTs, await channelRow(onlyTs, '1001'))).url,
        endsWith('/1001.ts'),
      );
    });

    test('a usable direct_source wins', () async {
      await env.channel(
        pid,
        '1002',
        'Direct',
        directSource: ' http://cdn.example/direct/index.m3u8 ',
      );
      await env.channel(pid, '1003', 'Junk', directSource: '0');
      expect(
        (await resolver.live(pid, await channelRow(pid, '1002'))).url,
        'http://cdn.example/direct/index.m3u8',
      );
      expect(
        (await resolver.live(pid, await channelRow(pid, '1003'))).url,
        endsWith('/live/kanal/test123/1003.ts'),
      );
    });

    test('special characters in credentials are encoded', () async {
      final odd = await xtream(username: 'ka@nal', password: 'p@ss/w rd+&');
      await env.channel(odd, '7', 'Odd', archiveDays: 1);
      final s = await resolver.live(odd, await channelRow(odd, '7'));
      expect(
        s.url,
        'http://panel.example:8080/live/ka%40nal/p%40ss%2Fw%20rd%2B%26/7.ts',
      );
      final segments = Uri.parse(s.url).pathSegments;
      expect(segments.sublist(1, 3), ['ka@nal', 'p@ss/w rd+&']);
      final fallback = (await resolver.catchupFallback(
        odd,
        await channelRow(odd, '7'),
        DateTime.utc(2026, 10, 17, 18),
        DateTime.utc(2026, 10, 17, 18, 30),
      ))!;
      final q = Uri.parse(fallback.url).queryParameters;
      expect(q['username'], 'ka@nal');
      expect(q['password'], 'p@ss/w rd+&');
    });

    test(
      'timeshift uses the server clock (+3 h) and rounds minutes up',
      () async {
        final plus3 = await xtream(offset: const Duration(hours: 3));
        await env.channel(plus3, '1001', 'TRT 1', archiveDays: 3);
        final ch = await channelRow(plus3, '1001');
        final start = DateTime.utc(2026, 10, 17, 17, 30);
        final end = DateTime.utc(2026, 10, 17, 18, 45, 30);
        final s = await resolver.catchup(plus3, ch, start, end);
        expect(
          s.url,
          'http://panel.example:8080/timeshift/kanal/test123/76/'
          '2026-10-17:20-30/1001.ts',
        );
        expect(s.isLive, isFalse);
        final f = (await resolver.catchupFallback(plus3, ch, start, end))!;
        expect(
          f.url,
          'http://panel.example:8080/streaming/timeshift.php?username=kanal'
          '&password=test123&stream=1001&start=2026-10-17:20-30&duration=76',
        );
      },
    );

    test('no archive, no catch-up', () async {
      await env.channel(pid, '1004', 'No archive');
      final ch = await channelRow(pid, '1004');
      final start = DateTime.utc(2026, 10, 17, 17);
      final end = DateTime.utc(2026, 10, 17, 18);
      await expectLater(
        resolver.catchup(pid, ch, start, end),
        throwsA(
          isA<StreamResolveException>().having(
            (e) => e.error,
            'error',
            StreamResolveError.noCatchup,
          ),
        ),
      );
      expect(await resolver.catchupFallback(pid, ch, start, end), isNull);
    });

    test('movies and episodes', () async {
      await env.movie(pid, '3001', 'Kış Uykusu', containerExt: 'mkv');
      await env.movie(pid, '3002', 'No ext');
      final movies = await env.db.select(env.db.movies).get();
      final m1 = await resolver.movie(pid, movies[0]);
      expect(m1.url, 'http://panel.example:8080/movie/kanal/test123/3001.mkv');
      expect(m1.isLive, isFalse);
      expect(
        (await resolver.movie(pid, movies[1])).url,
        endsWith('/movie/kanal/test123/3002.mp4'),
      );
      await env.db
          .into(env.db.episodes)
          .insert(
            EpisodesCompanion.insert(
              playlistId: pid,
              providerId: '9001',
              seriesId: '5001',
              season: 1,
              episodeNum: 1,
              title: 'Pilot',
              containerExt: const Value('mp4'),
            ),
          );
      final ep = (await env.db.select(env.db.episodes).get()).single;
      expect(
        (await resolver.episode(pid, ep)).url,
        'http://panel.example:8080/series/kanal/test123/9001.mp4',
      );
    });

    test('errors', () async {
      final ch = await channelRow(pid, '1001');
      env.secrets.values.clear();
      final noPassword = PlaylistRepository(env.db, env.secrets, env.settings);
      final r = StreamUrlResolver(noPassword, env.settings);
      await expectLater(
        r.live(pid, ch),
        throwsA(
          isA<StreamResolveException>().having(
            (e) => e.error,
            'error',
            StreamResolveError.missingCredentials,
          ),
        ),
      );
      await expectLater(
        resolver.live(999, ch),
        throwsA(
          isA<StreamResolveException>().having(
            (e) => e.error,
            'error',
            StreamResolveError.playlistNotFound,
          ),
        ),
      );
      await env.channel(pid, 'drm', 'DRM', unsupported: true);
      await expectLater(
        resolver.live(pid, await channelRow(pid, 'drm')),
        throwsA(
          isA<StreamResolveException>().having(
            (e) => e.error,
            'error',
            StreamResolveError.unsupported,
          ),
        ),
      );
    });
  });

  group('M3U', () {
    late int pid;
    const stream = 'http://lists.example/live/user1/pass1/55.ts';
    final start = DateTime.utc(2026, 10, 17, 17, 30);
    final end = DateTime.utc(2026, 10, 17, 18, 15);

    setUp(() async {
      pid = await env.playlist(
        type: PlaylistType.m3u,
        m3uUrl: 'http://lists.example/tv.m3u',
      );
    });

    test('entry headers: agent, referer and the rest', () async {
      await env.channel(
        pid,
        'e1',
        'Entry',
        streamUrl: stream,
        headersJson: jsonEncode({
          'User-Agent': 'EntryUA/1',
          'Referrer': 'http://ref.example/',
          'X-Forwarded-For': '1.2.3.4',
        }),
      );
      final s = await resolver.live(pid, await channelRow(pid, 'e1'));
      expect(s.url, stream);
      expect(s.isLive, isTrue);
      expect(s.userAgent, 'EntryUA/1');
      expect(s.referer, 'http://ref.example/');
      expect(s.headers, {'X-Forwarded-For': '1.2.3.4'});
    });

    test('User-Agent: entry > playlist custom > setting', () async {
      await env.channel(pid, 'plain', 'Plain', streamUrl: stream);
      await env.channel(
        pid,
        'ua',
        'UA',
        streamUrl: stream,
        headersJson: '{"user-agent":"EntryUA/1"}',
      );
      final plain = await channelRow(pid, 'plain');
      final withUa = await channelRow(pid, 'ua');
      Future<String?> agent(int p, ChannelRow c) async =>
          (await resolver.live(p, c)).userAgent;

      expect(await agent(pid, plain), isNull);
      await env.settings.set(
        PlaylistSettings.userAgentMode,
        'vlc',
        playlistId: pid,
      );
      expect(await agent(pid, plain), vlcUserAgent);
      await env.settings.set(
        PlaylistSettings.userAgentMode,
        'custom',
        playlistId: pid,
      );
      await env.settings.set(
        PlaylistSettings.userAgentCustom,
        'MyCustom/3',
        playlistId: pid,
      );
      expect(await agent(pid, plain), 'MyCustom/3');
      expect(await agent(pid, withUa), 'EntryUA/1');

      final custom = await env.playlist(
        type: PlaylistType.m3u,
        m3uUrl: 'http://lists.example/b.m3u',
        userAgent: 'PlaylistUA/2',
      );
      await env.channel(custom, 'plain', 'Plain', streamUrl: stream);
      await env.channel(
        custom,
        'ua',
        'UA',
        streamUrl: stream,
        headersJson: '{"User-Agent":"EntryUA/1"}',
      );
      await env.settings.set(
        PlaylistSettings.userAgentMode,
        'vlc',
        playlistId: custom,
      );
      expect(
        await agent(custom, await channelRow(custom, 'plain')),
        'PlaylistUA/2',
      );
      expect(await agent(custom, await channelRow(custom, 'ua')), 'EntryUA/1');
    });

    test('Referer: entry > setting', () async {
      await env.channel(pid, 'plain', 'Plain', streamUrl: stream);
      await env.channel(
        pid,
        'ref',
        'Ref',
        streamUrl: stream,
        headersJson: '{"Referer":"http://entry.ref/"}',
      );
      await env.settings.set(
        PlaylistSettings.referer,
        ' http://setting.ref/ ',
        playlistId: pid,
      );
      expect(
        (await resolver.live(pid, await channelRow(pid, 'plain'))).referer,
        'http://setting.ref/',
      );
      expect(
        (await resolver.live(pid, await channelRow(pid, 'ref'))).referer,
        'http://entry.ref/',
      );
    });

    test('every catch-up mode is delegated to buildCatchupUrl', () async {
      final modes = <String, String?>{
        'default': 'http://archive.example/{channel}/{utc}-{duration}.ts',
        'append': '?start={utc}&end={utcend}',
        'shift': null,
        'timeshift': null,
        'flussonic': null,
        'fs': null,
        'xc': null,
      };
      var i = 0;
      for (final e in modes.entries) {
        final id = 'c${i++}';
        await env.channel(
          pid,
          id,
          'Kanal $i',
          streamUrl: stream,
          archiveDays: 2,
          catchupType: e.key,
          catchupSource: e.value,
        );
        final s = await resolver.catchup(
          pid,
          await channelRow(pid, id),
          start,
          end,
        );
        final expected = buildCatchupUrl(
          streamUrl: stream,
          mode: e.key,
          source: e.value,
          startUtc: start,
          endUtc: end,
          nowUtc: clock.now,
          channelName: 'Kanal $i',
        );
        expect(expected, isNotNull, reason: e.key);
        expect(s.url, expected, reason: e.key);
        expect(s.isLive, isFalse);
      }
      final shift = await resolver.catchup(
        pid,
        await channelRow(pid, 'c2'),
        start,
        end,
      );
      final utc = start.millisecondsSinceEpoch ~/ 1000;
      expect(shift.url, startsWith('$stream?utc=$utc&lutc='));
      final xc = await resolver.catchup(
        pid,
        await channelRow(pid, 'c6'),
        start,
        end,
      );
      expect(
        xc.url,
        'http://lists.example/timeshift/user1/pass1/45/2026-10-17:17-30/55.ts',
      );
    });

    test('header defaults apply when the entry has no mode', () async {
      final withHeader = await env.playlist(
        type: PlaylistType.m3u,
        m3uUrl: 'http://lists.example/c.m3u',
        m3uHeader: {'catchup': 'append', 'catchupSource': '&archive={utc}'},
      );
      await env.channel(
        withHeader,
        'h',
        'H',
        streamUrl: 'http://s.example/live.m3u8?token=abc',
        archiveDays: 1,
      );
      final s = await resolver.catchup(
        withHeader,
        await channelRow(withHeader, 'h'),
        start,
        end,
      );
      expect(
        s.url,
        'http://s.example/live.m3u8?token=abc'
        '&archive=${start.millisecondsSinceEpoch ~/ 1000}',
      );
      expect(s.maskedUrl, contains('token=***'));
    });

    test('errors: no URL, no catch-up', () async {
      await env.channel(pid, 'nourl', 'No URL');
      await expectLater(
        resolver.live(pid, await channelRow(pid, 'nourl')),
        throwsA(
          isA<StreamResolveException>().having(
            (e) => e.error,
            'error',
            StreamResolveError.noStreamUrl,
          ),
        ),
      );
      await env.channel(pid, 'live', 'Live', streamUrl: stream);
      await expectLater(
        resolver.catchup(pid, await channelRow(pid, 'live'), start, end),
        throwsA(
          isA<StreamResolveException>().having(
            (e) => e.error,
            'error',
            StreamResolveError.noCatchup,
          ),
        ),
      );
      expect(
        await resolver.catchupFallback(
          pid,
          await channelRow(pid, 'live'),
          start,
          end,
        ),
        isNull,
      );
    });

    test('M3U movies use the stored URL and entry headers', () async {
      await env.movie(
        pid,
        'm1',
        'Film',
        streamUrl: 'http://vod.example/movie/a.mkv',
        headersJson: '{"User-Agent":"VodUA"}',
      );
      final movie = (await env.db.select(env.db.movies).get()).single;
      final s = await resolver.movie(pid, movie);
      expect(s.url, 'http://vod.example/movie/a.mkv');
      expect(s.userAgent, 'VodUA');
      expect(s.isLive, isFalse);
    });
  });
}
