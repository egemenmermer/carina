import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/sources/m3u/m3u.dart';

M3uEntry _single(String text) {
  final result = parseM3u(text);
  expect(result.entries, hasLength(1), reason: result.warnings.join('\n'));
  return result.entries.single;
}

void main() {
  group('#EXTGRP', () {
    test('is the group fallback', () {
      final e = _single('#EXTINF:-1,A\n#EXTGRP:Haber\nhttp://example.com/a.ts');
      expect(e.group, 'Haber');
    });

    test('loses against group-title', () {
      final e = _single(
        '#EXTGRP:Fallback\n#EXTINF:-1 group-title="Explicit",A\n'
        'http://example.com/a.ts',
      );
      expect(e.group, 'Explicit');
    });

    test('persists until the next #EXTGRP (an empty one clears it)', () {
      final r = parseM3u(
        '#EXTGRP:Spor\n'
        '#EXTINF:-1,A\nhttp://example.com/a.ts\n'
        '#EXTINF:-1,B\nhttp://example.com/b.ts\n'
        '#EXTGRP:Film\n'
        '#EXTINF:-1,C\nhttp://example.com/c.ts\n'
        '#EXTGRP:\n'
        '#EXTINF:-1,D\nhttp://example.com/d.ts\n',
      );
      expect(r.entries.map((e) => e.group), ['Spor', 'Spor', 'Film', null]);
    });

    test('semicolon-separated groups are split by groups', () {
      final e = _single(
        '#EXTINF:-1 group-title="News; Sports;;",A\nhttp://example.com/a.ts',
      );
      expect(e.group, 'News; Sports;;');
      expect(e.groups, ['News', 'Sports']);
    });
  });

  group('#EXTVLCOPT', () {
    test('http-user-agent sets the user agent header', () {
      final e = _single(
        '#EXTINF:-1,A\n#EXTVLCOPT:http-user-agent=Carina/1.0 (Test)\n'
        'http://example.com/a.ts',
      );
      expect(e.userAgent, 'Carina/1.0 (Test)');
      expect(e.headers, {'User-Agent': 'Carina/1.0 (Test)'});
    });

    test('http-referrer and http-referer both set Referer', () {
      final r = parseM3u(
        '#EXTINF:-1,A\n#EXTVLCOPT:http-referrer=http://ref.example.com/a\n'
        'http://example.com/a.ts\n'
        '#EXTINF:-1,B\n#EXTVLCOPT:http-referer=http://ref.example.com/b\n'
        'http://example.com/b.ts\n',
      );
      expect(r.entries.map((e) => e.referrer), [
        'http://ref.example.com/a',
        'http://ref.example.com/b',
      ]);
      expect(r.entries.first.headers, {'Referer': 'http://ref.example.com/a'});
    });

    test('http-origin, quoted values and unknown options', () {
      final e = _single(
        '#EXTINF:-1,A\n'
        '#EXTVLCOPT:http-origin=http://origin.example.com\n'
        '#EXTVLCOPT:http-user-agent="Quoted UA"\n'
        '#EXTVLCOPT:network-caching=1000\n'
        'http://example.com/a.ts',
      );
      expect(e.headers, {
        'Origin': 'http://origin.example.com',
        'User-Agent': 'Quoted UA',
      });
    });

    test('lines before #EXTINF apply to the next URL', () {
      final e = _single(
        '#EXTVLCOPT:http-user-agent=Before\n#EXTINF:-1,A\n'
        'http://example.com/a.ts',
      );
      expect(e.userAgent, 'Before');
    });

    test('options do not leak into the next entry', () {
      final r = parseM3u(
        '#EXTINF:-1,A\n#EXTVLCOPT:http-user-agent=Only A\n'
        '#KODIPROP:inputstream.adaptive.license_key=https://lic.example.com\n'
        'http://example.com/a.mpd\n'
        '#EXTINF:-1,B\nhttp://example.com/b.ts\n',
      );
      expect(r.entries[0].userAgent, 'Only A');
      expect(r.entries[0].unsupported, isTrue);
      expect(r.entries[1].userAgent, isNull);
      expect(r.entries[1].headers, isEmpty);
      expect(r.entries[1].unsupported, isFalse);
    });
  });

  group('#EXTHTTP', () {
    test('JSON headers are merged with canonical names', () {
      final e = _single(
        '#EXTINF:-1,A\n'
        '#EXTHTTP:{"user-agent":"JsonUA","Referer":"http://r.example.com",'
        '"cookie":"a=1; b=2","x-forwarded-for":"10.0.0.1","n":5}\n'
        'http://example.com/a.ts',
      );
      expect(e.userAgent, 'JsonUA');
      expect(e.referrer, 'http://r.example.com');
      expect(e.headers, {
        'User-Agent': 'JsonUA',
        'Referer': 'http://r.example.com',
        'Cookie': 'a=1; b=2',
        'X-Forwarded-For': '10.0.0.1',
        'N': '5',
      });
    });

    test('invalid JSON is ignored with a warning', () {
      final r = parseM3u(
        '#EXTM3U\n#EXTINF:-1,A\n#EXTHTTP:{"User-Agent": broken\n'
        'http://example.com/a.ts\n',
      );
      expect(r.entries.single.headers, isEmpty);
      expect(r.warnings.single, allOf(contains('Line 3'), contains('JSON')));
    });

    test('a JSON value that is not an object is ignored with a warning', () {
      final r = parseM3u(
        '#EXTM3U\n#EXTINF:-1,A\n#EXTHTTP:["User-Agent"]\nhttp://example.com/a\n',
      );
      expect(r.entries.single.headers, isEmpty);
      expect(r.warnings.single, contains('not a JSON object'));
    });
  });

  group('#KODIPROP', () {
    test('license_type marks the entry unsupported', () {
      final e = _single(
        '#KODIPROP:inputstream.adaptive.license_type=com.widevine.alpha\n'
        '#EXTINF:-1,Widevine\nhttp://example.com/w.mpd',
      );
      expect(e.unsupported, isTrue);
    });

    test('license_key marks the entry unsupported', () {
      final e = _single(
        '#EXTINF:-1,Keyed\n'
        '#KODIPROP:inputstream.adaptive.license_key=https://lic.example.com/k\n'
        'http://example.com/k.mpd',
      );
      expect(e.unsupported, isTrue);
    });

    test('the newer drm_legacy property marks the entry unsupported', () {
      final e = _single(
        '#EXTINF:-1,Legacy\n'
        '#KODIPROP:inputstream.adaptive.drm_legacy=org.w3.clearkey|0102:0304\n'
        'http://example.com/l.mpd',
      );
      expect(e.unsupported, isTrue);
    });

    test('other properties are ignored', () {
      final e = _single(
        '#EXTINF:-1,Plain\n'
        '#KODIPROP:inputstream=inputstream.adaptive\n'
        '#KODIPROP:inputstream.adaptive.manifest_type=hls\n'
        '#KODIPROP:inputstream.adaptive.license_key=\n'
        'http://example.com/p.m3u8',
      );
      expect(e.unsupported, isFalse);
      expect(e.headers, isEmpty);
    });
  });

  group('URL | header suffix', () {
    test('is moved to headers and URL-decoded', () {
      final e = _single(
        '#EXTINF:-1,Piped\n'
        'http://example.com/p.m3u8?token=1|User-Agent=Mozilla%2F5.0%20(X11)'
        '&Referer=http%3A%2F%2Fref.example.com%2F\n',
      );
      expect(e.url, 'http://example.com/p.m3u8?token=1');
      expect(e.userAgent, 'Mozilla/5.0 (X11)');
      expect(e.referrer, 'http://ref.example.com/');
    });

    test('keys are case-insensitive and Kodi player options are dropped', () {
      final e = _single(
        '#EXTINF:-1,Piped\n'
        'http://example.com/p.ts|user-agent=UA&referrer=http://r.example.com'
        '&seekable=0&X-Token=abc\n',
      );
      expect(e.url, 'http://example.com/p.ts');
      expect(e.headers, {
        'User-Agent': 'UA',
        'Referer': 'http://r.example.com',
        'X-Token': 'abc',
      });
    });

    test('a | without key=value pairs is part of the URL', () {
      final e = _single('#EXTINF:-1,Bar\nhttp://example.com/a|b.ts\n');
      expect(e.url, 'http://example.com/a|b.ts');
      expect(e.headers, isEmpty);
    });

    test('header precedence: pipe > option lines > attributes > header', () {
      final r = parseM3u(
        '#EXTM3U user-agent="HeaderUA"\n'
        '#EXTINF:-1 user-agent="AttrUA" http-referrer="http://attr.example.com",A\n'
        'http://example.com/a.ts\n'
        '#EXTINF:-1 user-agent="AttrUA",B\n'
        '#EXTVLCOPT:http-user-agent=OptUA\n'
        'http://example.com/b.ts\n'
        '#EXTINF:-1,C\n'
        '#EXTVLCOPT:http-user-agent=OptUA\n'
        '#EXTHTTP:{"User-Agent":"HttpUA"}\n'
        'http://example.com/c.ts|User-Agent=PipeUA\n'
        '#EXTINF:-1,D\nhttp://example.com/d.ts\n',
      );
      expect(r.entries.map((e) => e.userAgent), [
        'AttrUA',
        'OptUA',
        'PipeUA',
        'HeaderUA',
      ]);
      expect(r.entries.first.referrer, 'http://attr.example.com');
      expect(r.entries.last.headers, {'User-Agent': 'HeaderUA'});
    });
  });

  group('#EXTM3U header', () {
    test('reads EPG URLs from url-tvg, x-tvg-url and tvg-url', () {
      final r = parseM3u(
        '#EXTM3U url-tvg="http://epg.example.com/a.xml, http://epg.example.com/b.xml.gz" '
        'x-tvg-url="http://epg.example.com/b.xml.gz,http://epg.example.com/c.xml" '
        'tvg-url="http://epg.example.com/d.xml"\n',
      );
      expect(r.header.tvgUrls, [
        'http://epg.example.com/a.xml',
        'http://epg.example.com/b.xml.gz',
        'http://epg.example.com/c.xml',
        'http://epg.example.com/d.xml',
      ]);
    });

    test('keeps commas in unquoted header values', () {
      final r = parseM3u(
        '#EXTM3U x-tvg-url=http://epg.example.com/a.xml,http://epg.example.com/b.xml '
        'tvg-shift=2\n',
      );
      expect(r.header.tvgUrls, [
        'http://epg.example.com/a.xml',
        'http://epg.example.com/b.xml',
      ]);
      expect(r.header.tvgShift, 2);
    });

    test('reads tvg-shift, catch-up values and the user agent', () {
      final r = parseM3u(
        '#EXTM3U tvg-shift="-1.5" catchup="Shift" catchup-days="7" '
        'catchup-source="?utc={utc}" http-user-agent="HeaderUA" refresh="3600"\n',
      );
      final h = r.header;
      expect(h.tvgShift, -1.5);
      expect(h.catchup, 'shift');
      expect(h.catchupDays, 7);
      expect(h.catchupSource, '?utc={utc}');
      expect(h.userAgent, 'HeaderUA');
      expect(h.attrs['refresh'], '3600');
      expect(h.isEmpty, isFalse);
    });

    test('values are defaults for every entry; entry attributes win', () {
      final r = parseM3u(
        '#EXTM3U tvg-shift="2" catchup="default" catchup-days="5" '
        'catchup-source="http://archive.example.com/{utc}.ts"\n'
        '#EXTINF:-1 tvg-id="a",Defaults\nhttp://example.com/a.ts\n'
        '#EXTINF:-1 tvg-shift="-3" catchup="flussonic" catchup-days="2" '
        'catchup-source="http://other.example.com/{start}",Own\n'
        'http://example.com/b/index.m3u8\n',
      );
      final a = r.entries[0];
      expect(a.tvgShift, 2);
      expect(a.catchup, 'default');
      expect(a.catchupDays, 5);
      expect(a.catchupSource, 'http://archive.example.com/{utc}.ts');
      final b = r.entries[1];
      expect(b.tvgShift, -3);
      expect(b.catchup, 'flussonic');
      expect(b.catchupDays, 2);
      expect(b.catchupSource, 'http://other.example.com/{start}');
    });

    test('a later #EXTM3U line (concatenated playlists) merges', () {
      final r = parseM3u(
        '#EXTM3U url-tvg="http://epg.example.com/1.xml" catchup="shift"\n'
        '#EXTINF:-1,A\nhttp://example.com/a.ts\n'
        '#EXTM3U url-tvg="http://epg.example.com/2.xml" catchup="append" '
        'catchup-source="?t={utc}"\n'
        '#EXTINF:-1,B\nhttp://example.com/b.ts\n',
      );
      expect(r.header.tvgUrls, [
        'http://epg.example.com/1.xml',
        'http://epg.example.com/2.xml',
      ]);
      expect(r.entries[0].catchup, 'shift');
      expect(r.entries[0].catchupSource, isNull);
      expect(r.entries[1].catchup, 'append');
      expect(r.entries[1].catchupSource, '?t={utc}');
      expect(r.warnings.single, contains('another #EXTM3U'));
    });

    test('survives a JSON round trip', () {
      final r = parseM3u(
        '#EXTM3U url-tvg="http://epg.example.com/a.xml" tvg-shift="1" '
        'catchup="xc" catchup-days="3" user-agent="UA"\n',
      );
      final json = jsonDecode(jsonEncode(r.header.toJson()));
      final back = M3uHeader.fromJson(json as Map<String, Object?>);
      expect(back.tvgUrls, r.header.tvgUrls);
      expect(back.tvgShift, 1);
      expect(back.catchup, 'xc');
      expect(back.catchupDays, 3);
      expect(back.userAgent, 'UA');
      expect(back.attrs, r.header.attrs);
    });
  });

  group('catch-up attributes', () {
    test('catchup-type is an alias of catchup', () {
      final e = _single(
        '#EXTINF:-1 catchup-type="Flussonic",A\nhttp://example.com/a/index.m3u8',
      );
      expect(e.catchup, 'flussonic');
    });

    test('a source without a mode infers default', () {
      final e = _single(
        '#EXTINF:-1 catchup-source="http://archive.example.com/{utc}",A\n'
        'http://example.com/a.ts',
      );
      expect(e.catchup, 'default');
      expect(e.hasCatchup, isTrue);
    });

    test('SIPTV timeshift days infer shift', () {
      final e = _single('#EXTINF:-1 timeshift="4",A\nhttp://example.com/a.ts');
      expect(e.timeshift, 4);
      expect(e.catchupDays, 4);
      expect(e.catchup, 'shift');
    });

    test('tvg-rec days and plain catchup-days infer shift', () {
      final r = parseM3u(
        '#EXTINF:-1 tvg-rec="3",A\nhttp://example.com/a.ts\n'
        '#EXTINF:-1 catchup-days="6",B\nhttp://example.com/b.ts\n',
      );
      expect(r.entries.map((e) => e.catchupDays), [3, 6]);
      expect(r.entries.map((e) => e.catchup), ['shift', 'shift']);
    });

    test('catchup-days wins over timeshift, which wins over tvg-rec', () {
      final r = parseM3u(
        '#EXTM3U catchup-days="9"\n'
        '#EXTINF:-1 catchup-days="1" timeshift="2" tvg-rec="3",A\n'
        'http://example.com/a.ts\n'
        '#EXTINF:-1 timeshift="2" tvg-rec="3",B\nhttp://example.com/b.ts\n'
        '#EXTINF:-1 tvg-rec="3",C\nhttp://example.com/c.ts\n'
        '#EXTINF:-1,D\nhttp://example.com/d.ts\n',
      );
      expect(r.entries.map((e) => e.catchupDays), [1, 2, 3, 9]);
    });

    test('no catch-up information means no catch-up', () {
      final e = _single('#EXTINF:-1,A\nhttp://example.com/a.ts');
      expect(e.catchup, isNull);
      expect(e.catchupDays, isNull);
      expect(e.hasCatchup, isFalse);
    });

    test('catchup="none" switches catch-up off', () {
      final e = _single(
        '#EXTINF:-1 catchup="none" catchup-source="?utc={utc}",A\n'
        'http://example.com/a.ts',
      );
      expect(e.catchup, isNull);
    });

    test('tvg-shift accepts fractions, signs and decimal commas', () {
      final r = parseM3u(
        '#EXTINF:-1 tvg-shift="+3",A\nhttp://example.com/a.ts\n'
        '#EXTINF:-1 tvg-shift="-0.5",B\nhttp://example.com/b.ts\n'
        '#EXTINF:-1 tvg-shift="1,5",C\nhttp://example.com/c.ts\n'
        '#EXTINF:-1 tvg-shift="abc",D\nhttp://example.com/d.ts\n',
      );
      expect(r.entries.map((e) => e.tvgShift), [3, -0.5, 1.5, null]);
    });
  });
}
