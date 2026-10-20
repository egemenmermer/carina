import 'package:flutter/widgets.dart';

import '../../data/repositories/repository_models.dart' show CategoryRef;
import 'actions/channel_actions.dart' as actions;
import 'actions/custom_epg_picker.dart' as epg_picker;

/// Cross-feature entry points owned by TV Live (`lib/features/live/`).

/// The channel context menu at [position] (global). Used by TV
/// Live, TV Guide (channel name click), Search and the live player.
///
/// [categoryId] is the provider category the category actions (hide,
/// rename, lock) apply to; null uses the channel's own category.
/// [listCategory] is the list the menu was opened from: inside Last
/// watched the menu offers "Remove from Last watched". Every action that
/// changes state shows a green toast.
Future<void> showChannelActions(
  BuildContext context, {
  required int playlistId,
  required String channelId,
  required Offset position,
  String? categoryId,
  CategoryRef? listCategory,
}) => actions.showChannelActionsMenu(
  context,
  playlistId: playlistId,
  channelId: channelId,
  position: position,
  categoryId: categoryId,
  listCategory: listCategory,
);

/// The searchable Custom EPG picker; resolves to true when the mapping
/// changed.
Future<bool> showCustomEpgPicker(
  BuildContext context, {
  required int playlistId,
  required String channelId,
}) => epg_picker.showCustomEpgPickerSheet(
  context,
  playlistId: playlistId,
  channelId: channelId,
);
