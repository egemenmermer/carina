import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import '../../tools/mock_server/src/server.dart';
import 'helpers.dart';

void main() {
  late FakeMedia media;
  late MockServer server;
  late String base;

  setUpAll(() async {
    media = await FakeMedia.create();
    server = await MockServer.start(
      port: 0,
      mediaDir: media.mediaDir,
      liveDir: media.liveDir,
      slowDelay: const Duration(milliseconds: 400),
    );
    base = server.baseUrl;
  });

  tearDownAll(() async {
    await server.stop();
    await media.delete();
  });

  group('failure endpoints ', () {
    test('empty: 200 with an empty body', () async {
      for (final path in [
        'player_api.php?$account',
        'playlist.m3u',
        'xmltv.php?$account',
      ]) {
        final r = await fetch('$base/fail/empty/$path');
        expect(r.status, 200, reason: path);
        expect(r.body, isEmpty, reason: path);
      }
    });

    test('html: 200 with an HTML error page', () async {
      final r = await fetch(
        '$base/fail/html/player_api.php?$account&action=get_live_streams',
      );
      expect(r.status, 200);
      expect(r.header('content-type'), startsWith('text/html'));
      expect(r.text, contains('<html>'));
      expect(() => r.json, throwsFormatException);
    });

    test('slow: delayed, then the normal response', () async {
      final r = await fetch('$base/fail/slow/player_api.php?$account');
      expect(r.status, 200);
      expect(
        r.elapsed,
        greaterThanOrEqualTo(const Duration(milliseconds: 380)),
      );
      expect(((r.json! as Map)['user_info'] as Map)['auth'], 1);
      final list = await fetch(
        '$base/fail/slow/player_api.php?$account&action=get_live_categories',
      );
      expect(list.json, isNotEmpty);
    });

    test('401: unauthorized with auth 0', () async {
      final r = await fetch('$base/fail/401/player_api.php?$account');
      expect(r.status, 401);
      expect(r.json, {
        'user_info': {'auth': 0},
      });
      expect((await fetch('$base/fail/401/playlist.m3u')).status, 401);
    });

    test('notm3u: 200 with text that is not a playlist', () async {
      final r = await fetch('$base/fail/notm3u/playlist.m3u');
      expect(r.status, 200);
      expect(r.text, isNotEmpty);
      expect(r.text, isNot(contains('#EXTM3U')));
      expect(r.text, isNot(contains('http')));
    });

    test('badxml: truncated XMLTV', () async {
      final r = await fetch('$base/fail/badxml/epg.xml');
      expect(r.status, 200);
      expect(r.text, startsWith('<?xml'));
      expect(r.text, contains('<programme '));
      expect(r.text, isNot(contains('</tv>')));
      expect(() => XmlDocument.parse(r.text), throwsA(isA<XmlException>()));
    });

    test('emptysection: valid auth but empty lists', () async {
      final auth = await fetch(
        '$base/fail/emptysection/player_api.php?$account',
      );
      expect(((auth.json! as Map)['user_info'] as Map)['status'], 'Active');
      for (final action in [
        'get_live_categories', 'get_live_streams', 'get_vod_categories', //
        'get_vod_streams', 'get_series_categories', 'get_series',
      ]) {
        final r = await fetch(
          '$base/fail/emptysection/player_api.php?$account&action=$action',
        );
        expect(r.status, 200, reason: action);
        expect(r.json, isEmpty, reason: action);
      }
    });

    test('redirect and 500', () async {
      final r = await fetch('$base/fail/redirect/player_api.php?$account');
      expect(r.status, 302);
      expect(r.header('location'), '/player_api.php?$account');
      final followed = await fetch(
        '$base/fail/redirect/player_api.php?$account',
        followRedirects: true,
      );
      expect(followed.status, 200);
      expect((await fetch('$base/fail/500/player_api.php')).status, 500);
      expect((await fetch('$base/fail/unknown/x')).status, 404);
    });

    test('streams under a failure prefix still resolve', () async {
      final r = await readStreamFor(
        '$base/fail/slow/live/$creds/1001.ts',
        const Duration(milliseconds: 800),
      );
      expect(r.status, 200);
      expect(r.bytes, greaterThan(0));
    });
  });

  group('diagnostics', () {
    test('requestLog keeps every path, newest last', () async {
      server.clearRequestLog();
      await fetch('$base/player_api.php?$account&action=get_live_categories');
      await fetch('$base/live/$creds/1008.ts');
      expect(server.requestLog, [
        '/player_api.php?$account&action=get_live_categories',
        '/live/$creds/1008.ts',
      ]);
      expect(server.requests.last.status, 404);
      for (var i = 0; i < 2100; i++) {
        await fetch('$base/nothing/$i');
      }
      expect(server.requestLog, hasLength(2000));
      expect(server.requestLog.last, '/nothing/2099');
    });

    test('/mock/requests and /mock/health', () async {
      server.clearRequestLog();
      await fetch(
        '$base/player_api.php?$account',
        headers: {'user-agent': 'CarinaTest/1.0'},
      );
      final log = (await fetch('$base/mock/requests')).json! as Map;
      expect(log['count'], 1);
      final entry = (log['requests'] as List).single as Map;
      expect(entry['path'], '/player_api.php?$account');
      expect(entry['status'], 200);
      expect(entry['user_agent'], 'CarinaTest/1.0');
      expect(
        (await fetch('$base/mock/requests', method: 'DELETE')).status,
        200,
      );
      expect(server.requestLog, isEmpty);

      final health = (await fetch('$base/mock/health')).json! as Map;
      expect(health['ok'], isTrue);
      expect(health['scale'], 'small');
      expect((health['counts'] as Map)['live'], 300);
      expect((health['media'] as Map)[MockMedia.vodTracksMkv], isTrue);
      expect((health['hls'] as Map)['running'], isTrue);
    });

    test('unknown paths are 404 with a hint', () async {
      final r = await fetch('$base/definitely/not/here');
      expect(r.status, 404);
      expect(r.text, contains('See $base/'));
      final index = await fetch('$base/');
      expect(index.text, contains('player_api.php'));
    });
  });
}
