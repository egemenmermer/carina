/// Live channels for TV Live, the guide rows, zapping and number zapping, plus
/// per-channel local state: hidden, locked, Custom EPG and Last watched.
library;

import 'dart:async';
import 'dart:collection';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_paths.dart' show appDatabaseProvider;
import '../db/database.dart';
import '../settings/settings_store.dart';
import 'parental_service.dart' show parentalSessionProvider;
import 'repository_models.dart';

/// Channel lists and channel state.
///
/// Lists leave out hidden channels. Lists of special categories (Favorites,
/// tags, Last watched, Recently added, All) also leave out channels whose
/// category is hidden; a provider category lists its channels even when the
/// category itself is hidden (it can only be opened from Hidden items).
/// With parental mode `hide`, locked channels and channels of locked
/// categories are left out unless `revealLocked`.
///
/// Order: provider categories and [AllCategory] follow `channelsOrder`
/// (`playlist` = provider order, `name` = locale-aware display name,
/// `number` = channel number then provider order, `date` = newest added
/// first); Favorites follow `favoritesOrder` (`lastAdded`, `leastRecent`,
/// `name`, `custom`); Last watched is most recent first; Recently added is
/// newest first.
class LiveRepository {
  LiveRepository(this._db, this._settings, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    _updates = _db
        .tableUpdates(
          TableUpdateQuery.onAllTables([..._baseTables, _db.lastWatchedLive]),
        )
        .listen((updates) {
          for (final u in updates) {
            if (u.table == _db.lastWatchedLive.actualTableName) {
              _lastWatchedGeneration++;
            } else {
              _generation++;
            }
          }
        });
  }

  final AppDatabase _db;
  final SettingsStore _settings;
  final DateTime Function() _clock;

  late final StreamSubscription<Set<TableUpdate>> _updates;

  /// Bumped on every change of a table every list reads; cached lists of
  /// an older generation are stale.
  int _generation = 0;

  /// Bumped when Last watched changes (only that list reads it, so zapping
  /// does not invalidate the other cached lists).
  int _lastWatchedGeneration = 0;
  final LinkedHashMap<_ListKey, _CachedList> _cache = LinkedHashMap();
  static const int _cacheSize = 8;

  List<ResultSetImplementation<dynamic, dynamic>> get _baseTables => [
    _db.channels,
    _db.categories,
    _db.favorites,
    _db.favoriteTagLinks,
    _db.reminders,
  ];

  /// Tables the list of [category] reads.
  List<ResultSetImplementation<dynamic, dynamic>> _tablesFor(
    CategoryRef category,
  ) => [
    _db.channels,
    _db.categories,
    _db.favorites,
    _db.reminders,
    if (category case FavoritesCategory(tagId: _?)) _db.favoriteTagLinks,
    if (category is LastWatchedCategory) _db.lastWatchedLive,
  ];

  /// The cache stamp of [category]'s list now.
  _Stamp _stamp(CategoryRef category) => (
    base: _generation,
    lastWatched: category is LastWatchedCategory ? _lastWatchedGeneration : 0,
  );

  /// Stops listening to table updates.
  Future<void> dispose() => _updates.cancel();

  // -------------------------------------------------------------------------
  // Lists
  // -------------------------------------------------------------------------

  /// The channels of [category] (see the class comment for filters and
  /// order). Updates when channels, categories, favorites, Last watched,
  /// reminders or the order/parental settings change.
  Stream<List<ChannelView>> watchChannels(
    int playlistId,
    CategoryRef category, {
    bool revealLocked = false,
  }) => watchComputed(
    db: _db,
    tables: _tablesFor(category),
    compute: () async {
      final options = _options(playlistId);
      final stamp = _stamp(category);
      final list = await _query(
        playlistId,
        category,
        options,
        revealLocked: revealLocked,
      );
      _remember(
        _ListKey(playlistId, category, revealLocked, options),
        stamp,
        list,
      );
      return list;
    },
    settings: _settings,
    settingsKey: () => _options(playlistId),
  );

  /// One-shot [watchChannels] (served from a cache while nothing changed).
  Future<List<ChannelView>> channels(
    int playlistId,
    CategoryRef category, {
    bool revealLocked = false,
  }) async {
    final options = _options(playlistId);
    final key = _ListKey(playlistId, category, revealLocked, options);
    final hit = _cache[key];
    if (hit != null && hit.stamp == _stamp(category)) return hit.list;
    final stamp = _stamp(category);
    final list = await _query(
      playlistId,
      category,
      options,
      revealLocked: revealLocked,
    );
    _remember(key, stamp, list);
    return list;
  }

  /// Previous and next channel of [providerId] inside [category], wrapping
  /// around. Both null when the channel is not in the list or is alone.
  Future<ChannelNeighbors> neighbors(
    int playlistId,
    CategoryRef category,
    String providerId, {
    bool revealLocked = false,
  }) async {
    final list = await channels(
      playlistId,
      category,
      revealLocked: revealLocked,
    );
    final index = list.indexWhere((c) => c.providerId == providerId);
    if (index < 0 || list.length < 2) return (previous: null, next: null);
    return (
      previous: list[(index - 1 + list.length) % list.length],
      next: list[(index + 1) % list.length],
    );
  }

  /// Visible channels of the playlist (the [AllCategory] list length).
  Future<int> allChannelsCount(
    int playlistId, {
    bool revealLocked = false,
  }) async {
    final hideLocked = _options(playlistId).hideLocked && !revealLocked;
    final row = await _db
        .customSelect(
          'SELECT COUNT(*) AS n FROM channels c $_categoryJoin '
          'WHERE c.playlist_id = ? AND ${_visible(hideLocked)}',
          variables: [Variable.withInt(playlistId)],
        )
        .getSingle();
    return row.read<int>('n');
  }

  // -------------------------------------------------------------------------
  // Single channels
  // -------------------------------------------------------------------------

  /// One channel by provider id, whatever its hidden/locked state.
  Future<ChannelView?> channel(int playlistId, String providerId) async {
    final type = await _playlistType(playlistId);
    if (type == null) return null;
    final rows = await _db
        .customSelect(
          '${_select()} WHERE c.playlist_id = ? AND c.provider_id = ?',
          variables: [
            Variable.withInt(_nowMs()),
            Variable.withInt(playlistId),
            Variable.withString(providerId),
          ],
          readsFrom: _readsFrom,
        )
        .get();
    return rows.isEmpty ? null : _map(rows.first, type);
  }

  /// Number zapping: the visible channel with `num` [number] (first in
  /// provider order). When no channel of the playlist has a number (M3U
  /// without `tvg-chno`), [number] is the 1-based position in provider
  /// order instead.
  Future<ChannelView?> channelByNumber(
    int playlistId,
    int number, {
    bool revealLocked = false,
  }) async {
    final type = await _playlistType(playlistId);
    if (type == null || number <= 0) return null;
    final hideLocked = _options(playlistId).hideLocked && !revealLocked;
    final visible = 'c.playlist_id = ? AND ${_visible(hideLocked)}';
    var rows = await _db
        .customSelect(
          '${_select()} WHERE $visible AND c.num = ? '
          'ORDER BY c.sort_index, c.id LIMIT 1',
          variables: [
            Variable.withInt(_nowMs()),
            Variable.withInt(playlistId),
            Variable.withInt(number),
          ],
          readsFrom: _readsFrom,
        )
        .get();
    if (rows.isEmpty) {
      final numbered = await _db
          .customSelect(
            'SELECT EXISTS (SELECT 1 FROM channels '
            'WHERE playlist_id = ? AND num IS NOT NULL) AS any_num',
            variables: [Variable.withInt(playlistId)],
          )
          .getSingle();
      if (sqlBool(numbered.data['any_num'])) return null;
      rows = await _db
          .customSelect(
            '${_select()} WHERE $visible '
            'ORDER BY c.sort_index, c.id LIMIT 1 OFFSET ?',
            variables: [
              Variable.withInt(_nowMs()),
              Variable.withInt(playlistId),
              Variable.withInt(number - 1),
            ],
            readsFrom: _readsFrom,
          )
          .get();
    }
    return rows.isEmpty ? null : _map(rows.first, type);
  }

  // -------------------------------------------------------------------------
  // Settings lists
  // -------------------------------------------------------------------------

  /// Hidden channels (Settings → Hidden items), by name.
  Stream<List<ChannelView>> hiddenChannels(int playlistId) =>
      _watchWhere(playlistId, 'c.hidden = 1');

  /// Channels locked individually (Settings → Parental Control), by name.
  Stream<List<ChannelView>> lockedChannels(int playlistId) =>
      _watchWhere(playlistId, 'c.locked = 1');

  /// One-shot [lockedChannels].
  Future<List<ChannelView>> lockedChannelsOnce(int playlistId) =>
      _where(playlistId, 'c.locked = 1');

  /// Channels with a Custom EPG assignment (Settings → Custom EPG
  /// assignments), by name.
  Stream<List<ChannelView>> customEpgChannels(int playlistId) =>
      _watchWhere(playlistId, 'c.custom_epg_id IS NOT NULL');

  Stream<List<ChannelView>> _watchWhere(int playlistId, String condition) =>
      watchComputed(
        db: _db,
        tables: _baseTables,
        compute: () => _where(playlistId, condition),
        settings: _settings,
        settingsKey: () => isTurkishCollation(_settings),
      );

  Future<List<ChannelView>> _where(int playlistId, String condition) async {
    final type = await _playlistType(playlistId);
    if (type == null) return const [];
    final rows = await _db
        .customSelect(
          '${_select()} WHERE c.playlist_id = ? AND $condition',
          variables: [Variable.withInt(_nowMs()), Variable.withInt(playlistId)],
          readsFrom: _readsFrom,
        )
        .get();
    return sortCollated(
      [for (final r in rows) _map(r, type)],
      (c) => c.displayName,
      turkish: isTurkishCollation(_settings),
    );
  }

  // -------------------------------------------------------------------------
  // Mutations
  // -------------------------------------------------------------------------

  Future<void> setHidden(int playlistId, String providerId, bool hidden) =>
      _write(playlistId, providerId, ChannelsCompanion(hidden: Value(hidden)));

  Future<void> setLocked(int playlistId, String providerId, bool locked) =>
      _write(playlistId, providerId, ChannelsCompanion(locked: Value(locked)));

  /// Custom EPG assignment; null or blank resets it so the
  /// matched id applies again.
  Future<void> setCustomEpg(int playlistId, String providerId, String? epgId) {
    final trimmed = epgId?.trim();
    return _write(
      playlistId,
      providerId,
      ChannelsCompanion(
        customEpgId: Value(trimmed == null || trimmed.isEmpty ? null : trimmed),
      ),
    );
  }

  /// Records that [providerId] started playing: it moves to the top of Last
  /// watched, which keeps the [lastWatchedLimit] most recent channels.
  Future<void> addLastWatched(int playlistId, String providerId) async {
    await _db.transaction(() async {
      // Delete + insert gives the row a new (largest) rowid, the tie-breaker
      // for channels started within the same second.
      await (_db.delete(_db.lastWatchedLive)..where(
            (l) =>
                l.playlistId.equals(playlistId) &
                l.channelId.equals(providerId),
          ))
          .go();
      await _db
          .into(_db.lastWatchedLive)
          .insert(
            LastWatchedLiveCompanion.insert(
              playlistId: playlistId,
              channelId: providerId,
              watchedAt: _clock(),
            ),
          );
      await _db.customUpdate(
        'DELETE FROM last_watched_live WHERE playlist_id = ?1 AND rowid NOT IN '
        '(SELECT rowid FROM last_watched_live WHERE playlist_id = ?1 '
        'ORDER BY watched_at DESC, rowid DESC LIMIT $lastWatchedLimit)',
        variables: [Variable.withInt(playlistId)],
        updates: {_db.lastWatchedLive},
        updateKind: UpdateKind.delete,
      );
    });
    _lastWatchedGeneration++;
  }

  Future<void> removeLastWatched(int playlistId, String providerId) async {
    await (_db.delete(_db.lastWatchedLive)..where(
          (l) =>
              l.playlistId.equals(playlistId) & l.channelId.equals(providerId),
        ))
        .go();
    _lastWatchedGeneration++;
  }

  Future<void> clearLastWatched(int playlistId) async {
    await (_db.delete(
      _db.lastWatchedLive,
    )..where((l) => l.playlistId.equals(playlistId))).go();
    _lastWatchedGeneration++;
  }

  Future<void> _write(
    int playlistId,
    String providerId,
    ChannelsCompanion companion,
  ) async {
    await (_db.update(_db.channels)..where(
          (c) =>
              c.playlistId.equals(playlistId) & c.providerId.equals(providerId),
        ))
        .write(companion);
    _generation++;
  }

  // -------------------------------------------------------------------------
  // Query
  // -------------------------------------------------------------------------

  Set<ResultSetImplementation<dynamic, dynamic>> get _readsFrom => {
    _db.channels,
    _db.categories,
    _db.favorites,
    _db.reminders,
  };

  /// `cat.kind = 0` is [SectionKind.live].
  static const String _categoryJoin =
      'LEFT JOIN categories cat ON cat.playlist_id = c.playlist_id '
      'AND cat.kind = 0 AND cat.provider_id = c.category_id';

  /// The channel columns plus category, favorite and reminder state. The
  /// first variable is "now" in epoch ms (pending reminders).
  static String _select() =>
      'SELECT c.*, cat.name AS cat_name, cat.local_name AS cat_local, '
      'COALESCE(cat.hidden, 0) AS cat_hidden, '
      'COALESCE(cat.locked, 0) AS cat_locked, f.id AS fav_id, '
      'EXISTS (SELECT 1 FROM reminders r WHERE r.playlist_id = c.playlist_id '
      'AND r.channel_id = c.provider_id AND r.stop > ?) AS has_rem '
      'FROM channels c $_categoryJoin '
      'LEFT JOIN favorites f ON f.playlist_id = c.playlist_id '
      'AND f.item_type = ${ItemType.channel.index} '
      'AND f.provider_id = c.provider_id';

  /// Visible in special lists (see the class comment).
  static String _visible(bool hideLocked) => [
    'c.hidden = 0',
    'COALESCE(cat.hidden, 0) = 0',
    if (hideLocked) 'c.locked = 0 AND COALESCE(cat.locked, 0) = 0',
  ].join(' AND ');

  Future<List<ChannelView>> _query(
    int playlistId,
    CategoryRef category,
    _LiveOptions o, {
    required bool revealLocked,
  }) async {
    final type = await _playlistType(playlistId);
    if (type == null) return const [];
    final hideLocked = o.hideLocked && !revealLocked;
    final sql = StringBuffer(_select());
    final vars = <Variable<Object>>[Variable.withInt(_nowMs())];
    final where = <String>['c.playlist_id = ?', 'c.hidden = 0'];
    vars.add(Variable.withInt(playlistId));
    var byName = false;
    String orderBy;
    var limit = '';

    String channelOrder() {
      switch (o.channelsOrder) {
        case 'name':
          byName = true;
          return 'c.sort_index, c.id';
        case 'number':
          return 'c.num IS NULL, c.num, c.sort_index, c.id';
        case 'date':
          return 'c.added IS NULL, c.added DESC, c.sort_index, c.id';
        default:
          return 'c.sort_index, c.id';
      }
    }

    switch (category) {
      case ProviderCategory(:final id):
        where.add('c.category_id = ?');
        vars.add(Variable.withString(id));
        orderBy = channelOrder();
      case AllCategory():
        orderBy = channelOrder();
      case FavoritesCategory(:final tagId):
        where.add('f.id IS NOT NULL');
        if (tagId != null) {
          where.add(
            'EXISTS (SELECT 1 FROM favorite_tag_links l '
            'WHERE l.favorite_id = f.id AND l.tag_id = ?)',
          );
          vars.add(Variable.withInt(tagId));
        }
        switch (o.favoritesOrder) {
          case 'name':
            byName = true;
            orderBy = 'f.added_at DESC, f.id DESC';
          case 'leastRecent':
            orderBy = 'f.added_at, f.id';
          case 'custom':
            orderBy =
                'f.custom_index IS NULL, f.custom_index, '
                'f.added_at DESC, f.id DESC';
          default:
            orderBy = 'f.added_at DESC, f.id DESC';
        }
      case LastWatchedCategory():
        sql.write(
          ' JOIN last_watched_live lw ON lw.playlist_id = c.playlist_id '
          'AND lw.channel_id = c.provider_id',
        );
        orderBy = 'lw.watched_at DESC, lw.rowid DESC';
        limit = ' LIMIT $lastWatchedLimit';
      case RecentlyAddedCategory():
        where.add('c.added >= ?');
        vars.add(Variable<DateTime>(_clock().subtract(recentlyAddedWindow)));
        orderBy = 'c.added DESC, c.sort_index, c.id';
    }
    if (category is! ProviderCategory) {
      where.add('COALESCE(cat.hidden, 0) = 0');
    }
    if (hideLocked) where.add('c.locked = 0 AND COALESCE(cat.locked, 0) = 0');
    sql
      ..write(' WHERE ')
      ..write(where.join(' AND '))
      ..write(' ORDER BY ')
      ..write(orderBy)
      ..write(limit);

    final rows = await _db
        .customSelect(sql.toString(), variables: vars, readsFrom: _readsFrom)
        .get();
    final list = [for (final r in rows) _map(r, type)];
    return List.unmodifiable(
      byName
          ? sortCollated(list, (c) => c.displayName, turkish: o.turkish)
          : list,
    );
  }

  ChannelView _map(QueryRow r, PlaylistType type) {
    final row = _db.channels.map(r.data);
    final categoryLocked = sqlBool(r.data['cat_locked']);
    final local = (r.data['cat_local'] as String?)?.trim();
    final categoryName = (local == null || local.isEmpty)
        ? (r.data['cat_name'] as String?) ?? ''
        : local;
    return ChannelView(
      row: row,
      displayName: row.displayName.trim().isEmpty ? row.name : row.displayName,
      badges: qualityBadges(row.quality),
      locked: row.locked || categoryLocked,
      channelLocked: row.locked,
      categoryLocked: categoryLocked,
      categoryHidden: sqlBool(r.data['cat_hidden']),
      favorite: r.data['fav_id'] != null,
      hasReminder: sqlBool(r.data['has_rem']),
      hasArchive: row.archiveDays > 0,
      epgKey: channelEpgKey(row, type),
      categoryName: categoryName,
    );
  }

  Future<PlaylistType?> _playlistType(int playlistId) async {
    final type = _db.playlists.type;
    final row =
        await (_db.selectOnly(_db.playlists)
              ..addColumns([type])
              ..where(_db.playlists.id.equals(playlistId)))
            .getSingleOrNull();
    return row?.readWithConverter(type);
  }

  int _nowMs() => _clock().millisecondsSinceEpoch;

  _LiveOptions _options(int playlistId) => (
    channelsOrder: _settings.get(
      PlaylistSettings.channelsOrder,
      playlistId: playlistId,
    ),
    favoritesOrder: _settings.get(
      PlaylistSettings.favoritesOrder,
      playlistId: playlistId,
    ),
    hideLocked:
        _settings.get(PlaylistSettings.parentalMode, playlistId: playlistId) ==
        'hide',
    turkish: isTurkishCollation(_settings),
  );

  void _remember(_ListKey key, _Stamp stamp, List<ChannelView> list) {
    _cache.remove(key);
    _cache[key] = _CachedList(stamp, list);
    while (_cache.length > _cacheSize) {
      _cache.remove(_cache.keys.first);
    }
  }
}

typedef _LiveOptions = ({
  String channelsOrder,
  String favoritesOrder,
  bool hideLocked,
  bool turkish,
});

class _ListKey {
  const _ListKey(this.playlistId, this.category, this.reveal, this.options);

  final int playlistId;
  final CategoryRef category;
  final bool reveal;
  final _LiveOptions options;

  @override
  bool operator ==(Object other) =>
      other is _ListKey &&
      other.playlistId == playlistId &&
      other.category == category &&
      other.reveal == reveal &&
      other.options == options;

  @override
  int get hashCode => Object.hash(playlistId, category, reveal, options);
}

typedef _Stamp = ({int base, int lastWatched});

class _CachedList {
  const _CachedList(this.stamp, this.list);

  final _Stamp stamp;
  final List<ChannelView> list;
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final liveRepositoryProvider = Provider<LiveRepository>((ref) {
  final repo = LiveRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(settingsStoreProvider),
  );
  ref.onDispose(repo.dispose);
  return repo;
});

/// Arguments of [channelsProvider].
typedef ChannelListArgs = ({int playlistId, CategoryRef category});

/// The channel list of a category; locked channels are revealed in parental
/// `hide` mode after the PIN unlocked everything for the session.
final channelsProvider = StreamProvider.autoDispose
    .family<List<ChannelView>, ChannelListArgs>((ref, args) {
      final reveal = ref.watch(
        parentalSessionProvider.select(
          (s) => s.allUnlockedFor(args.playlistId),
        ),
      );
      return ref
          .watch(liveRepositoryProvider)
          .watchChannels(args.playlistId, args.category, revealLocked: reveal);
    });

/// Settings → Hidden items (channels).
final hiddenChannelsProvider = StreamProvider.autoDispose
    .family<List<ChannelView>, int>(
      (ref, playlistId) =>
          ref.watch(liveRepositoryProvider).hiddenChannels(playlistId),
    );

/// Settings → Custom EPG assignments.
final customEpgChannelsProvider = StreamProvider.autoDispose
    .family<List<ChannelView>, int>(
      (ref, playlistId) =>
          ref.watch(liveRepositoryProvider).customEpgChannels(playlistId),
    );
