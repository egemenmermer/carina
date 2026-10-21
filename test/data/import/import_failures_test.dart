import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/import/import.dart';
import 'package:carina/data/sources/source_exception.dart';

import 'import_harness.dart';

void main() {
  late ImportHarness h;

  setUpAll(() async => h = await ImportHarness.create());
  tearDownAll(() => h.dispose());

  /// Imports a fresh Xtream playlist on [server] and returns the result.
  Future<ImportProgress> xtream({
    String? server,
    String username = user,
    String? epgUrl,
    bool epg = false,
  }) async {
    final id = await h.addXtream(
      server: server,
      username: username,
      epgUrl: epgUrl,
      epg: epg,
    );
    return h.service.run(id);
  }

  void expectFailed(
    ImportProgress p,
    SourceErrorKind kind, {
    ImportStep at = ImportStep.connecting,
  }) {
    expect(p.step, ImportStep.failed, reason: '$p');
    expect(p.done, isTrue);
    expect(p.error?.kind, kind, reason: '${p.error}');
    expect(p.failedStep, at);
    expect(p.statusOf(at), ImportStepStatus.failed);
    final url = p.error?.url ?? '';
    expect(url, isNot(contains(MockFixtures.password)));
    expect(url, isNot(contains('username=$user')));
  }

  group('Xtream', () {
    test('unreachable server (closed port)', () async {
      final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = socket.port;
      await socket.close();
      expectFailed(
        await xtream(server: 'http://127.0.0.1:$port'),
        SourceErrorKind.unreachable,
      );
    });

    test('HTTP 401', () async {
      final p = await xtream(server: '${h.base}/fail/401');
      expectFailed(p, SourceErrorKind.unauthorized);
      expect(p.error?.statusCode, 401);
    });

    test('wrong password', () async {
      final id = await h.addXtream(password: 'wrong', epg: false);
      expectFailed(await h.service.run(id), SourceErrorKind.unauthorized);
    });

    test('expired account', () async {
      expectFailed(
        await xtream(username: MockFixtures.expiredUsername),
        SourceErrorKind.accountInactive,
      );
    });

    test('empty body', () async {
      expectFailed(
        await xtream(server: '${h.base}/fail/empty'),
        SourceErrorKind.emptyBody,
      );
    });

    test('HTML instead of JSON', () async {
      expectFailed(
        await xtream(server: '${h.base}/fail/html'),
        SourceErrorKind.unparseable,
      );
    });

    test('missing password', () async {
      final id = await h.addXtream(epg: false);
      await h.secrets.write('playlist.$id.password', null);
      expectFailed(await h.service.run(id), SourceErrorKind.unauthorized);
    });

    test('unknown playlist', () async {
      final p = await h.service.run(999999);
      expect(p.step, ImportStep.failed);
      expect(p.error?.kind, SourceErrorKind.notFound);
    });

    test('empty sections: warnings for all three, import succeeds', () async {
      final id = await h.addXtream(
        server: '${h.base}/fail/emptysection',
        epg: false,
      );
      final p = await h.service.run(id);
      expect(p.step, ImportStep.completed, reason: '$p');
      expect(p.warnings, [
        const ImportWarning(SourceErrorKind.sectionEmpty, SectionKind.live),
        const ImportWarning(SourceErrorKind.sectionEmpty, SectionKind.movie),
        const ImportWarning(SourceErrorKind.sectionEmpty, SectionKind.series),
      ]);
      expect(p.emptySections, SectionKind.values.toSet());
      expect(p.counts[ImportStep.liveChannels], 0);
      final row = await h.playlist(id);
      expect((row.liveCount, row.movieCount, row.seriesCount), (0, 0, 0));
      expect(row.lastReloadAt, isNotNull);
    });

    test('a failure in a later step reverts the removed marks', () async {
      final proxy = await FilteringProxy.start(h.base);
      addTearDown(proxy.stop);
      final id = await h.addXtream(server: proxy.baseUrl, epg: false);
      expect((await h.service.run(id)).succeeded, isTrue);
      final before = await h.playlist(id);

      proxy.failingActions.add('get_series');
      final p = await h.service.run(id);
      expectFailed(p, SourceErrorKind.http, at: ImportStep.series);
      expect(p.statusOf(ImportStep.movies), ImportStepStatus.done);
      expect(p.statusOf(ImportStep.completed), ImportStepStatus.pending);
      for (final table in ['categories', 'channels', 'movies', 'series']) {
        expect(await h.count(table, id, 'removed = 1'), 0, reason: table);
      }
      expect(await h.count('channels', id), before.liveCount);
      expect(await h.count('movies', id), before.movieCount);
      expect(await h.count('series', id), before.seriesCount);
      final after = await h.playlist(id);
      expect(after.lastReloadAt, before.lastReloadAt);
    });
  });

  group('M3U', () {
    test('not an M3U', () async {
      final id = await h.addM3u(url: '${h.base}/fail/notm3u/playlist.m3u');
      expectFailed(await h.service.run(id), SourceErrorKind.unparseable);
    });

    test('empty body', () async {
      final id = await h.addM3u(url: '${h.base}/fail/empty/playlist.m3u');
      expectFailed(await h.service.run(id), SourceErrorKind.emptyBody);
    });

    test('HTML error page', () async {
      final id = await h.addM3u(url: '${h.base}/fail/html/playlist.m3u');
      expectFailed(await h.service.run(id), SourceErrorKind.unparseable);
    });

    test('HTTP 404', () async {
      final id = await h.addM3u(url: '${h.base}/nothing-here.m3u');
      final p = await h.service.run(id);
      expectFailed(p, SourceErrorKind.notFound);
      expect(p.error?.statusCode, 404);
    });

    test('missing local file', () async {
      final id = await h.addM3u(
        url: '${h.tempDir.path}/missing.m3u',
        type: PlaylistType.m3uFile,
      );
      expectFailed(await h.service.run(id), SourceErrorKind.notFound);
    });
  });

  group('EPG', () {
    test('bad XML: content kept, EPG step failed', () async {
      final id = await h.addXtream(epgUrl: '${h.base}/fail/badxml/xmltv.php');
      final p = await h.service.run(id);
      expect(p.step, ImportStep.completed, reason: '$p');
      expect(p.error, isNull);
      expect(p.epgFailed, isTrue);
      expect(p.epgError?.kind, SourceErrorKind.unparseable);
      expect(p.failedStep, ImportStep.epgParsing);
      expect(p.statusOf(ImportStep.series), ImportStepStatus.done);
      expect(p.statusOf(ImportStep.epgParsing), ImportStepStatus.failed);
      expect(p.statusOf(ImportStep.completed), ImportStepStatus.done);
      final row = await h.playlist(id);
      expect(row.liveCount, h.catalog.channels.length);
      expect(row.lastReloadAt, isNotNull);
      expect(row.lastEpgReloadAt, isNull);
      expect(await h.count('programmes', id), 0);

      // An EPG-only import fails outright.
      final epgOnly = await h.service.run(id, scope: ImportScope.epg);
      expectFailed(
        epgOnly,
        SourceErrorKind.unparseable,
        at: ImportStep.epgParsing,
      );
      expect(epgOnly.epgError, epgOnly.error);
      expect(epgOnly.plannedSteps, [
        ...ImportStep.epgSteps,
        ImportStep.completed,
      ]);
      expect(epgOnly.skippedSteps, containsAll(ImportStep.contentSteps));
    });

    test('unreachable guide: download step failed', () async {
      final id = await h.addXtream(
        epgUrl: '${h.base}/fail/401/xmltv.php?username=$user&password=$pass',
      );
      final p = await h.service.run(id);
      expect(p.step, ImportStep.completed);
      expect(p.epgError?.kind, SourceErrorKind.unauthorized);
      expect(p.failedStep, ImportStep.epgDownloading);
      expect(p.statusOf(ImportStep.epgParsing), ImportStepStatus.skipped);
    });
  });

  group('cancel', () {
    test('mid content import: cancelled, previous data intact', () async {
      final id = await h.addXtream(epg: false);
      expect((await h.service.run(id)).succeeded, isTrue);
      final before = await h.playlist(id);
      await h.db.customStatement(
        "UPDATE channels SET locked = 1 WHERE playlist_id = $id "
        "AND provider_id = '1006'",
      );

      final events = <ImportProgress>[];
      await for (final e in h.service.start(id)) {
        events.add(e);
        if (e.step == ImportStep.movies && !e.done) h.service.cancel(id);
      }
      final last = events.last;
      expect(last.step, ImportStep.cancelled, reason: '$last');
      expect(last.error, isNull);
      expect(last.failedStep, ImportStep.movies);
      expect(last.statusOf(ImportStep.movies), ImportStepStatus.cancelled);
      expect(last.statusOf(ImportStep.liveChannels), ImportStepStatus.done);
      expect(h.service.isRunning(id), isFalse);

      for (final table in ['categories', 'channels', 'movies', 'series']) {
        expect(await h.count(table, id, 'removed = 1'), 0, reason: table);
      }
      expect(await h.count('channels', id), before.liveCount);
      expect(await h.count('movies', id), before.movieCount);
      expect(await h.count('series', id), before.seriesCount);
      expect((await h.channel(id, 1006))!.locked, isTrue);
      final after = await h.playlist(id);
      expect(after.lastReloadAt, before.lastReloadAt);
    });

    test('while parsing the guide: the previous guide stays', () async {
      final id = await h.addXtream();
      expect((await h.service.run(id)).succeeded, isTrue);
      final programmes = await h.count('programmes', id);
      final before = await h.playlist(id);
      expect(programmes, greaterThan(0));

      final events = <ImportProgress>[];
      await for (final e in h.service.start(id, scope: ImportScope.epg)) {
        events.add(e);
        if (e.step == ImportStep.epgParsing &&
            (e.counts[ImportStep.epgParsing] ?? 0) > 0) {
          h.service.cancel(id);
        }
      }
      expect(events.last.step, ImportStep.cancelled, reason: '${events.last}');
      expect(events.last.failedStep, ImportStep.epgParsing);
      expect(await h.count('programmes', id), programmes);
      final after = await h.playlist(id);
      expect(after.programmeCount, before.programmeCount);
      expect(after.lastEpgReloadAt, before.lastEpgReloadAt);
    });

    test('a late content cancel leaves consistent data', () async {
      final id = await h.addXtream(epg: false);
      expect((await h.service.run(id)).succeeded, isTrue);
      final searchRows = await h.count('search_index', id);
      final before = await h.playlist(id);

      final events = <ImportProgress>[];
      await for (final e in h.service.start(id)) {
        events.add(e);
        // The last upsert of the content: the finishing steps follow.
        if (e.step == ImportStep.series &&
            e.counts[ImportStep.series] == h.catalog.series.length) {
          h.service.cancel(id);
        }
      }
      // Too late to cancel once the content is committed; either way the
      // data must be complete.
      expect(
        events.last.step,
        isIn([ImportStep.completed, ImportStep.cancelled]),
      );
      for (final table in ['categories', 'channels', 'movies', 'series']) {
        expect(await h.count(table, id, 'removed = 1'), 0, reason: table);
      }
      expect(await h.count('search_index', id), searchRows);
      final after = await h.playlist(id);
      expect(after.liveCount, before.liveCount);
      expect(after.movieCount, before.movieCount);
    });

    test('a late guide cancel keeps one complete guide', () async {
      final id = await h.addXtream();
      expect((await h.service.run(id)).succeeded, isTrue);
      final programmes = await h.count('programmes', id);

      final events = <ImportProgress>[];
      await for (final e in h.service.start(id, scope: ImportScope.epg)) {
        events.add(e);
        if (e.step == ImportStep.epgParsing &&
            e.counts[ImportStep.epgParsing] == programmes) {
          h.service.cancel(id);
        }
      }
      expect(
        events.last.step,
        isIn([ImportStep.completed, ImportStep.cancelled]),
      );
      // The mock guide is generated around "now", so a completed second
      // import may hold a few programmes more or less than the first.
      final expected = events.last.step == ImportStep.cancelled
          ? programmes
          : events.last.countOf(ImportStep.epgParsing);
      expect(await h.count('programmes', id), expected);
      expect((await h.playlist(id)).programmeCount, expected);
      expect(await h.count('programme_search', id), greaterThan(0));
    });

    test('before the first snapshot', () async {
      final id = await h.addXtream(epg: false);
      final stream = h.service.start(id);
      h.service.cancel(id);
      final last = await stream.last;
      expect(last.step, ImportStep.cancelled);
      expect(await h.count('channels', id), 0);
    });
  });

  group('timeouts', () {
    late ImportHarness slow;

    setUpAll(() async {
      slow = await ImportHarness.create(
        slowDelay: const Duration(seconds: 4),
        config: const ImportConfig(
          connectTimeout: Duration(seconds: 2),
          receiveTimeout: Duration(milliseconds: 800),
          retries: 0,
        ),
      );
    });
    tearDownAll(() => slow.dispose());

    test('a slow server times out', () async {
      final id = await slow.addXtream(
        server: '${slow.base}/fail/slow',
        epg: false,
      );
      final watch = Stopwatch()..start();
      final p = await slow.service.run(id);
      expectFailed(p, SourceErrorKind.timeout);
      expect(watch.elapsed, lessThan(const Duration(seconds: 4)));
    });

    test('cancel while waiting for a slow server is immediate', () async {
      final id = await slow.addXtream(
        server: '${slow.base}/fail/slow',
        epg: false,
      );
      final watch = Stopwatch()..start();
      final stream = slow.service.start(id);
      await stream.first;
      slow.service.cancel(id);
      final last = await stream.last;
      expect(last.step, ImportStep.cancelled);
      // Well before the slow server would have answered (4 s).
      expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
    });
  });
}
