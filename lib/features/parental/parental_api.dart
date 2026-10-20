import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/live_repository.dart';
import '../../data/repositories/parental_service.dart';
import 'parental_pin_flows.dart';

/// Parental control gate for channels. Owner: `lib/features/parental/`.

/// Resolves true when the channel (or its category) is not locked, already
/// unlocked for this session, or the user entered the correct PIN.
///
/// A locked channel asks for the parental PIN on the numeric pad (keyboard
/// digits work); when the playlist has no PIN yet, the user creates one
/// first. A correct PIN unlocks the channel — and its category when the
/// lock comes from there — until the app restarts or the playlist is
/// switched (`parentalSessionProvider`). Unknown channels are not locked.
Future<bool> ensureChannelUnlocked(
  BuildContext context, {
  required int playlistId,
  required String channelId,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final channel = await container
      .read(liveRepositoryProvider)
      .channel(playlistId, channelId);
  if (channel == null) return true;
  final service = container.read(parentalServiceProvider);
  if (!service.isLocked(channel, container.read(parentalSessionProvider))) {
    return true;
  }
  if (!context.mounted) return false;
  final unlocked = await requestParentalPin(
    context,
    playlistId: playlistId,
    subject: channel.displayName,
  );
  if (!unlocked) return false;
  container.read(parentalSessionProvider.notifier).unlockFor(channel);
  return true;
}
