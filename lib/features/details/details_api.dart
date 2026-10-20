import 'package:flutter/widgets.dart';

import '../../core/core.dart';
import '../../data/db/tables.dart';
import '../home_movies/widgets/vod_actions.dart';
import 'details_parts.dart';
import 'movie_details_sheet.dart';
import 'series_details_sheet.dart';

/// Cross-feature entry points owned by Movies & Shows details
/// (`lib/features/details/`).

/// Opens the movie detail sheet over a dimmed, blurred
/// backdrop; resolves when it closes.
Future<void> showMovieDetails(
  BuildContext context, {
  required int playlistId,
  required String movieId,
}) => showKSheet<void>(
  context,
  width: kDetailsSheetWidth,
  child: MovieDetailsSheet(playlistId: playlistId, movieId: movieId),
);

/// Opens the series detail sheet. [season] picks the season
/// tab to show first (default: the Continue watching season, else the
/// first season).
Future<void> showSeriesDetails(
  BuildContext context, {
  required int playlistId,
  required String seriesId,
  int? season,
}) => showKSheet<void>(
  context,
  width: kDetailsSheetWidth,
  scrollable: false,
  expand: true,
  child: SeriesDetailsSheet(
    playlistId: playlistId,
    seriesId: seriesId,
    initialSeason: season,
  ),
);

/// Movie/show card context menu (Play · Favorites · Mark watched · Hide ·
/// Info). [inContinueWatching] adds "Remove from Continue watching" for
/// movies.
Future<void> showVodActions(
  BuildContext context, {
  required int playlistId,
  required ItemType type,
  required String providerId,
  required Offset position,
  bool inContinueWatching = false,
}) => showVodCardMenu(
  context,
  playlistId: playlistId,
  type: type,
  providerId: providerId,
  position: position,
  inContinueWatching: inContinueWatching,
);
