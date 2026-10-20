import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_paths.dart';
import '../db/database.dart';
import '../settings/settings_store.dart';
import '../text/normalize.dart';
import 'repository_models.dart' show isTurkishCollation;
import 'vod_models.dart';

export 'vod_models.dart' show FavoritesOrder;

/// A favorite (stable key: playlist + type + provider id), with the item's
/// current name when the item exists.
@immutable
class FavoriteEntry {
  const FavoriteEntry({
    required this.id,
    required this.type,
    required this.providerId,
    required this.addedAt,
    this.customIndex,
    this.name,
  });

  /// Favorite row id (tag links point here).
  final int id;
  final ItemType type;
  final String providerId;
  final DateTime addedAt;
  final int? customIndex;

  /// Channel display name / movie or series name / episode title; null when
  /// the item is not in the library right now (e.g. during a reload).
  final String? name;

  bool get isAvailable => name != null;

  @override
  bool operator ==(Object other) =>
      other is FavoriteEntry &&
      other.id == id &&
      other.type == type &&
      other.providerId == providerId &&
      other.addedAt == addedAt &&
      other.customIndex == customIndex &&
      other.name == name;

  @override
  int get hashCode =>
      Object.hash(id, type, providerId, addedAt, customIndex, name);

  @override
  String toString() => 'FavoriteEntry(${type.name} $providerId)';
}

/// A favorites tag (sub-category under Favorites in the sidebar).
@immutable
class FavoriteTag {
  const FavoriteTag({
    required this.id,
    required this.name,
    this.sortIndex = 0,
    this.counts = const {},
  });

  final int id;
  final String name;
  final int sortIndex;

  /// Tagged favorites per item type (types without favorites are absent).
  final Map<ItemType, int> counts;

  int countOf(ItemType type) => counts[type] ?? 0;
  int get total => counts.values.fold(0, (a, b) => a + b);

  @override
  bool operator ==(Object other) =>
      other is FavoriteTag &&
      other.id == id &&
      other.name == name &&
      other.sortIndex == sortIndex &&
      mapEquals(other.counts, counts);

  @override
  int get hashCode => Object.hash(id, name, sortIndex, counts.length);

  @override
  String toString() => 'FavoriteTag($id "$name" $counts)';
}

/// Favorites and favorite tags for channels, movies and series, per
/// playlist.
///
/// Favorites reference provider ids, so they survive reloads even while
/// the item row is deleted and re-inserted.
class FavoritesRepository {
  FavoritesRepository({
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
  // Favorites
  // -------------------------------------------------------------------------

  Stream<bool> watchIsFavorite(int playlistId, ItemType type, String id) =>
      (_db.selectOnly(_db.favorites)
            ..addColumns([_db.favorites.id])
            ..where(_key(playlistId, type, id))
            ..limit(1))
          .watch()
          .map((rows) => rows.isNotEmpty);

  Future<bool> isFavorite(int playlistId, ItemType type, String id) async =>
      await _find(playlistId, type, id) != null;

  /// Provider ids of every favorite of [type] (for star badges on cards).
  Stream<Set<String>> watchFavoriteIds(int playlistId, ItemType type) =>
      (_db.selectOnly(_db.favorites)
            ..addColumns([_db.favorites.providerId])
            ..where(
              _db.favorites.playlistId.equals(playlistId) &
                  _db.favorites.itemType.equalsValue(type),
            ))
          .watch()
          .map(
            (rows) => {for (final r in rows) r.read(_db.favorites.providerId)!},
          );

  /// Adds or removes the favorite; returns the new state.
  Future<bool> toggle(int playlistId, ItemType type, String id) =>
      _db.transaction(() async {
        final existing = await _find(playlistId, type, id);
        if (existing != null) {
          await _deleteFavorite(existing.id);
          return false;
        }
        await _insert(playlistId, type, id);
        return true;
      });

  /// Adds a favorite (no-op when it exists) and links [tagIds] (tags of
  /// other playlists are ignored). Returns the favorite id.
  Future<int> add(
    int playlistId,
    ItemType type,
    String id, {
    Iterable<int> tagIds = const [],
  }) => _db.transaction(() async {
    final existing = await _find(playlistId, type, id);
    final favoriteId = existing?.id ?? await _insert(playlistId, type, id);
    final valid = await _validTags(playlistId, tagIds);
    if (valid.isNotEmpty) {
      await _db.batch((b) {
        for (final tagId in valid) {
          b.insert(
            _db.favoriteTagLinks,
            FavoriteTagLinksCompanion.insert(
              favoriteId: favoriteId,
              tagId: tagId,
            ),
            mode: InsertMode.insertOrIgnore,
          );
        }
      });
    }
    return favoriteId;
  });

  /// Removes a favorite (and its tag links). Returns whether it existed.
  Future<bool> remove(int playlistId, ItemType type, String id) =>
      _db.transaction(() async {
        final existing = await _find(playlistId, type, id);
        if (existing == null) return false;
        await _deleteFavorite(existing.id);
        return true;
      });

  /// Favorites of [type] in [order] (custom = the drag order), optionally
  /// only those with [tagId]. Name order joins the item table (channels by
  /// display name); favorites whose item is missing sort last there.
  Stream<List<FavoriteEntry>> watchFavorites(
    int playlistId,
    ItemType type, {
    int? tagId,
    FavoritesOrder? order,
  }) {
    final effective = order ?? _defaultOrder(playlistId);
    return _favoritesQuery(
      playlistId,
      type,
      tagId,
      effective,
    ).watch().map((rows) => _mapFavorites(rows, type, effective));
  }

  /// One-shot [watchFavorites].
  Future<List<FavoriteEntry>> favorites(
    int playlistId,
    ItemType type, {
    int? tagId,
    FavoritesOrder? order,
  }) async {
    final effective = order ?? _defaultOrder(playlistId);
    final rows = await _favoritesQuery(
      playlistId,
      type,
      tagId,
      effective,
    ).get();
    return _mapFavorites(rows, type, effective);
  }

  Selectable<QueryRow> _favoritesQuery(
    int playlistId,
    ItemType type,
    int? tagId,
    FavoritesOrder order,
  ) {
    final (join, nameExpr, itemTable) = _nameJoin(type);
    final orderBy = switch (order) {
      FavoritesOrder.lastAdded ||
      FavoritesOrder.name => 'f.added_at DESC, f.id DESC',
      FavoritesOrder.leastRecent => 'f.added_at ASC, f.id ASC',
      FavoritesOrder.custom =>
        'f.custom_index IS NULL, f.custom_index, f.added_at, f.id',
    };
    final vars = <Variable<Object>>[
      Variable.withInt(playlistId),
      Variable.withInt(type.index),
    ];
    var tagClause = '';
    if (tagId != null) {
      tagClause =
          ' AND EXISTS (SELECT 1 FROM favorite_tag_links l '
          'WHERE l.favorite_id = f.id AND l.tag_id = ?)';
      vars.add(Variable.withInt(tagId));
    }
    return _db.customSelect(
      'SELECT f.id AS id, f.provider_id AS provider_id, '
      'f.added_at AS added_at, f.custom_index AS custom_index, '
      '$nameExpr AS name FROM favorites f $join '
      'WHERE f.playlist_id = ? AND f.item_type = ?$tagClause '
      'ORDER BY $orderBy',
      variables: vars,
      readsFrom: {_db.favorites, _db.favoriteTagLinks, itemTable},
    );
  }

  List<FavoriteEntry> _mapFavorites(
    List<QueryRow> rows,
    ItemType type,
    FavoritesOrder order,
  ) {
    final entries = [
      for (final r in rows)
        FavoriteEntry(
          id: r.read<int>('id'),
          type: type,
          providerId: r.read<String>('provider_id'),
          addedAt: r.read<DateTime>('added_at'),
          customIndex: r.readNullable<int>('custom_index'),
          name: r.readNullable<String>('name'),
        ),
    ];
    return List<FavoriteEntry>.unmodifiable(
      order == FavoritesOrder.name
          ? _keys.sort(entries, (e) => e.name)
          : entries,
    );
  }

  /// Custom order: [ids] in their new order. When [ids] is a subset (e.g.
  /// the favorites of one tag), they are reordered among the positions they
  /// already occupy; others keep their place. Unknown ids are ignored.
  Future<void> reorder(int playlistId, ItemType type, List<String> ids) =>
      _db.transaction(() async {
        final current = await favorites(
          playlistId,
          type,
          order: FavoritesOrder.custom,
        );
        final known = {for (final e in current) e.providerId};
        final moving = <String>[];
        final seen = <String>{};
        for (final id in ids) {
          if (known.contains(id) && seen.add(id)) moving.add(id);
        }
        final movingSet = moving.toSet();
        final result = <String>[];
        var next = 0;
        for (final e in current) {
          result.add(
            movingSet.contains(e.providerId) ? moving[next++] : e.providerId,
          );
        }
        final idOf = {for (final e in current) e.providerId: e.id};
        await _db.batch((b) {
          for (var i = 0; i < result.length; i++) {
            b.update(
              _db.favorites,
              FavoritesCompanion(customIndex: Value(i)),
              where: (f) => f.id.equals(idOf[result[i]]!),
            );
          }
        });
      });

  // -------------------------------------------------------------------------
  // Tags
  // -------------------------------------------------------------------------

  /// Tags of the playlist (custom order, then name) with counts per type.
  Stream<List<FavoriteTag>> watchTags(int playlistId) =>
      _tagsQuery(playlistId).watch().map(_mapTags);

  Future<List<FavoriteTag>> tags(int playlistId) async =>
      _mapTags(await _tagsQuery(playlistId).get());

  Selectable<QueryRow> _tagsQuery(int playlistId) => _db.customSelect(
    'SELECT t.id AS id, t.name AS name, t.sort_index AS sort_index, '
    'f.item_type AS item_type, COUNT(f.id) AS n '
    'FROM favorite_tags t '
    'LEFT JOIN favorite_tag_links l ON l.tag_id = t.id '
    'LEFT JOIN favorites f ON f.id = l.favorite_id '
    'WHERE t.playlist_id = ? '
    'GROUP BY t.id, f.item_type',
    variables: [Variable.withInt(playlistId)],
    readsFrom: {_db.favoriteTags, _db.favoriteTagLinks, _db.favorites},
  );

  List<FavoriteTag> _mapTags(List<QueryRow> rows) {
    final names = <int, String>{};
    final order = <int, int>{};
    final counts = <int, Map<ItemType, int>>{};
    for (final r in rows) {
      final id = r.read<int>('id');
      names[id] = r.read<String>('name');
      order[id] = r.read<int>('sort_index');
      final type = r.readNullable<int>('item_type');
      final n = r.read<int>('n');
      final map = counts[id] ??= {};
      if (type != null && n > 0 && type < ItemType.values.length) {
        map[ItemType.values[type]] = n;
      }
    }
    final tags = [
      for (final id in names.keys)
        FavoriteTag(
          id: id,
          name: names[id]!,
          sortIndex: order[id]!,
          counts: Map.unmodifiable(counts[id] ?? const {}),
        ),
    ];
    tags.sort((a, b) {
      final c = a.sortIndex.compareTo(b.sortIndex);
      return c != 0 ? c : _keys.compare(a.name, b.name);
    });
    return List<FavoriteTag>.unmodifiable(tags);
  }

  /// Creates a tag and returns its id. The name is trimmed; an existing tag
  /// with the same name (case- and diacritics-insensitive) is reused.
  /// Throws [ArgumentError] for a blank name.
  Future<int> createTag(int playlistId, String name) =>
      _db.transaction(() async {
        final trimmed = _cleanTagName(name);
        final existing = await _tagNamed(playlistId, trimmed);
        if (existing != null) return existing.id;
        final maxIndex = await _maxTagSortIndex(playlistId);
        return _db
            .into(_db.favoriteTags)
            .insert(
              FavoriteTagsCompanion.insert(
                playlistId: playlistId,
                name: trimmed,
                sortIndex: Value(maxIndex + 1),
              ),
            );
      });

  /// Renames a tag. Returns false when the tag does not exist or another
  /// tag already has the name. Throws [ArgumentError] for a blank name.
  Future<bool> renameTag(int tagId, String name) => _db.transaction(() async {
    final trimmed = _cleanTagName(name);
    final tag = await (_db.select(
      _db.favoriteTags,
    )..where((t) => t.id.equals(tagId))).getSingleOrNull();
    if (tag == null) return false;
    final clash = await _tagNamed(tag.playlistId, trimmed);
    if (clash != null && clash.id != tagId) return false;
    await (_db.update(_db.favoriteTags)..where((t) => t.id.equals(tagId)))
        .write(FavoriteTagsCompanion(name: Value(trimmed)));
    return true;
  });

  /// Deletes a tag (favorites stay). Returns whether it existed.
  Future<bool> deleteTag(int tagId) => _db.transaction(() async {
    await (_db.delete(
      _db.favoriteTagLinks,
    )..where((l) => l.tagId.equals(tagId))).go();
    final n = await (_db.delete(
      _db.favoriteTags,
    )..where((t) => t.id.equals(tagId))).go();
    return n > 0;
  });

  /// Custom tag order.
  Future<void> reorderTags(int playlistId, List<int> tagIds) => _db.batch((b) {
    for (var i = 0; i < tagIds.length; i++) {
      b.update(
        _db.favoriteTags,
        FavoriteTagsCompanion(sortIndex: Value(i)),
        where: (t) => t.id.equals(tagIds[i]) & t.playlistId.equals(playlistId),
      );
    }
  });

  /// Tags of a favorite (by favorite row id).
  Future<List<FavoriteTag>> tagsForFavorite(int favoriteId) async {
    final rows =
        await (_db.select(_db.favoriteTags).join([
                innerJoin(
                  _db.favoriteTagLinks,
                  _db.favoriteTagLinks.tagId.equalsExp(_db.favoriteTags.id),
                ),
              ])
              ..where(_db.favoriteTagLinks.favoriteId.equals(favoriteId))
              ..orderBy([OrderingTerm.asc(_db.favoriteTags.sortIndex)]))
            .get();
    return List.unmodifiable(
      rows
          .map((r) => r.readTable(_db.favoriteTags))
          .map(
            (t) => FavoriteTag(id: t.id, name: t.name, sortIndex: t.sortIndex),
          ),
    );
  }

  /// Tags of an item's favorite (empty when it is not a favorite).
  Future<List<FavoriteTag>> tagsFor(
    int playlistId,
    ItemType type,
    String id,
  ) async {
    final favorite = await _find(playlistId, type, id);
    return favorite == null ? const [] : tagsForFavorite(favorite.id);
  }

  /// Tag ids of an item's favorite (for the tag sheet's chip selection).
  Stream<Set<int>> watchTagIdsFor(int playlistId, ItemType type, String id) =>
      _db
          .customSelect(
            'SELECT l.tag_id AS tag_id FROM favorite_tag_links l '
            'JOIN favorites f ON f.id = l.favorite_id '
            'WHERE f.playlist_id = ? AND f.item_type = ? AND f.provider_id = ?',
            variables: [
              Variable.withInt(playlistId),
              Variable.withInt(type.index),
              Variable.withString(id),
            ],
            readsFrom: {_db.favorites, _db.favoriteTagLinks},
          )
          .watch()
          .map((rows) => {for (final r in rows) r.read<int>('tag_id')});

  /// Replaces an item's tags with [tagIds] ("Add to favorite with tags"),
  /// adding the favorite when missing. Tags of other playlists are ignored.
  Future<void> setTags(
    int playlistId,
    ItemType type,
    String id,
    Set<int> tagIds,
  ) => _db.transaction(() async {
    final existing = await _find(playlistId, type, id);
    final favoriteId = existing?.id ?? await _insert(playlistId, type, id);
    final valid = await _validTags(playlistId, tagIds);
    await (_db.delete(_db.favoriteTagLinks)..where(
          (l) => l.favoriteId.equals(favoriteId) & l.tagId.isNotIn(valid),
        ))
        .go();
    await _db.batch((b) {
      for (final tagId in valid) {
        b.insert(
          _db.favoriteTagLinks,
          FavoriteTagLinksCompanion.insert(
            favoriteId: favoriteId,
            tagId: tagId,
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  });

  // -------------------------------------------------------------------------
  // Internals
  // -------------------------------------------------------------------------

  FavoritesOrder _defaultOrder(int playlistId) => FavoritesOrder.fromSetting(
    _settings?.get(PlaylistSettings.favoritesOrder, playlistId: playlistId),
  );

  Expression<bool> _key(int playlistId, ItemType type, String id) =>
      _db.favorites.playlistId.equals(playlistId) &
      _db.favorites.itemType.equalsValue(type) &
      _db.favorites.providerId.equals(id);

  Future<FavoriteRow?> _find(int playlistId, ItemType type, String id) =>
      (_db.select(_db.favorites)
            ..where(
              (f) =>
                  f.playlistId.equals(playlistId) &
                  f.itemType.equalsValue(type) &
                  f.providerId.equals(id),
            )
            ..limit(1))
          .getSingleOrNull();

  Future<int> _insert(int playlistId, ItemType type, String id) async {
    final max = _db.favorites.customIndex.max();
    final row =
        await (_db.selectOnly(_db.favorites)
              ..addColumns([max])
              ..where(
                _db.favorites.playlistId.equals(playlistId) &
                    _db.favorites.itemType.equalsValue(type),
              ))
            .getSingle();
    final next = (row.read(max) ?? -1) + 1;
    return _db
        .into(_db.favorites)
        .insert(
          FavoritesCompanion.insert(
            playlistId: playlistId,
            itemType: type,
            providerId: id,
            addedAt: _clock(),
            customIndex: Value(next),
          ),
        );
  }

  Future<void> _deleteFavorite(int favoriteId) async {
    await (_db.delete(
      _db.favoriteTagLinks,
    )..where((l) => l.favoriteId.equals(favoriteId))).go();
    await (_db.delete(
      _db.favorites,
    )..where((f) => f.id.equals(favoriteId))).go();
  }

  Future<List<int>> _validTags(int playlistId, Iterable<int> tagIds) async {
    final ids = tagIds.toSet();
    if (ids.isEmpty) return const [];
    final rows =
        await (_db.selectOnly(_db.favoriteTags)
              ..addColumns([_db.favoriteTags.id])
              ..where(
                _db.favoriteTags.playlistId.equals(playlistId) &
                    _db.favoriteTags.id.isIn(ids),
              ))
            .get();
    return [for (final r in rows) r.read(_db.favoriteTags.id)!];
  }

  static String _cleanTagName(String name) {
    final trimmed = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Tag name is blank');
    }
    return trimmed;
  }

  /// A tag whose name equals [name] ignoring case and diacritics.
  Future<FavoriteTagRow?> _tagNamed(int playlistId, String name) async {
    final rows = await (_db.select(
      _db.favoriteTags,
    )..where((t) => t.playlistId.equals(playlistId))).get();
    final key = normalizeForSearch(name);
    for (final t in rows) {
      if (t.name == name) return t;
    }
    if (key.isEmpty) return null;
    for (final t in rows) {
      if (normalizeForSearch(t.name) == key) return t;
    }
    return null;
  }

  Future<int> _maxTagSortIndex(int playlistId) async {
    final max = _db.favoriteTags.sortIndex.max();
    final row =
        await (_db.selectOnly(_db.favoriteTags)
              ..addColumns([max])
              ..where(_db.favoriteTags.playlistId.equals(playlistId)))
            .getSingle();
    return row.read(max) ?? -1;
  }

  /// `(join, name expression, item table)` for the name of [type].
  (String, String, ResultSetImplementation<dynamic, dynamic>) _nameJoin(
    ItemType type,
  ) => switch (type) {
    ItemType.channel => (
      'LEFT JOIN channels i ON i.playlist_id = f.playlist_id '
          'AND i.provider_id = f.provider_id',
      'i.display_name',
      _db.channels,
    ),
    ItemType.movie => (
      'LEFT JOIN movies i ON i.playlist_id = f.playlist_id '
          'AND i.provider_id = f.provider_id',
      'i.name',
      _db.movies,
    ),
    ItemType.series => (
      'LEFT JOIN series i ON i.playlist_id = f.playlist_id '
          'AND i.provider_id = f.provider_id',
      'i.name',
      _db.series,
    ),
    ItemType.episode => (
      'LEFT JOIN episodes i ON i.playlist_id = f.playlist_id '
          'AND i.provider_id = f.provider_id',
      'i.title',
      _db.episodes,
    ),
  };
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
  (ref) => FavoritesRepository(
    db: ref.watch(appDatabaseProvider),
    settings: ref.watch(settingsStoreProvider),
  ),
);

/// Arguments for per-item providers.
typedef FavoriteKeyArgs = ({int playlistId, ItemType type, String providerId});

/// Star state of one item.
final isFavoriteProvider = StreamProvider.autoDispose
    .family<bool, FavoriteKeyArgs>(
      (ref, a) => ref
          .watch(favoritesRepositoryProvider)
          .watchIsFavorite(a.playlistId, a.type, a.providerId),
    );

/// Favorites of a type (order from the favorites order setting).
final favoritesProvider = StreamProvider.autoDispose
    .family<List<FavoriteEntry>, ({int playlistId, ItemType type, int? tagId})>(
      (ref, a) {
        final order = FavoritesOrder.fromSetting(
          ref.watchSetting(
            PlaylistSettings.favoritesOrder,
            playlistId: a.playlistId,
          ),
        );
        return ref
            .watch(favoritesRepositoryProvider)
            .watchFavorites(a.playlistId, a.type, tagId: a.tagId, order: order);
      },
    );

/// Tags with counts (sidebar sub-categories).
final favoriteTagsProvider = StreamProvider.autoDispose
    .family<List<FavoriteTag>, int>(
      (ref, playlistId) =>
          ref.watch(favoritesRepositoryProvider).watchTags(playlistId),
    );

/// Selected tag ids of one item (tag sheet).
final favoriteTagIdsProvider = StreamProvider.autoDispose
    .family<Set<int>, FavoriteKeyArgs>(
      (ref, a) => ref
          .watch(favoritesRepositoryProvider)
          .watchTagIdsFor(a.playlistId, a.type, a.providerId),
    );
