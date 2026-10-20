/// Progress model of the import pipeline (ARCHITECTURE 2.12), shared by the
/// wizard's progress stepper, the top-bar reload chip and the import code.
library;

import 'package:flutter/foundation.dart';

import '../db/tables.dart' show SectionKind;
import '../sources/source_exception.dart';

/// A step of an import, in stepper order: Connecting → Live
/// categories → Live channels (n) → Movies (n) → Series (n) → EPG: Cleaning
/// programs → Downloading → Parsing (n programmes) → Completed.
///
/// [completed], [failed] and [cancelled] are terminal.
enum ImportStep {
  /// Xtream: authenticate. M3U: download (byte progress) and parse.
  connecting,
  liveCategories,
  liveChannels,

  /// Movie categories and movies.
  movies,

  /// Series categories and series (M3U: also seasons and episodes). The
  /// content finalization (removing vanished items, search index, counts)
  /// runs at the end of this step.
  series,

  /// Prunes programmes outside the guide window.
  epgCleaning,

  /// Downloads the XMLTV file (byte progress).
  epgDownloading,

  /// Parses and stores programmes (running count), then matches channels.
  epgParsing,
  completed,
  failed,
  cancelled;

  /// Content steps in order.
  static const List<ImportStep> contentSteps = [
    connecting,
    liveCategories,
    liveChannels,
    movies,
    series,
  ];

  /// EPG steps in order.
  static const List<ImportStep> epgSteps = [
    epgCleaning,
    epgDownloading,
    epgParsing,
  ];

  bool get isTerminal =>
      this == completed || this == failed || this == cancelled;

  bool get isContent => contentSteps.contains(this);

  bool get isEpg => epgSteps.contains(this);
}

/// What an import covers.
enum ImportScope {
  /// Content, then the EPG (when the playlist has an EPG URL).
  all,

  /// Categories, channels, movies and series only.
  content,

  /// The XMLTV guide only.
  epg;

  bool get includesContent => this != epg;

  bool get includesEpg => this != content;
}

/// How the stepper should draw one step (see [ImportProgress.statusOf]).
enum ImportStepStatus { pending, active, done, failed, cancelled, skipped }

/// A non-fatal finding. A section that imported zero items yields
/// `ImportWarning(SourceErrorKind.sectionEmpty, section)` — the wizard shows
/// the "imported but section empty" dialog; the import still succeeds.
@immutable
class ImportWarning {
  const ImportWarning(this.kind, this.section, {this.message});

  final SourceErrorKind kind;

  /// The section concerned, or null for playlist-wide warnings.
  final SectionKind? section;

  /// Developer-facing detail (never contains URLs or credentials).
  final String? message;

  @override
  bool operator ==(Object other) =>
      other is ImportWarning &&
      other.kind == kind &&
      other.section == section &&
      other.message == message;

  @override
  int get hashCode => Object.hash(kind, section, message);

  @override
  String toString() =>
      'ImportWarning(${kind.name}'
      '${section != null ? ', ${section!.name}' : ''}'
      '${message != null ? ', $message' : ''})';
}

/// A snapshot of a running or finished import.
///
/// The stream returned by `ImportService.start` emits snapshots and closes
/// after the terminal one ([ImportStep.completed], [ImportStep.failed] or
/// [ImportStep.cancelled]); it never emits errors.
///
/// EPG failures are not fatal when content was imported too: the import
/// ends [ImportStep.completed] with [epgError] set and [failedStep] naming
/// the EPG step that failed (the stepper shows "EPG failed" there, see
/// [statusOf]). In an EPG-only import ([ImportScope.epg]) an EPG failure is
/// fatal: [step] is [ImportStep.failed] and [error] == [epgError].
@immutable
class ImportProgress {
  const ImportProgress({
    required this.playlistId,
    required this.scope,
    required this.step,
    this.counts = const {},
    this.receivedBytes,
    this.totalBytes,
    this.error,
    this.warnings = const [],
    this.done = false,
    this.plannedSteps = const [],
    this.skippedSteps = const {},
    this.failedStep,
    this.epgError,
    this.stepDurations = const {},
    this.startedAt,
  });

  final int playlistId;
  final ImportScope scope;

  /// The running step, or the terminal step once [done].
  final ImportStep step;

  /// Item counts per step:
  /// - [ImportStep.liveCategories]: live categories;
  /// - [ImportStep.liveChannels], [ImportStep.movies], [ImportStep.series]:
  ///   items stored so far (final once the step is over);
  /// - [ImportStep.epgCleaning]: programmes pruned;
  /// - [ImportStep.epgParsing]: programmes stored so far.
  final Map<ImportStep, int> counts;

  /// Bytes received in the current step (M3U download while
  /// [ImportStep.connecting], XMLTV download, then XMLTV bytes parsed while
  /// [ImportStep.epgParsing]); null when the step has no byte progress.
  final int? receivedBytes;

  /// Expected bytes; null when unknown (chunked or gzip-encoded responses).
  final int? totalBytes;

  /// Why the import failed; set exactly when [step] is [ImportStep.failed].
  final SourceException? error;
  final List<ImportWarning> warnings;

  /// True for the last snapshot (terminal [step]).
  final bool done;

  /// Steps this run goes through, in order, ending with
  /// [ImportStep.completed] (what the stepper lists). Empty until the
  /// playlist was read.
  final List<ImportStep> plannedSteps;

  /// Steps that do not apply to this run (EPG without an EPG URL, content in
  /// an EPG-only import…). They are not part of [plannedSteps].
  final Set<ImportStep> skippedSteps;

  /// The step that was running when the import failed or was cancelled, or
  /// the EPG step that failed in an otherwise completed import.
  final ImportStep? failedStep;

  /// The EPG failure, if any (see the class documentation).
  final SourceException? epgError;

  /// Wall-clock time of each finished step (for logs and benchmarks).
  final Map<ImportStep, Duration> stepDurations;
  final DateTime? startedAt;

  bool get isTerminal => step.isTerminal;
  bool get succeeded => step == ImportStep.completed;
  bool get isFailed => step == ImportStep.failed;
  bool get isCancelled => step == ImportStep.cancelled;

  /// The guide could not be imported (the content may still be fine).
  bool get epgFailed => epgError != null;

  /// [receivedBytes] / [totalBytes] in 0…1 when both are known.
  double? get byteFraction {
    final r = receivedBytes;
    final t = totalBytes;
    if (r == null || t == null || t <= 0) return null;
    return (r / t).clamp(0.0, 1.0);
  }

  /// Rough overall progress in 0…1 for a chip or a bar: the finished
  /// [plannedSteps] plus the byte fraction of the running step. 1 once
  /// completed; 0 before the plan is known.
  double get fraction {
    if (step == ImportStep.completed) return 1;
    final steps = plannedSteps.length - 1; // without [ImportStep.completed]
    final i = stepIndex;
    if (steps <= 0 || i < 0) return 0;
    return ((i + (byteFraction ?? 0)) / steps).clamp(0.0, 1.0);
  }

  /// The count of [step] (see [counts]).
  int? countOf(ImportStep step) => counts[step];

  /// Index of the step to highlight in [plannedSteps]: the running step, the
  /// interrupted step of a failed or cancelled import, or the last index when
  /// completed. -1 before the plan is known.
  int get stepIndex {
    final s = switch (step) {
      ImportStep.failed || ImportStep.cancelled => failedStep,
      _ => step,
    };
    return s == null ? -1 : plannedSteps.indexOf(s);
  }

  /// How the stepper should draw [s].
  ImportStepStatus statusOf(ImportStep s) {
    if (skippedSteps.contains(s)) return ImportStepStatus.skipped;
    final i = plannedSteps.indexOf(s);
    if (i < 0) return ImportStepStatus.skipped;
    final failedAt = failedStep == null
        ? -1
        : plannedSteps.indexOf(failedStep!);
    switch (step) {
      case ImportStep.completed:
        if (failedAt < 0 || i < failedAt) return ImportStepStatus.done;
        if (i == failedAt) return ImportStepStatus.failed;
        return s == ImportStep.completed
            ? ImportStepStatus.done
            : ImportStepStatus.skipped;
      case ImportStep.failed:
      case ImportStep.cancelled:
        if (i < failedAt) return ImportStepStatus.done;
        if (i == failedAt) {
          return step == ImportStep.failed
              ? ImportStepStatus.failed
              : ImportStepStatus.cancelled;
        }
        return ImportStepStatus.pending;
      default:
        final current = plannedSteps.indexOf(step);
        if (i < current) return ImportStepStatus.done;
        if (i == current) return ImportStepStatus.active;
        return ImportStepStatus.pending;
    }
  }

  /// Warnings of kind [SourceErrorKind.sectionEmpty], by section.
  Set<SectionKind> get emptySections => {
    for (final w in warnings)
      if (w.kind == SourceErrorKind.sectionEmpty && w.section != null)
        w.section!,
  };

  ImportProgress copyWith({
    ImportStep? step,
    Map<ImportStep, int>? counts,
    int? Function()? receivedBytes,
    int? Function()? totalBytes,
    SourceException? Function()? error,
    List<ImportWarning>? warnings,
    bool? done,
    List<ImportStep>? plannedSteps,
    Set<ImportStep>? skippedSteps,
    ImportStep? Function()? failedStep,
    SourceException? Function()? epgError,
    Map<ImportStep, Duration>? stepDurations,
  }) => ImportProgress(
    playlistId: playlistId,
    scope: scope,
    step: step ?? this.step,
    counts: counts ?? this.counts,
    receivedBytes: receivedBytes == null ? this.receivedBytes : receivedBytes(),
    totalBytes: totalBytes == null ? this.totalBytes : totalBytes(),
    error: error == null ? this.error : error(),
    warnings: warnings ?? this.warnings,
    done: done ?? this.done,
    plannedSteps: plannedSteps ?? this.plannedSteps,
    skippedSteps: skippedSteps ?? this.skippedSteps,
    failedStep: failedStep == null ? this.failedStep : failedStep(),
    epgError: epgError == null ? this.epgError : epgError(),
    stepDurations: stepDurations ?? this.stepDurations,
    startedAt: startedAt,
  );

  /// Never contains URLs or credentials.
  @override
  String toString() {
    final b = StringBuffer('ImportProgress(#$playlistId ${scope.name}: ')
      ..write(step.name);
    if (counts.isNotEmpty) {
      b.write(', counts: {');
      b.write(
        counts.entries.map((e) => '${e.key.name}: ${e.value}').join(', '),
      );
      b.write('}');
    }
    if (receivedBytes != null) {
      b.write(', bytes: $receivedBytes/${totalBytes ?? '?'}');
    }
    if (failedStep != null) b.write(', failedStep: ${failedStep!.name}');
    if (error != null) b.write(', error: $error');
    if (epgError != null) b.write(', epgError: $epgError');
    if (warnings.isNotEmpty) b.write(', warnings: $warnings');
    b.write(')');
    return b.toString();
  }
}
