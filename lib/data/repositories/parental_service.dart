/// Parental control: the parental PIN, lock checks with session unlocks, and
/// the locked-item lists.
library;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_paths.dart' show appDatabaseProvider;
import '../db/database.dart';
import '../secrets/secret_store.dart';
import 'category_repository.dart';
import 'live_repository.dart';
import 'repository_models.dart';

/// The parental PIN (salted hash in [SecretStore] under
/// `playlist.<id>.parentalPin`) and lock state of channels and categories.
///
/// Locks are stored flags (`channels.locked`, `categories.locked`); a
/// correct PIN unlocks content for the session through
/// [parentalSessionProvider], which the UI clears when the playlist is
/// switched (and which is empty after a restart).
class ParentalService {
  ParentalService(this._db, this._secrets, this._live, this._categories);

  final AppDatabase _db;
  final SecretStore _secrets;
  final LiveRepository _live;
  final CategoryRepository _categories;

  // -------------------------------------------------------------------------
  // PIN
  // -------------------------------------------------------------------------

  Future<bool> hasPin(int playlistId) async =>
      await _secrets.read(SecretStore.parentalPin(playlistId)) != null;

  /// Sets or replaces the PIN (4–8 digits; the UI uses 4).
  Future<void> setPin(int playlistId, String pin) async {
    if (!PinHash.isValid(pin)) {
      throw ArgumentError.value('***', 'pin', 'must be 4–8 digits');
    }
    await _secrets.write(
      SecretStore.parentalPin(playlistId),
      PinHash.hash(pin),
    );
  }

  /// Whether [pin] is the parental PIN. Without a PIN there is nothing to
  /// protect, so any input passes; the UI checks [hasPin] first and skips
  /// the pad in that case.
  Future<bool> verifyPin(int playlistId, String pin) async {
    final stored = await _secrets.read(SecretStore.parentalPin(playlistId));
    return stored == null || PinHash.verify(pin, stored);
  }

  /// Replaces the PIN after checking the current one; false when
  /// [currentPin] is wrong.
  Future<bool> changePin(
    int playlistId,
    String currentPin,
    String newPin,
  ) async {
    if (!await verifyPin(playlistId, currentPin)) return false;
    await setPin(playlistId, newPin);
    return true;
  }

  /// Removes the PIN. Lock flags stay; without a PIN they no longer ask.
  Future<void> clearPin(int playlistId) =>
      _secrets.write(SecretStore.parentalPin(playlistId), null);

  // -------------------------------------------------------------------------
  // Lock checks
  // -------------------------------------------------------------------------

  /// Whether opening [channel] must ask for the PIN: the channel or its
  /// category is locked and [session] has not unlocked it (the channel, its
  /// category, or everything of the playlist).
  bool isLocked(
    ChannelView channel, [
    ParentalSessionState session = ParentalSessionState.empty,
  ]) {
    if (!channel.locked) return false;
    return !session.isChannelUnlocked(
      channel.playlistId,
      channel.providerId,
      categoryId: channel.row.categoryId,
    );
  }

  /// Whether opening [category] must ask for the PIN.
  bool isCategoryLocked(
    CategoryView category, [
    ParentalSessionState session = ParentalSessionState.empty,
  ]) {
    final row = category.row;
    if (row == null || !row.locked) return false;
    return !session.isCategoryUnlocked(
      row.playlistId,
      category.kind,
      row.providerId,
    );
  }

  // -------------------------------------------------------------------------
  // Mutations and lists
  // -------------------------------------------------------------------------

  /// "Add to Parental Control" / unlock in Settings.
  Future<void> lockChannel(int playlistId, String providerId, bool locked) =>
      _live.setLocked(playlistId, providerId, locked);

  /// "Add category to Parental Control" / unlock in Settings.
  Future<void> lockCategory(
    int playlistId,
    SectionKind kind,
    String providerId,
    bool locked,
  ) => _categories.setLocked(playlistId, kind, providerId, locked);

  /// Locked channels and categories for Settings → Parental Control.
  Stream<LockedItems> lockedItems(int playlistId) => watchComputed(
    db: _db,
    tables: [_db.channels, _db.categories],
    compute: () => lockedItemsOnce(playlistId),
  );

  Future<LockedItems> lockedItemsOnce(int playlistId) async => LockedItems(
    channels: await _live.lockedChannelsOnce(playlistId),
    categories: await _categories.lockedCategoriesOnce(playlistId),
  );
}

// ---------------------------------------------------------------------------
// Session unlocks
// ---------------------------------------------------------------------------

/// What the parental PIN unlocked in this session, for one playlist.
@immutable
class ParentalSessionState {
  const ParentalSessionState({
    this.playlistId,
    this.allUnlocked = false,
    this.channels = const {},
    this.categories = const {},
  });

  static const ParentalSessionState empty = ParentalSessionState();

  /// The playlist the unlocks belong to (null = nothing unlocked).
  final int? playlistId;

  /// Everything of [playlistId] is unlocked (also reveals content that
  /// parental mode `hide` leaves out).
  final bool allUnlocked;

  /// Unlocked channel provider ids.
  final Set<String> channels;

  /// Unlocked categories as [categoryKey]s.
  final Set<String> categories;

  static String categoryKey(SectionKind kind, String providerId) =>
      '${kind.name}:$providerId';

  bool allUnlockedFor(int playlistId) =>
      allUnlocked && this.playlistId == playlistId;

  bool isChannelUnlocked(
    int playlistId,
    String providerId, {
    String? categoryId,
  }) {
    if (this.playlistId != playlistId) return false;
    if (allUnlocked || channels.contains(providerId)) return true;
    return categoryId != null &&
        categories.contains(categoryKey(SectionKind.live, categoryId));
  }

  bool isCategoryUnlocked(
    int playlistId,
    SectionKind kind,
    String providerId,
  ) =>
      this.playlistId == playlistId &&
      (allUnlocked || categories.contains(categoryKey(kind, providerId)));

  @override
  bool operator ==(Object other) =>
      other is ParentalSessionState &&
      other.playlistId == playlistId &&
      other.allUnlocked == allUnlocked &&
      const SetEquality<String>().equals(other.channels, channels) &&
      const SetEquality<String>().equals(other.categories, categories);

  @override
  int get hashCode => Object.hash(
    playlistId,
    allUnlocked,
    const SetEquality<String>().hash(channels),
    const SetEquality<String>().hash(categories),
  );

  @override
  String toString() =>
      'ParentalSessionState($playlistId, all: $allUnlocked, '
      '${channels.length} channels, ${categories.length} categories)';
}

/// Session unlocks. Unlocks for another playlist replace the
/// current ones; call [clear] (or [onPlaylistOpened]) when the playlist is
/// switched.
class ParentalSession extends Notifier<ParentalSessionState> {
  @override
  ParentalSessionState build() => ParentalSessionState.empty;

  ParentalSessionState _for(int playlistId) => state.playlistId == playlistId
      ? state
      : ParentalSessionState(playlistId: playlistId);

  void unlockChannel(int playlistId, String providerId) {
    final s = _for(playlistId);
    state = ParentalSessionState(
      playlistId: playlistId,
      allUnlocked: s.allUnlocked,
      channels: {...s.channels, providerId},
      categories: s.categories,
    );
  }

  void unlockCategory(int playlistId, SectionKind kind, String providerId) {
    final s = _for(playlistId);
    state = ParentalSessionState(
      playlistId: playlistId,
      allUnlocked: s.allUnlocked,
      channels: s.channels,
      categories: {
        ...s.categories,
        ParentalSessionState.categoryKey(kind, providerId),
      },
    );
  }

  /// After a correct PIN for [channel]: unlocks the channel and, when the
  /// lock comes from its category, the category too (so browsing it does
  /// not ask again).
  void unlockFor(ChannelView channel) {
    final categoryId = channel.row.categoryId;
    final s = _for(channel.playlistId);
    state = ParentalSessionState(
      playlistId: channel.playlistId,
      allUnlocked: s.allUnlocked,
      channels: {...s.channels, channel.providerId},
      categories: {
        ...s.categories,
        if (channel.categoryLocked && categoryId != null)
          ParentalSessionState.categoryKey(SectionKind.live, categoryId),
      },
    );
  }

  /// Unlocks every locked item of [playlistId] for the session.
  void unlockAll(int playlistId) => state = ParentalSessionState(
    playlistId: playlistId,
    allUnlocked: true,
    channels: _for(playlistId).channels,
    categories: _for(playlistId).categories,
  );

  /// Forgets every unlock.
  void clear() => state = ParentalSessionState.empty;

  /// Clears the unlocks when another playlist is opened.
  void onPlaylistOpened(int playlistId) {
    if (state.playlistId != null && state.playlistId != playlistId) clear();
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final parentalSessionProvider =
    NotifierProvider<ParentalSession, ParentalSessionState>(
      ParentalSession.new,
    );

final parentalServiceProvider = Provider<ParentalService>(
  (ref) => ParentalService(
    ref.watch(appDatabaseProvider),
    ref.watch(secretStoreProvider),
    ref.watch(liveRepositoryProvider),
    ref.watch(categoryRepositoryProvider),
  ),
);

/// Settings → Parental Control lists.
final lockedItemsProvider = StreamProvider.autoDispose.family<LockedItems, int>(
  (ref, playlistId) =>
      ref.watch(parentalServiceProvider).lockedItems(playlistId),
);
