import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/sources/m3u/m3u.dart';

M3uEntry _single(String text) {
  final result = parseM3u(text);
  expect(result.entries, hasLength(1), reason: result.warnings.join('\n'));
  return result.entries.single;
}

void main() {
  group('parseM3u tolerates', () {
    test('a minimal playlist with the standard attributes', () {
      final e = _single(
        '#EXTM3U\n'
        '#EXTINF:-1 tvg-id="trt1.tr" tvg-name="TRT 1 HD" '
        'tvg-logo="http://logo.example.com/trt1.png" tvg-chno="1" '
        'group-title="TR | Ulusal",TRT 1 HD\n'
        'http://example.com/live/kanal/test123/1001.ts\n',
      );
      expect(e.name, 'TRT 1 HD');
      expect(e.url, 'http://example.com/live/kanal/test123/1001.ts');
      expect(e.duration, -1);
      expect(e.tvgId, 'trt1.tr');
      expect(e.tvgName, 'TRT 1 HD');
      expect(e.tvgLogo, 'http://logo.example.com/trt1.png');
      expect(e.tvgChno, 1);
      expect(e.group, 'TR | Ulusal');
      expect(e.kind, M3uKind.live);
      expect(e.unsupported, isFalse);
      expect(e.headers, isEmpty);
      expect(e.catchup, isNull);
    });

    test('a UTF-8 BOM before #EXTM3U', () {
      final bom = String.fromCharCode(0xFEFF);
      final r = parseM3u(
        '$bom#EXTM3U url-tvg="http://epg.example.com/a.xml"\n'
        '#EXTINF:-1,A\nhttp://example.com/a.ts\n',
      );
      expect(r.header.tvgUrls, ['http://epg.example.com/a.xml']);
      expect(r.entries.single.name, 'A');
      expect(r.warnings, isEmpty);
    });

    test('a BOM that was decoded as Latin-1', () {
      final mojibake = String.fromCharCodes([0xEF, 0xBB, 0xBF]);
      final r = parseM3u(
        '$mojibake#EXTM3U url-tvg="http://epg.example.com/a.xml"\n'
        '#EXTINF:-1,A\nhttp://example.com/a.ts\n',
      );
      expect(r.header.tvgUrls, ['http://epg.example.com/a.xml']);
      expect(r.entries, hasLength(1));
    });

    test('CRLF line endings', () {
      final r = parseM3u(
        '#EXTM3U\r\n#EXTINF:-1,One\r\nhttp://example.com/1.ts\r\n'
        '#EXTINF:-1,Two\r\nhttp://example.com/2.ts\r\n',
      );
      expect(r.entries.map((e) => e.name), ['One', 'Two']);
      expect(r.entries.map((e) => e.url), [
        'http://example.com/1.ts',
        'http://example.com/2.ts',
      ]);
    });

    test('CR-only line endings', () {
      final r = parseM3u(
        '#EXTM3U\r#EXTINF:-1,One\rhttp://example.com/1.ts\r'
        '#EXTINF:-1,Two\rhttp://example.com/2.ts',
      );
      expect(r.entries.map((e) => e.name), ['One', 'Two']);
    });

    test('mixed LF, CRLF and CR line endings', () {
      final r = parseM3u(
        '#EXTM3U\n#EXTINF:-1,One\r\nhttp://example.com/1.ts\r'
        '#EXTINF:-1,Two\nhttp://example.com/2.ts\r\n',
      );
      expect(r.entries.map((e) => e.url), [
        'http://example.com/1.ts',
        'http://example.com/2.ts',
      ]);
    });

    test('blank and whitespace-only lines between #EXTINF and the URL', () {
      final e = _single(
        '#EXTM3U\n\n#EXTINF:-1,Spaced\n\n   \n\t\nhttp://example.com/s.ts\n\n',
      );
      expect(e.name, 'Spaced');
      expect(e.url, 'http://example.com/s.ts');
    });

    test('leading and trailing whitespace on every line', () {
      final r = parseM3u(
        '   #EXTM3U url-tvg="http://epg.example.com/e.xml"  \n'
        '\t #EXTINF:-1 tvg-id="x" ,  Indented  \n'
        '    http://example.com/i.ts   \n',
      );
      expect(r.header.tvgUrls, ['http://epg.example.com/e.xml']);
      final e = r.entries.single;
      expect(e.tvgId, 'x');
      expect(e.name, 'Indented');
      expect(e.url, 'http://example.com/i.ts');
    });

    test('a missing #EXTM3U header (with a warning)', () {
      final r = parseM3u('#EXTINF:-1 tvg-id="a",A\nhttp://example.com/a.ts\n');
      expect(r.entries.single.tvgId, 'a');
      expect(r.header.isEmpty, isTrue);
      expect(r.warnings.first, contains('No #EXTM3U'));
    });

    test('single-quoted attribute values', () {
      final e = _single(
        "#EXTINF:-1 tvg-id='single.id' group-title='Haber, Spor',Quoted\n"
        'http://example.com/q.ts',
      );
      expect(e.tvgId, 'single.id');
      expect(e.group, 'Haber, Spor');
      expect(e.name, 'Quoted');
    });

    test('unquoted attribute values', () {
      final e = _single(
        '#EXTINF:-1 tvg-id=plain.id tvg-chno=7 group-title=News,Plain\n'
        'http://example.com/p.ts',
      );
      expect(e.tvgId, 'plain.id');
      expect(e.tvgChno, 7);
      expect(e.group, 'News');
      expect(e.name, 'Plain');
    });

    test('unquoted values with spaces run until the next key=', () {
      final e = _single(
        '#EXTINF:-1 tvg-id=abc group-title=News Channel '
        'tvg-logo=http://logo.example.com/l.png,CNN International\n'
        'http://example.com/cnn.ts',
      );
      expect(e.tvgId, 'abc');
      expect(e.group, 'News Channel');
      expect(e.tvgLogo, 'http://logo.example.com/l.png');
      expect(e.name, 'CNN International');
    });

    test('quoted values containing commas and spaces', () {
      final e = _single(
        '#EXTINF:-1 group-title="News, Sports & More" '
        'tvg-logo="http://logo.example.com/a b,c.png",Name\n'
        'http://example.com/n.ts',
      );
      expect(e.group, 'News, Sports & More');
      expect(e.tvgLogo, 'http://logo.example.com/a b,c.png');
      expect(e.name, 'Name');
    });

    test('the display-name comma inside quoted values (tvg-name="A, B")', () {
      final e = _single(
        '#EXTINF:-1 tvg-name="A, B" group-title="X, Y",A, B\n'
        'http://example.com/ab.ts',
      );
      expect(e.tvgName, 'A, B');
      expect(e.group, 'X, Y');
      expect(e.name, 'A, B');
    });

    test('commas in the display name without attributes', () {
      final e = _single(
        '#EXTINF:-1,Name, with, commas\nhttp://example.com/c.ts',
      );
      expect(e.name, 'Name, with, commas');
      expect(e.attrs, isEmpty);
    });

    test('quotes in the display name', () {
      final e = _single(
        '#EXTINF:-1 tvg-id="best",The "Best" Channel\nhttp://example.com/b.ts',
      );
      expect(e.tvgId, 'best');
      expect(e.name, 'The "Best" Channel');
    });

    test('attributes without spaces between them', () {
      final e = _single(
        '#EXTINF:-1 tvg-id="a"tvg-name="B"group-title="C",D\n'
        'http://example.com/d.ts',
      );
      expect(e.tvgId, 'a');
      expect(e.tvgName, 'B');
      expect(e.group, 'C');
      expect(e.name, 'D');
    });

    test('spaces around = before a quoted value', () {
      final e = _single(
        '#EXTINF:-1 tvg-id = "spaced" group-title= "G",S\n'
        'http://example.com/s.ts',
      );
      expect(e.tvgId, 'spaced');
      expect(e.group, 'G');
    });

    test('attribute keys in any case (keys are lower-cased)', () {
      final e = _single(
        '#EXTINF:-1 TVG-ID="upper" Tvg-Logo="http://logo.example.com/u.png" '
        'GROUP-TITLE="Caps",Upper\nhttp://example.com/u.ts',
      );
      expect(e.tvgId, 'upper');
      expect(e.tvgLogo, 'http://logo.example.com/u.png');
      expect(e.group, 'Caps');
      expect(e.attrs.keys, containsAll(['tvg-id', 'tvg-logo', 'group-title']));
    });

    test('duplicate attributes (the first one wins)', () {
      final e = _single(
        '#EXTINF:-1 tvg-id="first" tvg-id="second",Dup\n'
        'http://example.com/d.ts',
      );
      expect(e.tvgId, 'first');
    });

    test('a negative duration', () {
      expect(_single('#EXTINF:-1,Live\nhttp://example.com/l.ts').duration, -1);
    });

    test('a zero duration', () {
      expect(_single('#EXTINF:0,Zero\nhttp://example.com/z.ts').duration, 0);
    });

    test('a missing duration before attributes', () {
      final a = _single('#EXTINF: tvg-id="x",Name\nhttp://example.com/x.ts');
      expect(a.duration, -1);
      expect(a.tvgId, 'x');
      expect(a.name, 'Name');
      final b = _single('#EXTINF:tvg-id="y",Other\nhttp://example.com/y.ts');
      expect(b.duration, -1);
      expect(b.tvgId, 'y');
    });

    test('a missing duration without attributes (#EXTINF:,Name)', () {
      final e = _single('#EXTINF:,Bare\nhttp://example.com/b.ts');
      expect(e.duration, -1);
      expect(e.name, 'Bare');
    });

    test('a decimal duration (truncated to seconds)', () {
      expect(
        _single('#EXTINF:5400.75,Film\nhttp://example.com/f.ts').duration,
        5400,
      );
    });

    test('#EXTINF:-1,Name without attributes', () {
      final e = _single('#EXTINF:-1,Just A Name\nhttp://example.com/j.ts');
      expect(e.name, 'Just A Name');
      expect(e.attrs, isEmpty);
      expect(e.tvgId, isNull);
      expect(e.group, isNull);
    });

    test('lower-case tags', () {
      final r = parseM3u(
        '#extm3u url-tvg="http://epg.example.com/l.xml"\n'
        '#extinf:-1 tvg-id="low",Low\n'
        '#extgrp:Lower\n'
        'http://example.com/low.ts\n',
      );
      expect(r.header.tvgUrls, ['http://epg.example.com/l.xml']);
      expect(r.entries.single.tvgId, 'low');
      expect(r.entries.single.group, 'Lower');
    });

    test('an empty display name (falls back to tvg-name)', () {
      final e = _single(
        '#EXTINF:-1 tvg-id="id1" tvg-name="From Tvg Name",\n'
        'http://example.com/n.ts',
      );
      expect(e.name, 'From Tvg Name');
    });

    test('no display name and no tvg-name (falls back to tvg-id)', () {
      final e = _single(
        '#EXTINF:-1 tvg-id="only.id",\nhttp://example.com/o.ts',
      );
      expect(e.name, 'only.id');
    });

    test('no name at all (falls back to the URL file name)', () {
      final e = _single(
        '#EXTINF:-1,\nhttp://example.com/live/Haber%20TV.m3u8?token=abc',
      );
      expect(e.name, 'Haber TV');
    });

    test('a missing display-name comma (bare words become the name)', () {
      final e = _single(
        '#EXTINF:-1 tvg-id="bbc1" BBC One\nhttp://example.com/bbc.ts',
      );
      expect(e.tvgId, 'bbc1');
      expect(e.name, 'BBC One');
    });

    test('an unterminated quote (the display name survives)', () {
      final e = _single(
        '#EXTINF:-1 tvg-id="x" tvg-name="Broken,Display\n'
        'http://example.com/broken.ts',
      );
      expect(e.tvgId, 'x');
      expect(e.tvgName, 'Broken');
      expect(e.name, 'Display');
    });

    test('empty attribute values (null fields, raw value kept in attrs)', () {
      final e = _single(
        '#EXTINF:-1 tvg-id="" tvg-name="" tvg-logo="" group-title="",Empty\n'
        'http://example.com/e.ts',
      );
      expect(e.tvgId, isNull);
      expect(e.tvgName, isNull);
      expect(e.tvgLogo, isNull);
      expect(e.group, isNull);
      expect(e.attrs['tvg-id'], '');
    });

    test('unknown attributes (kept in attrs)', () {
      final e = _single(
        '#EXTINF:-1 radio="true" tvg-rec="3" X-Custom="v" tvg-country="TR",R\n'
        'http://example.com/r.mp3',
      );
      expect(e.attrs, {
        'radio': 'true',
        'tvg-rec': '3',
        'x-custom': 'v',
        'tvg-country': 'TR',
      });
    });

    test('comments and unknown tags', () {
      final r = parseM3u(
        '#EXTM3U\n'
        '# a plain comment\n'
        '#EXTENC:UTF-8\n'
        '#PLAYLIST:My list\n'
        '#EXTINF:-1,Kept\n'
        '# comment between EXTINF and URL\n'
        '#EXTALB:Album\n'
        'http://example.com/kept.ts\n',
      );
      expect(r.entries.single.name, 'Kept');
      expect(r.warnings, isEmpty);
    });

    test('a plain list of URLs without #EXTINF', () {
      final r = parseM3u(
        'http://example.com/one.ts\nhttp://example.com/two.m3u8\n',
      );
      expect(r.entries.map((e) => e.name), ['one', 'two']);
      expect(r.entries.every((e) => e.kind == M3uKind.live), isTrue);
    });

    test('multiple URLs after one #EXTINF (extra URLs become entries)', () {
      final r = parseM3u(
        '#EXTM3U\n'
        '#EXTINF:-1 tvg-id="a" group-title="G",Alpha\n'
        'http://example.com/primary.ts\n'
        'http://example.com/backup.ts\n',
      );
      expect(r.entries, hasLength(2));
      expect(r.entries[0].name, 'Alpha');
      expect(r.entries[0].url, 'http://example.com/primary.ts');
      expect(r.entries[0].group, 'G');
      expect(r.entries[1].name, 'backup');
      expect(r.entries[1].tvgId, isNull);
      expect(r.entries[1].group, isNull);
    });

    test('#EXTINF without a URL before the next #EXTINF (skipped)', () {
      final r = parseM3u(
        '#EXTM3U\n#EXTINF:-1,Lost\n#EXTINF:-1,Kept\nhttp://example.com/k.ts\n',
      );
      expect(r.entries.single.name, 'Kept');
      expect(r.warnings.single, contains('Line 2'));
    });

    test('a trailing #EXTINF without a URL at the end of the file', () {
      final r = parseM3u(
        '#EXTM3U\n#EXTINF:-1,A\nhttp://example.com/a.ts\n#EXTINF:-1,B\n',
      );
      expect(r.entries.single.name, 'A');
      expect(r.warnings.single, allOf(contains('Line 4'), contains('end')));
    });

    test('relative URLs (kept as written)', () {
      final r = parseM3u(
        '#EXTM3U\n'
        '#EXTINF:-1,Rel\nstreams/rel.ts\n'
        '#EXTINF:-1,Abs\n/abs/path.m3u8\n'
        '#EXTINF:-1,Up\n../up/file.ts\n',
      );
      expect(r.entries.map((e) => e.url), [
        'streams/rel.ts',
        '/abs/path.m3u8',
        '../up/file.ts',
      ]);
    });

    test('very long lines', () {
      final longName = 'N' * 100000;
      final longQuery = 'q' * 100000;
      final e = _single(
        '#EXTINF:-1 tvg-id="long",$longName\n'
        'http://example.com/long.ts?$longQuery\n',
      );
      expect(e.name.length, 100000);
      expect(e.url.length, 'http://example.com/long.ts?'.length + 100000);
    });

    test('tvg-chno variants and the channel-number alias', () {
      final r = parseM3u(
        '#EXTINF:-1 tvg-chno="5.1",A\nhttp://example.com/a.ts\n'
        '#EXTINF:-1 tvg-chno="abc",B\nhttp://example.com/b.ts\n'
        '#EXTINF:-1 channel-number="7",C\nhttp://example.com/c.ts\n'
        '#EXTINF:-1 tvg-chno="" channel-number="8",D\nhttp://example.com/d.ts\n',
      );
      expect(r.entries.map((e) => e.tvgChno), [5, null, 7, 8]);
    });

    test('the logo alias for tvg-logo', () {
      final e = _single(
        '#EXTINF:-1 logo="http://logo.example.com/alias.png",L\n'
        'http://example.com/l.ts',
      );
      expect(e.tvgLogo, 'http://logo.example.com/alias.png');
    });

    test('empty input and a header-only playlist', () {
      expect(parseM3u('').entries, isEmpty);
      final r = parseM3u('#EXTM3U\n');
      expect(r.entries, isEmpty);
      expect(r.warnings, isEmpty);
      expect(r.header.isEmpty, isTrue);
    });

    test('file order is preserved', () {
      final text = StringBuffer('#EXTM3U\n');
      for (var i = 0; i < 50; i++) {
        text.write('#EXTINF:-1,Channel $i\nhttp://example.com/$i.ts\n');
      }
      final r = parseM3u(text.toString());
      expect(r.entries.map((e) => e.name), [
        for (var i = 0; i < 50; i++) 'Channel $i',
      ]);
    });

    test('a single HLS stream given as a playlist (warning)', () {
      final r = parseM3u(
        '#EXTM3U\n#EXT-X-VERSION:3\n#EXT-X-TARGETDURATION:10\n'
        '#EXTINF:10.0,\nseg0.ts\n#EXTINF:10.0,\nseg1.ts\n',
      );
      expect(r.entries, hasLength(2));
      expect(r.warnings.where((w) => w.contains('HLS')), hasLength(1));
    });

    test('garbage input without throwing', () {
      final r = parseM3u(
        '<html><body>404 Not Found</body></html>\n'
        '#EXTINF\n#EXTINF:\n#EXTINF:-\n#EXTINF:,\n"\n\'\n=\n,,,\n',
      );
      expect(r.entries, isNotEmpty);
    });

    test('pathological attribute text without throwing', () {
      final e = _single(
        '#EXTINF:-1 = "orphan" ="x" tvg-id= tvg-name="y" a="b\'c" \'q\',N\n'
        'http://example.com/p.ts',
      );
      expect(e.tvgName, 'y');
      expect(e.attrs['a'], "b'c");
      expect(e.name, 'N');
    });

    test('many warnings (capped with a summary line)', () {
      final text = List.filled(150, '#EXTINF:-1,No URL').join('\n');
      final r = parseM3u(text);
      expect(r.entries, isEmpty);
      expect(r.warnings, hasLength(maxM3uWarnings + 1));
      expect(r.warnings.last, '... and 50 more warnings');
    });

    test('non-ASCII names', () {
      final e = _single(
        '#EXTINF:-1 group-title="Çocuk",Çocuk Kilitli — Şeker İçerik\n'
        'http://example.com/cocuk.ts',
      );
      expect(e.group, 'Çocuk');
      expect(e.name, 'Çocuk Kilitli — Şeker İçerik');
    });

    test('toString never prints the URL', () {
      final e = _single(
        '#EXTINF:-1,Secret\nhttp://example.com/live/kanal/test123/1.ts',
      );
      expect(e.toString(), isNot(contains('test123')));
      expect(e.toString(), contains('Secret'));
    });
  });
}
