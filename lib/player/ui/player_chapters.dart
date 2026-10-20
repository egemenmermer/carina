/// Chapter metadata (mpv `chapter-list`) for Skip intro and the early
/// Next episode card.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

/// One chapter: [start] … [end] (the next chapter's start, or the file end).
@immutable
class PlayerChapter {
  const PlayerChapter({
    required this.title,
    required this.start,
    required this.end,
  });

  final String title;
  final Duration start;
  final Duration end;

  bool contains(Duration position) => position >= start && position < end;

  bool get isIntro => _intro.hasMatch(title);
  bool get isCredits => _credits.hasMatch(title);

  @override
  bool operator ==(Object other) =>
      other is PlayerChapter &&
      other.title == title &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(title, start, end);

  @override
  String toString() => 'PlayerChapter("$title" $start–$end)';
}

// `\b` is ASCII-only in Dart: Unicode letter lookarounds instead, so
// Turkish names (Giriş, Kapanış) match as whole words.
final RegExp _intro = RegExp(
  r'(?<![\p{L}\p{N}])(intro|opening|op|recap|giriş|jenerik başı|açılış)'
  r'(?![\p{L}\p{N}])',
  caseSensitive: false,
  unicode: true,
);

final RegExp _credits = RegExp(
  r'(?<![\p{L}\p{N}])(credits|end credits|ending|outro|closing|jenerik|'
  r'kapanış|bitiş jeneriği)(?![\p{L}\p{N}])',
  caseSensitive: false,
  unicode: true,
);

/// Parses mpv's `chapter-list` JSON (`[{"title": "Intro", "time": 0.0}, …]`).
/// Returns an empty list for null, invalid JSON or a single untitled
/// chapter.
List<PlayerChapter> parseChapterList(String? json, Duration duration) {
  if (json == null || json.trim().isEmpty) return const [];
  Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    return const [];
  }
  if (decoded is! List) return const [];
  final starts = <(String, Duration)>[];
  for (final entry in decoded) {
    if (entry is! Map) continue;
    final time = entry['time'];
    if (time is! num) continue;
    final title = entry['title'];
    starts.add((
      title is String ? title.trim() : '',
      Duration(milliseconds: (time * 1000).round()),
    ));
  }
  starts.sort((a, b) => a.$2.compareTo(b.$2));
  final out = <PlayerChapter>[];
  for (var i = 0; i < starts.length; i++) {
    final end = i + 1 < starts.length
        ? starts[i + 1].$2
        : (duration > starts[i].$2 ? duration : starts[i].$2);
    out.add(PlayerChapter(title: starts[i].$1, start: starts[i].$2, end: end));
  }
  return List.unmodifiable(out);
}

/// The intro chapter playing at [position], if any.
PlayerChapter? introAt(List<PlayerChapter> chapters, Duration position) {
  for (final c in chapters) {
    if (c.isIntro && c.contains(position) && c.end > c.start) return c;
  }
  return null;
}

/// Start of the credits chapter (the last one named like credits), if any.
Duration? creditsStart(List<PlayerChapter> chapters) {
  for (final c in chapters.reversed) {
    if (c.isCredits) return c.start;
  }
  return null;
}
