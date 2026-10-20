import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart' show fail;
import 'package:carina/data/db/database.dart';
import 'package:carina/data/secrets/secret_store.dart';
import 'package:carina/data/settings/settings_store.dart';

/// In-memory database, loaded settings and secrets for repository tests.
class R1Env {
  R1Env._(this.db, this.settings, this.secrets);

  static Future<R1Env> create() async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final settings = SettingsStore(db);
    await settings.load();
    return R1Env._(db, settings, MemorySecretStore());
  }

  final AppDatabase db;
  final SettingsStore settings;
  final MemorySecretStore secrets;

  Future<void> dispose() => db.close();

  Future<int> playlist({
    String name = 'Test',
    PlaylistType type = PlaylistType.xtream,
    String? server = 'http://127.0.0.1:8080',
    String? username = 'kanal',
    String? password = 'test123',
    String? m3uUrl,
    String? userAgent,
    Map<String, Object?>? account,
    Map<String, Object?>? m3uHeader,
  }) async {
    final id = await db
        .into(db.playlists)
        .insert(
          PlaylistsCompanion.insert(
            name: name,
            type: type,
            server: Value(type == PlaylistType.xtream ? server : null),
            username: Value(type == PlaylistType.xtream ? username : null),
            m3uUrl: Value(m3uUrl),
            userAgent: Value(userAgent),
            accountJson: Value(account == null ? null : jsonEncode(account)),
            m3uHeaderJson: Value(
              m3uHeader == null ? null : jsonEncode(m3uHeader),
            ),
            createdAt: DateTime(2026),
          ),
        );
    if (type == PlaylistType.xtream && password != null) {
      await secrets.write(SecretStore.playlistPassword(id), password);
    }
    return id;
  }

  Future<void> category(
    int playlistId,
    String providerId,
    String name, {
    SectionKind kind = SectionKind.live,
    int sortIndex = 0,
    int? customIndex,
    bool hidden = false,
    bool locked = false,
    String? localName,
  }) => db
      .into(db.categories)
      .insert(
        CategoriesCompanion.insert(
          playlistId: playlistId,
          kind: kind,
          providerId: providerId,
          name: name,
          sortIndex: Value(sortIndex),
          customIndex: Value(customIndex),
          hidden: Value(hidden),
          locked: Value(locked),
          localName: Value(localName),
        ),
      );

  Future<void> channel(
    int playlistId,
    String providerId,
    String name, {
    String? displayName,
    String? quality,
    String? categoryId,
    int? num,
    int sortIndex = 0,
    DateTime? added,
    String? epgId,
    String? matchedEpgId,
    String? customEpgId,
    int archiveDays = 0,
    bool hidden = false,
    bool locked = false,
    bool unsupported = false,
    String? streamUrl,
    String? directSource,
    String? headersJson,
    String? catchupType,
    String? catchupSource,
    String? logo,
  }) => db
      .into(db.channels)
      .insert(
        ChannelsCompanion.insert(
          playlistId: playlistId,
          providerId: providerId,
          name: name,
          displayName: displayName ?? name,
          quality: Value(quality),
          categoryId: Value(categoryId),
          num: Value(num),
          sortIndex: Value(sortIndex),
          added: Value(added),
          epgId: Value(epgId),
          matchedEpgId: Value(matchedEpgId),
          customEpgId: Value(customEpgId),
          archiveDays: Value(archiveDays),
          hidden: Value(hidden),
          locked: Value(locked),
          unsupported: Value(unsupported),
          streamUrl: Value(streamUrl),
          directSource: Value(directSource),
          headersJson: Value(headersJson),
          catchupType: Value(catchupType),
          catchupSource: Value(catchupSource),
          logo: Value(logo),
        ),
      );

  Future<void> movie(
    int playlistId,
    String providerId,
    String name, {
    String? categoryId,
    DateTime? added,
    bool hidden = false,
    String? containerExt,
    String? streamUrl,
    String? directSource,
    String? headersJson,
  }) => db
      .into(db.movies)
      .insert(
        MoviesCompanion.insert(
          playlistId: playlistId,
          providerId: providerId,
          name: name,
          categoryId: Value(categoryId),
          added: Value(added),
          hidden: Value(hidden),
          containerExt: Value(containerExt),
          streamUrl: Value(streamUrl),
          directSource: Value(directSource),
          headersJson: Value(headersJson),
        ),
      );

  Future<void> series(
    int playlistId,
    String providerId,
    String name, {
    String? categoryId,
    DateTime? lastModified,
  }) => db
      .into(db.series)
      .insert(
        SeriesCompanion.insert(
          playlistId: playlistId,
          providerId: providerId,
          name: name,
          categoryId: Value(categoryId),
          lastModified: Value(lastModified),
        ),
      );

  Future<int> tag(int playlistId, String name, {int sortIndex = 0}) => db
      .into(db.favoriteTags)
      .insert(
        FavoriteTagsCompanion.insert(
          playlistId: playlistId,
          name: name,
          sortIndex: Value(sortIndex),
        ),
      );

  Future<int> favorite(
    int playlistId,
    String providerId, {
    ItemType type = ItemType.channel,
    DateTime? addedAt,
    int? customIndex,
    List<int> tags = const [],
  }) async {
    final id = await db
        .into(db.favorites)
        .insert(
          FavoritesCompanion.insert(
            playlistId: playlistId,
            itemType: type,
            providerId: providerId,
            addedAt: addedAt ?? DateTime(2026),
            customIndex: Value(customIndex),
          ),
        );
    for (final tag in tags) {
      await db
          .into(db.favoriteTagLinks)
          .insert(FavoriteTagLinksCompanion.insert(favoriteId: id, tagId: tag));
    }
    return id;
  }

  Future<void> lastWatched(int playlistId, String channelId, DateTime at) => db
      .into(db.lastWatchedLive)
      .insert(
        LastWatchedLiveCompanion.insert(
          playlistId: playlistId,
          channelId: channelId,
          watchedAt: at,
        ),
      );

  Future<int> programme(
    int playlistId,
    String epgChannelId,
    DateTime start,
    DateTime stop,
    String title, {
    String? description,
  }) => db
      .into(db.programmes)
      .insert(
        ProgrammesCompanion.insert(
          playlistId: playlistId,
          epgChannelId: epgChannelId,
          start: start.millisecondsSinceEpoch,
          stop: stop.millisecondsSinceEpoch,
          title: title,
          description: Value(description),
        ),
      );

  Future<void> epgChannel(
    int playlistId,
    String epgId,
    String displayName, {
    String? normalized,
    String? icon,
  }) => db
      .into(db.epgChannels)
      .insert(
        EpgChannelsCompanion.insert(
          playlistId: playlistId,
          epgId: epgId,
          displayName: displayName,
          normalized: normalized ?? displayName.toLowerCase(),
          icon: Value(icon),
        ),
      );
}

/// A settable clock for repositories.
class FakeClock {
  FakeClock(this.now);

  DateTime now;

  DateTime call() => now;

  void advance(Duration d) => now = now.add(d);
}

/// Xtream `player_api.php` account JSON with the server clock [offset] from
/// UTC and the given output formats.
Map<String, Object?> xtreamAccountJson({
  Duration offset = Duration.zero,
  List<String> formats = const ['m3u8', 'ts', 'rtmp'],
}) {
  final utc = DateTime.utc(2026, 10, 17, 12);
  final wall = utc.add(offset);
  String two(int v) => v.toString().padLeft(2, '0');
  return {
    'user_info': {
      'username': 'kanal',
      'auth': 1,
      'status': 'Active',
      'max_connections': '2',
      'allowed_output_formats': formats,
    },
    'server_info': {
      'timezone': 'Europe/Istanbul',
      'timestamp_now': utc.millisecondsSinceEpoch ~/ 1000,
      'time_now':
          '${wall.year}-${two(wall.month)}-${two(wall.day)} '
          '${two(wall.hour)}:${two(wall.minute)}:${two(wall.second)}',
    },
  };
}

/// Lets streams deliver until [done] is true (fails after 2 s).
Future<void> pumpUntil(bool Function() done) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) fail('condition not reached');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
