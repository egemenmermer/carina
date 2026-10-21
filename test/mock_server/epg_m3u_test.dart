import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml_events.dart';

import '../../tools/mock_server/src/server.dart';
import 'helpers.dart';

final _xmltvTime = RegExp(
  r'^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2}) ([+-])(\d{2})(\d{2})$',
);

DateTime _parseXmltvTime(String s) {
  final m = _xmltvTime.firstMatch(s)!;
  int g(int i) => int.parse(m.group(i)!);
  final local = DateTime.utc(g(1), g(2), g(3), g(4), g(5), g(6));
  final offset = Duration(hours: g(8), minutes: g(9));
  return m.group(7) == '+' ? local.subtract(offset) : local.add(offset);
}

final class _Programme {
  _Programme(this.channel, this.start, this.stop);

  final String channel;
  final String start;
  final String stop;
  final children = <String>{};
  String? titleLang;
  final episodeSystems = <String>{};
}

final class _Guide {
  final channels = <String, List<String>>{};
  final programmes = <_Programme>[];
}

_Guide _parseGuide(String xml) {
  final guide = _Guide();
  String? channelId;
  _Programme? programme;
  String? element;
  for (final event in parseEvents(xml, validateNesting: true)) {
    if (event is XmlStartElementEvent) {
      String? attr(String name) {
        for (final a in event.attributes) {
          if (a.name == name) return a.value;
        }
        return null;
      }

      switch (event.name) {
        case 'channel':
          channelId = attr('id');
          guide.channels[channelId!] = [];
        case 'programme':
          programme = _Programme(
            attr('channel')!,
            attr('start')!,
            attr('stop')!,
          );
          guide.programmes.add(programme);
        default:
          if (programme != null) {
            programme.children.add(event.name);
            if (event.name == 'title') programme.titleLang = attr('lang');
            if (event.name == 'episode-num') {
              programme.episodeSystems.add(attr('system')!);
            }
          }
      }
      element = event.isSelfClosing ? null : event.name;
    } else if (event is XmlTextEvent) {
      if (element == 'display-name' && channelId != null && programme == null) {
        guide.channels[channelId]!.add(event.value);
      }
    } else if (event is XmlEndElementEvent) {
      if (event.name == 'programme') programme = null;
      if (event.name == 'channel') channelId = null;
      element = null;
    }
  }
  return guide;
}

void main() {
  late FakeMedia media;
  late MockServer server;
  late String base;
  // A fixed clock keeps /epg.xml and /epg.xml.gz on the same guide window.
  final fixedNow = DateTime.now().toUtc();

  setUpAll(() async {
    media = await FakeMedia.create();
    server = await MockServer.start(
      port: 0,
      mediaDir: media.mediaDir,
      liveDir: media.liveDir,
      clock: () => fixedNow,
    );
    base = server.baseUrl;
  });

  tearDownAll(() async {
    await server.stop();
    await media.delete();
  });

  group('XMLTV', () {
    late String xml;
    late _Guide guide;

    setUpAll(() async {
      final gz = await fetch('$base/epg.xml.gz');
      expect(gz.status, 200);
      expect(gz.body.sublist(0, 2), [0x1F, 0x8B], reason: 'gzip magic bytes');
      xml = utf8.decode(gzip.decode(gz.body));
      guide = _parseGuide(xml);
    });

    test('epg.xml.gz decodes to a well-formed guide', () {
      expect(xml, startsWith('<?xml version="1.0" encoding="UTF-8"?>'));
      expect(xml.trimRight(), endsWith('</tv>'));
      final declared = server.catalog.epgChannels
          .where((e) => e.declared)
          .length;
      expect(guide.channels, hasLength(declared));
      expect(guide.programmes.length, greaterThan(40000));
      expect(guide.channels['trt1.tr'], contains('TRT 1'));
    });

    test('programmes cover now − 7 days … now + 7 days', () {
      final anchor = DateTime.utc(
        fixedNow.year,
        fixedNow.month,
        fixedNow.day,
        fixedNow.hour,
      );
      final from = anchor.subtract(const Duration(days: 7));
      final to = anchor.add(const Duration(days: 7));
      var minStart = to;
      var maxStop = from;
      for (final p in guide.programmes) {
        expect(p.start, matches(_xmltvTime));
        expect(p.stop, matches(_xmltvTime));
        final start = _parseXmltvTime(p.start);
        final stop = _parseXmltvTime(p.stop);
        expect(stop.isAfter(start), isTrue);
        final minutes = stop.difference(start).inMinutes;
        expect(minutes, inInclusiveRange(15, 120));
        expect(
          stop.isAfter(from) && start.isBefore(to),
          isTrue,
          reason: 'inside the window',
        );
        if (start.isBefore(minStart)) minStart = start;
        if (stop.isAfter(maxStop)) maxStop = stop;
      }
      expect(minStart.isAfter(from.add(const Duration(hours: 2))), isFalse);
      expect(maxStop.isBefore(to.subtract(const Duration(hours: 2))), isFalse);
      // Something is on air right now on TRT 1.
      final now = guide.programmes.where((p) {
        return p.channel == 'trt1.tr' &&
            !_parseXmltvTime(p.start).isAfter(fixedNow) &&
            _parseXmltvTime(p.stop).isAfter(fixedNow);
      });
      expect(now, hasLength(1));
    });

    test('programmes carry the XMLTV fields', () {
      final children = guide.programmes.expand((p) => p.children).toSet();
      expect(
        children,
        containsAll([
          'title',
          'sub-title',
          'desc',
          'category',
          'episode-num',
          'icon',
          'rating',
          'value',
        ]),
      );
      expect(guide.programmes.every((p) => p.titleLang != null), isTrue);
      final systems = guide.programmes.expand((p) => p.episodeSystems).toSet();
      expect(systems, {'xmltv_ns', 'onscreen'});
      expect(xml, contains('+0300"'));
      expect(xml, contains('+0000"'), reason: 'UK channels use UTC offsets');
      expect(xml, contains('&amp;'), reason: 'escaped titles');
    });

    test('ids match most channels; some only by name; a few not at all', () {
      final ids = guide.channels.keys.toSet();
      final channels = server.catalog.channels;
      final exact = channels.where(
        (c) => c.epgChannelId != null && ids.contains(c.epgChannelId),
      );
      final caseOnly = channels.where(
        (c) =>
            c.epgChannelId != null &&
            !ids.contains(c.epgChannelId) &&
            ids.contains(c.epgChannelId!.toLowerCase()),
      );
      expect(exact.length / channels.length, greaterThan(0.6));
      expect(caseOnly, isNotEmpty);
      final nameOnly = channels
          .where((c) => c.epgMatch == EpgMatchKind.nameOnly)
          .toList();
      expect(nameOnly.length / channels.length, inInclusiveRange(0.05, 0.16));
      for (final c in nameOnly) {
        expect(ids, isNot(contains(c.epgChannelId)));
        expect(
          guide.channels[c.xmltvId]!.map(channelKey),
          contains(channelKey(c.name)),
        );
      }
      expect(
        channels.where((c) => c.epgMatch == EpgMatchKind.none),
        isNotEmpty,
      );
      // Guide-only channels (Custom EPG candidates) and an undeclared id.
      expect(
        server.catalog.epgChannels.where((e) => !e.usedByStreams && e.declared),
        isNotEmpty,
      );
      expect(guide.programmes.any((p) => !ids.contains(p.channel)), isTrue);
    });

    test('/epg.xml and /xmltv.php serve the same document', () async {
      final plain = await fetch('$base/epg.xml');
      expect(plain.status, 200);
      expect(plain.header('content-type'), startsWith('application/xml'));
      expect(plain.text, xml);
      final php = await fetch('$base/xmltv.php?$account');
      expect(php.status, 200);
      expect(php.text, xml);
      expect(
        (await fetch('$base/xmltv.php?username=carina&password=bad')).status,
        401,
      );
      expect(
        (await fetch('$base/xmltv.php?username=expired&password=test123'))
            .status,
        403,
      );
      final cached = await fetch('$base/epg.xml.gz');
      expect(utf8.decode(gzip.decode(cached.body)), xml);
    });

    test('short EPG and XMLTV agree', () async {
      final r = await fetch(
        '${server.baseUrl}/player_api.php?$account&action=get_short_epg&stream_id=1001&limit=1',
      );
      final listing = ((r.json! as Map)['epg_listings'] as List).single as Map;
      final title = utf8.decode(base64.decode(listing['title'] as String));
      final start = int.parse(listing['start_timestamp'] as String);
      final match = guide.programmes.firstWhere(
        (p) =>
            p.channel == 'trt1.tr' &&
            _parseXmltvTime(p.start).millisecondsSinceEpoch ~/ 1000 == start,
      );
      final escaped = const HtmlEscape(HtmlEscapeMode.element).convert(title);
      expect(
        xml,
        contains('channel="trt1.tr"><title lang="tr">$escaped</title>'),
      );
      expect(match.channel, 'trt1.tr');
    });
  });

  group('M3U', () {
    test('/playlist.m3u has the extended attributes and edge cases', () async {
      final r = await fetch('$base/playlist.m3u');
      expect(r.status, 200);
      expect(r.body.sublist(0, 3), [0xEF, 0xBB, 0xBF], reason: 'UTF-8 BOM');
      // Dart's UTF-8 decoder may drop the BOM; the raw bytes were checked.
      final decoded = r.text;
      final text = decoded.startsWith('\uFEFF')
          ? decoded.substring(1)
          : decoded;
      expect(
        text,
        startsWith(
          '#EXTM3U url-tvg="$base/epg.xml.gz" x-tvg-url="$base/epg.xml.gz"',
        ),
      );
      expect(text, contains('\r\n'), reason: 'CRLF lines');
      expect(text, contains('\n\n'), reason: 'blank lines');
      expect(
        RegExp(r'tvg-chno=\d+ ').hasMatch(text),
        isTrue,
        reason: 'unquoted attribute',
      );
      for (final needle in [
        'tvg-id="trt1.tr"',
        'tvg-name="TRT 1 HD"',
        'tvg-logo="$base/img/logo_00.png"', //
        'group-title="TR | Ulusal"', '#EXTVLCOPT:http-user-agent=CarinaMock/1.0',
        '#EXTVLCOPT:http-referrer=$base/',
        '#EXTHTTP:{"User-Agent":"CarinaMock/1.0"',
        '#EXTGRP:', '#KODIPROP:inputstream.adaptive.license_key=',
        'catchup="default"', 'catchup="append"', 'catchup="shift"',
        'catchup="flussonic"', 'catchup="xc"', 'catchup-days="3"',
        'catchup-source="$base/timeshift/carina/test123/{duration:60}/{Y}-{m}-{d}:{H}-{M}/1001.ts"',
        'catchup-source="?utc={utc}&lutc={lutc}"',
        '/fs/ch',
        '/movie/carina/test123/3001.mkv',
        '/series/carina/test123/', 'Sıcak Kafa S01E02', 'Sıcak Kafa S01 E01',
        '$base/live/carina/test123/1001.ts?plain=1',
        '#EXTINF:5400',
        '$base/vod/ornek-film.mp4',
      ]) {
        expect(text, contains(needle), reason: needle);
      }
      final live = RegExp(
        r'^http://[^\n]*/live/carina/test123/\d+\.ts\r?$',
        multiLine: true,
      ).allMatches(text).length;
      expect(live, greaterThanOrEqualTo(server.catalog.channels.length - 30));
      final extinf = RegExp(
        r'^#EXTINF',
        multiLine: true,
      ).allMatches(text).length;
      final c = server.catalog;
      expect(
        extinf,
        greaterThan(c.channels.length + c.movies.length + c.episodeCount),
      );
    });

    test('the plain HTTP entries of the playlist play', () async {
      final r = await readStreamFor(
        '$base/live/carina/test123/1001.ts?plain=1',
        const Duration(milliseconds: 300),
      );
      expect(r.status, 200);
      expect(r.bytes, greaterThan(0));
    });

    test('get.php exports the catalog like an Xtream panel', () async {
      final r = await fetch('$base/get.php?$account&type=m3u_plus&output=ts');
      expect(r.status, 200);
      final text = r.text;
      expect(text, startsWith('#EXTM3U\n'));
      final c = server.catalog;
      final extinf = RegExp(
        r'^#EXTINF:-1 ',
        multiLine: true,
      ).allMatches(text).length;
      expect(extinf, c.channels.length + c.movies.length + c.episodeCount);
      expect(
        text,
        contains(
          'tvg-id="trt1.tr" tvg-name="TRT 1 HD" tvg-logo="$base/img/logo_00.png" group-title="TR | Ulusal",TRT 1 HD\n$base/live/carina/test123/1001.ts\n',
        ),
      );
      expect(text, contains('$base/movie/carina/test123/3001.mkv'));
      expect(text, contains('Sıcak Kafa S01 E02'));
      final hls = await fetch('$base/get.php?$account&type=m3u&output=m3u8');
      expect(
        hls.text,
        contains('#EXTINF:-1,TRT 1 HD\n$base/live/carina/test123/1001.m3u8'),
      );
      expect(
        (await fetch('$base/get.php?username=carina&password=x&type=m3u_plus'))
            .status,
        401,
      );
    });
  });
}
