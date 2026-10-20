import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart' show Routes;
import '../../core/core.dart';
import '../../data/repositories/live_repository.dart';
import '../../data/repositories/playlist_repository.dart';
import '../../data/repositories/repository_models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../parental/parental_api.dart';
import 'multiview_layout.dart';
import 'multiview_screen.dart';
import 'multiview_state.dart';

export 'multiview_layout.dart' show MultiviewLayout;

/// Multi-channel (P2). Owner: `lib/features/multiview/`.

/// Adds a channel to the multi-channel screen and shows it (opens it when
/// closed).
///
/// * A channel that is already open gets the focus (and the audio).
/// * Before the 3rd and 4th stream the user confirms the connection-limit
///   warning (with the Xtream `max_connections`); a 5th shows a toast.
/// * [layout] (capture mode, "open as 2×2"): the session is rebuilt in that
///   layout with [channelId] as the main tile and the free slots filled
///   with the next channels of its category — no warning, the caller asked
///   for it explicitly.
/// * [pickAnother] (live player "Add channel"): the screen opens its
///   channel picker so a second channel can be chosen right away.
Future<void> addToMultiview(
  BuildContext context, {
  required int playlistId,
  required String channelId,
  MultiviewLayout? layout,
  bool pickAnother = false,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final notifier = container.read(
    multiviewSessionProvider(playlistId).notifier,
  );
  final toasts = container.read(toastControllerProvider);
  final l10n = L10n.of(context);

  final unlocked = await ensureChannelUnlocked(
    context,
    playlistId: playlistId,
    channelId: channelId,
  );
  if (!unlocked || !context.mounted) return;

  if (layout != null) {
    final ids = await multiviewFillChannels(
      container.read(liveRepositoryProvider),
      playlistId,
      channelId,
      layout.slots,
    );
    notifier.replace(ids, layout: layout);
  } else {
    final session = container.read(multiviewSessionProvider(playlistId));
    if (session.contains(channelId)) {
      notifier.add(channelId);
    } else if (session.isFull) {
      toasts.show(l10n.multiviewMaxReached);
    } else {
      if (session.tiles.length >= 2) {
        final ok = await confirmExtraStream(context, playlistId: playlistId);
        if (!ok || !context.mounted) return;
      }
      notifier.add(channelId);
      toasts.show(l10n.multiviewAdded);
    }
  }
  if (pickAnother) notifier.requestPicker(true);
  if (!context.mounted) return;
  showMultiview(context, playlistId);
}

/// Shows the multi-channel route (`/p/:pid/multiview`), or pushes the
/// screen on the root navigator when there is no router (tests, tools).
void showMultiview(BuildContext context, int playlistId) {
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    router.go(Routes.multiview(playlistId));
    return;
  }
  final navigator = Navigator.of(context, rootNavigator: true);
  var onTop = false;
  navigator.popUntil((route) {
    onTop = route.settings.name == kMultiviewRouteName;
    return true;
  });
  if (onTop) return;
  navigator.push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: kMultiviewRouteName),
      builder: (_) => MultiviewScreen(playlistId: playlistId),
    ),
  );
}

/// Route name of the pushed (router-less) multi-channel screen.
const String kMultiviewRouteName = 'multiview';

/// [channelId] followed by the next channels of its category (wrapping,
/// locked channels skipped), [count] at most.
Future<List<String>> multiviewFillChannels(
  LiveRepository live,
  int playlistId,
  String channelId,
  int count,
) async {
  final channel = await live.channel(playlistId, channelId);
  final categoryId = channel?.row.categoryId;
  final list = await live.channels(
    playlistId,
    categoryId == null ? const AllCategory() : ProviderCategory(categoryId),
  );
  final ids = <String>[channelId];
  final start = list.indexWhere((c) => c.providerId == channelId);
  for (var i = 1; i <= list.length && ids.length < count; i++) {
    final c = list[(start + i) % list.length];
    if (c.locked || !c.playable || ids.contains(c.providerId)) continue;
    ids.add(c.providerId);
  }
  return ids;
}

/// The connection-limit warning before a 3rd / 4th stream. True when the
/// user chose to open it anyway.
Future<bool> confirmExtraStream(
  BuildContext context, {
  required int playlistId,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final playlists = container.read(playlistRepositoryProvider);
  final row = await playlists.get(playlistId);
  final max = row == null ? null : playlists.account(row)?.maxConnections;
  if (!context.mounted) return false;
  final l10n = L10n.of(context);
  final result = await showChooser<bool>(
    context,
    title: l10n.multiviewWarnTitle,
    description: max == null || max <= 0
        ? l10n.multiviewWarnMessageUnknown
        : l10n.multiviewWarnMessage(max),
    choices: [KChoice(value: true, label: l10n.multiviewOpenAnyway)],
  );
  return result ?? false;
}
