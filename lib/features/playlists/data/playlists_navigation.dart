/// Navigation helpers and session state shared by the Playlists screens.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:carina/app/router.dart';
import 'package:carina/data/import/import.dart' show ImportScope;

/// `/playlists/<pid>/import`, with `?scope=content|epg` unless [scope] is
/// [ImportScope.all].
String importLocation(int playlistId, {ImportScope scope = ImportScope.all}) {
  final base = Routes.importPlaylist(playlistId);
  return scope == ImportScope.all ? base : '$base?scope=${scope.name}';
}

/// The scope named by a `scope` query value (`all` when missing or unknown).
ImportScope importScopeFromQuery(String? value) =>
    ImportScope.values.asNameMap()[value] ?? ImportScope.all;

/// The current [GoRouterState], or null outside a go_router page (widget
/// tests and galleries that pump a screen on its own).
GoRouterState? maybeGoRouterState(BuildContext context) {
  if (GoRouter.maybeOf(context) == null) return null;
  try {
    return GoRouterState.of(context);
  } on GoError {
    return null;
  }
}

/// Goes to the Playlist Manager (outside go_router: pops the page).
void leaveToManager(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router == null) {
    Navigator.of(context).maybePop();
  } else {
    router.go(Routes.manager);
  }
}

/// Leaves a Playlists sub-screen: back to the page below when it was pushed
/// (e.g. "Edit source" from the playlist settings), else to the Playlist
/// Manager.
void goBackFromPlaylists(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router != null && router.canPop()) {
    router.pop();
  } else {
    leaveToManager(context);
  }
}

/// Playlists whose access PIN was entered since the Playlist Manager was
/// last shown. The Manager clears it whenever it appears, so a playlist is
/// locked again as soon as the user is back on the start screen; within
/// one flow (Edit → Save → import → open) the PIN is asked only once.
class PlaylistAccessSession extends Notifier<Set<int>> {
  @override
  Set<int> build() => const {};

  bool isUnlocked(int playlistId) => state.contains(playlistId);

  void unlock(int playlistId) {
    if (!state.contains(playlistId)) state = {...state, playlistId};
  }

  void lock(int playlistId) {
    if (state.contains(playlistId)) {
      state = {...state}..remove(playlistId);
    }
  }

  void clear() {
    if (state.isNotEmpty) state = const {};
  }
}

/// See [PlaylistAccessSession].
final playlistAccessSessionProvider =
    NotifierProvider<PlaylistAccessSession, Set<int>>(
      PlaylistAccessSession.new,
    );
