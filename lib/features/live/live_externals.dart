import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart' show ItemType;
import '../../player/player_api.dart' as player_api;
import '../favorites/favorites_api.dart' as favorites_api;
import '../guide/guide_api.dart' as guide_api;
import '../multiview/multiview_api.dart' as multiview_api;
import '../parental/parental_api.dart' as parental_api;
import '../reminders/reminders_api.dart' as reminders_api;

/// The other teams' entry points TV Live calls (ARCHITECTURE 8.2), behind
/// one object so widget tests can record the calls instead of opening other
/// screens. Production code always uses the default implementation.
class LiveExternals {
  const LiveExternals();

  /// Full-screen playback (returns when the player closes).
  Future<void> openPlayer(
    BuildContext context,
    player_api.PlayRequest request,
  ) => player_api.openPlayer(context, request);

  /// Parental PIN gate for a locked channel.
  Future<bool> ensureChannelUnlocked(
    BuildContext context, {
    required int playlistId,
    required String channelId,
  }) => parental_api.ensureChannelUnlocked(
    context,
    playlistId: playlistId,
    channelId: channelId,
  );

  /// Sets or clears a reminder (shows its own toast).
  Future<void> toggleReminder(
    BuildContext context, {
    required int playlistId,
    required String channelId,
    required DateTime startUtc,
  }) => reminders_api.toggleReminder(
    context,
    playlistId: playlistId,
    channelId: channelId,
    startUtc: startUtc,
  );

  Future<void> showProgrammeDetails(
    BuildContext context, {
    required int playlistId,
    required String channelId,
    required DateTime startUtc,
  }) => guide_api.showProgrammeDetails(
    context,
    playlistId: playlistId,
    channelId: channelId,
    startUtc: startUtc,
  );

  Future<void> showArchiveSheet(
    BuildContext context, {
    required int playlistId,
    required String channelId,
  }) => guide_api.showArchiveSheet(
    context,
    playlistId: playlistId,
    channelId: channelId,
  );

  Future<void> showFavoriteTagsSheet(
    BuildContext context, {
    required int playlistId,
    required String providerId,
    required String title,
  }) => favorites_api.showFavoriteTagsSheet(
    context,
    playlistId: playlistId,
    type: ItemType.channel,
    providerId: providerId,
    title: title,
  );

  Future<void> addToMultiview(
    BuildContext context, {
    required int playlistId,
    required String channelId,
  }) => multiview_api.addToMultiview(
    context,
    playlistId: playlistId,
    channelId: channelId,
  );
}

/// Overridden in widget tests with a recording [LiveExternals].
final liveExternalsProvider = Provider<LiveExternals>(
  (ref) => const LiveExternals(),
);
