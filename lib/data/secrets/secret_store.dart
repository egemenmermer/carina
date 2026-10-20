import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;

/// Passwords, PINs and API keys.
///
/// Uses flutter_secure_storage (DPAPI-backed on Windows, Keychain on macOS).
/// If the platform store is unavailable (e.g. an unsigned macOS dev build
/// without keychain entitlements) it falls back to an obfuscated JSON file in
/// the app data folder and logs that once. Keys:
/// - `playlist.<id>.password` — Xtream password
/// - `playlist.<id>.accessPin` — playlist access PIN
/// - `playlist.<id>.parentalPin` — parental control PIN
/// - `app.tmdbKey` — TMDb API key or read-access token
/// - `app.openSubtitles` — JSON {username,password}
abstract class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String? value);
  Future<void> deleteWhere(bool Function(String key) test);

  static String playlistPassword(int id) => 'playlist.$id.password';
  static String playlistAccessPin(int id) => 'playlist.$id.accessPin';
  static String parentalPin(int id) => 'playlist.$id.parentalPin';
  static const tmdbKey = 'app.tmdbKey';
  static const openSubtitles = 'app.openSubtitles';
}

class PlatformSecretStore implements SecretStore {
  PlatformSecretStore({required String fallbackDir})
    : _fallback = _FileSecretStore(p.join(fallbackDir, 'secrets.bin'));

  final _FileSecretStore _fallback;
  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  bool? _secureWorks;

  Future<bool> _useSecure() async {
    if (_secureWorks != null) return _secureWorks!;
    try {
      await _secure.write(key: 'carina.probe', value: '1');
      _secureWorks = await _secure.read(key: 'carina.probe') == '1';
    } catch (e) {
      debugPrint('Secure storage unavailable, using file fallback: $e');
      _secureWorks = false;
    }
    return _secureWorks!;
  }

  @override
  Future<String?> read(String key) async {
    if (await _useSecure()) {
      try {
        return await _secure.read(key: key);
      } catch (_) {
        return _fallback.read(key);
      }
    }
    return _fallback.read(key);
  }

  @override
  Future<void> write(String key, String? value) async {
    if (await _useSecure()) {
      try {
        if (value == null) {
          await _secure.delete(key: key);
        } else {
          await _secure.write(key: key, value: value);
        }
        return;
      } catch (_) {
        // fall through to file store
      }
    }
    await _fallback.write(key, value);
  }

  @override
  Future<void> deleteWhere(bool Function(String key) test) async {
    if (await _useSecure()) {
      try {
        final all = await _secure.readAll();
        for (final k in all.keys.where(test)) {
          await _secure.delete(key: k);
        }
      } catch (_) {}
    }
    await _fallback.deleteWhere(test);
  }
}

/// In-memory store for tests.
class MemorySecretStore implements SecretStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> deleteWhere(bool Function(String key) test) async =>
      values.removeWhere((k, _) => test(k));
}

/// XOR-obfuscated JSON file. Not real encryption; only used when the
/// platform secure store is unavailable (development builds).
class _FileSecretStore {
  _FileSecretStore(this.path);

  final String path;
  // The app's former name; changing it would lose existing secrets.
  static const _salt = 'kanal-local-secrets';

  Map<String, String> _load() {
    final f = File(path);
    if (!f.existsSync()) return {};
    try {
      final bytes = f.readAsBytesSync();
      final plain = List<int>.generate(
        bytes.length,
        (i) => bytes[i] ^ _salt.codeUnitAt(i % _salt.length),
      );
      return Map<String, String>.from(jsonDecode(utf8.decode(plain)) as Map);
    } catch (_) {
      return {};
    }
  }

  void _save(Map<String, String> data) {
    final plain = utf8.encode(jsonEncode(data));
    final bytes = List<int>.generate(
      plain.length,
      (i) => plain[i] ^ _salt.codeUnitAt(i % _salt.length),
    );
    File(path)
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(bytes, flush: true);
  }

  Future<String?> read(String key) async => _load()[key];

  Future<void> write(String key, String? value) async {
    final data = _load();
    if (value == null) {
      data.remove(key);
    } else {
      data[key] = value;
    }
    _save(data);
  }

  Future<void> deleteWhere(bool Function(String key) test) async {
    final data = _load()..removeWhere((k, _) => test(k));
    _save(data);
  }
}

/// Overridden at bootstrap.
final secretStoreProvider = Provider<SecretStore>(
  (ref) => throw UnimplementedError('secretStoreProvider not overridden'),
);
