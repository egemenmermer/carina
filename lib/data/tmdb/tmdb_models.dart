/// TMDb view models.
library;

import 'package:flutter/foundation.dart';

import '../sources/xtream/json_utils.dart';

/// Which TMDb collection an item belongs to.
enum TmdbKind {
  movie,
  tv;

  /// Path segment (`movie` / `tv`).
  String get path => name;
}

/// Result of checking a TMDb credential.
enum TmdbKeyStatus {
  /// The key works.
  ok,

  /// TMDb rejected it (HTTP 401).
  invalid,

  /// TMDb could not be reached (or answered with an unexpected status).
  unreachable,
}

/// How a credential is sent: a v3 API key as `api_key=`, or a v4 read
/// access token as `Authorization: Bearer`.
enum TmdbAuthMode { apiKey, bearer }

/// Why a TMDb call failed. Messages never contain the credential.
enum TmdbErrorKind {
  unauthorized,
  notFound,
  rateLimited,
  http,
  network,
  unparseable,
}

class TmdbException implements Exception {
  const TmdbException(this.kind, {this.statusCode, this.message});

  final TmdbErrorKind kind;
  final int? statusCode;
  final String? message;

  @override
  String toString() =>
      'TmdbException(${kind.name}'
      '${statusCode == null ? '' : ', $statusCode'}'
      '${message == null ? '' : ', $message'})';
}

/// TMDb image base URL.
const String tmdbImageBase = 'https://image.tmdb.org/t/p/';

String? tmdbImage(String size, Object? path) {
  final p = asString(path);
  if (p == null) return null;
  if (p.startsWith('http://') || p.startsWith('https://')) return p;
  return '$tmdbImageBase$size${p.startsWith('/') ? '' : '/'}$p';
}

/// Artwork and metadata for a hero / detail sheet.
@immutable
class TmdbEnrichment {
  const TmdbEnrichment({
    required this.kind,
    required this.tmdbId,
    this.title,
    this.originalTitle,
    this.overview,
    this.tagline,
    this.backdropUrl,
    this.posterUrl,
    this.logoUrl,
    this.genres = const [],
    this.cast = const [],
    this.runtimeMinutes,
    this.numberOfSeasons,
    this.numberOfEpisodes,
    this.voteAverage,
    this.voteCount,
    this.certification,
    this.year,
    this.trailerYoutubeKey,
  });

  /// Maps a details response (with `images`, `credits`,
  /// `release_dates` / `content_ratings` and `videos` appended).
  ///
  /// [imageLanguage] is the preferred logo language (then `en`, then
  /// textless); [region] picks the certification (fallback `US`).
  factory TmdbEnrichment.fromDetails(
    TmdbKind kind,
    Map<String, Object?> json, {
    required String imageLanguage,
    required String region,
  }) {
    final images = asMap(json['images']);
    final runtime = kind == TmdbKind.movie
        ? asPositiveInt(json['runtime'])
        : _tvRuntime(json);
    final date = asString(
      kind == TmdbKind.movie ? json['release_date'] : json['first_air_date'],
    );
    return TmdbEnrichment(
      kind: kind,
      tmdbId: asInt(json['id']) ?? 0,
      title: asString(kind == TmdbKind.movie ? json['title'] : json['name']),
      originalTitle: asString(
        kind == TmdbKind.movie ? json['original_title'] : json['original_name'],
      ),
      overview: asString(json['overview']),
      tagline: asString(json['tagline']),
      backdropUrl:
          tmdbImage('w1280', json['backdrop_path']) ??
          tmdbImage('w1280', _firstPath(images['backdrops'])),
      posterUrl:
          tmdbImage('w500', json['poster_path']) ??
          tmdbImage('w500', _firstPath(images['posters'])),
      logoUrl: tmdbImage(
        'original',
        bestLogoPath(images['logos'], imageLanguage),
      ),
      genres: List.unmodifiable([
        for (final g in asList(json['genres'])) ?asString(asMap(g)['name']),
      ]),
      cast: _topCast(asMap(json['credits'])['cast']),
      runtimeMinutes: runtime,
      numberOfSeasons: kind == TmdbKind.tv
          ? asPositiveInt(json['number_of_seasons'])
          : null,
      numberOfEpisodes: kind == TmdbKind.tv
          ? asPositiveInt(json['number_of_episodes'])
          : null,
      voteAverage: asDouble(json['vote_average']),
      voteCount: asInt(json['vote_count']),
      certification: kind == TmdbKind.movie
          ? movieCertification(json['release_dates'], region)
          : tvCertification(json['content_ratings'], region),
      year: asYear(date),
      trailerYoutubeKey: _trailerKey(json['videos'], imageLanguage),
    );
  }

  final TmdbKind kind;
  final int tmdbId;
  final String? title;
  final String? originalTitle;
  final String? overview;
  final String? tagline;

  /// `w1280` backdrop.
  final String? backdropUrl;

  /// `w500` poster.
  final String? posterUrl;

  /// Title logo (`original` size), preferring the metadata language, then
  /// English, then a language-neutral logo.
  final String? logoUrl;
  final List<String> genres;

  /// Top 10 cast names in billing order.
  final List<String> cast;

  /// Movie runtime or TV episode run time, in minutes.
  final int? runtimeMinutes;
  final int? numberOfSeasons;
  final int? numberOfEpisodes;

  /// 0–10.
  final double? voteAverage;
  final int? voteCount;

  /// Age rating for the configured region (fallback US), e.g. `PG-13`,
  /// `TV-MA`, `16+`.
  final String? certification;
  final int? year;
  final String? trailerYoutubeKey;

  /// `vote_average × 10`, e.g. 76 for "★ 76%".
  int? get votePercent => voteAverage == null || voteAverage! <= 0
      ? null
      : (voteAverage! * 10).round();

  @override
  String toString() => 'TmdbEnrichment(${kind.name} $tmdbId "$title")';
}

/// One `trending/{movie|tv}/week` entry.
@immutable
class TmdbTrendingItem {
  const TmdbTrendingItem({
    required this.kind,
    required this.tmdbId,
    required this.rank,
    required this.title,
    this.originalTitle,
    this.year,
    this.posterUrl,
    this.backdropUrl,
    this.voteAverage,
  });

  /// Null for entries without an id.
  static TmdbTrendingItem? fromJson(TmdbKind kind, Object? raw, int rank) {
    final json = asMap(raw);
    final id = asPositiveInt(json['id']);
    if (id == null) return null;
    final movie = kind == TmdbKind.movie;
    final title = asString(movie ? json['title'] : json['name']);
    final original = asString(
      movie ? json['original_title'] : json['original_name'],
    );
    return TmdbTrendingItem(
      kind: kind,
      tmdbId: id,
      rank: rank,
      title: title ?? original ?? '',
      originalTitle: original,
      year: asYear(movie ? json['release_date'] : json['first_air_date']),
      posterUrl: tmdbImage('w500', json['poster_path']),
      backdropUrl: tmdbImage('w1280', json['backdrop_path']),
      voteAverage: asDouble(json['vote_average']),
    );
  }

  final TmdbKind kind;
  final int tmdbId;

  /// 1-based position in the trending list.
  final int rank;
  final String title;
  final String? originalTitle;
  final int? year;
  final String? posterUrl;
  final String? backdropUrl;
  final double? voteAverage;

  @override
  String toString() => 'TmdbTrendingItem(#$rank $tmdbId "$title")';
}

/// Picks the best logo from `images.logos`: the [language] first, then
/// `en`, then language-neutral (`null`); within a language PNG over SVG
/// (Flutter cannot paint SVG without a plugin), then the highest vote
/// average, then the widest. Logos in other languages are ignored.
String? bestLogoPath(Object? logos, String language) {
  final lang = language.toLowerCase();
  int? rankOf(String? iso) {
    final l = iso?.toLowerCase();
    if (l == lang) return 0;
    if (l == 'en') return 1;
    if (l == null || l.isEmpty || l == 'xx') return 2;
    return null;
  }

  Map<String, Object?>? best;
  late List<num> bestKey;
  for (final raw in asList(logos)) {
    final logo = asMap(raw);
    final path = asString(logo['file_path']);
    if (path == null) continue;
    final rank = rankOf(asString(logo['iso_639_1']));
    if (rank == null) continue;
    final svg = path.toLowerCase().endsWith('.svg') ? 1 : 0;
    final key = <num>[
      rank,
      svg,
      -(asDouble(logo['vote_average']) ?? 0),
      -(asInt(logo['width']) ?? 0),
    ];
    if (best == null || _lexLess(key, bestKey)) {
      best = logo;
      bestKey = key;
    }
  }
  return best == null ? null : asString(best['file_path']);
}

/// Movie certification from `release_dates` for [region] (else `US`):
/// theatrical (type 3) first, then digital (4), then any non-empty one.
String? movieCertification(Object? releaseDates, String region) {
  final results = asList(asMap(releaseDates)['results']);
  String? forRegion(String code) {
    for (final raw in results) {
      final entry = asMap(raw);
      if (asString(entry['iso_3166_1'])?.toUpperCase() != code) continue;
      final dates = asList(entry['release_dates']).map(asMap).toList();
      for (final type in const [3, 4, 5, 6, 2, 1]) {
        for (final d in dates) {
          final cert = asString(d['certification']);
          if (cert != null && asInt(d['type']) == type) return cert;
        }
      }
      for (final d in dates) {
        final cert = asString(d['certification']);
        if (cert != null) return cert;
      }
    }
    return null;
  }

  final code = region.toUpperCase();
  return forRegion(code) ?? (code == 'US' ? null : forRegion('US'));
}

/// TV certification from `content_ratings` for [region] (else `US`).
String? tvCertification(Object? contentRatings, String region) {
  final results = asList(asMap(contentRatings)['results']);
  String? forRegion(String code) {
    for (final raw in results) {
      final entry = asMap(raw);
      if (asString(entry['iso_3166_1'])?.toUpperCase() != code) continue;
      final rating = asString(entry['rating']);
      if (rating != null) return rating;
    }
    return null;
  }

  final code = region.toUpperCase();
  return forRegion(code) ?? (code == 'US' ? null : forRegion('US'));
}

bool _lexLess(List<num> a, List<num> b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return a[i] < b[i];
  }
  return false;
}

String? _firstPath(Object? list) {
  for (final raw in asList(list)) {
    final path = asString(asMap(raw)['file_path']);
    if (path != null) return path;
  }
  return null;
}

int? _tvRuntime(Map<String, Object?> json) {
  for (final v in asList(json['episode_run_time'])) {
    final n = asPositiveInt(v);
    if (n != null) return n;
  }
  return asPositiveInt(asMap(json['last_episode_to_air'])['runtime']) ??
      asPositiveInt(asMap(json['next_episode_to_air'])['runtime']);
}

List<String> _topCast(Object? cast) {
  final people = asList(cast).map(asMap).toList()
    ..sort(
      (a, b) => (asInt(a['order']) ?? 1 << 20).compareTo(
        asInt(b['order']) ?? 1 << 20,
      ),
    );
  final out = <String>[];
  for (final p in people) {
    final name = asString(p['name']);
    if (name != null && !out.contains(name)) out.add(name);
    if (out.length == 10) break;
  }
  return List.unmodifiable(out);
}

String? _trailerKey(Object? videos, String language) {
  final list = [
    for (final raw in asList(asMap(videos)['results']))
      if (asString(asMap(raw)['site'])?.toLowerCase() == 'youtube' &&
          asString(asMap(raw)['key']) != null)
        asMap(raw),
  ];
  int score(Map<String, Object?> v) {
    var s = 0;
    final type = asString(v['type']);
    if (type == 'Trailer') s += 4;
    if (type == 'Teaser') s += 1;
    if (asBool(v['official']) ?? false) s += 2;
    if (asString(v['iso_639_1'])?.toLowerCase() == language) s += 1;
    return s;
  }

  if (list.isEmpty) return null;
  var best = list.first;
  for (final v in list.skip(1)) {
    if (score(v) > score(best)) best = v;
  }
  return asString(best['key']);
}
