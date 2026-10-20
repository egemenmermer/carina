import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/sources/source_exception.dart';
import 'package:carina/data/sources/xmltv/xmltv.dart';

import 'xmltv_fixtures.dart';

void main() {
  DateTime utc(int d, int h, [int m = 0]) => DateTime.utc(2026, 10, d, h, m);

  group('parseXmltv', () {
    test('parses channels and programmes with all fields', () async {
      final events = await parseString(sampleXmltv);
      final channels = events.whereType<XmltvChannel>().toList();
      final programmes = events.whereType<XmltvProgramme>().toList();

      expect(channels, [
        const XmltvChannel(
          id: 'ShowTV.tr',
          displayNames: ['Show TV', 'SHOW', 'Show TV HD'],
          icon: 'http://logos/show.png',
        ),
        const XmltvChannel(id: 'TRT1.tr', displayNames: ['TRT 1']),
      ]);
      expect(channels.first.displayName, 'Show TV');

      expect(programmes, hasLength(3));
      final first = programmes[0];
      expect(first.channelId, 'ShowTV.tr');
      expect(first.start, utc(17, 9)); // 12:00 +0300
      expect(first.stop, utc(17, 10)); // 13:00 +0300
      expect(first.title, 'Haberler & Gündem');
      expect(first.subTitle, "Öğle Bülteni 'Canlı'");
      expect(first.description, 'Günün <önemli> haberleri.\nİkinci satır.');
      expect(first.category, 'Haber');
      expect(first.episodeNum, 'S1 E5');
      expect(first.episodeOnscreen, 'S01E05');
      expect(first.icon, 'http://img/news.jpg');
      expect(first.rating, '7+');
      expect(first.duration, const Duration(hours: 1));

      final second = programmes[1];
      expect(second.title, 'Dizi Gecesi');
      expect(second.start, utc(17, 10));
      expect(second.stop, utc(17, 12));
      expect(second.episodeNum, 'E3'); // xmltv_ns `.2.`: episode only
      expect(second.rating, isNull); // star-rating is not a rating
      expect(second.icon, 'http://img/poster.jpg'); // <image> fallback

      final third = programmes[2];
      expect(third.channelId, 'TRT1.tr');
      expect(third.start, utc(17, 17)); // 12:00 -0500
      expect(third.title, 'Film');
      expect(third.description, isNull);
      expect(third.episodeNum, 'Bölüm 12');
      expect(third.episodeOnscreen, 'Bölüm 12');
    });

    test('gives the same result for every chunking (entities, CDATA and '
        'multi-byte characters split across chunks)', () async {
      final whole = await parseString(sampleXmltv);
      for (final size in [1, 2, 3, 7, 64, 1000]) {
        expect(
          await parseString(sampleXmltv, chunkSize: size),
          whole,
          reason: 'chunk size $size',
        );
      }
    });

    test('prefers the configured languages', () async {
      const doc = '''
<tv>
  <channel id="a"><display-name lang="en">Show</display-name><display-name lang="tr">Şov</display-name></channel>
  <programme start="20261017120000" stop="20261017130000" channel="a">
    <title lang="en">News</title><title lang="tr-TR">Haberler</title><title>Nachrichten</title>
    <desc lang="en">English</desc><desc lang="TR">Türkçe</desc>
    <category lang="en">News</category><category lang="tr">Haber</category>
  </programme>
</tv>''';
      final plain = await parseString(doc);
      final channel = plain.whereType<XmltvChannel>().single;
      final programme = plain.whereType<XmltvProgramme>().single;
      expect(channel.displayNames, ['Show', 'Şov']);
      expect(programme.title, 'News');
      expect(programme.description, 'English');
      expect(programme.category, 'News');

      final turkish = await parseString(doc, languages: ['tr', 'en']);
      expect(turkish.whereType<XmltvChannel>().single.displayNames, [
        'Şov',
        'Show',
      ]);
      final tr = turkish.whereType<XmltvProgramme>().single;
      expect(tr.title, 'Haberler');
      expect(tr.description, 'Türkçe');
      expect(tr.category, 'Haber');

      final german = await parseString(doc, languages: ['de']);
      expect(german.whereType<XmltvProgramme>().single.title, 'News');
    });

    test('formats xmltv_ns episode numbers', () {
      expect(formatXmltvEpisode('0.4.'), 'S1 E5');
      expect(formatXmltvEpisode(' 0 . 4 . 0/1 '), 'S1 E5');
      expect(formatXmltvEpisode('2.9/12.0/2'), 'S3 E10');
      expect(formatXmltvEpisode('.4.'), 'E5');
      expect(formatXmltvEpisode('2..'), 'S3');
      expect(formatXmltvEpisode('..'), isNull);
      expect(formatXmltvEpisode('x.y.'), isNull);
      expect(formatXmltvEpisode(''), isNull);
    });

    group('missing or broken stop', () {
      test('is derived from the next programme of the same channel, '
          'otherwise start + 30 min', () async {
        const doc = '''
<tv>
  <programme start="20261017100000 +0000" channel="a"><title>A1</title></programme>
  <programme start="20261017103000 +0000" stop="20261017110000 +0000" channel="b"><title>B1</title></programme>
  <programme start="20261017104500 +0000" channel="a"><title>A2</title></programme>
  <programme start="20261017120000 +0000" stop="20261017110000 +0000" channel="a"><title>A3 stop before start</title></programme>
  <programme start="20261019120000 +0000" stop="20261019130000 +0000" channel="a"><title>A4 two days later</title></programme>
  <programme start="20261017200000 +0000" channel="c"><title>C1 last</title></programme>
</tv>''';
        final programmes = (await parseString(doc))
            .whereType<XmltvProgramme>()
            .toList();
        String span(XmltvProgramme p) =>
            '${p.title}: ${p.start.hour}:${p.start.minute} – '
            '${p.stop.day}/${p.stop.hour}:${p.stop.minute}';
        expect(programmes.map(span), [
          'B1: 10:30 – 17/11:0',
          'A1: 10:0 – 17/10:45',
          'A2: 10:45 – 17/12:0',
          // A3's stop was before its start; the next programme of `a` is
          // more than 24 h later, so it gets the 30 minute default.
          'A3 stop before start: 12:0 – 17/12:30',
          'A4 two days later: 12:0 – 19/13:0',
          'C1 last: 20:0 – 17/20:30',
        ]);
      });
    });

    test('skips programmes without channel or with a bad start', () async {
      const doc = '''
<tv>
  <programme start="20261017100000" stop="20261017110000"><title>no channel</title></programme>
  <programme start="garbage" stop="20261017110000" channel="a"><title>bad start</title></programme>
  <programme stop="20261017110000" channel="a"><title>no start</title></programme>
  <programme start="20261017100000" stop="20261017110000" channel="a"><title>ok</title></programme>
  <channel><display-name>no id</display-name></channel>
</tv>''';
      final events = await parseString(doc);
      expect(events.whereType<XmltvChannel>(), isEmpty);
      expect(events.whereType<XmltvProgramme>().map((p) => p.title), ['ok']);
    });

    test('handles self-closing tags, unknown elements, comments, doctype '
        'and whitespace', () async {
      const doc = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE tv SYSTEM "xmltv.dtd">
<?xml-stylesheet type="text/xsl" href="x.xsl"?>
<tv generator-info-name="test" source-info-url="http://example">
  <!-- a comment -->
  <channel id="  spaced.id  ">
    <display-name>
        Spaced   Name
    </display-name>
    <display-name/>
    <url>http://example</url>
    <icon src=" http://logo.png "/>
  </channel>
  <unknown><programme start="20261017100000" channel="x"><title>nested, ignored</title></programme></unknown>
  <programme start="20261017100000" stop="20261017110000" channel="spaced.id" clumpidx="0/1">
    <title>
      Multi
      line   title
    </title>
    <title/>
    <credits><director>Someone</director><actor role="x">Actor</actor></credits>
    <date>2026</date>
    <icon src="http://first.png" width="100"/>
    <icon src="http://second.png"/>
    <new/>
    <previously-shown start="20250101000000"/>
    <subtitles type="teletext"><language>tr</language></subtitles>
    <rating system="RTÜK"><value>13+</value><icon src="http://rating.png"/></rating>
    <rating system="other"><value>PG</value></rating>
    <star-rating><value>3/5</value></star-rating>
    <review type="text">Good</review>
  </programme>
  <programme start="20261017110000" stop="20261017120000" channel="spaced.id"/>
</tv>
''';
      final events = await parseString(doc);
      final channel = events.whereType<XmltvChannel>().single;
      expect(channel.id, 'spaced.id');
      expect(channel.displayNames, ['Spaced Name']);
      expect(channel.icon, 'http://logo.png');
      final programmes = events.whereType<XmltvProgramme>().toList();
      expect(programmes, hasLength(2));
      expect(programmes[0].title, 'Multi line title');
      expect(programmes[0].icon, 'http://first.png');
      expect(programmes[0].rating, '13+');
      expect(programmes[1].title, '');
      expect(programmes[1].stop, DateTime.utc(2026, 10, 17, 12));
    });

    test('decodes XML, numeric and HTML entities and CDATA', () async {
      const doc = '''
<tv><programme start="20261017100000" stop="20261017110000" channel="a">
  <title>Tom &amp; Jerry&#039;s &#x27;Show&#x27; &lt;3 &quot;q&quot; &apos;a&apos; caf&eacute;&nbsp;bar</title>
  <sub-title><![CDATA[<b>Raw</b> & unescaped]]></sub-title>
  <desc>Before <![CDATA[inside &amp; raw]]> after &amp; done</desc>
  <category>Tom & Jerry</category>
</programme></tv>''';
      final p = (await parseString(doc)).whereType<XmltvProgramme>().single;
      expect(p.title, 'Tom & Jerry\'s \'Show\' <3 "q" \'a\' café bar');
      expect(p.subTitle, '<b>Raw</b> & unescaped');
      expect(p.description, 'Before inside &amp; raw after & done');
      expect(p.category, 'Tom & Jerry');
    });

    test('normalizes CRLF in descriptions and keeps line breaks', () async {
      const doc =
          '<tv><programme start="20261017100000" stop="20261017110000" '
          'channel="a"><title>T</title><desc>  one\r\ntwo\rthree\n </desc>'
          '</programme></tv>';
      final p = (await parseString(doc)).whereType<XmltvProgramme>().single;
      expect(p.description, 'one\ntwo\nthree');
    });

    test('accepts a UTF-8 BOM and replaces malformed UTF-8', () async {
      final bytes = <int>[
        0xEF, 0xBB, 0xBF, // BOM
        ...utf8.encode(
          '<tv><programme start="20261017100000" stop="20261017110000" '
          'channel="a"><title>A',
        ),
        0xFF, 0xFE, // invalid UTF-8
        ...utf8.encode('B</title></programme></tv>'),
      ];
      final p = (await parseBytes(bytes)).whereType<XmltvProgramme>().single;
      expect(p.title, 'A��B');
    });

    group('gzip', () {
      test(
        'is sniffed from the content, whatever the file is called',
        () async {
          final dir = await Directory.systemTemp.createTemp('carina_xmltv');
          addTearDown(() => dir.delete(recursive: true));
          final file = File('${dir.path}/guide.xml'); // not .gz
          await file.writeAsBytes(gzip.encode(utf8.encode(sampleXmltv)));
          final fromFile = await parseXmltv(file.openRead()).toList();
          expect(fromFile, await parseString(sampleXmltv));
        },
      );

      test('works with tiny chunks', () async {
        final compressed = gzip.encode(utf8.encode(sampleXmltv));
        expect(
          await parseBytes(compressed, chunkSize: 3),
          await parseString(sampleXmltv),
        );
      });

      test('multi-member gzip parses completely or fails loudly', () async {
        // `cat a.gz b.gz c.gz`. dart:io's streaming inflater drops the rest
        // of a chunk when a member ends in a call that produces no output,
        // so depending on where chunks are cut this fails; it must then be
        // an error, never silently truncated data.
        final third = sampleXmltv.length ~/ 3;
        final parts = [
          sampleXmltv.substring(0, third),
          sampleXmltv.substring(third, 2 * third),
          sampleXmltv.substring(2 * third),
        ];
        final members = [for (final part in parts) ...gz(utf8.encode(part))];
        final expected = await parseString(sampleXmltv);
        var complete = 0;
        for (var size = 1; size <= members.length + 1; size++) {
          try {
            expect(
              await parseBytes(members, chunkSize: size),
              expected,
              reason: 'chunk size $size',
            );
            complete++;
          } on SourceException catch (e) {
            expect(e.kind, SourceErrorKind.unparseable);
          }
        }
        expect(complete, greaterThan(0));
        // One chunk (the whole file) always works.
        expect(await parseBytes(members), expected);
      });

      test('a document shorter than the sniffing window parses', () async {
        expect(await parseString('<tv/>'), isEmpty);
      });
    });

    group('errors', () {
      Future<SourceException> failure(List<int> bytes, {int? chunkSize}) async {
        try {
          await parseBytes(bytes, chunkSize: chunkSize);
        } on SourceException catch (e) {
          return e;
        }
        fail('expected a SourceException');
      }

      test('empty input is emptyBody', () async {
        final e = await failure(const []);
        expect(e.kind, SourceErrorKind.emptyBody);
      });

      test('malformed XML is unparseable', () async {
        final e = await failure(
          utf8.encode(
            '<tv><programme start="20261017100000" channel="a">'
            '<title>x</desc></programme></tv>',
          ),
        );
        expect(e.kind, SourceErrorKind.unparseable);
        expect(e.message, contains('Malformed XMLTV'));
      });

      test('a document truncated inside a tag is unparseable', () async {
        final cut = sampleXmltv.substring(
          0,
          sampleXmltv.indexOf('channel="TRT1') + 5,
        );
        final e = await failure(utf8.encode(cut), chunkSize: 100);
        expect(e.kind, SourceErrorKind.unparseable);
      });

      test('a document truncated between elements is unparseable', () async {
        final cut = sampleXmltv.substring(0, sampleXmltv.lastIndexOf('</tv>'));
        final e = await failure(utf8.encode(cut));
        expect(e.kind, SourceErrorKind.unparseable);
        expect(e.message, contains('tv'));
      });

      test('truncated gzip is unparseable', () async {
        final compressed = gzip.encode(utf8.encode(sampleXmltv * 20));
        final e = await failure(compressed.sublist(0, compressed.length ~/ 2));
        expect(e.kind, SourceErrorKind.unparseable);
      });

      test('corrupt gzip is unparseable', () async {
        final compressed = gzip.encode(utf8.encode(sampleXmltv));
        for (var i = 20; i < compressed.length - 10; i += 7) {
          compressed[i] ^= 0x5A;
        }
        final e = await failure(compressed);
        expect(e.kind, SourceErrorKind.unparseable);
      });

      test('an HTML page is unparseable and says what it got', () async {
        final e = await failure(
          utf8.encode('<!DOCTYPE html><html><body>Login</body></html>'),
        );
        expect(e.kind, SourceErrorKind.unparseable);
        expect(e.message, contains('<html>'));
      });

      test('non-XML content is unparseable', () async {
        final e = await failure(utf8.encode('{"user_info":{"auth":0}}'));
        expect(e.kind, SourceErrorKind.unparseable);
      });

      test('xz and zip are rejected with a clear message', () async {
        final xz = await failure([0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00, 1, 2]);
        expect(xz.message, contains('xz'));
        final zip = await failure([0x50, 0x4B, 0x03, 0x04, 0, 0, 0, 0]);
        expect(zip.message, contains('zip'));
      });

      test('errors of the input stream pass through', () async {
        final input = Stream<List<int>>.fromFuture(
          Future.error(const SocketException('offline')),
        );
        await expectLater(
          parseXmltv(input).toList(),
          throwsA(isA<SocketException>()),
        );
      });
    });
  });
}
