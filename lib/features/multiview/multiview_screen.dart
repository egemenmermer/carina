import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/platform/form_factor.dart';
import '../../app/platform/screen_awake.dart';
import '../../app/router.dart' show MainTab, Routes;
import '../../core/core.dart';
import '../../data/repositories/live_repository.dart';
import '../../data/repositories/repository_models.dart';
import '../../data/repositories/stream_url_resolver.dart';
import '../../data/settings/settings_store.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../player/engine/playback_engine.dart';
import '../../player/ui/player_options.dart';
import '../parental/parental_api.dart';
import 'channel_picker.dart';
import 'multiview_api.dart' show confirmExtraStream;
import 'multiview_layout.dart';
import 'multiview_state.dart';

/// Multi-channel: up to four live channels at once, each in
/// its own low-latency engine. Only the focused tile plays sound (white
/// border + speaker icon). Click or arrows focus a tile, double-click or
/// Enter shows it full screen inside multi-channel (Esc returns), and a
/// hover toolbar per tile changes the channel, swaps it with the main tile
/// or closes it. The layout picker (1 + 1, 2 × 2, 1 + 3) is in the top bar.
///
/// On a TV the arrows walk tiles, empty slots and the top bar; Down from a
/// tile reaches its toolbar (shown while the tile is focused, bottom right)
/// and Up from the top row reaches the top bar.
class MultiviewScreen extends ConsumerStatefulWidget {
  const MultiviewScreen({
    super.key,
    required this.playlistId,
    this.initialLayout,
    this.initialChannelIds = const [],
  });

  final int playlistId;

  /// Layout to start with (capture mode); the session's layout otherwise.
  final MultiviewLayout? initialLayout;

  /// Channels to open when the session is empty (capture mode, tests).
  final List<String> initialChannelIds;

  @override
  ConsumerState<MultiviewScreen> createState() => MultiviewScreenState();
}

/// An engine of one tile.
class _TileEngine {
  _TileEngine(this.engine);

  final PlaybackEngine engine;
  late final Widget video = engine.buildVideo();
  String? channelId;
  ChannelView? channel;
  bool? muted;
  String? error;
  StreamSubscription<EngineState>? sub;
}

class MultiviewScreenState extends ConsumerState<MultiviewScreen> {
  final FocusNode _focus = FocusNode(debugLabel: 'multiview');

  /// Parent of the top bar controls (TV: Up from the top row enters it).
  final FocusNode _barNode = FocusNode(
    debugLabel: 'multiview bar',
    canRequestFocus: false,
    skipTraversal: true,
  );

  /// Parent of the empty-state content (TV: nothing to focus but its button).
  final FocusNode _bodyNode = FocusNode(
    debugLabel: 'multiview body',
    canRequestFocus: false,
    skipTraversal: true,
  );

  /// Per-tile toolbar parents and per-slot nodes (TV only).
  final Map<int, FocusNode> _toolbarNodes = {};
  final Map<int, FocusNode> _slotNodes = {};
  final Map<int, _TileEngine> _engines = {};
  int? _hoveredTile;
  bool _pickerOpen = false;
  bool _disposed = false;

  int get _pid => widget.playlistId;

  late final ScreenAwake _screenAwake;

  bool get _tv => ref.read(formFactorProvider).isTv;

  MultiviewSessionNotifier get _notifier =>
      ref.read(multiviewSessionProvider(_pid).notifier);

  /// Engines by tile id (tests).
  Map<int, PlaybackEngine> get engines => {
    for (final e in _engines.entries) e.key: e.value.engine,
  };

  @override
  void initState() {
    super.initState();
    _screenAwake = ref.read(screenAwakeProvider)..hold(this);
    // The tile ring follows whether the tiles or a control hold focus.
    _focus.addListener(_onFocusChanged);
    // Providers cannot change while the tree builds: apply the initial
    // channels / layout right after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final session = ref.read(multiviewSessionProvider(_pid));
      if (widget.initialChannelIds.isNotEmpty && session.isEmpty) {
        _notifier.replace(
          widget.initialChannelIds,
          layout: widget.initialLayout,
        );
      } else if (widget.initialLayout != null) {
        _notifier.setLayout(widget.initialLayout!);
      }
      _enterBody();
      _sync(ref.read(multiviewSessionProvider(_pid)));
    });
  }

  void _onFocusChanged() {
    if (mounted && _tv) setState(() {});
  }

  @override
  void dispose() {
    _disposed = true;
    _screenAwake.release(this);
    for (final e in _engines.values) {
      unawaited(e.sub?.cancel());
      unawaited(e.engine.dispose());
    }
    _engines.clear();
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
    _barNode.dispose();
    _bodyNode.dispose();
    for (final n in [..._toolbarNodes.values, ..._slotNodes.values]) {
      n.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Engines

  EngineOptions _options() => playerEngineOptions(
    ref.read(settingsStoreProvider),
    _pid,
    PlayerKind.live,
  ).copyWith(profile: EngineProfile.lowLatency, muted: true);

  void _sync(MultiviewSession s) {
    if (_disposed) return;
    final ids = {for (final t in s.tiles) t.id};
    for (final id in _engines.keys.toList()) {
      if (!ids.contains(id)) {
        final e = _engines.remove(id)!;
        unawaited(e.sub?.cancel());
        unawaited(e.engine.dispose());
      }
    }
    for (final tile in s.tiles) {
      var e = _engines[tile.id];
      if (e == null) {
        final engine = ref
            .read(playbackEngineFactoryProvider)
            .create(options: _options());
        e = _engines[tile.id] = _TileEngine(engine);
        final created = e;
        created.sub = engine.stateStream.listen((_) {
          if (mounted) setState(() {});
        });
      }
      if (e.channelId != tile.channelId) {
        e.channelId = tile.channelId;
        unawaited(_open(e, tile.channelId));
      }
    }
    _routeAudio(s);
    if (mounted) setState(() {});
  }

  /// Only the focused tile has sound.
  void _routeAudio(MultiviewSession s) {
    for (var i = 0; i < s.tiles.length; i++) {
      final e = _engines[s.tiles[i].id];
      if (e == null) continue;
      final muted = i != clampIndex(s.focused, s.tiles.length);
      if (e.muted != muted) {
        e.muted = muted;
        unawaited(e.engine.setMuted(muted));
      }
    }
  }

  Future<void> _open(_TileEngine e, String channelId) async {
    final live = ref.read(liveRepositoryProvider);
    final resolver = ref.read(streamUrlResolverProvider);
    e.error = null;
    final channel = await live.channel(_pid, channelId);
    if (_disposed || e.channelId != channelId) return;
    e.channel = channel;
    if (channel == null) {
      e.error = '';
      if (mounted) setState(() {});
      return;
    }
    try {
      final r = await resolver.live(_pid, channel.row);
      if (_disposed || e.channelId != channelId) return;
      await e.engine.open(
        PlaybackSource(
          url: r.url,
          headers: r.headers,
          userAgent: r.userAgent,
          referer: r.referer,
          isLive: true,
          title: channel.displayName,
        ),
      );
    } on StreamResolveException {
      e.error = '';
    }
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------------------
  // Actions

  Future<void> _addChannel() async {
    final session = ref.read(multiviewSessionProvider(_pid));
    final l10n = L10n.of(context);
    final toasts = ref.read(toastControllerProvider);
    if (session.isFull) {
      toasts.show(l10n.multiviewMaxReached(session.maxTiles));
      return;
    }
    final id = await _pick(
      exclude: {for (final t in session.tiles) t.channelId},
    );
    if (id == null || !mounted) return;
    if (!await _unlock(id) || !mounted) return;
    if (ref.read(multiviewSessionProvider(_pid)).tiles.length >= 2) {
      final ok = await confirmExtraStream(context, playlistId: _pid);
      if (!ok || !mounted) return;
    }
    if (_notifier.add(id)) toasts.show(l10n.multiviewAdded);
    _enterBody();
  }

  Future<void> _changeChannel(int index) async {
    final session = ref.read(multiviewSessionProvider(_pid));
    final id = await _pick(
      exclude: {for (final t in session.tiles) t.channelId},
    );
    if (id == null || !mounted) return;
    if (!await _unlock(id) || !mounted) return;
    _notifier.changeChannel(index, id);
    _enterBody();
  }

  Future<bool> _unlock(String channelId) =>
      ensureChannelUnlocked(context, playlistId: _pid, channelId: channelId);

  Future<String?> _pick({Set<String> exclude = const {}}) async {
    if (_pickerOpen) return null;
    _pickerOpen = true;
    try {
      return await showMultiviewChannelPicker(
        context,
        playlistId: _pid,
        exclude: exclude,
      );
    } finally {
      _pickerOpen = false;
    }
  }

  void _closeTile(int index) {
    _notifier.close(index);
    ref.read(toastControllerProvider).show(L10n.of(context).multiviewClosed);
    _enterBody();
  }

  void _leave() {
    final navigator = Navigator.of(context);
    if (GoRouter.maybeOf(context) == null || navigator.canPop()) {
      unawaited(navigator.maybePop());
      return;
    }
    GoRouter.of(context).go(Routes.tab(_pid, MainTab.live));
  }

  FocusNode _toolbarNode(int tileId) => _toolbarNodes.putIfAbsent(
    tileId,
    () => FocusNode(
      debugLabel: 'multiview toolbar $tileId',
      canRequestFocus: false,
      skipTraversal: true,
    ),
  );

  FocusNode _slotNode(int slot) => _slotNodes.putIfAbsent(
    slot,
    () => FocusNode(debugLabel: 'multiview slot $slot'),
  );

  /// Moves focus into the tiles (or the empty state's button).
  void _enterBody() {
    final empty = ref.read(multiviewSessionProvider(_pid)).tiles.isEmpty;
    if (!empty || !_tv) {
      _focus.requestFocus();
      return;
    }
    (_bodyNode.traversalDescendants.firstOrNull ?? _focus).requestFocus();
  }

  bool _focusFirstOf(FocusNode parent) {
    final first = parent.traversalDescendants.firstOrNull;
    if (first == null) return false;
    first.requestFocus();
    return true;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final s = ref.read(multiviewSessionProvider(_pid));
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (s.fullTile != null) {
        _notifier.setFullTile(null);
      } else {
        _leave();
      }
      return KeyEventResult.handled;
    }
    final direction = switch (key) {
      LogicalKeyboardKey.arrowLeft => TraversalDirection.left,
      LogicalKeyboardKey.arrowRight => TraversalDirection.right,
      LogicalKeyboardKey.arrowUp => TraversalDirection.up,
      LogicalKeyboardKey.arrowDown => TraversalDirection.down,
      _ => null,
    };
    if (direction != null && _tv) return _onTvArrow(node, s, direction);
    if (s.tiles.isEmpty) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      // A held key repeats: toggle once.
      if (event is KeyDownEvent) {
        _notifier.setFullTile(s.fullTile == null ? s.focused : null);
      }
      return KeyEventResult.handled;
    }
    if (direction != null && s.fullTile == null) {
      final rects = multiviewRects(s.layout, const Size(1600, 900));
      final visible = rects.take(s.tiles.length).toList();
      _notifier.focus(neighborTile(visible, s.focused, direction));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// D-pad on a TV. The root node keeps the tile cursor; the top bar, the
  /// tile toolbars and the empty slots hold real focus and route back here
  /// through the arrows they leave unhandled.
  KeyEventResult _onTvArrow(
    FocusNode node,
    MultiviewSession s,
    TraversalDirection direction,
  ) {
    final down = direction == TraversalDirection.down;
    final up = direction == TraversalDirection.up;
    if (_barNode.hasFocus) {
      if (down) _enterBody();
      return down ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    if (s.tiles.isEmpty) {
      // Initial focus sits on the root: step into the empty state's button
      // or up to the top bar.
      if (!node.hasPrimaryFocus) return KeyEventResult.ignored;
      if (up) {
        _focusFirstOf(_barNode);
      } else {
        _enterBody();
      }
      return KeyEventResult.handled;
    }
    final tiles = s.tiles.length;
    final focused = clampIndex(s.focused, tiles);
    if (s.tiles.any((t) => _toolbarNodes[t.id]?.hasFocus ?? false)) {
      if (up) _focus.requestFocus();
      return up ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    var current = focused;
    if (!node.hasPrimaryFocus) {
      final slot = _slotNodes.entries
          .where((e) => e.value.hasFocus)
          .map((e) => e.key)
          .firstOrNull;
      if (slot == null) return KeyEventResult.ignored;
      current = slot;
    }
    final full = s.fullTile;
    if (full != null && full < tiles) {
      if (up) _focusFirstOf(_barNode);
      if (down) _focusFirstOf(_toolbarNode(s.tiles[full].id));
      return KeyEventResult.handled;
    }
    final rects = multiviewRects(s.layout, const Size(1600, 900));
    final target = neighborTile(rects, current, direction);
    if (target != current) {
      if (target < tiles) {
        _notifier.focus(target);
        _focus.requestFocus();
      } else {
        _slotNode(target).requestFocus();
      }
    } else if (up) {
      _focusFirstOf(_barNode);
    } else if (down && current < tiles) {
      _focusFirstOf(_toolbarNode(s.tiles[current].id));
    }
    return KeyEventResult.handled;
  }

  // ---------------------------------------------------------------------------
  // Build

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final session = ref.watch(multiviewSessionProvider(_pid));
    ref.listen(multiviewSessionProvider(_pid), (previous, next) {
      _sync(next);
    });
    // "Add channel" from the live player: open the picker once.
    if (session.pickerRequested && !_pickerOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!ref.read(multiviewSessionProvider(_pid)).pickerRequested) return;
        _notifier.requestPicker(false);
        unawaited(_addChannel());
      });
    }
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: ColoredBox(
        color: KColors.bg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Focus(
              focusNode: _barNode,
              canRequestFocus: false,
              skipTraversal: true,
              child: _TopBar(
                session: session,
                onLayout: _notifier.setLayout,
                onAdd: () => unawaited(_addChannel()),
                onClose: _leave,
              ),
            ),
            Expanded(
              child: Focus(
                focusNode: _bodyNode,
                canRequestFocus: false,
                skipTraversal: true,
                child: session.isEmpty
                  ? KEmptyState(
                      icon: PhosphorIconsLight.squaresFour,
                      title: l10n.multiviewEmptyTitle(session.maxTiles),
                      message: l10n.multiviewEmptyMessage,
                      actionLabel: l10n.multiviewAddChannel,
                      actionIcon: PhosphorIconsBold.plus,
                      onAction: () => unawaited(_addChannel()),
                    )
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                      child: LayoutBuilder(
                        builder: (context, constraints) =>
                            _buildTiles(session, constraints.biggest),
                      ),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTiles(MultiviewSession s, Size area) {
    final full = s.fullTile;
    if (full != null && full < s.tiles.length) {
      final rect = _contain(area);
      return Stack(
        children: [
          Positioned.fromRect(
            rect: rect,
            child: _tile(s, full, s.tiles[full], fullTile: true),
          ),
        ],
      );
    }
    final rects = multiviewRects(s.layout, area, gap: 10);
    return Stack(
      children: [
        for (var i = 0; i < rects.length; i++)
          Positioned.fromRect(
            rect: rects[i],
            child: i < s.tiles.length
                ? _tile(s, i, s.tiles[i])
                : _EmptySlot(
                    focusNode: _tv ? _slotNode(i) : null,
                    onTap: () => unawaited(_addChannel()),
                  ),
          ),
      ],
    );
  }

  Rect _contain(Size area) {
    var w = area.width;
    var h = w * 9 / 16;
    if (h > area.height) {
      h = area.height;
      w = h * 16 / 9;
    }
    return Rect.fromLTWH((area.width - w) / 2, (area.height - h) / 2, w, h);
  }

  Widget _tile(
    MultiviewSession s,
    int index,
    MultiviewTile tile, {
    bool fullTile = false,
  }) {
    final e = _engines[tile.id];
    final focused = index == clampIndex(s.focused, s.tiles.length);
    final tv = _tv;
    return _TileView(
      key: ValueKey('multiview-tile-${tile.id}'),
      index: index,
      engine: e,
      focused: focused,
      // TV: the ring marks where the cursor is, not just the audio tile.
      ring:
          focused &&
          (!tv ||
              _focus.hasPrimaryFocus ||
              (_toolbarNodes[tile.id]?.hasFocus ?? false)),
      tv: tv,
      toolbarNode: tv ? _toolbarNode(tile.id) : null,
      hovered: _hoveredTile == tile.id,
      isMain: index == 0,
      fullTile: fullTile,
      onHover: (h) => setState(() {
        if (h) {
          _hoveredTile = tile.id;
        } else if (_hoveredTile == tile.id) {
          _hoveredTile = null;
        }
      }),
      onFocus: () {
        _notifier.focus(index);
        _focus.requestFocus();
      },
      onToggleFull: () {
        _notifier.setFullTile(fullTile ? null : index);
        _enterBody();
      },
      onChangeChannel: () => unawaited(_changeChannel(index)),
      onSwap: () {
        _notifier.swapWithMain(index);
        _enterBody();
      },
      onClose: () => _closeTile(index),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.session,
    required this.onLayout,
    required this.onAdd,
    required this.onClose,
  });

  final MultiviewSession session;
  final ValueChanged<MultiviewLayout> onLayout;
  final VoidCallback onAdd;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
      child: Row(
        children: [
          Text(l10n.multiviewTitle, style: KText.sectionTitle),
          if (session.fullTile != null) ...[
            const SizedBox(width: 16),
            Text(
              // The remote has no Esc key.
              KTvMode.of(context)
                  ? l10n.multiviewFullTileHintTv
                  : l10n.multiviewFullTileHint,
              style: KText.caption,
            ),
          ],
          const Spacer(),
          // A single layout (TV: "1 + 1") needs no picker.
          if (session.layouts.length > 1) ...[
            for (final layout in session.layouts) ...[
              _LayoutButton(
                layout: layout,
                selected: session.layout == layout,
                enabled: session.tiles.length <= layout.slots,
                onTap: () => onLayout(layout),
              ),
              const SizedBox(width: 8),
            ],
            const SizedBox(width: 12),
          ],
          KButton.secondary(
            label: l10n.multiviewAddChannel,
            icon: PhosphorIconsBold.plus,
            onPressed: session.isFull ? null : onAdd,
          ),
          const SizedBox(width: 12),
          KIconButton(
            icon: PhosphorIconsBold.x,
            tooltip: l10n.multiviewClose,
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _LayoutButton extends StatelessWidget {
  const _LayoutButton({
    required this.layout,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final MultiviewLayout layout;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final (label, hint) = switch (layout) {
      MultiviewLayout.sideBySide => (
        l10n.multiviewLayoutSideBySide,
        l10n.multiviewLayoutSideBySideHint,
      ),
      MultiviewLayout.grid2x2 => (
        l10n.multiviewLayoutGrid,
        l10n.multiviewLayoutGridHint,
      ),
      MultiviewLayout.onePlusThree => (
        l10n.multiviewLayoutOnePlusThree,
        l10n.multiviewLayoutOnePlusThreeHint,
      ),
    };
    return Tooltip(
      message: hint,
      child: KInteractive(
        key: ValueKey('multiview-layout-${layout.name}'),
        onTap: enabled ? onTap : null,
        enabled: enabled,
        selected: selected,
        semanticLabel: hint,
        builder: (context, state, _) {
          final white = selected;
          final fg = white ? Colors.black : Colors.white;
          Widget box = AnimatedContainer(
            duration: KMotion.of(context, KDurations.hover),
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: white
                  ? Colors.white
                  : state.highlighted
                  ? KColors.glassHover
                  : KColors.glass,
              borderRadius: KRadii.pillBorder,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomPaint(
                  size: const Size(22, 14),
                  painter: _LayoutIconPainter(layout, fg),
                ),
                const SizedBox(width: 8),
                Text(label, style: KText.buttonSmall.copyWith(color: fg)),
              ],
            ),
          );
          box = KFocusRing(
            visible: state.focused,
            borderRadius: 18,
            child: box,
          );
          if (!enabled) box = Opacity(opacity: 0.4, child: box);
          return box;
        },
      ),
    );
  }
}

/// Tiny schematic of a layout for the picker.
class _LayoutIconPainter extends CustomPainter {
  _LayoutIconPainter(this.layout, this.color);

  final MultiviewLayout layout;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final r in multiviewRects(layout, size, gap: 1.5)) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(1.5)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_LayoutIconPainter old) =>
      old.layout != layout || old.color != color;
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.onTap, this.focusNode});

  final VoidCallback onTap;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return KInteractive(
      onTap: onTap,
      focusNode: focusNode,
      semanticLabel: l10n.multiviewAddChannel,
      builder: (context, state, _) => AnimatedContainer(
        duration: KMotion.of(context, KDurations.hover),
        decoration: BoxDecoration(
          color: state.highlighted ? KColors.surface2 : KColors.surface1,
          borderRadius: KRadii.cardBorder,
          border: Border.all(
            color: state.highlighted ? KColors.focusRing : KColors.stroke,
            width: state.highlighted ? 2 : 1,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                PhosphorIconsLight.plusCircle,
                size: 40,
                color: KColors.textSecondary,
              ),
              const SizedBox(height: 10),
              Text(l10n.multiviewAddChannel, style: KText.button),
            ],
          ),
        ),
      ),
    );
  }
}

class _TileView extends StatelessWidget {
  const _TileView({
    super.key,
    required this.index,
    required this.engine,
    required this.focused,
    required this.ring,
    required this.tv,
    required this.toolbarNode,
    required this.hovered,
    required this.isMain,
    required this.fullTile,
    required this.onHover,
    required this.onFocus,
    required this.onToggleFull,
    required this.onChangeChannel,
    required this.onSwap,
    required this.onClose,
  });

  final int index;
  final _TileEngine? engine;
  final bool focused;

  /// The focus border is drawn (on a TV only while the cursor is on the
  /// tile; [focused] alone marks the tile with sound).
  final bool ring;

  /// TV: the toolbar shows on the focused tile (bottom right) and its
  /// buttons take focus; [toolbarNode] parents them.
  final bool tv;
  final FocusNode? toolbarNode;
  final bool hovered;
  final bool isMain;
  final bool fullTile;
  final ValueChanged<bool> onHover;
  final VoidCallback onFocus;
  final VoidCallback onToggleFull;
  final VoidCallback onChangeChannel;
  final VoidCallback onSwap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final e = engine;
    final state = e?.engine.state;
    final channel = e?.channel;
    final busy =
        state == null ||
        (state.buffering && state.error == null) ||
        state.reconnecting;
    final failed = (state?.hasError ?? false) || e?.error != null;
    final showChrome = hovered || focused;
    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onFocus,
        onDoubleTap: onToggleFull,
        child: AnimatedContainer(
          duration: KMotion.of(context, KDurations.hover),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: KRadii.cardBorder,
            border: Border.all(
              color: ring ? KColors.focusRing : KColors.stroke,
              width: ring ? 3 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(KRadii.card - 1),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (e != null) e.video,
                if (busy && !failed) const Center(child: KSpinner(size: 34)),
                if (failed)
                  Center(
                    child: Icon(
                      PhosphorIconsLight.warningCircle,
                      size: 36,
                      color: KColors.accent.withValues(alpha: 0.9),
                    ),
                  ),
                // Channel label.
                Positioned(
                  left: 12,
                  bottom: 12,
                  // Leave room for the TV toolbar.
                  right: tv && focused ? 196 : 12,
                  child: AnimatedOpacity(
                    opacity: showChrome ? 1 : 0.85,
                    duration: KMotion.of(context, KDurations.hover),
                    child: Row(
                      children: [
                        if (channel != null)
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: KColors.overlay,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      channel.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: KText.cardTitle,
                                    ),
                                  ),
                                  for (final badge in channel.badges) ...[
                                    const SizedBox(width: 6),
                                    KBadge(badge, color: KColors.textPrimary),
                                  ],
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Audio marker.
                if (focused)
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Tooltip(
                      message: l10n.multiviewAudioOn,
                      child: Container(
                        key: const ValueKey('multiview-audio'),
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          PhosphorIconsFill.speakerHigh,
                          size: 18,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                // Toolbar: on hover; on a TV, on the focused tile (bottom
                // right, Down from the tile reaches it).
                Positioned(
                  right: 10,
                  top: tv ? null : 10,
                  bottom: tv ? 10 : null,
                  child: IgnorePointer(
                    ignoring: !(tv ? focused : hovered),
                    child: ExcludeFocus(
                      excluding: !tv || !focused,
                      child: Focus(
                        focusNode: toolbarNode,
                        canRequestFocus: false,
                        skipTraversal: true,
                        child: AnimatedOpacity(
                          opacity: (tv ? focused : hovered) ? 1 : 0,
                          duration: KMotion.of(context, KDurations.hover),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              KIconButton(
                                icon: PhosphorIconsLight.listBullets,
                                tooltip: l10n.multiviewChangeChannel,
                                background: KColors.overlay,
                                focusable: tv,
                                onPressed: onChangeChannel,
                              ),
                              if (!isMain && !fullTile) ...[
                                const SizedBox(width: 8),
                                KIconButton(
                                  icon: PhosphorIconsLight.arrowsLeftRight,
                                  tooltip: l10n.multiviewSwapWithMain,
                                  background: KColors.overlay,
                                  focusable: tv,
                                  onPressed: onSwap,
                                ),
                              ],
                              const SizedBox(width: 8),
                              KIconButton(
                                icon: fullTile
                                    ? PhosphorIconsLight.cornersIn
                                    : PhosphorIconsLight.cornersOut,
                                tooltip: l10n.multiviewFullTile,
                                background: KColors.overlay,
                                focusable: tv,
                                onPressed: onToggleFull,
                              ),
                              const SizedBox(width: 8),
                              KIconButton(
                                icon: PhosphorIconsBold.x,
                                tooltip: l10n.multiviewCloseTile,
                                background: KColors.overlay,
                                focusable: tv,
                                onPressed: onClose,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
