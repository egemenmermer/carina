import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/clock.dart';
import '../../app/platform/form_factor.dart';
import '../../app/shell/category_selection.dart';
import '../../app/time_format.dart';
import '../../core/core.dart';
import '../../data/db/database.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/epg_repository.dart';
import '../../data/repositories/live_repository.dart';
import '../../data/repositories/playlist_repository.dart';
import '../../data/repositories/reminders_repository.dart';
import '../../data/repositories/repository_models.dart';
import '../../data/settings/settings_store.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../player/engine/playback_engine.dart';
import '../../player/player_api.dart';
import 'src/guide_actions.dart';
import 'src/guide_cache.dart';
import 'src/guide_cells.dart';
import 'src/guide_controller.dart';
import 'src/guide_days.dart';
import 'src/guide_grid.dart';
import 'src/guide_info_panel.dart';
import 'src/guide_preview.dart';
import 'src/programme_details_sheet.dart';

/// The TV Guide tab: live preview and the focused programme above a grid of the
/// active category's channels.
class GuideScreen extends ConsumerStatefulWidget {
  const GuideScreen({super.key, required this.playlistId});
  final int playlistId;

  @override
  ConsumerState<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends ConsumerState<GuideScreen> {
  late final GuideProgrammeCache _cache = GuideProgrammeCache(
    (keys, from, to) => ref
        .read(epgRepositoryProvider)
        .guide(widget.playlistId, keys, from, to),
  );
  final GuideGridController _controller = GuideGridController();
  final ValueNotifier<EngineStats?> _stats = ValueNotifier<EngineStats?>(null);
  bool _playerOpen = false;
  List<ReminderRow>? _reminderRows;
  Set<String> _reminderKeys = const {};

  int get _pid => widget.playlistId;

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      playlistProvider(_pid).select((p) => p.value?.lastEpgReloadAt),
      (previous, next) {
        if (previous != null && previous != next) _cache.clear();
      },
    );
  }

  @override
  void dispose() {
    _cache.dispose();
    _controller.dispose();
    _stats.dispose();
    super.dispose();
  }

  DateTime _now() =>
      ref.read(minuteClockProvider).value ?? ref.read(clockSourceProvider)();

  Set<String> _keysOf(List<ReminderRow>? rows) {
    if (identical(rows, _reminderRows)) return _reminderKeys;
    _reminderRows = rows;
    _reminderKeys = {
      for (final r in rows ?? const <ReminderRow>[])
        reminderKey(r.channelId, r.start),
    };
    return _reminderKeys;
  }

  Future<void> _withPlayer(Future<void> Function() open) async {
    setState(() => _playerOpen = true);
    try {
      await open();
    } finally {
      if (mounted) setState(() => _playerOpen = false);
    }
  }

  Future<void> _activate(
    GuideFocus f,
    List<ChannelView> channels,
    CategoryView category,
  ) async {
    final actions = ref.read(guideActionsProvider);
    final cell = f.cell;
    final channel = f.channel;
    switch (guideCellAction(f, _now().millisecondsSinceEpoch)) {
      case GuideCellAction.watchLive:
        if (!mounted) return;
        await _withPlayer(
          () => actions.openPlayer(
            context,
            LivePlayRequest(
              playlistId: _pid,
              channelId: channel.providerId,
              zapChannelIds: [for (final c in channels) c.providerId],
              categoryId: category.providerId,
            ),
          ),
        );
      case GuideCellAction.catchup:
        if (!mounted) return;
        await _withPlayer(
          () => actions.openPlayer(
            context,
            CatchupPlayRequest(
              playlistId: _pid,
              channelId: channel.providerId,
              startUtc: cell.start,
              endUtc: cell.stop,
              title: cell.programme!.title,
            ),
          ),
        );
      case GuideCellAction.details:
        await openProgrammeDetailsSheet(
          context,
          playlistId: _pid,
          channelId: channel.providerId,
          startUtc: cell.start,
        );
      case GuideCellAction.none:
        break;
    }
  }

  Future<void> _pickDay(Rect anchor, EpgDataRange? range) async {
    final l10n = L10n.of(context);
    final fmt = ref.read(timeFormatProvider);
    final now = _now();
    final focused = _controller.focus?.cell.start ?? now;
    final visible = _controller.visibleStartMs;
    final current = localDay(
      visible == null
          ? focused
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
    final scope = (playlistId: _pid, kind: SectionKind.live);
    final category = ref.watch(activeCategoryProvider(scope));
    return category.when(
      skipLoadingOnReload: true,
      loading: () => const KLoadingState(),
      error: (e, st) => KErrorState(
        message: l10n.guideLoadError,
        onRetry: () => ref.invalidate(categoriesProvider(scope)),
      ),
      data: (cat) {
        if (cat == null) {
          return KEmptyState(
            icon: PhosphorIconsLight.television,
            title: l10n.guideNoChannels,
            message: l10n.guideNoChannelsHint,
          );
        }
        return _buildCategory(context, cat);
      },
    );
  }

  Widget _buildCategory(BuildContext context, CategoryView category) {
    final l10n = L10n.of(context);
    final args = (playlistId: _pid, category: category.ref);
    final channels = ref.watch(channelsProvider(args));
    final range = ref.watch(epgDataRangeProvider(_pid));
    if (!range.hasValue && range.isLoading) return const KLoadingState();
    return channels.when(
      skipLoadingOnReload: true,
      loading: () => const KLoadingState(),
      error: (e, st) => KErrorState(
        message: l10n.guideLoadError,
        onRetry: () => ref.invalidate(channelsProvider(args)),
      ),
      data: (list) {
        if (list.isEmpty) {
          return KEmptyState(
            icon: PhosphorIconsLight.television,
            title: l10n.guideNoChannels,
            message: l10n.guideNoChannelsHint,
          );
        }
        return _buildGuide(context, category, list, range.value);
      },
    );
  }

  Widget _buildGuide(
    BuildContext context,
    CategoryView category,
    List<ChannelView> channels,
    EpgDataRange? range,
  ) {
    final l10n = L10n.of(context);
    final fmt = ref.watch(timeFormatProvider);
    final now =
        ref.watch(minuteClockProvider).value ?? ref.read(clockSourceProvider)();
    final nowMs = now.millisecondsSinceEpoch;
    final zoom = ref.watchSetting(
      PlaylistSettings.guideZoomMinutes,
      playlistId: _pid,
    );
    final reminders = ref.watch(remindersProvider(_pid)).value;
    final timeRange = guideTimeRange(now, range, zoom);
    final emptyHint = range == null ? l10n.guideNoEpgHint : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final previewWidth = (constraints.maxWidth * 0.3).roundToDouble();
        final previewHeight = (previewWidth * 9 / 16).roundToDouble();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: SizedBox(
                height: previewHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: previewWidth,
                      child: ListenableBuilder(
                        listenable: _controller,
                        builder: (context, _) {
                          final channel = _controller.focus?.channel;
                          return GuidePreview(
                            playlistId: _pid,
                            channel: channel,
                            stats: _stats,
                            suspended: _playerOpen,
                            progress: channel == null
                                ? null
                                : _onAirProgress(channel, nowMs),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ListenableBuilder(
                        listenable: Listenable.merge([_controller, _stats]),
                        builder: (context, _) => GuideInfoPanel(
                          focus: _controller.focus,
                          nowMs: nowMs,
                          stats: _stats.value,
                          emptyHint: emptyHint,
                          trailing: _Toolbar(
                            nowLabel: l10n.guideNow,
                            nowTooltip: l10n.guideJumpToNow,
                            dayLabel: guideDayLabel(
                              l10n,
                              fmt,
                              _controller.focus?.cell.start ?? now,
                              now,
                            ),
                            onNow: _controller.jumpToNow,
                            onDay: (rect) => _pickDay(rect, range),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: GuideGrid(
                key: ValueKey('guide-grid-${category.ref.key}'),
                channels: channels,
                cache: _cache,
                controller: _controller,
                nowMs: nowMs,
                rangeStartMs: timeRange.startMs,
                rangeEndMs: timeRange.endMs,
                zoomMinutes: zoom,
                timeFormat: fmt,
                noEpgLabel: l10n.guideNoEpg,
                reminderKeys: _keysOf(reminders),
                dayLabel: (day) => guideDayLabel(l10n, fmt, day, now),
                tv: ref.watch(formFactorProvider).isTv,
                onDayTap: (rect) => _pickDay(rect, range),
                onActivate: (f) => unawaited(_activate(f, channels, category)),
                onChannelActions: (channel, position) => unawaited(
                  ref
                      .read(guideActionsProvider)
                      .showChannelActions(
                        context,
                        playlistId: _pid,
                        channelId: channel.providerId,
                        position: position,
                        categoryId: category.providerId,
                      ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  double? _onAirProgress(ChannelView channel, int nowMs) {
    final cell = cellAt(_cache, channel.epgKey, nowMs);
    return cell.isProgramme ? cell.progressAt(nowMs) : null;
  }
}

/// "Now" and the day picker button, top-right of the info panel.
class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.nowLabel,
    required this.nowTooltip,
    required this.dayLabel,
    required this.onNow,
    required this.onDay,
  });

  final String nowLabel;
  final String nowTooltip;
  final String dayLabel;
  final VoidCallback onNow;
  final ValueChanged<Rect> onDay;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: nowTooltip,
          child: KButton.secondary(
            label: nowLabel,
            icon: PhosphorIconsBold.clock,
            size: KButtonSize.small,
            onPressed: onNow,
          ),
        ),
        const SizedBox(width: 8),
        Builder(
          builder: (context) => KButton.secondary(
            label: dayLabel,
            icon: PhosphorIconsBold.calendarBlank,
            size: KButtonSize.small,
            onPressed: () {
              final box = context.findRenderObject() as RenderBox?;
              if (box == null || !box.hasSize) return;
              onDay(box.localToGlobal(Offset.zero) & box.size);
            },
          ),
        ),
      ],
    );
  }
}
