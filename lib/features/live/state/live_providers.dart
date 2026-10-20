/// Riverpod providers of TV Live: programme lookups for cards and panels,
/// reminder bells, the guide source line and the remembered selection.
///
/// Every provider here swallows repository errors and returns an empty
/// value: a broken guide must never take the channel list down (and
/// Riverpod 3 would otherwise schedule automatic retries).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/clock.dart';
import '../../../data/db/database.dart';
import '../../../data/repositories/epg_repository.dart';
import '../../../data/repositories/live_repository.dart';
import '../../../data/repositories/playlist_repository.dart';
import '../../../data/repositories/reminders_repository.dart';
import '../../../data/repositories/repository_models.dart';

/// One channel of a playlist (family argument).
typedef LiveChannelArgs = ({int playlistId, ChannelView channel});

/// One channel by id (family argument).
typedef LiveChannelIdArgs = ({int playlistId, String channelId});

/// Re-runs a provider after an EPG reload of [playlistId].
void _watchGuideRevision(Ref ref, int playlistId) {
  ref.watch(
    playlistProvider(playlistId).select((p) => p.value?.lastEpgReloadAt),
  );
}

/// Now/next of every channel of a list from the stored guide, keyed by the
/// channel's EPG key (one batched query; refreshed every minute, after an
/// EPG reload and when the list changes).
final liveListNowNextProvider = FutureProvider.autoDispose
    .family<Map<String, NowNext>, ChannelListArgs>((ref, args) async {
      _watchGuideRevision(ref, args.playlistId);
      final now = currentMinute(ref);
      final channels = await ref.watch(channelsProvider(args).future);
      final keys = <String>[
        for (final c in channels)
          if (c.epgKey != null) c.epgKey!,
      ];
      if (keys.isEmpty) return const {};
      try {
        return await ref
            .read(epgRepositoryProvider)
            .nowNext(args.playlistId, keys, at: now);
      } on Object {
        return const {};
      }
    });

/// Now/next of one channel with the Xtream short-EPG fallback (NOW ON AIR,
/// and cards whose channel has no stored programmes).
final liveChannelNowNextProvider = FutureProvider.autoDispose
    .family<NowNext, LiveChannelArgs>((ref, args) async {
      _watchGuideRevision(ref, args.playlistId);
      final now = currentMinute(ref);
      try {
        return await ref
            .read(epgRepositoryProvider)
            .nowNextForChannel(args.playlistId, args.channel, at: now);
      } on Object {
        return NowNext.empty;
      }
    });

/// UPCOMING: programmes of one channel in the next 24 hours.
final liveUpcomingProvider = FutureProvider.autoDispose
    .family<List<ProgrammeView>, LiveChannelArgs>((ref, args) async {
      _watchGuideRevision(ref, args.playlistId);
      final now = currentMinute(ref);
      try {
        return await ref
            .read(epgRepositoryProvider)
            .upcomingForChannel(args.playlistId, args.channel, at: now);
      } on Object {
        return const [];
      }
    });

/// Programme starts (UTC epoch ms) with a reminder on one channel (bells
/// on UPCOMING rows).
final liveReminderStartsProvider = Provider.autoDispose
    .family<Set<int>, LiveChannelIdArgs>((ref, args) {
      final rows =
          ref.watch(channelRemindersProvider(args)).value ??
          const <ReminderRow>[];
      return {for (final r in rows) r.start};
    });

/// Whether the playlist is an Xtream playlist (short-EPG fallback).
final liveIsXtreamProvider = Provider.autoDispose.family<bool, int>(
  (ref, playlistId) =>
      ref.watch(playlistProvider(playlistId).select((p) => p.value?.type)) ==
      PlaylistType.xtream,
);

/// The host of a guide that does not come from the IPTV server itself
/// ("EPG by epg-guide.com"), or null. Only the host is used: never a path,
/// query or credentials.
final liveEpgSourceProvider = FutureProvider.autoDispose.family<String?, int>((
  ref,
  playlistId,
) async {
  _watchGuideRevision(ref, playlistId);
  final repo = ref.read(playlistRepositoryProvider);
  try {
    final row = await repo.get(playlistId);
    if (row == null) return null;
    final url = await repo.epgUrlFor(playlistId);
    return epgSourceHost(url, server: row.server);
  } on Object {
    return null;
  }
});

/// The host of [epgUrl] when it differs from the host of [server] (the
/// provider's own XMLTV is not credited). Null for a missing or invalid URL.
String? epgSourceHost(String? epgUrl, {String? server}) {
  if (epgUrl == null || epgUrl.trim().isEmpty) return null;
  final host = Uri.tryParse(epgUrl.trim())?.host.toLowerCase() ?? '';
  if (host.isEmpty) return null;
  final serverHost = server == null
      ? ''
      : (Uri.tryParse(server.trim())?.host.toLowerCase() ?? '');
  if (host == serverHost) return null;
  return host.startsWith('www.') ? host.substring(4) : host;
}

/// The last selected channel per category key (`CategoryRef.key`) of a
/// playlist, kept for the app session so TV Live reopens where it was.
final liveLastSelectionProvider =
    NotifierProvider.family<LiveLastSelection, Map<String, String>, int>(
      LiveLastSelection.new,
    );

class LiveLastSelection extends Notifier<Map<String, String>> {
  LiveLastSelection(this.playlistId);

  final int playlistId;

  @override
  Map<String, String> build() => const {};

  void remember(String categoryKey, String channelId) {
    if (state[categoryKey] == channelId) return;
    state = {...state, categoryKey: channelId};
  }
}
