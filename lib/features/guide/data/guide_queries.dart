/// Guide-specific queries on the shared repositories (FEATURE_GUIDE: extra
/// queries live as extensions inside the feature folder).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/clock.dart';
import '../../../data/repositories/epg_repository.dart';
import '../../../data/repositories/live_repository.dart';
import '../../../data/repositories/repository_models.dart';

extension GuideEpgQueries on EpgRepository {
  /// The programme of [channel] that starts exactly at [startUtc]: from the
  /// stored guide, else (Xtream) from the short EPG.
  Future<ProgrammeView?> programmeStartingAt(
    int playlistId,
    ChannelView channel,
    DateTime startUtc,
  ) async {
    final startMs = startUtc.millisecondsSinceEpoch;
    final key = channel.epgKey;
    if (key != null) {
      final list = await programmes(
        playlistId,
        key,
        startUtc,
        startUtc.add(const Duration(minutes: 1)),
      );
      for (final p in list) {
        if (p.startMs == startMs) return p;
      }
    }
    for (final p in await shortEpg(playlistId, channel.row)) {
      if (p.startMs == startMs) return p;
    }
    return null;
  }
}

/// A channel and one of its programmes (null when it is not in the guide
/// any more; the channel is null when it was removed).
typedef ChannelProgramme = ({ChannelView? channel, ProgrammeView? programme});

/// Arguments of [channelProgrammeProvider].
typedef ChannelProgrammeArgs = ({
  int playlistId,
  String channelId,
  int startMs,
});

/// Loads the channel and its programme starting at `startMs`.
final channelProgrammeProvider = FutureProvider.autoDispose
    .family<ChannelProgramme, ChannelProgrammeArgs>((ref, args) async {
      final channel = await ref
          .watch(liveRepositoryProvider)
          .channel(args.playlistId, args.channelId);
      if (channel == null) return (channel: null, programme: null);
      final programme = await ref
          .watch(epgRepositoryProvider)
          .programmeStartingAt(
            args.playlistId,
            channel,
            DateTime.fromMillisecondsSinceEpoch(args.startMs, isUtc: true),
          );
      return (channel: channel, programme: programme);
    });

/// A channel and its TV archive days.
typedef ChannelArchive = ({ChannelView? channel, List<ArchiveDay> days});

/// Arguments of [channelArchiveProvider].
typedef ChannelArchiveArgs = ({int playlistId, String channelId});

/// The TV Archive of a channel at the current minute.
final channelArchiveProvider = FutureProvider.autoDispose
    .family<ChannelArchive, ChannelArchiveArgs>((ref, args) async {
      final now = ref.read(clockSourceProvider)();
      final channel = await ref
          .watch(liveRepositoryProvider)
          .channel(args.playlistId, args.channelId);
      if (channel == null) return (channel: null, days: const <ArchiveDay>[]);
      final days = await ref
          .watch(epgRepositoryProvider)
          .archive(args.playlistId, channel.row, now: now);
      return (channel: channel, days: days);
    });
