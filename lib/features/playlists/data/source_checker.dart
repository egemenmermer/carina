/// Live checks of the add / edit playlist wizard: the Xtream
/// login, the M3U URL, the XMLTV URL and a local M3U file. A green result
/// only means the source answered; it never guarantees the import.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:carina/data/net/dio_factory.dart' show createDio;
import 'package:carina/data/net/url_check.dart'
    show
        UrlCheckResult,
        UrlContentKind,
        checkUrlReachable,
        m3uHeaderEpgUrls,
        sniffContentKind;
import 'package:carina/data/sources/xtream/xtream_check.dart'
    show XtreamCheckResult, checkXtreamServer;
import 'package:carina/data/sources/xtream/xtream_credentials.dart';

/// Result of [PlaylistSourceChecker.checkFile].
class FileCheckResult {
  const FileCheckResult({
    required this.exists,
    this.kind,
    this.epgUrls = const [],
  });

  /// The file could be opened.
  final bool exists;

  /// Sniffed from the first bytes.
  final UrlContentKind? kind;

  /// `url-tvg` / `x-tvg-url` of the `#EXTM3U` header.
  final List<String> epgUrls;

  bool get ok => exists && kind == UrlContentKind.m3u;
}

/// Runs the wizard's live checks. Each call uses its own short-lived HTTP
/// client (8 s connect timeout, one retry), so a slow server never blocks
/// another check. Override [playlistSourceCheckerProvider] in tests.
class PlaylistSourceChecker {
  const PlaylistSourceChecker();

  Dio _dio(String? userAgent) => createDio(
    userAgent: userAgent,
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 20),
    retries: 1,
  );

  /// `player_api.php` login check (account status, expiry, connections).
  Future<XtreamCheckResult> checkXtream(
    XtreamCredentials credentials, {
    CancelToken? cancelToken,
  }) async {
    final dio = _dio(null);
    try {
      return await checkXtreamServer(
        dio,
        credentials,
        cancelToken: cancelToken,
      );
    } finally {
      dio.close(force: true);
    }
  }

  /// GETs the first 64 KB of an M3U URL; also reports the header's guide
  /// URLs ([UrlCheckResult.m3uEpgUrls]).
  Future<UrlCheckResult> checkPlaylistUrl(
    String url, {
    String? userAgent,
    CancelToken? cancelToken,
  }) => _checkUrl(
    url,
    expectM3u: true,
    userAgent: userAgent,
    cancelToken: cancelToken,
  );

  /// GETs the first 64 KB of an XMLTV URL (plain or gzip).
  Future<UrlCheckResult> checkEpgUrl(
    String url, {
    String? userAgent,
    CancelToken? cancelToken,
  }) => _checkUrl(
    url,
    expectXml: true,
    userAgent: userAgent,
    cancelToken: cancelToken,
  );

  Future<UrlCheckResult> _checkUrl(
    String url, {
    bool expectM3u = false,
    bool expectXml = false,
    String? userAgent,
    CancelToken? cancelToken,
  }) async {
    final dio = _dio(userAgent);
    try {
      return await checkUrlReachable(
        dio,
        url.trim(),
        expectM3u: expectM3u,
        expectXml: expectXml,
        cancelToken: cancelToken,
      );
    } finally {
      dio.close(force: true);
    }
  }

  /// Reads the first 64 KB of a local playlist file.
  Future<FileCheckResult> checkFile(String path) async {
    final file = File(path);
    try {
      if (!await file.exists()) return const FileCheckResult(exists: false);
      final builder = BytesBuilder(copy: false);
      await for (final chunk in file.openRead(0, 64 * 1024)) {
        builder.add(chunk);
      }
      final bytes = builder.takeBytes();
      final kind = sniffContentKind(bytes);
      return FileCheckResult(
        exists: true,
        kind: kind,
        epgUrls: kind == UrlContentKind.m3u
            ? m3uHeaderEpgUrls(bytes)
            : const [],
      );
    } on FileSystemException {
      return const FileCheckResult(exists: false);
    }
  }
}

/// The wizard's [PlaylistSourceChecker].
final playlistSourceCheckerProvider = Provider<PlaylistSourceChecker>(
  (ref) => const PlaylistSourceChecker(),
);

/// Picks a local M3U file and returns its path (null when cancelled).
typedef PlaylistFilePicker = Future<String?> Function(String dialogTitle);

/// The platform file picker behind the wizard's "Choose file…" (overridden
/// in tests).
final playlistFilePickerProvider = Provider<PlaylistFilePicker>(
  (ref) => _pickWithPlatform,
);

Future<String?> _pickWithPlatform(String dialogTitle) async {
  final file = await FilePicker.pickFile(
    dialogTitle: dialogTitle,
    type: FileType.custom,
    allowedExtensions: const ['m3u', 'm3u8'],
  );
  return file?.path;
}
