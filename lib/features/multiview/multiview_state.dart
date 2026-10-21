/// The multi-channel session of a playlist: which channels are open, the
/// layout, the focused tile. Plain data that outlives the screen (engines
/// belong to [MultiviewScreen] and are disposed with it).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/platform/form_factor.dart';
import 'multiview_layout.dart';

/// Maximum number of tiles on desktop.
const int kMultiviewMaxTiles = 4;

/// Maximum number of tiles on a TV (2 decoders; tune on a device).
const int kMultiviewMaxTilesTv = 2;

/// Tile cap of [formFactor].
int multiviewMaxTilesFor(FormFactor formFactor) =>
    formFactor.isTv ? kMultiviewMaxTilesTv : kMultiviewMaxTiles;

/// One open channel.
@immutable
class MultiviewTile {
  const MultiviewTile({required this.id, required this.channelId});

  /// Stable id (survives channel changes and swaps).
  final int id;
  final String channelId;

  MultiviewTile withChannel(String channelId) =>
      MultiviewTile(id: id, channelId: channelId);

  @override
  bool operator ==(Object other) =>
      other is MultiviewTile && other.id == id && other.channelId == channelId;

  @override
  int get hashCode => Object.hash(id, channelId);

  @override
  String toString() => 'MultiviewTile($id: $channelId)';
}

@immutable
class MultiviewSession {
  const MultiviewSession({
    this.tiles = const [],
    this.layout = MultiviewLayout.sideBySide,
    this.focused = 0,
    this.fullTile,
    this.pickerRequested = false,
    this.maxTiles = kMultiviewMaxTiles,
  });

  /// Open channels; index 0 is the main tile.
  final List<MultiviewTile> tiles;
  final MultiviewLayout layout;

  /// Index of the tile with audio.
  final int focused;

  /// Index of the tile shown full screen inside multi-channel, or null.
  final int? fullTile;

  /// The screen should open the channel picker once (player "Add channel").
  final bool pickerRequested;

  /// Most tiles this device opens ([multiviewMaxTilesFor]).
  final int maxTiles;

  /// Layouts of the picker that fit [maxTiles].
  List<MultiviewLayout> get layouts => MultiviewLayout.available(maxTiles);

  bool get isEmpty => tiles.isEmpty;
  bool get isFull => tiles.length >= maxTiles;
  bool contains(String channelId) => tiles.any((t) => t.channelId == channelId);

  MultiviewTile? get focusedTile =>
      tiles.isEmpty ? null : tiles[clampIndex(focused, tiles.length)];

  MultiviewSession copyWith({
    List<MultiviewTile>? tiles,
    MultiviewLayout? layout,
    int? focused,
    Object? fullTile = _unset,
    bool? pickerRequested,
  }) => MultiviewSession(
    tiles: tiles ?? this.tiles,
    layout: layout ?? this.layout,
    focused: focused ?? this.focused,
    fullTile: identical(fullTile, _unset) ? this.fullTile : fullTile as int?,
    pickerRequested: pickerRequested ?? this.pickerRequested,
    maxTiles: maxTiles,
  );

  @override
  bool operator ==(Object other) =>
      other is MultiviewSession &&
      listEquals(other.tiles, tiles) &&
      other.layout == layout &&
      other.focused == focused &&
      other.fullTile == fullTile &&
      other.pickerRequested == pickerRequested &&
      other.maxTiles == maxTiles;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(tiles),
    layout,
    focused,
    fullTile,
    pickerRequested,
    maxTiles,
  );

  @override
  String toString() =>
      'MultiviewSession(${layout.name}, focused $focused, $tiles)';
}

const Object _unset = Object();

/// Mutations of a playlist's [MultiviewSession].
class MultiviewSessionNotifier extends Notifier<MultiviewSession> {
  MultiviewSessionNotifier(this.playlistId);

  final int playlistId;
  int _nextId = 1;

  @override
  MultiviewSession build() => MultiviewSession(
    maxTiles: multiviewMaxTilesFor(ref.read(formFactorProvider)),
  );

  /// Adds [channelId] as a new tile and focuses it. Returns false when the
  /// session is full. A channel that is already open is focused instead.
  bool add(String channelId) {
    final s = state;
    final existing = s.tiles.indexWhere((t) => t.channelId == channelId);
    if (existing >= 0) {
      state = s.copyWith(focused: existing);
      return true;
    }
    if (s.isFull) return false;
    final tiles = [
      ...s.tiles,
      MultiviewTile(id: _nextId++, channelId: channelId),
    ];
    state = s.copyWith(
      tiles: tiles,
      focused: tiles.length - 1,
      layout: MultiviewLayout.fitting(tiles.length, s.layout, s.maxTiles),
    );
    return true;
  }

  /// Replaces the session with [channelIds] (at most [MultiviewSession.maxTiles])
  /// in [layout].
  void replace(List<String> channelIds, {MultiviewLayout? layout}) {
    final ids = <String>[];
    for (final id in channelIds) {
      if (!ids.contains(id)) ids.add(id);
      if (ids.length == state.maxTiles) break;
    }
    final tiles = [
      for (final id in ids) MultiviewTile(id: _nextId++, channelId: id),
    ];
    final wanted = layout ?? state.layout;
    state = MultiviewSession(
      tiles: tiles,
      layout: MultiviewLayout.fitting(tiles.length, wanted, state.maxTiles),
      maxTiles: state.maxTiles,
    );
  }

  /// Closes the tile at [index].
  void close(int index) {
    final s = state;
    if (index < 0 || index >= s.tiles.length) return;
    final tiles = [...s.tiles]..removeAt(index);
    var focused = s.focused;
    if (index < focused || focused >= tiles.length) focused--;
    state = s.copyWith(
      tiles: tiles,
      focused: clampIndex(focused, tiles.length),
      fullTile: null,
    );
  }

  /// Shows another channel in the tile at [index].
  void changeChannel(int index, String channelId) {
    final s = state;
    if (index < 0 || index >= s.tiles.length) return;
    final other = s.tiles.indexWhere((t) => t.channelId == channelId);
    if (other >= 0 && other != index) {
      // Already open elsewhere: focus it instead of opening it twice.
      state = s.copyWith(focused: other);
      return;
    }
    final tiles = [...s.tiles];
    tiles[index] = tiles[index].withChannel(channelId);
    state = s.copyWith(tiles: tiles, focused: index);
  }

  /// Swaps the tile at [index] with the main tile (index 0).
  void swapWithMain(int index) {
    final s = state;
    if (index <= 0 || index >= s.tiles.length) return;
    final tiles = [...s.tiles];
    final main = tiles[0];
    tiles[0] = tiles[index];
    tiles[index] = main;
    var focused = s.focused;
    if (focused == index) {
      focused = 0;
    } else if (focused == 0) {
      focused = index;
    }
    state = s.copyWith(tiles: tiles, focused: focused);
  }

  void focus(int index) {
    final s = state;
    if (s.tiles.isEmpty) return;
    final i = clampIndex(index, s.tiles.length);
    if (i != s.focused) state = s.copyWith(focused: i);
  }

  void setLayout(MultiviewLayout layout) {
    final s = state;
    if (s.tiles.length > layout.slots || layout.slots > s.maxTiles) return;
    state = s.copyWith(layout: layout, fullTile: null);
  }

  /// Full screen inside multi-channel for [index] (null: back to the grid).
  void setFullTile(int? index) {
    final s = state;
    if (index != null && (index < 0 || index >= s.tiles.length)) return;
    state = s.copyWith(fullTile: index, focused: index ?? s.focused);
  }

  void requestPicker(bool value) {
    if (state.pickerRequested != value) {
      state = state.copyWith(pickerRequested: value);
    }
  }

  /// Closes every tile.
  void clear() =>
      state = MultiviewSession(layout: state.layout, maxTiles: state.maxTiles);
}

/// The multi-channel session of a playlist (kept for the app session).
final multiviewSessionProvider =
    NotifierProvider.family<MultiviewSessionNotifier, MultiviewSession, int>(
      MultiviewSessionNotifier.new,
    );
