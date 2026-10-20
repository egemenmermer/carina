/// The Full TV Guide inside the live player: the guide grid
/// over the dimmed video. On-air programmes tune the player, archived ones
/// start the catch-up, upcoming ones open the details.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/clock.dart';
import '../../../app/shell/category_selection.dart';
import '../../../app/time_format.dart';
import '../../../core/core.dart';
import '../../../data/db/database.dart';
import '../../../data/repositories/epg_repository.dart';
import '../../../data/repositories/live_repository.dart';
import '../../../data/repositories/reminders_repository.dart';
import '../../../data/repositories/repository_models.dart';
import '../../../data/settings/settings_store.dart';
import '../../../l10n/gen/app_localizations.dart';
import 'guide_actions.dart';
import 'guide_cache.dart';
import 'guide_cells.dart';
import 'guide_controller.dart';
import 'guide_days.dart';
import 'guide_grid.dart';
import 'guide_info_panel.dart';
import 'programme_details_sheet.dart';

/// One channel by provider id (any hidden/locked state).
final guideChannelProvider = FutureProvider.autoDispose
    .family<ChannelView?, ({int playlistId, String channelId})>(
      (ref, args) => ref
          .watch(liveRepositoryProvider)
          .channel(args.playlistId, args.channelId),
    );

/// Rows of the player guides: the active live category when it contains
/// [currentChannelId], else the channel's own category.
CategoryRef? playerGuideCategory(
  WidgetRef ref,
  int playlistId,
  String currentChannelId,
) {
  final scope = (playlistId: playlistId, kind: SectionKind.live);
  final active = ref.watch(activeCategoryProvider(scope)).value;
  final channel = ref
      .watch(
        guideChannelProvider((
          playlistId: playlistId,
          channelId: currentChannelId,
        )),
      )
      .value;
  final own = channel?.row.categoryId;
  final activeRef = active?.ref;
  if (activeRef == null) return own == null ? null : ProviderCategory(own);
  final list = ref
      .watch(channelsProvider((playlistId: playlistId, category: activeRef)))
      .value;
  if (list == null) return activeRef;
  final contains = list.any((c) => c.providerId == currentChannelId);
  if (contains || own == null) return activeRef;
  return ProviderCategory(own);
}

class GuideOverlayView extends ConsumerStatefulWidget {
  const GuideOverlayView({
    super.key,
    required this.playlistId,
    required this.currentChannelId,
    required this.onTune,
    required this.onClose,
    this.onCatchup,
  });

  final int playlistId;
  final String currentChannelId;
  final ValueChanged<String> onTune;
  final VoidCallback onClose;
  final void Function(String channelId, DateTime startUtc, DateTime endUtc)?
  onCatchup;

  @override
  ConsumerState<GuideOverlayView> createState() => _GuideOverlayViewState();
}

class _GuideOverlayViewState extends ConsumerState<GuideOverlayView> {
  late final GuideProgrammeCache _cache = GuideProgrammeCache(
    (keys, from, to) => ref
        .read(epgRepositoryProvider)
        .guide(widget.playlistId, keys, from, to),
  );
  final GuideGridController _controller = GuideGridController();

  int get _pid => widget.playlistId;

  @override
  void dispose() {
    _cache.dispose();
    _controller.dispose();
    super.dispose();
  }

  DateTime _now() =>
      ref.read(minuteClockProvider).value ?? ref.read(clockSourceProvider)();

  void _catchup(String channelId, DateTime start, DateTime end) {
    final callback = widget.onCatchup;
    if (callback != null) {
      callback(channelId, start, end);
    } else {
      widget.onTune(channelId);
    }
  }

  Future<void> _activate(GuideFocus f) async {
    final channel = f.channel;
    final id = channel.providerId;
    switch (guideCellAction(f, _now().millisecondsSinceEpoch)) {
      case GuideCellAction.watchLive:
        widget.onTune(id);
      case GuideCellAction.catchup:
        _catchup(id, f.cell.start, f.cell.stop);
      case GuideCellAction.details:
        await openProgrammeDetailsSheet(
          context,
          playlistId: _pid,
          channelId: id,
          startUtc: f.cell.start,
          onWatchLive: () => widget.onTune(id),
          onPlayFromStart: (start, end) => _catchup(id, start, end),
        );
      case GuideCellAction.none:
        break;
    }
  }

  Future<void> _pickDay(Rect anchor, EpgDataRange? range) async {
    final l10n = L10n.of(context);
    final fmt = ref.read(timeFormatProvider);
    final now = _now();
    final visible = _controller.visibleStartMs;
    final current = localDay(
      visible == null
          ? now
          : DateTime.fromMillisecondsSinceEpoch(visible, isUtc: true),
    );
    final chosen = await showKContextMenu<DateTime>(
      context,
      position: anchor.bottomLeft + const Offset(0, 6),
      title: l10n.guideChooseDay,
      width: 300,
      entries: [
        for (final day in guideDays(now, range))
          KMenuEntry<DateTime>(
            label: guideDayMenuLabel(l10n, fmt, day, now),
            value: day,
            checked: day == current,
          ),
      ],
    );
    if (chosen != null && mounted) _controller.jumpToDay(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final fmt = ref.watch(timeFormatProvider);
    final now =
        ref.watch(minuteClockProvider).value ?? ref.read(clockSourceProvider)();
    final nowMs = now.millisecondsSinceEpoch;
    final category = playerGuideCategory(ref, _pid, widget.currentChannelId);
    final channels = category == null
        ? null
        : ref.watch(channelsProvider((playlistId: _pid, category: category)));
    final range = ref.watch(epgDataRangeProvider(_pid));
    final zoom = ref.watchSetting(
      PlaylistSettings.guideZoomMinutes,
      playlistId: _pid,
    );
    final reminders = ref.watch(remindersProvider(_pid)).value;
    final list = channels?.value;

    Widget body;
    if (channels != null && channels.hasError && list == null) {
      body = KErrorState(
        message: l10n.guideLoadError,
        onRetry: () => ref.invalidate(
          channelsProvider((playlistId: _pid, category: category!)),
        ),
      );
    } else if (list == null || (range.isLoading && !range.hasValue)) {
      body = const KLoadingState();
    } else if (list.isEmpty) {
      body = KEmptyState(
        icon: PhosphorIconsLight.television,
        message: l10n.guideNoChannels,
      );
    } else {
      final timeRange = guideTimeRange(now, range.value, zoom);
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 20, 0),
            child: SizedBox(
              height: 150,
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) => GuideInfoPanel(
                  focus: _controller.focus,
                  nowMs: nowMs,
                  emptyHint: range.value == null ? l10n.guideNoEpgHint : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      KButton.secondary(
                        label: l10n.guideNow,
                        icon: PhosphorIconsBold.clock,
                        size: KButtonSize.small,
                        onPressed: _controller.jumpToNow,
                      ),
                      const SizedBox(width: 12),
                      KIconButton(
                        icon: PhosphorIconsRegular.x,
                        tooltip: l10n.guideCloseGuide,
                        size: 36,
                        iconSize: 18,
                        onPressed: widget.onClose,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GuideGrid(
              channels: list,
              cache: _cache,
              controller: _controller,
              nowMs: nowMs,
              rangeStartMs: timeRange.startMs,
              rangeEndMs: timeRange.endMs,
              zoomMinutes: zoom,
              timeFormat: fmt,
              noEpgLabel: l10n.guideNoEpg,
              reminderKeys: {
                for (final r in reminders ?? const <ReminderRow>[])
                  reminderKey(r.channelId, r.start),
              },
              initialChannelId: widget.currentChannelId,
              dayLabel: (day) => guideDayLabel(l10n, fmt, day, now),
              onDayTap: (rect) => _pickDay(rect, range.value),
              onActivate: (f) => unawaited(_activate(f)),
              onChannelActions: (channel, position) => unawaited(
                ref
                    .read(guideActionsProvider)
                    .showChannelActions(
                      context,
                      playlistId: _pid,
                      channelId: channel.providerId,
                      position: position,
                      categoryId: channel.row.categoryId,
                    ),
              ),
            ),
          ),
        ],
      );
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
      },
      child: Material(
        type: MaterialType.transparency,
        // The player dims the video behind; this layer only blocks input.
        child: Stack(
          children: [
            const Positioned.fill(
              child: AbsorbPointer(child: SizedBox.expand()),
            ),
            Positioned.fill(child: body),
          ],
        ),
      ),
    );
  }
}
