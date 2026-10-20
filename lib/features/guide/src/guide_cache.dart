/// Programme cache of the TV Guide grid: programmes are loaded per EPG key
/// in fixed time chunks for the visible window (plus a margin) and kept in
/// sorted lists the painter can binary-search.
library;

import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/repository_models.dart';

/// Loads the programmes of [keys] overlapping `[from, to)` (UTC), keyed by
/// EPG key — `EpgRepository.guide` in the app.
typedef GuideLoader = Future<Map<String, List<ProgrammeView>>> Function(
  List<String> keys,
  DateTime from,
  DateTime to,
);

/// Programmes by EPG key, loaded in [chunk]-sized windows aligned to the
/// epoch. Listeners are notified (at most once per microtask) when a load
/// completes; failed loads are retried on the next [ensure] after
/// [retryAfter].
class GuideProgrammeCache extends ChangeNotifier {
  GuideProgrammeCache(
    this._loader, {
    this.chunk = const Duration(hours: 6),
    this.maxKeysPerLoad = 120,
    this.maxProgrammes = 80000,
    this.retryAfter = const Duration(seconds: 10),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final GuideLoader _loader;

  /// Size of one load window.
  final Duration chunk;

  /// Keys per [GuideLoader] call.
  final int maxKeysPerLoad;

  /// Soft cap of cached programmes; keys not asked for the longest are
  /// dropped above it.
  final int maxProgrammes;
  final Duration retryAfter;
  final DateTime Function() _clock;

  final LinkedHashMap<String, _KeyData> _data = LinkedHashMap();
  final Set<String> _inFlight = {};
  final Map<String, DateTime> _failedAt = {};
  int _generation = 0;
  int _programmeCount = 0;
  bool _notifyScheduled = false;
  bool _disposed = false;

  /// Bumped by [clear]; lets callers notice that everything was dropped.
  int get generation => _generation;

  /// Number of loads started (tests, diagnostics).
  int loadCount = 0;

  /// Total time spent in the loader (diagnostics).
  Duration loadTime = Duration.zero;

  int get _chunkMs => chunk.inMilliseconds;

  /// Start of the chunk containing [ms].
  int chunkStartMs(int ms) => ms - ms % _chunkMs;

  /// End of the chunk containing [ms].
  int chunkEndMs(int ms) => chunkStartMs(ms) + _chunkMs;

  /// Programmes of [key] loaded so far, sorted by start.
  List<ProgrammeView> programmes(String key) =>
      _data[key]?.list ?? const <ProgrammeView>[];

  /// Whether the chunk of [key] that contains [ms] has been loaded.
  bool isLoadedAt(String key, int ms) =>
      _data[key]?.chunks.contains(ms ~/ _chunkMs) ?? false;

  /// Whether any programme is cached.
  bool get isEmpty => _programmeCount == 0;

  /// Loads every chunk of [keys] × `[from, to)` that is neither loaded nor
  /// loading. Keys are batched per chunk.
  void ensure(Iterable<String> keys, DateTime from, DateTime to) {
    if (_disposed) return;
    final first = from.millisecondsSinceEpoch ~/ _chunkMs;
    final last = (to.millisecondsSinceEpoch - 1) ~/ _chunkMs;
    final now = _clock();
    final unique = <String>{
      for (final k in keys)
        if (k.isNotEmpty) k,
    };
    for (final k in unique) {
      // Recently used keys move to the end (eviction order).
      final d = _data.remove(k);
      if (d != null) _data[k] = d;
    }
    for (var c = first; c <= last; c++) {
      final missing = <String>[];
      for (final k in unique) {
        final id = '$k#$c';
        if (_inFlight.contains(id)) continue;
        if (_data[k]?.chunks.contains(c) ?? false) continue;
        final failed = _failedAt[id];
        if (failed != null && now.difference(failed) < retryAfter) continue;
        missing.add(k);
      }
      for (var i = 0; i < missing.length; i += maxKeysPerLoad) {
        final batch = missing.sublist(
          i,
          i + maxKeysPerLoad > missing.length
              ? missing.length
              : i + maxKeysPerLoad,
        );
        _load(batch, c);
      }
    }
  }

  void _load(List<String> keys, int c) {
    final generation = _generation;
    for (final k in keys) {
      _inFlight.add('$k#$c');
    }
    final from = DateTime.fromMillisecondsSinceEpoch(c * _chunkMs, isUtc: true);
    final to = DateTime.fromMillisecondsSinceEpoch(
      (c + 1) * _chunkMs,
      isUtc: true,
    );
    loadCount++;
    final watch = Stopwatch()..start();
    unawaited(
      _loader(keys, from, to).then(
        (result) {
          loadTime += watch.elapsed;
          if (_disposed || generation != _generation) return;
          for (final k in keys) {
            _inFlight.remove('$k#$c');
            _failedAt.remove('$k#$c');
            final data = _data.putIfAbsent(k, _KeyData.new);
            data.chunks.add(c);
            final added = result[k];
            if (added != null && added.isNotEmpty) {
              _programmeCount += data.merge(added);
            }
          }
          _evict(keys.toSet());
          _scheduleNotify();
        },
        onError: (Object e, StackTrace st) {
          if (_disposed || generation != _generation) return;
          final at = _clock();
          for (final k in keys) {
            _inFlight.remove('$k#$c');
            _failedAt['$k#$c'] = at;
          }
          debugPrint('Guide load failed: $e');
        },
      ),
    );
  }

  void _evict(Set<String> keep) {
    if (_programmeCount <= maxProgrammes) return;
    final victims = <String>[];
    var count = _programmeCount;
    for (final e in _data.entries) {
      if (count <= maxProgrammes * 3 ~/ 4) break;
      if (keep.contains(e.key)) continue;
      victims.add(e.key);
      count -= e.value.list.length;
    }
    for (final k in victims) {
      _programmeCount -= _data.remove(k)!.list.length;
    }
  }

  void _scheduleNotify() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    scheduleMicrotask(() {
      _notifyScheduled = false;
      if (!_disposed) notifyListeners();
    });
  }

  /// Forgets everything (after an EPG reload); loads in flight are ignored.
  void clear() {
    _generation++;
    _data.clear();
    _inFlight.clear();
    _failedAt.clear();
    _programmeCount = 0;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class _KeyData {
  final Set<int> chunks = {};
  List<ProgrammeView> list = const [];

  /// Adds [added] (sorted or not), skipping programmes already known by
  /// start; returns how many were new.
  int merge(List<ProgrammeView> added) {
    if (list.isEmpty) {
      list = List.of(added)..sort(_byStart);
      return list.length;
    }
    final known = {for (final p in list) p.startMs};
    final fresh = [
      for (final p in added)
        if (known.add(p.startMs)) p,
    ];
    if (fresh.isEmpty) return 0;
    list = [...list, ...fresh]..sort(_byStart);
    return fresh.length;
  }

  static int _byStart(ProgrammeView a, ProgrammeView b) =>
      a.startMs.compareTo(b.startMs);
}
