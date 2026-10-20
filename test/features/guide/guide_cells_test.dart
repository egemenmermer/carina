import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/repositories/repository_models.dart';
import 'package:carina/features/guide/src/guide_actions.dart';
import 'package:carina/features/guide/src/guide_cache.dart';
import 'package:carina/features/guide/src/guide_cells.dart';
import 'package:carina/features/guide/src/guide_controller.dart';
import 'package:carina/features/guide/src/guide_days.dart';

const _min = kMinuteMs;
final _base = DateTime.utc(2026, 10, 17, 12).millisecondsSinceEpoch;

ProgrammeView _p(int startMin, int stopMin, String title) => ProgrammeView(
  epgChannelId: 'k',
  start: DateTime.fromMillisecondsSinceEpoch(
    _base + startMin * _min,
    isUtc: true,
  ),
  stop: DateTime.fromMillisecondsSinceEpoch(
    _base + stopMin * _min,
    isUtc: true,
  ),
  title: title,
);

ChannelView _channel({int archiveDays = 0}) => ChannelView(
  row: ChannelRow(
    id: 1,
    playlistId: 1,
    providerId: 'c1',
    name: 'C1',
    displayName: 'C1',
    sortIndex: 0,
    archiveDays: archiveDays,
    hidden: false,
    locked: false,
    unsupported: false,
    removed: false,
  ),
  displayName: 'C1',
  badges: const [],
  locked: false,
  favorite: false,
  hasReminder: false,
  hasArchive: archiveDays > 0,
  epgKey: 'k',
  categoryName: '',
);

/// A cache loaded synchronously from [list] for every chunk asked.
Future<GuideProgrammeCache> _cache(List<ProgrammeView> list) async {
  final cache = GuideProgrammeCache(
    (keys, from, to) async => {
      for (final k in keys)
        k: [
          for (final p in list)
            if (p.stop.isAfter(from) && p.start.isBefore(to)) p,
        ],
    },
  );
  cache.ensure(
    ['k'],
    DateTime.fromMillisecondsSinceEpoch(_base - 12 * 60 * _min, isUtc: true),
    DateTime.fromMillisecondsSinceEpoch(_base + 12 * 60 * _min, isUtc: true),
  );
  await Future<void>.delayed(Duration.zero);
  return cache;
}

void main() {
  test('rows are programmes with hour blocks in the gaps', () async {
    final cache = await _cache([
      _p(-30, 20, 'A'),
      _p(20, 50, 'B'),
      _p(130, 190, 'C'),
    ]);
    final cells = rowCells(cache, 'k', _base, _base + 180 * _min);
    expect(cells.map((c) => c.programme?.title ?? c.kind.name).toList(), [
      'A',
      'B',
      'noData', // 12:50–13:00
      'noData', // 13:00–14:00
      'noData', // 14:00–14:10
      'C',
    ]);
    // The first cell keeps its real start (it began before the window).
    expect(cells.first.startMs, _base - 30 * _min);
    expect(cells[2].startMs, _base + 50 * _min);
    expect(cells[3].stopMs - cells[3].startMs, 60 * _min);
  });

  test('a block is the same whatever window asks for it', () async {
    final cache = await _cache([_p(0, 20, 'A'), _p(200, 260, 'B')]);
    final a = cellAt(cache, 'k', _base + 100 * _min);
    final b = rowCells(cache, 'k', _base + 95 * _min, _base + 96 * _min).first;
    expect(a, b);
    expect(a.kind, GuideCellKind.noData);
  });

  test('unloaded chunks are loading blocks; rows without key are noData', () {
    final cache = GuideProgrammeCache((keys, from, to) async => {});
    final cells = rowCells(cache, 'k', _base, _base + 60 * _min);
    expect(cells.every((c) => c.kind == GuideCellKind.loading), isTrue);
    final none = rowCells(cache, null, _base, _base + 60 * _min);
    expect(none.every((c) => c.kind == GuideCellKind.noData), isTrue);
  });

  test('next / previous cell walk the row', () async {
    final cache = await _cache([_p(0, 30, 'A'), _p(30, 90, 'B')]);
    final a = cellAt(cache, 'k', _base + 10 * _min);
    final b = nextCell(cache, 'k', a);
    expect(b.programme?.title, 'B');
    expect(previousCell(cache, 'k', b), a);
  });

  test('cache merges chunks without duplicates and counts loads', () async {
    var calls = 0;
    final cache = GuideProgrammeCache((keys, from, to) async {
      calls++;
      return {
        'k': [_p(-30, 400, 'Long')],
      };
    }, chunk: const Duration(hours: 6));
    final from = DateTime.fromMillisecondsSinceEpoch(_base, isUtc: true);
    cache.ensure(['k'], from, from.add(const Duration(hours: 13)));
    await Future<void>.delayed(Duration.zero);
    expect(calls, 3);
    expect(cache.programmes('k'), hasLength(1));
    // Everything is loaded: no new calls.
    cache.ensure(['k'], from, from.add(const Duration(hours: 13)));
    expect(calls, 3);
    cache.clear();
    expect(cache.programmes('k'), isEmpty);
  });

  test('cell routing: on air → live, archived → catch-up, else details', () {
    final now = _base + 60 * _min;
    GuideFocus focus(
      int start,
      int stop, {
      int archive = 0,
      bool data = true,
    }) => GuideFocus(
      row: 0,
      channel: _channel(archiveDays: archive),
      cell: GuideCell(
        startMs: _base + start * _min,
        stopMs: _base + stop * _min,
        kind: data ? GuideCellKind.programme : GuideCellKind.noData,
        programme: data ? _p(start, stop, 'X') : null,
      ),
    );
    expect(guideCellAction(focus(30, 90), now), GuideCellAction.watchLive);
    expect(
      guideCellAction(focus(30, 90, data: false), now),
      GuideCellAction.watchLive,
    );
    expect(
      guideCellAction(focus(0, 30, archive: 3), now),
      GuideCellAction.catchup,
    );
    expect(guideCellAction(focus(0, 30), now), GuideCellAction.details);
    expect(guideCellAction(focus(90, 120), now), GuideCellAction.details);
    expect(
      guideCellAction(focus(0, 30, data: false), now),
      GuideCellAction.none,
    );
  });

  test('day picker: today always, other days only with data', () {
    final now = DateTime(2026, 10, 17, 15);
    expect(guideDays(now, null), [DateTime(2026, 10, 17)]);
    final range = (
      start: DateTime(2026, 10, 15, 6).toUtc(),
      end: DateTime(2026, 10, 20, 2).toUtc(),
    );
    expect(guideDays(now, range), [
      for (var d = 15; d <= 20; d++) DateTime(2026, 10, d),
    ]);
    final r = guideTimeRange(now, range, 120);
    expect(r.startMs, DateTime(2026, 10, 15, 6).millisecondsSinceEpoch);
    expect(r.endMs, DateTime(2026, 10, 20, 2).millisecondsSinceEpoch);
  });
}
