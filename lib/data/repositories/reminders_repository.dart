/// Programme reminders: storage and the in-app scheduler that
/// reports due reminders (the UI shows the toast / banner).
library;

import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_paths.dart' show appDatabaseProvider;
import '../db/database.dart';
import '../settings/settings_store.dart';
import 'repository_models.dart';

/// Reminders are keyed by playlist, provider channel id and programme start
/// (UTC epoch ms), so they survive reloads.
class RemindersRepository {
  RemindersRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  /// Reminders by programme start, of one playlist or (null) all of them
  /// (Settings → Manage reminders). Ended ones are removed by the
  /// scheduler.
  Stream<List<ReminderRow>> watchAll([int? playlistId]) {
    final q = _db.select(_db.reminders)
      ..orderBy([
        (r) => OrderingTerm(expression: r.start),
        (r) => OrderingTerm(expression: r.id),
      ]);
    if (playlistId != null) q.where((r) => r.playlistId.equals(playlistId));
    return q.watch();
  }

  /// Reminders of one channel (bells on UPCOMING rows and guide cells).
  Stream<List<ReminderRow>> watchForChannel(int playlistId, String channelId) =>
      (_db.select(_db.reminders)
            ..where(
              (r) =>
                  r.playlistId.equals(playlistId) &
                  r.channelId.equals(channelId),
            )
            ..orderBy([(r) => OrderingTerm(expression: r.start)]))
          .watch();

  /// The reminder [id], or null once it is removed or expired.
  Future<ReminderRow?> byId(int id) => (_db.select(
    _db.reminders,
  )..where((r) => r.id.equals(id))).getSingleOrNull();

  Future<bool> isSet(int playlistId, String channelId, DateTime start) async =>
      await _find(playlistId, channelId, start.millisecondsSinceEpoch) != null;

  /// Sets a reminder for [programme] on [channel]; returns its id (the
  /// existing one when already set).
  Future<int> add(
    int playlistId,
    ChannelRow channel,
    ProgrammeView programme,
  ) async {
    final existing = await _find(
      playlistId,
      channel.providerId,
      programme.startMs,
    );
    if (existing != null) return existing.id;
    return _db
        .into(_db.reminders)
        .insert(
          RemindersCompanion.insert(
            playlistId: playlistId,
            channelId: channel.providerId,
            channelName: channel.displayName.trim().isEmpty
                ? channel.name
                : channel.displayName,
            epgChannelId: Value(programme.epgChannelId),
            title: programme.title,
            start: programme.startMs,
            stop: programme.stopMs,
            createdAt: _clock(),
          ),
        );
  }

  Future<void> remove(int id) =>
      (_db.delete(_db.reminders)..where((r) => r.id.equals(id))).go();

  /// Adds the reminder, or removes it when set; returns whether it is set
  /// afterwards (the bell state).
  Future<bool> toggle(
    int playlistId,
    ChannelRow channel,
    ProgrammeView programme,
  ) async {
    final existing = await _find(
      playlistId,
      channel.providerId,
      programme.startMs,
    );
    if (existing != null) {
      await remove(existing.id);
      return false;
    }
    await add(playlistId, channel, programme);
    return true;
  }

  Future<void> markFired(int id) =>
      (_db.update(_db.reminders)..where((r) => r.id.equals(id))).write(
        const RemindersCompanion(fired: Value(true)),
      );

  /// Unfired reminders of every playlist whose programme starts within
  /// [lead] of [now] (or already started) and has not ended, by start.
  Future<List<ReminderRow>> due(DateTime now, Duration lead) {
    final ms = now.millisecondsSinceEpoch;
    return (_db.select(_db.reminders)
          ..where(
            (r) =>
                r.fired.equals(false) &
                r.start.isSmallerOrEqualValue(ms + lead.inMilliseconds) &
                r.stop.isBiggerThanValue(ms),
          )
          ..orderBy([(r) => OrderingTerm(expression: r.start)]))
        .get();
  }

  /// Deletes reminders whose programme ended before [before] (default now);
  /// returns how many.
  Future<int> deleteExpired({DateTime? before}) {
    final ms = (before ?? _clock()).millisecondsSinceEpoch;
    return (_db.delete(
      _db.reminders,
    )..where((r) => r.stop.isSmallerOrEqualValue(ms))).go();
  }

  Future<ReminderRow?> _find(int playlistId, String channelId, int startMs) =>
      (_db.select(_db.reminders)..where(
            (r) =>
                r.playlistId.equals(playlistId) &
                r.channelId.equals(channelId) &
                r.start.equals(startMs),
          ))
          .getSingleOrNull();
}

/// Checks for due reminders every [interval] (pure Dart; the clock is
/// injectable) and emits each one once on [dueReminders], marking it fired.
/// Programmes that are already over are skipped, and ended reminders are
/// deleted. The app must be running.
class ReminderScheduler {
  ReminderScheduler(
    this._repo, {
    required this._lead,
    DateTime Function()? clock,
    this.interval = const Duration(seconds: 15),
  }) : _clock = clock ?? DateTime.now;

  final RemindersRepository _repo;
  final Duration Function() _lead;
  final DateTime Function() _clock;
  final Duration interval;

  final StreamController<ReminderRow> _due =
      StreamController<ReminderRow>.broadcast();
  Timer? _timer;
  bool _ticking = false;
  bool _disposed = false;

  /// Reminders that became due (already marked fired).
  Stream<ReminderRow> get dueReminders => _due.stream;

  bool get isRunning => _timer != null;

  /// Starts the periodic check (and runs one now).
  void start() {
    if (_disposed || _timer != null) return;
    _timer = Timer.periodic(interval, (_) => unawaited(tick()));
    unawaited(tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// One check: emits and returns the reminders that became due. Calls
  /// that overlap a running check return nothing.
  Future<List<ReminderRow>> tick() async {
    if (_ticking || _disposed) return const [];
    _ticking = true;
    try {
      final now = _clock();
      final nowMs = now.millisecondsSinceEpoch;
      final fired = <ReminderRow>[];
      for (final r in await _repo.due(now, _lead())) {
        if (r.stop <= nowMs) continue;
        await _repo.markFired(r.id);
        final row = r.copyWith(fired: true);
        fired.add(row);
        if (!_due.isClosed) _due.add(row);
      }
      await _repo.deleteExpired(before: now);
      return fired;
    } finally {
      _ticking = false;
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    stop();
    await _due.close();
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final remindersRepositoryProvider = Provider<RemindersRepository>(
  (ref) => RemindersRepository(ref.watch(appDatabaseProvider)),
);

/// Reminders of a playlist, or of every playlist for null.
final remindersProvider = StreamProvider.autoDispose
    .family<List<ReminderRow>, int?>(
      (ref, playlistId) =>
          ref.watch(remindersRepositoryProvider).watchAll(playlistId),
    );

/// Reminders of one channel.
final channelRemindersProvider = StreamProvider.autoDispose
    .family<List<ReminderRow>, ({int playlistId, String channelId})>(
      (ref, args) => ref
          .watch(remindersRepositoryProvider)
          .watchForChannel(args.playlistId, args.channelId),
    );

/// The running scheduler (lead time from `reminderLeadMinutes`); the UI
/// listens to [ReminderScheduler.dueReminders] for toasts and banners.
final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) {
  final settings = ref.watch(settingsStoreProvider);
  final scheduler = ReminderScheduler(
    ref.watch(remindersRepositoryProvider),
    lead: () =>
        Duration(minutes: settings.get(AppSettings.reminderLeadMinutes)),
  )..start();
  ref.onDispose(scheduler.dispose);
  return scheduler;
});
