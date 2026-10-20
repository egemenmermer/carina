import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router.dart';
import '../../../core/core.dart';
import '../../../data/db/database.dart';
import '../../../data/import/import.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/live_repository.dart';
import '../../../data/repositories/playlist_repository.dart';
import '../../../data/repositories/vod_repository.dart';
import '../../../data/settings/settings_store.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../data/playlist_options.dart';
import '../settings_model.dart';
import '../widgets/settings_widgets.dart';
import '../widgets/text_input_dialog.dart';

/// Drill-down lists inside a playlist section.
enum SettingsSubpage { hiddenItems, renamedCategories, customEpg }

typedef OpenSubpage = void Function(SettingsSubpage page);

/// Reload frequency choices (hours; 0 = never).
const List<int> libraryReloadFrequencies = [0, 12, 24, 72, 168];

String reloadFrequencyLabel(L10n l, int hours) => switch (hours) {
  0 => l.libraryReloadNever,
  < 24 => l.libraryEveryHours(hours),
  _ when hours % 24 == 0 => l.libraryEveryDays(hours ~/ 24),
  _ => l.libraryEveryHours(hours),
};

String epgShiftLabel(L10n l, int hours) {
  if (hours == 0) return l.libraryNoShift;
  final sign = hours > 0 ? '+' : '−';
  return l.libraryShiftHours('$sign${hours.abs()}');
}

// ---------------------------------------------------------------------------
// General
// ---------------------------------------------------------------------------

class PlaylistGeneralSection extends ConsumerWidget {
  const PlaylistGeneralSection({super.key, required this.playlistId});

  final int playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final pid = playlistId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroupTitle(l10n.libraryGroupStartup, first: true),
        SettingsGroup(
          children: [
            settingRow(LibrarySettingSpecs.initialTab, pid),
            settingRow(LibrarySettingSpecs.continueWatchingOpensPlayer, pid),
          ],
        ),
        SettingsGroupTitle(l10n.libraryGroupSections),
        SettingsNote(l10n.libraryGroupSectionsNote, center: true),
        const SizedBox(height: 4),
        SettingsGroup(
          children: [
            settingRow(LibrarySettingSpecs.showMovies, pid),
            settingRow(LibrarySettingSpecs.showShows, pid),
            settingRow(LibrarySettingSpecs.showLive, pid),
            settingRow(LibrarySettingSpecs.showGuide, pid),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Playlist Management
// ---------------------------------------------------------------------------

class ManagementSection extends ConsumerWidget {
  const ManagementSection({
    super.key,
    required this.playlistId,
    required this.onOpenSubpage,
  });

  final int playlistId;
  final OpenSubpage onOpenSubpage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final pid = playlistId;
    final playlist = ref.watch(playlistProvider(pid)).value;
    final hiddenCount =
        (ref.watch(hiddenChannelsProvider(pid)).value?.length ?? 0) +
        (ref.watch(hiddenCategoriesProvider(pid)).value?.length ?? 0) +
        (ref.watch(hiddenVodItemsProvider(pid)).value?.length ?? 0);
    final renamedCount =
        ref.watch(renamedCategoriesProvider(pid)).value?.length ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroupTitle(l10n.libraryGroupHome, first: true),
        SettingsGroup(
          children: [
            settingRow(LibrarySettingSpecs.showLastWatched, pid),
            settingRow(LibrarySettingSpecs.showRecentlyAdded, pid),
            settingRow(LibrarySettingSpecs.showTrending, pid),
          ],
        ),
        SettingsGroupTitle(l10n.libraryGroupSorting),
        SettingsGroup(
          children: [
            settingRow(LibrarySettingSpecs.categoriesOrder, pid),
            settingRow(LibrarySettingSpecs.channelsOrder, pid),
            settingRow(LibrarySettingSpecs.favoritesOrder, pid),
            settingRow(LibrarySettingSpecs.continueWatchingOrder, pid),
          ],
        ),
        SettingsGroupTitle(l10n.libraryGroupCustomization),
        SettingsGroup(
          children: [
            SettingsRow(
              key: const ValueKey('row:renamed'),
              title: l10n.libraryRenameCategories,
              value: l10n.libraryItemCount(renamedCount),
              onTap: () => onOpenSubpage(SettingsSubpage.renamedCategories),
            ),
            SettingsRow(
              key: const ValueKey('row:hidden'),
              title: l10n.libraryHiddenItems,
              value: l10n.libraryItemCount(hiddenCount),
              onTap: () => onOpenSubpage(SettingsSubpage.hiddenItems),
            ),
          ],
        ),
        SettingsGroupTitle(l10n.libraryGroupUpdates),
        SettingsGroup(
          children: [
            SettingsActionRow(
              key: const ValueKey('action:reload'),
              title: l10n.libraryForceReload,
              icon: PhosphorIconsBold.arrowClockwise,
              onTap: () => startPlaylistImport(
                context,
                ref,
                playlistId: pid,
                scope: ImportScope.all,
              ),
            ),
            SettingsActionRow(
              key: const ValueKey('action:reload-epg'),
              title: l10n.libraryForceReloadEpg,
              icon: PhosphorIconsBold.arrowClockwise,
              onTap: () => startPlaylistImport(
                context,
                ref,
                playlistId: pid,
                scope: ImportScope.epg,
              ),
            ),
            ImportStatusLine(playlistId: pid),
            if (playlist != null) ...[
              SettingsRow(
                key: const ValueKey('row:reload-frequency'),
                title: l10n.libraryReloadFrequency,
                value: reloadFrequencyLabel(
                  l10n,
                  playlist.reloadFrequencyHours,
                ),
                onTap: () => _chooseFrequency(context, ref, playlist),
              ),
              SettingsRow(
                key: const ValueKey('row:epg-shift'),
                title: l10n.libraryEpgShift,
                value: epgShiftLabel(l10n, playlist.epgShiftHours),
                onTap: () => _chooseShift(context, ref, playlist),
              ),
            ],
          ],
        ),
        SettingsGroupTitle(l10n.libraryGroupSource),
        SettingsGroup(
          children: [
            SettingsActionRow(
              key: const ValueKey('action:edit-source'),
              title: l10n.libraryEditSource,
              subtitle: l10n.libraryEditSourceHint,
              icon: PhosphorIconsBold.pencilSimple,
              onTap: () =>
                  GoRouter.maybeOf(context)?.go(Routes.editPlaylist(pid)),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _chooseFrequency(
    BuildContext context,
    WidgetRef ref,
    PlaylistRow playlist,
  ) async {
    final l10n = L10n.of(context);
    final hours = await showChooser<int>(
      context,
      title: l10n.libraryReloadFrequency,
      description: l10n.libraryReloadFrequencyHint,
      selected: playlist.reloadFrequencyHours,
      choices: [
        for (final h in {
          ...libraryReloadFrequencies,
          playlist.reloadFrequencyHours,
        })
          KChoice(value: h, label: reloadFrequencyLabel(l10n, h)),
      ],
    );
    if (hours == null || hours == playlist.reloadFrequencyHours) return;
    if (!context.mounted) return;
    await _saveOptions(
      context,
      ref,
      playlist.id,
      reloadFrequencyHours: hours,
      toast: l10n.librarySettingChanged(
        l10n.libraryReloadFrequency,
        reloadFrequencyLabel(l10n, hours),
      ),
    );
  }

  Future<void> _chooseShift(
    BuildContext context,
    WidgetRef ref,
    PlaylistRow playlist,
  ) async {
    final l10n = L10n.of(context);
    final hours = await showChooser<int>(
      context,
      title: l10n.libraryEpgShift,
      description: l10n.libraryEpgShiftHint,
      selected: playlist.epgShiftHours,
      choices: [
        for (var h = -12; h <= 12; h++)
          KChoice(value: h, label: epgShiftLabel(l10n, h)),
      ],
    );
    if (hours == null || hours == playlist.epgShiftHours) return;
    if (!context.mounted) return;
    await _saveOptions(
      context,
      ref,
      playlist.id,
      epgShiftHours: hours,
      toast: l10n.libraryEpgShiftSaved(epgShiftLabel(l10n, hours)),
    );
  }

  Future<void> _saveOptions(
    BuildContext context,
    WidgetRef ref,
    int playlistId, {
    int? reloadFrequencyHours,
    int? epgShiftHours,
    required String toast,
  }) async {
    final l10n = L10n.of(context);
    final toasts = ref.read(toastControllerProvider);
    final imports = ref.read(importServiceProvider);
    try {
      final changes = await ref
          .read(playlistRepositoryProvider)
          .updateOptions(
            playlistId,
            reloadFrequencyHours: reloadFrequencyHours,
            epgShiftHours: epgShiftHours,
          );
      toasts.show(toast);
      // The shift is applied while importing: reload the guide.
      if (changes != null && changes.epg && !imports.isRunning(playlistId)) {
        imports.start(playlistId, scope: ImportScope.epg);
      }
    } on Object catch (e) {
      debugPrint('Settings: saving playlist options failed: $e');
      toasts.show(l10n.libraryActionFailed, kind: KToastKind.error);
    }
  }
}

/// Starts a reload of [scope] (or reports the one already running).
void startPlaylistImport(
  BuildContext context,
  WidgetRef ref, {
  required int playlistId,
  required ImportScope scope,
}) {
  final l10n = L10n.of(context);
  final imports = ref.read(importServiceProvider);
  final toasts = ref.read(toastControllerProvider);
  if (imports.isRunning(playlistId)) {
    toasts.show(l10n.libraryReloadRunning, kind: KToastKind.info);
    return;
  }
  imports.start(playlistId, scope: scope);
  toasts.show(
    scope == ImportScope.epg
        ? l10n.libraryReloadEpgStarted
        : l10n.libraryReloadStarted,
  );
}

/// "Status: …" under the reload rows: the running import's step
/// (Connecting → … → Cleaning programs → Downloading → Parsing), then
/// "Completed (n programmes)"; when nothing ran this session, the last
/// update of the stored guide.
class ImportStatusLine extends ConsumerWidget {
  const ImportStatusLine({super.key, required this.playlistId});

  final int playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final number = NumberFormat.decimalPattern(l10n.localeName);
    final running = ref.watch(importProgressProvider(playlistId)).value;
    final service = ref.watch(importServiceProvider);
    final playlist = ref.watch(playlistProvider(playlistId)).value;
    final progress = running ?? service.lastResult(playlistId);

    String count(ImportStep step) =>
        number.format(progress?.countOf(step) ?? 0);

    final (String status, Color color) = switch (progress?.step) {
      null =>
        playlist?.lastEpgReloadAt == null
            ? (l10n.libraryStatusNever, KColors.textSecondary)
            : (
                l10n.libraryStatusStored(
                  number.format(playlist!.programmeCount),
                ),
                KColors.textSecondary,
              ),
      ImportStep.connecting => (
        l10n.libraryStepConnecting,
        KColors.textPrimary,
      ),
      ImportStep.liveCategories || ImportStep.liveChannels => (
        l10n.libraryStepChannels(count(ImportStep.liveChannels)),
        KColors.textPrimary,
      ),
      ImportStep.movies => (
        l10n.libraryStepMovies(count(ImportStep.movies)),
        KColors.textPrimary,
      ),
      ImportStep.series => (
        l10n.libraryStepSeries(count(ImportStep.series)),
        KColors.textPrimary,
      ),
      ImportStep.epgCleaning => (l10n.libraryStepCleaning, KColors.textPrimary),
      ImportStep.epgDownloading => (
        progress!.byteFraction == null
            ? l10n.libraryStepDownloading
            : l10n.libraryStepDownloadingPercent(
                (progress.byteFraction! * 100).round(),
              ),
        KColors.textPrimary,
      ),
      ImportStep.epgParsing => (
        l10n.libraryStepParsing(count(ImportStep.epgParsing)),
        KColors.textPrimary,
      ),
      ImportStep.completed => (
        progress!.epgFailed
            ? l10n.libraryStepCompletedNoGuide
            : l10n.libraryStepCompleted(
                number.format(
                  progress.countOf(ImportStep.epgParsing) ??
                      playlist?.programmeCount ??
                      0,
                ),
              ),
        progress.epgFailed ? KButton.destructiveForeground : KColors.success,
      ),
      ImportStep.failed => (
        l10n.libraryStepFailed,
        KButton.destructiveForeground,
      ),
      ImportStep.cancelled => (
        l10n.libraryStepCancelled,
        KColors.textSecondary,
      ),
    };
    final fraction = running == null || running.isTerminal
        ? null
        : running.fraction;
    return Padding(
      key: const ValueKey('import-status'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${l10n.libraryStatusLabel} '),
                TextSpan(
                  text: status,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            textAlign: TextAlign.center,
            style: KText.caption,
          ),
          if (fraction != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: 240,
              child: KProgressBar(value: fraction, height: 3),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TV Live & TV Guide
// ---------------------------------------------------------------------------

class LiveSection extends ConsumerWidget {
  const LiveSection({
    super.key,
    required this.playlistId,
    required this.onOpenSubpage,
  });

  final int playlistId;
  final OpenSubpage onOpenSubpage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final pid = playlistId;
    final playlist = ref.watch(playlistProvider(pid)).value;
    final customCount =
        ref.watch(customEpgChannelsProvider(pid)).value?.length ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroupTitle(l10n.libraryGroupEpg, first: true),
        SettingsGroup(
          children: [
            SettingsActionRow(
              key: const ValueKey('action:live-reload-epg'),
              title: l10n.libraryForceReloadEpg,
              icon: PhosphorIconsBold.arrowClockwise,
              onTap: () => startPlaylistImport(
                context,
                ref,
                playlistId: pid,
                scope: ImportScope.epg,
              ),
            ),
            ImportStatusLine(playlistId: pid),
            SettingsRow(
              key: const ValueKey('row:custom-epg'),
              title: l10n.libraryCustomEpg,
              value: l10n.libraryItemCount(customCount),
              onTap: () => onOpenSubpage(SettingsSubpage.customEpg),
            ),
          ],
        ),
        SettingsGroupTitle(l10n.shellLive),
        SettingsGroup(
          children: [
            settingRow(LibrarySettingSpecs.liveLayout, pid),
            settingRow(LibrarySettingSpecs.livePreview, pid),
            settingRow(LibrarySettingSpecs.previewStartsOn, pid),
            settingRow(LibrarySettingSpecs.previewFocusDelay, pid),
            settingRow(LibrarySettingSpecs.previewAudio, pid),
            settingRow(LibrarySettingSpecs.numberZapping, pid),
            settingRow(LibrarySettingSpecs.wheelZaps, pid),
            if (playlist?.type == PlaylistType.xtream)
              settingRow(LibrarySettingSpecs.liveOutputFormat, pid),
          ],
        ),
        SettingsGroupTitle(l10n.shellGuide),
        SettingsGroup(
          children: [settingRow(LibrarySettingSpecs.guideZoom, pid)],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Player
// ---------------------------------------------------------------------------

class PlayerSection extends ConsumerWidget {
  const PlayerSection({super.key, required this.playlistId});

  final int playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final pid = playlistId;
    final bufferPolicy = ref.watchSetting(
      PlaylistSettings.bufferPolicy,
      playlistId: pid,
    );
    final userAgentMode = ref.watchSetting(
      PlaylistSettings.userAgentMode,
      playlistId: pid,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroupTitle(l10n.libraryGroupPlayers, first: true),
        SettingsGroup(
          children: [
            settingRow(LibrarySettingSpecs.playerVod, pid),
            settingRow(LibrarySettingSpecs.playerLive, pid),
            settingRow(LibrarySettingSpecs.playerArchive, pid),
            settingRow(LibrarySettingSpecs.hardwareAcceleration, pid),
          ],
        ),
        SettingsGroupTitle(l10n.libraryGroupBuffering),
        SettingsGroup(
          children: [
            settingRow(LibrarySettingSpecs.bufferPolicy, pid),
            if (bufferPolicy == 'custom')
              settingRow(LibrarySettingSpecs.bufferCustomSeconds, pid),
            settingRow(LibrarySettingSpecs.liveReconnectAttempts, pid),
          ],
        ),
        SettingsGroupTitle(l10n.libraryGroupPicture),
        SettingsGroup(
          children: [
            settingRow(LibrarySettingSpecs.aspect, pid),
            settingRow(LibrarySettingSpecs.deinterlace, pid),
            settingRow(LibrarySettingSpecs.deinterlaceMethod, pid),
            settingRow(LibrarySettingSpecs.resolutionIndicator, pid),
          ],
        ),
        SettingsGroupTitle(l10n.libraryGroupAudioSubtitles),
        SettingsGroup(
          children: [
            settingRow(LibrarySettingSpecs.audioLanguage, pid),
            settingRow(LibrarySettingSpecs.subtitleLanguage, pid),
            settingRow(LibrarySettingSpecs.subtitleSize, pid),
            settingRow(LibrarySettingSpecs.audioDelay, pid),
          ],
        ),
        SettingsGroupTitle(l10n.libraryGroupPlayback),
        SettingsGroup(
          children: [
            settingRow(LibrarySettingSpecs.autoPlayOnCloseProgress, pid),
            settingRow(LibrarySettingSpecs.alwaysResume, pid),
            settingRow(LibrarySettingSpecs.autoplayNextEpisode, pid),
          ],
        ),
        SettingsGroupTitle(l10n.libraryGroupNetwork),
        SettingsGroup(
          children: [
            settingRow(LibrarySettingSpecs.userAgentMode, pid),
            if (userAgentMode == 'custom')
              TextSettingRow(
                key: const ValueKey('setting:userAgentCustom'),
                settingKey: PlaylistSettings.userAgentCustom,
                playlistId: pid,
                title: l10n.librarySetUserAgentCustom,
                description: l10n.librarySetUserAgentCustomHint,
                hint: 'Mozilla/5.0 …',
              ),
            TextSettingRow(
              key: const ValueKey('setting:referer'),
              settingKey: PlaylistSettings.referer,
              playlistId: pid,
              title: l10n.librarySetReferer,
              description: l10n.librarySetRefererHint,
              hint: 'https://…',
            ),
          ],
        ),
      ],
    );
  }
}

/// A row editing a free-text setting in the text panel (blank = not set).
class TextSettingRow extends ConsumerWidget {
  const TextSettingRow({
    super.key,
    required this.settingKey,
    required this.title,
    required this.description,
    this.playlistId,
    this.hint,
  });

  final SettingKey<String> settingKey;
  final int? playlistId;
  final String title;
  final String description;
  final String? hint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final value = ref.watchSetting(settingKey, playlistId: playlistId);
    return SettingsRow(
      title: title,
      value: value.isEmpty ? l10n.libraryNotSet : value,
      onTap: () async {
        final toasts = ref.read(toastControllerProvider);
        final store = ref.read(settingsStoreProvider);
        final text = await showLibraryTextInput(
          context,
          title: title,
          description: description,
          initialValue: value,
          hint: hint,
        );
        if (text == null || text == value) return;
        if (text.isEmpty) {
          await store.reset(settingKey, playlistId: playlistId);
        } else {
          await store.set(settingKey, text, playlistId: playlistId);
        }
        toasts.show(
          l10n.librarySettingChanged(
            title,
            text.isEmpty ? l10n.libraryNotSet : text,
          ),
        );
      },
    );
  }
}
