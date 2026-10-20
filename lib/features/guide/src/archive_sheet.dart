/// The "TV ARCHIVE • CATCH-UP" sheet: red day headers, rows with the red time
/// ("11:30 PM – ON AIR" for the programme on air), the title and one line of
/// description. A row plays the programme from the archive.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/clock.dart';
import '../../../app/time_format.dart';
import '../../../core/core.dart';
import '../../../data/repositories/repository_models.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../player/player_api.dart';
import '../data/guide_queries.dart';
import 'guide_actions.dart';

/// Opens the archive of [channelId]. [onPlay] replaces the default "open
/// the catch-up player" (called after the sheet closed).
Future<void> openArchiveSheet(
  BuildContext context, {
  required int playlistId,
  required String channelId,
  void Function(ProgrammeView programme)? onPlay,
}) => showKSheet<void>(
  context,
  width: 640,
  maxHeight: 840,
  scrollable: false,
  expand: true,
  child: ArchiveSheet(
    playlistId: playlistId,
    channelId: channelId,
    onPlay: onPlay,
  ),
);

class ArchiveSheet extends ConsumerWidget {
  const ArchiveSheet({
    super.key,
    required this.playlistId,
    required this.channelId,
    this.onPlay,
  });

  final int playlistId;
  final String channelId;
  final void Function(ProgrammeView programme)? onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final args = (playlistId: playlistId, channelId: channelId);
    final data = ref.watch(channelArchiveProvider(args));
    final channelName = data.value?.channel?.displayName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 30),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 64),
          child: Text(
            l10n.guideArchiveTitle,
            textAlign: TextAlign.center,
            style: KText.title.copyWith(letterSpacing: 0.2),
          ),
        ),
        if (channelName != null) ...[
          const SizedBox(height: 4),
          Text(
            channelName,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: KText.caption,
          ),
        ],
        const SizedBox(height: 18),
        Expanded(
          child: data.when(
            loading: () => const KLoadingState(),
            error: (e, st) => KErrorState(
              message: l10n.guideLoadError,
              onRetry: () => ref.invalidate(channelArchiveProvider(args)),
            ),
            data: (d) {
              final channel = d.channel;
              if (channel == null || !channel.hasArchive) {
                return KEmptyState(
                  icon: PhosphorIconsLight.clockCounterClockwise,
                  message: l10n.guideArchiveUnavailable,
                );
              }
              if (d.days.isEmpty) {
                return KEmptyState(
                  icon: PhosphorIconsLight.clockCounterClockwise,
                  message: l10n.guideArchiveEmpty,
                );
              }
              return _ArchiveList(
                playlistId: playlistId,
                channel: channel,
                days: d.days,
                onPlay: onPlay,
              );
            },
          ),
        ),
      ],
    );
  }
}

sealed class _Item {
  const _Item();
}

class _DayItem extends _Item {
  const _DayItem(this.day);
  final DateTime day;
}

class _RowItem extends _Item {
  const _RowItem(this.programme, {required this.first, required this.last});
  final ProgrammeView programme;
  final bool first;
  final bool last;
}

class _ArchiveList extends ConsumerWidget {
  const _ArchiveList({
    required this.playlistId,
    required this.channel,
    required this.days,
    required this.onPlay,
  });

  final int playlistId;
  final ChannelView channel;
  final List<ArchiveDay> days;
  final void Function(ProgrammeView programme)? onPlay;

  Future<void> _play(
    BuildContext context,
    WidgetRef ref,
    ProgrammeView p,
  ) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final actions = ref.read(guideActionsProvider);
    navigator.pop();
    final callback = onPlay;
    if (callback != null) {
      callback(p);
      return;
    }
    if (!navigator.mounted) return;
    await actions.openPlayer(
      navigator.context,
      CatchupPlayRequest(
        playlistId: playlistId,
        channelId: channel.providerId,
        startUtc: p.start,
        endUtc: p.stop,
        title: p.title,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final fmt = ref.watch(timeFormatProvider);
    final items = <_Item>[
      for (final day in days) ...[
        _DayItem(day.date),
        for (var i = 0; i < day.programmes.length; i++)
          _RowItem(
            day.programmes[i],
            first: i == 0,
            last: i == day.programmes.length - 1,
          ),
      ],
    ];
    final firstRow = items.indexWhere((i) => i is _RowItem);
    final now =
        ref.watch(minuteClockProvider).value ?? ref.read(clockSourceProvider)();
    final nowMs = now.millisecondsSinceEpoch;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        switch (item) {
          case _DayItem(:final day):
            return Padding(
              padding: EdgeInsets.only(top: index == 0 ? 0 : 22, bottom: 12),
              child: Text(
                fmt.dayHeader(day),
                style: KText.sectionTitle.copyWith(color: KColors.accent),
              ),
            );
          case _RowItem(:final programme, :final first, :final last):
            final onAir =
                programme.startMs <= nowMs && nowMs < programme.stopMs;
            final time = fmt.time(programme.start);
            return _ArchiveRow(
              key: ValueKey('archive-${programme.startMs}'),
              time: onAir ? l10n.guideArchiveOnAir(time) : time,
              title: programme.title,
              description: programme.description ?? programme.subTitle,
              first: first,
              last: last,
              autofocus: index == firstRow,
              onTap: () => _play(context, ref, programme),
            );
        }
      },
    );
  }
}

class _ArchiveRow extends StatelessWidget {
  const _ArchiveRow({
    super.key,
    required this.time,
    required this.title,
    required this.description,
    required this.first,
    required this.last,
    required this.autofocus,
    required this.onTap,
  });

  final String time;
  final String title;
  final String? description;
  final bool first;
  final bool last;
  final bool autofocus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.vertical(
      top: first ? const Radius.circular(KRadii.panel) : Radius.zero,
      bottom: last ? const Radius.circular(KRadii.panel) : Radius.zero,
    );
    return KInteractive(
      onTap: onTap,
      autofocus: autofocus,
      semanticLabel: '$time $title',
      builder: (context, state, _) {
        // Keyboard focus is the tvOS white pill; hover only lightens.
        final focused = state.focused;
        final background = focused
            ? KColors.textPrimary
            : state.hovered
            ? Color.lerp(KColors.tile, KColors.textPrimary, 0.06)!
            : KColors.tile;
        final titleColor = focused ? KColors.bg : KColors.textPrimary;
        final descriptionColor = focused
            ? KColors.textTertiary
            : KColors.textSecondary;
        return Container(
          decoration: BoxDecoration(color: background, borderRadius: radius),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: last || focused
                  ? null
                  : const Border(bottom: BorderSide(color: KColors.separator)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  time,
                  style: KText.time.copyWith(
                    color: KColors.accent,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KText.channelName.copyWith(color: titleColor),
                ),
                if (description != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KText.bodySecondary.copyWith(
                      fontSize: 14,
                      color: descriptionColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
