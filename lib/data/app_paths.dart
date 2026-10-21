import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'db/database.dart';

/// Where Carina keeps its data: `%APPDATA%\Carina` on Windows, the app support
/// directory on macOS and Android (on Android that is the app-private files
/// folder, removed with the app and not readable by other apps), or an
/// explicit `--data-dir` (tests, capture mode).
class AppPaths {
  AppPaths(this.root);

  final String root;

  String get database => root;
  String get imageCache => p.join(root, 'image_cache');
  String get epgCache => p.join(root, 'epg');
  String get logs => p.join(root, 'logs');
  String get tmp => p.join(root, 'tmp');

  static Future<AppPaths> resolve({String? override}) async {
    final String root;
    if (override != null) {
      root = override;
    } else if (Platform.isWindows && Platform.environment['APPDATA'] != null) {
      root = p.join(Platform.environment['APPDATA']!, 'Carina');
      // Carina was called Kanal before 1.1: keep that install's data.
      final legacy = Directory(
        p.join(Platform.environment['APPDATA']!, 'Kanal'),
      );
      if (!Directory(root).existsSync() && legacy.existsSync()) {
        await legacy.rename(root);
      }
    } else {
      root = (await getApplicationSupportDirectory()).path;
    }
    final paths = AppPaths(root);
    for (final dir in [
      root,
      paths.imageCache,
      paths.epgCache,
      paths.logs,
      paths.tmp,
    ]) {
      await Directory(dir).create(recursive: true);
    }
    return paths;
  }
}

/// Overridden at bootstrap.
final appPathsProvider = Provider<AppPaths>(
  (ref) => throw UnimplementedError('appPathsProvider not overridden'),
);

/// Overridden at bootstrap.
final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('appDatabaseProvider not overridden'),
);
