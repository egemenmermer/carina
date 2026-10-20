// Entry classification and series-marker parsing.

import 'm3u_models.dart';

const Set<String> _movieExtensions = {'mp4', 'mkv', 'avi', 'mov'};

/// Classifies an entry by its URL and `#EXTINF` duration:
///
/// 1. URL path contains `/movie/` → [M3uKind.movie];
/// 2. URL path contains `/series/` → [M3uKind.episode];
/// 3. extension mp4 / mkv / avi / mov and [duration] > 0 → [M3uKind.movie];
/// 4. otherwise [M3uKind.live].
///
/// The checks ignore case and the query string / fragment.
M3uKind classifyM3u(String url, int duration) {
  final path = _lowerPath(url);
  if (path.contains('/movie/')) return M3uKind.movie;
  if (path.contains('/series/')) return M3uKind.episode;
  if (duration > 0 && _movieExtensions.contains(_extension(path))) {
    return M3uKind.movie;
  }
  return M3uKind.live;
}

String _lowerPath(String url) {
  var end = url.length;
  final q = url.indexOf('?');
  if (q >= 0) end = q;
  final h = url.indexOf('#');
  if (h >= 0 && h < end) end = h;
  return url.substring(0, end).toLowerCase();
}

String _extension(String path) {
  final dot = path.lastIndexOf('.');
  if (dot < 0 || dot < path.lastIndexOf('/')) return '';
  return path.substring(dot + 1);
}

/// Season / episode marker found in an episode name.
class M3uSeriesMarker {
  const M3uSeriesMarker({
    required this.seriesName,
    required this.season,
    required this.episode,
    this.episodeTitle,
  });

  /// The name with the marker (and separators around it) removed.
  final String seriesName;
  final int season;
  final int episode;

  /// Text after the marker when the name also has text before it.
  final String? episodeTitle;

  @override
  String toString() =>
      'M3uSeriesMarker($seriesName, S$season E$episode'
      '${episodeTitle != null ? ', $episodeTitle' : ''})';
}

// S01E02, S01 E02, S1 E2, S01.E02, S01-E02, s01e02 (not inside a word).
final RegExp _seasonEpisode = RegExp(
  r'(?<![A-Za-z0-9])S(\d{1,3})[ ._-]*E(\d{1,4})(?!\d)',
  caseSensitive: false,
);

// 1x02, 01x02 (not 1920x1080: the digit limits and look-arounds reject it).
final RegExp _crossMarker = RegExp(
  r'(?<![A-Za-z0-9])(\d{1,2})x(\d{1,3})(?![A-Za-z0-9])',
  caseSensitive: false,
);

const String _tailJunk = ' \t-\u2013\u2014|:._,;([{';
const String _headJunk = ' \t-\u2013\u2014|:._,;)]}';

/// Parses `S01E02`, `S01 E02`, `S1 E2` and `1x02` markers (first match wins)
/// and strips the marker from the series name: `Sıcak Kafa S01 E02` →
/// `Sıcak Kafa`, season 1, episode 2. Text after the marker becomes the
/// [M3uSeriesMarker.episodeTitle] (`Show - S01E02 - Pilot` → `Pilot`).
/// Returns null when the name has no marker.
M3uSeriesMarker? parseSeriesMarker(String name) {
  final m = _seasonEpisode.firstMatch(name) ?? _crossMarker.firstMatch(name);
  if (m == null) return null;
  final before = _trimTail(name.substring(0, m.start));
  final after = _trimHead(name.substring(m.end));
  final seriesName = before.isNotEmpty
      ? before
      : (after.isNotEmpty ? after : name.trim());
  return M3uSeriesMarker(
    seriesName: seriesName,
    season: int.parse(m[1]!),
    episode: int.parse(m[2]!),
    episodeTitle: before.isNotEmpty && after.isNotEmpty ? after : null,
  );
}

String _trimTail(String s) {
  var end = s.length;
  while (end > 0 && _tailJunk.contains(s[end - 1])) {
    end--;
  }
  return s.substring(0, end).trim();
}

String _trimHead(String s) {
  var start = 0;
  while (start < s.length && _headJunk.contains(s[start])) {
    start++;
  }
  return s.substring(start).trim();
}
