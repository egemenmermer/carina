import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

/// M0 decode probe (`--probe --media <file> [--probe-out <json>]`): plays one
/// file with a raw media_kit player, writes mpv decode info as JSON and
/// exits. The Windows CI uses it as a quick codec gate.
class M0App extends StatefulWidget {
  const M0App({super.key, this.media, this.probe = false, this.probeOut});
  final String? media;
  final bool probe;
  final String? probeOut;

  @override
  State<M0App> createState() => _M0AppState();
}

class _M0AppState extends State<M0App> {
  late final Player player = Player(
    configuration: const PlayerConfiguration(title: 'Carina'),
  );
  late final VideoController controller = VideoController(player);
  String status = 'Carina M0';

  @override
  void initState() {
    super.initState();
    final media = widget.media;
    if (media != null) {
      unawaited(_play(media));
    }
  }

  Future<void> _play(String media) async {
    // CI runners have no audio device: keep decoding audio via a null output.
    await (player.platform as NativePlayer).setProperty(
      'audio-fallback-to-null',
      'yes',
    );
    await player.open(Media(media));
    if (!widget.probe) return;
    await Future<void>.delayed(const Duration(seconds: 4));
    final native = player.platform as NativePlayer;
    Future<String> prop(String name) async {
      try {
        return await native.getProperty(name);
      } catch (e) {
        return 'error: $e';
      }
    }

    final db = sql.sqlite3.openInMemory();
    String fts5;
    try {
      db.execute('CREATE VIRTUAL TABLE t USING fts5(x)');
      fts5 = 'ok';
    } catch (e) {
      fts5 = 'error: $e';
    } finally {
      db.close();
    }

    final info = <String, Object?>{
      'audio-codec-name': await prop('audio-codec-name'),
      'audio-params/channel-count': await prop('audio-params/channel-count'),
      'audio-params/samplerate': await prop('audio-params/samplerate'),
      'video-codec': await prop('video-codec'),
      'video-params/w': await prop('video-params/w'),
      'video-params/h': await prop('video-params/h'),
      'hwdec-current': await prop('hwdec-current'),
      'position': player.state.position.inMilliseconds,
      'width': player.state.width,
      'sqlite_version': sql.sqlite3.version.libVersion,
      'fts5': fts5,
    };
    stdout.writeln('M0_PROBE ${jsonEncode(info)}');
    final out = widget.probeOut;
    if (out != null) {
      await File(out).writeAsString(jsonEncode(info));
    }
    setState(() => status = jsonEncode(info));
    await player.dispose();
    exit(0);
  }

  @override
  void dispose() {
    unawaited(player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(child: Video(controller: controller)),
            Positioned(
              left: 16,
              top: 16,
              child: Text(status, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
