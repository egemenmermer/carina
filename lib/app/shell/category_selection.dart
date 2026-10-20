import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/repository_models.dart';
import '../../data/settings/settings_store.dart';

/// Which section a sidebar selection belongs to.
typedef CategoryScope = ({int playlistId, SectionKind kind});

/// Last selected category per section, kept across launches.
const _lastLive = SettingKey<String?>(
  'selectedCategory.live',
  null,
  SettingScope.playlist,
);
const _lastMovie = SettingKey<String?>(
  'selectedCategory.movie',
  null,
  SettingScope.playlist,
);
const _lastSeries = SettingKey<String?>(
  'selectedCategory.series',
  null,
  SettingScope.playlist,
);

SettingKey<String?> _keyFor(SectionKind kind) => switch (kind) {
  SectionKind.live => _lastLive,
  SectionKind.movie => _lastMovie,
  SectionKind.series => _lastSeries,
};

/// The category the user picked in the sidebar (null = not chosen yet; use
/// [activeCategoryProvider] to get the effective one). TV Live and TV Guide
/// share the live selection.
final selectedCategoryProvider =
    NotifierProvider.family<SelectedCategory, CategoryRef?, CategoryScope>(
      SelectedCategory.new,
    );

class SelectedCategory extends Notifier<CategoryRef?> {
  SelectedCategory(this.scope);

  final CategoryScope scope;

  @override
  CategoryRef? build() {
    final saved = ref
        .read(settingsStoreProvider)
        .get(_keyFor(scope.kind), playlistId: scope.playlistId);
    return saved == null ? null : CategoryRef.tryParse(saved);
  }

  void select(CategoryRef category) {
    state = category;
    ref
        .read(settingsStoreProvider)
        .set(_keyFor(scope.kind), category.key, playlistId: scope.playlistId);
  }
}

/// The effective category of a section: the user's choice when it still
/// exists, else the first provider category, else the first entry. Null while categories load or when the
/// section is empty.
final activeCategoryProvider = Provider.autoDispose
    .family<AsyncValue<CategoryView?>, CategoryScope>((ref, scope) {
      final list = ref.watch(categoriesProvider(scope));
      final chosen = ref.watch(selectedCategoryProvider(scope));
      return list.whenData((items) {
        // Movies/Shows: "Home" (hero + rows) is the default and an explicit
        // entry at the top of the sidebar.
        if (scope.kind != SectionKind.live) {
          final home = homeCategoryView(scope.kind);
          if (chosen == null || chosen is AllCategory) return home;
          for (final item in items) {
            if (item.ref == chosen) return item;
          }
          return home;
        }
        if (items.isEmpty) return null;
        if (chosen != null) {
          for (final item in items) {
            if (item.ref == chosen) return item;
          }
        }
        for (final item in items) {
          if (item.ref is ProviderCategory) return item;
        }
        return items.first;
      });
    });

/// The synthetic "Home" entry of the Movies/Shows sidebar.
CategoryView homeCategoryView(SectionKind kind) => CategoryView(
  ref: const AllCategory(),
  kind: kind,
  name: 'Home',
  label: 'Home',
  count: 0,
);
