import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/clock.dart';
import '../../../core/core.dart';
import '../../../data/repositories/epg_repository.dart';
import '../../../data/repositories/live_repository.dart';
import '../../../data/repositories/repository_models.dart';
import '../../../l10n/gen/app_localizations.dart';

/// Stand-in Mini TV Guide (see `mini_guide_adapter.dart`): a left column
/// with the channels of the current category (logo, name, programme on air
/// and its progress), a red marker on the playing channel, the video still
/// visible on the right. ↑/↓ choose, Enter tunes, Esc / G closes.
class PlayerMiniGuide extends ConsumerStatefulWidget {
  const PlayerMiniGuide({
    super.key,
    required this.playlistId,
    required this.currentChannelId,
    required this.onTune,
    required this.onClose,
    this.categoryId,
  });

  final int playlistId;
  final String currentChannelId;
  final String? categoryId;
  final ValueChanged<String> onTune;
  final VoidCallback onClose;

  @override
  ConsumerState<PlayerMiniGuide> createState() => _PlayerMiniGuideState();
}

class _PlayerMiniGuideState extends ConsumerState<PlayerMiniGuide> {
  static const double _rowHeight = 84;

  final FocusNode _focus = FocusNode(debugLabel: 'mini guide');
  final ScrollController _scroll = ScrollController();
  List<ChannelView>? _channels;
  Map<String, NowNext> _nowNext = const {};
  int _selected = 0;
  int? _hovered;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final live = ref.read(liveRepositoryProvider);
    var categoryId = widget.categoryId;
    if (categoryId == null) {
      final current = await live.channel(
        widget.playlistId,
        widget.currentChannelId,
      );
      categoryId = current?.row.categoryId;
    }
    final list = await live.channels(
      widget.playlistId,
      categoryId == null ? const AllCategory() : ProviderCategory(categoryId),
    );
    if (!mounted) return;
    final index = list.indexWhere(
      (c) => c.providerId == widget.currentChannelId,
    );
    setState(() {
      _channels = list;
      _selected = index < 0 ? 0 : index;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(jump: true));
    final keys = [for (final c in list) ?c.epgKey];
    if (keys.isEmpty) return;
    try {
      final nn = await ref
          .read(epgRepositoryProvider)
          .nowNext(
            widget.playlistId,
            keys,
            at: ref.read(clockSourceProvider)(),
          );
      if (mounted) setState(() => _nowNext = nn);
    } catch (error) {
      debugPrint('Mini guide: now/next failed: $error');
    }
  }

  void _reveal({bool jump = false}) {
    if (!_scroll.hasClients) return;
    final viewport = _scroll.position.viewportDimension;
    final top = _selected * _rowHeight;
    var target = _scroll.offset;
    if (top < target) target = top;
    if (top + _rowHeight > target + viewport) {
      target = top + _rowHeight - viewport;
    }
    target = target.clamp(0.0, _scroll.position.maxScrollExtent);
    if (jump || KMotion.reduced(context)) {
      _scroll.jumpTo(target);
    } else {
      unawaited(
        _scroll.animateTo(
          target,
          duration: KDurations.scroll,
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final channels = _channels;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.keyG ||
        key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.arrowLeft) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    if (channels == null || channels.isEmpty) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      final delta = key == LogicalKeyboardKey.arrowUp ? -1 : 1;
      setState(
        () => _selected = (_selected + delta).clamp(0, channels.length - 1),
      );
      _reveal();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.arrowRight) {
      widget.onTune(channels[_selected].providerId);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final channels = _channels;
    final now = ref.watch(minuteClockProvider).value ?? DateTime.now();
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: Stack(
        key: const ValueKey('player-mini-guide'),
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xF2000000), Color(0x00000000)],
                    stops: [0.28, 0.62],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 420,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Expanded(
                  child: channels == null
                      ? const Center(child: KSpinner(size: 32))
                      : channels.isEmpty
                      ? Center(
                          child: Text(
                            l10n.playerNoChannels,
                            style: KText.bodySecondary,
                          ),
                        )
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(24, 8, 16, 8),
                          itemExtent: _rowHeight,
                          itemCount: channels.length,
                          itemBuilder: (context, i) {
                            final c = channels[i];
                            return _MiniGuideRow(
                              channel: c,
                              nowNext: c.epgKey == null
                                  ? NowNext.empty
                                  : _nowNext[c.epgKey] ?? NowNext.empty,
                              now: now,
                              playing: c.providerId == widget.currentChannelId,
                              selected: i == _selected,
                              hovered: _hovered == i,
                              onHover: (h) => setState(
                                () => _hovered = h
                                    ? i
                                    : (_hovered == i ? null : _hovered),
                              ),
                              onTap: () {
                                setState(() => _selected = i);
                                widget.onTune(c.providerId);
                              },
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 8, 16, 20),
                  child: Text(
                    l10n.playerGuideHint,
                    style: KText.caption.copyWith(color: KColors.textTertiary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniGuideRow extends StatelessWidget {
  const _MiniGuideRow({
    required this.channel,
    required this.nowNext,
    required this.now,
    required this.playing,
    required this.selected,
    required this.hovered,
    required this.onHover,
    required this.onTap,
  });

  final ChannelView channel;
  final NowNext nowNext;
  final DateTime now;
  final bool playing;
  final bool selected;
  final bool hovered;
  final ValueChanged<bool> onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final programme = nowNext.now;
    final highlighted = selected || hovered;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 44,
                decoration: BoxDecoration(
                  color: playing ? KColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AnimatedContainer(
                  duration: KMotion.of(context, KDurations.hover),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: highlighted
                        ? const Color(0xFF1A1A1C)
                        : const Color(0xCC0D0D0D),
                    borderRadius: KRadii.cardBorder,
                    border: Border.all(
                      color: selected ? KColors.focusRing : KColors.stroke,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      KLogoTile(
                        name: channel.displayName,
                        url: channel.logo,
                        size: 48,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (channel.number != null) ...[
                                  Text(
                                    '${channel.number}',
                                    style: KText.time.copyWith(
                                      color: KColors.textTertiary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
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
                                  KBadge(badge),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              programme?.title ?? l10n.playerNoEpg,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: KText.caption,
                            ),
                            if (programme != null) ...[
                              const SizedBox(height: 5),
                              KProgressBar(
                                value: programme.progressAt(now),
                                height: 3,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
