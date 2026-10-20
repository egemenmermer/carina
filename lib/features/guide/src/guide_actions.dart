/// What the guide does when the user activates something: open the player
/// (which runs the parental gate) or the channel actions. One
/// object behind a provider so tests can record the calls instead of
/// opening routes owned by other teams.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../player/player_api.dart' as player;
import '../../live/live_api.dart' as live;
import 'guide_cells.dart';
import 'guide_controller.dart';

/// The guide's outgoing calls. Override [guideActionsProvider] in tests.
class GuideActions {
  const GuideActions();

  Future<void> openPlayer(BuildContext context, player.PlayRequest request) =>
      player.openPlayer(context, request);

  Future<void> showChannelActions(
    BuildContext context, {
    required int playlistId,
    required String channelId,
    required Offset position,
    String? categoryId,
  }) => live.showChannelActions(
    context,
    playlistId: playlistId,
    channelId: channelId,
    position: position,
    categoryId: categoryId,
  );
}

final guideActionsProvider = Provider<GuideActions>(
  (ref) => const GuideActions(),
);

/// What activating a guide cell does.
enum GuideCellAction {
  /// On air: play the channel.
  watchLive,

  /// Ended and inside the channel's archive: play the catch-up.
  catchup,

  /// Upcoming (or ended without archive): programme details.
  details,

  /// A past "No EPG data" block: nothing to do.
  none,
}

/// Routing of a click / Enter on [target] at [nowMs].
GuideCellAction guideCellAction(GuideFocus target, int nowMs) {
  final cell = target.cell;
  if (cell.isOnAirAt(nowMs)) return GuideCellAction.watchLive;
  final p = cell.programme;
  if (p == null) return GuideCellAction.none;
  if (cell.hasEndedAt(nowMs) &&
      p.isReplayableWith(
        target.channel.archiveDays,
        DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
      )) {
    return GuideCellAction.catchup;
  }
  return GuideCellAction.details;
}

/// `'<channel provider id>@<start ms>'`, the key of a reminder bell.
String reminderKey(String channelId, int startMs) => '$channelId@$startMs';

/// Minutes of [cell] for "(55 min)".
int cellMinutes(GuideCell cell) =>
    ((cell.stopMs - cell.startMs) / kMinuteMs).round();
