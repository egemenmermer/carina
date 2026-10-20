/// The Mini TV Guide inside the live player.
///
/// TV Guide owns the real widget, documented as
/// `MiniGuideOverlay(playlistId:, currentChannelId:, onTune:, onClose:)` in
/// `lib/features/guide/guide_api.dart`. Until it is merged the player uses
/// [PlayerMiniGuide] (same inputs). Merge: make [buildMiniGuideOverlay]
/// return `MiniGuideOverlay(playlistId: playlistId, currentChannelId:
/// currentChannelId, onTune: onTune, onClose: onClose)` and delete
/// `player_mini_guide.dart`.
library;

import 'package:flutter/widgets.dart';

import '../../../features/guide/guide_api.dart';

Widget buildMiniGuideOverlay({
  required int playlistId,
  required String currentChannelId,
  required ValueChanged<String> onTune,
  required VoidCallback onClose,
  String? categoryId,
}) => KeyedSubtree(
  key: const ValueKey('player-mini-guide'),
  child: MiniGuideOverlay(
    playlistId: playlistId,
    currentChannelId: currentChannelId,
    categoryId: categoryId,
    onTune: onTune,
    onClose: onClose,
  ),
);
