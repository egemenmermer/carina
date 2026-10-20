import 'package:flutter/widgets.dart';

import 'src/archive_sheet.dart';
import 'src/guide_overlay.dart';
import 'src/mini_guide_overlay.dart';
import 'src/programme_details_sheet.dart';

/// Cross-feature entry points owned by TV Guide (`lib/features/guide/`).

/// Programme details modal (title, time, duration, description, category,
/// episode, channel; Watch live / Play from start / Remind me).
///
/// By default Watch live / Play from start open the player; pass
/// [onWatchLive] / [onPlayFromStart] to handle them yourself (called after
/// the sheet closed), e.g. to tune a player that is already open.
Future<void> showProgrammeDetails(
  BuildContext context, {
  required int playlistId,
  required String channelId,
  required DateTime startUtc,
  VoidCallback? onWatchLive,
  void Function(DateTime startUtc, DateTime endUtc)? onPlayFromStart,
}) => openProgrammeDetailsSheet(
  context,
  playlistId: playlistId,
  channelId: channelId,
  startUtc: startUtc,
  onWatchLive: onWatchLive,
  onPlayFromStart: onPlayFromStart,
);

/// The "TV ARCHIVE • CATCH-UP" sheet for a channel. A row opens the
/// catch-up player, or calls [onPlay] (with the programme's start, end and
/// title) when given.
Future<void> showArchiveSheet(
  BuildContext context, {
  required int playlistId,
  required String channelId,
  void Function(DateTime startUtc, DateTime endUtc, String title)? onPlay,
}) => openArchiveSheet(
  context,
  playlistId: playlistId,
  channelId: channelId,
  onPlay: onPlay == null ? null : (p) => onPlay(p.start, p.stop, p.title),
);

/// The guide grid as an overlay inside the live player ("Full TV Guide").
/// [onTune] is called with a channel id when the user picks a programme
/// that is on air; past archive programmes call [onCatchup] (falls back to
/// [onTune]); upcoming ones open the programme details. Esc or the × call
/// [onClose]. The caller dims the video behind it.
class GuideOverlay extends StatelessWidget {
  const GuideOverlay({
    super.key,
    required this.playlistId,
    required this.currentChannelId,
    required this.onTune,
    required this.onClose,
    this.onCatchup,
  });

  final int playlistId;
  final String currentChannelId;
  final ValueChanged<String> onTune;
  final VoidCallback onClose;
  final void Function(String channelId, DateTime startUtc, DateTime endUtc)?
  onCatchup;

  @override
  Widget build(BuildContext context) => GuideOverlayView(
    playlistId: playlistId,
    currentChannelId: currentChannelId,
    onTune: onTune,
    onClose: onClose,
    onCatchup: onCatchup,
  );
}

/// The live player's Mini TV Guide: a left column of channel cards of the
/// current category (logo, name, now/next, progress) with a red marker on
/// [currentChannelId], the video visible on the right. ↑/↓ choose, Enter
/// (or a click) calls [onTune], ←/→ cycle the provider categories, Esc
/// calls [onClose]. [categoryId] picks the starting category (default: the
/// active live category when it holds the channel, else its own).
class MiniGuideOverlay extends StatelessWidget {
  const MiniGuideOverlay({
    super.key,
    required this.playlistId,
    required this.currentChannelId,
    required this.onTune,
    required this.onClose,
    this.categoryId,
  });

  final int playlistId;
  final String currentChannelId;
  final ValueChanged<String> onTune;
  final VoidCallback onClose;
  final String? categoryId;

  @override
  Widget build(BuildContext context) => MiniGuideView(
    playlistId: playlistId,
    currentChannelId: currentChannelId,
    onTune: onTune,
    onClose: onClose,
    categoryId: categoryId,
  );
}
