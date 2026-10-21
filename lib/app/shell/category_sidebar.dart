import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/core.dart';
import '../../data/db/database.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/repository_models.dart';
import '../../data/settings/settings_store.dart';
import '../../l10n/gen/app_localizations.dart';
import 'category_selection.dart';
import 'shell_state.dart';

/// The category sidebar opened by the red FAB: SORTING rows and
/// the CATEGORIES list (Favorites with tags, Last watched, Recently added,
/// then provider categories with counts). Slides in from the left over a
/// dimmed background; the selected category is a white pill.
class CategorySidebarHost extends ConsumerWidget {
  const CategorySidebarHost({
    super.key,
    required this.playlistId,
    required this.kind,
  });

  final int playlistId;
  final SectionKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(categorySidebarOpenProvider);
    final reduced = KMotion.reduced(context);
    final duration = reduced
        ? Duration.zero
        : const Duration(milliseconds: 220);
    return IgnorePointer(
      ignoring: !open,
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: open ? 1 : 0,
              duration: duration,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () =>
                    ref.read(categorySidebarOpenProvider.notifier).close(),
                child: const ColoredBox(color: Color(0x8C000000)),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: duration,
            curve: Curves.easeOutCubic,
            left: open ? 0 : -_kWidth - 24,
            top: 0,
            bottom: 0,
            width: _kWidth,
            child: open
                ? _SidebarPanel(playlistId: playlistId, kind: kind)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

const double _kWidth = 400;

class _SidebarPanel extends ConsumerWidget {
  const _SidebarPanel({required this.playlistId, required this.kind});

  final int playlistId;
  final SectionKind kind;

  CategoryScope get _scope => (playlistId: playlistId, kind: kind);

  String _orderLabel(L10n l10n, String value) => switch (value) {
    'name' => l10n.shellOrderName,
    'custom' => l10n.shellOrderCustom,
    'number' => l10n.shellOrderNumber,
    'date' => l10n.shellOrderDate,
    _ => l10n.shellOrderPlaylist,
  };

  String _title(L10n l10n, CategoryView view) => switch (view.ref) {
    FavoritesCategory(tagId: null) => l10n.shellFavorites,
    LastWatchedCategory() => l10n.shellLastWatched,
    RecentlyAddedCategory() => l10n.shellRecentlyAdded,
    AllCategory() =>
      kind == SectionKind.live ? l10n.shellAllChannels : l10n.shellHome,
    _ => view.title,
  };

  Future<void> _chooseOrder(
    BuildContext context,
    WidgetRef ref, {
    required SettingKey<String> key,
    required String title,
    required List<String> values,
  }) async {
    final l10n = L10n.of(context);
    final current = ref.readSetting(key, playlistId: playlistId);
    final picked = await showChooser<String>(
      context,
      title: title,
      selected: current,
      choices: [
        for (final v in values) KChoice(value: v, label: _orderLabel(l10n, v)),
      ],
    );
    if (picked != null && picked != current) {
      await ref.writeSetting(key, picked, playlistId: playlistId);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final categories = ref.watch(categoriesProvider(_scope));
    final active = ref.watch(activeCategoryProvider(_scope)).value;
    final categoriesOrder = ref.watchSetting(
      PlaylistSettings.categoriesOrder,
      playlistId: playlistId,
    );
    final channelsOrder = ref.watchSetting(
      PlaylistSettings.channelsOrder,
      playlistId: playlistId,
    );

    void close() => ref.read(categorySidebarOpenProvider.notifier).close();

    final panel = DecoratedBox(
      decoration: const BoxDecoration(
        color: KColors.surface1,
        border: Border(right: BorderSide(color: KColors.stroke)),
        boxShadow: [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 40,
            offset: Offset(8, 0),
          ),
        ],
      ),
      child: categories.when(
        loading: () => const KLoadingState(),
        error: (e, _) => KErrorState(message: '$e'),
        data: (items) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            SettingsSectionHeader(l10n.shellSorting.upper(context)),
            SettingsRow(
              title: l10n.shellCategoriesOrder,
              value: _orderLabel(l10n, categoriesOrder),
              onTap: () => _chooseOrder(
                context,
                ref,
                key: PlaylistSettings.categoriesOrder,
                title: l10n.shellCategoriesOrder,
                values: const ['playlist', 'name', 'custom'],
              ),
            ),
            if (kind == SectionKind.live)
              SettingsRow(
                title: l10n.shellChannelsOrder,
                value: _orderLabel(l10n, channelsOrder),
                onTap: () => _chooseOrder(
                  context,
                  ref,
                  key: PlaylistSettings.channelsOrder,
                  title: l10n.shellChannelsOrder,
                  values: const ['playlist', 'name', 'number', 'date'],
                ),
              ),
            SettingsSectionHeader(l10n.shellCategoriesHeader.upper(context)),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.shellNoCategories,
                  style: KText.body.copyWith(color: KColors.textSecondary),
                ),
              ),
            for (final item in [
              if (kind != SectionKind.live) homeCategoryView(kind),
              ...items,
            ])
              _CategoryRow(
                title: _title(l10n, item),
                count: item.ref is AllCategory ? null : item.count,
                depth: item.depth,
                locked: item.locked,
                selected: active?.ref == item.ref,
                autofocus: active?.ref == item.ref,
                onTap: () {
                  ref
                      .read(selectedCategoryProvider(_scope).notifier)
                      .select(item.ref);
                  close();
                },
              ),
          ],
        ),
      ),
    );

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): close},
      child: FocusScope(
        autofocus: true,
        // TV: when the selected row is not built (far down the lazy list),
        // the panel's first row takes focus instead of the invisible scope.
        child: KTvFocusFirst(child: panel),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.title,
    required this.count,
    required this.depth,
    required this.locked,
    required this.selected,
    required this.autofocus,
    required this.onTap,
  });

  final String title;
  final int? count;
  final int depth;
  final bool locked;
  final bool selected;
  final bool autofocus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: depth * 24.0, bottom: 2),
      child: KInteractive(
        onTap: onTap,
        autofocus: autofocus,
        selected: selected,
        builder: (context, state, _) {
          // On TV the white pill marks focus alone; the selected category
          // keeps a quiet fill.
          final tv = KTvMode.of(context);
          final pill = state.highlighted || (selected && !tv);
          final fg = pill ? Colors.black : KColors.textPrimary;
          return AnimatedContainer(
            duration: KDurations.hover,
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: tv
                  ? (state.highlighted
                        ? Colors.white
                        : selected
                        ? const Color(0x24FFFFFF)
                        : Colors.transparent)
                  : selected
                  ? Colors.white
                  : state.highlighted
                  ? const Color(0xFFE6E6E6)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(KRadii.pill),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KText.menu.copyWith(
                      color: fg,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (locked)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      PhosphorIconsLight.lock,
                      size: 16,
                      color: pill ? Colors.black54 : KColors.success,
                    ),
                  ),
                if (count != null)
                  Text(
                    '$count',
                    style: KText.time.copyWith(
                      color: pill ? Colors.black54 : KColors.textSecondary,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Small progress chip in the top bar while a background reload runs.
class ShellReloadChip extends ConsumerWidget {
  const ShellReloadChip({super.key, required this.playlistId});

  final int playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(shellImportProgressProvider(playlistId)).value;
    if (progress == null || progress.isTerminal) {
      return const SizedBox.shrink();
    }
    final l10n = L10n.of(context);
    final fraction = importFraction(progress);
    final label = progress.step.isEpg
        ? l10n.shellReloadingEpg
        : l10n.shellReloading((fraction * 100).round());
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: KProgressChip(label: label, progress: fraction),
    );
  }
}
