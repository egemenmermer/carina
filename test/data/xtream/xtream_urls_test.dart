import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/sources/xtream/xtream_credentials.dart';
import 'package:carina/data/sources/xtream/xtream_urls.dart';

void main() {
  final urls = XtreamUrls('http://domain.com:8080', 'kanal', 'test123');

  group('stream URLs', () {
    test('live, movie, episode', () {
      expect(
        urls.live(1001),
        'http://domain.com:8080/live/kanal/test123/1001.ts',
      );
      expect(
        urls.live('1001', ext: 'm3u8'),
        'http://domain.com:8080/live/kanal/test123/1001.m3u8',
      );
      expect(
        urls.movie(3001, 'mkv'),
        'http://domain.com:8080/movie/kanal/test123/3001.mkv',
      );
      expect(
        urls.episode('77001', 'mp4'),
        'http://domain.com:8080/series/kanal/test123/77001.mp4',
      );
    });

    test('extension cleanup and defaults', () {
      expect(urls.movie(1, '.mkv'), endsWith('/1.mkv'));
      expect(urls.movie(1, ' '), endsWith('/1.mp4'));
      expect(urls.episode(1, ''), endsWith('/1.mp4'));
      expect(urls.live(1, ext: '.ts'), endsWith('/1.ts'));
      expect(urls.live(1, ext: ''), endsWith('/1.ts'));
    });

    test('trailing slashes and whitespace on the server are ignored', () {
      final u = XtreamUrls(' https://domain.com:8443/// ', 'a b', 'c');
      expect(u.server, 'https://domain.com:8443');
      expect(u.live(5), 'https://domain.com:8443/live/a%20b/c/5.ts');
    });

    test('a server base path is kept', () {
      final u = XtreamUrls('http://domain.com/panel', 'u', 'p');
      expect(u.live(5), 'http://domain.com/panel/live/u/p/5.ts');
    });

    test('a usable direct_source wins', () {
      const direct = 'http://origin.example.com/stream/abc.m3u8';
      expect(urls.live(1, directSource: direct), direct);
      expect(urls.live(1, directSource: '  $direct  '), direct);
      expect(urls.movie(1, 'mp4', directSource: 'rtmp://x/y'), 'rtmp://x/y');
      expect(urls.episode(1, 'mp4', directSource: direct), direct);
      for (final junk in ['', ' ', '0', 'null', '/relative/path.ts']) {
        expect(
          urls.live(1, directSource: junk),
          endsWith('/live/kanal/test123/1.ts'),
        );
      }
      expect(urls.live(1, directSource: null), endsWith('/1.ts'));
    });

    test('special characters in credentials are encoded and round-trip', () {
      const user = 'user@mail.com';
      const pass = 'p@ss/w rd&?#+%ş';
      final u = XtreamUrls('http://domain.com:8080', user, pass);
      final live = u.live(1001);
      expect(
        live,
        'http://domain.com:8080/live/user%40mail.com/'
        'p%40ss%2Fw%20rd%26%3F%23%2B%25%C5%9F/1001.ts',
      );
      final segments = Uri.parse(live).pathSegments;
      expect(segments, ['live', user, pass, '1001.ts']);

      final ts = Uri.parse(
        u.timeshift(1001, DateTime.utc(2026, 10, 17, 18), 60),
      );
      expect(ts.pathSegments[1], user);
      expect(ts.pathSegments[2], pass);

      final fallback = Uri.parse(
        u.timeshiftFallback(1001, DateTime.utc(2026, 10, 17, 18), 60),
      );
      expect(fallback.queryParameters['username'], user);
      expect(fallback.queryParameters['password'], pass);

      final xmltv = u.xmltvUri();
      expect(xmltv.queryParameters['username'], user);
      expect(xmltv.queryParameters['password'], pass);

      final api = u.playerApiUri({'action': 'get_vod_info', 'vod_id': '3 1'});
      expect(api.queryParameters['password'], pass);
      expect(api.queryParameters['vod_id'], '3 1');
    });
  });

  group('timeshift', () {
    final start = DateTime.utc(2026, 10, 17, 18, 5);

    test('primary URL in server local time', () {
      expect(
        urls.timeshift(1001, start, 60, serverOffset: const Duration(hours: 3)),
        'http://domain.com:8080/timeshift/kanal/test123/60/2026-10-17:21-05/1001.ts',
      );
      expect(
        urls.timeshift(1001, start, 90),
        'http://domain.com:8080/timeshift/kanal/test123/90/2026-10-17:18-05/1001.ts',
      );
    });

    test('offset crossing midnight and negative offsets', () {
      final late = DateTime.utc(2026, 12, 31, 23, 30);
      expect(
        urls.timeshift(7, late, 30, serverOffset: const Duration(hours: 3)),
        endsWith('/30/2027-01-01:02-30/7.ts'),
      );
      expect(
        urls.timeshift(
          7,
          DateTime.utc(2026, 1, 1, 2, 0),
          30,
          serverOffset: const Duration(hours: -5),
        ),
        endsWith('/30/2025-12-31:21-00/7.ts'),
      );
      expect(
        urls.timeshift(
          7,
          DateTime.utc(2026, 3, 4, 1, 2),
          30,
          serverOffset: const Duration(hours: 5, minutes: 30),
        ),
        endsWith('/2026-03-04:06-32/7.ts'),
      );
    });

    test('a local DateTime is converted to UTC first', () {
      final local = DateTime.utc(2026, 10, 17, 18, 5).toLocal();
      expect(urls.timeshift(1, local, 60), endsWith('/2026-10-17:18-05/1.ts'));
    });

    test('duration is at least one minute', () {
      expect(urls.timeshift(1, start, 0), contains('/test123/1/'));
      expect(urls.timeshift(1, start, -10), contains('/test123/1/'));
    });

    test('fallback URL', () {
      expect(
        urls.timeshiftFallback(
          1001,
          start,
          60,
          serverOffset: const Duration(hours: 3),
        ),
        'http://domain.com:8080/streaming/timeshift.php?username=kanal'
        '&password=test123&stream=1001&start=2026-10-17:21-05&duration=60',
      );
    });

    test('formatXtreamTimeshiftStart pads fields', () {
      expect(
        formatXtreamTimeshiftStart(
          DateTime.utc(2026, 1, 2, 3, 4),
          Duration.zero,
        ),
        '2026-01-02:03-04',
      );
    });
  });

  test('xmltv and player_api', () {
    expect(
      urls.xmltv(),
      'http://domain.com:8080/xmltv.php?username=kanal&password=test123',
    );
    expect(urls.xmltvUri().path, '/xmltv.php');
    expect(
      urls.playerApiUri().toString(),
      'http://domain.com:8080/player_api.php?username=kanal&password=test123',
    );
    expect(
      urls.playerApiUri({
        'action': 'get_live_streams',
        'category_id': '5',
      }).toString(),
      'http://domain.com:8080/player_api.php?username=kanal&password=test123'
      '&action=get_live_streams&category_id=5',
    );
  });

  test('fromCredentials', () {
    final u = XtreamUrls.fromCredentials(
      const XtreamCredentials('http://h:1/', 'u', 'p'),
    );
    expect(u.live(1), 'http://h:1/live/u/p/1.ts');
  });

  test('credentials never print the password', () {
    const c = XtreamCredentials('http://domain.com:8080', 'kanal', 'test123');
    expect(c.toString(), isNot(contains('test123')));
    expect(c.toString(), isNot(contains('kanal')));
    expect(c.baseUrl, 'http://domain.com:8080');
    expect(
      c,
      const XtreamCredentials('http://domain.com:8080', 'kanal', 'test123'),
    );
  });

  group('pickLiveExt', () {
    test('uses the preference when allowed or unknown', () {
      expect(pickLiveExt(['m3u8', 'ts', 'rtmp']), 'ts');
      expect(pickLiveExt(['m3u8', 'ts'], preferred: 'm3u8'), 'm3u8');
      expect(pickLiveExt([]), 'ts');
      expect(pickLiveExt([], preferred: 'm3u8'), 'm3u8');
      expect(pickLiveExt(['rtmp']), 'ts');
    });

    test('falls back to an allowed format', () {
      expect(pickLiveExt(['m3u8']), 'm3u8');
      expect(pickLiveExt(['m3u8', 'rtmp']), 'm3u8');
      expect(pickLiveExt(['ts'], preferred: 'm3u8'), 'ts');
      expect(pickLiveExt(['TS', ' M3U8 '], preferred: '.M3U8'), 'm3u8');
      expect(pickLiveExt(['hls'], preferred: 'ts'), 'm3u8');
    });
  });
}
