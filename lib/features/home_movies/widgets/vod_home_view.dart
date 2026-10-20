import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/shell/category_selection.dart';
import '../../../core/core.dart';
import '../../../data/db/database.dart';
import '../../../data/repositories/repository_models.dart';
import '../../../data/repositories/vod_repository.dart';
import '../../../data/repositories/watch_state_repository.dart';
import '../../../data/settings/settings_store.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../details/details_api.dart';
import '../data/vod_providers.dart';
import 'vod_actions.dart';
import 'vod_cards.dart';
import 'vod_grid.dart';
import 'vod_hero.dart';
import 'vod_rows.dart';
import 'vod_trending.dart';

/// The Movies / Shows tab.
///
/// Two modes, driven by the shared sidebar selection
/// (`selectedCategoryProvider((playlistId:, kind:))`):
///
/// * **Home** — hero + rows — while the selection is empty or
///   [AllCategory];
/// * **Category** — the poster grid of the picked sidebar entry (provider
///   category, Favorites / a tag, Recently added) with a "‹ Home" chip,
///   which (like Esc / Backspace) selects [AllCategory] again. Because the
///   chip resets the selection, picking the same category in the sidebar
///   afterwards switches back to its grid.
///
/// The selection is saved per playlist, but the first visit of a section
/// in each app session starts on Home (a saved category is reset once), so
/// the app always opens on the hero; within the session the choice sticks
/// across tab switches. If the shell later lists an [AllCategory] entry
/// for Movies / Shows, it acts as the Home entry.
class VodHomeView extends ConsumerStatefulWidget {
  const VodHomeView({super.key, required this.playlistId, required this.kind});

  final int playlistId;

  /// [SectionKind.movie] or [SectionKind.series].
  final SectionKind kind;

  @override
  ConsumerState<VodHomeView> createState() => _VodHomeViewState();
}

class _VodHomeViewState extends ConsumerState<VodHomeView> {
  bool _forceHome = false;

  CategoryScope get _scope =>
      (playlistId: widget.playlistId, kind: widget.kind);

  @override
  void initState() {
    super.initState();
    final reset = ref.read(vodHomeResetProvider);
    if (reset.add('${widget.playlistId}:${widget.kind.name}')) {
      final selection = ref.read(selectedCategoryProvider(_scope));
      if (selection != null && selection is! AllCategory) {
        _forceHome = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _goHome();
        });
      }
    }
  }

  void _goHome() => ref
      .read(selectedCategoryProvider(_scope).notifier)
      .select(const AllCategory());

  String _titleOf(L10n l10n, CategoryView view) => switch (view.ref) {
    FavoritesCategory(tagId: null) => l10n.vodFavorites,
    RecentlyAddedCategory() => l10n.vodRecentlyAdded,
    AllCategory() =>
      widget.kind == SectionKind.series ? l10n.vodAllShows : l10n.vodAllMovies,
    _ => view.title,
  };

  @override
  Widget build(BuildContext context) {
    final selection = ref.watch(selectedCategoryProvider(_scope));
    final home = selection == null || selection is AllCategory;
    if (_forceHome && home) _forceHome = false;
    if (!home && !_forceHome) {
      final active = ref.watch(activeCategoryProvider(_scope));
      if (!active.hasValue && !active.hasError) return const KLoadingState();
      final view = active.value;
      if (view != null && view.ref == selection) {
        final l10n = L10n.of(context);
        return VodGridView(
          key: ValueKey('grid:${selection.key}'),
          playlistId: widget.playlistId,
          kind: widget.kind,
          sourceKey: selection.key,
          title: _titleOf(l10n, view),
          backLabel: l10n.vodHome,
          onBack: _goHome,
        );
      }
    }
    return _VodHomeRows(
      key: ValueKey('home:${widget.playlistId}:${widget.kind.name}'),
      playlistId: widget.playlistId,
      kind: widget.kind,
    );
  }
}

class _VodHomeRows extends ConsumerStatefulWidget {
  const _VodHomeRows({super.key, required this.playlistId, required this.kind});

  final int playlistId;
  final SectionKind kind;

  @override
  ConsumerState<_VodHomeRows> createState() => _VodHomeRowsState();
}

class _VodHomeRowsState extends ConsumerState<_VodHomeRows> {
  final ScrollController _scroll = ScrollController();
  final VodHeroController _hero = VodHeroController();
  List<VodItem>? _appliedCandidates;

  VodScope get _scope => (playlistId: widget.playlistId, kind: widget.kind);
  int get _pid => widget.playlistId;
  bool get _series => widget.kind == SectionKind.series;
  String get _section =>
      _series ? MainTab.shows.segment : MainTab.movies.segment;

  @override
  void initState() {
    super.initState();
    _hero.canRotate = () =>
        mounted && TickerMode.valuesOf(context).enabled && !_menuOpen;
  }

  bool _menuOpen = false;

  @override
  void dispose() {
    _hero.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _seeAll(String sourceKey) {
    final router = GoRouter.maybeOf(context);
    router?.push(Routes.seeAll(_pid, _section, sourceKey));
  }

  /// Opens a sheet or menu while the hero holds still.
  Future<void> _held(Future<void> Function() action) async {
    _menuOpen = true;
    _hero.hold();
    try {
      await action();
    } finally {
      _hero.release();
      _menuOpen = false;
    }
  }

  void _openDetails(VodItem item) => _held(
    () => openVodDetails(
      context,
      playlistId: _pid,
      kind: item.kind,
      providerId: item.providerId,
    ),
  );

  void _openMenu(VodItem item, Offset position, {bool continueRow = false}) =>
      _held(
        () => showVodActions(
          context,
          playlistId: _pid,
          type: item.itemType,
          providerId: item.providerId,
          position: position,
          inContinueWatching: continueRow,
        ),
      );

  void _applyCandidates(List<VodItem>? candidates) {
    if (candidates == null || identical(candidates, _appliedCandidates)) {
      return;
    }
    _appliedCandidates = candidates;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _hero.setCandidates(candidates);
    });
  }

  void _fallbackHero(VodItem? item) {
    if (item == null || _hero.current != null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _hero.showIfEmpty(item);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    _hero.autoRotate = !KMotion.reduced(context);
    final candidates = ref.watch(heroCandidatesProvider(_scope));
    _applyCandidates(candidates.value);

    final rowsAsync = ref.watch(vodHomeRowsProvider(_scope));
    final cw = ref.watch(continueWatchingProvider(_scope)).value ?? const [];
    final favorites =
        ref
            .watch(
              favoriteItemsProvider((
                playlistId: _pid,
                kind: widget.kind,
                tagId: null,
              )),
            )
            .value ??
        const <VodItem>[];
    final showRecent = ref.watchSetting(
      PlaylistSettings.showRecentlyAdded,
      playlistId: _pid,
    );
    final recent = showRecent
        ? ref.watch(recentlyAddedProvider(_scope)).value ?? const <VodItem>[]
        : const <VodItem>[];
    final history = _series
        ? ref.watch(vodSeriesWithHistoryProvider(_pid))
        : const <String>{};
    final opensPlayer = ref.watchSetting(
      PlaylistSettings.continueWatchingOpensPlayer,
      playlistId: _pid,
    );

    if (!rowsAsync.hasValue) {
      if (rowsAsync.hasError) {
        return KErrorState(
          message: l10n.vodLoadError,
          details: '${rowsAsync.error}',
          onRetry: () => ref.invalidate(vodHomeRowsProvider(_scope)),
        );
      }
      return const KLoadingState();
    }
    final rows = rowsAsync.value!;
    final heroItems = candidates.value ?? const <VodItem>[];
    if (rows.isEmpty &&
        cw.isEmpty &&
        favorites.isEmpty &&
        recent.isEmpty &&
        heroItems.isEmpty &&
        !candidates.isLoading) {
      return KEmptyState(
        icon: _series
            ? PhosphorIconsLight.television
            : PhosphorIconsLight.filmSlate,
        title: _series ? l10n.vodEmptyShowsTitle : l10n.vodEmptyMoviesTitle,
        message: _series
            ? l10n.vodEmptyShowsMessage
            : l10n.vodEmptyMoviesMessage,
      );
    }
    if (heroItems.isEmpty && !candidates.isLoading) {
      _fallbackHero(
        rows.firstOrNull?.items.firstOrNull ??
            recent.firstOrNull ??
            favorites.firstOrNull,
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        final heroHeight = (h * 0.46).clamp(360.0, 580.0);
        final backdropHeight = math.max(heroHeight + 280, h * 0.94);
        final posterWidth = (w * 0.117).clamp(132.0, 236.0);
        final posterHeight = posterWidth / kVodPosterAspect;
        final wideWidth = (w * 0.206).clamp(248.0, 420.0);
        final wideHeight =
            wideWidth / kVodWideAspect + VodContinueCard.barSpace;

        Widget posterRow({
          required String title,
          required List<VodItem> items,
          VoidCallback? onSeeAll,
          bool newBadges = true,
        }) => VodRowSection(
          title: title,
          onSeeAll: onSeeAll,
          itemCount: items.length,
          itemWidth: posterWidth,
          itemHeight: posterHeight,
          itemBuilder: (context, i) {
            final item = items[i];
            return VodPosterCard(
              key: ValueKey(item.providerId),
              item: item,
              newBadge: newBadges
                  ? vodNewBadgeFor(
                      item,
                      knownShow: history.contains(item.providerId),
                    )
                  : VodNewBadge.none,
              onTap: () => _openDetails(item),
              onContextMenu: (position) => _openMenu(item, position),
              onHighlight: () => _hero.preview(item),
            );
          },
        );

        final slivers = <Widget>[
          SliverToBoxAdapter(
            child: SizedBox(
              height: heroHeight,
              child: VodHeroContent(
                controller: _hero,
                playlistId: _pid,
                kind: widget.kind,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 18)),
          if (cw.isNotEmpty)
            SliverToBoxAdapter(
              child: VodRowSection(
                title: l10n.vodContinueWatching,
                onSeeAll: () => _seeAll(kVodContinueSource),
                itemCount: cw.length,
                itemWidth: wideWidth,
                itemHeight: wideHeight,
                itemBuilder: (context, i) {
                  final entry = cw[i];
                  return VodContinueCard(
                    key: ValueKey(entry.playId),
                    entry: entry,
                    newBadge: vodNewBadgeFor(entry.item, knownShow: true),
                    onTap: () => opensPlayer
                        ? playContinueEntry(
                            context,
                            playlistId: _pid,
                            entry: entry,
                          )
                        : _openDetails(entry.item),
                    onContextMenu: (position) =>
                        _openMenu(entry.item, position, continueRow: true),
                    onHighlight: () => _hero.preview(entry.item),
                  );
                },
              ),
            ),
          if (favorites.isNotEmpty)
            SliverToBoxAdapter(
              child: posterRow(
                title: l10n.vodFavorites,
                items: favorites,
                onSeeAll: () => _seeAll(const FavoritesCategory().key),
                newBadges: false,
              ),
            ),
          if (recent.isNotEmpty)
            SliverToBoxAdapter(
              child: posterRow(
                title: l10n.vodRecentlyAdded,
                items: recent,
                onSeeAll: () => _seeAll(const RecentlyAddedCategory().key),
              ),
            ),
          SliverToBoxAdapter(
            child: VodTrendingRow(
              playlistId: _pid,
              kind: widget.kind,
              posterWidth: posterWidth,
              onOpen: _openDetails,
              onMenu: _openMenu,
              onHighlight: _hero.preview,
            ),
          ),
          SliverList.builder(
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final row = rows[i];
              return posterRow(
                title: row.category.name,
                items: row.items,
                onSeeAll: () =>
                    _seeAll(ProviderCategory(row.category.providerId).key),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ];

        return Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: backdropHeight,
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _scroll,
                  builder: (context, child) {
                    final offset = _scroll.hasClients
                        ? _scroll.offset.clamp(0.0, backdropHeight)
                        : 0.0;
                    return Transform.translate(
                      offset: Offset(0, -offset * 0.6),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          child!,
                          ColoredBox(
                            color: Colors.black.withValues(
                              alpha: (offset / (backdropHeight * 0.7)).clamp(
                                0.0,
                                1.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  child: VodHeroBackdrop(controller: _hero, playlistId: _pid),
                ),
              ),
            ),
            Positioned.fill(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context)
                    .copyWith(scrollbars: false),
                child: CustomScrollView(controller: _scroll, slivers: slivers),
              ),
            ),
          ],
        );
      },
    );
  }
}
