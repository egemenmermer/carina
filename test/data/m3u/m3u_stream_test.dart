import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/sources/m3u/m3u.dart';
import 'package:carina/data/sources/m3u/m3u_decoder.dart';

const String _playlist =
    '#EXTM3U url-tvg="http://epg.example.com/a.xml" catchup="shift"\r\n'
    '#EXTINF:-1 tvg-id="trt1" group-title="Ulusal",TRT 1 HD\r\n'
    '#EXTVLCOPT:http-user-agent=Kanal\r\n'
    'http://example.com/live/1001.ts\r\n'
    '#EXTINF:-1 tvg-id="show" group-title="Ulusal",Show TV\r\n'
    'http://example.com/live/1002.ts\r\n'
    '#EXTINF:-1,Sıcak Kafa S01 E02\r\n'
    'http://example.com/series/u/p/9002.mkv';

Stream<List<int>> _chunks(List<int> bytes, int size) async* {
  for (var i = 0; i < bytes.length; i += size) {
    yield bytes.sublist(i, i + size > bytes.length ? bytes.length : i + size);
  }
}

List<String> _describe(List<M3uEntry> entries) => [
  for (final e in entries)
    '${e.name}|${e.url}|${e.group}|${e.userAgent}|${e.catchup}|${e.kind.name}',
];

void main() {
  group('parseM3uStream', () {
    test('matches parseM3u for a single chunk', () async {
      final expected = parseM3u(_playlist);
      final parsed = parseM3uStream(Stream.value(utf8.encode(_playlist)));
      final entries = await parsed.toList();
      expect(_describe(entries), _describe(expected.entries));
      expect((await parsed.header).tvgUrls, ['http://epg.example.com/a.xml']);
      expect(parsed.entryCount, 3);
    });

    test('matches parseM3u for 1-byte chunks with a BOM and CRLF', () async {
      final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode(_playlist)];
      final entries = await parseM3uStream(_chunks(bytes, 1)).toList();
      expect(_describe(entries), _describe(parseM3u(_playlist).entries));
      expect(entries.last.seriesName, 'Sıcak Kafa');
    });

    test('a CRLF split across chunks is one line break', () async {
      final parsed = parseM3uStream(
        Stream.fromIterable([
          utf8.encode('#EXTM3U\r'),
          utf8.encode('\n#EXTINF:-1,A\r'),
          utf8.encode('\nhttp://example.com/a.ts\r'),
          utf8.encode('\n#EXTINF:-1,B\r'),
          utf8.encode('\n'),
        ]),
      );
      final entries = await parsed.toList();
      expect(entries.single.name, 'A');
      expect(parsed.warnings.single, contains('Line 4'));
    });

    test('decodes Windows-1252 / Latin-1 lines', () async {
      final bytes = [
        ...utf8.encode('#EXTM3U\n#EXTINF:-1 group-title="Caf'),
        0xE9, // é
        ...utf8.encode('",Caf'),
        0xE9,
        0x20,
        0x80, // €
        0x20,
        0x93, // left double quotation mark
        ...utf8.encode('Ni'),
        0xF1, // ñ
        0x6F,
        0x94, // right double quotation mark
        ...utf8.encode('\nhttp://example.com/cafe.ts\n'),
      ];
      final e = (await parseM3uStream(Stream.value(bytes)).toList()).single;
      expect(e.group, 'Café');
      expect(e.name, 'Café € “Niño”');
    });

    test('keeps valid UTF-8 around a corrupt byte', () async {
      final bytes = [
        ...utf8.encode('#EXTINF:-1,Çocuk '),
        0xFF,
        ...utf8.encode(' Kanalı\nhttp://example.com/c.ts'),
      ];
      final e = (await parseM3uStream(Stream.value(bytes)).toList()).single;
      expect(e.name, 'Çocuk ${String.fromCharCode(0xFFFD)} Kanalı');
    });

    test('emits the last entry without a final line break', () async {
      final entries = await parseM3uStream(
        Stream.value(utf8.encode('#EXTINF:-1,Last\nhttp://example.com/l.ts')),
      ).toList();
      expect(entries.single.url, 'http://example.com/l.ts');
    });

    test('exposes header, warnings and a full result', () async {
      final parsed = parseM3uStream(
        Stream.value(utf8.encode('#EXTINF:-1,A\nhttp://example.com/a.ts\n')),
      );
      final result = await parsed.toResult();
      expect(result.entries.single.name, 'A');
      expect(result.header.isEmpty, isTrue);
      expect(result.warnings, ['No #EXTM3U header; parsed anyway']);
      expect(parsed.warnings, result.warnings);
    });

    test('can only be listened to once', () async {
      final parsed = parseM3uStream(Stream.value(utf8.encode('#EXTM3U')));
      await parsed.drain<void>();
      expect(() => parsed.listen((_) {}), throwsStateError);
    });

    test('follows pause and resume of the listener', () async {
      final text = StringBuffer('#EXTM3U\n');
      for (var i = 0; i < 300; i++) {
        text.write('#EXTINF:-1,C$i\nhttp://example.com/$i.ts\n');
      }
      final names = <String>[];
      await for (final e in parseM3uStream(
        _chunks(utf8.encode(text.toString()), 64),
      )) {
        names.add(e.name);
        if (names.length % 50 == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
      }
      expect(names, [for (var i = 0; i < 300; i++) 'C$i']);
    });

    test('cancelling completes the header and cancels the source', () async {
      var sourceCancelled = false;
      final controller = StreamController<List<int>>(
        onCancel: () => sourceCancelled = true,
      );
      final parsed = parseM3uStream(controller.stream);
      final first = Completer<M3uEntry>();
      late StreamSubscription<M3uEntry> sub;
      sub = parsed.listen((e) {
        if (!first.isCompleted) first.complete(e);
      });
      controller.add(
        utf8.encode(
          '#EXTM3U url-tvg="http://epg.example.com/x.xml"\n'
          '#EXTINF:-1,A\nhttp://example.com/a.ts\n',
        ),
      );
      expect((await first.future).name, 'A');
      await sub.cancel();
      expect(sourceCancelled, isTrue);
      expect((await parsed.header).tvgUrls, ['http://epg.example.com/x.xml']);
    });

    test('forwards errors of the byte stream', () async {
      final source = Stream<List<int>>.multi((c) {
        c.add(utf8.encode('#EXTINF:-1,A\nhttp://example.com/a.ts\n'));
        c.addError(const SocketException('connection reset'));
        c.close();
      });
      final parsed = parseM3uStream(source);
      await expectLater(parsed.toList(), throwsA(isA<SocketException>()));
      expect((await parsed.header).isEmpty, isTrue);
    });
  });

  group('parseM3uFileInIsolate', () {
    test('streams a file on a background isolate', () async {
      final dir = await Directory.systemTemp.createTemp('carina_m3u_');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/list.m3u');
      await file.writeAsBytes([0xEF, 0xBB, 0xBF, ...utf8.encode(_playlist)]);
      final result = await parseM3uFileInIsolate(file.path);
      expect(_describe(result.entries), _describe(parseM3u(_playlist).entries));
      expect(result.header.catchup, 'shift');
    });
  });

  group('decodeM3uLine', () {
    test('decodes ASCII, UTF-8 and Windows-1252', () {
      expect(decodeM3uLine(utf8.encode('plain'), 0, 5), 'plain');
      final utf = utf8.encode('Şeker İçerik');
      expect(decodeM3uLine(utf, 0, utf.length), 'Şeker İçerik');
      expect(
        decodeM3uLine([0x80, 0x99, 0x9F, 0xA0, 0xFF], 0, 5),
        '€™Ÿ${String.fromCharCode(0xA0)}ÿ',
      );
      expect(decodeM3uLine([0x41, 0x42, 0x43, 0x44], 1, 3), 'BC');
    });
  });
}
