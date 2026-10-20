import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Thrown when an image cannot be loaded (network, empty body, recent
/// failure, network disabled in tests).
class KImageLoadException implements Exception {
  KImageLoadException(this.reason);

  final String reason;

  @override
  String toString() => 'KImageLoadException: $reason';
}

/// Loads image bytes for [KNetworkImage] (docs/DECISIONS.md, 04:20):
///
/// * disk cache in `<app support dir>/image_cache/<sha1(url)>.img`;
/// * one download per URL at a time (in-flight requests are shared);
/// * at most [maxConcurrent] downloads (default 6) through dio;
/// * failures are remembered for [failureTtl] (default 2 minutes) and fail
///   fast in the meantime;
/// * under `flutter test` (FLUTTER_TEST is set) nothing touches the network
///   or disk: loads fail immediately so widgets show their placeholder,
///   unless [debugFetchOverride] supplies bytes.
///
/// Decoded images live in Flutter's [ImageCache] (memory), keyed by URL and
/// decode size.
class KImageLoader {
  KImageLoader({
    Dio? httpClient,
    this.maxConcurrent = 6,
    this.failureTtl = const Duration(minutes: 2),
    this.cacheDirectory,
  }) : _dio = httpClient;

  /// The shared loader used by [KNetworkImage].
  static KImageLoader instance = KImageLoader();

  /// Test hook: when set, every load returns these bytes (no disk/network).
  static Future<Uint8List> Function(String url)? debugFetchOverride;

  /// User-Agent of image requests.
  static const userAgent = 'Carina/1.0';

  final int maxConcurrent;
  final Duration failureTtl;

  /// Overrides the cache directory (tests); defaults to
  /// `<app support dir>/image_cache`.
  final Future<Directory> Function()? cacheDirectory;

  Dio? _dio;
  Future<Directory>? _dir;
  final Map<String, DateTime> _failures = {};
  final Map<String, Future<Uint8List>> _inflight = {};
  int _active = 0;
  final Queue<Completer<void>> _waiting = Queue();

  static bool get _underTest =>
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  Dio get _client => _dio ??= Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      responseType: ResponseType.bytes,
      followRedirects: true,
      headers: {'User-Agent': userAgent},
    ),
  );

  /// Returns the image bytes for [url] (http(s), file:// or a local path).
  Future<Uint8List> load(String url, {Map<String, String>? headers}) {
    final override = debugFetchOverride;
    if (override != null) return override(url);
    if (_underTest) {
      return Future.error(KImageLoadException('network disabled in tests'));
    }
    final failedAt = _failures[url];
    if (failedAt != null) {
      if (DateTime.now().difference(failedAt) < failureTtl) {
        return Future.error(KImageLoadException('recent failure'));
      }
      _failures.remove(url);
    }
    return _inflight.putIfAbsent(url, () async {
      try {
        return await _loadUncached(url, headers);
      } catch (_) {
        _failures[url] = DateTime.now();
        rethrow;
      } finally {
        _inflight.remove(url);
      }
    });
  }

  /// Forgets the cached file of [url] and remembers it as failed (called
  /// when the bytes do not decode).
  Future<void> markBroken(String url) async {
    _failures[url] = DateTime.now();
    try {
      final file = await _fileFor(url);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Best effort.
    }
  }

  /// Size of the disk cache in bytes.
  Future<int> diskCacheSizeBytes() async {
    if (_underTest && cacheDirectory == null) return 0;
    final dir = await _directory();
    var total = 0;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  /// Deletes the disk cache and clears decoded images from memory.
  Future<void> clearDiskCache() async {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    _failures.clear();
    if (_underTest && cacheDirectory == null) return;
    final dir = await _directory();
    await for (final entity in dir.list(followLinks: false)) {
      try {
        await entity.delete(recursive: true);
      } catch (_) {
        // A file in use; it is replaced on the next download.
      }
    }
  }

  Future<Directory> _directory() => _dir ??= () async {
    final custom = cacheDirectory;
    final base = custom != null
        ? await custom()
        : Directory(
            p.join(
              (await getApplicationSupportDirectory()).path,
              'image_cache',
            ),
          );
    await base.create(recursive: true);
    return base;
  }();

  Future<File> _fileFor(String url) async {
    final name = sha1.convert(utf8.encode(url)).toString();
    return File(p.join((await _directory()).path, '$name.img'));
  }

  Future<Uint8List> _loadUncached(
    String url,
    Map<String, String>? headers,
  ) async {
    final uri = Uri.tryParse(url);
    if (uri == null) throw KImageLoadException('invalid url');
    if (uri.scheme == 'file' || (uri.scheme.isEmpty && url.startsWith('/'))) {
      final file = File(uri.scheme == 'file' ? uri.toFilePath() : url);
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) throw KImageLoadException('empty file');
      return bytes;
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw KImageLoadException('unsupported scheme');
    }

    final file = await _fileFor(url);
    try {
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) return bytes;
      }
    } catch (_) {
      // Fall through to a fresh download.
    }

    await _acquire();
    try {
      final response = await _client.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: headers,
          validateStatus: (s) => s != null && s >= 200 && s < 300,
        ),
      );
      final data = response.data;
      if (data == null || data.isEmpty) {
        throw KImageLoadException('empty body');
      }
      final bytes = data is Uint8List ? data : Uint8List.fromList(data);
      unawaited(_store(file, bytes));
      return bytes;
    } on DioException catch (e) {
      throw KImageLoadException(
        'download failed (${e.response?.statusCode ?? e.type.name})',
      );
    } finally {
      _release();
    }
  }

  Future<void> _store(File file, Uint8List bytes) async {
    try {
      final tmp = File(
        '${file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
      );
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(file.path);
    } catch (_) {
      // The cache is an optimization; ignore write errors.
    }
  }

  Future<void> _acquire() {
    if (_active < maxConcurrent) {
      _active++;
      return Future.value();
    }
    final waiter = Completer<void>();
    _waiting.add(waiter);
    return waiter.future;
  }

  void _release() {
    if (_waiting.isNotEmpty) {
      _waiting.removeFirst().complete();
    } else {
      _active--;
    }
  }
}

/// [ImageProvider] for remote artwork (posters, backdrops, channel logos)
/// backed by [KImageLoader]'s disk cache. Wrap it in [ResizeImage] to
/// decode at display size — [KImage] does that automatically.
///
/// Always give widgets using it an error builder: in tests every load
/// fails fast by design.
@immutable
class KNetworkImage extends ImageProvider<KNetworkImage> {
  const KNetworkImage(this.url, {this.headers, this.scale = 1.0});

  final String url;

  /// Extra request headers (e.g. a playlist User-Agent / Referer).
  final Map<String, String>? headers;
  final double scale;

  @override
  Future<KNetworkImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<KNetworkImage>(this);

  @override
  ImageStreamCompleter loadImage(
    KNetworkImage key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _load(key, decode),
      scale: key.scale,
      debugLabel: key.url,
      informationCollector: () => [
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<KNetworkImage>('Image key', key),
      ],
    );
  }

  Future<ui.Codec> _load(KNetworkImage key, ImageDecoderCallback decode) async {
    try {
      final bytes = await KImageLoader.instance.load(
        key.url,
        headers: key.headers,
      );
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      try {
        return await decode(buffer);
      } catch (_) {
        unawaited(KImageLoader.instance.markBroken(key.url));
        rethrow;
      }
    } catch (_) {
      // Do not keep the failed completer in the ImageCache; the loader's
      // failure cache decides when a retry is allowed.
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(key));
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is KNetworkImage && other.url == url && other.scale == scale;

  @override
  int get hashCode => Object.hash(url, scale);

  @override
  String toString() =>
      '${objectRuntimeType(this, 'KNetworkImage')}("$url", scale: $scale)';
}
