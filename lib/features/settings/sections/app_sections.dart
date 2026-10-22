import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/time_format.dart';
import '../../../core/core.dart';
import '../../../data/app_paths.dart';
import '../../../data/repositories/playlist_repository.dart';
import '../../../data/repositories/reminders_repository.dart';
import '../../../data/secrets/secret_store.dart';
import '../../../data/settings/settings_store.dart';
import '../../../data/tmdb/tmdb_service.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../data/library_maintenance.dart';
import '../settings_model.dart';
import '../widgets/settings_widgets.dart';
import '../widgets/shell_safe_input.dart';

/// `12.3 MB` in the UI language.
String libraryBytesLabel(L10n l, int bytes) {
  final format = NumberFormat('0.#', l.localeName);
  if (bytes < 1024 * 1024) {
    return l.libraryKilobytes(format.format(bytes / 1024));
  }
  if (bytes < 1024 * 1024 * 1024) {
    return l.libraryMegabytes(format.format(bytes / (1024 * 1024)));
  }
  return l.libraryGigabytes(format.format(bytes / (1024 * 1024 * 1024)));
}

// ---------------------------------------------------------------------------
// General
// ---------------------------------------------------------------------------

class AppGeneralSection extends StatelessWidget {
  const AppGeneralSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroupTitle(l10n.libraryGroupLanguage, first: true),
        SettingsGroup(
          children: [
            settingRow(LibrarySettingSpecs.language, null),
            settingRow(LibrarySettingSpecs.timeFormat, null),
          ],
        ),
        SettingsGroupTitle(l10n.libraryGroupStartup),
        SettingsGroup(
          children: [
            settingRow(LibrarySettingSpecs.autoOpenLastPlaylist, null),
            settingRow(LibrarySettingSpecs.startFullscreen, null),
          ],
        ),
        SettingsGroupTitle(l10n.libraryGroupTopBar),
        SettingsGroup(
          children: [settingRow(LibrarySettingSpecs.showClock, null)],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// TMDb
// ---------------------------------------------------------------------------

class TmdbSection extends ConsumerStatefulWidget {
  const TmdbSection({super.key});

  @override
  ConsumerState<TmdbSection> createState() => _TmdbSectionState();
}

class _TmdbSectionState extends ConsumerState<TmdbSection> {
  final TextEditingController _key = TextEditingController();
  KFieldStatus? _status;
  bool _busy = false;

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  KFieldStatus _statusFor(L10n l10n, TmdbKeyStatus result) => switch (result) {
    TmdbKeyStatus.ok => KFieldStatus.ok(l10n.libraryTmdbKeyOk),
    TmdbKeyStatus.invalid => KFieldStatus.error(l10n.libraryTmdbKeyInvalid),
    TmdbKeyStatus.unreachable => KFieldStatus.error(
      l10n.libraryTmdbUnreachable,
    ),
  };

  Future<void> _test() async {
    final l10n = L10n.of(context);
    final typed = _key.text.trim();
    final stored = ref.read(tmdbKeyStoredProvider).value ?? false;
    if (typed.isEmpty && !stored) {
      setState(() => _status = KFieldStatus.error(l10n.libraryTmdbKeyMissing));
      return;
    }
    setState(() {
      _busy = true;
      _status = const KFieldStatus.checking();
    });
    final result = await ref
        .read(tmdbServiceProvider)
        .testKey(typed.isEmpty ? null : typed);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = _statusFor(l10n, result);
    });
  }

  Future<void> _save() async {
    final l10n = L10n.of(context);
    final typed = _key.text.trim();
    if (typed.isEmpty) {
      setState(() => _status = KFieldStatus.error(l10n.libraryTmdbKeyMissing));
      return;
    }
    final secrets = ref.read(secretStoreProvider);
    final service = ref.read(tmdbServiceProvider);
    final store = ref.read(settingsStoreProvider);
    final toasts = ref.read(toastControllerProvider);
    setState(() {
      _busy = true;
      _status = const KFieldStatus.checking();
    });
    await secrets.write(SecretStore.tmdbKey, typed);
    service.keyChanged();
    if (!store.get(AppSettings.tmdbEnabled)) {
      await store.set(AppSettings.tmdbEnabled, true);
    }
    ref.invalidate(tmdbKeyStoredProvider);
    _key.clear();
    toasts.show(l10n.libraryTmdbKeySaved);
    final result = await service.testKey(typed);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = _statusFor(l10n, result);
    });
  }

  Future<void> _remove() async {
    final l10n = L10n.of(context);
    await ref.read(secretStoreProvider).write(SecretStore.tmdbKey, null);
    ref.read(tmdbServiceProvider).keyChanged();
    ref.invalidate(tmdbKeyStoredProvider);
    ref.read(toastControllerProvider).show(l10n.libraryTmdbKeyRemoved);
    if (mounted) setState(() => _status = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final stored = ref.watch(tmdbKeyStoredProvider).value ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroupTitle(l10n.libraryGroupTmdbKey, first: true),
        SettingsNote(l10n.libraryTmdbIntro, center: true),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ShellSafeTextInput(
                  child: KTextField(
                    key: const ValueKey('tmdb-key-field'),
                    controller: _key,
                    obscure: true,
                    hint: stored
                        ? l10n.libraryTmdbKeyReplaceHint
                        : l10n.libraryTmdbKeyHint,
                    prefixIcon: PhosphorIconsLight.key,
                    status: _status,
                    onSubmitted: (_) => _save(),
                    semanticLabel: l10n.libraryTmdbKeyLabel,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 46,
                child: Center(
                  child: KButton.secondary(
                    key: const ValueKey('tmdb-test'),
                    label: l10n.libraryTmdbTest,
                    icon: PhosphorIconsBold.plugsConnected,
                    onPressed: _busy ? null : _test,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 46,
                child: Center(
                  child: KButton.accent(
                    key: const ValueKey('tmdb-save'),
                    label: l10n.save,
                    onPressed: _busy ? null : _save,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SettingsNote(
          stored ? l10n.libraryTmdbKeyStored : l10n.libraryTmdbKeyNone,
          center: true,
          color: stored ? KColors.success : null,
        ),
        if (stored)
          SettingsActionRow(
            key: const ValueKey('action:tmdb-remove'),
            title: l10n.libraryTmdbRemoveKey,
            icon: PhosphorIconsLight.trash,
            destructive: true,
            onTap: _remove,
          ),
        SettingsGroupTitle(l10n.libraryGroupTmdbOptions),
        SettingsGroup(
          children: [
            settingRow(LibrarySettingSpecs.tmdbEnabled, null),
            settingRow(LibrarySettingSpecs.tmdbLanguage, null),
            settingRow(LibrarySettingSpecs.tmdbRegion, null),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Reminders
// ---------------------------------------------------------------------------

class RemindersSection extends ConsumerWidget {
  const RemindersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final reminders = ref.watch(remindersProvider(null)).value;
    final playlists = ref.watch(playlistsProvider).value ?? const [];
    final names = {for (final p in playlists) p.id: p.name};
    final fmt = ref.watch(timeFormatProvider);
    final toasts = ref.read(toastControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroupTitle(l10n.libraryGroupNotifications, first: true),
        SettingsGroup(
          children: [settingRow(LibrarySettingSpecs.reminderLead, null)],
        ),
        SettingsNote(l10n.libraryRemindersNote, center: true),
        SettingsGroupTitle(l10n.libraryManageReminders),
        if (reminders == null)
          const Center(child: KSpinner(size: 22))
        else
          SettingsList(
            emptyMessage: l10n.libraryRemindersEmpty,
            children: [
              for (final r in reminders)
                SettingsListTile(
                  key: ValueKey('reminder-${r.id}'),
                  leading: const Icon(
                    PhosphorIconsFill.bellRinging,
                    size: 22,
                    color: KColors.accent,
                  ),
                  title: r.title,
                  subtitle: [
                    r.channelName,
                    '${fmt.dayHeader(_utc(r.start))}, '
                        '${fmt.range(_utc(r.start), _utc(r.stop))}',
                    if (names.length > 1 && names[r.playlistId] != null)
                      names[r.playlistId]!,
                  ].join('  ·  '),
                  trailing: KIconButton(
                    icon: PhosphorIconsLight.trash,
                    size: 36,
                    iconSize: 18,
                    tooltip: l10n.delete,
                    onPressed: () async {
                      await ref.read(remindersRepositoryProvider).remove(r.id);
                      toasts.show(l10n.libraryReminderDeleted);
                    },
                  ),
                ),
            ],
          ),
      ],
    );
  }

  static DateTime _utc(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
}

// ---------------------------------------------------------------------------
// Cache
// ---------------------------------------------------------------------------

class CacheSection extends ConsumerWidget {
  const CacheSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final number = NumberFormat.decimalPattern(l10n.localeName);
    final bytes = ref.watch(imageCacheBytesProvider).value;
    final programmes = ref.watch(programmeCountProvider).value;
    final toasts = ref.read(toastControllerProvider);
    final maintenance = ref.read(libraryMaintenanceProvider);

    Future<void> clearImages() async {
      await maintenance.clearImageCache();
      ref.invalidate(imageCacheBytesProvider);
      toasts.show(l10n.libraryImageCacheCleared);
    }

    Future<void> clearProgrammes() async {
      final ok = await showChooser<bool>(
        context,
        title: l10n.libraryClearProgrammesConfirm,
        description: l10n.libraryClearProgrammesHint,
        choices: [KChoice(value: true, label: l10n.libraryClear)],
      );
      if (ok != true) return;
      await maintenance.clearProgrammes();
      toasts.show(l10n.libraryProgrammesCleared);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroupTitle(l10n.libraryGroupImages, first: true),
        SettingsGroup(
          children: [
            SettingsRow(
              key: const ValueKey('row:image-cache'),
              title: l10n.libraryImageCache,
              value: bytes == null ? '…' : libraryBytesLabel(l10n, bytes),
            ),
            SettingsActionRow(
              key: const ValueKey('action:clear-images'),
              title: l10n.libraryClearImageCache,
              icon: PhosphorIconsLight.trash,
              destructive: true,
              onTap: clearImages,
            ),
          ],
        ),
        SettingsGroupTitle(l10n.libraryGroupGuideData),
        SettingsGroup(
          children: [
            SettingsRow(
              key: const ValueKey('row:epg-db'),
              title: l10n.libraryEpgDatabase,
              value: programmes == null
                  ? '…'
                  : l10n.libraryProgrammeCount(
                      programmes,
                      number.format(programmes),
                    ),
            ),
            SettingsActionRow(
              key: const ValueKey('action:clear-programmes'),
              title: l10n.libraryClearProgrammes,
              icon: PhosphorIconsLight.trash,
              destructive: true,
              onTap: clearProgrammes,
            ),
          ],
        ),
        SettingsNote(l10n.libraryCacheNote, center: true),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Diagnostics
// ---------------------------------------------------------------------------

class DiagnosticsSection extends ConsumerWidget {
  const DiagnosticsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final toasts = ref.read(toastControllerProvider);
    final maintenance = ref.read(libraryMaintenanceProvider);
    final launch = ref.read(libraryUriLauncherProvider);

    Future<String> version() async {
      try {
        return await ref.read(libraryAppVersionProvider.future);
      } on Object {
        return '?';
      }
    }

    Future<void> showLogs() async {
      final dir = Directory(ref.read(appPathsProvider).logs);
      try {
        await dir.create(recursive: true);
        if (!await launch(Uri.directory(dir.path))) {
          throw StateError('not opened');
        }
      } on Object catch (e) {
        debugPrint('Diagnostics: opening the logs folder failed: $e');
        toasts.show(l10n.libraryOpenFailed, kind: KToastKind.error);
      }
    }

    Future<void> copy() async {
      final text = await maintenance.diagnostics(version: await version());
      await Clipboard.setData(ClipboardData(text: text));
      toasts.show(l10n.libraryDiagnosticsCopied);
    }

    Future<void> report() async {
      try {
        final file = await maintenance.writeReport(
          version: await version(),
          template: l10n.libraryReportTemplate,
        );
        toasts.show(l10n.libraryReportSaved(file.uri.pathSegments.last));
        if (!await launch(Uri.file(file.path))) {
          throw StateError('not opened');
        }
      } on Object catch (e) {
        debugPrint('Diagnostics: report failed: $e');
        toasts.show(l10n.libraryOpenFailed, kind: KToastKind.error);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroupTitle(l10n.libraryGroupSupport, first: true),
        SettingsGroup(
          children: [
            SettingsActionRow(
              key: const ValueKey('action:logs'),
              title: l10n.libraryShowLogs,
              icon: PhosphorIconsBold.folderOpen,
              onTap: showLogs,
            ),
            SettingsActionRow(
              key: const ValueKey('action:copy-diagnostics'),
              title: l10n.libraryCopyDiagnostics,
              icon: PhosphorIconsBold.copy,
              onTap: copy,
            ),
            SettingsActionRow(
              key: const ValueKey('action:report'),
              title: l10n.libraryReportProblem,
              subtitle: l10n.libraryReportProblemHint,
              icon: PhosphorIconsBold.bug,
              onTap: report,
            ),
          ],
        ),
        SettingsNote(l10n.libraryDiagnosticsNote, center: true),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// About
// ---------------------------------------------------------------------------

class AboutSection extends ConsumerWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final version = ref.watch(libraryAppVersionProvider).value;
    final tmdb = ref.watch(tmdbKeyStoredProvider).value ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 18),
        const Center(child: CarinaMark(size: 76, tile: true)),
        const SizedBox(height: 16),
        const Text(
          'Carina',
          textAlign: TextAlign.center,
          style: KText.largeTitle,
        ),
        const SizedBox(height: 4),
        Text(
          version == null ? '' : l10n.libraryVersion(version),
          key: const ValueKey('about-version'),
          textAlign: TextAlign.center,
          style: KText.caption.copyWith(fontFeatures: KText.tabular),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.libraryAboutTagline,
          textAlign: TextAlign.center,
          style: KText.bodySecondary,
        ),
        SettingsGroupTitle(l10n.libraryGroupLegal),
        SettingsGroup(
          children: [
            SettingsRow(
              key: const ValueKey('row:licenses'),
              title: l10n.libraryLicenses,
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'Carina',
                applicationVersion: version,
                applicationIcon: const Padding(
                  padding: EdgeInsets.all(12),
                  child: CarinaMark(size: 56),
                ),
                useRootNavigator: true,
              ),
            ),
          ],
        ),
        if (tmdb) ...[
          const SettingsGroupTitle('TMDB'),
          SettingsNote(
            l10n.libraryTmdbAttribution,
            center: true,
            color: KColors.textPrimary,
          ),
        ],
      ],
    );
  }
}
