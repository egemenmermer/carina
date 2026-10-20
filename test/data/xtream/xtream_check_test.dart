import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/net/dio_factory.dart';
import 'package:carina/data/sources/source_exception.dart';
import 'package:carina/data/sources/xtream/xtream_check.dart';
import 'package:carina/data/sources/xtream/xtream_credentials.dart';

import '../net/test_http_server.dart';

Map<String, Object?> _account(String status) => {
  'user_info': {
    'username': 'kanal',
    'password': 'test123',
    'auth': 1,
    'status': status,
    'exp_date': '1803859200',
    'is_trial': '1',
    'active_cons': '1',
    'max_connections': '1',
    'allowed_output_formats': ['ts'],
  },
  'server_info': {
    'timestamp_now': 1760700000,
    'time_now': '2025-10-17 14:20:00',
  },
};

void main() {
  late TestHttpServer server;
  late Dio dio;

  setUp(() async {
    server = await TestHttpServer.start();
    dio = createDio(retryDelay: const Duration(milliseconds: 5));
  });
  tearDown(() => server.close());

  XtreamCredentials creds([String user = 'kanal']) =>
      XtreamCredentials(server.baseUrl, user, 'test123');

  test('ok with structured summary fields', () async {
    server.route(
      '/player_api.php',
      (r) => sendJson(r, _account('Active'), contentType: 'text/html'),
    );
    final result = await checkXtreamServer(dio, creds());
    expect(result.ok, isTrue);
    expect(result.reachable, isTrue);
    expect(result.error, isNull);
    expect(result.accountActive, isTrue);
    expect(result.status, 'Active');
    expect(result.expiresAt, DateTime.utc(2027, 3, 1));
    expect(result.maxConnections, 1);
    expect(result.activeConnections, 1);
    expect(result.isTrial, isTrue);
    expect(result.allowedOutputFormats, ['ts']);
    expect(result.account!.serverUtcOffset, const Duration(hours: 3));
    expect(result.toString(), isNot(contains('test123')));
  });

  test('wrong credentials', () async {
    server.route(
      '/player_api.php',
      (r) => sendJson(r, {
        'user_info': {'auth': 0},
      }, status: 401),
    );
    final result = await checkXtreamServer(dio, creds('nobody'));
    expect(result.ok, isFalse);
    expect(result.reachable, isTrue);
    expect(result.error, SourceErrorKind.unauthorized);
    expect(result.statusCode, 401);
    expect(server.requests, hasLength(1));
  });

  test('auth 0 with HTTP 200', () async {
    server.route(
      '/player_api.php',
      (r) => sendJson(r, {
        'user_info': {'auth': 0},
      }),
    );
    final result = await checkXtreamServer(dio, creds());
    expect(result.error, SourceErrorKind.unauthorized);
  });

  test('expired account keeps the account details', () async {
    server.route('/player_api.php', (r) => sendJson(r, _account('Expired')));
    final result = await checkXtreamServer(dio, creds());
    expect(result.ok, isFalse);
    expect(result.error, SourceErrorKind.accountInactive);
    expect(result.status, 'Expired');
    expect(result.expiresAt, DateTime.utc(2027, 3, 1));
    expect(result.accountActive, isFalse);
  });

  test('HTML instead of the API', () async {
    server.route(
      '/player_api.php',
      (r) => sendText(
        r,
        '<!DOCTYPE html><html><body>It works!</body></html>',
        contentType: 'text/html',
      ),
    );
    final result = await checkXtreamServer(dio, creds());
    expect(result.error, SourceErrorKind.unparseable);
    expect(result.reachable, isTrue);
  });

  test('not found and empty body', () async {
    final result = await checkXtreamServer(dio, creds());
    expect(result.error, SourceErrorKind.notFound);
    expect(result.statusCode, 404);
    server.route('/player_api.php', (r) => sendText(r, ''));
    expect(
      (await checkXtreamServer(dio, creds())).error,
      SourceErrorKind.emptyBody,
    );
  });

  test('unreachable server, retried once', () async {
    final port = await closedPort();
    final result = await checkXtreamServer(
      dio,
      XtreamCredentials('http://127.0.0.1:$port', 'kanal', 'test123'),
    );
    expect(result.ok, isFalse);
    expect(result.reachable, isFalse);
    expect(result.error, SourceErrorKind.unreachable);
    expect(result.account, isNull);
  });

  test('dropped connection is retried once', () async {
    var calls = 0;
    server.route('/player_api.php', (r) async {
      calls++;
      if (calls == 1) return dropConnection(r);
      await sendJson(r, _account('Active'));
    });
    expect((await checkXtreamServer(dio, creds())).ok, isTrue);
    expect(calls, 2);

    calls = 0;
    server.route('/player_api.php', (r) {
      calls++;
      return dropConnection(r);
    });
    final result = await checkXtreamServer(dio, creds());
    expect(result.error, SourceErrorKind.unreachable);
    expect(calls, 2);
  });

  test('cancellation', () async {
    server.route('/player_api.php', (r) async {
      await Future<void>.delayed(const Duration(seconds: 2));
      await sendJson(r, _account('Active'));
    });
    final token = CancelToken();
    Timer(const Duration(milliseconds: 100), token.cancel);
    final result = await checkXtreamServer(dio, creds(), cancelToken: token);
    expect(result.error, SourceErrorKind.cancelled);
    expect(result.reachable, isFalse);
  });

  test('checkUrlReachable is exported for the wizard', () async {
    server.route('/epg.xml', (r) => sendText(r, '<tv></tv>'));
    final result = await checkUrlReachable(
      dio,
      server.url('/epg.xml'),
      expectXml: true,
    );
    expect(result.ok, isTrue);
    expect(result.kind, UrlContentKind.xml);
  });
}
