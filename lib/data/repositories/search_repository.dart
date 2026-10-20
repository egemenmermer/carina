import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_paths.dart';
import '../db/database.dart';
import '../text/normalize.dart';
import 'vod_models.dart';
import 'vod_repository.dart' show decodeVodInfo, watchExcludeLocked;

/// Search page filter chips.
enum SearchFilter {
  all,
  movies,
  shows,

  /// Live channels and programmes.
  live,
  people,
}

/// A live channel in search results (or under a programme).
@immutable
class ChannelHit {
  const ChannelHit({
    required this.providerId,
    required this.name,
    this.logo,
    this.num,
    this.quality,
    this.categoryId,
    this.epgChannelId,
    this.archiveDays = 0,
    this.locked = false,
    this.now,
  });

  final String providerId;

  /// Display name (quality tokens stripped).
  final String name;
  final String? logo;
  final int? num;

  /// Comma-joined badges, e.g. `FHD` or `HD,H265`.
  final String? quality;
  final String? categoryId;

  /// Effective EPG id: custom, else matched, else the provider tvg-id.
  final String? epgChannelId;
  final int archiveDays;
  final bool locked;

  /// The programme on air right now, when the EPG has one.
  final ProgrammeHit? now;

  @override
  String toString() => 'ChannelHit($providerId "$name")';
}

/// A current or upcoming programme matching the query, with the channels
/// it airs on.
@immutable
class ProgrammeHit {
  const ProgrammeHit({
    required this.id,
    required this.epgChannelId,
    required this.start,
    required this.stop,
    required this.title,
    this.subTitle,
    this.description,
    this.category,
    this.episodeNum,
    this.icon,
    this.channels = const [],
  });

  final int id;
  final String epgChannelId;

  /// UTC.
  final DateTime start;

  /// UTC.
  final DateTime stop;
  final String title;
  final String? subTitle;
  final String? description;
  final String? category;
  final String? episodeNum;
  final String? icon;

  /// Channels whose effective EPG id is [epgChannelId] (empty for the
  /// [ChannelHit.now] programme of a channel).
  final List<ChannelHit> channels;

  bool isOnAirAt(DateTime now) => !now.isBefore(start) && now.isBefore(stop);

  @override
  String toString() => 'ProgrammeHit($id "$title" $start)';
}

/// A cast member found in metadata ("Search by actor").
@immutable
class PersonHit {
  const PersonHit({required this.name, required this.displayName});

  /// The name as stored in the cast data (key for [SearchRepository.titlesByPerson]).
  final String name;
  final String displayName;

  @override
  bool operator ==(Object other) =>
      other is PersonHit &&
      other.name == name &&
      other.displayName == displayName;

  @override
  int get hashCode => Object.hash(name, displayName);

  @override
  String toString() => 'PersonHit("$displayName")';
}

/// Everything one query found, by section.
@immutable
class SearchResults {
  const SearchResults({
    required this.query,
    required this.normalizedQuery,
    required this.filter,
    this.movies = const [],
    this.series = const [],
    this.channels = const [],
    this.programmes = const [],
    this.people = const [],
    this.elapsed = Duration.zero,
  });

  final String query;
  final String normalizedQuery;
  final SearchFilter filter;
  final List<VodItem> movies;
  final List<VodItem> series;
  final List<ChannelHit> channels;
  final List<ProgrammeHit> programmes;
  final List<PersonHit> people;

  /// Time spent in [SearchRepository.search].
  final Duration elapsed;

  bool get isEmpty =>
      movies.isEmpty &&
      series.isEmpty &&
      channels.isEmpty &&
      programmes.isEmpty &&
      people.isEmpty;
}

/// Library titles with a cast member.
@immutable
class PersonTitles {
  const PersonTitles({
    required this.name,
    this.movies = const [],
    this.series = const [],
  });

  final String name;
  final List<VodItem> movies;
  final List<VodItem> series;

  bool get isEmpty => movies.isEmpty && series.isEmpty;
}

/// Search over `search_index` / `programme_search`.
///
/// The query is normalized like the index (`normalizeForSearch`: Turkish
/// lowercase, diacritics folded, quality tokens such as FHD / HD dropped)
/// and every term is a prefix (`ftsQuery`). Within a section, an exact
/// title comes first, then titles starting with the query, then the rest by
/// bm25 rank and length. Hidden items, items of hidden categories and
/// programmes that already ended are left out.
class SearchRepository {
  SearchRepository({required this._db, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;
  final NameKeys _keys = NameKeys(maxEntries: 20000);

  static const _effectiveEpg =
      "COALESCE(NULLIF(c.custom_epg_id, ''), NULLIF(c.matched_epg_id, ''), "
      "NULLIF(c.epg_id, ''))";

  /// Searches [query] in [filter]'s sections, at most [limitPerSection]
  /// results each. With [excludeLocked] (parental mode `hide`), locked
  /// channels and items of locked categories are left out too.
  Future<SearchResults> search(
    int playlistId,
    String query, {
    SearchFilter filter = SearchFilter.all,
    int limitPerSection = 30,
    bool excludeLocked = false,
  }) async {
    final watch = Stopwatch()..start();
    final normalized = normalizeForSearch(query);
    final match = ftsQuery(query);
    if (match.isEmpty || limitPerSection <= 0) {
      return SearchResults(
        query: query,
        normalizedQuery: normalized,
        filter: filter,
      );
    }
    final limit = limitPerSection;
    final kinds = switch (filter) {
      SearchFilter.all => const ['movie', 'series', 'channel', 'person'],
      SearchFilter.movies => const ['movie'],
      SearchFilter.shows => const ['series'],
      SearchFilter.live => const ['channel'],
      SearchFilter.people => const ['person'],
    };
    // A single character matches a large part of the library; its best
    // results all start with it anyway, so only titles whose first word
    // starts with it are considered (FTS5 initial-token query). Very short
    // queries are ranked by the exact/prefix tier and length only: bm25 adds
    // nothing there but costs time on thousands of matches.
    final initialOnly = normalized.length == 1;
    final effectiveMatch = initialOnly ? '^$match' : match;
    final hits = await _indexHits(
      playlistId,
      effectiveMatch,
      normalized,
      kinds,
      limit,
      rankByBm25: normalized.length >= 3,
    );
    final now = _clock();
    final movies = await _vodHits(
      playlistId,
      SectionKind.movie,
      hits['movie'] ?? const [],
      limit,
      now,
      excludeLocked,
    );
    final series = await _vodHits(
      playlistId,
      SectionKind.series,
      hits['series'] ?? const [],
      limit,
      now,
      excludeLocked,
    );
    final channels = await _channelHits(
      playlistId,
      hits['channel'] ?? const [],
      limit,
      now,
      excludeLocked,
    );
    final people = _personHits(hits['person'] ?? const [], limit);
    final programmes =
        (filter == SearchFilter.all || filter == SearchFilter.live)
        ? await _programmeHits(
            playlistId,
            effectiveMatch,
            normalized,
            limit,
            now,
            excludeLocked,
          )
        : const <ProgrammeHit>[];
    watch.stop();
    return SearchResults(
      query: query,
      normalizedQuery: normalized,
      filter: filter,
      movies: movies,
      series: series,
      channels: channels,
      programmes: programmes,
      people: people,
      elapsed: watch.elapsed,
    );
  }

  /// Movies and series whose cast contains [name] (series `cast` column and
  /// cached movie info), newest first. [name] is a cast name as stored
  /// (e.g. [PersonHit.name]); a cast entry matches when it is the same name
  /// ignoring case and diacritics (`Ekin Koç` ≠ `Ekin Koçak`).
  Future<PersonTitles> titlesByPerson(
    int playlistId,
    String name, {
    bool excludeLocked = false,
  }) async {
    final key = normalizeForSearch(name);
    if (key.isEmpty) return PersonTitles(name: name);
    final raw = '%${_escapeLike(name.trim())}%';
    final folded = '%${_escapeLike(key)}%';
    final now = _clock();

    final seriesRows = await _db
        .customSelect(
          'SELECT ${VodSql.seriesColumns}, s.cast AS cast_text '
          '${VodSql.from(SectionKind.series)} '
          'WHERE s.playlist_id = ? AND s.hidden = 0 AND '
          "(s.cast LIKE ? ESCAPE '\\' OR s.cast LIKE ? ESCAPE '\\') AND "
          '${VodSql.notInHiddenCategory(SectionKind.series, includeLocked: excludeLocked)}',
          variables: [
            Variable.withInt(playlistId),
            Variable.withString(raw),
            Variable.withString(folded),
          ],
          readsFrom: VodSql.readsFrom(_db, SectionKind.series),
        )
        .get();
    final series = [
      for (final r in seriesRows)
        if (_hasPerson(r.readNullable<String>('cast_text'), key))
          readVodItem(r, SectionKind.series, now),
    ];

    final movieRows = await _db
        .customSelect(
          'SELECT ${VodSql.movieColumns}, m.info_json AS info '
          '${VodSql.from(SectionKind.movie)} '
          'WHERE m.playlist_id = ? AND m.hidden = 0 AND '
          'm.info_json IS NOT NULL AND '
          "(m.info_json LIKE ? ESCAPE '\\' OR m.info_json LIKE ? ESCAPE '\\') "
          'AND ${VodSql.notInHiddenCategory(SectionKind.movie, includeLocked: excludeLocked)}',
          variables: [
            Variable.withInt(playlistId),
            Variable.withString(raw),
            Variable.withString(folded),
          ],
          readsFrom: VodSql.readsFrom(_db, SectionKind.movie),
        )
        .get();
    final movies = <VodItem>[];
    for (final r in movieRows) {
      final item = readVodItem(r, SectionKind.movie, now);
      final info = decodeVodInfo(
        r.readNullable<String>('info'),
        item.providerId,
      );
      if (_hasPerson(info?.castText, key)) movies.add(item);
    }
    return PersonTitles(
      name: name,
      movies: List.unmodifiable(_byYear(movies)),
      series: List.unmodifiable(_byYear(series)),
    );
  }

  // -------------------------------------------------------------------------
  // Internals
  // -------------------------------------------------------------------------

  /// Best index rows per kind (`kind` → rows in rank order).
  Future<Map<String, List<({String refId, String title})>>> _indexHits(
    int playlistId,
    String match,
    String normalized,
    List<String> kinds,
    int limit, {
    bool rankByBm25 = true,
  }) async {
    final rows = await _db
        .customSelect(
          '''
SELECT kind, ref_id, title FROM (
  SELECT kind, ref_id, title,
    ROW_NUMBER() OVER (
      PARTITION BY kind
      ORDER BY
        CASE WHEN normalized = ?1 THEN 0
             WHEN substr(normalized, 1, ?2) = ?1 THEN 1
             ELSE 2 END,
        ${rankByBm25 ? 'bm25(search_index),' : ''}
        length(normalized),
        title
    ) AS rn
  FROM search_index
  WHERE search_index MATCH ?3
    AND CAST(playlist_id AS TEXT) = ?4
    AND kind IN (${[for (var i = 0; i < kinds.length; i++) '?${6 + i}'].join(', ')})
)
WHERE rn <= ?5
ORDER BY kind, rn''',
          variables: [
            Variable.withString(normalized),
            Variable.withInt(normalized.length),
            Variable.withString(match),
            Variable.withString('$playlistId'),
            // Extra rows absorb hidden items and duplicate people.
            Variable.withInt(limit * 2),
            for (final k in kinds) Variable.withString(k),
          ],
          readsFrom: {_db.searchIndex},
        )
        .get();
    final out = <String, List<({String refId, String title})>>{};
    for (final r in rows) {
      final kind = '${r.data['kind']}';
      (out[kind] ??= []).add((
        refId: '${r.data['ref_id']}',
        title: '${r.data['title']}',
      ));
    }
    return out;
  }

  Future<List<VodItem>> _vodHits(
    int playlistId,
    SectionKind kind,
    List<({String refId, String title})> hits,
    int limit,
    DateTime now,
    bool excludeLocked,
  ) async {
    if (hits.isEmpty) return const [];
    final a = VodSql.alias(kind);
    final ids = {for (final h in hits) h.refId}.toList();
    final rows = await _db
        .customSelect(
          'SELECT ${VodSql.columns(kind)} ${VodSql.from(kind)} '
          'WHERE $a.playlist_id = ? AND $a.hidden = 0 AND $a.provider_id IN '
          '(${VodSql.placeholders(ids.length)}) AND '
          '${VodSql.notInHiddenCategory(kind, includeLocked: excludeLocked)}',
          variables: [
            Variable.withInt(playlistId),
            for (final id in ids) Variable.withString(id),
          ],
          readsFrom: VodSql.readsFrom(_db, kind),
        )
        .get();
    final byId = {
      for (final r in rows)
        r.read<String>('provider_id'): readVodItem(r, kind, now),
    };
    return List.unmodifiable([for (final id in ids) ?byId[id]].take(limit));
  }

  Future<List<ChannelHit>> _channelHits(
    int playlistId,
    List<({String refId, String title})> hits,
    int limit,
    DateTime now,
    bool excludeLocked,
  ) async {
    if (hits.isEmpty) return const [];
    final ids = {for (final h in hits) h.refId}.toList();
    final rows = await _db
        .customSelect(
          'SELECT ${_channelColumns()} FROM channels c '
          'WHERE c.playlist_id = ? AND c.hidden = 0 AND c.provider_id IN '
          '(${VodSql.placeholders(ids.length)}) AND '
          '${_visibleChannel(excludeLocked)}',
          variables: [
            Variable.withInt(playlistId),
            for (final id in ids) Variable.withString(id),
          ],
          readsFrom: {_db.channels, _db.categories},
        )
        .get();
    final byId = {
      for (final r in rows) r.read<String>('provider_id'): _readChannel(r),
    };
    final ordered = [for (final id in ids) ?byId[id]].take(limit).toList();
    final epgIds = {for (final c in ordered) ?c.epgChannelId};
    if (epgIds.isEmpty) return List.unmodifiable(ordered);
    final nowMs = now.millisecondsSinceEpoch;
    final current = await _db
        .customSelect(
          'SELECT ${_programmeColumns()} FROM programmes p '
          'WHERE p.playlist_id = ? AND p.epg_channel_id IN '
          '(${VodSql.placeholders(epgIds.length)}) '
          // `+p.stop` keeps the planner on the (channel, start) index
          // instead of scanning every future programme via the stop index.
          'AND p.start <= ? AND +p.stop > ? ORDER BY p.start',
          variables: [
            Variable.withInt(playlistId),
            for (final id in epgIds) Variable.withString(id),
            Variable.withInt(nowMs),
            Variable.withInt(nowMs),
          ],
          readsFrom: {_db.programmes},
        )
        .get();
    final onAir = <String, ProgrammeHit>{};
    for (final r in current) {
      final p = _readProgramme(r, const []);
      onAir.putIfAbsent(p.epgChannelId, () => p);
    }
    return List.unmodifiable([
      for (final c in ordered)
        c.epgChannelId == null || onAir[c.epgChannelId] == null
            ? c
            : ChannelHit(
                providerId: c.providerId,
                name: c.name,
                logo: c.logo,
                num: c.num,
                quality: c.quality,
                categoryId: c.categoryId,
                epgChannelId: c.epgChannelId,
                archiveDays: c.archiveDays,
                locked: c.locked,
                now: onAir[c.epgChannelId],
              ),
    ]);
  }

  List<PersonHit> _personHits(
    List<({String refId, String title})> hits,
    int limit,
  ) {
    final seen = <String>{};
    final out = <PersonHit>[];
    for (final h in hits) {
      final key = normalizeForSearch(h.refId);
      if (!seen.add(key.isEmpty ? h.refId : key)) continue;
      out.add(PersonHit(name: h.refId, displayName: h.title));
      if (out.length == limit) break;
    }
    return List.unmodifiable(out);
  }

  Future<List<ProgrammeHit>> _programmeHits(
    int playlistId,
    String match,
    String normalized,
    int limit,
    DateTime now,
    bool excludeLocked,
  ) async {
    final nowMs = now.millisecondsSinceEpoch;
    final rows = await _db
        .customSelect(
          '''
SELECT ${_programmeColumns()}
FROM programme_search ps
CROSS JOIN programmes p ON p.id = CAST(ps.programme_id AS INTEGER)
WHERE programme_search MATCH ?1
  AND p.playlist_id = ?2
  AND p.stop > ?3
ORDER BY (p.start <= ?3) DESC, p.start,
  CASE WHEN ps.normalized = ?4 THEN 0
       WHEN substr(ps.normalized, 1, ?5) = ?4 THEN 1 ELSE 2 END,
  p.id
LIMIT ?6''',
          variables: [
            Variable.withString(match),
            Variable.withInt(playlistId),
            Variable.withInt(nowMs),
            Variable.withString(normalized),
            Variable.withInt(normalized.length),
            Variable.withInt(limit * 3),
          ],
          readsFrom: {_db.programmeSearch, _db.programmes},
        )
        .get();
    if (rows.isEmpty) return const [];
    final epgIds = {for (final r in rows) r.read<String>('epg_channel_id')};
    final channelRows = await _db
        .customSelect(
          'SELECT ${_channelColumns()} FROM channels c '
          'WHERE c.playlist_id = ? AND c.hidden = 0 AND $_effectiveEpg IN '
          '(${VodSql.placeholders(epgIds.length)}) AND '
          '${_visibleChannel(excludeLocked)} '
          'ORDER BY c.num IS NULL, c.num, c.sort_index, c.id',
          variables: [
            Variable.withInt(playlistId),
            for (final id in epgIds) Variable.withString(id),
          ],
          readsFrom: {_db.channels, _db.categories},
        )
        .get();
    final channelsByEpg = <String, List<ChannelHit>>{};
    for (final r in channelRows) {
      final c = _readChannel(r);
      (channelsByEpg[c.epgChannelId!] ??= []).add(c);
    }
    final out = <ProgrammeHit>[];
    for (final r in rows) {
      final channels = channelsByEpg[r.read<String>('epg_channel_id')];
      if (channels == null) continue;
      out.add(_readProgramme(r, List.unmodifiable(channels)));
      if (out.length == limit) break;
    }
    return List.unmodifiable(out);
  }

  static String _channelColumns() =>
      'c.provider_id AS provider_id, c.display_name AS display_name, '
      'c.logo AS logo, c.num AS num, c.quality AS quality, '
      'c.category_id AS category_id, c.archive_days AS archive_days, '
      'c.locked AS locked, $_effectiveEpg AS epg';

  /// Channel `c` is in no hidden category; with [excludeLocked] neither it
  /// nor its category is locked.
  static String _visibleChannel(bool excludeLocked) =>
      '${excludeLocked ? 'c.locked = 0 AND ' : ''}'
      'NOT EXISTS (SELECT 1 FROM categories hc '
      'WHERE hc.playlist_id = c.playlist_id '
      'AND hc.kind = ${SectionKind.live.index} '
      'AND hc.provider_id = c.category_id '
      'AND (hc.hidden = 1${excludeLocked ? ' OR hc.locked = 1' : ''}))';

  static String _programmeColumns() =>
      'p.id AS id, p.epg_channel_id AS epg_channel_id, p.start AS start, '
      'p.stop AS stop, p.title AS title, p.sub_title AS sub_title, '
      'p.description AS description, p.category AS category, '
      'p.episode_num AS episode_num, p.icon AS icon';

  static ChannelHit _readChannel(QueryRow r) => ChannelHit(
    providerId: r.read<String>('provider_id'),
    name: r.read<String>('display_name'),
    logo: r.readNullable<String>('logo'),
    num: r.readNullable<int>('num'),
    quality: r.readNullable<String>('quality'),
    categoryId: r.readNullable<String>('category_id'),
    epgChannelId: r.readNullable<String>('epg'),
    archiveDays: r.read<int>('archive_days'),
    locked: r.read<bool>('locked'),
  );

  static ProgrammeHit _readProgramme(QueryRow r, List<ChannelHit> channels) =>
      ProgrammeHit(
        id: r.read<int>('id'),
        epgChannelId: r.read<String>('epg_channel_id'),
        start: DateTime.fromMillisecondsSinceEpoch(
          r.read<int>('start'),
          isUtc: true,
        ),
        stop: DateTime.fromMillisecondsSinceEpoch(
          r.read<int>('stop'),
          isUtc: true,
        ),
        title: r.read<String>('title'),
        subTitle: r.readNullable<String>('sub_title'),
        description: r.readNullable<String>('description'),
        category: r.readNullable<String>('category'),
        episodeNum: r.readNullable<String>('episode_num'),
        icon: r.readNullable<String>('icon'),
        channels: channels,
      );

  static bool _hasPerson(String? castText, String key) =>
      splitPeople(castText).any((p) => normalizeForSearch(p) == key);

  static String _escapeLike(String s) =>
      s.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');

  /// Newest year first (unknown years last), then by name.
  List<VodItem> _byYear(List<VodItem> items) {
    final byName = _keys.sort(items, (i) => i.name);
    final indexed = [for (var i = 0; i < byName.length; i++) (i, byName[i])];
    indexed.sort((a, b) {
      final x = a.$2.year;
      final y = b.$2.year;
      if (x != null && y != null && x != y) return y.compareTo(x);
      if (x == null && y != null) return 1;
      if (x != null && y == null) return -1;
      return a.$1.compareTo(b.$1);
    });
    return [for (final e in indexed) e.$2];
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => SearchRepository(db: ref.watch(appDatabaseProvider)),
);

/// Results for the search page (debounce in the UI).
final searchResultsProvider = FutureProvider.autoDispose
    .family<
      SearchResults,
      ({int playlistId, String query, SearchFilter filter})
    >((ref, a) {
      final excludeLocked = watchExcludeLocked(ref, a.playlistId);
      return ref
          .watch(searchRepositoryProvider)
          .search(
            a.playlistId,
            a.query,
            filter: a.filter,
            excludeLocked: excludeLocked,
          );
    });

/// "Search by actor".
final titlesByPersonProvider = FutureProvider.autoDispose
    .family<PersonTitles, ({int playlistId, String name})>((ref, a) {
      final excludeLocked = watchExcludeLocked(ref, a.playlistId);
      return ref
          .watch(searchRepositoryProvider)
          .titlesByPerson(a.playlistId, a.name, excludeLocked: excludeLocked);
    });
