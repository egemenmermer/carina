import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/clock.dart';
import '../../app/router.dart' show rootNavigatorKey;
import '../../app/time_format.dart';
import '../../core/core.dart';
import '../../data/db/database.dart';
import '../../data/repositories/epg_repository.dart';
import '../../data/repositories/live_repository.dart';
import '../../data/repositories/reminders_repository.dart';
import '../../data/settings/settings_store.dart';
import '../../l10n/gen/app_localizations.dart';
import '../guide/data/guide_queries.dart';
import 'src/reminder_services.dart';

export 'src/reminder_services.dart'
    show
        AndroidReminderNotifications,
        LocalReminderNotifier,
        NoReminderOsScheduler,
        ReminderActions,
        ReminderNotification,
        ReminderOsScheduler,
        ReminderOsSync,
        ReminderSystemNotifier,
        reminderActionsProvider,
        reminderOsSchedulerProvider,
        reminderSystemNotifierProvider;

/// Reminders. Owner: `lib/features/reminders/`.

/// Sets or clears a reminder for the programme starting at [startUtc] on
/// [channelId]; shows the green toast and, when setting one, the note that
/// Carina must be running (not on Android, where the OS shows the reminder
/// at the programme time once the notification permission is granted, asked
/// for the first time a reminder is set).
///
/// Programmes that already started cannot get a new reminder (an info
/// toast says so); an existing one can always be removed.
Future<void> toggleReminder(
  BuildContext context, {
  required int playlistId,
  required String channelId,
  required DateTime startUtc,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final l10n = L10n.of(context);
  final toast = container.read(toastControllerProvider);
  final channel = await container
      .read(liveRepositoryProvider)
      .channel(playlistId, channelId);
  final programme = channel == null
      ? null
      : await container
            .read(epgRepositoryProvider)
            .programmeStartingAt(playlistId, channel, startUtc);
  if (channel == null || programme == null) {
    toast.show(l10n.remindersNotFound, kind: KToastKind.error);
    return;
  }
  final repo = container.read(remindersRepositoryProvider);
  final already = await repo.isSet(playlistId, channelId, programme.start);
  final now = container.read(clockSourceProvider)();
  if (!already && !programme.isUpcomingAt(now)) {
    toast.show(l10n.remindersAlreadyStarted, kind: KToastKind.info);
    return;
  }
  final isSet = await repo.toggle(playlistId, channel.row, programme);
  var scheduled = false;
  if (isSet) {
    scheduled = await container
        .read(reminderOsSchedulerProvider)
        .requestPermission();
  }
  toast.show(
    !isSet
        ? l10n.remindersRemoved
        : scheduled
        ? l10n.remindersSetScheduled
        : l10n.remindersSet,
    icon: isSet ? PhosphorIconsFill.bellRinging : PhosphorIconsFill.bellSlash,
  );
}

/// Placed by the app shell around the router: listens to due reminders and
/// shows the OS notification + in-app banner (Watch now / Dismiss).
///
/// Starts `reminderSchedulerProvider` (lead time from
/// `AppSettings.reminderLeadMinutes`). "Watch now" opens the live player on
/// [navigatorKey] (default: the app's root navigator).
class ReminderListener extends ConsumerStatefulWidget {
  const ReminderListener({super.key, required this.child, this.navigatorKey});

  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  ConsumerState<ReminderListener> createState() => _ReminderListenerState();
}

class _ReminderListenerState extends ConsumerState<ReminderListener> {
  ProviderSubscription<ReminderScheduler>? _scheduler;
  StreamSubscription<ReminderRow>? _due;
  StreamSubscription<int>? _taps;

  @override
  void initState() {
    super.initState();
    _scheduler = ref.listenManual<ReminderScheduler>(
      reminderSchedulerProvider,
      (previous, next) => _listen(next),
      fireImmediately: true,
    );
    // OS notifications (Android): keep them equal to the reminder list and
    // open the channel of a tapped one.
    final os = ref.read(reminderOsSchedulerProvider);
    if (os.supported) {
      ref.listenManual(
        remindersProvider(null),
        (previous, next) => _syncOs(next.value),
      );
      ref.listenManual(settingsRevisionProvider, (previous, next) {
        _syncOs(ref.read(remindersProvider(null)).value);
      });
      _taps = os.taps.listen((id) => unawaited(_onTap(id)));
      unawaited(os.start());
      // The first sync needs the localizations (not available in initState).
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _syncOs(ref.read(remindersProvider(null)).value),
      );
    }
  }

  void _syncOs(List<ReminderRow>? reminders) {
    if (!mounted || reminders == null) return;
    final l10n = L10n.of(context);
    final fmt = ref.read(timeFormatProvider);
    final lead = Duration(
      minutes: ref
          .read(settingsStoreProvider)
          .get(AppSettings.reminderLeadMinutes),
    );
    unawaited(
      ref
          .read(reminderOsSyncProvider)
          .sync(
            reminders,
            lead: lead,
            build: (reminder, at) => ReminderNotification(
              id: reminder.id,
              at: at,
              title: reminder.title,
              body: _bodyFor(reminder, l10n, fmt, at),
            ),
          ),
    );
  }

  Future<void> _onTap(int id) async {
    final reminder = await ref.read(remindersRepositoryProvider).byId(id);
    if (reminder == null || !mounted) return;
    // After the first frame: a tap can launch the app, with no navigator yet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _watch(reminder);
    });
  }

  /// "Channel · starts at 20:00" (or "on air now" once it started).
  String _bodyFor(
    ReminderRow reminder,
    L10n l10n,
    CarinaTimeFormat fmt,
    DateTime now,
  ) {
    final start = DateTime.fromMillisecondsSinceEpoch(
      reminder.start,
      isUtc: true,
    );
    return start.isAfter(now)
        ? l10n.remindersStartsAt(reminder.channelName, fmt.time(start))
        : l10n.remindersOnAirNow(reminder.channelName);
  }

  void _listen(ReminderScheduler scheduler) {
    unawaited(_due?.cancel());
    _due = scheduler.dueReminders.listen(_onDue);
  }

  @override
  void dispose() {
    unawaited(_due?.cancel());
    unawaited(_taps?.cancel());
    _scheduler?.close();
    super.dispose();
  }

  void _onDue(ReminderRow reminder) {
    if (!mounted) return;
    final l10n = L10n.of(context);
    final fmt = ref.read(timeFormatProvider);
    final now = ref.read(clockSourceProvider)();
    final body = _bodyFor(reminder, l10n, fmt, now);
    // The pending OS notification of this reminder (Android) is replaced by
    // this one, not shown after it.
    unawaited(
      ref
          .read(reminderOsSchedulerProvider)
          .cancel(reminder.id)
          .then(
            (_) => ref
                .read(reminderSystemNotifierProvider)
                .show(
                  title: reminder.title,
                  body: body,
                  id: reminder.id,
                  onClick: () => _watch(reminder),
                ),
          ),
    );
    ref
        .read(toastControllerProvider)
        .showBanner(
          title: reminder.title,
          message: body,
          icon: PhosphorIconsFill.bellRinging,
          actions: [
            KBannerAction(
              label: l10n.remindersWatchNow,
              primary: true,
              onPressed: () => _watch(reminder),
            ),
            KBannerAction(label: l10n.remindersDismiss, onPressed: () {}),
          ],
        );
  }

  void _watch(ReminderRow reminder) {
    final navigatorContext =
        widget.navigatorKey?.currentState?.overlay?.context ??
        rootNavigatorKey.currentState?.overlay?.context ??
        (mounted ? context : null);
    if (navigatorContext == null) return;
    unawaited(
      ref.read(reminderActionsProvider).watchNow(navigatorContext, reminder),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
