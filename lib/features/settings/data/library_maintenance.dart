/// Settings → Cache and Diagnostics: cache sizes, clearing, the diagnostics
/// text (credentials masked) and the "Report a problem" file. Feature-local
/// queries over the shared database (see the final report: no repository
/// offered programme counts or clearing).
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/images/k_network_image.dart';
import '../../../data/app_paths.dart';
import '../../../data/db/database.dart';
import '../../../data/import/import.dart';
import '../../../data/net/mask.dart';
import '../../../data/secrets/secret_store.dart';
import '../../../data/settings/settings_store.dart';
import '../settings_model.dart';

/// Cache maintenance and diagnostics.
class LibraryMaintenance {
  LibraryMaintenance({
    required this.db,
    required this.paths,
    required this.settings,
    required this.secrets,
    required this.imports,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final AppPaths paths;
  final SettingsStore settings;
  final SecretStore secrets;
  final ImportService imports;
  final DateTime Function() _clock;

  // -------------------------------------------------------------------------
  // Image cache
  // -------------------------------------------------------------------------

  /// Bytes in the image cache folder (`AppPaths.imageCache`).
  Future<int> imageCacheBytes() => _folderBytes(Directory(paths.imageCache));

  /// Deletes the image cache (disk and decoded images in memory).
  Future<void> clearImageCache() async {
    try {
      await KImageLoader.instance.clearDiskCache();
    } on Object catch (e) {
      debugPrint('Image cache: clear failed: $e');
    }
    final dir = Directory(paths.imageCache);
    if (!await dir.exists()) return;
    await for (final entity in dir.list(followLinks: false)) {
      try {
        await entity.delete(recursive: true);
      } on FileSystemException {
        // In use; it is replaced on the next download.
      }
    }
  }

  static Future<int> _folderBytes(Directory dir) async {
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } on FileSystemException {
          // Deleted meanwhile.
        }
      }
    }
    return total;
  }

  // -------------------------------------------------------------------------
  // EPG database
  // -------------------------------------------------------------------------

  /// Programmes stored for every playlist; updates as imports write.
  Stream<int> watchProgrammeCount() => db
      .customSelect(
        'SELECT COUNT(*) AS n FROM programmes',
        readsFrom: {db.programmes},
      )
      .watchSingle()
      .map((row) => row.read<int>('n'));

  /// Deletes every stored programme (all playlists) and the programme
  /// search index. The guide is downloaded again on the next EPG reload.
  Future<void> clearProgrammes() => db.transaction(() async {
    await db.customUpdate(
      'DELETE FROM programme_search',
      updates: {db.programmeSearch},
      updateKind: UpdateKind.delete,
    );
    await db.delete(db.programmes).go();
    await db
        .update(db.playlists)
        .write(
          const PlaylistsCompanion(
            programmeCount: Value(0),
            lastEpgReloadAt: Value(null),
          ),
        );
  });

  // -------------------------------------------------------------------------
  // Diagnostics
  // -------------------------------------------------------------------------

  /// Plain-text diagnostics for support: app, system, settings and
  /// playlists. Passwords, PINs and keys are never included; servers, user
  /// names and URLs are masked.
  Future<String> diagnostics({required String version}) async {
    final b = StringBuffer()
      ..writeln('Carina diagnostics')
      ..writeln('Generated: ${_clock().toIso8601String()}')
      ..writeln('App: Carina $version')
      ..writeln(
        'OS: ${_safe(() => Platform.operatingSystem)} '
        '${_safe(() => Platform.operatingSystemVersion)}',
      )
      ..writeln('Dart: ${_safe(() => Platform.version.split(' ').first)}')
      ..writeln('System locale: ${_safe(() => Platform.localeName)}')
      ..writeln('Data folder: ${_home(paths.root)}')
      ..writeln();

    b.writeln('[App settings]');
    for (final spec in LibrarySettingSpecs.all) {
      if (spec.section.isPlaylist) continue;
      b.writeln('${spec.key.id} = ${_value(settings.get(spec.key))}');
    }
    final hasKey =
        (await secrets.read(SecretStore.tmdbKey))?.isNotEmpty ?? false;
    b
      ..writeln('tmdbKeyStored = ${hasKey ? 'yes' : 'no'}')
      ..writeln();

    final playlists = await (db.select(
      db.playlists,
    )..orderBy([(t) => OrderingTerm(expression: t.sortIndex)])).get();
    b.writeln('[Playlists] ${playlists.length}');
    for (final pl in playlists) {
      b
        ..writeln()
        ..writeln('#${pl.id} "${pl.name}" (${pl.type.name})');
      if (pl.server != null) b.writeln('  server: ${maskServer(pl.server!)}');
      if (pl.username != null) b.writeln('  user: ${_maskName(pl.username!)}');
      if (pl.m3uUrl != null) {
        b.writeln(
          pl.type == PlaylistType.m3uFile
              ? '  file: ${_home(pl.m3uUrl!)}'
              : '  m3u: ${maskUrl(pl.m3uUrl!)}',
        );
      }
      final epg = pl.epgUrl;
      b
        ..writeln(
          '  epg: ${epg == null
              ? 'default'
              : epg.isEmpty
              ? 'off'
              : maskUrl(epg)}',
        )
        ..writeln(
          '  counts: live ${pl.liveCount}, movies ${pl.movieCount}, '
          'series ${pl.seriesCount}, programmes ${pl.programmeCount}',
        )
        ..writeln(
          '  epg shift: ${pl.epgShiftHours} h, '
          'reload every: ${pl.reloadFrequencyHours} h, '
          'access PIN: ${pl.hasAccessPin ? 'yes' : 'no'}',
        )
        ..writeln('  last reload: ${pl.lastReloadAt?.toIso8601String() ?? '-'}')
        ..writeln(
          '  last EPG reload: ${pl.lastEpgReloadAt?.toIso8601String() ?? '-'}',
        );
      final last = imports.lastResult(pl.id);
      if (last != null) {
        b.writeln('  last import (this session): ${last.step.name}');
        final error = last.error ?? last.epgError;
        if (error != null) {
          b.writeln(
            '  error: ${error.kind.name} ${error.statusCode ?? ''} '
            '${maskText(error.message ?? '')}',
          );
        }
      }
      final changed = <String>[];
      for (final spec in LibrarySettingSpecs.all) {
        if (!spec.section.isPlaylist) continue;
        if (!settings.isSet(spec.key, playlistId: pl.id)) continue;
        changed.add(
          '${spec.key.id}=${_value(settings.get(spec.key, playlistId: pl.id))}',
        );
      }
      if (settings.isSet(PlaylistSettings.referer, playlistId: pl.id)) {
        changed.add('referer=set');
      }
      if (settings.isSet(PlaylistSettings.userAgentCustom, playlistId: pl.id)) {
        changed.add('userAgentCustom=set');
      }
      b.writeln(
        '  settings: ${changed.isEmpty ? 'defaults' : changed.join(', ')}',
      );
    }
    return b.toString();
  }

  /// Writes a prefilled problem report (the user's notes on top, then the
  /// diagnostics) to the logs folder and returns the file.
  Future<File> writeReport({
    required String version,
    required String template,
  }) async {
    final dir = Directory(paths.logs);
    await dir.create(recursive: true);
    final now = _clock();
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp =
        '${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
    final file = File(p.join(dir.path, 'carina-report-$stamp.txt'));
    final text = '$template\n\n${await diagnostics(version: version)}';
    await file.writeAsString(text.replaceAll('\n', Platform.lineTerminator));
    return file;
  }

  String _home(String path) {
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home == null || home.isEmpty || !path.startsWith(home)) return path;
    return '~${path.substring(home.length)}';
  }

  static String _maskName(String name) {
    final t = name.trim();
    if (t.length < 4) return '***';
    return '${t.substring(0, 2)}***';
  }

  static String _value(Object? v) => v is String ? '"$v"' : '$v';

  static String _safe(String Function() read) {
    try {
      return read();
    } on Object {
      return '?';
    }
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final libraryMaintenanceProvider = Provider<LibraryMaintenance>(
  (ref) => LibraryMaintenance(
    db: ref.watch(appDatabaseProvider),
    paths: ref.watch(appPathsProvider),
    settings: ref.watch(settingsStoreProvider),
    secrets: ref.watch(secretStoreProvider),
    imports: ref.watch(importServiceProvider),
  ),
);

/// Image cache size in bytes (invalidate after clearing).
final imageCacheBytesProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.watch(libraryMaintenanceProvider).imageCacheBytes(),
);

/// Programmes stored for every playlist.
final programmeCountProvider = StreamProvider.autoDispose<int>(
  (ref) => ref.watch(libraryMaintenanceProvider).watchProgrammeCount(),
);

/// `1.0.0 (1)` from the app bundle.
final libraryAppVersionProvider = FutureProvider<String>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return info.buildNumber.isEmpty
        ? info.version
        : '${info.version} (${info.buildNumber})';
  } on Object {
    return '1.0.0';
  }
});

/// Whether a TMDb key or token is stored (invalidate after saving).
final tmdbKeyStoredProvider = FutureProvider.autoDispose<bool>((ref) async {
  final key = await ref.watch(secretStoreProvider).read(SecretStore.tmdbKey);
  return key != null && key.trim().isNotEmpty;
});

/// Opens a file or folder with the system (url_launcher); tests override it.
final libraryUriLauncherProvider = Provider<Future<bool> Function(Uri uri)>(
  (ref) =>
      (uri) => launchUrl(uri),
);
