import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:carina/player/engine/http_probe.dart';
import 'package:carina/player/engine/playback_engine.dart';

void main() {
  late HttpServer server;
  late String base;
  final seen = <String, HttpHeaders>{};
  final pending = <HttpResponse>[];

  setUpAll(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://127.0.0.1:${server.port}';
    server.listen((req) async {
      seen[req.uri.path] = req.headers;
      final res = req.response;
      switch (req.uri.path) {
        case '/ok.ts':
          res.headers.contentType = ContentType('video', 'mp2t');
          // A "live" body that never ends; the probe must not wait for it.
          res.add(List<int>.filled(188 * 100, 0x47));
          pending.add(res);
        case '/redirect':
          await res.redirect(Uri.parse('$base/403.ts'));
        case '/slow.ts':
          pending.add(res);
        default:
          final code = int.tryParse(req.uri.path.replaceAll(RegExp(r'\D'), ''));
          res.statusCode = code ?? 400;
          await res.close();
      }
    });
  });

  tearDownAll(() async {
    for (final res in pending) {
      try {
        await res.close();
      } catch (_) {}
    }
    await server.close(force: true);
  });

  test('isHttpUrl', () {
    expect(isHttpUrl('http://x/1.ts'), isTrue);
    expect(isHttpUrl(' HTTPS://x/1.ts'), isTrue);
    expect(isHttpUrl('/local/file.ts'), isFalse);
    expect(isHttpUrl('rtmp://x/live'), isFalse);
  });

  for (final code in [401, 403, 404, 500, 503]) {
    test('HTTP $code', () async {
      final e = await probeHttpFailure('$base/$code.ts');
      expect(e, isNotNull);
      expect(e!.kind, EngineErrorKind.http);
      expect(e.statusCode, code);
      expect(e.message, contains('$code'));
      expect(e.detail, isNot(contains('$code.ts?')));
    });
  }

  test('follows redirects', () async {
    final e = await probeHttpFailure('$base/redirect');
    expect(e?.statusCode, 403);
  });

  test(
    'success means "not an HTTP problem" and does not read the body',
    () async {
      final sw = Stopwatch()..start();
      final e = await probeHttpFailure('$base/ok.ts');
      expect(e, isNull);
      expect(sw.elapsed, lessThan(const Duration(seconds: 3)));
    },
  );

  test('sends the User-Agent and headers', () async {
    await probeHttpFailure(
      '$base/404.ts',
      userAgent: 'Carina/1.0 (Windows)',
      headers: const {'Referer': 'http://ref/', 'X-Token': 'abc'},
    );
    final headers = seen['/404.ts']!;
    expect(headers.value(HttpHeaders.userAgentHeader), 'Carina/1.0 (Windows)');
    expect(headers.value('referer'), 'http://ref/');
    expect(headers.value('x-token'), 'abc');
  });

  test('connection refused is a network error', () async {
    // Bind and release a port so nothing listens on it.
    final tmp = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = tmp.port;
    await tmp.close();
    final e = await probeHttpFailure('http://127.0.0.1:$port/x.ts');
    expect(e?.kind, EngineErrorKind.network);
  });

  test('no answer is a timeout', () async {
    final e = await probeHttpFailure(
      '$base/slow.ts',
      timeout: const Duration(milliseconds: 600),
    );
    expect(e?.kind, EngineErrorKind.timeout);
  });

  test('non-HTTP URLs are not probed', () async {
    expect(await probeHttpFailure('/tmp/file.ts'), isNull);
  });
}
