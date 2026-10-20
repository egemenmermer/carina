import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/net/dio_factory.dart';
import 'package:carina/data/repositories/favorites_repository.dart';
import 'package:carina/data/repositories/vod_repository.dart';
import 'package:carina/data/repositories/watch_state_repository.dart';
import 'package:carina/data/settings/settings_store.dart';
import 'package:carina/data/sources/source_exception.dart';
import 'package:carina/data/sources/xtream/xtream.dart';

import '../../net/test_http_server.dart';
import 'r2_fixtures.dart';

Map<String, Object?> vodInfoJson() => {
  'info': {
    'tmdb_id': '12345',
    'name': 'Kış Uykusu',
    'o_name': 'Winter Sleep',
    'cover_big': 'http://img.test/kis.jpg',
    'movie_image': 'http://img.test/kis.jpg',
    'backdrop_path': [
      'http://img.test/kis_bd1.jpg',
      'http://img.test/kis_bd2.jpg',
    ],
    'releasedate': '2014-06-13',
    'youtube_trailer': 'abc123',
    'director': 'Nuri Bilge Ceylan',
    'actors': 'Haluk Bilginer, Melisa Sözen, Demet Akbağ',
    'cast': 'Haluk Bilginer, Melisa Sözen, Demet Akbağ',
    'description': 'Aydın, a former actor, runs a hotel.',
    'plot': 'Plot fallback',
    'genre': 'Dram / Drama, Komedi',
    'age': '16+',
    'mpaa_rating': 'PG-13',
    'country': 'Türkiye',
    'duration_secs': 11760,
    'duration': '03:16:00',
    'rating': '8.1',
    'video': {
      'codec_name': 'h264',
      'width': 1920,
      'height': 1080,
      'avg_frame_rate': '25/1',
      'bit_rate': '4500000',
    },
    'audio': {
      'codec_name': 'ac3',
      'channels': 6,
      'channel_layout': '5.1(side)',
    },
    'bitrate': 4800,
  },
  'movie_data': {
    'stream_id': 3001,
    'name': 'Kış Uykusu',
    'added': '1760000000',
    'category_id': '10',
    'container_extension': 'mkv',
  },
};

Map<String, Object?> episodeJson(
  String id,
  int season,
  int num,
  String title,
) => {
  'id': id,
  'episode_num': num,
  'title': title,
  'container_extension': 'mp4',
  'season': season,
  'added': '1760000000',
  'info': {
    'plot': 'Plot of $title',
    'duration_secs': 2700,
    'releasedate': '2022-03-0$num',
    'movie_image': 'http://img.test/$id.jpg',
    'rating': '7',
  },
};

/// `get_series_info` for series 5001. [asList] sends `episodes` as a list of
/// per-season lists instead of a map; [variant] 2 drops S1E1 and adds S2E2.
Map<String, Object?> seriesInfoJson({bool asList = false, int variant = 1}) {
  final s0 = [episodeJson('50001', 0, 1, 'Kamera Arkası')];
  final s1 = [
    if (variant == 1) episodeJson('50011', 1, 1, 'Pilot'),
    episodeJson('50012', 1, 2, 'İkinci Gün'),
  ];
  final s2 = [
    episodeJson('50021', 2, 1, 'Dönüş'),
    if (variant == 2) episodeJson('50022', 2, 2, 'Final'),
  ];
  return {
    'seasons': [
      {'season_number': 0, 'name': 'Özel Bölümler', 'episode_count': 1},
      {
        'season_number': 1,
        'name': 'Sezon 1',
        'episode_count': 2,
        'air_date': '2022-03-01',
      },
      {'season_number': 2, 'name': 'Sezon 2', 'episode_count': 1},
    ],
    'info': {
      'name': 'Sıcak Kafa',
      'cover': 'http://img.test/sk.jpg',
      'plot': 'Bir virüs İstanbul’u sarar.',
      'cast': 'Ekin Koç, Nilperi Şahinkaya',
      'director': 'Mehmet Ada Öztekin',
      'genre': 'Bilim Kurgu, Gerilim',
      'releaseDate': '2022-03-01',
      'rating': '7.4',
      'backdrop_path': ['http://img.test/sk_bd.jpg'],
      'episode_run_time': '45',
      'tmdb': '98765',
    },
    'episodes': asList ? [s0, s1, s2] : {'0': s0, '1': s1, '2': s2},
  };
}

void main() {
  late R2Env env;
  late VodRepository repo;
  late int pid;

  VodRepository makeRepo() => VodRepository(
    db: env.db,
    settings: env.settings,
    secrets: env.secrets,
    clock: env.clock,
    dioFactory: (_) => createDio(retryDelay: const Duration(milliseconds: 5)),
  );

  setUp(() async {
    env = await R2Env.create();
    repo = makeRepo();
    pid = await env.playlist(server: 'http://127.0.0.1:1');
  });

  tearDown(() async {
    repo.dispose();
    await env.close();
  });

  group('lists', () {
    setUp(() async {
      await env.category(pid, SectionKind.movie, '10', 'Dram', sortIndex: 0);
      await env.category(pid, SectionKind.movie, '20', 'Gizli', hidden: true);
      final now = env.now;
      await env.movie(
        pid,
        'm1',
        'Zebra',
        categoryId: '10',
        sortIndex: 0,
        rating: 6,
        year: 2001,
        added: now.subtract(const Duration(days: 30)),
      );
      await env.movie(
        pid,
        'm2',
        'Çılgın Dersane',
        categoryId: '10',
        sortIndex: 1,
        rating: 8.5,
        year: 2007,
        added: now.subtract(const Duration(days: 2)),
      );
      await env.movie(
        pid,
        'm3',
        'Sıcak Kafa Film',
        categoryId: '10',
        sortIndex: 2,
        year: 2022,
        added: now.subtract(const Duration(days: 1)),
      );
      await env.movie(pid, 'm4', 'Ayı', categoryId: '10', sortIndex: 3);
      await env.movie(
        pid,
        'm5',
        'İstanbul Hatırası',
        categoryId: '10',
        sortIndex: 4,
        rating: 7,
      );
      await env.movie(
        pid,
        'm6',
        'Gizli Film',
        categoryId: '20',
        sortIndex: 5,
        added: now,
      );
      await env.movie(
        pid,
        'm7',
        'Saklı',
        categoryId: '10',
        sortIndex: 6,
        hidden: true,
        added: now,
      );
    });

    Future<List<String>> ids(Stream<List<VodItem>> s) async =>
        (await s.first).map((i) => i.providerId).toList();

    test('playlist order hides hidden items and hidden categories', () async {
      expect(await ids(repo.watchMovies(pid)), ['m1', 'm2', 'm3', 'm4', 'm5']);
      // An explicitly opened category is listed even when hidden.
      expect(await ids(repo.watchMovies(pid, categoryId: '20')), ['m6']);
      expect(await ids(repo.watchMovies(pid, categoryId: '10')), [
        'm1',
        'm2',
        'm3',
        'm4',
        'm5',
      ]);
    });

    test('sorts by name (Turkish-aware), date, rating and year', () async {
      expect(await ids(repo.watchMovies(pid, sort: VodSort.name)), [
        'm4', // Ayı
        'm2', // Çılgın Dersane
        'm5', // İstanbul Hatırası
        'm3', // Sıcak Kafa Film
        'm1', // Zebra
      ]);
      expect(await ids(repo.watchMovies(pid, sort: VodSort.dateAdded)), [
        'm3',
        'm2',
        'm1',
        'm4',
        'm5',
      ]);
      expect(await ids(repo.watchMovies(pid, sort: VodSort.rating)), [
        'm2',
        'm5',
        'm1',
        'm3',
        'm4',
      ]);
      expect(await ids(repo.watchMovies(pid, sort: VodSort.year)), [
        'm3',
        'm2',
        'm1',
        'm4',
        'm5',
      ]);
    });

    test(
      'name sort follows the app collation (Turkish alphabet, numbers)',
      () async {
        await env.category(pid, SectionKind.movie, 'n', 'Sıra');
        for (final (id, name) in [
          ('n1', 'Çocuk'),
          ('n2', 'Cuma'),
          ('n3', 'Film 10'),
          ('n4', 'Film 2'),
          ('n5', 'Işık'),
          ('n6', 'İnci'),
        ]) {
          await env.movie(pid, id, name, categoryId: 'n');
        }
        Future<List<String>> names() async => [
          for (final i
              in await repo
                  .watchMovies(pid, categoryId: 'n', sort: VodSort.name)
                  .first)
            i.name,
        ];
        await env.settings.set(AppSettings.language, 'tr');
        expect(await names(), [
          'Cuma',
          'Çocuk',
          'Film 2',
          'Film 10',
          'Işık',
          'İnci',
        ]);
        await env.settings.set(AppSettings.language, 'en');
        expect(await names(), [
          'Çocuk',
          'Cuma',
          'Film 2',
          'Film 10',
          'İnci',
          'Işık',
        ]);
      },
    );

    test('filter is normalized and every term must match', () async {
      expect(await ids(repo.watchMovies(pid, filter: 'sicak')), ['m3']);
      expect(await ids(repo.watchMovies(pid, filter: 'KAFA sıc')), ['m3']);
      expect(await ids(repo.watchMovies(pid, filter: 'istanbul')), ['m5']);
      expect(await ids(repo.watchMovies(pid, filter: 'cilgin')), ['m2']);
      expect(await ids(repo.watchMovies(pid, filter: 'yok')), isEmpty);
      // Blank or quality-only filters do not filter.
      expect(await ids(repo.watchMovies(pid, filter: ' FHD ')), hasLength(5));
      expect(
        await ids(
          repo.watchMovies(pid, filter: 'a', sort: VodSort.name, limit: 2),
        ),
        ['m4', 'm2'],
      );
      expect(await ids(repo.watchMovies(pid, limit: 2)), ['m1', 'm2']);
    });

    test(
      'excludeLocked drops locked categories from aggregated lists',
      () async {
        await env.category(
          pid,
          SectionKind.movie,
          '30',
          'Yetişkin',
          locked: true,
        );
        await env.movie(pid, 'm8', 'Kilitli', categoryId: '30', sortIndex: 7);
        expect(await ids(repo.watchMovies(pid)), contains('m8'));
        expect(
          await ids(repo.watchMovies(pid, excludeLocked: true)),
          isNot(contains('m8')),
        );
      },
    );

    test('recently added uses a 7-day window and NEW flags', () async {
      final recent = await repo.watchRecentlyAddedMovies(pid).first;
      expect(recent.map((i) => i.providerId), ['m3', 'm2']);
      expect(recent.every((i) => i.isNew), isTrue);
      final all = await repo.watchMovies(pid).first;
      expect(all.firstWhere((i) => i.providerId == 'm1').isNew, isFalse);
      expect(
        (await repo.watchRecentlyAddedMovies(pid, days: 60).first).map(
          (i) => i.providerId,
        ),
        ['m3', 'm2', 'm1'],
      );
    });

    test('series use lastModified for date sort, recent and NEW', () async {
      await env.category(pid, SectionKind.series, 's', 'Diziler');
      await env.series(
        pid,
        '5001',
        'Sıcak Kafa',
        categoryId: 's',
        lastModified: env.now.subtract(const Duration(days: 3)),
        sortIndex: 1,
        backdrops: ['http://img.test/bd.jpg'],
        plot: 'Plot',
      );
      await env.series(
        pid,
        '5002',
        'Avlu',
        categoryId: 's',
        lastModified: env.now.subtract(const Duration(days: 20)),
        sortIndex: 0,
      );
      expect(await ids(repo.watchSeries(pid)), ['5002', '5001']);
      expect(await ids(repo.watchSeries(pid, sort: VodSort.dateAdded)), [
        '5001',
        '5002',
      ]);
      final recent = await repo.watchRecentlyAddedSeries(pid).first;
      expect(recent.map((i) => i.providerId), ['5001']);
      expect(recent.single.isNew, isTrue);
      expect(recent.single.backdrop, 'http://img.test/bd.jpg');
      expect(recent.single.plot, 'Plot');
      expect(recent.single.itemType, ItemType.series);
    });

    test('isNew accepts cards and rows', () async {
      final rows = await env.db.select(env.db.movies).get();
      final m2 = rows.firstWhere((r) => r.providerId == 'm2');
      final m1 = rows.firstWhere((r) => r.providerId == 'm1');
      expect(repo.isNew(m2), isTrue);
      expect(repo.isNew(m1), isFalse);
      final sid = await env.series(
        pid,
        's1',
        'S',
        lastModified: env.now.subtract(const Duration(days: 6)),
      );
      final s = await (env.db.select(
        env.db.series,
      )..where((x) => x.id.equals(sid))).getSingle();
      expect(repo.isNew(s), isTrue);
      env.now = env.now.add(const Duration(days: 2));
      expect(repo.isNew(s), isFalse);
      expect(() => repo.isNew('nope'), throwsArgumentError);
    });

    test('rows update when favorites and watch state change', () async {
      final favorites = FavoritesRepository(db: env.db, clock: env.clock);
      final watch = WatchStateRepository(db: env.db, clock: env.clock);
      final emissions = Emissions(repo.watchMovies(pid));
      final first = await emissions.next();
      expect(first.firstWhere((i) => i.providerId == 'm2').isFavorite, isFalse);

      await favorites.toggle(pid, ItemType.movie, 'm2');
      final afterFavorite = await emissions.next(
        (l) => l.firstWhere((i) => i.providerId == 'm2').isFavorite,
      );
      expect(afterFavorite, isNotEmpty);

      await watch.save(
        pid,
        ItemType.movie,
        'm2',
        const Duration(minutes: 30),
        const Duration(minutes: 100),
      );
      final afterWatch = await emissions.next(
        (l) => l.firstWhere((i) => i.providerId == 'm2').inProgress,
      );
      final m2 = afterWatch.firstWhere((i) => i.providerId == 'm2');
      expect(m2.progress, closeTo(0.3, 0.001));

      await repo.setHidden(pid, SectionKind.movie, 'm2', true);
      await emissions.next((l) => l.every((i) => i.providerId != 'm2'));
      await emissions.cancel();
    });

    test('hidden items can be listed and unhidden', () async {
      await repo.setHidden(pid, SectionKind.movie, 'm1', true);
      await env.series(pid, 's9', 'Gizli Dizi', hidden: true);
      final hidden = await repo.hiddenItems(pid);
      // Movies first, each kind by name (Saklı < Zebra).
      expect(hidden.map((i) => i.providerId), ['m7', 'm1', 's9']);
      expect(hidden.last.kind, SectionKind.series);
      await repo.setHidden(pid, SectionKind.movie, 'm7', false);
      await repo.setHidden(pid, SectionKind.series, 's9', false);
      expect((await repo.hiddenItems(pid)).map((i) => i.providerId), ['m1']);
      expect(
        () => repo.setHidden(pid, SectionKind.live, 'x', true),
        throwsArgumentError,
      );
    });
  });

  group('home rows', () {
    setUp(() async {
      await env.category(pid, SectionKind.movie, 'a', 'Zeta', sortIndex: 0);
      await env.category(
        pid,
        SectionKind.movie,
        'b',
        'Alfa',
        sortIndex: 1,
        customIndex: 1,
      );
      await env.category(
        pid,
        SectionKind.movie,
        'c',
        'Beta',
        sortIndex: 2,
        customIndex: 0,
        localName: 'Çocuk',
      );
      await env.category(
        pid,
        SectionKind.movie,
        'h',
        'Gizli',
        sortIndex: 3,
        hidden: true,
      );
      await env.category(pid, SectionKind.movie, 'e', 'Boş', sortIndex: 4);
      for (var i = 0; i < 5; i++) {
        await env.movie(pid, 'a$i', 'A $i', categoryId: 'a', sortIndex: 10 + i);
      }
      await env.movie(pid, 'b0', 'B 0', categoryId: 'b', sortIndex: 1);
      await env.movie(
        pid,
        'b1',
        'B 1',
        categoryId: 'b',
        sortIndex: 0,
        hidden: true,
      );
      await env.movie(pid, 'c0', 'C 0', categoryId: 'c', sortIndex: 0);
      await env.movie(pid, 'h0', 'H 0', categoryId: 'h', sortIndex: 0);
      await env.movie(pid, 'x0', 'Kategorisiz', sortIndex: 0);
    });

    List<String> names(List<VodHomeRow> rows) =>
        rows.map((r) => r.category.name).toList();

    test('provider order, first N items, counts, hidden handling', () async {
      final rows = await repo.homeRows(pid, SectionKind.movie, perRow: 3);
      expect(names(rows), ['Zeta', 'Alfa', 'Çocuk']);
      expect(rows.first.items.map((i) => i.providerId), ['a0', 'a1', 'a2']);
      expect(rows.first.totalCount, 5);
      expect(rows[1].items.map((i) => i.providerId), ['b0']);
      expect(rows[1].totalCount, 1);
      expect(rows[2].category.providerName, 'Beta');
      expect(rows[2].category.isRenamed, isTrue);
    });

    test('name and custom category orders', () async {
      await env.settings.set(
        PlaylistSettings.categoriesOrder,
        'name',
        playlistId: pid,
      );
      expect(names(await repo.homeRows(pid, SectionKind.movie)), [
        'Alfa',
        'Çocuk',
        'Zeta',
      ]);
      await env.settings.set(
        PlaylistSettings.categoriesOrder,
        'custom',
        playlistId: pid,
      );
      expect(names(await repo.homeRows(pid, SectionKind.movie)), [
        'Çocuk',
        'Alfa',
        'Zeta',
      ]);
    });

    test('watchHomeRows re-runs on changes', () async {
      final emissions = Emissions(repo.watchHomeRows(pid, SectionKind.movie));
      expect(names(await emissions.next()), ['Zeta', 'Alfa', 'Çocuk']);
      await env.movie(pid, 'e0', 'E 0', categoryId: 'e');
      await emissions.next((rows) => names(rows).contains('Boş'));
      await emissions.cancel();
      expect(() => repo.homeRows(pid, SectionKind.live), throwsArgumentError);
    });

    test(
      'hero candidates interleave recent and in-progress items with art',
      () async {
        final now = env.now;
        await env.movie(
          pid,
          'r1',
          'Recent 1',
          poster: 'p1',
          added: now.subtract(const Duration(hours: 1)),
        );
        await env.movie(
          pid,
          'r2',
          'Recent 2',
          added: now.subtract(const Duration(hours: 2)),
        ); // no art
        await env.movie(
          pid,
          'r3',
          'Recent 3',
          poster: 'p3',
          added: now.subtract(const Duration(hours: 3)),
        );
        await env.movie(pid, 'w1', 'Watching', poster: 'pw');
        final watch = WatchStateRepository(db: env.db, clock: env.clock);
        await watch.save(
          pid,
          ItemType.movie,
          'w1',
          const Duration(minutes: 10),
          const Duration(minutes: 90),
        );
        final hero = await repo.heroCandidates(
          pid,
          SectionKind.movie,
          limit: 3,
        );
        expect(hero.map((i) => i.providerId), ['r1', 'w1', 'r3']);
        expect(hero.every((i) => i.art != null), isTrue);
      },
    );

    test('hero falls back to playlist order without added dates', () async {
      await (env.db.update(env.db.movies))
          .write(const MoviesCompanion(poster: Value('poster')));
      final hero = await repo.heroCandidates(pid, SectionKind.movie, limit: 2);
      expect(hero, hasLength(2));
    });
  });

  group('details', () {
    late TestHttpServer server;
    late Map<String, Object? Function(Map<String, String> q)> actions;
    late int status;

    setUp(() async {
      server = await TestHttpServer.start();
      actions = {};
      status = 200;
      server.route('/player_api.php', (r) async {
        final q = r.uri.queryParameters;
        if (q['username'] != 'kanal' || q['password'] != 'test123') {
          return sendJson(r, {
            'user_info': {'auth': 0},
          }, status: 401);
        }
        final handler = actions[q['action'] ?? ''];
        if (handler == null) return sendText(r, 'unknown', status: 404);
        if (status != 200) return sendText(r, 'boom', status: status);
        await sendJson(r, handler(q), contentType: 'text/html');
      });
      await (env.db.update(env.db.playlists)..where((p) => p.id.equals(pid)))
          .write(PlaylistsCompanion(server: Value(server.baseUrl)));
    });

    tearDown(() => server.close());

    int calls(String action) => server
        .requestsTo('/player_api.php')
        .where((r) => r.uri.queryParameters['action'] == action)
        .length;

    test(
      'movie info is fetched lazily, parsed and cached for 7 days',
      () async {
        actions['get_vod_info'] = (_) => vodInfoJson();
        await env.movie(
          pid,
          '3001',
          'Kış Uykusu',
          poster: 'http://p',
          year: 2014,
        );

        final d = (await repo.movieDetails(pid, '3001'))!;
        expect(calls('get_vod_info'), 1);
        expect(d.error, isNull);
        expect(d.hasProviderInfo, isTrue);
        expect(d.name, 'Kış Uykusu');
        expect(d.originalName, 'Winter Sleep');
        expect(d.poster, 'http://p');
        expect(d.backdrops, [
          'http://img.test/kis_bd1.jpg',
          'http://img.test/kis_bd2.jpg',
        ]);
        expect(d.plot, 'Aydın, a former actor, runs a hotel.');
        expect(d.genres, ['Dram', 'Drama', 'Komedi']);
        expect(d.cast, ['Haluk Bilginer', 'Melisa Sözen', 'Demet Akbağ']);
        expect(d.director, 'Nuri Bilge Ceylan');
        expect(d.duration, const Duration(seconds: 11760));
        expect(d.ageRating, 'PG-13');
        expect(d.country, 'Türkiye');
        expect(d.year, 2014);
        expect(d.releaseDate, '2014-06-13');
        expect(d.releaseDateParsed, DateTime.utc(2014, 6, 13));
        expect(d.rating, 8.1);
        expect(d.trailer, 'abc123');
        expect(d.tmdbId, 12345);
        expect(d.containerExt, 'mkv');
        final t = d.technical!;
        expect(t.resolution, 'FHD');
        expect(t.videoCodec, 'H.264');
        expect(t.audioCodec, 'AC-3');
        expect(t.audioChannels, 6);
        expect(t.audioLayout, '5.1');
        expect(t.bitrateKbps, 4800);
        expect(t.frameRate, 25);
        expect(t.badges, ['FHD', 'H.264', 'AC-3 5.1', '4.8 Mbps']);

        // Stored: tmdb id and container filled, info cached.
        final row = await (env.db.select(
          env.db.movies,
        )..where((m) => m.providerId.equals('3001'))).getSingle();
        expect(row.tmdbId, 12345);
        expect(row.containerExt, 'mkv');
        expect(row.infoFetchedAt, isNotNull);
        expect(jsonDecode(row.infoJson!), isA<Map<String, Object?>>());

        // Cached: no new request; the card now has the backdrop and plot.
        final again = (await repo.movieDetails(pid, '3001'))!;
        expect(calls('get_vod_info'), 1);
        expect(again.cast, d.cast);
        expect(again.technical!.badges, t.badges);
        final card = (await repo.item(pid, SectionKind.movie, '3001'))!;
        expect(card.backdrop, 'http://img.test/kis_bd1.jpg');
        expect(card.plot, 'Aydın, a former actor, runs a hotel.');

        // refresh, and expiry after 7 days.
        await repo.movieDetails(pid, '3001', refresh: true);
        expect(calls('get_vod_info'), 2);
        env.now = env.now.add(const Duration(days: 8));
        await repo.movieDetails(pid, '3001');
        expect(calls('get_vod_info'), 3);
      },
    );

    test('failures return cached or basic data with the error', () async {
      actions['get_vod_info'] = (_) => vodInfoJson();
      await env.movie(pid, '3001', 'Kış Uykusu', year: 2014, rating: 7.5);
      status = 500;
      final basic = (await repo.movieDetails(pid, '3001'))!;
      expect(basic.error?.kind, SourceErrorKind.http);
      expect(basic.hasProviderInfo, isFalse);
      expect(basic.name, 'Kış Uykusu');
      expect(basic.rating, 7.5);
      expect(basic.cast, isEmpty);

      status = 200;
      await repo.movieDetails(pid, '3001');
      status = 500;
      final cached = (await repo.movieDetails(pid, '3001', refresh: true))!;
      expect(cached.error, isNotNull);
      expect(cached.hasProviderInfo, isTrue);
      expect(cached.cast, hasLength(3));

      expect(await repo.movieDetails(pid, 'missing'), isNull);
    });

    test('missing credentials are reported, M3U movies are basic', () async {
      await env.movie(pid, '3001', 'Kış Uykusu');
      await env.secrets.write('playlist.$pid.password', null);
      final d = (await repo.movieDetails(pid, '3001'))!;
      expect(d.error?.kind, SourceErrorKind.unauthorized);

      final m3u = await env.playlist(type: PlaylistType.m3u);
      await env.movie(m3u, 'abc', 'Yerel Film', poster: 'p', year: 1999);
      final local = (await repo.movieDetails(m3u, 'abc'))!;
      expect(local.error, isNull);
      expect(local.hasProviderInfo, isFalse);
      expect(local.year, 1999);
      expect(local.poster, 'p');
      expect(calls('get_vod_info'), 0);
    });

    for (final asList in [false, true]) {
      test('series info (episodes as ${asList ? 'list' : 'map'})', () async {
        actions['get_series_info'] = (_) => seriesInfoJson(asList: asList);
        await env.series(pid, '5001', 'Sıcak Kafa', categoryId: 's');

        final d = (await repo.seriesDetails(pid, '5001'))!;
        expect(calls('get_series_info'), 1);
        expect(d.error, isNull);
        expect(d.seasons.map((s) => s.number), [1, 2, 0]);
        expect(d.seasons.last.isSpecial, isTrue);
        expect(d.seasons.last.name, 'Özel Bölümler');
        expect(d.seasons.first.name, 'Sezon 1');
        expect(d.seasons.first.airDate, '2022-03-01');
        expect(d.seasons.first.episodes.map((e) => e.code), ['S1 E1', 'S1 E2']);
        expect(d.seasons.first.episodes[1].label, 'S1 E2 · İkinci Gün');
        expect(d.seasonCount, 2);
        expect(d.episodeCount, 3);
        expect(d.totalEpisodeCount, 4);
        expect(d.plot, 'Bir virüs İstanbul’u sarar.');
        expect(d.cast, ['Ekin Koç', 'Nilperi Şahinkaya']);
        expect(d.genres, ['Bilim Kurgu', 'Gerilim']);
        expect(d.director, 'Mehmet Ada Öztekin');
        expect(d.releaseDate, '2022-03-01');
        expect(d.year, 2022);
        expect(d.rating, 7.4);
        expect(d.tmdbId, 98765);
        expect(d.episodeRunTime, const Duration(minutes: 45));
        expect(d.backdrops, ['http://img.test/sk_bd.jpg']);
        final e = d.seasons.first.episodes.first;
        expect(e.duration, const Duration(seconds: 2700));
        expect(e.plot, 'Plot of Pilot');
        expect(e.image, 'http://img.test/50011.jpg');
        expect(e.containerExt, 'mp4');
        expect(d.firstEpisode?.providerId, '50011');

        // Stored rows: episodes, seasons, info JSON and filled columns.
        expect(await env.db.select(env.db.episodes).get(), hasLength(4));
        expect(await env.db.select(env.db.seasons).get(), hasLength(3));
        final row = await env.db.select(env.db.series).getSingle();
        expect(row.infoJson, isNotNull);
        expect(row.cast, 'Ekin Koç, Nilperi Şahinkaya');
        expect(row.tmdbId, 98765);

        // Fresh: no new request.
        await repo.seriesDetails(pid, '5001');
        expect(calls('get_series_info'), 1);
      });
    }

    test('refreshEpisodes re-fetches and replaces the episode list', () async {
      var variant = 1;
      actions['get_series_info'] = (_) => seriesInfoJson(variant: variant);
      await env.series(pid, '5001', 'Sıcak Kafa');
      await repo.seriesDetails(pid, '5001');
      variant = 2;
      final d = (await repo.refreshEpisodes(pid, '5001'))!;
      expect(calls('get_series_info'), 2);
      expect(d.allEpisodes.map((e) => e.providerId), [
        '50012',
        '50021',
        '50022',
        '50001',
      ]);
      final stored = await env.db.select(env.db.episodes).get();
      expect(stored.map((e) => e.providerId), isNot(contains('50011')));

      // Failure keeps the stored episodes.
      status = 500;
      final failed = (await repo.refreshEpisodes(pid, '5001'))!;
      expect(failed.error, isNotNull);
      expect(failed.allEpisodes, hasLength(4));
    });

    test('nextEpisode walks seasons; specials stay among specials', () async {
      actions['get_series_info'] = (_) => seriesInfoJson();
      await env.series(pid, '5001', 'Sıcak Kafa');
      await repo.seriesDetails(pid, '5001');
      expect((await repo.nextEpisode(pid, '5001', 1, 1))?.providerId, '50012');
      expect((await repo.nextEpisode(pid, '5001', 1, 2))?.providerId, '50021');
      expect(await repo.nextEpisode(pid, '5001', 2, 1), isNull);
      expect(await repo.nextEpisode(pid, '5001', 0, 1), isNull);
      expect((await repo.nextEpisode(pid, '5001', 0, 0))?.providerId, '50001');
      expect((await repo.episodes(pid, '5001')).map((e) => e.code), [
        'S1 E1',
        'S1 E2',
        'S2 E1',
        'S0 E1',
      ]);
      expect((await repo.episode(pid, '50021'))?.title, 'Dönüş');
    });

    test('M3U series read stored episodes without seasons rows', () async {
      final m3u = await env.playlist(type: PlaylistType.m3u);
      await env.series(m3u, 'abcdef0123456789', 'Yerel Dizi');
      await env.episode(m3u, 'abcdef0123456789', 'e2', 1, 2, title: 'İki');
      await env.episode(m3u, 'abcdef0123456789', 'e1', 1, 1, title: 'Bir');
      await env.episode(m3u, 'abcdef0123456789', 'e3', 2, 1);
      final d = (await repo.seriesDetails(m3u, 'abcdef0123456789'))!;
      expect(d.error, isNull);
      expect(d.seasons.map((s) => s.number), [1, 2]);
      expect(d.seasons.first.episodes.map((e) => e.label), [
        'S1 E1 · Bir',
        'S1 E2 · İki',
      ]);
      expect(d.seasons.last.episodes.single.label, 'S2 E1');
      expect(calls('get_series_info'), 0);
    });

    test('concurrent detail requests share one fetch', () async {
      actions['get_vod_info'] = (_) => vodInfoJson();
      await env.movie(pid, '3001', 'Kış Uykusu');
      final results = await Future.wait([
        repo.movieDetails(pid, '3001'),
        repo.movieDetails(pid, '3001'),
      ]);
      expect(results.every((d) => d!.hasProviderInfo), isTrue);
      expect(calls('get_vod_info'), 1);
    });
  });

  group('favorites row and trending match', () {
    test('watchFavoriteItems follows order and tags', () async {
      final favorites = FavoritesRepository(db: env.db, clock: env.clock);
      await env.movie(pid, 'a', 'Bravo');
      await env.movie(pid, 'b', 'Alfa');
      await env.movie(pid, 'c', 'Charlie', hidden: true);
      await favorites.add(pid, ItemType.movie, 'a');
      env.now = env.now.add(const Duration(minutes: 1));
      await favorites.add(pid, ItemType.movie, 'b');
      await favorites.add(pid, ItemType.movie, 'c');
      await favorites.add(pid, ItemType.movie, 'gone');

      Future<List<String>> ids(FavoritesOrder order, {int? tag}) async =>
          (await repo
                  .watchFavoriteItems(
                    pid,
                    SectionKind.movie,
                    order: order,
                    tagId: tag,
                  )
                  .first)
              .map((i) => i.providerId)
              .toList();

      expect(await ids(FavoritesOrder.lastAdded), ['b', 'a']);
      expect(await ids(FavoritesOrder.leastRecent), ['a', 'b']);
      expect(await ids(FavoritesOrder.name), ['b', 'a']);
      await favorites.reorder(pid, ItemType.movie, ['b', 'a']);
      expect(await ids(FavoritesOrder.custom), ['b', 'a']);
      final tag = await favorites.createTag(pid, 'Hafta sonu');
      await favorites.setTags(pid, ItemType.movie, 'a', {tag});
      expect(await ids(FavoritesOrder.lastAdded, tag: tag), ['a']);
      final items = await repo
          .watchFavoriteItems(
            pid,
            SectionKind.movie,
            order: FavoritesOrder.name,
          )
          .first;
      expect(items.every((i) => i.isFavorite), isTrue);
    });

    test('matchTrending by tmdb id, then normalized title and year', () async {
      await env.movie(pid, 't1', 'Dune', tmdbId: 438631, year: 2021);
      await env.movie(pid, 't2', 'Kış Uykusu', year: 2014);
      await env.movie(pid, 't3', 'Dune', year: 1984);
      await env.index(pid, 'movie', 't2', 'Kış Uykusu');
      await env.index(pid, 'movie', 't3', 'Dune');
      final matched = await repo.matchTrending(pid, SectionKind.movie, [
        (tmdbId: 1, title: 'Kis Uykusu', originalTitle: null, year: 2014),
        (
          tmdbId: 438631,
          title: 'Dune: Part One',
          originalTitle: null,
          year: 2021,
        ),
        (tmdbId: 2, title: 'Unknown', originalTitle: 'Dune', year: 1984),
        (tmdbId: 3, title: 'Nothing', originalTitle: null, year: null),
      ]);
      expect(matched.map((i) => i.providerId), ['t2', 't1', 't3']);
    });
  });

  test('stored info JSON round-trips through the Xtream DTOs', () {
    final info = XtreamVodInfo.fromJson(vodInfoJson(), vodId: '3001');
    final back = decodeVodInfo(jsonEncode(vodInfoToJson(info)), '3001')!;
    expect(back.castText, info.castText);
    expect(back.backdrops, info.backdrops);
    expect(back.durationSecs, info.durationSecs);
    expect(back.rating, info.rating);
    expect(back.ageRating, info.ageRating);
    expect(back.added, info.added);
    expect(back.containerExtension, 'mkv');
    expect(back.video?.codecName, 'h264');
    expect(back.video?.height, 1080);
    expect(back.video?.frameRate, 25);
    expect(back.audio?.channels, 6);
    expect(back.bitrate, 4800);
    expect(decodeVodInfo('not json', '1'), isNull);
    expect(decodeVodInfo('{"info":[],"movie_data":[]}', '1'), isNull);

    final series = XtreamSeriesInfo.fromJson(
      seriesInfoJson(),
      seriesId: '5001',
    ).info!;
    final s = decodeSeriesInfo(jsonEncode(seriesToJson(series)), '5001')!;
    expect(s.cast, series.cast);
    expect(s.backdrops, series.backdrops);
    expect(s.episodeRunTime, 45);
    expect(s.tmdbId, 98765);
    expect(s.rating, 7.4);
    expect(s.releaseDate, '2022-03-01');
    expect(technicalFromXtream(null, null, null), isNull);
    expect(resolutionLabel(3840, 2160), '4K');
    expect(resolutionLabel(1920, 800), 'FHD');
    expect(resolutionLabel(1280, 720), 'HD');
    expect(resolutionLabel(720, 576), 'SD');
  });
}
