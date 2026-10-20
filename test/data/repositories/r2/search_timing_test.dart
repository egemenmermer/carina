import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/repositories/search_repository.dart';
import 'package:carina/data/text/normalize.dart';

import 'r2_fixtures.dart';

/// "Search keystroke → results < 100 ms on 80k items".
///
/// Seeds 60k movies + 8k series + 12k channels (plus 10k people and 50k
/// EPG programmes) into the tables and FTS indexes, then times full
/// `search()` calls (index query, hydration, now-playing and programme
/// search) for 10 typical queries.
void main() {
  test('search p50/p95 on 80k items', () async {
    final env = await R2Env.create();
    final pid = await env.playlist();
    final rng = Random(7);
    final words = _vocabulary(rng);
    String title() {
      final n = 1 + rng.nextInt(4);
      return List.generate(n, (_) {
        // Skewed: common words appear far more often.
        final i = (pow(rng.nextDouble(), 2.2) * words.length).floor();
        return words[i];
      }).join(' ');
    }

    final seed = Stopwatch()..start();
    const indexSql =
        'INSERT INTO search_index(normalized, title, kind, ref_id, '
        'playlist_id) VALUES (?, ?, ?, ?, ?)';
    final now = env.now;
    final nowMs = now.toUtc().millisecondsSinceEpoch;
    await env.db.batch((b) {
      for (var i = 0; i < 60000; i++) {
        final name = i == 4242 ? 'Kış Uykusu' : title();
        b.insert(
          env.db.movies,
          MoviesCompanion.insert(
            playlistId: pid,
            providerId: 'm$i',
            name: name,
            poster: Value('http://img.test/m$i.jpg'),
            categoryId: Value('c${i % 300}'),
            sortIndex: Value(i),
          ),
        );
        b.customStatement(indexSql, [
          normalizeForSearch(name),
          name,
          'movie',
          'm$i',
          '$pid',
        ]);
      }
      for (var i = 0; i < 8000; i++) {
        final name = i == 77 ? 'Sıcak Kafa' : title();
        b.insert(
          env.db.series,
          SeriesCompanion.insert(
            playlistId: pid,
            providerId: 's$i',
            name: name,
            categoryId: Value('d${i % 80}'),
            sortIndex: Value(i),
          ),
        );
        b.customStatement(indexSql, [
          normalizeForSearch(name),
          name,
          'series',
          's$i',
          '$pid',
        ]);
      }
      for (var i = 0; i < 12000; i++) {
        final raw = switch (i) {
          1 => 'TRT 1 HD',
          2 => 'Show TV FHD',
          _ => '${title()}${i.isEven ? ' HD' : ''}',
        };
        final display = raw.replaceAll(RegExp(r' (HD|FHD)$'), '');
        b.insert(
          env.db.channels,
          ChannelsCompanion.insert(
            playlistId: pid,
            providerId: '$i',
            name: raw,
            displayName: display,
            epgId: Value('epg${i % 2000}'),
            sortIndex: Value(i),
          ),
        );
        b.customStatement(indexSql, [
          normalizeForSearch(display),
          display,
          'channel',
          '$i',
          '$pid',
        ]);
      }
      for (var i = 0; i < 10000; i++) {
        final name =
            '${words[rng.nextInt(words.length)]} '
            '${words[rng.nextInt(words.length)]}';
        b.customStatement(indexSql, [
          normalizeForSearch(name),
          name,
          'person',
          name,
          '$pid',
        ]);
      }
      for (var i = 0; i < 50000; i++) {
        final start = nowMs + (i % 25 - 2) * 3600 * 1000;
        final name = title();
        b.insert(
          env.db.programmes,
          ProgrammesCompanion.insert(
            id: Value(i + 1),
            playlistId: pid,
            epgChannelId: 'epg${i % 2000}',
            start: start,
            stop: start + 3600 * 1000,
            title: name,
          ),
        );
        b.customStatement(
          'INSERT INTO programme_search(normalized, programme_id, '
          'playlist_id) VALUES (?, ?, ?)',
          [normalizeForSearch(name), i + 1, pid],
        );
      }
    });
    seed.stop();

    final repo = SearchRepository(db: env.db, clock: env.clock);
    await repo.search(pid, 'warm up');
    const queries = [
      'sicak kafa',
      'kis',
      'a',
      'ka',
      'show tv',
      'trt 1',
      'gece',
      'sev',
      'mor ta',
      'kara',
    ];
    double ms(int us) => us / 1000;
    ({double p50, double p95}) percentiles(List<int> us) {
      final sorted = [...us]..sort();
      return (
        p50: ms((sorted[4] + sorted[5]) ~/ 2),
        p95: ms(sorted[9]), // the slowest of 10
      );
    }

    // Round 1 is the first time each query runs (JIT warm-up included);
    // rounds 2–3 repeat them (steady state, as when typing on).
    final rounds = <List<int>>[];
    final lines = <String>[];
    for (var round = 0; round < 3; round++) {
      final times = <int>[];
      for (final q in queries) {
        final watch = Stopwatch()..start();
        final r = await repo.search(pid, q);
        watch.stop();
        times.add(watch.elapsedMicroseconds);
        if (round == 0) {
          lines.add(
            '  "$q": ${ms(watch.elapsedMicroseconds).toStringAsFixed(1)} ms '
            '(${r.movies.length} movies, ${r.series.length} series, '
            '${r.channels.length} channels, ${r.programmes.length} '
            'programmes, ${r.people.length} people)',
          );
        }
      }
      rounds.add(times);
    }
    final first = percentiles(rounds.first);
    final steady = percentiles(rounds.last);
    debugPrint(
      'search timing (seed ${seed.elapsedMilliseconds} ms; 60k movies, '
      '8k series, 12k channels, 10k people, 50k programmes):\n'
      '${lines.join('\n')}\n'
      '  first pass: p50 = ${first.p50.toStringAsFixed(1)} ms, '
      'p95 = ${first.p95.toStringAsFixed(1)} ms\n'
      '  steady:     p50 = ${steady.p50.toStringAsFixed(1)} ms, '
      'p95 = ${steady.p95.toStringAsFixed(1)} ms',
    );

    final sicak = await repo.search(pid, 'sicak kafa');
    expect(sicak.series.first.name, 'Sıcak Kafa');
    final kis = await repo.search(pid, 'kis uykusu');
    expect(kis.movies.first.name, 'Kış Uykusu');
    expect(
      (await repo.search(pid, 'show tv fhd')).channels.first.name,
      'Show TV',
    );

    expect(first.p50, lessThan(100), reason: 'search latency budget');
    expect(steady.p95, lessThan(100), reason: 'search latency budget');
    // The very first pass includes JIT warm-up; allow headroom on a loaded
    // machine.
    expect(first.p95, lessThan(250));
    await env.close();
  }, timeout: const Timeout(Duration(minutes: 5)));
}

/// ~4,000 pseudo-words from Turkish-like syllables plus common real words.
List<String> _vocabulary(Random rng) {
  const syllables = [
    'ka',
    'ra',
    'se',
    'mor',
    'ta',
    'li',
    'gün',
    'aş',
    'kı',
    'de',
    'ni',
    'şa',
    'yol',
    'can',
    'su',
    'ev',
    'ay',
    'ışık',
    'gö',
    'rü',
    'ba',
    'çe',
    'mi',
    'zor',
    'lu',
    'pe',
    'ri',
    'ko',
    'nu',
    'sa',
    'ha',
    'ber',
    'ti',
    'za',
    'man',
    'dü',
    'ya',
    'ze',
    'fi',
    'lm',
    'ste',
    'ar',
    'ol',
    'um',
    'en',
    'in',
    'on',
    'er',
  ];
  const real = [
    'Aşk',
    'Gece',
    'Kara',
    'Sevda',
    'Kış',
    'Yaz',
    'Show',
    'TV',
    'The',
    'Love',
    'Night',
    'Dark',
    'Star',
    'War',
    'King',
    'Kral',
    'Aile',
    'Ev',
    'Yol',
    'Haber',
    'Spor',
    'Film',
    'Dizi',
    'Çocuk',
    'Belgesel',
    'Müzik',
  ];
  final words = <String>{...real};
  while (words.length < 4000) {
    final n = 2 + rng.nextInt(2);
    final w = List.generate(
      n,
      (_) => syllables[rng.nextInt(syllables.length)],
    ).join();
    words.add(w[0].toUpperCase() + w.substring(1));
  }
  return words.toList();
}
