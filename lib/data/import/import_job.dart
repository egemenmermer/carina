/// Internal plumbing shared by the importers: configuration, the per-run
/// context (cancellation, HTTP client, playlist row) and the progress
/// reporter. Not exported by `import.dart` except [ImportConfig].
library;

import 'dart:async';
import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../app_paths.dart';
import '../db/database.dart';
import '../net/dio_factory.dart';
import '../sources/source_exception.dart';
import 'import_progress.dart';

/// Tunables of the import pipeline. Tests shorten the timeouts.
@immutable
class ImportConfig {
  const ImportConfig({
    this.connectTimeout = const Duration(seconds: 15),
    this.receiveTimeout = const Duration(seconds: 60),
    this.bulkReceiveTimeout = const Duration(seconds: 120),
    this.retries = 2,
    this.retryDelay = const Duration(milliseconds: 500),
    this.batchSize = 5000,
    this.categoryConcurrency = 4,
    this.epgDaysAhead = 7,
    this.programmeSearchHours = 48,
    this.clock,
    this.log,
  }) : assert(batchSize > 0 && batchSize <= 5000);

  /// TCP connect timeout of every request.
  final Duration connectTimeout;

  /// Maximum silence between two chunks of a response.
  final Duration receiveTimeout;

  /// Receive timeout of the Xtream "everything at once" list calls.
  final Duration bulkReceiveTimeout;

  /// Retries of idempotent requests on transient failures (the bulk live
  /// call never retries: it has the per-category fallback).
  final int retries;
  final Duration retryDelay;

  /// Rows per write transaction (ARCHITECTURE: at most 5,000).
  final int batchSize;

  /// Parallel requests of the per-category fallback.
  final int categoryConcurrency;

  /// Guide window end: now + this many days.
  final int epgDaysAhead;

  /// `programme_search` covers programmes overlapping now … now + this.
  final int programmeSearchHours;

  /// "Now" (tests); defaults to [DateTime.now].
  final DateTime Function()? clock;

  /// Log sink. Lines never contain credentials or unmasked URLs.
  final void Function(String message)? log;

  DateTime now() => (clock ?? DateTime.now)();
}

/// The cancellation error used throughout the pipeline.
const SourceException importCancelledError = SourceException(
  SourceErrorKind.cancelled,
  message: 'Import cancelled',
);

/// Accumulates the state of one run and emits [ImportProgress] snapshots.
final class ProgressReporter {
  ProgressReporter({
    required this.playlistId,
    required this.scope,
    required this.onEmit,
    required this.startedAt,
  });

  final int playlistId;
  final ImportScope scope;
  final void Function(ImportProgress progress) onEmit;
  final DateTime startedAt;

  ImportStep _step = ImportStep.connecting;
  final Map<ImportStep, int> _counts = {};
  final List<ImportWarning> _warnings = [];
  List<ImportStep> _planned = const [];
  Set<ImportStep> _skipped = const {};
  int? _received;
  int? _total;
  ImportStep? _failedStep;
  SourceException? _epgError;
  final Map<ImportStep, Duration> _durations = {};
  final Stopwatch _watch = Stopwatch();
  final Stopwatch _sinceEmit = Stopwatch()..start();

  ImportStep get step => _step;
  Map<ImportStep, int> get counts => Map.unmodifiable(_counts);
  Map<ImportStep, Duration> get durations => Map.unmodifiable(_durations);
  List<ImportWarning> get warnings => List.unmodifiable(_warnings);
  SourceException? get epgError => _epgError;

  /// Sets the steps of this run ([ImportStep.completed] is appended).
  void plan(List<ImportStep> planned, Set<ImportStep> skipped) {
    _planned = List.unmodifiable([...planned, ImportStep.completed]);
    _skipped = Set.unmodifiable(skipped);
  }

  /// Starts [step] and emits.
  void enter(ImportStep step) {
    _closeStep();
    _step = step;
    _received = null;
    _total = null;
    _watch
      ..reset()
      ..start();
    emit();
  }

  /// Sets the count of [step]; emits at most every 50 ms unless [force].
  void count(ImportStep step, int value, {bool force = false}) {
    _counts[step] = value;
    _throttledEmit(force);
  }

  /// Byte progress of the current step (throttled like [count]).
  void bytes(int received, int? total, {bool force = false}) {
    _received = received;
    _total = total;
    _throttledEmit(force);
  }

  void clearBytes() {
    _received = null;
    _total = null;
  }

  void warn(ImportWarning warning) {
    if (!_warnings.contains(warning)) _warnings.add(warning);
  }

  /// Records a non-fatal EPG failure at the current step.
  void epgFailed(SourceException error) {
    _epgError = error;
    _failedStep = _step;
  }

  /// Emits the terminal snapshot.
  ImportProgress finish(ImportStep terminal, {SourceException? error}) {
    assert(terminal.isTerminal);
    if (terminal != ImportStep.completed) _failedStep = _step;
    if (error != null && error.kind != SourceErrorKind.cancelled) {
      if (_step.isEpg) _epgError = error;
    }
    _closeStep();
    _step = terminal;
    _received = null;
    _total = null;
    final progress = snapshot(
      done: true,
      error: terminal == ImportStep.failed ? error : null,
    );
    onEmit(progress);
    return progress;
  }

  void emit() {
    _sinceEmit
      ..reset()
      ..start();
    onEmit(snapshot());
  }

  void _throttledEmit(bool force) {
    if (force || _sinceEmit.elapsedMilliseconds >= 50) emit();
  }

  void _closeStep() {
    if (_watch.isRunning && !_step.isTerminal) {
      _durations[_step] = (_durations[_step] ?? Duration.zero) + _watch.elapsed;
    }
    _watch.stop();
  }

  ImportProgress snapshot({bool done = false, SourceException? error}) =>
      ImportProgress(
        playlistId: playlistId,
        scope: scope,
        step: _step,
        counts: Map.unmodifiable(_counts),
        receivedBytes: _received,
        totalBytes: _total,
        error: error,
        warnings: List.unmodifiable(_warnings),
        done: done,
        plannedSteps: _planned,
        skippedSteps: _skipped,
        failedStep: _failedStep,
        epgError: _epgError,
        stepDurations: Map.unmodifiable(_durations),
        startedAt: startedAt,
      );
}

/// Context of one import run.
final class ImportJob {
  ImportJob({
    required this.db,
    required this.paths,
    required this.playlist,
    required this.scope,
    required this.config,
    required this.progress,
    this.password,
    this.userAgent,
    this.headers = const {},
  });

  final AppDatabase db;
  final AppPaths paths;

  /// The playlist row; refreshed when the run changes it (M3U `url-tvg`).
  PlaylistRow playlist;
  final ImportScope scope;
  final ImportConfig config;
  final ProgressReporter progress;

  /// Xtream password (never logged).
  final String? password;

  /// Effective User-Agent for every request (null = Carina default).
  final String? userAgent;

  /// Extra request headers (e.g. a Referer from the playlist settings).
  final Map<String, String> headers;

  final CancelToken cancelToken = CancelToken();
  final Completer<void> _cancelled = Completer<void>();
  Dio? _dio;

  int get playlistId => playlist.id;
  bool get isCancelled => _cancelled.isCompleted;

  /// Completes when the run is cancelled.
  Future<void> get whenCancelled => _cancelled.future;

  /// Stops HTTP requests, isolates and writes as soon as possible.
  void cancel() {
    if (_cancelled.isCompleted) return;
    _cancelled.complete();
    if (!cancelToken.isCancelled) cancelToken.cancel('import cancelled');
  }

  void throwIfCancelled() {
    if (isCancelled) throw importCancelledError;
  }

  /// The run's HTTP client (created on first use, closed by [close]).
  Dio get dio => _dio ??= createDio(
    userAgent: userAgent,
    headers: headers.isEmpty ? null : headers,
    connectTimeout: config.connectTimeout,
    receiveTimeout: config.receiveTimeout,
    retries: config.retries,
    retryDelay: config.retryDelay,
  );

  DateTime now() => config.now();

  void log(String message) => config.log?.call('import #$playlistId: $message');

  void close() {
    _dio?.close(force: true);
    _dio = null;
  }
}

/// Runs [computation] on a new isolate like [Isolate.run], but kills the
/// isolate as soon as [job] is cancelled and then throws
/// [importCancelledError]. [computation] must only capture sendable values.
Future<R> runCancellableIsolate<R>(
  ImportJob job,
  FutureOr<R> Function() computation, {
  String? debugName,
}) async {
  job.throwIfCancelled();
  final result = Completer<R>();
  final port = RawReceivePort();
  Isolate? isolate;
  var settled = false;

  void settle() {
    settled = true;
    port.close();
  }

  port.handler = (Object? message) {
    if (settled) return;
    settle();
    if (message == null) {
      result.completeError(
        RemoteError('Computation ended without result', ''),
        StackTrace.empty,
      );
      return;
    }
    final list = message as List<Object?>;
    if (list.length == 2) {
      final error = list[0];
      final stack = list[1];
      if (stack is StackTrace) {
        result.completeError(error!, stack);
      } else {
        final remote = RemoteError('$error', '$stack');
        result.completeError(remote, remote.stackTrace);
      }
    } else {
      result.complete(list[0] as R);
    }
  };

  unawaited(
    job.whenCancelled.then((_) {
      if (settled) return;
      settle();
      isolate?.kill(priority: Isolate.immediate);
      result.completeError(importCancelledError);
    }),
  );

  try {
    isolate = await Isolate.spawn<_IsolateTask<R>>(
      _runIsolateTask,
      _IsolateTask<R>(computation, port.sendPort),
      onError: port.sendPort,
      onExit: port.sendPort,
      errorsAreFatal: true,
      debugName: debugName,
    );
    if (settled) isolate.kill(priority: Isolate.immediate);
  } on Object {
    if (!settled) settle();
    rethrow;
  }
  return result.future;
}

final class _IsolateTask<R> {
  const _IsolateTask(this.computation, this.port);

  final FutureOr<R> Function() computation;
  final SendPort port;

  Future<void> run() async {
    R value;
    try {
      value = await computation();
    } catch (e, s) {
      Isolate.exit(port, [e, s]);
    }
    Isolate.exit(port, [value]);
  }
}

void _runIsolateTask(_IsolateTask<Object?> task) => task.run();
