/// Actions on movies, shows and episodes shared by the Movies / Shows homes,
/// the grids and the detail sheets: play / resume, favorites, watched flags,
/// hide, and the card context menu.
///
/// Every state change shows a green toast. The helpers read providers
/// through the [ProviderScope] above [BuildContext], so they also work from
/// plain functions such as `showVodActions`.
library;

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../../data/db/database.dart';
import '../../../data/repositories/favorites_repository.dart';
import '../../../data/repositories/vod_repository.dart';
import '../../../data/repositories/watch_state_repository.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../player/player_api.dart';
import '../../details/details_api.dart';
import '../../favorites/favorites_api.dart';
import '../data/vod_providers.dart';

ProviderContainer _container(BuildContext context) =>
    ProviderScope.containerOf(context, listen: false);

ItemType vodItemType(SectionKind kind) =>
    kind == SectionKind.series ? ItemType.series : ItemType.movie;

SectionKind vodSectionOf(ItemType type) =>
    type == ItemType.series ? SectionKind.series : SectionKind.movie;

/// Opens the movie or series detail sheet.
Future<void> openVodDetails(
  BuildContext context, {
  required int playlistId,
  required SectionKind kind,
  required String providerId,
}) => kind == SectionKind.series
    ? showSeriesDetails(context, playlistId: playlistId, seriesId: providerId)
    : showMovieDetails(context, playlistId: playlistId, movieId: providerId);

/// Plays a movie. [resume]: null lets the player offer "Resume from …"
/// between 2% and 95%; true resumes silently; false starts over.
Future<void> playMovie(
  BuildContext context, {
  required int playlistId,
  required String movieId,
  bool? resume,
}) => _container(context)
    .read(vodPlayerLauncherProvider)
    .open(
      context,
      VodPlayRequest(
        playlistId: playlistId,
        type: ItemType.movie,
        providerId: movieId,
        resume: resume,
      ),
    );

/// Plays an episode (see [playMovie] for [resume]).
Future<void> playEpisode(
  BuildContext context, {
  required int playlistId,
  required String seriesId,
  required String episodeId,
  bool? resume,
}) => _container(context)
    .read(vodPlayerLauncherProvider)
    .open(
      context,
      VodPlayRequest(
        playlistId: playlistId,
        type: ItemType.episode,
        providerId: episodeId,
        seriesId: seriesId,
        resume: resume,
      ),
    );

/// Plays a show: its Continue watching episode (resumed, or the next
/// episode from the start), else the first episode. Fetches the episodes
/// when none are stored yet.
Future<void> playSeries(
  BuildContext context, {
  required int playlistId,
  required String seriesId,
}) async {
  final c = _container(context);
  final l10n = L10n.of(context);
  final entries = await c
      .read(watchStateRepositoryProvider)
      .continueWatchingShows(playlistId);
  final entry = entries.firstWhereOrNull(
    (e) => e.item.providerId == seriesId && e.episode != null,
  );
  if (!context.mounted) return;
  if (entry != null) {
    return playContinueEntry(context, playlistId: playlistId, entry: entry);
  }
  final details = await c
      .read(vodRepositoryProvider)
      .seriesDetails(playlistId, seriesId);
  if (!context.mounted) return;
  final first = details?.firstEpisode;
  if (first == null) {
    c
        .read(toastControllerProvider)
        .show(
          l10n.vodToastNoEpisodes,
          kind: KToastKind.info,
          icon: PhosphorIconsLight.info,
        );
    return;
  }
  return playEpisode(
    context,
    playlistId: playlistId,
    seriesId: seriesId,
    episodeId: first.providerId,
    resume: false,
  );
}

/// Plays [item] (movie or show).
Future<void> playVodItem(
  BuildContext context, {
  required int playlistId,
  required SectionKind kind,
  required String providerId,
}) => kind == SectionKind.series
    ? playSeries(context, playlistId: playlistId, seriesId: providerId)
    : playMovie(context, playlistId: playlistId, movieId: providerId);

/// Resumes a Continue watching entry directly: the movie or the in-progress
/// episode at its position, or the next episode from the start.
Future<void> playContinueEntry(
  BuildContext context, {
  required int playlistId,
  required ContinueWatchingEntry entry,
}) {
  final episode = entry.episode;
  if (episode == null) {
    return playMovie(
      context,
      playlistId: playlistId,
      movieId: entry.item.providerId,
      resume: true,
    );
  }
  return playEpisode(
    context,
    playlistId: playlistId,
    seriesId: entry.item.providerId,
    episodeId: episode.providerId,
    resume: !entry.isNextEpisode && entry.position > Duration.zero,
  );
}

/// Adds or removes a favorite and shows the toast. Returns the new state.
Future<bool> toggleVodFavorite(
  BuildContext context, {
  required int playlistId,
  required ItemType type,
  required String providerId,
}) async {
  final c = _container(context);
  final l10n = L10n.of(context);
  final added = await c
      .read(favoritesRepositoryProvider)
      .toggle(playlistId, type, providerId);
  c
      .read(toastControllerProvider)
      .show(
        added
            ? l10n.vodToastAddedToFavorites
            : l10n.vodToastRemovedFromFavorites,
      );
  return added;
}

/// Marks a movie, show (all stored episodes follow) or episode watched or
/// unwatched, with the toast.
Future<void> setVodWatched(
  BuildContext context, {
  required int playlistId,
  required ItemType type,
  required String providerId,
  required bool watched,
  String? seriesId,
}) async {
  final c = _container(context);
  final l10n = L10n.of(context);
  await c
      .read(watchStateRepositoryProvider)
      .setWatched(playlistId, type, providerId, watched, seriesId: seriesId);
  c
      .read(toastControllerProvider)
      .show(
        watched ? l10n.vodToastMarkedWatched : l10n.vodToastMarkedUnwatched,
      );
}

/// "Mark all previous as watched" for [episode], with the toast.
Future<int> markPreviousEpisodesWatched(
  BuildContext context, {
  required int playlistId,
  required EpisodeItem episode,
}) async {
  final c = _container(context);
  final l10n = L10n.of(context);
  final n = await c
      .read(watchStateRepositoryProvider)
      .markPreviousWatched(
        playlistId,
        episode.seriesId,
        episode.season,
        episode.episode,
      );
  c
      .read(toastControllerProvider)
      .show(
        l10n.vodToastMarkedPrevious(n),
        kind: n == 0 ? KToastKind.info : KToastKind.success,
      );
  return n;
}

/// Hides a movie or show (Settings → Hidden items restores it).
Future<void> hideVodItem(
  BuildContext context, {
  required int playlistId,
  required SectionKind kind,
  required String providerId,
}) async {
  final c = _container(context);
  final l10n = L10n.of(context);
  await c
      .read(vodRepositoryProvider)
      .setHidden(playlistId, kind, providerId, true);
  c.read(toastControllerProvider).show(l10n.vodToastHidden);
}

/// Removes a movie from Continue watching (forgets its position).
Future<void> removeMovieFromContinueWatching(
  BuildContext context, {
  required int playlistId,
  required String movieId,
}) async {
  final c = _container(context);
  final l10n = L10n.of(context);
  await c
      .read(watchStateRepositoryProvider)
      .clear(playlistId, ItemType.movie, movieId);
  c.read(toastControllerProvider).show(l10n.vodToastRemovedFromContinue);
}

enum _CardAction {
  play,
  favorite,
  favoriteTags,
  watched,
  removeFromContinue,
  hide,
  info,
}

/// The movie / show card context menu: Play · Add to favorites
/// / Remove · Add to favorite with tags · Mark as watched / unwatched ·
/// (Remove from Continue watching) · Hide · Info.
Future<void> showVodCardMenu(
  BuildContext context, {
  required int playlistId,
  required ItemType type,
  required String providerId,
  required Offset position,
  bool inContinueWatching = false,
}) async {
  final kind = vodSectionOf(type);
  final c = _container(context);
  final item = await c
      .read(vodRepositoryProvider)
      .item(playlistId, kind, providerId);
  if (item == null || !context.mounted) return;
  final l10n = L10n.of(context);
  final title = vodDisplayTitle(item.name);
  final action = await showKContextMenu<_CardAction>(
    context,
    position: position,
    title: title.isEmpty ? l10n.vodUntitled : title,
    entries: [
      KMenuEntry(
        label: l10n.vodPlay,
        icon: PhosphorIconsLight.play,
        value: _CardAction.play,
      ),
      const KMenuEntry.separator(),
      KMenuEntry(
        label: item.isFavorite
            ? l10n.vodRemoveFromFavorites
            : l10n.vodAddToFavorites,
        icon: item.isFavorite
            ? PhosphorIconsFill.star
            : PhosphorIconsLight.star,
        value: _CardAction.favorite,
      ),
      KMenuEntry(
        label: l10n.vodAddToFavoriteWithTags,
        icon: PhosphorIconsLight.tag,
        value: _CardAction.favoriteTags,
      ),
      const KMenuEntry.separator(),
      KMenuEntry(
        label: item.watched ? l10n.vodMarkUnwatched : l10n.vodMarkWatched,
        icon: item.watched
            ? PhosphorIconsLight.eyeClosed
            : PhosphorIconsLight.eye,
        value: _CardAction.watched,
      ),
      if (inContinueWatching && kind == SectionKind.movie)
        KMenuEntry(
          label: l10n.vodRemoveFromContinue,
          icon: PhosphorIconsLight.xCircle,
          value: _CardAction.removeFromContinue,
        ),
      KMenuEntry(
        label: l10n.vodHide,
        icon: PhosphorIconsLight.eyeSlash,
        value: _CardAction.hide,
      ),
      const KMenuEntry.separator(),
      KMenuEntry(
        label: l10n.vodInfo,
        icon: PhosphorIconsLight.info,
        value: _CardAction.info,
      ),
    ],
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case _CardAction.play:
      await playVodItem(
        context,
        playlistId: playlistId,
        kind: kind,
        providerId: providerId,
      );
    case _CardAction.favorite:
      await toggleVodFavorite(
        context,
        playlistId: playlistId,
        type: type,
        providerId: providerId,
      );
    case _CardAction.favoriteTags:
      await showFavoriteTagsSheet(
        context,
        playlistId: playlistId,
        type: type,
        providerId: providerId,
        title: title,
      );
    case _CardAction.watched:
      await setVodWatched(
        context,
        playlistId: playlistId,
        type: type,
        providerId: providerId,
        watched: !item.watched,
      );
    case _CardAction.removeFromContinue:
      await removeMovieFromContinueWatching(
        context,
        playlistId: playlistId,
        movieId: providerId,
      );
    case _CardAction.hide:
      await hideVodItem(
        context,
        playlistId: playlistId,
        kind: kind,
        providerId: providerId,
      );
    case _CardAction.info:
      await openVodDetails(
        context,
        playlistId: playlistId,
        kind: kind,
        providerId: providerId,
      );
  }
}
