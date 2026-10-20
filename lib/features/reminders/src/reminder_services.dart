/// Side effects of reminders behind providers, so tests can replace them:
/// the OS notification (local_notifier) and the "Watch now" action.
library;

import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_notifier/local_notifier.dart';

import '../../../data/db/database.dart';
import '../../../player/player_api.dart';
import '../../playlists/playlist_access.dart';

/// Shows a system notification (Windows toast / macOS notification).
abstract interface class ReminderSystemNotifier {
  Future<void> show({
    required String title,
    required String body,
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

final reminderSystemNotifierProvider = Provider<ReminderSystemNotifier>(
  (ref) => const LocalReminderNotifier(),
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
