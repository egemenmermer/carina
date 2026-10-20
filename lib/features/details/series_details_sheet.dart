import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/time_format.dart';
import '../../core/core.dart';
import '../../data/db/database.dart';
import '../../data/repositories/vod_repository.dart';
import '../../data/repositories/watch_state_repository.dart';
import '../../data/sources/xtream/json_utils.dart' show asDate;
import '../../l10n/gen/app_localizations.dart';
import '../home_movies/data/vod_providers.dart';
import '../home_movies/widgets/vod_actions.dart';
import '../home_movies/widgets/vod_art.dart';
import '../home_movies/widgets/vod_hero.dart';
import 'details_parts.dart';

/// Series detail sheet: artwork with a ring play button and, when in progress,
/// "Continue watching / Name S1 E5: "Title"" with a red progress bar; title;
/// rating + outlined age; `5 SEASONS | January 2008`; overview; cast (opens the
/// person search) and genres; pinned season tabs (Season 1…N, Special contents)
/// with Refresh episodes; episode rows with thumbnail, play ring, `S1 E1`, red
/// progress, red eye when watched, `Title (43m)`, air date and a 3-line
/// overview. Right-click an episode: Play, Mark as watched / unwatched, Mark
/// all previous as watched.
class SeriesDetailsSheet extends ConsumerStatefulWidget {
  const SeriesDetailsSheet({
    super.key,
    required this.playlistId,
    required this.seriesId,
    this.initialSeason,
  });

  final int playlistId;
  final String seriesId;

  /// Season tab to open (default: the Continue watching season, else the
  /// first one).
  final int? initialSeason;

  @override
  ConsumerState<SeriesDetailsSheet> createState() => _SeriesDetailsState();
}

class _SeriesDetailsState extends ConsumerState<SeriesDetailsSheet> {
  int? _season;
  bool _refreshing = false;

  int get _pid => widget.playlistId;
  String get _sid => widget.seriesId;

  ({int playlistId, String providerId}) get _ids =>
      (playlistId: _pid, providerId: _sid);

  @override
  void initState() {
    super.initState();
    _season = widget.initialSeason;
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    final l10n = L10n.of(context);
    final toast = ref.read(toastControllerProvider);
    setState(() => _refreshing = true);
    SeriesDetails? result;
    try {
      result = await ref
          .read(vodRepositoryProvider)
          .refreshEpisodes(_pid, _sid);
    } finally {
      if (mounted) {
        ref.invalidate(seriesDetailsProvider(_ids));
        setState(() => _refreshing = false);
      }
    }
    if (result == null || result.error != null) {
      toast.show(
        l10n.vodToastEpisodesFailed,
        kind: KToastKind.error,
        icon: PhosphorIconsLight.warningCircle,
      );
    } else {
      toast.show(l10n.vodToastEpisodesUpdated);
    }
  }

  Future<void> _episodeMenu(
    EpisodeItem episode,
    bool watched,
    Offset position,
  ) async {
    final l10n = L10n.of(context);
    final action = await showKContextMenu<int>(
      context,
      position: position,
      title: episode.label,
      entries: [
        KMenuEntry(
          label: l10n.vodPlay,
          icon: PhosphorIconsLight.play,
          value: 0,
        ),
        const KMenuEntry.separator(),
        KMenuEntry(
          label: watched ? l10n.vodMarkUnwatched : l10n.vodMarkWatched,
          icon: watched ? PhosphorIconsLight.eyeClosed : PhosphorIconsLight.eye,
          value: 1,
        ),
        KMenuEntry(
          label: l10n.vodMarkPreviousWatched,
          icon: PhosphorIconsLight.checks,
          value: 2,
        ),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 0:
        await _playEpisode(episode, null);
      case 1:
        await setVodWatched(
          context,
          playlistId: _pid,
          type: ItemType.episode,
          providerId: episode.providerId,
          watched: !watched,
          seriesId: _sid,
        );
      case 2:
        await markPreviousEpisodesWatched(
          context,
          playlistId: _pid,
          episode: episode,
        );
    }
  }

  Future<void> _playEpisode(EpisodeItem episode, WatchState? state) =>
      playEpisode(
        context,
        playlistId: _pid,
        seriesId: _sid,
        episodeId: episode.providerId,
        resume: state != null && state.inProgress ? true : null,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final key = (playlistId: _pid, kind: SectionKind.series, providerId: _sid);
    final itemAsync = ref.watch(vodItemProvider(key));
    final item = itemAsync.value;
    if (item == null) {
      if (!itemAsync.hasValue && !itemAsync.hasError) {
        return const KLoadingState();
      }
      return KEmptyState(
        icon: PhosphorIconsLight.television,
        message: l10n.vodDetailsMissing,
      );
    }
    final detailsAsync = ref.watch(seriesDetailsProvider(_ids));
    final details = detailsAsync.value;
    final meta = ref.watch(vodMetaProvider(key)) ?? buildVodMeta(item: item);
    final states =
        ref
            .watch(episodeStatesProvider((playlistId: _pid, seriesId: _sid)))
            .value ??
        const <String, WatchState>{};
    final entry = ref
        .watch(
          continueWatchingProvider((
            playlistId: _pid,
            kind: SectionKind.series,
          )),
        )
        .value
        ?.firstWhereOrNull((e) => e.item.providerId == _sid);
    final fmt = ref.watch(timeFormatProvider);
    final title = meta.title.isEmpty ? l10n.vodUntitled : meta.title;

    final seasons = details?.seasons ?? const <SeasonDetails>[];
    final selected = _season ?? entry?.episode?.season;
    final season =
        seasons.firstWhereOrNull((s) => s.number == selected) ??
        seasons.firstOrNull;

    final continueEpisode = entry?.episode;
    final Widget? overlay = continueEpisode == null
        ? null
        : DetailsContinueOverlay(
            heading: l10n.vodContinueWatching,
            label: continueEpisode.title.trim().isEmpty
                ? '$title ${continueEpisode.code}'
                : '$title ${continueEpisode.code}: '
                      '"${continueEpisode.title.trim()}"',
            progress: entry!.progress,
          );

    final info = <Widget>[
      Row(
        children: [
          if (meta.hasRating) VodRatingLine(meta: meta, style: KText.body),
          if (meta.ageRating != null) ...[
            const SizedBox(width: 12),
            DetailsAgeBadge(meta.ageRating!),
          ],
          if (detailsAsync.isLoading) ...[
            const SizedBox(width: 14),
            const KSpinner(size: 16, strokeWidth: 2),
          ],
        ],
      ),
      if (_factLine(l10n, meta, details, fmt) case final line?) ...[
        const SizedBox(height: 6),
        Text(
          line,
          style: KText.bodySecondary.copyWith(fontSize: 15, letterSpacing: 0.2),
        ),
      ],
      if (meta.overview != null) ...[
        const SizedBox(height: 16),
        Text(
          meta.overview!,
          style: KText.body.copyWith(fontSize: 16, height: 1.4),
        ),
      ],
      const SizedBox(height: 10),
      if (meta.cast.isNotEmpty)
        DetailsPeopleLine(
          label: l10n.vodCastLabel,
          names: meta.cast.take(8).toList(),
          onPerson: (person) =>
              openPersonFromSheet(context, playlistId: _pid, person: person),
        ),
      if (meta.genres.isNotEmpty)
        DetailsInfoLine(
          label: l10n.vodGenresLabel,
          value: meta.genres.join(', '),
        ),
      if (details?.error != null) ...[
        const SizedBox(height: 14),
        DetailsNotice(message: l10n.vodDetailsCached),
      ],
    ];

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: DetailsBackdrop(
            meta: meta,
            playLabel: continueEpisode == null
                ? l10n.vodPlay
                : l10n.vodPlayEpisode(continueEpisode.code),
            onPlay: () => playSeries(context, playlistId: _pid, seriesId: _sid),
            overlay: overlay,
          ),
        ),
        SliverToBoxAdapter(
          child: DetailsTitle(meta: meta, title: title),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              kDetailsPadding,
              20,
              kDetailsPadding,
              18,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: info,
            ),
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _SeasonTabsDelegate(
            tabs: [
              for (final s in seasons)
                KNavTab(id: '${s.number}', label: l10n.seasonLabel(s.number)),
            ],
            active: season == null ? null : '${season.number}',
            onSelected: (id) => setState(() => _season = int.tryParse(id)),
            refreshing: _refreshing,
            refreshLabel: l10n.vodRefreshEpisodes,
            onRefresh: _refresh,
          ),
        ),
        if (season == null)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: detailsAsync.isLoading || _refreshing
                  ? const KLoadingState()
                  : KEmptyState(message: l10n.vodNoEpisodes),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              kDetailsPadding - 10,
              10,
              kDetailsPadding - 10,
              28,
            ),
            sliver: SliverList.builder(
              itemCount: season.episodes.length,
              itemBuilder: (context, i) {
                final episode = season.episodes[i];
                final state = states[episode.providerId];
                final date = asDate(episode.releaseDate);
                return _EpisodeRow(
                  key: ValueKey(episode.providerId),
                  episode: episode,
                  state: state,
                  dateText: date == null ? episode.releaseDate : fmt.date(date),
                  runtimeText: episode.duration == null
                      ? null
                      : fmt.runtime(episode.duration!),
                  fallbackArt: meta.backdropUrl,
                  posterUrl: meta.posterUrl,
                  watchedLabel: l10n.vodWatched,
                  onPlay: () => _playEpisode(episode, state),
                  onMenu: (position) =>
                      _episodeMenu(episode, state?.finished ?? false, position),
                );
              },
            ),
          ),
      ],
    );
  }

  /// `5 SEASONS | January 2008`.
  static String? _factLine(
    L10n l10n,
    VodMeta meta,
    SeriesDetails? details,
    CarinaTimeFormat fmt,
  ) {
    final seasons = meta.seasonCount;
    final date = meta.releaseDate;
    final parts = [
      if (seasons != null && seasons > 0) l10n.vodSeasonsUpper(seasons),
      if (date != null)
        fmt.monthYear(date)
      else if (meta.year != null)
        '${meta.year}',
    ];
    return parts.isEmpty ? null : parts.join('  |  ');
  }
}

class _SeasonTabsDelegate extends SliverPersistentHeaderDelegate {
  _SeasonTabsDelegate({
    required this.tabs,
    required this.active,
    required this.onSelected,
    required this.refreshing,
    required this.refreshLabel,
    required this.onRefresh,
  });

  final List<KNavTab> tabs;
  final String? active;
  final ValueChanged<String> onSelected;
  final bool refreshing;
  final String refreshLabel;
  final VoidCallback onRefresh;

  static const double _height = 58;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      height: _height,
      decoration: BoxDecoration(
        color: KColors.bg,
        border: Border(
          bottom: BorderSide(
            color: overlapsContent || shrinkOffset > 0
                ? KColors.stroke
                : const Color(0x00000000),
          ),
        ),
      ),
      padding: const EdgeInsets.only(left: kDetailsPadding - 2, right: 20),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: KUnderlineTabs(
                tabs: tabs,
                activeTabId: active,
                onTabSelected: onSelected,
                spacing: 30,
                style: KText.button.copyWith(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          refreshing
              ? const SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(child: KSpinner(size: 18, strokeWidth: 2)),
                )
              : KIconButton(
                  icon: PhosphorIconsLight.arrowClockwise,
                  tooltip: refreshLabel,
                  iconSize: 18,
                  onPressed: onRefresh,
                ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_SeasonTabsDelegate old) =>
      old.active != active ||
      old.refreshing != refreshing ||
      old.refreshLabel != refreshLabel ||
      !const ListEquality<String>().equals(
        [for (final t in old.tabs) '${t.id}|${t.label}'],
        [for (final t in tabs) '${t.id}|${t.label}'],
      );
}

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({
    super.key,
    required this.episode,
    required this.state,
    required this.dateText,
    required this.runtimeText,
    required this.fallbackArt,
    required this.posterUrl,
    required this.watchedLabel,
    required this.onPlay,
    required this.onMenu,
  });

  final EpisodeItem episode;
  final WatchState? state;
  final String? dateText;
  final String? runtimeText;
  final String? fallbackArt;
  final String? posterUrl;
  final String watchedLabel;
  final VoidCallback onPlay;
  final KContextMenuCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final watched = state?.finished ?? false;
    final progress = state != null && state!.inProgress
        ? state!.fraction
        : null;
    final title = episode.title.trim().isEmpty
        ? episode.code
        : episode.title.trim();
    return KInteractive(
      onTap: onPlay,
      onContextMenu: onMenu,
      semanticLabel: '${episode.code} $title',
      builder: (context, s, _) {
        final duration = KMotion.of(context, KDurations.hover);
        return AnimatedContainer(
          duration: duration,
          curve: KMotion.hover,
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: s.highlighted
                ? const Color(0x14FFFFFF)
                : const Color(0x00FFFFFF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: s.focused ? KColors.focusRing : const Color(0x00F5F5F5),
              width: 2,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 176,
                height: 99,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(KRadii.poster),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      VodArt(
                        url: episode.image ?? fallbackArt,
                        blurUrl: posterUrl,
                        title: episode.code,
                        wide: true,
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0.5, 1],
                            colors: [Color(0x00000000), Color(0x99000000)],
                          ),
                        ),
                      ),
                      Center(
                        child: VodPlayRing(
                          size: 36,
                          highlighted: s.highlighted,
                        ),
                      ),
                      Positioned(
                        right: 8,
                        bottom: progress != null ? 9 : 6,
                        child: Text(
                          episode.code,
                          style: KText.cardTitle.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            shadows: const [
                              Shadow(color: Color(0xCC000000), blurRadius: 6),
                            ],
                          ),
                        ),
                      ),
                      if (watched)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: VodWatchedBadge(
                            size: 22,
                            semanticLabel: watchedLabel,
                          ),
                        ),
                      if (progress != null)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: KProgressBar(
                            value: progress,
                            height: 4,
                            rounded: false,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: title),
                          if (runtimeText != null)
                            TextSpan(
                              text: '  ($runtimeText)',
                              style: KText.channelName.copyWith(
                                fontWeight: FontWeight.w400,
                                color: KColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KText.channelName,
                    ),
                    if (dateText != null && dateText!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          dateText!,
                          style: KText.caption.copyWith(fontSize: 14),
                        ),
                      ),
                    if (episode.plot != null &&
                        episode.plot!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        episode.plot!.trim(),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: KText.body.copyWith(
                          fontSize: 15,
                          color: const Color(0xFFD6D6D6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
