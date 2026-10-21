/// The full-window player: video, auto-hiding controls, menus,
/// overlays and the keyboard map, on top of a [PlayerController].
library;

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/clock.dart';
import '../../app/platform/form_factor.dart';
import '../../app/platform/screen_awake.dart';
import '../../app/router.dart' show rootNavigatorKey;
import '../../app/time_format.dart';
import '../../core/core.dart';
import '../../data/net/mask.dart';
import '../../data/settings/settings_store.dart';
import '../../features/guide/guide_api.dart';
import '../../features/multiview/multiview_api.dart';
import '../../features/parental/parental_api.dart';
import '../../l10n/gen/app_localizations.dart';
import '../engine/playback_engine.dart';
import '../player_api.dart';
import 'guide/mini_guide_adapter.dart';
import 'player_controller.dart';
import 'player_menus.dart';
import 'player_options.dart';
import 'player_route.dart';
import 'player_shortcuts.dart';
import 'player_texts.dart';
import 'player_window.dart';
import 'widgets/action_sheet.dart';
import 'widgets/info_panel.dart';
import 'widgets/player_bars.dart';
import 'widgets/player_button.dart';
import 'widgets/player_overlays.dart';

/// How long the controls stay after the last activity.
const Duration kPlayerControlsTimeout = Duration(seconds: 3);

/// How long the quick-switch OSD stays after a zap.
const Duration kZapOsdDuration = Duration(seconds: 3);

/// Number zapping waits this long after the last digit.
const Duration kNumberZapDelay = Duration(milliseconds: 1500);

enum _Guide { none, mini, full }

/// The remote's D-pad.
final Set<LogicalKeyboardKey> _arrowKeys = {
  LogicalKeyboardKey.arrowUp,
  LogicalKeyboardKey.arrowDown,
  LogicalKeyboardKey.arrowLeft,
  LogicalKeyboardKey.arrowRight,
};

/// Live keys that still work while the error overlay is up.
final Set<LogicalKeyboardKey> _liveZapKeys = {
  LogicalKeyboardKey.arrowUp,
  LogicalKeyboardKey.arrowDown,
  LogicalKeyboardKey.pageUp,
  LogicalKeyboardKey.pageDown,
  LogicalKeyboardKey.channelUp,
  LogicalKeyboardKey.channelDown,
  LogicalKeyboardKey.backspace,
  LogicalKeyboardKey.keyG,
};

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key, required this.request});

  final PlayRequest request;

  @override
  ConsumerState<PlayerScreen> createState() => PlayerScreenState();
}

/// Public so tests can reach the controller.
class PlayerScreenState extends ConsumerState<PlayerScreen> {
  late final PlayerController controller;
  late final Widget _video;
  final FocusNode _focus = FocusNode(debugLabel: 'player');
  final Map<PlayerMenu, GlobalKey> _menuKeys = {
    for (final m in PlayerMenu.values)
      m: GlobalKey(debugLabel: 'player ${m.name}'),
  };
  final GlobalKey _errorSwitchKey = GlobalKey(debugLabel: 'error switch');

  /// Android TV / Google TV with a remote (decided once at bootstrap).
  late final bool _tv;

  /// TV: marks the controls subtree, so "focus is on a control" is
  /// `_controlsScope.hasFocus`.
  final FocusNode _controlsScope = FocusNode(
    debugLabel: 'player controls',
    canRequestFocus: false,
    skipTraversal: true,
  );

  /// TV: focus nodes of the bar controls (null on desktop).
  PlayerBarFocus? _barFocus;

  /// TV: the control that had focus when an overlay opened.
  FocusNode? _returnFocus;

  bool _controlsVisible = true;
  bool _pinned = false;
  bool _pointerOverBar = false;
  Timer? _hideTimer;
  int _menuDepth = 0;
  PlayerMenu? _activeMenu;
  bool _infoOpen = false;
  bool _statsOpen = false;
  _Guide _guide = _Guide.none;
  bool _fullscreen = false;
  bool _initialDone = false;
  bool _hadModal = false;

  int _shownZapSerial = 0;
  bool _zapOsd = false;
  Timer? _zapTimer;
  String _digits = '';
  Timer? _digitsTimer;
  bool _volumeOsd = false;
  Timer? _volumeTimer;
  String? _flash;
  Timer? _flashTimer;
  DateTime _lastWheelZap = DateTime.fromMillisecondsSinceEpoch(0);

  late final ScreenAwake _screenAwake;

  PlayerKind get _kind => controller.kind;
  bool get _live => _kind == PlayerKind.live;

  /// Whether the controls (bars) are on screen.
  bool get controlsVisible => _controlsShown;

  bool get _controlsShown =>
      _controlsVisible &&
      !_infoOpen &&
      _guide == _Guide.none &&
      controller.failure == null &&
      controller.resumeOffer == null;

  List<PlayerMenu> get _menus => _live || _kind == PlayerKind.catchup
      ? const [
          PlayerMenu.switchPlayer,
          PlayerMenu.audio,
          PlayerMenu.subtitles,
          PlayerMenu.picture,
          PlayerMenu.more,
        ]
      : PlayerMenu.values;

  @override
  void initState() {
    super.initState();
    _tv = ref.read(formFactorProvider).isTv;
    if (_tv) {
      _barFocus = PlayerBarFocus(
        menus: {
          for (final m in PlayerMenu.values)
            m: FocusNode(debugLabel: 'player ${m.name} button'),
        },
        seek: FocusNode(debugLabel: 'player seek bar'),
        hint: FocusNode(debugLabel: 'player hint'),
      );
    }
    controller = PlayerController(
      request: widget.request,
      deps: PlayerDeps.of(ref),
      unlockChannel: _unlock,
    );
    _video = controller.engine.buildVideo();
    controller.addListener(_onController);
    _screenAwake = ref.read(screenAwakeProvider)..hold(this);
    _scheduleHide();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      unawaited(controller.start());
      unawaited(_readFullscreen());
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _zapTimer?.cancel();
    _digitsTimer?.cancel();
    _volumeTimer?.cancel();
    _flashTimer?.cancel();
    controller.removeListener(_onController);
    _screenAwake.release(this);
    controller.dispose();
    _focus.dispose();
    _controlsScope.dispose();
    final bar = _barFocus;
    if (bar != null) {
      for (final node in bar.menus.values) {
        node.dispose();
      }
      bar.seek.dispose();
      bar.hint.dispose();
    }
    super.dispose();
  }

  Future<bool> _unlock(String channelId) async {
    if (!mounted) return false;
    return ensureChannelUnlocked(
      context,
      playlistId: controller.playlistId,
      channelId: channelId,
    );
  }

  void _onController() {
    if (!mounted) return;
    // A paused stream or an error screen lets the TV dim again.
    final engine = controller.state;
    if (controller.failure == null &&
        (engine.source == null || engine.playing || engine.buffering)) {
      _screenAwake.hold(this);
    } else {
      _screenAwake.release(this);
    }
    // Give the keyboard back to the player when a prompt closes (its
    // focused pill is gone).
    final modal = controller.resumeOffer != null || controller.failure != null;
    if (_hadModal && !modal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_infoOpen && _guide == _Guide.none) {
          _focus.requestFocus();
        }
      });
    }
    _hadModal = modal;
    if (controller.zapSerial != _shownZapSerial) {
      _shownZapSerial = controller.zapSerial;
      _zapOsd = true;
      _zapTimer?.cancel();
      _zapTimer = Timer(kZapOsdDuration, () {
        if (mounted) setState(() => _zapOsd = false);
      });
    }
    if (!_initialDone) {
      final s = controller.state;
      if (controller.failure != null) {
        _initialDone = true;
      } else if (s.source != null && !s.buffering && !controller.resolving) {
        _openInitialOverlay();
      }
    }
    setState(() {});
  }

  // ---------------------------------------------------------------------------
  // Controls visibility

  void _showControls() {
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(kPlayerControlsTimeout, _maybeHide);
  }

  void _maybeHide() {
    if (!mounted) return;
    final s = controller.state;
    final pausedVod =
        !_live && s.source != null && !s.playing && controller.failure == null;
    // Never while a menu is open, the pointer is on the bar or a VOD is
    // paused.
    if (_menuDepth > 0 || _pinned || _pointerOverBar || pausedVod) {
      _scheduleHide();
      return;
    }
    _releaseControlFocus();
    setState(() => _controlsVisible = false);
  }

  void _hideControlsNow() {
    // Focus first: it may flush a pending seek, which re-arms the timer.
    _releaseControlFocus();
    _hideTimer?.cancel();
    if (_controlsVisible) setState(() => _controlsVisible = false);
  }

  /// TV: hidden controls are excluded from focus, so a control that has it
  /// hands it back to the player first (else the keys stop reaching it).
  void _releaseControlFocus() {
    if (_tv && _controlsScope.hasFocus) _focus.requestFocus();
  }

  /// TV: shows the controls and moves focus into them (the seek bar, on
  /// live the hint), once they are on screen again.
  void _focusControls() {
    final bar = _barFocus;
    if (bar == null) return;
    _showControls();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controlsShown || _controlsScope.hasFocus) return;
      (_live ? bar.hint : bar.seek).requestFocus();
    });
  }

  /// TV: remembers the control that has focus before an overlay covers it.
  void _rememberFocus() {
    _returnFocus = _tv && _controlsScope.hasFocus
        ? FocusManager.instance.primaryFocus
        : null;
  }

  /// Gives the keyboard back to the player when an overlay closes. On TV it
  /// goes to the remembered control (or [fallback]) while the controls are
  /// on screen, else to the player itself, never to an invisible node.
  void _restoreFocus({FocusNode? fallback}) {
    if (!_tv) {
      _focus.requestFocus();
      return;
    }
    final node = _returnFocus ?? fallback;
    _returnFocus = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_controlsShown &&
          node != null &&
          node.context != null &&
          node.canRequestFocus) {
        node.requestFocus();
      } else {
        _focus.requestFocus();
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Initial overlay (capture mode)

  void _openInitialOverlay() {
    _initialDone = true;
    final overlay = widget.request.initialOverlay;
    if (overlay == PlayerInitialOverlay.none) return;
    _pinned = true;
    _controlsVisible = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (overlay) {
        case PlayerInitialOverlay.none:
        case PlayerInitialOverlay.controls:
          break;
        case PlayerInitialOverlay.audioMenu:
          unawaited(openMenu(PlayerMenu.audio));
        case PlayerInitialOverlay.subtitlesMenu:
          unawaited(openMenu(PlayerMenu.subtitles));
        case PlayerInitialOverlay.switchPlayerMenu:
          unawaited(openMenu(PlayerMenu.switchPlayer));
        case PlayerInitialOverlay.infoPanel:
          _openInfo();
        case PlayerInitialOverlay.actionSheet:
          unawaited(_openActionSheet());
        case PlayerInitialOverlay.miniGuide:
          _openGuide(_Guide.mini);
        case PlayerInitialOverlay.fullGuide:
          _openGuide(_Guide.full);
        case PlayerInitialOverlay.stats:
          setState(() => _statsOpen = true);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Menus

  /// Opens a bar menu above its button (A / S keys, clicks, capture mode).
  Future<void> openMenu(PlayerMenu menu) async {
    if (_menuDepth > 0) return;
    if (!_controlsShown) {
      setState(() {
        _infoOpen = false;
        _controlsVisible = true;
      });
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    final anchor = _menuKeys[menu]?.currentContext;
    if (anchor == null || !anchor.mounted) return;
    await _showMenu(menu, anchor);
  }

  Future<void> _showMenu(PlayerMenu menu, BuildContext anchor) async {
    _hideTimer?.cancel();
    _rememberFocus();
    _menuDepth++;
    setState(() => _activeMenu = menu);
    try {
      await showKPopoverMenu(
        anchor,
        anchorRect: kGlobalRectOf(anchor),
        listenable: controller,
        width: switch (menu) {
          PlayerMenu.audio || PlayerMenu.subtitles => 360,
          PlayerMenu.speed => 220,
          _ => 320,
        },
        sections: (context) => _sections(context, menu),
      );
    } finally {
      _menuDepth--;
      if (mounted) {
        setState(() => _activeMenu = null);
        _scheduleHide();
        _restoreFocus();
      }
    }
  }

  List<KPopoverSection> _sections(BuildContext context, PlayerMenu menu) {
    final l10n = L10n.of(context);
    final c = controller;
    return switch (menu) {
      PlayerMenu.switchPlayer => switchPlayerSections(
        l10n,
        c,
        onSelect: _switchProfile,
      ),
      PlayerMenu.audio => audioSections(l10n, c),
      PlayerMenu.subtitles => subtitleSections(
        l10n,
        c,
        onLoadFile: () => unawaited(_loadSubtitleFile()),
      ),
      PlayerMenu.picture => pictureSections(l10n, c),
      PlayerMenu.speed => speedSections(l10n, c),
      PlayerMenu.more => moreSections(
        l10n,
        c,
        statsVisible: _statsOpen,
        fullscreen: _fullscreen,
        onInfo: () =>
            WidgetsBinding.instance.addPostFrameCallback((_) => _openInfo()),
        onStats: () => setState(() => _statsOpen = !_statsOpen),
        onFullscreen: () => unawaited(_toggleFullscreen()),
        onNextEpisode: c.nextEpisode == null
            ? null
            : () => unawaited(c.playNextEpisode()),
        tv: _tv,
        muted: c.state.muted,
        onMute: () => unawaited(c.toggleMute()),
      ),
    };
  }

  Future<void> _switchProfile(EngineProfile profile) async {
    final l10n = L10n.of(context);
    final toasts = ref.read(toastControllerProvider);
    await controller.switchProfile(profile);
    toasts.show(l10n.playerSwitchedTo(profileLabel(l10n, profile)));
  }

  Future<void> _openSwitchFromError() async {
    final anchor = _errorSwitchKey.currentContext;
    if (anchor == null) return;
    _menuDepth++;
    try {
      await showKPopoverMenu(
        anchor,
        anchorRect: kGlobalRectOf(anchor),
        listenable: controller,
        sections: (context) => _sections(context, PlayerMenu.switchPlayer),
      );
    } finally {
      _menuDepth--;
    }
  }

  Future<void> _loadSubtitleFile() async {
    final l10n = L10n.of(context);
    final toasts = ref.read(toastControllerProvider);
    final pick = ref.read(subtitleFilePickerProvider);
    _menuDepth++;
    String? path;
    try {
      path = await pick();
    } finally {
      _menuDepth--;
    }
    if (path == null || !mounted) return;
    await controller.addExternalSubtitle(path);
    toasts.show(l10n.playerSubtitleLoaded);
    _restoreFocus();
  }

  // ---------------------------------------------------------------------------
  // Panels and guides

  void _openInfo() {
    if (!mounted) return;
    _hideTimer?.cancel();
    _rememberFocus();
    _releaseControlFocus();
    setState(() {
      _infoOpen = true;
      _guide = _Guide.none;
    });
  }

  void _closeInfo() {
    setState(() => _infoOpen = false);
    _showControls();
    _restoreFocus(fallback: _live ? null : _barFocus?.seek);
  }

  void _openGuide(_Guide guide) {
    if (!_live) return;
    setState(() {
      _guide = guide;
      _infoOpen = false;
    });
    _hideControlsNow();
  }

  void _closeGuide() {
    setState(() => _guide = _Guide.none);
    _returnFocus = null;
    _focus.requestFocus();
  }

  Future<void> _openActionSheet() async {
    final channel = controller.channel;
    if (!_live || channel == null || _menuDepth > 0) return;
    _rememberFocus();
    _menuDepth++;
    LiveAction? action;
    try {
      action = await showLiveActionSheet(
        context,
        channelName: channel.displayName,
      );
    } finally {
      _menuDepth--;
    }
    if (!mounted) return;
    switch (action) {
      case LiveAction.fullGuide:
        _openGuide(_Guide.full);
      case LiveAction.miniGuide:
        _openGuide(_Guide.mini);
      case LiveAction.addChannel:
        await _addToMultiview();
      case null:
        _restoreFocus();
    }
  }

  Future<void> _addToMultiview() async {
    final channel = controller.channel;
    if (channel == null) return;
    final navigator = Navigator.of(context);
    final host = rootNavigatorKey.currentContext ?? navigator.context;
    final playlistId = controller.playlistId;
    navigator.pop();
    await addToMultiview(
      host,
      playlistId: playlistId,
      channelId: channel.providerId,
      pickAnother: true,
    );
  }

  Future<void> _tuneFromGuide(String channelId) async {
    _closeGuide();
    await controller.tuneChannel(channelId);
  }

  Future<void> _playCatchup(
    String channelId,
    DateTime startUtc,
    DateTime endUtc,
  ) async {
    final navigator = Navigator.of(context);
    var title = controller.channel?.displayName ?? '';
    final channel = controller.channel;
    if (channel?.epgKey != null) {
      try {
        final list = await controller.deps.epg.programmes(
          controller.playlistId,
          channel!.epgKey!,
          startUtc,
          endUtc,
        );
        final match = list.where((p) => p.start == startUtc.toUtc());
        if (match.isNotEmpty) title = match.first.title;
      } catch (_) {
        // Keep the channel name.
      }
    }
    if (!mounted) return;
    unawaited(
      navigator.pushReplacement(
        PlayerPageRoute(
          CatchupPlayRequest(
            playlistId: controller.playlistId,
            channelId: channelId,
            startUtc: startUtc,
            endUtc: endUtc,
            title: title,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions

  Future<void> _readFullscreen() async {
    final full = await ref.read(playerWindowProvider).isFullscreen();
    if (mounted && full != _fullscreen) setState(() => _fullscreen = full);
  }

  Future<void> _toggleFullscreen() async {
    await ref.read(playerWindowProvider).toggleFullscreen();
    await _readFullscreen();
  }

  /// Esc / Mouse4: close the top overlay, leave full screen, close.
  Future<void> back() async {
    if (_guide != _Guide.none) return _closeGuide();
    if (_infoOpen) return _closeInfo();
    final window = ref.read(playerWindowProvider);
    if (await window.isFullscreen()) {
      await window.exitFullscreen();
      await _readFullscreen();
      return;
    }
    if (mounted) await Navigator.of(context).maybePop();
  }

  void _togglePlay() {
    unawaited(controller.togglePlay());
    _showControls();
  }

  void _changeVolume(double delta) {
    unawaited(controller.changeVolume(delta));
    _showVolumeOsd();
  }

  void _showVolumeOsd() {
    setState(() => _volumeOsd = true);
    _volumeTimer?.cancel();
    _volumeTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _volumeOsd = false);
    });
  }

  void _showFlash(String text) {
    setState(() => _flash = text);
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _flash = null);
    });
  }

  void _typeDigit(int digit) {
    if (!ref.readSetting(
      PlaylistSettings.numberZapping,
      playlistId: controller.playlistId,
    )) {
      return;
    }
    if (_digits.length >= 4) _digits = '';
    setState(() => _digits += '$digit');
    _digitsTimer?.cancel();
    _digitsTimer = Timer(kNumberZapDelay, () async {
      final number = int.tryParse(_digits) ?? 0;
      if (mounted) setState(() => _digits = '');
      if (number <= 0) return;
      final l10n = L10n.of(context);
      final ok = await controller.tuneNumber(number);
      if (!ok && mounted) _showFlash(l10n.playerNoChannelNumber(number));
    });
  }

  void _onVideoTap() {
    if (_guide != _Guide.none) return _closeGuide();
    if (_infoOpen) return _closeInfo();
    if (_live) {
      _showControls();
      unawaited(_openActionSheet());
    } else {
      _togglePlay();
    }
  }

  void _run(PlayerShortcut shortcut, {required bool repeat}) {
    final l10n = L10n.of(context);
    final c = controller;
    switch (shortcut.command) {
      case PlayerCommand.togglePlay:
        if (!repeat) _togglePlay();
      case PlayerCommand.seekBack ||
          PlayerCommand.seekForward ||
          PlayerCommand.seekBackLong ||
          PlayerCommand.seekForwardLong:
        unawaited(c.seekBy(seekStepFor(shortcut.command, _kind)));
        _showControls();
      case PlayerCommand.seekPercent:
        unawaited(c.seekPercent(shortcut.digit ?? 0));
        _showControls();
      case PlayerCommand.volumeUp:
        _changeVolume(5);
      case PlayerCommand.volumeDown:
        _changeVolume(-5);
      case PlayerCommand.toggleMute:
        if (!repeat) {
          unawaited(c.toggleMute());
          _showVolumeOsd();
        }
      case PlayerCommand.toggleFullscreen:
        if (!repeat) unawaited(_toggleFullscreen());
      case PlayerCommand.audioMenu:
        if (!repeat) unawaited(openMenu(PlayerMenu.audio));
      case PlayerCommand.subtitlesMenu:
        if (!repeat) unawaited(openMenu(PlayerMenu.subtitles));
      case PlayerCommand.infoPanel:
        if (!repeat) _openInfo();
      case PlayerCommand.closeInfoPanel:
        _closeInfo();
      case PlayerCommand.nextEpisode:
        if (!repeat && c.nextEpisode != null) {
          unawaited(c.playNextEpisode());
        }
      case PlayerCommand.audioDelayDown || PlayerCommand.audioDelayUp:
        // The controller stores the new delay synchronously.
        unawaited(
          c.stepAudioDelay(
            shortcut.command == PlayerCommand.audioDelayUp ? 1 : -1,
          ),
        );
        _showFlash(
          l10n.playerDelayOsd(
            l10n.playerAudioDelay,
            delayLabel(l10n, c.audioDelay),
          ),
        );
      case PlayerCommand.toggleStats:
        if (!repeat) setState(() => _statsOpen = !_statsOpen);
      case PlayerCommand.back:
        if (!repeat) unawaited(back());
      case PlayerCommand.previousChannel:
        if (repeat) return;
        if (_guide != _Guide.none || _infoOpen) {
          unawaited(back());
        } else if (c.previousChannelId != null) {
          unawaited(c.previousChannel());
        } else {
          unawaited(back());
        }
      case PlayerCommand.zapPrevious:
        unawaited(c.zap(-1));
      case PlayerCommand.zapNext:
        unawaited(c.zap(1));
      case PlayerCommand.actionSheet:
        if (!repeat) unawaited(_openActionSheet());
      case PlayerCommand.miniGuide:
        if (!repeat) {
          _guide == _Guide.mini ? _closeGuide() : _openGuide(_Guide.mini);
        }
      case PlayerCommand.fullGuide:
        if (!repeat) _openGuide(_Guide.full);
      case PlayerCommand.numberZap:
        _typeDigit(shortcut.digit ?? 0);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    // In-screen prompts own the keyboard (focus moves between their pills);
    // only Esc reaches the player — and, on live TV, the zapping keys, so a
    // dead channel never traps the user.
    final modal = controller.resumeOffer != null || controller.failure != null;
    if (modal &&
        key != LogicalKeyboardKey.escape &&
        !(_live && (_liveZapKeys.contains(key) || digitOfKey(key) != null))) {
      return KeyEventResult.ignored;
    }
    final shortcut = playerShortcutFor(
      key,
      kind: _kind,
      controlsVisible: _controlsShown,
      infoPanelOpen: _infoOpen,
      modifiers: PlayerModifiers.current(),
    );
    if (_tv && !modal) {
      final result = _onTvKey(event, shortcut);
      if (result != null) return result;
    }
    if (shortcut == null) {
      if (event is KeyDownEvent) _showControls();
      return KeyEventResult.ignored;
    }
    _run(shortcut, repeat: event is KeyRepeatEvent);
    return KeyEventResult.handled;
  }

  /// The remote on TV: the D-pad moves focus between the controls while
  /// they show; with them hidden it seeks / zaps and OK brings them back.
  /// Returns null to let the keyboard map ([shortcut]) decide.
  KeyEventResult? _onTvKey(KeyEvent event, PlayerShortcut? shortcut) {
    final key = event.logicalKey;
    final repeat = event is KeyRepeatEvent;
    final arrow = _arrowKeys.contains(key);
    final ok =
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.select;

    // Back (Esc): the controls go first, then a second press leaves.
    if (shortcut?.command == PlayerCommand.back) {
      if (_controlsShown) {
        if (!repeat) _hideControlsNow();
        return KeyEventResult.handled;
      }
      return null;
    }
    if (!arrow && !ok) return null;

    // The guides and the info panel have their own focus (Back closes
    // them).
    if (_guide != _Guide.none || _infoOpen) return KeyEventResult.ignored;

    // Something else has focus (a control, the Skip intro pill, the paused
    // button): arrows travel between the focusable widgets, and OK reaches
    // the focused one first (only a node without an action, like the seek
    // bar, lets it through to the keyboard map).
    final primary = FocusManager.instance.primaryFocus;
    if (primary != null && primary != _focus) {
      final sideways =
          key == LogicalKeyboardKey.arrowLeft ||
          key == LogicalKeyboardKey.arrowRight;
      if (_controlsScope.hasFocus) {
        _scheduleHide();
        return arrow ? KeyEventResult.ignored : null;
      }
      if (!sideways || _controlsShown) {
        return arrow ? KeyEventResult.ignored : null;
      }
      // A lone pill must not trap ←/→: back to the player (seek / zap).
      _focus.requestFocus();
    }

    // The player itself has focus.
    final up = key == LogicalKeyboardKey.arrowUp;
    final down = key == LogicalKeyboardKey.arrowDown;
    if (_live) {
      // ↑/↓ zap and OK opens the actions, as on desktop; ←/→ bring the
      // controls.
      if (up || down || ok) return null;
      _focusControls();
      return KeyEventResult.handled;
    }
    if (up || down) {
      _focusControls();
      return KeyEventResult.handled;
    }
    // ←/→ seek and OK plays / pauses, with the controls following.
    if (shortcut != null) _run(shortcut, repeat: repeat);
    _focusControls();
    return KeyEventResult.handled;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.mouse &&
        (event.buttons & kBackMouseButton) != 0) {
      unawaited(back());
    }
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || _guide != _Guide.none) return;
    final dy = event.scrollDelta.dy;
    if (dy == 0) return;
    final wheelZaps = ref.readSetting(
      PlaylistSettings.wheelZaps,
      playlistId: controller.playlistId,
    );
    if (_live && wheelZaps) {
      final now = DateTime.now();
      if (now.difference(_lastWheelZap) < const Duration(milliseconds: 250)) {
        return;
      }
      _lastWheelZap = now;
      unawaited(controller.zap(dy > 0 ? 1 : -1));
    } else {
      _changeVolume(dy < 0 ? 5 : -5);
    }
  }

  // ---------------------------------------------------------------------------
  // Build

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = controller;
    final format = ref.watch(timeFormatProvider);
    final now = ref.watch(minuteClockProvider).value ?? DateTime.now();
    final state = c.state;
    final failure = c.failure;
    final controlsShown = _controlsShown;
    final cursorVisible =
        controlsShown ||
        _menuDepth > 0 ||
        _infoOpen ||
        _guide != _Guide.none ||
        failure != null ||
        c.resumeOffer != null;
    if (_tv) WidgetsBinding.instance.addPostFrameCallback(_ensureFocus);
    final duration = KMotion.of(context, const Duration(milliseconds: 200));
    final sizeIndicator =
        ref.watchSetting(
          PlaylistSettings.resolutionIndicator,
          playlistId: c.playlistId,
        ) ==
        'size';
    final channel = c.channel;
    final showPaused =
        !_live &&
        state.source != null &&
        !state.playing &&
        !c.busy &&
        failure == null &&
        c.resumeOffer == null &&
        !_infoOpen;
    final nextOffer = c.nextEpisodeOffer;
    final intro = c.introChapter;

    return Focus(
      focusNode: _focus,
      // On TV the player takes focus only when asked: directional traversal
      // must not land on it (its box is the whole screen).
      skipTraversal: _tv,
      onKeyEvent: _onKey,
      child: Listener(
        onPointerDown: _onPointerDown,
        onPointerSignal: _onPointerSignal,
        child: MouseRegion(
          key: const ValueKey('player-cursor'),
          cursor: cursorVisible ? MouseCursor.defer : SystemMouseCursors.none,
          onHover: (_) => _showControls(),
          child: ColoredBox(
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Video (click: play/pause or live actions; double-click:
                // full screen).
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _onVideoTap,
                    onDoubleTap: () => unawaited(_toggleFullscreen()),
                    child: _video,
                  ),
                ),

                // Controls.
                Positioned.fill(
                  child: _ControlsGate(
                    ignoring: !controlsShown,
                    scope: _tv ? _controlsScope : null,
                    child: AnimatedOpacity(
                      key: const ValueKey('player-controls'),
                      opacity: controlsShown ? 1 : 0,
                      duration: duration,
                      child: Stack(
                        children: [
                          const Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: PlayerScrim(top: true, height: 220),
                          ),
                          const Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: PlayerScrim(height: 340),
                          ),
                          Positioned(
                            top: 32,
                            left: 40,
                            right: 48,
                            child: Row(
                              children: [
                                PlayerIconButton(
                                  icon: PhosphorIconsLight.arrowLeft,
                                  tooltip: l10n.playerBack,
                                  onPressed: () => unawaited(back()),
                                ),
                                const SizedBox(width: 18),
                                if (_live && channel != null)
                                  Flexible(
                                    child: LiveChannelHeader(
                                      channel: channel,
                                      stats: c.stats,
                                      sizeIndicator: sizeIndicator,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Positioned(
                            left: 48,
                            right: 48,
                            bottom: 26,
                            child: MouseRegion(
                              onEnter: (_) => _pointerOverBar = true,
                              onExit: (_) => _pointerOverBar = false,
                              child: _live
                                  ? LiveBottomBar(
                                      nowNext: c.nowNext,
                                      now: now,
                                      timeFormat: format,
                                      menus: _menus,
                                      menuKeys: _menuKeys,
                                      activeMenu: _activeMenu,
                                      onOpenMenu: (m) => unawaited(openMenu(m)),
                                      onOptions: () =>
                                          unawaited(_openActionSheet()),
                                      onPreviousChannel: _tv
                                          ? () {
                                              unawaited(c.previousChannel());
                                              _showControls();
                                            }
                                          : null,
                                      hasPreviousChannel:
                                          c.previousChannelId != null,
                                      tvFocus: _barFocus,
                                    )
                                  : VodBottomBar(
                                      controller: c,
                                      timeFormat: format,
                                      menus: _menus,
                                      menuKeys: _menuKeys,
                                      activeMenu: _activeMenu,
                                      onOpenMenu: (m) => unawaited(openMenu(m)),
                                      onSeek: (d) {
                                        unawaited(c.seekTo(d));
                                        _showControls();
                                      },
                                      onInteraction: _showControls,
                                      onInfo: _openInfo,
                                      tvFocus: _barFocus,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                if (showPaused)
                  Center(child: PausedIndicator(onPressed: _togglePlay)),

                if (c.busy)
                  Center(
                    child: PlayerBufferingIndicator(
                      state: state,
                      reconnectTotal: c.options.reconnectAttempts,
                    ),
                  ),

                // Skip intro / Next episode (bottom-right, above the bar).
                AnimatedPositioned(
                  duration: duration,
                  right: 48,
                  bottom: controlsShown ? 196 : 48,
                  child: AnimatedSwitcher(
                    duration: duration,
                    child: nextOffer != null && !_infoOpen
                        ? NextEpisodeCard(
                            offer: nextOffer,
                            onPlay: () => unawaited(c.playNextEpisode()),
                            onDismiss: c.dismissNextEpisode,
                          )
                        : intro != null && !_infoOpen
                        ? SkipIntroPill(
                            onPressed: () => unawaited(c.skipIntro()),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),

                // Info panel.
                Positioned(
                  left: 48,
                  right: 48,
                  bottom: 28,
                  child: IgnorePointer(
                    ignoring: !_infoOpen,
                    child: AnimatedSlide(
                      offset: _infoOpen ? Offset.zero : const Offset(0, 0.25),
                      duration: duration,
                      curve: KMotion.enter,
                      child: AnimatedOpacity(
                        opacity: _infoOpen ? 1 : 0,
                        duration: duration,
                        child: _infoOpen
                            ? _buildInfoPanel(l10n, format, now)
                            : null,
                      ),
                    ),
                  ),
                ),

                // OSDs.
                if (_zapOsd && channel != null && _live)
                  Positioned(
                    top: 28,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: ZapOsd(channel: channel, nowNext: c.nowNext),
                    ),
                  ),
                if (_flash != null)
                  Positioned(
                    top: _zapOsd ? 112 : 36,
                    left: 0,
                    right: 0,
                    child: Center(child: FlashOsd(text: _flash!)),
                  ),
                Positioned(
                  top: 32,
                  right: 48,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (_digits.isNotEmpty) ...[
                        NumberOsd(digits: _digits),
                        const SizedBox(height: 12),
                      ],
                      if (_volumeOsd)
                        VolumeOsd(volume: state.volume, muted: state.muted)
                      else if (state.muted)
                        const MuteIndicator(),
                      if (_statsOpen) ...[
                        const SizedBox(height: 12),
                        PlayerStatsOverlay(
                          stats: c.stats,
                          state: state,
                          profileName: profileLabel(l10n, c.profile),
                          source: state.source == null
                              ? null
                              : maskUrl(state.source!.url),
                        ),
                      ],
                    ],
                  ),
                ),

                // Guides.
                if (_guide == _Guide.mini && channel != null)
                  Positioned.fill(
                    child: buildMiniGuideOverlay(
                      playlistId: c.playlistId,
                      currentChannelId: channel.providerId,
                      categoryId: channel.row.categoryId,
                      onTune: (id) => unawaited(_tuneFromGuide(id)),
                      onClose: _closeGuide,
                    ),
                  ),
                if (_guide == _Guide.full && channel != null)
                  Positioned.fill(
                    child: ColoredBox(
                      key: const ValueKey('player-full-guide'),
                      color: const Color(0xC7000000),
                      child: GuideOverlay(
                        playlistId: c.playlistId,
                        currentChannelId: channel.providerId,
                        onTune: (id) => unawaited(_tuneFromGuide(id)),
                        onClose: _closeGuide,
                        onCatchup: (id, start, end) =>
                            unawaited(_playCatchup(id, start, end)),
                      ),
                    ),
                  ),

                // Prompts.
                if (failure != null)
                  Positioned.fill(
                    child: PlayerErrorOverlay(
                      key: const ValueKey('player-error'),
                      failure: failure,
                      switchPlayerKey: _errorSwitchKey,
                      onRetry: () => unawaited(c.retry()),
                      onSwitchPlayer: () => unawaited(_openSwitchFromError()),
                      onBack: () => unawaited(back()),
                    ),
                  ),
                if (c.resumeOffer != null && failure == null)
                  Positioned.fill(
                    child: PlayerResumePrompt(
                      key: const ValueKey('player-resume'),
                      title: c.media?.title ?? '',
                      position: c.resumeOffer!,
                      onResume: () => unawaited(c.resumeFromPrompt()),
                      onStartOver: () => unawaited(c.startOver()),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// TV safety net: when a focused widget went away (a pill that closed,
  /// the paused button) the keys would stop reaching the player.
  void _ensureFocus(Duration _) {
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    // After the focus requests of this frame have been applied.
    scheduleMicrotask(() {
      if (mounted && !_focus.hasFocus) _focus.requestFocus();
    });
  }

  Widget _buildInfoPanel(L10n l10n, CarinaTimeFormat format, DateTime now) {
    final c = controller;
    if (_live) {
      final channel = c.channel;
      final programme = c.nowNext.now;
      final title = programme == null
          ? channel?.displayName ?? ''
          : '${channel?.displayName ?? ''}: “${programme.title}”';
      return PlayerInfoPanel(
        title: title,
        overview: programme?.description,
        image: programme?.icon,
        imageFallback: channel == null
            ? null
            : ColoredBox(
                color: KColors.surface2,
                child: Center(
                  child: KLogoTile(
                    name: channel.displayName,
                    url: channel.logo,
                    size: 96,
                  ),
                ),
              ),
        lead: programme == null
            ? null
            : format.range(programme.start, programme.stop),
        chips: technicalChips(c.stats),
        actions: [
          FocusOnMount(
            builder: (context, node) => PlayerPillButton(
              label: l10n.playerOpenGuide,
              icon: PhosphorIconsFill.play,
              primary: true,
              focusNode: node,
              onPressed: () => _openGuide(_Guide.full),
            ),
          ),
        ],
      );
    }
    final media = c.media;
    final d = c.duration;
    return PlayerInfoPanel(
      title: [
        media?.title,
        if (media?.subtitle != null && _kind == PlayerKind.vod) media!.subtitle,
      ].whereType<String>().join(' · '),
      overview: media?.overview,
      image: media?.image,
      lead: d > Duration.zero ? shortRuntime(d) : null,
      chips: technicalChips(
        c.stats,
        fallback: media?.technical?.badges ?? const [],
      ),
      actions: [
        FocusOnMount(
          builder: (context, node) => PlayerPillButton(
            label: l10n.playerFromBeginning,
            icon: PhosphorIconsFill.play,
            primary: true,
            focusNode: node,
            onPressed: () {
              unawaited(c.startOver());
              _closeInfo();
            },
          ),
        ),
        if (c.nextEpisode != null)
          PlayerPillButton(
            label: l10n.playerNextEpisode,
            icon: PhosphorIconsFill.skipForward,
            onPressed: () {
              _closeInfo();
              unawaited(c.playNextEpisode());
            },
          ),
      ],
    );
  }
}

/// The controls layer: swallows pointer events while hidden and, on TV
/// ([scope] set), keeps focus out of the hidden controls. [scope] tells
/// whether focus is inside them.
class _ControlsGate extends StatelessWidget {
  const _ControlsGate({
    required this.ignoring,
    required this.scope,
    required this.child,
  });

  final bool ignoring;
  final FocusNode? scope;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = this.scope;
    if (scope == null) return IgnorePointer(ignoring: ignoring, child: child);
    return IgnorePointer(
      ignoring: ignoring,
      child: ExcludeFocus(
        excluding: ignoring,
        child: Focus(
          focusNode: scope,
          canRequestFocus: false,
          skipTraversal: true,
          child: child,
        ),
      ),
    );
  }
}
