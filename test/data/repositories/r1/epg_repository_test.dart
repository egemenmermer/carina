import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/net/dio_factory.dart';
import 'package:carina/data/repositories/epg_repository.dart';
import 'package:carina/data/repositories/live_repository.dart';
import 'package:carina/data/repositories/playlist_repository.dart';
import 'package:carina/data/repositories/repository_models.dart';

import 'fixtures.dart';

DateTime utc(int h, [int m = 0, int day = 17]) =>
    DateTime.utc(2026, 10, day, h, m);

void main() {
  late R1Env env;
  late PlaylistRepository playlists;
  late EpgRepository repo;
  late FakeClock clock;
  late int pid;

  setUp(() async {
    env = await R1Env.create();
    clock = FakeClock(utc(11, 30));
    playlists = PlaylistRepository(env.db, env.secrets, env.settings);
    repo = EpgRepository(env.db, playlists, clock: clock.call);
    pid = await env.playlist();
    // trt1: 10–11 Sabah, 11–12 Öğle, 12–12:30 Haber, gap, 13–14 Film.
    await env.programme(pid, 'trt1', utc(10), utc(11), 'Sabah');
    await env.programme(pid, 'trt1', utc(11), utc(12), 'Öğle');
    await env.programme(pid, 'trt1', utc(12), utc(12, 30), 'Haber');
    await env.programme(pid, 'trt1', utc(13), utc(14), 'Film');
    // show: 09–13 Uzun (spans every window below), 13–15 Dizi.
    await env.programme(pid, 'show', utc(9), utc(13), 'Uzun');
    await env.programme(pid, 'show', utc(13), utc(15), 'Dizi');
    // Another playlist with the same key must not leak in.
    final other = await env.playlist(name: 'Other');
    await env.programme(other, 'trt1', utc(11), utc(12), 'Yabancı');
  });
  tearDown(() async {
    repo.dispose();
    await env.dispose();
  });

  List<String> titles(Iterable<ProgrammeView> list) => [
    for (final p in list) p.title,
  ];

  group('nowNext', () {
    test('one query for many keys', () async {
      final r = await repo.nowNext(pid, ['trt1', 'show', 'none', 'trt1']);
      expect(r.keys, ['trt1', 'show', 'none']);
      expect(r['trt1']!.now!.title, 'Öğle');
      expect(r['trt1']!.next!.title, 'Haber');
      expect(r['show']!.now!.title, 'Uzun');
      expect(r['show']!.next!.title, 'Dizi');
      expect(r['none'], NowNext.empty);
      expect(r['trt1']!.now!.start, utc(11));
      expect(r['trt1']!.now!.start.isUtc, isTrue);
    });

    test('boundaries and gaps', () async {
      var r = await repo.nowNext(pid, ['trt1'], at: utc(11));
      expect(r['trt1']!.now!.title, 'Öğle', reason: 'starts exactly now');
      r = await repo.nowNext(pid, ['trt1'], at: utc(12, 45));
      expect(r['trt1']!.now, isNull, reason: 'gap');
      expect(r['trt1']!.next!.title, 'Film');
      r = await repo.nowNext(pid, ['trt1'], at: utc(15));
      expect(r['trt1'], NowNext.empty);
      r = await repo.nowNext(pid, ['trt1'], at: utc(8));
      expect(r['trt1']!.now, isNull);
      expect(r['trt1']!.next!.title, 'Sabah');
    });
  });

  group('guide window', () {
    test('includes programmes that started before the window', () async {
      final g = await repo.guide(
        pid,
        ['trt1', 'show', 'none'],
        utc(11, 30),
        utc(13, 30),
      );
      expect(titles(g['trt1']!), ['Öğle', 'Haber', 'Film']);
      expect(titles(g['show']!), ['Uzun', 'Dizi']);
      expect(g['none'], isEmpty);
    });

    test('a programme ending at the window start is outside', () async {
      final g = await repo.guide(pid, ['trt1'], utc(12), utc(13));
      expect(titles(g['trt1']!), ['Haber']);
      final h = await repo.guide(pid, ['trt1'], utc(12, 40), utc(12, 50));
      expect(h['trt1'], isEmpty, reason: 'gap');
    });

    test('programmes() and upcoming()', () async {
      expect(
        titles(await repo.programmes(pid, 'trt1', utc(10, 30), utc(11, 30))),
        ['Sabah', 'Öğle'],
      );
      expect(titles(await repo.upcoming(pid, 'trt1')), ['Haber', 'Film']);
      expect(
        titles(
          await repo.upcoming(pid, 'trt1', window: const Duration(hours: 1)),
        ),
        ['Haber'],
      );
    });

    test('data range for the day picker', () async {
      final range = (await repo.dataRange(pid))!;
      expect(range.start, utc(9));
      expect(range.end, utc(15));
      final empty = await env.playlist(name: 'Empty');
      expect(await repo.dataRange(empty), isNull);
    });
  });

  group('archive', () {
    late ChannelRow channel;

    setUp(() async {
      await env.channel(
        pid,
        '77',
        'Arşiv TV',
        matchedEpgId: 'arch',
        archiveDays: 2,
      );
      await env.channel(pid, '78', 'No Archive', matchedEpgId: 'arch');
      for (
        var t = DateTime.utc(2026, 10, 15, 10);
        t.isBefore(utc(14));
        t = t.add(const Duration(hours: 1))
      ) {
        await env.programme(
          pid,
          'arch',
          t,
          t.add(const Duration(hours: 1)),
          'P ${t.toIso8601String()}',
        );
      }
      channel = (await (env.db.select(
        env.db.channels,
      )..where((c) => c.providerId.equals('77'))).getSingle());
    });

    void checkGrouping(List<ArchiveDay> days) {
      final all = [for (final d in days) ...d.programmes];
      for (var i = 1; i < all.length; i++) {
        expect(all[i].start.isBefore(all[i - 1].start), isTrue);
      }
      for (final d in days) {
        for (final p in d.programmes) {
          final l = p.start.toLocal();
          expect(DateTime(l.year, l.month, l.day), d.date);
        }
      }
      for (var i = 1; i < days.length; i++) {
        expect(days[i].date.isBefore(days[i - 1].date), isTrue);
      }
    }

    test('on air first, then replayable programmes by local day', () async {
      final now = utc(12, 15);
      final days = await repo.archive(pid, channel, now: now);
      checkGrouping(days);
      final all = [for (final d in days) ...d.programmes];
      expect(all.first.start, utc(12), reason: 'ON AIR');
      expect(all.first.isOnAirAt(now), isTrue);
      expect(all[1].start, utc(11));
      expect(all.last.start, DateTime.utc(2026, 10, 15, 13));
      expect(all, hasLength(48));
      expect(all.skip(1).every((p) => p.isReplayableWith(2, now)), isTrue);
    });

    test('replayable boundaries are strict', () async {
      final now = utc(12);
      final all = [
        for (final d in await repo.archive(pid, channel, now: now))
          ...d.programmes,
      ];
      expect(all.first.start, utc(12), reason: 'starts now: on air');
      // 11–12 ends exactly now: neither on air nor replayable.
      expect(all.any((p) => p.start == utc(11)), isFalse);
      expect(all[1].start, utc(10));
      // Starting exactly now − 2 days is outside the window.
      expect(
        all.any((p) => p.start == DateTime.utc(2026, 10, 15, 12)),
        isFalse,
      );
      expect(all.last.start, DateTime.utc(2026, 10, 15, 13));
      expect(all, hasLength(47));
    });

    test('no archive, no list', () async {
      final none = await (env.db.select(
        env.db.channels,
      )..where((c) => c.providerId.equals('78'))).getSingle();
      expect(await repo.archive(pid, none, now: utc(12)), isEmpty);
    });
  });

  test('Custom EPG picker search', () async {
    await env.epgChannel(
      pid,
      'trt1',
      'TRT 1',
      normalized: 'trt 1',
      icon: 'http://i/trt.png',
    );
    await env.epgChannel(pid, 'show.tr', 'Show TV', normalized: 'show tv');
    await env.epgChannel(pid, 'best', 'Best Show', normalized: 'best show');
    await env.epgChannel(
      pid,
      'sicak',
      'Sıcak Kafa TV',
      normalized: 'sicakkafatv',
    );
    await env.epgChannel(pid, 'kanal.d', 'Kanal D', normalized: 'kanal d');
    final all = await repo.epgChannels(pid);
    expect(all.map((c) => c.id), [
      'best',
      'kanal.d',
      'show.tr',
      'sicak',
      'trt1',
    ]);
    final trt = all.firstWhere((c) => c.id == 'trt1');
    expect(trt.nowTitle, 'Öğle');
    expect(trt.icon, 'http://i/trt.png');
    expect(
      (await repo.epgChannels(pid, query: 'sıcak kafa')).map((c) => c.id),
      ['sicak'],
    );
    expect((await repo.epgChannels(pid, query: 'SHOW')).map((c) => c.id), [
      'show.tr',
      'best',
    ]);
    expect((await repo.epgChannels(pid, query: 'kanal.d')).map((c) => c.id), [
      'kanal.d',
    ]);
    expect((await repo.epgChannels(pid, query: '100%')), isEmpty);
    expect(await repo.epgChannels(pid, query: 'trt', limit: 1), hasLength(1));
  });

  group('Xtream short EPG fallback', () {
    late HttpServer server;
    late List<Uri> requests;
    late int xpid;
    late LiveRepository live;
    late EpgRepository shortRepo;

    String b64(String s) => base64.encode(utf8.encode(s));

    setUp(() async {
      requests = [];
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((r) async {
        requests.add(r.uri);
        final q = r.uri.queryParameters;
        Object? body;
        var status = 200;
        switch (q['action']) {
          case null:
            body = xtreamAccountJson(offset: const Duration(hours: 3));
          case 'get_short_epg' when q['stream_id'] == '1001':
            body = {
              'epg_listings': [
                {
                  'title': b64('Akşam Haberleri'),
                  'description': b64('Günün özeti'),
                  'start_timestamp':
                      '${utc(11).millisecondsSinceEpoch ~/ 1000}',
                  'stop_timestamp': '${utc(12).millisecondsSinceEpoch ~/ 1000}',
                },
                {
                  'title': b64('Dizi'),
                  // No timestamps: server wall clock (UTC+3).
                  'start': '2026-10-17 15:00:00',
                  'end': '2026-10-17 16:00:00',
                },
              ],
            };
          case 'get_simple_data_table':
            body = {
              'epg_listings': [
                {
                  'title': b64('Dün'),
                  'start_timestamp':
                      '${utc(9, 0, 16).millisecondsSinceEpoch ~/ 1000}',
                  'stop_timestamp':
                      '${utc(10, 0, 16).millisecondsSinceEpoch ~/ 1000}',
                  'has_archive': 1,
                },
              ],
            };
          default:
            status = 500;
            body = {'error': 'boom'};
        }
        r.response
          ..statusCode = status
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(body));
        await r.response.close();
      });
      xpid = await env.playlist(
        name: 'Xtream',
        server: 'http://127.0.0.1:${server.port}',
        account: xtreamAccountJson(offset: const Duration(hours: 3)),
      );
      await env.channel(xpid, '1001', 'Kanal 1', archiveDays: 3);
      await env.channel(xpid, '2002', 'Kanal 2');
      live = LiveRepository(env.db, env.settings, clock: clock.call);
      shortRepo = EpgRepository(
        env.db,
        playlists,
        clock: clock.call,
        dioFactory: () => createDio(retries: 0),
      );
    });
    tearDown(() async {
      shortRepo.dispose();
      await live.dispose();
      await server.close(force: true);
    });

    List<Uri> epgCalls() => requests
        .where((u) => u.queryParameters['action'] == 'get_short_epg')
        .toList();

    test('maps listings and caches them for 30 minutes', () async {
      final ch = (await live.channel(xpid, '1001'))!;
      expect(ch.epgKey, isNull);
      final list = await shortRepo.shortEpg(xpid, ch.row);
      expect(titles(list), ['Akşam Haberleri', 'Dizi']);
      expect(list.first.description, 'Günün özeti');
      expect(list.first.start, utc(11));
      expect(list.first.stop, utc(12));
      expect(list.first.epgChannelId, 'xtream:1001');
      expect(list.first.id, isNull);
      expect(list[1].start, utc(12), reason: 'server time 15:00 at UTC+3');
      final call = epgCalls().single;
      expect(call.queryParameters['stream_id'], '1001');
      expect(call.queryParameters['limit'], '10');
      expect(call.queryParameters['username'], 'kanal');

      clock.advance(const Duration(minutes: 29));
      await shortRepo.shortEpg(xpid, ch.row);
      expect(epgCalls(), hasLength(1), reason: 'cached');
      clock.advance(const Duration(minutes: 2));
      await shortRepo.shortEpg(xpid, ch.row);
      expect(epgCalls(), hasLength(2), reason: 'expired after 30 minutes');

      shortRepo.clearShortEpgCache(xpid);
      await Future.wait([
        shortRepo.shortEpg(xpid, ch.row),
        shortRepo.shortEpg(xpid, ch.row),
      ]);
      expect(epgCalls(), hasLength(3), reason: 'one request in flight');
    });

    test('channel helpers fall back to the short EPG', () async {
      final ch = (await live.channel(xpid, '1001'))!;
      final nn = await shortRepo.nowNextForChannel(xpid, ch);
      expect(nn.now!.title, 'Akşam Haberleri');
      expect(nn.next!.title, 'Dizi');
      expect(titles(await shortRepo.upcomingForChannel(xpid, ch)), ['Dizi']);
      final archive = await shortRepo.archive(xpid, ch.row, now: utc(11, 30));
      expect(titles([for (final d in archive) ...d.programmes]), ['Dün']);
    });

    test('stored EPG wins over the short EPG', () async {
      await env.programme(xpid, 'k1', utc(11), utc(12), 'Stored');
      await live.setCustomEpg(xpid, '1001', 'k1');
      final ch = (await live.channel(xpid, '1001'))!;
      final nn = await shortRepo.nowNextForChannel(xpid, ch);
      expect(nn.now!.title, 'Stored');
      expect(epgCalls(), isEmpty);
    });

    test('failures return nothing and are not retried at once', () async {
      final ch = (await live.channel(xpid, '2002'))!;
      expect(await shortRepo.shortEpg(xpid, ch.row), isEmpty);
      expect(await shortRepo.shortEpg(xpid, ch.row), isEmpty);
      expect(epgCalls(), hasLength(1));
      clock.advance(const Duration(minutes: 3));
      await shortRepo.shortEpg(xpid, ch.row);
      expect(epgCalls(), hasLength(2));
    });

    test('M3U playlists never call the API', () async {
      final m3u = await env.playlist(
        type: PlaylistType.m3u,
        m3uUrl: 'http://x/a.m3u',
      );
      await env.channel(m3u, 'z', 'Z');
      final ch = (await live.channel(m3u, 'z'))!;
      expect(await shortRepo.shortEpg(m3u, ch.row), isEmpty);
      expect(await shortRepo.nowNextForChannel(m3u, ch), NowNext.empty);
      expect(requests, isEmpty);
    });
  });
}
