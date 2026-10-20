import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/repositories/category_repository.dart';
import 'package:carina/data/repositories/epg_repository.dart';
import 'package:carina/data/repositories/live_repository.dart';
import 'package:carina/data/repositories/playlist_repository.dart';
import 'package:carina/data/repositories/repository_models.dart';

import 'fixtures.dart';

/// Median wall time of [runs] calls of [body] after one warm-up call.
Future<double> medianMs(Future<void> Function() body, {int runs = 7}) async {
  await body();
  final times = <double>[];
  for (var i = 0; i < runs; i++) {
    final sw = Stopwatch()..start();
    await body();
    times.add(sw.elapsedMicroseconds / 1000);
  }
  times.sort();
  return times[times.length ~/ 2];
}

void main() {
  late R1Env env;
  late int pid;

  setUp(() async {
    env = await R1Env.create();
    pid = await env.playlist();
  });
  tearDown(() => env.dispose());

  test('EPG: 2,000 channels × 2 days of 30-min programmes', () async {
    const channels = 2000;
    const slots = 96; // 2 days
    final base = DateTime.utc(2026, 10, 16);
    final seed = Stopwatch()..start();
    await env.db.customStatement(
      'WITH RECURSIVE '
      'ch(i) AS (SELECT 0 UNION ALL SELECT i + 1 FROM ch WHERE i < ${channels - 1}), '
      'slot(j) AS (SELECT 0 UNION ALL SELECT j + 1 FROM slot WHERE j < ${slots - 1}) '
      'INSERT INTO programmes (playlist_id, epg_channel_id, start, stop, title, description) '
      "SELECT ?, 'ch' || i, ? + j * 1800000, ? + (j + 1) * 1800000, "
      "'Programme ' || i || '-' || j, 'Description of programme ' || j "
      'FROM ch, slot',
      [pid, base.millisecondsSinceEpoch, base.millisecondsSinceEpoch],
    );
    final count = await env.db
        .customSelect('SELECT COUNT(*) AS n FROM programmes')
        .getSingle();
    expect(count.read<int>('n'), channels * slots);
    debugPrint(
      'seeded ${channels * slots} programmes in ${seed.elapsedMilliseconds} ms',
    );

    final playlists = PlaylistRepository(env.db, env.secrets, env.settings);
    final repo = EpgRepository(env.db, playlists);
    addTearDown(repo.dispose);
    final at = base.add(const Duration(days: 1, minutes: 10));
    final keys50 = [for (var i = 0; i < 50; i++) 'ch${(i * 37) % channels}'];
    final keys40 = [for (var i = 0; i < 40; i++) 'ch${100 + i}'];

    late Map<String, NowNext> nn;
    final nowNextMs = await medianMs(() async {
      nn = await repo.nowNext(pid, keys50, at: at);
    });
    expect(nn, hasLength(50));
    expect(nn.values.every((v) => v.now != null && v.next != null), isTrue);
    expect(nn['ch0']!.now!.start, base.add(const Duration(days: 1)));

    late Map<String, List<ProgrammeView>> grid;
    final from = at.subtract(const Duration(hours: 1));
    final to = from.add(const Duration(hours: 6));
    final guideMs = await medianMs(() async {
      grid = await repo.guide(pid, keys40, from, to);
    });
    expect(grid, hasLength(40));
    // 23:10 … 05:10: the 23:00 programme plus the 12 starting inside.
    expect(grid.values.every((l) => l.length == 13), isTrue);

    final archiveCh = await env.db
        .into(env.db.channels)
        .insertReturning(
          ChannelsCompanion.insert(
            playlistId: pid,
            providerId: 'a1',
            name: 'Archive',
            displayName: 'Archive',
            matchedEpgId: const Value('ch5'),
            archiveDays: const Value(2),
          ),
        );
    late List<ArchiveDay> archive;
    final archiveMs = await medianMs(() async {
      archive = await repo.archive(pid, archiveCh, now: at);
    });
    expect(archive, isNotEmpty);
    final rangeMs = await medianMs(() => repo.dataRange(pid));

    debugPrint(
      'nowNext(50 keys): ${nowNextMs.toStringAsFixed(2)} ms · '
      'guide(40 keys × 6 h): ${guideMs.toStringAsFixed(2)} ms · '
      'archive(2 days): ${archiveMs.toStringAsFixed(2)} ms · '
      'dataRange: ${rangeMs.toStringAsFixed(2)} ms',
    );
    expect(nowNextMs, lessThan(50));
    expect(guideMs, lessThan(50));
  });

  test('live: 20,000 channels in 200 categories', () async {
    const total = 20000;
    await env.db.customStatement(
      'WITH RECURSIVE c(i) AS (SELECT 0 UNION ALL SELECT i + 1 FROM c WHERE i < 199) '
      'INSERT INTO categories (playlist_id, kind, provider_id, name, sort_index) '
      "SELECT ?, 0, 'cat' || i, 'Kategori ' || i, i FROM c",
      [pid],
    );
    await env.db.customStatement(
      'WITH RECURSIVE c(i) AS (SELECT 0 UNION ALL SELECT i + 1 FROM c WHERE i < ${total - 1}) '
      'INSERT INTO channels (playlist_id, provider_id, num, name, display_name, '
      'quality, category_id, matched_epg_id, archive_days, sort_index, added) '
      "SELECT ?, 's' || i, i + 1, 'Kanal ' || i || ' HD', 'Kanal ' || i, 'HD', "
      "'cat' || (i % 200), 'ch' || i, i % 3, i, 1760000000 + i FROM c",
      [pid],
    );
    for (var i = 0; i < 200; i++) {
      await env.favorite(pid, 's${i * 50}');
    }
    final live = LiveRepository(env.db, env.settings);
    addTearDown(live.dispose);
    final categories = CategoryRepository(env.db, env.settings);

    final allMs = await medianMs(() async {
      // The stream's compute path always queries (no cache).
      final list = await live.watchChannels(pid, const AllCategory()).first;
      expect(list, hasLength(total));
    }, runs: 3);
    final categoryMs = await medianMs(() async {
      final list = await live
          .watchChannels(pid, const ProviderCategory('cat7'))
          .first;
      expect(list, hasLength(100));
    });
    await live.channels(pid, const AllCategory());
    final neighborsMs = await medianMs(() async {
      final n = await live.neighbors(pid, const AllCategory(), 's10000');
      expect(n.next!.providerId, 's10001');
    });
    final sidebarMs = await medianMs(() async {
      final list = await categories.categories(pid, SectionKind.live);
      expect(list.where((c) => !c.isSpecial), hasLength(200));
    });
    final numberMs = await medianMs(() async {
      expect((await live.channelByNumber(pid, 12345))!.providerId, 's12344');
    });
    debugPrint(
      'live 20k: All list ${allMs.toStringAsFixed(1)} ms · '
      'category (100) ${categoryMs.toStringAsFixed(2)} ms · '
      'neighbors (cached) ${neighborsMs.toStringAsFixed(3)} ms · '
      'sidebar (200 categories) ${sidebarMs.toStringAsFixed(1)} ms · '
      'number lookup ${numberMs.toStringAsFixed(2)} ms',
    );
    expect(categoryMs, lessThan(50));
    expect(neighborsMs, lessThan(5));
  });

  test('movies: 60,000 items in 500 categories (sidebar)', () async {
    await env.db.customStatement(
      'WITH RECURSIVE c(i) AS (SELECT 0 UNION ALL SELECT i + 1 FROM c WHERE i < 499) '
      'INSERT INTO categories (playlist_id, kind, provider_id, name, sort_index) '
      "SELECT ?, 1, 'm' || i, 'Film Kategori ' || i, i FROM c",
      [pid],
    );
    await env.db.customStatement(
      'WITH RECURSIVE c(i) AS (SELECT 0 UNION ALL SELECT i + 1 FROM c WHERE i < 59999) '
      'INSERT INTO movies (playlist_id, provider_id, name, category_id, '
      'sort_index, added, hidden) '
      "SELECT ?, 'v' || i, 'Film ' || i, 'm' || (i % 500), i, "
      '1760000000 + i, i % 97 = 0 FROM c',
      [pid],
    );
    final categories = CategoryRepository(env.db, env.settings);
    late List<CategoryView> list;
    final ms = await medianMs(() async {
      list = await categories.categories(pid, SectionKind.movie);
    });
    final providers = list.where((c) => !c.isSpecial).toList();
    expect(providers, hasLength(500));
    expect(providers.fold<int>(0, (n, c) => n + c.count), 60000 - 619);
    debugPrint('movie sidebar (60k / 500): ${ms.toStringAsFixed(1)} ms');
    expect(ms, lessThan(500));
  });
}
