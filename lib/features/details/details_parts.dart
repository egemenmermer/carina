import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../l10n/gen/app_localizations.dart';
import '../home_movies/data/vod_meta.dart';
import '../home_movies/widgets/vod_art.dart';
import '../home_movies/widgets/vod_hero.dart';
import '../search/search_api.dart';

/// Width of the detail sheets.
const double kDetailsSheetWidth = 880;

/// Horizontal padding of the sheet text.
const double kDetailsPadding = 36;

/// The sheet's top artwork (2:1): backdrop → blurred poster → text
/// poster, a fade into the sheet, a big ring play button in the middle and
/// an optional [overlay] at the bottom (Continue watching + progress).
class DetailsBackdrop extends StatelessWidget {
  const DetailsBackdrop({
    super.key,
    required this.meta,
    required this.onPlay,
    required this.playLabel,
    this.overlay,
  });

  final VodMeta meta;
  final VoidCallback? onPlay;
  final String playLabel;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2,
      child: Stack(
        fit: StackFit.expand,
        children: [
          VodArt(
            url: meta.backdropUrl,
            blurUrl: meta.posterUrl,
            title: meta.title,
            year: meta.year,
            wide: true,
            alignment: const Alignment(0, -0.3),
          ),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.5, 0.82, 1],
                  colors: [
                    Color(0x33000000),
                    Color(0x00000000),
                    Color(0x99000000),
                    Color(0xFF000000),
                  ],
                ),
              ),
            ),
          ),
          if (onPlay != null)
            Center(
              child: KInteractive(
                onTap: onPlay,
                semanticLabel: playLabel,
                builder: (context, state, _) => AnimatedScale(
                  scale: state.pressed
                      ? 0.96
                      : state.highlighted
                      ? 1.08
                      : 1,
                  duration: KMotion.of(context, KDurations.hover),
                  curve: KMotion.hover,
                  child: KFocusRing(
                    visible: state.focused,
                    circle: true,
                    child: VodPlayRing(size: 84, highlighted: state.hovered),
                  ),
                ),
              ),
            ),
          if (overlay != null)
            Positioned(left: 28, right: 28, bottom: 18, child: overlay!),
        ],
      ),
    );
  }
}

/// "Continue watching / Breaking Bad S1 E5: "Title"" + red progress bar at
/// the bottom of the sheet artwork.
class DetailsContinueOverlay extends StatelessWidget {
  const DetailsContinueOverlay({
    super.key,
    required this.heading,
    required this.label,
    required this.progress,
  });

  final String heading;
  final String label;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    const shadow = [Shadow(color: Color(0xB3000000), blurRadius: 10)];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(heading, style: KText.channelName.copyWith(shadows: shadow)),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: KText.body.copyWith(
            color: const Color(0xFFE8E8E8),
            shadows: shadow,
          ),
        ),
        if (progress != null) ...[
          const SizedBox(height: 12),
          KProgressBar(value: progress!, height: 4),
        ],
      ],
    );
  }
}

/// Centered title (logo art when TMDb has one).
class DetailsTitle extends StatelessWidget {
  const DetailsTitle({super.key, required this.meta, required this.title});

  final VodMeta meta;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        kDetailsPadding,
        4,
        kDetailsPadding,
        0,
      ),
      child: Center(
        child: VodTitleArt(
          title: title,
          logoUrl: meta.logoUrl,
          maxLogoHeight: 110,
          maxLogoWidth: 420,
          maxLines: 2,
          textAlign: TextAlign.center,
          alignment: Alignment.center,
          style: KText.heroTitle.copyWith(fontSize: 40, letterSpacing: -0.9),
        ),
      ),
    );
  }
}

/// Outlined age rating (`TV-MA`, `16+`) next to the rating.
class DetailsAgeBadge extends StatelessWidget {
  const DetailsAgeBadge(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 1, 5, 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KRadii.badge),
        border: Border.all(color: KColors.textSecondary, width: 1.2),
      ),
      child: Text(
        label,
        style: KText.label.copyWith(
          fontSize: 14,
          color: KColors.textSecondary,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// `Cast: A, B, C` — the names open the person search ([onPerson]).
class DetailsPeopleLine extends StatelessWidget {
  const DetailsPeopleLine({
    super.key,
    required this.label,
    required this.names,
    required this.onPerson,
  });

  final String label;
  final List<String> names;
  final ValueChanged<String>? onPerson;

  @override
  Widget build(BuildContext context) {
    final style = KText.bodySecondary;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('$label ', style: style),
        for (var i = 0; i < names.length; i++)
          _PersonLink(
            name: names[i],
            suffix: i == names.length - 1 ? '' : ', ',
            style: style,
            onTap: onPerson == null ? null : () => onPerson!(names[i]),
          ),
      ],
    );
  }
}

class _PersonLink extends StatelessWidget {
  const _PersonLink({
    required this.name,
    required this.suffix,
    required this.style,
    required this.onTap,
  });

  final String name;
  final String suffix;
  final TextStyle style;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        KInteractive(
          onTap: onTap,
          semanticLabel: name,
          builder: (context, state, _) => KFocusRing(
            visible: state.focused,
            borderRadius: 3,
            gap: 1,
            child: Text(
              name,
              style: style.copyWith(
                color: state.highlighted ? Colors.white : style.color,
                decoration: state.hovered
                    ? TextDecoration.underline
                    : TextDecoration.none,
                decorationColor: Colors.white,
              ),
            ),
          ),
        ),
        if (suffix.isNotEmpty) Text(suffix, style: style),
      ],
    );
  }
}

/// `Genres: Drama, Crime` (secondary text).
class DetailsInfoLine extends StatelessWidget {
  const DetailsInfoLine({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label $value',
      style: KText.bodySecondary,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Small grey notice (cached details shown because the provider failed).
class DetailsNotice extends StatelessWidget {
  const DetailsNotice({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          PhosphorIconsLight.cloudSlash,
          size: 16,
          color: KColors.textTertiary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: KText.caption.copyWith(color: KColors.textTertiary),
          ),
        ),
      ],
    );
  }
}

/// Opens the person search for [person] after closing the sheet.
void openPersonFromSheet(
  BuildContext context, {
  required int playlistId,
  required String person,
}) {
  final navigator = Navigator.of(context);
  final outer = navigator.context;
  navigator.pop();
  openPersonSearch(outer, playlistId: playlistId, person: person);
}

/// Labels shared by the sheets.
extension DetailsL10n on L10n {
  String seasonLabel(int number) =>
      number == 0 ? vodSpecialContents : vodSeasonTab(number);
}
