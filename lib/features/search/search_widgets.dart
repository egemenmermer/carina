import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/time_format.dart';
import '../../core/core.dart';
import '../../data/db/tables.dart';
import '../../data/repositories/repository_models.dart';
import '../../data/repositories/search_repository.dart';
import '../../data/repositories/vod_models.dart';
import '../../l10n/gen/app_localizations.dart';

/// Section title of the search results: "Movies  12".
class SearchSectionTitle extends StatelessWidget {
  const SearchSectionTitle({
    super.key,
    required this.title,
    required this.count,
    this.padding = const EdgeInsets.fromLTRB(KSpacing.gutter, 0, 48, 0),
  });

  final String title;
  final int count;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Semantics(
        header: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(title, style: KText.sectionTitle),
            const SizedBox(width: 10),
            Text(
              '$count',
              style: KText.sectionTitle.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: KColors.textTertiary,
                fontFeatures: KText.tabular,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Poster of a movie or show in the results: 2:3 artwork with the title and
/// the year / rating under it. Click opens the details, right-click the
/// card menu.
class SearchPosterCard extends StatelessWidget {
  const SearchPosterCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onContextMenu,
  });

  static const double width = 152;
  static const double posterHeight = 228;
  static const double height = posterHeight + 50;

  final VodItem item;
  final VoidCallback onTap;
  final KContextMenuCallback onContextMenu;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final rating = item.rating;
    final meta = [
      if (item.year != null) '${item.year}',
      if (rating != null && rating > 0) '★ ${rating.toStringAsFixed(1)}',
    ].join('  ·  ');
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FocusableCard(
            width: width,
            height: posterHeight,
            borderRadius: KRadii.poster,
            color: KColors.surface2,
            onTap: onTap,
            onContextMenu: onContextMenu,
            semanticLabel: item.name,
            child: Stack(
              fit: StackFit.expand,
              children: [
                KImage(
                  item.poster,
                  fit: BoxFit.cover,
                  placeholder: SearchPosterFallback(name: item.name),
                  errorBuilder: (_) => SearchPosterFallback(name: item.name),
                ),
                if (item.isNew)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 10,
                    child: Center(
                      child: item.kind == SectionKind.series
                          ? const KNewBadge.show()
                          : const KNewBadge.movie(),
                    ),
                  ),
                if (item.isFavorite)
                  const Positioned(
                    top: 8,
                    right: 8,
                    child: Icon(
                      PhosphorIconsFill.star,
                      size: 18,
                      color: KColors.star,
                      shadows: [
                        Shadow(color: Color(0x99000000), blurRadius: 6),
                      ],
                    ),
                  ),
                if (item.inProgress)
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: KProgressBar(value: item.progress ?? 0, height: 3),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: KText.cardTitle,
          ),
          const SizedBox(height: 2),
          Text(
            meta.isEmpty
                ? (item.kind == SectionKind.series
                      ? l10n.libraryKindShow
                      : l10n.libraryKindMovie)
                : meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: KText.cardSubtitle,
          ),
        ],
      ),
    );
  }
}

/// Artwork placeholder: the title on a dark tile.
class SearchPosterFallback extends StatelessWidget {
  const SearchPosterFallback({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF232326), Color(0xFF131315)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              PhosphorIconsLight.filmStrip,
              size: 30,
              color: KColors.textTertiary,
            ),
            const SizedBox(height: 10),
            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: KText.cardSubtitle.copyWith(color: KColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// A live channel in the results: logo, quality badges + name, the
/// programme on air with its time and a red progress bar (TV Live card
/// look). A locked channel shows the green parental lock.
class SearchChannelCard extends StatelessWidget {
  const SearchChannelCard({
    super.key,
    required this.channel,
    required this.now,
    required this.clock,
    required this.format,
    required this.onTap,
    required this.onContextMenu,
  });

  static const double width = 384;
  static const double height = 108;

  final ChannelHit channel;

  /// The programme on air (null: no guide data).
  final ProgrammeView? now;
  final DateTime clock;
  final CarinaTimeFormat format;
  final VoidCallback onTap;
  final KContextMenuCallback onContextMenu;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final badges = qualityBadges(channel.quality);
    final programme = now;
    return FocusableCard(
      width: width,
      height: height,
      onTap: onTap,
      onContextMenu: onContextMenu,
      semanticLabel: channel.name,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          KLogoTile(name: channel.name, url: channel.logo, size: 64),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    for (final b in badges.take(2)) ...[
                      KBadge(b),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        channel.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KText.channelName,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  programme?.title ?? l10n.libraryNoGuide,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: programme == null
                      ? KText.programme.copyWith(color: KColors.textTertiary)
                      : KText.programme,
                ),
                if (programme != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    format.range(programme.start, programme.stop),
                    style: KText.time,
                  ),
                  const SizedBox(height: 7),
                  KProgressBar(value: programme.progressAt(clock), height: 3),
                ],
              ],
            ),
          ),
          if (channel.locked) ...[
            const SizedBox(width: 10),
            const Icon(
              PhosphorIconsFill.lockSimple,
              size: 18,
              color: KColors.success,
            ),
          ],
        ],
      ),
    );
  }
}

/// A current or upcoming programme: day label + start time, channel logo,
/// title, channel and duration; a progress bar while on air, a bell for
/// upcoming ones (filled when a reminder is set).
class SearchProgrammeTile extends StatelessWidget {
  const SearchProgrammeTile({
    super.key,
    required this.programme,
    required this.clock,
    required this.format,
    required this.localeCode,
    required this.hasReminder,
    required this.onTap,
    required this.onContextMenu,
    required this.onToggleReminder,
  });

  static const double height = 88;

  final ProgrammeHit programme;
  final DateTime clock;
  final CarinaTimeFormat format;
  final String localeCode;
  final bool hasReminder;
  final VoidCallback onTap;
  final KContextMenuCallback onContextMenu;
  final VoidCallback onToggleReminder;

  String _dayLabel(L10n l10n, bool onAir) {
    if (onAir) return l10n.libraryOnAir;
    final local = programme.start.toLocal();
    final today = clock.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    final base = DateTime(today.year, today.month, today.day);
    final diff = day.difference(base).inDays;
    if (diff == 0) return l10n.libraryToday;
    if (diff == 1) return l10n.libraryTomorrow;
    return DateFormat.E(localeCode).format(local);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final onAir = programme.isOnAirAt(clock);
    final channel = programme.channels.isEmpty
        ? null
        : programme.channels.first;
    final minutes = programme.stop.difference(programme.start).inMinutes;
    final subtitle = [
      if (channel != null) channel.name,
      if (programme.channels.length > 1)
        l10n.libraryMoreChannels(programme.channels.length - 1),
      l10n.libraryMinutes(minutes),
    ].join('  ·  ');
    final total = programme.stop.difference(programme.start).inSeconds;
    final elapsed = clock.difference(programme.start).inSeconds;
    return FocusableCard(
      height: height,
      color: KColors.tile,
      scale: 1.02,
      onTap: onTap,
      onContextMenu: onContextMenu,
      semanticLabel: programme.title,
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          SizedBox(
            width: 112,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _dayLabel(l10n, onAir).toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KText.menuHeader.copyWith(
                    color: KColors.accent,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    format.time(programme.start),
                    maxLines: 1,
                    style: KText.timeLarge.copyWith(fontSize: 20),
                  ),
                ),
              ],
            ),
          ),
          if (channel != null) ...[
            KLogoTile(name: channel.name, url: channel.logo, size: 48),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  programme.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KText.cardTitle.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KText.cardSubtitle,
                ),
                if (onAir) ...[
                  const SizedBox(height: 8),
                  KProgressBar(
                    value: total <= 0 ? 0 : elapsed / total,
                    height: 3,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            child: onAir || channel == null
                ? null
                : KIconButton(
                    icon: hasReminder
                        ? PhosphorIconsFill.bellRinging
                        : PhosphorIconsLight.bellSimple,
                    size: 38,
                    iconSize: 19,
                    selected: hasReminder,
                    background: const Color(0x00000000),
                    tooltip: hasReminder
                        ? l10n.libraryReminderCancel
                        : l10n.libraryReminderSet,
                    onPressed: onToggleReminder,
                  ),
          ),
        ],
      ),
    );
  }
}

/// A cast member: initials in a circle and the name ("Search by actor").
class SearchPersonTile extends StatelessWidget {
  const SearchPersonTile({
    super.key,
    required this.person,
    required this.onTap,
  });

  static const double width = 136;
  static const double circle = 108;
  static const double height = circle + 56;

  final PersonHit person;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return SizedBox(
      width: width,
      child: Column(
        children: [
          FocusableCard(
            width: circle,
            height: circle,
            borderRadius: circle / 2,
            showStroke: false,
            color: KColors.surface2,
            onTap: onTap,
            semanticLabel: person.displayName,
            child: KMonogram(name: person.displayName, size: circle),
          ),
          const SizedBox(height: 10),
          Text(
            person.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: KText.cardTitle,
          ),
          const SizedBox(height: 2),
          Text(
            l10n.libraryPersonRole,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: KText.cardSubtitle,
          ),
        ],
      ),
    );
  }
}
