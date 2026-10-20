/// "Dump Channel" / "Dump Category": JSON diagnostics on the Desktop.
/// Credentials never leave the app: stream, logo and source URLs are masked
/// (`maskUrl`), header values are replaced by `***`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../data/db/database.dart';
import '../../../data/net/mask.dart';
import '../../../data/repositories/live_repository.dart';
import '../../../data/repositories/playlist_repository.dart';
import '../../../data/repositories/repository_models.dart';
import '../../../data/repositories/stream_url_resolver.dart';

/// Where dumps are written; tests override it with a temp folder.
final liveDumpDirectoryProvider = Provider<Future<Directory> Function()>(
  (ref) => desktopDirectory,
);

/// The user's Desktop (`%USERPROFILE%\Desktop`, `~/Desktop`), else the
/// Downloads folder, else the system temp folder.
Future<Directory> desktopDirectory() async {
  final home =
      Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
  if (home != null && home.isNotEmpty) {
    final desktop = Directory(p.join(home, 'Desktop'));
    if (desktop.existsSync()) return desktop;
  }
  try {
    final downloads = await getDownloadsDirectory();
    if (downloads != null) return downloads;
  } on Object {
    // Fall through.
  }
  return Directory.systemTemp;
}

/// Writes the diagnostics of [channel]; returns the file, or null when it
/// could not be written.
Future<File?> dumpLiveChannel(
  ProviderContainer container, {
  required int playlistId,
  required ChannelView channel,
  NowNext nowNext = NowNext.empty,
}) async {
  final playlist = await container
      .read(playlistRepositoryProvider)
      .get(playlistId);
  final data = <String, Object?>{
    'kind': 'carina.channelDump',
    'createdAt': DateTime.now().toUtc().toIso8601String(),
    'playlist': _playlistJson(playlist),
    'channel': await _channelJson(container, playlistId, channel),
    'guide': {
      'epgKey': channel.epgKey,
      'now': _programmeJson(nowNext.now),
      'next': _programmeJson(nowNext.next),
    },
  };
  return _write(container, 'carina-channel-${_safe(channel.providerId)}', data);
}

/// Writes the diagnostics of every channel of [category].
Future<File?> dumpLiveCategory(
  ProviderContainer container, {
  required int playlistId,
  required CategoryView category,
}) async {
  final playlist = await container
      .read(playlistRepositoryProvider)
      .get(playlistId);
  final channels = await container
      .read(liveRepositoryProvider)
      .channels(playlistId, category.ref, revealLocked: true);
  final data = <String, Object?>{
    'kind': 'carina.categoryDump',
    'createdAt': DateTime.now().toUtc().toIso8601String(),
    'playlist': _playlistJson(playlist),
    'category': {
      'providerId': category.providerId,
      'name': category.name,
      'providerName': category.providerName,
      'hidden': category.hidden,
      'locked': category.locked,
      'count': category.count,
    },
    'channels': [
      for (final c in channels) await _channelJson(container, playlistId, c),
    ],
  };
  return _write(
    container,
    'carina-category-${_safe(category.providerId ?? category.ref.key)}',
    data,
  );
}

Map<String, Object?>? _playlistJson(PlaylistRow? row) => row == null
    ? null
    : {
        'id': row.id,
        'type': row.type.name,
        'server': row.server == null ? null : maskServer(row.server!),
        'lastReloadAt': row.lastReloadAt?.toUtc().toIso8601String(),
        'lastEpgReloadAt': row.lastEpgReloadAt?.toUtc().toIso8601String(),
      };

Future<Map<String, Object?>> _channelJson(
  ProviderContainer container,
  int playlistId,
  ChannelView c,
) async {
  final row = c.row;
  String? stream;
  String? streamError;
  try {
    stream =
        (await container.read(streamUrlResolverProvider).live(playlistId, row))
            .maskedUrl;
  } on StreamResolveException catch (e) {
    streamError = e.error.name;
  }
  return {
    'providerId': row.providerId,
    'num': row.num,
    'name': row.name,
    'displayName': c.displayName,
    'badges': c.badges,
    'categoryId': row.categoryId,
    'categoryName': c.categoryName,
    'logo': row.logo == null ? null : maskUrl(row.logo!),
    'epgId': row.epgId,
    'matchedEpgId': row.matchedEpgId,
    'customEpgId': row.customEpgId,
    'archiveDays': row.archiveDays,
    'catchupType': row.catchupType,
    'hidden': row.hidden,
    'locked': row.locked,
    'categoryLocked': c.categoryLocked,
    'favorite': c.favorite,
    'unsupported': row.unsupported,
    'added': row.added?.toUtc().toIso8601String(),
    'stream': stream,
    'streamError': ?streamError,
    'directSource': row.directSource == null
        ? null
        : maskUrl(row.directSource!),
    'headers': _maskedHeaders(row.headersJson),
  };
}

Map<String, Object?>? _programmeJson(ProgrammeView? p) => p == null
    ? null
    : {
        'start': p.start.toIso8601String(),
        'stop': p.stop.toIso8601String(),
        'title': p.title,
        'epgChannelId': p.epgChannelId,
      };

/// Header names with masked values.
Map<String, String> _maskedHeaders(String? json) {
  if (json == null || json.trim().isEmpty) return const {};
  try {
    final decoded = jsonDecode(json);
    if (decoded is! Map) return const {};
    return {for (final key in decoded.keys) '$key': '***'};
  } on FormatException {
    return const {};
  }
}

String _safe(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

Future<File?> _write(
  ProviderContainer container,
  String baseName,
  Map<String, Object?> data,
) async {
  try {
    final dir = await container.read(liveDumpDirectoryProvider)();
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-')
        .substring(0, 19);
    final file = File(p.join(dir.path, '$baseName-$stamp.json'));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
      flush: true,
    );
    return file;
  } on Object {
    return null;
  }
}
