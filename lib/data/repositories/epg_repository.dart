/// EPG queries for channel cards, NOW ON AIR / UPCOMING, the TV Guide grid, the
/// TV Archive sheet and the Custom EPG picker, with the Xtream short-EPG
/// fallback.
library;

import 'dart:async';
import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_paths.dart' show appDatabaseProvider;
import '../db/database.dart';
import '../net/dio_factory.dart' show createDio;
import '../sources/source_exception.dart';
import '../sources/xtream/xtream_client.dart';
import '../sources/xtream/xtream_credentials.dart';
import '../sources/xtream/xtream_models.dart' show XtreamEpgListing;
import '../text/normalize.dart' show normalizeForSearch;
import 'playlist_repository.dart';
import 'repository_models.dart';

/// Reads programmes (UTC epoch ms in `programmes`, EPG time shift already
/// applied) through the `(playlist_id, epg_channel_id, start)` index.
///
/// Multi-channel queries ([nowNext], [guide]) run one statement per 400
/// keys. Programmes that started before a window but end inside it are
/// included. For Xtream playlists without XMLTV data for a channel, the
/// `...ForChannel` helpers fall back to `get_short_epg` (cached 30 minutes
/// per channel; failures are retried after 2 minutes).
class EpgRepository {
  EpgRepository(
    this._db,
    this._playlists, {
    DateTime Function()? clock,
    Dio Function()? dioFactory,
    this.shortEpgTtl = const Duration(minutes: 30),
    this.shortEpgRetryAfter = const Duration(minutes: 2),
    int shortEpgConcurrency = 4,
  }) : _clock = clock ?? DateTime.now,
       _dioFactory = dioFactory ?? createDio,
       _concurrency = shortEpgConcurrency;

  final AppDatabase _db;
  final PlaylistRepository _playlists;
  final DateTime Function() _clock;
  final Dio Function() _dioFactory;

  /// How long a fetched short EPG is reused.
  final Duration shortEpgTtl;

  /// How long a failed short-EPG request is not repeated.
  final Duration shortEpgRetryAfter;

  static const int _chunk = 400;

  /// The earliest start is searched among programmes ending at most this
  /// long after the earliest end.
  static const Duration _rangeLookback = Duration(hours: 6);

  // -------------------------------------------------------------------------
  // Programme windows
  // -------------------------------------------------------------------------

  /// Programmes of [epgKey] overlapping [from]…[to], by start.
  Future<List<ProgrammeView>> programmes(
    int playlistId,
    String epgKey,
    DateTime from,
    DateTime to,
  ) async => (await guide(playlistId, [epgKey], from, to))[epgKey] ?? const [];

  /// The programme on air at [at] (default now) and the next one, for every
  /// key of [epgKeys] (keys without data map to [NowNext.empty]). Two index
  /// seeks per key in one statement.
  Future<Map<String, NowNext>> nowNext(
    int playlistId,
    List<String> epgKeys, {
    DateTime? at,
  }) async {
    final t = (at ?? _clock()).toUtc();
    final ms = t.millisecondsSinceEpoch;
    final keys = _distinct(epgKeys);
    final found = <String, List<ProgrammeView>>{};
    for (final chunk in keys.slices(_chunk)) {
      final rows = await _db
          .customSelect(
            '${_keysCte(chunk.length)} '
            'SELECT p.* FROM programmes p WHERE p.id IN ('
            'SELECT (SELECT q.id FROM programmes q '
            'WHERE q.playlist_id = ? AND q.epg_channel_id = k.key '
            'AND q.start <= ? ORDER BY q.start DESC LIMIT 1) FROM k '
            'UNION ALL '
            'SELECT (SELECT q.id FROM programmes q '
            'WHERE q.playlist_id = ? AND q.epg_channel_id = k.key '
            'AND q.start > ? ORDER BY q.start LIMIT 1) FROM k)',
            variables: [
              for (final k in chunk) Variable.withString(k),
              Variable.withInt(playlistId),
              Variable.withInt(ms),
              Variable.withInt(playlistId),
              Variable.withInt(ms),
            ],
          )
          .get();
      for (final r in rows) {
        final p = _programme(r);
        (found[p.epgChannelId] ??= []).add(p);
      }
    }
    return {
      for (final k in keys)
        k: NowNext.fromProgrammes(found[k] ?? const <ProgrammeView>[], t),
    };
  }

  /// Programmes of every key in [epgKeys] overlapping [from]…[to] (also the
  /// one that started before [from] and is still running), by start. Every
  /// key is present in the result.
  Future<Map<String, List<ProgrammeView>>> guide(
    int playlistId,
    List<String> epgKeys,
    DateTime from,
    DateTime to,
  ) async {
    final keys = _distinct(epgKeys);
    final out = {for (final k in keys) k: <ProgrammeView>[]};
    final fromMs = from.millisecondsSinceEpoch;
    final toMs = to.millisecondsSinceEpoch;
    if (keys.isEmpty || toMs <= fromMs) return out;
    for (final chunk in keys.slices(_chunk)) {
      final rows = await _db
          .customSelect(
            '${_keysCte(chunk.length)} '
            'SELECT p.* FROM k CROSS JOIN programmes p '
            'WHERE p.playlist_id = ? AND p.epg_channel_id = k.key '
            'AND p.start >= ? AND p.start < ? '
            'UNION ALL '
            'SELECT p.* FROM programmes p WHERE p.id IN ('
            'SELECT (SELECT q.id FROM programmes q '
            'WHERE q.playlist_id = ? AND q.epg_channel_id = k.key '
            'AND q.start < ? ORDER BY q.start DESC LIMIT 1) FROM k) '
            'AND p.stop > ?',
            variables: [
              for (final k in chunk) Variable.withString(k),
              Variable.withInt(playlistId),
              Variable.withInt(fromMs),
              Variable.withInt(toMs),
              Variable.withInt(playlistId),
              Variable.withInt(fromMs),
              Variable.withInt(fromMs),
            ],
          )
          .get();
      for (final r in rows) {
        final p = _programme(r);
        out[p.epgChannelId]?.add(p);
      }
    }
    return {
      for (final e in out.entries)
        e.key: List.unmodifiable(e.value..sort(_byStart)),
    };
  }

  /// Programmes of [epgKey] starting after [at] (default now) and within
  /// [window] (UPCOMING panel).
  Future<List<ProgrammeView>> upcoming(
    int playlistId,
    String epgKey, {
    Duration window = const Duration(hours: 24),
    DateTime? at,
  }) async {
    final t = (at ?? _clock()).toUtc();
    final rows = await _db
        .customSelect(
          'SELECT * FROM programmes WHERE playlist_id = ? '
          'AND epg_channel_id = ? AND start > ? AND start < ? ORDER BY start',
          variables: [
            Variable.withInt(playlistId),
            Variable.withString(epgKey),
            Variable.withInt(t.millisecondsSinceEpoch),
            Variable.withInt(t.add(window).millisecondsSinceEpoch),
          ],
        )
        .get();
    return List.unmodifiable(rows.map(_programme));
  }

  /// TV Archive: the programme on air at [now] followed by the past programmes
  /// that can be replayed ([ProgrammeView.isReplayableWith] with the channel's
  /// `archiveDays`), newest first, grouped by local day. Empty when the channel
  /// has no archive. Xtream channels without XMLTV data use
  /// `get_simple_data_table`.
  Future<List<ArchiveDay>> archive(
    int playlistId,
    ChannelRow channel, {
    DateTime? now,
  }) async {
    final days = channel.archiveDays;
    if (days <= 0) return const [];
    final t = (now ?? _clock()).toUtc();
    final playlist = await _playlists.get(playlistId);
    if (playlist == null) return const [];
    final key = channelEpgKey(channel, playlist.type);
    var list = <ProgrammeView>[];
    if (key != null) {
      final rows = await _db
          .customSelect(
            'SELECT * FROM programmes WHERE playlist_id = ? '
            'AND epg_channel_id = ? AND start > ? AND start <= ? '
            'ORDER BY start DESC',
            variables: [
              Variable.withInt(playlistId),
              Variable.withString(key),
              Variable.withInt(
                t.subtract(Duration(days: days)).millisecondsSinceEpoch,
              ),
              Variable.withInt(t.millisecondsSinceEpoch),
            ],
          )
          .get();
      list = rows.map(_programme).toList();
    }
    if (list.isEmpty && playlist.type == PlaylistType.xtream) {
      list = await _xtreamListings(
        'table',
        playlistId,
        channel,
        (client) => client.simpleDataTable(channel.providerId),
      );
    }
    final kept =
        list
            .where((p) => p.isOnAirAt(t) || p.isReplayableWith(days, t))
            .toList()
          ..sort((a, b) => b.start.compareTo(a.start));
    final byDay = <DateTime, List<ProgrammeView>>{};
    for (final p in kept) {
      final local = p.start.toLocal();
      (byDay[DateTime(local.year, local.month, local.day)] ??= []).add(p);
    }
    return List.unmodifiable([
      for (final e in byDay.entries)
        ArchiveDay(e.key, List.unmodifiable(e.value)),
    ]);
  }

  // -------------------------------------------------------------------------
  // Channel helpers with the short-EPG fallback
  // -------------------------------------------------------------------------

  /// Now/next of one channel: the stored EPG, else (Xtream) the short EPG.
  Future<NowNext> nowNextForChannel(
    int playlistId,
    ChannelView channel, {
    DateTime? at,
  }) async {
    final t = (at ?? _clock()).toUtc();
    final key = channel.epgKey;
    if (key != null) {
      final stored = (await nowNext(playlistId, [key], at: t))[key];
      if (stored != null && !stored.isEmpty) return stored;
    }
    return NowNext.fromProgrammes(await shortEpg(playlistId, channel.row), t);
  }

  /// UPCOMING of one channel: the stored EPG, else (Xtream) the short EPG.
  Future<List<ProgrammeView>> upcomingForChannel(
    int playlistId,
    ChannelView channel, {
    Duration window = const Duration(hours: 24),
    DateTime? at,
  }) async {
    final t = (at ?? _clock()).toUtc();
    final key = channel.epgKey;
    if (key != null) {
      final list = await upcoming(playlistId, key, window: window, at: t);
      if (list.isNotEmpty) return list;
      final stored = (await nowNext(playlistId, [key], at: t))[key];
      if (stored != null && !stored.isEmpty) return list;
    }
    final end = t.add(window);
    return List.unmodifiable(
      (await shortEpg(
        playlistId,
        channel.row,
      )).where((p) => p.start.isAfter(t) && p.start.isBefore(end)),
    );
  }

  // -------------------------------------------------------------------------
  // Custom EPG picker and day range
  // -------------------------------------------------------------------------

  /// XMLTV channels for the Custom EPG picker, with the programme on air.
  /// [query] matches the id or the display name (diacritics-insensitive);
  /// names starting with the query come first. At most [limit] results.
  Future<List<EpgChannelView>> epgChannels(
    int playlistId, {
    String? query,
    int limit = 200,
    DateTime? at,
  }) async {
    final q = query?.trim() ?? '';
    final vars = <Variable<Object>>[Variable.withInt(playlistId)];
    var where = 'playlist_id = ?';
    final folded = normalizeForSearch(q);
    if (q.isNotEmpty) {
      final like = '%${_escapeLike(q.toLowerCase())}%';
      final compact = folded.replaceAll(' ', '');
      where +=
          ' AND (LOWER(epg_id) LIKE ? ESCAPE \'\\\' '
          'OR LOWER(display_name) LIKE ? ESCAPE \'\\\''
          '${compact.isEmpty ? '' : " OR REPLACE(normalized, ' ', '') LIKE ?"})';
      vars
        ..add(Variable.withString(like))
        ..add(Variable.withString(like));
      if (compact.isNotEmpty) vars.add(Variable.withString('%$compact%'));
    }
    vars.add(Variable.withInt(limit));
    final rows = await _db
        .customSelect(
          'SELECT epg_id, display_name, icon FROM epg_channels WHERE $where '
          'ORDER BY display_name COLLATE NOCASE LIMIT ?',
          variables: vars,
        )
        .get();
    final ids = [for (final r in rows) r.read<String>('epg_id')];
    final now = await nowNext(playlistId, ids, at: at);
    final views = [
      for (final r in rows)
        EpgChannelView(
          id: r.read<String>('epg_id'),
          displayName: r.read<String>('display_name'),
          icon: _nonBlank(r.readNullable<String>('icon')),
          now: now[r.read<String>('epg_id')]?.now,
        ),
    ];
    if (folded.isEmpty) return sortCollated(views, (v) => v.displayName);
    final prefix = <EpgChannelView>[];
    final rest = <EpgChannelView>[];
    for (final v in views) {
      (normalizeForSearch(v.displayName).startsWith(folded) ? prefix : rest)
          .add(v);
    }
    return [
      ...sortCollated(prefix, (v) => v.displayName),
      ...sortCollated(rest, (v) => v.displayName),
    ];
  }

  /// First programme start and last programme end of the playlist (UTC), or
  /// null without programmes. Uses the `(playlist_id, stop)` index; the
  /// start is exact unless the earliest programme is longer than
  /// [_rangeLookback] (then it is at most that much later).
  Future<EpgDataRange?> dataRange(int playlistId) async {
    final pid = [Variable.withInt(playlistId)];
    final minStop =
        (await _db
                .customSelect(
                  'SELECT MIN(stop) AS v FROM programmes WHERE playlist_id = ?',
                  variables: pid,
                )
                .getSingle())
            .readNullable<int>('v');
    if (minStop == null) return null;
    final maxStop =
        (await _db
                .customSelect(
                  'SELECT MAX(stop) AS v FROM programmes WHERE playlist_id = ?',
                  variables: pid,
                )
                .getSingle())
            .read<int>('v');
    final minStart =
        (await _db
                .customSelect(
                  'SELECT MIN(start) AS v FROM programmes '
                  'WHERE playlist_id = ? AND stop <= ?',
                  variables: [
                    ...pid,
                    Variable.withInt(minStop + _rangeLookback.inMilliseconds),
                  ],
                )
                .getSingle())
            .read<int>('v');
    return (
      start: DateTime.fromMillisecondsSinceEpoch(minStart, isUtc: true),
      end: DateTime.fromMillisecondsSinceEpoch(maxStop, isUtc: true),
    );
  }

  // -------------------------------------------------------------------------
  // Xtream short EPG
  // -------------------------------------------------------------------------

  final Map<String, _CachedListings> _xtreamCache = {};
  final Map<String, Future<List<ProgrammeView>>> _inFlight = {};
  final Map<int, _XtreamSession> _sessions = {};
  final int _concurrency;
  int _active = 0;
  final Queue<Completer<void>> _waiting = Queue();

  /// `get_short_epg` of an Xtream channel (now + the next [limit]
  /// programmes) as [ProgrammeView]s; empty for other playlist types or on
  /// failure. Cached for [shortEpgTtl] per channel.
  Future<List<ProgrammeView>> shortEpg(
    int playlistId,
    ChannelRow channel, {
    int limit = 10,
  }) => _xtreamListings(
    'short',
    playlistId,
    channel,
    (client) => client.shortEpg(channel.providerId, limit: limit),
  );

  /// Forgets cached short EPGs (of one playlist, or all).
  void clearShortEpgCache([int? playlistId]) {
    if (playlistId == null) {
      _xtreamCache.clear();
    } else {
      _xtreamCache.removeWhere((k, _) => k.split('/')[1] == '$playlistId');
    }
  }

  /// Closes the HTTP clients of the short EPG.
  void dispose() {
    for (final s in _sessions.values) {
      s.dio.close(force: true);
    }
    _sessions.clear();
  }

  Future<List<ProgrammeView>> _xtreamListings(
    String kind,
    int playlistId,
    ChannelRow channel,
    Future<List<XtreamEpgListing>> Function(XtreamClient client) fetch,
  ) {
    final key = '$kind/$playlistId/${channel.providerId}';
    final hit = _xtreamCache[key];
    if (hit != null && _clock().isBefore(hit.expires)) {
      return Future.value(hit.programmes);
    }
    final pending = _inFlight[key];
    if (pending != null) return pending;
    final future = _fetchListings(key, playlistId, channel, fetch).whenComplete(
      () {
        // A block body: returning the removed future would make whenComplete
        // wait for itself.
        _inFlight.remove(key);
      },
    );
    _inFlight[key] = future;
    return future;
  }

  Future<List<ProgrammeView>> _fetchListings(
    String key,
    int playlistId,
    ChannelRow channel,
    Future<List<XtreamEpgListing>> Function(XtreamClient client) fetch,
  ) async {
    final playlist = await _playlists.get(playlistId);
    if (playlist == null || playlist.type != PlaylistType.xtream) {
      return const [];
    }
    final client = await _client(playlistId, playlist);
    if (client == null) return const [];
    await _acquire();
    try {
      final listings = await fetch(client);
      final epgKey =
          channelEpgKey(channel, playlist.type) ??
          'xtream:${channel.providerId}';
      final list = List<ProgrammeView>.unmodifiable([
        for (final l in listings)
          ProgrammeView(
            epgChannelId: epgKey,
            start: l.start.toUtc(),
            stop: l.stop.toUtc(),
            title: l.title,
            description: l.description,
          ),
      ]);
      _xtreamCache[key] = _CachedListings(list, _clock().add(shortEpgTtl));
      return list;
    } on SourceException {
      _xtreamCache[key] = _CachedListings(
        const [],
        _clock().add(shortEpgRetryAfter),
      );
      return const [];
    } finally {
      _release();
    }
  }

  Future<XtreamClient?> _client(int playlistId, PlaylistRow playlist) async {
    final creds = await _playlists.xtreamCredentials(playlistId);
    if (creds == null) return null;
    var session = _sessions[playlistId];
    if (session == null || session.credentials != creds) {
      session?.dio.close(force: true);
      final dio = _dioFactory();
      final client = XtreamClient(dio, creds);
      final offset =
          _playlists.account(playlist)?.serverUtcOffset ?? Duration.zero;
      session = _XtreamSession(
        creds,
        dio,
        client,
        // Listings without timestamps need the server offset, which the
        // client learns from the account call.
        offset == Duration.zero ? Future.value() : _learnOffset(client),
      );
      _sessions[playlistId] = session;
    }
    await session.ready;
    return session.client;
  }

  static Future<void> _learnOffset(XtreamClient client) async {
    try {
      await client.accountInfo();
    } on SourceException {
      // Keep a zero offset; most panels send timestamps anyway.
    }
  }

  Future<void> _acquire() async {
    if (_active < _concurrency) {
      _active++;
      return;
    }
    final slot = Completer<void>();
    _waiting.add(slot);
    await slot.future;
  }

  void _release() {
    if (_waiting.isNotEmpty) {
      _waiting.removeFirst().complete();
    } else {
      _active--;
    }
  }

  // -------------------------------------------------------------------------

  ProgrammeView _programme(QueryRow row) =>
      ProgrammeView.fromRow(_db.programmes.map(row.data));

  static int _byStart(ProgrammeView a, ProgrammeView b) =>
      a.start.compareTo(b.start);

  static String _keysCte(int n) =>
      'WITH k(key) AS (VALUES ${List.filled(n, '(?)').join(', ')})';

  static List<String> _distinct(List<String> keys) => [
    ...{
      for (final k in keys)
        if (k.isNotEmpty) k,
    },
  ];

  static String _escapeLike(String s) =>
      s.replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}');

  static String? _nonBlank(String? s) {
    final t = s?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }
}

class _CachedListings {
  const _CachedListings(this.programmes, this.expires);

  final List<ProgrammeView> programmes;
  final DateTime expires;
}

class _XtreamSession {
  _XtreamSession(this.credentials, this.dio, this.client, this.ready);

  final XtreamCredentials credentials;
  final Dio dio;
  final XtreamClient client;
  final Future<void> ready;
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final epgRepositoryProvider = Provider<EpgRepository>((ref) {
  final repo = EpgRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(playlistRepositoryProvider),
  );
  ref.onDispose(repo.dispose);
  return repo;
});

/// The guide's day-picker range; refreshed after each EPG reload.
final epgDataRangeProvider = FutureProvider.autoDispose
    .family<EpgDataRange?, int>((ref, playlistId) {
      ref.watch(
        playlistProvider(playlistId).select((p) => p.value?.lastEpgReloadAt),
      );
      return ref.watch(epgRepositoryProvider).dataRange(playlistId);
    });
