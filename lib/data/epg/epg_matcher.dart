/// Matches playlist channels to XMLTV channels.
library;

import '../text/normalize.dart';

/// An EPG channel as the matcher sees it: the XMLTV `id` and every
/// `<display-name>` (the first is the primary one).
final class EpgChannelRef {
  const EpgChannelRef(this.id, this.displayNames);

  final String id;
  final List<String> displayNames;

  @override
  String toString() => 'EpgChannelRef($id, $displayNames)';
}

/// How [EpgMatcher.matchDetailed] found the EPG channel.
enum EpgMatchMethod {
  /// The manual Custom EPG assignment.
  custom,

  /// `tvg-id` / `epg_channel_id` equals the XMLTV id.
  exactId,

  /// Same id ignoring case and surrounding whitespace.
  caseInsensitiveId,

  /// [normalizeChannelName] of the channel name equals that of one of the
  /// XMLTV display names.
  normalizedName,

  /// Nothing matched: "EPG not available".
  none,
}

/// The outcome of a match, for diagnostics ("Dump Channel").
final class EpgMatchResult {
  const EpgMatchResult(this.epgId, this.method);

  static const EpgMatchResult noMatch = EpgMatchResult(
    null,
    EpgMatchMethod.none,
  );

  /// The XMLTV channel id, or null.
  final String? epgId;
  final EpgMatchMethod method;

  @override
  bool operator ==(Object other) =>
      other is EpgMatchResult && other.epgId == epgId && other.method == method;

  @override
  int get hashCode => Object.hash(epgId, method);

  @override
  String toString() => 'EpgMatchResult($epgId, ${method.name})';
}

/// Resolves the EPG channel of a playlist channel, in this order:
///
/// 1. the manual Custom EPG assignment ([customEpgId]); it is returned even
///    when the current XMLTV does not declare it (the user's choice wins),
///    resolved to the declared spelling when only its case differs;
/// 2. exact `tvg-id` / `epg_channel_id`;
/// 3. case-insensitive id (also ignoring surrounding whitespace);
/// 4. [normalizeChannelName] of the channel name against the normalized
///    display names of every EPG channel (`TR: Show TV HD` → `showtv` =
///    `Show TV`);
/// 5. no match.
///
/// The lookup maps are built once in the constructor, so each match is a
/// few hash lookups plus one normalization. When several EPG channels share
/// a key, the first declared one wins (and, within a channel, its display
/// names in order).
final class EpgMatcher {
  EpgMatcher(Iterable<EpgChannelRef> channels) {
    for (final channel in channels) {
      final id = channel.id;
      if (id.isEmpty) continue;
      _ids.add(id);
      _lowerIds.putIfAbsent(id.trim().toLowerCase(), () => id);
      for (final name in channel.displayNames) {
        final key = normalizeChannelName(name);
        if (key.isNotEmpty) _names.putIfAbsent(key, () => id);
      }
    }
  }

  final Set<String> _ids = <String>{};
  final Map<String, String> _lowerIds = <String, String>{};
  final Map<String, String> _names = <String, String>{};

  /// Number of distinct EPG channel ids.
  int get channelCount => _ids.length;

  /// The matched XMLTV channel id, or null ("EPG not available").
  String? match({String? customEpgId, String? tvgId, required String name}) =>
      matchDetailed(customEpgId: customEpgId, tvgId: tvgId, name: name).epgId;

  /// Like [match], and says which rule matched.
  EpgMatchResult matchDetailed({
    String? customEpgId,
    String? tvgId,
    required String name,
  }) {
    final custom = customEpgId?.trim();
    if (custom != null && custom.isNotEmpty) {
      final resolved = _ids.contains(custom)
          ? custom
          : _lowerIds[custom.toLowerCase()] ?? custom;
      return EpgMatchResult(resolved, EpgMatchMethod.custom);
    }
    if (tvgId != null && tvgId.isNotEmpty) {
      if (_ids.contains(tvgId)) {
        return EpgMatchResult(tvgId, EpgMatchMethod.exactId);
      }
      final lower = tvgId.trim().toLowerCase();
      final byCase = lower.isEmpty ? null : _lowerIds[lower];
      if (byCase != null) {
        return EpgMatchResult(byCase, EpgMatchMethod.caseInsensitiveId);
      }
    }
    final key = normalizeChannelName(name);
    if (key.isNotEmpty) {
      final byName = _names[key];
      if (byName != null) {
        return EpgMatchResult(byName, EpgMatchMethod.normalizedName);
      }
    }
    return EpgMatchResult.noMatch;
  }
}
