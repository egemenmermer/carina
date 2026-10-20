import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../sources/source_exception.dart';
import 'mask.dart';
import 'net_errors.dart';

/// Minimum interval between two progress callbacks (the final one is always
/// delivered).
const Duration downloadProgressInterval = Duration(milliseconds: 100);

/// Streams [url] to the file at [path] without holding the body in memory.
///
/// The body is written to `<path>.part` and renamed to [path] when complete,
/// so a cancelled or failed download never leaves a truncated file behind
/// (an existing file at [path] is replaced only on success).
///
/// [onProgress] receives the bytes written so far and the expected total
/// (`null` when the server sends no length or a gzip-encoded body). It is
/// throttled to [downloadProgressInterval] and always called once at the end.
///
/// Throws [SourceException]: the mapped status for a non-2xx answer,
/// `emptyBody` for a 2xx answer without bytes, `cancelled` when
/// [cancelToken] is cancelled, and the mapped transport error otherwise.
/// File system errors are rethrown as they are.
Future<File> downloadToFile(
  Dio dio,
  String url,
  String path, {
  void Function(int received, int? total)? onProgress,
  CancelToken? cancelToken,
}) async {
  // An internal token lets us abort the transfer ourselves (error status)
  // and still honour the caller's token.
  final token = CancelToken();
  if (cancelToken != null) {
    if (cancelToken.isCancelled) {
      throw SourceException(
        SourceErrorKind.cancelled,
        message: 'Download cancelled',
        url: maskUrl(url),
      );
    }
    unawaited(
      cancelToken.whenCancel.then((_) {
        if (!token.isCancelled) token.cancel('cancelled by caller');
      }),
    );
  }

  final Response<ResponseBody> response;
  try {
    response = await dio.get<ResponseBody>(
      url,
      cancelToken: token,
      options: Options(responseType: ResponseType.stream),
    );
  } on DioException catch (e) {
    throw mapDioError(e, url: url);
  }

  final status = response.statusCode;
  final body = response.data;
  if (!isSuccessStatus(status) || body == null) {
    if (!token.isCancelled) token.cancel('unexpected status');
    throw sourceExceptionForStatus(status ?? 0, url: url);
  }

  final total = _expectedLength(response.headers);
  final target = File(path);
  final part = File('$path.part');
  await part.parent.create(recursive: true);
  final raf = await part.open(mode: FileMode.write);
  var received = 0;
  final clock = Stopwatch()..start();
  var lastReport = -downloadProgressInterval.inMilliseconds;
  try {
    await for (final chunk in body.stream) {
      await raf.writeFrom(chunk);
      received += chunk.length;
      if (onProgress != null &&
          clock.elapsedMilliseconds - lastReport >=
              downloadProgressInterval.inMilliseconds) {
        lastReport = clock.elapsedMilliseconds;
        onProgress(received, total);
      }
    }
    await raf.flush();
  } catch (e) {
    // Stop the transfer: leaving the loop alone does not close the socket.
    if (!token.isCancelled) token.cancel('download failed');
    await _closeQuietly(raf);
    await _deleteQuietly(part);
    if (cancelToken?.isCancelled ?? false) {
      throw SourceException(
        SourceErrorKind.cancelled,
        message: 'Download cancelled',
        url: maskUrl(url),
      );
    }
    if (e is DioException ||
        (e is IOException && e is! FileSystemException) ||
        e is TimeoutException) {
      throw mapNetworkError(e, url: url);
    }
    rethrow;
  }
  await raf.close();

  if (received == 0) {
    await _deleteQuietly(part);
    throw SourceException(
      SourceErrorKind.emptyBody,
      statusCode: status,
      message: 'Empty download',
      url: maskUrl(url),
    );
  }
  onProgress?.call(received, total);
  if (await target.exists()) await target.delete();
  return part.rename(path);
}

int? _expectedLength(Headers headers) {
  final encoding = headers.value(Headers.contentEncodingHeader)?.toLowerCase();
  if (encoding != null && encoding != 'identity') return null;
  final length = int.tryParse(
    headers.value(Headers.contentLengthHeader)?.trim() ?? '',
  );
  return (length == null || length <= 0) ? null : length;
}

Future<void> _closeQuietly(RandomAccessFile raf) async {
  try {
    await raf.close();
  } on Object {
    // Already closed.
  }
}

Future<void> _deleteQuietly(File file) async {
  try {
    if (await file.exists()) await file.delete();
  } on Object {
    // Best effort.
  }
}
