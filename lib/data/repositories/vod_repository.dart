import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_paths.dart';
import '../db/database.dart';
import '../net/dio_factory.dart';
import '../secrets/secret_store.dart';
import '../settings/settings_store.dart';
import '../sources/source_exception.dart';
import '../sources/xtream/xtream.dart';
import '../text/normalize.dart';
import 'parental_service.dart' show parentalSessionProvider;
import 'repository_models.dart'
    show
        AllCategory,
        CategoryRef,
        FavoritesCategory,
        LastWatchedCategory,
        ProviderCategory,
        RecentlyAddedCategory,
        isTurkishCollation,
        lastWatchedLimit,
        recentlyAddedWindow;
import 'vod_models.dart';

export 'repository_models.dart'
    show
        AllCategory,
        CategoryRef,
        FavoritesCategory,
        LastWatchedCategory,
        ProviderCategory,
        RecentlyAddedCategory;
export 'vod_models.dart';

/// Movies and series for the UI.
///
/// Lists come from the imported tables; `get_vod_info` / `get_series_info`
/// are fetched lazily when a detail sheet opens and cached in `infoJson`
/// (7 days). Hidden items are never listed (see [hiddenItems]); items of
/// hidden categories are left out of aggregated lists (all items, recently
/// added, hero) but still appear when their category is opened explicitly.
/// Rows marked `removed` by a running import stay visible: they are the
/// cached data until the import deletes them.
class VodRepository {
  VodRepository({
    required this._db,
    required this._settings,
    required this._secrets,
    Dio Function(PlaylistRow playlist)? dioFactory,
    DateTime Function()? clock,
  }) : _dioFactory = dioFactory ?? _defaultDio,
       _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final SettingsStore _settings;
  final SecretStore _secrets;
  final Dio Function(PlaylistRow playlist) _dioFactory;
  final DateTime Function() _clock;

  late final NameKeys _keys = NameKeys(
    turkish: () => isTurkishCollation(_settings),
  );
  final Map<int, _ClientEntry> _clients = {};
  final Map<String, Future<Object?>> _inFlight = {};

  static Dio _defaultDio(PlaylistRow playlist) => createDio(
    userAgent: playlist.userAgent,
    receiveTimeout: const Duration(seconds: 30),
  );

  DateTime _now() => _clock();

  /// Closes the cached Xtream clients.
  void dispose() {
    for (final entry in _clients.values) {
      entry.dio.close(force: true);
    }
    _clients.clear();
  }

  // -------------------------------------------------------------------------
  // Lists
  // -------------------------------------------------------------------------

  /// Items of a sidebar selection for the Movies / Shows grids, so screens can
  /// pass the sidebar selection straight through:
  ///
  /// * [ProviderCategory]: that category's items, listed even when the
  ///   category itself is hidden or locked (the UI opened it on purpose);
  /// * [AllCategory]: every visible item;
  /// * [RecentlyAddedCategory]: added (series: modified) within
  ///   `recentlyAddedWindow` (7 days);
  /// * [FavoritesCategory]: the favorites, or those with its tag;
  /// * [LastWatchedCategory]: the last `lastWatchedLimit` (50) played
  ///   movies, or series with played episodes.
  ///
  /// Hidden items are never listed. The aggregated selections (all but
  /// [ProviderCategory]) leave out items of hidden categories and, with
  /// [excludeLocked] (parental mode `hide`), of locked ones: the visibility
  /// the sidebar counts use.
  ///
  /// [VodSort.playlist] keeps the selection's own order: provider order;
  /// newest first for Recently added; [favoritesOrder] (default: the
  /// favorites order setting) for Favorites; most recent first for Last
  /// watched. [filter] keeps items whose normalized name contains every
  /// normalized term (`sicak` finds `Sıcak Kafa`).
  Stream<List<VodItem>> watchCategoryItems(
    int playlistId,
    SectionKind kind,
    CategoryRef category, {
    VodSort sort = VodSort.playlist,
    String? filter,
    int? limit,
    bool excludeLocked = false,
    FavoritesOrder? favoritesOrder,
  }) {
    _checkVodKind(kind);
    return _watchSource(
      _sourceFor(
        playlistId,
        kind,
        category,
        excludeLocked: excludeLocked,
        favoritesOrder: favoritesOrder,
      ),
      kind,
      sort: sort,
      filter: filter,
      limit: limit,
    );
  }

  /// Movies of one provider category ([categoryId]), or of every visible
  /// category; see [watchCategoryItems].
  Stream<List<VodItem>> watchMovies(
    int playlistId, {
    String? categoryId,
    VodSort sort = VodSort.playlist,
    String? filter,
    int? limit,
    bool excludeLocked = false,
  }) => watchCategoryItems(
    playlistId,
    SectionKind.movie,
    categoryId == null ? const AllCategory() : ProviderCategory(categoryId),
    sort: sort,
    filter: filter,
    limit: limit,
    excludeLocked: excludeLocked,
  );

  /// Series; same rules as [watchMovies] ("date added" is `lastModified`).
  Stream<List<VodItem>> watchSeries(
    int playlistId, {
    String? categoryId,
    VodSort sort = VodSort.playlist,
    String? filter,
    int? limit,
    bool excludeLocked = false,
  }) => watchCategoryItems(
    playlistId,
    SectionKind.series,
    categoryId == null ? const AllCategory() : ProviderCategory(categoryId),
    sort: sort,
    filter: filter,
    limit: limit,
    excludeLocked: excludeLocked,
  );

  /// The "Recently added" row: movies added within [days] days, newest
  /// first.
  Stream<List<VodItem>> watchRecentlyAddedMovies(
    int playlistId, {
    int days = 7,
    int limit = 40,
    bool excludeLocked = false,
  }) => _watchSource(
    _recentSource(
      playlistId,
      SectionKind.movie,
      Duration(days: days),
      excludeLocked,
    ),
    SectionKind.movie,
    sort: VodSort.playlist,
    limit: limit,
  );

  /// Series modified (new episodes) within [days] days, newest first.
  Stream<List<VodItem>> watchRecentlyAddedSeries(
    int playlistId, {
    int days = 7,
    int limit = 40,
    bool excludeLocked = false,
  }) => _watchSource(
    _recentSource(
      playlistId,
      SectionKind.series,
      Duration(days: days),
      excludeLocked,
    ),
    SectionKind.series,
    sort: VodSort.playlist,
    limit: limit,
  );

  /// One row per visible provider category of [kind] (movie or series), in
  /// the order of `PlaylistSettings.categoriesOrder` (playlist / name /
  /// custom), each with its first [perRow] items in provider order.
  /// Categories without visible items are skipped.
  Future<List<VodHomeRow>> homeRows(
    int playlistId,
    SectionKind kind, {
    int perRow = 30,
    bool excludeLocked = false,
  }) async {
    _checkVodKind(kind);
    final categories = await _orderedCategories(
      playlistId,
      kind,
      excludeLocked: excludeLocked,
    );
    if (categories.isEmpty) return const [];
    final a = VodSql.alias(kind);
    final t = VodSql.table(kind);
    final rows = await _db
        .customSelect(
          '''
SELECT ${VodSql.columns(kind)}, x.cat_count AS cat_count
FROM (
  SELECT id AS item_id,
    ROW_NUMBER() OVER (PARTITION BY category_id ORDER BY sort_index, id) AS rn,
    COUNT(*) OVER (PARTITION BY category_id) AS cat_count
  FROM $t
  WHERE playlist_id = ? AND hidden = 0 AND category_id IS NOT NULL
) x
JOIN $t $a ON $a.id = x.item_id
${VodSql.favoriteJoin(kind)}
${VodSql.watchJoin(kind)}
WHERE x.rn <= ?
ORDER BY $a.category_id, x.rn''',
          variables: [
            Variable.withInt(playlistId),
            Variable.withInt(math.max(1, perRow)),
          ],
          readsFrom: VodSql.readsFrom(_db, kind),
        )
        .get();
    final now = _now();
    final items = <String, List<VodItem>>{};
    final counts = <String, int>{};
    for (final row in rows) {
      final item = readVodItem(row, kind, now);
      final cid = item.categoryId!;
      (items[cid] ??= []).add(item);
      counts[cid] = row.read<int>('cat_count');
    }
    return List.unmodifiable([
      for (final c in categories)
        if (items[c.providerId] case final list?)
          VodHomeRow(
            category: c,
            items: List.unmodifiable(list),
            totalCount: counts[c.providerId] ?? list.length,
          ),
    ]);
  }

  /// [homeRows] that re-runs when items, categories, favorites or watch
  /// state change. (The category order setting is read on each run; the
  /// provider rebuilds when settings change.)
  Stream<List<VodHomeRow>> watchHomeRows(
    int playlistId,
    SectionKind kind, {
    int perRow = 30,
    bool excludeLocked = false,
  }) => asyncMapLatest(
    _changes(VodSql.readsFrom(_db, kind)),
    (_) => homeRows(
      playlistId,
      kind,
      perRow: perRow,
      excludeLocked: excludeLocked,
    ),
  );

  /// Items for the rotating hero: recently added and continue-watching
  /// items (interleaved, most recent first) that have a backdrop or poster.
  /// Filled up in playlist order when too few have an added date (M3U).
  /// Same visibility as the aggregated lists of [watchCategoryItems].
  Future<List<VodItem>> heroCandidates(
    int playlistId,
    SectionKind kind, {
    int limit = 8,
    bool excludeLocked = false,
  }) async {
    _checkVodKind(kind);
    if (limit <= 0) return const [];
    final a = VodSql.alias(kind);
    final added = kind == SectionKind.series ? '$a.last_modified' : '$a.added';
    final base =
        '$a.playlist_id = ? AND $a.hidden = 0 AND '
        '${VodSql.notInHiddenCategory(kind, includeLocked: excludeLocked)}';
    final recent = await _select(
      kind,
      where: '$base AND $added IS NOT NULL',
      orderBy: '$added DESC, $a.sort_index',
      variables: [Variable.withInt(playlistId)],
      limit: limit * 3,
    );
    final playing = await _inProgressForHero(
      playlistId,
      kind,
      limit * 2,
      excludeLocked,
    );
    final merged = <VodItem>[];
    final seen = <String>{};
    void add(VodItem item) {
      if (item.art != null && seen.add(item.providerId)) merged.add(item);
    }

    for (var i = 0; i < math.max(recent.length, playing.length); i++) {
      if (i < recent.length) add(recent[i]);
      if (i < playing.length) add(playing[i]);
    }
    if (merged.length < limit) {
      final fill = await _select(
        kind,
        where: base,
        orderBy: '$a.sort_index, $a.id',
        variables: [Variable.withInt(playlistId)],
        limit: limit * 3,
      );
      fill.forEach(add);
    }
    return List.unmodifiable(merged.take(limit));
  }

  /// The Favorites row: favorite movies or series (optionally one tag) in
  /// [order] (default: the favorites order setting). Same as
  /// [watchCategoryItems] with [FavoritesCategory]; favorites whose item is
  /// not in the library right now are left out.
  Stream<List<VodItem>> watchFavoriteItems(
    int playlistId,
    SectionKind kind, {
    int? tagId,
    FavoritesOrder? order,
    bool excludeLocked = false,
  }) => watchCategoryItems(
    playlistId,
    kind,
    FavoritesCategory(tagId: tagId),
    favoritesOrder: order,
    excludeLocked: excludeLocked,
  );

  /// One card by provider id (hidden items included), or null.
  Future<VodItem?> item(
    int playlistId,
    SectionKind kind,
    String providerId,
  ) async {
    _checkVodKind(kind);
    final a = VodSql.alias(kind);
    final rows = await _select(
      kind,
      where: '$a.playlist_id = ? AND $a.provider_id = ?',
      variables: [
        Variable.withInt(playlistId),
        Variable.withString(providerId),
      ],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// [item] that updates with favorites / watch state.
  Stream<VodItem?> watchItem(
    int playlistId,
    SectionKind kind,
    String providerId,
  ) {
    _checkVodKind(kind);
    final a = VodSql.alias(kind);
    return _db
        .customSelect(
          'SELECT ${VodSql.columns(kind)} ${VodSql.from(kind)} '
          'WHERE $a.playlist_id = ? AND $a.provider_id = ? LIMIT 1',
          variables: [
            Variable.withInt(playlistId),
            Variable.withString(providerId),
          ],
          readsFrom: VodSql.readsFrom(_db, kind),
        )
        .watch()
        .map(
          (rows) => rows.isEmpty ? null : readVodItem(rows.first, kind, _now()),
        );
  }

  /// Cards for library items with these provider ids, in the given order
  /// (missing and hidden ones are skipped; with [visibleOnly] also items of
  /// hidden categories, and of locked ones with [excludeLocked]).
  Future<List<VodItem>> itemsByIds(
    int playlistId,
    SectionKind kind,
    List<String> providerIds, {
    bool visibleOnly = false,
    bool excludeLocked = false,
  }) async {
    _checkVodKind(kind);
    if (providerIds.isEmpty) return const [];
    final a = VodSql.alias(kind);
    final visible = visibleOnly
        ? ' AND ${VodSql.notInHiddenCategory(kind, includeLocked: excludeLocked)}'
        : '';
    final byId = <String, VodItem>{};
    for (var i = 0; i < providerIds.length; i += 500) {
      final chunk = providerIds.sublist(
        i,
        math.min(providerIds.length, i + 500),
      );
      final rows = await _select(
        kind,
        where:
            '$a.playlist_id = ? AND $a.hidden = 0 AND $a.provider_id IN '
            '(${VodSql.placeholders(chunk.length)})$visible',
        variables: [
          Variable.withInt(playlistId),
          for (final id in chunk) Variable.withString(id),
        ],
      );
      for (final item in rows) {
        byId[item.providerId] = item;
      }
    }
    return List.unmodifiable([for (final id in providerIds) ?byId[id]]);
  }

  /// Whether [item] gets a NEW badge: added (series: last modified) within
  /// 7 days. Accepts [VodItem], [MovieRow], [SeriesRow], [EpisodeRow] and
  /// [EpisodeItem].
  bool isNew(Object item) {
    final now = _now();
    return switch (item) {
      VodItem(:final added) => isRecent(added, now),
      MovieRow(:final added) => isRecent(added, now),
      SeriesRow(:final lastModified) => isRecent(lastModified, now),
      EpisodeRow(:final added) => isRecent(added, now),
      EpisodeItem(:final added) => isRecent(added, now),
      _ => throw ArgumentError.value(item, 'item', 'Unsupported item type'),
    };
  }

  /// Matches TMDb trending entries to library items: by `tmdb_id`, else by
  /// normalized title (+ year within one). Returns cards in input order;
  /// unmatched entries are skipped. Same visibility as the aggregated lists.
  Future<List<VodItem>> matchTrending(
    int playlistId,
    SectionKind kind,
    List<({int? tmdbId, String title, String? originalTitle, int? year})>
    entries, {
    bool excludeLocked = false,
  }) async {
    _checkVodKind(kind);
    if (entries.isEmpty) return const [];
    final a = VodSql.alias(kind);
    final ids = {for (final e in entries) ?e.tmdbId};
    final byTmdb = <int, VodItem>{};
    if (ids.isNotEmpty) {
      final rows = await _select(
        kind,
        where:
            '$a.playlist_id = ? AND $a.hidden = 0 AND $a.tmdb_id IN '
            '(${VodSql.placeholders(ids.length)}) AND '
            '${VodSql.notInHiddenCategory(kind, includeLocked: excludeLocked)}',
        variables: [
          Variable.withInt(playlistId),
          for (final id in ids) Variable.withInt(id),
        ],
      );
      for (final item in rows) {
        byTmdb.putIfAbsent(item.tmdbId!, () => item);
      }
    }
    final out = <VodItem>[];
    final seen = <String>{};
    for (final e in entries) {
      var match = e.tmdbId == null ? null : byTmdb[e.tmdbId];
      match ??= await _matchByTitle(
        playlistId,
        kind,
        e.title,
        e.year,
        excludeLocked,
      );
      if (match == null && e.originalTitle != null) {
        match = await _matchByTitle(
          playlistId,
          kind,
          e.originalTitle!,
          e.year,
          excludeLocked,
        );
      }
      if (match != null && seen.add(match.providerId)) out.add(match);
    }
    return List.unmodifiable(out);
  }

  // -------------------------------------------------------------------------
  // Details
  // -------------------------------------------------------------------------

  /// Movie details. Xtream: `get_vod_info` is fetched when the cache is
  /// missing, older than 7 days, or [refresh] is set, and stored in
  /// `movies.infoJson`. When fetching fails the cached (or basic) data is
  /// returned with [MovieDetails.error] set. M3U movies return the basic
  /// row data. Null when the movie does not exist.
  Future<MovieDetails?> movieDetails(
    int playlistId,
    String providerId, {
    bool refresh = false,
  }) => _once(
    'movie:$playlistId:$providerId:$refresh',
    () => _movieDetails(playlistId, providerId, refresh),
  );

  /// Series details with seasons and episodes. Xtream: `get_series_info` is
  /// fetched when the info is missing or older than 7 days, when no episodes
  /// are stored, or with [refresh]; seasons and episodes are upserted (and
  /// episodes the provider dropped are deleted). M3U series use the stored
  /// seasons / episodes. Null when the series does not exist.
  Future<SeriesDetails?> seriesDetails(
    int playlistId,
    String providerId, {
    bool refresh = false,
  }) => _once(
    'series:$playlistId:$providerId:$refresh',
    () => _seriesDetails(playlistId, providerId, refresh),
  );

  /// "Refresh episodes" in the series sheet: re-fetches `get_series_info`.
  Future<SeriesDetails?> refreshEpisodes(int playlistId, String seriesId) =>
      seriesDetails(playlistId, seriesId, refresh: true);

  /// Stored episodes of a series: regular seasons ascending, specials last.
  Future<List<EpisodeItem>> episodes(int playlistId, String seriesId) async {
    final rows = await _episodeRows(playlistId, seriesId);
    return List.unmodifiable(_displayOrder(rows).map(EpisodeItem.fromRow));
  }

  /// One stored episode by provider id.
  Future<EpisodeItem?> episode(int playlistId, String episodeId) async {
    final row =
        await (_db.select(_db.episodes)
              ..where(
                (e) =>
                    e.playlistId.equals(playlistId) &
                    e.providerId.equals(episodeId),
              )
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : EpisodeItem.fromRow(row);
  }

  /// The episode after S[season] E[episode]: the next one in the season,
  /// else the first of the next season. Specials (season 0) only lead to
  /// the next special. Null at the end.
  Future<EpisodeItem?> nextEpisode(
    int playlistId,
    String seriesId,
    int season,
    int episode,
  ) async {
    final rows = await _episodeRows(playlistId, seriesId);
    EpisodeRow? best;
    for (final row in rows) {
      final after = season == 0
          ? row.season == 0 && row.episodeNum > episode
          : row.season > 0 &&
                (row.season > season ||
                    (row.season == season && row.episodeNum > episode));
      if (!after) continue;
      if (best == null ||
          row.season < best.season ||
          (row.season == best.season && row.episodeNum < best.episodeNum)) {
        best = row;
      }
    }
    return best == null ? null : EpisodeItem.fromRow(best);
  }

  // -------------------------------------------------------------------------
  // Hidden items
  // -------------------------------------------------------------------------

  /// Hides or unhides a movie or series ("Hide" in the card menu).
  Future<void> setHidden(
    int playlistId,
    SectionKind kind,
    String providerId,
    bool hidden,
  ) async {
    _checkVodKind(kind);
    if (kind == SectionKind.series) {
      await (_db.update(_db.series)..where(
            (s) =>
                s.playlistId.equals(playlistId) &
                s.providerId.equals(providerId),
          ))
          .write(SeriesCompanion(hidden: Value(hidden)));
    } else {
      await (_db.update(_db.movies)..where(
            (m) =>
                m.playlistId.equals(playlistId) &
                m.providerId.equals(providerId),
          ))
          .write(MoviesCompanion(hidden: Value(hidden)));
    }
  }

  /// Hidden movies and series (Settings → Hidden items), movies first, each
  /// by name.
  Future<List<VodItem>> hiddenItems(int playlistId) async => [
    ...await _hidden(playlistId, SectionKind.movie),
    ...await _hidden(playlistId, SectionKind.series),
  ];

  /// [hiddenItems] as a stream.
  Stream<List<VodItem>> watchHiddenItems(int playlistId) => asyncMapLatest(
    _changes({_db.movies, _db.series}),
    (_) => hiddenItems(playlistId),
  );

  // -------------------------------------------------------------------------
  // Internals: lists
  // -------------------------------------------------------------------------

  /// FROM / WHERE / natural order of a sidebar selection.
  _Source _sourceFor(
    int playlistId,
    SectionKind kind,
    CategoryRef category, {
    required bool excludeLocked,
    FavoritesOrder? favoritesOrder,
  }) {
    final a = VodSql.alias(kind);
    final t = VodSql.table(kind);
    final visible = VodSql.notInHiddenCategory(
      kind,
      includeLocked: excludeLocked,
    );
    final reads = VodSql.readsFrom(_db, kind);
    final pid = Variable.withInt(playlistId);
    switch (category) {
      case ProviderCategory(:final id):
        return _Source(
          from: VodSql.from(kind),
          where: '$a.playlist_id = ? AND $a.hidden = 0 AND $a.category_id = ?',
          variables: [pid, Variable.withString(id)],
          order: '$a.sort_index, $a.id',
          readsFrom: reads,
        );
      case AllCategory():
        return _Source(
          from: VodSql.from(kind),
          where: '$a.playlist_id = ? AND $a.hidden = 0 AND $visible',
          variables: [pid],
          order: '$a.sort_index, $a.id',
          readsFrom: reads,
        );
      case RecentlyAddedCategory():
        return _recentSource(
          playlistId,
          kind,
          recentlyAddedWindow,
          excludeLocked,
        );
      case FavoritesCategory(:final tagId):
        final order =
            favoritesOrder ??
            FavoritesOrder.fromSetting(
              _settings.get(
                PlaylistSettings.favoritesOrder,
                playlistId: playlistId,
              ),
            );
        final tagClause = tagId == null
            ? ''
            : ' AND EXISTS (SELECT 1 FROM favorite_tag_links l '
                  'WHERE l.favorite_id = f.id AND l.tag_id = ?)';
        return _Source(
          from:
              'FROM favorites f JOIN $t $a ON $a.playlist_id = f.playlist_id '
              'AND $a.provider_id = f.provider_id ${VodSql.watchJoin(kind)}',
          where:
              'f.playlist_id = ? AND f.item_type = ? AND $a.hidden = 0 AND '
              '$visible$tagClause',
          variables: [
            pid,
            Variable.withInt(VodSql.itemType(kind).index),
            if (tagId != null) Variable.withInt(tagId),
          ],
          order: switch (order) {
            FavoritesOrder.lastAdded ||
            FavoritesOrder.name => 'f.added_at DESC, f.id DESC',
            FavoritesOrder.leastRecent => 'f.added_at ASC, f.id ASC',
            FavoritesOrder.custom =>
              'f.custom_index IS NULL, f.custom_index, f.added_at, f.id',
          },
          orderIsName: order == FavoritesOrder.name,
          readsFrom: {...reads, _db.favoriteTagLinks},
        );
      case LastWatchedCategory():
        if (kind == SectionKind.movie) {
          return _Source(
            from:
                'FROM watch_states w JOIN movies m ON m.playlist_id = '
                'w.playlist_id AND m.provider_id = w.provider_id '
                '${VodSql.favoriteJoin(kind)}',
            where:
                'w.playlist_id = ? AND w.item_type = ${ItemType.movie.index} '
                'AND m.hidden = 0 AND $visible',
            variables: [pid],
            order: 'w.updated_at DESC, m.id DESC',
            cap: lastWatchedLimit,
            readsFrom: reads,
          );
        }
        return _Source(
          from:
              'FROM (SELECT series_id, MAX(updated_at) AS last_played '
              'FROM watch_states WHERE playlist_id = ? '
              'AND item_type = ${ItemType.episode.index} '
              'AND series_id IS NOT NULL GROUP BY series_id) cw '
              'JOIN series s ON s.playlist_id = ? '
              'AND s.provider_id = cw.series_id '
              '${VodSql.favoriteJoin(kind)} ${VodSql.watchJoin(kind)}',
          where: 's.hidden = 0 AND $visible',
          variables: [pid, pid],
          order: 'cw.last_played DESC, s.id DESC',
          cap: lastWatchedLimit,
          readsFrom: reads,
        );
    }
  }

  _Source _recentSource(
    int playlistId,
    SectionKind kind,
    Duration window,
    bool excludeLocked,
  ) {
    final a = VodSql.alias(kind);
    final added = _addedColumn(kind);
    return _Source(
      from: VodSql.from(kind),
      where:
          '$a.playlist_id = ? AND $a.hidden = 0 AND $added >= ? AND '
          '${VodSql.notInHiddenCategory(kind, includeLocked: excludeLocked)}',
      variables: [
        Variable.withInt(playlistId),
        Variable.withDateTime(_now().subtract(window)),
      ],
      order: '$added DESC, $a.sort_index, $a.id',
      readsFrom: VodSql.readsFrom(_db, kind),
    );
  }

  Stream<List<VodItem>> _watchSource(
    _Source source,
    SectionKind kind, {
    required VodSort sort,
    String? filter,
    int? limit,
  }) {
    final terms = _filterTerms(filter);
    final effective = sort == VodSort.playlist && source.orderIsName
        ? VodSort.name
        : sort;
    final capped = source.cap != null;
    // Capped selections (Last watched) keep their newest rows and are
    // re-sorted here; the others sort in SQL (names: in Dart, collated).
    final sqlSort =
        !capped && effective != VodSort.playlist && effective != VodSort.name;
    final dartSort =
        effective == VodSort.name || (capped && effective != VodSort.playlist);
    var sqlLimit = source.cap;
    if (!dartSort && terms.isEmpty && limit != null) {
      sqlLimit = sqlLimit == null ? limit : math.min(sqlLimit, limit);
    }
    return _db
        .customSelect(
          'SELECT ${VodSql.columns(kind)} ${source.from} '
          'WHERE ${source.where} '
          'ORDER BY ${sqlSort ? _orderBy(kind, effective) : source.order}'
          '${sqlLimit == null ? '' : ' LIMIT ${math.max(0, sqlLimit)}'}',
          variables: source.variables,
          readsFrom: source.readsFrom,
        )
        .watch()
        .map((rows) {
          final now = _now();
          Iterable<VodItem> items = [
            for (final r in rows) readVodItem(r, kind, now),
          ];
          if (terms.isNotEmpty) {
            items = items.where((i) {
              final key = _keys.searchKey(i.name);
              return terms.every(key.contains);
            });
          }
          var list = !dartSort
              ? items.toList()
              : effective == VodSort.name
              ? _keys.sort(items, (i) => i.name)
              : _sortBy(items, effective);
          if (limit != null && list.length > limit) {
            list = list.sublist(0, math.max(0, limit));
          }
          return List<VodItem>.unmodifiable(list);
        });
  }

  /// Stable [sort] in Dart: newest / best first, unknown values last.
  static List<VodItem> _sortBy(Iterable<VodItem> items, VodSort sort) {
    final indexed = items.indexed.toList()
      ..sort((x, y) {
        final a = x.$2;
        final b = y.$2;
        final c = switch (sort) {
          VodSort.dateAdded => _descNullsLast<DateTime>(a.added, b.added),
          VodSort.rating => _descNullsLast<num>(a.rating, b.rating),
          VodSort.year => _descNullsLast<num>(a.year, b.year),
          VodSort.playlist || VodSort.name => 0,
        };
        return c != 0 ? c : x.$1.compareTo(y.$1);
      });
    return [for (final e in indexed) e.$2];
  }

  static int _descNullsLast<T extends Comparable<T>>(T? a, T? b) {
    if (a == null || b == null) {
      if (a == null && b == null) return 0;
      return a == null ? 1 : -1;
    }
    return b.compareTo(a);
  }

  String _addedColumn(SectionKind kind) {
    final a = VodSql.alias(kind);
    return kind == SectionKind.series ? '$a.last_modified' : '$a.added';
  }

  String _orderBy(SectionKind kind, VodSort sort) {
    final a = VodSql.alias(kind);
    final added = kind == SectionKind.series ? '$a.last_modified' : '$a.added';
    return switch (sort) {
      VodSort.playlist || VodSort.name => '$a.sort_index, $a.id',
      VodSort.dateAdded => '$added IS NULL, $added DESC, $a.sort_index, $a.id',
      VodSort.rating =>
        '$a.rating IS NULL, $a.rating DESC, $a.sort_index, $a.id',
      VodSort.year => '$a.year IS NULL, $a.year DESC, $a.sort_index, $a.id',
    };
  }

  List<String> _filterTerms(String? filter) {
    if (filter == null) return const [];
    final normalized = normalizeForSearch(filter);
    if (normalized.isEmpty) return const [];
    return normalized.split(' ').where((t) => t.isNotEmpty).toList();
  }

  Future<List<VodItem>> _select(
    SectionKind kind, {
    required String where,
    String? orderBy,
    required List<Variable<Object>> variables,
    int? limit,
  }) async {
    final rows = await _db
        .customSelect(
          'SELECT ${VodSql.columns(kind)} ${VodSql.from(kind)} WHERE $where'
          '${orderBy == null ? '' : ' ORDER BY $orderBy'}'
          '${limit == null ? '' : ' LIMIT ${math.max(0, limit)}'}',
          variables: variables,
          readsFrom: VodSql.readsFrom(_db, kind),
        )
        .get();
    final now = _now();
    return [for (final r in rows) readVodItem(r, kind, now)];
  }

  Future<List<VodItem>> _inProgressForHero(
    int playlistId,
    SectionKind kind,
    int limit,
    bool excludeLocked,
  ) async {
    final visible = VodSql.notInHiddenCategory(
      kind,
      includeLocked: excludeLocked,
    );
    if (kind == SectionKind.movie) {
      final rows = await _db
          .customSelect(
            'SELECT ${VodSql.movieColumns} ${VodSql.from(kind)} '
            'WHERE m.playlist_id = ? AND m.hidden = 0 AND $visible '
            'AND w.watched = 0 '
            'AND w.duration_ms > 0 '
            'AND w.position_ms >= w.duration_ms * $kInProgressMinFraction '
            'AND w.position_ms < w.duration_ms * $kWatchedFraction '
            'ORDER BY w.updated_at DESC, m.id DESC LIMIT ?',
            variables: [Variable.withInt(playlistId), Variable.withInt(limit)],
            readsFrom: VodSql.readsFrom(_db, kind),
          )
          .get();
      final now = _now();
      return [for (final r in rows) readVodItem(r, kind, now)];
    }
    final rows = await _db
        .customSelect(
          '''
SELECT ${VodSql.seriesColumns}
FROM (
  SELECT series_id, MAX(updated_at) AS last_played FROM watch_states
  WHERE playlist_id = ? AND item_type = ${ItemType.episode.index}
    AND series_id IS NOT NULL
  GROUP BY series_id
) cw
JOIN series s ON s.playlist_id = ? AND s.provider_id = cw.series_id
${VodSql.favoriteJoin(kind)}
${VodSql.watchJoin(kind)}
WHERE s.hidden = 0 AND COALESCE(w.watched, 0) = 0 AND $visible
ORDER BY cw.last_played DESC, s.id DESC
LIMIT ?''',
          variables: [
            Variable.withInt(playlistId),
            Variable.withInt(playlistId),
            Variable.withInt(limit),
          ],
          readsFrom: VodSql.readsFrom(_db, kind),
        )
        .get();
    final now = _now();
    return [for (final r in rows) readVodItem(r, kind, now)];
  }

  Future<List<VodItem>> _hidden(int playlistId, SectionKind kind) async {
    final a = VodSql.alias(kind);
    final items = await _select(
      kind,
      where: '$a.playlist_id = ? AND $a.hidden = 1',
      variables: [Variable.withInt(playlistId)],
    );
    return _keys.sort(items, (i) => i.name);
  }

  Future<VodItem?> _matchByTitle(
    int playlistId,
    SectionKind kind,
    String title,
    int? year,
    bool excludeLocked,
  ) async {
    final normalized = normalizeForSearch(title);
    final match = ftsQuery(title);
    if (normalized.isEmpty || match.isEmpty) return null;
    final rows = await _db
        .customSelect(
          'SELECT ref_id FROM search_index WHERE search_index MATCH ? '
          'AND CAST(playlist_id AS TEXT) = ? AND kind = ? AND normalized = ? '
          'LIMIT 20',
          variables: [
            Variable.withString(match),
            Variable.withString('$playlistId'),
            Variable.withString(
              kind == SectionKind.series ? 'series' : 'movie',
            ),
            Variable.withString(normalized),
          ],
          readsFrom: {_db.searchIndex},
        )
        .get();
    if (rows.isEmpty) return null;
    final items = await itemsByIds(
      playlistId,
      kind,
      [for (final r in rows) '${r.data['ref_id']}'],
      visibleOnly: true,
      excludeLocked: excludeLocked,
    );
    if (year == null) return items.isEmpty ? null : items.first;
    for (final item in items) {
      if (item.year == null || (item.year! - year).abs() <= 1) return item;
    }
    return null;
  }

  /// Visible categories of [kind] in the configured order.
  Future<List<VodCategory>> _orderedCategories(
    int playlistId,
    SectionKind kind, {
    bool excludeLocked = false,
  }) async {
    final query = _db.select(_db.categories)
      ..where(
        (c) =>
            c.playlistId.equals(playlistId) &
            c.kind.equalsValue(kind) &
            c.hidden.equals(false),
      );
    if (excludeLocked) query.where((c) => c.locked.equals(false));
    final categories = (await query.get()).map(VodCategory.fromRow).toList();
    final order = CategoriesOrder.fromSetting(
      _settings.get(PlaylistSettings.categoriesOrder, playlistId: playlistId),
    );
    int byProvider(VodCategory a, VodCategory b) {
      final c = a.sortIndex.compareTo(b.sortIndex);
      return c != 0 ? c : a.rowId.compareTo(b.rowId);
    }

    switch (order) {
      case CategoriesOrder.playlist:
        categories.sort(byProvider);
        return categories;
      case CategoriesOrder.name:
        categories.sort(byProvider);
        return _keys.sort(categories, (c) => c.name);
      case CategoriesOrder.custom:
        categories.sort((a, b) {
          final ai = a.customIndex;
          final bi = b.customIndex;
          if (ai != null && bi != null && ai != bi) return ai.compareTo(bi);
          if (ai == null && bi != null) return 1;
          if (ai != null && bi == null) return -1;
          return byProvider(a, b);
        });
        return categories;
    }
  }

  Stream<void> _changes(
    Iterable<ResultSetImplementation<dynamic, dynamic>> tables,
  ) async* {
    yield null;
    yield* _db.tableUpdates(TableUpdateQuery.onAllTables(tables));
  }

  void _checkVodKind(SectionKind kind) {
    if (kind == SectionKind.live) {
      throw ArgumentError.value(kind, 'kind', 'Use LiveRepository for live');
    }
  }

  Future<T> _once<T>(String key, Future<T> Function() load) {
    final running = _inFlight[key];
    if (running != null) return running.then((v) => v as T);
    final future = load();
    _inFlight[key] = future;
    future.whenComplete(() => _inFlight.remove(key)).ignore();
    return future;
  }

  // -------------------------------------------------------------------------
  // Internals: details
  // -------------------------------------------------------------------------

  Future<PlaylistRow?> _playlist(int playlistId) =>
      (_db.select(_db.playlists)
            ..where((p) => p.id.equals(playlistId))
            ..limit(1))
          .getSingleOrNull();

  /// The cached Xtream client of an Xtream playlist with stored credentials.
  Future<XtreamClient?> _client(PlaylistRow playlist) async {
    if (playlist.type != PlaylistType.xtream) return null;
    final server = playlist.server?.trim();
    final username = playlist.username;
    if (server == null || server.isEmpty || username == null) return null;
    final password = await _secrets.read(
      SecretStore.playlistPassword(playlist.id),
    );
    if (password == null) return null;
    final credentials = XtreamCredentials(server, username, password);
    final cached = _clients[playlist.id];
    if (cached != null &&
        cached.credentials == credentials &&
        cached.userAgent == playlist.userAgent) {
      return cached.client;
    }
    cached?.dio.close(force: true);
    final dio = _dioFactory(playlist);
    final client = XtreamClient(dio, credentials);
    _clients[playlist.id] = _ClientEntry(
      credentials: credentials,
      userAgent: playlist.userAgent,
      dio: dio,
      client: client,
    );
    return client;
  }

  static const _noCredentials = SourceException(
    SourceErrorKind.unauthorized,
    message: 'No stored Xtream credentials',
  );

  bool _isStale(DateTime? fetchedAt) =>
      fetchedAt == null || _now().difference(fetchedAt) > kVodInfoMaxAge;

  Future<MovieDetails?> _movieDetails(
    int playlistId,
    String providerId,
    bool refresh,
  ) async {
    final row = await _movieRow(playlistId, providerId);
    if (row == null) return null;
    var info = decodeVodInfo(row.infoJson, providerId);
    var fetchedAt = info == null ? null : row.infoFetchedAt;
    SourceException? error;
    final playlist = await _playlist(playlistId);
    if (playlist?.type == PlaylistType.xtream &&
        (refresh || info == null || _isStale(fetchedAt))) {
      final client = await _client(playlist!);
      if (client == null) {
        error = _noCredentials;
      } else {
        try {
          final fresh = await client.vodInfo(providerId);
          if (!fresh.isEmpty) {
            info = fresh;
            fetchedAt = _now();
            await _storeVodInfo(row, fresh, fetchedAt);
          }
        } on SourceException catch (e) {
          error = e;
        }
      }
    }
    return _buildMovieDetails(row, info, fetchedAt, error);
  }

  Future<MovieRow?> _movieRow(int playlistId, String providerId) =>
      (_db.select(_db.movies)
            ..where(
              (m) =>
                  m.playlistId.equals(playlistId) &
                  m.providerId.equals(providerId),
            )
            ..limit(1))
          .getSingleOrNull();

  Future<void> _storeVodInfo(
    MovieRow row,
    XtreamVodInfo info,
    DateTime fetchedAt,
  ) async {
    await (_db.update(_db.movies)..where((m) => m.id.equals(row.id))).write(
      MoviesCompanion(
        infoJson: Value(jsonEncode(vodInfoToJson(info))),
        infoFetchedAt: Value(fetchedAt),
        tmdbId: row.tmdbId == null && info.tmdbId != null
            ? Value(info.tmdbId)
            : const Value.absent(),
        year: row.year == null && info.year != null
            ? Value(info.year)
            : const Value.absent(),
        containerExt:
            row.containerExt == null && info.containerExtension != null
            ? Value(info.containerExtension)
            : const Value.absent(),
      ),
    );
  }

  MovieDetails _buildMovieDetails(
    MovieRow row,
    XtreamVodInfo? info,
    DateTime? fetchedAt,
    SourceException? error,
  ) {
    final duration = info?.durationSecs;
    return MovieDetails(
      providerId: row.providerId,
      name: row.name,
      originalName: info?.originalName,
      categoryId: row.categoryId,
      poster: _nonBlank(row.poster) ?? info?.coverBig ?? info?.movieImage,
      backdrops: info?.backdrops ?? const [],
      plot: info?.overview,
      genres: splitGenres(info?.genre),
      cast: splitPeople(info?.castText),
      director: info?.director,
      duration: duration == null || duration <= 0
          ? null
          : Duration(seconds: duration),
      ageRating: info?.ageRating,
      country: info?.country,
      year: info?.year ?? row.year,
      releaseDate: info?.releaseDate,
      releaseDateParsed: info?.releaseDateParsed,
      rating: info?.rating ?? row.rating,
      trailer: info?.youtubeTrailer,
      tmdbId: info?.tmdbId ?? row.tmdbId,
      technical: info == null
          ? null
          : technicalFromXtream(info.video, info.audio, info.bitrate),
      containerExt: row.containerExt ?? info?.containerExtension,
      added: row.added ?? info?.added,
      infoFetchedAt: fetchedAt,
      hasProviderInfo: info != null,
      error: error,
    );
  }

  Future<SeriesDetails?> _seriesDetails(
    int playlistId,
    String providerId,
    bool refresh,
  ) async {
    final initial = await _seriesRow(playlistId, providerId);
    if (initial == null) return null;
    var row = initial;
    var episodeRows = await _episodeRows(playlistId, providerId);
    SourceException? error;
    final playlist = await _playlist(playlistId);
    if (playlist?.type == PlaylistType.xtream &&
        (refresh || episodeRows.isEmpty || _isStale(row.infoFetchedAt))) {
      final client = await _client(playlist!);
      if (client == null) {
        error = _noCredentials;
      } else {
        try {
          final info = await client.seriesInfo(providerId);
          await _storeSeriesInfo(row, info);
          row = await _seriesRow(playlistId, providerId) ?? row;
          episodeRows = await _episodeRows(playlistId, providerId);
        } on SourceException catch (e) {
          error = e;
        }
      }
    }
    final seasonRows =
        await (_db.select(_db.seasons)..where(
              (s) =>
                  s.playlistId.equals(playlistId) &
                  s.seriesId.equals(providerId),
            ))
            .get();
    return _buildSeriesDetails(row, seasonRows, episodeRows, error);
  }

  Future<SeriesRow?> _seriesRow(int playlistId, String providerId) =>
      (_db.select(_db.series)
            ..where(
              (s) =>
                  s.playlistId.equals(playlistId) &
                  s.providerId.equals(providerId),
            )
            ..limit(1))
          .getSingleOrNull();

  Future<List<EpisodeRow>> _episodeRows(int playlistId, String seriesId) =>
      (_db.select(_db.episodes)
            ..where(
              (e) =>
                  e.playlistId.equals(playlistId) & e.seriesId.equals(seriesId),
            )
            ..orderBy([
              (e) => OrderingTerm.asc(e.season),
              (e) => OrderingTerm.asc(e.episodeNum),
              (e) => OrderingTerm.asc(e.id),
            ]))
          .get();

  Future<void> _storeSeriesInfo(SeriesRow row, XtreamSeriesInfo info) async {
    final playlistId = row.playlistId;
    final seriesId = row.providerId;
    final now = _now();
    final s = info.info;
    await _db.transaction(() async {
      final episodes = [for (final list in info.episodes.values) ...list];
      if (episodes.isNotEmpty) {
        await _db.batch((b) {
          for (final season in info.seasons) {
            final companion = SeasonsCompanion.insert(
              playlistId: playlistId,
              seriesId: seriesId,
              seasonNumber: season.seasonNumber,
              name: Value(season.name),
              cover: Value(season.cover),
              airDate: Value(season.airDate),
              episodeCount: Value(season.episodeCount),
              overview: Value(season.overview),
            );
            b.insert(
              _db.seasons,
              companion,
              onConflict: DoUpdate(
                (_) => companion,
                target: [
                  _db.seasons.playlistId,
                  _db.seasons.seriesId,
                  _db.seasons.seasonNumber,
                ],
              ),
            );
          }
          for (final e in episodes) {
            final duration = e.durationSecs;
            final companion = EpisodesCompanion.insert(
              playlistId: playlistId,
              providerId: e.id,
              seriesId: seriesId,
              season: e.season,
              episodeNum: e.episodeNum,
              title: e.title,
              containerExt: Value(e.containerExtension),
              plot: Value(e.plot),
              durationSecs: Value(
                duration == null || duration <= 0 ? null : duration,
              ),
              releaseDate: Value(e.releaseDate),
              image: Value(e.movieImage),
              rating: Value(e.rating),
              directSource: Value(e.directSource),
              added: Value(e.added),
            );
            b.insert(
              _db.episodes,
              companion,
              onConflict: DoUpdate(
                (_) => companion,
                target: [_db.episodes.playlistId, _db.episodes.providerId],
              ),
            );
          }
        });
        final keep = {for (final e in episodes) e.id};
        await (_db.delete(_db.episodes)..where(
              (e) =>
                  e.playlistId.equals(playlistId) &
                  e.seriesId.equals(seriesId) &
                  e.providerId.isNotIn(keep),
            ))
            .go();
        if (info.seasons.isNotEmpty) {
          final keepSeasons = {for (final s in info.seasons) s.seasonNumber};
          await (_db.delete(_db.seasons)..where(
                (x) =>
                    x.playlistId.equals(playlistId) &
                    x.seriesId.equals(seriesId) &
                    x.seasonNumber.isNotIn(keepSeasons),
              ))
              .go();
        }
      }
      await (_db.update(_db.series)..where((x) => x.id.equals(row.id))).write(
        SeriesCompanion(
          infoJson: s == null
              ? const Value.absent()
              : Value(jsonEncode(seriesToJson(s))),
          infoFetchedAt: Value(now),
          plot: _fill(row.plot, s?.plot),
          cast: _fill(row.cast, s?.cast),
          director: _fill(row.director, s?.director),
          genre: _fill(row.genre, s?.genre),
          releaseDate: _fill(row.releaseDate, s?.releaseDate),
          youtubeTrailer: _fill(row.youtubeTrailer, s?.youtubeTrailer),
          cover: _fill(row.cover, s?.cover),
          backdropsJson:
              decodeStringList(row.backdropsJson).isEmpty &&
                  (s?.backdrops.isNotEmpty ?? false)
              ? Value(jsonEncode(s!.backdrops))
              : const Value.absent(),
          tmdbId: row.tmdbId == null && s?.tmdbId != null
              ? Value(s!.tmdbId)
              : const Value.absent(),
          year: row.year == null && s?.year != null
              ? Value(s!.year)
              : const Value.absent(),
        ),
      );
    });
  }

  static Value<String?> _fill(String? current, String? fresh) =>
      (_nonBlank(current) == null && fresh != null)
      ? Value(fresh)
      : const Value.absent();

  SeriesDetails _buildSeriesDetails(
    SeriesRow row,
    List<SeasonRow> seasonRows,
    List<EpisodeRow> episodeRows,
    SourceException? error,
  ) {
    final info = decodeSeriesInfo(row.infoJson, row.providerId);
    final bySeason = <int, List<EpisodeItem>>{};
    for (final e in episodeRows) {
      (bySeason[e.season] ??= []).add(EpisodeItem.fromRow(e));
    }
    final meta = {for (final s in seasonRows) s.seasonNumber: s};
    final numbers = bySeason.keys.toList()..sort(_seasonOrder);
    final seasons = [
      for (final n in numbers)
        SeasonDetails(
          number: n,
          name: _nonBlank(meta[n]?.name),
          cover: _nonBlank(meta[n]?.cover),
          airDate: _nonBlank(meta[n]?.airDate),
          overview: _nonBlank(meta[n]?.overview),
          declaredEpisodeCount: meta[n]?.episodeCount,
          episodes: List.unmodifiable(
            bySeason[n]!..sort((a, b) {
              final c = a.episode.compareTo(b.episode);
              return c != 0 ? c : a.rowId.compareTo(b.rowId);
            }),
          ),
        ),
    ];
    final backdrops = (info?.backdrops.isNotEmpty ?? false)
        ? info!.backdrops
        : decodeStringList(row.backdropsJson);
    final releaseDate = _nonBlank(info?.releaseDate) ?? row.releaseDate;
    final runTime = info?.episodeRunTime;
    return SeriesDetails(
      providerId: row.providerId,
      name: row.name,
      categoryId: row.categoryId,
      cover: _nonBlank(row.cover) ?? info?.cover,
      backdrops: backdrops,
      plot: _nonBlank(info?.plot) ?? _nonBlank(row.plot),
      cast: splitPeople(_nonBlank(info?.cast) ?? row.cast),
      genres: splitGenres(_nonBlank(info?.genre) ?? row.genre),
      director: _nonBlank(info?.director) ?? _nonBlank(row.director),
      releaseDate: releaseDate,
      releaseDateParsed: asDate(releaseDate),
      year: info?.year ?? row.year ?? asYear(releaseDate),
      rating: info?.rating ?? row.rating,
      trailer: _nonBlank(info?.youtubeTrailer) ?? _nonBlank(row.youtubeTrailer),
      tmdbId: info?.tmdbId ?? row.tmdbId,
      episodeRunTime: runTime == null || runTime <= 0
          ? null
          : Duration(minutes: runTime),
      lastModified: row.lastModified,
      infoFetchedAt: row.infoFetchedAt,
      seasons: List.unmodifiable(seasons),
      error: error,
    );
  }

  /// Regular seasons ascending, season 0 last.
  static int _seasonOrder(int a, int b) {
    if (a == b) return 0;
    if (a == 0) return 1;
    if (b == 0) return -1;
    return a.compareTo(b);
  }

  static List<EpisodeRow> _displayOrder(List<EpisodeRow> rows) {
    final list = [...rows];
    list.sort((a, b) {
      final s = _seasonOrder(a.season, b.season);
      if (s != 0) return s;
      final e = a.episodeNum.compareTo(b.episodeNum);
      return e != 0 ? e : a.id.compareTo(b.id);
    });
    return list;
  }
}

/// FROM / WHERE / natural ORDER BY of a list selection.
class _Source {
  const _Source({
    required this.from,
    required this.where,
    required this.variables,
    required this.order,
    required this.readsFrom,
    this.orderIsName = false,
    this.cap,
  });

  /// `FROM …` with joins (the item alias and `f` / `w` available).
  final String from;
  final String where;

  /// In order of appearance: FROM first, then WHERE.
  final List<Variable<Object>> variables;

  /// ORDER BY for [VodSort.playlist].
  final String order;

  /// The natural order is by name (favorites order "name").
  final bool orderIsName;

  /// Hard limit applied in the natural order (Last watched).
  final int? cap;
  final Set<ResultSetImplementation<dynamic, dynamic>> readsFrom;
}

class _ClientEntry {
  _ClientEntry({
    required this.credentials,
    required this.userAgent,
    required this.dio,
    required this.client,
  });

  final XtreamCredentials credentials;
  final String? userAgent;
  final Dio dio;
  final XtreamClient client;
}

String? _nonBlank(String? s) {
  final t = s?.trim();
  return (t == null || t.isEmpty) ? null : t;
}

// ---------------------------------------------------------------------------
// Info JSON (stored in movies.infoJson / series.infoJson)
// ---------------------------------------------------------------------------

/// Serializes [info] in the `get_vod_info` shape (`{info, movie_data}`), so
/// `XtreamVodInfo.fromJson` reads it back. This is the `movies.infoJson`
/// format.
Map<String, Object?> vodInfoToJson(XtreamVodInfo info) => {
  'info': _compact({
    'tmdb_id': info.tmdbId,
    'name': info.name,
    'o_name': info.originalName,
    'cover_big': info.coverBig,
    'movie_image': info.movieImage,
    'backdrop_path': info.backdrops,
    'releasedate': info.releaseDate,
    'year': info.year,
    'youtube_trailer': info.youtubeTrailer,
    'director': info.director,
    'actors': info.actors,
    'cast': info.cast,
    'description': info.description,
    'plot': info.plot,
    'genre': info.genre,
    'age': info.age,
    'mpaa_rating': info.mpaaRating,
    'country': info.country,
    'duration_secs': info.durationSecs,
    'duration': info.duration,
    'rating': info.rating,
    'video': _videoToJson(info.video),
    'audio': _audioToJson(info.audio),
    'bitrate': info.bitrate,
  }),
  'movie_data': _compact({
    'stream_id': info.streamId,
    'name': info.name,
    'container_extension': info.containerExtension,
    'added': info.added == null
        ? null
        : '${info.added!.millisecondsSinceEpoch ~/ 1000}',
    'category_id': info.categoryId,
    'category_ids': info.categoryIds,
    'direct_source': info.directSource,
    'custom_sid': info.customSid,
  }),
};

/// Serializes `get_series_info.info` (an [XtreamSeries]) so
/// `XtreamSeries.fromJson` reads it back. This is the `series.infoJson`
/// format.
Map<String, Object?> seriesToJson(XtreamSeries s) => _compact({
  'series_id': s.seriesId.isEmpty ? null : s.seriesId,
  'name': s.name,
  'cover': s.cover,
  'plot': s.plot,
  'cast': s.cast,
  'director': s.director,
  'genre': s.genre,
  'releaseDate': s.releaseDate,
  'year': s.year,
  'last_modified': s.lastModified == null
      ? null
      : '${s.lastModified!.millisecondsSinceEpoch ~/ 1000}',
  'rating': s.rating,
  'backdrop_path': s.backdrops,
  'youtube_trailer': s.youtubeTrailer,
  'episode_run_time': s.episodeRunTime,
  'tmdb': s.tmdbId,
  'category_id': s.categoryId,
});

/// Reads `movies.infoJson`; null when missing, invalid or empty.
XtreamVodInfo? decodeVodInfo(String? json, String vodId) {
  if (json == null || json.isEmpty) return null;
  try {
    final info = XtreamVodInfo.fromJson(jsonDecode(json), vodId: vodId);
    return info.isEmpty ? null : info;
  } on FormatException {
    return null;
  }
}

/// Reads `series.infoJson`; null when missing or invalid.
XtreamSeries? decodeSeriesInfo(String? json, String seriesId) {
  if (json == null || json.isEmpty) return null;
  try {
    return XtreamSeries.fromJson(jsonDecode(json), fallbackId: seriesId);
  } on FormatException {
    return null;
  }
}

Map<String, Object?>? _videoToJson(XtreamVideoInfo? v) => v == null
    ? null
    : _compact({
        'codec_name': v.codecName,
        'codec_long_name': v.codecLongName,
        'profile': v.profile,
        'width': v.width,
        'height': v.height,
        'display_aspect_ratio': v.displayAspectRatio,
        'pix_fmt': v.pixFmt,
        'field_order': v.fieldOrder,
        'color_transfer': v.colorTransfer,
        'avg_frame_rate': v.frameRate == null ? null : '${v.frameRate}',
        'bit_rate': v.bitRate,
        if (v.language != null) 'tags': {'language': v.language},
      });

Map<String, Object?>? _audioToJson(XtreamAudioInfo? a) => a == null
    ? null
    : _compact({
        'codec_name': a.codecName,
        'codec_long_name': a.codecLongName,
        'profile': a.profile,
        'channels': a.channels,
        'channel_layout': a.channelLayout,
        'sample_rate': a.sampleRate,
        'bit_rate': a.bitRate,
        if (a.language != null) 'tags': {'language': a.language},
      });

Map<String, Object?> _compact(Map<String, Object?> map) =>
    map..removeWhere((_, v) => v == null || (v is List && v.isEmpty));

/// Technical badges from ffprobe-style `video` / `audio` blocks and the
/// `bitrate` (kbit/s) of `get_vod_info` or an episode. Null when nothing is
/// known.
MediaTechnical? technicalFromXtream(
  XtreamVideoInfo? video,
  XtreamAudioInfo? audio,
  int? bitrateKbps,
) {
  final width = video?.width;
  final height = video?.height;
  final videoBits = video?.bitRate;
  final technical = MediaTechnical(
    width: width,
    height: height,
    resolution: resolutionLabel(width, height),
    videoCodec: _videoCodecLabel(video?.codecName),
    videoCodecName: video?.codecName,
    hdr: const {
      'smpte2084',
      'arib-std-b67',
    }.contains(video?.colorTransfer?.toLowerCase()),
    frameRate: video?.frameRate,
    audioCodec: _audioCodecLabel(audio?.codecName),
    audioCodecName: audio?.codecName,
    audioChannels: audio?.channels,
    audioLayout: _audioLayoutLabel(audio?.channels, audio?.channelLayout),
    bitrateKbps:
        (bitrateKbps != null && bitrateKbps > 0 ? bitrateKbps : null) ??
        (videoBits == null ? null : (videoBits / 1000).round()),
  );
  return technical.isEmpty ? null : technical;
}

/// `8K`, `4K`, `FHD`, `HD` or `SD` from a frame size (wide formats such as
/// 1920×800 count as FHD).
String? resolutionLabel(int? width, int? height) {
  final w = width ?? 0;
  final h = height ?? 0;
  if (w <= 0 && h <= 0) return null;
  if (w >= 7000 || h >= 4000) return '8K';
  if (w >= 3800 || h >= 2000) return '4K';
  if (w >= 1900 || h >= 1000) return 'FHD';
  if (w >= 1200 || h >= 700) return 'HD';
  return 'SD';
}

String? _videoCodecLabel(String? codec) {
  final c = codec?.toLowerCase();
  if (c == null || c.isEmpty) return null;
  return switch (c) {
    'h264' || 'avc' || 'avc1' => 'H.264',
    'hevc' || 'h265' => 'HEVC',
    'mpeg2video' => 'MPEG-2',
    'mpeg4' => 'MPEG-4',
    'av1' => 'AV1',
    'vp9' => 'VP9',
    'vp8' => 'VP8',
    'vc1' => 'VC-1',
    _ => c.toUpperCase(),
  };
}

String? _audioCodecLabel(String? codec) {
  final c = codec?.toLowerCase();
  if (c == null || c.isEmpty) return null;
  return switch (c) {
    'aac' => 'AAC',
    'ac3' => 'AC-3',
    'eac3' => 'E-AC-3',
    'dts' => 'DTS',
    'truehd' => 'TrueHD',
    'mp2' => 'MP2',
    'mp3' => 'MP3',
    'opus' => 'Opus',
    'flac' => 'FLAC',
    'vorbis' => 'Vorbis',
    _ when c.startsWith('pcm') => 'PCM',
    _ => c.toUpperCase(),
  };
}

String? _audioLayoutLabel(int? channels, String? layout) {
  switch (channels) {
    case 1:
      return 'mono';
    case 2:
      return 'stereo';
    case 6:
      return '5.1';
    case 8:
      return '7.1';
  }
  final l = layout?.toLowerCase();
  if (l == null || l.isEmpty) return channels == null ? null : '${channels}ch';
  if (l.startsWith('5.1')) return '5.1';
  if (l.startsWith('7.1')) return '7.1';
  return l;
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final vodRepositoryProvider = Provider<VodRepository>((ref) {
  final repo = VodRepository(
    db: ref.watch(appDatabaseProvider),
    settings: ref.watch(settingsStoreProvider),
    secrets: ref.watch(secretStoreProvider),
  );
  ref.onDispose(repo.dispose);
  return repo;
});

/// Whether lists leave out locked categories: parental mode `hide` and the
/// session has not unlocked everything (the rule of the category sidebar,
/// `categoriesProvider`).
bool watchExcludeLocked(Ref ref, int playlistId) {
  final mode = ref.watchSetting(
    PlaylistSettings.parentalMode,
    playlistId: playlistId,
  );
  if (mode != 'hide') return false;
  return !ref.watch(
    parentalSessionProvider.select((s) => s.allUnlockedFor(playlistId)),
  );
}

/// Arguments of [vodCategoryItemsProvider].
typedef VodCategoryArgs = ({
  int playlistId,
  SectionKind kind,
  CategoryRef category,
  VodSort sort,
  String? filter,
});

/// The Movies / Shows grid of a sidebar selection (see
/// [VodRepository.watchCategoryItems]); favorites order, parental `hide`
/// mode and session unlocks are applied like in the sidebar.
final vodCategoryItemsProvider = StreamProvider.autoDispose
    .family<List<VodItem>, VodCategoryArgs>((ref, a) {
      final excludeLocked = watchExcludeLocked(ref, a.playlistId);
      final order = FavoritesOrder.fromSetting(
        ref.watchSetting(
          PlaylistSettings.favoritesOrder,
          playlistId: a.playlistId,
        ),
      );
      return ref
          .watch(vodRepositoryProvider)
          .watchCategoryItems(
            a.playlistId,
            a.kind,
            a.category,
            sort: a.sort,
            filter: a.filter,
            excludeLocked: excludeLocked,
            favoritesOrder: order,
          );
    });

/// Arguments for per-section providers.
typedef VodSectionArgs = ({int playlistId, SectionKind kind});

/// Provider-category rows of the Movies / Shows home (rebuilds when the
/// category order or parental settings change).
final vodHomeRowsProvider = StreamProvider.autoDispose
    .family<List<VodHomeRow>, VodSectionArgs>((ref, a) {
      final excludeLocked = watchExcludeLocked(ref, a.playlistId);
      ref.watchSetting(
        PlaylistSettings.categoriesOrder,
        playlistId: a.playlistId,
      );
      return ref
          .watch(vodRepositoryProvider)
          .watchHomeRows(a.playlistId, a.kind, excludeLocked: excludeLocked);
    });

/// The "Recently added" row (7 days).
final recentlyAddedProvider = StreamProvider.autoDispose
    .family<List<VodItem>, VodSectionArgs>((ref, a) {
      final excludeLocked = watchExcludeLocked(ref, a.playlistId);
      final repo = ref.watch(vodRepositoryProvider);
      return a.kind == SectionKind.series
          ? repo.watchRecentlyAddedSeries(
              a.playlistId,
              excludeLocked: excludeLocked,
            )
          : repo.watchRecentlyAddedMovies(
              a.playlistId,
              excludeLocked: excludeLocked,
            );
    });

/// Rotating hero items.
final heroCandidatesProvider = FutureProvider.autoDispose
    .family<List<VodItem>, VodSectionArgs>((ref, a) {
      final excludeLocked = watchExcludeLocked(ref, a.playlistId);
      return ref
          .watch(vodRepositoryProvider)
          .heroCandidates(a.playlistId, a.kind, excludeLocked: excludeLocked);
    });

/// The Favorites row (order from the favorites order setting).
final favoriteItemsProvider = StreamProvider.autoDispose
    .family<List<VodItem>, ({int playlistId, SectionKind kind, int? tagId})>((
      ref,
      a,
    ) {
      final excludeLocked = watchExcludeLocked(ref, a.playlistId);
      final order = FavoritesOrder.fromSetting(
        ref.watchSetting(
          PlaylistSettings.favoritesOrder,
          playlistId: a.playlistId,
        ),
      );
      return ref
          .watch(vodRepositoryProvider)
          .watchFavoriteItems(
            a.playlistId,
            a.kind,
            tagId: a.tagId,
            order: order,
            excludeLocked: excludeLocked,
          );
    });

/// Movie detail sheet data.
final movieDetailsProvider = FutureProvider.autoDispose
    .family<MovieDetails?, ({int playlistId, String providerId})>(
      (ref, a) => ref
          .watch(vodRepositoryProvider)
          .movieDetails(a.playlistId, a.providerId),
    );

/// Series detail sheet data (invalidate after `refreshEpisodes`).
final seriesDetailsProvider = FutureProvider.autoDispose
    .family<SeriesDetails?, ({int playlistId, String providerId})>(
      (ref, a) => ref
          .watch(vodRepositoryProvider)
          .seriesDetails(a.playlistId, a.providerId),
    );

/// Hidden movies and series of a playlist.
final hiddenVodItemsProvider = StreamProvider.autoDispose
    .family<List<VodItem>, int>(
      (ref, playlistId) =>
          ref.watch(vodRepositoryProvider).watchHiddenItems(playlistId),
    );
