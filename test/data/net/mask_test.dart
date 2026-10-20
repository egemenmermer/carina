import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/net/mask.dart';

void main() {
  group('maskUrl', () {
    final cases = <String, String>{
      // ARCHITECTURE 2.2 example.
      'http://domain.com:8080/live/kanal/test123/1001.ts':
          'http://dom***:8080/live/ka***/***/1001.ts',
      'https://domain.com:8443/movie/kanal/test123/3001.mkv':
          'https://dom***:8443/movie/ka***/***/3001.mkv',
      'http://domain.com/series/kanal/test123/77001.mp4':
          'http://dom***/series/ka***/***/77001.mp4',
      'http://domain.com:8080/timeshift/kanal/test123/120/2026-10-17:21-00/1001.ts':
          'http://dom***:8080/timeshift/ka***/***/120/2026-10-17:21-00/1001.ts',
      'http://domain.com:8080/player_api.php?username=kanal&password=test123&action=get_live_streams': 'http://dom***:8080/player_api.php?username=***&password=***&action=get_live_streams',
      'http://domain.com:8080/get.php?username=kanal&password=test123&type=m3u_plus&output=ts': 'http://dom***:8080/get.php?username=***&password=***&type=m3u_plus&output=ts',
      'http://domain.com:8080/xmltv.php?username=kanal&password=test123':
          'http://dom***:8080/xmltv.php?username=***&password=***',
      'http://domain.com:8080/streaming/timeshift.php?username=kanal&password=test123&stream=1001&start=2026-10-17:21-00&duration=60': 'http://dom***:8080/streaming/timeshift.php?username=***&password=***&stream=1001&start=2026-10-17:21-00&duration=60',
      // Userinfo.
      'http://bob:secret@host.example.com/playlist.m3u':
          'http://***@hos***/playlist.m3u',
      'rtsp://admin@cam.local:554/stream': 'rtsp://***@cam***:554/stream',
      // token / key / case-insensitive names.
      'https://cdn.example.com/a.m3u8?token=abc123&key=xyz&foo=bar':
          'https://cdn***/a.m3u8?token=***&key=***&foo=bar',
      'http://h.example.com/x?Password=Secret&USERNAME=Bob':
          'http://h.e***/x?Password=***&USERNAME=***',
      'http://h.example.com/x?access_token=t0k&api_key=k3y&apikey=k4y':
          'http://h.e***/x?access_token=***&api_key=***&apikey=***',
      // `&amp;` copied from an HTML page or an M3U file.
      'http://h.example.com/get.php?username=bob&amp;password=secret':
          'http://h.e***/get.php?username=***&amp;password=***',
      // Short usernames are hidden completely.
      'http://domain.com/live/bob/pw/1.ts': 'http://dom***/live/***/***/1.ts',
      // Short Xtream form without /live/.
      'http://domain.com:8080/kanal/test123/1001':
          'http://dom***:8080/ka***/***/1001',
      'http://domain.com:8080/kanal/test123/1001.ts':
          'http://dom***:8080/ka***/***/1001.ts',
      'http://domain.com:8080/kanal/test123/1001.ts|User-Agent=VLC':
          'http://dom***:8080/ka***/***/1001.ts|User-Agent=VLC',
      // Percent-encoded username: the visible prefix is decoded.
      'http://domain.com/live/user%40mail.com/p%40ss/1.ts':
          'http://dom***/live/us***/***/1.ts',
      // Keyword match is case-insensitive and may follow a base path.
      'http://domain.com/panel/LIVE/kanal/test123/1.m3u8':
          'http://dom***/panel/LIVE/ka***/***/1.m3u8',
      // Nothing to mask in the path.
      'https://image.tmdb.org/t/p/w500/abc.jpg':
          'https://ima***/t/p/w500/abc.jpg',
      'http://domain.com/live/index.m3u8': 'http://dom***/live/index.m3u8',
      // IPv4 / IPv6 hosts.
      'http://192.168.1.10:8080/live/kanal/test123/5.ts':
          'http://192***:8080/live/ka***/***/5.ts',
      'http://[2001:db8::1]:8080/x?user=a': 'http://[200***]:8080/x?user=***',
      // Without a scheme.
      'domain.com:8080/live/kanal/test123/1.ts':
          'dom***:8080/live/ka***/***/1.ts',
      // A non-numeric "port" is hidden.
      'user:pass': 'use***:***',
      // Fragment parameters.
      'http://domain.com/x#token=abc': 'http://dom***/x#token=***',
      // Multicast without userinfo keeps the bare `@`.
      'udp://@239.0.0.1:1234': 'udp://@239***:1234',
    };

    cases.forEach((input, expected) {
      test(input, () => expect(maskUrl(input), expected));
    });

    test('never throws on garbage', () {
      for (final input in [
        '',
        ' ',
        'not a url',
        '::::',
        '%zz',
        'http://[::1',
        '/live/a/b/c',
        '?password=x',
        '@@@',
        'http://',
      ]) {
        expect(() => maskUrl(input), returnsNormally, reason: input);
        expect(maskUrl(input), isNot(contains('password=x')));
      }
      expect(maskUrl(''), '');
    });

    test('secrets never survive masking', () {
      const secret = 'S3cr3tP4ss';
      const user = 'loginname';
      final urls = [
        'http://h.com:80/live/$user/$secret/1.ts',
        'http://h.com:80/movie/$user/$secret/1.mkv',
        'http://h.com:80/series/$user/$secret/1.mp4',
        'http://h.com:80/timeshift/$user/$secret/60/2026-01-01:00-00/1.ts',
        'http://h.com:80/$user/$secret/1',
        'http://h.com/get.php?username=$user&password=$secret',
        'http://h.com/xmltv.php?password=$secret&username=$user',
        'http://$user:$secret@h.com/x',
        'http://h.com/x?token=$secret&user=$user',
      ];
      for (final url in urls) {
        final masked = maskUrl(url);
        expect(masked, isNot(contains(secret)), reason: url);
        expect(masked, isNot(contains(user)), reason: url);
      }
    });
  });

  group('maskServer', () {
    test('cuts the host and keeps the port', () {
      expect(maskServer('https://domain.com:8080'), 'https://dom***:8080');
      expect(maskServer('http://domain.com'), 'http://dom***');
      expect(maskServer(' http://domain.com:80/ '), 'http://dom***:80/');
    });

    test('drops a query string', () {
      expect(
        maskServer('http://domain.com:8080/?username=a&password=b'),
        'http://dom***:8080/',
      );
    });

    test('masks userinfo', () {
      expect(maskServer('http://a:b@domain.com:1'), 'http://***@dom***:1');
    });
  });

  group('maskText', () {
    test('masks embedded URLs and stray credential pairs', () {
      const text =
          'GET http://domain.com:8080/live/kanal/test123/1.ts failed; '
          'retry with password=hunter2 and token=abc';
      final masked = maskText(text);
      expect(masked, contains('http://dom***:8080/live/ka***/***/1.ts'));
      expect(masked, contains('password=***'));
      expect(masked, contains('token=***'));
      expect(masked, isNot(contains('test123')));
      expect(masked, isNot(contains('hunter2')));
    });

    test('leaves plain text alone', () {
      expect(maskText('Connection refused'), 'Connection refused');
    });
  });
}
