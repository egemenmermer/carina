/// The Playlist Manager's playlist menu actions: avatar,
/// details, force reload (content + EPG, or EPG only), access PIN, edit,
/// playlist settings and remove.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:carina/app/router.dart';
import 'package:carina/core/core.dart';
import 'package:carina/data/db/database.dart' show PlaylistRow;
import 'package:carina/data/import/import.dart';
import 'package:carina/data/repositories/playlist_repository.dart';
import 'package:carina/features/playlists/data/playlists_navigation.dart';
import 'package:carina/features/playlists/playlist_access.dart';
import 'package:carina/features/playlists/widgets/playlist_details_sheet.dart';
import 'package:carina/features/playlists/widgets/playlist_dialog.dart';
import 'package:carina/l10n/gen/app_localizations.dart';

/// Entries of the playlist menu.
enum PlaylistMenuAction {
  chooseAvatar,
  details,
  forceReload,
  accessPin,
  forceReloadEpg,
  edit,
  openSettings,
  remove,
}

/// The menu entries for [row] (the PIN entry reads "Remove PIN" when the
/// playlist has one).
List<KMenuEntry<PlaylistMenuAction>> playlistMenuEntries(
  L10n l10n,
  PlaylistRow row,
) => [
  KMenuEntry(
    label: l10n.playlistsMenuChooseAvatar,
    icon: PhosphorIconsLight.userCircle,
    value: PlaylistMenuAction.chooseAvatar,
  ),
  KMenuEntry(
    label: l10n.playlistsMenuDetails,
    icon: PhosphorIconsLight.info,
    value: PlaylistMenuAction.details,
  ),
  KMenuEntry(
    label: l10n.playlistsMenuForceReload,
    icon: PhosphorIconsLight.arrowClockwise,
    value: PlaylistMenuAction.forceReload,
  ),
  KMenuEntry(
    label: row.hasAccessPin
        ? l10n.playlistsMenuRemovePin
        : l10n.playlistsMenuSetPin,
    icon: row.hasAccessPin
        ? PhosphorIconsLight.lockSimpleOpen
        : PhosphorIconsLight.lockSimple,
    value: PlaylistMenuAction.accessPin,
  ),
  KMenuEntry(
    label: l10n.playlistsMenuForceReloadEpg,
    icon: PhosphorIconsLight.calendarDots,
    value: PlaylistMenuAction.forceReloadEpg,
  ),
  KMenuEntry(
    label: l10n.playlistsMenuEdit,
    icon: PhosphorIconsLight.pencilSimple,
    value: PlaylistMenuAction.edit,
  ),
  KMenuEntry(
    label: l10n.playlistsMenuOpenSettings,
    icon: PhosphorIconsLight.gearSix,
    value: PlaylistMenuAction.openSettings,
  ),
  KMenuEntry(
    label: l10n.playlistsMenuRemove,
    icon: PhosphorIconsLight.trash,
    value: PlaylistMenuAction.remove,
    destructive: true,
  ),
];

/// Opens the playlist menu titled with the playlist name at [position] and
/// runs the chosen action.
Future<void> showPlaylistMenu(
  BuildContext context, {
  required PlaylistRow playlist,
  required Offset position,
  VoidCallback? onClosed,
}) async {
  final action = await showKContextMenu<PlaylistMenuAction>(
    context,
    position: position,
    title: playlist.name,
    entries: playlistMenuEntries(L10n.of(context), playlist),
    iconPosition: KMenuIconPosition.leading,
    separators: false,
    width: 300,
  );
  onClosed?.call();
  if (action == null || !context.mounted) return;
  await runPlaylistAction(context, action, playlist.id);
}

/// Runs one menu action. Actions that reveal or change the source (details,
/// edit, settings, remove, removing the PIN) ask for the access PIN first.
Future<void> runPlaylistAction(
  BuildContext context,
  PlaylistMenuAction action,
  int playlistId,
) async {
  final router = GoRouter.of(context);
  final container = ProviderScope.containerOf(context, listen: false);
  switch (action) {
    case PlaylistMenuAction.chooseAvatar:
      router.go(Routes.avatar(playlistId));
    case PlaylistMenuAction.details:
      if (!await ensurePlaylistUnlocked(context, playlistId: playlistId)) {
        return;
      }
      if (!context.mounted) return;
      await showPlaylistDetailsSheet(context, playlistId);
    case PlaylistMenuAction.forceReload:
      router.go(importLocation(playlistId));
    case PlaylistMenuAction.forceReloadEpg:
      await _forceReloadEpg(context, playlistId);
    case PlaylistMenuAction.accessPin:
      final row = await container
          .read(playlistRepositoryProvider)
          .get(playlistId);
      if (row == null || !context.mounted) return;
      if (row.hasAccessPin) {
        await removeAccessPin(context, row);
      } else {
        await setAccessPin(context, row);
      }
    case PlaylistMenuAction.edit:
      if (!await ensurePlaylistUnlocked(context, playlistId: playlistId)) {
        return;
      }
      router.go(Routes.editPlaylist(playlistId));
    case PlaylistMenuAction.openSettings:
      if (!context.mounted) return;
      await openPlaylist(
        context,
        playlistId: playlistId,
        location: Routes.playlistSettings(playlistId),
      );
    case PlaylistMenuAction.remove:
      await removePlaylist(context, playlistId);
  }
}

Future<void> _forceReloadEpg(BuildContext context, int playlistId) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final url = await container
      .read(playlistRepositoryProvider)
      .epgUrlFor(playlistId);
  if (!context.mounted) return;
  if (url != null && url.trim().isNotEmpty) {
    GoRouter.of(context).go(importLocation(playlistId, scope: ImportScope.epg));
    return;
  }
  final l10n = L10n.of(context);
  final edit = await showPlaylistDialog<bool>(
    context,
    title: l10n.playlistsNoGuideTitle,
    message: l10n.playlistsNoGuideMessage,
    icon: PhosphorIconsLight.calendarDots,
    actions: [
      PlaylistDialogAction(label: l10n.ok, value: false),
      PlaylistDialogAction(label: l10n.playlistsEditPlaylist, value: true),
    ],
  );
  if (edit != true || !context.mounted) return;
  await runPlaylistAction(context, PlaylistMenuAction.edit, playlistId);
}

/// "Set Playlist Access PIN": enter a 4-digit PIN twice.
Future<void> setAccessPin(BuildContext context, PlaylistRow row) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final l10n = L10n.of(context);
  final first = await showPinPad(
    context,
    title: l10n.playlistsPinSetTitle,
    subtitle: l10n.playlistsPinSetSubtitle(row.name),
  );
  if (first == null || !context.mounted) return;
  final second = await showPinPad(
    context,
    title: l10n.playlistsPinConfirmTitle,
    subtitle: l10n.playlistsPinSetSubtitle(row.name),
    validate: (pin) async => pin == first,
  );
  if (second == null) return;
  await container.read(playlistRepositoryProvider).setAccessPin(row.id, first);
  container.read(toastControllerProvider).show(l10n.playlistsPinSet);
}

/// "Remove PIN": asks for the current PIN, then removes it.
Future<void> removeAccessPin(BuildContext context, PlaylistRow row) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final l10n = L10n.of(context);
  final ok = await ensurePlaylistUnlocked(
    context,
    playlistId: row.id,
    force: true,
  );
  if (!ok) return;
  await container.read(playlistRepositoryProvider).removeAccessPin(row.id);
  container.read(toastControllerProvider).show(l10n.playlistsPinRemoved);
}

/// "Remove": PIN (when set), a confirmation, then the playlist and
/// everything that belongs to it are deleted. A running import is
/// cancelled first.
Future<void> removePlaylist(BuildContext context, int playlistId) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final repository = container.read(playlistRepositoryProvider);
  final row = await repository.get(playlistId);
  if (row == null || !context.mounted) return;
  if (!await ensurePlaylistUnlocked(context, playlistId: playlistId)) return;
  if (!context.mounted) return;
  final l10n = L10n.of(context);
  final confirmed = await showPlaylistDialog<bool>(
    context,
    title: l10n.playlistsRemoveTitle(row.name),
    message: l10n.playlistsRemoveMessage,
    icon: PhosphorIconsLight.trash,
    iconColor: KButton.destructiveForeground,
    autofocusIndex: 1,
    actions: [
      PlaylistDialogAction(
        label: l10n.playlistsMenuRemove,
        value: true,
        destructive: true,
      ),
      PlaylistDialogAction(label: l10n.cancel, value: false),
    ],
  );
  if (confirmed != true) return;
  final imports = container.read(importServiceProvider);
  if (imports.isRunning(playlistId)) {
    imports.cancel(playlistId);
    await waitForImportIdle(imports, playlistId);
  }
  await repository.delete(playlistId);
  container.read(playlistAccessSessionProvider.notifier).lock(playlistId);
  container.read(toastControllerProvider).show(l10n.playlistsRemoved);
}

/// Completes once no import of [playlistId] runs (or after [timeout]).
Future<void> waitForImportIdle(
  ImportService imports,
  int playlistId, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  if (!imports.isRunning(playlistId)) return;
  try {
    await imports
        .watch(playlistId)
        .firstWhere((progress) => progress == null || progress.done)
        .timeout(timeout);
    // The terminal snapshot is followed by null once the run is removed.
    if (imports.isRunning(playlistId)) {
      await imports
          .watch(playlistId)
          .firstWhere((progress) => progress == null)
          .timeout(timeout);
    }
  } on TimeoutException {
    // Give up waiting; the caller proceeds.
  }
}
