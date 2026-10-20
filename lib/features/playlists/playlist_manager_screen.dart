import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:carina/app/router.dart';
import 'package:carina/core/core.dart';
import 'package:carina/data/db/database.dart' show PlaylistRow;
import 'package:carina/data/import/import.dart';
import 'package:carina/data/repositories/playlist_repository.dart';
import 'package:carina/data/settings/settings_store.dart';
import 'package:carina/features/playlists/data/playlist_actions.dart';
import 'package:carina/features/playlists/data/playlists_navigation.dart';
import 'package:carina/features/playlists/playlist_access.dart';
import 'package:carina/features/playlists/widgets/manager_rail.dart';
import 'package:carina/features/playlists/widgets/playlist_avatar_tile.dart';
import 'package:carina/features/playlists/widgets/playlists_chrome.dart';
import 'package:carina/l10n/gen/app_localizations.dart';

/// The start screen: a full black profile picker with a slim
/// left icon rail (Add playlist, Downloads, Settings, About) and the
/// playlists as large circular avatars, centered and wrapping.
///
/// Click / Enter opens a playlist (access PIN first when set); right-click,
/// long-press, the ••• button or the Menu key opens the playlist menu;
/// arrow keys move between avatars; Ctrl/⌘+N adds a playlist.
///
/// [openPlaylistId] — or the router's `extra: {'open': pid}` that the
/// shell's "Switch playlist" menu passes — opens that playlist right away.
class PlaylistManagerScreen extends ConsumerStatefulWidget {
  const PlaylistManagerScreen({super.key, this.openPlaylistId});

  final int? openPlaylistId;

  @override
  ConsumerState<PlaylistManagerScreen> createState() =>
      _PlaylistManagerScreenState();
}

class _PlaylistManagerScreenState extends ConsumerState<PlaylistManagerScreen> {
  static const double _railWidth = 68;
  static const double _railMargin = 12;

  /// Height of the window-drag strip of [PlaylistsWindowFrame].
  static const double _dragStrip = 44;

  /// The playlist whose menu is open (its avatar stays lit).
  int? _menuFor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _onShown());
  }

  /// The Manager locks every playlist again, then honours an open request.
  void _onShown() {
    if (!mounted) return;
    ref.read(playlistAccessSessionProvider.notifier).clear();
    final pid = widget.openPlaylistId ?? _routerOpenRequest();
    if (pid != null) unawaited(openPlaylist(context, playlistId: pid));
  }

  int? _routerOpenRequest() {
    final extra = maybeGoRouterState(context)?.extra;
    if (extra is Map && extra['open'] is int) return extra['open'] as int;
    return null;
  }

  void _addPlaylist() => GoRouter.of(context).go(Routes.newPlaylist);

  Future<void> _openMenu(PlaylistRow row, Offset position) async {
    setState(() => _menuFor = row.id);
    await showPlaylistMenu(
      context,
      playlist: row,
      position: position,
      onClosed: () {
        if (mounted) setState(() => _menuFor = null);
      },
    );
    if (mounted && _menuFor != null) setState(() => _menuFor = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final playlists = ref.watch(playlistsProvider);
    final router = GoRouter.of(context);
    final topInset = macTitleBarInset();

    final Widget content = playlists.when(
      data: (rows) => rows.isEmpty
          ? _EmptyManager(onAdd: _addPlaylist)
          : _AvatarGrid(
              playlists: rows,
              onOpen: (row) => openPlaylist(context, playlistId: row.id),
              menuFor: _menuFor,
              onMenu: _openMenu,
            ),
      loading: () => const KLoadingState(),
      error: (error, _) => KErrorState(
        message: l10n.playlistsLoadError,
        onRetry: () => ref.invalidate(playlistsProvider),
      ),
    );

    return PlaylistsWindowFrame(
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyN, control: true):
              _addPlaylist,
          const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
              _addPlaylist,
        },
        child: FocusTraversalGroup(
          child: Stack(
            children: [
              // The grid scrolls, which would swallow the window-drag strip:
              // keep it below the strip.
              Positioned.fill(
                left: _railMargin + _railWidth,
                top: _dragStrip,
                child: content,
              ),
              Positioned(
                left: _railMargin,
                top: _railMargin + topInset,
                bottom: _railMargin,
                child: ManagerRail(
                  collapsedWidth: _railWidth,
                  title: l10n.appName,
                  items: [
                    ManagerRailItem(
                      key: const ValueKey('rail-add'),
                      icon: PhosphorIconsLight.plus,
                      label: l10n.playlistsAddPlaylist,
                      onTap: _addPlaylist,
                    ),
                    ManagerRailItem(
                      key: const ValueKey('rail-downloads'),
                      icon: PhosphorIconsLight.downloadSimple,
                      label: l10n.playlistsDownloads,
                      onTap: () => router.push(Routes.downloads),
                    ),
                    ManagerRailItem(
                      key: const ValueKey('rail-settings'),
                      icon: PhosphorIconsLight.gearSix,
                      label: l10n.playlistsSettings,
                      onTap: () => router.push(Routes.appSettings()),
                    ),
                    ManagerRailItem(
                      key: const ValueKey('rail-about'),
                      icon: PhosphorIconsLight.info,
                      label: l10n.playlistsAbout,
                      onTap: () => router.push(Routes.appSettings('about')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The avatars, centered and wrapping (scrolls when there are many).
class _AvatarGrid extends ConsumerWidget {
  const _AvatarGrid({
    required this.playlists,
    required this.onOpen,
    required this.onMenu,
    this.menuFor,
  });

  final List<PlaylistRow> playlists;
  final int? menuFor;
  final ValueChanged<PlaylistRow> onOpen;
  final void Function(PlaylistRow playlist, Offset position) onMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = ref.readSetting(AppSettings.lastPlaylistId);
    final focusId = playlists.any((p) => p.id == last)
        ? last
        : playlists.first.id;
    return LayoutBuilder(
      builder: (context, constraints) {
        final avatarSize = constraints.maxHeight < 560 ? 116.0 : 140.0;
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 56),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - 112).clamp(0, 1e6),
            ),
            child: Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 36,
                runSpacing: 44,
                children: [
                  for (final playlist in playlists)
                    _ManagedTile(
                      key: ValueKey('playlist-${playlist.id}'),
                      playlist: playlist,
                      autofocus: playlist.id == focusId,
                      avatarSize: avatarSize,
                      active: playlist.id == menuFor,
                      onOpen: () => onOpen(playlist),
                      onMenu: (position) => onMenu(playlist, position),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ManagedTile extends ConsumerWidget {
  const _ManagedTile({
    super.key,
    required this.playlist,
    required this.autofocus,
    required this.avatarSize,
    required this.onOpen,
    required this.onMenu,
    this.active = false,
  });

  final PlaylistRow playlist;
  final bool autofocus;
  final double avatarSize;
  final bool active;
  final VoidCallback onOpen;
  final ValueChanged<Offset> onMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(importProgressProvider(playlist.id)).value;
    return PlaylistAvatarTile(
      playlist: playlist,
      autofocus: autofocus,
      avatarSize: avatarSize,
      active: active,
      updateProgress: progress == null || progress.done
          ? null
          : progress.fraction,
      onOpen: onOpen,
      onMenu: onMenu,
    );
  }
}

/// "Add your first playlist" with the big red button, which has the
/// keyboard focus (the [KEmptyState] layout).
class _EmptyManager extends StatelessWidget {
  const _EmptyManager({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.playlistsEmptyTitle,
                textAlign: TextAlign.center,
                style: KText.largeTitle,
              ),
              const SizedBox(height: 10),
              Text(
                l10n.playlistsEmptyMessage,
                textAlign: TextAlign.center,
                style: KText.bodySecondary.copyWith(fontSize: 17),
              ),
              const SizedBox(height: 28),
              KButton.accent(
                key: const ValueKey('manager-add-playlist'),
                label: l10n.playlistsAddPlaylist,
                icon: PhosphorIconsBold.plus,
                onPressed: onAdd,
                size: KButtonSize.large,
                minWidth: 220,
                autofocus: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
