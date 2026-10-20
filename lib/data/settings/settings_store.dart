import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import 'setting_keys.dart';

export 'setting_keys.dart';

/// Synchronous, cached access to settings backed by the `settings` table.
///
/// All rows are loaded once at startup ([load]); reads are synchronous and
/// writes update the cache immediately and persist in the background.
class SettingsStore extends ChangeNotifier {
  SettingsStore(this._db);

  final AppDatabase _db;
  final Map<String, Object?> _cache = {};

  static String scopeOf(SettingScope scope, int? playlistId) {
    if (scope == SettingScope.app) return 'app';
    if (playlistId == null) {
      throw ArgumentError('playlistId is required for playlist settings');
    }
    return 'playlist:$playlistId';
  }

  static String _cacheKey(String scope, String key) => '$scope/$key';

  Future<void> load() async {
    final rows = await _db.select(_db.settings).get();
    _cache.clear();
    for (final row in rows) {
      try {
        _cache[_cacheKey(row.scope, row.key)] = jsonDecode(row.json);
      } on FormatException {
        // Ignore corrupt values; the default applies.
      }
    }
  }

  T get<T>(SettingKey<T> key, {int? playlistId}) {
    final scope = scopeOf(key.scope, playlistId);
    final ck = _cacheKey(scope, key.id);
    if (!_cache.containsKey(ck)) return key.defaultValue;
    final value = _cache[ck];
    if (value is T) return value;
    // JSON numbers may come back as int/double; maps as Map<String, dynamic>.
    if (T == double && value is num) return value.toDouble() as T;
    if (value is Map && key.defaultValue is Map?) {
      return Map<String, Object?>.from(value) as T;
    }
    return key.defaultValue;
  }

  bool isSet(SettingKey<Object?> key, {int? playlistId}) =>
      _cache.containsKey(_cacheKey(scopeOf(key.scope, playlistId), key.id));

  Future<void> set<T>(SettingKey<T> key, T value, {int? playlistId}) async {
    final scope = scopeOf(key.scope, playlistId);
    _cache[_cacheKey(scope, key.id)] = value;
    notifyListeners();
    await _db
        .into(_db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(
            scope: scope,
            key: key.id,
            json: jsonEncode(value),
          ),
        );
  }

  Future<void> reset(SettingKey<Object?> key, {int? playlistId}) async {
    final scope = scopeOf(key.scope, playlistId);
    _cache.remove(_cacheKey(scope, key.id));
    notifyListeners();
    await (_db.delete(
      _db.settings,
    )..where((s) => s.scope.equals(scope) & s.key.equals(key.id))).go();
  }

  /// Removes every setting of a deleted playlist.
  Future<void> clearPlaylist(int playlistId) async {
    final scope = scopeOf(SettingScope.playlist, playlistId);
    _cache.removeWhere((k, _) => k.startsWith('$scope/'));
    notifyListeners();
    await (_db.delete(_db.settings)..where((s) => s.scope.equals(scope))).go();
  }
}

/// Overridden at bootstrap with a loaded store.
final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => throw UnimplementedError('settingsStoreProvider not overridden'),
);

/// Bumps whenever any setting changes; watch it to rebuild on changes.
final settingsRevisionProvider = NotifierProvider<_SettingsRevision, int>(
  _SettingsRevision.new,
);

class _SettingsRevision extends Notifier<int> {
  @override
  int build() {
    final store = ref.watch(settingsStoreProvider);
    void listener() => state = state + 1;
    store.addListener(listener);
    ref.onDispose(() => store.removeListener(listener));
    return 0;
  }
}

extension SettingsRefX on WidgetRef {
  /// Reads a setting and rebuilds the widget when settings change.
  T watchSetting<T>(SettingKey<T> key, {int? playlistId}) {
    watch(settingsRevisionProvider);
    return read(settingsStoreProvider).get(key, playlistId: playlistId);
  }

  T readSetting<T>(SettingKey<T> key, {int? playlistId}) =>
      read(settingsStoreProvider).get(key, playlistId: playlistId);

  Future<void> writeSetting<T>(SettingKey<T> key, T value, {int? playlistId}) =>
      read(settingsStoreProvider).set(key, value, playlistId: playlistId);
}

extension SettingsProviderRefX on Ref {
  T watchSetting<T>(SettingKey<T> key, {int? playlistId}) {
    watch(settingsRevisionProvider);
    return read(settingsStoreProvider).get(key, playlistId: playlistId);
  }
}

/// Helper for `Value<T>` in companions where a nullable column is optional.
Value<T> valueOrAbsent<T>(T? v) => v == null ? const Value.absent() : Value(v);
