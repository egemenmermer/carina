import 'package:flutter/material.dart';

import 'package:carina/core/strings.dart';
import 'package:carina/core/tokens.dart';

/// Outlined quality badge (SD / HD / FHD / 4K / H265 / 50FPS): 1 px secondary
/// stroke, radius 4, 11/600.
class KBadge extends StatelessWidget {
  const KBadge(this.label, {super.key, this.color = KColors.textSecondary});

  final String label;

  /// Stroke and text color.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 1, 4, 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KRadii.badge),
        border: Border.all(color: color),
      ),
      child: Text(label, style: KText.badge.copyWith(color: color)),
    );
  }
}

enum _NewKind { movie, show, episodes }

/// Red filled "NEW MOVIE" / "NEW SHOW" / "NEW EPISODES" badge, centered at the
/// bottom of recently added posters.
class KNewBadge extends StatelessWidget {
  /// Custom label.
  const KNewBadge({super.key, required String this.label}) : _kind = null;

  /// Localized "NEW MOVIE".
  const KNewBadge.movie({super.key}) : label = null, _kind = _NewKind.movie;

  /// Localized "NEW SHOW".
  const KNewBadge.show({super.key}) : label = null, _kind = _NewKind.show;

  /// Localized "NEW EPISODES".
  const KNewBadge.episodes({super.key})
    : label = null,
      _kind = _NewKind.episodes;

  final String? label;
  final _NewKind? _kind;

  @override
  Widget build(BuildContext context) {
    final strings = KStrings.of(context);
    final text =
        label ??
        switch (_kind!) {
          _NewKind.movie => strings.newMovie,
          _NewKind.show => strings.newShow,
          _NewKind.episodes => strings.newEpisodes,
        };
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 2, 6, 2),
      decoration: BoxDecoration(
        color: KColors.accent,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        maxLines: 1,
        style: KText.badge.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Red "● LIVE" pill (live preview and live player overlays).
class KLivePill extends StatelessWidget {
  const KLivePill({super.key, this.large = false, this.label});

  /// 34 px tall with 15 pt text (player overlay) instead of 24 px / 12 pt.
  final bool large;

  /// Overrides the localized "LIVE".
  final String? label;

  @override
  Widget build(BuildContext context) {
    final text = label ?? KStrings.of(context).live;
    final dot = large ? 11.0 : 8.0;
    return Container(
      height: large ? 34 : 24,
      padding: EdgeInsets.symmetric(horizontal: large ? 12 : 8),
      decoration: BoxDecoration(
        color: KColors.accent,
        borderRadius: BorderRadius.circular(large ? 7 : 5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: dot,
            height: dot,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: large ? 7 : 5),
          Text(
            text,
            style: (large ? KText.button : KText.buttonSmall).copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: large ? 16 : 12,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dark chip with tabular text ("1920x1080", "25 fps", "HD").
///
/// [overlay] uses a translucent black fill for chips drawn over video.
class KChip extends StatelessWidget {
  const KChip(
    this.label, {
    super.key,
    this.overlay = false,
    this.large = false,
    this.icon,
  });

  final String label;
  final bool overlay;

  /// 34 px tall with 16 pt text (player overlay) instead of 22 px / 13 pt.
  final bool large;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final style = KText.chip.copyWith(fontSize: large ? 16 : 13);
    return Container(
      height: large ? 34 : 22,
      padding: EdgeInsets.symmetric(horizontal: large ? 12 : 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: overlay ? KColors.overlay : KColors.chip,
        borderRadius: BorderRadius.circular(large ? 7 : KRadii.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: (style.fontSize ?? 13) + 1, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Text(label, style: style),
        ],
      ),
    );
  }
}

/// Age-rating tab for the right edge of a hero (red left bar, dark
/// translucent body, white bold text, e.g. "PG-13"), as in the Apple TV
/// reference. Place it flush with the right edge.
class KAgeTab extends StatelessWidget {
  const KAgeTab(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 7,
            decoration: const BoxDecoration(
              color: KColors.accent,
              borderRadius: BorderRadius.horizontal(left: Radius.circular(3)),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 9, 22, 9),
            color: const Color(0xB3161616),
            child: Text(
              label,
              style: KText.title.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small status chip for the top bar ("Updating 45%" during a background
/// reload): pill with a thin progress ring and a label.
class KProgressChip extends StatelessWidget {
  const KProgressChip({super.key, required this.label, this.progress});

  final String label;

  /// 0..1, or null for an indeterminate ring.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: KColors.surface2,
        borderRadius: KRadii.pillBorder,
        border: Border.all(color: KColors.stroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 14,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 2,
              color: KColors.accent,
              backgroundColor: KColors.glass,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: KText.buttonSmall.copyWith(
                color: KColors.textSecondary,
                fontFeatures: KText.tabular,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
