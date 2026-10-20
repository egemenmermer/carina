/// View models shared by the VOD-facing repositories (movies, series,
/// favorites, watch state, search) plus the SQL fragments they share.
///
/// Everything here is immutable and safe to hand to widgets. Times are local
/// `DateTime`s as drift reads them; positions and durations are [Duration]s.
library;

import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../db/database.dart';
import '../sources/source_exception.dart';
import '../text/normalize.dart';
import 'repository_models.dart' show collationKey;

// ---------------------------------------------------------------------------
// Thresholds
// ---------------------------------------------------------------------------

/// Below this fraction a position does not count as "in progress".
const double kInProgressMinFraction = 0.02;

/// At or above this fraction an item is marked watched.
const double kWatchedFraction = 0.95;

/// Items added (series: modified) within this window get a NEW badge.
const Duration kNewItemWindow = Duration(days: 7);

/// Cached `get_vod_info` / `get_series_info` responses older than this are
/// fetched again when the detail sheet opens.
const Duration kVodInfoMaxAge = Duration(days: 7);

// ---------------------------------------------------------------------------
// Orders
// ---------------------------------------------------------------------------

/// Sort options of movie / series grids.
enum VodSort {
  /// Provider order (`sortIndex`).
  playlist,

  /// Name, Turkish-aware and diacritics-insensitive.
  name,

  /// Date added (series: last modified), newest first.
  dateAdded,

  /// Provider rating, highest first.
  rating,

  /// Year, newest first.
  year,
}

/// `PlaylistSettings.categoriesOrder`.
enum CategoriesOrder {
  playlist,
  name,
  custom;

  static CategoriesOrder fromSetting(String? value) =>
      values.firstWhere((o) => o.name == value, orElse: () => playlist);
}

/// `PlaylistSettings.favoritesOrder`.
enum FavoritesOrder {
  /// Newest favorite first.
  lastAdded,

  /// By item name.
  name,

  /// Oldest favorite first.
  leastRecent,

  /// The user's drag order (`customIndex`).
  custom;

  static FavoritesOrder fromSetting(String? value) =>
      values.firstWhere((o) => o.name == value, orElse: () => lastAdded);
}

/// `PlaylistSettings.continueWatchingOrder`.
enum ContinueWatchingOrder {
  /// Most recently played first.
  lastUpdated,

  /// Newest library item first (movie `added`, series `lastModified`).
  lastAdded,

  /// By title.
  name;

  static ContinueWatchingOrder fromSetting(String? value) =>
      values.firstWhere((o) => o.name == value, orElse: () => lastUpdated);
}

// ---------------------------------------------------------------------------
// Cards
// ---------------------------------------------------------------------------

/// A movie or series card (poster rows, grids, hero, search results).
@immutable
class VodItem {
  const VodItem({
    required this.kind,
    required this.rowId,
    required this.providerId,
    required this.name,
    this.categoryId,
    this.poster,
    this.backdrop,
    this.rating,
    this.year,
    this.added,
    this.tmdbId,
    this.plot,
    this.genre,
    this.sortIndex = 0,
    this.hidden = false,
    this.isNew = false,
    this.isFavorite = false,
    this.watched = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  /// [SectionKind.movie] or [SectionKind.series].
  final SectionKind kind;

  /// Local row id (changes when an import deletes and re-adds the item; use
  /// [providerId] as the stable key).
  final int rowId;
  final String providerId;
  final String name;
  final String? categoryId;

  /// Movie poster / series cover.
  final String? poster;

  /// First provider backdrop (series list data, or cached movie info).
  final String? backdrop;

  /// Provider rating, 0–10.
  final double? rating;
  final int? year;

  /// Movie `added`; series `lastModified` (drives NEW badges).
  final DateTime? added;
  final int? tmdbId;

  /// Series plot / cached movie overview, when known.
  final String? plot;

  /// Raw provider genre text, when known.
  final String? genre;
  final int sortIndex;
  final bool hidden;

  /// Added (series: modified) within [kNewItemWindow].
  final bool isNew;
  final bool isFavorite;

  /// Watched flag of the movie or of the series as a whole.
  final bool watched;
  final Duration position;
  final Duration duration;

  ItemType get itemType =>
      kind == SectionKind.series ? ItemType.series : ItemType.movie;

  /// Played fraction (0–1) when a duration is known.
  double? get progress => progressOf(position, duration);

  /// Between [kInProgressMinFraction] and [kWatchedFraction] and not watched.
  bool get inProgress => !watched && isInProgress(position, duration);

  /// Best artwork for wide cards: backdrop, else poster.
  String? get art => backdrop ?? poster;

  @override
  bool operator ==(Object other) =>
      other is VodItem &&
      other.kind == kind &&
      other.rowId == rowId &&
      other.providerId == providerId &&
      other.name == name &&
      other.categoryId == categoryId &&
      other.poster == poster &&
      other.backdrop == backdrop &&
      other.rating == rating &&
      other.year == year &&
      other.added == added &&
      other.tmdbId == tmdbId &&
      other.plot == plot &&
      other.genre == genre &&
      other.sortIndex == sortIndex &&
      other.hidden == hidden &&
      other.isNew == isNew &&
      other.isFavorite == isFavorite &&
      other.watched == watched &&
      other.position == position &&
      other.duration == duration;

  @override
  int get hashCode => Object.hash(
    kind,
    rowId,
    providerId,
    name,
    poster,
    backdrop,
    rating,
    added,
    hidden,
    isFavorite,
    watched,
    position,
    duration,
  );

  @override
  String toString() => 'VodItem(${kind.name} $providerId "$name")';
}

/// A provider category of movies or series.
@immutable
class VodCategory {
  const VodCategory({
    required this.rowId,
    required this.kind,
    required this.providerId,
    required this.name,
    required this.providerName,
    this.parentId,
    this.sortIndex = 0,
    this.customIndex,
    this.hidden = false,
    this.locked = false,
  });

  factory VodCategory.fromRow(CategoryRow row) => VodCategory(
    rowId: row.id,
    kind: row.kind,
    providerId: row.providerId,
    name: _nonBlank(row.localName) ?? row.name,
    providerName: row.name,
    parentId: row.parentId,
    sortIndex: row.sortIndex,
    customIndex: row.customIndex,
    hidden: row.hidden,
    locked: row.locked,
  );

  final int rowId;
  final SectionKind kind;
  final String providerId;

  /// Local rename when set, else the provider name.
  final String name;
  final String providerName;
  final String? parentId;
  final int sortIndex;
  final int? customIndex;
  final bool hidden;
  final bool locked;

  bool get isRenamed => name != providerName;

  @override
  String toString() => 'VodCategory(${kind.name} $providerId "$name")';
}

/// One provider-category row of the Movies / Shows home.
@immutable
class VodHomeRow {
  const VodHomeRow({
    required this.category,
    required this.items,
    required this.totalCount,
  });

  final VodCategory category;

  /// The first items in provider order.
  final List<VodItem> items;

  /// Visible items in the category ("See All" count).
  final int totalCount;
}

// ---------------------------------------------------------------------------
// Details
// ---------------------------------------------------------------------------

/// Technical badges from `get_vod_info`.
@immutable
class MediaTechnical {
  const MediaTechnical({
    this.width,
    this.height,
    this.resolution,
    this.videoCodec,
    this.videoCodecName,
    this.hdr = false,
    this.frameRate,
    this.audioCodec,
    this.audioCodecName,
    this.audioChannels,
    this.audioLayout,
    this.bitrateKbps,
  });

  final int? width;
  final int? height;

  /// `SD`, `HD`, `FHD`, `4K` or `8K`.
  final String? resolution;

  /// Display codec: `H.264`, `HEVC`, `MPEG-2`, `AV1`…
  final String? videoCodec;

  /// Raw ffprobe codec name (`h264`, `hevc`…).
  final String? videoCodecName;
  final bool hdr;
  final double? frameRate;

  /// Display codec: `AAC`, `AC-3`, `E-AC-3`, `DTS`…
  final String? audioCodec;
  final String? audioCodecName;
  final int? audioChannels;

  /// `mono`, `stereo`, `5.1`, `7.1`, or the provider layout.
  final String? audioLayout;
  final int? bitrateKbps;

  bool get isEmpty =>
      resolution == null &&
      videoCodec == null &&
      audioCodec == null &&
      audioChannels == null &&
      bitrateKbps == null;

  /// Chips in display order, e.g. `FHD · HEVC · HDR · AC-3 5.1 · 8.2 Mbps`.
  List<String> get badges => [
    ?resolution,
    ?videoCodec,
    if (hdr) 'HDR',
    if (audioCodec != null || audioLayout != null)
      [?audioCodec, ?audioLayout].join(' '),
    if (bitrateKbps != null) formatBitrate(bitrateKbps!),
  ];

  /// `8.2 Mbps` / `950 kbps`.
  static String formatBitrate(int kbps) {
    if (kbps >= 1000) {
      final mbps = kbps / 1000;
      return '${mbps >= 10 ? mbps.round() : mbps.toStringAsFixed(1)} Mbps';
    }
    return '$kbps kbps';
  }
}

/// Movie detail sheet data. Built from the stored row plus the
/// lazily fetched `get_vod_info`; M3U movies only have the basic fields.
@immutable
class MovieDetails {
  const MovieDetails({
    required this.providerId,
    required this.name,
    this.originalName,
    this.categoryId,
    this.poster,
    this.backdrops = const [],
    this.plot,
    this.genres = const [],
    this.cast = const [],
    this.director,
    this.duration,
    this.ageRating,
    this.country,
    this.year,
    this.releaseDate,
    this.releaseDateParsed,
    this.rating,
    this.trailer,
    this.tmdbId,
    this.technical,
    this.containerExt,
    this.added,
    this.infoFetchedAt,
    this.hasProviderInfo = false,
    this.error,
  });

  final String providerId;
  final String name;
  final String? originalName;
  final String? categoryId;
  final String? poster;
  final List<String> backdrops;
  final String? plot;
  final List<String> genres;
  final List<String> cast;
  final String? director;
  final Duration? duration;

  /// `mpaa_rating`, else `age` (e.g. `PG-13`, `16+`).
  final String? ageRating;
  final String? country;
  final int? year;

  /// Raw release date text.
  final String? releaseDate;
  final DateTime? releaseDateParsed;

  /// 0–10.
  final double? rating;

  /// YouTube id or URL.
  final String? trailer;
  final int? tmdbId;
  final MediaTechnical? technical;
  final String? containerExt;
  final DateTime? added;
  final DateTime? infoFetchedAt;

  /// True when `get_vod_info` data (fresh or cached) was available.
  final bool hasProviderInfo;

  /// Set when fetching `get_vod_info` failed; the rest is the cached or
  /// basic data.
  final SourceException? error;

  String? get backdrop => backdrops.isEmpty ? null : backdrops.first;
}

/// One episode (series sheet rows, continue watching, next episode).
@immutable
class EpisodeItem {
  const EpisodeItem({
    required this.rowId,
    required this.providerId,
    required this.seriesId,
    required this.season,
    required this.episode,
    required this.title,
    this.plot,
    this.duration,
    this.releaseDate,
    this.image,
    this.rating,
    this.containerExt,
    this.streamUrl,
    this.directSource,
    this.added,
  });

  factory EpisodeItem.fromRow(EpisodeRow row) => EpisodeItem(
    rowId: row.id,
    providerId: row.providerId,
    seriesId: row.seriesId,
    season: row.season,
    episode: row.episodeNum,
    title: row.title,
    plot: row.plot,
    duration: row.durationSecs == null || row.durationSecs! <= 0
        ? null
        : Duration(seconds: row.durationSecs!),
    releaseDate: row.releaseDate,
    image: row.image,
    rating: row.rating,
    containerExt: row.containerExt,
    streamUrl: row.streamUrl,
    directSource: row.directSource,
    added: row.added,
  );

  final int rowId;

  /// Provider episode id (watch state / stream URL key).
  final String providerId;
  final String seriesId;
  final int season;
  final int episode;

  /// `''` when the provider sent none.
  final String title;
  final String? plot;
  final Duration? duration;

  /// Raw air date text.
  final String? releaseDate;
  final String? image;
  final double? rating;
  final String? containerExt;
  final String? streamUrl;
  final String? directSource;
  final DateTime? added;

  bool get isSpecial => season == 0;

  /// `S1 E2`.
  String get code => 'S$season E$episode';

  /// `S1 E2 · Title` (just the code when there is no title).
  String get label => episodeLabel(season, episode, title);

  @override
  bool operator ==(Object other) =>
      other is EpisodeItem &&
      other.providerId == providerId &&
      other.seriesId == seriesId &&
      other.season == season &&
      other.episode == episode &&
      other.title == title &&
      other.rowId == rowId;

  @override
  int get hashCode => Object.hash(providerId, seriesId, season, episode);

  @override
  String toString() => 'EpisodeItem($providerId $code)';
}

/// A season tab of the series sheet. Season 0 ([isSpecial]) is listed last;
/// the UI labels it "Special contents".
@immutable
class SeasonDetails {
  const SeasonDetails({
    required this.number,
    required this.episodes,
    this.name,
    this.cover,
    this.airDate,
    this.overview,
    this.declaredEpisodeCount,
  });

  final int number;

  /// Provider season name, if any (`Season 1`, `Sezon 1`, `Specials`).
  final String? name;
  final String? cover;
  final String? airDate;
  final String? overview;

  /// `episode_count` from the provider (may differ from [episodes]).
  final int? declaredEpisodeCount;

  /// Sorted by episode number.
  final List<EpisodeItem> episodes;

  bool get isSpecial => number == 0;
  int get episodeCount => episodes.length;
}

/// Series detail sheet data.
@immutable
class SeriesDetails {
  const SeriesDetails({
    required this.providerId,
    required this.name,
    required this.seasons,
    this.categoryId,
    this.cover,
    this.backdrops = const [],
    this.plot,
    this.cast = const [],
    this.genres = const [],
    this.director,
    this.releaseDate,
    this.releaseDateParsed,
    this.year,
    this.rating,
    this.trailer,
    this.tmdbId,
    this.episodeRunTime,
    this.lastModified,
    this.infoFetchedAt,
    this.error,
  });

  final String providerId;
  final String name;
  final String? categoryId;
  final String? cover;
  final List<String> backdrops;
  final String? plot;
  final List<String> cast;
  final List<String> genres;
  final String? director;
  final String? releaseDate;
  final DateTime? releaseDateParsed;
  final int? year;

  /// 0–10.
  final double? rating;
  final String? trailer;
  final int? tmdbId;
  final Duration? episodeRunTime;
  final DateTime? lastModified;
  final DateTime? infoFetchedAt;

  /// Seasons that have episodes: regular seasons ascending, then season 0
  /// ("Special contents").
  final List<SeasonDetails> seasons;

  /// Set when `get_series_info` failed; seasons are the stored ones.
  final SourceException? error;

  String? get backdrop => backdrops.isEmpty ? null : backdrops.first;

  /// Regular seasons (season 0 excluded) — the "5 SEASONS" count.
  int get seasonCount => seasons.where((s) => !s.isSpecial).length;

  /// Episodes of the regular seasons.
  int get episodeCount => seasons
      .where((s) => !s.isSpecial)
      .fold(0, (sum, s) => sum + s.episodes.length);

  /// Every episode including specials.
  int get totalEpisodeCount =>
      seasons.fold(0, (sum, s) => sum + s.episodes.length);

  /// First regular episode (else the first special).
  EpisodeItem? get firstEpisode {
    for (final s in seasons) {
      if (s.episodes.isNotEmpty) return s.episodes.first;
    }
    return null;
  }

  Iterable<EpisodeItem> get allEpisodes => seasons.expand((s) => s.episodes);
}

// ---------------------------------------------------------------------------
// Watch state
// ---------------------------------------------------------------------------

/// Resume position / watched flag of a movie, episode or series.
@immutable
class WatchState {
  const WatchState({
    required this.type,
    required this.providerId,
    required this.position,
    required this.duration,
    required this.watched,
    required this.updatedAt,
    this.seriesId,
  });

  factory WatchState.fromRow(WatchStateRow row) => WatchState(
    type: row.itemType,
    providerId: row.providerId,
    seriesId: row.seriesId,
    position: Duration(milliseconds: row.positionMs),
    duration: Duration(milliseconds: row.durationMs),
    watched: row.watched,
    updatedAt: row.updatedAt,
  );

  final ItemType type;
  final String providerId;

  /// Episodes: the provider series id.
  final String? seriesId;
  final Duration position;
  final Duration duration;
  final bool watched;
  final DateTime updatedAt;

  /// Played fraction (0–1) when a duration is known.
  double? get fraction => progressOf(position, duration);

  /// Between 2% and 95% and not watched.
  bool get inProgress => !watched && isInProgress(position, duration);

  /// Watched, or played to at least 95%.
  bool get finished => watched || (fraction ?? 0) >= kWatchedFraction;

  @override
  bool operator ==(Object other) =>
      other is WatchState &&
      other.type == type &&
      other.providerId == providerId &&
      other.seriesId == seriesId &&
      other.position == position &&
      other.duration == duration &&
      other.watched == watched &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    type,
    providerId,
    seriesId,
    position,
    duration,
    watched,
    updatedAt,
  );

  @override
  String toString() =>
      'WatchState(${type.name} $providerId ${position.inSeconds}s/'
      '${duration.inSeconds}s${watched ? ' watched' : ''})';
}

enum ResumeKind {
  /// Start from the beginning without asking.
  none,

  /// Ask "Resume from 12:34 / From the beginning".
  offer,

  /// Resume directly ("always resume" setting).
  resume,
}

/// What the player does when an item opens.
@immutable
class ResumeDecision {
  const ResumeDecision.none()
    : kind = ResumeKind.none,
      position = Duration.zero;
  const ResumeDecision.offer(this.position) : kind = ResumeKind.offer;
  const ResumeDecision.resume(this.position) : kind = ResumeKind.resume;

  final ResumeKind kind;
  final Duration position;

  @override
  bool operator ==(Object other) =>
      other is ResumeDecision &&
      other.kind == kind &&
      other.position == position;

  @override
  int get hashCode => Object.hash(kind, position);

  @override
  String toString() => 'ResumeDecision.${kind.name}(${position.inSeconds}s)';
}

/// A Continue watching card. For shows, [episode] is the episode to play
/// (the in-progress one, or the next one after a finished episode).
@immutable
class ContinueWatchingEntry {
  const ContinueWatchingEntry({
    required this.item,
    required this.position,
    required this.duration,
    required this.updatedAt,
    this.episode,
    this.isNextEpisode = false,
  });

  /// The movie or the series.
  final VodItem item;
  final EpisodeItem? episode;

  /// True when [episode] is the next episode after a finished one.
  final bool isNextEpisode;
  final Duration position;
  final Duration duration;

  /// When the item (series: its latest episode) was last played.
  final DateTime updatedAt;

  /// `S1 E2 · Title` for shows.
  String? get episodeLabel => episode?.label;

  double? get progress => progressOf(position, duration);

  /// Provider id of what plays: the episode or the movie.
  String get playId => episode?.providerId ?? item.providerId;

  @override
  String toString() =>
      'ContinueWatchingEntry(${item.providerId}'
      '${episode == null ? '' : ' ${episode!.code}'})';
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Played fraction (clamped to 0–1), or null without a duration.
double? progressOf(Duration position, Duration duration) {
  if (duration <= Duration.zero) return null;
  final f = position.inMilliseconds / duration.inMilliseconds;
  return f < 0 ? 0 : (f > 1 ? 1 : f);
}

/// Whether [position] is within the in-progress window (2%–95%).
bool isInProgress(Duration position, Duration duration) {
  final f = progressOf(position, duration);
  return f != null && f >= kInProgressMinFraction && f < kWatchedFraction;
}

/// `S1 E2 · Title`, or `S1 E2` without a title.
String episodeLabel(int season, int episode, String? title) {
  final code = 'S$season E$episode';
  final t = title?.trim() ?? '';
  return t.isEmpty ? code : '$code · $t';
}

/// Whether [addedOrModified] is within [window] of [now] (future timestamps
/// from skewed server clocks count as new).
bool isRecent(
  DateTime? addedOrModified,
  DateTime now, {
  Duration window = kNewItemWindow,
}) => addedOrModified != null && now.difference(addedOrModified) <= window;

final RegExp _genreSeparators = RegExp(r'\s*[,/|;]\s*');
final RegExp _peopleSeparators = RegExp(r'\s*[,;]\s*');

/// Splits provider genre text (`Dram, Komedi`, `Action / Adventure`).
List<String> splitGenres(String? text) => _splitUnique(text, _genreSeparators);

/// Splits provider cast / director text (`A, B, C`).
List<String> splitPeople(String? text) => _splitUnique(text, _peopleSeparators);

List<String> _splitUnique(String? text, RegExp separators) {
  if (text == null) return const [];
  final seen = <String>{};
  final out = <String>[];
  for (final part in text.split(separators)) {
    final p = part.trim();
    if (p.isEmpty) continue;
    final key = normalizeForSearch(p);
    if (seen.add(key.isEmpty ? p : key)) out.add(p);
  }
  return List.unmodifiable(out);
}

/// Decodes a JSON list of strings (e.g. `series.backdropsJson`); never
/// throws.
List<String> decodeStringList(String? json) {
  if (json == null || json.isEmpty) return const [];
  try {
    final value = jsonDecode(json);
    if (value is List) {
      return List.unmodifiable([
        for (final v in value)
          if (v is String && v.trim().isNotEmpty) v.trim(),
      ]);
    }
    if (value is String && value.trim().isNotEmpty) return [value.trim()];
  } on FormatException {
    // fall through
  }
  return const [];
}

String? _nonBlank(String? s) {
  final t = s?.trim();
  return (t == null || t.isEmpty) ? null : t;
}

/// Memoized name keys for large lists: [sortKey] orders names like the
/// rest of the app (`collationKey`: Turkish alphabet when the app language is
/// Turkish, numbers in numeric order) and [searchKey] filters them
/// ([normalizeForSearch]).
class NameKeys {
  NameKeys({this.maxEntries = 250000, bool Function()? turkish})
    : _turkish = turkish ?? _never;

  static bool _never() => false;

  final int maxEntries;
  final bool Function() _turkish;
  final Map<String, String> _sortKeys = {};
  final Map<String, String> _searchKeys = {};
  bool? _sortKeysTurkish;

  /// Collation key of [name] (see `collationKey`).
  String sortKey(String name) {
    final turkish = _turkish();
    if (turkish != _sortKeysTurkish) {
      _sortKeys.clear();
      _sortKeysTurkish = turkish;
    }
    final cached = _sortKeys[name];
    if (cached != null) return cached;
    if (_sortKeys.length >= maxEntries) _sortKeys.clear();
    return _sortKeys[name] = collationKey(name, turkish: turkish);
  }

  /// [normalizeForSearch] of [name].
  String searchKey(String name) {
    final cached = _searchKeys[name];
    if (cached != null) return cached;
    if (_searchKeys.length >= maxEntries) _searchKeys.clear();
    return _searchKeys[name] = normalizeForSearch(name);
  }

  /// Compares two names by collation key, then by raw text.
  int compare(String a, String b) {
    final c = sortKey(a).compareTo(sortKey(b));
    return c != 0 ? c : a.compareTo(b);
  }

  /// Stable sort of [items] by [nameOf] (nulls last).
  List<T> sort<T>(Iterable<T> items, String? Function(T) nameOf) {
    final list = items.toList();
    final keyed = [
      for (var i = 0; i < list.length; i++)
        (i: i, k: nameOf(list[i]), v: list[i]),
    ];
    keyed.sort((a, b) {
      final ka = a.k;
      final kb = b.k;
      if (ka == null || kb == null) {
        if (ka == null && kb == null) return a.i.compareTo(b.i);
        return ka == null ? 1 : -1;
      }
      final c = compare(ka, kb);
      return c != 0 ? c : a.i.compareTo(b.i);
    });
    return [for (final e in keyed) e.v];
  }
}

/// Maps every event of [source] through [convert], dropping intermediate
/// events while a conversion runs (the latest one is converted next). Used
/// for streams whose value needs several queries.
Stream<R> asyncMapLatest<T, R>(
  Stream<T> source,
  Future<R> Function(T event) convert,
) {
  late final StreamController<R> controller;
  StreamSubscription<T>? sub;
  var running = false;
  var cancelled = false;
  var sourceDone = false;
  var hasPending = false;
  T? pending;

  Future<void> run(T first) async {
    running = true;
    var current = first;
    while (!cancelled) {
      try {
        final value = await convert(current);
        if (!cancelled) controller.add(value);
      } catch (e, st) {
        if (!cancelled) controller.addError(e, st);
      }
      if (!hasPending) break;
      current = pending as T;
      pending = null;
      hasPending = false;
    }
    running = false;
    if (sourceDone && !cancelled) await controller.close();
  }

  controller = StreamController<R>(
    onListen: () {
      sub = source.listen(
        (event) {
          if (running) {
            pending = event;
            hasPending = true;
          } else {
            unawaited(run(event));
          }
        },
        onError: controller.addError,
        onDone: () {
          sourceDone = true;
          if (!running) controller.close();
        },
      );
    },
    onPause: () => sub?.pause(),
    onResume: () => sub?.resume(),
    onCancel: () {
      cancelled = true;
      return sub?.cancel();
    },
  );
  return controller.stream;
}

/// SQL fragments shared by the R2 repositories. Internal: the UI never sees
/// SQL; this only keeps the column lists in one place.
abstract final class VodSql {
  /// Columns read by [readVodItem] for `movies m`. Needs the aliases `f`
  /// (favorites, may be NULL) and `w` (watch_states, may be NULL).
  static const String movieColumns = '''
m.id AS row_id, m.provider_id AS provider_id, m.name AS name,
m.category_id AS category_id, m.poster AS poster, m.rating AS rating,
m.added AS added_at, m.year AS year, m.tmdb_id AS tmdb_id,
m.sort_index AS sort_index, m.hidden AS hidden,
CASE WHEN json_valid(m.info_json)
  THEN json_extract(m.info_json, '\$.info.backdrop_path[0]') END AS backdrop,
CASE WHEN json_valid(m.info_json)
  THEN COALESCE(json_extract(m.info_json, '\$.info.description'),
                json_extract(m.info_json, '\$.info.plot')) END AS plot,
CASE WHEN json_valid(m.info_json)
  THEN json_extract(m.info_json, '\$.info.genre') END AS genre,
f.id AS fav_id, w.position_ms AS position_ms, w.duration_ms AS duration_ms,
w.watched AS watched''';

  /// Columns read by [readVodItem] for `series s` (aliases `f`, `w`).
  static const String seriesColumns = '''
s.id AS row_id, s.provider_id AS provider_id, s.name AS name,
s.category_id AS category_id, s.cover AS poster, s.rating AS rating,
s.last_modified AS added_at, s.year AS year, s.tmdb_id AS tmdb_id,
s.sort_index AS sort_index, s.hidden AS hidden,
CASE WHEN json_valid(s.backdrops_json)
  THEN json_extract(s.backdrops_json, '\$[0]') END AS backdrop,
s.plot AS plot, s.genre AS genre,
f.id AS fav_id, w.position_ms AS position_ms, w.duration_ms AS duration_ms,
w.watched AS watched''';

  /// Item alias of [kind] (`m` / `s`).
  static String alias(SectionKind kind) =>
      kind == SectionKind.series ? 's' : 'm';

  static String table(SectionKind kind) =>
      kind == SectionKind.series ? 'series' : 'movies';

  static String columns(SectionKind kind) =>
      kind == SectionKind.series ? seriesColumns : movieColumns;

  static ItemType itemType(SectionKind kind) =>
      kind == SectionKind.series ? ItemType.series : ItemType.movie;

  /// `LEFT JOIN favorites f`.
  static String favoriteJoin(SectionKind kind) {
    final a = alias(kind);
    return 'LEFT JOIN favorites f ON f.playlist_id = $a.playlist_id '
        'AND f.item_type = ${itemType(kind).index} '
        'AND f.provider_id = $a.provider_id';
  }

  /// `LEFT JOIN watch_states w`.
  static String watchJoin(SectionKind kind) {
    final a = alias(kind);
    return 'LEFT JOIN watch_states w ON w.playlist_id = $a.playlist_id '
        'AND w.item_type = ${itemType(kind).index} '
        'AND w.provider_id = $a.provider_id';
  }

  /// `FROM <table> <alias>` with both joins.
  static String from(SectionKind kind) =>
      'FROM ${table(kind)} ${alias(kind)} ${favoriteJoin(kind)} '
      '${watchJoin(kind)}';

  /// Excludes items whose category is hidden (and locked, when
  /// [includeLocked]).
  static String notInHiddenCategory(
    SectionKind kind, {
    bool includeLocked = false,
  }) {
    final a = alias(kind);
    return 'NOT EXISTS (SELECT 1 FROM categories hc '
        'WHERE hc.playlist_id = $a.playlist_id AND hc.kind = ${kind.index} '
        'AND hc.provider_id = $a.category_id '
        'AND (hc.hidden = 1${includeLocked ? ' OR hc.locked = 1' : ''}))';
  }

  /// Tables a [VodItem] query reads (for `watch()`).
  static Set<ResultSetImplementation<dynamic, dynamic>> readsFrom(
    AppDatabase db,
    SectionKind kind,
  ) => {
    kind == SectionKind.series ? db.series : db.movies,
    db.favorites,
    db.watchStates,
    db.categories,
  };

  /// `?, ?, ?` for [n] variables.
  static String placeholders(int n) => List.filled(n, '?').join(', ');
}

/// Reads a row selected with [VodSql.movieColumns] / [VodSql.seriesColumns].
VodItem readVodItem(QueryRow row, SectionKind kind, DateTime now) {
  final added = row.readNullable<DateTime>('added_at');
  final positionMs = row.readNullable<int>('position_ms') ?? 0;
  final durationMs = row.readNullable<int>('duration_ms') ?? 0;
  return VodItem(
    kind: kind,
    rowId: row.read<int>('row_id'),
    providerId: row.read<String>('provider_id'),
    name: row.read<String>('name'),
    categoryId: row.readNullable<String>('category_id'),
    poster: _nonBlank(row.readNullable<String>('poster')),
    backdrop: _nonBlank(_readText(row, 'backdrop')),
    rating: row.readNullable<double>('rating'),
    year: row.readNullable<int>('year'),
    added: added,
    tmdbId: row.readNullable<int>('tmdb_id'),
    plot: _nonBlank(_readText(row, 'plot')),
    genre: _nonBlank(_readText(row, 'genre')),
    sortIndex: row.read<int>('sort_index'),
    hidden: row.read<bool>('hidden'),
    isNew: isRecent(added, now),
    isFavorite: row.readNullable<int>('fav_id') != null,
    watched: row.readNullable<bool>('watched') ?? false,
    position: Duration(milliseconds: positionMs),
    duration: Duration(milliseconds: durationMs),
  );
}

/// JSON-extracted values may come back as numbers; read them as text.
String? _readText(QueryRow row, String column) {
  final v = row.data[column];
  if (v == null) return null;
  return v is String ? v : '$v';
}
