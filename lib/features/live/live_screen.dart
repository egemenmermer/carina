/// TV Live: the channels of the sidebar's category in the
/// horizontal (list + preview + NOW ON AIR + UPCOMING) or vertical (grid
/// with an in-card preview) layout, with the shared live preview, keyboard
/// navigation, the channel menu and number zapping.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/clock.dart';
import '../../app/shell/category_selection.dart';
import '../../app/shell/shell_state.dart';
import '../../app/time_format.dart';
import '../../core/core.dart';
import '../../data/db/database.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/live_repository.dart';
import '../../data/repositories/parental_service.dart';
import '../../data/repositories/repository_models.dart';
import '../../data/repositories/stream_url_resolver.dart';
import '../../data/settings/settings_store.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../player/engine/playback_engine.dart';
import '../../player/player_api.dart' show LivePlayRequest;
import 'layouts/live_layouts.dart';
import 'live_api.dart';
import 'live_externals.dart';
import 'preview/live_preview_controller.dart';
import 'preview/live_preview_view.dart';
import 'state/live_card_info.dart';
import 'state/live_providers.dart';
import 'widgets/channel_cards.dart';
import 'widgets/live_overlays.dart';
import 'widgets/now_on_air_panel.dart';
import 'widgets/upcoming_panel.dart';

/// TV Live for [playlistId]; follows the live category selected in the
/// shell's sidebar.
class LiveScreen extends ConsumerStatefulWidget {
  const LiveScreen({super.key, required this.playlistId});

  final int playlistId;

  @override
  ConsumerState<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends ConsumerState<LiveScreen> {
  int get _pid => widget.playlistId;
  CategoryScope get _scope => (playlistId: _pid, kind: SectionKind.live);

  late final LivePreviewController _preview;

  final Map<String, FocusNode> _nodes = {};
  final ScrollController _listScroll = ScrollController();
  final ScrollController _gridScroll = ScrollController();
  final LayerLink _tileLink = LayerLink();
  final FocusNode _screenFocus = FocusNode(
    debugLabel: 'live-screen',
    skipTraversal: true,
  );
  final FocusNode _pillFocus = FocusNode(debugLabel: 'live-category-pill');
  final FocusNode _upcomingFocus = FocusNode(debugLabel: 'live-upcoming');

  /// The list on screen and the category key it belongs to.
  List<ChannelView> _channels = const [];
  String? _listKey;
  List<ChannelView>? _reconciledList;
  String? _lastCategoryKey;

  /// The selected channel (white border, NOW ON AIR, preview target).
  String? _selectedId;
  int _selectedIndex = 0;
  String? _selectionKey;

  /// The card with keyboard focus.
  String? _focusedId;

  /// A channel to select once the list of [_pendingCategoryKey] arrives
  /// (number zapping into another category).
  String? _pendingSelectId;
  String? _pendingCategoryKey;
  bool _focusAfterLoad = true;
  bool _reconcileScheduled = false;
  Timer? _focusTimer;
  bool _playing = false;

  /// The channel in the preview (rebuilds the grid tile when it changes).
  String? _previewId;

  LiveGridMetrics _grid = LiveGridMetrics.of(1440);
  double _viewportHeight = 800;

  // Number zapping.
  String _zapDigits = '';
  String? _zapMessage;
  Timer? _zapTimer;

  late bool _lastPreviewEnabled;
  late bool _lastPreviewAudio;

  @override
  void initState() {
    super.initState();
    _preview = LivePreviewController(
      playlistId: _pid,
      factory: ref.read(playbackEngineFactoryProvider),
      resolver: ref.read(streamUrlResolverProvider),
      options: () =>
          livePreviewEngineOptions(ref.read(settingsStoreProvider), _pid),
    );
    _preview.status.addListener(_onPreviewStatus);
    _lastPreviewEnabled = _previewEnabled;
    _lastPreviewAudio = _previewAudio;
    ref.listenManual(settingsRevisionProvider, (_, _) => _onSettings());
    ref.listenManual(categorySidebarOpenProvider, (previous, open) {
      if (previous == true && !open) _focusSelected(afterFrame: true);
    });
    ref.listenManual(parentalSessionProvider, (_, _) => _syncMute());
  }

  @override
  void dispose() {
    _focusTimer?.cancel();
    _zapTimer?.cancel();
    _preview.status.removeListener(_onPreviewStatus);
    unawaited(_preview.dispose());
    for (final node in _nodes.values) {
      node.dispose();
    }
    _listScroll.dispose();
    _gridScroll.dispose();
    _screenFocus.dispose();
    _pillFocus.dispose();
    _upcomingFocus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------

  T _setting<T>(SettingKey<T> key) => ref.readSetting(key, playlistId: _pid);

  bool get _previewEnabled => _setting(PlaylistSettings.livePreview);
  bool get _focusMode => _setting(PlaylistSettings.previewStartsOn) != 'select';
  bool get _previewAudio => _setting(PlaylistSettings.previewAudio);
  bool get _vertical => _setting(PlaylistSettings.liveLayout) == 'vertical';
  int get _focusDelayMs =>
      _setting(PlaylistSettings.previewFocusDelayMs).clamp(0, 3000);

  void _onSettings() {
    if (!mounted) return;
    final enabled = _previewEnabled;
    if (enabled != _lastPreviewEnabled) {
      _lastPreviewEnabled = enabled;
      final selected = _find(_selectedId);
      if (!enabled) {
        unawaited(_preview.stop());
      } else if (selected != null && _focusMode) {
        unawaited(_preview.open(selected, muted: _mutedFor(selected)));
      }
    }
    final audio = _previewAudio;
    if (audio != _lastPreviewAudio) {
      _lastPreviewAudio = audio;
      _syncMute();
    }
  }

  // ---------------------------------------------------------------------------
  // Preview
  // ---------------------------------------------------------------------------

  void _onPreviewStatus() {
    final id = _preview.status.value.channelId;
    if (id != _previewId && mounted) setState(() => _previewId = id);
  }

  bool _lockedNow(ChannelView channel) => ref
      .read(parentalServiceProvider)
      .isLocked(channel, ref.read(parentalSessionProvider));

  bool _mutedFor(ChannelView channel) => !_previewAudio || _lockedNow(channel);

  void _syncMute() {
    if (!mounted) return;
    final current = _find(_preview.channelId);
    if (current == null) return;
    unawaited(_preview.setMuted(_mutedFor(current)));
  }

  // ---------------------------------------------------------------------------
  // Selection
  // ---------------------------------------------------------------------------

  ChannelView? _find(String? id) {
    if (id == null) return null;
    for (final c in _channels) {
      if (c.providerId == id) return c;
    }
    return null;
  }

  int _indexOf(String? id) =>
      id == null ? -1 : _channels.indexWhere((c) => c.providerId == id);

  /// Selects [channel]: white border, panels, remembered per category, and
  /// the preview when it is on and the selection came from the user (or
  /// the preview starts on focus).
  void _select(ChannelView channel, {required bool user}) {
    _focusTimer?.cancel();
    final index = _indexOf(channel.providerId);
    setState(() {
      _selectedId = channel.providerId;
      _selectedIndex = math.max(index, 0);
      _selectionKey = _listKey;
    });
    final key = _listKey;
    if (key != null) {
      ref
          .read(liveLastSelectionProvider(_pid).notifier)
          .remember(key, channel.providerId);
    }
    if (_previewEnabled && (user || _focusMode)) {
      final status = _preview.status.value;
      if (status.channelId != channel.providerId || status.hasError) {
        unawaited(_preview.open(channel, muted: _mutedFor(channel)));
      }
    } else if (_preview.channelId != null &&
        _preview.channelId != channel.providerId) {
      unawaited(_preview.stop());
    }
  }

  void _scheduleReconcile() {
    if (_reconcileScheduled) return;
    _reconcileScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _reconcile());
  }

  /// Keeps the selection valid for the list on screen: the pending number
  /// zap target, else the current channel, else the remembered one, else
  /// the channel at the old position (after hiding one) or the first.
  void _reconcile() {
    _reconcileScheduled = false;
    if (!mounted) return;
    _reconciledList = _channels;
    final list = _channels;
    final key = _listKey;
    if (list.isEmpty) {
      if (_preview.channelId != null) unawaited(_preview.stop());
      if (_selectedId != null) setState(() => _selectedId = null);
      // Keep the keyboard alive: the pill opens the sidebar.
      if (_focusAfterLoad && key == _lastCategoryKey) {
        _focusAfterLoad = false;
        if (ModalRoute.of(context)?.isCurrent ?? true) {
          _pillFocus.requestFocus();
        }
      }
      return;
    }
    var user = false;
    ChannelView? target;
    if (_pendingSelectId != null && key == _pendingCategoryKey) {
      target = _find(_pendingSelectId);
      user = target != null;
      _pendingSelectId = null;
      _pendingCategoryKey = null;
      _focusAfterLoad = true;
    }
    target ??= _selectionKey == key ? _find(_selectedId) : null;
    if (target == null) {
      final remembered = key == null
          ? null
          : ref.read(liveLastSelectionProvider(_pid))[key];
      target =
          _find(remembered) ??
          list[_selectionKey == key
              ? _selectedIndex.clamp(0, list.length - 1)
              : 0];
    }
    if (target.providerId != _selectedId || _selectionKey != key || user) {
      _select(target, user: user);
    } else {
      // Lock flags arrive with the list: a channel locked while it plays
      // goes silent at once.
      _syncMute();
    }
    // Focus moves to the selection once the list of the active category is
    // on screen, or when the focused card left the list (hidden channel).
    final focusLost = _focusedId != null && _find(_focusedId) == null;
    if ((_focusAfterLoad && key == _lastCategoryKey) || focusLost) {
      _focusAfterLoad = false;
      _focusedId = null;
      _focusChannel(target.providerId, animate: false);
    }
  }

  // ---------------------------------------------------------------------------
  // Cards
  // ---------------------------------------------------------------------------

  FocusNode _nodeFor(String id) =>
      _nodes.putIfAbsent(id, () => FocusNode(debugLabel: 'live-card-$id'));

  /// Disposes focus nodes of channels that left the list (after the frame
  /// that removed their cards).
  void _pruneNodes() {
    final keep = {for (final c in _channels) c.providerId};
    final stale = [
      for (final id in _nodes.keys)
        if (!keep.contains(id)) id,
    ];
    if (stale.isEmpty) return;
    final removed = [for (final id in stale) _nodes.remove(id)!];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final node in removed) {
        node.dispose();
      }
    });
  }

  void _onCardFocus(ChannelView channel, bool gained) {
    if (!gained) return;
    _focusedId = channel.providerId;
    final previewOn = _previewEnabled;
    if (previewOn && !_focusMode) return;
    final settled =
        channel.providerId == _selectedId &&
        (!previewOn || _preview.channelId == channel.providerId);
    _focusTimer?.cancel();
    if (settled) return;
    final delay = previewOn ? _focusDelayMs : 150;
    if (delay == 0) {
      _select(channel, user: false);
      return;
    }
    final id = channel.providerId;
    _focusTimer = Timer(Duration(milliseconds: delay), () {
      if (!mounted || _focusedId != id) return;
      final current = _find(id);
      if (current != null) _select(current, user: false);
    });
  }

  /// Click / Enter on a card: preview it, or play it when it is already
  /// the previewed (preview off: selected) channel.
  void _onCardActivate(ChannelView channel) {
    if (_zapDigits.isNotEmpty && _zapMessage == null) {
      unawaited(_commitZap());
      return;
    }
    _focusTimer?.cancel();
    if (_previewEnabled) {
      if (_preview.channelId == channel.providerId &&
          _selectedId == channel.providerId) {
        unawaited(_play(channel));
      } else {
        _select(channel, user: true);
      }
      return;
    }
    if (_vertical || _selectedId == channel.providerId) {
      unawaited(_play(channel));
    } else {
      _select(channel, user: true);
    }
  }

  void _onCardMenu(ChannelView channel, Offset position) {
    final category = ref.read(activeCategoryProvider(_scope)).value;
    unawaited(
      showChannelActions(
        context,
        playlistId: _pid,
        channelId: channel.providerId,
        position: position,
        categoryId: category?.providerId,
        listCategory: category?.ref,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Playback
  // ---------------------------------------------------------------------------

  /// Full-screen playback: PIN for locked channels, stop the preview, add
  /// to Last watched, open the player, resume the preview afterwards.
  Future<void> _play(ChannelView channel) async {
    if (_playing || !channel.playable) return;
    _playing = true;
    try {
      final externals = ref.read(liveExternalsProvider);
      if (_lockedNow(channel)) {
        final unlocked = await externals.ensureChannelUnlocked(
          context,
          playlistId: _pid,
          channelId: channel.providerId,
        );
        if (!unlocked || !mounted) return;
      }
      final resume = _preview.channelId != null;
      final zapIds = [for (final c in _channels) c.providerId];
      final categoryId = ref
          .read(activeCategoryProvider(_scope))
          .value
          ?.providerId;
      await _preview.stop();
      try {
        await ref
            .read(liveRepositoryProvider)
            .addLastWatched(_pid, channel.providerId);
      } on Object catch (e) {
        debugPrint('Last watched not updated: $e');
      }
      if (!mounted) return;
      await externals.openPlayer(
        context,
        LivePlayRequest(
          playlistId: _pid,
          channelId: channel.providerId,
          zapChannelIds: zapIds,
          categoryId: categoryId,
        ),
      );
      if (!mounted) return;
      final current = _find(_selectedId);
      if (resume && current != null && _previewEnabled) {
        unawaited(_preview.open(current, muted: _mutedFor(current)));
      }
      _focusSelected(afterFrame: true);
    } finally {
      _playing = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Focus and scrolling
  // ---------------------------------------------------------------------------

  void _focusSelected({bool afterFrame = false}) {
    void run() {
      if (!mounted) return;
      final id = _selectedId;
      if (id != null) _focusChannel(id, animate: false);
    }

    if (afterFrame) {
      WidgetsBinding.instance.addPostFrameCallback((_) => run());
    } else {
      run();
    }
  }

  /// Scrolls [id]'s card into view and gives it keyboard focus (only while
  /// TV Live is the current route: never steal focus from a dialog).
  void _focusChannel(String id, {bool animate = true}) {
    final index = _indexOf(id);
    if (index < 0) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    _ensureVisible(index, animate: animate);
    final node = _nodeFor(id);
    if (node.context != null) {
      node.requestFocus();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _nodes[id] == node) node.requestFocus();
      });
    }
  }

  void _ensureVisible(int index, {bool animate = true}) {
    final controller = _vertical ? _gridScroll : _listScroll;
    if (!controller.hasClients) return;
    final double top;
    final double bottom;
    if (_vertical) {
      final row = index ~/ _grid.columns;
      top = LiveGridMetrics.topPadding + row * _grid.rowExtent;
      bottom = top + _grid.cardHeight;
    } else {
      top = kLiveListTopPadding + index * kLiveListItemExtent;
      bottom = top + kLiveListCardHeight;
    }
    final position = controller.position;
    const margin = 24.0;
    double? target;
    if (top - margin < position.pixels) {
      target = index == 0 || (_vertical && index < _grid.columns)
          ? 0
          : top - margin;
    } else if (bottom + margin > position.pixels + position.viewportDimension) {
      target = bottom + margin - position.viewportDimension;
    }
    if (target == null) return;
    target = target.clamp(position.minScrollExtent, position.maxScrollExtent);
    final duration = KMotion.of(context, KDurations.scroll);
    if (!animate || duration == Duration.zero) {
      controller.jumpTo(target);
    } else {
      unawaited(
        controller.animateTo(target, duration: duration, curve: KMotion.enter),
      );
    }
  }

  void _moveFocus(int index) {
    if (_channels.isEmpty) return;
    final i = index.clamp(0, _channels.length - 1);
    _focusChannel(_channels[i].providerId);
  }

  void _openSidebar() => ref.read(categorySidebarOpenProvider.notifier).open();

  int get _listPageSize =>
      math.max(1, (_viewportHeight / kLiveListItemExtent).floor() - 1);

  int get _gridPageSize =>
      _grid.columns *
      math.max(1, (_viewportHeight / _grid.rowExtent).floor() - 1);

  bool _isDown(KeyEvent event) =>
      event is KeyDownEvent || event is KeyRepeatEvent;

  /// Arrow keys inside the channel list (horizontal layout).
  KeyEventResult _onListKey(FocusNode node, KeyEvent event) {
    if (!_isDown(event)) return KeyEventResult.ignored;
    final i = _indexOf(_focusedId);
    if (i < 0) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final last = _channels.length - 1;
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveFocus(math.min(i + 1, last));
    } else if (key == LogicalKeyboardKey.arrowUp) {
      if (i == 0) {
        _pillFocus.requestFocus();
      } else {
        _moveFocus(i - 1);
      }
    } else if (key == LogicalKeyboardKey.pageDown) {
      _moveFocus(i + _listPageSize);
    } else if (key == LogicalKeyboardKey.pageUp) {
      _moveFocus(i - _listPageSize);
    } else if (key == LogicalKeyboardKey.home) {
      _moveFocus(0);
    } else if (key == LogicalKeyboardKey.end) {
      _moveFocus(last);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      _openSidebar();
    } else if (key == LogicalKeyboardKey.arrowRight) {
      if (_upcomingFocus.context != null) _upcomingFocus.requestFocus();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  /// Arrow keys inside the grid (vertical layout).
  KeyEventResult _onGridKey(FocusNode node, KeyEvent event) {
    if (!_isDown(event)) return KeyEventResult.ignored;
    final i = _indexOf(_focusedId);
    if (i < 0) return KeyEventResult.ignored;
    final cols = _grid.columns;
    final last = _channels.length - 1;
    final col = i % cols;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (col == 0) {
        _openSidebar();
      } else {
        _moveFocus(i - 1);
      }
    } else if (key == LogicalKeyboardKey.arrowRight) {
      if (col < cols - 1 && i < last) _moveFocus(i + 1);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      if (i < cols) {
        _pillFocus.requestFocus();
      } else {
        _moveFocus(i - cols);
      }
    } else if (key == LogicalKeyboardKey.arrowDown) {
      final lastRow = last ~/ cols;
      if (i ~/ cols < lastRow) _moveFocus(math.min(i + cols, last));
    } else if (key == LogicalKeyboardKey.pageDown) {
      _moveFocus(i + _gridPageSize);
    } else if (key == LogicalKeyboardKey.pageUp) {
      _moveFocus(i - _gridPageSize);
    } else if (key == LogicalKeyboardKey.home) {
      _moveFocus(0);
    } else if (key == LogicalKeyboardKey.end) {
      _moveFocus(last);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  /// Down from the category pill returns to the selected card; Left opens
  /// the sidebar.
  KeyEventResult _onPillKey(FocusNode node, KeyEvent event) {
    if (!_isDown(event)) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _focusSelected();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _openSidebar();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Left from the UPCOMING rows returns to the selected card.
  KeyEventResult _onUpcomingKey(FocusNode node, KeyEvent event) {
    if (!_isDown(event)) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _focusSelected();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---------------------------------------------------------------------------
  // Number zapping
  // ---------------------------------------------------------------------------

  static final Map<LogicalKeyboardKey, String> _digitKeys = {
    LogicalKeyboardKey.digit0: '0',
    LogicalKeyboardKey.digit1: '1',
    LogicalKeyboardKey.digit2: '2',
    LogicalKeyboardKey.digit3: '3',
    LogicalKeyboardKey.digit4: '4',
    LogicalKeyboardKey.digit5: '5',
    LogicalKeyboardKey.digit6: '6',
    LogicalKeyboardKey.digit7: '7',
    LogicalKeyboardKey.digit8: '8',
    LogicalKeyboardKey.digit9: '9',
    LogicalKeyboardKey.numpad0: '0',
    LogicalKeyboardKey.numpad1: '1',
    LogicalKeyboardKey.numpad2: '2',
    LogicalKeyboardKey.numpad3: '3',
    LogicalKeyboardKey.numpad4: '4',
    LogicalKeyboardKey.numpad5: '5',
    LogicalKeyboardKey.numpad6: '6',
    LogicalKeyboardKey.numpad7: '7',
    LogicalKeyboardKey.numpad8: '8',
    LogicalKeyboardKey.numpad9: '9',
  };

  static const Duration _zapDelay = Duration(milliseconds: 1500);

  /// Digits typed anywhere on TV Live (number zapping), plus Backspace /
  /// Esc / Enter while the OSD shows.
  KeyEventResult _onScreenKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final digit = _digitKeys[key];
    final keyboard = HardwareKeyboard.instance;
    if (digit != null) {
      if (!_setting(PlaylistSettings.numberZapping) ||
          keyboard.isControlPressed ||
          keyboard.isMetaPressed ||
          keyboard.isAltPressed) {
        return KeyEventResult.ignored;
      }
      _addZapDigit(digit);
      return KeyEventResult.handled;
    }
    if (_zapDigits.isEmpty || _zapMessage != null) {
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.backspace) {
      setState(
        () => _zapDigits = _zapDigits.substring(0, _zapDigits.length - 1),
      );
      _zapTimer?.cancel();
      if (_zapDigits.isNotEmpty) _zapTimer = Timer(_zapDelay, _commitZapSync);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      _zapTimer?.cancel();
      setState(() => _zapDigits = '');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      unawaited(_commitZap());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _addZapDigit(String digit) {
    _zapTimer?.cancel();
    setState(() {
      if (_zapMessage != null) {
        _zapDigits = '';
        _zapMessage = null;
      }
      if (_zapDigits.length < 5) _zapDigits += digit;
    });
    _zapTimer = Timer(_zapDelay, _commitZapSync);
  }

  void _commitZapSync() => unawaited(_commitZap());

  /// Tunes the channel whose number was typed (`channelByNumber`).
  Future<void> _commitZap() async {
    _zapTimer?.cancel();
    final digits = _zapDigits;
    if (digits.isEmpty || _zapMessage != null) return;
    setState(() => _zapDigits = '');
    final number = int.tryParse(digits);
    if (number == null || number <= 0) return;
    final reveal = ref.read(parentalSessionProvider).allUnlockedFor(_pid);
    ChannelView? channel;
    try {
      channel = await ref
          .read(liveRepositoryProvider)
          .channelByNumber(_pid, number, revealLocked: reveal);
    } on Object {
      channel = null;
    }
    if (!mounted) return;
    if (channel == null) {
      final message = L10n.of(context).liveChannelNotFound(number);
      setState(() {
        _zapDigits = digits;
        _zapMessage = message;
      });
      _zapTimer = Timer(_zapDelay, () {
        if (!mounted) return;
        setState(() {
          _zapDigits = '';
          _zapMessage = null;
        });
      });
      return;
    }
    _tuneTo(channel);
  }

  /// Selects [channel] (with the preview) and focuses it; switches the
  /// category first when the channel is not in the list on screen.
  void _tuneTo(ChannelView channel) {
    final inList = _find(channel.providerId);
    if (inList != null) {
      _select(inList, user: true);
      _focusChannel(inList.providerId);
      return;
    }
    final categoryId = channel.row.categoryId;
    if (categoryId == null) {
      unawaited(_play(channel));
      return;
    }
    final category = ProviderCategory(categoryId);
    _pendingSelectId = channel.providerId;
    _pendingCategoryKey = category.key;
    ref.read(selectedCategoryProvider(_scope).notifier).select(category);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final active = ref.watch(activeCategoryProvider(_scope));
    return Focus(
      focusNode: _screenFocus,
      onKeyEvent: _onScreenKey,
      child: Stack(
        children: [
          Positioned.fill(
            child: active.when(
              loading: () => const KLoadingState(),
              error: (e, _) => KErrorState(
                message: l10n.liveLoadError,
                onRetry: () => ref.invalidate(categoriesProvider(_scope)),
              ),
              data: (category) => category == null
                  ? KEmptyState(
                      icon: PhosphorIconsLight.television,
                      title: l10n.liveNoChannelsTitle,
                      message: l10n.liveNoChannels,
                    )
                  : _category(context, category),
            ),
          ),
          if (_zapDigits.isNotEmpty)
            Positioned(
              top: 18,
              right: 28,
              child: LiveNumberOsd(digits: _zapDigits, message: _zapMessage),
            ),
        ],
      ),
    );
  }

  Widget _category(BuildContext context, CategoryView category) {
    final l10n = L10n.of(context);
    final key = category.ref.key;
    if (key != _lastCategoryKey) {
      if (_lastCategoryKey != null) _focusAfterLoad = true;
      _lastCategoryKey = key;
    }
    final args = (playlistId: _pid, category: category.ref);
    final list = ref.watch(channelsProvider(args));
    final value = list.value;
    if (value != null && !list.isLoading) {
      _channels = value;
      _listKey = key;
    } else if (value != null && _listKey == null) {
      _channels = value;
      _listKey = key;
    }
    if (list.hasError && value == null) {
      return KErrorState(
        message: l10n.liveLoadError,
        onRetry: () => ref.invalidate(channelsProvider(args)),
      );
    }
    if (_listKey == null) return const KLoadingState();
    if (!identical(_reconciledList, _channels) ||
        (_focusAfterLoad && _listKey == key)) {
      _scheduleReconcile();
      _pruneNodes();
    }
    final pill = Focus(
      onKeyEvent: _onPillKey,
      skipTraversal: true,
      canRequestFocus: false,
      child: _PillHost(focusNode: _pillFocus, category: category),
    );
    if (_channels.isEmpty) {
      return Stack(
        children: [
          Positioned.fill(
            // An empty list of another category: the new one is loading.
            child: _listKey == key
                ? _emptyCategory(l10n, category)
                : const KLoadingState(),
          ),
          Positioned(top: 6, left: 0, right: 0, child: Center(child: pill)),
        ],
      );
    }
    final listArgs = (
      playlistId: _pid,
      category: CategoryRef.tryParse(_listKey!) ?? category.ref,
    );
    final nowNext = ref.watch(liveListNowNextProvider(listArgs)).value;
    final xtream = ref.watch(liveIsXtreamProvider(_pid));
    final now = ref.watch(minuteClockProvider).value ?? DateTime.now();
    final vertical =
        ref.watchSetting(PlaylistSettings.liveLayout, playlistId: _pid) ==
        'vertical';
    final previewEnabled = ref.watchSetting(
      PlaylistSettings.livePreview,
      playlistId: _pid,
    );
    final sizeIndicator =
        ref.watchSetting(
          PlaylistSettings.resolutionIndicator,
          playlistId: _pid,
        ) ==
        'size';
    final session = ref.watch(parentalSessionProvider);
    final parental = ref.read(parentalServiceProvider);
    final selected = _find(_selectedId) ?? _channels.first;
    final selectedLocked = parental.isLocked(selected, session);

    Widget cardInfo(ChannelView c, Widget Function(LiveCardInfo) builder) =>
        _CardInfoHost(
          playlistId: _pid,
          channel: c,
          listNowNext: nowNext,
          xtream: xtream,
          now: now,
          builder: builder,
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportHeight = constraints.maxHeight;
        if (vertical) {
          _grid = LiveGridMetrics.of(constraints.maxWidth);
          return _verticalLayout(
            pill: pill,
            cardInfo: cardInfo,
            previewEnabled: previewEnabled,
            sizeIndicator: sizeIndicator,
            session: session,
          );
        }
        final logoSize = LiveHorizontalLayout.logoSize(
          LiveHorizontalLayout.listWidth(constraints.maxWidth),
        );
        return LiveHorizontalLayout(
          pill: pill,
          list: Focus(
            onKeyEvent: _onListKey,
            skipTraversal: true,
            canRequestFocus: false,
            child: ListView.builder(
              controller: _listScroll,
              padding: const EdgeInsets.fromLTRB(
                kLiveListSidePadding,
                kLiveListTopPadding,
                kLiveListSidePadding,
                kLiveListBottomPadding,
              ),
              itemExtent: kLiveListItemExtent,
              itemCount: _channels.length,
              itemBuilder: (context, i) {
                final c = _channels[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: kLiveListGap),
                  child: cardInfo(
                    c,
                    (info) => LiveListCard(
                      key: ValueKey('live-card-${c.providerId}'),
                      channel: c,
                      info: info,
                      logoSize: logoSize,
                      selected: c.providerId == _selectedId,
                      focusNode: _nodeFor(c.providerId),
                      onTap: () => _onCardActivate(c),
                      onFocusChange: (g) => _onCardFocus(c, g),
                      onContextMenu: (pos) => _onCardMenu(c, pos),
                    ),
                  ),
                );
              },
            ),
          ),
          preview: LivePreviewView(
            controller: _preview,
            channel: selected,
            locked: selectedLocked,
            previewEnabled: previewEnabled,
            sizeIndicator: sizeIndicator,
            onActivate: () => _onCardActivate(selected),
            onContextMenu: (pos) => _onCardMenu(selected, pos),
          ),
          nowOnAir: _NowOnAirHost(playlistId: _pid, channel: selected),
          upcoming: Focus(
            onKeyEvent: _onUpcomingKey,
            skipTraversal: true,
            canRequestFocus: false,
            child: _UpcomingHost(
              playlistId: _pid,
              channel: selected,
              firstRowFocusNode: _upcomingFocus,
            ),
          ),
        );
      },
    );
  }

  Widget _verticalLayout({
    required Widget pill,
    required Widget Function(ChannelView, Widget Function(LiveCardInfo))
    cardInfo,
    required bool previewEnabled,
    required bool sizeIndicator,
    required ParentalSessionState session,
  }) {
    final grid = _grid;
    final previewId = previewEnabled ? _previewId : null;
    final previewed = _find(previewId);
    Widget? tile;
    if (previewed != null) {
      final size = grid.tileSize;
      // Edge columns keep the tile inside the grid.
      final column = _indexOf(previewed.providerId) % grid.columns;
      final anchor = column == 0
          ? Alignment.centerLeft
          : column == grid.columns - 1
          ? Alignment.centerRight
          : Alignment.center;
      final locked = ref
          .read(parentalServiceProvider)
          .isLocked(previewed, session);
      tile = Positioned(
        left: 0,
        top: 0,
        child: CompositedTransformFollower(
          link: _tileLink,
          showWhenUnlinked: false,
          targetAnchor: anchor,
          followerAnchor: anchor,
          child: SizedBox.fromSize(
            size: size,
            child: _PreviewTile(
              key: ValueKey('live-tile-${previewed.providerId}'),
              child: LivePreviewView(
                controller: _preview,
                channel: previewed,
                locked: locked,
                compact: true,
                sizeIndicator: sizeIndicator,
                borderRadius: KRadii.card,
                onActivate: () => _onCardActivate(previewed),
                onContextMenu: (pos) => _onCardMenu(previewed, pos),
              ),
            ),
          ),
        ),
      );
    }
    return LiveVerticalLayout(
      pill: pill,
      tile: tile,
      grid: Focus(
        onKeyEvent: _onGridKey,
        skipTraversal: true,
        canRequestFocus: false,
        child: GridView.builder(
          controller: _gridScroll,
          padding: const EdgeInsets.fromLTRB(
            LiveGridMetrics.sidePadding,
            LiveGridMetrics.topPadding,
            LiveGridMetrics.sidePadding,
            LiveGridMetrics.bottomPadding,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: grid.columns,
            mainAxisSpacing: LiveGridMetrics.gap,
            crossAxisSpacing: LiveGridMetrics.gap,
            mainAxisExtent: grid.cardHeight,
          ),
          itemCount: _channels.length,
          itemBuilder: (context, i) {
            final c = _channels[i];
            Widget card = cardInfo(
              c,
              (info) => LiveGridCard(
                key: ValueKey('live-card-${c.providerId}'),
                channel: c,
                info: info,
                selected: c.providerId == _selectedId,
                focusNode: _nodeFor(c.providerId),
                onTap: () => _onCardActivate(c),
                onFocusChange: (g) => _onCardFocus(c, g),
                onContextMenu: (pos) => _onCardMenu(c, pos),
              ),
            );
            if (c.providerId == previewed?.providerId) {
              card = CompositedTransformTarget(link: _tileLink, child: card);
            }
            return card;
          },
        ),
      ),
    );
  }

  Widget _emptyCategory(L10n l10n, CategoryView category) {
    final (title, message) = switch (category.ref) {
      FavoritesCategory() => (
        l10n.liveEmptyFavoritesTitle,
        l10n.liveEmptyFavorites,
      ),
      LastWatchedCategory() => (
        l10n.liveEmptyLastWatchedTitle,
        l10n.liveEmptyLastWatched,
      ),
      RecentlyAddedCategory() => (
        l10n.liveEmptyCategoryTitle,
        l10n.liveEmptyRecent,
      ),
      _ => (l10n.liveEmptyCategoryTitle, l10n.liveEmptyCategory),
    };
    return KEmptyState(
      icon: switch (category.ref) {
        FavoritesCategory() => PhosphorIconsLight.star,
        LastWatchedCategory() => PhosphorIconsLight.clockCounterClockwise,
        _ => PhosphorIconsLight.television,
      },
      title: title,
      message: message,
      actionLabel: l10n.liveChooseCategory,
      actionIcon: PhosphorIconsLight.list,
      onAction: _openSidebar,
    );
  }
}

// -----------------------------------------------------------------------------
// Hosts (watch their own providers so the whole screen does not rebuild)
// -----------------------------------------------------------------------------

class _PillHost extends ConsumerWidget {
  const _PillHost({required this.focusNode, required this.category});

  final FocusNode focusNode;
  final CategoryView category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LiveCategoryPill(
      category: category,
      focusNode: focusNode,
      onTap: () => ref.read(categorySidebarOpenProvider.notifier).open(),
    );
  }
}

class _CardInfoHost extends ConsumerWidget {
  const _CardInfoHost({
    required this.playlistId,
    required this.channel,
    required this.listNowNext,
    required this.xtream,
    required this.now,
    required this.builder,
  });

  final int playlistId;
  final ChannelView channel;
  final Map<String, NowNext>? listNowNext;
  final bool xtream;
  final DateTime now;
  final Widget Function(LiveCardInfo info) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nowNext = watchCardNowNext(
      ref,
      playlistId: playlistId,
      channel: channel,
      listNowNext: listNowNext,
      xtream: xtream,
    );
    return builder(
      liveCardInfo(
        programme: nowNext.now,
        now: now,
        format: ref.watch(timeFormatProvider),
        noEpgLabel: L10n.of(context).liveEpgNotAvailable,
      ),
    );
  }
}

class _NowOnAirHost extends ConsumerWidget {
  const _NowOnAirHost({required this.playlistId, required this.channel});

  final int playlistId;
  final ChannelView channel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nowNext = ref
        .watch(
          liveChannelNowNextProvider((
            playlistId: playlistId,
            channel: channel,
          )),
        )
        .value;
    return NowOnAirPanel(
      channel: channel,
      programme: nowNext?.now,
      format: ref.watch(timeFormatProvider),
      epgSource: ref.watch(liveEpgSourceProvider(playlistId)).value,
    );
  }
}

class _UpcomingHost extends ConsumerWidget {
  const _UpcomingHost({
    required this.playlistId,
    required this.channel,
    required this.firstRowFocusNode,
  });

  final int playlistId;
  final ChannelView channel;
  final FocusNode firstRowFocusNode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (playlistId: playlistId, channel: channel);
    final programmes = ref.watch(liveUpcomingProvider(args)).value;
    final reminders = ref.watch(
      liveReminderStartsProvider((
        playlistId: playlistId,
        channelId: channel.providerId,
      )),
    );
    final now = ref.watch(minuteClockProvider).value ?? DateTime.now();
    final externals = ref.read(liveExternalsProvider);
    return UpcomingPanel(
      programmes: programmes,
      reminderStarts: reminders,
      now: now,
      format: ref.watch(timeFormatProvider),
      firstRowFocusNode: firstRowFocusNode,
      onOpen: (p) => externals.showProgrammeDetails(
        context,
        playlistId: playlistId,
        channelId: channel.providerId,
        startUtc: p.start,
      ),
      onToggleReminder: (p) => externals.toggleReminder(
        context,
        playlistId: playlistId,
        channelId: channel.providerId,
        startUtc: p.start,
      ),
    );
  }
}

/// The white-bordered frame of the grid preview tile; fades and scales in.
class _PreviewTile extends StatelessWidget {
  const _PreviewTile({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: KMotion.of(context, const Duration(milliseconds: 180)),
      curve: KMotion.enter,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.scale(scale: 0.94 + 0.06 * t, child: child),
      ),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(KRadii.card),
          border: Border.all(color: KColors.focusRing, width: 3),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KRadii.card),
            boxShadow: KShadows.focus,
          ),
          child: child,
        ),
      ),
    );
  }
}
