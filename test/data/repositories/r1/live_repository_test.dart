import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/repositories/live_repository.dart';
import 'package:carina/data/repositories/repository_models.dart';
import 'package:carina/data/settings/settings_store.dart';

import 'fixtures.dart';

void main() {
  late R1Env env;
  late LiveRepository repo;
  late int pid;
  late FakeClock clock;

  /// Category a "Ulusal": 11 atv HD (num 2), 12 Çağrı TV (no num), 10 Show
  /// TV FHD (num 5), 13 Kanal 7 (hidden, num 1), 14 Beyaz TV (locked,
  /// num 3). b "Haber": 20 CNN Türk (10), 21 Habertürk (11). h hidden: 30.
  /// l locked: 40.
  setUp(() async {
    clock = FakeClock(DateTime(2026, 10, 17, 20));
    env = await R1Env.create();
    repo = LiveRepository(env.db, env.settings, clock: clock.call);
    pid = await env.playlist();
    await env.category(pid, 'a', 'Ulusal', sortIndex: 0);
    await env.category(pid, 'b', 'Haber', sortIndex: 1, localName: 'Haberler');
    await env.category(pid, 'h', 'Gizli Kat', sortIndex: 2, hidden: true);
    await env.category(pid, 'l', 'Kilitli Kat', sortIndex: 3, locked: true);
    await env.channel(
      pid,
      '10',
      'Show TV FHD',
      displayName: 'Show TV',
      quality: 'FHD',
      categoryId: 'a',
      num: 5,
      sortIndex: 2,
      added: DateTime(2026, 10, 10),
      archiveDays: 3,
    );
    await env.channel(
      pid,
      '11',
      'atv HD',
      displayName: 'atv',
      quality: 'HD,H265',
      categoryId: 'a',
      num: 2,
      sortIndex: 0,
      added: DateTime(2026, 10, 15),
    );
    await env.channel(pid, '12', 'Çağrı TV', categoryId: 'a', sortIndex: 1);
    await env.channel(
      pid,
      '13',
      'Kanal 7',
      categoryId: 'a',
      num: 1,
      sortIndex: 3,
      added: DateTime(2026, 10, 16),
      hidden: true,
    );
    await env.channel(
      pid,
      '14',
      'Beyaz TV',
      categoryId: 'a',
      num: 3,
      sortIndex: 4,
      locked: true,
    );
    await env.channel(
      pid,
      '20',
      'CNN Türk',
      categoryId: 'b',
      num: 10,
      sortIndex: 5,
    );
    await env.channel(
      pid,
      '21',
      'Habertürk',
      categoryId: 'b',
      num: 11,
      sortIndex: 6,
      added: DateTime(2026, 10, 17, 9),
    );
    await env.channel(pid, '30', 'Gizli 1', categoryId: 'h', sortIndex: 7);
    await env.channel(pid, '40', 'Kilit 1', categoryId: 'l', sortIndex: 8);
  });
  tearDown(() async {
    await repo.dispose();
    await env.dispose();
  });

  Future<List<String>> ids(CategoryRef ref, {bool reveal = false}) async =>
      (await repo.channels(
        pid,
        ref,
        revealLocked: reveal,
      )).map((c) => c.providerId).toList();

  Future<void> order(String value) =>
      env.settings.set(PlaylistSettings.channelsOrder, value, playlistId: pid);

  group('order', () {
    const a = ProviderCategory('a');

    test('playlist, name, number and date', () async {
      expect(await ids(a), ['11', '12', '10', '14']);
      await order('name');
      expect(await ids(a), ['11', '14', '12', '10']);
      await order('number');
      expect(await ids(a), ['11', '14', '10', '12']);
      await order('date');
      expect(await ids(a), ['11', '10', '12', '14']);
    });

    test('name order is Turkish-aware in Turkish', () async {
      await env.channel(pid, '15', 'Cem TV', categoryId: 'a', sortIndex: 9);
      await order('name');
      await env.settings.set(AppSettings.language, 'en');
      expect(await ids(a), ['11', '14', '12', '15', '10']);
      await env.settings.set(AppSettings.language, 'tr');
      expect(await ids(a), ['11', '14', '15', '12', '10']);
    });
  });

  group('filters', () {
    test('All leaves out hidden channels and hidden categories', () async {
      expect(await ids(const AllCategory()), [
        '11',
        '12',
        '10',
        '14',
        '20',
        '21',
        '40',
      ]);
      expect(await repo.allChannelsCount(pid), 7);
    });

    test(
      'a hidden category opened from Hidden items lists its channels',
      () async {
        expect(await ids(const ProviderCategory('h')), ['30']);
      },
    );

    test(
      'parental hide mode leaves out locked channels and categories',
      () async {
        await env.settings.set(
          PlaylistSettings.parentalMode,
          'hide',
          playlistId: pid,
        );
        expect(await ids(const AllCategory()), ['11', '12', '10', '20', '21']);
        expect(await repo.allChannelsCount(pid), 5);
        expect(await ids(const ProviderCategory('l')), isEmpty);
        expect(await ids(const AllCategory(), reveal: true), hasLength(7));
        expect(await repo.channelByNumber(pid, 3), isNull);
        expect(
          (await repo.channelByNumber(pid, 3, revealLocked: true))!.providerId,
          '14',
        );
      },
    );

    test('Recently added: last 7 days, newest first', () async {
      expect(await ids(const RecentlyAddedCategory()), ['21', '11']);
    });
  });

  group('zapping', () {
    test('neighbors wrap around the list', () async {
      const a = ProviderCategory('a');
      var n = await repo.neighbors(pid, a, '11');
      expect(n.previous!.providerId, '14');
      expect(n.next!.providerId, '12');
      n = await repo.neighbors(pid, a, '14');
      expect(n.previous!.providerId, '10');
      expect(n.next!.providerId, '11');
      n = await repo.neighbors(pid, a, '99');
      expect(n.previous, isNull);
      expect(n.next, isNull);
      n = await repo.neighbors(pid, const ProviderCategory('h'), '30');
      expect(n.next, isNull, reason: 'alone in its list');
    });

    test('neighbors see changes made through the repository', () async {
      const a = ProviderCategory('a');
      expect((await repo.neighbors(pid, a, '11')).next!.providerId, '12');
      await repo.setHidden(pid, '12', true);
      expect((await repo.neighbors(pid, a, '11')).next!.providerId, '10');
      expect((await repo.hiddenChannels(pid).first).map((c) => c.providerId), [
        '12',
        '13',
      ]);
    });

    test('number lookup', () async {
      expect((await repo.channelByNumber(pid, 5))!.providerId, '10');
      expect((await repo.channelByNumber(pid, 10))!.providerId, '20');
      expect(await repo.channelByNumber(pid, 1), isNull, reason: 'hidden');
      expect(await repo.channelByNumber(pid, 42), isNull);
    });

    test('without channel numbers, the number is the position', () async {
      final m3u = await env.playlist(
        type: PlaylistType.m3u,
        m3uUrl: 'http://x/a.m3u',
      );
      await env.channel(m3u, 'x1', 'Bir', sortIndex: 0);
      await env.channel(m3u, 'x2', 'İki', sortIndex: 1, hidden: true);
      await env.channel(m3u, 'x3', 'Üç', sortIndex: 2);
      expect((await repo.channelByNumber(m3u, 2))!.providerId, 'x3');
      expect(await repo.channelByNumber(m3u, 3), isNull);
    });
  });

  group('last watched', () {
    test('most recent first, capped at 50', () async {
      final big = await env.playlist(name: 'Big');
      for (var i = 0; i < 60; i++) {
        await env.channel(big, 'c$i', 'Channel $i', sortIndex: i);
      }
      for (var i = 0; i < 55; i++) {
        await repo.addLastWatched(big, 'c$i');
        if (i.isEven) clock.advance(const Duration(seconds: 1));
      }
      var list = (await repo.channels(
        big,
        const LastWatchedCategory(),
      )).map((c) => c.providerId).toList();
      expect(list, hasLength(50));
      expect(list.first, 'c54');
      expect(list.take(3), ['c54', 'c53', 'c52']);
      expect(list.last, 'c5');
      final rows = await (env.db.select(
        env.db.lastWatchedLive,
      )..where((l) => l.playlistId.equals(big))).get();
      expect(rows, hasLength(50));

      await repo.addLastWatched(big, 'c10');
      list = (await repo.channels(
        big,
        const LastWatchedCategory(),
      )).map((c) => c.providerId).toList();
      expect(list.take(2), ['c10', 'c54']);
      expect(list, hasLength(50));

      await repo.removeLastWatched(big, 'c10');
      list = (await repo.channels(
        big,
        const LastWatchedCategory(),
      )).map((c) => c.providerId).toList();
      expect(list.first, 'c54');
      expect(list, hasLength(49));
    });

    test('hidden channels are left out', () async {
      await repo.addLastWatched(pid, '13');
      await repo.addLastWatched(pid, '10');
      expect(await ids(const LastWatchedCategory()), ['10']);
    });
  });

  group('EPG key', () {
    test(
      'custom EPG overrides the matched id, which overrides tvg-id',
      () async {
        await env.channel(
          pid,
          '50',
          'EPG Test',
          epgId: 'tvg.id',
          matchedEpgId: 'matched.id',
          sortIndex: 10,
        );
        await env.channel(
          pid,
          '51',
          'Only tvg',
          epgId: 'only.tvg',
          sortIndex: 11,
        );
        expect((await repo.channel(pid, '50'))!.epgKey, 'matched.id');
        expect((await repo.channel(pid, '51'))!.epgKey, 'only.tvg');
        await repo.setCustomEpg(pid, '50', ' custom.id ');
        expect((await repo.channel(pid, '50'))!.epgKey, 'custom.id');
        expect(
          (await repo.customEpgChannels(pid).first).map((c) => c.providerId),
          ['50'],
        );
        await repo.setCustomEpg(pid, '50', null);
        expect((await repo.channel(pid, '50'))!.epgKey, 'matched.id');
      },
    );

    test('M3U channels use only matched or custom ids', () async {
      final m3u = await env.playlist(
        type: PlaylistType.m3u,
        m3uUrl: 'http://x/a.m3u',
      );
      await env.channel(m3u, 'm', 'M', epgId: 'tvg.only');
      expect((await repo.channel(m3u, 'm'))!.epgKey, isNull);
      await repo.setCustomEpg(m3u, 'm', 'picked');
      expect((await repo.channel(m3u, 'm'))!.epgKey, 'picked');
    });
  });

  test('channel view fields', () async {
    await env.favorite(pid, '10');
    final now = clock.now.toUtc();
    await env.db
        .into(env.db.reminders)
        .insert(
          RemindersCompanion.insert(
            playlistId: pid,
            channelId: '10',
            channelName: 'Show TV',
            title: 'Upcoming',
            start: now.add(const Duration(hours: 1)).millisecondsSinceEpoch,
            stop: now.add(const Duration(hours: 2)).millisecondsSinceEpoch,
            createdAt: clock.now,
          ),
        );
    await env.db
        .into(env.db.reminders)
        .insert(
          RemindersCompanion.insert(
            playlistId: pid,
            channelId: '11',
            channelName: 'atv',
            title: 'Over',
            start: now
                .subtract(const Duration(hours: 2))
                .millisecondsSinceEpoch,
            stop: now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch,
            createdAt: clock.now,
          ),
        );
    final show = (await repo.channel(pid, '10'))!;
    expect(show.displayName, 'Show TV');
    expect(show.badges, ['FHD']);
    expect(show.favorite, isTrue);
    expect(show.hasReminder, isTrue);
    expect(show.hasArchive, isTrue);
    expect(show.locked, isFalse);
    expect(show.categoryName, 'Ulusal');
    expect(show.number, 5);
    final atv = (await repo.channel(pid, '11'))!;
    expect(atv.badges, ['HD', 'H265']);
    expect(atv.hasReminder, isFalse, reason: 'its programme is over');
    expect(atv.favorite, isFalse);
    final cnn = (await repo.channel(pid, '20'))!;
    expect(cnn.categoryName, 'Haberler', reason: 'local rename');
    final kilit = (await repo.channel(pid, '40'))!;
    expect(kilit.locked, isTrue);
    expect(kilit.categoryLocked, isTrue);
    expect(kilit.channelLocked, isFalse);
    final beyaz = (await repo.channel(pid, '14'))!;
    expect(beyaz.channelLocked, isTrue);
    await repo.setLocked(pid, '14', false);
    expect((await repo.channel(pid, '14'))!.locked, isFalse);
    expect(await repo.channel(pid, 'missing'), isNull);
  });

  group('favorites', () {
    setUp(() async {
      final tag = await env.tag(pid, 'Akşam');
      await env.favorite(
        pid,
        '20',
        addedAt: DateTime(2026, 10, 1),
        customIndex: 1,
        tags: [tag],
      );
      await env.favorite(
        pid,
        '10',
        addedAt: DateTime(2026, 10, 2),
        customIndex: 0,
        tags: [tag],
      );
      await env.favorite(pid, '12', addedAt: DateTime(2026, 10, 3));
      await env.favorite(
        pid,
        '30',
        addedAt: DateTime(2026, 10, 4),
      ); // hidden cat
    });

    Future<void> favOrder(String value) => env.settings.set(
      PlaylistSettings.favoritesOrder,
      value,
      playlistId: pid,
    );

    test('follow the favorites order setting', () async {
      expect(await ids(const FavoritesCategory()), ['12', '10', '20']);
      await favOrder('leastRecent');
      expect(await ids(const FavoritesCategory()), ['20', '10', '12']);
      await favOrder('custom');
      expect(await ids(const FavoritesCategory()), ['10', '20', '12']);
      await favOrder('name');
      await env.settings.set(AppSettings.language, 'en');
      expect(await ids(const FavoritesCategory()), ['12', '20', '10']);
      await env.settings.set(AppSettings.language, 'tr');
      expect(await ids(const FavoritesCategory()), ['20', '12', '10']);
    });

    test('a tag lists its channels', () async {
      expect(await ids(const FavoritesCategory(tagId: 1)), ['10', '20']);
    });
  });

  test('watchChannels follows changes and settings', () async {
    final seen = <List<String>>[];
    final sub = repo
        .watchChannels(pid, const ProviderCategory('a'))
        .listen((l) => seen.add([for (final c in l) c.providerId]));
    await pumpUntil(() => seen.isNotEmpty);
    expect(seen.last, ['11', '12', '10', '14']);
    await repo.setHidden(pid, '12', true);
    await pumpUntil(() => seen.last.length == 3);
    expect(seen.last, ['11', '10', '14']);
    await order('number');
    await pumpUntil(() => seen.last.first == '11' && seen.last[1] == '14');
    expect(seen.last, ['11', '14', '10']);
    final before = seen.length;
    await env.favorite(pid, '20'); // another category: same list, no emission
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(seen.length, before);
    await sub.cancel();
  });
}
