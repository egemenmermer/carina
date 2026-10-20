import 'package:flutter/widgets.dart';

import '../data/db/tables.dart';
import 'ui/player_route.dart' as route;

/// An overlay the player opens by itself as soon as the stream started (the
/// `--capture` screenshot mode and tests, which cannot press keys). The
/// controls stay visible while it is open.
enum PlayerInitialOverlay {
  none,

  /// The bottom bar (VOD) or the channel overlay (live), pinned.
  controls,
  audioMenu,
  subtitlesMenu,
  switchPlayerMenu,

  /// VOD: the info panel. Live: the programme info panel.
  infoPanel,

  /// Live: "What do you need to do?".
  actionSheet,
  miniGuide,
  fullGuide,

  /// The hidden technical overlay (Ctrl+Shift+D).
  stats,
}

/// What to play. The player resolves URLs itself (StreamUrlResolver), so
/// callers only pass ids. Owner: player UI (`lib/player/ui/`).
sealed class PlayRequest {
  const PlayRequest({
    required this.playlistId,
    this.initialOverlay = PlayerInitialOverlay.none,
  });

  final int playlistId;

  /// Overlay opened right after the stream starts (see
  /// [PlayerInitialOverlay]).
  final PlayerInitialOverlay initialOverlay;
}

/// A live channel. [zapChannelIds] is the ordered channel list of the
/// current category for ↑/↓ zapping (null: the player loads the channel's
/// category). [categoryId] is the provider category the list came from.
class LivePlayRequest extends PlayRequest {
  const LivePlayRequest({
    required super.playlistId,
    required this.channelId,
    this.zapChannelIds,
    this.categoryId,
    super.initialOverlay,
  });

  final String channelId;
  final List<String>? zapChannelIds;
  final String? categoryId;

  @override
  String toString() => 'LivePlayRequest($playlistId, $channelId)';
}

/// A movie or an episode. [resume]: null = ask (Resume from … / From the
/// beginning) when the item is between 2% and 95% watched; true = resume
/// silently; false = start from the beginning.
class VodPlayRequest extends PlayRequest {
  const VodPlayRequest({
    required super.playlistId,
    required this.type,
    required this.providerId,
    this.seriesId,
    this.resume,
    super.initialOverlay,
  }) : assert(type == ItemType.movie || type == ItemType.episode);

  final ItemType type;
  final String providerId;
  final String? seriesId;
  final bool? resume;

  @override
  String toString() => 'VodPlayRequest($playlistId, ${type.name} $providerId)';
}

/// A past programme from the TV archive (catch-up).
class CatchupPlayRequest extends PlayRequest {
  const CatchupPlayRequest({
    required super.playlistId,
    required this.channelId,
    required this.startUtc,
    required this.endUtc,
    required this.title,
    super.initialOverlay,
  });

  final String channelId;
  final DateTime startUtc;
  final DateTime endUtc;
  final String title;

  @override
  String toString() =>
      'CatchupPlayRequest($playlistId, $channelId, '
      '${startUtc.toIso8601String()})';
}

/// Opens the full-window player on the root navigator. Returns when the
/// player closes.
///
/// Live and catch-up requests pass the parental gate
/// (`ensureChannelUnlocked`) first; a cancelled PIN returns without
/// opening the player.
Future<void> openPlayer(BuildContext context, PlayRequest request) =>
    route.launchPlayer(context, request);
