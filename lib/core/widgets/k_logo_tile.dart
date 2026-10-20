import 'package:flutter/widgets.dart';

import 'package:carina/core/images/k_image.dart';
import 'package:carina/core/tokens.dart';

/// Channel logo tile: [size] square (64 by default), radius 8, light
/// neutral background, logo scaled to fit. Falls back to a [KMonogram]
/// (initials on a deterministic dark gradient) when [url] is empty or fails.
class KLogoTile extends StatelessWidget {
  const KLogoTile({
    super.key,
    required this.name,
    this.url,
    this.size = 64,
    this.radius = KRadii.logo,
    this.background = KColors.logoBackground,
    this.headers,
  });

  /// Channel name (used for the monogram).
  final String name;
  final String? url;
  final double size;
  final double radius;
  final Color background;
  final Map<String, String>? headers;

  @override
  Widget build(BuildContext context) {
    final monogram = KMonogram(name: name, size: size);
    return SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: KImage(
          url,
          fit: BoxFit.contain,
          width: size,
          height: size,
          headers: headers,
          imageBackground: background,
          imagePadding: EdgeInsets.all(size * 0.09),
          placeholder: Container(color: const Color(0xFF1E1E20)),
          errorBuilder: (_) => monogram,
        ),
      ),
    );
  }
}

/// Initials on a deterministic dark gradient — the fallback for missing
/// channel logos (and anything else that needs a generated tile).
class KMonogram extends StatelessWidget {
  const KMonogram({super.key, required this.name, this.size = 64});

  final String name;
  final double size;

  static const List<List<Color>> _gradients = [
    [Color(0xFF4A1D2E), Color(0xFF26101A)],
    [Color(0xFF1D3A4A), Color(0xFF0F1E28)],
    [Color(0xFF243B2A), Color(0xFF111E15)],
    [Color(0xFF3B2A4D), Color(0xFF1C1427)],
    [Color(0xFF4A3A1D), Color(0xFF261D0E)],
    [Color(0xFF1D4A45), Color(0xFF0E2624)],
    [Color(0xFF4A231D), Color(0xFF26110D)],
    [Color(0xFF2A2F4D), Color(0xFF141729)],
    [Color(0xFF3D3D40), Color(0xFF1C1C1E)],
    [Color(0xFF4D2A44), Color(0xFF281523)],
  ];

  static final RegExp _quality = RegExp(
    r'\b(SD|HD|FHD|UHD|4K|8K|H\.?265|HEVC|HDR|\d{2,3}\s?FPS)\b',
    caseSensitive: false,
  );
  static final RegExp _prefix = RegExp(
    r'^\s*(\[[^\]]*\]|\|[^|]*\||[A-Za-z]{2,3}\s*[:|]\s*)',
  );
  static final RegExp _separators = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

  /// Up to two initials for [name], ignoring quality tokens and country
  /// prefixes ("TR: TRT 1 HD" → "T1", "Show TV FHD" → "ST").
  static String initialsOf(String name) {
    var s = name.replaceFirst(_prefix, '');
    s = s.replaceAll(_quality, ' ');
    final words = s.split(_separators).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      final w = words.first.characters;
      return w.take(2).toString().toUpperCase();
    }
    return (words[0].characters.first + words[1].characters.first)
        .toUpperCase();
  }

  /// Stable 32-bit FNV-1a hash (identical across runs and platforms).
  static int stableHash(String s) {
    var h = 0x811C9DC5;
    for (final unit in s.codeUnits) {
      h ^= unit;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }

  @override
  Widget build(BuildContext context) {
    final colors = _gradients[stableHash(name) % _gradients.length];
    final initials = initialsOf(name);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Text(
        initials,
        maxLines: 1,
        style: TextStyle(
          fontFamily: KText.family,
          fontSize: size * (initials.length > 1 ? 0.34 : 0.42),
          fontWeight: FontWeight.w800,
          letterSpacing: -0.02 * size,
          color: const Color(0xEBFFFFFF),
        ),
      ),
    );
  }
}
