/// Side effects of reminders behind providers, so tests can replace them:
/// the OS notification (local_notifier on desktop, flutter_local_notifications
/// on Android), notifications scheduled for the programme time (Android) and
/// the "Watch now" action.
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../app/time_format.dart';
import '../../../data/db/database.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../player/player_api.dart';
import '../../playlists/playlist_access.dart';

/// Shows a system notification (Windows toast / macOS notification /
/// Android notification).
///
/// [id] is the reminder's id: on Android it is the notification id, so a
/// notification scheduled for the same reminder is replaced instead of shown
/// twice. Desktop ignores it.
abstract interface class ReminderSystemNotifier {
  Future<void> show({
    required String title,
    required String body,
    int? id,
    VoidCallback? onClick,
  });
}

/// [ReminderSystemNotifier] over `local_notifier` (set up at bootstrap with
/// the Carina AppUserModelID). Failures are logged and ignored: the in-app
/// banner is shown anyway.
class LocalReminderNotifier implements ReminderSystemNotifier {
  const LocalReminderNotifier();

  @override
  Future<void> show({
    required String title,
    required String body,
    int? id,
    VoidCallback? onClick,
  }) async {
    if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) return;
    try {
      final notification = LocalNotification(title: title, body: body);
      notification
        ..onClick = () {
          onClick?.call();
          localNotifier.removeListener(notification);
        }
        ..onClose = (_) => localNotifier.removeListener(notification);
      await notification.show();
    } catch (e) {
      debugPrint('Reminder notification failed: $e');
    }
  }
}

/// A notification the OS shows at [at] even when Carina is not running.
@immutable
class ReminderNotification {
  const ReminderNotification({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
  });

  /// The reminder's id (also the notification id).
  final int id;

  /// When to show it (UTC).
  final DateTime at;
  final String title;
  final String body;
}

/// Notifications scheduled with the OS (Android; desktop only notifies while
/// Carina runs) and the permission they need.
abstract interface class ReminderOsScheduler {
  /// Whether this platform can show a reminder while Carina is closed.
  bool get supported;

  /// Starts the plugin (and reports a tap that launched the app on
  /// [taps]). Call after listening to [taps].
  Future<void> start();

  /// Asks for the notification permission when it is not granted yet
  /// (Android 13+: `POST_NOTIFICATIONS`); returns whether notifications can
  /// be shown.
  Future<bool> requestPermission();

  /// Schedules (or replaces) the notification with [ReminderNotification.id].
  Future<void> schedule(ReminderNotification notification);

  /// Cancels the pending notification [id] (and dismisses it if shown).
  Future<void> cancel(int id);

  /// Reminder ids of notifications the user tapped.
  Stream<int> get taps;
}

/// Desktop: nothing to schedule.
class NoReminderOsScheduler implements ReminderOsScheduler {
  const NoReminderOsScheduler();

  @override
  bool get supported => false;

  @override
  Future<void> start() async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> schedule(ReminderNotification notification) async {}

  @override
  Future<void> cancel(int id) async {}

  @override
  Stream<int> get taps => const Stream<int>.empty();
}

/// Android: shows reminders and schedules them with `zonedSchedule`.
///
/// - No timezone database: the plugin only needs the instant, so dates are
///   `TZDateTime`s in the built-in UTC location (no `initializeTimeZones`).
/// - Inexact alarms (`inexactAllowWhileIdle`): no exact-alarm permission,
///   which Play restricts and a TV user could not grant easily. A reminder
///   may be a few minutes late when the TV sleeps.
/// - Failures are logged and ignored: the in-app banner is shown anyway.
class AndroidReminderNotifications
    implements ReminderSystemNotifier, ReminderOsScheduler {
  AndroidReminderNotifications({
    required this.channelTexts,
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const channelId = 'reminders';

  /// Name and description of the notification channel (shown in the
  /// system settings), in the current UI language.
  final ({String name, String description}) Function() channelTexts;

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<int> _taps = StreamController<int>.broadcast();
  Future<bool>? _ready;

  @override
  bool get supported => true;

  @override
  Stream<int> get taps => _taps.stream;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  Future<bool> _init() => _ready ??= _initialize();

  Future<bool> _initialize() async {
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/ic_stat_reminder'),
        ),
        onDidReceiveNotificationResponse: _onResponse,
      );
      final texts = channelTexts();
      await _android?.createNotificationChannel(
        AndroidNotificationChannel(
          channelId,
          texts.name,
          description: texts.description,
          importance: Importance.high,
        ),
      );
      return true;
    } catch (e) {
      debugPrint('Reminder notifications unavailable: $e');
      return false;
    }
  }

  void _onResponse(NotificationResponse response) {
    final id = int.tryParse(response.payload ?? '');
    if (id != null && !_taps.isClosed) _taps.add(id);
  }

  NotificationDetails _details() {
    final texts = channelTexts();
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        texts.name,
        channelDescription: texts.description,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
      ),
    );
  }

  @override
  Future<void> start() async {
    if (!await _init()) return;
    try {
      final launch = await _plugin.getNotificationAppLaunchDetails();
      final response = launch?.notificationResponse;
      if (launch?.didNotificationLaunchApp == true && response != null) {
        _onResponse(response);
      }
    } catch (e) {
      debugPrint('Reminder launch details failed: $e');
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!await _init()) return false;
    try {
      final android = _android;
      if (android == null) return false;
      if (await android.areNotificationsEnabled() ?? false) return true;
      return await android.requestNotificationsPermission() ?? false;
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
      return false;
    }
  }

  @override
  Future<void> show({
    required String title,
    required String body,
    int? id,
    VoidCallback? onClick,
  }) async {
    if (!await _init()) return;
    try {
      await _plugin.show(
        id: id ?? (title.hashCode & 0x7fffffff),
        title: title,
        body: body,
        notificationDetails: _details(),
        payload: id?.toString(),
      );
    } catch (e) {
      debugPrint('Reminder notification failed: $e');
    }
  }

  @override
  Future<void> schedule(ReminderNotification notification) async {
    if (!await _init()) return;
    try {
      await _plugin.zonedSchedule(
        id: notification.id,
        scheduledDate: tz.TZDateTime.fromMillisecondsSinceEpoch(
          tz.UTC,
          notification.at.millisecondsSinceEpoch,
        ),
        title: notification.title,
        body: notification.body,
        notificationDetails: _details(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: '${notification.id}',
      );
    } catch (e) {
      debugPrint('Reminder scheduling failed: $e');
    }
  }

  @override
  Future<void> cancel(int id) async {
    if (!await _init()) return;
    try {
      await _plugin.cancel(id: id);
    } catch (e) {
      debugPrint('Reminder cancel failed: $e');
    }
  }
}

final _androidRemindersProvider = Provider<AndroidReminderNotifications>((ref) {
  final notifications = AndroidReminderNotifications(
    channelTexts: () {
      final l10n = lookupL10n(Locale(ref.read(appLocaleCodeProvider)));
      return (
        name: l10n.remindersChannelName,
        description: l10n.remindersChannelDescription,
      );
    },
  );
  return notifications;
});

final reminderSystemNotifierProvider = Provider<ReminderSystemNotifier>(
  (ref) => !kIsWeb && Platform.isAndroid
      ? ref.watch(_androidRemindersProvider)
      : const LocalReminderNotifier(),
);

final reminderOsSchedulerProvider = Provider<ReminderOsScheduler>(
  (ref) => !kIsWeb && Platform.isAndroid
      ? ref.watch(_androidRemindersProvider)
      : const NoReminderOsScheduler(),
);

/// Keeps the OS notifications equal to the reminder list: every unfired
/// reminder whose programme has not ended is scheduled at `start - lead`
/// (at the start when that is already past); a changed lead time
/// reschedules; a reminder the user removed
/// before its programme ended is cancelled.
///
/// Reminders that fired (the in-app scheduler cancels the pending OS
/// notification and shows it itself) and expired ones are forgotten, never
/// cancelled: cancelling would dismiss a notification the user may be
/// looking at. Reminders that are due right now are left to the in-app
/// scheduler while Carina runs.
class ReminderOsSync {
  ReminderOsSync(this._os, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final ReminderOsScheduler _os;
  final DateTime Function() _clock;

  /// What is scheduled: the row and the lead it was planned with.
  final Map<int, ({Duration lead, ReminderRow row})> _scheduled = {};
  Future<void> _tail = Future.value();

  /// The ids currently scheduled (tests).
  Set<int> get scheduledIds => _scheduled.keys.toSet();

  /// Brings the OS in line with [reminders]; [build] makes the notification
  /// (localized texts) for a reminder shown at [DateTime].
  Future<void> sync(
    List<ReminderRow> reminders, {
    required Duration lead,
    required ReminderNotification Function(ReminderRow reminder, DateTime at)
    build,
  }) {
    if (!_os.supported) return Future.value();
    return _tail = _tail.then((_) => _run(reminders, lead, build));
  }

  Future<void> _run(
    List<ReminderRow> reminders,
    Duration lead,
    ReminderNotification Function(ReminderRow, DateTime) build,
  ) async {
    final now = _clock();
    final nowMs = now.millisecondsSinceEpoch;
    final byId = {for (final r in reminders) r.id: r};
    for (final id in _scheduled.keys.toList()) {
      final row = byId[id];
      if (row == null) {
        final removed = _scheduled.remove(id)!;
        // Gone before the programme ended: the user removed it.
        if (removed.row.stop > nowMs) await _os.cancel(id);
      } else if (row.fired || row.stop <= nowMs) {
        _scheduled.remove(id);
      }
    }
    for (final r in reminders) {
      if (r.fired || r.stop <= nowMs) continue;
      // Already planned with this lead (its time may have passed since).
      if (_scheduled[r.id]?.lead == lead) continue;
      final start = DateTime.fromMillisecondsSinceEpoch(r.start, isUtc: true);
      var at = start.subtract(lead);
      final soonest = now.add(const Duration(seconds: 2));
      if (!at.isAfter(soonest)) at = start;
      // Due now: the in-app scheduler reports it while Carina runs.
      if (!at.isAfter(soonest)) continue;
      _scheduled[r.id] = (lead: lead, row: r);
      await _os.schedule(build(r, at));
    }
  }
}

/// Starts the sync for [ReminderListener].
final reminderOsSyncProvider = Provider<ReminderOsSync>(
  (ref) => ReminderOsSync(ref.watch(reminderOsSchedulerProvider)),
);

/// "Watch now" on a due reminder: playlist access PIN, then the live player
/// (which asks for the parental PIN itself).
class ReminderActions {
  const ReminderActions();

  Future<void> watchNow(BuildContext context, ReminderRow reminder) async {
    if (!await ensurePlaylistUnlocked(
      context,
      playlistId: reminder.playlistId,
    )) {
      return;
    }
    if (!context.mounted) return;
    await openPlayer(
      context,
      LivePlayRequest(
        playlistId: reminder.playlistId,
        channelId: reminder.channelId,
      ),
    );
  }
}

final reminderActionsProvider = Provider<ReminderActions>(
  (ref) => const ReminderActions(),
);
