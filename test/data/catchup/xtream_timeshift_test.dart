import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/sources/catchup/catchup.dart';

final DateTime _start = DateTime.utc(2026, 10, 17, 18);
const Duration _plus3 = Duration(hours: 3);

void main() {
  group('formatXtreamTimeshiftStart', () {
    test('formats YYYY-MM-DD:HH-MM in UTC by default', () {
      expect(formatXtreamTimeshiftStart(_start), '2026-10-17:18-00');
      expect(
        formatXtreamTimeshiftStart(DateTime.utc(2026, 3, 5, 7, 8, 59)),
        '2026-03-05:07-08',
      );
    });

    test('applies the server offset', () {
      expect(formatXtreamTimeshiftStart(_start, _plus3), '2026-10-17:21-00');
      expect(
        formatXtreamTimeshiftStart(DateTime.utc(2026, 12, 31, 22, 15), _plus3),
        '2027-01-01:01-15',
      );
      expect(
        formatXtreamTimeshiftStart(
          DateTime.utc(2026, 10, 17, 2, 30),
          const Duration(hours: -5),
        ),
        '2026-10-16:21-30',
      );
    });
  });

  group('xtreamTimeshiftMinutes', () {
    test('rounds up to whole minutes and never goes negative', () {
      final end = _start.add(const Duration(minutes: 90));
      expect(xtreamTimeshiftMinutes(_start, end), 90);
      expect(
        xtreamTimeshiftMinutes(_start, end.add(const Duration(seconds: 30))),
        91,
      );
      expect(
        xtreamTimeshiftMinutes(_start, _start.add(const Duration(seconds: 59))),
        1,
      );
      expect(xtreamTimeshiftMinutes(_start, _start), 0);
      expect(
        xtreamTimeshiftMinutes(
          _start,
          _start.subtract(const Duration(hours: 1)),
        ),
        0,
      );
    });
  });

  group('xtreamTimeshiftUrl', () {
    test('builds the primary URL ', () {
      expect(
        xtreamTimeshiftUrl(
          server: 'http://example.com:8080',
          username: 'kanal',
          password: 'test123',
          streamId: 1001,
          startUtc: _start,
          durationMinutes: 90,
        ),
        'http://example.com:8080/timeshift/kanal/test123/90/'
        '2026-10-17:18-00/1001.ts',
      );
    });

    test('uses server time with serverOffset +3h', () {
      expect(
        xtreamTimeshiftUrl(
          server: 'http://example.com:8080',
          username: 'kanal',
          password: 'test123',
          streamId: '1001',
          startUtc: _start,
          durationMinutes: 60,
          serverOffset: _plus3,
        ),
        'http://example.com:8080/timeshift/kanal/test123/60/'
        '2026-10-17:21-00/1001.ts',
      );
    });

    test('tolerates a trailing slash on the server', () {
      expect(
        xtreamTimeshiftUrl(
          server: 'https://example.com/',
          username: 'kanal',
          password: 'test123',
          streamId: 7,
          startUtc: _start,
          durationMinutes: 30,
        ),
        'https://example.com/timeshift/kanal/test123/30/2026-10-17:18-00/7.ts',
      );
    });

    test('percent-encodes credentials only where needed', () {
      expect(
        xtreamTimeshiftUrl(
          server: 'http://example.com',
          username: 'me@mail.com',
          password: 'p/a ss#?%şifre',
          streamId: 1,
          startUtc: _start,
          durationMinutes: 5,
        ),
        'http://example.com/timeshift/me@mail.com/p%2Fa%20ss%23%3F%25%C5%9Fifre'
        '/5/2026-10-17:18-00/1.ts',
      );
    });
  });

  group('xtreamTimeshiftFallbackUrl', () {
    test('builds the timeshift.php URL ', () {
      expect(
        xtreamTimeshiftFallbackUrl(
          server: 'http://example.com:8080',
          username: 'kanal',
          password: 'test123',
          streamId: 1001,
          startUtc: _start,
          durationMinutes: 90,
        ),
        'http://example.com:8080/streaming/timeshift.php?username=kanal'
        '&password=test123&stream=1001&start=2026-10-17:18-00&duration=90',
      );
    });

    test('uses server time and encodes query values', () {
      expect(
        xtreamTimeshiftFallbackUrl(
          server: 'http://example.com:8080/',
          username: 'a&b',
          password: 'c=d+e f',
          streamId: '1001',
          startUtc: _start,
          durationMinutes: 45,
          serverOffset: _plus3,
        ),
        'http://example.com:8080/streaming/timeshift.php?username=a%26b'
        '&password=c%3Dd%2Be%20f&stream=1001&start=2026-10-17:21-00'
        '&duration=45',
      );
    });
  });

  group('parseXtreamStreamUrl', () {
    test('reads live URLs with and without live/ and an extension', () {
      final a = parseXtreamStreamUrl(
        'http://example.com:8080/live/kanal/test123/1001.ts',
      )!;
      expect(a.server, 'http://example.com:8080');
      expect(a.username, 'kanal');
      expect(a.password, 'test123');
      expect(a.streamId, '1001');
      expect(a.extension, 'ts');
      final b = parseXtreamStreamUrl('https://example.com/kanal/test123/1001')!;
      expect(b.server, 'https://example.com');
      expect(b.streamId, '1001');
      expect(b.extension, isNull);
    });

    test('keeps a path prefix and ignores query, fragment and | options', () {
      final p = parseXtreamStreamUrl(
        'http://example.com/panel/live/kanal/test123/5.m3u8?x=1#f|User-Agent=A',
      )!;
      expect(p.server, 'http://example.com/panel');
      expect(p.streamId, '5');
      expect(p.extension, 'm3u8');
    });

    test('decodes percent-encoded credentials', () {
      final p = parseXtreamStreamUrl(
        'http://example.com/live/me%40mail.com/p%2Fw/9.ts',
      )!;
      expect(p.username, 'me@mail.com');
      expect(p.password, 'p/w');
    });

    test('rejects other shapes', () {
      expect(parseXtreamStreamUrl('http://example.com/live/1001.ts'), isNull);
      expect(
        parseXtreamStreamUrl('http://example.com/movie/u/p/1.mkv'),
        isNull,
      );
      expect(
        parseXtreamStreamUrl('http://example.com/series/u/p/1.mp4'),
        isNull,
      );
      expect(parseXtreamStreamUrl('rtmp://example.com/u/p/1'), isNull);
      expect(parseXtreamStreamUrl('http:///u/p/1'), isNull);
      expect(parseXtreamStreamUrl('u/p/1.ts'), isNull);
      expect(parseXtreamStreamUrl('http://example.com/u/p/.ts'), isNull);
    });

    test('toString does not print the credentials', () {
      final p = parseXtreamStreamUrl(
        'http://example.com/live/kanal/test123/1001.ts',
      )!;
      expect(p.toString(), isNot(contains('test123')));
      expect(p.toString(), isNot(contains('kanal')));
    });
  });
}
