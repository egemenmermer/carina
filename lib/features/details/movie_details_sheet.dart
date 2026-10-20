import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/time_format.dart' show CarinaTimeFormat;
import '../../core/core.dart';
import '../../data/db/database.dart';
import '../../data/repositories/vod_repository.dart';
import '../../data/repositories/watch_state_repository.dart';
import '../../data/settings/settings_store.dart';
import '../../l10n/gen/app_localizations.dart';
import '../home_movies/data/vod_providers.dart';
import '../home_movies/widgets/vod_actions.dart';
import '../home_movies/widgets/vod_hero.dart';
import 'details_parts.dart';

/// Movie detail sheet: artwork with a ring play button, title
/// (logo art with TMDb), rating + age, `Science Fiction • Crime • 15+ •
/// 114'`, Play / Resume from mm:ss / From the beginning, Add to favorites,
/// Mark as watched, overview, cast (opens the person search), genres,
/// director and the technical badges from `get_vod_info`.
class MovieDetailsSheet extends ConsumerWidget {
  const MovieDetailsSheet({
    super.key,
    required this.playlistId,
    required this.movieId,
  });

  final int playlistId;
  final String movieId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final key = (
      playlistId: playlistId,
      kind: SectionKind.movie,
      providerId: movieId,
    );
    final itemAsync = ref.watch(vodItemProvider(key));
    final item = itemAsync.value;
    if (item == null) {
      if (!itemAsync.hasValue && !itemAsync.hasError) {
        return const SizedBox(height: 460, child: KLoadingState());
      }
      return SizedBox(
        height: 320,
        child: KEmptyState(
          icon: PhosphorIconsLight.filmSlate,
          message: l10n.vodDetailsMissing,
        ),
      );
    }
    final details = ref.watch(
      movieDetailsProvider((playlistId: playlistId, providerId: movieId)),
    );
    final meta = ref.watch(vodMetaProvider(key)) ?? buildVodMeta(item: item);
    final state = ref
        .watch(
          watchStateProvider((
            playlistId: playlistId,
            type: ItemType.movie,
            providerId: movieId,
          )),
        )
        .value;
    final alwaysResume = ref.watchSetting(
      PlaylistSettings.alwaysResume,
      playlistId: playlistId,
    );
    final decision = ref
        .read(watchStateRepositoryProvider)
        .resumeFor(state, alwaysResume: alwaysResume);
    final inProgress = decision.kind != ResumeKind.none;
    final title = meta.title.isEmpty ? l10n.vodUntitled : meta.title;
    final error = details.value?.error;

    void play({bool? resume}) => playMovie(
      context,
      playlistId: playlistId,
      movieId: movieId,
      resume: resume,
    );

    final factLine = _factLine(meta);
    final technical = meta.technical?.badges ?? const <String>[];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DetailsBackdrop(
          meta: meta,
          playLabel: inProgress
              ? l10n.vodResumeFrom(CarinaTimeFormat.clock(decision.position))
              : l10n.vodPlay,
          onPlay: () => play(resume: inProgress ? true : null),
          overlay: inProgress && state != null
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: KProgressBar(value: state.fraction ?? 0, height: 4),
                )
              : null,
        ),
        DetailsTitle(meta: meta, title: title),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            kDetailsPadding,
            20,
            kDetailsPadding,
            32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (meta.hasRating)
                    VodRatingLine(meta: meta, style: KText.body),
                  if (details.isLoading) ...[
                    const SizedBox(width: 14),
                    const KSpinner(size: 16, strokeWidth: 2),
                  ],
                ],
              ),
              if (factLine.isNotEmpty) ...[
                const SizedBox(height: 8),
                _FactLine(parts: factLine),
              ],
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (inProgress) ...[
                    KButton.primaryWhite(
                      label: l10n.vodResumeFrom(
                        CarinaTimeFormat.clock(decision.position),
                      ),
                      icon: PhosphorIconsFill.play,
                      onPressed: () => play(resume: true),
                    ),
                    KButton.secondary(
                      label: l10n.vodFromBeginning,
                      icon: PhosphorIconsBold.arrowCounterClockwise,
                      onPressed: () => play(resume: false),
                    ),
                  ] else
                    KButton.primaryWhite(
                      label: l10n.vodPlay,
                      icon: PhosphorIconsFill.play,
                      minWidth: 140,
                      onPressed: () => play(),
                    ),
                  KButton.secondary(
                    label: item.isFavorite
                        ? l10n.vodRemoveFromFavorites
                        : l10n.vodAddToFavorites,
                    icon: item.isFavorite
                        ? PhosphorIconsFill.star
                        : PhosphorIconsLight.star,
                    onPressed: () => toggleVodFavorite(
                      context,
                      playlistId: playlistId,
                      type: ItemType.movie,
                      providerId: movieId,
                    ),
                  ),
                  KIconButton(
                    icon: item.watched
                        ? PhosphorIconsLight.eyeClosed
                        : PhosphorIconsLight.eye,
                    size: 40,
                    iconSize: 20,
                    tooltip: item.watched
                        ? l10n.vodMarkUnwatched
                        : l10n.vodMarkWatched,
                    onPressed: () => setVodWatched(
                      context,
                      playlistId: playlistId,
                      type: ItemType.movie,
                      providerId: movieId,
                      watched: !item.watched,
                    ),
                  ),
                ],
              ),
              if (meta.overview != null) ...[
                const SizedBox(height: 22),
                Text(
                  meta.overview!,
                  style: KText.body.copyWith(fontSize: 16, height: 1.4),
                ),
              ],
              const SizedBox(height: 14),
              if (meta.cast.isNotEmpty)
                DetailsPeopleLine(
                  label: l10n.vodCastLabel,
                  names: meta.cast.take(8).toList(),
                  onPerson: (person) => openPersonFromSheet(
                    context,
                    playlistId: playlistId,
                    person: person,
                  ),
                ),
              if (meta.genres.isNotEmpty)
                DetailsInfoLine(
                  label: l10n.vodGenresLabel,
                  value: meta.genres.join(', '),
                ),
              if (meta.director != null)
                DetailsPeopleLine(
                  label: l10n.vodDirectorLabel,
                  names: splitPeople(meta.director),
                  onPerson: (person) => openPersonFromSheet(
                    context,
                    playlistId: playlistId,
                    person: person,
                  ),
                ),
              if (technical.isNotEmpty) ...[
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final b in technical) KBadge(b)],
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: 18),
                DetailsNotice(message: l10n.vodDetailsCached),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// `Science Fiction • Crime • 15+ • 114' • 2014` (genres, age rating,
  /// minutes, year).
  static List<String> _factLine(VodMeta meta) => [
    ...meta.genres.take(3),
    ?meta.ageRating,
    if (meta.runtime != null) "${meta.runtime!.inMinutes}'",
    if (meta.year != null) '${meta.year}',
  ];
}

/// Facts separated by small red dots (iPad style).
class _FactLine extends StatelessWidget {
  const _FactLine({required this.parts});

  final List<String> parts;

  @override
  Widget build(BuildContext context) {
    final style = KText.body.copyWith(color: const Color(0xFFE2E2E2));
    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < parts.length; i++) ...[
            if (i > 0)
              TextSpan(
                text: '  •  ',
                style: style.copyWith(
                  color: KColors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            TextSpan(text: parts[i]),
          ],
        ],
      ),
      style: style,
    );
  }
}
