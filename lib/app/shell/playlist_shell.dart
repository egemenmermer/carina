import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/core.dart';
import '../../data/db/database.dart';
import '../../data/settings/settings_store.dart';
import '../../l10n/gen/app_localizations.dart';
import '../clock.dart';
import '../platform/form_factor.dart';
import '../router.dart';
import '../time_format.dart';
import 'category_sidebar.dart';
import 'shell_state.dart';

/// The main shell of an open playlist: top navigation, the red
/// menu FAB and the category sidebar on Movies/Shows/TV Live/TV Guide, and
/// the keyboard shortcuts Ctrl+1…4, Ctrl+F or /, Ctrl+,.
///
/// On TV the remote's Back walks up inside the shell ([shellBackLocation])
/// and focus never rests on an invisible node: when a page leaves nothing
/// focused, the active top-nav tab takes focus.
class PlaylistShell extends ConsumerStatefulWidget {
  const PlaylistShell({
    super.key,
    required this.playlistId,
    required this.location,
    required this.child,
  });

  final int playlistId;
  final String location;
  final Widget child;

  @override
  ConsumerState<PlaylistShell> createState() => _PlaylistShellState();
}

class _PlaylistShellState extends ConsumerState<PlaylistShell> {
  final FocusNode _shortcutFocus = FocusNode(debugLabel: 'shell-shortcuts');

  /// Focus nodes of the top-nav tabs by id (TV focus fallback).
  final Map<String, FocusNode> _tabNodes = {};

  /// Parent of the top nav's focus nodes (key routing only).
  final FocusNode _navFocus = FocusNode(
    debugLabel: 'shell-nav',
    canRequestFocus: false,
    skipTraversal: true,
  );

  /// The visible main tabs of the last build.
  List<MainTab> _tabs = const [];

  late final bool _tv = ref.read(formFactorProvider).isTv;
  bool _focusCheckScheduled = false;

  int get _pid => widget.playlistId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _remember());
    if (_tv) {
      FocusManager.instance.addListener(_onFocusChanged);
      _scheduleFocusCheck();
    }
  }

  @override
  void didUpdateWidget(PlaylistShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location ||
        oldWidget.playlistId != widget.playlistId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _remember());
      if (_tv) _scheduleFocusCheck();
    }
  }

  @override
  void dispose() {
    if (_tv) FocusManager.instance.removeListener(_onFocusChanged);
    _shortcutFocus.dispose();
    _navFocus.dispose();
    for (final node in _tabNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  FocusNode _tabNode(String id) =>
      _tabNodes.putIfAbsent(id, () => FocusNode(debugLabel: 'nav-$id'));

  /// Focus that shows nothing on screen: none, the shell itself, or a page
  /// scope of the shell with nothing focused in it. Pages that park focus
  /// on their own key-handling nodes (live, grids) are left alone.
  bool _isLost(FocusNode? node) {
    if (node == null || node == _shortcutFocus) return true;
    if (node is! FocusScopeNode) return false;
    return node == _shortcutFocus.enclosingScope ||
        node.ancestors.contains(_shortcutFocus);
  }

  void _onFocusChanged() {
    if (_isLost(FocusManager.instance.primaryFocus)) _scheduleFocusCheck();
  }

  void _scheduleFocusCheck() {
    if (_focusCheckScheduled) return;
    _focusCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusCheckScheduled = false;
      _ensureVisibleFocus();
    });
  }

  /// TV: after a page change or when the focused element went away, a page
  /// that focused nothing hands focus to the active top-nav tab.
  void _ensureVisibleFocus() {
    if (!mounted || !(ModalRoute.isCurrentOf(context) ?? true)) return;
    if (!_isLost(FocusManager.instance.primaryFocus)) return;
    _focusActiveTab();
  }

  void _focusActiveTab() {
    final active = _activeId();
    final node = active == null ? null : _tabNodes[active];
    if (node != null && node.context != null) {
      node.requestFocus();
    } else {
      kFocusFirstIn(_navFocus);
    }
  }

  /// TV ↑ that the page did not handle: move up inside the page, and from
  /// its top edge into the top nav (pages are separate focus scopes, which
  /// directional traversal does not leave on its own).
  bool _moveUp() {
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null ||
        _navFocus.hasFocus ||
        ref.read(categorySidebarOpenProvider)) {
      return false;
    }
    if (!primary.focusInDirection(TraversalDirection.up)) _focusActiveTab();
    return true;
  }

  /// TV Back that the page did not handle: up one level in the shell.
  void _goBack() {
    final home = shellHomeTab(
      ref
          .read(settingsStoreProvider)
          .get(PlaylistSettings.initialTab, playlistId: _pid),
      _tabs,
    );
    ref.read(categorySidebarOpenProvider.notifier).close();
    GoRouter.of(context)
        .go(shellBackLocation(widget.location, pid: _pid, home: home));
  }

  /// Remembers the last playlist and tab (Auto-open last playlist, initial
  /// tab "Last used").
  void _remember() {
    if (!mounted) return;
    final settings = ref.read(settingsStoreProvider);
    if (settings.get(AppSettings.lastPlaylistId) != _pid) {
      settings.set(AppSettings.lastPlaylistId, _pid);
    }
    final tab = tabForLocation(widget.location);
    if (tab != null &&
        settings.get(PlaylistSettings.lastTab, playlistId: _pid) !=
            tab.segment) {
      settings.set(PlaylistSettings.lastTab, tab.segment, playlistId: _pid);
    }
  }

  List<MainTab> _visibleTabs(PlaylistRow? row) {
    String key(MainTab t) => t.segment;
    final settings = ref.watch(settingsRevisionProvider);
    assert(settings >= 0);
    final store = ref.read(settingsStoreProvider);
    // Before the first import nothing is known: show every tab.
    final imported = row?.lastReloadAt != null;
    bool enabled(MainTab t) => switch (t) {
      MainTab.movies =>
        store.get(PlaylistSettings.showMovies, playlistId: _pid) &&
            (!imported || (row?.movieCount ?? 0) > 0),
      MainTab.shows =>
        store.get(PlaylistSettings.showShows, playlistId: _pid) &&
            (!imported || (row?.seriesCount ?? 0) > 0),
      MainTab.live =>
        store.get(PlaylistSettings.showLive, playlistId: _pid) &&
            (!imported || (row?.liveCount ?? 0) > 0),
      MainTab.guide =>
        store.get(PlaylistSettings.showGuide, playlistId: _pid) &&
            (!imported || (row?.liveCount ?? 0) > 0),
    };
    final tabs = MainTab.values.where(enabled).toList();
    assert(tabs.map(key).toSet().length == tabs.length);
    return tabs;
  }

  String _label(L10n l10n, MainTab tab) => switch (tab) {
    MainTab.movies => l10n.shellMovies,
    MainTab.shows => l10n.shellShows,
    MainTab.live => l10n.shellLive,
    MainTab.guide => l10n.shellGuide,
  };

  String? _activeId() {
    final tab = tabForLocation(widget.location);
    if (tab != null) return tab.segment;
    final segments = Uri.parse(widget.location).pathSegments;
    if (segments.length >= 3) return segments[2];
    return null;
  }

  void _select(String id) {
    final router = GoRouter.of(context);
    ref.read(categorySidebarOpenProvider.notifier).close();
    switch (id) {
      case 'search':
        router.go(Routes.search(_pid));
      case 'settings':
        router.go(Routes.playlistSettings(_pid));
      default:
        final tab = MainTabPath.fromSegment(id);
        if (tab != null) router.go(Routes.tab(_pid, tab));
    }
  }

  void _selectIndex(List<MainTab> tabs, int index) {
    if (index < tabs.length) _select(tabs[index].segment);
  }

  Future<void> _openAvatarMenu(Rect anchor, List<PlaylistRow> playlists) async {
    final l10n = L10n.of(context);
    final router = GoRouter.of(context);
    final others = playlists.where((p) => p.id != _pid).toList();
    final choice = await showKContextMenu<int>(
      context,
      position: anchor.bottomRight,
      title: l10n.shellSwitchPlaylist,
      iconPosition: KMenuIconPosition.leading,
      separators: false,
      entries: [
        for (final p in others)
          KMenuEntry<int>(
            label: p.name,
            value: p.id,
            icon: PhosphorIconsLight.userCircle,
          ),
        KMenuEntry<int>(
          label: l10n.shellPlaylistManager,
          value: -1,
          icon: PhosphorIconsLight.squaresFour,
        ),
      ],
    );
    if (!mounted || choice == null) return;
    if (choice == -1) {
      router.go(Routes.manager);
    } else {
      router.go(Routes.manager, extra: {'open': choice});
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final playlist = ref.watch(shellPlaylistProvider(_pid)).value;
    final playlists = ref.watch(shellPlaylistsProvider).value ?? const [];
    final now = ref.watch(minuteClockProvider).value ?? DateTime.now();
    final fmt = ref.watch(timeFormatProvider);
    final showClock = ref.watchSetting(AppSettings.showClock);
    final tabs = _visibleTabs(playlist);
    _tabs = tabs;
    final mainTab = tabForLocation(widget.location);
    final sidebarKind = switch (mainTab) {
      MainTab.movies => SectionKind.movie,
      MainTab.shows => SectionKind.series,
      MainTab.live || MainTab.guide => SectionKind.live,
      null => null,
    };
    // Main tabs only; "See All" grids keep the FAB too (same section).
    final showFab = sidebarKind != null;

    return CallbackShortcuts(
      bindings: {
        for (var i = 0; i < 4; i++) ...{
          SingleActivator(
            LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + i),
            control: true,
          ): () =>
              _selectIndex(tabs, i),
          SingleActivator(
            LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + i),
            meta: true,
          ): () =>
              _selectIndex(tabs, i),
        },
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
            _select('search'),
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): () =>
            _select('search'),
        const SingleActivator(LogicalKeyboardKey.comma, control: true): () =>
            _select('settings'),
        const SingleActivator(LogicalKeyboardKey.comma, meta: true): () =>
            _select('settings'),
      },
      child: Focus(
        focusNode: _shortcutFocus,
        // On TV the shell only routes keys: focus belongs on visible items.
        autofocus: !_tv,
        canRequestFocus: !_tv,
        skipTraversal: _tv,
        // "/" opens search, unless the user is typing in a text field.
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (_tv && event.logicalKey == LogicalKeyboardKey.escape) {
            _goBack();
            return KeyEventResult.handled;
          }
          if (_tv &&
              event.logicalKey == LogicalKeyboardKey.arrowUp &&
              _moveUp()) {
            return KeyEventResult.handled;
          }
          if (event.logicalKey != LogicalKeyboardKey.slash) {
            return KeyEventResult.ignored;
          }
          final focused = FocusManager.instance.primaryFocus?.context?.widget;
          if (focused is EditableText) return KeyEventResult.ignored;
          _select('search');
          return KeyEventResult.handled;
        },
        child: ColoredBox(
          color: KColors.bg,
          child: Column(
            children: [
              Focus(
                focusNode: _navFocus,
                child: KTopNav(
                  leadingInset: Platform.isMacOS ? 72 : 0,
                  tabs: [
                    for (final t in tabs)
                      KNavTab(id: t.segment, label: _label(l10n, t)),
                    KNavTab.icon(
                      id: 'search',
                      icon: PhosphorIconsLight.magnifyingGlass,
                      label: l10n.shellSearch,
                    ),
                    KNavTab(id: 'settings', label: l10n.shellSettings),
                  ],
                  activeTabId: _activeId(),
                  tabFocusNodes: {
                    for (final t in tabs) t.segment: _tabNode(t.segment),
                    'search': _tabNode('search'),
                    'settings': _tabNode('settings'),
                  },
                  onTabSelected: _select,
                  dateTimeText: showClock ? fmt.navDateTime(now) : null,
                  onLogoTap: () => GoRouter.of(context).go(Routes.manager),
                  avatar: KAvatar(
                    playlist?.avatarId,
                    44,
                    fallbackName: playlist?.name,
                  ),
                  avatarTooltip: l10n.shellSwitchPlaylist,
                  onAvatarTap: (rect) => _openAvatarMenu(rect, playlists),
                  trailing: [ShellReloadChip(playlistId: _pid)],
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(child: widget.child),
                    if (showFab)
                      Positioned(
                        right: 28,
                        bottom: 28,
                        child: KFab(
                          tooltip: l10n.shellCategories,
                          onPressed: () => ref
                              .read(categorySidebarOpenProvider.notifier)
                              .toggle(),
                        ),
                      ),
                    if (sidebarKind != null)
                      Positioned.fill(
                        child: CategorySidebarHost(
                          playlistId: _pid,
                          kind: sidebarKind,
                        ),
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
