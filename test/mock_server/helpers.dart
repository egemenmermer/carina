// Shared helpers for the mock server tests: a temporary media folder with
// small fake files (so the tests never depend on tools/gen_media.sh) and a
// tiny HTTP client.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../tools/mock_server/src/server.dart';

/// MPEG-TS bytes whose packets carry a PCR clock: [seconds] of "media" at
/// [packetsPerSecond] packets (188 bytes each).
Uint8List fakeTs({double seconds = 10, int packetsPerSecond = 1000}) {
  final count = (seconds * packetsPerSecond).round();
  final out = Uint8List(count * 188);
  for (var i = 0; i < count; i++) {
    final o = i * 188;
    out[o] = 0x47;
    out[o + 1] = 0x01; // PID 0x100
    out[o + 2] = 0x00;
    out[o + 3] = 0x20 | (i & 0x0F); // adaptation field only
    out[o + 4] = 183;
    out[o + 5] = 0x10; // PCR flag
    final base = 900000 + i * 90000 ~/ packetsPerSecond;
    out[o + 6] = (base >> 25) & 0xFF;
    out[o + 7] = (base >> 17) & 0xFF;
    out[o + 8] = (base >> 9) & 0xFF;
    out[o + 9] = (base >> 1) & 0xFF;
    out[o + 10] = ((base & 1) << 7) | 0x7E;
    out[o + 11] = 0;
    for (var k = o + 12; k < o + 188; k++) {
      out[k] = 0xFF;
    }
  }
  return out;
}

/// Deterministic pseudo-content for VOD files.
Uint8List fakeBytes(int length, int seed) {
  final out = Uint8List(length);
  for (var i = 0; i < length; i++) {
    out[i] = (i * 31 + seed * 17 + (i >> 8)) & 0xFF;
  }
  return out;
}

/// A temporary media folder (`media/` with the six files and `img/`, plus
/// a `live/` folder with a fresh HLS playlist).
final class FakeMedia {
  FakeMedia._(this.root);

  final Directory root;

  String get mediaDir => '${root.path}${Platform.pathSeparator}media';
  String get liveDir => '${root.path}${Platform.pathSeparator}live';

  File media(String name) => File('$mediaDir${Platform.pathSeparator}$name');
  File live(String name) => File('$liveDir${Platform.pathSeparator}$name');

  static Future<FakeMedia> create({double tsSeconds = 10}) async {
    final root = await Directory.systemTemp.createTemp('carina_mock_test_');
    final m = FakeMedia._(root);
    await Directory('${m.mediaDir}${Platform.pathSeparator}img')
        .create(recursive: true);
    await Directory(m.liveDir).create(recursive: true);
    final ts = fakeTs(seconds: tsSeconds);
    for (final name in MockMedia.liveTsFiles) {
      await m.media(name).writeAsBytes(ts);
    }
    await m.media(MockMedia.vodTracksMkv).writeAsBytes(fakeBytes(300000, 1));
    await m
        .media(MockMedia.h264Aac720p50Mp4)
        .writeAsBytes(fakeBytes(200000, 2));
    for (final name in ['poster_00.jpg', 'backdrop_00.jpg', 'still_00.jpg']) {
      await m.media('img${Platform.pathSeparator}$name').writeAsBytes([
        0xFF,
        0xD8,
        0xFF,
        0xE0,
        1,
        2,
        3,
      ]);
    }
    await m.media('img${Platform.pathSeparator}logo_00.png').writeAsBytes([
      0x89,
      0x50,
      0x4E,
      0x47,
      1,
      2,
    ]);
    await m.writePlaylist();
    await m.live('seg_00042.ts').writeAsBytes(fakeTs(seconds: 2));
    return m;
  }

  Future<void> writePlaylist() => live('index.m3u8').writeAsString(
    '#EXTM3U\n#EXT-X-VERSION:3\n#EXT-X-TARGETDURATION:2\n'
    '#EXT-X-MEDIA-SEQUENCE:42\n#EXTINF:2.000000,\nseg_00042.ts\n'
    '#EXTINF:2.000000,\nhttp://writer.invalid/out/seg_00043.ts?x=1\n',
  );

  Future<void> delete() async {
    try {
      await root.delete(recursive: true);
    } on FileSystemException {
      // Best effort (Windows may still hold a handle for a moment).
    }
  }
}

/// A fetched HTTP response.
final class Fetched {
  Fetched(this.status, this.headers, this.body, this.elapsed);

  final int status;
  final HttpHeaders headers;
  final Uint8List body;
  final Duration elapsed;

  String get text => utf8.decode(body, allowMalformed: true);
  Object? get json => jsonDecode(text);
  String? header(String name) => headers.value(name);
}

final HttpClient _client = HttpClient()..autoUncompress = false;

/// GET (or [method]) [url], reading the whole body.
Future<Fetched> fetch(
  String url, {
  Map<String, String> headers = const {},
  String method = 'GET',
  String? body,
  bool followRedirects = false,
}) async {
  final watch = Stopwatch()..start();
  final request = await _client.openUrl(method, Uri.parse(url));
  request.followRedirects = followRedirects;
  headers.forEach(request.headers.set);
  if (body != null) {
    request.headers.contentType = ContentType(
      'application',
      'x-www-form-urlencoded',
      charset: 'utf-8',
    );
    request.write(body);
  }
  final response = await request.close();
  final builder = BytesBuilder(copy: false);
  await for (final chunk in response) {
    builder.add(chunk);
  }
  return Fetched(
    response.statusCode,
    response.headers,
    builder.takeBytes(),
    watch.elapsed,
  );
}

/// Reads a (live) stream for [duration] and returns the byte count, or
/// stops earlier when the server ends the stream. `done` tells whether the
/// server closed it.
Future<
  ({int bytes, bool done, Duration elapsed, int status, String? contentType})
>
readStreamFor(
  String url,
  Duration duration, {
  Map<String, String> headers = const {},
}) async {
  final watch = Stopwatch()..start();
  final request = await _client.getUrl(Uri.parse(url));
  headers.forEach(request.headers.set);
  final response = await request.close();
  var bytes = 0;
  final finished = Completer<bool>();
  late final StreamSubscription<List<int>> sub;
  sub = response.listen(
    (chunk) => bytes += chunk.length,
    onDone: () {
      if (!finished.isCompleted) finished.complete(true);
    },
    onError: (Object _) {
      if (!finished.isCompleted) finished.complete(true);
    },
    cancelOnError: true,
  );
  final timer = Timer(duration, () {
    if (!finished.isCompleted) finished.complete(false);
  });
  final done = await finished.future;
  timer.cancel();
  if (!done) await sub.cancel();
  return (
    bytes: bytes,
    done: done,
    elapsed: watch.elapsed,
    status: response.statusCode,
    contentType: response.headers.contentType?.mimeType,
  );
}

/// Query string with the active test account.
const account =
    'username=${MockFixtures.username}&password=${MockFixtures.password}';

/// `/live/kanal/test123` style path prefix.
const creds = '${MockFixtures.username}/${MockFixtures.password}';
