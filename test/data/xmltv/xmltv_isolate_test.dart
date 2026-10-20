import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/sources/source_exception.dart';
import 'package:carina/data/sources/xmltv/xmltv.dart';

import 'xmltv_fixtures.dart';

void main() {
  final origin = DateTime.utc(2026, 10, 17);
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('carina_xmltv_isolate');
  });
  tearDown(() => dir.delete(recursive: true));

  Future<File> writeDocument(
    String name, {
    int channels = 5,
    int perChannel = 40,
    bool gzipped = false,
  }) async {
    final plain = File('${dir.path}/$name.plain');
    final sink = plain.openWrite();
    await writeXmltv(
      sink,
      channels: channels,
      programmesPerChannel: perChannel,
      origin: origin,
    );
    await sink.close();
    if (!gzipped) return plain.rename('${dir.path}/$name');
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(gz(await plain.readAsBytes()));
    await plain.delete();
    return file;
  }

  Future<SourceException> failure(Stream<XmltvBatch> stream) async {
    try {
      await stream.drain<void>();
    } on SourceException catch (e) {
      return e;
    }
    fail('expected a SourceException');
  }

  group('parseXmltvFileInIsolate', () {
    test('matches the in-process result (gzip file named .xml)', () async {
      final file = await writeDocument('guide.xml', gzipped: true);
      final local = await collect(
        parseXmltvBatches(
          file.openRead(),
          batchSize: 30,
          shift: const Duration(hours: 1),
        ),
      );
      final isolated = await collect(
        parseXmltvFileInIsolate(
          file.path,
          batchSize: 30,
          shift: const Duration(hours: 1),
        ),
      );
      expect(isolated.channels, local.channels);
      expect(isolated.programmes, local.programmes);
      expect(isolated.programmes, hasLength(200));
      expect(
        isolated.batches.whereType<XmltvProgrammeBatch>().map(
          (b) => b.programmes.length,
        ),
        [30, 30, 30, 30, 30, 30, 20],
      );
      expect(isolated.summary.programmes, 200);
      expect(isolated.summary.bytesRead, await file.length());
    });

    test('applies window, languages and shift in the worker', () async {
      final file = await writeDocument('plain.xml', channels: 1, perChannel: 8);
      final result = await collect(
        parseXmltvFileInIsolate(
          file.path,
          shift: const Duration(minutes: 30),
          windowStart: origin.add(const Duration(hours: 2)),
          windowEnd: origin.add(const Duration(hours: 3)),
          preferredLanguages: const ['tr'],
        ),
      );
      expect(result.programmes.map((p) => p.start.toIso8601String()), [
        '2026-10-17T02:00:00.000Z',
        '2026-10-17T02:30:00.000Z',
      ]);
      expect(result.summary.outsideWindow, 6);
    });

    test('a slow consumer gets every batch in order', () async {
      final file = await writeDocument('slow.xml', channels: 4, perChannel: 25);
      final seen = <XmltvProgramme>[];
      await for (final batch in parseXmltvFileInIsolate(
        file.path,
        batchSize: 7,
      )) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        if (batch is XmltvProgrammeBatch) seen.addAll(batch.programmes);
      }
      final local = await collect(parseXmltvBatches(file.openRead()));
      expect(seen, local.programmes);
    });

    test('cancelling stops the worker promptly', () async {
      final file = await writeDocument(
        'big.xml',
        channels: 50,
        perChannel: 400,
      );
      final received = <XmltvBatch>[];
      final cancelled = Completer<Duration>();
      late final StreamSubscription<XmltvBatch> subscription;
      subscription = parseXmltvFileInIsolate(file.path, batchSize: 100).listen((
        batch,
      ) {
        received.add(batch);
        if (received.length == 2) {
          final sw = Stopwatch()..start();
          subscription.cancel().then((_) => cancelled.complete(sw.elapsed));
        }
      });
      final took = await cancelled.future;
      // A worker that did not stop would only be killed after 2 s.
      expect(took, lessThan(const Duration(milliseconds: 1500)));
      final count = received.length;
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(received.length, count);
      expect(received.whereType<XmltvSummary>(), isEmpty);
    });

    test('malformed XML fails with unparseable', () async {
      final file = File('${dir.path}/bad.xml');
      await file.writeAsString(
        '<tv><programme start="20261017100000" channel="a">'
        '<title>x</desc></programme></tv>',
      );
      final e = await failure(parseXmltvFileInIsolate(file.path));
      expect(e.kind, SourceErrorKind.unparseable);
      expect(e.message, contains('Malformed XMLTV'));
    });

    test('a truncated file fails after delivering earlier batches', () async {
      final whole = await writeDocument('cut.xml', perChannel: 100);
      final bytes = await whole.readAsBytes();
      await whole.writeAsBytes(bytes.sublist(0, bytes.length * 2 ~/ 3));
      final batches = <XmltvBatch>[];
      Object? error;
      try {
        await for (final batch in parseXmltvFileInIsolate(
          whole.path,
          batchSize: 50,
        )) {
          batches.add(batch);
        }
      } catch (e) {
        error = e;
      }
      expect(batches.whereType<XmltvProgrammeBatch>(), isNotEmpty);
      expect(
        error,
        isA<SourceException>().having(
          (e) => e.kind,
          'kind',
          SourceErrorKind.unparseable,
        ),
      );
    });

    test('a missing file fails with unparseable and the reason', () async {
      final e = await failure(
        parseXmltvFileInIsolate('${dir.path}/does-not-exist.xml'),
      );
      expect(e.kind, SourceErrorKind.unparseable);
      expect(e.message, contains('Cannot read the XMLTV file'));
    });

    test('an empty file fails with emptyBody', () async {
      final file = File('${dir.path}/empty.xml');
      await file.writeAsBytes(const []);
      final e = await failure(parseXmltvFileInIsolate(file.path));
      expect(e.kind, SourceErrorKind.emptyBody);
    });

    test('rejects a batch size below 1 right away', () {
      expect(
        () => parseXmltvFileInIsolate('x', batchSize: 0),
        throwsArgumentError,
      );
    });
  });

  group('parseXmltvBytesInIsolate', () {
    test('matches the in-process result', () async {
      final file = await writeDocument('bytes.xml', gzipped: true);
      final bytes = await file.readAsBytes();
      final local = await collect(parseXmltvBatches(file.openRead()));
      final isolated = await collect(
        parseXmltvBytesInIsolate(Stream.fromIterable(chunked(bytes, 999))),
      );
      expect(isolated.channels, local.channels);
      expect(isolated.programmes, local.programmes);
      expect(isolated.summary.bytesRead, bytes.length);
    });

    test('pulls input only as fast as it parses', () async {
      final file = await writeDocument(
        'pull.xml',
        channels: 100,
        perChannel: 400,
      );
      var delivered = 0;
      final input = file.openRead().map((chunk) {
        delivered += chunk.length;
        return chunk;
      });
      final iterator = StreamIterator(
        parseXmltvBytesInIsolate(input, batchSize: 50),
      );
      expect(await iterator.moveNext(), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      // While the listener holds back, the worker is at most a couple of
      // batches and one 256 KB chunk ahead.
      expect(delivered, lessThan(await file.length() ~/ 2));
      await iterator.cancel();
    });

    test('errors of the input stream pass through unchanged', () async {
      final controller = StreamController<List<int>>();
      final stream = parseXmltvBytesInIsolate(controller.stream);
      final done = stream.drain<void>();
      controller.add(utf8.encode('<tv><channel id="a">'));
      controller.addError(const SocketException('connection reset'));
      await expectLater(done, throwsA(isA<SocketException>()));
      await controller.close();
    });

    test('cancelling cancels the input', () async {
      final inputCancelled = Completer<void>();
      final controller = StreamController<List<int>>(
        onCancel: () => inputCancelled.complete(),
      );
      final subscription = parseXmltvBytesInIsolate(controller.stream)
          .listen((_) {});
      controller.add(utf8.encode('<tv><channel id="a"><display-name>A'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await subscription.cancel();
      await inputCancelled.future.timeout(const Duration(seconds: 2));
    });
  });
}
