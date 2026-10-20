import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/sources/catchup/catchup.dart';

// Programme 18:00–19:30 UTC on 2026-10-17, watched at 21:00 UTC.
final DateTime _start = DateTime.utc(2026, 10, 17, 18);
final DateTime _end = DateTime.utc(2026, 10, 17, 19, 30);
final DateTime _now = DateTime.utc(2026, 10, 17, 21);
const String _s = '1792260000';
const String _n = '1792270800';
const Duration _plus3 = Duration(hours: 3);

String? _build(
  String streamUrl,
  String mode, {
  String? source,
  DateTime? end,
  Duration serverOffset = Duration.zero,
  String? channelName,
}) => buildCatchupUrl(
  streamUrl: streamUrl,
  mode: mode,
  source: source,
  startUtc: _start,
  endUtc: end ?? _end,
  nowUtc: _now,
  channelName: channelName,
  serverOffset: serverOffset,
);

void main() {
  group('default mode', () {
    test('uses catchup-source as the full template', () {
      expect(
        _build(
          'http://example.com/live/1.m3u8',
          'default',
          source:
              'http://archive.example.com/1/{Y}/{m}/{d}/{H}{M}.m3u8'
              '?from={utc}&len={duration}',
        ),
        'http://archive.example.com/1/2026/10/17/1800.m3u8'
        '?from=$_s&len=5400',
      );
    });

    test('appends a query-only source to the stream URL', () {
      expect(
        _build('http://example.com/1.ts', 'default', source: '?utc={utc}'),
        'http://example.com/1.ts?utc=$_s',
      );
      expect(
        _build('http://example.com/1.ts?t=a', 'default', source: '?utc={utc}'),
        'http://example.com/1.ts?t=a&utc=$_s',
      );
      expect(
        _build('http://example.com/1.ts?t=a', 'default', source: '&utc={utc}'),
        'http://example.com/1.ts?t=a&utc=$_s',
      );
    });

    test('resolves path sources against the stream URL', () {
      const stream = 'http://example.com:8080/ch/7/index.m3u8?token=x';
      expect(
        _build(stream, 'default', source: '/archive/{utc}.ts'),
        'http://example.com:8080/archive/$_s.ts',
      );
      expect(
        _build(stream, 'default', source: 'index-{utc}.m3u8'),
        'http://example.com:8080/ch/7/index-$_s.m3u8',
      );
      expect(
        _build(stream, 'default', source: '//cdn.example.com/{utc}'),
        'http://cdn.example.com/$_s',
      );
    });

    test('needs a source', () {
      expect(_build('http://example.com/1.ts', 'default'), isNull);
      expect(
        _build('http://example.com/1.ts', 'default', source: '  '),
        isNull,
      );
    });
  });

  group('append mode', () {
    test('appends the source to the stream URL', () {
      expect(
        _build(
          'http://example.com/live/1.m3u8',
          'append',
          source: '?start={utc}&end={utcend}',
        ),
        'http://example.com/live/1.m3u8?start=$_s&end=1792265400',
      );
      expect(
        _build('http://example.com/ch1', 'append', source: '/{utc}-{duration}'),
        'http://example.com/ch1/$_s-5400',
      );
    });

    test('joins with & when the stream URL already has a query', () {
      expect(
        _build('http://example.com/1.ts?t=a', 'append', source: '?utc={utc}'),
        'http://example.com/1.ts?t=a&utc=$_s',
      );
    });

    test('needs a source', () {
      expect(_build('http://example.com/1.ts', 'append'), isNull);
    });
  });

  group('shift / timeshift mode', () {
    test('shift appends ?utc={utc}&lutc={lutc}', () {
      expect(
        _build('http://example.com/live/1.ts', 'shift'),
        'http://example.com/live/1.ts?utc=$_s&lutc=$_n',
      );
    });

    test('shift uses & when the stream URL has a query', () {
      expect(
        _build('http://example.com/live/1.m3u8?token=abc', 'shift'),
        'http://example.com/live/1.m3u8?token=abc&utc=$_s&lutc=$_n',
      );
    });

    test('timeshift is an alias of shift', () {
      expect(
        _build('http://example.com/live/1.ts', 'timeshift'),
        'http://example.com/live/1.ts?utc=$_s&lutc=$_n',
      );
    });
  });

  group('flussonic mode', () {
    test('index.m3u8 becomes index-{utc}-{duration}.m3u8', () {
      expect(
        _build('http://fs.example.com:8888/ch325/index.m3u8', 'flussonic'),
        'http://fs.example.com:8888/ch325/index-$_s-5400.m3u8',
      );
    });

    test('mono.m3u8 keeps its playlist name', () {
      expect(
        _build(
          'http://fs.example.com/ch325/mono.m3u8?token=secret',
          'flussonic',
        ),
        'http://fs.example.com/ch325/mono-$_s-5400.m3u8?token=secret',
      );
    });

    test('mpegts becomes timeshift_abs-{utc}.ts', () {
      expect(
        _build('http://fs.example.com/ch325/mpegts?token=secret', 'flussonic'),
        'http://fs.example.com/ch325/timeshift_abs-$_s.ts?token=secret',
      );
    });

    test('a .ts URL becomes timeshift_abs-{utc}.ts', () {
      expect(
        _build('https://fs.example.com/a/b/live.ts', 'flussonic'),
        'https://fs.example.com/a/b/timeshift_abs-$_s.ts',
      );
    });

    test('fs, flussonic-hls and flussonic-ts follow the URL type', () {
      const hls = 'http://fs.example.com/ch/index.m3u8';
      const ts = 'http://fs.example.com/ch/mpegts';
      for (final mode in ['fs', 'flussonic-hls', 'flussonic-ts', 'FS']) {
        expect(
          _build(hls, mode),
          'http://fs.example.com/ch/index-$_s-5400.m3u8',
          reason: mode,
        );
        expect(
          _build(ts, mode),
          'http://fs.example.com/ch/timeshift_abs-$_s.ts',
          reason: mode,
        );
      }
    });

    test('other URLs use the mode: -ts and fs give TS, others HLS', () {
      const live = 'http://fs.example.com/ch/live?token=t';
      expect(
        _build(live, 'flussonic-ts'),
        'http://fs.example.com/ch/timeshift_abs-$_s.ts?token=t',
      );
      expect(_build(live, 'fs'), _build(live, 'flussonic-ts'));
      expect(
        _build(live, 'flussonic'),
        'http://fs.example.com/ch/index-$_s-5400.m3u8?token=t',
      );
      expect(_build(live, 'flussonic-hls'), _build(live, 'flussonic'));
    });

    test('needs a channel path segment and an absolute URL', () {
      expect(_build('http://fs.example.com/index.m3u8', 'flussonic'), isNull);
      expect(_build('http://fs.example.com', 'flussonic'), isNull);
      expect(_build('ch/index.m3u8', 'flussonic'), isNull);
    });
  });

  group('xc mode', () {
    test('builds the Xtream timeshift URL from a live URL', () {
      expect(
        _build('http://example.com:8080/live/kanal/test123/1001.ts', 'xc'),
        'http://example.com:8080/timeshift/kanal/test123/90/'
        '2026-10-17:18-00/1001.ts',
      );
    });

    test('accepts URLs without live/ and without an extension', () {
      expect(
        _build('http://example.com:8080/kanal/test123/1001', 'xc'),
        'http://example.com:8080/timeshift/kanal/test123/90/'
        '2026-10-17:18-00/1001.ts',
      );
    });

    test('always requests .ts , also for .m3u8 streams', () {
      expect(
        _build('https://example.com/live/kanal/test123/1001.m3u8', 'xc'),
        'https://example.com/timeshift/kanal/test123/90/'
        '2026-10-17:18-00/1001.ts',
      );
    });

    test('writes the start in server time (serverOffset +3h)', () {
      expect(
        _build(
          'http://example.com:8080/live/kanal/test123/1001.ts',
          'xc',
          serverOffset: _plus3,
        ),
        'http://example.com:8080/timeshift/kanal/test123/90/'
        '2026-10-17:21-00/1001.ts',
      );
    });

    test('rounds the duration up to whole minutes', () {
      expect(
        _build(
          'http://example.com/live/kanal/test123/1001.ts',
          'xc',
          end: _start.add(const Duration(minutes: 44, seconds: 1)),
        ),
        'http://example.com/timeshift/kanal/test123/45/'
        '2026-10-17:18-00/1001.ts',
      );
    });

    test('returns null for non-Xtream, movie and series URLs', () {
      expect(_build('http://example.com/stream.m3u8', 'xc'), isNull);
      expect(_build('http://example.com/movie/u/p/3001.mkv', 'xc'), isNull);
      expect(_build('http://example.com/series/u/p/9001.mkv', 'xc'), isNull);
    });
  });

  group('modes in general', () {
    test('an empty mode with a source means default', () {
      expect(
        _build(
          'http://example.com/1.ts',
          '',
          source: 'http://a.example.com/{utc}',
        ),
        'http://a.example.com/$_s',
      );
      expect(_build('http://example.com/1.ts', ''), isNull);
    });

    test('unknown modes return null', () {
      expect(
        _build('http://example.com/1.ts', 'vod', source: '{catchup-id}'),
        isNull,
      );
      expect(_build('http://example.com/1.ts', 'rewind'), isNull);
    });

    test('modes ignore case and surrounding spaces', () {
      expect(
        _build('http://example.com/1.ts', ' Shift '),
        'http://example.com/1.ts?utc=$_s&lutc=$_n',
      );
      expect(catchupModes, contains('flussonic-ts'));
    });

    test('Kodi |options of the stream URL are kept at the end', () {
      expect(
        _build('http://example.com/1.ts|User-Agent=Kanal', 'shift'),
        'http://example.com/1.ts?utc=$_s&lutc=$_n|User-Agent=Kanal',
      );
      expect(
        _build(
          'http://example.com/1.ts|User-Agent=Kanal',
          'default',
          source: 'http://a.example.com/{utc}|Referer=http://r.example.com',
        ),
        'http://a.example.com/$_s|Referer=http://r.example.com',
      );
    });

    test('passes the channel name and now to the template', () {
      expect(
        _build(
          'http://example.com/1.ts',
          'append',
          source: '?ch={channel}&now={now}&off={offset:60}',
          channelName: 'Show TV',
        ),
        'http://example.com/1.ts?ch=Show%20TV&now=$_n&off=180',
      );
    });
  });

  group('isReplayable', () {
    bool replay(DateTime start, DateTime end, {int days = 3, DateTime? now}) =>
        isReplayable(
          startUtc: start,
          endUtc: end,
          archiveDays: days,
          nowUtc: now ?? _now,
        );

    test('a finished programme inside the window is replayable', () {
      expect(replay(_start, _end), isTrue);
      expect(
        replay(
          _now.subtract(const Duration(days: 2, hours: 23)),
          _now.subtract(const Duration(days: 2, hours: 22)),
        ),
        isTrue,
      );
    });

    test('a programme that is on air or in the future is not', () {
      expect(
        replay(
          _now.subtract(const Duration(minutes: 10)),
          _now.add(const Duration(minutes: 20)),
        ),
        isFalse,
      );
      expect(
        replay(
          _now.add(const Duration(hours: 1)),
          _now.add(const Duration(hours: 2)),
        ),
        isFalse,
      );
    });

    test('a programme older than the archive window is not', () {
      expect(
        replay(
          _now.subtract(const Duration(days: 3, hours: 1)),
          _now.subtract(const Duration(days: 3)),
        ),
        isFalse,
      );
    });

    test('the bounds are strict (end < now, start > now - days)', () {
      expect(replay(_start, _now), isFalse);
      expect(replay(_now.subtract(const Duration(days: 3)), _end), isFalse);
      expect(
        replay(
          _now
              .subtract(const Duration(days: 3))
              .add(const Duration(seconds: 1)),
          _end,
        ),
        isTrue,
      );
    });

    test('no archive means nothing is replayable', () {
      expect(replay(_start, _end, days: 0), isFalse);
      expect(replay(_start, _end, days: -1), isFalse);
    });

    test('nowUtc defaults to the current time', () {
      final now = DateTime.now().toUtc();
      expect(
        isReplayable(
          startUtc: now.subtract(const Duration(hours: 2)),
          endUtc: now.subtract(const Duration(hours: 1)),
          archiveDays: 1,
        ),
        isTrue,
      );
    });
  });
}
