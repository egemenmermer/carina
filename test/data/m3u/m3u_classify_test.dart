import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/sources/m3u/m3u.dart';

void main() {
  group('classifyM3u', () {
    test('/movie/ in the path is a movie', () {
      expect(
        classifyM3u('http://example.com/movie/kanal/test123/3001.mkv', -1),
        M3uKind.movie,
      );
      expect(
        classifyM3u('http://example.com/MOVIE/kanal/test123/3001.mp4', -1),
        M3uKind.movie,
      );
    });

    test('/series/ in the path is an episode', () {
      expect(
        classifyM3u('http://example.com/series/kanal/test123/9001.mkv', -1),
        M3uKind.episode,
      );
    });

    test('mp4, mkv, avi and mov with a positive duration are movies', () {
      for (final ext in ['mp4', 'mkv', 'avi', 'mov', 'MP4']) {
        expect(
          classifyM3u('http://example.com/vod/film.$ext', 5400),
          M3uKind.movie,
          reason: ext,
        );
      }
    });

    test('movie extensions without a positive duration are live', () {
      expect(classifyM3u('http://example.com/vod/film.mp4', -1), M3uKind.live);
      expect(classifyM3u('http://example.com/vod/film.mkv', 0), M3uKind.live);
    });

    test('other extensions are live even with a duration', () {
      expect(classifyM3u('http://example.com/a.ts', 3600), M3uKind.live);
      expect(classifyM3u('http://example.com/a.m3u8', 3600), M3uKind.live);
      expect(classifyM3u('http://example.com/a.mp4x', 3600), M3uKind.live);
    });

    test('query strings and fragments are ignored', () {
      expect(
        classifyM3u('http://example.com/film.mp4?token=a.ts', 100),
        M3uKind.movie,
      );
      expect(
        classifyM3u('http://example.com/live.ts?next=/movie/x', 100),
        M3uKind.live,
      );
      expect(
        classifyM3u('http://example.com/dir.mkv/stream#frag', 100),
        M3uKind.live,
      );
    });
  });

  group('parseSeriesMarker', () {
    test('S01E02', () {
      final m = parseSeriesMarker('Breaking Bad S05E14')!;
      expect(m.seriesName, 'Breaking Bad');
      expect(m.season, 5);
      expect(m.episode, 14);
      expect(m.episodeTitle, isNull);
    });

    test('S01 E02 (Xtream export style)', () {
      final m = parseSeriesMarker('Sıcak Kafa S01 E02')!;
      expect(m.seriesName, 'Sıcak Kafa');
      expect(m.season, 1);
      expect(m.episode, 2);
    });

    test('S1 E2 and lower case s1e2', () {
      expect(parseSeriesMarker('Show S1 E2')!.episode, 2);
      final m = parseSeriesMarker('show s1e12')!;
      expect(m.seriesName, 'show');
      expect(m.season, 1);
      expect(m.episode, 12);
    });

    test('1x02', () {
      final m = parseSeriesMarker('The Office 2x05')!;
      expect(m.seriesName, 'The Office');
      expect(m.season, 2);
      expect(m.episode, 5);
    });

    test('separators around the marker are stripped', () {
      final a = parseSeriesMarker('Dark - S02E03 - Lost and Found')!;
      expect(a.seriesName, 'Dark');
      expect(a.episodeTitle, 'Lost and Found');
      final b = parseSeriesMarker('The Office (US) (S01E01)')!;
      expect(b.seriesName, 'The Office (US)');
      expect(b.episodeTitle, isNull);
      final c = parseSeriesMarker('Show | S01.E02: Pilot')!;
      expect(c.seriesName, 'Show');
      expect(c.episodeTitle, 'Pilot');
    });

    test('a marker at the start uses the rest as the series name', () {
      final m = parseSeriesMarker('S03E04 Mystery Show')!;
      expect(m.seriesName, 'Mystery Show');
      expect(m.episodeTitle, isNull);
    });

    test('no marker, resolutions and words are not markers', () {
      expect(parseSeriesMarker('Movie 1920x1080 HD'), isNull);
      expect(parseSeriesMarker('ASE01E02'), isNull);
      expect(parseSeriesMarker('Plain Name'), isNull);
    });
  });

  group('parser classification', () {
    test('Xtream export entries become movies and episodes', () {
      final r = parseM3u(
        '#EXTM3U\n'
        '#EXTINF:-1 tvg-name="Kış Uykusu" group-title="Filmler",Kış Uykusu\n'
        'http://example.com/movie/kanal/test123/3001.mkv\n'
        '#EXTINF:-1 tvg-name="Sıcak Kafa S01 E02" group-title="Diziler",'
        'Sıcak Kafa S01 E02\n'
        'http://example.com/series/kanal/test123/9002.mp4\n'
        '#EXTINF:-1,TRT 1 HD\n'
        'http://example.com/live/kanal/test123/1001.ts\n',
      );
      expect(r.entries.map((e) => e.kind), [
        M3uKind.movie,
        M3uKind.episode,
        M3uKind.live,
      ]);
      final ep = r.entries[1];
      expect(ep.seriesName, 'Sıcak Kafa');
      expect(ep.season, 1);
      expect(ep.episode, 2);
      expect(ep.name, 'Sıcak Kafa S01 E02');
      expect(r.entries[0].seriesName, isNull);
      expect(r.entries[2].seriesName, isNull);
    });

    test('a movie extension with a duration is a movie', () {
      final e = parseM3u('#EXTINF:7200,Film\nhttp://example.com/vod/film.mkv')
          .entries
          .single;
      expect(e.kind, M3uKind.movie);
      expect(e.duration, 7200);
    });

    test('the series marker falls back to tvg-name', () {
      final e = parseM3u(
        '#EXTINF:-1 tvg-name="Dizi S02E07",Bölüm 7\n'
        'http://example.com/series/u/p/1.mkv',
      ).entries.single;
      expect(e.seriesName, 'Dizi');
      expect(e.season, 2);
      expect(e.episode, 7);
    });

    test('an episode without a marker keeps its name as the series name', () {
      final e = parseM3u(
        '#EXTINF:-1,Special Documentary\nhttp://example.com/series/u/p/2.mkv',
      ).entries.single;
      expect(e.kind, M3uKind.episode);
      expect(e.seriesName, 'Special Documentary');
      expect(e.season, isNull);
      expect(e.episode, isNull);
    });
  });
}
