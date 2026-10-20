import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/net/dio_factory.dart';
import 'package:carina/data/sources/source_exception.dart';

import 'test_http_server.dart';

void main() {
  late TestHttpServer server;
  late Directory dir;
  late Dio dio;

  setUp(() async {
    server = await TestHttpServer.start();
    dir = await Directory.systemTemp.createTemp('carina_download_');
    dio = createDio(retries: 0);
  });

  tearDown(() async {
    await server.close();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  List<int> payload(int size) => List.generate(size, (i) => (i * 31) % 256);

  TypeMatcher<SourceException> sourceError(SourceErrorKind kind) =>
      isA<SourceException>().having((e) => e.kind, 'kind', kind);

  test('streams a body to disk with progress and a known total', () async {
    final body = payload(300 * 1024);
    server.route('/epg.xml.gz', (r) => sendBytes(r, body));
    final path = '${dir.path}/sub/epg.xml.gz';
    final progress = <(int, int?)>[];
    final file = await downloadToFile(
      dio,
      server.url('/epg.xml.gz'),
      path,
      onProgress: (received, total) => progress.add((received, total)),
    );
    expect(file.path, path);
    expect(await file.readAsBytes(), body);
    expect(progress.last, (body.length, body.length));
    expect(progress.every((p) => p.$2 == body.length), isTrue);
    expect(await File('$path.part').exists(), isFalse);
  });

  test('unknown total for chunked and gzip-encoded bodies', () async {
    final text = List.generate(20000, (i) => '<programme n="$i"/>').join();
    server.route('/chunked', (r) => sendText(r, text, chunked: true));
    final progress = <int?>[];
    final f1 = await downloadToFile(
      dio,
      server.url('/chunked'),
      '${dir.path}/a.xml',
      onProgress: (_, total) => progress.add(total),
    );
    expect(await f1.readAsString(), text);
    expect(progress.toSet(), {null});

    server.autoCompress = true;
    progress.clear();
    final f2 = await downloadToFile(
      dio,
      server.url('/chunked'),
      '${dir.path}/b.xml',
      onProgress: (_, total) => progress.add(total),
    );
    expect(await f2.readAsString(), text, reason: 'decompressed on the fly');
    expect(progress.toSet(), {null});
  });

  test('replaces an existing file only on success', () async {
    final path = '${dir.path}/epg.xml';
    await File(path).writeAsString('old');
    server.route('/missing', (r) => sendText(r, 'not here', status: 404));
    await expectLater(
      downloadToFile(dio, server.url('/missing'), path),
      throwsA(sourceError(SourceErrorKind.notFound)),
    );
    expect(await File(path).readAsString(), 'old');
    expect(await File('$path.part').exists(), isFalse);

    server.route('/new', (r) => sendText(r, 'new'));
    await downloadToFile(dio, server.url('/new'), path);
    expect(await File(path).readAsString(), 'new');
  });

  test('error statuses map to source errors', () async {
    server
      ..route('/401', (r) => sendText(r, '', status: 401))
      ..route('/403', (r) => sendText(r, '', status: 403))
      ..route('/500', (r) => sendText(r, 'boom', status: 500));
    await expectLater(
      downloadToFile(dio, server.url('/401'), '${dir.path}/x'),
      throwsA(sourceError(SourceErrorKind.unauthorized)),
    );
    await expectLater(
      downloadToFile(dio, server.url('/403'), '${dir.path}/x'),
      throwsA(sourceError(SourceErrorKind.forbidden)),
    );
    await expectLater(
      downloadToFile(dio, server.url('/500'), '${dir.path}/x'),
      throwsA(
        sourceError(SourceErrorKind.http)
            .having((e) => e.statusCode, 'status', 500),
      ),
    );
    expect(dir.listSync(), isEmpty);
  });

  test('an empty 200 is emptyBody and leaves no file', () async {
    server.route('/empty', (r) => sendBytes(r, const []));
    await expectLater(
      downloadToFile(dio, server.url('/empty'), '${dir.path}/e.xml'),
      throwsA(sourceError(SourceErrorKind.emptyBody)),
    );
    expect(dir.listSync(), isEmpty);
  });

  test('cancelling mid-transfer deletes the partial file', () async {
    final chunk = utf8.encode('x' * 16384);
    server.route('/slow', (r) async {
      r.response.headers.contentType = ContentType.text;
      for (var i = 0; i < 200; i++) {
        r.response.add(chunk);
        await r.response.flush();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      await r.response.close();
    });
    final token = CancelToken();
    var received = 0;
    final path = '${dir.path}/c.xml';
    final future = downloadToFile(
      dio,
      server.url('/slow'),
      path,
      cancelToken: token,
      onProgress: (r, _) {
        received = r;
        if (r > 50000 && !token.isCancelled) token.cancel();
      },
    );
    await expectLater(future, throwsA(sourceError(SourceErrorKind.cancelled)));
    expect(received, greaterThan(0));
    expect(await File(path).exists(), isFalse);
    expect(await File('$path.part').exists(), isFalse);
  });

  test('a connection dropped mid-body is unreachable', () async {
    // A raw socket server: promise 100000 bytes, send 1000, hang up.
    final raw = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(raw.close);
    raw.listen((socket) async {
      socket.listen((_) {}, onError: (_) {});
      socket.write(
        'HTTP/1.1 200 OK\r\nContent-Type: text/xml\r\n'
        'Content-Length: 100000\r\n\r\n',
      );
      socket.add(List.filled(1000, 65));
      await socket.flush();
      socket.destroy();
    });
    final path = '${dir.path}/d.xml';
    await expectLater(
      downloadToFile(dio, 'http://127.0.0.1:${raw.port}/epg.xml', path),
      throwsA(sourceError(SourceErrorKind.unreachable)),
    );
    expect(await File('$path.part').exists(), isFalse);
    expect(await File(path).exists(), isFalse);
  });

  test('a cancelled token fails fast', () async {
    final token = CancelToken()..cancel();
    await expectLater(
      downloadToFile(
        dio,
        server.url('/x'),
        '${dir.path}/x',
        cancelToken: token,
      ),
      throwsA(sourceError(SourceErrorKind.cancelled)),
    );
    expect(server.requests, isEmpty);
  });

  test('unreachable host', () async {
    final url = 'http://127.0.0.1:${await closedPort()}/epg.xml';
    await expectLater(
      downloadToFile(dio, url, '${dir.path}/u.xml'),
      throwsA(sourceError(SourceErrorKind.unreachable)),
    );
  });
}
