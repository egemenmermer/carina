import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/net/dio_factory.dart';
import 'package:carina/data/secrets/secret_store.dart';
import 'package:carina/data/settings/settings_store.dart';
import 'package:carina/data/tmdb/tmdb_service.dart';

import '../net/test_http_server.dart';

const apiKey = '0123456789abcdef0123456789abcdef';

Map<String, Object?> movieJson(int id, {String title = 'Kış Uykusu'}) => {
  'id': id,
  'title': title,
  'original_title': 'Kış Uykusu',
  'overview': 'Aydın, a former actor, runs a hotel.',
  'tagline': 'Bir kış masalı',
  'backdrop_path': '/bd.jpg',
  'poster_path': '/poster.jpg',
  'genres': [
    {'id': 18, 'name': 'Dram'},
  ],
  'runtime': 196,
  'vote_average': 7.6,
  'vote_count': 1300,
  'release_date': '2014-06-13',
  'images': {
    'logos': [
      {'file_path': '/logo_en.png', 'iso_639_1': 'en', 'vote_average': 5.3},
      {'file_path': '/logo_tr.svg', 'iso_639_1': 'tr', 'vote_average': 9.0},
      {'file_path': '/logo_tr.png', 'iso_639_1': 'tr', 'vote_average': 5.0},
      {'file_path': '/logo_null.png', 'iso_639_1': null},
      {'file_path': '/logo_fr.png', 'iso_639_1': 'fr', 'vote_average': 10},
    ],
    'backdrops': [
      {'file_path': '/bd2.jpg'},
    ],
  },
  'credits': {
    'cast': [
      for (var i = 0; i < 12; i++) {'name': 'Actor $i', 'order': 11 - i},
    ],
    'crew': [
      for (var i = 0; i < 50; i++) {'name': 'Crew $i', 'job': 'Grip'},
    ],
  },
  'release_dates': {
    'results': [
      {
        'iso_3166_1': 'US',
        'release_dates': [
          {'certification': 'R', 'type': 3},
        ],
      },
      {
        'iso_3166_1': 'TR',
        'release_dates': [
          {'certification': '', 'type': 1},
          {'certification': '15+', 'type': 3},
        ],
      },
    ],
  },
  'videos': {
    'results': [
      {'site': 'YouTube', 'key': 'teaser1', 'type': 'Teaser'},
      {
        'site': 'YouTube',
        'key': 'trailer1',
        'type': 'Trailer',
        'official': true,
      },
      {'site': 'Vimeo', 'key': 'v1', 'type': 'Trailer'},
    ],
  },
};

Map<String, Object?> tvJson(int id) => {
  'id': id,
  'name': 'Sıcak Kafa',
  'original_name': 'Sıcak Kafa',
  'first_air_date': '2022-03-01',
  'episode_run_time': <Object?>[],
  'last_episode_to_air': {'runtime': 44, 'overview': 'long text'},
  'number_of_seasons': 1,
  'number_of_episodes': 8,
  'vote_average': 6.9,
  'vote_count': 120,
  'images': {
    'logos': [
      {'file_path': '/tv_logo.png', 'iso_639_1': null},
    ],
  },
  'content_ratings': {
    'results': [
      {'iso_3166_1': 'US', 'rating': 'TV-MA'},
      {'iso_3166_1': 'DE', 'rating': '16'},
    ],
  },
};

void main() {
  late TestHttpServer server;
  late AppDatabase db;
  late SettingsStore settings;
  late MemorySecretStore secrets;
  late DateTime now;
  late Duration delay;
  final services = <TmdbService>[];

  setUp(() async {
    server = await TestHttpServer.start();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    settings = SettingsStore(db);
    await settings.load();
    await settings.set(AppSettings.tmdbEnabled, true);
    secrets = MemorySecretStore();
    await secrets.write(SecretStore.tmdbKey, apiKey);
    now = DateTime(2026, 10, 17, 12);
    delay = Duration.zero;

    Future<void> json(HttpRequest r, Object body) async {
      if (r.uri.queryParameters['api_key'] != apiKey) {
        return sendJson(r, {'status_code': 7}, status: 401);
      }
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      await sendJson(r, body);
    }

    server.route('/3/movie/1001', (r) => json(r, movieJson(1001)));
    for (var i = 0; i < 10; i++) {
      server.route('/3/movie/${2000 + i}', (r) => json(r, movieJson(2000 + i)));
    }
    server.route(
      '/3/movie/404',
      (r) => sendJson(r, {'status_code': 34}, status: 404),
    );
    server.route('/3/tv/77', (r) => json(r, tvJson(77)));
    server.route('/3/search/movie', (r) {
      final q = r.uri.queryParameters;
      final results = switch ((q['query'], q['year'])) {
        ('Kış Uykusu', '2014' || null) => [
          {'id': 999, 'title': 'Uykusuz Kış', 'release_date': '2014-01-01'},
          {
            'id': 1001,
            'title': 'Kış Uykusu',
            'original_title': 'Kış Uykusu',
            'release_date': '2014-06-13',
          },
          {'id': 998, 'title': 'Kış Uykusu', 'release_date': '1990-01-01'},
        ],
        ('Yalnız Film', null) => [
          {'id': 1001, 'title': 'Yalnız Film', 'release_date': '2010-01-01'},
        ],
        _ => <Object?>[],
      };
      return json(r, {'results': results});
    });
    server.route(
      '/3/search/tv',
      (r) => json(r, {
        'results': [
          {'id': 77, 'name': 'Sıcak Kafa', 'first_air_date': '2022-03-01'},
        ],
      }),
    );
    server.route(
      '/3/trending/movie/week',
      (r) => json(r, {
        'results': [
          {'id': 1001, 'title': 'Kış Uykusu', 'release_date': '2014-06-13'},
          {'title': 'no id'},
          {
            'id': 5,
            'title': 'Başka',
            'poster_path': '/p5.jpg',
            'backdrop_path': '/b5.jpg',
            'vote_average': 8.2,
          },
        ],
      }),
    );
  });

  tearDown(() async {
    for (final s in services) {
      s.dispose();
    }
    services.clear();
    await server.close();
    await db.close();
  });

  TmdbService service({String system = 'tr_TR'}) {
    final s = TmdbService(
      db: db,
      settings: settings,
      secrets: secrets,
      dioFactory: () => createDio(retryDelay: const Duration(milliseconds: 5)),
      baseUrl: server.url('/3'),
      clock: () => now,
      systemLanguage: () => system,
      keyCacheTtl: Duration.zero,
    );
    services.add(s);
    return s;
  }

  int requests(String path) => server.requestsTo(path).length;

  test('no key or TMDb disabled: everything is a null no-op', () async {
    await secrets.write(SecretStore.tmdbKey, null);
    final s = service();
    expect(await s.isEnabled(), isFalse);
    expect(await s.enrichMovie(tmdbId: 1001, title: 'Kış Uykusu'), isNull);
    expect(await s.enrichSeries(title: 'Sıcak Kafa'), isNull);
    expect(await s.trending(TmdbKind.movie), isNull);
    await secrets.write(SecretStore.tmdbKey, '   ');
    expect(await s.enrichMovie(tmdbId: 1001, title: 'X'), isNull);

    await secrets.write(SecretStore.tmdbKey, apiKey);
    await settings.set(AppSettings.tmdbEnabled, false);
    expect(await s.enrichMovie(tmdbId: 1001, title: 'Kış Uykusu'), isNull);
    expect(await s.trending(TmdbKind.movie), isNull);
    expect(server.requests, isEmpty);

    await settings.set(AppSettings.tmdbEnabled, true);
    expect(await s.isEnabled(), isTrue);
  });

  test(
    'movie enrichment maps artwork, logo, cast, rating and certification',
    () async {
      final e = (await service().enrichMovie(
        tmdbId: 1001,
        title: 'Kış Uykusu',
      ))!;
      final q = server.requestsTo('/3/movie/1001').single.uri.queryParameters;
      expect(q['language'], 'tr-TR');
      expect(q['include_image_language'], 'tr,en,null');
      expect(q['append_to_response'], 'images,credits,release_dates,videos');

      expect(e.kind, TmdbKind.movie);
      expect(e.tmdbId, 1001);
      expect(e.title, 'Kış Uykusu');
      expect(e.tagline, 'Bir kış masalı');
      expect(e.overview, startsWith('Aydın'));
      expect(e.backdropUrl, 'https://image.tmdb.org/t/p/w1280/bd.jpg');
      expect(e.posterUrl, 'https://image.tmdb.org/t/p/w500/poster.jpg');
      // Turkish PNG beats the higher-voted Turkish SVG and the English logo.
      expect(e.logoUrl, 'https://image.tmdb.org/t/p/original/logo_tr.png');
      expect(e.genres, ['Dram']);
      expect(e.cast, [for (var i = 11; i >= 2; i--) 'Actor $i']);
      expect(e.runtimeMinutes, 196);
      expect(e.voteAverage, 7.6);
      expect(e.voteCount, 1300);
      expect(e.votePercent, 76);
      expect(e.certification, '15+'); // region TR (default setting)
      expect(e.year, 2014);
      expect(e.trailerYoutubeKey, 'trailer1');
    },
  );

  test('logo language preference and certification region fallback', () async {
    await settings.set(AppSettings.tmdbLanguage, 'en');
    await settings.set(AppSettings.tmdbRegion, 'DE');
    final e = (await service().enrichMovie(tmdbId: 1001, title: 'Kış Uykusu'))!;
    final q = server.requestsTo('/3/movie/1001').single.uri.queryParameters;
    expect(q['language'], 'en-US');
    expect(q['include_image_language'], 'en,null');
    expect(e.logoUrl, 'https://image.tmdb.org/t/p/original/logo_en.png');
    expect(e.certification, 'R'); // no DE release → US

    expect(
      bestLogoPath(const [
        {'file_path': '/a.png', 'iso_639_1': 'fr'},
        {'file_path': '/b.png', 'iso_639_1': null},
      ], 'tr'),
      '/b.png',
    );
    expect(
      bestLogoPath(const [
        {'file_path': '/a.png', 'iso_639_1': 'fr'},
      ], 'tr'),
      isNull,
    );
    expect(
      bestLogoPath(const [
        {'file_path': '/w1.png', 'iso_639_1': 'tr', 'width': 300},
        {'file_path': '/w2.png', 'iso_639_1': 'tr', 'width': 900},
      ], 'tr'),
      '/w2.png',
    );
  });

  test(
    'tv enrichment: episode run time, seasons, content rating fallback',
    () async {
      await settings.set(AppSettings.tmdbRegion, 'TR');
      final e = (await service().enrichSeries(
        tmdbId: 77,
        title: 'Sıcak Kafa',
      ))!;
      final q = server.requestsTo('/3/tv/77').single.uri.queryParameters;
      expect(q['append_to_response'], 'images,credits,content_ratings,videos');
      expect(e.kind, TmdbKind.tv);
      expect(e.title, 'Sıcak Kafa');
      expect(e.runtimeMinutes, 44);
      expect(e.numberOfSeasons, 1);
      expect(e.numberOfEpisodes, 8);
      expect(e.certification, 'TV-MA'); // no TR rating → US
      expect(e.logoUrl, 'https://image.tmdb.org/t/p/original/tv_logo.png');
      expect(e.year, 2022);
    },
  );

  test('search fallback by cleaned title and year', () async {
    final s = service();
    final e = (await s.enrichMovie(title: 'TR: Kış Uykusu (2014) FHD'))!;
    expect(e.tmdbId, 1001);
    final q = server.requestsTo('/3/search/movie').single.uri.queryParameters;
    expect(q['query'], 'Kış Uykusu');
    expect(q['year'], '2014');
    // An unknown tmdb id falls back to the search too.
    final viaSearch = (await s.enrichMovie(
      tmdbId: 404,
      title: 'Kış Uykusu',
      year: 2014,
    ))!;
    expect(viaSearch.tmdbId, 1001);
    // The 404 is remembered (like a search miss) for 3 days.
    await service().enrichMovie(tmdbId: 404, title: 'Kış Uykusu', year: 2014);
    expect(requests('/3/movie/404'), 1);
    now = now.add(const Duration(days: 4));
    await service().enrichMovie(tmdbId: 404, title: 'Kış Uykusu', year: 2014);
    expect(requests('/3/movie/404'), 2);
    // A year-restricted search without results is retried without the year.
    final noYear = (await s.enrichMovie(title: 'Yalnız Film', year: 2010))!;
    expect(noYear.tmdbId, 1001);
    final yalniz = server
        .requestsTo('/3/search/movie')
        .where((r) => r.uri.queryParameters['query'] == 'Yalnız Film');
    expect(yalniz.map((r) => r.uri.queryParameters['year']), ['2010', null]);
    // Unrelated titles are never picked.
    expect(await s.enrichMovie(title: 'Bambaşka'), isNull);
    expect(await s.enrichSeries(title: 'Sıcak Kafa', year: 2022), isNotNull);
  });

  test('responses are cached for 14 days, misses for 3 days', () async {
    await service().enrichMovie(tmdbId: 1001, title: 'Kış Uykusu');
    expect(requests('/3/movie/1001'), 1);
    // A new service instance (empty memory cache) reads tmdb_cache.
    final cached = await service().enrichMovie(
      tmdbId: 1001,
      title: 'Kış Uykusu',
    );
    expect(cached?.logoUrl, endsWith('/logo_tr.png'));
    expect(requests('/3/movie/1001'), 1);
    final row = await (db.select(db.tmdbCache)).get();
    expect(row.every((r) => r.json.length < 6000), isTrue); // trimmed

    now = now.add(const Duration(days: 15));
    await service().enrichMovie(tmdbId: 1001, title: 'Kış Uykusu');
    expect(requests('/3/movie/1001'), 2);

    expect(await service().enrichMovie(title: 'Bambaşka'), isNull);
    expect(await service().enrichMovie(title: 'Bambaşka'), isNull);
    expect(requests('/3/search/movie'), 1);
    now = now.add(const Duration(days: 4));
    expect(await service().enrichMovie(title: 'Bambaşka'), isNull);
    expect(requests('/3/search/movie'), 2);

    await service().clearCache();
    expect(await db.select(db.tmdbCache).get(), isEmpty);
  });

  test(
    'at most 4 requests run at once; duplicates share one request',
    () async {
      delay = const Duration(milliseconds: 150);
      final s = service();
      final results = await Future.wait([
        for (var i = 0; i < 10; i++)
          s.enrichMovie(tmdbId: 2000 + i, title: 'Kış Uykusu'),
        s.enrichMovie(tmdbId: 2000, title: 'Kış Uykusu'),
      ]);
      expect(results.every((e) => e != null), isTrue);
      expect(server.maxInFlight, 4);
      expect(requests('/3/movie/2000'), 1);
    },
  );

  test('trending is ranked and cached for a day', () async {
    final list = (await service().trending(TmdbKind.movie))!;
    expect(list.map((t) => t.tmdbId), [1001, 5]);
    expect(list.map((t) => t.rank), [1, 2]);
    expect(list.last.posterUrl, 'https://image.tmdb.org/t/p/w500/p5.jpg');
    expect(list.last.backdropUrl, 'https://image.tmdb.org/t/p/w1280/b5.jpg');
    expect(list.first.year, 2014);
    await service().trending(TmdbKind.movie);
    expect(requests('/3/trending/movie/week'), 1);
    now = now.add(const Duration(hours: 25));
    await service().trending(TmdbKind.movie);
    expect(requests('/3/trending/movie/week'), 2);
  });

  test('language follows the app language when set to auto', () async {
    expect(service(system: 'en_US.UTF-8').language(), 'en-US');
    expect(service(system: 'tr_TR').language(), 'tr-TR');
    await settings.set(AppSettings.language, 'tr');
    expect(service(system: 'en_US').language(), 'tr-TR');
    await settings.set(AppSettings.tmdbLanguage, 'de');
    expect(service().language(), 'de-DE');
    expect(tmdbLanguageTag('pt-BR'), 'pt-BR');
    expect(tmdbLanguageTag('C'), 'en-US');
    expect(tmdbLanguageTag('sv'), 'sv');
    await settings.set(AppSettings.tmdbRegion, 'x');
    expect(service().region(), 'US');
  });

  test('errors return null and never expose the key', () async {
    server.route('/3/movie/3', (r) => sendText(r, 'down', status: 500));
    final s = service();
    expect(await s.enrichMovie(tmdbId: 3, title: 'Nothing Matches'), isNull);
    expect(s.lastError, isNotNull);
    expect(s.lastError.toString(), isNot(contains(apiKey)));

    await secrets.write(
      SecretStore.tmdbKey,
      'ffffffffffffffffffffffffffffffff',
    );
    s.keyChanged();
    expect(await s.enrichMovie(tmdbId: 1001, title: 'Kış Uykusu'), isNull);
    expect(s.lastError?.kind, TmdbErrorKind.unauthorized);
  });

  test('testKey checks a given or the stored credential', () async {
    server.route('/3/configuration', (r) {
      final ok = r.uri.queryParameters['api_key'] == apiKey;
      return sendJson(r, {}, status: ok ? 200 : 401);
    });
    final s = service();
    expect(await s.testKey(), TmdbKeyStatus.ok);
    expect(
      await s.testKey('ffffffffffffffffffffffffffffffff'),
      TmdbKeyStatus.invalid,
    );
    expect(await s.testKey('  '), TmdbKeyStatus.invalid);
  });

  test('title helpers', () {
    expect(searchTitle('TR: Kış Uykusu (2014) FHD'), 'Kış Uykusu');
    expect(searchTitle('Blade Runner 2049'), 'Blade Runner 2049');
    expect(searchTitle('[TR] Show [2019]'), 'Show');
    expect(yearInTitle('Kış Uykusu (2014)'), 2014);
    expect(yearInTitle('Blade Runner 2049'), isNull);
    final results = [
      {'id': 1, 'title': 'Dune', 'release_date': '1984-12-14'},
      {'id': 2, 'title': 'Dune', 'release_date': '2021-09-15'},
      {'id': 3, 'title': 'Dune: Part Two', 'release_date': '2024-02-27'},
    ];
    expect(pickSearchResult(results, 'Dune', 2021), 2);
    expect(pickSearchResult(results, 'Dune', 1984), 1);
    expect(pickSearchResult(results, 'Dune', null), 1);
    expect(pickSearchResult(results, 'Arrival', null), isNull);
    expect(
      pickSearchResult(
        [
          {'id': 9, 'name': 'Sicak Kafa', 'first_air_date': '2022-01-01'},
        ],
        'Sıcak Kafa',
        2022,
      ),
      9,
    );
  });
}
