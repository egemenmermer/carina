/// Incremental writes of playlist content (ARCHITECTURE 2.11).
///
/// Protocol of a content import:
/// 1. for each section: [ContentWriter.upsertCategories] /
///    [ContentWriter.upsertChannels] / … mark the section's existing rows
///    `removed = 1`, then upsert the new rows (`removed = 0`) on the unique
///    keys, at most `batchSize` rows per transaction;
/// 2. on success: [ContentWriter.deleteRemoved], [rebuildSearchIndex],
///    [ContentWriter.updateCounts];
/// 3. on failure or cancel: [ContentWriter.revertRemoved] (the previous data
///    stays usable; rows updated so far keep their fresh values).
///
/// Upserts never touch local fields: `localName`, `customIndex`, `hidden`,
/// `locked`, `customEpgId`; `infoJson` / `infoFetchedAt` are cleared only
/// when the item changed upstream; `matchedEpgId` is cleared only when the
/// channel's tvg-id or name changed (it is re-matched afterwards).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../db/database.dart';
import '../epg/epg_matcher.dart';
import '../repositories/vod_models.dart' show splitPeople;
import '../text/normalize.dart';
import 'import_rows.dart';

/// Which source produced the rows; decides a few upsert rules.
enum ContentSource {
  /// Provider `added` / `last_modified` are authoritative.
  xtream,

  /// No provider dates: `added` is stamped when an item first appears in a
  /// reload and never changed afterwards.
  m3u,
}

/// Search-index row kinds (`search_index.kind`).
abstract final class SearchKinds {
  static const channel = 'channel';
  static const movie = 'movie';
  static const series = 'series';
  static const person = 'person';
}

/// Number of rows deleted by [ContentWriter.deleteRemoved].
typedef RemovedCounts = ({
  int categories,
  int channels,
  int movies,
  int series,
  int episodes,
});

final class ContentWriter {
  ContentWriter(
    this._db,
    this.playlistId, {
    required this.source,
    this.batchSize = 5000,
    this.throwIfCancelled,
  }) : assert(batchSize > 0 && batchSize <= 5000);

  final AppDatabase _db;
  final int playlistId;
  final ContentSource source;
  final int batchSize;

  /// Called before every write transaction until [deleteRemoved] (the
  /// commit point); the finishing steps after it are not cancellable, so a
  /// late cancel never leaves a half-built search index behind.
  final void Function()? throwIfCancelled;

  bool _committed = false;

  void _checkCancelled() {
    if (!_committed) throwIfCancelled?.call();
  }

  // ------------------------------------------------------------------ SQL

  static String _q(String column) => '"$column"';

  static String _upsertSql({
    required String table,
    required List<String> columns,
    required List<String> conflict,
    required List<String> updated,
    Map<String, String> custom = const {},
    bool hasRemoved = true,
  }) {
    final insertColumns = [...columns, if (hasRemoved) 'removed'];
    final values = [for (final _ in columns) '?', if (hasRemoved) '0'];
    final sets = <String>[
      for (final entry in custom.entries) '${_q(entry.key)} = ${entry.value}',
      for (final c in updated) '${_q(c)} = excluded.${_q(c)}',
      if (hasRemoved) '${_q('removed')} = 0',
    ];
    return 'INSERT INTO ${_q(table)} (${insertColumns.map(_q).join(', ')}) '
        'VALUES (${values.join(', ')}) '
        'ON CONFLICT (${conflict.map(_q).join(', ')}) DO UPDATE SET '
        '${sets.join(', ')}';
  }

  static const _categoryColumns = [
    'playlist_id',
    'kind',
    'provider_id',
    'name',
    'parent_id',
    'sort_index',
  ];

  static final String _categorySql = _upsertSql(
    table: 'categories',
    columns: _categoryColumns,
    conflict: const ['playlist_id', 'kind', 'provider_id'],
    updated: const ['name', 'parent_id', 'sort_index'],
  );

  static const _channelColumns = [
    'playlist_id',
    'provider_id',
    'num',
    'name',
    'display_name',
    'quality',
    'logo',
    'category_id',
    'epg_id',
    'archive_days',
    'catchup_type',
    'catchup_source',
    'stream_url',
    'direct_source',
    'headers_json',
    'unsupported',
    'added',
    'sort_index',
  ];

  String _channelSql() => _upsertSql(
    table: 'channels',
    columns: _channelColumns,
    conflict: const ['playlist_id', 'provider_id'],
    custom: {
      'matched_epg_id':
          'CASE WHEN "channels"."epg_id" IS NOT excluded."epg_id" '
          'OR "channels"."name" IS NOT excluded."name" THEN NULL '
          'ELSE "channels"."matched_epg_id" END',
      if (source == ContentSource.xtream)
        'added': 'COALESCE(excluded."added", "channels"."added")',
    },
    updated: const [
      'num',
      'name',
      'display_name',
      'quality',
      'logo',
      'category_id',
      'epg_id',
      'archive_days',
      'catchup_type',
      'catchup_source',
      'stream_url',
      'direct_source',
      'headers_json',
      'unsupported',
      'sort_index',
    ],
  );

  static const _movieColumns = [
    'playlist_id',
    'provider_id',
    'name',
    'category_id',
    'poster',
    'rating',
    'added',
    'container_ext',
    'tmdb_id',
    'year',
    'stream_url',
    'direct_source',
    'headers_json',
    'sort_index',
  ];

  String _movieSql() {
    final changed = source == ContentSource.xtream
        ? '("movies"."name" IS NOT excluded."name" '
              'OR "movies"."container_ext" IS NOT excluded."container_ext" '
              'OR (excluded."added" IS NOT NULL '
              'AND "movies"."added" IS NOT excluded."added"))'
        : '("movies"."name" IS NOT excluded."name")';
    return _upsertSql(
      table: 'movies',
      columns: _movieColumns,
      conflict: const ['playlist_id', 'provider_id'],
      custom: {
        'info_json':
            'CASE WHEN $changed THEN NULL ELSE "movies"."info_json" END',
        'info_fetched_at':
            'CASE WHEN $changed THEN NULL ELSE "movies"."info_fetched_at" END',
        if (source == ContentSource.xtream)
          'added': 'COALESCE(excluded."added", "movies"."added")',
      },
      updated: const [
        'name',
        'category_id',
        'poster',
        'rating',
        'container_ext',
        'tmdb_id',
        'year',
        'stream_url',
        'direct_source',
        'headers_json',
        'sort_index',
      ],
    );
  }

  static const _seriesColumns = [
    'playlist_id',
    'provider_id',
    'name',
    'category_id',
    'cover',
    'plot',
    'cast',
    'director',
    'genre',
    'release_date',
    'last_modified',
    'rating',
    'backdrops_json',
    'youtube_trailer',
    'tmdb_id',
    'year',
    'sort_index',
  ];

  static const String _seriesChanged =
      '("series"."name" IS NOT excluded."name" '
      'OR (excluded."last_modified" IS NOT NULL '
      'AND "series"."last_modified" IS NOT excluded."last_modified"))';

  static final String _seriesSql = _upsertSql(
    table: 'series',
    columns: _seriesColumns,
    conflict: const ['playlist_id', 'provider_id'],
    custom: const {
      'info_json':
          'CASE WHEN $_seriesChanged THEN NULL ELSE "series"."info_json" END',
      'info_fetched_at':
          'CASE WHEN $_seriesChanged THEN NULL '
          'ELSE "series"."info_fetched_at" END',
    },
    updated: const [
      'name',
      'category_id',
      'cover',
      'plot',
      'cast',
      'director',
      'genre',
      'release_date',
      'last_modified',
      'rating',
      'backdrops_json',
      'youtube_trailer',
      'tmdb_id',
      'year',
      'sort_index',
    ],
  );

  static final String _seasonSql = _upsertSql(
    table: 'seasons',
    columns: const [
      'playlist_id',
      'series_id',
      'season_number',
      'name',
      'cover',
      'air_date',
      'episode_count',
      'overview',
    ],
    conflict: const ['playlist_id', 'series_id', 'season_number'],
    updated: const ['name', 'cover', 'air_date', 'episode_count', 'overview'],
    hasRemoved: false,
  );

  static final String _episodeSql = _upsertSql(
    table: 'episodes',
    columns: const [
      'playlist_id',
      'provider_id',
      'series_id',
      'season',
      'episode_num',
      'title',
      'container_ext',
      'plot',
      'duration_secs',
      'release_date',
      'image',
      'rating',
      'stream_url',
      'direct_source',
      'added',
    ],
    conflict: const ['playlist_id', 'provider_id'],
    updated: const [
      'series_id',
      'season',
      'episode_num',
      'title',
      'container_ext',
      'plot',
      'duration_secs',
      'release_date',
      'image',
      'rating',
      'stream_url',
      'direct_source',
    ],
    hasRemoved: false,
  );

  Object? _date(DateTime? value) =>
      value == null ? null : _db.typeMapping.mapToSqlVariable(value);

  // --------------------------------------------------------------- writes

  /// Marks the [kind] categories removed, then upserts [rows].
  Future<void> upsertCategories(
    SectionKind kind,
    List<CategoryData> rows,
  ) async {
    _checkCancelled();
    await _db.customStatement(
      'UPDATE "categories" SET "removed" = 1 '
      'WHERE "playlist_id" = ? AND "kind" = ?',
      [playlistId, kind.index],
    );
    await _writeBatches(
      _categorySql,
      rows,
      (c) => [
        playlistId,
        c.kind.index,
        c.providerId,
        c.name,
        c.parentId,
        c.sortIndex,
      ],
    );
  }

  /// Marks every channel removed, then upserts [rows].
  Future<void> upsertChannels(
    List<ChannelData> rows, {
    void Function(int written)? onProgress,
  }) async {
    await _markItemsRemoved('channels');
    final sql = _channelSql();
    await _writeBatches(
      sql,
      rows,
      (c) => [
        playlistId,
        c.providerId,
        c.num,
        c.name,
        c.displayName,
        c.quality,
        c.logo,
        c.categoryId,
        c.epgId,
        c.archiveDays,
        c.catchupType,
        c.catchupSource,
        c.streamUrl,
        c.directSource,
        c.headersJson,
        c.unsupported ? 1 : 0,
        _date(c.added),
        c.sortIndex,
      ],
      onProgress: onProgress,
    );
  }

  /// Marks every movie removed, then upserts [rows].
  Future<void> upsertMovies(
    List<MovieData> rows, {
    void Function(int written)? onProgress,
  }) async {
    await _markItemsRemoved('movies');
    await _writeBatches(
      _movieSql(),
      rows,
      (m) => [
        playlistId,
        m.providerId,
        m.name,
        m.categoryId,
        m.poster,
        m.rating,
        _date(m.added),
        m.containerExt,
        m.tmdbId,
        m.year,
        m.streamUrl,
        m.directSource,
        m.headersJson,
        m.sortIndex,
      ],
      onProgress: onProgress,
    );
  }

  /// Marks every series removed, then upserts [rows].
  Future<void> upsertSeries(
    List<SeriesData> rows, {
    void Function(int written)? onProgress,
  }) async {
    await _markItemsRemoved('series');
    await _writeBatches(
      _seriesSql,
      rows,
      (s) => [
        playlistId,
        s.providerId,
        s.name,
        s.categoryId,
        s.cover,
        s.plot,
        s.cast,
        s.director,
        s.genre,
        s.releaseDate,
        _date(s.lastModified),
        s.rating,
        s.backdropsJson,
        s.youtubeTrailer,
        s.tmdbId,
        s.year,
        s.sortIndex,
      ],
      onProgress: onProgress,
    );
  }

  /// Upserts seasons and episodes (M3U). Stale ones are removed by
  /// [deleteStaleEpisodes] once the import succeeded.
  Future<void> upsertSeasonsAndEpisodes(
    List<SeasonData> seasons,
    List<EpisodeData> episodes,
  ) async {
    await _writeBatches(
      _seasonSql,
      seasons,
      (s) => [
        playlistId,
        s.seriesId,
        s.seasonNumber,
        s.name,
        s.cover,
        s.airDate,
        s.episodeCount,
        s.overview,
      ],
    );
    await _writeBatches(
      _episodeSql,
      episodes,
      (e) => [
        playlistId,
        e.providerId,
        e.seriesId,
        e.season,
        e.episodeNum,
        e.title,
        e.containerExt,
        e.plot,
        e.durationSecs,
        e.releaseDate,
        e.image,
        e.rating,
        e.streamUrl,
        e.directSource,
        _date(e.added),
      ],
    );
  }

  Future<void> _markItemsRemoved(String table) async {
    _checkCancelled();
    await _db.customStatement(
      'UPDATE ${_q(table)} SET "removed" = 1 WHERE "playlist_id" = ?',
      [playlistId],
    );
  }

  Future<void> _writeBatches<T>(
    String sql,
    List<T> rows,
    List<Object?> Function(T row) args, {
    void Function(int written)? onProgress,
  }) async {
    for (var start = 0; start < rows.length; start += batchSize) {
      _checkCancelled();
      final end = math.min(start + batchSize, rows.length);
      await _db.batch((b) {
        for (var i = start; i < end; i++) {
          b.customStatement(sql, args(rows[i]));
        }
      });
      onProgress?.call(end);
    }
  }

  // ------------------------------------------------------------ finishing

  /// Deletes every row still marked removed (and the seasons / episodes of
  /// removed series). Call only after the whole content import succeeded:
  /// this is the commit point (see [throwIfCancelled]).
  Future<RemovedCounts> deleteRemoved() {
    _committed = true;
    return _deleteRemoved();
  }

  Future<RemovedCounts> _deleteRemoved() => _db.transaction(() async {
    Future<int> run(String sql, int args) => _db.customUpdate(
      sql,
      variables: [for (var i = 0; i < args; i++) Variable.withInt(playlistId)],
    );
    const removedSeries =
        '(SELECT "provider_id" FROM "series" '
        'WHERE "playlist_id" = ? AND "removed" = 1)';
    final episodes = await run(
      'DELETE FROM "episodes" WHERE "playlist_id" = ? '
      'AND "series_id" IN $removedSeries',
      2,
    );
    await run(
      'DELETE FROM "seasons" WHERE "playlist_id" = ? '
      'AND "series_id" IN $removedSeries',
      2,
    );
    final channels = await run(
      'DELETE FROM "channels" WHERE "playlist_id" = ? AND "removed" = 1',
      1,
    );
    final movies = await run(
      'DELETE FROM "movies" WHERE "playlist_id" = ? AND "removed" = 1',
      1,
    );
    final series = await run(
      'DELETE FROM "series" WHERE "playlist_id" = ? AND "removed" = 1',
      1,
    );
    final categories = await run(
      'DELETE FROM "categories" WHERE "playlist_id" = ? AND "removed" = 1',
      1,
    );
    return (
      categories: categories,
      channels: channels,
      movies: movies,
      series: series,
      episodes: episodes,
    );
  });

  /// Clears the removed marks after a failed or cancelled import.
  Future<void> revertRemoved() => _db.transaction(() async {
    for (final table in const ['categories', 'channels', 'movies', 'series']) {
      await _db.customStatement(
        'UPDATE ${_q(table)} SET "removed" = 0 '
        'WHERE "playlist_id" = ? AND "removed" = 1',
        [playlistId],
      );
    }
  });

  /// Deletes seasons and episodes that are not in [episodeIds] /
  /// [seasonKeys] (`"<seriesId>/<season>"`). M3U only: there every episode
  /// comes with the playlist.
  Future<int> deleteStaleEpisodes(
    Set<String> episodeIds,
    Set<String> seasonKeys,
  ) async {
    final staleEpisodes = <int>[];
    await forEachPlaylistRow(
      _db,
      table: 'episodes',
      playlistId: playlistId,
      columns: '"provider_id"',
      onRow: (row) {
        if (!episodeIds.contains(row.read<String>('provider_id'))) {
          staleEpisodes.add(row.read<int>('id'));
        }
      },
    );
    final staleSeasons = <int>[];
    await forEachPlaylistRow(
      _db,
      table: 'seasons',
      playlistId: playlistId,
      columns: '"series_id", "season_number"',
      onRow: (row) {
        final key =
            '${row.read<String>('series_id')}/${row.read<int>('season_number')}';
        if (!seasonKeys.contains(key)) staleSeasons.add(row.read<int>('id'));
      },
    );
    await _writeBatches(
      'DELETE FROM "episodes" WHERE "id" = ?',
      staleEpisodes,
      (id) => [id],
    );
    await _writeBatches(
      'DELETE FROM "seasons" WHERE "id" = ?',
      staleSeasons,
      (id) => [id],
    );
    return staleEpisodes.length;
  }

  /// Stores the item counts and `lastReloadAt`.
  Future<({int live, int movies, int series})> updateCounts(
    DateTime now,
  ) async {
    Future<int> count(String table) async {
      final row = await _db
          .customSelect(
            'SELECT COUNT(*) AS "n" FROM ${_q(table)} WHERE "playlist_id" = ?',
            variables: [Variable.withInt(playlistId)],
          )
          .getSingle();
      return row.read<int>('n');
    }

    final live = await count('channels');
    final movies = await count('movies');
    final series = await count('series');
    await (_db.update(
      _db.playlists,
    )..where((p) => p.id.equals(playlistId))).write(
      PlaylistsCompanion(
        liveCount: Value(live),
        movieCount: Value(movies),
        seriesCount: Value(series),
        lastReloadAt: Value(now),
      ),
    );
    return (live: live, movies: movies, series: series);
  }

  /// Fills `matchedEpgId` of channels that have none, from the stored
  /// `epg_channels` (used after a content import; the EPG import re-matches
  /// every channel with the full XMLTV display names). Returns the number of
  /// channels matched.
  Future<int> matchUnmatchedChannels() async {
    final epg = await _db
        .customSelect(
          'SELECT "epg_id", "display_name" FROM "epg_channels" '
          'WHERE "playlist_id" = ?',
          variables: [Variable.withInt(playlistId)],
        )
        .get();
    if (epg.isEmpty) return 0;
    final matcher = EpgMatcher([
      for (final row in epg)
        EpgChannelRef(row.read<String>('epg_id'), [
          row.read<String>('display_name'),
        ]),
    ]);
    final channels = await _db
        .customSelect(
          'SELECT "id", "name", "epg_id" FROM "channels" '
          'WHERE "playlist_id" = ? AND "matched_epg_id" IS NULL',
          variables: [Variable.withInt(playlistId)],
        )
        .get();
    final updates = <List<Object?>>[];
    for (var i = 0; i < channels.length; i++) {
      if (i > 0 && i % 2000 == 0) await Future<void>.delayed(Duration.zero);
      final row = channels[i];
      final id = matcher.match(
        tvgId: row.readNullable<String>('epg_id'),
        name: row.read<String>('name'),
      );
      if (id != null) updates.add([id, row.read<int>('id')]);
    }
    await _writeBatches(
      'UPDATE "channels" SET "matched_epg_id" = ? WHERE "id" = ?',
      updates,
      (u) => u,
    );
    return updates.length;
  }

  // --------------------------------------------------------- search index

  /// Rebuilds the playlist's `search_index` rows (ARCHITECTURE 2.11):
  /// channels (display name), movies, series and people (series `cast` and
  /// cached movie info `actors` / `cast`; `ref_id` = the person's name).
  ///
  /// `playlist_id` is stored as an INTEGER: compare it with an integer
  /// parameter.
  Future<int> rebuildSearchIndex() async {
    final titles = <String>[];
    final kinds = <String>[];
    final refs = <String>[];
    void add(String title, String kind, String ref) {
      titles.add(title);
      kinds.add(kind);
      refs.add(ref);
    }

    final people = <String>[];
    await forEachPlaylistRow(
      _db,
      table: 'channels',
      playlistId: playlistId,
      columns: '"provider_id", "display_name"',
      onRow: (row) => add(
        row.read<String>('display_name'),
        SearchKinds.channel,
        row.read<String>('provider_id'),
      ),
    );
    await forEachPlaylistRow(
      _db,
      table: 'movies',
      playlistId: playlistId,
      columns: '"provider_id", "name", "info_json"',
      onRow: (row) {
        add(
          row.read<String>('name'),
          SearchKinds.movie,
          row.read<String>('provider_id'),
        );
        final info = row.readNullable<String>('info_json');
        if (info != null) people.addAll(peopleFromInfoJson(info));
      },
    );
    await forEachPlaylistRow(
      _db,
      table: 'series',
      playlistId: playlistId,
      columns: '"provider_id", "name", "cast"',
      onRow: (row) {
        add(
          row.read<String>('name'),
          SearchKinds.series,
          row.read<String>('provider_id'),
        );
        people.addAll(splitPeople(row.readNullable<String>('cast')));
      },
    );

    // Normalization runs off this isolate for big catalogs.
    final itemCount = titles.length;
    final (normalized, personNames, personKeys) = await _normalize(
      titles,
      people,
    );
    for (var i = 0; i < personNames.length; i++) {
      add(personNames[i], SearchKinds.person, personNames[i]);
      normalized.add(personKeys[i]);
    }

    const insert =
        'INSERT INTO "search_index" '
        '("normalized", "title", "kind", "ref_id", "playlist_id") '
        'VALUES (?, ?, ?, ?, ?)';
    var written = 0;
    var first = true;
    for (var start = 0; first || start < titles.length; start += batchSize) {
      _checkCancelled();
      final end = math.min(start + batchSize, titles.length);
      final deleteFirst = first;
      first = false;
      await _db.batch((b) {
        if (deleteFirst) {
          b.customStatement(
            'DELETE FROM "search_index" WHERE "playlist_id" = ?',
            [playlistId],
          );
        }
        for (var i = start; i < end; i++) {
          final n = normalized[i];
          if (n.isEmpty) continue;
          b.customStatement(insert, [
            n,
            titles[i],
            kinds[i],
            refs[i],
            playlistId,
          ]);
          written++;
        }
      });
    }
    assert(written <= itemCount + personNames.length);
    return written;
  }

  /// Normalized titles, plus deduplicated people (first spelling wins) and
  /// their normalized keys.
  static Future<(List<String>, List<String>, List<String>)> _normalize(
    List<String> titles,
    List<String> people,
  ) {
    (List<String>, List<String>, List<String>) work() {
      final normalized = [for (final t in titles) normalizeForSearch(t)];
      final names = <String>[];
      final keys = <String>[];
      final seen = <String>{};
      for (final person in people) {
        final key = normalizeForSearch(person);
        if (key.isEmpty || !seen.add(key)) continue;
        names.add(person);
        keys.add(key);
      }
      return (normalized, names, keys);
    }

    if (titles.length + people.length < 4000) return Future.value(work());
    return Isolate.run(work, debugName: 'carina-search-normalize');
  }
}

/// People of a cached movie info JSON (`get_vod_info` response or its
/// `info` object, as `VodRepository` stores it): `actors`, else `cast`, as
/// a comma- or semicolon-separated string or a list of names. Never throws.
///
/// Names are split with the repositories' `splitPeople`, so `person` rows
/// match what `SearchRepository` looks for.
List<String> peopleFromInfoJson(String json) {
  Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    return const [];
  }
  if (decoded is! Map) return const [];
  final info = decoded['info'] is Map ? decoded['info'] as Map : decoded;
  for (final key in const ['actors', 'cast']) {
    final value = info[key];
    if (value is String && value.trim().isNotEmpty) return splitPeople(value);
    if (value is List) {
      final names = <String>[];
      for (final item in value) {
        final name = item is Map ? item['name'] : item;
        if (name is String) {
          for (final n in splitPeople(name)) {
            if (!names.contains(n)) names.add(n);
          }
        }
      }
      if (names.isNotEmpty) return names;
    }
  }
  return const [];
}

/// Reads `SELECT "id", <columns> FROM <table> WHERE "playlist_id" = ?` in
/// pages of [pageSize] rows (keyset on `id`), yielding to the event loop
/// between pages so big result sets never block the calling isolate.
Future<void> forEachPlaylistRow(
  AppDatabase db, {
  required String table,
  required int playlistId,
  required String columns,
  required void Function(QueryRow row) onRow,
  int pageSize = 10000,
}) async {
  var lastId = 0;
  while (true) {
    final rows = await db
        .customSelect(
          'SELECT "id", $columns FROM "$table" '
          'WHERE "playlist_id" = ? AND "id" > ? ORDER BY "id" LIMIT ?',
          variables: [
            Variable.withInt(playlistId),
            Variable.withInt(lastId),
            Variable.withInt(pageSize),
          ],
        )
        .get();
    for (final row in rows) {
      onRow(row);
    }
    if (rows.length < pageSize) return;
    lastId = rows.last.read<int>('id');
    await Future<void>.delayed(Duration.zero);
  }
}
