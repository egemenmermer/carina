import 'package:flutter_test/flutter_test.dart';
import 'package:carina/player/engine/engine_errors.dart';
import 'package:carina/player/engine/playback_engine.dart';

void main() {
  group('classifyLogLine', () {
    test('HTTP status from FFmpeg http warnings', () {
      final e = classifyLogLine('[ffmpeg] http: HTTP error 404 Not Found')!;
      expect(e.kind, EngineErrorKind.http);
      expect(e.statusCode, 404);
      expect(e.message, contains('404'));
    });

    test('HTTP status from av_err2str messages', () {
      expect(
        classifyLogLine(
          '[ffmpeg] Server returned 403 Forbidden (access denied)',
        )!.statusCode,
        403,
      );
      expect(
        classifyLogLine(
          'Server returned 401 Unauthorized (authorization failed)',
        )!.statusCode,
        401,
      );
      final e500 = classifyLogLine('HTTP error 500 Internal Server Error')!;
      expect(e500.statusCode, 500);
      expect(e500.message, contains('Server error'));
    });

    test('generic 4XX / 5XX replies', () {
      final e4 = classifyLogLine(
        'Server returned 4XX Client Error, but not one of 40{0,1,3,4}',
      )!;
      expect(e4.kind, EngineErrorKind.http);
      expect(e4.statusCode, isNull);
      final e5 = classifyLogLine('Server returned 5XX Server Error reply')!;
      expect(e5.kind, EngineErrorKind.http);
      expect(e5.message, contains('Server error'));
    });

    test('readable messages for common statuses', () {
      expect(httpStatusMessage(401), contains('username and password'));
      expect(httpStatusMessage(403), contains('connection limit'));
      expect(httpStatusMessage(404), 'Stream not found (HTTP 404).');
      expect(httpStatusMessage(410), contains('HTTP 410'));
      expect(httpStatusMessage(503), contains('HTTP 503'));
    });

    test('timeouts', () {
      for (final line in [
        '[ffmpeg] tcp: Connection to tcp://h:80 failed: Operation timed out',
        'Connection timed out',
        '[stream] timeout while reading',
      ]) {
        expect(
          classifyLogLine(line)!.kind,
          EngineErrorKind.timeout,
          reason: line,
        );
      }
    });

    test('network failures', () {
      for (final line in [
        '[ffmpeg] tcp: Connection to tcp://127.0.0.1:9 failed: Connection refused',
        '[ffmpeg] tcp: Failed to resolve hostname nowhere.invalid: '
            'nodename nor servname provided, or not known',
        'Connection reset by peer',
        'Network is unreachable',
      ]) {
        expect(
          classifyLogLine(line)!.kind,
          EngineErrorKind.network,
          reason: line,
        );
      }
    });

    test('unsupported formats and codecs', () {
      final html = classifyLogLine(
        '[cplayer] Failed to recognize file format.',
      )!;
      expect(html.kind, EngineErrorKind.codec);
      expect(html.message, contains('Unrecognized stream format'));
      final codec = classifyLogLine(
        '[vd] Failed to initialize a decoder for codec \'foo\'.',
      )!;
      expect(codec.kind, EngineErrorKind.codec);
      expect(codec.message, contains('not supported'));
      expect(codec.retryable, isFalse);
    });

    test('ignores non-error lines', () {
      expect(classifyLogLine(''), isNull);
      expect(classifyLogLine('[cplayer] Playing: file.ts'), isNull);
      expect(classifyLogLine('HTTP error 200 OK'), isNull);
    });

    test('masks URLs in the detail', () {
      final e = classifyLogLine(
        '[ffmpeg] http: HTTP error 404 for '
        'http://provider.example:8080/live/user/secret/1001.ts?password=x',
      )!;
      expect(e.detail, isNot(contains('secret')));
      expect(e.detail, isNot(contains('user')));
      expect(e.detail, isNot(contains('password')));
      expect(e.detail, contains('pro***:8080/…/1001.ts'));
    });
  });

  group('errorFromLogLines', () {
    test('HTTP wins over network and generic lines', () {
      final e = errorFromLogLines([
        '[cplayer] Failed to recognize file format.',
        '[ffmpeg] tcp: Connection reset by peer',
        '[ffmpeg] http: HTTP error 404 Not Found',
      ]);
      expect(e.kind, EngineErrorKind.http);
      expect(e.statusCode, 404);
    });

    test('timeout wins over codec', () {
      final e = errorFromLogLines([
        '[cplayer] Failed to recognize file format.',
        'Operation timed out',
      ]);
      expect(e.kind, EngineErrorKind.timeout);
    });

    test('fallbacks', () {
      expect(errorFromLogLines(const []).kind, EngineErrorKind.unknown);
      expect(errorFromLogLines(const []).message, 'Playback failed.');
      expect(
        errorFromLogLines(const ['nothing useful'], timedOut: true).kind,
        EngineErrorKind.timeout,
      );
    });

    test('ended and timeout helpers', () {
      expect(endedError().kind, EngineErrorKind.ended);
      expect(endedError().message, 'The stream ended.');
      expect(endedError().retryable, isTrue);
      expect(timeoutError().kind, EngineErrorKind.timeout);
    });
  });

  test('isSharedFfmpegLine', () {
    expect(
      isSharedFfmpegLine('[ffmpeg] http: HTTP error 403 Forbidden'),
      isTrue,
    );
    expect(isSharedFfmpegLine('[ffmpeg/demuxer] mpegts: bad packet'), isTrue);
    expect(
      isSharedFfmpegLine('[cplayer] Failed to recognize file format.'),
      isFalse,
    );
    expect(isSharedFfmpegLine('[stream] Failed to open x.'), isFalse);
  });

  group('URL masking', () {
    test('maskUrlForLog', () {
      expect(
        maskUrlForLog('http://provider.example:8080/live/u/p/1001.ts?x=1'),
        'http://pro***:8080/…/1001.ts',
      );
      expect(maskUrlForLog('https://ab/'), 'https://ab***');
      expect(maskUrlForLog('not a url'), '<url>');
    });

    test('scrubUrls replaces every URL', () {
      final s = scrubUrls(
        'a http://one.example/u/p/1.ts b https://two.example/x.m3u8?t=1 c',
      );
      expect(s, 'a http://one***/…/1.ts b https://two***/…/x.m3u8 c');
    });
  });

  group('hardware decoder failures', () {
    test('detected', () {
      for (final line in [
        'Attempting next decoding method after failure of videotoolbox.',
        'Failed to open VDPAU backend libvdpau_nvidia.so',
        'Failed to create D3D11VA device',
        'Could not create device.',
        'hardware decoding failed',
        'videotoolbox: decoder error -12909',
      ]) {
        expect(isHwdecFailureLine('vd', line), isTrue, reason: line);
      }
    });

    test('not detected', () {
      expect(
        isHwdecFailureLine(
          'vd',
          'Error while decoding frame (hardware decoding)!',
        ),
        isFalse,
      );
      expect(isHwdecFailureLine('vd', 'Using software decoding.'), isFalse);
      expect(
        isHwdecFailureLine('cplayer', 'Failed to recognize file format.'),
        isFalse,
      );
      expect(
        isHwdecFailureLine('media_kit', 'error: hwdec failed _command(...)'),
        isFalse,
      );
      // FFmpeg's lines may belong to another player (one mpv instance gets
      // all of them).
      expect(
        isHwdecFailureLine(
          'ffmpeg/video',
          'h264: hardware accelerator failed to decode picture',
        ),
        isFalse,
      );
    });
  });
}
