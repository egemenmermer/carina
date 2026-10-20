/// The category sidebar of TV Live, Movies and Shows: special
/// entries, provider categories in the chosen order, item counts, local
/// renames, hiding, locking and the custom order.
library;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_paths.dart' show appDatabaseProvider;
import '../db/database.dart';
import '../settings/settings_store.dart';
import '../text/flags.dart';
import 'parental_service.dart' show parentalSessionProvider;
import 'repository_models.dart';

/// Builds sidebar entries and edits provider categories.
///
/// Counting rules (shared with `LiveRepository` so a count always equals
/// the length of the list it opens):
/// * hidden items never count;
/// * with parental mode `hide`, locked categories are left out of the
///   sidebar and locked channels do not count (unless [revealLocked]);
/// * special entries (Favorites, tags, Last watched, Recently added) leave
///   out items whose category is hidden; a provider category counts its own
///   items even while it is hidden (Settings → Hidden items).
///
/// Rows still flagged `removed` by a running import are kept, so the
/// sidebar stays stable while a reload is in progress.
class CategoryRepository {
  CategoryRepository(this._db, this._settings, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final SettingsStore _settings;
  final DateTime Function() _clock;

  // -------------------------------------------------------------------------
  // Sidebar
  // -------------------------------------------------------------------------

  /// Sidebar entries of [kind]: Favorites (+ one entry per tag that has
  /// items of [kind]), Last watched (live, when enabled), Recently added
  /// (when enabled), then the provider categories in the
  /// `categoriesOrder` setting's order. Updates when categories, items,
  /// favorites or the relevant settings change.
  Stream<List<CategoryView>> watchCategories(
    int playlistId,
    SectionKind kind, {
    bool includeHidden = false,
    bool revealLocked = false,
  }) => watchComputed(
    db: _db,
    tables: _tablesFor(kind),
    compute: () => categories(
      playlistId,
      kind,
      includeHidden: includeHidden,
      revealLocked: revealLocked,
    ),
    settings: _settings,
    settingsKey: () => _options(playlistId),
  );

  /// One-shot [watchCategories].
  Future<List<CategoryView>> categories(
    int playlistId,
    SectionKind kind, {
    bool includeHidden = false,
    bool revealLocked = false,
  }) async {
    final o = _options(playlistId);
    final hideLocked = o.hideLocked && !revealLocked;
    final spec = _ItemSpec.of(kind);
    final out = <CategoryView>[];

    final favorites = await _favoriteCounts(playlistId, spec, hideLocked);
    out.add(
      CategoryView(
        ref: const FavoritesCategory(),
        kind: kind,
        name: 'Favorites',
        label: 'Favorites',
        count: favorites.total,
      ),
    );
    final tags =
        await (_db.select(_db.favoriteTags)
              ..where((t) => t.playlistId.equals(playlistId))
              ..orderBy([(t) => OrderingTerm(expression: t.sortIndex)]))
            .get();
    final sortedTags = _stableSort(
      tags,
      (a, b) => a.sortIndex != b.sortIndex
          ? a.sortIndex.compareTo(b.sortIndex)
          : compareCollated(a.name, b.name, turkish: o.turkish),
    );
    for (final tag in sortedTags) {
      final n = favorites.byTag[tag.id] ?? 0;
      if (n == 0) continue;
      out.add(
        CategoryView(
          ref: FavoritesCategory(tagId: tag.id),
          kind: kind,
          name: tag.name,
          label: tag.name,
          count: n,
          depth: 1,
        ),
      );
    }

    if (kind == SectionKind.live && o.showLastWatched) {
      out.add(
        CategoryView(
          ref: const LastWatchedCategory(),
          kind: kind,
          name: 'Last watched',
          label: 'Last watched',
          count: await _lastWatchedCount(playlistId, hideLocked),
        ),
      );
    }
    if (o.showRecentlyAdded) {
      out.add(
        CategoryView(
          ref: const RecentlyAddedCategory(),
          kind: kind,
          name: 'Recently added',
          label: 'Recently added',
          count: await _recentCount(playlistId, spec, hideLocked),
        ),
      );
    }

    final rows =
        await (_db.select(_db.categories)..where(
              (c) => c.playlistId.equals(playlistId) & c.kind.equalsValue(kind),
            ))
            .get();
    final counts = await _countsByCategory(playlistId, spec, hideLocked);
    final views = [
      for (final row in rows)
        if ((includeHidden || !row.hidden) && !(hideLocked && row.locked))
          _view(row, counts[row.providerId] ?? 0),
    ];
    out.addAll(_order(views, o.order, o.turkish));
    return out;
  }

  /// One provider category (any state), or null.
  Future<CategoryView?> category(
    int playlistId,
    SectionKind kind,
    String providerId,
  ) async {
    final row = await _row(playlistId, kind, providerId);
    if (row == null) return null;
    final o = _options(playlistId);
    final counts = await _countsByCategory(
      playlistId,
      _ItemSpec.of(kind),
      o.hideLocked,
      categoryId: providerId,
    );
    return _view(row, counts[providerId] ?? 0);
  }

  // -------------------------------------------------------------------------
  // Settings lists
  // -------------------------------------------------------------------------

  /// Hidden categories of every kind (Settings → Playlist Management →
  /// Hidden items), live first, then by name.
  Stream<List<CategoryView>> hiddenCategories(int playlistId) =>
      _watchFiltered(playlistId, (c) => c.hidden.equals(true));

  /// Locked categories of every kind (Settings → Parental Control).
  Stream<List<CategoryView>> lockedCategories(int playlistId) =>
      _watchFiltered(playlistId, (c) => c.locked.equals(true));

  /// Locally renamed categories (Settings → Rename categories).
  Stream<List<CategoryView>> renamedCategories(int playlistId) =>
      _watchFiltered(playlistId, (c) => c.localName.isNotNull());

  /// One-shot [lockedCategories].
  Future<List<CategoryView>> lockedCategoriesOnce(int playlistId) =>
      _filtered(playlistId, (c) => c.locked.equals(true));

  Stream<List<CategoryView>> _watchFiltered(
    int playlistId,
    Expression<bool> Function($CategoriesTable c) filter,
  ) => watchComputed(
    db: _db,
    tables: [_db.categories, _db.channels, _db.movies, _db.series],
    compute: () => _filtered(playlistId, filter),
    settings: _settings,
    settingsKey: () => isTurkishCollation(_settings),
  );

  Future<List<CategoryView>> _filtered(
    int playlistId,
    Expression<bool> Function($CategoriesTable c) filter,
  ) async {
    final rows = await (_db.select(
      _db.categories,
    )..where((c) => c.playlistId.equals(playlistId) & filter(c))).get();
    final turkish = isTurkishCollation(_settings);
    final out = <CategoryView>[];
    for (final kind in SectionKind.values) {
      final ofKind = rows.where((r) => r.kind == kind).toList();
      if (ofKind.isEmpty) continue;
      final counts = await _countsByCategory(
        playlistId,
        _ItemSpec.of(kind),
        false,
      );
      out.addAll(
        sortCollated(
          [for (final r in ofKind) _view(r, counts[r.providerId] ?? 0)],
          (v) => v.name,
          turkish: turkish,
        ),
      );
    }
    return out;
  }

  // -------------------------------------------------------------------------
  // Mutations
  // -------------------------------------------------------------------------

  /// Local rename; null, blank or the provider name resets it.
  Future<void> rename(
    int playlistId,
    SectionKind kind,
    String providerId,
    String? name,
  ) async {
    final row = await _row(playlistId, kind, providerId);
    if (row == null) return;
    final trimmed = name?.trim();
    final local = (trimmed == null || trimmed.isEmpty || trimmed == row.name)
        ? null
        : trimmed;
    await (_db.update(_db.categories)..where((c) => c.id.equals(row.id))).write(
      CategoriesCompanion(localName: Value(local)),
    );
  }

  Future<void> setHidden(
    int playlistId,
    SectionKind kind,
    String providerId,
    bool hidden,
  ) => _write(
    playlistId,
    kind,
    providerId,
    CategoriesCompanion(hidden: Value(hidden)),
  );

  Future<void> setLocked(
    int playlistId,
    SectionKind kind,
    String providerId,
    bool locked,
  ) => _write(
    playlistId,
    kind,
    providerId,
    CategoriesCompanion(locked: Value(locked)),
  );

  /// Custom order ("Reorder" mode): [providerIds] get `customIndex` 0, 1, 2…
  /// and every other category of [kind] none (they follow in provider
  /// order). Switches `categoriesOrder` to `custom`.
  Future<void> reorder(
    int playlistId,
    SectionKind kind,
    List<String> providerIds,
  ) async {
    await _db.transaction(() async {
      await (_db.update(_db.categories)..where(
            (c) => c.playlistId.equals(playlistId) & c.kind.equalsValue(kind),
          ))
          .write(const CategoriesCompanion(customIndex: Value(null)));
      for (final (index, id) in providerIds.indexed) {
        await (_db.update(_db.categories)..where(
              (c) =>
                  c.playlistId.equals(playlistId) &
                  c.kind.equalsValue(kind) &
                  c.providerId.equals(id),
            ))
            .write(CategoriesCompanion(customIndex: Value(index)));
      }
    });
    if (_settings.get(
          PlaylistSettings.categoriesOrder,
          playlistId: playlistId,
        ) !=
        'custom') {
      await _settings.set(
        PlaylistSettings.categoriesOrder,
        'custom',
        playlistId: playlistId,
      );
    }
  }

  Future<void> _write(
    int playlistId,
    SectionKind kind,
    String providerId,
    CategoriesCompanion companion,
  ) =>
      (_db.update(_db.categories)..where(
            (c) =>
                c.playlistId.equals(playlistId) &
                c.kind.equalsValue(kind) &
                c.providerId.equals(providerId),
          ))
          .write(companion);

  // -------------------------------------------------------------------------
  // Counting
  // -------------------------------------------------------------------------

  Future<({int total, Map<int, int> byTag})> _favoriteCounts(
    int playlistId,
    _ItemSpec s,
    bool hideLocked,
  ) async {
    final from =
        'FROM favorites f '
        'JOIN ${s.table} i ON i.playlist_id = f.playlist_id '
        'AND i.provider_id = f.provider_id '
        '${s.categoryJoin}';
    final where =
        'f.playlist_id = ? AND f.item_type = ? AND '
        '${s.visible(hideLocked: hideLocked)}';
    final vars = [
      Variable.withInt(playlistId),
      Variable.withInt(s.itemType.index),
    ];
    final total = await _db
        .customSelect(
          'SELECT COUNT(*) AS n $from WHERE $where',
          variables: vars,
        )
        .getSingle();
    final tagRows = await _db
        .customSelect(
          'SELECT l.tag_id AS tag, COUNT(*) AS n $from '
          'JOIN favorite_tag_links l ON l.favorite_id = f.id '
          'WHERE $where GROUP BY l.tag_id',
          variables: vars,
        )
        .get();
    return (
      total: total.read<int>('n'),
      byTag: {for (final r in tagRows) r.read<int>('tag'): r.read<int>('n')},
    );
  }

  Future<int> _lastWatchedCount(int playlistId, bool hideLocked) async {
    const s = _ItemSpec.live;
    final row = await _db
        .customSelect(
          'SELECT COUNT(*) AS n FROM ('
          'SELECT lw.channel_id FROM last_watched_live lw '
          'JOIN channels i ON i.playlist_id = lw.playlist_id '
          'AND i.provider_id = lw.channel_id ${s.categoryJoin} '
          'WHERE lw.playlist_id = ? AND ${s.visible(hideLocked: hideLocked)} '
          'LIMIT $lastWatchedLimit)',
          variables: [Variable.withInt(playlistId)],
        )
        .getSingle();
    return row.read<int>('n');
  }

  Future<int> _recentCount(int playlistId, _ItemSpec s, bool hideLocked) async {
    final since = _clock().subtract(recentlyAddedWindow);
    final row = await _db
        .customSelect(
          'SELECT COUNT(*) AS n FROM ${s.table} i ${s.categoryJoin} '
          'WHERE i.playlist_id = ? AND ${s.visible(hideLocked: hideLocked)} '
          'AND i.${s.addedColumn} >= ?',
          variables: [Variable.withInt(playlistId), Variable<DateTime>(since)],
        )
        .getSingle();
    return row.read<int>('n');
  }

  /// Visible items per provider category id (the category's own hidden /
  /// locked flags are not applied here).
  Future<Map<String?, int>> _countsByCategory(
    int playlistId,
    _ItemSpec s,
    bool hideLocked, {
    String? categoryId,
  }) async {
    final rows = await _db
        .customSelect(
          'SELECT i.category_id AS cid, COUNT(*) AS n FROM ${s.table} i '
          'WHERE i.playlist_id = ? AND i.hidden = 0'
          '${hideLocked && s.hasLock ? ' AND i.locked = 0' : ''}'
          '${categoryId != null ? ' AND i.category_id = ?' : ''} '
          'GROUP BY i.category_id',
          variables: [
            Variable.withInt(playlistId),
            if (categoryId != null) Variable.withString(categoryId),
          ],
        )
        .get();
    return {
      for (final r in rows) r.readNullable<String>('cid'): r.read<int>('n'),
    };
  }

  // -------------------------------------------------------------------------

  Future<CategoryRow?> _row(
    int playlistId,
    SectionKind kind,
    String providerId,
  ) =>
      (_db.select(_db.categories)..where(
            (c) =>
                c.playlistId.equals(playlistId) &
                c.kind.equalsValue(kind) &
                c.providerId.equals(providerId),
          ))
          .getSingleOrNull();

  CategoryView _view(CategoryRow row, int count) {
    final local = row.localName?.trim();
    final name = (local == null || local.isEmpty) ? row.name : local;
    final parsed = parseCategoryFlag(name);
    return CategoryView(
      ref: ProviderCategory(row.providerId),
      kind: row.kind,
      name: name,
      flag: parsed.flag,
      label: parsed.label,
      count: count,
      hidden: row.hidden,
      locked: row.locked,
      row: row,
    );
  }

  List<CategoryView> _order(
    List<CategoryView> views,
    String order,
    bool turkish,
  ) {
    int byProvider(CategoryView a, CategoryView b) {
      final c = a.row!.sortIndex.compareTo(b.row!.sortIndex);
      return c != 0 ? c : a.row!.id.compareTo(b.row!.id);
    }

    switch (order) {
      case 'name':
        return sortCollated(views, (v) => v.name, turkish: turkish);
      case 'custom':
        return _stableSort(views, (a, b) {
          final ai = a.row!.customIndex;
          final bi = b.row!.customIndex;
          if (ai != null && bi != null && ai != bi) return ai.compareTo(bi);
          if ((ai == null) != (bi == null)) return ai == null ? 1 : -1;
          return byProvider(a, b);
        });
      default:
        return _stableSort(views, byProvider);
    }
  }

  _SidebarOptions _options(int playlistId) {
    final s = _settings;
    return (
      order: s.get(PlaylistSettings.categoriesOrder, playlistId: playlistId),
      showLastWatched: s.get(
        PlaylistSettings.showLastWatched,
        playlistId: playlistId,
      ),
      showRecentlyAdded: s.get(
        PlaylistSettings.showRecentlyAdded,
        playlistId: playlistId,
      ),
      hideLocked:
          s.get(PlaylistSettings.parentalMode, playlistId: playlistId) ==
          'hide',
      turkish: isTurkishCollation(s),
    );
  }

  List<ResultSetImplementation<dynamic, dynamic>> _tablesFor(
    SectionKind kind,
  ) => [
    _db.categories,
    switch (kind) {
      SectionKind.live => _db.channels,
      SectionKind.movie => _db.movies,
      SectionKind.series => _db.series,
    },
    _db.favorites,
    _db.favoriteTags,
    _db.favoriteTagLinks,
    if (kind == SectionKind.live) _db.lastWatchedLive,
  ];
}

typedef _SidebarOptions = ({
  String order,
  bool showLastWatched,
  bool showRecentlyAdded,
  bool hideLocked,
  bool turkish,
});

/// The item table behind a [SectionKind] (alias `i`, category alias `cat`).
class _ItemSpec {
  const _ItemSpec(
    this.kind,
    this.table,
    this.itemType,
    this.addedColumn, {
    required this.hasLock,
  });

  static const live = _ItemSpec(
    SectionKind.live,
    'channels',
    ItemType.channel,
    'added',
    hasLock: true,
  );
  static const movie = _ItemSpec(
    SectionKind.movie,
    'movies',
    ItemType.movie,
    'added',
    hasLock: false,
  );
  static const series = _ItemSpec(
    SectionKind.series,
    'series',
    ItemType.series,
    'last_modified',
    hasLock: false,
  );

  static _ItemSpec of(SectionKind kind) => switch (kind) {
    SectionKind.live => live,
    SectionKind.movie => movie,
    SectionKind.series => series,
  };

  final SectionKind kind;
  final String table;
  final ItemType itemType;

  /// "Recently added" date.
  final String addedColumn;

  /// The item table has its own `locked` column (channels only).
  final bool hasLock;

  String get categoryJoin =>
      'LEFT JOIN categories cat ON cat.playlist_id = i.playlist_id '
      'AND cat.kind = ${kind.index} AND cat.provider_id = i.category_id';

  /// Visible in special entries: not hidden, category not hidden; with
  /// [hideLocked] neither the item nor its category locked.
  String visible({required bool hideLocked}) => [
    'i.hidden = 0',
    'COALESCE(cat.hidden, 0) = 0',
    if (hideLocked) 'COALESCE(cat.locked, 0) = 0',
    if (hideLocked && hasLock) 'i.locked = 0',
  ].join(' AND ');
}

/// [List.sort] is not stable; this is (merge sort on indices).
List<T> _stableSort<T>(Iterable<T> items, int Function(T a, T b) compare) {
  final indexed = items.indexed.toList()
    ..sort((a, b) {
      final c = compare(a.$2, b.$2);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
  return [for (final e in indexed) e.$2];
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => CategoryRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(settingsStoreProvider),
  ),
);

/// Arguments of [categoriesProvider].
typedef CategoryListArgs = ({int playlistId, SectionKind kind});

/// Sidebar entries; locked categories are revealed in parental `hide` mode
/// after the PIN unlocked everything for the session.
final categoriesProvider = StreamProvider.autoDispose
    .family<List<CategoryView>, CategoryListArgs>((ref, args) {
      final reveal = ref.watch(
        parentalSessionProvider.select(
          (s) => s.allUnlockedFor(args.playlistId),
        ),
      );
      return ref
          .watch(categoryRepositoryProvider)
          .watchCategories(args.playlistId, args.kind, revealLocked: reveal);
    });

/// Settings → Hidden items (categories).
final hiddenCategoriesProvider = StreamProvider.autoDispose
    .family<List<CategoryView>, int>(
      (ref, playlistId) =>
          ref.watch(categoryRepositoryProvider).hiddenCategories(playlistId),
    );

/// Settings → Rename categories.
final renamedCategoriesProvider = StreamProvider.autoDispose
    .family<List<CategoryView>, int>(
      (ref, playlistId) =>
          ref.watch(categoryRepositoryProvider).renamedCategories(playlistId),
    );
