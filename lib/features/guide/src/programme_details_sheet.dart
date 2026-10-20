/// Programme details modal: title, time, duration,
/// description, category, episode, channel, with Watch live / Play from
/// start / Remind me.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/clock.dart';
import '../../../app/time_format.dart';
import '../../../core/core.dart';
import '../../../data/repositories/reminders_repository.dart';
import '../../../data/repositories/repository_models.dart';
import '../../../data/text/flags.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../player/player_api.dart';
import '../../reminders/reminders_api.dart';
import '../data/guide_queries.dart';
import 'guide_actions.dart';
import 'guide_days.dart';

/// Opens the details sheet. [onWatchLive] / [onPlayFromStart] replace the
/// default "open the player" (the Full TV Guide tunes the running player
/// instead); both are called after the sheet closed.
Future<void> openProgrammeDetailsSheet(
  BuildContext context, {
  required int playlistId,
  required String channelId,
  required DateTime startUtc,
  VoidCallback? onWatchLive,
  void Function(DateTime startUtc, DateTime endUtc)? onPlayFromStart,
}) => showKSheet<void>(
  context,
  width: 640,
  child: ProgrammeDetailsSheet(
    playlistId: playlistId,
    channelId: channelId,
    startUtc: startUtc,
    onWatchLive: onWatchLive,
    onPlayFromStart: onPlayFromStart,
  ),
);

class ProgrammeDetailsSheet extends ConsumerWidget {
  const ProgrammeDetailsSheet({
    super.key,
    required this.playlistId,
    required this.channelId,
    required this.startUtc,
    this.onWatchLive,
    this.onPlayFromStart,
  });

  final int playlistId;
  final String channelId;
  final DateTime startUtc;
  final VoidCallback? onWatchLive;
  final void Function(DateTime startUtc, DateTime endUtc)? onPlayFromStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final args = (
      playlistId: playlistId,
      channelId: channelId,
      startMs: startUtc.millisecondsSinceEpoch,
    );
    final data = ref.watch(channelProgrammeProvider(args));
    return data.when(
      loading: () => const SizedBox(height: 280, child: KLoadingState()),
      error: (e, st) => KErrorState(
        message: l10n.guideProgrammeNotFound,
        onRetry: () => ref.invalidate(channelProgrammeProvider(args)),
      ),
      data: (d) {
        final channel = d.channel;
        final programme = d.programme;
        if (channel == null || programme == null) {
          return KEmptyState(
            icon: PhosphorIconsLight.calendarX,
            message: l10n.guideProgrammeNotFound,
          );
        }
        return _DetailsBody(
          playlistId: playlistId,
          channel: channel,
          programme: programme,
          onWatchLive: onWatchLive,
          onPlayFromStart: onPlayFromStart,
        );
      },
    );
  }
}

class _DetailsBody extends ConsumerWidget {
  const _DetailsBody({
    required this.playlistId,
    required this.channel,
    required this.programme,
    required this.onWatchLive,
    required this.onPlayFromStart,
  });

  final int playlistId;
  final ChannelView channel;
  final ProgrammeView programme;
  final VoidCallback? onWatchLive;
  final void Function(DateTime startUtc, DateTime endUtc)? onPlayFromStart;

  Future<void> _watchLive(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final actions = ref.read(guideActionsProvider);
    navigator.pop();
    final callback = onWatchLive;
    if (callback != null) {
      callback();
      return;
    }
    if (!navigator.mounted) return;
    await actions.openPlayer(
      navigator.context,
      LivePlayRequest(
        playlistId: playlistId,
        channelId: channel.providerId,
        categoryId: channel.row.categoryId,
      ),
    );
  }

  Future<void> _playFromStart(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final actions = ref.read(guideActionsProvider);
    navigator.pop();
    final callback = onPlayFromStart;
    if (callback != null) {
      callback(programme.start, programme.stop);
      return;
    }
    if (!navigator.mounted) return;
    await actions.openPlayer(
      navigator.context,
      CatchupPlayRequest(
        playlistId: playlistId,
        channelId: channel.providerId,
        startUtc: programme.start,
        endUtc: programme.stop,
        title: programme.title,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final fmt = ref.watch(timeFormatProvider);
    final now =
        ref.watch(minuteClockProvider).value ?? ref.read(clockSourceProvider)();
    final reminders = ref.watch(
      channelRemindersProvider((
        playlistId: playlistId,
        channelId: channel.providerId,
      )),
    );
    final p = programme;
    final reminderSet =
        reminders.value?.any((r) => r.start == p.startMs) ?? false;
    final onAir = p.isOnAirAt(now);
    final upcoming = p.isUpcomingAt(now);
    final replayable = p.isReplayableWith(channel.archiveDays, now);
    final startOver = onAir && channel.hasArchive;
    final day = guideDayLabel(l10n, fmt, p.start, now);
    final minutes = (p.duration.inSeconds / 60).round();
    final meta = <(String, String)>[
      if (p.category != null) (l10n.guideCategoryLabel, p.category!),
      if (p.episodeNum != null) (l10n.guideEpisodeLabel, p.episodeNum!),
      if (p.rating != null) (l10n.guideRatingLabel, p.rating!),
    ];
    final subTitle = p.subTitle;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 48),
            child: Row(
              children: [
                KLogoTile(
                  name: channel.displayName,
                  url: channel.logo,
                  size: 44,
                  radius: 6,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        channel.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KText.channelName,
                      ),
                      if (channel.categoryName.isNotEmpty)
                        Text(
                          flagged(channel.categoryName),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: KText.caption.copyWith(
                            fontFamilyFallback: KText.emojiFallback,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            p.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: KText.largeTitle,
          ),
          if (subTitle != null && subTitle != p.title) ...[
            const SizedBox(height: 4),
            Text(
              subTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: KText.bodySecondary,
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '$day · ${fmt.range(p.start, p.stop)} · '
                '${l10n.guideDurationMinutes(minutes)}',
                style: KText.bodySecondary.copyWith(
                  fontWeight: FontWeight.w500,
                  fontFeatures: KText.tabular,
                ),
              ),
              if (onAir) KLivePill(label: l10n.guideOnAir),
            ],
          ),
          if (onAir) ...[
            const SizedBox(height: 12),
            KProgressBar(value: p.progressAt(now)),
          ],
          const SizedBox(height: 18),
          Text(
            p.description ?? l10n.guideNoDescription,
            maxLines: 12,
            overflow: TextOverflow.ellipsis,
            style: p.description == null ? KText.bodySecondary : KText.body,
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 18),
            Wrap(
              spacing: 22,
              runSpacing: 8,
              children: [
                for (final (label, value) in meta)
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$label  ',
                          style: KText.label.copyWith(
                            color: KColors.textTertiary,
                          ),
                        ),
                        TextSpan(
                          text: value,
                          style: KText.label.copyWith(
                            color: KColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 26),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (onAir)
                KButton.primaryWhite(
                  label: l10n.guideWatchLive,
                  icon: PhosphorIconsFill.play,
                  autofocus: true,
                  onPressed: () => _watchLive(context, ref),
                ),
              if (startOver || replayable)
                KButton(
                  variant: onAir
                      ? KButtonVariant.secondary
                      : KButtonVariant.primaryWhite,
                  label: l10n.guidePlayFromStart,
                  icon: PhosphorIconsBold.arrowCounterClockwise,
                  autofocus: !onAir,
                  onPressed: () => _playFromStart(context, ref),
                ),
              if (upcoming)
                KButton(
                  variant: reminderSet
                      ? KButtonVariant.secondary
                      : KButtonVariant.primaryWhite,
                  label: reminderSet
                      ? l10n.guideReminderSet
                      : l10n.guideRemindMe,
                  icon: reminderSet
                      ? PhosphorIconsFill.bellRinging
                      : PhosphorIconsBold.bell,
                  autofocus: true,
                  onPressed: () => toggleReminder(
                    context,
                    playlistId: playlistId,
                    channelId: channel.providerId,
                    startUtc: p.start,
                  ),
                ),
            ],
          ),
          if (upcoming) ...[
            const SizedBox(height: 10),
            Text(
              l10n.guideReminderNote,
              style: KText.caption.copyWith(color: KColors.textTertiary),
            ),
          ],
          if (p.hasEndedAt(now) && !replayable)
            Text(
              l10n.guideNotInArchive,
              style: KText.caption.copyWith(color: KColors.textTertiary),
            ),
        ],
      ),
    );
  }
}
