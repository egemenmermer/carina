import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/repositories/category_repository.dart';
import 'package:carina/data/repositories/repository_models.dart';
import 'package:carina/data/settings/settings_store.dart';

import 'fixtures.dart';

void main() {
  late R1Env env;
  late CategoryRepository repo;
  late int pid;
  final clock = FakeClock(DateTime(2026, 10, 17, 20));

  /// Live: c1 "TR | Ulusal" (2 visible + 1 hidden + 1 locked), c2 "Belgesel"
  /// (2), c3 "Çocuk" (1), c4 "Spor" hidden (2), c5 "Yetişkin" locked (1).
  setUp(() async {
    env = await R1Env.create();
    repo = CategoryRepository(env.db, env.settings, clock: clock.call);
    pid = await env.playlist();
    await env.category(pid, 'c1', 'TR | Ulusal', sortIndex: 2);
    await env.category(pid, 'c2', 'Belgesel', sortIndex: 0);
    await env.category(pid, 'c3', 'Çocuk', sortIndex: 1);
    await env.category(pid, 'c4', 'Spor', sortIndex: 3, hidden: true);
    await env.category(pid, 'c5', 'Yetişkin', sortIndex: 4, locked: true);
    final recent = clock.now.subtract(const Duration(days: 2));
    final old = clock.now.subtract(const Duration(days: 30));
    await env.channel(pid, '1', 'TRT 1', categoryId: 'c1', added: recent);
    await env.channel(pid, '2', 'Show TV', categoryId: 'c1', added: old);
    await env.channel(pid, '3', 'Gizli', categoryId: 'c1', hidden: true);
    await env.channel(pid, '4', 'Kilitli', categoryId: 'c1', locked: true);
    await env.channel(pid, '5', 'Belgesel 1', categoryId: 'c2', added: recent);
    await env.channel(pid, '6', 'Belgesel 2', categoryId: 'c2');
    await env.channel(pid, '7', 'Minika', categoryId: 'c3');
    await env.channel(pid, '8', 'Spor 1', categoryId: 'c4', added: recent);
    await env.channel(pid, '9', 'Spor 2', categoryId: 'c4');
    await env.channel(pid, '10', 'Gece', categoryId: 'c5');
    final news = await env.tag(pid, 'Haber');
    await env.tag(pid, 'Boş');
    await env.favorite(pid, '1', tags: [news]);
    await env.favorite(pid, '5');
    await env.favorite(pid, '8', tags: [news]); // hidden category
    await env.favorite(pid, '10'); // locked category
    await env.lastWatched(pid, '2', clock.now);
    await env.lastWatched(pid, '9', clock.now); // hidden category
  });
  tearDown(() => env.dispose());

  String summary(List<CategoryView> list) => list
      .map((c) => '${'  ' * c.depth}${c.ref.key} ${c.name} ${c.count}')
      .join('\n');

  test('specials first, then provider categories in playlist order', () async {
    final list = await repo.categories(pid, SectionKind.live);
    expect(
      summary(list),
      [
        'fav Favorites 3',
        '  fav:1 Haber 1',
        'last Last watched 1',
        'recent Recently added 2',
        'p:c2 Belgesel 2',
        'p:c3 Çocuk 1',
        'p:c1 TR | Ulusal 3',
        'p:c5 Yetişkin 1',
      ].join('\n'),
    );
    final ulusal = list.firstWhere((c) => c.providerId == 'c1');
    expect(ulusal.flag, '🇹🇷');
    expect(ulusal.label, 'Ulusal');
    expect(ulusal.title, '🇹🇷 Ulusal');
    expect(ulusal.row!.name, 'TR | Ulusal');
    expect(list.firstWhere((c) => c.providerId == 'c5').locked, isTrue);
    expect(list.first.isSpecial, isTrue);
  });

  test('includeHidden lists hidden categories with their own counts', () async {
    final list = await repo.categories(
      pid,
      SectionKind.live,
      includeHidden: true,
    );
    final spor = list.firstWhere((c) => c.providerId == 'c4');
    expect(spor.hidden, isTrue);
    expect(spor.count, 2);
  });

  test('parental hide mode drops locked channels and categories', () async {
    await env.settings.set(
      PlaylistSettings.parentalMode,
      'hide',
      playlistId: pid,
    );
    final list = await repo.categories(pid, SectionKind.live);
    expect(list.any((c) => c.providerId == 'c5'), isFalse);
    expect(list.firstWhere((c) => c.providerId == 'c1').count, 2);
    expect(list.first.count, 2, reason: 'favorite in locked category gone');
    final revealed = await repo.categories(
      pid,
      SectionKind.live,
      revealLocked: true,
    );
    expect(revealed.firstWhere((c) => c.providerId == 'c1').count, 3);
    expect(revealed.any((c) => c.providerId == 'c5'), isTrue);
  });

  group('order', () {
    test('name order follows the Turkish alphabet when Turkish', () async {
      await env.category(pid, 'c6', 'Cuma', sortIndex: 5);
      await env.category(pid, 'c7', 'Çizgi', sortIndex: 6);
      await env.settings.set(
        PlaylistSettings.categoriesOrder,
        'name',
        playlistId: pid,
      );
      await env.settings.set(AppSettings.language, 'tr');
      List<String> names(List<CategoryView> l) =>
          l.where((c) => !c.isSpecial).map((c) => c.name).toList();
      expect(names(await repo.categories(pid, SectionKind.live)), [
        'Belgesel',
        'Cuma',
        'Çizgi',
        'Çocuk',
        'TR | Ulusal',
        'Yetişkin',
      ]);
      await env.settings.set(AppSettings.language, 'en');
      expect(names(await repo.categories(pid, SectionKind.live)), [
        'Belgesel',
        'Çizgi',
        'Çocuk',
        'Cuma',
        'TR | Ulusal',
        'Yetişkin',
      ]);
    });

    test('custom order via reorder, rest in provider order', () async {
      await repo.reorder(pid, SectionKind.live, ['c3', 'c1']);
      expect(
        env.settings.get(PlaylistSettings.categoriesOrder, playlistId: pid),
        'custom',
      );
      final ids = (await repo.categories(
        pid,
        SectionKind.live,
      )).where((c) => !c.isSpecial).map((c) => c.providerId);
      expect(ids, ['c3', 'c1', 'c2', 'c5']);
      await repo.reorder(pid, SectionKind.live, ['c5']);
      final again = (await repo.categories(
        pid,
        SectionKind.live,
      )).where((c) => !c.isSpecial).map((c) => c.providerId);
      expect(again, ['c5', 'c2', 'c3', 'c1']);
    });
  });

  test('rename and reset', () async {
    await repo.rename(pid, SectionKind.live, 'c2', '  DE | Dokümanter ');
    var c2 = (await repo.category(pid, SectionKind.live, 'c2'))!;
    expect(c2.name, 'DE | Dokümanter');
    expect(c2.flag, '🇩🇪');
    expect(c2.label, 'Dokümanter');
    expect(c2.isRenamed, isTrue);
    expect(c2.providerName, 'Belgesel');
    expect((await repo.renamedCategories(pid).first).map((c) => c.providerId), [
      'c2',
    ]);
    await repo.rename(pid, SectionKind.live, 'c2', null);
    c2 = (await repo.category(pid, SectionKind.live, 'c2'))!;
    expect(c2.name, 'Belgesel');
    expect(c2.isRenamed, isFalse);
    await repo.rename(pid, SectionKind.live, 'c2', 'Belgesel');
    expect(
      (await repo.category(pid, SectionKind.live, 'c2'))!.isRenamed,
      isFalse,
    );
  });

  test('settings toggle Last watched and Recently added', () async {
    final stream = repo.watchCategories(pid, SectionKind.live);
    final seen = <List<String>>[];
    final sub = stream.listen((l) => seen.add([for (final c in l) c.ref.key]));
    await pumpUntil(() => seen.isNotEmpty);
    expect(seen.last, containsAll(['last', 'recent']));
    await env.settings.set(
      PlaylistSettings.showLastWatched,
      false,
      playlistId: pid,
    );
    await pumpUntil(() => !seen.last.contains('last'));
    await env.settings.set(
      PlaylistSettings.showRecentlyAdded,
      false,
      playlistId: pid,
    );
    await pumpUntil(() => !seen.last.contains('recent'));
    // An unrelated setting does not recompute.
    final count = seen.length;
    await env.settings.set(
      PlaylistSettings.previewAudio,
      true,
      playlistId: pid,
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(seen.length, count);
    await sub.cancel();
  });

  test('the stream follows hide / unhide and favorites', () async {
    final seen = <List<CategoryView>>[];
    final sub = repo.watchCategories(pid, SectionKind.live).listen(seen.add);
    await pumpUntil(() => seen.isNotEmpty);
    await repo.setHidden(pid, SectionKind.live, 'c2', true);
    await pumpUntil(() => !seen.last.any((c) => c.providerId == 'c2'));
    expect((await repo.hiddenCategories(pid).first).map((c) => c.providerId), [
      'c2',
      'c4',
    ]);
    await repo.setHidden(pid, SectionKind.live, 'c4', false);
    await pumpUntil(() => seen.last.any((c) => c.providerId == 'c4'));
    expect(
      seen.last.first.count,
      3,
      reason: '1, 8 (category visible again), 10; 5 is in a hidden category',
    );
    await env.favorite(pid, '7');
    await pumpUntil(() => seen.last.first.count == 4);
    await repo.setLocked(pid, SectionKind.live, 'c3', true);
    await pumpUntil(
      () => seen.last.firstWhere((c) => c.providerId == 'c3').locked,
    );
    expect((await repo.lockedCategoriesOnce(pid)).map((c) => c.providerId), [
      'c3',
      'c5',
    ]);
    await sub.cancel();
  });

  test('movies and series use their own items, tags and dates', () async {
    await env.category(pid, 'm1', 'Aksiyon', kind: SectionKind.movie);
    await env.category(
      pid,
      'm2',
      'Dram',
      kind: SectionKind.movie,
      hidden: true,
    );
    await env.movie(pid, '100', 'Film A', categoryId: 'm1', added: clock.now);
    await env.movie(pid, '101', 'Film B', categoryId: 'm1', hidden: true);
    await env.movie(pid, '102', 'Film C', categoryId: 'm2', added: clock.now);
    final films = await env.tag(pid, 'Filmler');
    await env.favorite(pid, '100', type: ItemType.movie, tags: [films]);
    await env.favorite(pid, '102', type: ItemType.movie, tags: [films]);
    final movies = await repo.categories(pid, SectionKind.movie);
    expect(
      summary(movies),
      [
        'fav Favorites 1',
        '  fav:$films Filmler 1',
        'recent Recently added 1',
        'p:m1 Aksiyon 1',
      ].join('\n'),
    );
    await env.category(pid, 's1', 'Yerli', kind: SectionKind.series);
    await env.series(
      pid,
      '500',
      'Dizi',
      categoryId: 's1',
      lastModified: clock.now,
    );
    await env.series(
      pid,
      '501',
      'Eski Dizi',
      categoryId: 's1',
      lastModified: clock.now.subtract(const Duration(days: 8)),
    );
    final series = await repo.categories(pid, SectionKind.series);
    expect(
      summary(series),
      ['fav Favorites 0', 'recent Recently added 1', 'p:s1 Yerli 2'].join('\n'),
    );
  });

  test('CategoryRef keys round-trip', () {
    for (final ref in const <CategoryRef>[
      ProviderCategory('a:b'),
      FavoritesCategory(),
      FavoritesCategory(tagId: 4),
      LastWatchedCategory(),
      RecentlyAddedCategory(),
      AllCategory(),
    ]) {
      expect(CategoryRef.tryParse(ref.key), ref);
    }
    expect(CategoryRef.tryParse('fav:x'), isNull);
    expect(CategoryRef.tryParse('nope'), isNull);
    expect(const ProviderCategory('1'), isNot(const ProviderCategory('2')));
  });
}
