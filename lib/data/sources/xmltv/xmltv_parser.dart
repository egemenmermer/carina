/// Streaming XMLTV parser built on the `package:xml` event API (no DOM).
library;

import 'dart:convert';
import 'dart:io' show gzip;

import 'package:xml/xml.dart'
    show XmlDefaultEntityMapping, XmlException, XmlParserException;
import 'package:xml/xml_events.dart';

import '../source_exception.dart';
import 'xmltv_models.dart';
import 'xmltv_time.dart';

/// Parses an XMLTV document from raw bytes into [XmltvChannel] and
/// [XmltvProgramme] events, in document order (except that a programme
/// without a `stop` is held back until the next programme of its channel,
/// see [XmltvProgramme.stop]).
///
/// * gzip is detected from the magic bytes `1F 8B` (any file name) and
///   decompressed on the fly; xz / bzip2 / zip / zstd are rejected with a
///   clear message. The text is decoded as UTF-8 (malformed bytes become
///   U+FFFD). Known limitation: multi-member gzip (`cat a.gz b.gz`) relies
///   on dart:io's streaming inflater, which loses data when a member ends in
///   a call that produces no output; that surfaces as an `unparseable` error
///   (never as silently truncated data). Single-member gzip, which XMLTV
///   generators produce, is not affected.
/// * Nothing is accumulated: events go straight from the byte chunks to the
///   listener, so memory stays flat for any document size.
/// * CDATA, XML and HTML entities (`&amp;`, `&#039;`, `&nbsp;`), self-closing
///   tags, comments, unknown elements and attributes are handled; text is
///   whitespace-collapsed (descriptions keep their line breaks).
/// * [preferredLanguages] (`['tr', 'en']`, matched on the primary subtag)
///   picks `title`, `sub-title`, `desc` and `category` by their `lang`
///   attribute and the primary display name of a channel; without a match
///   the first one in the document wins.
/// * Times are UTC and no time shift is applied (the batch runners do that).
///
/// Errors arrive as [SourceException]: `emptyBody` for an empty input,
/// `unparseable` for malformed or truncated XML, a non-`<tv>` root element
/// (an HTML error page, for example), corrupt gzip data or an unsupported
/// compression. Errors of [bytes] itself are passed through unchanged.
Stream<XmltvEvent> parseXmltv(
  Stream<List<int>> bytes, {
  List<String> preferredLanguages = const [],
}) async* {
  final out = <XmltvEvent>[];
  final parser = XmltvSaxParser(
    onChannel: out.add,
    onProgramme: out.add,
    preferredLanguages: preferredLanguages,
  );
  await for (final chunk in bytes) {
    parser.add(chunk);
    if (out.isEmpty) continue;
    final ready = List<XmltvEvent>.of(out);
    out.clear();
    for (final event in ready) {
      yield event;
    }
  }
  parser.close();
  for (final event in out) {
    yield event;
  }
}

/// `xmltv_ns` episode numbers (`season.episode.part`, zero-based, each part
/// `N` or `N/total`) in display form: `0.4.` → `S1 E5`, `.4.` → `E5`,
/// `2..` → `S3`. Null when neither season nor episode is present.
String? formatXmltvEpisode(String xmltvNs) {
  final parts = xmltvNs.split('.');
  final season = _episodePart(parts[0]);
  final episode = parts.length > 1 ? _episodePart(parts[1]) : null;
  if (season == null && episode == null) return null;
  if (season == null) return 'E${episode! + 1}';
  if (episode == null) return 'S${season + 1}';
  return 'S${season + 1} E${episode + 1}';
}

int? _episodePart(String part) {
  final slash = part.indexOf('/');
  final text = (slash < 0 ? part : part.substring(0, slash)).trim();
  if (text.isEmpty) return null;
  final n = int.tryParse(text);
  return n == null || n < 0 || n > 100000 ? null : n;
}

/// A stop-less programme is given [_defaultDurationMs] unless the next
/// programme of the channel starts within [_maxDerivedGapMs].
const int _defaultDurationMs = 30 * 60 * 1000;
const int _maxDerivedGapMs = 24 * 60 * 60 * 1000;

/// Text between markup can be held back at most this long (see
/// [_XmlChunker]); only reached by documents with megabytes of text.
const int _maxCarry = 4 << 20;

const int _noContainer = 0;
const int _inChannel = 1;
const int _inProgramme = 2;

const int _fNone = 0;
const int _fTitle = 1;
const int _fSubTitle = 2;
const int _fDesc = 3;
const int _fCategory = 4;
const int _fEpisode = 5;
const int _fRating = 6;
const int _fImage = 7;
const int _fDisplayName = 8;

/// The synchronous engine behind [parseXmltv] and the batch runners: feed it
/// byte chunks with [add] and finish with [close]; channels and programmes
/// are delivered to the callbacks while [add] runs.
///
/// [shift] is added to every time (the playlist EPG shift; [parseXmltv]
/// passes zero). Programmes that do not overlap [windowStart]–[windowEnd]
/// (shifted times) are skipped as early as possible: their content is not
/// even collected.
///
/// Every failure is thrown as a [SourceException] (see [parseXmltv]).
final class XmltvSaxParser {
  XmltvSaxParser({
    required this.onChannel,
    required this.onProgramme,
    List<String> preferredLanguages = const [],
    Duration shift = Duration.zero,
    DateTime? windowStart,
    DateTime? windowEnd,
  }) : _languages = [
         for (final l in preferredLanguages)
           if (l.trim().isNotEmpty) _primarySubtag(l.trim().toLowerCase()),
       ],
       _shiftMs = shift.inMilliseconds,
       _windowStartRaw = windowStart == null
           ? -_unbounded
           : windowStart.millisecondsSinceEpoch - shift.inMilliseconds,
       _windowEndRaw = windowEnd == null
           ? _unbounded
           : windowEnd.millisecondsSinceEpoch - shift.inMilliseconds {
    _xml = XmlEventDecoder(
      entityMapping: const XmlDefaultEntityMapping.html5(),
      validateNesting: true,
    ).startChunkedConversion(_EventSink(this));
    _text8 = const Utf8Decoder(allowMalformed: true)
        .startChunkedConversion(_XmlChunker(_xml));
  }

  static const int _unbounded = 1 << 60;

  final void Function(XmltvChannel channel) onChannel;
  final void Function(XmltvProgramme programme) onProgramme;

  final List<String> _languages;
  final int _shiftMs;
  final int _windowStartRaw;
  final int _windowEndRaw;

  late final StringConversionSink _xml;
  late final ByteConversionSink _text8;
  ByteConversionSink? _input;
  final List<int> _head = [];
  bool _closed = false;

  int _bytesRead = 0;

  /// Input bytes consumed so far (compressed bytes for gzip input).
  int get bytesRead => _bytesRead;

  int _channels = 0;
  int _programmes = 0;
  int _outsideWindow = 0;
  int _invalid = 0;
  int _derivedStops = 0;

  /// Channels delivered so far.
  int get channelCount => _channels;

  /// Programmes delivered so far.
  int get programmeCount => _programmes;

  /// Programmes dropped because they do not overlap the window.
  int get outsideWindowCount => _outsideWindow;

  /// Programmes dropped for a missing channel or an unparseable start.
  int get invalidCount => _invalid;

  /// Delivered programmes whose stop was derived.
  int get derivedStopCount => _derivedStops;

  // Document state.
  int _depth = 0;
  bool _sawRoot = false;
  bool _rootClosed = false;
  int _container = _noContainer;
  bool _skip = false;
  bool _inRating = false;

  // Text capture.
  int _capture = _fNone;
  int _captureLevel = 0;
  String? _captureAttr;
  String? _text;
  StringBuffer? _textBuffer;
  bool _multiPiece = false;

  // Programme fields.
  String _pChannel = '';
  int _pStart = 0;
  int? _pStop;
  String? _pTitle;
  int _pTitleRank = 0;
  String? _pSubTitle;
  int _pSubTitleRank = 0;
  String? _pDesc;
  int _pDescRank = 0;
  String? _pCategory;
  int _pCategoryRank = 0;
  String? _pEpisodeNs;
  String? _pEpisodeOnscreen;
  String? _pIcon;
  String? _pImage;
  String? _pRating;

  // Channel fields.
  String _cId = '';
  final List<String> _cNames = [];
  final List<int> _cRanks = [];
  String? _cIcon;

  /// Stop-less programmes waiting for the next programme of their channel.
  final Map<String, _Pending> _pending = {};

  /// Channel ids, categories and ratings repeat a lot; sharing one instance
  /// saves memory and makes batches cheaper to send between isolates.
  final Map<String, String> _strings = {};

  /// Feeds the next chunk of the document.
  void add(List<int> chunk) {
    if (_closed) throw StateError('XmltvSaxParser is closed');
    _bytesRead += chunk.length;
    try {
      final input = _input;
      if (input != null) {
        input.add(chunk);
      } else if (_head.isEmpty && chunk.length >= 6) {
        _startPipeline(chunk).add(chunk);
      } else {
        _head.addAll(chunk);
        if (_head.length >= 6) _startPipeline(_head).add(_head);
      }
    } on SourceException {
      rethrow;
    } catch (error) {
      throw _wrap(error);
    }
  }

  /// Ends the document: validates that it was complete and delivers the
  /// programmes still waiting for a derived stop.
  void close() {
    if (_closed) return;
    _closed = true;
    try {
      var input = _input;
      if (input == null) {
        if (_head.isEmpty) {
          throw const SourceException(
            SourceErrorKind.emptyBody,
            message: 'The XMLTV source is empty',
          );
        }
        input = _startPipeline(_head)..add(_head);
      }
      input.close();
    } on SourceException {
      rethrow;
    } catch (error) {
      throw _wrap(error);
    }
    if (!_sawRoot) {
      throw const SourceException(
        SourceErrorKind.unparseable,
        message: 'Not an XMLTV document: no <tv> element',
      );
    }
    for (final pending in _pending.values) {
      _emitPending(pending, null);
    }
    _pending.clear();
  }

  ByteConversionSink _startPipeline(List<int> head) {
    final b0 = head[0];
    final b1 = head.length > 1 ? head[1] : -1;
    String? unsupported;
    if (b0 == 0xFD && b1 == 0x37) unsupported = 'xz';
    if (b0 == 0x42 && b1 == 0x5A && head.length > 2 && head[2] == 0x68) {
      unsupported = 'bzip2';
    }
    if (b0 == 0x50 && b1 == 0x4B) unsupported = 'zip';
    if (b0 == 0x28 && b1 == 0xB5) unsupported = 'zstd';
    if (unsupported != null) {
      throw SourceException(
        SourceErrorKind.unparseable,
        message:
            'The XMLTV source is $unsupported-compressed; only plain '
            'XML and gzip are supported',
      );
    }
    final isGzip = b0 == 0x1F && b1 == 0x8B;
    return _input = isGzip
        ? gzip.decoder.startChunkedConversion(_text8)
        : _text8;
  }

  SourceException _wrap(Object error) {
    final String message;
    if (error is XmlParserException) {
      message =
          'Malformed XMLTV: ${error.message}'
          '${error.position == null ? '' : ' (character ${error.position})'}';
    } else if (error is XmlException) {
      message = 'Malformed XMLTV: ${error.message}';
    } else if (error is FormatException) {
      message = 'Corrupt XMLTV data: ${error.message}';
    } else {
      message = 'XMLTV parsing failed: $error';
    }
    return SourceException(SourceErrorKind.unparseable, message: message);
  }

  void _onEvents(List<XmlEvent> events) {
    for (var i = 0; i < events.length; i++) {
      final event = events[i];
      if (event is XmlTextEvent) {
        if (_capture != _fNone) _appendText(event.value);
      } else if (event is XmlStartElementEvent) {
        _start(event);
      } else if (event is XmlEndElementEvent) {
        _end();
      } else if (event is XmlCDATAEvent) {
        if (_capture != _fNone) _appendText(event.value);
      }
      // Comments, declarations, doctypes and processing instructions are
      // ignored.
    }
  }

  void _start(XmlStartElementEvent e) {
    final level = _depth;
    final selfClosing = e.isSelfClosing;
    if (!selfClosing) _depth++;
    if (_rootClosed) return;
    switch (level) {
      case 0:
        if (e.name != 'tv') {
          throw SourceException(
            SourceErrorKind.unparseable,
            message: 'Not an XMLTV document: the root element is <${e.name}>',
          );
        }
        _sawRoot = true;
        if (selfClosing) _rootClosed = true;
      case 1:
        final name = e.name;
        if (name == 'programme') {
          _beginProgramme(e);
          if (selfClosing) _endProgramme();
        } else if (name == 'channel') {
          _beginChannel(e);
          if (selfClosing) _endChannel();
        }
      case 2:
        if (_container == _inProgramme) {
          if (!_skip) _programmeChild(e, selfClosing);
        } else if (_container == _inChannel) {
          _channelChild(e, selfClosing);
        }
      case 3:
        if (_inRating &&
            !selfClosing &&
            _capture == _fNone &&
            _pRating == null &&
            e.name == 'value') {
          _beginCapture(_fRating, 3, null);
        }
    }
  }

  void _end() {
    final level = --_depth;
    if (_capture != _fNone) {
      if (level == _captureLevel) _finishCapture();
      return;
    }
    switch (level) {
      case 0:
        _rootClosed = true;
      case 1:
        if (_container == _inProgramme) {
          _endProgramme();
        } else if (_container == _inChannel) {
          _endChannel();
        }
      case 2:
        _inRating = false;
    }
  }

  void _beginCapture(int field, int level, String? attr) {
    _capture = field;
    _captureLevel = level;
    _captureAttr = attr;
    _text = null;
    _multiPiece = false;
  }

  void _appendText(String s) {
    final first = _text;
    if (first == null) {
      _text = s;
      return;
    }
    final buffer = _textBuffer ??= StringBuffer();
    if (!_multiPiece) {
      buffer
        ..clear()
        ..write(first);
      _multiPiece = true;
    }
    buffer.write(s);
  }

  void _finishCapture() {
    final field = _capture;
    _capture = _fNone;
    final raw = _multiPiece ? _textBuffer.toString() : (_text ?? '');
    _text = null;
    _multiPiece = false;
    switch (field) {
      case _fTitle:
        final v = _line(raw);
        if (v.isEmpty) return;
        final rank = _rank(_captureAttr);
        if (_pTitle == null || rank < _pTitleRank) {
          _pTitle = v;
          _pTitleRank = rank;
        }
      case _fSubTitle:
        final v = _line(raw);
        if (v.isEmpty) return;
        final rank = _rank(_captureAttr);
        if (_pSubTitle == null || rank < _pSubTitleRank) {
          _pSubTitle = v;
          _pSubTitleRank = rank;
        }
      case _fDesc:
        final v = _paragraph(raw);
        if (v.isEmpty) return;
        final rank = _rank(_captureAttr);
        if (_pDesc == null || rank < _pDescRank) {
          _pDesc = v;
          _pDescRank = rank;
        }
      case _fCategory:
        final v = _line(raw);
        if (v.isEmpty) return;
        final rank = _rank(_captureAttr);
        if (_pCategory == null || rank < _pCategoryRank) {
          _pCategory = _intern(v);
          _pCategoryRank = rank;
        }
      case _fEpisode:
        final system = _captureAttr?.trim().toLowerCase() ?? 'onscreen';
        if (system == 'xmltv_ns') {
          _pEpisodeNs ??= raw;
        } else if (system == 'onscreen' ||
            system == 'sxxexx' ||
            system == 'common') {
          final v = _line(raw);
          if (v.isNotEmpty) _pEpisodeOnscreen ??= v;
        }
      case _fRating:
        final v = _line(raw);
        if (v.isNotEmpty) _pRating ??= _intern(v);
      case _fImage:
        final v = raw.trim();
        if (v.isNotEmpty) _pImage ??= v;
      case _fDisplayName:
        final v = _line(raw);
        if (v.isNotEmpty) {
          _cNames.add(v);
          _cRanks.add(_rank(_captureAttr));
        }
    }
  }

  void _beginProgramme(XmlStartElementEvent e) {
    _container = _inProgramme;
    _skip = false;
    _inRating = false;
    String? start;
    String? stop;
    String? channel;
    final attributes = e.attributes;
    for (var i = 0; i < attributes.length; i++) {
      final a = attributes[i];
      switch (a.name) {
        case 'start':
          start = a.value;
        case 'stop':
          stop = a.value;
        case 'channel':
          channel = a.value;
      }
    }
    final startMs = start == null ? null : xmltvTimeToEpochMs(start);
    final channelId = channel == null ? '' : channel.trim();
    if (startMs == null || channelId.isEmpty) {
      _invalid++;
      _skip = true;
      return;
    }
    final id = _intern(channelId);
    if (_pending.isNotEmpty) {
      final waiting = _pending.remove(id);
      if (waiting != null) _emitPending(waiting, startMs);
    }
    var stopMs = stop == null ? null : xmltvTimeToEpochMs(stop);
    if (stopMs != null && stopMs <= startMs) stopMs = null;
    if (startMs >= _windowEndRaw ||
        (stopMs != null && stopMs <= _windowStartRaw)) {
      _outsideWindow++;
      _skip = true;
      return;
    }
    _pChannel = id;
    _pStart = startMs;
    _pStop = stopMs;
    _pTitle = null;
    _pSubTitle = null;
    _pDesc = null;
    _pCategory = null;
    _pEpisodeNs = null;
    _pEpisodeOnscreen = null;
    _pIcon = null;
    _pImage = null;
    _pRating = null;
  }

  void _programmeChild(XmlStartElementEvent e, bool selfClosing) {
    switch (e.name) {
      case 'title':
        if (!selfClosing) _beginCapture(_fTitle, 2, _attr(e, 'lang'));
      case 'sub-title':
        if (!selfClosing) _beginCapture(_fSubTitle, 2, _attr(e, 'lang'));
      case 'desc':
        if (!selfClosing) _beginCapture(_fDesc, 2, _attr(e, 'lang'));
      case 'category':
        if (!selfClosing) _beginCapture(_fCategory, 2, _attr(e, 'lang'));
      case 'episode-num':
        if (!selfClosing) _beginCapture(_fEpisode, 2, _attr(e, 'system'));
      case 'icon':
        if (_pIcon == null) {
          final src = _attr(e, 'src')?.trim();
          if (src != null && src.isNotEmpty) _pIcon = src;
        }
      case 'rating':
        if (!selfClosing) _inRating = true;
      case 'image':
        if (!selfClosing && _pImage == null) _beginCapture(_fImage, 2, null);
    }
  }

  void _endProgramme() {
    _container = _noContainer;
    _inRating = false;
    if (_skip) {
      _skip = false;
      return;
    }
    final stop = _pStop;
    final episodeNs = _pEpisodeNs;
    final programme = XmltvProgramme(
      channelId: _pChannel,
      start: _utc(_pStart),
      stop: _utc(stop ?? _pStart + _defaultDurationMs),
      title: _pTitle ?? '',
      subTitle: _pSubTitle,
      description: _pDesc,
      category: _pCategory,
      episodeNum:
          (episodeNs == null ? null : formatXmltvEpisode(episodeNs)) ??
          _pEpisodeOnscreen,
      episodeOnscreen: _pEpisodeOnscreen,
      icon: _pIcon ?? _pImage,
      rating: _pRating,
    );
    if (stop == null) {
      _pending[_pChannel] = _Pending(programme, _pStart);
      return;
    }
    _programmes++;
    onProgramme(programme);
  }

  /// Delivers a stop-less programme once the start of the next programme of
  /// its channel ([nextStartRaw]) is known, or at the end of the document.
  void _emitPending(_Pending pending, int? nextStartRaw) {
    var programme = pending.programme;
    var stopRaw = pending.rawStart + _defaultDurationMs;
    if (nextStartRaw != null) {
      final gap = nextStartRaw - pending.rawStart;
      if (gap > 0 && gap <= _maxDerivedGapMs && gap != _defaultDurationMs) {
        stopRaw = nextStartRaw;
        programme = programme.copyWith(stop: _utc(stopRaw));
      }
    }
    if (stopRaw <= _windowStartRaw || pending.rawStart >= _windowEndRaw) {
      _outsideWindow++;
      return;
    }
    _derivedStops++;
    _programmes++;
    onProgramme(programme);
  }

  void _beginChannel(XmlStartElementEvent e) {
    _container = _inChannel;
    _cId = _attr(e, 'id')?.trim() ?? '';
    _cNames.clear();
    _cRanks.clear();
    _cIcon = null;
  }

  void _channelChild(XmlStartElementEvent e, bool selfClosing) {
    switch (e.name) {
      case 'display-name':
        if (!selfClosing) _beginCapture(_fDisplayName, 2, _attr(e, 'lang'));
      case 'icon':
        if (_cIcon == null) {
          final src = _attr(e, 'src')?.trim();
          if (src != null && src.isNotEmpty) _cIcon = src;
        }
    }
  }

  void _endChannel() {
    _container = _noContainer;
    if (_cId.isEmpty) return;
    final names = <String>[];
    var best = -1;
    for (var i = 0; i < _cNames.length; i++) {
      final name = _cNames[i];
      if (names.contains(name)) continue;
      names.add(name);
      if (best < 0 || _cRanks[i] < _cRanks[best]) best = i;
    }
    if (best > 0) {
      final preferred = _cNames[best];
      names
        ..remove(preferred)
        ..insert(0, preferred);
    }
    _channels++;
    onChannel(
      XmltvChannel(id: _intern(_cId), displayNames: names, icon: _cIcon),
    );
  }

  DateTime _utc(int rawMs) =>
      DateTime.fromMillisecondsSinceEpoch(rawMs + _shiftMs, isUtc: true);

  String _intern(String s) {
    if (_strings.length > 50000) _strings.clear();
    return _strings[s] ??= s;
  }

  /// 0 for the first preferred language, …; `_languages.length` otherwise.
  int _rank(String? lang) {
    final prefs = _languages;
    if (prefs.isEmpty) return 0;
    if (lang == null) return prefs.length;
    for (var i = 0; i < prefs.length; i++) {
      if (_sameLanguage(lang, prefs[i])) return i;
    }
    return prefs.length;
  }
}

final class _Pending {
  const _Pending(this.programme, this.rawStart);

  final XmltvProgramme programme;
  final int rawStart;
}

final class _EventSink implements Sink<List<XmlEvent>> {
  _EventSink(this._parser);

  final XmltvSaxParser _parser;

  @override
  void add(List<XmlEvent> data) => _parser._onEvents(data);

  @override
  void close() {}
}

/// Hands text to the XML decoder only up to the last `<` of each chunk, so a
/// text node (and an entity such as `&amp;` inside it) is never split
/// between two decoder calls: `package:xml` decodes the entities of each
/// text event on its own.
final class _XmlChunker implements Sink<String> {
  _XmlChunker(this._xml);

  final StringConversionSink _xml;
  String _carry = '';

  @override
  void add(String chunk) {
    final cut = chunk.lastIndexOf('<');
    if (cut < 0) {
      _carry = _carry.isEmpty ? chunk : _carry + chunk;
      if (_carry.length > _maxCarry) {
        _xml.add(_carry);
        _carry = '';
      }
      return;
    }
    if (_carry.isEmpty) {
      if (cut > 0) _xml.addSlice(chunk, 0, cut, false);
    } else {
      _xml.add(_carry + chunk.substring(0, cut));
    }
    _carry = chunk.substring(cut);
  }

  @override
  void close() {
    if (_carry.isNotEmpty) {
      _xml.add(_carry);
      _carry = '';
    }
    _xml.close();
  }
}

String? _attr(XmlStartElementEvent e, String name) {
  final attributes = e.attributes;
  for (var i = 0; i < attributes.length; i++) {
    if (attributes[i].name == name) return attributes[i].value;
  }
  return null;
}

String _primarySubtag(String lang) {
  for (var i = 0; i < lang.length; i++) {
    final c = lang.codeUnitAt(i);
    if (c == 0x2D || c == 0x5F) return lang.substring(0, i);
  }
  return lang;
}

/// [lang] (any case, maybe with a region) has the primary subtag [primary]
/// (lowercase).
bool _sameLanguage(String lang, String primary) {
  var start = 0;
  var end = lang.length;
  while (start < end && lang.codeUnitAt(start) <= 0x20) {
    start++;
  }
  while (end > start && lang.codeUnitAt(end - 1) <= 0x20) {
    end--;
  }
  final n = primary.length;
  if (end - start < n) return false;
  for (var i = 0; i < n; i++) {
    if ((lang.codeUnitAt(start + i) | 0x20) != primary.codeUnitAt(i)) {
      return false;
    }
  }
  if (end - start == n) return true;
  final next = lang.codeUnitAt(start + n);
  return next == 0x2D || next == 0x5F;
}

bool _isSpace(int c) => c <= 0x20 || c == 0xA0 || c == 0x2028 || c == 0x2029;

/// Single-line text: whitespace runs (including newlines and NBSP) become
/// one space, control characters are dropped, the ends are trimmed.
String _line(String s) {
  final n = s.length;
  if (n == 0) return s;
  var clean = !_isSpace(s.codeUnitAt(0)) && !_isSpace(s.codeUnitAt(n - 1));
  if (clean) {
    for (var i = 0; i < n; i++) {
      final c = s.codeUnitAt(i);
      if (c == 0x20) {
        if (s.codeUnitAt(i + 1) == 0x20) {
          clean = false;
          break;
        }
      } else if (_isSpace(c)) {
        clean = false;
        break;
      }
    }
  }
  if (clean) return s;
  final out = StringBuffer();
  var space = false;
  for (var i = 0; i < n; i++) {
    final c = s.codeUnitAt(i);
    if (_isSpace(c)) {
      space = out.isNotEmpty;
      continue;
    }
    if (space) {
      out.writeCharCode(0x20);
      space = false;
    }
    out.writeCharCode(c);
  }
  return out.toString();
}

/// Multi-line text (descriptions): CRLF / CR → LF, ends trimmed.
String _paragraph(String s) {
  final t = s.trim();
  if (!t.contains('\r')) return t;
  return t.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
}
