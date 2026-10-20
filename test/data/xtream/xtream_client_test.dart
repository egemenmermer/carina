import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/net/dio_factory.dart';
import 'package:carina/data/sources/source_exception.dart';
import 'package:carina/data/sources/xtream/xtream.dart';

import '../net/test_http_server.dart';

Map<String, Object?> accountJson({String status = 'Active', Object auth = 1}) =>
    {
      'user_info': {
        'username': 'kanal',
        'password': 'test123',
        'auth': auth,
        'status': status,
        'exp_date': '1803859200',
        'is_trial': '0',
        'active_cons': '0',
        'created_at': '1700000000',
        'max_connections': '2',
        'allowed_output_formats': ['m3u8', 'ts', 'rtmp'],
      },
      'server_info': {
        'url': '127.0.0.1',
        'port': '8080',
        'https_port': '8443',
        'server_protocol': 'http',
        'timezone': 'Europe/Istanbul',
        'timestamp_now': 1760700000,
        'time_now': '2025-10-17 14:20:00',
      },
    };

List<Map<String, Object?>> liveRows(String categoryId, List<int> ids) => [
  for (final id in ids)
    {
      'num': id,
      'name': 'Channel $id',
      'stream_id': '$id',
      'stream_icon': '',
      'epg_channel_id': 'ch$id',
      'added': '1700000000',
      'category_id': categoryId,
      'tv_archive': id.isEven ? 1 : 0,
      'tv_archive_duration': '3',
    },
];

void main() {
  late TestHttpServer server;
  late Dio dio;
  late XtreamClient client;

  /// The fake panel's handler for `/player_api.php`, by action.
  late Map<String, FutureOr<void> Function(HttpRequest)> actions;

  setUp(() async {
    server = await TestHttpServer.start();
    actions = {};
    server.route('/player_api.php', (r) async {
      final q = r.uri.queryParameters;
      if (q['username'] != 'kanal' || q['password'] != 'test123') {
        return sendJson(r, {
          'user_info': {'auth': 0},
        }, status: 401);
      }
      final handler = actions[q['action'] ?? ''];
      if (handler == null) return sendText(r, 'unknown', status: 404);
      await handler(r);
    });
    actions[''] = (r) => sendJson(r, accountJson(), contentType: 'text/html');
    dio = createDio(retryDelay: const Duration(milliseconds: 5));
    client = XtreamClient(
      dio,
      XtreamCredentials(server.baseUrl, 'kanal', 'test123'),
    );
  });

  tearDown(() => server.close());

  TypeMatcher<SourceException> sourceError(
    SourceErrorKind kind, {
    int? status,
  }) {
    var m = isA<SourceException>().having((e) => e.kind, 'kind', kind);
    if (status != null) m = m.having((e) => e.statusCode, 'status', status);
    return m.having((e) => '${e.url}', 'url', isNot(contains('test123')));
  }

  group('authenticate', () {
    test('parses the account and the server offset', () async {
      final account = await client.authenticate();
      expect(account.isActive, isTrue);
      expect(account.expDate, DateTime.utc(2027, 3, 1));
      expect(account.maxConnections, 2);
      expect(account.serverUtcOffset, const Duration(hours: 3));
      expect(client.account, same(account));
      expect(client.serverUtcOffset, const Duration(hours: 3));

      final request = server.requests.single;
      expect(request.uri.queryParameters, {
        'username': 'kanal',
        'password': 'test123',
      });
      expect(request.headers['user-agent'], defaultUserAgent());
    });

    test('follows 301/302 redirects', () async {
      server
        ..route('/old/player_api.php', (r) {
          return sendRedirect(
            r,
            '/player_api.php?${r.uri.query}',
            status: HttpStatus.movedPermanently,
          );
        })
        ..route('/lb/player_api.php', (r) {
          return sendRedirect(
            r,
            server.url('/old/player_api.php?${r.uri.query}'),
          );
        });
      final redirected = XtreamClient(
        dio,
        XtreamCredentials('${server.baseUrl}/lb', 'kanal', 'test123'),
      );
      final account = await redirected.authenticate();
      expect(account.isActive, isTrue);
      expect(server.requests.map((r) => r.uri.path), [
        '/lb/player_api.php',
        '/old/player_api.php',
        '/player_api.php',
      ]);
      expect(server.requests.map((r) => r.headers['user-agent']).toSet(), {
        defaultUserAgent(),
      });
    });

    test('HTTP 401 is unauthorized', () async {
      final bad = XtreamClient(
        dio,
        XtreamCredentials(server.baseUrl, 'kanal', 'wrong'),
      );
      await expectLater(
        bad.authenticate(),
        throwsA(sourceError(SourceErrorKind.unauthorized, status: 401)),
      );
      expect(server.requests, hasLength(1), reason: '4xx is not retried');
    });

    test('auth 0 with HTTP 200 is unauthorized', () async {
      actions[''] = (r) => sendJson(r, {
        'user_info': {'auth': 0},
      });
      await expectLater(
        client.authenticate(),
        throwsA(sourceError(SourceErrorKind.unauthorized)),
      );
    });

    test(
      'auth 0 with HTTP 403 is unauthorized, a bare 403 forbidden',
      () async {
        actions[''] = (r) => sendJson(r, {
          'user_info': {'auth': '0'},
        }, status: 403);
        await expectLater(
          client.authenticate(),
          throwsA(sourceError(SourceErrorKind.unauthorized, status: 403)),
        );
        actions[''] = (r) => sendText(r, 'Access denied', status: 403);
        await expectLater(
          client.authenticate(),
          throwsA(sourceError(SourceErrorKind.forbidden, status: 403)),
        );
      },
    );

    test('Expired / Banned / Disabled are accountInactive', () async {
      for (final status in ['Expired', 'Banned', 'Disabled']) {
        actions[''] = (r) => sendJson(r, accountJson(status: status));
        await expectLater(
          client.authenticate(),
          throwsA(
            sourceError(SourceErrorKind.accountInactive)
                .having((e) => e.message, 'message', contains(status)),
          ),
        );
        // accountInfo still returns the account for the UI.
        final account = await client.accountInfo();
        expect(account.status, status);
        expect(account.isActive, isFalse);
      }
    });

    test('an empty body is emptyBody', () async {
      actions[''] = (r) => sendText(r, '', contentType: 'text/html');
      await expectLater(
        client.authenticate(),
        throwsA(sourceError(SourceErrorKind.emptyBody)),
      );
      actions[''] = (r) => sendText(r, ' \r\n ');
      await expectLater(
        client.authenticate(),
        throwsA(sourceError(SourceErrorKind.emptyBody)),
      );
    });

    test('an HTML page is unparseable', () async {
      actions[''] = (r) => sendText(
        r,
        '<!DOCTYPE html>\n<html><head><title>502 Bad Gateway</title></head>'
        '<body><script>var a = {"x": 1};</script></body></html>',
        contentType: 'text/html',
      );
      await expectLater(
        client.authenticate(),
        throwsA(
          sourceError(SourceErrorKind.unparseable)
              .having((e) => e.message, 'message', contains('HTML')),
        ),
      );
    });

    test('invalid JSON is unparseable', () async {
      actions[''] = (r) => sendText(
        r,
        '{"user_info": {"auth": 1,',
        contentType: 'application/json',
      );
      await expectLater(
        client.authenticate(),
        throwsA(sourceError(SourceErrorKind.unparseable)),
      );
      actions[''] = (r) => sendText(r, 'Server error, try later');
      await expectLater(
        client.authenticate(),
        throwsA(sourceError(SourceErrorKind.unparseable)),
      );
    });

    test('JSON without user_info is unparseable', () async {
      actions[''] = (r) => sendJson(r, {'error': 'nope'});
      await expectLater(
        client.authenticate(),
        throwsA(sourceError(SourceErrorKind.unparseable)),
      );
      actions[''] = (r) => sendJson(r, []);
      await expectLater(
        client.authenticate(),
        throwsA(sourceError(SourceErrorKind.unparseable)),
      );
    });

    test('tolerates a BOM and PHP notices before the JSON', () async {
      actions[''] = (r) => sendText(r, '﻿${jsonEncode(accountJson())}');
      expect((await client.authenticate()).isActive, isTrue);
      actions[''] = (r) => sendText(
        r,
        '<br />\n<b>Notice</b>: Undefined index: x in <b>/var/www/api.php</b>'
        ' on line <b>12</b><br />\n${jsonEncode(accountJson())}',
        contentType: 'text/html',
      );
      expect((await client.authenticate()).isActive, isTrue);
    });

    test('404, 500 and other statuses', () async {
      actions[''] = (r) => sendText(r, 'gone', status: 404);
      await expectLater(
        client.authenticate(),
        throwsA(sourceError(SourceErrorKind.notFound, status: 404)),
      );
      actions[''] = (r) => sendText(r, 'boom', status: 500);
      await expectLater(
        client.authenticate(),
        throwsA(sourceError(SourceErrorKind.http, status: 500)),
      );
    });

    test('a slow server times out', () async {
      actions[''] = (r) async {
        await Future<void>.delayed(const Duration(seconds: 3));
        await sendJson(r, accountJson());
      };
      final slow = XtreamClient(
        createDio(
          retries: 0,
          receiveTimeout: const Duration(milliseconds: 300),
        ),
        XtreamCredentials(server.baseUrl, 'kanal', 'test123'),
      );
      await expectLater(
        slow.authenticate(),
        throwsA(sourceError(SourceErrorKind.timeout)),
      );
    });

    test('an unreachable server', () async {
      final down = XtreamClient(
        createDio(retries: 0),
        XtreamCredentials(
          'http://127.0.0.1:${await closedPort()}',
          'kanal',
          'test123',
        ),
      );
      await expectLater(
        down.authenticate(),
        throwsA(sourceError(SourceErrorKind.unreachable)),
      );
    });

    test('an invalid server URL', () async {
      final invalid = XtreamClient(
        dio,
        const XtreamCredentials('http://[bad', 'kanal', 'test123'),
      );
      await expectLater(
        invalid.authenticate(),
        throwsA(sourceError(SourceErrorKind.unreachable)),
      );
    });

    test('dropped connections are retried', () async {
      var calls = 0;
      actions[''] = (r) async {
        calls++;
        if (calls < 3) return dropConnection(r);
        await sendJson(r, accountJson());
      };
      expect((await client.authenticate()).isActive, isTrue);
      expect(calls, 3);
    });

    test('cancellation', () async {
      actions[''] = (r) async {
        await Future<void>.delayed(const Duration(seconds: 2));
        await sendJson(r, accountJson());
      };
      final token = CancelToken();
      Timer(const Duration(milliseconds: 100), token.cancel);
      await expectLater(
        client.authenticate(cancelToken: token),
        throwsA(sourceError(SourceErrorKind.cancelled)),
      );
    });

    test('special characters in credentials reach the server intact', () async {
      const user = 'user@mail.com';
      const pass = 'p@ss w/rd&x=1+2#ş';
      server.route('/player_api.php', (r) {
        final q = r.uri.queryParameters;
        if (q['username'] == user && q['password'] == pass) {
          return sendJson(r, accountJson());
        }
        return sendText(r, '', status: 401);
      });
      final special = XtreamClient(
        dio,
        XtreamCredentials(server.baseUrl, user, pass),
      );
      expect((await special.authenticate()).isActive, isTrue);
    });
  });

  group('catalog calls', () {
    test('categories and streams, JSON served as text/html', () async {
      actions['get_live_categories'] = (r) => sendJson(r, [
        {'category_id': '1', 'category_name': 'TR | Ulusal', 'parent_id': 0},
        {'category_id': 2, 'category_name': 'Spor'},
      ], contentType: 'text/html; charset=UTF-8');
      actions['get_live_streams'] = (r) => sendJson(
        r,
        liveRows(r.uri.queryParameters['category_id'] ?? '1', [1001, 1002]),
        contentType: 'text/html',
      );
      final categories = await client.liveCategories();
      expect(categories.map((c) => c.categoryName), ['TR | Ulusal', 'Spor']);
      final all = await client.liveStreams();
      expect(all.map((s) => s.streamId), ['1001', '1002']);
      expect(all[1].archiveDays, 3);
      final one = await client.liveStreams(categoryId: '2');
      expect(one.first.categoryId, '2');
      expect(server.requests.last.uri.queryParameters['category_id'], '2');
    });

    test('a large body is decoded on a background isolate', () async {
      final ids = List.generate(4000, (i) => 10000 + i);
      actions['get_live_streams'] = (r) => sendJson(r, liveRows('1', ids));
      final streams = await client.liveStreams();
      expect(streams, hasLength(4000));
      expect(streams.first.streamId, '10000');
      expect(streams.last.name, 'Channel 13999');
      expect(streams.last.added, DateTime.utc(2023, 11, 14, 22, 13, 20));
    });

    test('a large HTML page is still unparseable', () async {
      actions['get_live_streams'] = (r) => sendText(
        r,
        '<html><body>${'<p>error</p>' * 10000}</body></html>',
        contentType: 'text/html',
      );
      await expectLater(
        client.liveStreams(),
        throwsA(sourceError(SourceErrorKind.unparseable)),
      );
    });

    test('a large invalid JSON body is unparseable', () async {
      actions['get_vod_streams'] = (r) =>
          sendText(r, '[${List.filled(10000, '{"stream_id": 1}').join(',')}');
      await expectLater(
        client.vodStreams(),
        throwsA(sourceError(SourceErrorKind.unparseable)),
      );
    });

    test('auth failure on a list endpoint is unauthorized', () async {
      actions['get_vod_categories'] = (r) => sendJson(r, {
        'user_info': {'auth': 0},
      });
      await expectLater(
        client.vodCategories(),
        throwsA(sourceError(SourceErrorKind.unauthorized)),
      );
    });

    test('null, [] and PHP objects for lists', () async {
      actions['get_series_categories'] = (r) => sendText(r, 'null');
      expect(await client.seriesCategories(), isEmpty);
      actions['get_series_categories'] = (r) => sendJson(r, []);
      expect(await client.seriesCategories(), isEmpty);
      actions['get_series_categories'] = (r) => sendJson(r, {
        '5': {'category_id': '5', 'category_name': 'Dizi'},
      });
      expect((await client.seriesCategories()).single.categoryId, '5');
    });

    test('vod, series, info and EPG calls', () async {
      actions['get_vod_streams'] = (r) => sendJson(r, [
        {'stream_id': 3001, 'name': 'Kış Uykusu', 'container_extension': 'mkv'},
      ]);
      actions['get_series'] = (r) => sendJson(r, [
        {'series_id': 5001, 'name': 'Sıcak Kafa'},
      ]);
      actions['get_vod_info'] = (r) {
        expect(r.uri.queryParameters['vod_id'], '3001');
        return sendJson(r, {
          'info': {'name': 'Kış Uykusu', 'duration_secs': 11760},
          'movie_data': {'stream_id': 3001, 'container_extension': 'mkv'},
        });
      };
      actions['get_series_info'] = (r) {
        expect(r.uri.queryParameters['series_id'], '5001');
        return sendJson(r, {
          'seasons': [
            {'season_number': 1},
          ],
          'info': {'name': 'Sıcak Kafa'},
          'episodes': {
            '1': [
              {'id': '9001', 'episode_num': 1, 'title': 'Pilot'},
            ],
          },
        });
      };
      actions['get_short_epg'] = (r) {
        expect(r.uri.queryParameters['stream_id'], '1001');
        expect(r.uri.queryParameters['limit'], '4');
        return sendJson(r, {
          'epg_listings': [
            {
              'title': 'TmV3cw==',
              'start': '2025-10-17 20:00:00',
              'end': '2025-10-17 21:00:00',
            },
          ],
        });
      };
      actions['get_simple_data_table'] = (r) => sendJson(r, {
        'epg_listings': [
          {
            'title': 'QWvFn2FtIEhhYmVybGVyaQ==',
            'start_timestamp': '1760720400',
            'stop_timestamp': '1760724000',
            'now_playing': 0,
            'has_archive': 1,
          },
        ],
      });

      expect((await client.vodStreams()).single.containerExtension, 'mkv');
      expect((await client.seriesList()).single.seriesId, '5001');
      final vod = await client.vodInfo('3001');
      expect(vod.durationSecs, 11760);
      expect(vod.streamId, '3001');
      final series = await client.seriesInfo('5001');
      expect(series.info!.seriesId, '5001');
      expect(series.episodes[1]!.single.seriesId, '5001');

      // Without an account call the wall-clock fallback uses offset 0 …
      final short = await client.shortEpg('1001', limit: 4);
      expect(short.single.title, 'News');
      expect(short.single.start, DateTime.utc(2025, 10, 17, 20));
      // … after it, the server offset (+3 h).
      await client.authenticate();
      final shifted = await client.shortEpg('1001', limit: 4);
      expect(shifted.single.start, DateTime.utc(2025, 10, 17, 17));

      final table = await client.simpleDataTable('1001');
      expect(table.single.title, 'Akşam Haberleri');
      expect(table.single.hasArchive, isTrue);
    });

    test('xmltvUri', () {
      final uri = client.xmltvUri();
      expect(uri.path, '/xmltv.php');
      expect(uri.queryParameters['username'], 'kanal');
    });
  });

  group('bulk live streams and per-category fallback', () {
    test('the bulk call uses its own timeout and is not retried', () async {
      actions['get_live_streams'] = (r) async {
        if (r.uri.queryParameters.containsKey('category_id')) {
          return sendJson(
            r,
            liveRows(r.uri.queryParameters['category_id']!, [1]),
          );
        }
        await Future<void>.delayed(const Duration(seconds: 3));
        await sendJson(r, liveRows('1', [1]));
      };
      final fast = XtreamClient(
        dio,
        XtreamCredentials(server.baseUrl, 'kanal', 'test123'),
        bulkReceiveTimeout: const Duration(milliseconds: 300),
      );
      final watch = Stopwatch()..start();
      await expectLater(
        fast.liveStreams(),
        throwsA(sourceError(SourceErrorKind.timeout)),
      );
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
      expect(server.requests, hasLength(1));

      // A category call keeps the normal (60 s) timeout.
      expect(await fast.liveStreams(categoryId: '7'), hasLength(1));
    });

    test('per category: concurrency, order, dedupe and progress', () async {
      actions['get_live_streams'] = (r) async {
        final cat = r.uri.queryParameters['category_id']!;
        await Future<void>.delayed(
          Duration(milliseconds: 40 + int.parse(cat) * 3),
        );
        final ids = switch (cat) {
          '1' => [1, 2],
          '2' => [3, 2],
          '3' => <int>[],
          _ => [100 + int.parse(cat)],
        };
        await sendJson(r, liveRows(cat, ids));
      };
      final cats = [for (var i = 1; i <= 12; i++) '$i'];
      final progress = <int>[];
      final streams = await client.liveStreamsPerCategory(
        cats,
        concurrency: 4,
        onProgress: (done, total) {
          expect(total, 12);
          progress.add(done);
        },
      );
      expect(server.maxInFlight, lessThanOrEqualTo(4));
      expect(server.maxInFlight, greaterThan(1));
      expect(progress, [for (var i = 1; i <= 12; i++) i]);
      expect(streams.map((s) => s.streamId).take(3), ['1', '2', '3']);
      expect(streams, hasLength(3 + 9));
      final two = streams.firstWhere((s) => s.streamId == '2');
      expect(two.categoryId, '1');
      expect(two.categoryIds, ['1', '2']);
    });

    test('per category: the first failure aborts by default', () async {
      actions['get_live_streams'] = (r) async {
        final cat = r.uri.queryParameters['category_id']!;
        if (cat == '2') return sendText(r, 'boom', status: 500);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await sendJson(r, liveRows(cat, [int.parse(cat)]));
      };
      await expectLater(
        client.liveStreamsPerCategory(['1', '2', '3', '4', '5', '6']),
        throwsA(sourceError(SourceErrorKind.http, status: 500)),
      );
    });

    test('per category: onCategoryError skips failures', () async {
      actions['get_live_streams'] = (r) async {
        final cat = r.uri.queryParameters['category_id']!;
        if (cat == '2') return sendText(r, '<html>oops</html>');
        await sendJson(r, liveRows(cat, [int.parse(cat)]));
      };
      final failed = <String, SourceErrorKind>{};
      final streams = await client.liveStreamsPerCategory([
        '1',
        '2',
        '3',
      ], onCategoryError: (id, e) => failed[id] = e.kind);
      expect(streams.map((s) => s.streamId), ['1', '3']);
      expect(failed, {'2': SourceErrorKind.unparseable});
    });

    test('per category: caller cancellation', () async {
      actions['get_live_streams'] = (r) async {
        await Future<void>.delayed(const Duration(seconds: 2));
        await sendJson(r, []);
      };
      final token = CancelToken();
      Timer(const Duration(milliseconds: 100), token.cancel);
      await expectLater(
        client.liveStreamsPerCategory(
          ['1', '2', '3'],
          cancelToken: token,
          onCategoryError: (_, _) =>
              fail('cancellation is not a category error'),
        ),
        throwsA(sourceError(SourceErrorKind.cancelled)),
      );
    });

    test('per category: empty input and vod/series variants', () async {
      expect(await client.liveStreamsPerCategory([]), isEmpty);
      actions['get_vod_streams'] = (r) => sendJson(r, [
        {'stream_id': 1, 'category_id': r.uri.queryParameters['category_id']},
        {'stream_id': 2},
      ]);
      actions['get_series'] = (r) => sendJson(r, [
        {'series_id': r.uri.queryParameters['category_id']},
      ]);
      final vod = await client.vodStreamsPerCategory(['a', 'b']);
      expect(vod.map((v) => v.streamId), ['1', '2']);
      expect(vod.first.categoryId, 'a');
      final series = await client.seriesListPerCategory(['a', 'b']);
      expect(series.map((s) => s.seriesId), ['a', 'b']);
    });
  });
}
