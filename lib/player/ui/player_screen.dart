/// The full-window player: video, auto-hiding controls, menus,
/// overlays and the keyboard map, on top of a [PlayerController].
library;

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/clock.dart';
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
    setState(() => _controlsVisible = false);
  }

  void _hideControlsNow() {
    _hideTimer?.cancel();
    if (_controlsVisible) setState(() => _controlsVisible = false);
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
        _focus.requestFocus();
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
    _focus.requestFocus();
  }

  // ---------------------------------------------------------------------------
  // Panels and guides

  void _openInfo() {
    if (!mounted) return;
    _hideTimer?.cancel();
    setState(() {
      _infoOpen = true;
      _guide = _Guide.none;
    });
  }

  void _closeInfo() {
    setState(() => _infoOpen = false);
    _showControls();
    _focus.requestFocus();
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
    _focus.requestFocus();
  }

  Future<void> _openActionSheet() async {
    final channel = controller.channel;
    if (!_live || channel == null || _menuDepth > 0) return;
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
        _focus.requestFocus();
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
    if (shortcut == null) {
      if (event is KeyDownEvent) _showControls();
      return KeyEventResult.ignored;
    }
    _run(shortcut, repeat: event is KeyRepeatEvent);
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
                  child: IgnorePointer(
                    ignoring: !controlsShown,
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
