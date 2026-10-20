import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:carina/app/bootstrap.dart' show initialTabLocation;
import 'package:carina/core/core.dart';
import 'package:carina/data/import/import.dart';
import 'package:carina/data/repositories/parental_service.dart';
import 'package:carina/data/repositories/playlist_repository.dart';
import 'package:carina/data/settings/settings_store.dart';
import 'package:carina/l10n/gen/app_localizations.dart';
import 'package:carina/features/playlists/data/playlists_navigation.dart';

/// Playlist access PIN gate. Owner: `lib/features/playlists/`.
///
/// Returns true when [playlistId] has no access PIN, when the PIN was
/// already entered since the Playlist Manager was last shown (see
/// [PlaylistAccessSession]), or when the user enters it on the PIN pad.
/// Returns false when the pad is cancelled or the playlist no longer
/// exists. [force] always asks (e.g. before removing the PIN).
Future<bool> ensurePlaylistUnlocked(
  BuildContext context, {
  required int playlistId,
  bool force = false,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final repository = container.read(playlistRepositoryProvider);
  final row = await repository.get(playlistId);
  if (row == null) return false;
  if (!row.hasAccessPin) return true;
  final session = container.read(playlistAccessSessionProvider.notifier);
  if (!force && session.isUnlocked(playlistId)) return true;
  if (!context.mounted) return false;
  final l10n = L10n.of(context);
  final pin = await showPinPad(
    context,
    title: force ? l10n.playlistsPinCurrentTitle : l10n.playlistsPinEnterTitle,
    subtitle: l10n.playlistsPinProtectedSubtitle(row.name),
    validate: (pin) => repository.verifyAccessPin(playlistId, pin),
  );
  if (pin == null) return false;
  session.unlock(playlistId);
  return true;
}

/// Opens a playlist: access PIN, parental session reset, background reload
/// check, then navigation to its initial tab (Settings → General → Initial
/// tab), or to [location] when given (e.g. the playlist's settings).
Future<void> openPlaylist(
  BuildContext context, {
  required int playlistId,
  String? location,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final row = await container.read(playlistRepositoryProvider).get(playlistId);
  if (!context.mounted) return;
  if (row == null) {
    container
        .read(toastControllerProvider)
        .show(
          L10n.of(context).playlistsNotFound,
          kind: KToastKind.error,
          icon: PhosphorIconsLight.warningCircle,
        );
    return;
  }
  if (!await ensurePlaylistUnlocked(context, playlistId: playlistId)) return;
  if (!context.mounted) return;

  container.read(parentalSessionProvider.notifier).onPlaylistOpened(playlistId);
  final settings = container.read(settingsStoreProvider);
  if (settings.get(AppSettings.lastPlaylistId) != playlistId) {
    unawaited(settings.set(AppSettings.lastPlaylistId, playlistId));
  }
  // Reload in the background when the reload frequency has elapsed; the
  // shell's top-bar chip shows the progress.
  unawaited(
    container.read(reloadSchedulerProvider).checkOnOpen(playlistId).catchError((
      Object error,
    ) {
      debugPrint('Reload check of playlist #$playlistId failed: $error');
      return false;
    }),
  );
  GoRouter.of(context).go(location ?? initialTabLocation(settings, playlistId));
}
