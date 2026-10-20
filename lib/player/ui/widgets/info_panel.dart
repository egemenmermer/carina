import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../../../l10n/gen/app_localizations.dart';

/// The panel that slides up from the bottom (Down / ⓘ): artwork, title,
/// overview, technical chips (`8m` `HD` `stereo` `H.264`) and action
/// buttons at the right ("From the beginning", "Next episode", "Open TV
/// Guide"). Shows "↑ for options" above it.
class PlayerInfoPanel extends StatelessWidget {
  const PlayerInfoPanel({
    super.key,
    required this.title,
    required this.actions,
    this.overview,
    this.image,
    this.imageFallback,
    this.lead,
    this.chips = const [],
  });

  final String title;
  final String? overview;
  final String? image;

  /// Shown instead of [image] when it is missing (live: the logo tile).
  final Widget? imageFallback;

  /// Plain text before the chips (the runtime: `8m`).
  final String? lead;
  final List<String> chips;

  /// Pill buttons, top to bottom (the first one gets the focus).
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Column(
      key: const ValueKey('player-info-panel'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.playerOptionsHint,
          style: KText.caption.copyWith(color: KColors.textSecondary),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xF0101012),
            borderRadius: KRadii.panelBorder,
            border: Border.all(color: KColors.stroke),
            boxShadow: KShadows.menu,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: KRadii.posterBorder,
                child: SizedBox(
                  width: 256,
                  height: 144,
                  child: image == null && imageFallback != null
                      ? imageFallback
                      : KImage(
                          image,
                          placeholder: const ColoredBox(
                            color: KColors.surface2,
                          ),
                          errorBuilder: imageFallback == null
                              ? null
                              : (_) => imageFallback!,
                        ),
                ),
              ),
              const SizedBox(width: 22),
              Expanded(
                child: SizedBox(
                  height: 144,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KText.title.copyWith(fontSize: 22),
                      ),
                      const SizedBox(height: 6),
                      if (overview != null)
                        Expanded(
                          child: Text(
                            overview!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: KText.bodySecondary,
                          ),
                        )
                      else
                        const Spacer(),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (lead != null) ...[
                            Text(
                              lead!,
                              style: KText.button.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          for (final chip in chips) ...[
                            _LightChip(chip),
                            const SizedBox(width: 6),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 22),
              FocusTraversalGroup(
                child: IntrinsicWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(height: 10),
                        actions[i],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Light chip (`HD`, `stereo`) as in the info panel.
class _LightChip extends StatelessWidget {
  const _LightChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xE6FFFFFF),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: KText.badge.copyWith(
          color: Colors.black,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
