import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../tools/mock_server/src/server.dart';
import 'helpers.dart';

void main() {
  late FakeMedia media;
  late MockServer server;
  late String api;

  setUpAll(() async {
    media = await FakeMedia.create();
    server = await MockServer.start(
      port: 0,
      mediaDir: media.mediaDir,
      liveDir: media.liveDir,
    );
    api = '${server.baseUrl}/player_api.php';
  });

  tearDownAll(() async {
    await server.stop();
    await media.delete();
  });

  Future<Object?> action(String name, [String extra = '']) async {
    final r = await fetch('$api?$account&action=$name$extra');
    expect(r.status, 200, reason: name);
    return r.json;
  }

  group('authentication', () {
    test('kanal/test123 is active', () async {
      final r = await fetch('$api?$account');
      expect(r.status, 200);
      expect(r.header('content-type'), startsWith('application/json'));
      final body = r.json! as Map<String, Object?>;
      final user = body['user_info']! as Map<String, Object?>;
      final info = body['server_info']! as Map<String, Object?>;
      expect(user['auth'], 1);
      expect(user['status'], 'Active');
      expect(
        user['exp_date'],
        '${DateTime.utc(2027, 3, 1).millisecondsSinceEpoch ~/ 1000}',
      );
      expect(user['max_connections'], '2');
      expect(user['active_cons'], '0');
      expect(user['allowed_output_formats'], ['m3u8', 'ts']);
      expect(info['timezone'], 'Europe/Istanbul');
      expect(info['port'], '${server.port}');
      // time_now − timestamp_now is the server offset (+03:00).
      final nowSeconds = info['timestamp_now']! as int;
      final local = DateTime.parse(
        '${(info['time_now']! as String).replaceFirst(' ', 'T')}Z',
      );
      expect(local.millisecondsSinceEpoch ~/ 1000 - nowSeconds, 3 * 3600);
      expect(
        (DateTime.now().millisecondsSinceEpoch ~/ 1000 - nowSeconds).abs(),
        lessThan(5),
      );
    });

    test('expired/test123 reports Expired with auth 1', () async {
      final r = await fetch('$api?username=expired&password=test123');
      expect(r.status, 200);
      final user = (r.json! as Map)['user_info'] as Map;
      expect(user['auth'], 1);
      expect(user['status'], 'Expired');
      final lists = await fetch(
        '$api?username=expired&password=test123&action=get_live_streams',
      );
      expect(lists.json, isEmpty);
    });

    test('anything else is HTTP 401 with auth 0', () async {
      for (final query in [
        'username=kanal&password=wrong',
        'username=x&password=y',
        '',
      ]) {
        final r = await fetch('$api?$query');
        expect(r.status, 401, reason: query);
        expect(r.json, {
          'user_info': {'auth': 0},
        });
      }
      final r = await fetch(
        '$api?username=nobody&password=x&action=get_live_streams',
      );
      expect(r.status, 401);
    });

    test('POST form bodies work too', () async {
      final r = await fetch(
        api,
        method: 'POST',
        body: '$account&action=get_vod_categories',
      );
      expect(r.status, 200);
      expect(r.json, isA<List<Object?>>());
    });
  });

  group('actions', () {
    test('categories have id, name and parent', () async {
      for (final name in [
        'get_live_categories',
        'get_vod_categories',
        'get_series_categories',
      ]) {
        final list = (await action(name))! as List;
        expect(list, isNotEmpty);
        for (final c in list.cast<Map<String, Object?>>()) {
          expect(c['category_id'], isA<String>());
          expect(c['category_name'], isA<String>());
          expect(c['parent_id'], 0);
        }
      }
    });

    test('some actions answer JSON as text/html (like real panels)', () async {
      final html = await fetch('$api?$account&action=get_live_categories');
      expect(html.header('content-type'), 'text/html; charset=UTF-8');
      expect(jsonDecode(html.text), isA<List<Object?>>());
      final json = await fetch('$api?$account&action=get_vod_streams');
      expect(json.header('content-type'), startsWith('application/json'));
    });

    test(
      'get_live_streams returns every channel with the Xtream fields',
      () async {
        final list = ((await action('get_live_streams'))! as List)
            .cast<Map<String, Object?>>();
        expect(list, hasLength(300));
        final trt = list.firstWhere((c) => c['stream_id'] == 1001);
        expect(trt['name'], 'TRT 1 HD');
        expect(trt['category_id'], MockFixtures.ulusalCategoryId);
        expect(trt['tv_archive'], 1);
        expect(trt['tv_archive_duration'], 3);
        expect(trt['epg_channel_id'], 'trt1.tr');
        expect(trt['stream_icon'], '${server.baseUrl}/img/logo_00.png');
        for (final key in [
          'num',
          'name',
          'stream_type',
          'stream_id',
          'stream_icon',
          'epg_channel_id', //
          'added',
          'category_id',
          'tv_archive',
          'direct_source',
          'tv_archive_duration',
          'custom_sid',
        ]) {
          expect(trt.containsKey(key), isTrue, reason: key);
        }
        // Odd types that clients must normalize.
        expect(list.any((c) => c['num'] is String), isTrue);
        expect(list.any((c) => c['stream_id'] is String), isTrue);
        expect(list.any((c) => c['stream_icon'] == null), isTrue);
        expect(list.any((c) => c['stream_icon'] == ''), isTrue);
        expect(list.any((c) => c['category_id'] == null), isTrue);
        expect(list.any((c) => c['tv_archive'] == '1'), isTrue);
        expect(list.any((c) => c['added'] is int), isTrue);
        expect(list.any((c) => c['name'] == ''), isTrue);
        expect(list.any((c) => c['stream_type'] == 'radio_streams'), isTrue);
        expect(
          list.any((c) => (c['direct_source'] as String).isNotEmpty),
          isTrue,
        );
      },
    );

    test('category_id filters streams', () async {
      final list =
          (await action('get_live_streams', '&category_id=1'))! as List;
      expect(list, isNotEmpty);
      expect(list.every((c) => (c as Map)['category_id'] == '1'), isTrue);
      expect(await action('get_live_streams', '&category_id=424242'), isEmpty);
      final vod =
          (await action('get_vod_streams', '&category_id=1001'))! as List;
      expect(vod.every((m) => (m as Map)['category_id'] == '1001'), isTrue);
      final series = (await action('get_series', '&category_id=2001'))! as List;
      expect(series.every((s) => (s as Map)['category_id'] == '2001'), isTrue);
    });

    test('get_vod_streams has 2,000 movies with mixed field types', () async {
      final list = ((await action('get_vod_streams'))! as List)
          .cast<Map<String, Object?>>();
      expect(list, hasLength(2000));
      final kis = list.firstWhere((m) => m['stream_id'] == 3001);
      expect(kis['name'], 'Kış Uykusu');
      expect(kis['container_extension'], 'mkv');
      expect(kis['year'], '2014');
      expect(
        list.map((m) => m['rating'].runtimeType).toSet().length,
        greaterThanOrEqualTo(3),
      );
      expect(list.any((m) => m['rating'] == ''), isTrue);
      expect(list.any((m) => m.containsKey('tmdb_id')), isTrue);
      expect(
        list.any(
          (m) => m['tmdb'] is String && (m['tmdb'] as String).isNotEmpty,
        ),
        isTrue,
      );
      expect(
        list.map((m) => m['container_extension']).toSet(),
        containsAll(['mkv', 'mp4']),
      );
      expect(list.any((m) => !m.containsKey('year')), isTrue);
    });

    test('get_vod_info returns info and movie_data', () async {
      final r = await fetch('$api?$account&action=get_vod_info&vod_id=3001');
      expect(r.header('content-type'), startsWith('text/html'));
      final body = r.json! as Map<String, Object?>;
      final info = body['info']! as Map<String, Object?>;
      for (final key in [
        'tmdb_id',
        'name',
        'o_name',
        'cover_big',
        'movie_image',
        'backdrop_path', //
        'releasedate',
        'director',
        'actors',
        'cast',
        'description',
        'plot',
        'genre',
        'age',
        'country',
        'duration_secs',
        'duration',
        'rating',
        'video',
        'audio',
        'bitrate',
      ]) {
        expect(info.containsKey(key), isTrue, reason: key);
      }
      expect(info['name'], 'Kış Uykusu');
      expect(info['duration'], '01:52:00');
      expect(info['duration_secs'], 6720);
      expect(info['backdrop_path'], isA<List<Object?>>());
      expect((info['video']! as Map)['codec_name'], 'h264');
      expect((info['video']! as Map)['width'], isA<int>());
      expect((info['audio']! as Map)['channels'], isA<int>());
      expect(info['cast'], contains(MockFixtures.sharedActor));
      final data = body['movie_data']! as Map<String, Object?>;
      expect(data['stream_id'], 3001);
      expect(data['container_extension'], 'mkv');
      final unknown = await action('get_vod_info', '&vod_id=1');
      expect(unknown, {'info': <Object?>[], 'movie_data': <Object?>[]});
    });

    test('get_series and get_series_info (map shape)', () async {
      final list = ((await action('get_series'))! as List)
          .cast<Map<String, Object?>>();
      expect(list, hasLength(200));
      final sicak = list.firstWhere((s) => s['series_id'] == 5001);
      expect(sicak['name'], 'Sıcak Kafa');
      for (final key in [
        'cover',
        'plot',
        'cast',
        'director',
        'genre',
        'releaseDate',
        'last_modified', //
        'rating', 'backdrop_path', 'category_id',
      ]) {
        expect(sicak.containsKey(key), isTrue, reason: key);
      }
      final info =
          (await action('get_series_info', '&series_id=5001'))!
              as Map<String, Object?>;
      final seasons = (info['seasons']! as List).cast<Map<String, Object?>>();
      expect(seasons.map((s) => s['season_number']), [1, 2]);
      final episodes = info['episodes']! as Map<String, Object?>;
      expect(episodes.keys, ['1', '2']);
      final first = ((episodes['1']! as List).first as Map)
          .cast<String, Object?>();
      expect(first['id'], '${MockFixtures.episodeId(5001, 1, 1)}');
      expect(first['container_extension'], 'mkv');
      final epInfo = first['info']! as Map<String, Object?>;
      for (final key in [
        'movie_image',
        'plot',
        'duration_secs',
        'releasedate',
        'rating',
      ]) {
        expect(epInfo.containsKey(key), isTrue, reason: key);
      }
      expect((info['info']! as Map)['name'], 'Sıcak Kafa');
    });

    test('get_series_info returns a list shape for some series', () async {
      final info =
          (await action(
                'get_series_info',
                '&series_id=${MockFixtures.geceYarisi}',
              ))!
              as Map;
      final episodes = info['episodes'] as List;
      expect(episodes, hasLength(4));
      expect(((episodes.first as List).first as Map)['season'], 0);
      final noSeasons =
          (await action(
                'get_series_info',
                '&series_id=${MockFixtures.maviKapi}',
              ))!
              as Map;
      expect(noSeasons['seasons'], isEmpty);
      expect((noSeasons['episodes'] as Map).keys, ['1', '2']);
      final unknown = (await action('get_series_info', '&series_id=1'))! as Map;
      expect(unknown['seasons'], isEmpty);
    });

    test('get_short_epg returns base64 titles around now', () async {
      final r = await fetch(
        '$api?$account&action=get_short_epg&stream_id=1001&limit=3',
      );
      final listings = ((r.json! as Map)['epg_listings'] as List)
          .cast<Map<String, Object?>>();
      expect(listings, hasLength(3));
      final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final first = listings.first;
      expect(
        int.parse(first['start_timestamp']! as String),
        lessThanOrEqualTo(nowSeconds),
      );
      expect(
        int.parse(first['stop_timestamp']! as String),
        greaterThan(nowSeconds),
      );
      for (final l in listings) {
        expect(utf8.decode(base64.decode(l['title']! as String)), isNotEmpty);
        base64.decode(l['description']! as String);
        expect(
          l['start'],
          matches(RegExp(r'^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d$')),
        );
        // `start` is server time (+03:00) of `start_timestamp`.
        final start = DateTime.parse(
          '${(l['start']! as String).replaceFirst(' ', 'T')}Z',
        );
        expect(
          start.millisecondsSinceEpoch ~/ 1000 -
              int.parse(l['start_timestamp']! as String),
          3 * 3600,
        );
      }
      final none = (await action('get_short_epg', '&stream_id=1008'))! as Map;
      expect(none['epg_listings'], isEmpty);
    });

    test('get_simple_data_table flags now_playing and has_archive', () async {
      final table =
          ((await action('get_simple_data_table', '&stream_id=1001'))!
                  as Map)['epg_listings']
              as List;
      final rows = table.cast<Map<String, Object?>>();
      expect(rows.where((r) => r['now_playing'] == 1), hasLength(1));
      expect(rows.where((r) => r['has_archive'] == 1), isNotEmpty);
      final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      for (final r in rows.where((r) => r['has_archive'] == 1)) {
        expect(
          int.parse(r['stop_timestamp']! as String),
          lessThanOrEqualTo(nowSeconds),
        );
      }
      final noArchive =
          ((await action('get_simple_data_table', '&stream_id=1002'))!
                  as Map)['epg_listings']
              as List;
      expect(noArchive, isNotEmpty);
      expect(noArchive.every((r) => (r as Map)['has_archive'] == 0), isTrue);
    });

    test('unknown actions answer an empty list', () async {
      expect(await action('get_everything'), isEmpty);
    });
  });
}
