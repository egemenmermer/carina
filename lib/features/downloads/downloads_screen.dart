import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/core.dart';
import '../../l10n/gen/app_localizations.dart';
import '../settings/widgets/standalone_page.dart';

/// Tabs of the Downloads page.
enum DownloadsTab { downloads, recordings }

/// The global Downloads page. For now it is the page shell: Downloads /
/// Recordings tabs with their empty states. Downloading and recording are not
/// built yet, so no items are listed.
class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key, this.initialTab = DownloadsTab.downloads});

  final DownloadsTab initialTab;

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  late DownloadsTab _tab = widget.initialTab;

  void _back() {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go(Routes.manager);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final empty = switch (_tab) {
      DownloadsTab.downloads => KEmptyState(
        key: const ValueKey('downloads-empty'),
        icon: PhosphorIconsLight.downloadSimple,
        title: l10n.libraryDownloadsEmptyTitle,
        message: l10n.libraryDownloadsEmptyMessage,
      ),
      DownloadsTab.recordings => KEmptyState(
        key: const ValueKey('recordings-empty'),
        icon: PhosphorIconsLight.record,
        title: l10n.libraryRecordingsEmptyTitle,
        message: l10n.libraryRecordingsEmptyMessage,
      ),
    };
    return LibraryStandalonePage(
      title: l10n.libraryDownloadsTitle,
      onBack: _back,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 20, 32, 0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: LibraryBackButton(
                    label: l10n.libraryBackToPlaylists,
                    onPressed: _back,
                  ),
                ),
                KSegmented<DownloadsTab>(
                  segments: [
                    KSegment(
                      value: DownloadsTab.downloads,
                      label: l10n.libraryDownloadsTab,
                      icon: PhosphorIconsLight.downloadSimple,
                    ),
                    KSegment(
                      value: DownloadsTab.recordings,
                      label: l10n.libraryRecordingsTab,
                      icon: PhosphorIconsLight.record,
                    ),
                  ],
                  value: _tab,
                  onChanged: (tab) => setState(() => _tab = tab),
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: KMotion.of(context, KDurations.hover),
              child: empty,
            ),
          ),
        ],
      ),
    );
  }
}
