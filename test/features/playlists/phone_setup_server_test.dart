import 'dart:convert';
import 'dart:io';

import 'package:carina/data/db/database.dart' show PlaylistType;
import 'package:carina/features/playlists/data/lan_address.dart';
import 'package:carina/features/playlists/data/phone_setup_server.dart';
import 'package:carina/features/playlists/data/wizard_form.dart';
import 'package:flutter_test/flutter_test.dart';

class _Reply {
  _Reply(this.status, this.body);

  final int status;
  final String body;

  Map<String, Object?> get json => jsonDecode(body) as Map<String, Object?>;
}

Future<_Reply> _request(
  Uri url, {
  String method = 'GET',
  Object? body,
  String contentType = 'application/json',
  String? path,
}) async {
  final client = HttpClient();
  try {
    final target = path == null ? url : url.replace(path: path);
    final request = await client.openUrl(method, target);
    if (body != null) {
      request.headers.set(HttpHeaders.contentTypeHeader, contentType);
      request.add(utf8.encode(body is String ? body : jsonEncode(body)));
    }
    final response = await request.close();
    final text = await utf8.decodeStream(response);
    // The server delivers the values right after flushing its reply.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return _Reply(response.statusCode, text);
  } finally {
    client.close(force: true);
  }
}

const _xtream = {
  'type': 'xtream',
  'name': '',
  'server': 'http://tv.example.com:8080',
  'username': 'alice',
  'password': 's3cret',
  'epgUrl': '',
};

void main() {
  group('PhoneSetupServer', () {
    late PhoneSetupServer server;
    late List<WizardValues> received;
    var expired = false;

    Future<void> startServer({
      Duration lifetime = phoneSetupLifetime,
      int maxBodyBytes = phoneSetupMaxBodyBytes,
    }) async {
      received = [];
      expired = false;
      server = await PhoneSetupServer.start(
        address: InternetAddress.loopbackIPv4,
        page: '<html>page</html>',
        onSubmitted: received.add,
        onExpired: () => expired = true,
        lifetime: lifetime,
        maxBodyBytes: maxBodyBytes,
      );
    }

    tearDown(() => server.close());

    test('the URL carries a random token and the bound address', () async {
      await startServer();
      expect(server.url.host, '127.0.0.1');
      expect(server.url.port, greaterThan(0));
      expect(server.url.path, '/${server.token}');
      expect(server.token.length, greaterThanOrEqualTo(22));
      expect(
        PhoneSetupServer.generateToken(),
        isNot(PhoneSetupServer.generateToken()),
      );
    });

    test('serves the page only on the token path', () async {
      await startServer();
      final page = await _request(server.url);
      expect(page.status, 200);
      expect(page.body, '<html>page</html>');

      for (final path in ['/', '/nope', '/${server.token}x', '/a/b']) {
        final miss = await _request(server.url, path: path);
        expect(miss.status, 404, reason: path);
      }
      final post = await _request(
        server.url,
        method: 'POST',
        body: _xtream,
        path: '/wrong-token',
      );
      expect(post.status, 404);
      expect(received, isEmpty);
    });

    test('rejects other methods, content types and bad bodies', () async {
      await startServer();
      final put = await _request(server.url, method: 'PUT', body: '{}');
      expect(put.status, 405);
      final form = await _request(
        server.url,
        method: 'POST',
        body: 'type=xtream',
        contentType: 'application/x-www-form-urlencoded',
      );
      expect(form.status, 415);
      for (final body in ['not json', '[]', '"x"', '{"type":"file"}']) {
        final r = await _request(server.url, method: 'POST', body: body);
        expect(r.status, 400, reason: body);
      }
      // A value that is not a string.
      final bad = await _request(
        server.url,
        method: 'POST',
        body: {..._xtream, 'username': 5},
      );
      expect(bad.status, 400);
      expect(received, isEmpty);
      expect(server.isClosed, isFalse);
    });

    test('caps the body size', () async {
      await startServer(maxBodyBytes: 256);
      final big = await _request(
        server.url,
        method: 'POST',
        body: {..._xtream, 'name': 'x' * 1000},
      );
      expect(big.status, 413);
      expect(received, isEmpty);
      expect(server.isClosed, isFalse);
    });

    test('invalid values answer 422 with the wizard problems', () async {
      await startServer();
      final r = await _request(
        server.url,
        method: 'POST',
        body: {..._xtream, 'server': 'tv.example.com', 'password': ''},
      );
      expect(r.status, 422);
      expect(r.json['errors'], {
        'server': WizardProblem.serverScheme.name,
        'password': WizardProblem.password.name,
      });
      expect(received, isEmpty);
      // The server stays open for another try.
      expect(server.isClosed, isFalse);
      final ok = await _request(server.url, method: 'POST', body: _xtream);
      expect(ok.status, 200);
    });

    test('accepts one valid submission, then shuts down', () async {
      await startServer();
      final url = server.url;
      final r = await _request(url, method: 'POST', body: _xtream);
      expect(r.status, 200);
      expect(r.json, {'ok': true});
      expect(received, hasLength(1));
      final v = received.single;
      expect(v.type, PlaylistType.xtream);
      expect(v.server, 'http://tv.example.com:8080');
      expect(v.username, 'alice');
      expect(v.password, 's3cret');
      // The name defaults to the host.
      expect(v.name, 'tv.example.com');
      expect(v.validate(), isEmpty);
      expect(server.accepted, isTrue);

      // Single use: the port closes after the reply.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(server.isClosed, isTrue);
      await expectLater(
        _request(url, method: 'POST', body: _xtream),
        throwsA(isA<SocketException>()),
      );
      expect(received, hasLength(1));
    });

    test('two racing submissions deliver only one', () async {
      await startServer();
      Future<int> post() => _request(
        server.url,
        method: 'POST',
        body: _xtream,
      ).then((r) => r.status, onError: (Object _) => -1);
      final results = await Future.wait([post(), post()]);
      expect(received, hasLength(1));
      expect(results.where((s) => s == 200), hasLength(1));
    });

    test('an M3U submission keeps its name and guide', () async {
      await startServer();
      final r = await _request(
        server.url,
        method: 'POST',
        body: {
          'type': 'm3u',
          'name': ' Sports ',
          'playlistUrl': 'https://example.com/list.m3u',
          'epgUrl': 'https://example.com/guide.xml',
          // Ignored for M3U.
          'server': 'junk',
        },
      );
      expect(r.status, 200);
      final v = received.single;
      expect(v.type, PlaylistType.m3u);
      expect(v.name.trim(), 'Sports');
      expect(v.playlistUrl, 'https://example.com/list.m3u');
      expect(v.epgText, 'https://example.com/guide.xml');
      expect(v.server, isEmpty);
    });

    test('a get.php link in Server fills the three Xtream fields', () async {
      await startServer();
      final r = await _request(
        server.url,
        method: 'POST',
        body: {
          'type': 'xtream',
          'server': 'http://tv.example.com:8080/get.php?username=bob&password=pw&type=m3u_plus',
        },
      );
      expect(r.status, 200);
      expect(received.single.username, 'bob');
      expect(received.single.password, 'pw');
      expect(received.single.server, 'http://tv.example.com:8080');
    });

    test('expires after its lifetime', () async {
      await startServer(lifetime: const Duration(milliseconds: 80));
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(expired, isTrue);
      expect(server.isClosed, isTrue);
      await expectLater(_request(server.url), throwsA(isA<SocketException>()));
    });

    test('close is idempotent and stops the server', () async {
      await startServer();
      await server.close();
      await server.close();
      expect(server.isClosed, isTrue);
      expect(expired, isFalse);
      await expectLater(_request(server.url), throwsA(isA<SocketException>()));
    });
  });

  group('pickLanAddress', () {
    LanCandidate c(String name, String ip) =>
        LanCandidate(name, InternetAddress(ip));

    test('prefers Wi-Fi / Ethernet private addresses', () {
      expect(
        pickLanAddress([c('rmnet0', '10.20.30.40'), c('wlan0', '192.168.1.20')])
            ?.address,
        '192.168.1.20',
      );
      expect(
        pickLanAddress([c('foo0', '10.0.0.5'), c('eth0', '172.16.4.2')])
            ?.address,
        '172.16.4.2',
      );
      expect(pickLanAddress([c('en0', '192.168.0.9')])?.address, '192.168.0.9');
      expect(
        pickLanAddress([c('Wi-Fi', '192.168.2.2')])?.address,
        '192.168.2.2',
      );
    });

    test('skips virtual, public and link-local addresses', () {
      expect(
        pickLanAddress([
          c('docker0', '172.17.0.1'),
          c('utun3', '10.8.0.2'),
          c('wlan0', '169.254.3.4'),
          c('eth0', '8.8.4.4'),
          c('eth1', '172.32.0.1'),
        ]),
        isNull,
      );
      expect(pickLanAddress(const []), isNull);
    });

    test('falls back to an unknown real interface', () {
      expect(pickLanAddress([c('foo0', '10.1.1.1')])?.address, '10.1.1.1');
    });
  });

  test('defaultPlaylistName uses the host', () {
    expect(
      defaultPlaylistName(PlaylistType.xtream, server: 'http://a.b:80'),
      'a.b',
    );
    expect(
      defaultPlaylistName(
        PlaylistType.m3u,
        playlistUrl: 'https://www.x.tv/l.m3u',
      ),
      'x.tv',
    );
    expect(defaultPlaylistName(PlaylistType.m3u), 'IPTV');
  });
}
