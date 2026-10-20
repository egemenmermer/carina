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
import '../../l10n/gen/app_localizations.dart';
import '../guide/data/guide_queries.dart';
import 'src/reminder_services.dart';

export 'src/reminder_services.dart'
    show
        LocalReminderNotifier,
        ReminderActions,
        ReminderSystemNotifier,
        reminderActionsProvider,
        reminderSystemNotifierProvider;

/// Reminders. Owner: `lib/features/reminders/`.

/// Sets or clears a reminder for the programme starting at [startUtc] on
/// [channelId]; shows the green toast and, when setting one, the note that
/// Carina must be running.
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
  toast.show(
    isSet ? l10n.remindersSet : l10n.remindersRemoved,
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

  @override
  void initState() {
    super.initState();
    _scheduler = ref.listenManual<ReminderScheduler>(
      reminderSchedulerProvider,
      (previous, next) => _listen(next),
      fireImmediately: true,
    );
  }

  void _listen(ReminderScheduler scheduler) {
    unawaited(_due?.cancel());
    _due = scheduler.dueReminders.listen(_onDue);
  }

  @override
  void dispose() {
    unawaited(_due?.cancel());
    _scheduler?.close();
    super.dispose();
  }

  void _onDue(ReminderRow reminder) {
    if (!mounted) return;
    final l10n = L10n.of(context);
    final fmt = ref.read(timeFormatProvider);
    final now = ref.read(clockSourceProvider)();
    final start = DateTime.fromMillisecondsSinceEpoch(
      reminder.start,
      isUtc: true,
    );
    final body = start.isAfter(now)
        ? l10n.remindersStartsAt(reminder.channelName, fmt.time(start))
        : l10n.remindersOnAirNow(reminder.channelName);
    unawaited(
      ref
          .read(reminderSystemNotifierProvider)
          .show(
            title: reminder.title,
            body: body,
            onClick: () => _watch(reminder),
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
