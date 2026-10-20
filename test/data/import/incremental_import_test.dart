import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/import/import.dart';
import 'package:carina/data/text/normalize.dart';

import 'import_harness.dart';

void main() {
  late ImportHarness h;
  late FilteringProxy proxy;
  late int pid;
  late ImportProgress reload;

  // Items that "disappear" upstream before the reload.
  late String goneChannel;
  late String goneMovie;
  const goneSeries = '${MockFixtures.maviKapi}';
  late String goneCategory;
  late String renamedMovie;

  setUpAll(() async {
    h = await ImportHarness.create();
    proxy = await FilteringProxy.start(h.base);
    final c = h.catalog;
    // Default EPG (epgUrl null): {proxy}/xmltv.php.
    pid = await h.addXtream(server: proxy.baseUrl);
    final first = await h.service.run(pid);
    expect(first.step, ImportStep.completed, reason: '$first');

    goneChannel = '${c.channels.last.streamId}';
    goneMovie = '${c.movies.last.streamId}';
    renamedMovie = '${c.movies[10].streamId}';
    final fixtureCategories = {
      for (final id in MockFixtures.liveNames.keys)
        c.channelById(id)!.categoryId,
    };
    goneCategory = c.liveCategories
        .lastWhere((cat) => !fixtureCategories.contains(cat.id))
        .id;

    await _addLocalState(h, pid, goneChannel, renamedMovie);

    proxy
      ..hiddenLive.add(goneChannel)
      ..hiddenMovies.add(goneMovie)
      ..hiddenSeries.add(goneSeries)
      ..hiddenLiveCategories.add(goneCategory)
      ..renamedMovies[renamedMovie] = 'Yeni Ad (2026)';
    reload = await h.service.run(pid);
  });

  tearDownAll(() async {
    await proxy.stop();
    await h.dispose();
  });

  test('the reload completes', () {
    expect(reload.step, ImportStep.completed, reason: '$reload');
    expect(reload.warnings, isEmpty);
  });

  test(
    'favorites, tags, watch state, last watched and reminders survive',
    () async {
      final favorites = await h.db.select(h.db.favorites).get();
      expect(
        favorites.map((f) => (f.itemType, f.providerId)),
        unorderedEquals([
          (ItemType.channel, '1001'),
          (ItemType.movie, '${MockFixtures.kisUykusu}'),
          (ItemType.series, '${MockFixtures.sicakKafa}'),
          (ItemType.channel, goneChannel),
        ]),
      );
      expect(await h.db.select(h.db.favoriteTagLinks).get(), hasLength(1));
      final watch = await h.db.select(h.db.watchStates).get();
      expect(watch.map((w) => (w.providerId, w.positionMs)), [
        ('${MockFixtures.kisUykusu}', 60000),
        ('5001101', 30000),
      ]);
      final last = await h.db.select(h.db.lastWatchedLive).getSingle();
      expect(last.channelId, '1002');
      final reminder = await h.db.select(h.db.reminders).getSingle();
      expect(reminder.channelId, '1001');
    },
  );

  test('local category and channel fields are kept', () async {
    final ulusal = (await h.category(
      pid,
      SectionKind.live,
      MockFixtures.ulusalCategoryId,
    ))!;
    expect(ulusal.name, MockFixtures.ulusalCategoryName);
    expect(ulusal.localName, 'Benim Ulusal');
    expect(ulusal.customIndex, 2);
    expect(ulusal.hidden, isTrue);
    expect(ulusal.locked, isTrue);
    expect(ulusal.removed, isFalse);

    final trt1 = (await h.channel(pid, 1001))!;
    expect(trt1.customIndex, 7);
    expect(trt1.matchedEpgId, h.catalog.channelById(1001)!.xmltvId);
    expect((await h.channel(pid, 1004))!.hidden, isTrue);
    expect((await h.channel(pid, 1006))!.locked, isTrue);
    final uhd = (await h.channel(pid, 1003))!;
    expect(uhd.customEpgId, 'custom.epg.id');
    expect(uhd.matchedEpgId, h.catalog.channelById(1003)!.xmltvId);
  });

  test('movie / series local fields and unchanged info are kept', () async {
    final movie = (await h.movie(pid, MockFixtures.kisUykusu))!;
    expect(movie.hidden, isTrue);
    expect(movie.infoJson, contains('Deniz Yıldız'));
    expect(movie.infoFetchedAt, isNotNull);
    final series = (await h.series(pid, MockFixtures.sicakKafa))!;
    expect(series.hidden, isTrue);
    expect(series.infoJson, '{"seasons":[]}');
    expect(series.infoFetchedAt, isNotNull);
    expect(
      await h.count('episodes', pid, "series_id = '${MockFixtures.sicakKafa}'"),
      2,
    );
    expect(await h.count('seasons', pid, "series_id = '5001'"), 1);
  });

  test('an item that changed upstream loses its cached info', () async {
    final movie = (await h.movie(pid, renamedMovie))!;
    expect(movie.name, 'Yeni Ad (2026)');
    expect(movie.infoJson, isNull);
    expect(movie.infoFetchedAt, isNull);
  });

  test('items that disappeared upstream are removed', () async {
    expect(await h.channel(pid, goneChannel), isNull);
    expect(await h.movie(pid, goneMovie), isNull);
    expect(await h.series(pid, goneSeries), isNull);
    expect(await h.category(pid, SectionKind.live, goneCategory), isNull);
    // Seasons and episodes of a removed series go with it.
    expect(await h.count('episodes', pid, "series_id = '$goneSeries'"), 0);
    expect(await h.count('seasons', pid, "series_id = '$goneSeries'"), 0);
    // Channels of the removed category stay (their category is just gone).
    final c = h.catalog;
    final inGone = c.channels
        .where(
          (ch) =>
              ch.categoryId == goneCategory && '${ch.streamId}' != goneChannel,
        )
        .length;
    expect(
      await h.count('channels', pid, "category_id = '$goneCategory'"),
      inGone,
    );
    for (final table in ['categories', 'channels', 'movies', 'series']) {
      expect(await h.count(table, pid, 'removed = 1'), 0, reason: table);
    }
    final p = await h.playlist(pid);
    expect(p.liveCount, c.channels.length - 1);
    expect(p.movieCount, c.movies.length - 1);
    expect(p.seriesCount, c.series.length - 1);
  });

  test('the search index follows the reload', () async {
    final gone = h.catalog.channelById(int.parse(goneChannel))!;
    final goneHits = await h.search(pid, ftsQuery(gone.name));
    expect(goneHits.where((r) => r.ref == goneChannel), isEmpty);
    // People from cached movie info.
    final people = await h.search(pid, ftsQuery('deniz yildiz'));
    expect(people.map((r) => (r.kind, r.title)), [('person', 'Deniz Yıldız')]);
    expect(await h.search(pid, ftsQuery('yeni ad')), isNotEmpty);
    final mavi = await h.search(pid, ftsQuery(MockFixtures.maviKapiName));
    expect(mavi.where((r) => r.ref == goneSeries), isEmpty);
  });

  test('the guide is replaced, not duplicated', () async {
    final rows = await h.db
        .customSelect(
          'SELECT COUNT(*) AS n FROM (SELECT epg_channel_id, start '
          'FROM programmes WHERE playlist_id = ? '
          'GROUP BY epg_channel_id, start HAVING COUNT(*) > 1)',
          variables: [Variable.withInt(pid)],
        )
        .getSingle();
    expect(rows.read<int>('n'), 0);
    final p = await h.playlist(pid);
    expect(p.programmeCount, await h.count('programmes', pid));
  });

  test('the bulk live call falls back to one request per category', () async {
    proxy
      ..hiddenLive.clear()
      ..hiddenMovies.clear()
      ..hiddenSeries.clear()
      ..hiddenLiveCategories.clear()
      ..failBulkLive = true
      ..actions.clear();
    final result = await h.service.run(pid, scope: ImportScope.content);
    expect(result.step, ImportStep.completed, reason: '$result');
    final c = h.catalog;
    expect(
      proxy.actions.where((a) => a == 'get_live_streams').length,
      1 + c.liveCategories.length,
    );
    // Every channel that has a known category comes back.
    final categorized = c.channels
        .where((ch) => c.liveCategories.any((cat) => cat.id == ch.categoryId))
        .length;
    expect(result.counts[ImportStep.liveChannels], categorized);
    expect(await h.count('channels', pid), categorized);
    expect((await h.channel(pid, 1001))!.customIndex, 7);
    proxy.failBulkLive = false;
  });
}

Future<void> _addLocalState(
  ImportHarness h,
  int pid,
  String goneChannel,
  String renamedMovie,
) async {
  final db = h.db;
  final now = DateTime.now();
  Future<int> favorite(ItemType type, String id) => db
      .into(db.favorites)
      .insert(
        FavoritesCompanion.insert(
          playlistId: pid,
          itemType: type,
          providerId: id,
          addedAt: now,
        ),
      );
  final fav = await favorite(ItemType.channel, '1001');
  await favorite(ItemType.movie, '${MockFixtures.kisUykusu}');
  await favorite(ItemType.series, '${MockFixtures.sicakKafa}');
  await favorite(ItemType.channel, goneChannel);
  final tag = await db
      .into(db.favoriteTags)
      .insert(FavoriteTagsCompanion.insert(playlistId: pid, name: 'Haber'));
  await db
      .into(db.favoriteTagLinks)
      .insert(FavoriteTagLinksCompanion.insert(favoriteId: fav, tagId: tag));
  await db
      .into(db.watchStates)
      .insert(
        WatchStatesCompanion.insert(
          playlistId: pid,
          itemType: ItemType.movie,
          providerId: '${MockFixtures.kisUykusu}',
          positionMs: const Value(60000),
          durationMs: const Value(120000),
          updatedAt: now,
        ),
      );
  await db
      .into(db.watchStates)
      .insert(
        WatchStatesCompanion.insert(
          playlistId: pid,
          itemType: ItemType.episode,
          providerId: '5001101',
          seriesId: const Value('5001'),
          positionMs: const Value(30000),
          updatedAt: now,
        ),
      );
  await db
      .into(db.lastWatchedLive)
      .insert(
        LastWatchedLiveCompanion.insert(
          playlistId: pid,
          channelId: '1002',
          watchedAt: now,
        ),
      );
  await db
      .into(db.reminders)
      .insert(
        RemindersCompanion.insert(
          playlistId: pid,
          channelId: '1001',
          channelName: 'TRT 1',
          title: 'Ana Haber',
          start: now.add(const Duration(hours: 1)).millisecondsSinceEpoch,
          stop: now.add(const Duration(hours: 2)).millisecondsSinceEpoch,
          createdAt: now,
        ),
      );

  await (db.update(db.categories)..where(
        (c) =>
            c.playlistId.equals(pid) &
            c.kind.equalsValue(SectionKind.live) &
            c.providerId.equals(MockFixtures.ulusalCategoryId),
      ))
      .write(
        const CategoriesCompanion(
          localName: Value('Benim Ulusal'),
          customIndex: Value(2),
          hidden: Value(true),
          locked: Value(true),
        ),
      );
  Future<void> channel(String id, ChannelsCompanion values) =>
      (db.update(db.channels)
            ..where((c) => c.playlistId.equals(pid) & c.providerId.equals(id)))
          .write(values);
  await channel('1001', const ChannelsCompanion(customIndex: Value(7)));
  await channel('1004', const ChannelsCompanion(hidden: Value(true)));
  await channel('1006', const ChannelsCompanion(locked: Value(true)));
  await channel(
    '1003',
    const ChannelsCompanion(customEpgId: Value('custom.epg.id')),
  );

  await (db.update(db.movies)..where(
        (m) =>
            m.playlistId.equals(pid) &
            m.providerId.equals('${MockFixtures.kisUykusu}'),
      ))
      .write(
        MoviesCompanion(
          hidden: const Value(true),
          infoJson: const Value(
            '{"info":{"actors":"Deniz Yıldız, Nehir Aydın"}}',
          ),
          infoFetchedAt: Value(now),
        ),
      );
  await (db.update(db.movies)..where(
        (m) => m.playlistId.equals(pid) & m.providerId.equals(renamedMovie),
      ))
      .write(
        MoviesCompanion(
          infoJson: const Value('{"info":{}}'),
          infoFetchedAt: Value(now),
        ),
      );
  await (db.update(db.series)..where(
        (s) =>
            s.playlistId.equals(pid) &
            s.providerId.equals('${MockFixtures.sicakKafa}'),
      ))
      .write(
        SeriesCompanion(
          hidden: const Value(true),
          infoJson: const Value('{"seasons":[]}'),
          infoFetchedAt: Value(now),
        ),
      );

  // Lazily cached seasons / episodes (what the repositories store).
  for (final series in ['5001', '${MockFixtures.maviKapi}']) {
    await db
        .into(db.seasons)
        .insert(
          SeasonsCompanion.insert(
            playlistId: pid,
            seriesId: series,
            seasonNumber: 1,
          ),
        );
    for (var e = 1; e <= 2; e++) {
      await db
          .into(db.episodes)
          .insert(
            EpisodesCompanion.insert(
              playlistId: pid,
              providerId: '${series}1$e',
              seriesId: series,
              season: 1,
              episodeNum: e,
              title: 'Bölüm $e',
            ),
          );
    }
  }
}
