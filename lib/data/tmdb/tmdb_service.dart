import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_paths.dart';
import '../db/database.dart';
import '../net/dio_factory.dart';
import '../secrets/secret_store.dart';
import '../settings/settings_store.dart';
import '../sources/xtream/json_utils.dart';
import '../text/flags.dart';
import '../text/normalize.dart';
import '../text/quality.dart';
import 'tmdb_client.dart';
import 'tmdb_models.dart';

export 'tmdb_models.dart';

/// TMDb enrichment: artwork, logos, cast, ratings and
/// certifications for heroes and detail sheets, plus the trending lists.
///
/// Everything is a no-op returning null unless `AppSettings.tmdbEnabled` is
/// on and a credential is stored under `SecretStore.tmdbKey` (v3 API key or
/// v4 read access token). Network requests go through a queue of
/// [maxConcurrent] (4) and responses are cached in `tmdb_cache`: details and
/// search matches for 14 days, "no match" for 3 days, trending for 24 hours.
/// Failures return null (see [lastError]); the credential is never logged.
class TmdbService {
  TmdbService({
    required this._db,
    required this._settings,
    required this._secrets,
    Dio Function()? dioFactory,
    this.baseUrl = TmdbClient.defaultBaseUrl,
    DateTime Function()? clock,
    String Function()? systemLanguage,
    this.maxConcurrent = 4,
    this.cacheTtl = const Duration(days: 14),
    this.negativeCacheTtl = const Duration(days: 3),
    this.trendingTtl = const Duration(hours: 24),
    this.keyCacheTtl = const Duration(seconds: 10),
  }) : _dioFactory = dioFactory ?? _defaultDio,
       _clock = clock ?? DateTime.now,
       _systemLanguage = systemLanguage ?? _platformLanguage,
       _pool = _Pool(maxConcurrent);

  final AppDatabase _db;
  final SettingsStore _settings;
  final SecretStore _secrets;
  final Dio Function() _dioFactory;
  final DateTime Function() _clock;
  final String Function() _systemLanguage;
  final _Pool _pool;

  /// API root (tests point it at a local server).
  final String baseUrl;
  final int maxConcurrent;
  final Duration cacheTtl;
  final Duration negativeCacheTtl;
  final Duration trendingTtl;

  /// How long the stored credential is reused before it is read again
  /// (call [keyChanged] after saving a new one).
  final Duration keyCacheTtl;

  Dio? _dio;
  TmdbClient? _client;
  String? _clientKey;
  String? _key;
  DateTime? _keyReadAt;
  final Map<String, Future<Object?>> _inFlight = {};
  final _memory = _Lru<String, TmdbEnrichment?>(300);

  /// The last failure (for diagnostics); never contains the credential.
  TmdbException? lastError;

  static Dio _defaultDio() =>
      createDio(receiveTimeout: const Duration(seconds: 20), retries: 1);

  static String _platformLanguage() {
    try {
      return Platform.localeName;
    } on Object {
      return 'en';
    }
  }

  void dispose() {
    _dio?.close(force: true);
    _dio = null;
    _client = null;
  }

  /// Forget the cached credential (after the settings screen saved one).
  void keyChanged() {
    _key = null;
    _keyReadAt = null;
    _memory.clear();
  }

  /// Whether TMDb is enabled and a credential is stored.
  Future<bool> isEnabled() async => await _context() != null;

  /// Checks [credential] (or the stored one) against TMDb.
  Future<TmdbKeyStatus> testKey([String? credential]) async {
    final key = credential?.trim() ?? await _readKey();
    if (key == null || key.isEmpty) return TmdbKeyStatus.invalid;
    return TmdbClient(_http(), key, baseUrl: baseUrl).test();
  }

  /// Metadata language sent to TMDb (`tr-TR`, `en-US`…):
  /// `AppSettings.tmdbLanguage`, or the app language when it is `auto`.
  String language() {
    var lang = _settings.get(AppSettings.tmdbLanguage).trim();
    if (lang.isEmpty || lang == 'auto') {
      final app = _settings.get(AppSettings.language).trim();
      lang = (app.isEmpty || app == 'system') ? _systemLanguage() : app;
    }
    return tmdbLanguageTag(lang);
  }

  /// Region for certifications (`AppSettings.tmdbRegion`, fallback US).
  String region() {
    final r = _settings.get(AppSettings.tmdbRegion).trim().toUpperCase();
    return r.length == 2 ? r : 'US';
  }

  /// Enrichment for a movie: by [tmdbId] when known (falling back to a
  /// search when TMDb does not know it), else by searching the normalized
  /// [title] and [year]. Null when disabled, not found or on errors.
  Future<TmdbEnrichment?> enrichMovie({
    int? tmdbId,
    required String title,
    int? year,
  }) => _enrich(TmdbKind.movie, tmdbId, title, year);

  /// [enrichMovie] for a series (`/tv`).
  Future<TmdbEnrichment?> enrichSeries({
    int? tmdbId,
    required String title,
    int? year,
  }) => _enrich(TmdbKind.tv, tmdbId, title, year);

  /// `trending/{movie|tv}/week`, ranked from 1. Null when disabled or on
  /// errors.
  Future<List<TmdbTrendingItem>?> trending(TmdbKind kind) async {
    final ctx = await _context();
    if (ctx == null) return null;
    try {
      final json = await _cachedFetch(
        'trending:${kind.path}:${ctx.language}',
        (_) => trendingTtl,
        () => ctx.client.trending(kind, language: ctx.language),
      );
      final out = <TmdbTrendingItem>[];
      for (final raw in asList(json['results'])) {
        final item = TmdbTrendingItem.fromJson(kind, raw, out.length + 1);
        if (item != null) out.add(item);
      }
      return List.unmodifiable(out);
    } on TmdbException catch (e) {
      lastError = e;
      return null;
    }
  }

  /// Deletes every cached TMDb response.
  Future<void> clearCache() async {
    _memory.clear();
    await _db.delete(_db.tmdbCache).go();
  }

  // -------------------------------------------------------------------------
  // Internals
  // -------------------------------------------------------------------------

  Future<TmdbEnrichment?> _enrich(
    TmdbKind kind,
    int? tmdbId,
    String title,
    int? year,
  ) async {
    final ctx = await _context();
    if (ctx == null) return null;
    final memoryKey =
        '${kind.path}:${tmdbId ?? ''}:${normalizeForSearch(title)}:'
        '${year ?? ''}:${ctx.language}:${ctx.region}';
    if (_memory.containsKey(memoryKey)) return _memory[memoryKey];
    try {
      Map<String, Object?>? details;
      if (tmdbId != null && tmdbId > 0) {
        details = await _details(ctx, kind, tmdbId);
      }
      if (details == null) {
        final id = await _searchId(ctx, kind, title, year);
        if (id != null) details = await _details(ctx, kind, id);
      }
      final result = details == null
          ? null
          : TmdbEnrichment.fromDetails(
              kind,
              details,
              imageLanguage: ctx.imageLanguage,
              region: ctx.region,
            );
      _memory[memoryKey] = result;
      return result;
    } on TmdbException catch (e) {
      lastError = e;
      return null;
    }
  }

  /// Details of [id], or null when TMDb does not know it (a 404 is cached
  /// like a search miss, for [negativeCacheTtl]).
  Future<Map<String, Object?>?> _details(
    _Context ctx,
    TmdbKind kind,
    int id,
  ) async {
    final json = await _cachedFetch(
      '${kind.path}:$id:${ctx.language}',
      (json) => json[_missingKey] == true ? negativeCacheTtl : cacheTtl,
      () async {
        try {
          final json = kind == TmdbKind.movie
              ? await ctx.client.movie(
                  id,
                  language: ctx.language,
                  imageLanguages: ctx.imageLanguages,
                )
              : await ctx.client.tv(
                  id,
                  language: ctx.language,
                  imageLanguages: ctx.imageLanguages,
                );
          return trimDetails(json);
        } on TmdbException catch (e) {
          if (e.kind != TmdbErrorKind.notFound) rethrow;
          return const {_missingKey: true};
        }
      },
    );
    return json[_missingKey] == true ? null : json;
  }

  static const _missingKey = '_missing';

  Future<int?> _searchId(_Context ctx, TmdbKind kind, String title, int? year) {
    final cleaned = searchTitle(title);
    final y = year ?? yearInTitle(title);
    final normalized = normalizeForSearch(cleaned);
    if (normalized.isEmpty) return Future.value();
    final cacheKey =
        'search:${kind.path}:$normalized:${y ?? ''}:${ctx.language}';
    return _once<int?>(cacheKey, () async {
      final cached = await _readCache(cacheKey);
      if (cached != null) {
        final id = asPositiveInt(cached.json['id']);
        final ttl = id == null ? negativeCacheTtl : cacheTtl;
        if (_clock().difference(cached.fetchedAt) <= ttl) return id;
      }
      var response = await _pool.run(
        () => ctx.client.search(kind, cleaned, year: y, language: ctx.language),
      );
      var id = pickSearchResult(response['results'], cleaned, y);
      if (id == null && y != null) {
        response = await _pool.run(
          () => ctx.client.search(kind, cleaned, language: ctx.language),
        );
        id = pickSearchResult(response['results'], cleaned, y);
      }
      await _writeCache(cacheKey, {'id': id});
      return id;
    });
  }

  /// Cache-or-fetch through the queue; concurrent callers share one fetch.
  Future<Map<String, Object?>> _cachedFetch(
    String cacheKey,
    Duration Function(Map<String, Object?> json) ttlOf,
    Future<Map<String, Object?>> Function() fetch,
  ) => _once(cacheKey, () async {
    final cached = await _readCache(cacheKey);
    if (cached != null &&
        _clock().difference(cached.fetchedAt) <= ttlOf(cached.json)) {
      return cached.json;
    }
    final json = await _pool.run(fetch);
    await _writeCache(cacheKey, json);
    return json;
  });

  Future<T> _once<T>(String key, Future<T> Function() run) {
    final running = _inFlight[key];
    if (running != null) return running.then((v) => v as T);
    final future = run();
    _inFlight[key] = future;
    future.whenComplete(() => _inFlight.remove(key)).ignore();
    return future;
  }

  Future<({Map<String, Object?> json, DateTime fetchedAt})?> _readCache(
    String key,
  ) async {
    final row = await (_db.select(
      _db.tmdbCache,
    )..where((c) => c.cacheKey.equals(key))).getSingleOrNull();
    if (row == null) return null;
    try {
      final json = jsonDecode(row.json);
      if (json is Map<String, Object?>) {
        return (json: json, fetchedAt: row.fetchedAt);
      }
    } on FormatException {
      // corrupt entry: refetch
    }
    return null;
  }

  Future<void> _writeCache(String key, Map<String, Object?> json) => _db
      .into(_db.tmdbCache)
      .insertOnConflictUpdate(
        TmdbCacheCompanion.insert(
          cacheKey: key,
          json: jsonEncode(json),
          fetchedAt: _clock(),
        ),
      );

  Future<_Context?> _context() async {
    if (!_settings.get(AppSettings.tmdbEnabled)) return null;
    final key = await _readKey();
    if (key == null || key.isEmpty) return null;
    if (_client == null || _clientKey != key) {
      _client = TmdbClient(_http(), key, baseUrl: baseUrl);
      _clientKey = key;
    }
    final lang = language();
    final iso = lang.split('-').first.toLowerCase();
    return _Context(
      client: _client!,
      language: lang,
      imageLanguage: iso,
      imageLanguages: iso == 'en' ? 'en,null' : '$iso,en,null',
      region: region(),
    );
  }

  Future<String?> _readKey() async {
    final readAt = _keyReadAt;
    if (readAt != null && _clock().difference(readAt) < keyCacheTtl) {
      return _key;
    }
    final value = (await _secrets.read(SecretStore.tmdbKey))?.trim();
    _key = (value == null || value.isEmpty) ? null : value;
    _keyReadAt = _clock();
    return _key;
  }

  Dio _http() => _dio ??= _dioFactory();
}

class _Context {
  _Context({
    required this.client,
    required this.language,
    required this.imageLanguage,
    required this.imageLanguages,
    required this.region,
  });

  final TmdbClient client;

  /// `tr-TR`.
  final String language;

  /// `tr`.
  final String imageLanguage;

  /// `tr,en,null`.
  final String imageLanguages;
  final String region;
}

/// At most [max] tasks run at once; the rest wait in FIFO order.
class _Pool {
  _Pool(int max) : max = max < 1 ? 1 : max;

  final int max;
  int _active = 0;
  final Queue<Completer<void>> _waiting = Queue();

  Future<T> run<T>(Future<T> Function() task) async {
    if (_active >= max) {
      final turn = Completer<void>();
      _waiting.add(turn);
      await turn.future;
    } else {
      _active++;
    }
    try {
      return await task();
    } finally {
      if (_waiting.isNotEmpty) {
        _waiting.removeFirst().complete();
      } else {
        _active--;
      }
    }
  }
}

/// A tiny insertion-ordered LRU map.
class _Lru<K, V> {
  _Lru(this.capacity);

  final int capacity;
  final LinkedHashMap<K, V> _map = LinkedHashMap();

  bool containsKey(K key) => _map.containsKey(key);

  V? operator [](K key) {
    if (!_map.containsKey(key)) return null;
    final value = _map.remove(key) as V;
    _map[key] = value;
    return value;
  }

  void operator []=(K key, V value) {
    _map.remove(key);
    _map[key] = value;
    if (_map.length > capacity) _map.remove(_map.keys.first);
  }

  void clear() => _map.clear();
}

const Map<String, String> _defaultRegions = {
  'tr': 'tr-TR',
  'en': 'en-US',
  'de': 'de-DE',
  'fr': 'fr-FR',
  'es': 'es-ES',
  'it': 'it-IT',
  'nl': 'nl-NL',
  'pt': 'pt-PT',
  'ru': 'ru-RU',
  'ar': 'ar-SA',
  'ja': 'ja-JP',
  'ko': 'ko-KR',
  'zh': 'zh-CN',
};

/// TMDb `language` tag for an app / system locale: `tr` → `tr-TR`,
/// `en_US.UTF-8` → `en-US`, `C` / blank → `en-US`.
String tmdbLanguageTag(String locale) {
  final cleaned = locale.replaceAll('_', '-').split('.').first.trim();
  final parts = cleaned.split('-');
  final lang = parts.first.toLowerCase();
  if (lang.length != 2) return 'en-US';
  if (parts.length > 1 && parts[1].length == 2) {
    return '$lang-${parts[1].toUpperCase()}';
  }
  return _defaultRegions[lang] ?? lang;
}

final RegExp _bracketYear = RegExp(r'[\(\[]\s*((?:19|20)\d{2})\s*[\)\]]');
final RegExp _spaces = RegExp(r'\s+');

/// The title sent to TMDb search: country prefix (`TR:`), bracketed year
/// (`(2014)`) and quality tokens (`FHD`) removed.
String searchTitle(String title) {
  var t = stripCountryPrefix(title.trim());
  t = t.replaceAll(_bracketYear, ' ');
  t = parseQuality(t).displayName;
  t = t.replaceAll(_spaces, ' ').trim();
  return t.isEmpty ? title.trim() : t;
}

/// A year in brackets in [title] (`Kış Uykusu (2014)` → 2014).
int? yearInTitle(String title) {
  final m = _bracketYear.firstMatch(title);
  return m == null ? null : int.parse(m[1]!);
}

/// Picks the search result for [wanted] (+ [year]): an exact normalized
/// title (or original title) match first, then a partial one; the year
/// breaks ties (±1 tolerated); results whose title is unrelated are never
/// picked. Earlier results win remaining ties (TMDb relevance order).
int? pickSearchResult(Object? results, String wanted, int? year) {
  final key = normalizeForSearch(wanted);
  if (key.isEmpty) return null;
  int? bestId;
  var bestScore = -1 << 30;
  for (final raw in asList(results)) {
    final r = asMap(raw);
    final id = asPositiveInt(r['id']);
    if (id == null) continue;
    final titles = [
      for (final f in const [
        'title',
        'original_title',
        'name',
        'original_name',
      ])
        if (asString(r[f]) case final t?) normalizeForSearch(t),
    ];
    final exact = titles.contains(key);
    final partial =
        !exact &&
        titles.any((t) => t.isNotEmpty && (t.contains(key) || key.contains(t)));
    if (!exact && !partial) continue;
    var score = exact ? 4 : 1;
    final ry = asYear(r['release_date'] ?? r['first_air_date']);
    if (year != null && ry != null) {
      final diff = (ry - year).abs();
      score += diff == 0 ? 3 : (diff == 1 ? 1 : -2);
    }
    if (score > bestScore) {
      bestScore = score;
      bestId = id;
    }
  }
  return bestId;
}

/// Keeps the fields [TmdbEnrichment.fromDetails] reads, so cached entries
/// stay a few KB instead of the full response.
Map<String, Object?> trimDetails(Map<String, Object?> json) {
  Map<String, Object?> pick(Object? raw, List<String> keys) {
    final m = asMap(raw);
    return {
      for (final k in keys)
        if (m[k] != null) k: m[k],
    };
  }

  final images = asMap(json['images']);
  final cast =
      asList(asMap(json['credits'])['cast'])
          .map((c) => pick(c, const ['name', 'order']))
          .toList()
        ..sort(
          (a, b) => (asInt(a['order']) ?? 1 << 20).compareTo(
            asInt(b['order']) ?? 1 << 20,
          ),
        );
  return {
    for (final k in const [
      'id',
      'title',
      'name',
      'original_title',
      'original_name',
      'overview',
      'tagline',
      'backdrop_path',
      'poster_path',
      'genres',
      'runtime',
      'episode_run_time',
      'number_of_seasons',
      'number_of_episodes',
      'vote_average',
      'vote_count',
      'release_date',
      'first_air_date',
      'release_dates',
      'content_ratings',
    ])
      if (json[k] != null) k: json[k],
    if (json['last_episode_to_air'] != null)
      'last_episode_to_air': pick(json['last_episode_to_air'], const [
        'runtime',
      ]),
    if (json['next_episode_to_air'] != null)
      'next_episode_to_air': pick(json['next_episode_to_air'], const [
        'runtime',
      ]),
    'images': {
      'logos': [
        for (final l in asList(images['logos']))
          pick(l, const ['file_path', 'iso_639_1', 'vote_average', 'width']),
      ],
      'backdrops': [
        for (final b in asList(images['backdrops']).take(3))
          pick(b, const ['file_path', 'iso_639_1']),
      ],
      'posters': [
        for (final p in asList(images['posters']).take(3))
          pick(p, const ['file_path', 'iso_639_1']),
      ],
    },
    'credits': {'cast': cast.take(10).toList()},
    'videos': {
      'results': [
        for (final v in asList(asMap(json['videos'])['results']))
          if (asString(asMap(v)['site'])?.toLowerCase() == 'youtube')
            pick(v, const ['key', 'site', 'type', 'official', 'iso_639_1']),
      ],
    },
  };
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final tmdbServiceProvider = Provider<TmdbService>((ref) {
  final service = TmdbService(
    db: ref.watch(appDatabaseProvider),
    settings: ref.watch(settingsStoreProvider),
    secrets: ref.watch(secretStoreProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Lookup arguments for the enrichment providers.
typedef TmdbLookupArgs = ({int? tmdbId, String title, int? year});

/// Movie enrichment (null without TMDb). Re-evaluates when settings change.
final movieEnrichmentProvider = FutureProvider.autoDispose
    .family<TmdbEnrichment?, TmdbLookupArgs>((ref, a) {
      ref.watch(settingsRevisionProvider);
      return ref
          .watch(tmdbServiceProvider)
          .enrichMovie(tmdbId: a.tmdbId, title: a.title, year: a.year);
    });

/// Series enrichment (null without TMDb).
final seriesEnrichmentProvider = FutureProvider.autoDispose
    .family<TmdbEnrichment?, TmdbLookupArgs>((ref, a) {
      ref.watch(settingsRevisionProvider);
      return ref
          .watch(tmdbServiceProvider)
          .enrichSeries(tmdbId: a.tmdbId, title: a.title, year: a.year);
    });

/// Trending this week (null without TMDb: hide the row).
final tmdbTrendingProvider = FutureProvider.autoDispose
    .family<List<TmdbTrendingItem>?, TmdbKind>((ref, kind) {
      ref.watch(settingsRevisionProvider);
      return ref.watch(tmdbServiceProvider).trending(kind);
    });
