/// View models and helpers shared by the live TV, EPG, category, parental and
/// reminder repositories (ARCHITECTURE 2.10).
///
/// Everything here is immutable and safe to hand to widgets. Programme times
/// are UTC [DateTime]s (the database stores UTC epoch milliseconds).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show PlatformDispatcher;

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show Listenable, immutable;

import '../db/database.dart';
import '../settings/settings_store.dart';
import '../sources/catchup/catchup.dart' show isReplayable;
import '../text/src/fold.dart';

// ---------------------------------------------------------------------------
// Category references
// ---------------------------------------------------------------------------

/// What a category entry of the sidebar points at. Value
/// semantics, so it can be a Riverpod family argument.
sealed class CategoryRef {
  const CategoryRef();

  /// Stable text form for routes and saved selections: `p:<providerId>`,
  /// `fav`, `fav:<tagId>`, `last`, `recent`, `all`.
  String get key;

  /// Parses [key]; null when it is not a valid key.
  static CategoryRef? tryParse(String key) {
    if (key.startsWith('p:')) return ProviderCategory(key.substring(2));
    if (key == 'fav') return const FavoritesCategory();
    if (key.startsWith('fav:')) {
      final tag = int.tryParse(key.substring(4));
      return tag == null ? null : FavoritesCategory(tagId: tag);
    }
    return switch (key) {
      'last' => const LastWatchedCategory(),
      'recent' => const RecentlyAddedCategory(),
      'all' => const AllCategory(),
      _ => null,
    };
  }

  @override
  String toString() => 'CategoryRef($key)';
}

/// A category delivered by the provider (`categories.providerId`).
final class ProviderCategory extends CategoryRef {
  const ProviderCategory(this.id);

  final String id;

  @override
  String get key => 'p:$id';

  @override
  bool operator ==(Object other) => other is ProviderCategory && other.id == id;

  @override
  int get hashCode => Object.hash(ProviderCategory, id);
}

/// Favorites, or one favorite tag ([tagId]) below it.
final class FavoritesCategory extends CategoryRef {
  const FavoritesCategory({this.tagId});

  final int? tagId;

  @override
  String get key => tagId == null ? 'fav' : 'fav:$tagId';

  @override
  bool operator ==(Object other) =>
      other is FavoritesCategory && other.tagId == tagId;

  @override
  int get hashCode => Object.hash(FavoritesCategory, tagId);
}

/// Live channels started recently.
final class LastWatchedCategory extends CategoryRef {
  const LastWatchedCategory();

  @override
  String get key => 'last';

  @override
  bool operator ==(Object other) => other is LastWatchedCategory;

  @override
  int get hashCode => (LastWatchedCategory).hashCode;
}

/// Items added in the last 7 days (series: modified).
final class RecentlyAddedCategory extends CategoryRef {
  const RecentlyAddedCategory();

  @override
  String get key => 'recent';

  @override
  bool operator ==(Object other) => other is RecentlyAddedCategory;

  @override
  int get hashCode => (RecentlyAddedCategory).hashCode;
}

/// Every visible item of the section (guide default, zapping, pickers).
/// Not listed in the sidebar.
final class AllCategory extends CategoryRef {
  const AllCategory();

  @override
  String get key => 'all';

  @override
  bool operator ==(Object other) => other is AllCategory;

  @override
  int get hashCode => (AllCategory).hashCode;
}

/// Window of [RecentlyAddedCategory].
const Duration recentlyAddedWindow = Duration(days: 7);

/// Maximum length of the Last watched list.
const int lastWatchedLimit = 50;

// ---------------------------------------------------------------------------
// Sidebar entries
// ---------------------------------------------------------------------------

/// One entry of the category sidebar.
///
/// Special entries (Favorites, its tags, Last watched, Recently added) carry
/// an English fallback [name]; the UI localizes them by the type of [ref]
/// (tag entries use the tag name as is).
@immutable
class CategoryView {
  const CategoryView({
    required this.ref,
    required this.kind,
    required this.name,
    required this.label,
    required this.count,
    this.flag,
    this.hidden = false,
    this.locked = false,
    this.depth = 0,
    this.row,
  });

  final CategoryRef ref;
  final SectionKind kind;

  /// Display name: the local rename, else the provider name.
  final String name;

  /// Country flag emoji parsed from [name] (`TR | Ulusal` → 🇹🇷), or null.
  final String? flag;

  /// [name] without the country marker (`Ulusal`).
  final String label;

  /// Visible items: hidden items never count; with parental mode `hide`,
  /// locked ones neither.
  final int count;
  final bool hidden;
  final bool locked;

  /// 1 for favorite tags (indented below Favorites), else 0.
  final int depth;

  /// The stored row of a provider category (null for special entries).
  final CategoryRow? row;

  /// Text for pills and lists: `🇹🇷 Ulusal`.
  String get title => flag == null ? label : '$flag $label';

  /// Provider category id, or null for special entries.
  String? get providerId => switch (ref) {
    ProviderCategory(:final id) => id,
    _ => null,
  };

  bool get isSpecial => ref is! ProviderCategory;

  /// The provider name (for "Rename … Reset"), null for special entries.
  String? get providerName => row?.name;

  /// A local rename is active.
  bool get isRenamed => row?.localName != null;

  @override
  bool operator ==(Object other) =>
      other is CategoryView &&
      other.ref == ref &&
      other.kind == kind &&
      other.name == name &&
      other.flag == flag &&
      other.label == label &&
      other.count == count &&
      other.hidden == hidden &&
      other.locked == locked &&
      other.depth == depth &&
      other.row == row;

  @override
  int get hashCode =>
      Object.hash(ref, kind, name, flag, label, count, hidden, locked, depth);

  @override
  String toString() => 'CategoryView(${ref.key} "$name" $count)';
}

// ---------------------------------------------------------------------------
// Channels
// ---------------------------------------------------------------------------

/// A live channel as the channel cards, guide rows and player need it.
@immutable
class ChannelView {
  const ChannelView({
    required this.row,
    required this.displayName,
    required this.badges,
    required this.locked,
    required this.favorite,
    required this.hasReminder,
    required this.hasArchive,
    required this.epgKey,
    required this.categoryName,
    this.channelLocked = false,
    this.categoryLocked = false,
    this.categoryHidden = false,
  });

  final ChannelRow row;

  /// Name without quality tokens (`Show TV`).
  final String displayName;

  /// Quality badges in display order (`FHD`, `H265`…).
  final List<String> badges;

  /// The channel or its category is locked (stored flags; the session
  /// unlock is applied by `ParentalService.isLocked`).
  final bool locked;
  final bool channelLocked;
  final bool categoryLocked;
  final bool categoryHidden;
  final bool favorite;

  /// A reminder is set on a programme of this channel that has not ended.
  final bool hasReminder;

  /// The channel has catch-up (`archiveDays > 0`).
  final bool hasArchive;

  /// XMLTV channel id for programme lookups: Custom EPG, else the matched
  /// id, else (Xtream only) the provider `epg_channel_id`. Null = "EPG not
  /// available" (Xtream playlists may still use the short EPG).
  final String? epgKey;

  /// Display name of the channel's category ('' when unknown).
  final String categoryName;

  String get providerId => row.providerId;
  int get playlistId => row.playlistId;
  int? get number => row.num;
  String? get logo => row.logo;
  int get archiveDays => row.archiveDays;

  /// False for DRM entries (shown, but not playable).
  bool get playable => !row.unsupported;

  @override
  bool operator ==(Object other) =>
      other is ChannelView &&
      other.row == row &&
      other.displayName == displayName &&
      const ListEquality<String>().equals(other.badges, badges) &&
      other.locked == locked &&
      other.channelLocked == channelLocked &&
      other.categoryLocked == categoryLocked &&
      other.categoryHidden == categoryHidden &&
      other.favorite == favorite &&
      other.hasReminder == hasReminder &&
      other.hasArchive == hasArchive &&
      other.epgKey == epgKey &&
      other.categoryName == categoryName;

  @override
  int get hashCode => Object.hash(
    row,
    displayName,
    locked,
    favorite,
    hasReminder,
    epgKey,
    categoryName,
  );

  @override
  String toString() => 'ChannelView(${row.providerId} "$displayName")';
}

/// Previous / next channel for zapping (wrapping around the list).
typedef ChannelNeighbors = ({ChannelView? previous, ChannelView? next});

/// Locked channels and categories of a playlist (Settings → Parental
/// Control lists).
@immutable
class LockedItems {
  const LockedItems({required this.channels, required this.categories});

  static const LockedItems empty = LockedItems(channels: [], categories: []);

  final List<ChannelView> channels;
  final List<CategoryView> categories;

  bool get isEmpty => channels.isEmpty && categories.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is LockedItems &&
      const ListEquality<ChannelView>().equals(other.channels, channels) &&
      const ListEquality<CategoryView>().equals(other.categories, categories);

  @override
  int get hashCode => Object.hash(channels.length, categories.length);
}

/// The EPG key of [channel] (see [ChannelView.epgKey]).
String? channelEpgKey(ChannelRow channel, PlaylistType type) =>
    _nonBlank(channel.customEpgId) ??
    _nonBlank(channel.matchedEpgId) ??
    (type == PlaylistType.xtream ? _nonBlank(channel.epgId) : null);

/// `channels.quality` (`HD,H265`) as a list.
List<String> qualityBadges(String? quality) {
  if (quality == null || quality.isEmpty) return const [];
  return List.unmodifiable([
    for (final part in quality.split(','))
      if (part.trim().isNotEmpty) part.trim(),
  ]);
}

// ---------------------------------------------------------------------------
// Programmes
// ---------------------------------------------------------------------------

/// One EPG programme, from the database or from the Xtream short EPG.
@immutable
class ProgrammeView {
  const ProgrammeView({
    required this.epgChannelId,
    required this.start,
    required this.stop,
    required this.title,
    this.id,
    this.subTitle,
    this.description,
    this.category,
    this.episodeNum,
    this.icon,
    this.rating,
  });

  factory ProgrammeView.fromRow(ProgrammeRow row) => ProgrammeView(
    id: row.id,
    epgChannelId: row.epgChannelId,
    start: DateTime.fromMillisecondsSinceEpoch(row.start, isUtc: true),
    stop: DateTime.fromMillisecondsSinceEpoch(row.stop, isUtc: true),
    title: row.title,
    subTitle: _nonBlank(row.subTitle),
    description: _nonBlank(row.description),
    category: _nonBlank(row.category),
    episodeNum: _nonBlank(row.episodeNum),
    icon: _nonBlank(row.icon),
    rating: _nonBlank(row.rating),
  );

  /// `programmes.id`; null for short-EPG programmes.
  final int? id;

  /// The EPG key it belongs to (short EPG: the channel's key, else
  /// `xtream:<streamId>`).
  final String epgChannelId;

  /// UTC.
  final DateTime start;

  /// UTC.
  final DateTime stop;
  final String title;
  final String? subTitle;
  final String? description;
  final String? category;
  final String? episodeNum;
  final String? icon;
  final String? rating;

  int get startMs => start.millisecondsSinceEpoch;
  int get stopMs => stop.millisecondsSinceEpoch;
  Duration get duration => stop.difference(start);

  /// Stable identity across the database and the short EPG.
  String get key => '$epgChannelId@$startMs';

  bool isOnAirAt(DateTime at) => !at.isBefore(start) && at.isBefore(stop);
  bool hasEndedAt(DateTime at) => !stop.isAfter(at);
  bool isUpcomingAt(DateTime at) => start.isAfter(at);

  /// Played fraction (0–1) at [at].
  double progressAt(DateTime at) {
    final total = stopMs - startMs;
    if (total <= 0) return 0;
    return ((at.millisecondsSinceEpoch - startMs) / total).clamp(0.0, 1.0);
  }

  /// ended and started inside the archive window.
  bool isReplayableWith(int archiveDays, DateTime now) => isReplayable(
    startUtc: start,
    endUtc: stop,
    archiveDays: archiveDays,
    nowUtc: now.toUtc(),
  );

  @override
  bool operator ==(Object other) =>
      other is ProgrammeView &&
      other.id == id &&
      other.epgChannelId == epgChannelId &&
      other.start == start &&
      other.stop == stop &&
      other.title == title &&
      other.subTitle == subTitle &&
      other.description == description &&
      other.category == category &&
      other.episodeNum == episodeNum &&
      other.icon == icon &&
      other.rating == rating;

  @override
  int get hashCode => Object.hash(id, epgChannelId, start, stop, title);

  @override
  String toString() =>
      'ProgrammeView($epgChannelId ${start.toIso8601String()} "$title")';
}

/// The programme on air and the one after it.
@immutable
class NowNext {
  const NowNext({this.now, this.next});

  /// Picks now/next from programmes sorted or unsorted by start.
  factory NowNext.fromProgrammes(Iterable<ProgrammeView> list, DateTime at) {
    ProgrammeView? now;
    ProgrammeView? next;
    for (final p in list) {
      if (!p.start.isAfter(at)) {
        if (p.stop.isAfter(at) && (now == null || p.start.isAfter(now.start))) {
          now = p;
        }
      } else if (next == null || p.start.isBefore(next.start)) {
        next = p;
      }
    }
    return NowNext(now: now, next: next);
  }

  static const NowNext empty = NowNext();

  final ProgrammeView? now;
  final ProgrammeView? next;

  bool get isEmpty => now == null && next == null;

  @override
  bool operator ==(Object other) =>
      other is NowNext && other.now == now && other.next == next;

  @override
  int get hashCode => Object.hash(now, next);

  @override
  String toString() => 'NowNext(now: ${now?.title}, next: ${next?.title})';
}

/// One day of the TV Archive sheet, newest programme first.
@immutable
class ArchiveDay {
  const ArchiveDay(this.date, this.programmes);

  /// Local midnight of the day.
  final DateTime date;
  final List<ProgrammeView> programmes;

  @override
  bool operator ==(Object other) =>
      other is ArchiveDay &&
      other.date == date &&
      const ListEquality<ProgrammeView>().equals(other.programmes, programmes);

  @override
  int get hashCode => Object.hash(date, programmes.length);

  @override
  String toString() => 'ArchiveDay($date, ${programmes.length})';
}

/// An XMLTV channel for the Custom EPG picker.
@immutable
class EpgChannelView {
  const EpgChannelView({
    required this.id,
    required this.displayName,
    this.icon,
    this.now,
  });

  /// XMLTV channel id (what `setCustomEpg` stores).
  final String id;
  final String displayName;
  final String? icon;

  /// The programme on air now, when the guide has one.
  final ProgrammeView? now;

  String? get nowTitle => now?.title;

  @override
  bool operator ==(Object other) =>
      other is EpgChannelView &&
      other.id == id &&
      other.displayName == displayName &&
      other.icon == icon &&
      other.now == now;

  @override
  int get hashCode => Object.hash(id, displayName, icon, now);

  @override
  String toString() => 'EpgChannelView($id "$displayName")';
}

/// First programme start and last programme end stored for a playlist
/// (UTC), for the guide's day picker.
typedef EpgDataRange = ({DateTime start, DateTime end});

// ---------------------------------------------------------------------------
// Collation
// ---------------------------------------------------------------------------

/// True when names sort with the Turkish alphabet: the app language is
/// Turkish, or it follows a Turkish system locale.
bool isTurkishCollation(SettingsStore settings) {
  final language = settings.get(AppSettings.language);
  if (language == 'tr') return true;
  if (language != 'system') return false;
  return PlatformDispatcher.instance.locale.languageCode == 'tr';
}

/// Sort key for locale-aware name ordering. Compare keys with
/// [String.compareTo] (see [compareCollated]).
///
/// * Case-insensitive; diacritics and punctuation are folded like search
///   text, so `Émile` sorts with `Emile` and `A-Z` with `A Z`.
/// * [turkish]: the Turkish alphabet order `a b c ç d e f g ğ h ı i j k l m
///   n o ö p r s ş t u ü v y z` (`I` is the capital of `ı`, `İ` of `i`).
/// * Digit runs compare as numbers (`TRT 2` before `TRT 10`).
String collationKey(String s, {bool turkish = false}) {
  final out = <int>[];
  var space = false;
  final n = s.length;
  for (var i = 0; i < n; i++) {
    final c = s.codeUnitAt(i);
    if (turkish) {
      final base = _turkishBase(c);
      if (base != 0) {
        if (space) {
          out.add(0x20);
          space = false;
        }
        out.add(base);
        if (c != 0x130) out.add(_turkishMarker);
        continue;
      }
    }
    int v;
    var lo = -1;
    if (c >= 0xD800 && c <= 0xDBFF && i + 1 < n) {
      final next = s.codeUnitAt(i + 1);
      if (next >= 0xDC00 && next <= 0xDFFF) {
        lo = next;
        i++;
        v = foldSupplementary(0x10000 + ((c - 0xD800) << 10) + (next - 0xDC00));
      } else {
        v = foldBoundary;
      }
    } else {
      v = foldUnit(c);
    }
    if (v == foldDrop) continue;
    if (v < foldSingle && v != foldKeepPair) {
      if (out.isNotEmpty) space = true;
      continue;
    }
    if (space) {
      out.add(0x20);
      space = false;
    }
    if (v == foldKeepPair) {
      out.add(c);
      if (lo >= 0) out.add(lo);
    } else if (v >= foldMultiBase) {
      out.addAll(foldMultiString(v).codeUnits);
    } else {
      out.add(v - foldSingle);
    }
  }
  final key = String.fromCharCodes(out);
  return key.replaceAllMapped(_digitRun, (m) {
    final digits = m[0]!.replaceFirst(_leadingZeros, '');
    return digits.length >= 10 ? digits : digits.padLeft(10, '0');
  });
}

/// Compares [a] and [b] by [collationKey], then by the raw text.
int compareCollated(String a, String b, {bool turkish = false}) {
  final c = collationKey(
    a,
    turkish: turkish,
  ).compareTo(collationKey(b, turkish: turkish));
  return c != 0 ? c : a.compareTo(b);
}

/// Sorts [items] by [nameOf] with [collationKey] (stable; keys are computed
/// once per item).
List<T> sortCollated<T>(
  Iterable<T> items,
  String Function(T item) nameOf, {
  bool turkish = false,
}) {
  final keyed = [
    for (final (i, item) in items.indexed)
      (i: i, key: collationKey(nameOf(item), turkish: turkish), item: item),
  ];
  keyed.sort((a, b) {
    final c = a.key.compareTo(b.key);
    if (c != 0) return c;
    final raw = nameOf(a.item).compareTo(nameOf(b.item));
    return raw != 0 ? raw : a.i.compareTo(b.i);
  });
  return [for (final e in keyed) e.item];
}

final RegExp _digitRun = RegExp(r'[0-9]+');
final RegExp _leadingZeros = RegExp(r'^0+(?=[0-9])');

/// Sorts after every letter that can follow the base letter.
const int _turkishMarker = 0x7F;

/// Base letter of the Turkish letters that have their own place in the
/// alphabet (`ç` → `c` + marker, `ı`/`I` → `h` + marker so it sorts before
/// `i`); `İ` → `i`. 0 for other characters.
int _turkishBase(int c) => switch (c) {
  0xC7 || 0xE7 => 0x63, // Ç ç
  0x11E || 0x11F => 0x67, // Ğ ğ
  0x49 || 0x131 => 0x68, // I ı
  0x130 => 0x69, // İ
  0xD6 || 0xF6 => 0x6F, // Ö ö
  0x15E || 0x15F => 0x73, // Ş ş
  0xDC || 0xFC => 0x75, // Ü ü
  _ => 0,
};

// ---------------------------------------------------------------------------
// PIN hashing
// ---------------------------------------------------------------------------

/// Salted SHA-256 hashes for the playlist access PIN and the parental PIN.
/// Stored as `v1$<base64url salt>$<hex digest>`; the raw PIN is never kept.
abstract final class PinHash {
  static const String _version = 'v1';
  static final RegExp _validPin = RegExp(r'^[0-9]{4,8}$');

  /// 4–8 digits.
  static bool isValid(String pin) => _validPin.hasMatch(pin);

  /// Hashes [pin] with 16 random salt bytes.
  static String hash(String pin, {math.Random? random}) {
    final rnd = random ?? math.Random.secure();
    final salt = Uint8List.fromList([
      for (var i = 0; i < 16; i++) rnd.nextInt(256),
    ]);
    return '$_version\$${base64Url.encode(salt)}\$${_digest(salt, pin)}';
  }

  /// Whether [pin] matches [stored] (false for a missing or corrupt value).
  static bool verify(String pin, String? stored) {
    if (stored == null) return false;
    final parts = stored.split(r'$');
    if (parts.length != 3 || parts[0] != _version) return false;
    final Uint8List salt;
    try {
      salt = base64Url.decode(parts[1]);
    } on FormatException {
      return false;
    }
    final expected = parts[2];
    final actual = _digest(salt, pin);
    if (actual.length != expected.length) return false;
    var diff = 0;
    for (var i = 0; i < actual.length; i++) {
      diff |= actual.codeUnitAt(i) ^ expected.codeUnitAt(i);
    }
    return diff == 0;
  }

  static String _digest(List<int> salt, String pin) =>
      sha256.convert([...salt, ...utf8.encode(pin)]).toString();
}

// ---------------------------------------------------------------------------
// Streams
// ---------------------------------------------------------------------------

/// A stream that runs [compute] when listened to, and again whenever one of
/// [tables] changes or the value of [settingsKey] changes after [settings]
/// notifies.
///
/// Runs never overlap: triggers that arrive during a run coalesce into one
/// more run. A result equal to the previous one (deep equality) is not
/// emitted again. Errors are forwarded and do not end the stream.
Stream<T> watchComputed<T>({
  required AppDatabase db,
  required Iterable<ResultSetImplementation<dynamic, dynamic>> tables,
  required Future<T> Function() compute,
  Listenable? settings,
  Object? Function()? settingsKey,
}) {
  late final StreamController<T> controller;
  StreamSubscription<Set<TableUpdate>>? sub;
  var running = false;
  var dirty = false;
  var cancelled = false;
  var hasLast = false;
  T? last;
  Object? lastKey;
  const equality = DeepCollectionEquality();

  Future<void> run() async {
    if (running) {
      dirty = true;
      return;
    }
    running = true;
    try {
      do {
        dirty = false;
        try {
          final value = await compute();
          if (cancelled) return;
          if (!hasLast || !equality.equals(last, value)) {
            last = value;
            hasLast = true;
            controller.add(value);
          }
        } catch (e, st) {
          if (!cancelled) controller.addError(e, st);
        }
      } while (dirty && !cancelled);
    } finally {
      running = false;
    }
  }

  void onSettings() {
    if (settingsKey != null) {
      final key = settingsKey();
      if (equality.equals(key, lastKey)) return;
      lastKey = key;
    }
    unawaited(run());
  }

  controller = StreamController<T>(
    onListen: () {
      lastKey = settingsKey?.call();
      sub = db
          .tableUpdates(TableUpdateQuery.onAllTables(tables))
          .listen((_) => unawaited(run()));
      settings?.addListener(onSettings);
      unawaited(run());
    },
    onCancel: () async {
      cancelled = true;
      settings?.removeListener(onSettings);
      await sub?.cancel();
    },
  );
  return controller.stream;
}

// ---------------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------------

String? _nonBlank(String? s) {
  final t = s?.trim();
  return (t == null || t.isEmpty) ? null : t;
}

/// `?, ?, ?` for [n] SQL variables.
String sqlPlaceholders(int n) => List.filled(n, '?').join(', ');

/// Reads a 0/1 (or NULL) SQL value as a bool.
bool sqlBool(Object? value) => value is int ? value != 0 : value == true;
