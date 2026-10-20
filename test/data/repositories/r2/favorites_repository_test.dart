import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/repositories/favorites_repository.dart';
import 'package:carina/data/repositories/vod_repository.dart';
import 'package:carina/data/settings/settings_store.dart';

import 'r2_fixtures.dart';

void main() {
  late R2Env env;
  late FavoritesRepository repo;
  late int pid;

  setUp(() async {
    env = await R2Env.create();
    repo = FavoritesRepository(
      db: env.db,
      settings: env.settings,
      clock: env.clock,
    );
    pid = await env.playlist();
  });

  tearDown(() => env.close());

  void tick() => env.now = env.now.add(const Duration(minutes: 1));

  Future<List<String>> ids(
    ItemType type, {
    FavoritesOrder? order,
    int? tagId,
  }) async => (await repo.favorites(
    pid,
    type,
    order: order,
    tagId: tagId,
  )).map((e) => e.providerId).toList();

  group('favorites', () {
    test('toggle, add, remove and watchIsFavorite', () async {
      final emissions = Emissions(
        repo.watchIsFavorite(pid, ItemType.channel, '1001'),
      );
      expect(await emissions.next(), isFalse);
      expect(await repo.toggle(pid, ItemType.channel, '1001'), isTrue);
      expect(await emissions.next((v) => v), isTrue);
      expect(await repo.isFavorite(pid, ItemType.channel, '1001'), isTrue);
      // Same provider id, other type: independent.
      expect(await repo.isFavorite(pid, ItemType.movie, '1001'), isFalse);
      expect(await repo.toggle(pid, ItemType.channel, '1001'), isFalse);
      expect(await emissions.next((v) => !v), isFalse);

      final a = await repo.add(pid, ItemType.movie, 'm1');
      expect(await repo.add(pid, ItemType.movie, 'm1'), a); // no duplicate
      expect(await repo.remove(pid, ItemType.movie, 'm1'), isTrue);
      expect(await repo.remove(pid, ItemType.movie, 'm1'), isFalse);
      await emissions.cancel();
    });

    test('favorites are per playlist', () async {
      final other = await env.playlist(name: 'Other');
      await repo.add(pid, ItemType.movie, 'm1');
      expect(await repo.isFavorite(other, ItemType.movie, 'm1'), isFalse);
      expect(await ids(ItemType.movie), ['m1']);
      expect(await repo.favorites(other, ItemType.movie), isEmpty);
    });

    test('watchFavoriteIds lists provider ids of a type', () async {
      final emissions = Emissions(repo.watchFavoriteIds(pid, ItemType.series));
      expect(await emissions.next(), isEmpty);
      await repo.add(pid, ItemType.series, 's1');
      await repo.add(pid, ItemType.movie, 'm1');
      expect(await emissions.next((s) => s.isNotEmpty), {'s1'});
      await emissions.cancel();
    });

    test('orders: last added, least recent, name (joined), custom', () async {
      await env.channel(pid, 'c1', 'TRT 1 HD', displayName: 'TRT 1');
      await env.channel(pid, 'c2', 'ATV FHD', displayName: 'ATV');
      await env.channel(pid, 'c3', 'Çocuk TV', displayName: 'Çocuk TV');
      await repo.add(pid, ItemType.channel, 'c1');
      tick();
      await repo.add(pid, ItemType.channel, 'c3');
      tick();
      await repo.add(pid, ItemType.channel, 'c2');
      tick();
      await repo.add(pid, ItemType.channel, 'gone'); // item not in library

      expect(await ids(ItemType.channel), ['gone', 'c2', 'c3', 'c1']);
      expect(await ids(ItemType.channel, order: FavoritesOrder.leastRecent), [
        'c1',
        'c3',
        'c2',
        'gone',
      ]);
      final byName = await repo.favorites(
        pid,
        ItemType.channel,
        order: FavoritesOrder.name,
      );
      expect(byName.map((e) => e.name), ['ATV', 'Çocuk TV', 'TRT 1', null]);
      expect(byName.last.isAvailable, isFalse);
      // Custom = insertion order until reordered.
      expect(await ids(ItemType.channel, order: FavoritesOrder.custom), [
        'c1',
        'c3',
        'c2',
        'gone',
      ]);
      await repo.reorder(pid, ItemType.channel, ['c2', 'gone', 'c1', 'c3']);
      expect(await ids(ItemType.channel, order: FavoritesOrder.custom), [
        'c2',
        'gone',
        'c1',
        'c3',
      ]);
      // A new favorite goes to the end of the custom order.
      await repo.add(pid, ItemType.channel, 'c4');
      expect(
        (await ids(ItemType.channel, order: FavoritesOrder.custom)).last,
        'c4',
      );
    });

    test('default order comes from the favorites order setting', () async {
      await repo.add(pid, ItemType.movie, 'a');
      tick();
      await repo.add(pid, ItemType.movie, 'b');
      expect(await ids(ItemType.movie), ['b', 'a']);
      await env.settings.set(
        PlaylistSettings.favoritesOrder,
        'leastRecent',
        playlistId: pid,
      );
      expect(await ids(ItemType.movie), ['a', 'b']);
    });

    test('reorder of a subset keeps the other positions', () async {
      for (final id in ['a', 'b', 'c', 'd', 'e']) {
        await repo.add(pid, ItemType.movie, id);
      }
      final tag = await repo.createTag(pid, 'Seçilmiş');
      for (final id in ['b', 'd']) {
        await repo.setTags(pid, ItemType.movie, id, {tag});
      }
      // Reorder within the tag: d before b.
      await repo.reorder(pid, ItemType.movie, ['d', 'b', 'unknown']);
      expect(await ids(ItemType.movie, order: FavoritesOrder.custom), [
        'a',
        'd',
        'c',
        'b',
        'e',
      ]);
      expect(
        await ids(ItemType.movie, order: FavoritesOrder.custom, tagId: tag),
        ['d', 'b'],
      );
    });

    test(
      'favorites survive the item row being deleted and re-inserted',
      () async {
        final vod = VodRepository(
          db: env.db,
          settings: env.settings,
          secrets: env.secrets,
          clock: env.clock,
        );
        await env.movie(pid, '3001', 'Kış Uykusu');
        await repo.add(pid, ItemType.movie, '3001');
        final emissions = Emissions(
          repo.watchFavorites(pid, ItemType.movie, order: FavoritesOrder.name),
        );
        expect((await emissions.next()).single.name, 'Kış Uykusu');

        // Reload: the row disappears ...
        await (env.db.delete(
          env.db.movies,
        )..where((m) => m.providerId.equals('3001'))).go();
        final missing = await emissions.next((l) => l.single.name == null);
        expect(missing.single.providerId, '3001');
        expect(
          await vod.watchFavoriteItems(pid, SectionKind.movie).first,
          isEmpty,
        );
        expect(await repo.isFavorite(pid, ItemType.movie, '3001'), isTrue);

        // ... and comes back with a new row id but the same provider id.
        await env.movie(pid, '3001', 'Kış Uykusu (Yeni)');
        final back = await emissions.next((l) => l.single.name != null);
        expect(back.single.name, 'Kış Uykusu (Yeni)');
        final items = await vod
            .watchFavoriteItems(pid, SectionKind.movie)
            .first;
        expect(items.single.providerId, '3001');
        expect(items.single.isFavorite, isTrue);
        await emissions.cancel();
        vod.dispose();
      },
    );
  });

  group('tags', () {
    test('create dedupes trimmed names ignoring case and diacritics', () async {
      final a = await repo.createTag(pid, '  Hafta Sonu ');
      expect(await repo.createTag(pid, 'hafta sonu'), a);
      expect(await repo.createTag(pid, 'HAFTA  SONU'), a);
      final b = await repo.createTag(pid, 'Çocuk');
      expect(await repo.createTag(pid, 'cocuk'), b);
      final emoji = await repo.createTag(pid, '⭐');
      expect(await repo.createTag(pid, '⭐'), emoji);
      expect(() => repo.createTag(pid, '   '), throwsArgumentError);
      final tags = await repo.tags(pid);
      expect(tags.map((t) => t.name), ['Hafta Sonu', 'Çocuk', '⭐']);
      // Another playlist has its own tags.
      final other = await env.playlist(name: 'Other');
      expect(await repo.createTag(other, 'Hafta Sonu'), isNot(a));
    });

    test('rename refuses clashes, delete keeps favorites', () async {
      final a = await repo.createTag(pid, 'Aksiyon');
      final b = await repo.createTag(pid, 'Dram');
      expect(await repo.renameTag(a, 'Macera'), isTrue);
      expect(await repo.renameTag(a, 'dram'), isFalse);
      expect(await repo.renameTag(a, 'MACERA'), isTrue); // own name, new case
      expect(await repo.renameTag(999, 'X'), isFalse);
      await repo.add(pid, ItemType.movie, 'm1', tagIds: [a, b]);
      expect(await repo.deleteTag(b), isTrue);
      expect(await repo.deleteTag(b), isFalse);
      expect(await repo.isFavorite(pid, ItemType.movie, 'm1'), isTrue);
      expect(
        (await repo.tagsFor(pid, ItemType.movie, 'm1')).map((t) => t.name),
        ['MACERA'],
      );
    });

    test('watchTags counts tagged favorites per type', () async {
      final emissions = Emissions(repo.watchTags(pid));
      final tag = await repo.createTag(pid, 'Akşam');
      final empty = await emissions.next((l) => l.isNotEmpty);
      expect(empty.single.total, 0);
      await repo.add(pid, ItemType.channel, 'c1', tagIds: [tag]);
      await repo.add(pid, ItemType.channel, 'c2', tagIds: [tag]);
      await repo.add(pid, ItemType.movie, 'm1', tagIds: [tag]);
      final counted = await emissions.next((l) => l.single.total == 3);
      expect(counted.single.countOf(ItemType.channel), 2);
      expect(counted.single.countOf(ItemType.movie), 1);
      expect(counted.single.countOf(ItemType.series), 0);
      await repo.remove(pid, ItemType.channel, 'c1');
      final after = await emissions.next((l) => l.single.total == 2);
      expect(after.single.counts, {ItemType.channel: 1, ItemType.movie: 1});
      await emissions.cancel();
    });

    test('setTags adds the favorite and replaces its tags', () async {
      final a = await repo.createTag(pid, 'A');
      final b = await repo.createTag(pid, 'B');
      final other = await env.playlist(name: 'Other');
      final foreign = await repo.createTag(other, 'Foreign');

      final ids = Emissions(repo.watchTagIdsFor(pid, ItemType.series, 's1'));
      expect(await ids.next(), isEmpty);
      await repo.setTags(pid, ItemType.series, 's1', {a, foreign});
      expect(await repo.isFavorite(pid, ItemType.series, 's1'), isTrue);
      expect(await ids.next((s) => s.isNotEmpty), {a});
      await repo.setTags(pid, ItemType.series, 's1', {b});
      expect(await ids.next((s) => s.contains(b) && !s.contains(a)), {b});
      await repo.setTags(pid, ItemType.series, 's1', {});
      expect(await ids.next((s) => s.isEmpty), isEmpty);
      expect(await repo.isFavorite(pid, ItemType.series, 's1'), isTrue);
      await ids.cancel();

      final favorite = (await repo.favorites(pid, ItemType.series)).single;
      await repo.setTags(pid, ItemType.series, 's1', {a, b});
      expect((await repo.tagsForFavorite(favorite.id)).map((t) => t.name), [
        'A',
        'B',
      ]);
      expect(await repo.tagsFor(pid, ItemType.series, 'nope'), isEmpty);
      await repo.reorderTags(pid, [b, a]);
      expect((await repo.tags(pid)).map((t) => t.name), ['B', 'A']);
    });

    test('favorites filtered by tag', () async {
      final t = await repo.createTag(pid, 'T');
      await repo.add(pid, ItemType.movie, 'x', tagIds: [t]);
      await repo.add(pid, ItemType.movie, 'y');
      expect(await ids(ItemType.movie, tagId: t), ['x']);
      expect(await ids(ItemType.movie), hasLength(2));
    });
  });
}
