/// "Assign Custom EPG": a searchable list of the playlist's
/// XMLTV channels with the programme on air; the current mapping is marked
/// and pinned on top; Reset returns to the automatic match.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../../data/repositories/epg_repository.dart';
import '../../../data/repositories/live_repository.dart';
import '../../../data/repositories/repository_models.dart';
import '../../../l10n/gen/app_localizations.dart';

/// Opens the picker for a channel; saves with `LiveRepository.setCustomEpg`
/// and shows a toast. Resolves to true when the mapping changed.
Future<bool> showCustomEpgPickerSheet(
  BuildContext context, {
  required int playlistId,
  required String channelId,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final live = container.read(liveRepositoryProvider);
  final channel = await live.channel(playlistId, channelId);
  if (channel == null || !context.mounted) return false;
  final l10n = L10n.of(context);
  final choice = await showKSheet<CustomEpgChoice>(
    context,
    width: 700,
    maxHeight: 720,
    expand: true,
    scrollable: false,
    child: CustomEpgPicker(playlistId: playlistId, channel: channel),
  );
  if (choice == null) return false;
  final current = channel.row.customEpgId;
  if (choice.epgId == current) return false;
  await live.setCustomEpg(playlistId, channelId, choice.epgId);
  container
      .read(toastControllerProvider)
      .show(
        choice.epgId == null
            ? l10n.liveCustomEpgRemoved
            : l10n.liveCustomEpgAssigned,
      );
  return true;
}

/// The picker's result: an XMLTV channel id, or null for Reset.
@immutable
class CustomEpgChoice {
  const CustomEpgChoice(this.epgId);

  final String? epgId;
}

/// The picker body (search field, list, Reset / Cancel).
class CustomEpgPicker extends ConsumerStatefulWidget {
  const CustomEpgPicker({
    super.key,
    required this.playlistId,
    required this.channel,
  });

  final int playlistId;
  final ChannelView channel;

  @override
  ConsumerState<CustomEpgPicker> createState() => _CustomEpgPickerState();
}

class _CustomEpgPickerState extends ConsumerState<CustomEpgPicker> {
  final TextEditingController _query = TextEditingController();
  final FocusNode _field = FocusNode(debugLabel: 'epg-picker-search');
  final FocusNode _firstRow = FocusNode(debugLabel: 'epg-picker-first');
  Timer? _debounce;
  List<EpgChannelView>? _results;
  bool _hasGuide = true;
  int _seq = 0;

  String? get _custom => widget.channel.row.customEpgId;
  String? get _automatic => widget.channel.row.matchedEpgId;

  @override
  void initState() {
    super.initState();
    unawaited(_load(''));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _field.dispose();
    _firstRow.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () => _load(text));
  }

  Future<void> _load(String text) async {
    final seq = ++_seq;
    final epg = ref.read(epgRepositoryProvider);
    final query = text.trim();
    List<EpgChannelView> list;
    try {
      list = await epg.epgChannels(widget.playlistId, query: query);
      final current = _custom ?? _automatic;
      if (query.isEmpty && current != null) {
        // Pin the current mapping on top.
        var pinned = list.where((e) => e.id == current).firstOrNull;
        if (pinned == null) {
          final found = await epg.epgChannels(
            widget.playlistId,
            query: current,
            limit: 20,
          );
          pinned = found.where((e) => e.id == current).firstOrNull;
        }
        if (pinned != null) {
          list = [pinned, ...list.where((e) => e.id != current)];
        }
      }
    } on Object {
      list = const [];
    }
    if (!mounted || seq != _seq) return;
    setState(() {
      _results = list;
      if (query.isEmpty) _hasGuide = list.isNotEmpty;
    });
  }

  void _pick(String? epgId) =>
      Navigator.of(context).pop(CustomEpgChoice(epgId));

  KeyEventResult _onFieldKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
        (_results?.isNotEmpty ?? false)) {
      _firstRow.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final results = _results;
    Widget list;
    if (results == null) {
      list = const KLoadingState();
    } else if (results.isEmpty) {
      list = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _query.text.trim().isEmpty || !_hasGuide
                ? l10n.liveCustomEpgNoGuide
                : l10n.liveCustomEpgNoMatch(_query.text.trim()),
            textAlign: TextAlign.center,
            style: KText.bodySecondary,
          ),
        ),
      );
    } else {
      list = ListView.builder(
        padding: const EdgeInsets.only(bottom: 8),
        itemCount: results.length,
        itemBuilder: (context, i) {
          final e = results[i];
          return _EpgRow(
            entry: e,
            focusNode: i == 0 ? _firstRow : null,
            assigned: e.id == _custom,
            automatic: _custom == null && e.id == _automatic,
            onTap: () => _pick(e.id),
          );
        },
      );
    }
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 44),
              child: Text(l10n.liveAssignCustomEpg, style: KText.title),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.liveCustomEpgFor(widget.channel.displayName),
              style: KText.caption,
            ),
            const SizedBox(height: 16),
            Focus(
              onKeyEvent: _onFieldKey,
              child: KTextField(
                controller: _query,
                focusNode: _field,
                hint: l10n.liveCustomEpgSearch,
                prefixIcon: PhosphorIconsLight.magnifyingGlass,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: _onChanged,
                onSubmitted: (_) {
                  final first = _results?.firstOrNull;
                  if (first != null) _pick(first.id);
                },
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: list),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.liveCustomEpgHint,
                    style: KText.caption.copyWith(color: KColors.textTertiary),
                  ),
                ),
                const SizedBox(width: 16),
                if (_custom != null) ...[
                  KButton.secondary(
                    label: l10n.liveReset,
                    icon: PhosphorIconsLight.arrowCounterClockwise,
                    onPressed: () => _pick(null),
                  ),
                  const SizedBox(width: 10),
                ],
                KButton.secondary(
                  label: l10n.cancel,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EpgRow extends StatelessWidget {
  const _EpgRow({
    required this.entry,
    required this.assigned,
    required this.automatic,
    required this.onTap,
    this.focusNode,
  });

  final EpgChannelView entry;
  final bool assigned;
  final bool automatic;
  final VoidCallback onTap;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final now = entry.nowTitle;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: KInteractive(
        onTap: onTap,
        focusNode: focusNode,
        selected: assigned,
        semanticLabel: entry.displayName,
        builder: (context, state, _) {
          final pill = state.highlighted;
          final fg = pill ? Colors.black : KColors.textPrimary;
          final sub = pill ? Colors.black54 : KColors.textSecondary;
          return AnimatedContainer(
            duration: KMotion.of(context, KDurations.hover),
            curve: KMotion.hover,
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: pill
                  ? KColors.focusRing
                  : assigned || automatic
                  ? KColors.surface2
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(KRadii.card),
            ),
            child: Row(
              children: [
                KLogoTile(
                  name: entry.displayName,
                  url: entry.icon,
                  size: 40,
                  radius: 6,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KText.cardTitle.copyWith(color: fg),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${entry.id}  ·  '
                        '${now == null ? l10n.liveCustomEpgNoProgramme : l10n.liveCustomEpgNow(now)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KText.caption.copyWith(color: sub),
                      ),
                    ],
                  ),
                ),
                if (assigned || automatic) ...[
                  const SizedBox(width: 12),
                  Icon(
                    assigned
                        ? PhosphorIconsBold.check
                        : PhosphorIconsLight.sparkle,
                    size: 16,
                    color: pill ? Colors.black : KColors.accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    assigned
                        ? l10n.liveCustomEpgCurrent
                        : l10n.liveCustomEpgAutomatic,
                    style: KText.label.copyWith(
                      color: pill ? Colors.black : KColors.accent,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
