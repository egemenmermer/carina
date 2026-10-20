// The wizard's live checks against the in-process mock server: the real
// PlaylistSourceChecker plus the user-facing status texts.
import 'dart:io';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:carina/app/time_format.dart';
import 'package:carina/core/core.dart' show KFieldStatusKind;
import 'package:carina/data/db/database.dart' show SectionKind;
import 'package:carina/data/import/import.dart';
import 'package:carina/data/net/url_check.dart' show UrlContentKind;
import 'package:carina/data/sources/m3u/m3u_detect.dart';
import 'package:carina/data/sources/source_exception.dart';
import 'package:carina/data/sources/xtream/xtream_credentials.dart';
import 'package:carina/features/playlists/data/source_checker.dart';
import 'package:carina/features/playlists/data/source_messages.dart';
import 'package:carina/l10n/gen/app_localizations.dart';

import '../../../tools/mock_server/src/server.dart';
import 'support/playlists_harness.dart';

void main() {
  late MockServer server;
  late Directory temp;
  const checker = PlaylistSourceChecker();
  final en = lookupL10n(const Locale('en'));
  final tr = lookupL10n(const Locale('tr'));
  final fmtEn = CarinaTimeFormat(locale: 'en', use24h: false);
  final fmtTr = CarinaTimeFormat(locale: 'tr', use24h: true);

  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('tr');
    temp = await Directory.systemTemp.createTemp('carina_checks_');
    final media = Directory('${temp.path}/media')..createSync();
    Directory('${temp.path}/live').createSync();
    server = await MockServer.start(
      port: 0,
      mediaDir: media.path,
      slowDelay: const Duration(seconds: 2),
    );
  });

  tearDownAll(() async {
    await server.stop();
    await temp.delete(recursive: true);
  });

  XtreamCredentials creds(
    String user, [
    String password = MockFixtures.password,
    String? base,
  ]) => XtreamCredentials(base ?? server.baseUrl, user, password);

  group('Xtream', () {
    test('active account: reachable, expiry and connections', () async {
      final result = await withRealHttp(
        () => checker.checkXtream(creds(MockFixtures.username)),
      );
      expect(result.ok, isTrue, reason: '$result');
      expect(result.expiresAt?.toUtc(), DateTime.utc(2027, 3, 1));
      expect(result.maxConnections, 2);
      final status = xtreamCheckStatus(en, fmtEn, result);
      expect(status.kind, KFieldStatusKind.ok);
      expect(
        status.message,
        'Server reachable · account active · expires 1 March 2027 · '
        '2 connections',
      );
      expect(
        xtreamCheckStatus(tr, fmtTr, result).message,
        'Sunucuya ulaşıldı · hesap etkin · bitiş 1 Mart 2027 · 2 bağlantı',
      );
    });

    test('expired account', () async {
      final result = await withRealHttp(
        () => checker.checkXtream(
          creds(MockFixtures.expiredUsername, MockFixtures.expiredPassword),
        ),
      );
      expect(result.ok, isFalse);
      expect(result.error, SourceErrorKind.accountInactive);
      final status = xtreamCheckStatus(en, fmtEn, result);
      expect(status.kind, KFieldStatusKind.error);
      expect(status.message, startsWith('Account expired · ended '));
    });

    test('wrong password → 401 text', () async {
      final result = await withRealHttp(
        () => checker.checkXtream(creds(MockFixtures.username, 'nope')),
      );
      expect(result.error, SourceErrorKind.unauthorized);
      expect(
        xtreamCheckStatus(en, fmtEn, result).message,
        'Wrong username or password (401)',
      );
    });

    test('a web page instead of the API', () async {
      final result = await withRealHttp(
        () => checker.checkXtream(
          creds(
            MockFixtures.username,
            MockFixtures.password,
            '${server.baseUrl}/fail/html',
          ),
        ),
      );
      expect(result.error, SourceErrorKind.unparseable);
      expect(
        xtreamCheckStatus(en, fmtEn, result).message,
        "This doesn't look like an Xtream server",
      );
    });

    test('unreachable server (closed port)', () async {
      final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = socket.port;
      await socket.close();
      final result = await withRealHttp(
        () => checker.checkXtream(
          creds(
            MockFixtures.username,
            MockFixtures.password,
            'http://127.0.0.1:$port',
          ),
        ),
      );
      expect(result.ok, isFalse);
      expect(result.reachable, isFalse);
      expect(
        xtreamCheckStatus(en, fmtEn, result).message,
        'Unreachable: check the address and your connection',
      );
    });
  });

  group('M3U URL', () {
    test('Xtream export: reachable M3U, detected as Xtream', () async {
      final url =
          '${server.baseUrl}/get.php?username=${MockFixtures.username}'
          '&password=${MockFixtures.password}&type=m3u_plus&output=ts';
      final result = await withRealHttp(() => checker.checkPlaylistUrl(url));
      expect(result.ok, isTrue, reason: '$result');
      expect(result.m3uEpgUrls, isEmpty);
      expect(playlistUrlStatus(en, result).message, 'Playlist reachable · M3U');
      final export = detectXtreamExport(url);
      expect(export?.server, server.baseUrl);
      expect(export?.username, MockFixtures.username);
    });

    test('extended M3U with url-tvg in the header', () async {
      final result = await withRealHttp(
        () => checker.checkPlaylistUrl('${server.baseUrl}/playlist.m3u'),
      );
      expect(result.ok, isTrue, reason: '$result');
      expect(result.m3uEpgUrls, ['${server.baseUrl}/epg.xml.gz']);
      expect(
        playlistUrlStatus(en, result).message,
        'Playlist reachable · M3U · guide link found',
      );
      expect(detectXtreamExport('${server.baseUrl}/playlist.m3u'), isNull);
    });

    test('not an M3U, empty body, 404', () async {
      final notM3u = await withRealHttp(
        () => checker.checkPlaylistUrl('${server.baseUrl}/fail/notm3u/x.m3u'),
      );
      expect(notM3u.error, SourceErrorKind.unparseable);
      expect(
        playlistUrlStatus(en, notM3u).message,
        'This is not an M3U playlist',
      );

      final empty = await withRealHttp(
        () => checker.checkPlaylistUrl('${server.baseUrl}/fail/empty/x.m3u'),
      );
      expect(empty.error, SourceErrorKind.emptyBody);
      expect(
        playlistUrlStatus(en, empty).message,
        'The server sent an empty response',
      );

      final missing = await withRealHttp(
        () => checker.checkPlaylistUrl('${server.baseUrl}/nothing-here.m3u'),
      );
      expect(missing.error, SourceErrorKind.notFound);
      expect(
        playlistUrlStatus(en, missing).message,
        'Not found (404): check the address',
      );
    });
  });

  group('EPG URL', () {
    test('plain and gzip XMLTV', () async {
      final xml = await withRealHttp(
        () => checker.checkEpgUrl('${server.baseUrl}/epg.xml'),
      );
      expect(xml.ok, isTrue);
      expect(epgUrlStatus(en, xml).message, 'Guide reachable · XMLTV');
      final gz = await withRealHttp(
        () => checker.checkEpgUrl('${server.baseUrl}/epg.xml.gz'),
      );
      expect(gz.ok, isTrue);
      expect(gz.kind, UrlContentKind.gzip);
      expect(
        epgUrlStatus(en, gz).message,
        'Guide reachable · XMLTV (compressed)',
      );
    });

    test(
      'a truncated guide still passes: a green check is no promise',
      () async {
        final bad = await withRealHttp(
          () => checker.checkEpgUrl('${server.baseUrl}/fail/badxml/epg.xml'),
        );
        expect(bad.ok, isTrue);
        final html = await withRealHttp(
          () => checker.checkEpgUrl('${server.baseUrl}/fail/html/epg.xml'),
        );
        expect(html.ok, isFalse);
        expect(epgUrlStatus(en, html).message, 'This is not an XMLTV guide');
      },
    );
  });

  group('local file', () {
    test('M3U with a header guide, a text file, a missing file', () async {
      final m3u = File('${temp.path}/list.m3u')
        ..writeAsStringSync(
          '#EXTM3U url-tvg="http://guide.example/epg.xml"\n'
          '#EXTINF:-1,One\nhttp://s.example/1.ts\n',
        );
      final ok = await checker.checkFile(m3u.path);
      expect(ok.ok, isTrue);
      expect(ok.epgUrls, ['http://guide.example/epg.xml']);
      expect(fileStatus(en, ok).message, 'File ready · M3U');

      final text = File('${temp.path}/notes.txt')..writeAsStringSync('hi');
      final notM3u = await checker.checkFile(text.path);
      expect(notM3u.ok, isFalse);
      expect(fileStatus(en, notM3u).message, 'This is not an M3U playlist');

      final missing = await checker.checkFile('${temp.path}/missing.m3u');
      expect(missing.exists, isFalse);
      expect(fileStatus(en, missing).message, 'File not found');
    });
  });

  group('import result texts', () {
    test('failures name the cause and warn about the green check', () {
      final unreachable = importFailureText(
        en,
        const SourceException(SourceErrorKind.unreachable),
      );
      expect(unreachable.title, 'The playlist could not be imported');
      expect(unreachable.message, contains("couldn't reach the server"));
      expect(unreachable.note, contains('green check'));
      expect(
        importFailureText(
          en,
          const SourceException(SourceErrorKind.emptyBody),
        ).message,
        contains('empty response'),
      );
      expect(
        importFailureText(
          en,
          const SourceException(SourceErrorKind.unparseable),
        ).message,
        contains('could not be read as a playlist'),
      );
      expect(
        importFailureText(
          en,
          const SourceException(
            SourceErrorKind.accountInactive,
            message: 'Account status: Expired',
          ),
        ).message,
        'The provider reports the account as expired.',
      );
      expect(
        importFailureText(
          en,
          const SourceException(SourceErrorKind.http, statusCode: 502),
        ).message,
        'The server answered with an error (HTTP 502).',
      );
    });

    test('empty sections and guide failures', () {
      final empty = emptySectionsText(en, {
        SectionKind.movie,
        SectionKind.series,
      });
      expect(empty.title, 'Imported, but some sections are empty');
      expect(empty.message, contains('Movies, Series'));
      final epg = epgFailureText(
        en,
        const SourceException(SourceErrorKind.unparseable),
      );
      expect(epg.message, contains('were imported and are ready'));
      expect(epg.message, contains('not valid XMLTV'));
      final epgOnly = epgFailureText(
        en,
        const SourceException(SourceErrorKind.emptyBody),
        contentImported: false,
      );
      expect(epgOnly.message, 'The guide file was empty.');
    });

    test('step labels follow the brief', () {
      expect(
        [for (final s in allSteps) importStepLabel(en, s)],
        [
          'Connecting',
          'Live categories',
          'Live channels',
          'Movies',
          'Series',
          'EPG: Cleaning programs',
          'EPG: Downloading',
          'EPG: Parsing',
          'Completed',
        ],
      );
      expect(ImportStep.values, contains(ImportStep.completed));
    });

    test('numbers and sizes', () {
      expect(formatCount('en', 123456), '123,456');
      expect(formatCount('tr', 123456), '123.456');
      expect(formatBytes('en', 512), '512 B');
      expect(formatBytes('en', 1536), '1.5 KB');
      expect(formatBytes('en', 45 * 1024 * 1024), '45.0 MB');
      expect(formatBytes('en', 150 * 1024 * 1024), '150 MB');
    });
  });
}
