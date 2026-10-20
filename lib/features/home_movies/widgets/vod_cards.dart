import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../../../data/db/database.dart';
import '../../../data/repositories/vod_repository.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../data/vod_meta.dart';
import 'vod_art.dart';

/// Poster rows and grids (2:3).
const double kVodPosterAspect = 2 / 3;

/// Continue watching cards (16:9).
const double kVodWideAspect = 16 / 9;

/// Which NEW badge a recently added card carries.
enum VodNewBadge { none, movie, show, episodes }

/// The NEW badge of [item]: NEW MOVIE for movies; for shows,
/// NEW EPISODES when the user already knows the show ([knownShow]: played
/// before or a favorite), else NEW SHOW.
VodNewBadge vodNewBadgeFor(VodItem item, {bool knownShow = false}) {
  if (!item.isNew) return VodNewBadge.none;
  if (item.kind != SectionKind.series) return VodNewBadge.movie;
  return knownShow || item.isFavorite ? VodNewBadge.episodes : VodNewBadge.show;
}

Widget? _badgeWidget(VodNewBadge badge) => switch (badge) {
  VodNewBadge.none => null,
  VodNewBadge.movie => const KNewBadge.movie(),
  VodNewBadge.show => const KNewBadge.show(),
  VodNewBadge.episodes => const KNewBadge.episodes(),
};

/// A 2:3 poster card: artwork (or a generated text poster), a red eye when
/// watched, the NEW badge bottom-center, and a thin red progress bar when
/// in progress. Hover / focus scale it (tvOS style) and call [onHighlight]
/// (the home hero follows it).
class VodPosterCard extends StatelessWidget {
  const VodPosterCard({
    super.key,
    required this.item,
    required this.onTap,
    this.onContextMenu,
    this.onHighlight,
    this.newBadge = VodNewBadge.none,
    this.focusNode,
    this.autofocus = false,
  });

  final VodItem item;
  final VoidCallback onTap;
  final KContextMenuCallback? onContextMenu;
  final VoidCallback? onHighlight;
  final VodNewBadge newBadge;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final title = vodDisplayTitle(item.name);
    final shown = title.isEmpty ? l10n.vodUntitled : title;
    final badge = _badgeWidget(newBadge);
    final progress = item.inProgress ? item.progress : null;
    return FocusableCard(
      onTap: onTap,
      onContextMenu: onContextMenu,
      onHoverChange: (hovered) {
        if (hovered) onHighlight?.call();
      },
      onFocusChange: (focused) {
        if (focused) onHighlight?.call();
      },
      focusNode: focusNode,
      autofocus: autofocus,
      borderRadius: KRadii.poster,
      color: KColors.surface2,
      semanticLabel: shown,
      child: Stack(
        fit: StackFit.expand,
        children: [
          VodArt(url: item.poster, title: shown, year: item.year),
          if (item.watched)
            Positioned(
              top: 7,
              left: 7,
              child: VodWatchedBadge(semanticLabel: l10n.vodWatched),
            ),
          if (badge != null)
            Positioned(
              left: 6,
              right: 6,
              bottom: progress != null ? 14 : 10,
              child: Center(child: badge),
            ),
          if (progress != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: KProgressBar(value: progress, height: 4, rounded: false),
            ),
        ],
      ),
    );
  }
}

/// A grid poster with its caption (title, year · rating) below.
class VodPosterTile extends StatelessWidget {
  const VodPosterTile({
    super.key,
    required this.item,
    required this.onTap,
    this.onContextMenu,
    this.newBadge = VodNewBadge.none,
    this.focusNode,
    this.autofocus = false,
  });

  final VodItem item;
  final VoidCallback onTap;
  final KContextMenuCallback? onContextMenu;
  final VodNewBadge newBadge;
  final FocusNode? focusNode;
  final bool autofocus;

  /// Height of the caption under the poster.
  static const double captionHeight = 50;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final title = vodDisplayTitle(item.name);
    final locale = Localizations.localeOf(context).languageCode;
    final rating = item.rating;
    final details = [
      if (item.year != null) '${item.year}',
      if (rating != null && rating > 0) '★ ${vodRatingText(rating, locale)}',
    ].join('  ·  ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: VodPosterCard(
            item: item,
            onTap: onTap,
            onContextMenu: onContextMenu,
            newBadge: newBadge,
            focusNode: focusNode,
            autofocus: autofocus,
          ),
        ),
        SizedBox(
          height: captionHeight,
          child: Padding(
            padding: const EdgeInsets.only(top: 9, left: 2, right: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty ? l10n.vodUntitled : title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KText.cardTitle.copyWith(fontSize: 14),
                ),
                if (details.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      details,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KText.cardSubtitle.copyWith(
                        fontFeatures: KText.tabular,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A Continue watching card (16:9): artwork (episode still, backdrop or
/// the blurred poster), a white play ring, the title and `S1 E2 · Title`
/// (movies: the time left) at the bottom-left, and the red progress bar
/// under the card. Hover / focus scale the whole card with a white border.
class VodContinueCard extends StatelessWidget {
  const VodContinueCard({
    super.key,
    required this.entry,
    required this.onTap,
    this.onContextMenu,
    this.onHighlight,
    this.newBadge = VodNewBadge.none,
    this.focusNode,
  });

  final ContinueWatchingEntry entry;
  final VoidCallback onTap;
  final KContextMenuCallback? onContextMenu;
  final VoidCallback? onHighlight;
  final VodNewBadge newBadge;
  final FocusNode? focusNode;

  /// Gap + progress bar under the 16:9 card.
  static const double barSpace = 11;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final item = entry.item;
    final title = vodDisplayTitle(item.name);
    final shown = title.isEmpty ? l10n.vodUntitled : title;
    final episode = entry.episode;
    final String? subtitle;
    if (episode != null) {
      subtitle = episode.label;
    } else {
      final left = entry.duration - entry.position;
      subtitle = left > const Duration(minutes: 1)
          ? l10n.vodTimeLeft(_shortRuntime(left))
          : null;
    }
    final badge = _badgeWidget(newBadge);
    final art = episode?.image ?? item.backdrop;
    return KInteractive(
      onTap: onTap,
      onContextMenu: onContextMenu,
      focusNode: focusNode,
      onHoverChange: (hovered) {
        if (hovered) onHighlight?.call();
      },
      onFocusChange: (focused) {
        if (focused) onHighlight?.call();
      },
      semanticLabel: subtitle == null ? shown : '$shown, $subtitle',
      builder: (context, state, _) {
        final duration = KMotion.of(context, KDurations.hover);
        final active = state.highlighted;
        final radius = BorderRadius.circular(KRadii.card);
        return AnimatedScale(
          scale: active ? (state.pressed ? 1.02 : 1.04) : 1,
          duration: duration,
          curve: KMotion.hover,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: duration,
                  curve: KMotion.hover,
                  decoration: BoxDecoration(
                    color: KColors.surface2,
                    borderRadius: radius,
                    boxShadow: active ? KShadows.focus : const [],
                  ),
                  foregroundDecoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(
                      color: active
                          ? KColors.focusRing
                          : const Color(0x00F5F5F5),
                      width: 2,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      VodArt(
                        url: art,
                        blurUrl: item.poster,
                        title: shown,
                        wide: true,
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0.42, 1],
                            colors: [Color(0x00000000), Color(0xD9000000)],
                          ),
                        ),
                      ),
                      Center(child: VodPlayRing(highlighted: active)),
                      if (badge != null)
                        Positioned(top: 10, right: 10, child: badge),
                      Positioned(
                        left: 14,
                        right: 14,
                        bottom: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              shown,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: KText.cardTitle.copyWith(
                                fontSize: 16,
                                shadows: const [
                                  Shadow(
                                    color: Color(0x99000000),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            if (subtitle != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 1),
                                child: Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: KText.cardSubtitle.copyWith(
                                    fontSize: 14,
                                    color: const Color(0xFFD0D0D0),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: barSpace - 4),
              KProgressBar(value: entry.progress ?? 0, height: 4),
            ],
          ),
        );
      },
    );
  }
}

/// `1h 49m` / `49m`.
String _shortRuntime(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h == 0) return '${m}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

/// Trending card: a huge outlined rank number with the poster overlapping its
/// right side.
class VodTrendingCard extends StatelessWidget {
  const VodTrendingCard({
    super.key,
    required this.rank,
    required this.item,
    required this.posterWidth,
    required this.onTap,
    this.onContextMenu,
    this.onHighlight,
  });

  final int rank;
  final VodItem item;
  final double posterWidth;
  final VoidCallback onTap;
  final KContextMenuCallback? onContextMenu;
  final VoidCallback? onHighlight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final h = c.maxHeight;
        final numberSize = h * 0.78;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              bottom: -h * 0.06,
              child: ExcludeSemantics(
                child: Text(
                  '$rank',
                  style: TextStyle(
                    fontFamily: KText.family,
                    fontSize: numberSize,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -numberSize * 0.06,
                    height: 1,
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 3
                      ..color = const Color(0xFF5A5A5A),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: posterWidth,
              child: VodPosterCard(
                item: item,
                onTap: onTap,
                onContextMenu: onContextMenu,
                onHighlight: onHighlight,
              ),
            ),
          ],
        );
      },
    );
  }
}
