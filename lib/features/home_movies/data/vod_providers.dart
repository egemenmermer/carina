/// Riverpod providers of the Movies & Shows feature (on top of the shared
/// VOD repositories; no new SQL).
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/database.dart';
import '../../../data/repositories/vod_repository.dart';
import '../../../data/tmdb/tmdb_service.dart';
import '../../../player/player_api.dart';
import 'vod_meta.dart';

export 'vod_meta.dart';

/// Stable key of a movie or show card.
typedef VodKey = ({int playlistId, SectionKind kind, String providerId});

/// Key of a Movies / Shows section.
typedef VodScope = ({int playlistId, SectionKind kind});

/// One library item (hidden ones included) that follows favorites and
/// watch state.
final vodItemProvider = StreamProvider.autoDispose.family<VodItem?, VodKey>(
  (ref, k) => ref
      .watch(vodRepositoryProvider)
      .watchItem(k.playlistId, k.kind, k.providerId),
);

/// Hero / detail-sheet metadata of an item ([buildVodMeta]). Fetches the
/// provider details lazily (cached 7 days by the repository) and the TMDb
/// enrichment (null without a key). Null while the card loads or when the
/// item no longer exists.
final vodMetaProvider = Provider.autoDispose.family<VodMeta?, VodKey>((ref, k) {
  final item = ref.watch(vodItemProvider(k)).value;
  if (item == null) return null;
  final ids = (playlistId: k.playlistId, providerId: k.providerId);
  MovieDetails? movie;
  SeriesDetails? series;
  if (k.kind == SectionKind.series) {
    series = ref.watch(seriesDetailsProvider(ids)).value;
  } else {
    movie = ref.watch(movieDetailsProvider(ids)).value;
  }
  final lookup = (
    tmdbId: item.tmdbId ?? movie?.tmdbId ?? series?.tmdbId,
    title: vodDisplayTitle(item.name),
    year: item.year ?? vodTitleYear(item.name),
  );
  final TmdbEnrichment? tmdb = k.kind == SectionKind.series
      ? ref.watch(seriesEnrichmentProvider(lookup)).value
      : ref.watch(movieEnrichmentProvider(lookup)).value;
  return buildVodMeta(item: item, movie: movie, series: series, tmdb: tmdb);
});

/// Opens the player. A provider so tests can record the requests instead
/// of opening the real player.
class VodPlayerLauncher {
  const VodPlayerLauncher();

  Future<void> open(BuildContext context, VodPlayRequest request) =>
      openPlayer(context, request);
}

final vodPlayerLauncherProvider = Provider<VodPlayerLauncher>(
  (ref) => const VodPlayerLauncher(),
);

/// Shows the user has played (the "Last watched" selection), used to label
/// recently modified shows NEW EPISODES instead of NEW SHOW.
final vodSeriesWithHistoryProvider = Provider.autoDispose
    .family<Set<String>, int>((ref, playlistId) {
      final items = ref
          .watch(
            vodCategoryItemsProvider((
              playlistId: playlistId,
              kind: SectionKind.series,
              category: const LastWatchedCategory(),
              sort: VodSort.playlist,
              filter: null,
            )),
          )
          .value;
      return {for (final i in items ?? const <VodItem>[]) i.providerId};
    });

/// The grid sort chosen per section, kept for the session.
final vodGridSortProvider =
    NotifierProvider.family<VodGridSort, VodSort, VodScope>(VodGridSort.new);

class VodGridSort extends Notifier<VodSort> {
  VodGridSort(this.scope);

  final VodScope scope;

  @override
  VodSort build() => VodSort.playlist;

  void set(VodSort sort) => state = sort;
}

/// Sections (`<playlistId>:<kind>`) whose saved sidebar selection was
/// already reset to Home in this session: Movies / Shows open on the Home
/// rows after a restart (see `VodHomeView`).
final vodHomeResetProvider = Provider<Set<String>>((ref) => <String>{});
