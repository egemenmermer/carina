import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/repositories/vod_repository.dart';
import 'package:carina/data/tmdb/tmdb_models.dart';
import 'package:carina/features/home_movies/data/vod_meta.dart';
import 'package:carina/features/home_movies/widgets/vod_cards.dart';
import 'package:carina/features/home_movies/widgets/vod_grid.dart';
import 'package:carina/features/home_movies/widgets/vod_hero.dart';

VodItem _item(
  String id, {
  SectionKind kind = SectionKind.movie,
  String? name,
  bool isNew = false,
  bool favorite = false,
  String? backdrop,
  String? poster,
  double? rating,
  int? year,
  String? genre,
  String? plot,
}) => VodItem(
  kind: kind,
  rowId: id.hashCode,
  providerId: id,
  name: name ?? 'Item $id',
  isNew: isNew,
  isFavorite: favorite,
  backdrop: backdrop,
  poster: poster,
  rating: rating,
  year: year,
  genre: genre,
  plot: plot,
);

void main() {
  group('vodDisplayTitle', () {
    test('drops prefixes, years and quality tokens', () {
      expect(vodDisplayTitle('TR: Kış Uykusu'), 'Kış Uykusu');
      expect(vodDisplayTitle('[Altyazılı] Gece'), 'Gece');
      expect(vodDisplayTitle('4K | Dune 4K'), 'Dune');
      expect(vodDisplayTitle('Sıcak Kafa (2022)'), 'Sıcak Kafa');
      expect(vodDisplayTitle('The Thing FHD'), 'The Thing');
      expect(vodDisplayTitle('|TR| Ulusal'), 'Ulusal');
    });

    test('keeps ordinary titles and never returns empty', () {
      expect(vodDisplayTitle('WAR: The Movie'), 'WAR: The Movie');
      expect(vodDisplayTitle('2012'), '2012');
      expect(vodDisplayTitle('HD'), 'HD');
      expect(vodDisplayTitle(''), '');
    });

    test('vodTitleYear reads a trailing year', () {
      expect(vodTitleYear('Film (1999)'), 1999);
      expect(vodTitleYear('Film'), isNull);
    });
  });

  test('vodUpper uses Turkish casing for Turkish text', () {
    expect(vodUpper('Family'), 'FAMILY');
    expect(vodUpper('Bilim Kurgu', turkish: true), 'BİLİM KURGU');
    expect(vodUpper('Aşk ve ılık'), 'AŞK VE ILIK');
    expect(vodLooksTurkish('Sıcak Kafa'), isTrue);
    expect(vodLooksTurkish('Fräulein'), isFalse);
  });

  test('vodCompactCount', () {
    expect(vodCompactCount(950, 'en'), '950');
    expect(vodCompactCount(1500, 'en'), '1.5k');
    expect(vodCompactCount(18000, 'en'), '18k');
    expect(vodCompactCount(1500, 'tr'), isNot(contains('k')));
  });

  group('buildVodMeta', () {
    test('provider data only (no TMDb)', () {
      final meta = buildVodMeta(
        item: _item(
          '1',
          poster: 'p.jpg',
          rating: 7.6,
          year: 2014,
          genre: 'Dram, Komedi',
          plot: 'plot',
        ),
        movie: const MovieDetails(
          providerId: '1',
          name: 'TR: Film',
          backdrops: ['b.jpg'],
          cast: ['A', 'B', 'C'],
          duration: Duration(minutes: 112),
          ageRating: 'PG-13',
          plot: 'details plot',
        ),
      );
      expect(meta.backdropUrl, 'b.jpg');
      expect(meta.posterUrl, 'p.jpg');
      expect(meta.genres, ['Dram', 'Komedi']);
      expect(meta.cast, ['A', 'B', 'C']);
      expect(meta.runtime, const Duration(minutes: 112));
      expect(meta.ageRating, 'PG-13');
      expect(meta.overview, 'details plot');
      expect(meta.votePercent, isNull);
      expect(meta.providerRating, 7.6);
      expect(meta.hasRating, isTrue);
      expect(meta.detailsLoaded, isTrue);
    });

    test('TMDb wins for genres, cast, overview, rating and age; provider '
        'backdrop wins over TMDb', () {
      final meta = buildVodMeta(
        item: _item('2', kind: SectionKind.series, backdrop: 'prov.jpg'),
        series: const SeriesDetails(
          providerId: '2',
          name: 'Show',
          seasons: [],
          genres: ['Dram'],
          plot: 'provider plot',
        ),
        tmdb: const TmdbEnrichment(
          kind: TmdbKind.tv,
          tmdbId: 9,
          backdropUrl: 'tmdb.jpg',
          logoUrl: 'logo.png',
          genres: ['Drama', 'Crime'],
          cast: ['X', 'Y'],
          overview: 'tmdb overview',
          tagline: 'Tag',
          voteAverage: 8.9,
          voteCount: 18000,
          certification: 'TV-MA',
          numberOfSeasons: 5,
          numberOfEpisodes: 62,
        ),
      );
      expect(meta.backdropUrl, 'prov.jpg');
      expect(meta.logoUrl, 'logo.png');
      expect(meta.genres, ['Drama', 'Crime']);
      expect(meta.cast, ['X', 'Y']);
      expect(meta.overview, 'tmdb overview');
      expect(meta.tagline, 'Tag');
      expect(meta.votePercent, 89);
      expect(meta.voteCount, 18000);
      expect(meta.ageRating, 'TV-MA');
      expect(meta.seasonCount, 5);
      expect(meta.episodeCount, 62);
    });

    test('falls back to the TMDb backdrop', () {
      final meta = buildVodMeta(
        item: _item('3'),
        tmdb: const TmdbEnrichment(
          kind: TmdbKind.movie,
          tmdbId: 3,
          backdropUrl: 'tmdb.jpg',
        ),
      );
      expect(meta.backdropUrl, 'tmdb.jpg');
    });
  });

  test('NEW badges', () {
    expect(vodNewBadgeFor(_item('1')), VodNewBadge.none);
    expect(vodNewBadgeFor(_item('1', isNew: true)), VodNewBadge.movie);
    final show = _item('2', kind: SectionKind.series, isNew: true);
    expect(vodNewBadgeFor(show), VodNewBadge.show);
    expect(vodNewBadgeFor(show, knownShow: true), VodNewBadge.episodes);
    expect(
      vodNewBadgeFor(
        _item('3', kind: SectionKind.series, isNew: true, favorite: true),
      ),
      VodNewBadge.episodes,
    );
  });

  test('grid sources', () {
    expect(vodGridCategory('cw'), isNull);
    expect(vodGridCategory('p:12'), const ProviderCategory('12'));
    expect(vodGridCategory('fav'), const FavoritesCategory());
    expect(vodGridCategory('recent'), const RecentlyAddedCategory());
    expect(vodGridCategory('1234'), const ProviderCategory('1234'));
  });

  group('VodHeroController', () {
    testWidgets('rotates, previews after a dwell, holds and wraps', (
      tester,
    ) async {
      final c = VodHeroController();
      final items = [_item('a'), _item('b'), _item('c')];
      c.setCandidates(items);
      expect(c.current?.providerId, 'a');
      await tester.pump(const Duration(seconds: 10));
      expect(c.current?.providerId, 'b');

      c.preview(_item('x'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(c.current?.providerId, 'b');
      await tester.pump(const Duration(milliseconds: 150));
      expect(c.current?.providerId, 'x');

      // The interval restarts after a preview; holding pauses it.
      c.hold();
      await tester.pump(const Duration(seconds: 25));
      expect(c.current?.providerId, 'x');
      c.release();
      await tester.pump(const Duration(seconds: 10));
      // Continues after the last candidate index (b → c).
      expect(c.current?.providerId, 'c');
      await tester.pump(const Duration(seconds: 10));
      expect(c.current?.providerId, 'a');
      c.dispose();
    });

    testWidgets('does not rotate when auto-rotate is off or vetoed', (
      tester,
    ) async {
      final c = VodHeroController();
      c.setCandidates([_item('a'), _item('b')]);
      c.autoRotate = false;
      await tester.pump(const Duration(seconds: 30));
      expect(c.current?.providerId, 'a');
      c.autoRotate = true;
      var allowed = false;
      c.canRotate = () => allowed;
      await tester.pump(const Duration(seconds: 30));
      expect(c.current?.providerId, 'a');
      allowed = true;
      await tester.pump(const Duration(seconds: 10));
      expect(c.current?.providerId, 'b');
      c.dispose();
    });

    testWidgets('keeps the current item when candidates reload', (
      tester,
    ) async {
      final c = VodHeroController();
      c.setCandidates([_item('a'), _item('b')]);
      c.next();
      expect(c.current?.providerId, 'b');
      c.setCandidates([_item('c'), _item('b')]);
      expect(c.current?.providerId, 'b');
      c.dispose();
    });
  });
}
