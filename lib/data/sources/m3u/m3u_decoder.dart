// Byte stream → decoded lines for the streaming M3U parser.

import 'dart:convert';
import 'dart:typed_data';

const int _lf = 0x0A;
const int _cr = 0x0D;

/// Splits bytes into lines (LF, CRLF or CR, also across chunk boundaries)
/// and decodes every line with [decodeM3uLine].
class M3uByteLineSplitter {
  M3uByteLineSplitter(this._onLine);

  final void Function(String line) _onLine;
  final BytesBuilder _carry = BytesBuilder();
  bool _skipLf = false;
  bool _closed = false;

  void add(List<int> chunk) {
    if (_closed) throw StateError('M3uByteLineSplitter is closed');
    final n = chunk.length;
    var start = 0;
    var i = 0;
    if (_skipLf && n > 0) {
      if (chunk[0] == _lf) {
        start = 1;
        i = 1;
      }
      _skipLf = false;
    }
    for (; i < n; i++) {
      final b = chunk[i];
      if (b != _lf && b != _cr) continue;
      _emit(chunk, start, i);
      if (b == _cr) {
        if (i + 1 < n) {
          if (chunk[i + 1] == _lf) i++;
        } else {
          _skipLf = true;
        }
      }
      start = i + 1;
    }
    if (start < n) {
      _carry.add(start == 0 ? chunk : chunk.sublist(start));
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    if (_carry.isNotEmpty) {
      final bytes = _carry.takeBytes();
      _onLine(decodeM3uLine(bytes, 0, bytes.length));
    }
  }

  void _emit(List<int> chunk, int start, int end) {
    if (_carry.isEmpty) {
      _onLine(decodeM3uLine(chunk, start, end));
      return;
    }
    if (end > start) _carry.add(chunk.sublist(start, end));
    final bytes = _carry.takeBytes();
    _onLine(decodeM3uLine(bytes, 0, bytes.length));
  }
}

const Utf8Decoder _strictUtf8 = Utf8Decoder();
const Utf8Decoder _lenientUtf8 = Utf8Decoder(allowMalformed: true);

/// Decodes one line of bytes.
///
/// Valid UTF-8 is decoded as UTF-8. A line that is not valid UTF-8 is decoded
/// leniently as UTF-8 (bad bytes become U+FFFD) when it still contains valid
/// multi-byte UTF-8 sequences, so a single corrupt byte does not garble the
/// rest of the line; otherwise it is decoded as Latin-1 in its Windows-1252
/// form (what servers labelled `iso-8859-1` really send, per WHATWG).
String decodeM3uLine(List<int> bytes, int start, int end) {
  var ascii = true;
  for (var i = start; i < end; i++) {
    if (bytes[i] > 0x7F) {
      ascii = false;
      break;
    }
  }
  if (ascii) return String.fromCharCodes(bytes, start, end);
  try {
    return _strictUtf8.convert(bytes, start, end);
  } on FormatException {
    if (_hasUtf8Sequence(bytes, start, end)) {
      return _lenientUtf8.convert(bytes, start, end);
    }
    return _decodeWindows1252(bytes, start, end);
  }
}

bool _hasUtf8Sequence(List<int> bytes, int start, int end) {
  for (var i = start; i < end; i++) {
    final b = bytes[i];
    final int extra;
    if (b >= 0xC2 && b <= 0xDF) {
      extra = 1;
    } else if (b >= 0xE0 && b <= 0xEF) {
      extra = 2;
    } else if (b >= 0xF0 && b <= 0xF4) {
      extra = 3;
    } else {
      continue;
    }
    if (i + extra >= end) continue;
    var ok = true;
    for (var k = 1; k <= extra; k++) {
      final c = bytes[i + k];
      if (c < 0x80 || c > 0xBF) {
        ok = false;
        break;
      }
    }
    if (ok) return true;
  }
  return false;
}

// Windows-1252 code points for bytes 0x80-0x9F (undefined bytes map to the
// C1 control with the same value, like the WHATWG decoder).
const List<int> _cp1252High = [
  0x20AC, 0x0081, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, //
  0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0x008D, 0x017D, 0x008F, //
  0x0090, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, //
  0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x009D, 0x017E, 0x0178, //
];

String _decodeWindows1252(List<int> bytes, int start, int end) {
  final codes = Uint16List(end - start);
  for (var i = start; i < end; i++) {
    final b = bytes[i] & 0xFF;
    codes[i - start] = b >= 0x80 && b <= 0x9F ? _cp1252High[b - 0x80] : b;
  }
  return String.fromCharCodes(codes);
}
