import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/platform/form_factor.dart';
import '../../../core/core.dart';
import '../../../data/db/database.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/repository_models.dart' show CategoryView;
import '../../../data/repositories/vod_repository.dart';
import '../../../data/repositories/watch_state_repository.dart';
import '../../../data/settings/settings_store.dart';
import '../../../data/text/normalize.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../details/details_api.dart';
import '../data/vod_providers.dart';
import 'vod_actions.dart';
import 'vod_cards.dart';

/// Source key of the Continue watching grid (`Routes.seeAll(…, 'cw')`).
const String kVodContinueSource = 'cw';

/// Parses a grid source key: `cw`, a [CategoryRef] key (`p:<id>`, `fav`,
/// `fav:<tag>`, `recent`, `all`), or a bare provider category id.
CategoryRef? vodGridCategory(String sourceKey) {
  if (sourceKey == kVodContinueSource) return null;
  return CategoryRef.tryParse(sourceKey) ?? ProviderCategory(sourceKey);
}

/// One provider category (any state) for grid titles.
final vodCategoryViewProvider = FutureProvider.autoDispose
    .family<CategoryView?, ({int playlistId, SectionKind kind, String id})>(
      (ref, a) => ref
          .watch(categoryRepositoryProvider)
          .category(a.playlistId, a.kind, a.id),
    );

/// The localized title of a grid source.
String vodSourceTitle(
  L10n l10n,
  SectionKind kind,
  String sourceKey, {
  String? categoryName,
}) {
  if (sourceKey == kVodContinueSource) return l10n.vodContinueWatching;
  return switch (vodGridCategory(sourceKey)) {
    FavoritesCategory(tagId: null) => l10n.vodFavorites,
    RecentlyAddedCategory() => l10n.vodRecentlyAdded,
    AllCategory() =>
      kind == SectionKind.series ? l10n.vodAllShows : l10n.vodAllMovies,
    _ => categoryName ?? '',
  };
}

/// Poster grid of a category / special list with a sort menu (Default, Name,
/// Date added, Rating, Year), an in-list filter field and keyboard navigation
/// (arrows move between posters, Enter opens, the Menu key opens the context
/// menu, Esc goes [onBack]). The Continue watching source shows 16:9 cards in
/// the Continue watching order.
class VodGridView extends ConsumerStatefulWidget {
  const VodGridView({
    super.key,
    required this.playlistId,
    required this.kind,
    required this.sourceKey,
    this.title,
    this.backLabel,
    this.onBack,
  });

  final int playlistId;
  final SectionKind kind;
  final String sourceKey;

  /// Overrides the derived title (sidebar entries pass their label).
  final String? title;

  /// Label of the back chip ("Home", "Movies"); hidden without [onBack].
  final String? backLabel;
  final VoidCallback? onBack;

  @override
  ConsumerState<VodGridView> createState() => _VodGridViewState();
}

class _VodGridViewState extends ConsumerState<VodGridView> {
  final TextEditingController _filter = TextEditingController();
  final FocusNode _filterFocus = FocusNode(debugLabel: 'vod grid filter');

  /// The grid itself takes focus when it appears, so Esc / Backspace go
  /// back and the arrow keys move into the posters right away.
  final FocusNode _gridFocus = FocusNode(
    debugLabel: 'vod grid',
    skipTraversal: true,
  );

  /// Parent of the grid cells (for "arrow from the grid → first cell").
  final FocusNode _bodyFocus = FocusNode(
    debugLabel: 'vod grid body',
    canRequestFocus: false,
    skipTraversal: true,
  );
  final ScrollController _scroll = ScrollController();
  final Map<String, String> _keys = {};
  Timer? _debounce;

  /// TV: the first poster takes focus once, as soon as there is one.
  bool _focusedFirstCell = false;
  String _query = '';
  List<VodItem>? _lastItems;

  VodScope get _scope => (playlistId: widget.playlistId, kind: widget.kind);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final current = FocusManager.instance.primaryFocus;
      // Keep focus that the user already placed inside the grid.
      if (current != null && current.context != null) {
        final inside = current.context!
            .findAncestorStateOfType<_VodGridViewState>();
        if (inside == this) return;
      }
      _gridFocus.requestFocus();
    });
  }

  @override
  void didUpdateWidget(VodGridView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sourceKey != widget.sourceKey) {
      _filter.clear();
      _query = '';
      _lastItems = null;
      if (_scroll.hasClients) _scroll.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _filter.dispose();
    _filterFocus.dispose();
    _gridFocus.dispose();
    _bodyFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onFilterChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _query = text);
    });
  }

  void _clearFilter() {
    _debounce?.cancel();
    _filter.clear();
    setState(() => _query = '');
  }

  List<String> get _terms {
    final normalized = normalizeForSearch(_query);
    if (normalized.isEmpty) return const [];
    return normalized.split(' ').where((t) => t.isNotEmpty).toList();
  }

  bool _matches(String name, List<String> terms) {
    if (terms.isEmpty) return true;
    final key = _keys[name] ??= normalizeForSearch(name);
    return terms.every(key.contains);
  }

  /// With a remote there is no pointer to pick a poster: put focus on the
  /// first one when the grid fills, unless the user already moved it (to the
  /// header, say).
  void _focusFirstCellOnTv() {
    if (_focusedFirstCell || !ref.read(formFactorProvider).isTv) return;
    _focusedFirstCell = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final current = FocusManager.instance.primaryFocus;
      if (current != null && current != _gridFocus) return;
      _bodyFocus.traversalDescendants.firstOrNull?.requestFocus();
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    // The grid itself has focus (just opened): arrows enter the cells.
    if (_gridFocus.hasPrimaryFocus &&
        (key == LogicalKeyboardKey.arrowDown ||
            key == LogicalKeyboardKey.arrowRight)) {
      final first = _bodyFocus.traversalDescendants.firstOrNull;
      if (first != null) {
        first.requestFocus();
        return KeyEventResult.handled;
      }
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.escape) {
      if (_filterFocus.hasFocus) {
        _filterFocus.unfocus();
        return KeyEventResult.handled;
      }
      if (widget.onBack != null) {
        widget.onBack!();
        return KeyEventResult.handled;
      }
    }
    if (key == LogicalKeyboardKey.backspace &&
        !_filterFocus.hasFocus &&
        widget.onBack != null) {
      widget.onBack!();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final isContinue = widget.sourceKey == kVodContinueSource;
    final category = vodGridCategory(widget.sourceKey);
    String? categoryName;
    if (category is ProviderCategory && widget.title == null) {
      categoryName = ref
          .watch(
            vodCategoryViewProvider((
              playlistId: widget.playlistId,
              kind: widget.kind,
              id: category.id,
            )),
          )
          .value
          ?.title;
    }
    final title =
        widget.title ??
        vodSourceTitle(
          l10n,
          widget.kind,
          widget.sourceKey,
          categoryName: categoryName,
        );

    final Widget body;
    int? count;
    if (isContinue) {
      final async = ref.watch(continueWatchingProvider(_scope));
      final terms = _terms;
      final entries = async.value
          ?.where((e) => _matches(e.item.name, terms))
          .toList();
      count = entries?.length;
      body = _states(
        async,
        hasData: entries != null,
        empty: entries?.isEmpty ?? false,
        emptyMessage: l10n.vodEmptyContinue,
        onRetry: () => ref.invalidate(continueWatchingProvider(_scope)),
        builder: () => _ContinueGrid(
          playlistId: widget.playlistId,
          entries: entries!,
          controller: _scroll,
        ),
      );
    } else {
      final sort = ref.watch(vodGridSortProvider(_scope));
      final async = ref.watch(
        vodCategoryItemsProvider((
          playlistId: widget.playlistId,
          kind: widget.kind,
          category: category!,
          sort: sort,
          filter: null,
        )),
      );
      if (async.hasValue) _lastItems = async.value;
      final source = async.value ?? (async.hasError ? null : _lastItems);
      final terms = _terms;
      final items = source?.where((i) => _matches(i.name, terms)).toList();
      count = items?.length;
      final history = widget.kind == SectionKind.series
          ? ref.watch(vodSeriesWithHistoryProvider(widget.playlistId))
          : const <String>{};
      body = _states(
        async,
        hasData: items != null,
        empty: items?.isEmpty ?? false,
        emptyMessage: switch (category) {
          FavoritesCategory() => l10n.vodEmptyFavorites,
          RecentlyAddedCategory() => l10n.vodEmptyRecent,
          _ => l10n.vodEmptyCategory,
        },
        onRetry: () => ref.invalidate(vodCategoryItemsProvider),
        builder: () => _PosterGrid(
          playlistId: widget.playlistId,
          items: items!,
          history: history,
          controller: _scroll,
        ),
      );
    }

    if (count != null && count > 0) _focusFirstCellOnTv();

    return Focus(
      focusNode: _gridFocus,
      onKeyEvent: _onKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            title: title,
            count: count,
            backLabel: widget.backLabel,
            onBack: widget.onBack,
            filter: _filter,
            filterFocus: _filterFocus,
            onFilterChanged: _onFilterChanged,
            onClearFilter: _clearFilter,
            sortScope: isContinue ? null : _scope,
          ),
          Expanded(
            child: Focus(
              focusNode: _bodyFocus,
              canRequestFocus: false,
              skipTraversal: true,
              child: body,
            ),
          ),
        ],
      ),
    );
  }

  Widget _states(
    AsyncValue<Object?> async, {
    required bool hasData,
    required bool empty,
    required String emptyMessage,
    required VoidCallback onRetry,
    required Widget Function() builder,
  }) {
    final l10n = L10n.of(context);
    if (!hasData) {
      if (async.hasError) {
        return KErrorState(
          message: l10n.vodLoadError,
          details: '${async.error}',
          onRetry: onRetry,
        );
      }
      return const KLoadingState();
    }
    if (empty) {
      if (_query.trim().isNotEmpty) {
        return KEmptyState(
          icon: PhosphorIconsLight.magnifyingGlass,
          message: l10n.vodNoResults(_query.trim()),
          actionLabel: l10n.vodClearFilter,
          onAction: _clearFilter,
        );
      }
      return KEmptyState(
        icon: widget.kind == SectionKind.series
            ? PhosphorIconsLight.television
            : PhosphorIconsLight.filmSlate,
        message: emptyMessage,
      );
    }
    return builder();
  }
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.title,
    required this.count,
    required this.backLabel,
    required this.onBack,
    required this.filter,
    required this.filterFocus,
    required this.onFilterChanged,
    required this.onClearFilter,
    required this.sortScope,
  });

  final String title;
  final int? count;
  final String? backLabel;
  final VoidCallback? onBack;
  final TextEditingController filter;
  final FocusNode filterFocus;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback onClearFilter;
  final VodScope? sortScope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KSpacing.gutter,
        18,
        KSpacing.gutter,
        18,
      ),
      child: Row(
        children: [
          if (onBack != null) ...[
            KPill(
              label: backLabel ?? l10n.back,
              large: true,
              leading: const Icon(
                PhosphorIconsBold.caretLeft,
                size: 16,
                color: Colors.white,
              ),
              onTap: onBack,
            ),
            const SizedBox(width: 18),
          ],
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KText.largeTitle,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 14),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                l10n.vodTitlesCount(count!),
                style: KText.bodySecondary.copyWith(
                  fontFeatures: KText.tabular,
                ),
              ),
            ),
          ],
          const Spacer(),
          const SizedBox(width: 24),
          SizedBox(
            width: 300,
            child: ListenableBuilder(
              listenable: filter,
              builder: (context, _) => KTextField(
                controller: filter,
                focusNode: filterFocus,
                hint: l10n.vodFilterHint,
                prefixIcon: PhosphorIconsLight.magnifyingGlass,
                onChanged: onFilterChanged,
                semanticLabel: l10n.vodFilterHint,
                suffix: filter.text.isEmpty
                    ? null
                    : KIconButton(
                        icon: PhosphorIconsBold.x,
                        size: 26,
                        iconSize: 13,
                        tooltip: l10n.vodClearFilter,
                        onPressed: onClearFilter,
                      ),
              ),
            ),
          ),
          if (sortScope != null) ...[
            const SizedBox(width: 12),
            _SortButton(scope: sortScope!),
          ],
        ],
      ),
    );
  }
}

/// Label of a sort option.
String vodSortLabel(L10n l10n, VodSort sort) => switch (sort) {
  VodSort.playlist => l10n.vodSortDefault,
  VodSort.name => l10n.vodSortName,
  VodSort.dateAdded => l10n.vodSortDateAdded,
  VodSort.rating => l10n.vodSortRating,
  VodSort.year => l10n.vodSortYear,
};

class _SortButton extends ConsumerWidget {
  const _SortButton({required this.scope});

  final VodScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final sort = ref.watch(vodGridSortProvider(scope));
    return Builder(
      builder: (context) => KPill(
        label: vodSortLabel(l10n, sort),
        large: true,
        leading: const Icon(
          PhosphorIconsLight.sortAscending,
          size: 19,
          color: Colors.white,
        ),
        onTap: () {
          final box = context.findRenderObject() as RenderBox?;
          if (box == null || !box.hasSize) return;
          final rect = box.localToGlobal(Offset.zero) & box.size;
          showKPopoverMenu(
            context,
            anchorRect: rect,
            placement: KPopupPlacement.below,
            width: 260,
            sections: (context) => [
              KPopoverSection(
                header: l10n.vodSortHeader,
                items: [
                  for (final option in VodSort.values)
                    KPopoverItem.check(
                      label: vodSortLabel(l10n, option),
                      checked: option == ref.read(vodGridSortProvider(scope)),
                      onTap: () => ref
                          .read(vodGridSortProvider(scope).notifier)
                          .set(option),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Grid geometry shared by the poster grids.
const double _kGridPosterMax = 196;
const double _kGridSpacing = 18;
const double _kGridRunSpacing = 22;

class _PosterGrid extends StatelessWidget {
  const _PosterGrid({
    required this.playlistId,
    required this.items,
    required this.history,
    required this.controller,
  });

  final int playlistId;
  final List<VodItem> items;
  final Set<String> history;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final usable = c.maxWidth - KSpacing.gutter * 2;
        final columns =
            ((usable + _kGridSpacing) / (_kGridPosterMax + _kGridSpacing))
                .ceil()
                .clamp(2, 12);
        final tileWidth = (usable - _kGridSpacing * (columns - 1)) / columns;
        final tileHeight =
            tileWidth / kVodPosterAspect + VodPosterTile.captionHeight;
        return FocusTraversalGroup(
          child: GridView.builder(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(
              KSpacing.gutter,
              6,
              KSpacing.gutter,
              120,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: _kGridSpacing,
              mainAxisSpacing: _kGridRunSpacing,
              childAspectRatio: tileWidth / tileHeight,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              return VodPosterTile(
                key: ValueKey(item.providerId),
                item: item,
                newBadge: vodNewBadgeFor(
                  item,
                  knownShow: history.contains(item.providerId),
                ),
                onTap: () => openVodDetails(
                  context,
                  playlistId: playlistId,
                  kind: item.kind,
                  providerId: item.providerId,
                ),
                onContextMenu: (position) => showVodActions(
                  context,
                  playlistId: playlistId,
                  type: item.itemType,
                  providerId: item.providerId,
                  position: position,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ContinueGrid extends ConsumerWidget {
  const _ContinueGrid({
    required this.playlistId,
    required this.entries,
    required this.controller,
  });

  final int playlistId;
  final List<ContinueWatchingEntry> entries;
  final ScrollController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opensPlayer = ref.watchSetting(
      PlaylistSettings.continueWatchingOpensPlayer,
      playlistId: playlistId,
    );
    return LayoutBuilder(
      builder: (context, c) {
        final usable = c.maxWidth - KSpacing.gutter * 2;
        const maxWidth = 340.0;
        final columns = ((usable + _kGridSpacing) / (maxWidth + _kGridSpacing))
            .ceil()
            .clamp(1, 8);
        final tileWidth = (usable - _kGridSpacing * (columns - 1)) / columns;
        final tileHeight =
            tileWidth / kVodWideAspect + VodContinueCard.barSpace;
        return FocusTraversalGroup(
          child: GridView.builder(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(
              KSpacing.gutter,
              6,
              KSpacing.gutter,
              120,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: _kGridSpacing,
              mainAxisSpacing: _kGridRunSpacing + 6,
              childAspectRatio: tileWidth / tileHeight,
            ),
            itemCount: entries.length,
            itemBuilder: (context, i) {
              final entry = entries[i];
              return VodContinueCard(
                key: ValueKey(entry.playId),
                entry: entry,
                onTap: () => opensPlayer
                    ? playContinueEntry(
                        context,
                        playlistId: playlistId,
                        entry: entry,
                      )
                    : openVodDetails(
                        context,
                        playlistId: playlistId,
                        kind: entry.item.kind,
                        providerId: entry.item.providerId,
                      ),
                onContextMenu: (position) => showVodActions(
                  context,
                  playlistId: playlistId,
                  type: entry.item.itemType,
                  providerId: entry.item.providerId,
                  position: position,
                  inContinueWatching: true,
                ),
              );
            },
          ),
        );
      },
    );
  }
}
