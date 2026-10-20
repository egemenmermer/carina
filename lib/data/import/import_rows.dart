/// Source-independent rows produced by the Xtream and M3U importers and
/// written by `ContentWriter`. Plain data, so M3U rows can be built on a
/// background isolate and moved back without copying.
library;

import 'dart:math' as math;

import '../db/tables.dart' show SectionKind;
import '../text/quality.dart';

/// A category (`categories` row).
final class CategoryData {
  const CategoryData({
    required this.kind,
    required this.providerId,
    required this.name,
    required this.sortIndex,
    this.parentId,
  });

  final SectionKind kind;

  /// Xtream `category_id`; M3U: the group title.
  final String providerId;
  final String name;
  final String? parentId;

  /// Provider order.
  final int sortIndex;
}

/// A live channel (`channels` row).
final class ChannelData {
  const ChannelData({
    required this.providerId,
    required this.name,
    required this.displayName,
    required this.sortIndex,
    this.num,
    this.quality,
    this.logo,
    this.categoryId,
    this.epgId,
    this.archiveDays = 0,
    this.catchupType,
    this.catchupSource,
    this.streamUrl,
    this.directSource,
    this.headersJson,
    this.unsupported = false,
    this.added,
  });

  final String providerId;
  final int? num;

  /// Raw provider name.
  final String name;

  /// [name] without quality tokens (see [channelDisplayName]).
  final String displayName;

  /// Comma-joined quality badges (`FHD`, `HD,H265`), or null.
  final String? quality;
  final String? logo;
  final String? categoryId;
  final String? epgId;
  final int archiveDays;
  final String? catchupType;
  final String? catchupSource;
  final String? streamUrl;
  final String? directSource;
  final String? headersJson;
  final bool unsupported;
  final DateTime? added;
  final int sortIndex;
}

/// A movie (`movies` row).
final class MovieData {
  const MovieData({
    required this.providerId,
    required this.name,
    required this.sortIndex,
    this.categoryId,
    this.poster,
    this.rating,
    this.added,
    this.containerExt,
    this.tmdbId,
    this.year,
    this.streamUrl,
    this.directSource,
    this.headersJson,
  });

  final String providerId;
  final String name;
  final String? categoryId;
  final String? poster;

  /// 0–10.
  final double? rating;
  final DateTime? added;
  final String? containerExt;
  final int? tmdbId;
  final int? year;
  final String? streamUrl;
  final String? directSource;
  final String? headersJson;
  final int sortIndex;
}

/// A series (`series` row).
final class SeriesData {
  const SeriesData({
    required this.providerId,
    required this.name,
    required this.sortIndex,
    this.categoryId,
    this.cover,
    this.plot,
    this.cast,
    this.director,
    this.genre,
    this.releaseDate,
    this.lastModified,
    this.rating,
    this.backdropsJson,
    this.youtubeTrailer,
    this.tmdbId,
    this.year,
  });

  final String providerId;
  final String name;
  final String? categoryId;
  final String? cover;
  final String? plot;
  final String? cast;
  final String? director;
  final String? genre;
  final String? releaseDate;
  final DateTime? lastModified;
  final double? rating;
  final String? backdropsJson;
  final String? youtubeTrailer;
  final int? tmdbId;
  final int? year;
  final int sortIndex;
}

/// A season (`seasons` row; M3U imports only, Xtream seasons are lazy).
final class SeasonData {
  const SeasonData({
    required this.seriesId,
    required this.seasonNumber,
    this.name,
    this.cover,
    this.airDate,
    this.episodeCount,
    this.overview,
  });

  final String seriesId;
  final int seasonNumber;
  final String? name;
  final String? cover;
  final String? airDate;
  final int? episodeCount;
  final String? overview;
}

/// An episode (`episodes` row; M3U imports only).
final class EpisodeData {
  const EpisodeData({
    required this.providerId,
    required this.seriesId,
    required this.season,
    required this.episodeNum,
    required this.title,
    this.containerExt,
    this.plot,
    this.durationSecs,
    this.releaseDate,
    this.image,
    this.rating,
    this.streamUrl,
    this.directSource,
    this.added,
  });

  final String providerId;
  final String seriesId;
  final int season;
  final int episodeNum;
  final String title;
  final String? containerExt;
  final String? plot;
  final int? durationSecs;
  final String? releaseDate;
  final String? image;
  final double? rating;
  final String? streamUrl;
  final String? directSource;
  final DateTime? added;
}

/// Display name and comma-joined quality badges of a raw channel name.
///
/// The display name is never empty: a name made only of whitespace falls
/// back to [fallback] (the provider id).
({String displayName, String? quality}) channelDisplayName(
  String rawName, {
  required String fallback,
}) {
  final parsed = parseQuality(rawName);
  var display = parsed.displayName.trim();
  if (display.isEmpty) display = rawName.trim();
  if (display.isEmpty) display = fallback;
  return (
    displayName: display,
    quality: parsed.badges.isEmpty ? null : parsed.badges.join(','),
  );
}

/// Item names that are only whitespace fall back to [fallback].
String nonBlankName(String raw, {required String fallback}) {
  final t = raw.trim();
  return t.isEmpty ? fallback : t;
}

/// Maps [items] slice by slice ([chunk] items each), yielding to the event
/// loop between slices so a big catalog never blocks the calling isolate
/// for long. [map] gets the slice and the number of results so far.
Future<List<R>> mapInSlices<T, R>(
  List<T> items,
  List<R> Function(List<T> slice, int done) map, {
  int chunk = 1000,
}) async {
  final out = <R>[];
  for (var i = 0; i < items.length; i += chunk) {
    if (i > 0) await Future<void>.delayed(Duration.zero);
    out.addAll(
      map(items.sublist(i, math.min(i + chunk, items.length)), out.length),
    );
  }
  return out;
}
