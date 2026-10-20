import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/db/tables.dart';
import 'package:carina/data/import/content_writer.dart';
import 'package:carina/data/import/import.dart';
import 'package:carina/data/import/import_rows.dart';
import 'package:carina/data/import/m3u_importer.dart';
import 'package:carina/data/import/xtream_importer.dart';
import 'package:carina/data/sources/m3u/m3u.dart';
import 'package:carina/data/sources/source_exception.dart';
import 'package:carina/data/sources/xtream/xtream.dart';

void main() {
  group('ImportProgress', () {
    ImportProgress progress(
      ImportStep step, {
      ImportStep? failedStep,
      Set<ImportStep> skipped = const {},
    }) => ImportProgress(
      playlistId: 1,
      scope: ImportScope.all,
      step: step,
      plannedSteps: [
        ...ImportStep.contentSteps,
        ...ImportStep.epgSteps.where((s) => !skipped.contains(s)),
        ImportStep.completed,
      ],
      skippedSteps: skipped,
      failedStep: failedStep,
    );

    test('running step: done / active / pending', () {
      final p = progress(ImportStep.movies);
      expect(p.statusOf(ImportStep.connecting), ImportStepStatus.done);
      expect(p.statusOf(ImportStep.liveChannels), ImportStepStatus.done);
      expect(p.statusOf(ImportStep.movies), ImportStepStatus.active);
      expect(p.statusOf(ImportStep.series), ImportStepStatus.pending);
      expect(p.statusOf(ImportStep.completed), ImportStepStatus.pending);
      expect(p.stepIndex, 3);
      expect(p.isTerminal, isFalse);
    });

    test('overall fraction', () {
      expect(progress(ImportStep.connecting).fraction, 0);
      expect(progress(ImportStep.series).fraction, closeTo(4 / 8, 1e-9));
      final downloading = progress(ImportStep.epgDownloading)
          .copyWith(receivedBytes: () => 50, totalBytes: () => 100);
      expect(downloading.fraction, closeTo(6.5 / 8, 1e-9));
      expect(progress(ImportStep.completed).fraction, 1);
      final contentOnly = progress(
        ImportStep.movies,
        skipped: ImportStep.epgSteps.toSet(),
      );
      expect(contentOnly.fraction, closeTo(3 / 5, 1e-9));
    });

    test('skipped steps', () {
      final p = progress(
        ImportStep.series,
        skipped: ImportStep.epgSteps.toSet(),
      );
      expect(p.statusOf(ImportStep.epgCleaning), ImportStepStatus.skipped);
      expect(p.statusOf(ImportStep.completed), ImportStepStatus.pending);
    });

    test('failed and cancelled', () {
      final failed = progress(ImportStep.failed, failedStep: ImportStep.movies);
      expect(failed.statusOf(ImportStep.liveChannels), ImportStepStatus.done);
      expect(failed.statusOf(ImportStep.movies), ImportStepStatus.failed);
      expect(failed.statusOf(ImportStep.series), ImportStepStatus.pending);
      expect(failed.stepIndex, 3);
      expect(failed.isFailed, isTrue);
      final cancelled = progress(
        ImportStep.cancelled,
        failedStep: ImportStep.epgDownloading,
      );
      expect(
        cancelled.statusOf(ImportStep.epgDownloading),
        ImportStepStatus.cancelled,
      );
      expect(cancelled.statusOf(ImportStep.series), ImportStepStatus.done);
    });

    test('completed with a failed EPG step', () {
      final p = progress(
        ImportStep.completed,
        failedStep: ImportStep.epgDownloading,
      );
      expect(p.statusOf(ImportStep.series), ImportStepStatus.done);
      expect(p.statusOf(ImportStep.epgCleaning), ImportStepStatus.done);
      expect(p.statusOf(ImportStep.epgDownloading), ImportStepStatus.failed);
      expect(p.statusOf(ImportStep.epgParsing), ImportStepStatus.skipped);
      expect(p.statusOf(ImportStep.completed), ImportStepStatus.done);
    });

    test('byte fraction and helpers', () {
      const p = ImportProgress(
        playlistId: 1,
        scope: ImportScope.epg,
        step: ImportStep.epgDownloading,
        receivedBytes: 50,
        totalBytes: 200,
        warnings: [
          ImportWarning(SourceErrorKind.sectionEmpty, SectionKind.movie),
        ],
      );
      expect(p.byteFraction, 0.25);
      expect(p.copyWith(totalBytes: () => null).byteFraction, isNull);
      expect(p.emptySections, {SectionKind.movie});
      expect(p.toString(), contains('epgDownloading'));
      expect(ImportStep.cancelled.isTerminal, isTrue);
      expect(ImportStep.epgParsing.isEpg, isTrue);
      expect(ImportStep.series.isContent, isTrue);
      expect(ImportScope.epg.includesContent, isFalse);
      expect(ImportScope.content.includesEpg, isFalse);
    });
  });

  group('Xtream rows', () {
    test('channels: quality, archive, direct source, duplicates', () {
      final rows = channelsFromXtream([
        XtreamLiveStream.fromJson({
          'stream_id': '7',
          'name': 'TR: Show TV FHD',
          'num': '3',
          'tv_archive': '1',
          'tv_archive_duration': '5',
          'direct_source': 'relative/junk',
          'stream_icon': '',
          'category_id': 2,
          'epg_channel_id': 'showtv.tr',
        })!,
        XtreamLiveStream.fromJson({'stream_id': 7, 'name': 'Duplicate'})!,
        XtreamLiveStream.fromJson({
          'stream_id': 8,
          'name': '   ',
          'tv_archive': 0,
          'tv_archive_duration': 3,
          'direct_source': 'http://cdn.example/8.ts',
        })!,
      ]);
      expect(rows, hasLength(2));
      final show = rows.first;
      expect(show.displayName, 'TR: Show TV');
      expect(show.quality, 'FHD');
      expect((show.num, show.archiveDays, show.categoryId), (3, 5, '2'));
      expect(show.directSource, isNull);
      expect(show.logo, isNull);
      expect(show.streamUrl, isNull);
      final blank = rows.last;
      expect(blank.displayName, '8');
      expect(blank.archiveDays, 0);
      expect(blank.directSource, 'http://cdn.example/8.ts');
      expect(blank.sortIndex, 1);
    });

    test('series: backdrops JSON, year from release date', () {
      final rows = seriesFromXtream([
        XtreamSeries.fromJson({
          'series_id': 9,
          'name': 'Dizi',
          'releaseDate': '2019-05-01',
          'backdrop_path': ['http://x/1.jpg', 'http://x/2.jpg'],
          'last_modified': '1700000000',
        })!,
        XtreamSeries.fromJson({'series_id': 10, 'name': 'Boş'})!,
      ]);
      expect(rows.first.year, 2019);
      expect(jsonDecode(rows.first.backdropsJson!), [
        'http://x/1.jpg',
        'http://x/2.jpg',
      ]);
      expect(rows.first.lastModified, isNotNull);
      expect(rows.last.backdropsJson, isNull);
    });

    test('categories keep provider order', () {
      final rows = categoriesFromXtream([
        const XtreamCategory(categoryId: '5', categoryName: 'B'),
        const XtreamCategory(categoryId: '1', categoryName: 'A'),
        const XtreamCategory(categoryId: '5', categoryName: 'dup'),
      ], SectionKind.movie);
      expect(rows.map((c) => (c.providerId, c.name, c.sortIndex)), [
        ('5', 'B', 0),
        ('1', 'A', 1),
      ]);
      expect(rows.first.kind, SectionKind.movie);
    });
  });

  group('M3U rows', () {
    M3uContent content(String text, {DateTime? added}) =>
        m3uContentFromResult(parseM3u(text), added: added);

    test('archive days: header defaults and the 7-day default', () {
      final c = content(
        '#EXTM3U catchup="shift" catchup-days="2"\n'
        '#EXTINF:-1,Default Days\nhttp://h/1.ts\n'
        '#EXTINF:-1 catchup-days="4",Own Days\nhttp://h/2.ts\n'
        '#EXTINF:-1 catchup="none",Off\nhttp://h/3.ts\n',
      );
      expect(c.channels.map((ch) => (ch.catchupType, ch.archiveDays)), [
        ('shift', 2),
        ('shift', 4),
        (null, 0),
      ]);
      final noDays = content(
        '#EXTM3U\n#EXTINF:-1 catchup="append" catchup-source="?u={utc}",X\n'
        'http://h/1.ts\n',
      );
      expect(noDays.channels.single.archiveDays, 7);
      expect(noDays.channels.single.catchupSource, '?u={utc}');
    });

    test('duplicates are kept once; ids are stable', () {
      const text =
          '#EXTM3U\n#EXTINF:-1 tvg-id="a" group-title="G1",A\nhttp://h/a.ts\n'
          '#EXTINF:-1 tvg-id="a" group-title="G2",A again\nhttp://h/a.ts\n';
      final c = content(text);
      expect(c.duplicates, 1);
      expect(c.channels.single.categoryId, 'G1');
      expect(c.liveCategories.map((g) => g.providerId), ['G1']);
      expect(
        c.channels.single.providerId,
        content(text).channels.single.providerId,
      );
    });

    test('series grouping, missing markers and stamps', () {
      final added = DateTime.utc(2026, 10, 17);
      final c = content(
        '#EXTM3U\n'
        '#EXTINF:-1 group-title="Diziler",Kuzey S01E01\n'
        'http://h/series/u/p/1.mkv\n'
        '#EXTINF:-1 group-title="Diziler",kuzey S01 E02\n'
        'http://h/series/u/p/2.mkv\n'
        '#EXTINF:-1 group-title="Yeni Dizi",S01E01\n'
        'http://h/series/u/p/3.mp4\n'
        '#EXTINF:-1 group-title="Diziler",Pilot Bölüm\n'
        'http://h/series/u/p/4.mp4\n',
        added: added,
      );
      expect(c.series.map((s) => s.name), [
        'Kuzey',
        'Yeni Dizi',
        'Pilot Bölüm',
      ]);
      expect(c.series.first.providerId, m3uSeriesId('KUZEY'));
      expect(c.episodes.map((e) => (e.season, e.episodeNum)), [
        (1, 1),
        (1, 2),
        (1, 1),
        (1, 1),
      ]);
      expect(c.episodes.every((e) => e.added == added), isTrue);
      expect(c.seasons.map((s) => (s.seriesId, s.episodeCount)), [
        (m3uSeriesId('Kuzey'), 2),
        (m3uSeriesId('Yeni Dizi'), 1),
        (m3uSeriesId('Pilot Bölüm'), 1),
      ]);
      expect(c.seriesCategories.map((g) => g.name), ['Diziler', 'Yeni Dizi']);
    });

    test('helpers', () {
      expect(urlExtension('http://h/movie/u/p/1.MKV?token=1'), 'mkv');
      expect(urlExtension('http://h/live/1'), isNull);
      expect(urlExtension('http://h.example/live/'), isNull);
      expect(yearFromTitle('Kış Uykusu (2014)'), 2014);
      expect(yearFromTitle('Film [1999] TR'), 1999);
      expect(yearFromTitle('Film 2014'), isNull);
      expect(localPathOf('/tmp/a.m3u'), '/tmp/a.m3u');
      expect(localPathOf(r'C:\iptv\a.m3u'), r'C:\iptv\a.m3u');
      expect(
        localPathOf('file:///tmp/a.m3u'),
        Uri.parse('file:///tmp/a.m3u').toFilePath(),
      );
      expect(localPathOf('http://h/a.m3u'), isNull);
      expect(isSeriesMarkerOnly('S01E02'), isTrue);
      expect(isSeriesMarkerOnly('S01 E02'), isTrue);
      expect(isSeriesMarkerOnly('Dizi S01E02'), isFalse);
      expect(isSeriesMarkerOnly('Dizi'), isFalse);
    });
  });

  group('people', () {
    test('peopleFromInfoJson reads actors / cast in several shapes', () {
      expect(peopleFromInfoJson('{"info":{"actors":"A, B"}}'), ['A', 'B']);
      expect(peopleFromInfoJson('{"cast":"C; D , C"}'), ['C', 'D']);
      expect(peopleFromInfoJson('{"info":{"cast":[{"name":"D"},"E, F"]}}'), [
        'D',
        'E',
        'F',
      ]);
      expect(peopleFromInfoJson('not json'), isEmpty);
      expect(peopleFromInfoJson('[1,2]'), isEmpty);
    });
  });

  test('channelDisplayName never returns an empty name', () {
    expect(channelDisplayName('HD', fallback: '9').displayName, 'HD');
    expect(channelDisplayName('', fallback: '9').displayName, '9');
    expect(channelDisplayName('Show TV HD', fallback: '9').quality, 'HD');
  });
}
