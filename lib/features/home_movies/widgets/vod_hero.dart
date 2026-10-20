import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/time_format.dart';
import '../../../core/core.dart';
import '../../../data/db/database.dart';
import '../../../data/repositories/vod_repository.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../data/vod_providers.dart';
import 'vod_actions.dart';
import 'vod_art.dart';

/// Which item the Movies / Shows hero shows.
///
/// The hero rotates through [candidates] every [interval] (10 s). Hovering
/// or focusing a row card calls [preview], which shows that card after a
/// short dwell ([previewDelay]) and restarts the interval. Rotation pauses
/// while the hero is [hold]-ed (pointer or focus on its buttons), while
/// [canRotate] says no (the screen is covered or off-stage), and entirely
/// when [autoRotate] is off (reduce motion).
class VodHeroController extends ChangeNotifier {
  VodHeroController({
    this.interval = const Duration(seconds: 10),
    this.previewDelay = const Duration(milliseconds: 220),
  });

  final Duration interval;
  final Duration previewDelay;

  /// Extra condition checked before each automatic step.
  bool Function()? canRotate;

  List<VodItem> _candidates = const [];
  VodItem? _current;
  int _index = -1;
  int _holds = 0;
  bool _autoRotate = true;
  Timer? _rotation;
  Timer? _preview;
  bool _disposed = false;

  VodItem? get current => _current;
  List<VodItem> get candidates => _candidates;
  bool get isHeld => _holds > 0;

  bool get autoRotate => _autoRotate;
  set autoRotate(bool value) {
    if (_autoRotate == value) return;
    _autoRotate = value;
    _schedule();
  }

  /// Sets the rotation list. Keeps the current item when it is still
  /// listed (or was picked by hovering); otherwise starts at the first.
  void setCandidates(List<VodItem> items) {
    if (_sameIds(items, _candidates)) {
      _candidates = items;
      return;
    }
    _candidates = items;
    final at = _current == null ? -1 : _indexOf(_current!);
    if (at >= 0) {
      _index = at;
    } else if (_current == null && items.isNotEmpty) {
      _index = 0;
      _current = items.first;
      notifyListeners();
    }
    _schedule();
  }

  /// Shows [item] when nothing else is shown yet (e.g. no candidates).
  void showIfEmpty(VodItem item) {
    if (_current != null) return;
    _current = item;
    notifyListeners();
  }

  /// Shows [item] after the dwell delay (hover / focus on a card).
  void preview(VodItem item, {bool immediate = false}) {
    _preview?.cancel();
    if (immediate || previewDelay == Duration.zero) {
      _show(item);
      return;
    }
    _preview = Timer(previewDelay, () => _show(item));
  }

  /// Cancels a pending [preview].
  void cancelPreview() => _preview?.cancel();

  /// Pauses rotation until [release].
  void hold() => _holds++;

  void release() {
    if (_holds > 0) _holds--;
  }

  /// Advances to the next candidate.
  void next() {
    if (_candidates.isEmpty) return;
    final at = _current == null ? -1 : _indexOf(_current!);
    _index = ((at >= 0 ? at : _index) + 1) % _candidates.length;
    _current = _candidates[_index];
    notifyListeners();
    _schedule();
  }

  void _show(VodItem item) {
    if (_disposed) return;
    final current = _current;
    if (current != null &&
        current.providerId == item.providerId &&
        current.kind == item.kind) {
      _current = item;
      _schedule();
      return;
    }
    _current = item;
    notifyListeners();
    _schedule();
  }

  void _schedule() {
    _rotation?.cancel();
    _rotation = null;
    if (_disposed || !_autoRotate || _candidates.length < 2) return;
    _rotation = Timer(interval, _tick);
  }

  void _tick() {
    if (_disposed) return;
    if (_holds > 0 || !(canRotate?.call() ?? true)) {
      _schedule();
      return;
    }
    next();
  }

  int _indexOf(VodItem item) => _candidates.indexWhere(
    (c) => c.providerId == item.providerId && c.kind == item.kind,
  );

  static bool _sameIds(List<VodItem> a, List<VodItem> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].providerId != b[i].providerId) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _disposed = true;
    _rotation?.cancel();
    _preview?.cancel();
    super.dispose();
  }
}

/// Full-bleed hero artwork behind the home rows: provider backdrop → TMDb
/// backdrop → the poster scaled and blurred, under a left-to-right black
/// gradient (85% → 0%), a top fade into the navigation bar and a bottom
/// fade into the page. Crossfades over 400 ms when the item changes.
class VodHeroBackdrop extends ConsumerWidget {
  const VodHeroBackdrop({
    super.key,
    required this.controller,
    required this.playlistId,
  });

  final VodHeroController controller;
  final int playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final item = controller.current;
        Widget art = const SizedBox.expand(key: ValueKey('none'));
        if (item != null) {
          art = _HeroArt(
            key: ValueKey('${item.kind.name}:${item.providerId}'),
            playlistId: playlistId,
            item: item,
          );
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            AnimatedSwitcher(
              duration: KMotion.of(context, KDurations.heroCrossfade),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              layoutBuilder: (current, previous) => Stack(
                fit: StackFit.expand,
                children: [...previous, ?current],
              ),
              child: art,
            ),
            const IgnorePointer(child: _HeroScrims()),
          ],
        );
      },
    );
  }
}

class _HeroArt extends ConsumerWidget {
  const _HeroArt({super.key, required this.playlistId, required this.item});

  final int playlistId;
  final VodItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = ref.watch(
      vodMetaProvider((
        playlistId: playlistId,
        kind: item.kind,
        providerId: item.providerId,
      )),
    );
    final backdrop = meta?.backdropUrl ?? item.backdrop;
    final poster = meta?.posterUrl ?? item.poster;
    final Widget art;
    if (backdrop != null) {
      art = KImage(
        backdrop,
        alignment: const Alignment(0.2, -0.3),
        fadeDuration: KDurations.heroCrossfade,
        placeholder: const ColoredBox(color: KColors.bg),
        errorBuilder: (_) => poster == null
            ? const ColoredBox(color: KColors.bg)
            : VodBlurredArt(url: poster, sigma: 30, dim: 0.2),
      );
    } else if (poster != null) {
      art = VodBlurredArt(url: poster, sigma: 30, dim: 0.2);
    } else {
      art = VodTextPoster(title: '', year: null, wide: true);
    }
    return SizedBox.expand(child: art);
  }
}

class _HeroScrims extends StatelessWidget {
  const _HeroScrims();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        // Left-to-right: 85% black behind the text → clear.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [0, 0.32, 0.72],
              colors: [Color(0xD9000000), Color(0x99000000), Color(0x00000000)],
            ),
          ),
        ),
        // Top: blend into the black navigation bar.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, 0.16],
              colors: [Color(0xB3000000), Color(0x00000000)],
            ),
          ),
        ),
        // Bottom: fade into the page.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.42, 0.78, 1],
              colors: [Color(0x00000000), Color(0xB3000000), Color(0xFF000000)],
            ),
          ),
        ),
      ],
    );
  }
}

/// Key of the hero text block showing [providerId] (tests, analytics).
ValueKey<String> vodHeroKey(SectionKind kind, String providerId) =>
    ValueKey('vod-hero:${kind.name}:$providerId');

/// The hero text block (Apple TV layout): logo art or a 56/800 title,
/// `GENRE • GENRE | Cast, Cast | 1h 49m | 2025` (shows: `3 seasons (21
/// episodes)`), the rating, tagline + overview (3 lines), the iPad buttons
/// row (☆ Favorites · ▶ Play · ⓘ Info) and the age tab on the right edge.
class VodHeroContent extends ConsumerWidget {
  const VodHeroContent({
    super.key,
    required this.controller,
    required this.playlistId,
    required this.kind,
  });

  final VodHeroController controller;
  final int playlistId;
  final SectionKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MouseRegion(
      onEnter: (_) => controller.hold(),
      onExit: (_) => controller.release(),
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (focused) =>
            focused ? controller.hold() : controller.release(),
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final item = controller.current;
            return AnimatedSwitcher(
              duration: KMotion.of(context, KDurations.heroCrossfade),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              layoutBuilder: (current, previous) => Stack(
                fit: StackFit.expand,
                children: [...previous, ?current],
              ),
              child: item == null
                  ? const SizedBox.expand(key: ValueKey('none'))
                  : _HeroDetails(
                      key: vodHeroKey(item.kind, item.providerId),
                      playlistId: playlistId,
                      item: item,
                    ),
            );
          },
        ),
      ),
    );
  }
}

class _HeroDetails extends ConsumerWidget {
  const _HeroDetails({super.key, required this.playlistId, required this.item});

  final int playlistId;
  final VodItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final key = (
      playlistId: playlistId,
      kind: item.kind,
      providerId: item.providerId,
    );
    final meta = ref.watch(vodMetaProvider(key)) ?? buildVodMeta(item: item);
    final live = ref.watch(vodItemProvider(key)).value ?? item;
    final fmt = ref.watch(timeFormatProvider);
    final locale = Localizations.localeOf(context).languageCode;
    final title = meta.title.isEmpty ? l10n.vodUntitled : meta.title;

    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth;
        final textWidth = math.min(width * 0.56, 820.0);
        final overviewWidth = math.min(width * 0.46, 660.0);
        final metaLine = vodMetaLine(l10n, meta, fmt, locale);
        final age = meta.ageRating;
        final hasAge = age != null && age.isNotEmpty;
        // The age tab sits on the right edge, level with the rating (or
        // the metadata line when there is no rating), as on Apple TV.
        Widget line(Widget text, {required bool withAge}) => Row(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: textWidth),
              child: text,
            ),
            const Spacer(),
            if (withAge) KAgeTab(age!),
          ],
        );
        final ageOnRating = hasAge && meta.hasRating;
        final ageOnMeta = hasAge && !meta.hasRating && metaLine.isNotEmpty;
        final column = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: textWidth),
              child: VodTitleArt(
                title: title,
                logoUrl: meta.logoUrl,
                maxLogoHeight: 128,
                maxLogoWidth: math.min(textWidth, 520),
                style: KText.heroTitle,
                maxLines: 2,
              ),
            ),
            if (metaLine.isNotEmpty) ...[
              SizedBox(height: ageOnMeta ? 6 : 14),
              line(
                Text(
                  metaLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KText.heroMeta,
                ),
                withAge: ageOnMeta,
              ),
            ],
            if (meta.hasRating) ...[
              SizedBox(height: ageOnRating ? 2 : 10),
              line(
                VodRatingLine(meta: meta, style: KText.heroMeta),
                withAge: ageOnRating,
              ),
            ],
            if (meta.tagline != null || meta.overview != null) ...[
              SizedBox(height: ageOnRating ? 8 : 16),
              SizedBox(
                width: overviewWidth,
                child: _Overview(
                  tagline: meta.tagline,
                  overview: meta.overview,
                ),
              ),
            ],
            const SizedBox(height: 22),
            _HeroButtons(playlistId: playlistId, item: live),
          ],
        );
        // Bottom-aligned so the buttons stay put while items rotate; very
        // tall content (logo + tagline + long title) scales down instead
        // of overflowing.
        return Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 6),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.bottomLeft,
            child: SizedBox(
              width: width,
              child: Padding(
                padding: const EdgeInsets.only(left: KSpacing.gutter),
                child: column,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({this.tagline, this.overview});

  final String? tagline;
  final String? overview;

  @override
  Widget build(BuildContext context) {
    final base = KText.body.copyWith(
      fontSize: 17,
      height: 1.32,
      color: const Color(0xFFE6E6E6),
      shadows: const [Shadow(color: Color(0x80000000), blurRadius: 8)],
    );
    return Text.rich(
      TextSpan(
        children: [
          if (tagline != null)
            TextSpan(
              text: overview == null ? tagline : '$tagline\n',
              style: base.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          if (overview != null) TextSpan(text: overview),
        ],
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: base,
    );
  }
}

class _HeroButtons extends StatelessWidget {
  const _HeroButtons({required this.playlistId, required this.item});

  final int playlistId;
  final VodItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        KButton.ghostIconLabel(
          label: l10n.vodFavorites,
          icon: item.isFavorite
              ? PhosphorIconsFill.star
              : PhosphorIconsLight.star,
          minWidth: 88,
          semanticLabel: item.isFavorite
              ? l10n.vodRemoveFromFavorites
              : l10n.vodAddToFavorites,
          onPressed: () => toggleVodFavorite(
            context,
            playlistId: playlistId,
            type: vodItemType(item.kind),
            providerId: item.providerId,
          ),
        ),
        const SizedBox(width: 20),
        KButton.primaryWhite(
          label: l10n.vodPlay,
          icon: PhosphorIconsFill.play,
          size: KButtonSize.large,
          minWidth: 156,
          onPressed: () => playVodItem(
            context,
            playlistId: playlistId,
            kind: item.kind,
            providerId: item.providerId,
          ),
        ),
        const SizedBox(width: 20),
        KButton.ghostIconLabel(
          label: l10n.vodInfo,
          icon: PhosphorIconsLight.info,
          minWidth: 88,
          onPressed: () => openVodDetails(
            context,
            playlistId: playlistId,
            kind: item.kind,
            providerId: item.providerId,
          ),
        ),
      ],
    );
  }
}

/// TMDb logo art when available, else the text title.
class VodTitleArt extends StatelessWidget {
  const VodTitleArt({
    super.key,
    required this.title,
    required this.logoUrl,
    required this.style,
    this.maxLogoHeight = 120,
    this.maxLogoWidth = 480,
    this.maxLines = 2,
    this.textAlign = TextAlign.start,
    this.alignment = Alignment.centerLeft,
  });

  final String title;
  final String? logoUrl;
  final TextStyle style;
  final double maxLogoHeight;
  final double maxLogoWidth;
  final int maxLines;
  final TextAlign textAlign;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      title,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: style.copyWith(
        shadows: const [Shadow(color: Color(0x66000000), blurRadius: 18)],
      ),
    );
    final logo = logoUrl;
    if (logo == null) return text;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: maxLogoHeight,
        maxWidth: maxLogoWidth,
      ),
      child: KImage(
        logo,
        fit: BoxFit.contain,
        alignment: alignment,
        width: maxLogoWidth,
        height: maxLogoHeight,
        semanticLabel: title,
        placeholder: const SizedBox.shrink(),
        errorBuilder: (_) => text,
      ),
    );
  }
}

/// `★ 76% (1.3k reviews)` from TMDb, else the provider's `★ 7.6`.
class VodRatingLine extends StatelessWidget {
  const VodRatingLine({
    super.key,
    required this.meta,
    required this.style,
    this.trailing = const [],
  });

  final VodMeta meta;
  final TextStyle style;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final percent = meta.votePercent;
    final String text;
    if (percent != null) {
      final count = meta.voteCount;
      text = count == null || count <= 0
          ? '$percent%'
          : '$percent% ${l10n.vodReviews(vodCompactCount(count, locale))}';
    } else {
      text = vodRatingText(meta.providerRating ?? 0, locale);
    }
    final size = style.fontSize ?? 15;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(PhosphorIconsFill.star, size: size + 2, color: KColors.star),
        SizedBox(width: size * 0.35),
        Text(
          text,
          style: style.copyWith(
            color: Colors.white.withValues(alpha: 0.92),
            fontFeatures: KText.tabular,
          ),
        ),
        for (final w in trailing) ...[SizedBox(width: size * 0.7), w],
      ],
    );
  }
}

/// The hero metadata line: `FAMILY • FANTASY | Rachel Zegler, Gal Gadot |
/// 1h 49m | 2025`; shows use `3 seasons (21 episodes)` instead of the
/// runtime. Missing parts are left out.
String vodMetaLine(
  L10n l10n,
  VodMeta meta,
  CarinaTimeFormat fmt,
  String locale,
) {
  final turkish =
      locale == 'tr' || vodLooksTurkish('${meta.title} ${meta.overview ?? ''}');
  final parts = <String>[
    if (meta.genres.isNotEmpty)
      meta.genres.take(3).map((g) => vodUpper(g, turkish: turkish)).join(' • '),
    if (meta.cast.isNotEmpty) meta.cast.take(2).join(', '),
    if (meta.isSeries && meta.seasonCount != null)
      meta.episodeCount != null && meta.episodeCount! > 0
          ? '${l10n.vodSeasons(meta.seasonCount!)} '
                '(${l10n.vodEpisodes(meta.episodeCount!)})'
          : l10n.vodSeasons(meta.seasonCount!)
    else if (!meta.isSeries && meta.runtime != null)
      fmt.runtime(meta.runtime!),
    if (meta.year != null) '${meta.year}',
  ];
  return parts.join('  |  ');
}
