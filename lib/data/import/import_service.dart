/// The import pipeline entry point (ARCHITECTURE 2.12).
library;

import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_paths.dart';
import '../db/database.dart';
import '../net/mask.dart';
import '../repositories/playlist_repository.dart' show effectiveEpgUrl;
import '../secrets/secret_store.dart';
import '../settings/settings_store.dart';
import '../sources/m3u/m3u_models.dart' show M3uHeader;
import '../sources/source_exception.dart';
import 'content_writer.dart';
import 'epg_importer.dart';
import 'import_job.dart';
import 'import_progress.dart';
import 'm3u_importer.dart';
import 'xtream_importer.dart';

/// The XMLTV URL an import downloads for [playlist]: `effectiveEpgUrl` of
/// the playlist repository (custom URL; `''` = switched off; null = the
/// default — Xtream `{server}/xmltv.php` with [password], M3U the stored
/// header's `url-tvg`). Never written back for Xtream (it holds the
/// password).
String? importEpgUrl(PlaylistRow playlist, {String? password}) {
  M3uHeader? header;
  final json = playlist.m3uHeaderJson;
  if (json != null && json.isNotEmpty) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map<String, Object?>) header = M3uHeader.fromJson(decoded);
    } on Object {
      header = null;
    }
  }
  final url = effectiveEpgUrl(playlist, password: password, header: header);
  return url == null || url.trim().isEmpty ? null : url.trim();
}

/// User-Agent sent when the playlist settings choose "VLC".
const String vlcUserAgent = 'VLC/3.0.20 LibVLC/3.0.20';

/// Imports playlists: content (Xtream or M3U) and the XMLTV guide.
///
/// - [start] runs an import in the background and returns its progress
///   stream. Only one import per playlist runs at a time: a second [start]
///   returns the running import's stream (whatever its scope). The stream
///   replays the latest snapshot to new listeners, never errors, and closes
///   after the terminal snapshot. Not listening does not stop the import.
/// - [cancel] stops HTTP requests, parsing isolates and writes; the
///   previous data stays intact and the run ends with
///   [ImportStep.cancelled].
/// - [watch] follows a playlist across runs (the top-bar reload chip): the
///   current snapshot first (null when idle), every snapshot of a run, then
///   null once it is over.
///
/// Content imports are incremental (ARCHITECTURE 2.11): favorites, watch
/// state, last-watched, reminders, local renames, hidden / locked flags,
/// custom order and Custom EPG assignments survive a reload. Nothing is
/// logged with credentials or unmasked URLs.
class ImportService {
  ImportService({
    required this.db,
    required this.paths,
    required this.secrets,
    required this.settings,
    this.config = const ImportConfig(),
  });

  final AppDatabase db;
  final AppPaths paths;
  final SecretStore secrets;
  final SettingsStore settings;
  final ImportConfig config;

  final Map<int, _Run> _runs = {};
  final Map<int, StreamController<ImportProgress?>> _watchers = {};
  final Map<int, ImportProgress> _lastResults = {};
  bool _disposed = false;

  /// Starts an import of [playlistId] (or joins the running one).
  Stream<ImportProgress> start(
    int playlistId, {
    ImportScope scope = ImportScope.all,
  }) {
    final running = _runs[playlistId];
    if (running != null) return running.stream;
    if (_disposed) throw StateError('ImportService was disposed');
    final run = _Run(playlistId, scope);
    _runs[playlistId] = run;
    unawaited(_execute(run));
    return run.stream;
  }

  /// [start] and wait for the terminal snapshot.
  Future<ImportProgress> run(
    int playlistId, {
    ImportScope scope = ImportScope.all,
  }) => start(playlistId, scope: scope).last;

  /// Cancels the running import of [playlistId], if any.
  void cancel(int playlistId) => _runs[playlistId]?.cancel();

  bool isRunning(int playlistId) => _runs.containsKey(playlistId);

  /// The latest snapshot of the running import, or null when idle.
  ImportProgress? current(int playlistId) => _runs[playlistId]?.latest;

  /// The terminal snapshot of the last finished import (this session).
  ImportProgress? lastResult(int playlistId) => _lastResults[playlistId];

  /// Current snapshot (null when idle), then every change; never closes
  /// (until [dispose]).
  Stream<ImportProgress?> watch(int playlistId) =>
      Stream<ImportProgress?>.multi((controller) {
        controller.add(_runs[playlistId]?.latest);
        final sub = _watcher(playlistId).stream
            .listen(controller.add, onDone: controller.close);
        controller.onCancel = sub.cancel;
      });

  /// Cancels every import and closes the watch streams.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final runs = _runs.values.toList();
    for (final run in runs) {
      run.cancel();
    }
    await Future.wait([for (final run in runs) run.finished])
        .timeout(const Duration(seconds: 10), onTimeout: () => const []);
    for (final controller in _watchers.values) {
      await controller.close();
    }
    _watchers.clear();
  }

  StreamController<ImportProgress?> _watcher(int playlistId) =>
      _watchers.putIfAbsent(
        playlistId,
        () => StreamController<ImportProgress?>.broadcast(sync: true),
      );

  void _publish(_Run run, ImportProgress progress) {
    run.add(progress);
    final watcher = _watchers[run.playlistId];
    if (watcher != null && !watcher.isClosed) watcher.add(progress);
  }

  void _log(String message) => config.log?.call(message);

  // ---------------------------------------------------------------------

  Future<void> _execute(_Run run) async {
    final pid = run.playlistId;
    final reporter = ProgressReporter(
      playlistId: pid,
      scope: run.scope,
      startedAt: config.now(),
      onEmit: (progress) => _publish(run, progress),
    );
    ImportJob? job;
    ContentWriter? writer;
    var contentStarted = false;
    var contentFinished = false;
    ImportProgress result;
    try {
      // Let the caller subscribe before the first snapshot.
      await Future<void>.delayed(Duration.zero);
      final playlist = await (db.select(
        db.playlists,
      )..where((p) => p.id.equals(pid))).getSingleOrNull();
      if (playlist == null) {
        throw const SourceException(
          SourceErrorKind.notFound,
          message: 'Playlist not found',
        );
      }
      final password = playlist.type == PlaylistType.xtream
          ? await secrets.read(SecretStore.playlistPassword(pid))
          : null;
      final hasEpg = importEpgUrl(playlist, password: password) != null;
      final planned = [
        if (run.scope.includesContent) ...ImportStep.contentSteps,
        if (run.scope.includesEpg && hasEpg) ...ImportStep.epgSteps,
      ];
      reporter.plan(planned, {
        for (final s in [...ImportStep.contentSteps, ...ImportStep.epgSteps])
          if (!planned.contains(s)) s,
      });

      final userAgent = _userAgentFor(playlist);
      final referer = settings.get(PlaylistSettings.referer, playlistId: pid);
      job = run.job = ImportJob(
        db: db,
        paths: paths,
        playlist: playlist,
        scope: run.scope,
        config: config,
        progress: reporter,
        password: password,
        userAgent: userAgent,
        headers: referer.trim().isEmpty ? const {} : {'Referer': referer},
      );
      if (run.cancelRequested) job.cancel();
      job.throwIfCancelled();
      _log(
        'import #$pid (${playlist.type.name}, ${run.scope.name}) '
        'started: ${_describeSource(playlist)}',
      );

      // Content.
      if (run.scope.includesContent) {
        writer = ContentWriter(
          db,
          pid,
          source: playlist.type == PlaylistType.xtream
              ? ContentSource.xtream
              : ContentSource.m3u,
          batchSize: config.batchSize,
          throwIfCancelled: job.throwIfCancelled,
        );
        contentStarted = true;
        final ContentCounts counts;
        M3uImporter? m3u;
        if (playlist.type == PlaylistType.xtream) {
          counts = await XtreamImporter(job, writer).run();
        } else {
          m3u = M3uImporter(job, writer);
          counts = await m3u.run();
        }
        job.throwIfCancelled();
        await _finishContent(job, writer, counts, m3u);
        contentFinished = true;
      }

      // Guide (the M3U header may just have provided the URL).
      final epgUrl = importEpgUrl(job.playlist, password: password);
      if (run.scope.includesEpg && epgUrl != null) {
        if (!hasEpg) {
          // Planned without EPG; the M3U header filled in the URL.
          reporter.plan(planned + ImportStep.epgSteps, const {});
        }
        try {
          final epg = await EpgImporter(job, settings).run(epgUrl);
          _log(
            'import #$pid: guide stored (${epg.programmes} programmes, '
            '${epg.epgChannels} EPG channels, ${epg.matchedChannels} '
            'channels matched, ${epg.pruned} pruned)',
          );
          db.notifyUpdates({
            TableUpdate.onTable(db.epgChannels),
            TableUpdate.onTable(db.programmes),
            TableUpdate.onTable(db.channels),
            TableUpdate.onTable(db.programmeSearch),
          });
        } on Object catch (e) {
          final error = _asSourceException(e, job);
          if (error.kind == SourceErrorKind.cancelled ||
              !run.scope.includesContent) {
            rethrow;
          }
          // The content is safe: report the guide failure and complete.
          reporter.epgFailed(error);
          _log('import #$pid: guide failed: $error');
        }
      }
      result = reporter.finish(ImportStep.completed);
    } on Object catch (e, stack) {
      final error = _asSourceException(e, job);
      final cancelled =
          error.kind == SourceErrorKind.cancelled ||
          (job?.isCancelled ?? run.cancelRequested);
      if (contentStarted && !contentFinished && writer != null) {
        try {
          await writer.revertRemoved();
        } on Object catch (revertError) {
          _log('import #$pid: revert failed: ${revertError.runtimeType}');
        }
      }
      if (cancelled) {
        result = reporter.finish(ImportStep.cancelled);
      } else {
        if (e is! SourceException) {
          _log('import #$pid: unexpected ${e.runtimeType}\n$stack');
        }
        result = reporter.finish(ImportStep.failed, error: error);
      }
    } finally {
      job?.close();
    }
    _log(
      'import #$pid finished: ${result.step.name} in '
      '${config.now().difference(result.startedAt ?? config.now()).inMilliseconds} ms '
      '${_timings(result)}${result.error != null ? ' — ${result.error}' : ''}',
    );
    _lastResults[pid] = result;
    _runs.remove(pid);
    run.close();
    final watcher = _watchers[pid];
    if (watcher != null && !watcher.isClosed) watcher.add(null);
  }

  Future<void> _finishContent(
    ImportJob job,
    ContentWriter writer,
    ContentCounts counts,
    M3uImporter? m3u,
  ) async {
    final removed = await writer.deleteRemoved();
    await m3u?.finish();
    final searchRows = await writer.rebuildSearchIndex();
    final stored = await writer.updateCounts(job.now());
    final matched = await writer.matchUnmatchedChannels();
    for (final (kind, n) in [
      (SectionKind.live, counts.live),
      (SectionKind.movie, counts.movies),
      (SectionKind.series, counts.series),
    ]) {
      if (n == 0) {
        job.progress.warn(ImportWarning(SourceErrorKind.sectionEmpty, kind));
      }
    }
    db.notifyUpdates({
      TableUpdate.onTable(db.categories),
      TableUpdate.onTable(db.channels),
      TableUpdate.onTable(db.movies),
      TableUpdate.onTable(db.series),
      TableUpdate.onTable(db.seasons),
      TableUpdate.onTable(db.episodes),
      TableUpdate.onTable(db.searchIndex),
    });
    job.log(
      'content stored: ${stored.live} live, ${stored.movies} movies, '
      '${stored.series} series; removed ${removed.channels} channels, '
      '${removed.movies} movies, ${removed.series} series, '
      '${removed.categories} categories; $searchRows search rows; '
      '$matched channels matched from the stored guide',
    );
  }

  /// The playlist's own User-Agent, else the playlist setting (custom /
  /// VLC), else null (Carina default).
  String? _userAgentFor(PlaylistRow playlist) {
    final own = playlist.userAgent?.trim() ?? '';
    if (own.isNotEmpty) return own;
    final mode = settings.get(
      PlaylistSettings.userAgentMode,
      playlistId: playlist.id,
    );
    if (mode == 'custom') {
      final custom = settings
          .get(PlaylistSettings.userAgentCustom, playlistId: playlist.id)
          .trim();
      if (custom.isNotEmpty) return custom;
    }
    if (mode == 'vlc') return vlcUserAgent;
    return null;
  }

  static String _describeSource(PlaylistRow playlist) =>
      switch (playlist.type) {
        PlaylistType.xtream => maskServer(playlist.server ?? ''),
        PlaylistType.m3u => maskUrl(playlist.m3uUrl ?? ''),
        PlaylistType.m3uFile => 'local file',
      };

  static String _timings(ImportProgress p) => p.stepDurations.isEmpty
      ? ''
      : '(${p.stepDurations.entries.map((e) => '${e.key.name} ${e.value.inMilliseconds} ms').join(', ')})';

  static SourceException _asSourceException(Object e, ImportJob? job) {
    if (job != null && job.isCancelled) return importCancelledError;
    if (e is SourceException) return e;
    return SourceException(
      SourceErrorKind.unparseable,
      message: 'Import failed (${e.runtimeType})',
    );
  }
}

/// One running import.
final class _Run {
  _Run(this.playlistId, this.scope);

  final int playlistId;
  final ImportScope scope;
  final StreamController<ImportProgress> _controller =
      StreamController<ImportProgress>.broadcast(sync: true);
  final Completer<void> _finished = Completer<void>();
  ImportJob? job;
  ImportProgress? latest;
  bool cancelRequested = false;

  Future<void> get finished => _finished.future;

  /// Replays [latest] to each new listener, then forwards.
  Stream<ImportProgress> get stream =>
      Stream<ImportProgress>.multi((controller) {
        final last = latest;
        if (last != null) controller.add(last);
        if (_finished.isCompleted) {
          controller.close();
          return;
        }
        final sub = _controller.stream.listen(
          controller.add,
          onDone: controller.close,
        );
        controller.onCancel = sub.cancel;
      });

  void add(ImportProgress progress) {
    latest = progress;
    if (!_controller.isClosed) _controller.add(progress);
  }

  void cancel() {
    cancelRequested = true;
    job?.cancel();
  }

  void close() {
    if (!_finished.isCompleted) _finished.complete();
    unawaited(_controller.close());
  }
}

/// Reloads a playlist in the background when it is opened and its reload
/// frequency has elapsed.
class ReloadScheduler {
  ReloadScheduler(this.service, {DateTime Function()? clock})
    : _clock = clock ?? service.config.now;

  final ImportService service;
  final DateTime Function() _clock;

  /// Starts a background [ImportScope.all] import and returns true when
  /// `reloadFrequencyHours > 0` and the last reload is older than that (or
  /// there was none). Returns false otherwise, or when an import of the
  /// playlist is already running.
  Future<bool> checkOnOpen(int playlistId) async {
    if (service.isRunning(playlistId)) return false;
    final playlist = await (service.db.select(
      service.db.playlists,
    )..where((p) => p.id.equals(playlistId))).getSingleOrNull();
    if (playlist == null || playlist.reloadFrequencyHours <= 0) return false;
    final last = playlist.lastReloadAt;
    if (last != null &&
        _clock().difference(last) <=
            Duration(hours: playlist.reloadFrequencyHours)) {
      return false;
    }
    if (service.isRunning(playlistId)) return false;
    service.start(playlistId);
    return true;
  }
}

/// The app's [ImportService] (dependencies come from the bootstrap
/// overrides).
final importServiceProvider = Provider<ImportService>((ref) {
  final service = ImportService(
    db: ref.watch(appDatabaseProvider),
    paths: ref.watch(appPathsProvider),
    secrets: ref.watch(secretStoreProvider),
    settings: ref.watch(settingsStoreProvider),
    config: ImportConfig(
      log: kDebugMode ? (message) => debugPrint('[import] $message') : null,
    ),
  );
  ref.onDispose(service.dispose);
  return service;
});

final reloadSchedulerProvider = Provider<ReloadScheduler>(
  (ref) => ReloadScheduler(ref.watch(importServiceProvider)),
);

/// [ImportService.watch] as a provider (top-bar reload chip): null when
/// idle.
final importProgressProvider = StreamProvider.family<ImportProgress?, int>(
  (ref, playlistId) => ref.watch(importServiceProvider).watch(playlistId),
);
