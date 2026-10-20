/// Media serving for the mock server: files with HTTP Range support, live
/// MPEG-TS paced near real time, the live HLS writer's playlist and
/// segments, and images.
///
/// The server never generates media. Missing files produce a 404 with a
/// message that says what is missing and how to create it.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:shelf/shelf.dart';

const _contentTypes = <String, String>{
  'ts': 'video/mp2t',
  'mp4': 'video/mp4',
  'm4v': 'video/mp4',
  'mkv': 'video/x-matroska',
  'm4s': 'video/iso.segment',
  'm3u8': 'application/vnd.apple.mpegurl',
  'aac': 'audio/aac',
  'vtt': 'text/vtt',
  'srt': 'application/x-subrip',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
  'gif': 'image/gif',
  'svg': 'image/svg+xml',
};

/// Content type for a file name, by extension.
String contentTypeFor(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0) return 'application/octet-stream';
  return _contentTypes[name.substring(dot + 1).toLowerCase()] ??
      'application/octet-stream';
}

/// Joins a directory and a file name with the platform separator.
String joinPath(String dir, String name) {
  if (dir.isEmpty) return name;
  final last = dir[dir.length - 1];
  if (last == '/' || last == r'\') return '$dir$name';
  return '$dir${Platform.pathSeparator}$name';
}

final _safeName = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._\-]*$');

/// True for a plain file name (no directories, no `..`).
bool isSafeFileName(String name) =>
    _safeName.hasMatch(name) && !name.contains('..');

Response textResponse(
  int status,
  String message, {
  Map<String, String>? headers,
}) => Response(
  status,
  body: message.endsWith('\n') ? message : '$message\n',
  headers: {'content-type': 'text/plain; charset=utf-8', ...?headers},
);

/// A parsed single `Range: bytes=…` request.
typedef ByteRange = ({int start, int end});

/// Parses a `Range` header for a resource of [size] bytes.
///
/// Returns `null` when the header should be ignored (absent, another unit,
/// several ranges, malformed) and `(start: -1, end: -1)` when the range is
/// not satisfiable (answer 416).
ByteRange? parseRange(String? header, int size) {
  if (header == null) return null;
  final h = header.trim();
  if (!h.toLowerCase().startsWith('bytes=')) return null;
  final spec = h.substring(6).trim();
  if (spec.contains(',')) return null;
  final dash = spec.indexOf('-');
  if (dash < 0) return null;
  final a = spec.substring(0, dash).trim();
  final b = spec.substring(dash + 1).trim();
  const unsatisfiable = (start: -1, end: -1);
  if (a.isEmpty) {
    final suffix = int.tryParse(b);
    if (suffix == null) return null;
    if (suffix <= 0 || size == 0) return unsatisfiable;
    final start = size - suffix < 0 ? 0 : size - suffix;
    return (start: start, end: size - 1);
  }
  final start = int.tryParse(a);
  if (start == null || start < 0) return null;
  if (b.isEmpty) {
    if (start >= size) return unsatisfiable;
    return (start: start, end: size - 1);
  }
  final end = int.tryParse(b);
  if (end == null || end < start) return null;
  if (start >= size) return unsatisfiable;
  return (start: start, end: end >= size ? size - 1 : end);
}

String _etag(FileStat stat) =>
    '"${stat.size.toRadixString(16)}-${stat.modified.millisecondsSinceEpoch.toRadixString(16)}"';

/// Serves [file] with `Accept-Ranges`, 206 partial content and 416.
Future<Response> serveFile(
  Request request,
  File file, {
  String? contentType,
  Map<String, String> headers = const {},
}) async {
  final FileStat stat;
  try {
    stat = await file.stat();
  } on FileSystemException {
    return textResponse(404, 'File not found: ${file.path}');
  }
  if (stat.type != FileSystemEntityType.file) {
    return textResponse(404, 'File not found: ${file.path}');
  }
  final size = stat.size;
  final type = contentType ?? contentTypeFor(file.path);
  final common = <String, String>{
    'content-type': type,
    'accept-ranges': 'bytes',
    'last-modified': HttpDate.format(stat.modified.toUtc()),
    'etag': _etag(stat),
    ...headers,
  };
  final range = parseRange(request.headers['range'], size);
  if (range == null) {
    return Response.ok(
      file.openRead(),
      headers: {...common, 'content-length': '$size'},
    );
  }
  if (range.start < 0) {
    return Response(
      416,
      body: 'Requested range not satisfiable (size $size)\n',
      headers: {
        'content-type': 'text/plain; charset=utf-8',
        'content-range': 'bytes */$size',
        'accept-ranges': 'bytes',
      },
    );
  }
  return Response(
    206,
    body: file.openRead(range.start, range.end + 1),
    headers: {
      ...common,
      'content-length': '${range.end - range.start + 1}',
      'content-range': 'bytes ${range.start}-${range.end}/$size',
    },
  );
}

// ---------------------------------------------------------------------------
// Live MPEG-TS
// ---------------------------------------------------------------------------

const _packet = 188;
const _pcrWrap = 1 << 33;

/// Offset of the first TS packet (0 for files written by ffmpeg).
int _syncOffset(Uint8List head) {
  for (var off = 0; off < _packet && off < head.length; off++) {
    var ok = true;
    for (var k = 0; k < 3; k++) {
      final i = off + k * _packet;
      if (i >= head.length || head[i] != 0x47) {
        ok = false;
        break;
      }
    }
    if (ok) return off;
  }
  return 0;
}

/// The 33-bit PCR base (90 kHz) of the last packet in [chunk] that has one.
int? lastPcr(Uint8List chunk) {
  final packets = chunk.length ~/ _packet;
  for (var n = packets - 1; n >= 0; n--) {
    final o = n * _packet;
    if (chunk[o] != 0x47) continue;
    final adaptation = (chunk[o + 3] >> 4) & 0x3;
    if (adaptation < 2) continue;
    if (chunk[o + 4] < 7) continue;
    if (chunk[o + 5] & 0x10 == 0) continue;
    return (chunk[o + 6] << 25) |
        (chunk[o + 7] << 17) |
        (chunk[o + 8] << 9) |
        (chunk[o + 9] << 1) |
        (chunk[o + 10] >> 7);
  }
  return null;
}

/// Streams [file] in a loop, paced by its PCR clock so the client receives
/// roughly real-time data after an initial [burst]. Files without PCRs are
/// paced at [fallbackBytesPerSecond]. The stream ends after [dropAfter]
/// (simulated drop) or when [isClosed] reports the server stopped.
Stream<List<int>> pacedTsStream(
  File file, {
  Duration burst = const Duration(seconds: 2),
  Duration? dropAfter,
  int fallbackBytesPerSecond = 625000,
  bool Function()? isClosed,
}) async* {
  final raf = await file.open();
  try {
    final size = await raf.length();
    if (size == 0) return;
    final head = await raf.read(_packet * 4);
    final offset = _syncOffset(head);
    await raf.setPosition(offset);
    final watch = Stopwatch()..start();
    final burstSeconds = burst.inMicroseconds / 1e6;
    var mediaSeconds = 0.0;
    var sentBytes = 0;
    var sawPcr = false;
    int? previousPcr;
    while (true) {
      if (isClosed?.call() ?? false) return;
      final chunk = await raf.read(_packet * 256);
      if (chunk.isEmpty) {
        // Loop. The next PCR jumps back; treat it as a discontinuity.
        await raf.setPosition(offset);
        previousPcr = null;
        mediaSeconds += 0.04;
        continue;
      }
      final pcr = lastPcr(chunk);
      if (pcr != null) {
        sawPcr = true;
        if (previousPcr != null) {
          var delta = (pcr - previousPcr) % _pcrWrap;
          if (delta < 0) delta += _pcrWrap;
          if (delta > 5 * 90000) delta = 0;
          mediaSeconds += delta / 90000.0;
        }
        previousPcr = pcr;
      } else if (!sawPcr) {
        mediaSeconds = sentBytes / fallbackBytesPerSecond;
      }
      final wait =
          mediaSeconds - burstSeconds - watch.elapsedMicroseconds / 1e6;
      if (wait > 0) {
        await Future<void>.delayed(
          Duration(microseconds: (wait * 1e6).round()),
        );
      }
      yield chunk;
      sentBytes += chunk.length;
      if (dropAfter != null && watch.elapsed >= dropAfter) return;
    }
  } finally {
    await raf.close();
  }
}

// ---------------------------------------------------------------------------
// Library
// ---------------------------------------------------------------------------

/// Status of the live HLS writer.
typedef HlsStatus = ({
  bool exists,
  bool fresh,
  double? ageSeconds,
  String path,
});

final class MediaLibrary {
  MediaLibrary({
    required this.mediaDir,
    required this.liveDir,
    this.hlsMaxAge = const Duration(seconds: 30),
  });

  final String mediaDir;
  final String liveDir;
  final Duration hlsMaxAge;

  File file(String name) => File(joinPath(mediaDir, name));

  String get imageDir => joinPath(mediaDir, 'img');

  File get hlsPlaylistFile => File(joinPath(liveDir, 'index.m3u8'));

  Response missingMedia(String name) => textResponse(
    404,
    'Media file not found: $name\n'
    'Looked in: $mediaDir\n'
    'Generate the test media with tools/gen_media.sh (the mock server never '
    'creates media itself).',
  );

  /// A media file of the media directory, or a 404 explaining what is
  /// missing.
  Future<Response> serveMedia(
    Request request,
    String name, {
    Map<String, String> headers = const {},
  }) async {
    final f = file(name);
    if (!await f.exists()) return missingMedia(name);
    return serveFile(request, f, headers: headers);
  }

  /// A looping live TS response for [name].
  Future<Response> liveTs(
    String name, {
    Duration burst = const Duration(seconds: 2),
    Duration? dropAfter,
    bool Function()? isClosed,
  }) async {
    final f = file(name);
    if (!await f.exists()) return missingMedia(name);
    return Response.ok(
      pacedTsStream(f, burst: burst, dropAfter: dropAfter, isClosed: isClosed),
      headers: {
        'content-type': 'video/mp2t',
        'cache-control': 'no-cache, no-store',
        'access-control-allow-origin': '*',
      },
      context: {'shelf.io.buffer_output': false},
    );
  }

  HlsStatus hlsStatus() {
    final f = hlsPlaylistFile;
    if (!f.existsSync()) {
      return (exists: false, fresh: false, ageSeconds: null, path: f.path);
    }
    final age = DateTime.now().difference(f.lastModifiedSync());
    final seconds = age.inMilliseconds / 1000.0;
    return (
      exists: true,
      fresh: age <= hlsMaxAge,
      ageSeconds: seconds,
      path: f.path,
    );
  }

  /// The live HLS playlist with its segment URIs rewritten to `/hls/…`.
  Future<Response> hlsPlaylist() async {
    final status = hlsStatus();
    if (!status.exists) {
      return textResponse(
        404,
        'Live HLS is not running: ${status.path} does not exist.\n'
        'Start the live HLS writer (see tools/gen_media.sh) and retry.',
      );
    }
    if (!status.fresh) {
      return textResponse(
        404,
        'Live HLS writer looks stopped: ${status.path} was last updated '
        '${status.ageSeconds!.toStringAsFixed(0)} s ago.',
      );
    }
    var text = await hlsPlaylistFile.readAsString();
    if (!text.contains('#EXTINF')) {
      // The writer may be replacing the file right now.
      await Future<void>.delayed(const Duration(milliseconds: 150));
      text = await hlsPlaylistFile.readAsString();
    }
    if (text.contains('#EXT-X-ENDLIST')) {
      return textResponse(
        404,
        'Live HLS writer has stopped: ${status.path} ends with #EXT-X-ENDLIST.',
      );
    }
    return Response.ok(
      rewriteHlsPlaylist(text),
      headers: {
        'content-type': 'application/vnd.apple.mpegurl',
        'cache-control': 'no-cache, no-store',
        'access-control-allow-origin': '*',
      },
    );
  }

  /// A segment (or init section) written by the live HLS writer.
  Future<Response> hlsSegment(Request request, String name) async {
    if (!isSafeFileName(name)) return textResponse(400, 'Bad segment name');
    final f = File(joinPath(liveDir, name));
    if (!await f.exists()) {
      return textResponse(404, 'HLS segment not found (expired?): $name');
    }
    return serveFile(
      request,
      f,
      headers: const {'cache-control': 'public, max-age=60'},
    );
  }

  /// `/img/<name>` with caching headers and 304 support.
  Future<Response> image(Request request, String name) async {
    if (!isSafeFileName(name)) return textResponse(400, 'Bad image name');
    final f = File(joinPath(imageDir, name));
    final FileStat stat;
    try {
      stat = await f.stat();
    } on FileSystemException {
      return _missingImage(name);
    }
    if (stat.type != FileSystemEntityType.file) return _missingImage(name);
    final etag = _etag(stat);
    final modified = stat.modified.toUtc();
    final headers = {
      'cache-control': 'public, max-age=86400',
      'etag': etag,
      'last-modified': HttpDate.format(modified),
      'access-control-allow-origin': '*',
    };
    final ifNoneMatch = request.headers['if-none-match'];
    if (ifNoneMatch != null &&
        ifNoneMatch.split(',').map((t) => t.trim()).contains(etag)) {
      return Response.notModified(headers: headers);
    }
    final ifModifiedSince = request.headers['if-modified-since'];
    if (ifNoneMatch == null && ifModifiedSince != null) {
      try {
        final since = HttpDate.parse(ifModifiedSince);
        if (modified.millisecondsSinceEpoch ~/ 1000 <=
            since.millisecondsSinceEpoch ~/ 1000) {
          return Response.notModified(headers: headers);
        }
      } on HttpException {
        // Ignore a malformed date.
      }
    }
    return Response.ok(
      f.openRead(),
      headers: {
        ...headers,
        'content-type': contentTypeFor(name),
        'content-length': '${stat.size}',
      },
    );
  }

  Response _missingImage(String name) => textResponse(
    404,
    'Image not found: img/$name\nLooked in: $imageDir\n'
    'Generate the images with tools/gen_media.sh.',
  );
}

final _uriAttribute = RegExp(r'URI="([^"]*)"');

String _lastSegment(String uri) {
  var s = uri;
  final q = s.indexOf('?');
  if (q >= 0) s = s.substring(0, q);
  final slash = s.lastIndexOf('/');
  return slash >= 0 ? s.substring(slash + 1) : s;
}

/// Points every segment / init URI of an HLS playlist at `/hls/<name>`.
String rewriteHlsPlaylist(String text) {
  final out = StringBuffer();
  for (final raw in text.split('\n')) {
    final line = raw.endsWith('\r') ? raw.substring(0, raw.length - 1) : raw;
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      out.write('\n');
    } else if (trimmed.startsWith('#')) {
      out
        ..write(
          trimmed.replaceAllMapped(
            _uriAttribute,
            (m) => 'URI="/hls/${_lastSegment(m.group(1)!)}"',
          ),
        )
        ..write('\n');
    } else {
      out
        ..write('/hls/')
        ..write(_lastSegment(trimmed))
        ..write('\n');
    }
  }
  var s = out.toString();
  while (s.endsWith('\n\n')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}
