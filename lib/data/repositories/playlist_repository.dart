/// Playlists: the Manager list, the add/edit wizard, avatars, the playlist
/// access PIN and the Xtream credentials.
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_paths.dart' show appDatabaseProvider;
import '../db/database.dart';
import '../secrets/secret_store.dart';
import '../settings/settings_store.dart';
import '../sources/m3u/m3u_models.dart' show M3uHeader;
import '../sources/xtream/xtream_credentials.dart';
import '../sources/xtream/xtream_models.dart' show XtreamAccount;
import '../sources/xtream/xtream_urls.dart' show XtreamUrls;
import 'repository_models.dart' show PinHash;

/// Every field of the add/edit wizard.
///
/// [epgUrl] is the text of the EPG URL field: `null`, or the URL the wizard
/// auto-fills for Xtream (`{server}/xmltv.php?username=…&password=…`),
/// means "the default EPG" and is stored as `null` (so the password never
/// reaches the database); `''` means "no XMLTV" (Xtream then uses the short
/// EPG); anything else is a custom URL. For M3U, the default is the
/// playlist's `url-tvg` header.
@immutable
class PlaylistDraft {
  const PlaylistDraft({
    required this.name,
    required this.type,
    this.server,
    this.username,
    this.password,
    this.m3uUrl,
    this.epgUrl,
    this.epgShiftHours = 0,
    this.reloadFrequencyHours = 72,
    this.userAgent,
    this.avatarId,
  });

  final String name;
  final PlaylistType type;

  /// Xtream base URL (`https://domain.com:8080`).
  final String? server;
  final String? username;

  /// Xtream password (stored in [SecretStore], never in the database). On
  /// [PlaylistRepository.update], null keeps the stored password.
  final String? password;

  /// M3U playlist URL, or the file path for [PlaylistType.m3uFile].
  final String? m3uUrl;
  final String? epgUrl;

  /// −12…+12.
  final int epgShiftHours;

  /// 0 = never; 12, 24, 72 (default) or 168.
  final int reloadFrequencyHours;

  /// Custom User-Agent (M3U wizard field).
  final String? userAgent;
  final String? avatarId;

  /// The XMLTV URL the wizard auto-fills for these Xtream credentials.
  String? get defaultEpgUrl {
    final s = server;
    final u = username;
    final p = password;
    if (type != PlaylistType.xtream || s == null || u == null || p == null) {
      return null;
    }
    return XtreamUrls(s, u, p).xmltv();
  }

  /// Copy with the given non-null fields replaced.
  PlaylistDraft copyWith({
    String? name,
    PlaylistType? type,
    String? server,
    String? username,
    String? password,
    String? m3uUrl,
    String? epgUrl,
    int? epgShiftHours,
    int? reloadFrequencyHours,
    String? userAgent,
    String? avatarId,
  }) => PlaylistDraft(
    name: name ?? this.name,
    type: type ?? this.type,
    server: server ?? this.server,
    username: username ?? this.username,
    password: password ?? this.password,
    m3uUrl: m3uUrl ?? this.m3uUrl,
    epgUrl: epgUrl ?? this.epgUrl,
    epgShiftHours: epgShiftHours ?? this.epgShiftHours,
    reloadFrequencyHours: reloadFrequencyHours ?? this.reloadFrequencyHours,
    userAgent: userAgent ?? this.userAgent,
    avatarId: avatarId ?? this.avatarId,
  );

  /// Never prints credentials or URLs.
  @override
  String toString() => 'PlaylistDraft("$name", ${type.name})';
}

/// What an edit changed: [source] (server, username, password, M3U URL or
/// type → reload everything) and [epg] (EPG URL or time shift, or [source]
/// → reload the EPG).
typedef PlaylistChanges = ({bool source, bool epg});

/// Create, edit and delete playlists. Passwords and PINs live in
/// [SecretStore] (`playlist.<id>.*`), never in the database.
class PlaylistRepository {
  PlaylistRepository(
    this._db,
    this._secrets,
    this._settings, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final SecretStore _secrets;
  final SettingsStore _settings;
  final DateTime Function() _clock;

  final Map<int, XtreamCredentials> _credentials = {};
  final Map<int, (String, XtreamAccount?)> _accounts = {};
  final Map<int, (String, M3uHeader?)> _headers = {};

  // -------------------------------------------------------------------------
  // Queries
  // -------------------------------------------------------------------------

  /// Every playlist in Manager order.
  Stream<List<PlaylistRow>> watchAll() => _ordered().watch();

  Future<List<PlaylistRow>> getAll() => _ordered().get();

  Future<PlaylistRow?> get(int id) => _byId(id).getSingleOrNull();

  Stream<PlaylistRow?> watch(int id) => _byId(id).watchSingleOrNull();

  SimpleSelectStatement<$PlaylistsTable, PlaylistRow> _ordered() =>
      _db.select(_db.playlists)..orderBy([
        (p) => OrderingTerm(expression: p.sortIndex),
        (p) => OrderingTerm(expression: p.id),
      ]);

  SimpleSelectStatement<$PlaylistsTable, PlaylistRow> _byId(int id) =>
      _db.select(_db.playlists)..where((p) => p.id.equals(id));

  // -------------------------------------------------------------------------
  // Create / edit / delete
  // -------------------------------------------------------------------------

  /// Inserts a playlist and stores its password; returns the new id. Throws
  /// [ArgumentError] when a required field of the type is missing.
  Future<int> create(PlaylistDraft draft) async {
    final fields = _validate(draft);
    final id = await _db.transaction(() async {
      final maxIndex = _db.playlists.sortIndex.max();
      final last = await (_db.selectOnly(
        _db.playlists,
      )..addColumns([maxIndex])).map((r) => r.read(maxIndex)).getSingle();
      return _db
          .into(_db.playlists)
          .insert(
            PlaylistsCompanion.insert(
              name: fields.name,
              type: draft.type,
              server: Value(fields.server),
              username: Value(fields.username),
              m3uUrl: Value(fields.m3uUrl),
              epgUrl: Value(_storedEpgUrl(draft, fields)),
              epgShiftHours: Value(draft.epgShiftHours),
              reloadFrequencyHours: Value(draft.reloadFrequencyHours),
              userAgent: Value(_nonBlank(draft.userAgent)),
              avatarId: Value(_nonBlank(draft.avatarId)),
              sortIndex: Value(last == null ? 0 : last + 1),
              createdAt: _clock(),
            ),
          );
    });
    if (draft.type == PlaylistType.xtream) {
      await _secrets.write(SecretStore.playlistPassword(id), draft.password);
    }
    return id;
  }

  /// Saves an edit; returns true when the source changed (server, username,
  /// password, M3U URL or type) and the caller must reload the playlist.
  /// See [updateWithChanges] for the EPG flag.
  Future<bool> update(int id, PlaylistDraft draft) async =>
      (await updateWithChanges(id, draft)).source;

  /// [update] that also reports whether the EPG source changed.
  Future<PlaylistChanges> updateWithChanges(int id, PlaylistDraft draft) async {
    final row = await get(id);
    if (row == null) throw StateError('Playlist $id not found');
    final passwordKey = SecretStore.playlistPassword(id);
    final oldPassword = await _secrets.read(passwordKey);
    final isXtream = draft.type == PlaylistType.xtream;
    final password = isXtream ? (draft.password ?? oldPassword) : null;
    final fields = _validate(draft, password: password);
    final source =
        row.type != draft.type ||
        row.server != fields.server ||
        row.username != fields.username ||
        row.m3uUrl != fields.m3uUrl ||
        (isXtream && password != oldPassword);
    // The edit form pre-fills the default URL of the old credentials; it
    // is still "the default" when the credentials change.
    final epgUrl = _storedEpgUrl(
      draft,
      fields,
      previous: row.type == PlaylistType.xtream && row.epgUrl == null
          ? (row.server, row.username, oldPassword)
          : null,
    );
    final epg =
        source ||
        row.epgUrl != epgUrl ||
        row.epgShiftHours != draft.epgShiftHours;
    await (_db.update(_db.playlists)..where((p) => p.id.equals(id))).write(
      PlaylistsCompanion(
        name: Value(fields.name),
        type: Value(draft.type),
        server: Value(fields.server),
        username: Value(fields.username),
        m3uUrl: Value(fields.m3uUrl),
        epgUrl: Value(epgUrl),
        epgShiftHours: Value(draft.epgShiftHours),
        reloadFrequencyHours: Value(draft.reloadFrequencyHours),
        userAgent: Value(_nonBlank(draft.userAgent)),
        avatarId: Value(_nonBlank(draft.avatarId)),
        // The stored account belongs to the old source.
        accountJson: source ? const Value(null) : const Value.absent(),
        m3uHeaderJson: source ? const Value(null) : const Value.absent(),
      ),
    );
    if (password != oldPassword) await _secrets.write(passwordKey, password);
    _forget(id);
    return (source: source, epg: epg);
  }

  /// The wizard fields of a stored playlist, for the edit form. The EPG URL
  /// is the effective one (the Xtream default with credentials, or the M3U
  /// header URL) unless it was customized or switched off.
  Future<PlaylistDraft?> draftFor(int id) async {
    final row = await get(id);
    if (row == null) return null;
    final password = row.type == PlaylistType.xtream
        ? await _secrets.read(SecretStore.playlistPassword(id))
        : null;
    final draft = PlaylistDraft(
      name: row.name,
      type: row.type,
      server: row.server,
      username: row.username,
      password: password,
      m3uUrl: row.m3uUrl,
      epgUrl: row.epgUrl,
      epgShiftHours: row.epgShiftHours,
      reloadFrequencyHours: row.reloadFrequencyHours,
      userAgent: row.userAgent,
      avatarId: row.avatarId,
    );
    if (row.epgUrl != null) return draft;
    final effective = row.type == PlaylistType.xtream
        ? draft.defaultEpgUrl
        : m3uHeader(row)?.tvgUrls.firstOrNull;
    return effective == null ? draft : draft.copyWith(epgUrl: effective);
  }

  /// Deletes the playlist with everything that belongs to it: rows (foreign
  /// keys cascade), its search index rows, its secrets
  /// (`playlist.<id>.*`) and its settings. Cancel a running import first.
  Future<void> delete(int id) async {
    await _db.transaction(() async {
      await _db.customUpdate(
        'DELETE FROM search_index WHERE playlist_id = ?',
        variables: [Variable.withInt(id)],
        updates: {_db.searchIndex},
        updateKind: UpdateKind.delete,
      );
      await _db.customUpdate(
        'DELETE FROM programme_search WHERE playlist_id = ?',
        variables: [Variable.withInt(id)],
        updates: {_db.programmeSearch},
        updateKind: UpdateKind.delete,
      );
      await (_db.delete(_db.playlists)..where((p) => p.id.equals(id))).go();
    });
    final prefix = 'playlist.$id.';
    await _secrets.deleteWhere((key) => key.startsWith(prefix));
    await _settings.clearPlaylist(id);
    if (_settings.get(AppSettings.lastPlaylistId) == id) {
      await _settings.reset(AppSettings.lastPlaylistId);
    }
    _forget(id);
  }

  Future<void> setAvatar(int id, String? avatarId) =>
      (_db.update(_db.playlists)..where((p) => p.id.equals(id))).write(
        PlaylistsCompanion(avatarId: Value(_nonBlank(avatarId))),
      );

  Future<void> rename(int id, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(name, 'name', 'empty');
    return (_db.update(_db.playlists)..where((p) => p.id.equals(id))).write(
      PlaylistsCompanion(name: Value(trimmed)),
    );
  }

  /// Manager order: [ids] first, in this order.
  Future<void> reorder(List<int> ids) => _db.transaction(() async {
    for (final (index, id) in ids.indexed) {
      await (_db.update(_db.playlists)..where((p) => p.id.equals(id))).write(
        PlaylistsCompanion(sortIndex: Value(index)),
      );
    }
  });

  // -------------------------------------------------------------------------
  // Access PIN (salted SHA-256 in SecretStore `playlist.<id>.accessPin`)
  // -------------------------------------------------------------------------

  /// Sets or replaces the access PIN (4–8 digits).
  Future<void> setAccessPin(int id, String pin) async {
    if (!PinHash.isValid(pin)) {
      throw ArgumentError.value('***', 'pin', 'must be 4–8 digits');
    }
    await _secrets.write(SecretStore.playlistAccessPin(id), PinHash.hash(pin));
    await _setHasAccessPin(id, true);
  }

  Future<void> removeAccessPin(int id) async {
    await _secrets.write(SecretStore.playlistAccessPin(id), null);
    await _setHasAccessPin(id, false);
  }

  /// Whether [pin] opens the playlist. Without a stored PIN (none set, or
  /// the secure store lost it) there is nothing to protect: returns true and
  /// clears `hasAccessPin`.
  Future<bool> verifyAccessPin(int id, String pin) async {
    final stored = await _secrets.read(SecretStore.playlistAccessPin(id));
    if (stored == null) {
      await _setHasAccessPin(id, false);
      return true;
    }
    return PinHash.verify(pin, stored);
  }

  Future<void> _setHasAccessPin(int id, bool value) =>
      (_db.update(_db.playlists)
            ..where((p) => p.id.equals(id) & p.hasAccessPin.equals(!value)))
          .write(PlaylistsCompanion(hasAccessPin: Value(value)));

  // -------------------------------------------------------------------------
  // Source details
  // -------------------------------------------------------------------------

  /// Server, username and password of an Xtream playlist; null for other
  /// types or when the password is missing. Cached per playlist.
  Future<XtreamCredentials?> xtreamCredentials(int id) async {
    final cached = _credentials[id];
    if (cached != null) return cached;
    final row = await get(id);
    final server = row?.server;
    final username = row?.username;
    if (row == null ||
        row.type != PlaylistType.xtream ||
        server == null ||
        username == null) {
      return null;
    }
    final password = await _secrets.read(SecretStore.playlistPassword(id));
    if (password == null) return null;
    return _credentials[id] = XtreamCredentials(server, username, password);
  }

  /// The Xtream account stored by the last import (`accountJson`), or null.
  XtreamAccount? account(PlaylistRow row) {
    final json = row.accountJson;
    if (json == null || json.isEmpty) return null;
    final cached = _accounts[row.id];
    if (cached != null && cached.$1 == json) return cached.$2;
    XtreamAccount? account;
    try {
      account = XtreamAccount.fromJson(jsonDecode(json));
    } on FormatException {
      account = null;
    }
    _accounts[row.id] = (json, account);
    return account;
  }

  /// The `#EXTM3U` header defaults stored by the last M3U import, or null.
  M3uHeader? m3uHeader(PlaylistRow row) {
    final json = row.m3uHeaderJson;
    if (json == null || json.isEmpty) return null;
    final cached = _headers[row.id];
    if (cached != null && cached.$1 == json) return cached.$2;
    M3uHeader? header;
    try {
      final decoded = jsonDecode(json);
      header = decoded is Map<String, Object?>
          ? M3uHeader.fromJson(decoded)
          : null;
    } on FormatException {
      header = null;
    } on TypeError {
      header = null;
    }
    _headers[row.id] = (json, header);
    return header;
  }

  /// The XMLTV URL to download: the custom URL, else the default (Xtream:
  /// `{server}/xmltv.php` with the stored credentials; M3U: the first
  /// `url-tvg` of the header). Null when switched off or unknown.
  Future<String?> epgUrlFor(int id) async {
    final row = await get(id);
    if (row == null) return null;
    final password = row.type == PlaylistType.xtream && row.epgUrl == null
        ? (await xtreamCredentials(id))?.password
        : null;
    return effectiveEpgUrl(row, password: password, header: m3uHeader(row));
  }

  // -------------------------------------------------------------------------

  void _forget(int id) {
    _credentials.remove(id);
    _accounts.remove(id);
    _headers.remove(id);
  }

  _Fields _validate(PlaylistDraft d, {String? password}) {
    final name = d.name.trim();
    if (name.isEmpty) throw ArgumentError.value(d.name, 'name', 'empty');
    switch (d.type) {
      case PlaylistType.xtream:
        final server = _nonBlank(d.server);
        final username = _nonBlank(d.username);
        if (server == null) throw ArgumentError.notNull('server');
        if (username == null) throw ArgumentError.notNull('username');
        if ((password ?? d.password) == null) {
          throw ArgumentError.notNull('password');
        }
        return _Fields(
          name: name,
          server: normalizeXtreamServer(server),
          username: username,
          password: password ?? d.password!,
        );
      case PlaylistType.m3u || PlaylistType.m3uFile:
        final url = _nonBlank(d.m3uUrl);
        if (url == null) throw ArgumentError.notNull('m3uUrl');
        return _Fields(name: name, m3uUrl: url);
    }
  }

  /// See [PlaylistDraft.epgUrl]. [previous] are the credentials before an
  /// edit whose default URL also counts as the default.
  String? _storedEpgUrl(
    PlaylistDraft d,
    _Fields f, {
    (String?, String?, String?)? previous,
  }) {
    final raw = d.epgUrl;
    if (raw == null) return null;
    final url = raw.trim();
    if (url.isEmpty) return '';
    // The old default (also after switching to M3U) never gets stored: it
    // carries the old password.
    if (previous case (final String s, final String u, final String p)
        when _isDefaultXtreamEpg(url, s, u, p)) {
      return null;
    }
    if (d.type == PlaylistType.xtream &&
        _isDefaultXtreamEpg(url, f.server!, f.username!, f.password!)) {
      return null;
    }
    return url;
  }
}

/// The XMLTV URL to download for [row] (see [PlaylistDraft.epgUrl]): the
/// stored custom URL; null when switched off (`''`); else the default — for
/// Xtream `{server}/xmltv.php` with [password] (from [SecretStore]), for M3U
/// the first `url-tvg` of [header]. Pure, so the importer can use it with
/// the password it already holds.
String? effectiveEpgUrl(
  PlaylistRow row, {
  String? password,
  M3uHeader? header,
}) {
  final stored = row.epgUrl?.trim();
  if (stored != null) return stored.isEmpty ? null : stored;
  if (row.type == PlaylistType.xtream) {
    final server = row.server;
    final username = row.username;
    if (server == null || username == null || password == null) return null;
    return XtreamUrls(server, username, password).xmltv();
  }
  return header?.tvgUrls.firstOrNull;
}

/// `{server}/xmltv.php?username=<u>&password=<p>` for these credentials,
/// however it is encoded.
bool _isDefaultXtreamEpg(
  String url,
  String server,
  String username,
  String password,
) {
  final u = Uri.tryParse(url);
  final s = Uri.tryParse(normalizeXtreamServer(server));
  if (u == null || s == null || !u.hasAuthority || !s.hasAuthority) {
    return false;
  }
  if (u.scheme.toLowerCase() != s.scheme.toLowerCase() ||
      u.host.toLowerCase() != s.host.toLowerCase() ||
      u.port != s.port ||
      u.path != '${s.path}/xmltv.php') {
    return false;
  }
  final q = u.queryParameters;
  return q.length == 2 &&
      q['username'] == username &&
      q['password'] == password;
}

class _Fields {
  _Fields({
    required this.name,
    this.server,
    this.username,
    this.password,
    this.m3uUrl,
  });

  final String name;
  final String? server;
  final String? username;
  final String? password;
  final String? m3uUrl;
}

String? _nonBlank(String? s) {
  final t = s?.trim();
  return (t == null || t.isEmpty) ? null : t;
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final playlistRepositoryProvider = Provider<PlaylistRepository>(
  (ref) => PlaylistRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(secretStoreProvider),
    ref.watch(settingsStoreProvider),
  ),
);

/// Every playlist in Manager order.
final playlistsProvider = StreamProvider<List<PlaylistRow>>(
  (ref) => ref.watch(playlistRepositoryProvider).watchAll(),
);

/// One playlist (null after it is deleted).
final playlistProvider = StreamProvider.family<PlaylistRow?, int>(
  (ref, id) => ref.watch(playlistRepositoryProvider).watch(id),
);
