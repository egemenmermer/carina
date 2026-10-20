import 'package:flutter/widgets.dart';

import 'package:carina/core/strings.dart';

/// Avatar picker categories (Playlist Manager → Choose Avatar).
enum AvatarCategory {
  characters,
  animals,
  cars,
  objects,
  abstract,
  initials;

  /// Localized category name.
  String label(BuildContext context) {
    final s = KStrings.of(context);
    return switch (this) {
      AvatarCategory.characters => s.avatarCharacters,
      AvatarCategory.animals => s.avatarAnimals,
      AvatarCategory.cars => s.avatarCars,
      AvatarCategory.objects => s.avatarObjects,
      AvatarCategory.abstract => s.avatarAbstract,
      AvatarCategory.initials => s.avatarInitials,
    };
  }
}

/// Geometric glyphs of the Abstract avatars (drawn by a CustomPainter).
enum AvatarShape {
  rings,
  triangles,
  waves,
  dots,
  diamond,
  crescent,
  star,
  stripes,
  hexagon,
  orbit,
}

/// One procedurally generated avatar: a gradient circle plus a bold glyph
/// (an emoji, a geometric shape, or the playlist's initials).
@immutable
class AvatarSpec {
  const AvatarSpec._({
    required this.id,
    required this.category,
    required this.name,
    required this.gradient,
    this.emoji,
    this.shape,
  });

  /// Stable id stored with the playlist.
  final String id;
  final AvatarCategory category;

  /// English name (accessibility label).
  final String name;

  /// Two gradient stops (top-left → bottom-right).
  final List<Color> gradient;

  /// Emoji glyph (characters, animals, cars, objects).
  final String? emoji;

  /// Geometric glyph (abstract).
  final AvatarShape? shape;

  /// Whether the glyph is the owner's initials.
  bool get usesInitials => category == AvatarCategory.initials;
}

/// Gradient pairs that read well on pure black.
abstract final class _G {
  static const coral = [Color(0xFFFF7A6B), Color(0xFFC9184A)];
  static const amber = [Color(0xFFFFC15E), Color(0xFFFF6A00)];
  static const sun = [Color(0xFFFFE08A), Color(0xFFF4A100)];
  static const mint = [Color(0xFF5FF0C4), Color(0xFF048A6E)];
  static const sky = [Color(0xFF6FD6F7), Color(0xFF3A6FFF)];
  static const indigo = [Color(0xFF6A7DFF), Color(0xFF3A0CA3)];
  static const purple = [Color(0xFFD94FC0), Color(0xFF7209B7)];
  static const pink = [Color(0xFFFF6FAE), Color(0xFFB5179E)];
  static const lime = [Color(0xFFA6F28B), Color(0xFF2E9E00)];
  static const teal = [Color(0xFF4FE0D2), Color(0xFF0B6E6A)];
  static const tangerine = [Color(0xFFFFB443), Color(0xFFFF4D00)];
  static const violet = [Color(0xFFB98CFF), Color(0xFF5A189A)];
  static const rose = [Color(0xFFFF9AAE), Color(0xFFE5385B)];
  static const ocean = [Color(0xFF63D5F0), Color(0xFF0062A8)];
  static const steel = [Color(0xFFC5CCD3), Color(0xFF4A535C)];
  static const sand = [Color(0xFFF2D27A), Color(0xFFD9593B)];
  static const ruby = [Color(0xFFFF5A47), Color(0xFF8E0B1F)];
  static const night = [Color(0xFF5C6BC0), Color(0xFF141A3D)];
}

/// The built-in avatars (58, all original and generated at runtime — see
/// docs/ASSETS.md).
abstract final class AvatarCatalog {
  static const List<AvatarSpec> all = [
    // Characters
    AvatarSpec._(
      id: 'char-robot',
      category: AvatarCategory.characters,
      name: 'Robot',
      gradient: _G.sky,
      emoji: '🤖',
    ),
    AvatarSpec._(
      id: 'char-alien',
      category: AvatarCategory.characters,
      name: 'Alien',
      gradient: _G.lime,
      emoji: '👽',
    ),
    AvatarSpec._(
      id: 'char-ghost',
      category: AvatarCategory.characters,
      name: 'Ghost',
      gradient: _G.violet,
      emoji: '👻',
    ),
    AvatarSpec._(
      id: 'char-cowboy',
      category: AvatarCategory.characters,
      name: 'Cowboy',
      gradient: _G.sand,
      emoji: '🤠',
    ),
    AvatarSpec._(
      id: 'char-mage',
      category: AvatarCategory.characters,
      name: 'Mage',
      gradient: _G.indigo,
      emoji: '🧙',
    ),
    AvatarSpec._(
      id: 'char-vampire',
      category: AvatarCategory.characters,
      name: 'Vampire',
      gradient: _G.ruby,
      emoji: '🧛',
    ),
    AvatarSpec._(
      id: 'char-hero',
      category: AvatarCategory.characters,
      name: 'Superhero',
      gradient: _G.coral,
      emoji: '🦸',
    ),
    AvatarSpec._(
      id: 'char-mermaid',
      category: AvatarCategory.characters,
      name: 'Merperson',
      gradient: _G.teal,
      emoji: '🧜',
    ),
    AvatarSpec._(
      id: 'char-genie',
      category: AvatarCategory.characters,
      name: 'Genie',
      gradient: _G.purple,
      emoji: '🧞',
    ),
    AvatarSpec._(
      id: 'char-santa',
      category: AvatarCategory.characters,
      name: 'Santa',
      gradient: _G.rose,
      emoji: '🎅',
    ),
    // Animals
    AvatarSpec._(
      id: 'animal-fox',
      category: AvatarCategory.animals,
      name: 'Fox',
      gradient: _G.tangerine,
      emoji: '🦊',
    ),
    AvatarSpec._(
      id: 'animal-panda',
      category: AvatarCategory.animals,
      name: 'Panda',
      gradient: _G.mint,
      emoji: '🐼',
    ),
    AvatarSpec._(
      id: 'animal-tiger',
      category: AvatarCategory.animals,
      name: 'Tiger',
      gradient: _G.amber,
      emoji: '🐯',
    ),
    AvatarSpec._(
      id: 'animal-lion',
      category: AvatarCategory.animals,
      name: 'Lion',
      gradient: _G.sun,
      emoji: '🦁',
    ),
    AvatarSpec._(
      id: 'animal-koala',
      category: AvatarCategory.animals,
      name: 'Koala',
      gradient: _G.steel,
      emoji: '🐨',
    ),
    AvatarSpec._(
      id: 'animal-frog',
      category: AvatarCategory.animals,
      name: 'Frog',
      gradient: _G.lime,
      emoji: '🐸',
    ),
    AvatarSpec._(
      id: 'animal-octopus',
      category: AvatarCategory.animals,
      name: 'Octopus',
      gradient: _G.pink,
      emoji: '🐙',
    ),
    AvatarSpec._(
      id: 'animal-owl',
      category: AvatarCategory.animals,
      name: 'Owl',
      gradient: _G.night,
      emoji: '🦉',
    ),
    AvatarSpec._(
      id: 'animal-wolf',
      category: AvatarCategory.animals,
      name: 'Wolf',
      gradient: _G.ocean,
      emoji: '🐺',
    ),
    AvatarSpec._(
      id: 'animal-unicorn',
      category: AvatarCategory.animals,
      name: 'Unicorn',
      gradient: _G.purple,
      emoji: '🦄',
    ),
    AvatarSpec._(
      id: 'animal-penguin',
      category: AvatarCategory.animals,
      name: 'Penguin',
      gradient: _G.sky,
      emoji: '🐧',
    ),
    AvatarSpec._(
      id: 'animal-dolphin',
      category: AvatarCategory.animals,
      name: 'Dolphin',
      gradient: _G.teal,
      emoji: '🐬',
    ),
    // Cars
    AvatarSpec._(
      id: 'car-red',
      category: AvatarCategory.cars,
      name: 'Car',
      gradient: _G.steel,
      emoji: '🚗',
    ),
    AvatarSpec._(
      id: 'car-race',
      category: AvatarCategory.cars,
      name: 'Race car',
      gradient: _G.ruby,
      emoji: '🏎️',
    ),
    AvatarSpec._(
      id: 'car-suv',
      category: AvatarCategory.cars,
      name: 'SUV',
      gradient: _G.ocean,
      emoji: '🚙',
    ),
    AvatarSpec._(
      id: 'car-taxi',
      category: AvatarCategory.cars,
      name: 'Taxi',
      gradient: _G.sun,
      emoji: '🚕',
    ),
    AvatarSpec._(
      id: 'car-police',
      category: AvatarCategory.cars,
      name: 'Police car',
      gradient: _G.indigo,
      emoji: '🚓',
    ),
    AvatarSpec._(
      id: 'car-fire',
      category: AvatarCategory.cars,
      name: 'Fire engine',
      gradient: _G.amber,
      emoji: '🚒',
    ),
    AvatarSpec._(
      id: 'car-tractor',
      category: AvatarCategory.cars,
      name: 'Tractor',
      gradient: _G.lime,
      emoji: '🚜',
    ),
    AvatarSpec._(
      id: 'car-moto',
      category: AvatarCategory.cars,
      name: 'Motorcycle',
      gradient: _G.night,
      emoji: '🏍️',
    ),
    // Objects
    AvatarSpec._(
      id: 'obj-gamepad',
      category: AvatarCategory.objects,
      name: 'Game controller',
      gradient: _G.violet,
      emoji: '🎮',
    ),
    AvatarSpec._(
      id: 'obj-headphones',
      category: AvatarCategory.objects,
      name: 'Headphones',
      gradient: _G.pink,
      emoji: '🎧',
    ),
    AvatarSpec._(
      id: 'obj-tv',
      category: AvatarCategory.objects,
      name: 'Television',
      gradient: _G.sky,
      emoji: '📺',
    ),
    AvatarSpec._(
      id: 'obj-clapper',
      category: AvatarCategory.objects,
      name: 'Clapper board',
      gradient: _G.steel,
      emoji: '🎬',
    ),
    AvatarSpec._(
      id: 'obj-popcorn',
      category: AvatarCategory.objects,
      name: 'Popcorn',
      gradient: _G.coral,
      emoji: '🍿',
    ),
    AvatarSpec._(
      id: 'obj-football',
      category: AvatarCategory.objects,
      name: 'Football',
      gradient: _G.mint,
      emoji: '⚽',
    ),
    AvatarSpec._(
      id: 'obj-guitar',
      category: AvatarCategory.objects,
      name: 'Guitar',
      gradient: _G.sand,
      emoji: '🎸',
    ),
    AvatarSpec._(
      id: 'obj-camera',
      category: AvatarCategory.objects,
      name: 'Camera',
      gradient: _G.ocean,
      emoji: '📷',
    ),
    AvatarSpec._(
      id: 'obj-dice',
      category: AvatarCategory.objects,
      name: 'Dice',
      gradient: _G.rose,
      emoji: '🎲',
    ),
    AvatarSpec._(
      id: 'obj-rocket',
      category: AvatarCategory.objects,
      name: 'Rocket',
      gradient: _G.night,
      emoji: '🚀',
    ),
    // Abstract
    AvatarSpec._(
      id: 'abs-rings',
      category: AvatarCategory.abstract,
      name: 'Rings',
      gradient: _G.ruby,
      shape: AvatarShape.rings,
    ),
    AvatarSpec._(
      id: 'abs-triangles',
      category: AvatarCategory.abstract,
      name: 'Triangles',
      gradient: _G.tangerine,
      shape: AvatarShape.triangles,
    ),
    AvatarSpec._(
      id: 'abs-waves',
      category: AvatarCategory.abstract,
      name: 'Waves',
      gradient: _G.ocean,
      shape: AvatarShape.waves,
    ),
    AvatarSpec._(
      id: 'abs-dots',
      category: AvatarCategory.abstract,
      name: 'Dots',
      gradient: _G.purple,
      shape: AvatarShape.dots,
    ),
    AvatarSpec._(
      id: 'abs-diamond',
      category: AvatarCategory.abstract,
      name: 'Diamond',
      gradient: _G.teal,
      shape: AvatarShape.diamond,
    ),
    AvatarSpec._(
      id: 'abs-crescent',
      category: AvatarCategory.abstract,
      name: 'Crescent',
      gradient: _G.night,
      shape: AvatarShape.crescent,
    ),
    AvatarSpec._(
      id: 'abs-star',
      category: AvatarCategory.abstract,
      name: 'Star',
      gradient: _G.sun,
      shape: AvatarShape.star,
    ),
    AvatarSpec._(
      id: 'abs-stripes',
      category: AvatarCategory.abstract,
      name: 'Stripes',
      gradient: _G.pink,
      shape: AvatarShape.stripes,
    ),
    AvatarSpec._(
      id: 'abs-hexagon',
      category: AvatarCategory.abstract,
      name: 'Hexagon',
      gradient: _G.lime,
      shape: AvatarShape.hexagon,
    ),
    AvatarSpec._(
      id: 'abs-orbit',
      category: AvatarCategory.abstract,
      name: 'Orbit',
      gradient: _G.indigo,
      shape: AvatarShape.orbit,
    ),
    // Initials (glyph = the owner's initials)
    AvatarSpec._(
      id: 'init-ruby',
      category: AvatarCategory.initials,
      name: 'Initials, red',
      gradient: _G.ruby,
    ),
    AvatarSpec._(
      id: 'init-amber',
      category: AvatarCategory.initials,
      name: 'Initials, orange',
      gradient: _G.amber,
    ),
    AvatarSpec._(
      id: 'init-sun',
      category: AvatarCategory.initials,
      name: 'Initials, yellow',
      gradient: _G.sun,
    ),
    AvatarSpec._(
      id: 'init-mint',
      category: AvatarCategory.initials,
      name: 'Initials, green',
      gradient: _G.mint,
    ),
    AvatarSpec._(
      id: 'init-sky',
      category: AvatarCategory.initials,
      name: 'Initials, blue',
      gradient: _G.sky,
    ),
    AvatarSpec._(
      id: 'init-violet',
      category: AvatarCategory.initials,
      name: 'Initials, violet',
      gradient: _G.violet,
    ),
    AvatarSpec._(
      id: 'init-pink',
      category: AvatarCategory.initials,
      name: 'Initials, pink',
      gradient: _G.pink,
    ),
    AvatarSpec._(
      id: 'init-steel',
      category: AvatarCategory.initials,
      name: 'Initials, grey',
      gradient: _G.steel,
    ),
  ];

  static final Map<String, AvatarSpec> _byId = {for (final a in all) a.id: a};

  /// The avatar with [id], or null when unknown.
  static AvatarSpec? byId(String? id) => id == null ? null : _byId[id];

  /// Avatars of [category] in display order.
  static List<AvatarSpec> byCategory(AvatarCategory category) =>
      all.where((a) => a.category == category).toList(growable: false);

  /// A deterministic non-initials avatar for [seed] (e.g. a new playlist's
  /// name), so new playlists get varied defaults.
  static AvatarSpec defaultFor(String seed) {
    final pool = all.where((a) => !a.usesInitials).toList(growable: false);
    var h = 0x811C9DC5;
    for (final unit in seed.codeUnits) {
      h ^= unit;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return pool[h % pool.length];
  }

  /// The initials avatar used when a playlist has no (or an unknown) avatar.
  static AvatarSpec initialsFor(String seed) {
    final pool = byCategory(AvatarCategory.initials);
    var h = 0x811C9DC5;
    for (final unit in seed.codeUnits) {
      h ^= unit;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return pool[h % pool.length];
  }
}
