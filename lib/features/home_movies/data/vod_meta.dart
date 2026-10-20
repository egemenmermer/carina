/// Display metadata of a movie or show for the hero and the detail sheets:
/// the library card merged with the provider details (`get_vod_info` /
/// `get_series_info`, fetched lazily) and the optional TMDb enrichment
/// (null without a key — everything here must look good without it).
library;

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../../data/db/database.dart';
import '../../../data/repositories/vod_repository.dart';
import '../../../data/tmdb/tmdb_models.dart';

/// Hero / sheet metadata.
///
/// Priorities: backdrop = provider → TMDb (the hero falls back to the
/// poster, blurred); genres, cast, overview and certification prefer TMDb
/// (localized, clean) and fall back to the provider; the rating is TMDb's
/// `★ 76% (1.3k reviews)` when known, else the provider's `★ 7.6`.
@immutable
class VodMeta {
  const VodMeta({
    required this.kind,
    required this.providerId,
    required this.title,
    this.rawName = '',
    this.logoUrl,
    this.backdropUrl,
    this.posterUrl,
    this.genres = const [],
    this.cast = const [],
    this.director,
    this.runtime,
    this.seasonCount,
    this.episodeCount,
    this.year,
    this.releaseDate,
    this.votePercent,
    this.voteCount,
    this.providerRating,
    this.ageRating,
    this.tagline,
    this.overview,
    this.technical,
    this.isFavorite = false,
    this.watched = false,
    this.detailsLoaded = false,
  });

  final SectionKind kind;
  final String providerId;

  /// Display title ([vodDisplayTitle] of the provider name).
  final String title;

  /// The provider name as delivered.
  final String rawName;

  /// TMDb title logo.
  final String? logoUrl;

  /// Best wide artwork; null when only a poster exists.
  final String? backdropUrl;
  final String? posterUrl;
  final List<String> genres;
  final List<String> cast;
  final String? director;

  /// Movie runtime (series: the episode run time when known).
  final Duration? runtime;

  /// Regular seasons / their episodes (series).
  final int? seasonCount;
  final int? episodeCount;
  final int? year;

  /// Series first air date / movie release date.
  final DateTime? releaseDate;

  /// TMDb `vote_average × 10`.
  final int? votePercent;
  final int? voteCount;

  /// Provider rating 0–10.
  final double? providerRating;

  /// `PG-13`, `TV-MA`, `16+`…
  final String? ageRating;
  final String? tagline;
  final String? overview;
  final MediaTechnical? technical;
  final bool isFavorite;
  final bool watched;

  /// Provider details (or TMDb) were merged in.
  final bool detailsLoaded;

  bool get isSeries => kind == SectionKind.series;

  /// Whether a rating line can be shown.
  bool get hasRating =>
      votePercent != null || (providerRating != null && providerRating! > 0);
}

/// Merges the card [item] with the provider [movie] / [series] details and
/// the TMDb [tmdb] enrichment.
VodMeta buildVodMeta({
  required VodItem item,
  MovieDetails? movie,
  SeriesDetails? series,
  TmdbEnrichment? tmdb,
}) {
  final providerBackdrop = item.backdrop ?? movie?.backdrop ?? series?.backdrop;
  final providerGenres = movie?.genres.isNotEmpty == true
      ? movie!.genres
      : series?.genres.isNotEmpty == true
      ? series!.genres
      : splitGenres(item.genre);
  final providerCast = movie?.cast.isNotEmpty == true
      ? movie!.cast
      : (series?.cast ?? const <String>[]);
  final tmdbRuntime = tmdb?.runtimeMinutes;
  final seasons = series?.seasonCount;
  final episodes = series?.episodeCount;
  return VodMeta(
    kind: item.kind,
    providerId: item.providerId,
    title: vodDisplayTitle(item.name),
    rawName: item.name,
    logoUrl: tmdb?.logoUrl,
    backdropUrl: providerBackdrop ?? tmdb?.backdropUrl,
    posterUrl: item.poster ?? movie?.poster ?? series?.cover ?? tmdb?.posterUrl,
    genres: (tmdb?.genres.isNotEmpty ?? false) ? tmdb!.genres : providerGenres,
    cast: (tmdb?.cast.isNotEmpty ?? false) ? tmdb!.cast : providerCast,
    director: movie?.director ?? series?.director,
    runtime:
        movie?.duration ??
        series?.episodeRunTime ??
        (tmdbRuntime == null ? null : Duration(minutes: tmdbRuntime)),
    seasonCount: (seasons != null && seasons > 0)
        ? seasons
        : tmdb?.numberOfSeasons,
    episodeCount: (episodes != null && episodes > 0)
        ? episodes
        : tmdb?.numberOfEpisodes,
    year: item.year ?? movie?.year ?? series?.year ?? tmdb?.year,
    releaseDate: movie?.releaseDateParsed ?? series?.releaseDateParsed,
    votePercent: tmdb?.votePercent,
    voteCount: tmdb?.voteCount,
    providerRating: movie?.rating ?? series?.rating ?? item.rating,
    ageRating: _nonBlank(tmdb?.certification) ?? _nonBlank(movie?.ageRating),
    tagline: _nonBlank(tmdb?.tagline),
    overview:
        _nonBlank(tmdb?.overview) ??
        _nonBlank(movie?.plot) ??
        _nonBlank(series?.plot) ??
        _nonBlank(item.plot),
    technical: movie?.technical,
    isFavorite: item.isFavorite,
    watched: item.watched,
    detailsLoaded: movie != null || series != null || tmdb != null,
  );
}

String? _nonBlank(String? s) {
  final t = s?.trim();
  return (t == null || t.isEmpty) ? null : t;
}

// ---------------------------------------------------------------------------
// Text helpers
// ---------------------------------------------------------------------------

final RegExp _leadingTag = RegExp(
  r'^\s*(?:\[[^\]]{1,24}\]|\((?:[A-Za-z]{2,3})\)|\|[A-Z]{2}\||'
  r'(?:[A-Z]{2}|4K|UHD|FHD|HD)\s*[:|\-–]\s)\s*',
);
final RegExp _trailingYear = RegExp(r'\s*[\(\[]((?:19|20)\d{2})[\)\]]\s*$');
final RegExp _trailingQuality = RegExp(
  r'\s+(?:4K|8K|UHD|FHD|HD|SD|HEVC|H\.?265|HDR)\s*$',
  caseSensitive: false,
);

/// A provider title for display: drops a leading country / quality / tag
/// prefix (`TR: `, `4K | `, `[Altyazılı] `), a trailing `(2019)` and
/// trailing quality tokens. Returns [raw] trimmed when nothing is left.
String vodDisplayTitle(String raw) {
  var s = raw.trim();
  for (var i = 0; i < 2; i++) {
    final next = s.replaceFirst(_leadingTag, '');
    if (next == s || next.trim().isEmpty) break;
    s = next;
  }
  for (var i = 0; i < 3; i++) {
    final next = s.replaceFirst(_trailingQuality, '');
    if (next == s || next.trim().isEmpty) break;
    s = next;
  }
  final noYear = s.replaceFirst(_trailingYear, '');
  if (noYear.trim().isNotEmpty) s = noYear;
  s = s.trim();
  return s.isEmpty ? raw.trim() : s;
}

/// The year in a trailing `(2019)` of [raw], if any.
int? vodTitleYear(String raw) {
  final m = _trailingYear.firstMatch(raw.trim());
  return m == null ? null : int.tryParse(m.group(1)!);
}

final RegExp _turkishLetters = RegExp('[ğışĞİŞ]');

/// Whether [text] contains letters only Turkish uses (ğ ı ş İ), a hint
/// that metadata from the same provider (genres) is Turkish too.
bool vodLooksTurkish(String text) => _turkishLetters.hasMatch(text);

/// Uppercase for metadata lines (`FAMILY • FANTASY`). Turkish casing
/// (`i` → `İ`) applies when [turkish] is set or the text is evidently
/// Turkish.
String vodUpper(String s, {bool turkish = false}) {
  if (!turkish && !_turkishLetters.hasMatch(s)) return s.toUpperCase();
  return s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
}

/// `1.5k`, `18k`, `1.2M` (English) / `1,5 B` (Turkish) for review counts.
String vodCompactCount(int n, String locale) {
  if (n < 1000) return '$n';
  final text = NumberFormat.compact(locale: locale).format(n);
  return locale.startsWith('en') ? text.toLowerCase() : text;
}

/// `7.6` / `7,6` provider rating.
String vodRatingText(double rating, String locale) =>
    NumberFormat('0.0', locale).format(rating);
