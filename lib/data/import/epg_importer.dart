/// XMLTV guide import.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../db/database.dart';
import '../epg/epg_matcher.dart';
import '../net/dio_factory.dart';
import '../net/mask.dart';
import '../settings/settings_store.dart';
import '../sources/source_exception.dart';
import '../sources/xmltv/xmltv.dart';
import '../text/normalize.dart';
import 'import_job.dart';
import 'import_progress.dart';
import 'm3u_importer.dart' show localPathOf;

/// Playlist setting (internal): short hash of the EPG URL of the last
/// successful guide import, to notice a changed source. Never the URL itself
/// (it usually contains credentials).
const SettingKey<String?> epgSourceHashSetting = SettingKey<String?>(
  'importEpgSourceHash',
  null,
  SettingScope.playlist,
);

/// Result of a guide import.
typedef EpgCounts = ({
  int programmes,
  int epgChannels,
  int matchedChannels,
  int pruned,
});

/// Imports the playlist's XMLTV guide:
///
/// 1. **Cleaning programs** — deletes programmes outside the window
///    `now − max(maxArchiveDays, 1) days … now + 7 days`;
/// 2. **Downloading** — streams the XMLTV to `AppPaths.epgCache` (plain or
///    gzip; a local path or `file://` URL is read in place);
/// 3. **Parsing** — parses on a background isolate with the playlist EPG
///    shift and the window, upserts `epg_channels` and inserts programmes
///    5,000 per transaction; then replaces the previous programmes of every
///    channel the new guide covers (all of them when the source URL
///    changed), drops EPG channels that disappeared, re-matches every
///    playlist channel (`matchedEpgId`), rebuilds `programme_search` and
///    stores `programmeCount` / `lastEpgReloadAt`.
///
/// A failure or cancel before the old programmes are replaced removes the
/// programmes inserted by this run, so the previous guide stays intact;
/// after that commit point the run finishes without checking for
/// cancellation.
final class EpgImporter {
  EpgImporter(this.job, this.settings);

  final ImportJob job;
  final SettingsStore settings;

  ProgressReporter get _progress => job.progress;
  AppDatabase get _db => job.db;
  int get _pid => job.playlistId;

  /// Imports the guide at [url] (see `importEpgUrl`).
  Future<EpgCounts> run(String url) async {
    if (url.trim().isEmpty) {
      throw const SourceException(
        SourceErrorKind.notFound,
        message: 'The playlist has no EPG URL',
      );
    }
    final now = job.now().toUtc();

    // 1. Cleaning programs.
    _progress.enter(ImportStep.epgCleaning);
    final maxArchive = await _maxArchiveDays();
    final windowStart = now.subtract(Duration(days: math.max(maxArchive, 1)));
    final windowEnd = now.add(Duration(days: job.config.epgDaysAhead));
    job.throwIfCancelled();
    // Two statements so both use the (playlist_id, stop) index; a programme
    // that starts after the window also stops after it.
    final pruned = await _db.transaction(() async {
      final past = await _db.customUpdate(
        'DELETE FROM "programmes" WHERE "playlist_id" = ? AND "stop" <= ?',
        variables: [
          Variable.withInt(_pid),
          Variable.withInt(windowStart.millisecondsSinceEpoch),
        ],
      );
      final future = await _db.customUpdate(
        'DELETE FROM "programmes" WHERE "playlist_id" = ? AND "stop" > ? '
        'AND "start" >= ?',
        variables: [
          Variable.withInt(_pid),
          Variable.withInt(windowEnd.millisecondsSinceEpoch),
          Variable.withInt(windowEnd.millisecondsSinceEpoch),
        ],
      );
      return past + future;
    });
    _progress.count(ImportStep.epgCleaning, pruned, force: true);

    // 2. Downloading.
    _progress.enter(ImportStep.epgDownloading);
    final local = localPathOf(url);
    final String path;
    if (local != null) {
      path = local;
      if (!await File(path).exists()) {
        throw const SourceException(
          SourceErrorKind.notFound,
          message: 'The EPG file does not exist',
        );
      }
    } else {
      path = p.join(job.paths.epgCache, 'epg_$_pid.xml');
      job.log('downloading the guide from ${maskUrl(url)}');
      await downloadToFile(
        job.dio,
        url,
        path,
        onProgress: (received, total) => _progress.bytes(received, total),
        cancelToken: job.cancelToken,
      );
    }
    job.throwIfCancelled();

    // 3. Parsing.
    _progress.enter(ImportStep.epgParsing);
    final sourceHash = epgSourceHash(url);
    final previousHash = settings.get(epgSourceHashSetting, playlistId: _pid);
    final sourceChanged = previousHash != null && previousHash != sourceHash;
    final maxIdBefore = await _maxProgrammeId();
    final _Parsed parsed;
    try {
      parsed = await _parse(
        path,
        await File(path).length(),
        windowStart,
        windowEnd,
      );
      job.throwIfCancelled();
      if (parsed.programmes == 0) {
        throw SourceException(
          SourceErrorKind.emptyBody,
          message: 'The guide has no programmes between now and the next days',
          url: local == null ? maskUrl(url) : null,
        );
      }
      await _addOrphanChannels(parsed);
      job.throwIfCancelled();
    } catch (_) {
      // Before the commit point: drop what this run inserted.
      await _rollback(maxIdBefore);
      rethrow;
    } finally {
      if (local == null) await _deleteQuietly(path);
    }

    // Commit point: the new guide replaces the old one. From here on the
    // run is not cancellable (a rollback would leave no guide at all); the
    // remaining steps take a second or two even for a million programmes.
    await _replaceOldProgrammes(parsed, maxIdBefore, sourceChanged);
    final counts = await _finish(parsed, now);
    await settings.set(epgSourceHashSetting, sourceHash, playlistId: _pid);
    return (
      programmes: counts.programmes,
      epgChannels: parsed.refs.length,
      matchedChannels: counts.matched,
      pruned: pruned,
    );
  }

  Future<int> _maxArchiveDays() async {
    final row = await _db
        .customSelect(
          'SELECT MAX("archive_days") AS "d" FROM "channels" '
          'WHERE "playlist_id" = ?',
          variables: [Variable.withInt(_pid)],
        )
        .getSingle();
    return row.readNullable<int>('d') ?? 0;
  }

  Future<int> _maxProgrammeId() async {
    final row = await _db
        .customSelect('SELECT MAX("id") AS "m" FROM "programmes"')
        .getSingle();
    return row.readNullable<int>('m') ?? 0;
  }

  Future<void> _rollback(int maxIdBefore) async {
    try {
      await _db.customStatement(
        'DELETE FROM "programmes" WHERE "playlist_id" = ? AND "id" > ?',
        [_pid, maxIdBefore],
      );
    } on Object catch (e) {
      job.log('could not roll back the guide: ${e.runtimeType}');
    }
  }

  static const _programmeSql =
      'INSERT INTO "programmes" ("playlist_id", "epg_channel_id", "start", '
      '"stop", "title", "sub_title", "description", "category", "episode_num", '
      '"icon", "rating") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';

  static const _epgChannelSql =
      'INSERT INTO "epg_channels" ("playlist_id", "epg_id", "display_name", '
      '"normalized", "icon") VALUES (?, ?, ?, ?, ?) '
      'ON CONFLICT ("playlist_id", "epg_id") DO UPDATE SET '
      '"display_name" = excluded."display_name", '
      '"normalized" = excluded."normalized", "icon" = excluded."icon"';

  Future<_Parsed> _parse(
    String path,
    int fileSize,
    DateTime windowStart,
    DateTime windowEnd,
  ) async {
    final refs = <String, List<String>>{};
    final minStart = <String, int>{};
    final maxStop = <String, int>{};
    var programmes = 0;
    XmltvSummary? summary;
    final parseWatch = Stopwatch()..start();

    final stream = parseXmltvFileInIsolate(
      path,
      batchSize: job.config.batchSize,
      shift: Duration(hours: job.playlist.epgShiftHours),
      windowStart: windowStart,
      windowEnd: windowEnd,
      preferredLanguages: _preferredLanguages(),
    );
    final iterator = StreamIterator<XmltvBatch>(stream);
    try {
      while (true) {
        final hasNext = await Future.any<bool>([
          iterator.moveNext(),
          job.whenCancelled.then((_) => false),
        ]);
        job.throwIfCancelled();
        if (!hasNext) break;
        switch (iterator.current) {
          case XmltvChannelBatch(:final channels):
            final rows = <List<Object?>>[];
            for (final c in channels) {
              if (refs.containsKey(c.id)) continue;
              refs[c.id] = c.displayNames;
              rows.add([
                _pid,
                c.id,
                c.displayName,
                normalizeChannelName(c.displayName),
                c.icon,
              ]);
            }
            await _db.batch((b) {
              for (final row in rows) {
                b.customStatement(_epgChannelSql, row);
              }
            });
          case XmltvProgrammeBatch(programmes: final list, :final bytesRead):
            await _db.batch((b) {
              for (final prog in list) {
                final id = prog.channelId;
                final start = prog.start.millisecondsSinceEpoch;
                final stop = prog.stop.millisecondsSinceEpoch;
                final lo = minStart[id];
                if (lo == null || start < lo) minStart[id] = start;
                final hi = maxStop[id];
                if (hi == null || stop > hi) maxStop[id] = stop;
                b.customStatement(_programmeSql, [
                  _pid,
                  id,
                  start,
                  stop,
                  prog.title,
                  prog.subTitle,
                  prog.description,
                  prog.category,
                  prog.episodeNum,
                  prog.icon,
                  prog.rating,
                ]);
              }
            });
            programmes += list.length;
            _progress
              ..bytes(bytesRead, fileSize)
              ..count(ImportStep.epgParsing, programmes);
          case XmltvProgress(:final bytesRead):
            _progress.bytes(bytesRead, fileSize);
          case final XmltvSummary s:
            summary = s;
        }
      }
    } finally {
      await iterator.cancel();
    }
    _progress
      ..bytes(fileSize, fileSize)
      ..count(ImportStep.epgParsing, programmes, force: true);
    if (summary != null) {
      job.log(
        'parsed and stored the guide in ${parseWatch.elapsedMilliseconds} ms: $summary',
      );
    }
    return _Parsed(refs, minStart, maxStop, programmes);
  }

  /// Programmes of channels without a `<channel>` element still deserve an
  /// EPG channel row (Custom EPG picker, exact-id matching).
  Future<void> _addOrphanChannels(_Parsed parsed) async {
    final orphans = [
      for (final id in parsed.minStart.keys)
        if (!parsed.refs.containsKey(id)) id,
    ];
    if (orphans.isEmpty) return;
    await _db.batch((b) {
      for (final id in orphans) {
        b.customStatement(
          'INSERT INTO "epg_channels" ("playlist_id", "epg_id", '
          '"display_name", "normalized", "icon") VALUES (?, ?, ?, ?, NULL) '
          'ON CONFLICT ("playlist_id", "epg_id") DO NOTHING',
          [_pid, id, id, normalizeChannelName(id)],
        );
      }
    });
    for (final id in orphans) {
      parsed.refs[id] = const [];
    }
  }

  /// Deletes the previous programmes: all of them when the source changed,
  /// else those overlapping what the new guide covers, per channel (older
  /// archive days the new file no longer lists are kept).
  Future<void> _replaceOldProgrammes(
    _Parsed parsed,
    int maxIdBefore,
    bool sourceChanged,
  ) async {
    final watch = Stopwatch()..start();
    if (sourceChanged) {
      await _db.customStatement(
        'DELETE FROM "programmes" WHERE "playlist_id" = ? AND "id" <= ?',
        [_pid, maxIdBefore],
      );
    } else if (maxIdBefore > 0) {
      final ids = parsed.minStart.keys.toList();
      final batchSize = job.config.batchSize;
      for (var i = 0; i < ids.length; i += batchSize) {
        final end = math.min(i + batchSize, ids.length);
        await _db.batch((b) {
          for (var k = i; k < end; k++) {
            final id = ids[k];
            b.customStatement(
              'DELETE FROM "programmes" WHERE "playlist_id" = ? '
              'AND "epg_channel_id" = ? AND "id" <= ? '
              'AND "start" < ? AND "stop" > ?',
              [_pid, id, maxIdBefore, parsed.maxStop[id], parsed.minStart[id]],
            );
          }
        });
      }
    }
    job.log(
      'replaced the previous programmes in ${watch.elapsedMilliseconds} ms',
    );
  }

  /// After the commit point: stale EPG channels, matching,
  /// `programme_search`, counts. Never checks for cancellation.
  Future<({int programmes, int matched})> _finish(
    _Parsed parsed,
    DateTime now,
  ) async {
    final pid = Variable.withInt(_pid);
    final batchSize = job.config.batchSize;
    final watch = Stopwatch()..start();
    void lap(String what) {
      job.log('$what in ${watch.elapsedMilliseconds} ms');
      watch.reset();
    }

    // EPG channels that are gone.
    final existing = await _db
        .customSelect(
          'SELECT "id", "epg_id" FROM "epg_channels" WHERE "playlist_id" = ?',
          variables: [pid],
        )
        .get();
    final stale = [
      for (final row in existing)
        if (!parsed.refs.containsKey(row.read<String>('epg_id')))
          row.read<int>('id'),
    ];
    for (var i = 0; i < stale.length; i += batchSize) {
      final end = math.min(i + batchSize, stale.length);
      await _db.batch((b) {
        for (var k = i; k < end; k++) {
          b.customStatement('DELETE FROM "epg_channels" WHERE "id" = ?', [
            stale[k],
          ]);
        }
      });
    }

    lap('removed ${stale.length} stale EPG channels');
    final matched = await _matchChannels(parsed.refs);
    lap('matched channels');
    await _rebuildProgrammeSearch(now);
    lap('rebuilt programme_search');

    final count = await _db
        .customSelect(
          'SELECT COUNT(*) AS "n" FROM "programmes" WHERE "playlist_id" = ?',
          variables: [pid],
        )
        .getSingle();
    final programmes = count.read<int>('n');
    await (_db.update(_db.playlists)..where((t) => t.id.equals(_pid))).write(
      PlaylistsCompanion(
        programmeCount: Value(programmes),
        lastEpgReloadAt: Value(job.now()),
      ),
    );
    return (programmes: programmes, matched: matched);
  }

  /// Re-matches every playlist channel; returns how many have a match.
  Future<int> _matchChannels(Map<String, List<String>> refs) async {
    final matcher = EpgMatcher([
      for (final e in refs.entries) EpgChannelRef(e.key, e.value),
    ]);
    final rows = await _db
        .customSelect(
          'SELECT "id", "name", "epg_id", "matched_epg_id" FROM "channels" '
          'WHERE "playlist_id" = ?',
          variables: [Variable.withInt(_pid)],
        )
        .get();
    var matched = 0;
    final updates = <List<Object?>>[];
    for (var i = 0; i < rows.length; i++) {
      if (i > 0 && i % 2000 == 0) await Future<void>.delayed(Duration.zero);
      final row = rows[i];
      final id = matcher.match(
        tvgId: row.readNullable<String>('epg_id'),
        name: row.read<String>('name'),
      );
      if (id != null) matched++;
      if (id != row.readNullable<String>('matched_epg_id')) {
        updates.add([id, row.read<int>('id')]);
      }
    }
    final batchSize = job.config.batchSize;
    for (var i = 0; i < updates.length; i += batchSize) {
      final end = math.min(i + batchSize, updates.length);
      await _db.batch((b) {
        for (var k = i; k < end; k++) {
          b.customStatement(
            'UPDATE "channels" SET "matched_epg_id" = ? WHERE "id" = ?',
            updates[k],
          );
        }
      });
    }
    job.log('matched $matched of ${rows.length} channels');
    return matched;
  }

  /// `programme_search` rows for programmes with `stop > now` and
  /// `start < now + 48 h`; `programme_id` and `playlist_id` are INTEGERs.
  Future<void> _rebuildProgrammeSearch(DateTime now) async {
    final from = now.millisecondsSinceEpoch;
    final to = now
        .add(Duration(hours: job.config.programmeSearchHours))
        .millisecondsSinceEpoch;
    final rows = await _db
        .customSelect(
          'SELECT "id", "title" FROM "programmes" WHERE "playlist_id" = ? '
          'AND "stop" > ? AND "start" < ?',
          variables: [
            Variable.withInt(_pid),
            Variable.withInt(from),
            Variable.withInt(to),
          ],
        )
        .get();
    final ids = [for (final row in rows) row.read<int>('id')];
    final titles = [for (final row in rows) row.read<String>('title')];
    final normalized = await _normalizeTitles(titles);

    const insert =
        'INSERT INTO "programme_search" '
        '("normalized", "programme_id", "playlist_id") VALUES (?, ?, ?)';
    final batchSize = job.config.batchSize;
    var start = 0;
    var first = true;
    while (first || start < ids.length) {
      final end = math.min(start + batchSize, ids.length);
      final deleteFirst = first;
      first = false;
      await _db.batch((b) {
        if (deleteFirst) {
          b.customStatement(
            'DELETE FROM "programme_search" WHERE "playlist_id" = ?',
            [_pid],
          );
        }
        for (var i = start; i < end; i++) {
          final n = normalized[i];
          if (n.isEmpty) continue;
          b.customStatement(insert, [n, ids[i], _pid]);
        }
      });
      start = end;
    }
  }

  List<String> _preferredLanguages() {
    final setting = settings.get(AppSettings.language);
    final code = setting == 'system'
        ? Platform.localeName.split(RegExp('[_-]')).first.toLowerCase()
        : setting;
    return [if (code.isNotEmpty) code, if (code != 'en') 'en'];
  }
}

/// Normalizes programme titles (each distinct title once), off the calling
/// isolate for big guides.
Future<List<String>> _normalizeTitles(List<String> titles) {
  List<String> work() {
    final cache = <String, String>{};
    return [for (final t in titles) cache[t] ??= normalizeForSearch(t)];
  }

  if (titles.length < 4000) return Future.value(work());
  return Isolate.run(work, debugName: 'carina-programme-search');
}

/// First 16 hex characters of `sha1(url)`.
String epgSourceHash(String url) =>
    sha1.convert(utf8.encode(url.trim())).toString().substring(0, 16);

final class _Parsed {
  _Parsed(this.refs, this.minStart, this.maxStop, this.programmes);

  /// EPG channel id → display names (declared channels, then orphans).
  final Map<String, List<String>> refs;
  final Map<String, int> minStart;
  final Map<String, int> maxStop;
  final int programmes;
}

Future<void> _deleteQuietly(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) await file.delete();
  } on FileSystemException {
    // Best effort.
  }
}
