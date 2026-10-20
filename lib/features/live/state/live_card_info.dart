import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/time_format.dart';
import '../../../data/repositories/repository_models.dart';
import 'live_providers.dart';

/// The programme lines of a channel card.
@immutable
class LiveCardInfo {
  const LiveCardInfo({
    required this.title,
    required this.time,
    required this.progress,
    required this.hasEpg,
  });

  /// Programme title, or "EPG not available".
  final String title;

  /// `3:15 PM – 4:15 PM`.
  final String time;

  /// 0–1.
  final double progress;
  final bool hasEpg;
}

/// Card lines for the programme on air. Without a programme the card shows
/// the current hour as its slot with [noEpgLabel].
LiveCardInfo liveCardInfo({
  required ProgrammeView? programme,
  required DateTime now,
  required CarinaTimeFormat format,
  required String noEpgLabel,
}) {
  if (programme != null) {
    return LiveCardInfo(
      title: programme.title,
      time: format.range(programme.start, programme.stop),
      progress: programme.progressAt(now),
      hasEpg: true,
    );
  }
  final local = now.toLocal();
  final start = DateTime(local.year, local.month, local.day, local.hour);
  return LiveCardInfo(
    title: noEpgLabel,
    time: format.range(start, start.add(const Duration(hours: 1))),
    progress: (local.minute * 60 + local.second) / 3600,
    hasEpg: false,
  );
}

/// The now/next of [channel] for a card: the batched list lookup
/// ([listNowNext], null while it loads) and, for Xtream channels the stored
/// guide does not cover, the short-EPG fallback.
NowNext watchCardNowNext(
  WidgetRef ref, {
  required int playlistId,
  required ChannelView channel,
  required Map<String, NowNext>? listNowNext,
  required bool xtream,
}) {
  final key = channel.epgKey;
  final stored = key == null ? null : listNowNext?[key];
  if (stored != null && !stored.isEmpty) return stored;
  if (listNowNext == null || !xtream) return stored ?? NowNext.empty;
  return ref
          .watch(
            liveChannelNowNextProvider((
              playlistId: playlistId,
              channel: channel,
            )),
          )
          .value ??
      NowNext.empty;
}
