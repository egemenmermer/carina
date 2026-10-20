import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/database.dart';
import '../../../data/repositories/vod_repository.dart';
import '../../../data/settings/settings_store.dart';
import '../../../data/tmdb/tmdb_service.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../data/vod_providers.dart';
import 'vod_cards.dart';
import 'vod_rows.dart';

/// Library items matching TMDb `trending/{movie|tv}/week`, at most ten, in
/// trending order. Null — hide the row — without TMDb, when the "Show Trending"
/// setting is off, or when nothing matches.
final vodTrendingProvider = FutureProvider.autoDispose
    .family<List<VodItem>?, VodScope>((ref, s) async {
      final enabled = ref.watchSetting(
        PlaylistSettings.showTrending,
        playlistId: s.playlistId,
      );
      if (!enabled) return null;
      final excludeLocked = watchExcludeLocked(ref, s.playlistId);
      final kind = s.kind == SectionKind.series ? TmdbKind.tv : TmdbKind.movie;
      final trending = await ref.watch(tmdbTrendingProvider(kind).future);
      if (trending == null || trending.isEmpty) return null;
      final items = await ref.read(vodRepositoryProvider).matchTrending(
        s.playlistId,
        s.kind,
        [
          for (final t in trending)
            (
              tmdbId: t.tmdbId,
              title: t.title,
              originalTitle: t.originalTitle,
              year: t.year,
            ),
        ],
        excludeLocked: excludeLocked,
      );
      if (items.isEmpty) return null;
      return List.unmodifiable(items.take(10));
    });

/// "Trending this week": big outlined rank numbers next to the posters.
/// Renders nothing without TMDb.
class VodTrendingRow extends ConsumerWidget {
  const VodTrendingRow({
    super.key,
    required this.playlistId,
    required this.kind,
    required this.posterWidth,
    required this.onOpen,
    required this.onMenu,
    required this.onHighlight,
  });

  final int playlistId;
  final SectionKind kind;
  final double posterWidth;
  final ValueChanged<VodItem> onOpen;
  final void Function(VodItem item, Offset position) onMenu;
  final ValueChanged<VodItem> onHighlight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref
        .watch(vodTrendingProvider((playlistId: playlistId, kind: kind)))
        .value;
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    final l10n = L10n.of(context);
    final height = posterWidth / kVodPosterAspect;
    return VodRowSection(
      title: l10n.vodTrendingThisWeek,
      itemCount: items.length,
      itemWidth: posterWidth * 1.62,
      itemHeight: height,
      spacing: 10,
      itemBuilder: (context, i) {
        final item = items[i];
        return VodTrendingCard(
          key: ValueKey(item.providerId),
          rank: i + 1,
          item: item,
          posterWidth: posterWidth,
          onTap: () => onOpen(item),
          onContextMenu: (position) => onMenu(item, position),
          onHighlight: () => onHighlight(item),
        );
      },
    );
  }
}
