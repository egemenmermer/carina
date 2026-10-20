/// Events produced by the XMLTV parser and the batches delivered by the
/// batch / isolate runners. All values are plain data and can be sent to
/// another isolate.
library;

import 'package:collection/collection.dart';

/// Something parsed from an XMLTV document.
sealed class XmltvEvent {
  const XmltvEvent();
}

/// `<channel id="…"><display-name>…</display-name><icon src="…"/></channel>`
final class XmltvChannel extends XmltvEvent {
  const XmltvChannel({required this.id, required this.displayNames, this.icon});

  /// The `id` attribute, trimmed.
  final String id;

  /// Every `<display-name>`, whitespace-collapsed, empty ones skipped. The
  /// first is the primary name: the first one in a preferred language when
  /// the parser was given languages, otherwise the first in the document.
  final List<String> displayNames;

  /// `<icon src>` of the channel.
  final String? icon;

  /// The primary display name, or the id when there is none.
  String get displayName => displayNames.isEmpty ? id : displayNames.first;

  @override
  bool operator ==(Object other) =>
      other is XmltvChannel &&
      other.id == id &&
      other.icon == icon &&
      const ListEquality<String>().equals(other.displayNames, displayNames);

  @override
  int get hashCode =>
      Object.hash(id, icon, const ListEquality<String>().hash(displayNames));

  @override
  String toString() => 'XmltvChannel($id, $displayNames, icon: $icon)';
}

/// `<programme start stop channel>` with its children. Times are UTC.
final class XmltvProgramme extends XmltvEvent {
  const XmltvProgramme({
    required this.channelId,
    required this.start,
    required this.stop,
    required this.title,
    this.subTitle,
    this.description,
    this.category,
    this.episodeNum,
    this.episodeOnscreen,
    this.icon,
    this.rating,
  });

  final String channelId;
  final DateTime start;

  /// The `stop` attribute; when it is missing or not after [start], the start
  /// of the next programme on the same channel (if that is at most 24 h
  /// later), otherwise [start] + 30 minutes.
  final DateTime stop;

  /// `<title>` in the preferred language (else the first); '' when missing.
  final String title;
  final String? subTitle;

  /// `<desc>`: trimmed, line breaks kept (CRLF → LF).
  final String? description;

  /// The first `<category>` in the preferred language.
  final String? category;

  /// Display form: `S1 E5` from `xmltv_ns` (`0.4.`), `S1` / `E5` when only
  /// one part is known; otherwise the `onscreen` text.
  final String? episodeNum;

  /// Raw `<episode-num system="onscreen">` text (`S01E05`, `Bölüm 5`).
  final String? episodeOnscreen;

  /// `<icon src>` (or the first `<image>` URL when there is no icon).
  final String? icon;

  /// `<rating><value>` of the first rating (`18+`, `PG-13`).
  final String? rating;

  Duration get duration => stop.difference(start);

  XmltvProgramme copyWith({DateTime? start, DateTime? stop}) => XmltvProgramme(
    channelId: channelId,
    start: start ?? this.start,
    stop: stop ?? this.stop,
    title: title,
    subTitle: subTitle,
    description: description,
    category: category,
    episodeNum: episodeNum,
    episodeOnscreen: episodeOnscreen,
    icon: icon,
    rating: rating,
  );

  @override
  bool operator ==(Object other) =>
      other is XmltvProgramme &&
      other.channelId == channelId &&
      other.start == start &&
      other.stop == stop &&
      other.title == title &&
      other.subTitle == subTitle &&
      other.description == description &&
      other.category == category &&
      other.episodeNum == episodeNum &&
      other.episodeOnscreen == episodeOnscreen &&
      other.icon == icon &&
      other.rating == rating;

  @override
  int get hashCode => Object.hash(
    channelId,
    start,
    stop,
    title,
    subTitle,
    description,
    category,
    episodeNum,
    episodeOnscreen,
    icon,
    rating,
  );

  @override
  String toString() =>
      'XmltvProgramme($channelId, ${start.toIso8601String()} – '
      '${stop.toIso8601String()}, $title)';
}

/// What the batch runners deliver. Every batch carries [bytesRead]: input
/// bytes consumed so far (compressed bytes for gzip input), for progress.
sealed class XmltvBatch {
  const XmltvBatch(this.bytesRead);

  final int bytesRead;
}

/// Channels, in document order. Channels are flushed before the next
/// programme batch, so a channel never arrives after a programme batch that
/// follows it in the document.
final class XmltvChannelBatch extends XmltvBatch {
  const XmltvChannelBatch(this.channels, super.bytesRead);

  final List<XmltvChannel> channels;
}

/// Up to `batchSize` programmes (time shift applied, window-filtered).
final class XmltvProgrammeBatch extends XmltvBatch {
  const XmltvProgrammeBatch(this.programmes, super.bytesRead);

  final List<XmltvProgramme> programmes;
}

/// Emitted when a lot of input was consumed without producing a batch (for
/// example while skipping programmes outside the window).
final class XmltvProgress extends XmltvBatch {
  const XmltvProgress(super.bytesRead);
}

/// Always the last item of a successful run.
final class XmltvSummary extends XmltvBatch {
  const XmltvSummary({
    required int bytesRead,
    required this.channels,
    required this.programmes,
    required this.outsideWindow,
    required this.invalid,
    required this.derivedStops,
  }) : super(bytesRead);

  /// Channels delivered.
  final int channels;

  /// Programmes delivered.
  final int programmes;

  /// Programmes dropped because they do not overlap the window.
  final int outsideWindow;

  /// Programmes dropped for a missing channel or an unparseable start.
  final int invalid;

  /// Delivered programmes whose stop was derived (missing or invalid stop).
  final int derivedStops;

  @override
  String toString() =>
      'XmltvSummary(channels: $channels, programmes: $programmes, '
      'outsideWindow: $outsideWindow, invalid: $invalid, '
      'derivedStops: $derivedStops, bytesRead: $bytesRead)';
}
