import 'package:carina/data/db/database.dart';
import 'package:carina/features/reminders/reminders_api.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_reminder_os.dart';

final _now = DateTime.utc(2026, 10, 21, 20);

ReminderRow _row(
  int id, {
  required Duration startsIn,
  Duration length = const Duration(minutes: 30),
  bool fired = false,
}) {
  final start = _now.add(startsIn);
  return ReminderRow(
    id: id,
    playlistId: 1,
    channelId: 'c$id',
    channelName: 'Channel $id',
    title: 'Programme $id',
    start: start.millisecondsSinceEpoch,
    stop: start.add(length).millisecondsSinceEpoch,
    fired: fired,
    createdAt: _now,
  );
}

ReminderNotification _build(ReminderRow r, DateTime at) =>
    ReminderNotification(id: r.id, at: at, title: r.title, body: r.channelName);

void main() {
  late FakeReminderOs os;
  late ReminderOsSync sync;
  var now = _now;
  const lead = Duration(minutes: 5);

  Future<void> run(List<ReminderRow> rows, {Duration l = lead}) =>
      sync.sync(rows, lead: l, build: _build);

  setUp(() {
    now = _now;
    os = FakeReminderOs();
    sync = ReminderOsSync(os, clock: () => now);
  });

  test('schedules at start minus the lead, once', () async {
    final r = _row(1, startsIn: const Duration(minutes: 30));
    await run([r]);
    expect(os.calls, ['schedule 1']);
    expect(os.pending[1]!.at, _now.add(const Duration(minutes: 25)));
    expect(os.pending[1]!.title, 'Programme 1');
    await run([r]);
    expect(os.calls, ['schedule 1']);
  });

  test('a start inside the lead is scheduled at the start', () async {
    await run([_row(1, startsIn: const Duration(minutes: 3))]);
    expect(os.pending[1]!.at, _now.add(const Duration(minutes: 3)));
  });

  test('already due, started, ended and fired ones are left alone', () async {
    await run([
      _row(1, startsIn: const Duration(seconds: 1)),
      _row(2, startsIn: const Duration(minutes: -10)),
      _row(3, startsIn: const Duration(minutes: -40)),
      _row(4, startsIn: const Duration(minutes: 30), fired: true),
    ]);
    expect(os.calls, isEmpty);
  });

  test('removing a reminder cancels it; expiry and firing do not', () async {
    final a = _row(1, startsIn: const Duration(minutes: 30));
    final b = _row(2, startsIn: const Duration(minutes: 60));
    final c = _row(3, startsIn: const Duration(minutes: 90));
    await run([a, b, c]);
    expect(sync.scheduledIds, {1, 2, 3});
    os.calls.clear();

    // The user removes `a`; `b` fires in the app; `c` stays.
    await run([b.copyWith(fired: true), c]);
    expect(os.calls, ['cancel 1']);
    expect(sync.scheduledIds, {3});

    // `c` is deleted after its programme ended: no cancel (the notification
    // may be on screen).
    os.calls.clear();
    now = _now.add(const Duration(hours: 3));
    await run(const []);
    expect(os.calls, isEmpty);
    expect(sync.scheduledIds, isEmpty);
  });

  test('a new lead time reschedules every reminder', () async {
    final r = _row(1, startsIn: const Duration(minutes: 30));
    await run([r]);
    await run([r], l: const Duration(minutes: 10));
    expect(os.calls, ['schedule 1', 'schedule 1']);
    expect(os.pending[1]!.at, _now.add(const Duration(minutes: 20)));
  });

  test('a time that passed is not scheduled a second time', () async {
    final r = _row(1, startsIn: const Duration(minutes: 30));
    await run([r]);
    now = _now.add(const Duration(minutes: 27));
    await run([r]);
    expect(os.calls, ['schedule 1']);
  });

  test('desktop has nothing to schedule', () async {
    final none = ReminderOsSync(
      const NoReminderOsScheduler(),
      clock: () => now,
    );
    await none.sync(
      [_row(1, startsIn: const Duration(minutes: 30))],
      lead: lead,
      build: _build,
    );
    expect(none.scheduledIds, isEmpty);
    expect(await const NoReminderOsScheduler().requestPermission(), isFalse);
  });
}
