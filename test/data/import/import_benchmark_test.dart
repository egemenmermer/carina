// Opt-in benchmark:
//   CARINA_BENCH=1 flutter test test/data/import/import_benchmark_test.dart
// The large mock server runs on its own isolate (like a remote server) and
// the database is a file opened on a background isolate (like the app).
// ignore_for_file: avoid_print
@Tags(['bench'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart' show Value, Variable, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/app_paths.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/import/import.dart';
import 'package:carina/data/secrets/secret_store.dart';
import 'package:carina/data/settings/settings_store.dart';

import '../../../tools/mock_server/src/server.dart';

void main() {
  final enabled = Platform.environment['CARINA_BENCH'] == '1';
  final skip = enabled ? false : 'Set CARINA_BENCH=1 to run the benchmark';

  late Directory temp;
  late _RemoteServer server;
  late AppDatabase db;
  late ImportService service;
  late int pid;

  setUpAll(() async {
    if (!enabled) return;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    temp = await Directory.systemTemp.createTemp('carina_bench_');
    server = await _RemoteServer.start(temp.path);
    print(
      'mock server (large): started in ${server.startMs} ms, '
      'list caches warmed in ${server.warmUpMs} ms',
    );
    db = AppDatabase.forTesting(
      NativeDatabase.createInBackground(File('${temp.path}/kanal.sqlite')),
    );
    final paths = await AppPaths.resolve(override: '${temp.path}/data');
    final settings = SettingsStore(db);
    await settings.load();
    final secrets = MemorySecretStore();
    service = ImportService(
      db: db,
      paths: paths,
      secrets: secrets,
      settings: settings,
      config: ImportConfig(
        retries: 0,
        log: Platform.environment['CARINA_BENCH_LOG'] == '1' ? print : null,
      ),
    );
    pid = await db
        .into(db.playlists)
        .insert(
          PlaylistsCompanion.insert(
            name: 'Large',
            type: PlaylistType.xtream,
            server: Value(server.baseUrl),
            username: const Value(MockFixtures.username),
            epgUrl: Value('${server.baseUrl}/epg.xml.gz'),
            createdAt: DateTime.now(),
          ),
        );
    await secrets.write(
      SecretStore.playlistPassword(pid),
      MockFixtures.password,
    );
  });

  tearDownAll(() async {
    if (!enabled) return;
    await service.dispose();
    await db.close();
    await server.stop();
    await temp.delete(recursive: true);
  });

  test(
    'large Xtream import (20k live / 60k movies / 8k series) < 45 s',
    () async {
      final run = await _measure(
        service.start(pid, scope: ImportScope.content),
      );
      final p = run.last;
      expect(p.step, ImportStep.completed, reason: '$p');
      _report('content', run);
      final row = await (db.select(
        db.playlists,
      )..where((t) => t.id.equals(pid))).getSingle();
      print(
        'stored: ${row.liveCount} live, ${row.movieCount} movies, '
        '${row.seriesCount} series',
      );
      expect(row.liveCount, 20000);
      expect(row.movieCount, 60000);
      expect(row.seriesCount, 8000);
      expect(run.elapsed, lessThan(const Duration(seconds: 45)));

      // A reload of the same catalog (every row is an update).
      final again = await _measure(
        service.start(pid, scope: ImportScope.content),
      );
      expect(again.last.step, ImportStep.completed);
      _report('content reload', again);
      expect(again.elapsed, lessThan(const Duration(seconds: 45)));
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 10)),
  );

  test(
    'large XMLTV (~1M programmes) parse + store < 90 s',
    () async {
      // Let the mock generate and cache the gzip guide first, so the import
      // is measured without the mock's generation time.
      final gen = Stopwatch()..start();
      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse('${server.baseUrl}/epg.xml.gz'),
      );
      final response = await request.close();
      var bytes = 0;
      await for (final chunk in response) {
        bytes += chunk.length;
      }
      client.close();
      print(
        'mock XMLTV generation + gzip: ${gen.elapsedMilliseconds} ms '
        '(${(bytes / (1 << 20)).toStringAsFixed(1)} MB gzip)',
      );

      final run = await _measure(service.start(pid, scope: ImportScope.epg));
      final p = run.last;
      expect(p.step, ImportStep.completed, reason: '$p');
      _report('epg', run);
      final row = await (db.select(
        db.playlists,
      )..where((t) => t.id.equals(pid))).getSingle();
      final matched = await db
          .customSelect(
            'SELECT COUNT(*) AS n FROM channels WHERE playlist_id = ? '
            'AND matched_epg_id IS NOT NULL',
            variables: [Variable.withInt(pid)],
          )
          .getSingle();
      print(
        'stored: ${row.programmeCount} programmes; '
        '${matched.read<int>('n')} of ${row.liveCount} channels matched',
      );
      expect(row.programmeCount, greaterThan(900000));
      expect(run.elapsed, lessThan(const Duration(seconds: 90)));

      // Re-import over the existing guide (replace path).
      final again = await _measure(service.start(pid, scope: ImportScope.epg));
      expect(again.last.step, ImportStep.completed);
      _report('epg reload', again);
      final row2 = await (db.select(
        db.playlists,
      )..where((t) => t.id.equals(pid))).getSingle();
      expect(row2.programmeCount, row.programmeCount);
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 15)),
  );
}

typedef _Run = ({
  ImportProgress last,
  Duration elapsed,
  int events,
  Duration maxStall,
  int peakRssMb,
  List<String> stalls,
});

/// Collects a run and measures the longest event-loop stall of this isolate
/// (what the UI isolate would feel) and the peak RSS.
Future<_Run> _measure(Stream<ImportProgress> stream) async {
  final watch = Stopwatch()..start();
  var last = watch.elapsedMicroseconds;
  var maxStall = 0;
  ImportProgress? progress;
  final stalls = <String>[];
  final ticker = Timer.periodic(const Duration(milliseconds: 4), (_) {
    final now = watch.elapsedMicroseconds;
    final gap = now - last;
    if (gap > maxStall) maxStall = gap;
    if (gap > 50000) {
      stalls.add(
        '${gap ~/ 1000} ms at ${(now / 1e6).toStringAsFixed(2)} s '
        '(${progress?.step.name})',
      );
    }
    last = now;
  });
  var peak = ProcessInfo.currentRss;
  var events = 0;
  await for (final p in stream) {
    progress = p;
    events++;
    final rss = ProcessInfo.currentRss;
    if (rss > peak) peak = rss;
  }
  ticker.cancel();
  return (
    last: progress!,
    elapsed: watch.elapsed,
    events: events,
    maxStall: Duration(microseconds: maxStall),
    peakRssMb: peak >> 20,
    stalls: stalls,
  );
}

void _report(String label, _Run run) {
  final steps = run.last.stepDurations.entries
      .map(
        (e) =>
            '${e.key.name} ${(e.value.inMilliseconds / 1000).toStringAsFixed(2)} s',
      )
      .join(', ');
  print(
    '$label: ${(run.elapsed.inMilliseconds / 1000).toStringAsFixed(2)} s total '
    '($steps); ${run.events} progress events; '
    'max event-loop stall ${run.maxStall.inMilliseconds} ms; '
    'peak RSS ${run.peakRssMb} MB; counts ${run.last.counts.map((k, v) => MapEntry(k.name, v))}',
  );
  if (run.stalls.isNotEmpty) {
    print('  stalls > 50 ms: ${run.stalls.join('; ')}');
  }
}

/// The large mock server on its own isolate.
final class _RemoteServer {
  _RemoteServer(this.baseUrl, this._control, this.startMs, this.warmUpMs);

  final String baseUrl;
  final SendPort _control;
  final int startMs;
  final int warmUpMs;

  static Future<_RemoteServer> start(String root) async {
    final media = Directory('$root/media')..createSync(recursive: true);
    final live = Directory('$root/live')..createSync(recursive: true);
    final port = ReceivePort();
    await Isolate.spawn(_serve, [port.sendPort, media.path, live.path]);
    final reply = await port.first as List<Object?>;
    return _RemoteServer(
      reply[0]! as String,
      reply[1]! as SendPort,
      reply[2]! as int,
      reply[3]! as int,
    );
  }

  Future<void> stop() async {
    final done = ReceivePort();
    _control.send(done.sendPort);
    await done.first;
  }
}

Future<void> _serve(List<Object?> args) async {
  final reply = args[0]! as SendPort;
  final watch = Stopwatch()..start();
  final server = await MockServer.start(
    port: 0,
    scale: MockScale.large,
    mediaDir: args[1]! as String,
    liveDir: args[2]! as String,
    warmUp: false,
  );
  final startMs = watch.elapsedMilliseconds;
  // Encode the big lists once (what a real panel has ready).
  final client = HttpClient();
  for (final action in ['get_live_streams', 'get_vod_streams', 'get_series']) {
    final request = await client.getUrl(
      Uri.parse(
        '${server.baseUrl}/player_api.php?username=${MockFixtures.username}'
        '&password=${MockFixtures.password}&action=$action',
      ),
    );
    final response = await request.close();
    await response.drain<void>();
  }
  client.close();
  final warmUpMs = watch.elapsedMilliseconds - startMs;
  final control = ReceivePort();
  reply.send([server.baseUrl, control.sendPort, startMs, warmUpMs]);
  final done = await control.first as SendPort;
  await server.stop();
  done.send(true);
}
