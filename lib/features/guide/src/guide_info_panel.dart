/// The text block above the guide grid: focused programme
/// title with the preview's "1920x1080" / "25 fps" chips, its time and
/// duration, and the description.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/time_format.dart';
import '../../../core/core.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../player/engine/playback_engine.dart';
import 'guide_actions.dart';
import 'guide_controller.dart';
import 'guide_days.dart';
import 'guide_style.dart';

/// Shows [focus] (title, chips from [stats], time, description). [trailing]
/// sits at the top-right (the Now / day buttons). [emptyHint] replaces the
/// description of "No EPG data" blocks.
class GuideInfoPanel extends ConsumerWidget {
  const GuideInfoPanel({
    super.key,
    required this.focus,
    required this.nowMs,
    this.stats,
    this.trailing,
    this.emptyHint,
  });

  final GuideFocus? focus;
  final int nowMs;
  final EngineStats? stats;
  final Widget? trailing;
  final String? emptyHint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final fmt = ref.watch(timeFormatProvider);
    final f = focus;
    final cell = f?.cell;
    final programme = cell?.programme;
    final title = programme == null
        ? l10n.guideNoEpg
        : (programme.title.trim().isEmpty ? '…' : programme.title);
    final s = stats;
    final chips = <String>[
      if (s != null && s.width > 0 && s.height > 0) '${s.width}x${s.height}',
      if (s != null && s.fps > 0) _fps(s.fps),
    ];
    String? time;
    if (cell != null) {
      final now = DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true);
      final days = calendarDaysBetween(now, cell.start);
      final day = days == 0
          ? ''
          : '${guideDayLabel(l10n, fmt, cell.start, now)} · ';
      time =
          '$day${fmt.range(cell.start, cell.stop)}  '
          '(${l10n.guideDurationMinutes(cellMinutes(cell))})';
    }
    final description =
        programme?.description ??
        programme?.subTitle ??
        (programme == null ? emptyHint : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GuideText.title,
                    ),
                  ),
                  for (final chip in chips) ...[
                    const SizedBox(width: 8),
                    _GuideChip(chip),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 16), trailing!],
          ],
        ),
        if (time != null) ...[
          const SizedBox(height: 6),
          Text(
            time,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GuideText.time,
          ),
        ],
        if (description != null) ...[
          const SizedBox(height: 8),
          Flexible(
            child: Text(
              description,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: GuideText.description,
            ),
          ),
        ],
      ],
    );
  }

  static String _fps(double fps) {
    final rounded = fps.roundToDouble();
    final text = (fps - rounded).abs() < 0.05
        ? rounded.toStringAsFixed(0)
        : fps.toStringAsFixed(2);
    return '$text fps';
  }
}

class _GuideChip extends StatelessWidget {
  const _GuideChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 27,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: KColors.chip,
        borderRadius: BorderRadius.circular(KRadii.chip),
      ),
      child: Text(label, style: GuideText.chip),
    );
  }
}
