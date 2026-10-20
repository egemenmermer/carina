import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../../data/db/database.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/live_repository.dart';
import '../../../data/repositories/repository_models.dart';
import '../../../data/repositories/vod_repository.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../live/live_api.dart';
import '../widgets/settings_widgets.dart';

String _kindLabel(L10n l10n, SectionKind kind) => switch (kind) {
  SectionKind.live => l10n.shellLive,
  SectionKind.movie => l10n.shellMovies,
  SectionKind.series => l10n.shellShows,
};

Widget _smallButton(String label, IconData icon, VoidCallback onPressed) =>
    KButton.secondary(
      label: label,
      icon: icon,
      size: KButtonSize.small,
      onPressed: onPressed,
    );

/// Settings → Playlist Management → Hidden items: hidden channels,
/// categories, movies and shows, each with Unhide.
class HiddenItemsPage extends ConsumerWidget {
  const HiddenItemsPage({super.key, required this.playlistId});

  final int playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final pid = playlistId;
    final channels = ref.watch(hiddenChannelsProvider(pid)).value;
    final categories = ref.watch(hiddenCategoriesProvider(pid)).value;
    final vod = ref.watch(hiddenVodItemsProvider(pid)).value;
    if (channels == null || categories == null || vod == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 60),
        child: KLoadingState(),
      );
    }
    final toasts = ref.read(toastControllerProvider);
    final movies = vod.where((v) => v.kind == SectionKind.movie).toList();
    final shows = vod.where((v) => v.kind == SectionKind.series).toList();

    Future<void> unhideChannel(ChannelView c) async {
      await ref
          .read(liveRepositoryProvider)
          .setHidden(pid, c.providerId, false);
      toasts.show(l10n.libraryUnhidden(c.displayName));
    }

    Future<void> unhideCategory(CategoryView c) async {
      final id = c.providerId;
      if (id == null) return;
      await ref
          .read(categoryRepositoryProvider)
          .setHidden(pid, c.kind, id, false);
      toasts.show(l10n.libraryUnhidden(c.title));
    }

    Future<void> unhideVod(VodItem item) async {
      await ref
          .read(vodRepositoryProvider)
          .setHidden(pid, item.kind, item.providerId, false);
      toasts.show(l10n.libraryUnhidden(item.name));
    }

    if (channels.isEmpty &&
        categories.isEmpty &&
        movies.isEmpty &&
        shows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 48),
        child: KEmptyState(
          icon: PhosphorIconsLight.eyeSlash,
          message: l10n.libraryHiddenEmpty,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsNote(l10n.libraryHiddenNote, center: true),
        if (channels.isNotEmpty) ...[
          SettingsGroupTitle(l10n.libraryHiddenChannels(channels.length)),
          SettingsList(
            emptyMessage: '',
            children: [
              for (final c in channels)
                SettingsListTile(
                  key: ValueKey('hidden-channel-${c.providerId}'),
                  leading: KLogoTile(
                    name: c.displayName,
                    url: c.logo,
                    size: 40,
                  ),
                  title: c.displayName,
                  subtitle: c.categoryName.isEmpty ? null : c.categoryName,
                  trailing: _smallButton(
                    l10n.libraryUnhide,
                    PhosphorIconsBold.eye,
                    () => unhideChannel(c),
                  ),
                ),
            ],
          ),
        ],
        if (categories.isNotEmpty) ...[
          SettingsGroupTitle(l10n.libraryHiddenCategories(categories.length)),
          SettingsList(
            emptyMessage: '',
            children: [
              for (final c in categories)
                SettingsListTile(
                  key: ValueKey(
                    'hidden-category-${c.kind.name}-${c.providerId}',
                  ),
                  leading: const Icon(
                    PhosphorIconsLight.folderSimple,
                    size: 24,
                    color: KColors.textSecondary,
                  ),
                  title: c.title,
                  subtitle:
                      '${_kindLabel(l10n, c.kind)} · ${l10n.libraryItemCount(c.count)}',
                  trailing: _smallButton(
                    l10n.libraryUnhide,
                    PhosphorIconsBold.eye,
                    () => unhideCategory(c),
                  ),
                ),
            ],
          ),
        ],
        for (final (items, title) in [
          (movies, l10n.libraryHiddenMovies(movies.length)),
          (shows, l10n.libraryHiddenShows(shows.length)),
        ])
          if (items.isNotEmpty) ...[
            SettingsGroupTitle(title),
            SettingsList(
              emptyMessage: '',
              children: [
                for (final item in items)
                  SettingsListTile(
                    key: ValueKey(
                      'hidden-${item.kind.name}-${item.providerId}',
                    ),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        width: 28,
                        height: 42,
                        child: KImage(
                          item.poster,
                          fit: BoxFit.cover,
                          placeholder: const ColoredBox(
                            color: KColors.surface3,
                          ),
                          errorBuilder: (_) =>
                              const ColoredBox(color: KColors.surface3),
                        ),
                      ),
                    ),
                    title: item.name,
                    subtitle: item.year == null ? null : '${item.year}',
                    trailing: _smallButton(
                      l10n.libraryUnhide,
                      PhosphorIconsBold.eye,
                      () => unhideVod(item),
                    ),
                  ),
              ],
            ),
          ],
      ],
    );
  }
}

/// Settings → Playlist Management → Rename categories: local names with
/// Reset (back to the provider's name).
class RenamedCategoriesPage extends ConsumerWidget {
  const RenamedCategoriesPage({super.key, required this.playlistId});

  final int playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final renamed = ref.watch(renamedCategoriesProvider(playlistId)).value;
    if (renamed == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 60),
        child: KLoadingState(),
      );
    }
    if (renamed.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 48),
        child: KEmptyState(
          icon: PhosphorIconsLight.textT,
          message: l10n.libraryRenamedEmpty,
        ),
      );
    }
    final toasts = ref.read(toastControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsNote(l10n.libraryRenamedNote, center: true),
        const SizedBox(height: 10),
        SettingsList(
          emptyMessage: '',
          children: [
            for (final c in renamed)
              SettingsListTile(
                key: ValueKey('renamed-${c.kind.name}-${c.providerId}'),
                leading: const Icon(
                  PhosphorIconsLight.textT,
                  size: 22,
                  color: KColors.textSecondary,
                ),
                title: c.title,
                subtitle: l10n.libraryRenamedOriginal(
                  c.providerName ?? '',
                  _kindLabel(l10n, c.kind),
                ),
                trailing: _smallButton(
                  l10n.libraryReset,
                  PhosphorIconsBold.arrowCounterClockwise,
                  () async {
                    final id = c.providerId;
                    if (id == null) return;
                    await ref
                        .read(categoryRepositoryProvider)
                        .rename(playlistId, c.kind, id, null);
                    toasts.show(l10n.libraryRenameReset(c.providerName ?? ''));
                  },
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Settings → TV Live & TV Guide → Custom EPG assignments: channels with a
/// manual guide channel, with Change (the picker) and Reset.
class CustomEpgPage extends ConsumerWidget {
  const CustomEpgPage({super.key, required this.playlistId});

  final int playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final channels = ref.watch(customEpgChannelsProvider(playlistId)).value;
    if (channels == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 60),
        child: KLoadingState(),
      );
    }
    if (channels.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 48),
        child: KEmptyState(
          icon: PhosphorIconsLight.listBullets,
          message: l10n.libraryCustomEpgEmpty,
        ),
      );
    }
    final toasts = ref.read(toastControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsNote(l10n.libraryCustomEpgNote, center: true),
        const SizedBox(height: 10),
        SettingsList(
          emptyMessage: '',
          children: [
            for (final c in channels)
              SettingsListTile(
                key: ValueKey('custom-epg-${c.providerId}'),
                leading: KLogoTile(name: c.displayName, url: c.logo, size: 40),
                title: c.displayName,
                subtitle: l10n.libraryCustomEpgAssigned(
                  c.row.customEpgId ?? '',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _smallButton(
                      l10n.libraryChange,
                      PhosphorIconsBold.pencilSimple,
                      () => showCustomEpgPicker(
                        context,
                        playlistId: playlistId,
                        channelId: c.providerId,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _smallButton(
                      l10n.libraryReset,
                      PhosphorIconsBold.arrowCounterClockwise,
                      () async {
                        await ref
                            .read(liveRepositoryProvider)
                            .setCustomEpg(playlistId, c.providerId, null);
                        toasts.show(l10n.libraryCustomEpgReset(c.displayName));
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
