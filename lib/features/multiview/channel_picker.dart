import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/platform/form_factor.dart';
import '../../core/core.dart';
import '../../data/repositories/live_repository.dart';
import '../../data/repositories/repository_models.dart';
import '../../data/text/normalize.dart';
import '../../l10n/gen/app_localizations.dart';

/// "Choose a channel": a sheet with a search field over every visible
/// channel of the playlist. ↑/↓ move, Enter picks. Resolves to the channel
/// id, or null.
///
/// On a TV the list takes focus first, so the on-screen keyboard stays
/// closed until the user moves Up to the search field.
Future<String?> showMultiviewChannelPicker(
  BuildContext context, {
  required int playlistId,
  Set<String> exclude = const {},
}) {
  return showKSheet<String>(
    context,
    width: 560,
    maxHeight: 640,
    scrollable: false,
    expand: true,
    child: MultiviewChannelPicker(playlistId: playlistId, exclude: exclude),
  );
}

class MultiviewChannelPicker extends ConsumerStatefulWidget {
  const MultiviewChannelPicker({
    super.key,
    required this.playlistId,
    this.exclude = const {},
  });

  final int playlistId;

  /// Channels already open (shown dimmed, not selectable).
  final Set<String> exclude;

  @override
  ConsumerState<MultiviewChannelPicker> createState() =>
      _MultiviewChannelPickerState();
}

class _MultiviewChannelPickerState
    extends ConsumerState<MultiviewChannelPicker> {
  static const double _rowHeight = 64;

  final TextEditingController _query = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _fieldFocus = FocusNode(debugLabel: 'picker search');
  final FocusNode _listFocus = FocusNode(debugLabel: 'picker list');
  List<ChannelView>? _all;
  List<(ChannelView, String)> _keys = const [];
  List<ChannelView> _results = const [];
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    _fieldFocus.dispose();
    _listFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await ref
        .read(liveRepositoryProvider)
        .channels(widget.playlistId, const AllCategory());
    if (!mounted) return;
    setState(() {
      _all = list;
      _keys = [for (final c in list) (c, normalizeForSearch(c.displayName))];
      _filter();
    });
  }

  void _filter() {
    final q = normalizeForSearch(_query.text);
    final terms = q.split(' ').where((t) => t.isNotEmpty).toList();
    _results = [
      for (final (c, key) in _keys)
        if (terms.every(key.contains)) c,
    ];
    _selected = _results.indexWhere(
      (c) => !widget.exclude.contains(c.providerId),
    );
    if (_selected < 0) _selected = 0;
  }

  void _pick(ChannelView c) {
    if (widget.exclude.contains(c.providerId)) return;
    Navigator.of(context).pop(c.providerId);
  }

  void _reveal() {
    if (!_scroll.hasClients) return;
    final viewport = _scroll.position.viewportDimension;
    final top = _selected * _rowHeight;
    var target = _scroll.offset;
    if (top < target) target = top;
    if (top + _rowHeight > target + viewport) {
      target = top + _rowHeight - viewport;
    }
    _scroll.jumpTo(target.clamp(0.0, _scroll.position.maxScrollExtent));
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final tv = ref.read(formFactorProvider).isTv;
    if (tv &&
        _fieldFocus.hasPrimaryFocus &&
        (key == LogicalKeyboardKey.arrowDown ||
            key == LogicalKeyboardKey.arrowUp)) {
      // The field keeps its arrows for the caret; Down leaves it.
      if (key == LogicalKeyboardKey.arrowDown) _listFocus.requestFocus();
      return key == LogicalKeyboardKey.arrowDown
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    if (tv &&
        key == LogicalKeyboardKey.arrowUp &&
        !_results
            .take(_selected)
            .any((c) => !widget.exclude.contains(c.providerId))) {
      _fieldFocus.requestFocus();
      return KeyEventResult.handled;
    }
    if (_results.isEmpty) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selected = (_selected + (key == LogicalKeyboardKey.arrowDown ? 1 : -1))
            .clamp(0, _results.length - 1);
      });
      _reveal();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (event is KeyDownEvent) _pick(_results[_selected]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final all = _all;
    final tv = ref.watch(formFactorProvider).isTv;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 48),
            child: Text(l10n.multiviewPickerTitle, style: KText.title),
          ),
          const SizedBox(height: 16),
          Focus(
            onKeyEvent: _onKey,
            child: KTextField(
              controller: _query,
              focusNode: _fieldFocus,
              autofocus: !tv,
              hint: l10n.multiviewSearchHint,
              prefixIcon: PhosphorIconsLight.magnifyingGlass,
              onChanged: (_) => setState(_filter),
              onSubmitted: (_) {
                if (_results.isNotEmpty) _pick(_results[_selected]);
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Focus(
              focusNode: _listFocus,
              autofocus: tv,
              onKeyEvent: _onKey,
              child: all == null
                  ? const KLoadingState()
                  : _results.isEmpty
                  ? KEmptyState(
                      icon: PhosphorIconsLight.magnifyingGlass,
                      message: l10n.multiviewNoResults(_query.text.trim()),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      itemExtent: _rowHeight,
                      itemCount: _results.length,
                      itemBuilder: (context, i) {
                        final c = _results[i];
                        final open = widget.exclude.contains(c.providerId);
                        return _PickerRow(
                          channel: c,
                          selected: i == _selected,
                          enabled: !open,
                          onTap: () => _pick(c),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.channel,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final ChannelView channel;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return KInteractive(
      onTap: enabled ? onTap : null,
      enabled: enabled,
      focusable: false,
      semanticLabel: channel.displayName,
      builder: (context, state, _) {
        final highlighted = selected || state.hovered;
        Widget row = AnimatedContainer(
          duration: KMotion.of(context, KDurations.hover),
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: highlighted ? KColors.focusRing : KColors.surface1,
            borderRadius: KRadii.cardBorder,
          ),
          child: Row(
            children: [
              KLogoTile(name: channel.displayName, url: channel.logo, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KText.cardTitle.copyWith(
                        color: highlighted ? Colors.black : KColors.textPrimary,
                      ),
                    ),
                    if (channel.categoryName.isNotEmpty)
                      Text(
                        channel.categoryName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KText.caption.copyWith(
                          color: highlighted
                              ? const Color(0xFF55555A)
                              : KColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              for (final badge in channel.badges) ...[
                const SizedBox(width: 6),
                KBadge(
                  badge,
                  color: highlighted ? Colors.black : KColors.textSecondary,
                ),
              ],
            ],
          ),
        );
        if (!enabled) row = Opacity(opacity: 0.4, child: row);
        return row;
      },
    );
  }
}
