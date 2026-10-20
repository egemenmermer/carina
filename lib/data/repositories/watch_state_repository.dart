import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_paths.dart';
import '../db/database.dart';
import '../settings/settings_store.dart';
import 'repository_models.dart' show isTurkishCollation;
import 'vod_models.dart';
import 'vod_repository.dart' show watchExcludeLocked;

export 'vod_models.dart'
    show
        ContinueWatchingEntry,
        ContinueWatchingOrder,
        ResumeDecision,
        ResumeKind,
        WatchState,
        kInProgressMinFraction,
        kWatchedFraction;

/// Resume positions, watched flags and Continue watching.
///
/// Rules: a save at or above 95% marks the item watched (the flag sticks
/// until [setWatched] clears it); positions below 2% do not count as in
/// progress; [resumeFor] offers resuming between 2% and 95%.
class WatchStateRepository {
  WatchStateRepository({
    required this._db,
    this._settings,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final SettingsStore? _settings;
  final DateTime Function() _clock;
  late final NameKeys _keys = NameKeys(
    maxEntries: 20000,
    turkish: () => _settings != null && isTurkishCollation(_settings),
  );

  // -------------------------------------------------------------------------
  // Positions
  // -------------------------------------------------------------------------

  /// Stores the playback position (the player calls this every 5 s and on
  /// exit). Episodes without [seriesId] are looked up in the episodes table.
  /// A zero [duration] keeps the stored one.
  Future<WatchState> save(
    int playlistId,
    ItemType type,
    String id,
    Duration position,
    Duration duration, {
    String? seriesId,
  }) => _db.transaction(() async {
    final existing = await _row(playlistId, type, id);
    final series =
        seriesId ??
        existing?.seriesId ??
        (type == ItemType.episode ? await _seriesOf(playlistId, id) : null);
    final positionMs = math.max(0, position.inMilliseconds);
    final durationMs = duration.inMilliseconds > 0
        ? duration.inMilliseconds
        : (existing?.durationMs ?? 0);
    final fraction = durationMs > 0 ? positionMs / durationMs : null;
    final watched =
        (existing?.watched ?? false) ||
        (fraction != null && fraction >= kWatchedFraction);
    final row = WatchStateRow(
      playlistId: playlistId,
      itemType: type,
      providerId: id,
      seriesId: series,
      positionMs: positionMs,
      durationMs: durationMs,
      watched: watched,
      updatedAt: _clock(),
    );
    await _db.into(_db.watchStates).insertOnConflictUpdate(row);
    return WatchState.fromRow(row);
  });

  Future<WatchState?> get(int playlistId, ItemType type, String id) async {
    final row = await _row(playlistId, type, id);
    return row == null ? null : WatchState.fromRow(row);
  }

  Stream<WatchState?> watch(int playlistId, ItemType type, String id) =>
      (_db.select(_db.watchStates)..where(
            (w) =>
                w.playlistId.equals(playlistId) &
                w.itemType.equalsValue(type) &
                w.providerId.equals(id),
          ))
          .watchSingleOrNull()
          .map((row) => row == null ? null : WatchState.fromRow(row));

  /// Removes the stored state ("Remove from Continue watching").
  Future<void> clear(int playlistId, ItemType type, String id) =>
      (_db.delete(_db.watchStates)..where(
            (w) =>
                w.playlistId.equals(playlistId) &
                w.itemType.equalsValue(type) &
                w.providerId.equals(id),
          ))
          .go();

  /// Marks an item watched / unwatched (context menu). Both reset the
  /// resume position. For a series, every stored episode follows.
  Future<void> setWatched(
    int playlistId,
    ItemType type,
    String id,
    bool watched, {
    String? seriesId,
  }) => _db.transaction(() async {
    final now = _clock();
    final existing = await _row(playlistId, type, id);
    final series =
        seriesId ??
        existing?.seriesId ??
        (type == ItemType.episode ? await _seriesOf(playlistId, id) : null);
    await _db
        .into(_db.watchStates)
        .insertOnConflictUpdate(
          WatchStateRow(
            playlistId: playlistId,
            itemType: type,
            providerId: id,
            seriesId: series,
            positionMs: 0,
            durationMs: existing?.durationMs ?? 0,
            watched: watched,
            updatedAt: now,
          ),
        );
    if (type == ItemType.series) {
      final episodes =
          await (_db.select(_db.episodes)..where(
                (e) => e.playlistId.equals(playlistId) & e.seriesId.equals(id),
              ))
              .get();
      await _markEpisodes(playlistId, episodes, watched, now);
    }
  });

  /// "Mark all previous as watched": every episode before S[season]
  /// E[episode] (earlier seasons and earlier episodes of the season;
  /// specials only count before a special). Returns how many were marked.
  Future<int> markPreviousWatched(
    int playlistId,
    String seriesId,
    int season,
    int episode,
  ) => _db.transaction(() async {
    final episodes =
        await (_db.select(_db.episodes)..where(
              (e) =>
                  e.playlistId.equals(playlistId) &
                  e.seriesId.equals(seriesId) &
                  (season == 0
                      ? e.season.equals(0) &
                            e.episodeNum.isSmallerThanValue(episode)
                      : e.season.isBiggerThanValue(0) &
                            (e.season.isSmallerThanValue(season) |
                                (e.season.equals(season) &
                                    e.episodeNum.isSmallerThanValue(episode)))),
            ))
            .get();
    await _markEpisodes(playlistId, episodes, true, _clock());
    return episodes.length;
  });

  /// Provider ids of the watched episodes of a series.
  Future<Set<String>> watchedEpisodeIds(int playlistId, String seriesId) async {
    final states = await _episodeStatesQuery(playlistId, seriesId).get();
    return {
      for (final r in states)
        if (WatchState.fromRow(r).finished) r.providerId,
    };
  }

  Stream<Set<String>> watchWatchedEpisodeIds(int playlistId, String seriesId) =>
      watchEpisodeStates(playlistId, seriesId).map(
        (states) => {
          for (final s in states.values)
            if (s.finished) s.providerId,
        },
      );

  /// Episode states of a series by episode provider id (progress bars and
  /// eye icons in the series sheet).
  Stream<Map<String, WatchState>> watchEpisodeStates(
    int playlistId,
    String seriesId,
  ) => _episodeStatesQuery(playlistId, seriesId).watch().map(
    (rows) => {for (final r in rows) r.providerId: WatchState.fromRow(r)},
  );

  /// What to do when an item opens: nothing below 2% or from 95%, else
  /// offer resuming (or resume directly with [alwaysResume]).
  ResumeDecision resumeFor(WatchState? state, {bool alwaysResume = false}) {
    if (state == null) return const ResumeDecision.none();
    if (!isInProgress(state.position, state.duration)) {
      return const ResumeDecision.none();
    }
    return alwaysResume
        ? ResumeDecision.resume(state.position)
        : ResumeDecision.offer(state.position);
  }

  // -------------------------------------------------------------------------
  // Continue watching
  // -------------------------------------------------------------------------

  /// In-progress movies (2%–95%, not watched) in [order] (default:
  /// `PlaylistSettings.continueWatchingOrder`). Hidden movies and movies of
  /// hidden categories (and of locked ones with [excludeLocked]) are left
  /// out, like in every aggregated row.
  Future<List<ContinueWatchingEntry>> continueWatchingMovies(
    int playlistId, {
    ContinueWatchingOrder? order,
    bool excludeLocked = false,
  }) async {
    final effective = order ?? _defaultOrder(playlistId);
    final rows = await _moviesQuery(playlistId, effective, excludeLocked).get();
    return _mapMovies(rows, effective);
  }

  Stream<List<ContinueWatchingEntry>> watchContinueWatchingMovies(
    int playlistId, {
    ContinueWatchingOrder? order,
    bool excludeLocked = false,
  }) {
    final effective = order ?? _defaultOrder(playlistId);
    return _moviesQuery(
      playlistId,
      effective,
      excludeLocked,
    ).watch().map((rows) => _mapMovies(rows, effective));
  }

  /// One entry per series: its most recently played episode when in
  /// progress, or the next unwatched episode after a finished one. Series
  /// marked watched, series whose last episode is finished, hidden series
  /// and series of hidden categories (and of locked ones with
  /// [excludeLocked]) are left out. The entry carries the series card, the
  /// episode and its `S1 E2 · Title` label.
  Future<List<ContinueWatchingEntry>> continueWatchingShows(
    int playlistId, {
    ContinueWatchingOrder? order,
    bool excludeLocked = false,
  }) async {
    final effective = order ?? _defaultOrder(playlistId);
    final stateRows = await _db
        .customSelect(
          'SELECT w.provider_id AS provider_id, '
          'COALESCE(w.series_id, e.series_id) AS sid, '
          'w.position_ms AS position_ms, w.duration_ms AS duration_ms, '
          'w.watched AS watched, w.updated_at AS updated_at '
          'FROM watch_states w LEFT JOIN episodes e '
          'ON e.playlist_id = w.playlist_id AND e.provider_id = w.provider_id '
          'WHERE w.playlist_id = ? AND w.item_type = ?',
          variables: [
            Variable.withInt(playlistId),
            Variable.withInt(ItemType.episode.index),
          ],
          readsFrom: {_db.watchStates, _db.episodes},
        )
        .get();
    if (stateRows.isEmpty) return const [];
    final bySeries = <String, List<WatchState>>{};
    for (final r in stateRows) {
      final sid = r.readNullable<String>('sid');
      if (sid == null) continue;
      (bySeries[sid] ??= []).add(
        WatchState(
          type: ItemType.episode,
          providerId: r.read<String>('provider_id'),
          seriesId: sid,
          position: Duration(milliseconds: r.read<int>('position_ms')),
          duration: Duration(milliseconds: r.read<int>('duration_ms')),
          watched: r.read<bool>('watched'),
          updatedAt: r.read<DateTime>('updated_at'),
        ),
      );
    }
    final watchedSeries = {
      for (final r
          in await (_db.select(_db.watchStates)..where(
                (w) =>
                    w.playlistId.equals(playlistId) &
                    w.itemType.equalsValue(ItemType.series) &
                    w.watched.equals(true),
              ))
              .get())
        r.providerId,
    };
    final seriesIds = [
      for (final sid in bySeries.keys)
        if (!watchedSeries.contains(sid)) sid,
    ];
    if (seriesIds.isEmpty) return const [];
    final items = await _seriesItems(playlistId, seriesIds, excludeLocked);
    final episodes = await _episodesOf(playlistId, items.keys.toList());

    final entries = <ContinueWatchingEntry>[];
    for (final sid in seriesIds) {
      final item = items[sid];
      if (item == null) continue;
      final entry = _showEntry(item, episodes[sid] ?? const [], bySeries[sid]!);
      if (entry != null) entries.add(entry);
    }
    return _sortEntries(entries, effective);
  }

  Stream<List<ContinueWatchingEntry>> watchContinueWatchingShows(
    int playlistId, {
    ContinueWatchingOrder? order,
    bool excludeLocked = false,
  }) => asyncMapLatest(
    _changes({
      _db.watchStates,
      _db.episodes,
      _db.series,
      _db.favorites,
      _db.categories,
    }),
    (_) => continueWatchingShows(
      playlistId,
      order: order,
      excludeLocked: excludeLocked,
    ),
  );

  // -------------------------------------------------------------------------
  // Internals
  // -------------------------------------------------------------------------

  ContinueWatchingOrder _defaultOrder(int playlistId) =>
      ContinueWatchingOrder.fromSetting(
        _settings?.get(
          PlaylistSettings.continueWatchingOrder,
          playlistId: playlistId,
        ),
      );

  Future<WatchStateRow?> _row(int playlistId, ItemType type, String id) =>
      (_db.select(_db.watchStates)
            ..where(
              (w) =>
                  w.playlistId.equals(playlistId) &
                  w.itemType.equalsValue(type) &
                  w.providerId.equals(id),
            )
            ..limit(1))
          .getSingleOrNull();

  Future<String?> _seriesOf(int playlistId, String episodeId) async {
    final row =
        await (_db.select(_db.episodes)
              ..where(
                (e) =>
                    e.playlistId.equals(playlistId) &
                    e.providerId.equals(episodeId),
              )
              ..limit(1))
            .getSingleOrNull();
    return row?.seriesId;
  }

  Future<void> _markEpisodes(
    int playlistId,
    List<EpisodeRow> episodes,
    bool watched,
    DateTime now,
  ) async {
    if (episodes.isEmpty) return;
    final existing = {
      for (final r
          in await (_db.select(_db.watchStates)..where(
                (w) =>
                    w.playlistId.equals(playlistId) &
                    w.itemType.equalsValue(ItemType.episode) &
                    w.providerId.isIn(episodes.map((e) => e.providerId)),
              ))
              .get())
        r.providerId: r,
    };
    await _db.batch((b) {
      for (final e in episodes) {
        final known = existing[e.providerId];
        b.insert(
          _db.watchStates,
          WatchStateRow(
            playlistId: playlistId,
            itemType: ItemType.episode,
            providerId: e.providerId,
            seriesId: e.seriesId,
            positionMs: 0,
            durationMs: known?.durationMs ?? ((e.durationSecs ?? 0) * 1000),
            watched: watched,
            updatedAt: now,
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  SimpleSelectStatement<$WatchStatesTable, WatchStateRow> _episodeStatesQuery(
    int playlistId,
    String seriesId,
  ) => _db.select(_db.watchStates)
    ..where(
      (w) =>
          w.playlistId.equals(playlistId) &
          w.itemType.equalsValue(ItemType.episode) &
          (w.seriesId.equals(seriesId) |
              w.providerId.isInQuery(
                _db.selectOnly(_db.episodes)
                  ..addColumns([_db.episodes.providerId])
                  ..where(
                    _db.episodes.playlistId.equals(playlistId) &
                        _db.episodes.seriesId.equals(seriesId),
                  ),
              )),
    );

  Selectable<QueryRow> _moviesQuery(
    int playlistId,
    ContinueWatchingOrder order,
    bool excludeLocked,
  ) {
    final orderBy = switch (order) {
      ContinueWatchingOrder.lastUpdated ||
      ContinueWatchingOrder.name => 'w.updated_at DESC, m.id DESC',
      ContinueWatchingOrder.lastAdded =>
        'm.added IS NULL, m.added DESC, w.updated_at DESC, m.id DESC',
    };
    return _db.customSelect(
      'SELECT ${VodSql.movieColumns}, w.updated_at AS played_at '
      'FROM watch_states w '
      'JOIN movies m ON m.playlist_id = w.playlist_id '
      'AND m.provider_id = w.provider_id '
      '${VodSql.favoriteJoin(SectionKind.movie)} '
      'WHERE w.playlist_id = ? AND w.item_type = ? AND w.watched = 0 '
      'AND m.hidden = 0 AND w.duration_ms > 0 AND '
      '${VodSql.notInHiddenCategory(SectionKind.movie, includeLocked: excludeLocked)} '
      'AND w.position_ms >= w.duration_ms * $kInProgressMinFraction '
      'AND w.position_ms < w.duration_ms * $kWatchedFraction '
      'ORDER BY $orderBy',
      variables: [
        Variable.withInt(playlistId),
        Variable.withInt(ItemType.movie.index),
      ],
      readsFrom: {_db.watchStates, _db.movies, _db.favorites, _db.categories},
    );
  }

  List<ContinueWatchingEntry> _mapMovies(
    List<QueryRow> rows,
    ContinueWatchingOrder order,
  ) {
    final now = _clock();
    final entries = rows.map((r) {
      final item = readVodItem(r, SectionKind.movie, now);
      return ContinueWatchingEntry(
        item: item,
        position: item.position,
        duration: item.duration,
        updatedAt: r.read<DateTime>('played_at'),
      );
    }).toList();
    return order == ContinueWatchingOrder.name
        ? List.unmodifiable(_keys.sort(entries, (e) => e.item.name))
        : List.unmodifiable(entries);
  }

  Future<Map<String, VodItem>> _seriesItems(
    int playlistId,
    List<String> seriesIds,
    bool excludeLocked,
  ) async {
    final out = <String, VodItem>{};
    final now = _clock();
    for (var i = 0; i < seriesIds.length; i += 500) {
      final chunk = seriesIds.sublist(i, math.min(seriesIds.length, i + 500));
      final rows = await _db
          .customSelect(
            'SELECT ${VodSql.seriesColumns} ${VodSql.from(SectionKind.series)} '
            'WHERE s.playlist_id = ? AND s.hidden = 0 AND '
            '${VodSql.notInHiddenCategory(SectionKind.series, includeLocked: excludeLocked)} '
            'AND s.provider_id IN '
            '(${VodSql.placeholders(chunk.length)})',
            variables: [
              Variable.withInt(playlistId),
              for (final id in chunk) Variable.withString(id),
            ],
            readsFrom: VodSql.readsFrom(_db, SectionKind.series),
          )
          .get();
      for (final r in rows) {
        final item = readVodItem(r, SectionKind.series, now);
        out[item.providerId] = item;
      }
    }
    return out;
  }

  /// Episodes per series in display order (regular seasons, then specials).
  Future<Map<String, List<EpisodeRow>>> _episodesOf(
    int playlistId,
    List<String> seriesIds,
  ) async {
    final out = <String, List<EpisodeRow>>{};
    for (var i = 0; i < seriesIds.length; i += 500) {
      final chunk = seriesIds.sublist(i, math.min(seriesIds.length, i + 500));
      final rows =
          await (_db.select(_db.episodes)..where(
                (e) => e.playlistId.equals(playlistId) & e.seriesId.isIn(chunk),
              ))
              .get();
      for (final r in rows) {
        (out[r.seriesId] ??= []).add(r);
      }
    }
    for (final list in out.values) {
      list.sort((a, b) {
        final s = _seasonOrder(a.season, b.season);
        if (s != 0) return s;
        final e = a.episodeNum.compareTo(b.episodeNum);
        return e != 0 ? e : a.id.compareTo(b.id);
      });
    }
    return out;
  }

  ContinueWatchingEntry? _showEntry(
    VodItem series,
    List<EpisodeRow> episodes,
    List<WatchState> states,
  ) {
    final index = {
      for (var i = 0; i < episodes.length; i++) episodes[i].providerId: i,
    };
    final byId = {for (final s in states) s.providerId: s};
    final anchors =
        states
            .where(
              (s) =>
                  s.finished ||
                  (progressOf(s.position, s.duration) ?? 0) >=
                      kInProgressMinFraction,
            )
            .toList()
          ..sort((a, b) {
            final c = b.updatedAt.compareTo(a.updatedAt);
            if (c != 0) return c;
            return (index[b.providerId] ?? -1).compareTo(
              index[a.providerId] ?? -1,
            );
          });
    if (anchors.isEmpty) return null;
    final anchor = anchors.first;
    final at = index[anchor.providerId];
    if (at == null) return null;
    if (!anchor.finished) {
      return ContinueWatchingEntry(
        item: series,
        episode: EpisodeItem.fromRow(episodes[at]),
        position: anchor.position,
        duration: anchor.duration,
        updatedAt: anchor.updatedAt,
      );
    }
    final anchorSeason = episodes[at].season;
    for (var i = at + 1; i < episodes.length; i++) {
      final e = episodes[i];
      if (anchorSeason != 0 && e.season == 0) break;
      final state = byId[e.providerId];
      if (state != null && state.finished) continue;
      final episode = EpisodeItem.fromRow(e);
      return ContinueWatchingEntry(
        item: series,
        episode: episode,
        isNextEpisode: true,
        position: state?.position ?? Duration.zero,
        duration: (state != null && state.duration > Duration.zero)
            ? state.duration
            : (episode.duration ?? Duration.zero),
        updatedAt: anchor.updatedAt,
      );
    }
    return null;
  }

  List<ContinueWatchingEntry> _sortEntries(
    List<ContinueWatchingEntry> entries,
    ContinueWatchingOrder order,
  ) {
    switch (order) {
      case ContinueWatchingOrder.lastUpdated:
        entries.sort((a, b) {
          final c = b.updatedAt.compareTo(a.updatedAt);
          return c != 0 ? c : b.item.rowId.compareTo(a.item.rowId);
        });
        return List.unmodifiable(entries);
      case ContinueWatchingOrder.lastAdded:
        entries.sort((a, b) {
          final x = a.item.added;
          final y = b.item.added;
          if (x != null && y != null && x != y) return y.compareTo(x);
          if (x == null && y != null) return 1;
          if (x != null && y == null) return -1;
          return b.updatedAt.compareTo(a.updatedAt);
        });
        return List.unmodifiable(entries);
      case ContinueWatchingOrder.name:
        entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return List.unmodifiable(_keys.sort(entries, (e) => e.item.name));
    }
  }

  static int _seasonOrder(int a, int b) {
    if (a == b) return 0;
    if (a == 0) return 1;
    if (b == 0) return -1;
    return a.compareTo(b);
  }

  Stream<void> _changes(
    Iterable<ResultSetImplementation<dynamic, dynamic>> tables,
  ) async* {
    yield null;
    yield* _db.tableUpdates(TableUpdateQuery.onAllTables(tables));
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final watchStateRepositoryProvider = Provider<WatchStateRepository>(
  (ref) => WatchStateRepository(
    db: ref.watch(appDatabaseProvider),
    settings: ref.watch(settingsStoreProvider),
  ),
);

/// Watch state of one movie / episode / series.
final watchStateProvider = StreamProvider.autoDispose
    .family<WatchState?, ({int playlistId, ItemType type, String providerId})>(
      (ref, a) => ref
          .watch(watchStateRepositoryProvider)
          .watch(a.playlistId, a.type, a.providerId),
    );

/// Episode states of a series by episode id.
final episodeStatesProvider = StreamProvider.autoDispose
    .family<Map<String, WatchState>, ({int playlistId, String seriesId})>(
      (ref, a) => ref
          .watch(watchStateRepositoryProvider)
          .watchEpisodeStates(a.playlistId, a.seriesId),
    );

/// Continue watching row of Movies ([SectionKind.movie]) or Shows
/// ([SectionKind.series]), in the order of the setting.
final continueWatchingProvider = StreamProvider.autoDispose
    .family<List<ContinueWatchingEntry>, ({int playlistId, SectionKind kind})>((
      ref,
      a,
    ) {
      final order = ContinueWatchingOrder.fromSetting(
        ref.watchSetting(
          PlaylistSettings.continueWatchingOrder,
          playlistId: a.playlistId,
        ),
      );
      final excludeLocked = watchExcludeLocked(ref, a.playlistId);
      final repo = ref.watch(watchStateRepositoryProvider);
      return a.kind == SectionKind.series
          ? repo.watchContinueWatchingShows(
              a.playlistId,
              order: order,
              excludeLocked: excludeLocked,
            )
          : repo.watchContinueWatchingMovies(
              a.playlistId,
              order: order,
              excludeLocked: excludeLocked,
            );
    });
