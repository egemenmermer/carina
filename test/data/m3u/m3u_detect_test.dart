import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/sources/m3u/m3u.dart';

void main() {
  group('detectXtreamExport', () {
    test('reads server, credentials, type and output', () {
      final info = detectXtreamExport(
        'http://example.com:8080/get.php?username=kanal&password=test123'
        '&type=m3u_plus&output=ts',
      )!;
      expect(info.server, 'http://example.com:8080');
      expect(info.username, 'kanal');
      expect(info.password, 'test123');
      expect(info.type, 'm3u_plus');
      expect(info.output, 'ts');
    });

    test('keeps https, drops default ports and keeps path prefixes', () {
      final a = detectXtreamExport(
        'https://example.com/get.php?username=kanal&password=test123',
      )!;
      expect(a.server, 'https://example.com');
      expect(a.type, isNull);
      final b = detectXtreamExport(
        'http://example.com:80/panel/get.php?password=test123&username=kanal',
      )!;
      expect(b.server, 'http://example.com/panel');
      final c = detectXtreamExport(
        'HTTP://Example.com:25461/GET.PHP?USERNAME=kanal&Password=test123',
      )!;
      expect(c.server, 'http://example.com:25461');
      expect(c.username, 'kanal');
    });

    test('decodes percent-encoded credentials', () {
      final info = detectXtreamExport(
        'http://example.com/get.php?username=me%40mail.com&password=a%26b%3Dc',
      )!;
      expect(info.username, 'me@mail.com');
      expect(info.password, 'a&b=c');
    });

    test('supports IPv6 hosts', () {
      final info = detectXtreamExport(
        'http://[2001:db8::1]:8080/get.php?username=kanal&password=test123',
      )!;
      expect(info.server, 'http://[2001:db8::1]:8080');
    });

    test('returns null without both credentials', () {
      expect(
        detectXtreamExport('http://example.com/get.php?username=kanal'),
        isNull,
      );
      expect(
        detectXtreamExport(
          'http://example.com/get.php?username=kanal&password=',
        ),
        isNull,
      );
    });

    test('returns null for other URLs and garbage', () {
      expect(
        detectXtreamExport(
          'http://example.com/playlist.m3u?username=kanal&password=test123',
        ),
        isNull,
      );
      expect(
        detectXtreamExport(
          'ftp://example.com/get.php?username=kanal&password=test123',
        ),
        isNull,
      );
      expect(detectXtreamExport('not a url'), isNull);
      expect(detectXtreamExport(''), isNull);
    });

    test('keeps malformed percent escapes literally', () {
      final info = detectXtreamExport(
        'http://example.com/get.php?username=%zz&password=x',
      )!;
      expect(info.username, '%zz');
    });

    test('toString does not print the credentials or the server', () {
      final info = detectXtreamExport(
        'http://example.com/get.php?username=kanal&password=test123',
      )!;
      expect(info.toString(), isNot(contains('test123')));
      expect(info.toString(), isNot(contains('kanal')));
      expect(info.toString(), isNot(contains('example.com')));
    });
  });

  group('looksLikeM3u', () {
    test('accepts #EXTM3U in any case, after a BOM or whitespace', () {
      expect(looksLikeM3u('#EXTM3U\n#EXTINF:-1,A\nhttp://x/a.ts'), isTrue);
      expect(looksLikeM3u('#extm3u'), isTrue);
      expect(looksLikeM3u('${String.fromCharCode(0xFEFF)}#EXTM3U'), isTrue);
      expect(
        looksLikeM3u('${String.fromCharCodes([0xEF, 0xBB, 0xBF])}#EXTM3U'),
        isTrue,
      );
      expect(looksLikeM3u('\r\n\n   #EXTM3U x-tvg-url="a"'), isTrue);
    });

    test('accepts playlists without a header', () {
      expect(looksLikeM3u('#EXTINF:-1,A\nhttp://x/a.ts'), isTrue);
      expect(
        looksLikeM3u('#EXTVLCOPT:http-user-agent=A\n#EXTINF:-1,A\nhttp://x/a'),
        isTrue,
      );
      expect(looksLikeM3u('http://example.com/a.ts\nhttp://x/b.ts'), isTrue);
      expect(looksLikeM3u('udp://@239.0.0.1:1234'), isTrue);
      expect(
        looksLikeM3u('http://example.com/a.ts|User-Agent=Mozilla/5.0 (X11)'),
        isTrue,
      );
    });

    test('rejects HTML, XML and JSON', () {
      expect(
        looksLikeM3u('<!DOCTYPE html><html><body>403</body></html>'),
        isFalse,
      );
      expect(looksLikeM3u('  <html>'), isFalse);
      expect(looksLikeM3u('<?xml version="1.0"?><tv></tv>'), isFalse);
      expect(looksLikeM3u('{"user_info":{"auth":0}}'), isFalse);
      expect(looksLikeM3u('[1, 2, 3]'), isFalse);
    });

    test('rejects empty input, comments only and random text', () {
      expect(looksLikeM3u(''), isFalse);
      expect(looksLikeM3u('   \n\n'), isFalse);
      expect(looksLikeM3u('# just a comment\n# another'), isFalse);
      expect(looksLikeM3u('Account expired, contact the reseller'), isFalse);
      expect(looksLikeM3u('http://example.com is down'), isFalse);
      expect(looksLikeM3u('Bad Request'), isFalse);
    });
  });

  group('m3uEntryId', () {
    M3uEntry entry(String text) => parseM3u(text).entries.single;

    test('is 16 lower-case hex characters and stable across parses', () {
      const text =
          '#EXTINF:-1 tvg-id="trt1.tr",TRT 1\nhttp://example.com/1001.ts';
      final id = m3uEntryId(entry(text));
      expect(id, matches(RegExp(r'^[0-9a-f]{16}$')));
      expect(m3uEntryId(entry(text)), id);
    });

    test('ignores name, group and the | header suffix', () {
      final a = entry(
        '#EXTINF:-1 tvg-id="x" group-title="A",Old Name\n'
        'http://example.com/1.ts',
      );
      final b = entry(
        '#EXTINF:-1 tvg-id="x" group-title="B",New Name\n'
        'http://example.com/1.ts|User-Agent=Other',
      );
      expect(m3uEntryId(a), m3uEntryId(b));
    });

    test('changes with the tvg-id or the URL', () {
      final base = entry('#EXTINF:-1 tvg-id="x",A\nhttp://example.com/1.ts');
      final otherId = entry('#EXTINF:-1 tvg-id="y",A\nhttp://example.com/1.ts');
      final otherUrl = entry(
        '#EXTINF:-1 tvg-id="x",A\nhttp://example.com/2.ts',
      );
      final noId = entry('#EXTINF:-1,A\nhttp://example.com/1.ts');
      final ids = {
        m3uEntryId(base),
        m3uEntryId(otherId),
        m3uEntryId(otherUrl),
        m3uEntryId(noId),
      };
      expect(ids, hasLength(4));
    });

    test('matches sha1("tvg-id|url")', () {
      // sha1("|http://example.com/a.ts") computed independently.
      final e = entry('#EXTINF:-1,A\nhttp://example.com/a.ts');
      expect(m3uEntryId(e), _sha1Prefix);
    });
  });
}

// First 16 hex characters of sha1('|http://example.com/a.ts').
const String _sha1Prefix = '6d3afe34af0e1232';
