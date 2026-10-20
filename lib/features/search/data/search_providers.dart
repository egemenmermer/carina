import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/clock.dart';
import '../../../data/repositories/epg_repository.dart';
import '../../../data/repositories/reminders_repository.dart';
import '../../../data/repositories/repository_models.dart';

/// Separator of the EPG keys packed into [searchNowNextProvider]'s
/// argument (family arguments need value equality, lists have none).
const String searchKeySeparator = '\n';

/// Now / next programme of every EPG key of the visible channel results
/// (`EpgRepository.nowNext`, one statement for all keys). Re-runs every
/// minute, so the channel cards follow programme changes while the page is
/// open. [keys] are joined with [searchKeySeparator].
final searchNowNextProvider = FutureProvider.autoDispose
    .family<Map<String, NowNext>, ({int playlistId, String keys})>((ref, a) {
      final now = currentMinute(ref);
      final keys = a.keys.isEmpty
          ? const <String>[]
          : a.keys.split(searchKeySeparator);
      if (keys.isEmpty) return Future.value(const <String, NowNext>{});
      return ref
          .watch(epgRepositoryProvider)
          .nowNext(a.playlistId, keys, at: now.toUtc());
    });

/// Reminder keys (`channelId@startMs`) of a playlist, for the bells of the
/// programme results.
final searchReminderKeysProvider = Provider.autoDispose
    .family<Set<String>, int>((ref, playlistId) {
      final reminders = ref.watch(remindersProvider(playlistId)).value;
      if (reminders == null) return const {};
      return {for (final r in reminders) reminderKey(r.channelId, r.start)};
    });

/// Key of a reminder in [searchReminderKeysProvider].
String reminderKey(String channelId, int startMs) => '$channelId@$startMs';
