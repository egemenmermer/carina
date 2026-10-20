import 'package:flutter/material.dart';

import '../../../app/time_format.dart';
import '../../../core/core.dart';
import '../../../data/repositories/repository_models.dart';
import '../../../l10n/gen/app_localizations.dart';

/// NOW ON AIR: red-bar header, the
/// programme title (28/700), a 4-line description with "EPG by …", the
/// Time / Duration / Recording tiles, and CHANNEL FUNCTIONS (TV Archive,
/// Parental).
class NowOnAirPanel extends StatelessWidget {
  const NowOnAirPanel({
    super.key,
    required this.channel,
    required this.programme,
    required this.format,
    this.epgSource,
  });

  /// The selected channel (null while the list is empty).
  final ChannelView? channel;

  /// The programme on air, or null without guide data.
  final ProgrammeView? programme;
  final CarinaTimeFormat format;

  /// Host the guide comes from (`epg-guide.com`), or null.
  final String? epgSource;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final description = _description(l10n);
    return KPanel(
      padding: const EdgeInsets.fromLTRB(20, 18, 18, 16),
      child: LayoutBuilder(
        builder: (context, constraints) =>
            _content(context, l10n, description, constraints.maxWidth),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    L10n l10n,
    String description,
    double width,
  ) {
    final c = channel;
    final p = programme;
    // Narrow panels (small windows) drop the Recording tile (P2) so the
    // others stay legible.
    final showRecording = width >= 400;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelHeader(l10n.liveNowOnAir),
        const SizedBox(height: 12),
        Text(
          p?.title ?? c?.displayName ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: KText.largeTitle,
        ),
        const SizedBox(height: 6),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final style = KText.caption.copyWith(
                fontSize: 13.5,
                height: 1.35,
                letterSpacing: -0.06,
                color: KColors.textSecondary,
              );
              final lineHeight = style.fontSize! * style.height!;
              final lines = (constraints.maxHeight / lineHeight).floor().clamp(
                0,
                4,
              );
              if (lines == 0) return const SizedBox.shrink();
              return Text(
                description,
                maxLines: lines,
                overflow: TextOverflow.ellipsis,
                style: p == null || p.description == null
                    ? style.copyWith(color: KColors.textTertiary)
                    : style,
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              flex: 6,
              child: _InfoTile(
                icon: PhosphorIconsLight.clock,
                label: l10n.liveTime,
                value: p == null ? '–' : format.range(p.start, p.stop),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: _InfoTile(
                icon: PhosphorIconsLight.hourglassMedium,
                label: l10n.liveDuration,
                value: p == null ? '–' : l10n.liveMinutes(p.duration.inMinutes),
              ),
            ),
            if (showRecording) ...[
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: _InfoTile(
                  icon: PhosphorIconsLight.record,
                  label: l10n.liveRecording,
                  value: l10n.liveNotActive,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        PanelHeader(l10n.liveChannelFunctions, showBar: false),
        const SizedBox(height: 7),
        Row(
          children: [
            Expanded(
              flex: 6,
              child: _InfoTile(
                icon: PhosphorIconsLight.clockCounterClockwise,
                iconColor: c != null && c.hasArchive
                    ? KColors.textPrimary
                    : KColors.textTertiary,
                label: l10n.liveTvArchive,
                value: c != null && c.hasArchive
                    ? l10n.liveArchiveDays(c.archiveDays)
                    : l10n.liveNotAvailable,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: _InfoTile(
                icon: c != null && c.locked
                    ? PhosphorIconsLight.lockSimple
                    : PhosphorIconsLight.lockSimpleOpen,
                iconColor: c != null && c.locked
                    ? KColors.success
                    : KColors.textPrimary,
                label: l10n.liveParental,
                value: c != null && c.locked
                    ? l10n.liveActive
                    : l10n.liveInactive,
              ),
            ),
            if (showRecording) ...[
              const SizedBox(width: 8),
              const Spacer(flex: 4),
            ],
          ],
        ),
      ],
    );
  }

  String _description(L10n l10n) {
    final p = programme;
    if (p == null) return l10n.liveNoProgrammeInfo;
    final text = p.description ?? p.subTitle;
    final source = epgSource;
    if (text == null) {
      return source == null
          ? l10n.liveNoDescription
          : '${l10n.liveNoDescription} – ${l10n.liveEpgBy(source)}';
    }
    return source == null ? text : '$text – ${l10n.liveEpgBy(source)}';
  }
}

/// Info tile (icon, grey label, white value) sized for the 1440 px window:
/// the value scales down instead of being cut ("11:20 AM – 12:20 PM").
class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor = KColors.textPrimary,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: KColors.tile,
        borderRadius: BorderRadius.circular(KRadii.tile),
        border: Border.all(color: KColors.stroke),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: KText.caption.copyWith(fontSize: 12.5),
                  ),
                ),
                const SizedBox(height: 1),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: KText.time.copyWith(
                      color: KColors.textPrimary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
