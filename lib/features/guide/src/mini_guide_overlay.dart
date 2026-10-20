/// The Mini TV Guide inside the live player: a left column of
/// channel cards (logo, name, now/next, progress) with a red marker on the
/// playing channel. ↑/↓ choose, Enter tunes, ←/→ cycle the provider
/// categories, Esc closes.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/clock.dart';
import '../../../app/time_format.dart';
import '../../../core/core.dart';
import '../../../data/db/database.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/epg_repository.dart';
import '../../../data/repositories/live_repository.dart';
import '../../../data/repositories/repository_models.dart';
import '../../../l10n/gen/app_localizations.dart';
import 'guide_overlay.dart' show playerGuideCategory;

class MiniGuideView extends ConsumerStatefulWidget {
  const MiniGuideView({
    super.key,
    required this.playlistId,
    required this.currentChannelId,
    required this.onTune,
    required this.onClose,
    this.categoryId,
  });

  final int playlistId;
  final String currentChannelId;
  final ValueChanged<String> onTune;
  final VoidCallback onClose;

  /// Category to start in (default: the active live category when it holds
  /// the channel, else the channel's own).
  final String? categoryId;

  @override
  ConsumerState<MiniGuideView> createState() => _MiniGuideViewState();
}

class _MiniGuideViewState extends ConsumerState<MiniGuideView> {
  static const double _rowExtent = 96;
  static const double _width = 400;

  final FocusNode _focus = FocusNode(debugLabel: 'mini guide');
  final ScrollController _scroll = ScrollController();
  CategoryRef? _category;
  List<ChannelView>? _channels;
  Map<String, NowNext> _nowNext = const {};
  int _selected = -1;
  int _loadId = 0;
  DateTime? _loadedAt;

  int get _pid => widget.playlistId;

  @override
  void initState() {
    super.initState();
    final id = widget.categoryId;
    if (id != null) _category = ProviderCategory(id);
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

  Future<void> _loadNowNext(List<ChannelView> channels, DateTime now) async {
    final id = ++_loadId;
    _loadedAt = now;
    final keys = [
      for (final c in channels)
        if (c.epgKey != null) c.epgKey!,
    ];
    final result = await ref
        .read(epgRepositoryProvider)
        .nowNext(_pid, keys, at: now);
    if (!mounted || id != _loadId) return;
    setState(() => _nowNext = result);
  }

  void _select(int index, {bool animate = true}) {
    final channels = _channels;
    if (channels == null || channels.isEmpty) return;
    final i = index.clamp(0, channels.length - 1);
    setState(() => _selected = i);
    if (!_scroll.hasClients) return;
    final viewport = _scroll.position.viewportDimension;
    final top = i * _rowExtent;
    double? target;
    if (top < _scroll.offset) {
      target = top;
    } else if (top + _rowExtent > _scroll.offset + viewport) {
      target = top + _rowExtent - viewport;
    }
    if (target == null) return;
    final t = target.clamp(0.0, _scroll.position.maxScrollExtent);
    if (!animate || KMotion.reduced(context)) {
      _scroll.jumpTo(t);
    } else {
      unawaited(
        _scroll.animateTo(
          t,
          duration: const Duration(milliseconds: 160),
          curve: KMotion.enter,
        ),
      );
    }
  }

  void _cycleCategory(int direction, CategoryRef current) {
    final scope = (playlistId: _pid, kind: SectionKind.live);
    final categories = [
      for (final c in ref.read(categoriesProvider(scope)).value ?? const [])
        if (c.ref is ProviderCategory && c.count > 0) c.ref,
    ];
    if (categories.isEmpty) return;
    final at = categories.indexOf(current);
    final next = at < 0
        ? 0
        : (at + direction + categories.length) % categories.length;
    setState(() {
      _category = categories[next];
      _channels = null;
      _selected = -1;
      _nowNext = const {};
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event, CategoryRef? current) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final channels = _channels ?? const <ChannelView>[];
    if (key == LogicalKeyboardKey.arrowUp) {
      _select(_selected - 1, animate: event is! KeyRepeatEvent);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _select(_selected + 1, animate: event is! KeyRepeatEvent);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      if (current != null && event is KeyDownEvent) _cycleCategory(-1, current);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      if (current != null && event is KeyDownEvent) _cycleCategory(1, current);
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.select) {
      if (event is KeyDownEvent &&
          _selected >= 0 &&
          _selected < channels.length) {
        widget.onTune(channels[_selected].providerId);
      }
    } else if (key == LogicalKeyboardKey.escape) {
      if (event is KeyDownEvent) widget.onClose();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final now =
        ref.watch(minuteClockProvider).value ?? ref.read(clockSourceProvider)();
    final category =
        _category ?? playerGuideCategory(ref, _pid, widget.currentChannelId);
    final scope = (playlistId: _pid, kind: SectionKind.live);
    final categories = ref.watch(categoriesProvider(scope)).value;
    CategoryView? view;
    for (final c in categories ?? const <CategoryView>[]) {
      if (c.ref == category) view = c;
    }
    final channelsValue = category == null
        ? null
        : ref.watch(channelsProvider((playlistId: _pid, category: category)));
    final list = channelsValue?.value;
    if (list != null && !identical(list, _channels)) {
      _channels = list;
      if (_selected < 0) {
        final current = list.indexWhere(
          (c) => c.providerId == widget.currentChannelId,
        );
        _selected = math.max(0, current);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _select(_selected, animate: false);
        });
      }
      unawaited(_loadNowNext(list, now));
    } else if (list != null && _loadedAt != null && _loadedAt != now) {
      unawaited(_loadNowNext(list, now));
    }

    Widget content;
    if (list == null) {
      content = channelsValue != null && channelsValue.hasError
          ? KErrorState(message: l10n.guideLoadError)
          : const KLoadingState();
    } else if (list.isEmpty) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.guideMiniEmpty,
            textAlign: TextAlign.center,
            style: KText.bodySecondary,
          ),
        ),
      );
    } else {
      content = ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemExtent: _rowExtent,
        itemCount: list.length,
        itemBuilder: (context, i) {
          final c = list[i];
          final nn = c.epgKey == null ? null : _nowNext[c.epgKey!];
          return _MiniCard(
            key: ValueKey('mini-${c.providerId}'),
            channel: c,
            nowNext: nn,
            now: now,
            playing: c.providerId == widget.currentChannelId,
            selected: i == _selected,
            onTap: () {
              _select(i);
              widget.onTune(c.providerId);
            },
          );
        },
      );
    }

    return Focus(
      focusNode: _focus,
      onKeyEvent: (node, event) => _onKey(node, event, category),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: _width,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    KColors.bg.withValues(alpha: 0.92),
                    KColors.bg.withValues(alpha: 0.72),
                  ],
                ),
              ),
              child: SafeArea(
                right: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 16, 10),
                      child: Row(
                        children: [
                          Container(
                            width: 3,
                            height: 18,
                            color: KColors.accent,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              view?.title ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: KText.panelHeader.copyWith(
                                fontFamilyFallback: KText.emojiFallback,
                              ),
                            ),
                          ),
                          Text(
                            l10n.guideMiniCategoryHint,
                            style: KText.caption.copyWith(
                              color: KColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: content),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniCard extends ConsumerWidget {
  const _MiniCard({
    super.key,
    required this.channel,
    required this.nowNext,
    required this.now,
    required this.playing,
    required this.selected,
    required this.onTap,
  });

  final ChannelView channel;
  final NowNext? nowNext;
  final DateTime now;
  final bool playing;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final fmt = ref.watch(timeFormatProvider);
    final current = nowNext?.now;
    final next = nowNext?.next;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: KInteractive(
        onTap: onTap,
        focusable: false,
        selected: selected,
        semanticLabel: channel.displayName,
        builder: (context, state, _) {
          final highlighted = selected || state.hovered;
          return Container(
            decoration: BoxDecoration(
              color: KColors.surface1.withValues(alpha: 0.94),
              borderRadius: KRadii.cardBorder,
              border: Border.all(
                color: highlighted ? KColors.focusRing : KColors.stroke,
                width: selected ? 2 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              children: [
                Container(
                  width: 4,
                  color: playing ? KColors.accent : Colors.transparent,
                ),
                const SizedBox(width: 8),
                KLogoTile(
                  name: channel.displayName,
                  url: channel.logo,
                  size: 48,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            for (final b in channel.badges.take(1)) ...[
                              KBadge(b),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(
                                channel.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: KText.cardTitle,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          current?.title ?? l10n.guideNoEpg,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: KText.programme.copyWith(fontSize: 13),
                        ),
                        Text(
                          current == null
                              ? (next == null
                                    ? ''
                                    : l10n.guideMiniNext(next.title))
                              : next == null
                              ? fmt.range(current.start, current.stop)
                              : '${fmt.range(current.start, current.stop)} · '
                                    '${l10n.guideMiniNext(next.title)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: KText.time.copyWith(fontSize: 12),
                        ),
                        if (current != null) ...[
                          const SizedBox(height: 5),
                          KProgressBar(
                            value: current.progressAt(now),
                            height: 3,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
