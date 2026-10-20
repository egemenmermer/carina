import 'package:flutter_test/flutter_test.dart';

import '../../tools/mock_server/src/catalog.dart';

String _digest(MockCatalog c) => [
  for (final ch in c.channels)
    '${ch.streamId}|${ch.name}|${ch.categoryId}|${ch.epgChannelId}|${ch.variant.name}|${ch.archiveDays}',
  for (final m in c.movies)
    '${m.streamId}|${m.name}|${m.year}|${m.rating}|${m.containerExtension}',
  for (final s in c.series)
    '${s.seriesId}|${s.name}|${s.seasons.map((x) => '${x.number}:${x.episodeCount}').join(',')}',
  for (final e in c.epgChannels) '${e.id}|${e.displayNames.join('/')}',
].join('\n');

void main() {
  final now = DateTime.now().toUtc();
  final small = MockCatalog.generate(MockScale.small, now: now);

  group('MockCatalog.generate(small)', () {
    test('has the exact small counts', () {
      expect(small.channels, hasLength(300));
      expect(small.movies, hasLength(2000));
      expect(small.series, hasLength(200));
      expect(small.channels.map((c) => c.streamId).toSet(), hasLength(300));
      expect(small.movies.map((m) => m.streamId).toSet(), hasLength(2000));
      expect(small.series.map((s) => s.seriesId).toSet(), hasLength(200));
    });

    test('is deterministic', () {
      final again = MockCatalog.generate(MockScale.small, now: now);
      expect(_digest(again), _digest(small));
      // A different day only moves timestamps, not content.
      final later = MockCatalog.generate(
        MockScale.small,
        now: now.add(const Duration(days: 3)),
      );
      expect(_digest(later), _digest(small));
    });

    test('contains the contract fixtures (ARCHITECTURE.md section 4)', () {
      MockChannel live(int id) => small.channelById(id)!;
      final ulusal = small.liveCategories.firstWhere(
        (c) => c.name == 'TR | Ulusal',
      );
      expect(ulusal.id, MockFixtures.ulusalCategoryId);

      expect(live(1001).name, 'TRT 1 HD');
      expect(live(1001).categoryId, ulusal.id);
      expect(live(1001).archiveDays, 3);
      expect(live(1001).variant, LiveVariant.h264Aac1080p25);
      expect(live(1002).name, 'Show TV FHD');
      expect(live(1002).variant, LiveVariant.h264Ac351080p25);
      expect(live(1003).name, 'UHD Test 4K');
      expect(live(1003).variant, LiveVariant.hevcEac32160p25);
      expect(live(1004).name, 'Kanal D SD');
      expect(live(1004).variant, LiveVariant.mpeg2Mp2576i25);
      expect(live(1005).name, 'Haber Canlı HLS');
      expect(live(1005).variant, LiveVariant.hls);
      expect(live(1006).name, 'Çocuk Kilitli');

      final movie = small.movieById(3001)!;
      expect(movie.name, 'Kış Uykusu');
      expect(movie.containerExtension, 'mkv');
      expect(movie.mediaFile, MockMedia.vodTracksMkv);

      final series = small.seriesById(5001)!;
      expect(series.name, 'Sıcak Kafa');
      expect(series.seasons.map((s) => s.number), [1, 2]);
      final episodes = small.episodesOf(series);
      expect(episodes.first.id, MockFixtures.episodeId(5001, 1, 1));
      expect(episodes.first.mediaFile, MockMedia.vodTracksMkv);
      expect(episodes.map((e) => e.mediaFile).toSet(), {
        MockMedia.vodTracksMkv,
        MockMedia.h264Aac720p50Mp4,
      });
    });

    test('has the extra test fixtures', () {
      expect(
        small.channelById(MockFixtures.dropAfter10s)!.behavior,
        LiveBehavior.dropAfter,
      );
      for (final id in MockFixtures.notFoundLiveIds) {
        expect(small.channelById(id)!.behavior, LiveBehavior.notFound);
      }
      expect(small.channelById(MockFixtures.trtHaberHd)!.archiveDays, 7);
      final showNames = small.channels
          .where((c) => c.baseName == 'Show TV')
          .map((c) => c.name);
      expect(
        showNames,
        containsAll(['Show TV HD', 'Show TV FHD', 'Show TV SD']),
      );
      expect(
        small.seriesById(MockFixtures.geceYarisi)!.shape,
        EpisodesShape.list,
      );
      expect(
        small.seriesById(MockFixtures.geceYarisi)!.seasons.first.number,
        0,
      );
      expect(
        small
            .seriesById(MockFixtures.maviKapi)!
            .hasQuirk(SeriesQuirk.seasonsEmpty),
        isTrue,
      );
    });

    test('names are realistic: prefixes, quality tokens, diacritics', () {
      final names = small.channels.map((c) => c.name).join('\n');
      for (final prefix in [
        'TR: ',
        'TR | ',
        '|TR| ',
        'UK: ',
        'IT | ',
        'DE: ',
      ]) {
        expect(names, contains(prefix), reason: prefix);
      }
      for (final token in ['SD', 'HD', 'FHD', '4K', 'H265', 'HEVC', '50FPS']) {
        expect(
          RegExp('(^| )$token( |\$)', multiLine: true).hasMatch(names),
          isTrue,
          reason: token,
        );
      }
      final everything = [
        names,
        ...small.movies.map((m) => m.name),
        ...small.series.map((s) => s.name),
      ].join(' ');
      for (final ch in ['ş', 'ğ', 'ı', 'İ', 'ö', 'ü', 'ç', 'ä', 'à']) {
        expect(everything, contains(ch), reason: ch);
      }
    });

    test('categories cover the expected names', () {
      final live = small.liveCategories.map((c) => c.name);
      expect(
        live,
        containsAll([
          'TR | Ulusal',
          'TR | Spor',
          'TR | Haber',
          'TR | Belgesel',
          'TR | Çocuk', //
          'IT | Top Italia', 'UK | Entertainment', 'DE | Filme',
        ]),
      );
      expect(
        small.vodCategories.map((c) => c.name),
        containsAll(['Aksiyon', 'Komedi', 'Dram', 'Bilim Kurgu', 'Belgesel']),
      );
      expect(
        small.seriesCategories.map((c) => c.name),
        containsAll(['Yerli Diziler', 'Netflix Series']),
      );
    });

    test('includes missing logos and broken entries', () {
      final missing = small.channels.where((c) => c.logoPath == null).length;
      expect(missing / small.channels.length, inInclusiveRange(0.08, 0.22));
      expect(small.channels.any((c) => c.name.isEmpty), isTrue);
      expect(small.channels.any((c) => c.name != c.name.trim()), isTrue);
      expect(small.channels.any((c) => c.categoryId == null), isTrue);
      expect(
        small.channels.any((c) => c.categoryId == '9999'),
        isTrue,
        reason: 'orphan category',
      );
      expect(
        small.channels.any((c) => c.hasQuirk(ChannelQuirk.numAsString)),
        isTrue,
      );
      expect(
        small.channels.any((c) => c.hasQuirk(ChannelQuirk.idAsString)),
        isTrue,
      );
      expect(
        small.channels.any(
          (c) => c.logoPath == null && c.hasQuirk(ChannelQuirk.logoNull),
        ),
        isTrue,
      );
      expect(
        small.channels.any((c) => c.hasQuirk(ChannelQuirk.separator)),
        isTrue,
      );
      expect(small.movies.any((m) => m.name.isEmpty), isTrue);
      expect(
        small.movies.any((m) => m.hasQuirk(MovieQuirk.ratingEmpty)),
        isTrue,
      );
      expect(small.series.any((s) => s.name.isEmpty), isTrue);
    });

    test('added timestamps: last 60 days, ~5 % in the last 7 days', () {
      final all = [
        ...small.channels.map((c) => c.added),
        ...small.movies.map((m) => m.added),
        ...small.series.map((s) => s.lastModified),
      ];
      for (final d in all) {
        expect(d.isAfter(now.subtract(const Duration(days: 61))), isTrue);
        expect(d.isBefore(now.add(const Duration(minutes: 1))), isTrue);
      }
      final recent = all
          .where((d) => now.difference(d) < const Duration(days: 7))
          .length;
      expect(recent / all.length, inInclusiveRange(0.02, 0.09));
    });

    test('archive channels use 3 or 7 days and every catch-up mode', () {
      final archive = small.channels.where((c) => c.hasArchive).toList();
      expect(archive.length, greaterThan(5));
      expect(archive.map((c) => c.archiveDays).toSet(), {3, 7});
      expect(
        archive.map((c) => c.catchupMode).toSet(),
        containsAll(['default', 'append', 'shift', 'flussonic', 'xc']),
      );
    });

    test(
      'EPG ids: mostly exact, ~10 % name-only, a few case-only and none',
      () {
        final count = <EpgMatchKind, int>{};
        for (final c in small.channels) {
          count[c.epgMatch] = (count[c.epgMatch] ?? 0) + 1;
        }
        final total = small.channels.length;
        expect(count[EpgMatchKind.exact]! / total, greaterThan(0.6));
        expect(
          count[EpgMatchKind.nameOnly]! / total,
          inInclusiveRange(0.05, 0.16),
        );
        expect(count[EpgMatchKind.caseInsensitive], greaterThan(0));
        expect(count[EpgMatchKind.none], greaterThan(0));
        final xmltvIds = small.epgChannels.map((e) => e.id).toSet();
        for (final c in small.channels) {
          switch (c.epgMatch) {
            case EpgMatchKind.exact:
              expect(xmltvIds, contains(c.epgChannelId));
            case EpgMatchKind.caseInsensitive:
              expect(xmltvIds, isNot(contains(c.epgChannelId)));
              expect(xmltvIds, contains(c.epgChannelId!.toLowerCase()));
            case EpgMatchKind.nameOnly:
              expect(xmltvIds, isNot(contains(c.epgChannelId)));
              final guide = small.epgChannelById(c.xmltvId!)!;
              expect(
                guide.displayNames.map(channelKey),
                contains(channelKey(c.name)),
                reason: '${c.name} must match by normalized name',
              );
            case EpgMatchKind.none:
              expect(c.xmltvId, isNull);
          }
        }
      },
    );

    test('movies and series carry metadata', () {
      expect(
        small.movies.where((m) => m.tmdbId != null).length,
        greaterThan(500),
      );
      expect(
        small.movies.map((m) => m.containerExtension.toLowerCase()).toSet(),
        {'mkv', 'mp4'},
      );
      for (final s in small.series) {
        final regular = s.seasons.where((x) => x.number > 0).toList();
        expect(regular.length, inInclusiveRange(1, 5));
        for (final season in regular) {
          if (MockFixtures.fixtureSeriesIds.contains(s.seriesId)) continue;
          expect(season.episodeCount, inInclusiveRange(4, 10));
        }
      }
      expect(
        small.series.where((s) => s.seasons.first.number == 0).length,
        greaterThan(3),
      );
      expect(
        small.series.where((s) => s.shape == EpisodesShape.list).length,
        greaterThan(3),
      );
      expect(
        small.series.where((s) => s.shape == EpisodesShape.map).length,
        greaterThan(100),
      );
    });

    test('a shared actor appears in several titles', () {
      bool has(List<String> cast) => cast.contains(MockFixtures.sharedActor);
      final titles =
          small.movies.where((m) => has(m.cast)).length +
          small.series.where((s) => has(s.cast)).length;
      expect(titles, inInclusiveRange(3, 60));
      expect(has(small.movieById(3001)!.cast), isTrue);
      expect(has(small.seriesById(5001)!.cast), isTrue);
    });

    test('episodes resolve by id', () {
      final ids = <int>[];
      for (final s in small.series) {
        final eps = small.episodesOf(s);
        expect(eps.length, s.episodeTotal);
        for (final e in eps) {
          final found = small.episodeById(e.id)!;
          expect(found.series.seriesId, s.seriesId);
          expect(found.season, e.season);
          expect(found.episode, e.episode);
          ids.add(e.id);
        }
      }
      expect(ids.toSet(), hasLength(ids.length));
      expect(small.episodeById(42), isNull);
      expect(small.episodeById(MockFixtures.episodeId(5001, 9, 1)), isNull);
    });
  });

  test('channelKey approximates the app normalizer', () {
    expect(channelKey('TR: Show TV SD'), 'showtv');
    expect(channelKey('|TR| Habertürk HD'), 'haberturk');
    expect(channelKey('[TR] İZMİR TV FHD 50FPS'), 'izmirtv');
    expect(channelKey('UK: BBC One HD'), 'bbcone');
    expect(channelKey('Kanal D'), 'kanald');
  });
}
