// lib/data/intention_tracker.dart — SkillBridge AI
// ══════════════════════════════════════════════════════════════════════════════
// Research grounding:
//   [LH22] Li Huang (2022) — Graduate Employment Intention Classification
//
// Tracks a learner's employment intention over time, supporting longitudinal
// analysis of how intentions shift throughout a degree programme or career
// transition period.
//
// Key classes (all immutable):
//   EmploymentIntention    — enum of five mutually-exclusive intention types
//   MonthlyTimelineEntry   — typed (month, intention) pair for timeline charts
//   IntentionSummary       — analytics snapshot (current, dominant, counts)
//   IntentionEntry         — timestamped intention snapshot with confidence
//   IntentionTracker       — full history with analytics helpers
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════════════════════
// §1  EMPLOYMENT INTENTION ENUM
// ══════════════════════════════════════════════════════════════════════════════

/// [LH22 — Graduate Employment Intention Classification]
/// Five mutually-exclusive categories used to classify a graduate's or
/// transitioning professional's primary career intention.
enum EmploymentIntention {
  studyAbroad,
  furtherEducationLocal,
  seekEmployment,
  startBusiness,
  undecided,
}

extension EmploymentIntentionX on EmploymentIntention {
  // ── Display ───────────────────────────────────────────────────────────────

  /// Short label for chips, timeline dots, and legend entries.
  String get displayName {
    switch (this) {
      case EmploymentIntention.studyAbroad:
        return 'Study Abroad';
      case EmploymentIntention.furtherEducationLocal:
        return 'Further Education';
      case EmploymentIntention.seekEmployment:
        return 'Seek Employment';
      case EmploymentIntention.startBusiness:
        return 'Start a Business';
      case EmploymentIntention.undecided:
        return 'Undecided';
    }
  }

  /// Full description shown in the onboarding picker and profile page.
  String get description {
    switch (this) {
      case EmploymentIntention.studyAbroad:
        return 'Pursuing further studies at an international institution';
      case EmploymentIntention.furtherEducationLocal:
        return 'Continuing education at a local university or college';
      case EmploymentIntention.seekEmployment:
        return 'Actively searching for a job in the local or remote market';
      case EmploymentIntention.startBusiness:
        return 'Planning to launch a startup, SME, or freelance business';
      case EmploymentIntention.undecided:
        return 'Still exploring options — no firm decision yet';
    }
  }

  // ── Visual ────────────────────────────────────────────────────────────────

  /// Material icon representing this intention.
  IconData get icon {
    switch (this) {
      case EmploymentIntention.studyAbroad:
        return Icons.flight_takeoff_rounded;
      case EmploymentIntention.furtherEducationLocal:
        return Icons.school_rounded;
      case EmploymentIntention.seekEmployment:
        return Icons.work_outline_rounded;
      case EmploymentIntention.startBusiness:
        return Icons.rocket_launch_rounded;
      case EmploymentIntention.undecided:
        return Icons.help_outline_rounded;
    }
  }

  /// Brand colour for the intention chip, timeline dot, and charts.
  Color get color {
    switch (this) {
      case EmploymentIntention.studyAbroad:
        return const Color(0xFF1565C0); // primaryBlue
      case EmploymentIntention.furtherEducationLocal:
        return const Color(0xFF00695C); // dark teal
      case EmploymentIntention.seekEmployment:
        return const Color(0xFF2E7D32); // accentGreen
      case EmploymentIntention.startBusiness:
        return const Color(0xFFE65100); // deep orange
      case EmploymentIntention.undecided:
        return const Color(0xFF6D4C41); // brown
    }
  }

  /// Hex colour string for non-Flutter contexts (chart tooltips, export).
  String get hexColor {
    switch (this) {
      case EmploymentIntention.studyAbroad:
        return '#1565C0';
      case EmploymentIntention.furtherEducationLocal:
        return '#00695C';
      case EmploymentIntention.seekEmployment:
        return '#2E7D32';
      case EmploymentIntention.startBusiness:
        return '#E65100';
      case EmploymentIntention.undecided:
        return '#6D4C41';
    }
  }

  // ── Serialisation ─────────────────────────────────────────────────────────

  /// Stable string key for JSON persistence.
  String get key {
    switch (this) {
      case EmploymentIntention.studyAbroad:
        return 'studyAbroad';
      case EmploymentIntention.furtherEducationLocal:
        return 'furtherEducationLocal';
      case EmploymentIntention.seekEmployment:
        return 'seekEmployment';
      case EmploymentIntention.startBusiness:
        return 'startBusiness';
      case EmploymentIntention.undecided:
        return 'undecided';
    }
  }

  /// Deserialises from a [key] string.  Falls back to [undecided] for unknown
  /// keys so pre-upgrade persisted data degrades gracefully.
  ///
  /// Called as `EmploymentIntentionX.fromKey(key)` — Dart allows static
  /// extension members to be invoked via the extension name.
  static EmploymentIntention fromKey(String key) {
    switch (key) {
      case 'studyAbroad':
        return EmploymentIntention.studyAbroad;
      case 'furtherEducationLocal':
        return EmploymentIntention.furtherEducationLocal;
      case 'seekEmployment':
        return EmploymentIntention.seekEmployment;
      case 'startBusiness':
        return EmploymentIntention.startBusiness;
      default:
        return EmploymentIntention.undecided;
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// §2  MONTHLY TIMELINE ENTRY
// ══════════════════════════════════════════════════════════════════════════════

/// Typed replacement for the previous [Map<String, dynamic>] returned by
/// [IntentionTracker.getMonthlyTimeline]. Represents the intention that was
/// active at the start of a given calendar month.
@immutable
class MonthlyTimelineEntry {
  /// First day of the month (year, month, day = 1, time = midnight).
  final DateTime month;

  /// Employment intention active at the start of [month].
  final EmploymentIntention intention;

  const MonthlyTimelineEntry({
    required this.month,
    required this.intention,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          (other is MonthlyTimelineEntry &&
              month == other.month &&
              intention == other.intention);

  @override
  int get hashCode => Object.hash(month, intention);

  @override
  String toString() =>
      'MonthlyTimelineEntry('
          '${month.year}-${month.month.toString().padLeft(2, '0')}: '
          '${intention.displayName})';
}

// ══════════════════════════════════════════════════════════════════════════════
// §3  INTENTION SUMMARY
// ══════════════════════════════════════════════════════════════════════════════

/// Immutable analytics snapshot of an [IntentionTracker].
/// Returned by [IntentionTracker.summary] for dashboard cards and reports.
@immutable
class IntentionSummary {
  /// Most recently recorded intention, or null when history is empty.
  final EmploymentIntention? current;

  /// Most frequently recorded intention across all history, or null when
  /// history is empty.  Ties broken by the most recently recorded intention.
  final EmploymentIntention? dominant;

  /// Total number of recorded intention entries.
  final int totalEntries;

  /// Number of times the intention changed between consecutive entries.
  final int changeCount;

  /// Mean confidence level (1.0–5.0) across entries that have one, or null
  /// when no entries carry a confidence value.
  final double? averageConfidence;

  /// True when the intention changed at least once in the last 30 days.
  final bool hasRecentChange;

  /// Total calendar duration spanned by the history
  /// (distance from first to last entry).
  final Duration totalTrackedDuration;

  const IntentionSummary({
    required this.current,
    required this.dominant,
    required this.totalEntries,
    required this.changeCount,
    required this.averageConfidence,
    required this.hasRecentChange,
    required this.totalTrackedDuration,
  });

  // ── Convenience getters ───────────────────────────────────────────────────

  /// True when the learner's intention is stable (no changes in history).
  bool get isStable => changeCount == 0 && totalEntries > 0;

  /// True when the learner's current intention is [EmploymentIntention.seekEmployment].
  bool get isActiveJobSeeker => current == EmploymentIntention.seekEmployment;

  /// [averageConfidence] normalised to [0.0–1.0] using the formula
  /// `(raw − 1) / 4`, matching [IntentionEntry.normalisedConfidence].
  /// Returns null when [averageConfidence] is null.
  double? get normalisedAverageConfidence => averageConfidence != null
      ? ((averageConfidence! - 1.0) / 4.0).clamp(0.0, 1.0)
      : null;

  @override
  String toString() =>
      'IntentionSummary('
          'current: ${current?.displayName ?? 'none'}, '
          'dominant: ${dominant?.displayName ?? 'none'}, '
          'entries: $totalEntries, changes: $changeCount, '
          'avgConfidence: ${averageConfidence?.toStringAsFixed(1) ?? 'null'})';
}

// ══════════════════════════════════════════════════════════════════════════════
// §4  INTENTION ENTRY
// ══════════════════════════════════════════════════════════════════════════════

/// [LH22] An immutable timestamped snapshot of a learner's employment intention,
/// optionally annotated with a free-text note and a self-reported confidence level.
@immutable
class IntentionEntry {
  /// When this intention was recorded.
  final DateTime timestamp;

  /// Employment intention classification at this snapshot.
  final EmploymentIntention intention;

  /// Optional free-text note explaining why the learner recorded this entry
  /// (e.g. "Changed because I received an internship offer").
  final String? note;

  /// Learner's self-reported confidence in this intention (scale 1.0–5.0).
  ///   1 = very uncertain · 5 = very certain.
  /// Stored as [double] to support half-point precision (e.g. 3.5).
  final double? confidenceLevel;

  // ── Constructor ────────────────────────────────────────────────────────────

  const IntentionEntry({
    required this.timestamp,
    required this.intention,
    this.note,
    this.confidenceLevel,
  }) : assert(
  confidenceLevel == null ||
      (confidenceLevel >= 1.0 && confidenceLevel <= 5.0),
  'confidenceLevel must be in [1.0, 5.0].',
  );

  // ── Confidence helpers ────────────────────────────────────────────────────

  /// Confidence normalised to [0.0–1.0] using the formula `(raw − 1) / 4`.
  /// Returns null when [confidenceLevel] is null.
  double? get normalisedConfidence => confidenceLevel != null
      ? ((confidenceLevel! - 1.0) / 4.0).clamp(0.0, 1.0)
      : null;

  /// True when [confidenceLevel] is 4.0 or above — signals strong intent.
  bool get isHighConfidence =>
      confidenceLevel != null && confidenceLevel! >= 4.0;

  /// Human-readable confidence category for UI display.
  ///
  /// | Range  | Label      |
  /// |--------|------------|
  /// | null   | Unknown    |
  /// | 1–<2   | Low        |
  /// | 2–<3   | Moderate   |
  /// | 3–<4   | High       |
  /// | 4–5    | Very High  |
  String get confidenceCategory {
    if (confidenceLevel == null) return 'Unknown';
    if (confidenceLevel! < 2.0) return 'Low';
    if (confidenceLevel! < 3.0) return 'Moderate';
    if (confidenceLevel! < 4.0) return 'High';
    return 'Very High';
  }

  // ── Convenience ───────────────────────────────────────────────────────────

  /// ISO-8601 date string (date portion only) for display in timeline tiles.
  String get formattedDate =>
      '${timestamp.year}-'
          '${timestamp.month.toString().padLeft(2, '0')}-'
          '${timestamp.day.toString().padLeft(2, '0')}';

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
    'timestamp': timestamp.millisecondsSinceEpoch,
    'intention': intention.key,
    'note': note,
    'confidenceLevel': confidenceLevel,
  };

  Map<String, dynamic> toJson() => toMap();

  factory IntentionEntry.fromMap(Map<String, dynamic> map) => IntentionEntry(
    timestamp: DateTime.fromMillisecondsSinceEpoch(
      (map['timestamp'] as num).toInt(),
    ),
    intention: EmploymentIntentionX.fromKey(
      (map['intention'] as String?) ?? 'undecided',
    ),
    note: map['note'] as String?,
    confidenceLevel: (map['confidenceLevel'] as num?)?.toDouble(),
  );

  factory IntentionEntry.fromJson(Map<String, dynamic> json) =>
      IntentionEntry.fromMap(json);

  // ── copyWith ───────────────────────────────────────────────────────────────

  /// Returns an updated copy.
  ///
  /// Pass [clearNote] = `true` or [clearConfidenceLevel] = `true` to
  /// explicitly set those nullable fields to null.
  IntentionEntry copyWith({
    DateTime? timestamp,
    EmploymentIntention? intention,
    String? note,
    double? confidenceLevel,
    bool clearNote = false,
    bool clearConfidenceLevel = false,
  }) =>
      IntentionEntry(
        timestamp: timestamp ?? this.timestamp,
        intention: intention ?? this.intention,
        note: clearNote ? null : (note ?? this.note),
        confidenceLevel: clearConfidenceLevel
            ? null
            : (confidenceLevel ?? this.confidenceLevel),
      );

  // ── Equality ───────────────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          (other is IntentionEntry &&
              timestamp == other.timestamp &&
              intention == other.intention &&
              note == other.note &&
              confidenceLevel == other.confidenceLevel);

  @override
  int get hashCode => Object.hash(timestamp, intention, note, confidenceLevel);

  @override
  String toString() =>
      'IntentionEntry('
          'intention: ${intention.displayName}, '
          'date: $formattedDate, '
          'confidence: ${confidenceLevel?.toStringAsFixed(1) ?? 'null'})';
}

// ══════════════════════════════════════════════════════════════════════════════
// §5  INTENTION TRACKER
// ══════════════════════════════════════════════════════════════════════════════

/// [LH22 — Employment Intention Tracking]
/// Immutable longitudinal record of a learner's employment intention entries,
/// with analytics helpers for timeline charts, change detection, and summaries.
///
/// All mutation methods return a **new** [IntentionTracker] instance (copyWith
/// pattern).  The internal [history] list is never modified in place.
@immutable
class IntentionTracker {
  /// Complete chronological list of intention entries (oldest first).
  final List<IntentionEntry> history;

  const IntentionTracker({required this.history});

  // ── Factory constructors ───────────────────────────────────────────────────

  /// Returns an empty [IntentionTracker] with no history.
  factory IntentionTracker.empty() =>
      const IntentionTracker(history: <IntentionEntry>[]);

  // ──────────────────────────────────────────────────────────────────────────
  // §5.1  CURRENT STATE ACCESSORS
  // ──────────────────────────────────────────────────────────────────────────

  /// The most recently recorded [EmploymentIntention], or null when empty.
  EmploymentIntention? get currentIntention =>
      history.isEmpty ? null : history.last.intention;

  /// The most recent [IntentionEntry], or null when history is empty.
  IntentionEntry? get currentEntry =>
      history.isEmpty ? null : history.last;

  /// The earliest [IntentionEntry], or null when history is empty.
  IntentionEntry? get firstEntry =>
      history.isEmpty ? null : history.first;

  // ──────────────────────────────────────────────────────────────────────────
  // §5.2  MUTATION (immutable — returns new instance)
  // ──────────────────────────────────────────────────────────────────────────

  /// Records a new intention entry at the current time and returns a new
  /// [IntentionTracker] with the entry appended.
  ///
  /// [intention]       — the new employment intention classification.
  /// [note]            — optional free-text reason for the change.
  /// [confidenceLevel] — optional 1–5 self-reported confidence.
  IntentionTracker addEntry(
      EmploymentIntention intention, {
        String? note,
        double? confidenceLevel,
      }) {
    final entry = IntentionEntry(
      timestamp: DateTime.now(),
      intention: intention,
      note: note,
      confidenceLevel: confidenceLevel,
    );
    return IntentionTracker(history: [...history, entry]);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // §5.3  HISTORY QUERIES
  // ──────────────────────────────────────────────────────────────────────────

  /// Returns the [EmploymentIntention] active at [date].
  ///
  /// Finds the most recent entry whose [IntentionEntry.timestamp] is at or
  /// before [date].  Returns null if [date] precedes all recorded entries.
  EmploymentIntention? getIntentionAt(DateTime date) {
    IntentionEntry? best;
    for (final entry in history) {
      if (!entry.timestamp.isAfter(date)) best = entry;
    }
    return best?.intention;
  }

  /// Returns the [n] most recent entries, or fewer when history has fewer
  /// than [n] entries.  Returned in chronological order (oldest first).
  List<IntentionEntry> recentHistory(int n) {
    if (n <= 0 || history.isEmpty) return const <IntentionEntry>[];
    final start = (history.length - n).clamp(0, history.length);
    return history.sublist(start);
  }

  /// Returns all entries whose [IntentionEntry.timestamp] falls within
  /// [start] and [end] (both bounds inclusive).
  /// Returned in chronological order.
  List<IntentionEntry> entriesBetween(DateTime start, DateTime end) =>
      history
          .where((e) =>
      !e.timestamp.isBefore(start) && !e.timestamp.isAfter(end))
          .toList();

  // ──────────────────────────────────────────────────────────────────────────
  // §5.4  ANALYTICS GETTERS
  // ──────────────────────────────────────────────────────────────────────────

  /// Number of times the intention changed between consecutive entries.
  /// Returns 0 for histories with 0 or 1 entry.
  int get intentionChangeCount {
    if (history.length < 2) return 0;
    var changes = 0;
    for (var i = 1; i < history.length; i++) {
      if (history[i].intention != history[i - 1].intention) changes++;
    }
    return changes;
  }

  /// The [EmploymentIntention] appearing most frequently across all entries.
  ///
  /// **Tie-breaking:** when two or more intentions share the highest count,
  /// the one recorded most recently wins (i.e. the one closest to the end of
  /// [history]).  Returns null when history is empty.
  EmploymentIntention? get dominantIntention {
    if (history.isEmpty) return null;

    // Build frequency counts.
    final counts = <EmploymentIntention, int>{};
    for (final entry in history) {
      counts[entry.intention] = (counts[entry.intention] ?? 0) + 1;
    }

    // Find the maximum count.
    final maxCount = counts.values.reduce((a, b) => a > b ? a : b);

    // Collect all intentions that share the maximum count.
    final topIntentions = counts.entries
        .where((e) => e.value == maxCount)
        .map((e) => e.key)
        .toSet();

    // Tie-break: return the most recently recorded among the top intentions.
    // history is chronological (oldest first), so iterate in reverse.
    for (var i = history.length - 1; i >= 0; i--) {
      if (topIntentions.contains(history[i].intention)) {
        return history[i].intention;
      }
    }

    // Unreachable — history is non-empty and topIntentions is a subset of it.
    return history.last.intention;
  }

  /// True when the intention changed at least once in the last 30 days.
  bool get hasRecentChange {
    if (history.length < 2) return false;
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    for (var i = 1; i < history.length; i++) {
      if (history[i].timestamp.isAfter(cutoff) &&
          history[i].intention != history[i - 1].intention) {
        return true;
      }
    }
    return false;
  }

  /// Mean confidence level (1.0–5.0) across entries that carry a
  /// [IntentionEntry.confidenceLevel].  Returns null when none do.
  double? get averageConfidence {
    final withConf =
    history.where((e) => e.confidenceLevel != null).toList();
    if (withConf.isEmpty) return null;
    final sum =
    withConf.fold<double>(0.0, (s, e) => s + e.confidenceLevel!);
    return sum / withConf.length;
  }

  /// Frequency map: intention → count of entries with that classification.
  Map<EmploymentIntention, int> get intentionBreakdown {
    final map = <EmploymentIntention, int>{};
    for (final entry in history) {
      map[entry.intention] = (map[entry.intention] ?? 0) + 1;
    }
    return map;
  }

  /// Total [Duration] the learner held [intention] across all recorded spans.
  ///
  /// Each entry of the target [intention] spans from its own timestamp to the
  /// timestamp of the immediately following entry.  The final entry in
  /// [history] — if it matches — extends to [DateTime.now()].
  ///
  /// [LH22 — longitudinal intention duration]
  Duration durationForIntention(EmploymentIntention intention) {
    if (history.isEmpty) return Duration.zero;
    var total = Duration.zero;
    for (var i = 0; i < history.length; i++) {
      if (history[i].intention != intention) continue;
      final spanStart = history[i].timestamp;
      final spanEnd = (i + 1 < history.length)
          ? history[i + 1].timestamp
          : DateTime.now();
      total += spanEnd.difference(spanStart);
    }
    return total;
  }

  /// Duration breakdown for all intention types.
  ///
  /// Returns a [Map] of intention → [Duration], containing only intentions
  /// that appear at least once in [history].
  Map<EmploymentIntention, Duration> get durationBreakdown {
    final result = <EmploymentIntention, Duration>{};
    for (final intention in EmploymentIntention.values) {
      final d = durationForIntention(intention);
      if (d > Duration.zero) result[intention] = d;
    }
    return result;
  }

  /// Total calendar duration spanned by [history] (first → last timestamp).
  /// Returns [Duration.zero] when history has fewer than two entries.
  Duration get totalTrackedDuration => history.length < 2
      ? Duration.zero
      : history.last.timestamp.difference(history.first.timestamp);

  // ──────────────────────────────────────────────────────────────────────────
  // §5.5  TIMELINE
  // ──────────────────────────────────────────────────────────────────────────

  /// [LH22] Returns a typed list of [MonthlyTimelineEntry] objects covering
  /// every calendar month from the first to the last recorded entry.
  ///
  /// For each month, the intention active at 23:59:59.999 on the last day of
  /// that month is used, ensuring any entry recorded on the 1st of the month
  /// at midnight is captured correctly.
  ///
  /// Returns an empty list when [history] is empty.
  List<MonthlyTimelineEntry> getMonthlyTimeline() {
    if (history.isEmpty) return const <MonthlyTimelineEntry>[];

    final oldest = history.first.timestamp;
    final newest = history.last.timestamp;
    final result = <MonthlyTimelineEntry>[];

    var cursor = DateTime(oldest.year, oldest.month);
    final end = DateTime(newest.year, newest.month);

    while (!cursor.isAfter(end)) {
      // Query the very last millisecond of this calendar month.
      final nextMonth = cursor.month == 12 ? 1 : cursor.month + 1;
      final nextYear = cursor.month == 12 ? cursor.year + 1 : cursor.year;
      final endOfMonth =
      DateTime(nextYear, nextMonth).subtract(const Duration(milliseconds: 1));

      final intention = getIntentionAt(endOfMonth);
      if (intention != null) {
        result.add(MonthlyTimelineEntry(month: cursor, intention: intention));
      }

      cursor = DateTime(nextYear, nextMonth);
    }

    return result;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // §5.6  SUMMARY
  // ──────────────────────────────────────────────────────────────────────────

  /// Returns an [IntentionSummary] analytics snapshot suitable for dashboard
  /// cards and report screens.
  IntentionSummary get summary => IntentionSummary(
    current: currentIntention,
    dominant: dominantIntention,
    totalEntries: history.length,
    changeCount: intentionChangeCount,
    averageConfidence: averageConfidence,
    hasRecentChange: hasRecentChange,
    totalTrackedDuration: totalTrackedDuration,
  );

  // ──────────────────────────────────────────────────────────────────────────
  // §5.7  SERIALISATION
  // ──────────────────────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
    'history': history.map((e) => e.toMap()).toList(),
  };

  Map<String, dynamic> toJson() => toMap();

  factory IntentionTracker.fromMap(Map<String, dynamic> map) {
    final raw = map['history'];
    final entries = raw == null
        ? <IntentionEntry>[]
        : (raw as List<dynamic>)
        .map((e) => IntentionEntry.fromMap(
      Map<String, dynamic>.from(e as Map),
    ))
        .toList();
    return IntentionTracker(history: entries);
  }

  factory IntentionTracker.fromJson(Map<String, dynamic> json) =>
      IntentionTracker.fromMap(json);

  // ──────────────────────────────────────────────────────────────────────────
  // §5.8  copyWith / EQUALITY / HASHCODE
  // ──────────────────────────────────────────────────────────────────────────

  IntentionTracker copyWith({List<IntentionEntry>? history}) =>
      IntentionTracker(
        history: history ?? List<IntentionEntry>.from(this.history),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          (other is IntentionTracker &&
              history.length == other.history.length &&
              _listsEqual(history, other.history));

  @override
  int get hashCode => Object.hashAll(history);

  @override
  String toString() =>
      'IntentionTracker('
          'entries: ${history.length}, '
          'current: ${currentIntention?.displayName ?? 'none'}, '
          'changes: $intentionChangeCount)';
}

// ══════════════════════════════════════════════════════════════════════════════
// §6  PRIVATE HELPERS
// ══════════════════════════════════════════════════════════════════════════════

/// Structural equality check for two [IntentionEntry] lists of equal length.
bool _listsEqual(List<IntentionEntry> a, List<IntentionEntry> b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}