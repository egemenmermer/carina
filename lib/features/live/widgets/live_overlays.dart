import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../../../data/repositories/repository_models.dart';
import '../../../l10n/gen/app_localizations.dart';

/// The floating category pill at the top-center of the channel list / grid.
/// Clicking it opens the category sidebar.
class LiveCategoryPill extends StatelessWidget {
  const LiveCategoryPill({
    super.key,
    required this.category,
    required this.onTap,
    this.focusNode,
  });

  /// The active category; null shows "Choose a category".
  final CategoryView? category;
  final VoidCallback onTap;
  final FocusNode? focusNode;

  /// The sidebar's label of [category] (special entries are localized).
  static String labelOf(L10n l10n, CategoryView category) =>
      switch (category.ref) {
        FavoritesCategory(tagId: null) => l10n.shellFavorites,
        LastWatchedCategory() => l10n.shellLastWatched,
        RecentlyAddedCategory() => l10n.shellRecentlyAdded,
        AllCategory() => l10n.shellAllChannels,
        _ => category.label,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = category;
    final flag = c?.flag;
    final icon = switch (c?.ref) {
      FavoritesCategory() => PhosphorIconsFill.star,
      LastWatchedCategory() => PhosphorIconsLight.clockCounterClockwise,
      RecentlyAddedCategory() => PhosphorIconsLight.sparkle,
      _ => null,
    };
    return KPill(
      label: c == null ? l10n.liveChooseCategory : labelOf(l10n, c),
      outlined: true,
      large: true,
      leading: flag != null
          ? Text(flag)
          : icon != null
          ? Icon(icon)
          : null,
      onTap: onTap,
      focusNode: focusNode,
    );
  }
}

/// Number zapping OSD (top-right): the typed digits, or "No channel 42".
class LiveNumberOsd extends StatelessWidget {
  const LiveNumberOsd({super.key, required this.digits, this.message});

  final String digits;

  /// Shown under the digits (channel not found).
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: message ?? digits,
      child: Container(
        constraints: const BoxConstraints(minWidth: 120),
        padding: const EdgeInsets.fromLTRB(26, 12, 26, 14),
        decoration: BoxDecoration(
          color: KColors.surface2.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(KRadii.panel),
          border: Border.all(color: KColors.materialStroke),
          boxShadow: KShadows.floating,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              digits,
              style: KText.heroTitle.copyWith(
                fontSize: 52,
                fontFeatures: KText.tabular,
                letterSpacing: 2,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 2),
              Text(
                message!,
                style: KText.label.copyWith(color: KColors.accent),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
