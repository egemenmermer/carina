import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/repositories/search_repository.dart';

import 'r2_fixtures.dart';

void main() {
  late R2Env env;
  late SearchRepository repo;
  late int pid;

  setUp(() async {
    env = await R2Env.create();
    repo = SearchRepository(db: env.db, clock: env.clock);
    pid = await env.playlist();
    final now = env.now;

    await env.category(pid, SectionKind.movie, 'M', 'Filmler');
    await env.category(pid, SectionKind.movie, 'MH', 'Gizli', hidden: true);
    await env.category(pid, SectionKind.live, 'L', 'TR | Ulusal');
    await env.category(pid, SectionKind.live, 'LH', 'Gizli', hidden: true);

    Future<void> movie(
      String id,
      String name, {
      String? cat,
      bool hidden = false,
    }) async {
      await env.movie(pid, id, name, categoryId: cat ?? 'M', hidden: hidden);
      await env.index(pid, 'movie', id, name);
    }

    await movie('3001', 'Kış Uykusu');
    await movie('3002', 'Bir Kış Masalı');
    await movie('3003', 'Kış');
    await movie('3004', 'Kışın Ortası', hidden: true);
    await movie('3005', 'Kış Gecesi', cat: 'MH');

    await env.series(
      pid,
      '5001',
      'Sıcak Kafa',
      cast: 'Ekin Koç, Nilperi Şahinkaya',
      year: 2022,
    );
    await env.index(pid, 'series', '5001', 'Sıcak Kafa');
    await env.series(
      pid,
      '5002',
      'Kafa Kağıdı',
      cast: 'Ekin Koçak',
      year: 2019,
    );
    await env.index(pid, 'series', '5002', 'Kafa Kağıdı');

    Future<void> channel(
      String id,
      String raw,
      String display, {
      String? epg,
      String? matched,
      String? custom,
      String? cat,
      bool hidden = false,
      int? num,
    }) async {
      await env.channel(
        pid,
        id,
        raw,
        displayName: display,
        epgId: epg,
        matchedEpgId: matched,
        customEpgId: custom,
        categoryId: cat ?? 'L',
        hidden: hidden,
        num: num,
      );
      await env.index(pid, 'channel', id, display);
    }

    await channel('1001', 'TRT 1 HD', 'TRT 1', epg: 'trt1.tr', num: 1);
    await channel(
      '1002',
      'Show TV FHD',
      'Show TV',
      epg: 'show.tr',
      matched: 'showtv.xmltv',
      num: 2,
    );
    await channel('1003', 'Show Max', 'Show Max', epg: 'showmax', num: 3);
    await channel('1004', 'Show Gizli', 'Show Gizli', hidden: true);
    await channel('1005', 'Show Kategorisi', 'Show Kategorisi', cat: 'LH');
    await channel(
      '1006',
      'Kanal D',
      'Kanal D',
      epg: 'kanald',
      matched: 'kanald.matched',
      custom: 'kanald.custom',
      num: 6,
    );
    await channel(
      '1007',
      'Show TV Yedek',
      'Show TV Yedek',
      matched: 'showtv.xmltv',
      num: 7,
    );

    Future<void> programme(
      String epg,
      Duration start,
      Duration length,
      String title,
    ) async {
      final id = await env.programme(
        pid,
        epg,
        now.add(start),
        now.add(start + length),
        title,
      );
      await env.indexProgramme(pid, id, title);
    }

    const hour = Duration(hours: 1);
    await programme(
      'showtv.xmltv',
      const Duration(minutes: -30),
      hour,
      'Gündem Özel',
    );
    await programme(
      'showtv.xmltv',
      const Duration(hours: 2),
      hour,
      'Gündem Akşam',
    );
    await programme(
      'showtv.xmltv',
      const Duration(hours: -3),
      hour,
      'Gündem Sabah',
    );
    await programme('show.tr', const Duration(hours: 1), hour, 'Gündem Yanlış');
    await programme(
      'kanald.custom',
      const Duration(hours: 3),
      hour,
      'Arka Sokaklar',
    );
    await programme(
      'kanald.matched',
      const Duration(hours: 4),
      hour,
      'Arka Sokaklar Tekrar',
    );
    await programme('trt1.tr', const Duration(minutes: -10), hour, 'Haberler');

    await env.index(pid, 'person', 'Ekin Koç', 'Ekin Koç');
    await env.index(pid, 'person', 'Haluk Bilginer', 'Haluk Bilginer');
    await env.index(pid, 'person', 'Haluk Bilginer', 'Haluk Bilginer');
    await env.index(pid, 'person', 'Nilperi Şahinkaya', 'Nilperi Şahinkaya');
  });

  tearDown(() => env.close());

  List<String> movieIds(SearchResults r) =>
      r.movies.map((m) => m.providerId).toList();

  test('Turkish normalization and prefix terms', () async {
    for (final q in ['sicak kafa', 'SICAK KAFA', 'Sıcak', 'sıc ka', 'SİCAK']) {
      final r = await repo.search(pid, q);
      expect(r.series.first.providerId, '5001', reason: q);
    }
    final r = await repo.search(pid, 'sicak kafa');
    expect(r.series.map((s) => s.providerId), ['5001']);
    expect(r.normalizedQuery, 'sicak kafa');
    expect(r.elapsed, greaterThan(Duration.zero));
  });

  test(
    'exact and prefix matches rank first; hidden items are left out',
    () async {
      final r = await repo.search(pid, 'kis');
      // Kış (exact) > Kış Uykusu (prefix) > Bir Kış Masalı; hidden movie and
      // the hidden category's movie are not listed.
      expect(movieIds(r), ['3003', '3001', '3002']);
      expect(movieIds(await repo.search(pid, 'kış uyku')), ['3001']);
    },
  );

  test('quality tokens are ignored', () async {
    final r = await repo.search(pid, 'show tv fhd');
    expect(r.channels.map((c) => c.providerId).take(2), ['1002', '1007']);
    expect(r.channels.first.name, 'Show TV');
    expect(
      await repo.search(pid, 'FHD'),
      predicate<SearchResults>((r) => r.isEmpty),
    );
    expect((await repo.search(pid, ' hd ')).isEmpty, isTrue);
    expect((await repo.search(pid, '')).isEmpty, isTrue);
    expect((await repo.search(pid, '"*:()')).isEmpty, isTrue);
  });

  test('hidden channels and hidden categories are left out', () async {
    final r = await repo.search(pid, 'show');
    expect(
      r.channels.map((c) => c.providerId),
      unorderedEquals(['1002', '1003', '1007']),
    );
  });

  test('channel hits carry the programme on air', () async {
    final r = await repo.search(pid, 'trt');
    final trt = r.channels.single;
    expect(trt.providerId, '1001');
    expect(trt.epgChannelId, 'trt1.tr');
    expect(trt.now?.title, 'Haberler');
    expect(trt.now!.isOnAirAt(env.now.toUtc()), isTrue);
    final show = (await repo.search(pid, 'show tv')).channels.first;
    expect(show.epgChannelId, 'showtv.xmltv'); // matched beats the tvg-id
    expect(show.now?.title, 'Gündem Özel');
  });

  test('programmes: current and upcoming only, mapped to channels', () async {
    final r = await repo.search(pid, 'gundem');
    expect(r.programmes.map((p) => p.title), ['Gündem Özel', 'Gündem Akşam']);
    final onAir = r.programmes.first;
    expect(onAir.isOnAirAt(env.now.toUtc()), isTrue);
    expect(onAir.start.isUtc, isTrue);
    expect(onAir.channels.map((c) => c.providerId), ['1002', '1007']);

    // A custom EPG assignment wins over the matched id.
    final arka = await repo.search(pid, 'arka sokaklar');
    expect(arka.programmes.map((p) => p.title), ['Arka Sokaklar']);
    expect(arka.programmes.single.channels.single.providerId, '1006');

    // Time passes: the on-air programme ends and drops out.
    env.now = env.now.add(const Duration(hours: 1));
    final later = await repo.search(pid, 'gündem');
    expect(later.programmes.map((p) => p.title), ['Gündem Akşam']);
  });

  test('programme channels follow channel changes', () async {
    final before = await repo.search(pid, 'gundem ozel');
    expect(before.programmes.single.channels.map((c) => c.providerId), [
      '1002',
      '1007',
    ]);
    await (env.db.update(env.db.channels)
          ..where((c) => c.providerId.equals('1007')))
        .write(const ChannelsCompanion(hidden: Value(true)));
    final after = await repo.search(pid, 'gundem ozel');
    expect(after.programmes.single.channels.map((c) => c.providerId), ['1002']);
  });

  test(
    'excludeLocked leaves out locked channels and locked categories',
    () async {
      await (env.db.update(env.db.channels)
            ..where((c) => c.providerId.equals('1007')))
          .write(const ChannelsCompanion(locked: Value(true)));
      await env.category(pid, SectionKind.live, 'LL', 'Kilitli', locked: true);
      await env.channel(pid, '2001', 'Show Kilit', categoryId: 'LL');
      await env.index(pid, 'channel', '2001', 'Show Kilit');
      await env.category(pid, SectionKind.movie, 'ML', 'Kilitli', locked: true);
      await env.movie(pid, '3300', 'Kış Kilidi', categoryId: 'ML');
      await env.index(pid, 'movie', '3300', 'Kış Kilidi');

      final open = await repo.search(pid, 'show');
      expect(
        open.channels.map((c) => c.providerId),
        containsAll(['1007', '2001']),
      );
      final hidden = await repo.search(pid, 'show', excludeLocked: true);
      expect(hidden.channels.map((c) => c.providerId), isNot(contains('1007')));
      expect(hidden.channels.map((c) => c.providerId), isNot(contains('2001')));

      expect(movieIds(await repo.search(pid, 'kis kilidi')), ['3300']);
      expect(
        movieIds(await repo.search(pid, 'kis kilidi', excludeLocked: true)),
        isEmpty,
      );

      final gundem = await repo.search(pid, 'gundem ozel', excludeLocked: true);
      expect(gundem.programmes.single.channels.map((c) => c.providerId), [
        '1002',
      ]);
    },
  );

  test('filters choose the sections', () async {
    final all = await repo.search(pid, 'kafa');
    expect(all.series, hasLength(2));
    final movies = await repo.search(pid, 'kis', filter: SearchFilter.movies);
    expect(movies.movies, isNotEmpty);
    expect(movies.series, isEmpty);
    expect(movies.channels, isEmpty);
    expect(movies.programmes, isEmpty);
    final shows = await repo.search(pid, 'kafa', filter: SearchFilter.shows);
    expect(shows.series, hasLength(2));
    expect(shows.movies, isEmpty);
    final live = await repo.search(pid, 'gundem', filter: SearchFilter.live);
    expect(live.programmes, hasLength(2));
    final liveChannels = await repo.search(
      pid,
      'show',
      filter: SearchFilter.live,
    );
    expect(liveChannels.channels, isNotEmpty);
    expect(liveChannels.movies, isEmpty);
    final people = await repo.search(pid, 'ekin', filter: SearchFilter.people);
    expect(people.people.map((p) => p.name), ['Ekin Koç']);
    expect(people.series, isEmpty);
    expect(
      (await repo.search(pid, 'kis', limitPerSection: 1)).movies,
      hasLength(1),
    );
  });

  test('people are distinct', () async {
    final r = await repo.search(pid, 'haluk');
    expect(r.people, [
      const PersonHit(name: 'Haluk Bilginer', displayName: 'Haluk Bilginer'),
    ]);
    final s = await repo.search(pid, 'sahinkaya');
    expect(s.people.single.displayName, 'Nilperi Şahinkaya');
  });

  test('titlesByPerson uses series cast and cached movie info', () async {
    await env.movie(
      pid,
      '3100',
      'Film A',
      year: 2020,
      categoryId: 'M',
      infoJson: jsonEncode({
        'info': {'name': 'Film A', 'actors': 'Ekin Koç, Ahmet Mümtaz Taylan'},
        'movie_data': {'stream_id': 3100},
      }),
    );
    await env.movie(
      pid,
      '3101',
      'Film B',
      year: 2023,
      categoryId: 'M',
      infoJson: jsonEncode({
        'info': {'name': 'Film B', 'cast': 'Ekin Koçak'},
        'movie_data': {'stream_id': 3101},
      }),
    );
    await env.movie(
      pid,
      '3102',
      'Film C',
      year: 2021,
      categoryId: 'MH',
      infoJson: jsonEncode({
        'info': {'name': 'Film C', 'actors': 'Ekin Koç'},
      }),
    );
    final t = await repo.titlesByPerson(pid, 'Ekin Koç');
    expect(t.series.map((s) => s.providerId), ['5001']);
    expect(t.movies.map((m) => m.providerId), ['3100']);
    expect((await repo.titlesByPerson(pid, 'Nobody')).isEmpty, isTrue);
    expect((await repo.titlesByPerson(pid, '  ')).isEmpty, isTrue);
    // LIKE wildcards in names are escaped.
    expect((await repo.titlesByPerson(pid, '%')).isEmpty, isTrue);
  });

  test(
    'results are per playlist; integer playlist ids in the index work',
    () async {
      final other = await env.playlist(name: 'Other');
      await env.movie(other, '9001', 'Kış Uykusu');
      await env.index(other, 'movie', '9001', 'Kış Uykusu', asInt: true);
      await env.movie(pid, '3200', 'Kış Masalı');
      await env.index(pid, 'movie', '3200', 'Kış Masalı', asInt: true);
      expect(movieIds(await repo.search(pid, 'uykusu')), ['3001']);
      expect(movieIds(await repo.search(other, 'uykusu')), ['9001']);
      expect(movieIds(await repo.search(pid, 'masali')), ['3200', '3002']);
    },
  );
}
