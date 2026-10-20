/// Cells of the TV Guide grid: programmes, "No EPG data"
/// blocks and not-yet-loaded blocks, plus the time arithmetic the grid
/// shares with the overlays.
library;

import 'package:flutter/foundation.dart';

import '../../../data/repositories/repository_models.dart';
import 'guide_cache.dart';

/// Milliseconds per minute.
const int kMinuteMs = 60000;

/// Milliseconds of one guide slot (time headers every 15 minutes).
const int kSlotMs = 15 * kMinuteMs;

/// Milliseconds per hour ("No EPG data" blocks are split at whole hours).
const int kHourMs = 60 * kMinuteMs;

/// What a [GuideCell] shows.
enum GuideCellKind {
  /// A programme from the guide.
  programme,

  /// No programme is known for this hour ("No EPG data available").
  noData,

  /// The guide for this hour is still loading.
  loading,
}

/// One cell of a guide row.
@immutable
class GuideCell {
  const GuideCell({
    required this.startMs,
    required this.stopMs,
    required this.kind,
    this.programme,
  });

  factory GuideCell.programme(ProgrammeView p) => GuideCell(
    startMs: p.startMs,
    stopMs: p.stopMs,
    kind: GuideCellKind.programme,
    programme: p,
  );

  /// UTC epoch milliseconds.
  final int startMs;
  final int stopMs;
  final GuideCellKind kind;

  /// Set for [GuideCellKind.programme].
  final ProgrammeView? programme;

  DateTime get start =>
      DateTime.fromMillisecondsSinceEpoch(startMs, isUtc: true);
  DateTime get stop => DateTime.fromMillisecondsSinceEpoch(stopMs, isUtc: true);
  Duration get duration => Duration(milliseconds: stopMs - startMs);

  bool get isProgramme => kind == GuideCellKind.programme;

  bool isOnAirAt(int nowMs) => startMs <= nowMs && nowMs < stopMs;
  bool hasEndedAt(int nowMs) => stopMs <= nowMs;
  bool isUpcomingAt(int nowMs) => startMs > nowMs;

  /// Played fraction (0–1) at [nowMs].
  double progressAt(int nowMs) {
    final total = stopMs - startMs;
    if (total <= 0) return 0;
    return ((nowMs - startMs) / total).clamp(0.0, 1.0);
  }

  bool contains(int ms) => startMs <= ms && ms < stopMs;

  @override
  bool operator ==(Object other) =>
      other is GuideCell &&
      other.startMs == startMs &&
      other.stopMs == stopMs &&
      other.kind == kind &&
      other.programme == programme;

  @override
  int get hashCode => Object.hash(startMs, stopMs, kind, programme);

  @override
  String toString() =>
      'GuideCell(${kind.name} ${DateTime.fromMillisecondsSinceEpoch(startMs).toIso8601String()}'
      '${programme == null ? '' : ' "${programme!.title}"'})';
}

/// Start of the 15-minute slot containing [ms] (every real time zone is a
/// whole number of quarter hours away from UTC, so this is also the local
/// slot).
int floorToSlot(int ms) => ms - ms % kSlotMs;

/// Start of the local hour containing [ms].
int floorToLocalHour(int ms) {
  final offset = DateTime.fromMillisecondsSinceEpoch(ms).timeZoneOffset;
  final local = ms + offset.inMilliseconds;
  return local - local % kHourMs - offset.inMilliseconds;
}

/// Local midnight of the day containing [t] (any zone), as a local
/// [DateTime].
DateTime localDay(DateTime t) {
  final l = t.toLocal();
  return DateTime(l.year, l.month, l.day);
}

/// Calls [emit] for every cell of a row overlapping `[fromMs, toMs)`, in
/// time order: the row's programmes, with the gaps between them split into
/// one-hour blocks that are [GuideCellKind.noData] where the guide was
/// loaded and [GuideCellKind.loading] where it was not.
///
/// [key] is the row's EPG key (null: the channel has no guide, every block
/// is "No EPG data"). Overlapping programmes are clipped to the end of the
/// previous one. Allocation-free apart from [emit]'s arguments.
void forEachRowCell(
  GuideProgrammeCache cache,
  String? key,
  int fromMs,
  int toMs,
  void Function(
    int startMs,
    int stopMs,
    GuideCellKind kind,
    ProgrammeView? programme,
  )
  emit,
) {
  if (toMs <= fromMs) return;
  final list = key == null ? const <ProgrammeView>[] : cache.programmes(key);
  // Gap blocks end at whole local hours and (for keyed rows) at cache chunk
  // ends, so a block is the same whatever window asks for it.
  int blockFloor(int ms) {
    final hour = floorToLocalHour(ms);
    if (key == null) return hour;
    final chunk = cache.chunkStartMs(ms);
    return chunk > hour ? chunk : hour;
  }

  int blockCeil(int ms) {
    final hour = floorToLocalHour(ms) + kHourMs;
    if (key == null) return hour;
    final chunk = cache.chunkEndMs(ms);
    return chunk < hour ? chunk : hour;
  }

  var i = _firstEndingAfter(list, fromMs);
  int t;
  if (i < list.length && list[i].startMs <= fromMs) {
    t = list[i].startMs;
  } else {
    t = blockFloor(fromMs);
    if (i > 0 && list[i - 1].stopMs > t) t = list[i - 1].stopMs;
  }
  while (t < toMs) {
    if (i < list.length && list[i].startMs <= t) {
      final p = list[i++];
      if (p.stopMs <= t) continue; // fully overlapped by the previous one
      emit(t, p.stopMs, GuideCellKind.programme, p);
      t = p.stopMs;
      continue;
    }
    final kind = key == null || cache.isLoadedAt(key, t)
        ? GuideCellKind.noData
        : GuideCellKind.loading;
    var end = blockCeil(t);
    if (i < list.length && list[i].startMs < end) end = list[i].startMs;
    emit(t, end, kind, null);
    t = end;
  }
}

/// The cells of a row overlapping `[fromMs, toMs)` (see [forEachRowCell]).
List<GuideCell> rowCells(
  GuideProgrammeCache cache,
  String? key,
  int fromMs,
  int toMs,
) {
  final out = <GuideCell>[];
  forEachRowCell(
    cache,
    key,
    fromMs,
    toMs,
    (s, e, kind, p) =>
        out.add(GuideCell(startMs: s, stopMs: e, kind: kind, programme: p)),
  );
  return out;
}

/// The cell of a row that contains [ms].
GuideCell cellAt(GuideProgrammeCache cache, String? key, int ms) {
  final cells = rowCells(cache, key, ms, ms + 1);
  for (final c in cells) {
    if (c.contains(ms)) return c;
  }
  // Unreachable in practice: the iteration always covers [ms].
  final start = floorToLocalHour(ms);
  return GuideCell(
    startMs: start,
    stopMs: start + kHourMs,
    kind: GuideCellKind.noData,
  );
}

/// The cell after [cell] in the same row.
GuideCell nextCell(GuideProgrammeCache cache, String? key, GuideCell cell) =>
    cellAt(cache, key, cell.stopMs);

/// The cell before [cell] in the same row.
GuideCell previousCell(
  GuideProgrammeCache cache,
  String? key,
  GuideCell cell,
) => cellAt(cache, key, cell.startMs - 1);

/// Index of the first programme of [list] (sorted by start, non-overlapping
/// in practice) whose stop is after [ms].
int _firstEndingAfter(List<ProgrammeView> list, int ms) {
  var lo = 0;
  var hi = list.length;
  while (lo < hi) {
    final mid = (lo + hi) >> 1;
    if (list[mid].stopMs <= ms) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  return lo;
}
