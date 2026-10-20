import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/shell/category_selection.dart';
import '../../data/db/database.dart';
import '../../l10n/gen/app_localizations.dart';
import 'widgets/vod_grid.dart';

/// "See All" (`Routes.seeAll`): the full grid of a home row.
///
/// [section] is `movies` or `shows`; [categoryId] is a grid source key:
/// `cw` (Continue watching), a sidebar key (`p:<id>`, `fav`, `fav:<tag>`,
/// `recent`, `all`) or a bare provider category id. Back (the chip, Esc or
/// Backspace) returns to the home; picking a category in the sidebar while
/// here shows it on the tab.
class CategoryGridScreen extends ConsumerWidget {
  const CategoryGridScreen({
    super.key,
    required this.playlistId,
    required this.section,
    required this.categoryId,
  });
  final int playlistId;
  final String section;
  final String categoryId;

  SectionKind get _kind =>
      section == MainTab.shows.segment ? SectionKind.series : SectionKind.movie;

  MainTab get _tab =>
      _kind == SectionKind.series ? MainTab.shows : MainTab.movies;

  void _back(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      Navigator.of(context).maybePop();
      return;
    }
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(Routes.tab(playlistId, _tab));
    }
  }

  /// Route parameters may arrive encoded (`p%3A1001`) or decoded.
  static String _decode(String value) {
    if (!value.contains('%')) return value;
    try {
      return Uri.decodeComponent(value);
    } on ArgumentError {
      return value;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    ref.listen(
      selectedCategoryProvider((playlistId: playlistId, kind: _kind)),
      (previous, next) {
        if (next != null && next != previous) {
          GoRouter.maybeOf(context)?.go(Routes.tab(playlistId, _tab));
        }
      },
    );
    return VodGridView(
      playlistId: playlistId,
      kind: _kind,
      sourceKey: _decode(categoryId),
      backLabel: _kind == SectionKind.series
          ? l10n.vodBackToShows
          : l10n.vodBackToMovies,
      onBack: () => _back(context),
    );
  }
}
