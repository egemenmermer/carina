import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/net/dio_factory.dart';
import 'package:carina/data/sources/source_exception.dart';

import 'test_http_server.dart';

void main() {
  late TestHttpServer server;

  setUp(() async => server = await TestHttpServer.start());
  tearDown(() => server.close());

  Dio quickDio({int retries = 2, Duration? receiveTimeout}) => createDio(
    retries: retries,
    retryDelay: const Duration(milliseconds: 5),
    receiveTimeout: receiveTimeout ?? const Duration(seconds: 10),
  );

  group('user agent and headers', () {
    test('defaultUserAgent names the platform', () {
      final ua = defaultUserAgent();
      if (Platform.isWindows) expect(ua, 'Carina/1.0 (Windows)');
      if (Platform.isMacOS) expect(ua, 'Carina/1.0 (macOS)');
      expect(ua, startsWith('Carina/1.0 ('));
    });

    test('sends the default UA, gzip and extra headers', () async {
      server.route('/h', (r) => sendText(r, 'ok'));
      final dio = createDio(headers: {'Referer': 'http://ref.example/'});
      await dio.get<String>(server.url('/h'));
      final h = server.requests.single.headers;
      expect(h['user-agent'], defaultUserAgent());
      expect(h['accept-encoding'], contains('gzip'));
      expect(h['referer'], 'http://ref.example/');
    });

    test('custom UA from the parameter or from headers', () async {
      server.route('/h', (r) => sendText(r, 'ok'));
      await createDio(userAgent: 'VLC/3.0.20').get<String>(server.url('/h'));
      await createDio(headers: {'user-agent': 'TiviMate/5'})
          .get<String>(server.url('/h'));
      await createDio(
        userAgent: '  ',
        headers: {'User-Agent': 'Header/1'},
      ).get<String>(server.url('/h'));
      expect(server.requests.map((r) => r.headers['user-agent']), [
        'VLC/3.0.20',
        'TiviMate/5',
        'Header/1',
      ]);
    });

    test('decodes gzip-encoded bodies', () async {
      server.autoCompress = true;
      final payload = List.generate(2000, (i) => 'line $i').join('\n');
      server.route('/gz', (r) => sendText(r, payload, chunked: true));
      final res = await createDio().get<String>(server.url('/gz'));
      expect(res.data, payload);
    });

    test('BackgroundTransformer decodes large JSON', () async {
      final big = List.generate(5000, (i) => {'id': i, 'name': 'item $i'});
      server.route('/json', (r) => sendJson(r, big));
      final dio = createDio();
      expect(dio.transformer, isA<BackgroundTransformer>());
      final res = await dio.get<List<dynamic>>(server.url('/json'));
      expect(res.data, hasLength(5000));
    });
  });

  group('redirects', () {
    test('follows 301 and 302 and keeps the UA', () async {
      server
        ..route('/a', (r) => sendRedirect(r, '/b', status: 301))
        ..route('/b', (r) => sendRedirect(r, server.url('/c')))
        ..route('/c', (r) => sendText(r, 'final'));
      final res = await createDio(userAgent: 'Carina/Test')
          .get<String>(server.url('/a'));
      expect(res.statusCode, 200);
      expect(res.data, 'final');
      expect(res.redirects, hasLength(2));
      expect(server.requests.map((r) => r.headers['user-agent']).toSet(), {
        'Carina/Test',
      });
    });

    test('stops after 5 redirects', () async {
      var hop = 0;
      server.route('/loop', (r) => sendRedirect(r, '/loop?n=${hop++}'));
      final dio = quickDio();
      final url = server.url('/loop');
      try {
        await dio.get<String>(url);
        fail('expected an error');
      } on DioException catch (e) {
        final mapped = mapDioError(e, url: url);
        expect(mapped.kind, SourceErrorKind.http);
        expect(mapped.message, 'Too many redirects');
      }
      // 1 request + 5 redirects, never retried.
      expect(server.requests, hasLength(6));
    });
  });

  group('validateStatus', () {
    test('4xx/5xx come back as responses', () async {
      server
        ..route('/404', (r) => sendText(r, 'nope', status: 404))
        ..route('/500', (r) => sendText(r, 'boom', status: 500));
      final dio = quickDio();
      final notFound = await dio.get<String>(server.url('/404'));
      expect(notFound.statusCode, 404);
      expect(notFound.data, 'nope');
      final error = await dio.get<String>(server.url('/500'));
      expect(error.statusCode, 500);
      expect(
        () => ensureSuccess(notFound, url: server.url('/404')),
        throwsA(
          isA<SourceException>()
              .having((e) => e.kind, 'kind', SourceErrorKind.notFound)
              .having((e) => e.statusCode, 'status', 404),
        ),
      );
      // Not retried.
      expect(server.requestsTo('/404'), hasLength(1));
      expect(server.requestsTo('/500'), hasLength(1));
    });
  });

  group('retries', () {
    test('retries dropped connections, then succeeds', () async {
      var calls = 0;
      server.route('/flaky', (r) async {
        calls++;
        if (calls <= 2) return dropConnection(r);
        await sendText(r, 'ok');
      });
      final res = await quickDio().get<String>(server.url('/flaky'));
      expect(res.data, 'ok');
      expect(calls, 3);
    });

    test('gives up after 2 retries with unreachable', () async {
      server.route('/down', dropConnection);
      final url = server.url('/down');
      try {
        await quickDio().get<String>(url);
        fail('expected an error');
      } on DioException catch (e) {
        expect(mapDioError(e, url: url).kind, SourceErrorKind.unreachable);
      }
      expect(server.requestsTo('/down'), hasLength(3));
    });

    test('retries 503 and returns the final response', () async {
      var calls = 0;
      server.route('/busy', (r) async {
        calls++;
        if (calls == 1) return sendText(r, 'busy', status: 503);
        await sendText(r, 'ok');
      });
      final res = await quickDio().get<String>(server.url('/busy'));
      expect(res.statusCode, 200);
      expect(res.data, 'ok');
      expect(calls, 2);

      server.route('/always503', (r) => sendText(r, 'busy', status: 503));
      final last = await quickDio().get<String>(server.url('/always503'));
      expect(last.statusCode, 503);
      expect(server.requestsTo('/always503'), hasLength(3));
    });

    test('a per-request budget of 0 disables retries', () async {
      server.route('/down', dropConnection);
      await expectLater(
        quickDio().get<String>(
          server.url('/down'),
          options: Options(extra: {kRetriesExtraKey: 0}),
        ),
        throwsA(isA<DioException>()),
      );
      expect(server.requestsTo('/down'), hasLength(1));
    });

    test('POST is never retried', () async {
      server.route('/down', dropConnection);
      await expectLater(
        quickDio().post<String>(server.url('/down'), data: 'x'),
        throwsA(isA<DioException>()),
      );
      expect(server.requestsTo('/down'), hasLength(1));
    });

    test('a receive timeout maps to timeout after retries', () async {
      server.route('/slow', (r) async {
        await Future<void>.delayed(const Duration(seconds: 2));
        await sendText(r, 'late');
      });
      final url = server.url('/slow');
      final dio = quickDio(
        retries: 1,
        receiveTimeout: const Duration(milliseconds: 200),
      );
      final watch = Stopwatch()..start();
      try {
        await dio.get<String>(url);
        fail('expected a timeout');
      } on DioException catch (e) {
        expect(e.type, DioExceptionType.receiveTimeout);
        expect(mapDioError(e, url: url).kind, SourceErrorKind.timeout);
      }
      expect(server.requestsTo('/slow'), hasLength(2));
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('cancelling during the backoff stops the retries', () async {
      server.route('/down', dropConnection);
      final dio = createDio(retryDelay: const Duration(seconds: 5));
      final token = CancelToken();
      final watch = Stopwatch()..start();
      final future = dio.get<String>(server.url('/down'), cancelToken: token);
      Timer(const Duration(milliseconds: 300), token.cancel);
      try {
        await future;
        fail('expected cancellation');
      } on DioException catch (e) {
        expect(e.type, DioExceptionType.cancel);
        expect(
          mapDioError(e, url: server.url('/down')).kind,
          SourceErrorKind.cancelled,
        );
      }
      expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
      // Let a pending backoff timer (if any) see the cancellation.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(server.requestsTo('/down'), hasLength(1));
    });
  });

  test('connection refused maps to unreachable', () async {
    final url = 'http://127.0.0.1:${await closedPort()}/x';
    try {
      await quickDio(retries: 0).get<String>(url);
      fail('expected an error');
    } on DioException catch (e) {
      final mapped = mapDioError(e, url: url);
      expect(mapped.kind, SourceErrorKind.unreachable);
      expect(mapped.url, startsWith('http://127***:'));
    }
  });

  test('utf8 sanity of the helper server', () async {
    server.route('/tr', (r) => sendText(r, 'Çocuk Kuşağı'));
    final res = await createDio().get<List<int>>(
      server.url('/tr'),
      options: Options(responseType: ResponseType.bytes),
    );
    expect(utf8.decode(res.data!), 'Çocuk Kuşağı');
  });
}
