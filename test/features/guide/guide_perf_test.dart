import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/app/clock.dart';
import 'package:carina/data/app_paths.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/repositories/epg_repository.dart';
import 'package:carina/data/repositories/playlist_repository.dart';
import 'package:carina/data/secrets/secret_store.dart';
import 'package:carina/data/settings/settings_store.dart';
import 'package:carina/features/guide/guide_screen.dart';
import 'package:carina/features/guide/src/guide_actions.dart';
import 'package:carina/features/guide/src/guide_grid.dart';
import 'package:carina/player/engine/fake_engine.dart';
import 'package:carina/player/engine/playback_engine.dart';

import 'guide_test_support.dart';

const _channels = 1000;
const _days = 8; // one day back, seven ahead

/// Frame-time summary in milliseconds.
String _summary(String name, List<Duration> frames) {
  final ms = frames.map((d) => d.inMicroseconds / 1000).toList()..sort();
  final avg = ms.reduce((a, b) => a + b) / ms.length;
  final p95 = ms[(ms.length * 0.95).floor().clamp(0, ms.length - 1)];
  return '$name: ${ms.length} frames, avg ${avg.toStringAsFixed(2)} ms, '
      'p95 ${p95.toStringAsFixed(2)} ms, max ${ms.last.toStringAsFixed(2)} ms';
}

double _avgMs(List<Duration> frames) =>
    frames.map((d) => d.inMicroseconds / 1000).reduce((a, b) => a + b) /
    frames.length;

/// Database, settings and secrets for the perf test.
class _PerfEnv {
  _PerfEnv(this.db, this.settings, this.secrets);

  final AppDatabase db;
  final SettingsStore settings;
  final MemorySecretStore secrets;
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets(
    'perf: 1,000 channels × 7 days scroll on both axes',
    (tester) async {
      final now = fixedNow();
      final base = DateTime(
        now.year,
        now.month,
        now.day - 1,
      ).toUtc().millisecondsSinceEpoch;
      late _PerfEnv env;
      late Directory tempDir;
      late int pid;
      late int programmes;
      final seed = Stopwatch()..start();
      await tester.runAsync(() async {
        // A background-isolate database, as in the app (drift_flutter):
        // queries never run inside a frame.
        tempDir = await Directory.systemTemp.createTemp('carina_guide_perf_');
        final db = AppDatabase.forTesting(
          NativeDatabase.createInBackground(File('${tempDir.path}/perf.db')),
        );
        final settings = SettingsStore(db);
        await settings.load();
        env = _PerfEnv(db, settings, MemorySecretStore());
        pid = await db
            .into(db.playlists)
            .insert(
              PlaylistsCompanion.insert(
                name: 'Perf',
                type: PlaylistType.m3u,
                createdAt: DateTime(2026),
              ),
            );
        await db
            .into(db.categories)
            .insert(
              CategoriesCompanion.insert(
                playlistId: pid,
                kind: SectionKind.live,
                providerId: 'cat',
                name: 'Perf',
              ),
            );
        await env.db.customStatement(
          'WITH RECURSIVE ch(i) AS (SELECT 0 UNION ALL SELECT i + 1 FROM ch '
          'WHERE i < ${_channels - 1}) '
          'INSERT INTO channels (playlist_id, provider_id, name, display_name, '
          'category_id, matched_epg_id, sort_index, archive_days) '
          "SELECT ?, 'p' || i, 'Channel ' || i, 'Channel ' || i, 'cat', "
          "'ch' || i, i, CASE WHEN i % 5 = 0 THEN 3 ELSE 0 END FROM ch",
          [pid],
        );
        // 30, 45 or 60-minute programmes, depending on the channel.
        await env.db.customStatement(
          'WITH RECURSIVE ch(i) AS (SELECT 0 UNION ALL SELECT i + 1 FROM ch '
          'WHERE i < ${_channels - 1}), '
          'slot(j) AS (SELECT 0 UNION ALL SELECT j + 1 FROM slot '
          'WHERE j < ${_days * 48 - 1}) '
          'INSERT INTO programmes (playlist_id, epg_channel_id, start, stop, '
          'title, description) '
          "SELECT ?, 'ch' || i, ? + j * (30 + (i % 3) * 15) * 60000, "
          '? + (j + 1) * (30 + (i % 3) * 15) * 60000, '
          "'Programme ' || i || '·' || j, 'Description ' || j "
          'FROM ch, slot WHERE j * (30 + (i % 3) * 15) < ${_days * 1440}',
          [pid, base, base],
        );
        programmes =
            (await env.db
                    .customSelect('SELECT COUNT(*) AS n FROM programmes')
                    .getSingle())
                .read<int>('n');
      });
      debugPrint(
        'seeded $_channels channels / $programmes programmes in '
        '${seed.elapsedMilliseconds} ms',
      );

      // Query cost of one load (40 rows × one 6-hour chunk).
      final repo = EpgRepository(
        env.db,
        PlaylistRepository(env.db, env.secrets, env.settings),
      );
      final queryMs = (await tester.runAsync(() async {
        final keys = [for (var i = 300; i < 340; i++) 'ch$i'];
        final from = DateTime.fromMillisecondsSinceEpoch(
          base + 86400000,
          isUtc: true,
        );
        await repo.guide(pid, keys, from, from.add(const Duration(hours: 6)));
        final sw = Stopwatch()..start();
        for (var r = 0; r < 5; r++) {
          await repo.guide(
            pid,
            keys,
            from.add(Duration(hours: r * 6)),
            from.add(Duration(hours: r * 6 + 6)),
          );
        }
        return sw.elapsedMicroseconds / 5000;
      }))!;
      repo.dispose();
      debugPrint(
        'guide(40 keys × 6 h) query: ${queryMs.toStringAsFixed(2)} ms',
      );

      await pumpScreen(
        tester,
        GuideScreen(playlistId: pid),
        overrides: [
          appDatabaseProvider.overrideWithValue(env.db),
          settingsStoreProvider.overrideWithValue(env.settings),
          secretStoreProvider.overrideWithValue(env.secrets),
          playbackEngineFactoryProvider.overrideWithValue(
            FakeEngineFactory(autoTick: false),
          ),
          minuteClockProvider.overrideWith((ref) => Stream.value(now)),
          clockSourceProvider.overrideWithValue(() => now),
          guideActionsProvider.overrideWithValue(RecordingGuideActions()),
        ],
      );
      await settleDrift(tester, rounds: 30);
      expect(find.text('Channel 0'), findsOneWidget);

      final scrollables = find.descendant(
        of: find.byType(GuideGrid),
        matching: find.byType(Scrollable),
      );
      final v = tester.state<ScrollableState>(scrollables.first).position;
      final h = tester.state<ScrollableState>(scrollables.at(1)).position;
      expect(v.maxScrollExtent, greaterThan(_channels * 60));

      final scrollFrames = <Duration>[];
      final jumpFrames = <Duration>[];
      final dataFrames = <Duration>[];
      Future<void> frame(List<Duration> into) async {
        final sw = Stopwatch()..start();
        await tester.pump();
        into.add(sw.elapsed);
      }

      // Warm-up (debug JIT compiles the scrolling paths on first use); not
      // measured.
      final warmup = <Duration>[];
      for (var i = 0; i < 60; i++) {
        v.jumpTo((v.pixels + 53).clamp(0, v.maxScrollExtent));
        h.jumpTo((h.pixels + 61).clamp(0, h.maxScrollExtent));
        await frame(warmup);
        if (i % 10 == 9) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 15)),
          );
          await frame(warmup);
        }
      }
      v.jumpTo(0);
      h.jumpTo(h.maxScrollExtent / 3);
      await frame(warmup);

      // One axis at a time (diagnostics).
      final verticalFrames = <Duration>[];
      final horizontalFrames = <Duration>[];
      for (final (axis, into, step) in [
        (v, verticalFrames, 37.0),
        (h, horizontalFrames, 45.0),
      ]) {
        for (var i = 0; i < 80; i++) {
          axis.jumpTo((axis.pixels + step).clamp(0, axis.maxScrollExtent));
          await frame(into);
          if (i % 8 == 7) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 15)),
            );
            await frame(dataFrames);
          }
        }
      }
      debugPrint(_summary('vertical-only frames', verticalFrames));
      debugPrint(_summary('horizontal-only frames', horizontalFrames));

      // Smooth scrolling: 37 px down and 45 px right per frame (both
      // axes), letting the loads land every 8 frames.
      for (var i = 0; i < 240; i++) {
        v.jumpTo((v.pixels + 37).clamp(0, v.maxScrollExtent));
        h.jumpTo((h.pixels + 45).clamp(0, h.maxScrollExtent));
        await frame(scrollFrames);
        if (i % 8 == 7) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 15)),
          );
          await frame(dataFrames);
        }
      }
      // Big jumps across the list and the week (cold rows and chunks).
      for (var i = 0; i < 40; i++) {
        v.jumpTo(v.maxScrollExtent * ((i * 7) % 40) / 40);
        h.jumpTo(h.maxScrollExtent * ((i * 11) % 40) / 40);
        await frame(jumpFrames);
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 15)),
        );
        await frame(dataFrames);
      }
      debugPrint(_summary('smooth scroll frames, both axes', scrollFrames));
      debugPrint(_summary('jump frames (a new page of rows/time)', jumpFrames));
      debugPrint(_summary('frames after data loads', dataFrames));

      // Debug-mode JIT numbers on the UI thread (build + layout + paint;
      // raster excluded); profile/release builds are several times faster.
      // Generous bounds keep the test stable on a busy machine.
      expect(_avgMs(scrollFrames), lessThan(16));
      expect(_avgMs(dataFrames), lessThan(16));
      expect(_avgMs(jumpFrames), lessThan(120));
      await unmountAndFlush(tester);
      await tester.runAsync(() async {
        await env.db.close();
        await tempDir.delete(recursive: true);
      });
    },
    timeout: const Timeout(Duration(minutes: 5)),
    // As in the app without assistive technology (flutter_test builds the
    // semantics tree by default, ~2 ms per frame here).
    semanticsEnabled: false,
  );
}
