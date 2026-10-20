import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/app_paths.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/repositories/favorites_repository.dart';
import 'package:carina/data/repositories/parental_service.dart';
import 'package:carina/data/repositories/repository_models.dart'
    show lastWatchedLimit;
import 'package:carina/data/repositories/search_repository.dart';
import 'package:carina/data/repositories/vod_repository.dart';
import 'package:carina/data/repositories/watch_state_repository.dart';
import 'package:carina/data/secrets/secret_store.dart';
import 'package:carina/data/settings/settings_store.dart';

import 'r2_fixtures.dart';

void main() {
  late R2Env env;
  late VodRepository repo;
  late FavoritesRepository favorites;
  late WatchStateRepository watch;
  late int pid;

  setUp(() async {
    env = await R2Env.create();
    repo = VodRepository(
      db: env.db,
      settings: env.settings,
      secrets: env.secrets,
      clock: env.clock,
    );
    favorites = FavoritesRepository(
      db: env.db,
      settings: env.settings,
      clock: env.clock,
    );
    watch = WatchStateRepository(
      db: env.db,
      settings: env.settings,
      clock: env.clock,
    );
    pid = await env.playlist();
    final now = env.now;
    await env.category(pid, SectionKind.movie, 'A', 'Açık');
    await env.category(pid, SectionKind.movie, 'H', 'Gizli', hidden: true);
    await env.category(pid, SectionKind.movie, 'L', 'Kilitli', locked: true);
    await env.movie(
      pid,
      'a1',
      'Bir',
      categoryId: 'A',
      sortIndex: 0,
      rating: 5,
      added: now.subtract(const Duration(days: 1)),
    );
    await env.movie(
      pid,
      'a2',
      'Altı',
      categoryId: 'A',
      sortIndex: 1,
      rating: 9,
      added: now.subtract(const Duration(days: 10)),
    );
    await env.movie(
      pid,
      'h1',
      'Gizli Film',
      categoryId: 'H',
      sortIndex: 2,
      added: now.subtract(const Duration(days: 1)),
    );
    await env.movie(
      pid,
      'l1',
      'Kilitli Film',
      categoryId: 'L',
      sortIndex: 3,
      rating: 7,
      added: now.subtract(const Duration(days: 2)),
    );
    await env.movie(pid, 'x1', 'Saklı', categoryId: 'A', hidden: true);
  });

  tearDown(() async {
    repo.dispose();
    await env.close();
  });

  void tick() => env.now = env.now.add(const Duration(minutes: 1));

  Future<List<String>> ids(
    CategoryRef ref, {
    VodSort sort = VodSort.playlist,
    bool excludeLocked = false,
    FavoritesOrder? order,
    SectionKind kind = SectionKind.movie,
    int? limit,
  }) async => [
    for (final i
        in await repo
            .watchCategoryItems(
              pid,
              kind,
              ref,
              sort: sort,
              excludeLocked: excludeLocked,
              favoritesOrder: order,
              limit: limit,
            )
            .first)
      i.providerId,
  ];

  test('provider categories list their items even when hidden', () async {
    expect(await ids(const ProviderCategory('A')), ['a1', 'a2']);
    expect(await ids(const ProviderCategory('H')), ['h1']);
    expect(await ids(const ProviderCategory('L'), excludeLocked: true), ['l1']);
  });

  test('All and Recently added follow the sidebar visibility', () async {
    expect(await ids(const AllCategory()), ['a1', 'a2', 'l1']);
    expect(await ids(const AllCategory(), excludeLocked: true), ['a1', 'a2']);
    expect(await ids(const RecentlyAddedCategory()), ['a1', 'l1']);
    expect(await ids(const RecentlyAddedCategory(), excludeLocked: true), [
      'a1',
    ]);
    expect(await ids(const RecentlyAddedCategory(), sort: VodSort.rating), [
      'l1',
      'a1',
    ]);
  });

  test('Favorites: tag, order, hidden and locked categories', () async {
    for (final id in ['a1', 'h1', 'l1', 'a2']) {
      await favorites.add(pid, ItemType.movie, id);
      tick();
    }
    final tag = await favorites.createTag(pid, 'Akşam');
    await favorites.setTags(pid, ItemType.movie, 'a2', {tag});

    expect(await ids(const FavoritesCategory()), ['a2', 'l1', 'a1']);
    expect(await ids(const FavoritesCategory(), excludeLocked: true), [
      'a2',
      'a1',
    ]);
    expect(await ids(FavoritesCategory(tagId: tag)), ['a2']);
    expect(
      await ids(const FavoritesCategory(), order: FavoritesOrder.leastRecent),
      ['a1', 'l1', 'a2'],
    );
    // Favorites order "name" sorts by name (collated).
    expect(await ids(const FavoritesCategory(), order: FavoritesOrder.name), [
      'a2', // Altı
      'a1', // Bir
      'l1', // Kilitli Film
    ]);
    // An explicit grid sort wins over the favorites order.
    expect(await ids(const FavoritesCategory(), sort: VodSort.rating), [
      'a2',
      'l1',
      'a1',
    ]);
    // Same visibility as the sidebar count (R1 CategoryRepository).
    await env.settings.set(
      PlaylistSettings.favoritesOrder,
      'custom',
      playlistId: pid,
    );
    expect(await ids(const FavoritesCategory()), ['a1', 'l1', 'a2']);
  });

  test('Last watched: most recent first, capped, sortable', () async {
    for (final id in ['a2', 'h1', 'a1']) {
      tick();
      await watch.save(
        pid,
        ItemType.movie,
        id,
        const Duration(minutes: 1),
        const Duration(minutes: 90),
      );
    }
    expect(await ids(const LastWatchedCategory()), ['a1', 'a2']);
    expect(await ids(const LastWatchedCategory(), sort: VodSort.rating), [
      'a2',
      'a1',
    ]);

    for (var i = 0; i < 55; i++) {
      await env.movie(pid, 'p$i', 'Film $i', categoryId: 'A');
      tick();
      await watch.save(
        pid,
        ItemType.movie,
        'p$i',
        Duration.zero,
        const Duration(minutes: 90),
      );
    }
    final last = await ids(const LastWatchedCategory());
    expect(last, hasLength(lastWatchedLimit));
    expect(last.first, 'p54');
    expect(await ids(const LastWatchedCategory(), limit: 3), [
      'p54',
      'p53',
      'p52',
    ]);

    await env.series(pid, 'S1', 'Dizi Bir');
    await env.series(pid, 'S2', 'Dizi İki');
    await watch.save(
      pid,
      ItemType.episode,
      'e2',
      Duration.zero,
      Duration.zero,
      seriesId: 'S2',
    );
    tick();
    await watch.save(
      pid,
      ItemType.episode,
      'e1',
      Duration.zero,
      Duration.zero,
      seriesId: 'S1',
    );
    expect(await ids(const LastWatchedCategory(), kind: SectionKind.series), [
      'S1',
      'S2',
    ]);
  });

  test('continue watching leaves out hidden and locked categories', () async {
    for (final id in ['a1', 'h1', 'l1']) {
      tick();
      await watch.save(
        pid,
        ItemType.movie,
        id,
        const Duration(minutes: 30),
        const Duration(minutes: 90),
      );
    }
    List<String> of(List<ContinueWatchingEntry> l) => [
      for (final e in l) e.item.providerId,
    ];
    expect(of(await watch.continueWatchingMovies(pid)), ['l1', 'a1']);
    expect(of(await watch.continueWatchingMovies(pid, excludeLocked: true)), [
      'a1',
    ]);

    await env.category(pid, SectionKind.series, 'SL', 'Kilitli', locked: true);
    await env.series(pid, 'S', 'Dizi', categoryId: 'SL');
    await env.episode(pid, 'S', 'e1', 1, 1);
    await watch.save(
      pid,
      ItemType.episode,
      'e1',
      const Duration(minutes: 10),
      const Duration(minutes: 40),
      seriesId: 'S',
    );
    expect(of(await watch.continueWatchingShows(pid)), ['S']);
    expect(
      of(await watch.continueWatchingShows(pid, excludeLocked: true)),
      isEmpty,
    );
  });

  test('home rows, hero and trending use the same visibility', () async {
    final rows = await repo.homeRows(
      pid,
      SectionKind.movie,
      excludeLocked: true,
    );
    expect(rows.map((r) => r.category.providerId), ['A']);
    await (env.db.update(env.db.movies))
        .write(const MoviesCompanion(poster: Value('p')));
    final hero = await repo.heroCandidates(
      pid,
      SectionKind.movie,
      excludeLocked: true,
    );
    expect(hero.map((i) => i.providerId), isNot(contains('l1')));
    expect(hero.map((i) => i.providerId), isNot(contains('h1')));
    await env.index(pid, 'movie', 'l1', 'Kilitli Film');
    expect(
      await repo.matchTrending(pid, SectionKind.movie, [
        (tmdbId: null, title: 'Kilitli Film', originalTitle: null, year: null),
      ], excludeLocked: true),
      isEmpty,
    );
  });

  group('providers', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(env.db),
          settingsStoreProvider.overrideWithValue(env.settings),
          secretStoreProvider.overrideWithValue(env.secrets),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('parental hide mode and session unlocks, like the sidebar', () async {
      final VodCategoryArgs args = (
        playlistId: pid,
        kind: SectionKind.movie,
        category: const AllCategory(),
        sort: VodSort.playlist,
        filter: null,
      );
      final grid = vodCategoryItemsProvider(args);
      List<String> names(List<VodItem> l) => [for (final i in l) i.providerId];

      container.listen(grid, (_, _) {});
      expect(names(await container.read(grid.future)), ['a1', 'a2', 'l1']);

      await env.settings.set(
        PlaylistSettings.parentalMode,
        'hide',
        playlistId: pid,
      );
      expect(names(await container.read(grid.future)), ['a1', 'a2']);

      final rowsProvider = vodHomeRowsProvider((
        playlistId: pid,
        kind: SectionKind.movie,
      ));
      container.listen(rowsProvider, (_, _) {});
      final rows = await container.read(rowsProvider.future);
      expect(rows.map((r) => r.category.providerId), ['A']);

      await env.index(pid, 'movie', 'l1', 'Kilitli Film');
      final search = searchResultsProvider((
        playlistId: pid,
        query: 'kilitli',
        filter: SearchFilter.all,
      ));
      container.listen(search, (_, _) {});
      expect((await container.read(search.future)).movies, isEmpty);

      container.read(parentalSessionProvider.notifier).unlockAll(pid);
      expect(names(await container.read(grid.future)), ['a1', 'a2', 'l1']);
      expect(
        (await container.read(rowsProvider.future))
            .map((r) => r.category.providerId),
        ['A', 'L'],
      );
      expect(
        (await container.read(search.future)).movies.map((m) => m.providerId),
        ['l1'],
      );
    });
  });
}
