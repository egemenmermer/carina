import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/net/dio_factory.dart';
import 'package:carina/data/net/url_check.dart';
import 'package:carina/data/sources/source_exception.dart';

import 'test_http_server.dart';

const _m3u =
    '#EXTM3U url-tvg="http://epg.example.com/a.xml.gz,http://epg.example.com/b.xml" '
    'x-tvg-url="http://epg.example.com/b.xml" tvg-shift="0"\n'
    '#EXTINF:-1 tvg-id="trt1.tr" group-title="TR | Ulusal",TRT 1 HD\n'
    'http://domain.com/live/u/p/1001.ts\n';

const _xmltv =
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    '<!DOCTYPE tv SYSTEM "xmltv.dtd">\n'
    '<!-- generated -->\n'
    '<tv generator-info-name="kanal">\n'
    '<channel id="trt1.tr"><display-name>TRT 1</display-name></channel>\n'
    '</tv>\n';

void main() {
  late TestHttpServer server;
  late Dio dio;

  setUp(() async {
    server = await TestHttpServer.start();
    dio = createDio(retries: 0);
  });
  tearDown(() => server.close());

  group('checkUrlReachable', () {
    test('M3U playlist with EPG header', () async {
      server.route(
        '/get.php',
        (r) => sendText(r, '﻿$_m3u', contentType: 'audio/x-mpegurl'),
      );
      final url = server.url('/get.php?username=kanal&password=test123');
      final result = await checkUrlReachable(dio, url, expectM3u: true);
      expect(result.ok, isTrue);
      expect(result.reachable, isTrue);
      expect(result.statusCode, 200);
      expect(result.kind, UrlContentKind.m3u);
      expect(result.error, isNull);
      expect(result.contentType, 'audio/x-mpegurl');
      expect(result.m3uEpgUrls, [
        'http://epg.example.com/a.xml.gz',
        'http://epg.example.com/b.xml',
      ]);
      expect(result.maskedUrl, isNot(contains('test123')));
      expect(result.toString(), isNot(contains('test123')));
    });

    test('expecting M3U but getting an HTML page', () async {
      server.route(
        '/get.php',
        (r) => sendText(
          r,
          '<!DOCTYPE html><html><head><title>Login</title></head></html>',
          contentType: 'text/html',
        ),
      );
      final result = await checkUrlReachable(
        dio,
        server.url('/get.php'),
        expectM3u: true,
      );
      expect(result.ok, isFalse);
      expect(result.reachable, isTrue);
      expect(result.kind, UrlContentKind.html);
      expect(result.error, SourceErrorKind.unparseable);
      expect(result.message, contains('Not an M3U'));
    });

    test('XMLTV, plain and gzip-compressed', () async {
      server
        ..route('/epg.xml', (r) => sendText(r, _xmltv, contentType: 'text/xml'))
        ..route(
          '/epg.xml.gz',
          (r) => sendBytes(
            r,
            gzip.encode(utf8.encode(_xmltv * 50)),
            contentType: 'application/gzip',
          ),
        );
      final xml = await checkUrlReachable(
        dio,
        server.url('/epg.xml'),
        expectXml: true,
      );
      expect(xml.ok, isTrue);
      expect(xml.kind, UrlContentKind.xml);

      final gz = await checkUrlReachable(
        dio,
        server.url('/epg.xml.gz'),
        expectXml: true,
      );
      expect(gz.ok, isTrue);
      expect(gz.kind, UrlContentKind.gzip);
      expect(gz.compressedKind, UrlContentKind.xml);
    });

    test('a truncated gzip prefix is still sniffed', () async {
      final big = StringBuffer(_xmltv.replaceFirst('</tv>\n', ''));
      for (var i = 0; i < 40000; i++) {
        big.write(
          '<programme start="20261017120000 +0300" channel="c$i">'
          '<title>Programme ${i * 7919}</title></programme>\n',
        );
      }
      big.write('</tv>');
      final compressed = gzip.encode(utf8.encode(big.toString()));
      expect(compressed.length, greaterThan(64 * 1024));
      server.route('/big.gz', (r) => sendBytes(r, compressed));
      final result = await checkUrlReachable(
        dio,
        server.url('/big.gz'),
        expectXml: true,
      );
      expect(result.bytesRead, 64 * 1024);
      expect(result.compressedKind, UrlContentKind.xml);
      expect(result.ok, isTrue);
    });

    test(
      'expecting XML but getting JSON or a gzip of something else',
      () async {
        server
          ..route('/json', (r) => sendJson(r, {'a': 1}))
          ..route(
            '/gzjson',
            (r) => sendBytes(r, gzip.encode(utf8.encode('[1]'))),
          );
        final json = await checkUrlReachable(
          dio,
          server.url('/json'),
          expectXml: true,
        );
        expect(json.ok, isFalse);
        expect(json.kind, UrlContentKind.json);
        expect(json.error, SourceErrorKind.unparseable);

        final gz = await checkUrlReachable(
          dio,
          server.url('/gzjson'),
          expectXml: true,
        );
        expect(gz.ok, isFalse);
        expect(gz.compressedKind, UrlContentKind.json);
        expect(gz.message, contains('gzip/json'));
      },
    );

    test('empty body', () async {
      server.route('/empty', (r) => sendText(r, '  \r\n'));
      final result = await checkUrlReachable(dio, server.url('/empty'));
      expect(result.ok, isFalse);
      expect(result.kind, UrlContentKind.empty);
      expect(result.error, SourceErrorKind.emptyBody);
    });

    test('any non-empty body passes without an expectation', () async {
      server.route('/txt', (r) => sendText(r, 'hello'));
      final result = await checkUrlReachable(dio, server.url('/txt'));
      expect(result.ok, isTrue);
      expect(result.kind, UrlContentKind.other);
    });

    test('error statuses', () async {
      server
        ..route('/404', (r) => sendText(r, 'no', status: 404))
        ..route('/401', (r) => sendText(r, 'no', status: 401))
        ..route('/403', (r) => sendText(r, 'no', status: 403));
      final notFound = await checkUrlReachable(dio, server.url('/404'));
      expect(notFound.reachable, isTrue);
      expect(notFound.ok, isFalse);
      expect(notFound.statusCode, 404);
      expect(notFound.error, SourceErrorKind.notFound);
      expect(
        (await checkUrlReachable(dio, server.url('/401'))).error,
        SourceErrorKind.unauthorized,
      );
      expect(
        (await checkUrlReachable(dio, server.url('/403'))).error,
        SourceErrorKind.forbidden,
      );
    });

    test('unreachable and invalid URLs never throw', () async {
      final refused = await checkUrlReachable(
        dio,
        'http://127.0.0.1:${await closedPort()}/x.m3u',
      );
      expect(refused.reachable, isFalse);
      expect(refused.ok, isFalse);
      expect(refused.error, SourceErrorKind.unreachable);

      final invalid = await checkUrlReachable(dio, 'not a url');
      expect(invalid.reachable, isFalse);
      expect(invalid.error, SourceErrorKind.unreachable);
    });

    test('stops reading after maxBytes and aborts the transfer', () async {
      // A raw socket server so the test can see the client hang up: it
      // streams an endless body (~1.6 MB/s) until the connection closes.
      final raw = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(raw.close);
      final chunk = utf8.encode('#EXTINF:-1,Channel\nhttp://x/1.ts\n' * 500);
      final hungUp = Completer<int>();
      raw.listen((socket) async {
        var sent = 0;
        void done([Object? _]) {
          if (!hungUp.isCompleted) hungUp.complete(sent);
        }

        socket.listen((_) {}, onDone: done, onError: done);
        socket.write(
          'HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n'
          'Connection: close\r\n\r\n#EXTM3U\n',
        );
        try {
          for (var i = 0; i < 1000 && !hungUp.isCompleted; i++) {
            socket.add(chunk);
            await socket.flush();
            sent += chunk.length;
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        } on Object {
          done();
        }
        socket.destroy();
      });

      final watch = Stopwatch()..start();
      final result = await checkUrlReachable(
        dio,
        'http://127.0.0.1:${raw.port}/huge.m3u',
        expectM3u: true,
      );
      expect(result.ok, isTrue);
      expect(result.kind, UrlContentKind.m3u);
      expect(result.bytesRead, 64 * 1024);
      expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
      // The client closes the socket instead of draining the 16 MB body.
      final sent = await hungUp.future.timeout(const Duration(seconds: 3));
      expect(sent, lessThan(4 * 1024 * 1024));
    });

    test('cancellation', () async {
      server.route('/slow', (r) async {
        await Future<void>.delayed(const Duration(seconds: 2));
        await sendText(r, 'late');
      });
      final token = CancelToken();
      Timer(const Duration(milliseconds: 100), token.cancel);
      final result = await checkUrlReachable(
        dio,
        server.url('/slow'),
        cancelToken: token,
      );
      expect(result.ok, isFalse);
      expect(result.error, SourceErrorKind.cancelled);
    });
  });

  group('sniffContentKind', () {
    UrlContentKind sniff(String s) => sniffContentKind(utf8.encode(s));

    test('kinds', () {
      expect(sniff('#EXTM3U\n'), UrlContentKind.m3u);
      expect(sniff('﻿\r\n  #extm3u'), UrlContentKind.m3u);
      expect(sniff('#EXTINF:-1,A\nhttp://a'), UrlContentKind.m3u);
      expect(sniff('# comment\n#EXTINF:-1,A\nhttp://a'), UrlContentKind.m3u);
      expect(sniff('#EXT-X-VERSION:3'), UrlContentKind.m3u);
      expect(sniff(_xmltv), UrlContentKind.xml);
      expect(sniff('<tv></tv>'), UrlContentKind.xml);
      expect(sniff('<rss version="2.0">'), UrlContentKind.xml);
      expect(sniff('<!DOCTYPE html><html>'), UrlContentKind.html);
      expect(sniff('<html><body>'), UrlContentKind.html);
      expect(
        sniff('<?xml version="1.0"?><!DOCTYPE html PUBLIC "x"><html>'),
        UrlContentKind.html,
      );
      expect(sniff('<br />\n<b>Warning</b>'), UrlContentKind.xml);
      expect(sniff('{"user_info":{}}'), UrlContentKind.json);
      expect(sniff(' [1,2]'), UrlContentKind.json);
      expect(sniff(''), UrlContentKind.empty);
      expect(sniff(' \n\t'), UrlContentKind.empty);
      expect(sniff('hello'), UrlContentKind.other);
      expect(sniffContentKind(gzip.encode([1, 2, 3])), UrlContentKind.gzip);
    });

    test('m3uHeaderEpgUrls', () {
      expect(m3uHeaderEpgUrls(utf8.encode('#EXTM3U\n')), isEmpty);
      expect(
        m3uHeaderEpgUrls(utf8.encode("#EXTM3U url-tvg='http://a/x.xml'\n")),
        ['http://a/x.xml'],
      );
      expect(
        m3uHeaderEpgUrls(utf8.encode('#EXTM3U x-tvg-url=http://a/y.xml\n')),
        ['http://a/y.xml'],
      );
      expect(
        m3uHeaderEpgUrls(utf8.encode('#EXTINF:-1 url-tvg="http://a",A\n')),
        isEmpty,
      );
    });
  });
}
