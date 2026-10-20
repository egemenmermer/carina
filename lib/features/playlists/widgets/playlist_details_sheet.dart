import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:carina/app/time_format.dart';
import 'package:carina/core/core.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/net/mask.dart';
import 'package:carina/data/repositories/playlist_repository.dart';
import 'package:carina/features/playlists/data/source_messages.dart';
import 'package:carina/features/playlists/data/wizard_form.dart';
import 'package:carina/l10n/gen/app_localizations.dart';

/// Opens the "Playlist details" sheet (Playlist Manager menu).
Future<void> showPlaylistDetailsSheet(BuildContext context, int playlistId) =>
    showKSheet<void>(
      context,
      width: 760,
      child: PlaylistDetailsSheet(playlistId: playlistId),
    );

/// Playlist details: name and avatar, the section counts in
/// big numbers under red labels, then Source, Account and Updates rows.
/// Credentials stay masked (server via `maskServer`, the username behind
/// an eye toggle).
class PlaylistDetailsSheet extends ConsumerStatefulWidget {
  const PlaylistDetailsSheet({super.key, required this.playlistId});

  final int playlistId;

  @override
  ConsumerState<PlaylistDetailsSheet> createState() =>
      _PlaylistDetailsSheetState();
}

class _PlaylistDetailsSheetState extends ConsumerState<PlaylistDetailsSheet> {
  bool _showUsername = false;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final async = ref.watch(playlistProvider(widget.playlistId));
    final row = async.value;
    if (row == null) {
      return SizedBox(
        height: 320,
        child: async.isLoading
            ? const KLoadingState()
            : KEmptyState(message: l10n.playlistsNotFound),
      );
    }
    final repository = ref.read(playlistRepositoryProvider);
    final fmt = ref.watch(timeFormatProvider);
    final locale = ref.watch(appLocaleCodeProvider);
    final account = row.type == PlaylistType.xtream
        ? repository.account(row)
        : null;
    String count(int n) => formatCount(locale, n);
    String dateTime(DateTime? t) => t == null
        ? l10n.playlistsDetailsNotYet
        : l10n.playlistsDetailsDateTime(fmt.date(t), fmt.time(t));

    final sourceRows = <_DetailRow>[
      _DetailRow(l10n.playlistsDetailsType, playlistTypeLabel(l10n, row.type)),
      if (row.type == PlaylistType.xtream) ...[
        _DetailRow(l10n.playlistsDetailsServer, maskServer(row.server ?? '')),
        _DetailRow(
          l10n.playlistsDetailsUsername,
          _showUsername ? (row.username ?? '') : _maskName(row.username),
          trailing: KIconButton(
            icon: _showUsername
                ? PhosphorIconsLight.eyeSlash
                : PhosphorIconsLight.eye,
            size: 30,
            iconSize: 17,
            background: const Color(0x00000000),
            tooltip: _showUsername
                ? l10n.playlistsHideUsername
                : l10n.playlistsShowUsername,
            onPressed: () => setState(() => _showUsername = !_showUsername),
          ),
        ),
      ],
      if (row.type == PlaylistType.m3u)
        _DetailRow(l10n.playlistsDetailsPlaylistUrl, maskUrl(row.m3uUrl ?? '')),
      if (row.type == PlaylistType.m3uFile)
        _DetailRow(l10n.playlistsDetailsFile, p.basename(row.m3uUrl ?? '')),
      if ((row.userAgent ?? '').isNotEmpty)
        _DetailRow(l10n.playlistsDetailsUserAgent, row.userAgent!),
    ];

    final accountRows = <_DetailRow>[
      if (account != null) ...[
        _DetailRow(
          l10n.playlistsDetailsStatus,
          accountStatusLabel(l10n, account.status),
        ),
        _DetailRow(
          l10n.playlistsDetailsExpires,
          account.expDate == null
              ? l10n.playlistsDetailsNever
              : fmt.date(account.expDate!),
        ),
        if (account.maxConnections != null)
          _DetailRow(
            l10n.playlistsDetailsMaxConnections,
            count(account.maxConnections!),
          ),
        if (account.activeCons != null)
          _DetailRow(
            l10n.playlistsDetailsActiveConnections,
            count(account.activeCons!),
          ),
        if (account.userInfo.isTrial)
          _DetailRow(l10n.playlistsDetailsTrial, l10n.yes),
        if (account.userInfo.createdAt != null)
          _DetailRow(
            l10n.playlistsDetailsCreated,
            fmt.date(account.userInfo.createdAt!),
          ),
      ],
    ];

    final updateRows = <_DetailRow>[
      _DetailRow(l10n.playlistsDetailsLastReload, dateTime(row.lastReloadAt)),
      _DetailRow(
        l10n.playlistsDetailsLastEpgReload,
        dateTime(row.lastEpgReloadAt),
      ),
      _DetailRow(
        l10n.playlistsDetailsReloadFrequency,
        reloadFrequencyLabel(l10n, row.reloadFrequencyHours),
      ),
      _DetailRow(
        l10n.playlistsDetailsEpgShift,
        l10n.playlistsShiftHours(formatEpgShift(row.epgShiftHours)),
      ),
      _DetailRow(l10n.playlistsDetailsGuide, _guideLabel(l10n, row)),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 30, 36, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              KAvatar(row.avatarId, 64, fallbackName: row.name),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RedLabel(l10n.playlistsDetailsTitle),
                    const SizedBox(height: 6),
                    Text(
                      row.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: KText.largeTitle,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (label, value) in [
                (l10n.playlistsDetailsLive, row.liveCount),
                (l10n.playlistsDetailsMovies, row.movieCount),
                (l10n.playlistsDetailsSeries, row.seriesCount),
                (l10n.playlistsDetailsProgrammes, row.programmeCount),
              ])
                Expanded(
                  child: _StatTile(label: label, value: count(value)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _Section(title: l10n.playlistsDetailsSource, rows: sourceRows),
          if (row.type == PlaylistType.xtream)
            _Section(
              title: l10n.playlistsDetailsAccount,
              rows: accountRows,
              empty: l10n.playlistsDetailsNoAccount,
            ),
          _Section(title: l10n.playlistsDetailsUpdates, rows: updateRows),
        ],
      ),
    );
  }

  String _guideLabel(L10n l10n, PlaylistRow row) {
    final stored = row.epgUrl?.trim();
    if (stored != null) {
      return stored.isEmpty
          ? l10n.playlistsDetailsGuideOff
          : l10n.playlistsDetailsGuideCustom;
    }
    if (row.type == PlaylistType.xtream) {
      return l10n.playlistsDetailsGuideProvider;
    }
    final header = ref.read(playlistRepositoryProvider).m3uHeader(row);
    return (header?.tvgUrls.isNotEmpty ?? false)
        ? l10n.playlistsDetailsGuideHeader
        : l10n.playlistsDetailsGuideOff;
  }
}

/// `carina` → `ka•••`: enough to recognize, nothing to copy.
String _maskName(String? name) {
  final value = name ?? '';
  if (value.isEmpty) return '';
  final keep = value.runes.length >= 4 ? 2 : 0;
  return '${String.fromCharCodes(value.runes.take(keep))}•••••';
}

class _DetailRow {
  const _DetailRow(this.label, this.value, {this.trailing});

  final String label;
  final String value;
  final Widget? trailing;
}

class _RedLabel extends StatelessWidget {
  const _RedLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: KText.menuHeader.copyWith(color: KColors.accent),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 2, width: 40, color: KColors.accent),
          const SizedBox(height: 8),
          _RedLabel(label),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            style: KText.largeTitle.copyWith(
              fontSize: 30,
              fontFeatures: KText.tabular,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows, this.empty});

  final String title;
  final List<_DetailRow> rows;
  final String? empty;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RedLabel(title),
          const SizedBox(height: 6),
          if (rows.isEmpty && empty != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(empty!, style: KText.bodySecondary),
            ),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Container(height: 1, color: KColors.stroke),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 36),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      rows[i].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KText.bodySecondary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: Text(
                      rows[i].value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: KText.body.copyWith(
                        fontWeight: FontWeight.w600,
                        fontFeatures: KText.tabular,
                      ),
                    ),
                  ),
                  if (rows[i].trailing != null) ...[
                    const SizedBox(width: 6),
                    rows[i].trailing!,
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
