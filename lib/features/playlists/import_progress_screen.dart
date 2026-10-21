import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import 'package:carina/app/router.dart';
import 'package:carina/app/time_format.dart';
import 'package:carina/core/core.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/import/import.dart';
import 'package:carina/data/net/mask.dart';
import 'package:carina/data/repositories/playlist_repository.dart';
import 'package:carina/features/playlists/data/playlists_navigation.dart';
import 'package:carina/features/playlists/data/source_messages.dart';
import 'package:carina/features/playlists/playlist_access.dart';
import 'package:carina/features/playlists/widgets/playlist_dialog.dart';
import 'package:carina/features/playlists/widgets/playlists_chrome.dart';
import 'package:carina/l10n/gen/app_localizations.dart';

/// Import progress: a stepper Connecting → Live categories →
/// Live channels (n) → Movies (n) → Series (n) → EPG: Cleaning programs →
/// Downloading → Parsing (n programmes) → Completed, driven by
/// `ImportService.start`. Esc cancels and returns to the Playlist Manager.
///
/// On success the playlist opens (after the "guide could not be loaded" /
/// "imported but section empty" dialogs when they apply); a failure shows
/// the import-error dialog. The scope comes from [scope], else from
/// the location's `?scope=content|epg` (default: everything).
class ImportProgressScreen extends ConsumerStatefulWidget {
  const ImportProgressScreen({super.key, required this.playlistId, this.scope});

  final int playlistId;
  final ImportScope? scope;

  @override
  ConsumerState<ImportProgressScreen> createState() =>
      _ImportProgressScreenState();
}

class _ImportProgressScreenState extends ConsumerState<ImportProgressScreen> {
  StreamSubscription<ImportProgress>? _subscription;
  ImportProgress? _progress;
  ImportScope _scope = ImportScope.all;
  PlaylistRow? _playlist;
  bool _missing = false;
  bool _firstImport = false;
  bool _cancelling = false;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    // Leaving the screen does not stop the import (the shell chip and the
    // Manager keep showing it).
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    if (!mounted) return;
    _scope =
        widget.scope ??
        importScopeFromQuery(
          maybeGoRouterState(context)?.uri.queryParameters['scope'],
        );
    final row = await ref
        .read(playlistRepositoryProvider)
        .get(widget.playlistId);
    if (!mounted) return;
    if (row == null) {
      setState(() => _missing = true);
      return;
    }
    final service = ref.read(importServiceProvider);
    setState(() {
      _playlist = row;
      _firstImport = row.lastReloadAt == null;
      _progress = service.current(widget.playlistId);
    });
    _subscription = service
        .start(widget.playlistId, scope: _scope)
        .listen(_onProgress);
  }

  void _onProgress(ImportProgress progress) {
    if (!mounted) return;
    setState(() {
      _progress = progress;
      // A running import is joined whatever its scope.
      _scope = progress.scope;
    });
    if (progress.done && !_handled) {
      _handled = true;
      unawaited(_finish(progress));
    }
  }

  void _cancel() {
    if (_handled || (_progress?.done ?? false)) return;
    if (_progress == null && _playlist == null) {
      leaveToManager(context);
      return;
    }
    setState(() => _cancelling = true);
    ref.read(importServiceProvider).cancel(widget.playlistId);
  }

  Future<void> _finish(ImportProgress progress) async {
    final l10n = L10n.of(context);
    final toasts = ref.read(toastControllerProvider);
    switch (progress.step) {
      case ImportStep.completed:
        if (progress.epgFailed) {
          await _showResultDialog(
            epgFailureText(
              l10n,
              progress.epgError,
              contentImported: _scope.includesContent,
            ),
            icon: PhosphorIconsLight.calendarX,
          );
        }
        final empty = progress.emptySections;
        if (empty.isNotEmpty && mounted) {
          await _showResultDialog(
            emptySectionsText(l10n, empty),
            icon: PhosphorIconsLight.warningCircle,
          );
        }
        if (!mounted) return;
        toasts.show(
          _firstImport ? l10n.playlistsImportReady : l10n.playlistsImportDone,
        );
        await openPlaylist(context, playlistId: widget.playlistId);
      case ImportStep.failed:
        final text = _scope == ImportScope.epg
            ? epgFailureText(l10n, progress.error, contentImported: false)
            : importFailureText(l10n, progress.error);
        final edit = await showPlaylistDialog<bool>(
          context,
          title: text.title,
          message: text.message,
          note: text.note,
          icon: PhosphorIconsLight.warningCircle,
          iconColor: KButton.destructiveForeground,
          barrierDismissible: false,
          actions: [
            PlaylistDialogAction(label: l10n.ok, value: false),
            PlaylistDialogAction(
              label: l10n.playlistsEditPlaylist,
              value: true,
            ),
          ],
        );
        if (!mounted) return;
        if (edit == true &&
            await ensurePlaylistUnlocked(
              context,
              playlistId: widget.playlistId,
            ) &&
            mounted) {
          GoRouter.of(context).go(Routes.editPlaylist(widget.playlistId));
          return;
        }
        if (mounted) leaveToManager(context);
      case ImportStep.cancelled:
        toasts.show(
          l10n.playlistsImportCancelledToast,
          kind: KToastKind.info,
          icon: PhosphorIconsLight.info,
        );
        leaveToManager(context);
      default:
        break;
    }
  }

  Future<void> _showResultDialog(
    ImportDialogText text, {
    required IconData icon,
  }) async {
    if (!mounted) return;
    await showPlaylistDialog<bool>(
      context,
      title: text.title,
      message: text.message,
      note: text.note,
      icon: icon,
      iconColor: KColors.star,
      barrierDismissible: false,
      actions: [PlaylistDialogAction(label: L10n.of(context).ok, value: true)],
    );
  }

  String _sourceLine(PlaylistRow row) => switch (row.type) {
    PlaylistType.xtream => maskServer(row.server ?? ''),
    PlaylistType.m3u => maskUrl(row.m3uUrl ?? ''),
    PlaylistType.m3uFile => p.basename(row.m3uUrl ?? ''),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final row = _playlist;
    final progress = _progress;
    final fraction = progress?.fraction ?? 0;

    Widget body;
    if (_missing) {
      body = KEmptyState(
        message: l10n.playlistsNotFound,
        actionLabel: l10n.back,
        onAction: () => leaveToManager(context),
      );
    } else if (row == null) {
      body = const KLoadingState();
    } else {
      final title = switch (_scope) {
        ImportScope.epg => l10n.playlistsImportTitleEpg(row.name),
        _ =>
          _firstImport
              ? l10n.playlistsImportTitleNew(row.name)
              : l10n.playlistsImportTitleReload(row.name),
      };
      body = Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: KAvatar(row.avatarId, 72, fallbackName: row.name),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: KText.largeTitle,
                ),
                const SizedBox(height: 6),
                Text(
                  _sourceLine(row),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KText.caption.copyWith(color: KColors.textTertiary),
                ),
                const SizedBox(height: 26),
                Row(
                  children: [
                    Expanded(child: KProgressBar(value: fraction, height: 4)),
                    const SizedBox(width: 14),
                    SizedBox(
                      width: 44,
                      child: Text(
                        '${(fraction * 100).round()}%',
                        textAlign: TextAlign.end,
                        style: KText.chip.copyWith(
                          color: KColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                ImportStepper(progress: progress, scope: _scope),
                const SizedBox(height: 22),
                if (!(progress?.done ?? false))
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _cancelling
                            ? l10n.playlistsImportCancelling
                            : l10n.playlistsImportCancelHint,
                        style: KText.caption,
                      ),
                      const SizedBox(width: 16),
                      KButton.secondary(
                        key: const ValueKey('import-cancel'),
                        label: l10n.cancel,
                        size: KButtonSize.small,
                        onPressed: _cancelling || (progress?.done ?? false)
                            ? null
                            : _cancel,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return PlaylistsWindowFrame(
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): _cancel},
        child: FocusScope(
          autofocus: true,
          child: KTvFocusFirst(
            child: Padding(
              padding: EdgeInsets.only(top: macTitleBarInset() + 56),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: body),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(72, 8, 72, 30),
                    child: CarinaWordmarkFooter(progress: fraction),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The step list of an import: one row per planned step with its status
/// (pending, running, done, failed, cancelled) and count or byte progress.
class ImportStepper extends ConsumerWidget {
  const ImportStepper({super.key, required this.progress, required this.scope});

  /// The latest snapshot (null before the first one).
  final ImportProgress? progress;
  final ImportScope scope;

  List<ImportStep> get _steps {
    final planned = progress?.plannedSteps ?? const <ImportStep>[];
    if (planned.isNotEmpty) return planned;
    return [
      if (scope.includesContent) ...ImportStep.contentSteps,
      if (scope.includesEpg) ...ImportStep.epgSteps,
      ImportStep.completed,
    ];
  }

  ImportStepStatus _status(ImportStep step) {
    final p = progress;
    if (p == null || p.plannedSteps.isEmpty) {
      return step == ImportStep.connecting && p != null
          ? ImportStepStatus.active
          : ImportStepStatus.pending;
    }
    return p.statusOf(step);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final locale = ref.watch(appLocaleCodeProvider);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      decoration: BoxDecoration(
        color: KColors.surface1,
        borderRadius: KRadii.panelBorder,
        border: Border.all(color: KColors.stroke),
      ),
      child: Column(
        children: [
          for (final step in _steps)
            _StepRow(
              key: ValueKey('import-step-${step.name}'),
              label: importStepLabel(l10n, step),
              status: _status(step),
              detail: _detail(l10n, locale, step, _status(step)),
            ),
        ],
      ),
    );
  }

  String? _detail(
    L10n l10n,
    String locale,
    ImportStep step,
    ImportStepStatus status,
  ) {
    final p = progress;
    if (p == null) return null;
    if (status == ImportStepStatus.failed) {
      return step.isEpg && p.step == ImportStep.completed
          ? l10n.playlistsImportGuideFailed
          : l10n.playlistsImportFailed;
    }
    if (status == ImportStepStatus.cancelled) {
      return l10n.playlistsImportCancelledStep;
    }
    final count = p.countOf(step);
    final bytes = status == ImportStepStatus.active && p.step == step
        ? p.receivedBytes
        : null;
    switch (step) {
      case ImportStep.connecting || ImportStep.epgDownloading:
        if (bytes == null) return null;
        final total = p.totalBytes;
        return total == null
            ? formatBytes(locale, bytes)
            : l10n.playlistsImportBytesOf(
                formatBytes(locale, bytes),
                formatBytes(locale, total),
              );
      case ImportStep.epgCleaning:
        return count == null || count == 0
            ? null
            : l10n.playlistsImportRemoved(formatCount(locale, count));
      case ImportStep.epgParsing:
        return count == null
            ? null
            : l10n.playlistsImportProgrammes(formatCount(locale, count));
      case ImportStep.liveCategories ||
          ImportStep.liveChannels ||
          ImportStep.movies ||
          ImportStep.series:
        return count == null ? null : formatCount(locale, count);
      default:
        return null;
    }
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    super.key,
    required this.label,
    required this.status,
    this.detail,
  });

  final String label;
  final ImportStepStatus status;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final Widget icon = switch (status) {
      ImportStepStatus.pending => Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: KColors.strokeStrong, width: 1.5),
        ),
      ),
      ImportStepStatus.active => const KSpinner(size: 18, strokeWidth: 2),
      ImportStepStatus.done => const Icon(
        PhosphorIconsFill.checkCircle,
        size: 21,
        color: KColors.success,
      ),
      ImportStepStatus.failed => const Icon(
        PhosphorIconsFill.xCircle,
        size: 21,
        color: KButton.destructiveForeground,
      ),
      ImportStepStatus.cancelled => const Icon(
        PhosphorIconsFill.minusCircle,
        size: 21,
        color: KColors.textTertiary,
      ),
      ImportStepStatus.skipped => const Icon(
        PhosphorIconsLight.minus,
        size: 16,
        color: KColors.textTertiary,
      ),
    };
    final labelStyle = switch (status) {
      ImportStepStatus.active => KText.body.copyWith(
        fontWeight: FontWeight.w700,
      ),
      ImportStepStatus.done => KText.body.copyWith(fontWeight: FontWeight.w500),
      ImportStepStatus.failed => KText.body.copyWith(
        fontWeight: FontWeight.w600,
        color: KButton.destructiveForeground,
      ),
      _ => KText.body.copyWith(color: KColors.textTertiary),
    };
    return Semantics(
      liveRegion: status == ImportStepStatus.active,
      child: SizedBox(
        height: 42,
        child: Row(
          children: [
            SizedBox(width: 24, child: Center(child: icon)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: labelStyle,
              ),
            ),
            if (detail != null) ...[
              const SizedBox(width: 12),
              Text(
                detail!,
                style: KText.time.copyWith(
                  fontSize: 14,
                  color: status == ImportStepStatus.failed
                      ? KButton.destructiveForeground
                      : status == ImportStepStatus.active
                      ? KColors.textPrimary
                      : KColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
