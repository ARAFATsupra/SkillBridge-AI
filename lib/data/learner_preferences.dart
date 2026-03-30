// lib/data/learner_preferences.dart — SkillBridge AI
// ══════════════════════════════════════════════════════════════════════════════
// Research grounding:
//   [TAV22] Tavakoli et al. (2022) Advanced Engineering Informatics 52, 101508
//           eDoer adaptive learning system — learner preference model §3.5
//   [ALS22] Alsaif et al. (2022) — weighted cosine-similarity job recommender
//
// ZERO external dependencies — self-contained model; all enums defined here.
//
// Preference vector layout (15 dimensions):
//   Index  0–2   ContentLength:    short | medium | long
//   Index  3–5   DetailLevel:      low   | medium | high
//   Index  6–8   LearningStrategy: theoryOnly | exampleOnly | both
//   Index  9–10  Classroom:        classroomYes | classroomNo
//   Index 11–14  ContentFormat:    video | bookChapter | webPage | slide
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:math' show sqrt, max;

// ══════════════════════════════════════════════════════════════════════════════
// §1  PREFERENCE KEY CONSTANTS  [TAV22 Table 4]
// ══════════════════════════════════════════════════════════════════════════════

/// Named string keys for persisting preference dimensions in SharedPreferences
/// and JSON serialisation. Mirrors the 15-element preference vector exactly.
class PreferenceKeys {
  PreferenceKeys._();

  // ── Length ────────────────────────────────────────────────────────────────
  static const String lengthShort  = 'length_short';
  static const String lengthMedium = 'length_medium';
  static const String lengthLong   = 'length_long';

  // ── Detail ────────────────────────────────────────────────────────────────
  static const String detailLow    = 'detail_low';
  static const String detailMedium = 'detail_medium';
  static const String detailHigh   = 'detail_high';

  // ── Strategy ──────────────────────────────────────────────────────────────
  static const String strategyTheory  = 'strategy_theory';
  static const String strategyExample = 'strategy_example';
  static const String strategyBoth    = 'strategy_both';

  // ── Classroom ─────────────────────────────────────────────────────────────
  static const String classBased    = 'class_based';
  static const String nonClassBased = 'non_class_based';

  // ── Format ────────────────────────────────────────────────────────────────
  static const String formatVideo   = 'format_video';
  static const String formatBook    = 'format_book';
  static const String formatWebPage = 'format_web_page';
  static const String formatSlide   = 'format_slide';

  /// All 15 keys in vector-index order (must stay in sync with [kPrefVectorSize]).
  static const List<String> allKeys = <String>[
    lengthShort,    lengthMedium,    lengthLong,     // 0–2
    detailLow,      detailMedium,    detailHigh,     // 3–5
    strategyTheory, strategyExample, strategyBoth,   // 6–8
    classBased,     nonClassBased,                   // 9–10
    formatVideo,    formatBook,      formatWebPage,  // 11–13
    formatSlide,                                     // 14
  ];

  /// Reverse-lookup: key → vector index. Used by [LearnerPreferences.fromKeyMap].
  static const Map<String, int> keyToVectorIndex = <String, int>{
    lengthShort:     0,
    lengthMedium:    1,
    lengthLong:      2,
    detailLow:       3,
    detailMedium:    4,
    detailHigh:      5,
    strategyTheory:  6,
    strategyExample: 7,
    strategyBoth:    8,
    classBased:      9,
    nonClassBased:   10,
    formatVideo:     11,
    formatBook:      12,
    formatWebPage:   13,
    formatSlide:     14,
  };

  /// Cold-start neutral vector — equal weights within each dimension group.
  /// [TAV22 §3.5.1 — uninformed initialisation]
  static Map<String, double> get defaultVectorMap => <String, double>{
    lengthShort:     1.0 / 3,
    lengthMedium:    1.0 / 3,
    lengthLong:      1.0 / 3,
    detailLow:       1.0 / 3,
    detailMedium:    1.0 / 3,
    detailHigh:      1.0 / 3,
    strategyTheory:  1.0 / 3,
    strategyExample: 1.0 / 3,
    strategyBoth:    1.0 / 3,
    classBased:      0.5,
    nonClassBased:   0.5,
    formatVideo:     0.25,
    formatBook:      0.25,
    formatWebPage:   0.25,
    formatSlide:     0.25,
  };
}

// ══════════════════════════════════════════════════════════════════════════════
// §2  CONTENT LENGTH ENUM  [TAV22 Table 4 — "Length" dimension]
// ══════════════════════════════════════════════════════════════════════════════

enum ContentLength { short, medium, long }

extension ContentLengthX on ContentLength {
  String get displayName {
    switch (this) {
      case ContentLength.short:  return 'Short (< 10 min)';
      case ContentLength.medium: return 'Medium (10–20 min)';
      case ContentLength.long:   return 'Long (> 20 min)';
    }
  }

  /// Single-word label used in human-readable summaries without fragile splitting.
  String get shortLabel {
    switch (this) {
      case ContentLength.short:  return 'short';
      case ContentLength.medium: return 'medium-length';
      case ContentLength.long:   return 'long';
    }
  }

  String get prefKey {
    switch (this) {
      case ContentLength.short:  return PreferenceKeys.lengthShort;
      case ContentLength.medium: return PreferenceKeys.lengthMedium;
      case ContentLength.long:   return PreferenceKeys.lengthLong;
    }
  }

  /// Position in the 15-dim preference vector.
  int get vectorIndex {
    switch (this) {
      case ContentLength.short:  return 0;
      case ContentLength.medium: return 1;
      case ContentLength.long:   return 2;
    }
  }

  String get icon {
    switch (this) {
      case ContentLength.short:  return '⚡';
      case ContentLength.medium: return '📘';
      case ContentLength.long:   return '🎓';
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// §3  DETAIL LEVEL ENUM  [TAV22 Table 4 — "Detail" dimension]
// ══════════════════════════════════════════════════════════════════════════════

enum DetailLevel { low, medium, high }

extension DetailLevelX on DetailLevel {
  String get displayName {
    switch (this) {
      case DetailLevel.low:    return 'Overview';
      case DetailLevel.medium: return 'Standard';
      case DetailLevel.high:   return 'In-Depth';
    }
  }

  /// Single-word label used in human-readable summaries.
  String get shortLabel {
    switch (this) {
      case DetailLevel.low:    return 'overview';
      case DetailLevel.medium: return 'standard';
      case DetailLevel.high:   return 'in-depth';
    }
  }

  String get prefKey {
    switch (this) {
      case DetailLevel.low:    return PreferenceKeys.detailLow;
      case DetailLevel.medium: return PreferenceKeys.detailMedium;
      case DetailLevel.high:   return PreferenceKeys.detailHigh;
    }
  }

  /// Position in the 15-dim preference vector (group offset: 3).
  int get vectorIndex {
    switch (this) {
      case DetailLevel.low:    return 3;
      case DetailLevel.medium: return 4;
      case DetailLevel.high:   return 5;
    }
  }

  String get icon {
    switch (this) {
      case DetailLevel.low:    return '🔍';
      case DetailLevel.medium: return '📊';
      case DetailLevel.high:   return '🔬';
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// §4  LEARNING STRATEGY ENUM  [TAV22 Table 4 — "Strategy" dimension]
// ══════════════════════════════════════════════════════════════════════════════

enum LearningStrategy { theoryOnly, exampleOnly, both }

extension LearningStrategyX on LearningStrategy {
  String get displayName {
    switch (this) {
      case LearningStrategy.theoryOnly:  return 'Theory';
      case LearningStrategy.exampleOnly: return 'Examples';
      case LearningStrategy.both:        return 'Mixed';
    }
  }

  /// Single-word label used in human-readable summaries.
  String get shortLabel {
    switch (this) {
      case LearningStrategy.theoryOnly:  return 'theory-focused';
      case LearningStrategy.exampleOnly: return 'example-based';
      case LearningStrategy.both:        return 'mixed';
    }
  }

  String get prefKey {
    switch (this) {
      case LearningStrategy.theoryOnly:  return PreferenceKeys.strategyTheory;
      case LearningStrategy.exampleOnly: return PreferenceKeys.strategyExample;
      case LearningStrategy.both:        return PreferenceKeys.strategyBoth;
    }
  }

  /// Position in the 15-dim preference vector (group offset: 6).
  int get vectorIndex {
    switch (this) {
      case LearningStrategy.theoryOnly:  return 6;
      case LearningStrategy.exampleOnly: return 7;
      case LearningStrategy.both:        return 8;
    }
  }

  String get icon {
    switch (this) {
      case LearningStrategy.theoryOnly:  return '📖';
      case LearningStrategy.exampleOnly: return '💡';
      case LearningStrategy.both:        return '⚖️';
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// §5  CONTENT FORMAT ENUM  [TAV22 Table 4 — "Format" dimension]
// ══════════════════════════════════════════════════════════════════════════════

enum ContentFormat { video, bookChapter, webPage, slide, classroomBased }

extension ContentFormatX on ContentFormat {
  String get displayName {
    switch (this) {
      case ContentFormat.video:          return 'Video';
      case ContentFormat.bookChapter:    return 'Book / PDF';
      case ContentFormat.webPage:        return 'Web Article';
      case ContentFormat.slide:          return 'Slides';
      case ContentFormat.classroomBased: return 'Lecture';
    }
  }

  /// Single-word label used in human-readable summaries.
  String get shortLabel {
    switch (this) {
      case ContentFormat.video:          return 'video';
      case ContentFormat.bookChapter:    return 'book/PDF';
      case ContentFormat.webPage:        return 'web article';
      case ContentFormat.slide:          return 'slide';
      case ContentFormat.classroomBased: return 'lecture';
    }
  }

  String get prefKey {
    switch (this) {
      case ContentFormat.video:          return PreferenceKeys.formatVideo;
      case ContentFormat.bookChapter:    return PreferenceKeys.formatBook;
      case ContentFormat.webPage:        return PreferenceKeys.formatWebPage;
      case ContentFormat.slide:          return PreferenceKeys.formatSlide;
      case ContentFormat.classroomBased: return PreferenceKeys.classBased;
    }
  }

  /// Position in the 15-dim preference vector.
  /// [classroomBased] maps to the classroom group (index 9).
  int get vectorIndex {
    switch (this) {
      case ContentFormat.video:          return 11;
      case ContentFormat.bookChapter:    return 12;
      case ContentFormat.webPage:        return 13;
      case ContentFormat.slide:          return 14;
      case ContentFormat.classroomBased: return 9;
    }
  }

  String get icon {
    switch (this) {
      case ContentFormat.video:          return '🎬';
      case ContentFormat.bookChapter:    return '📚';
      case ContentFormat.webPage:        return '🌐';
      case ContentFormat.slide:          return '📋';
      case ContentFormat.classroomBased: return '🏫';
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// §6  ANALYTICAL ENUMS (extends [TAV22] with learner-state signals)
// ══════════════════════════════════════════════════════════════════════════════

/// Strength of a learned preference along a given dimension group.
/// Derived by comparing the dominant weight against the uniform baseline.
enum PreferenceStrength {
  /// Near-equal weights — insufficient signal to favour any value (cold-start).
  weak,

  /// Moderate lean — one value is noticeably preferred but not dominant.
  moderate,

  /// Clear signal — one value significantly exceeds the rest.
  strong,
}

extension PreferenceStrengthX on PreferenceStrength {
  String get displayName {
    switch (this) {
      case PreferenceStrength.weak:     return 'Developing';
      case PreferenceStrength.moderate: return 'Moderate';
      case PreferenceStrength.strong:   return 'Strong';
    }
  }

  String get icon {
    switch (this) {
      case PreferenceStrength.weak:     return '🌱';
      case PreferenceStrength.moderate: return '📈';
      case PreferenceStrength.strong:   return '🎯';
    }
  }
}

/// Degree of divergence between the short-term and long-term vectors.
/// Signals when recent behaviour departs from the accumulated baseline.
/// [TAV22 §3.5.1 — short-/long-term split rationale]
enum DriftLevel {
  /// Cosine similarity ≥ 0.95 — vectors highly consistent.
  none,

  /// Cosine similarity 0.80–0.95 — mild recent divergence.
  mild,

  /// Cosine similarity < 0.80 — significant preference shift detected.
  significant,
}

extension DriftLevelX on DriftLevel {
  String get displayName {
    switch (this) {
      case DriftLevel.none:        return 'Consistent';
      case DriftLevel.mild:        return 'Slight Shift';
      case DriftLevel.significant: return 'Notable Shift';
    }
  }

  String get description {
    switch (this) {
      case DriftLevel.none:
        return 'Your recent activity matches your established learning profile.';
      case DriftLevel.mild:
        return 'Your recent activity shows a slight shift in preferences.';
      case DriftLevel.significant:
        return 'Your learning preferences appear to be evolving significantly. '
            'Consider a profile refresh after the next monthly update.';
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// §7  PREFERENCE DIMENSION SNAPSHOT (for UI dimension cards)
// ══════════════════════════════════════════════════════════════════════════════

/// Immutable snapshot of one preference dimension group for display.
/// Returned by [LearnerPreferences.dimensionBreakdown].
class PreferenceDimension {
  /// Human-readable group label (e.g. "Content Length").
  final String label;

  /// Current dominant value (e.g. "Short (< 10 min)").
  final String preferredValue;

  /// Normalised confidence [0.0, 1.0].
  ///   0.0 = uniform (no signal) · 1.0 = fully determined.
  final double confidence;

  /// Icon emoji for the preferred value.
  final String icon;

  const PreferenceDimension({
    required this.label,
    required this.preferredValue,
    required this.confidence,
    required this.icon,
  });

  @override
  String toString() =>
      'PreferenceDimension($label: $preferredValue, '
          'confidence: ${(confidence * 100).toStringAsFixed(0)}%)';
}

// ══════════════════════════════════════════════════════════════════════════════
// §8  VECTOR CONSTANTS
// ══════════════════════════════════════════════════════════════════════════════

/// Total dimensions in every preference / feature vector.
const int kPrefVectorSize = 15;

/// Minimum interaction count before [confidenceScore] is considered meaningful.
const int kConfidenceThreshold = 20;

/// EMA step size for [LearnerPreferences.updateFromFeedback].
/// Controls how quickly short-term preferences adapt to new ratings.
/// [TAV22 §3.5.2]
const double kFeedbackAlpha = 0.25;

/// EMA blend weight (short-term share) for [LearnerPreferences.performMonthlyUpdate].
/// Controls how quickly recent behaviour propagates into the long-term baseline.
/// [TAV22 §3.5.1]
const double kMonthlyBlendAlpha = 0.40;

/// Returns a fresh equal-weight 15-dimensional cold-start vector.
/// [TAV22 §3.5.1 — uninformed initialisation]
List<double> _defaultVector() => <double>[
  1.0 / 3, 1.0 / 3, 1.0 / 3, // 0–2   Length
  1.0 / 3, 1.0 / 3, 1.0 / 3, // 3–5   Detail
  1.0 / 3, 1.0 / 3, 1.0 / 3, // 6–8   Strategy
  0.5,      0.5,               // 9–10  Classroom
  0.25,     0.25,  0.25, 0.25, // 11–14 Format
];

// ══════════════════════════════════════════════════════════════════════════════
// §9  LEARNER PREFERENCES MODEL
// ══════════════════════════════════════════════════════════════════════════════

/// [TAV22 §3.5 — Learner profile]
///
/// Encapsulates a learner's content preferences as two 15-dimensional vectors:
///   • [shortTermVector] — EMA-updated after each rated interaction; resets monthly.
///   • [longTermVector]  — stable baseline blended from [shortTermVector] monthly.
///
/// Scoring uses both dot-product [TAV22 §3.5.2] and cosine similarity [ALS22]
/// to support different ranking contexts.
///
/// Immutable: every mutation method returns a new [LearnerPreferences] instance.
class LearnerPreferences {
  // ── Core vectors ──────────────────────────────────────────────────────────

  /// [TAV22 §3.5.1 — Short-term preference vector]
  /// Updated via EMA after each feedback event. Reset to equal weights monthly.
  /// Length: exactly [kPrefVectorSize] = 15 elements.
  final List<double> shortTermVector;

  /// [TAV22 §3.5.1 — Long-term preference vector]
  /// Stable accumulated baseline; the primary scoring vector for recommenders.
  /// Length: exactly [kPrefVectorSize] = 15 elements.
  final List<double> longTermVector;

  /// Timestamp of the most recent vector mutation.
  final DateTime lastUpdated;

  /// Cumulative count of feedback interactions (ratings submitted).
  /// Drives [confidenceScore]. Never negative.
  final int interactionCount;

  // ── Constructor ───────────────────────────────────────────────────────────

  LearnerPreferences({
    required this.shortTermVector,
    required this.longTermVector,
    required this.lastUpdated,
    this.interactionCount = 0,
  })  : assert(
  shortTermVector.length == kPrefVectorSize,
  'shortTermVector must have $kPrefVectorSize elements; '
      'got ${shortTermVector.length}.',
  ),
        assert(
        longTermVector.length == kPrefVectorSize,
        'longTermVector must have $kPrefVectorSize elements; '
            'got ${longTermVector.length}.',
        ),
        assert(
        interactionCount >= 0,
        'interactionCount cannot be negative.',
        );

  // ── Factory: cold-start defaults ──────────────────────────────────────────

  /// Returns equal-weight preferences for a brand-new learner (cold-start).
  /// [TAV22 §3.5.1]
  factory LearnerPreferences.defaults() => LearnerPreferences(
    shortTermVector: _defaultVector(),
    longTermVector: _defaultVector(),
    lastUpdated: DateTime.now(),
    interactionCount: 0,
  );

  // ── Factory: profile-setup key map ────────────────────────────────────────

  /// Builds a [LearnerPreferences] from a [Map<String, double>] whose keys
  /// correspond to [PreferenceKeys] constants. Missing keys fall back to
  /// equal-weight defaults. Each dimension group is normalised after loading.
  factory LearnerPreferences.fromKeyMap(Map<String, double> keyMap) {
    final vec = _defaultVector();
    for (final entry in keyMap.entries) {
      final idx = PreferenceKeys.keyToVectorIndex[entry.key];
      if (idx != null) vec[idx] = entry.value.clamp(0.0, 1.0);
    }
    final normalised = _normaliseGroups(vec);
    return LearnerPreferences(
      shortTermVector: List<double>.from(normalised),
      longTermVector: List<double>.from(normalised),
      lastUpdated: DateTime.now(),
      interactionCount: 0,
    );
  }

  // ── Factory: deserialisation ──────────────────────────────────────────────

  factory LearnerPreferences.fromMap(Map<String, dynamic> map) =>
      LearnerPreferences(
        shortTermVector: _parseVector(map['shortTermVector']),
        longTermVector: _parseVector(map['longTermVector']),
        lastUpdated: map['lastUpdated'] != null
            ? DateTime.fromMillisecondsSinceEpoch(
          (map['lastUpdated'] as num).toInt(),
        )
            : DateTime.now(),
        interactionCount: (map['interactionCount'] as num?)?.toInt() ?? 0,
      );

  factory LearnerPreferences.fromJson(Map<String, dynamic> json) =>
      LearnerPreferences.fromMap(json);

  // ══════════════════════════════════════════════════════════════════════════
  // MUTATION METHODS
  // ══════════════════════════════════════════════════════════════════════════

  /// [TAV22 §3.5.2 — Feedback-driven EMA short-term update]
  ///
  /// Updates [shortTermVector] based on a learner's rating of a content item.
  ///
  /// Algorithm:
  ///   normRating = (rating − 1) / 4   →  [0.0 … 1.0]
  ///
  ///   Positive feedback (normRating ≥ 0.5):
  ///     short[i] += alpha × normRating × courseVector[i]
  ///     → moves the vector toward the content's feature profile.
  ///
  ///   Negative feedback (normRating < 0.5):
  ///     short[i] = max(0, short[i] − alpha × (1 − normRating) × courseVector[i])
  ///     → moves the vector away from the content's feature profile.
  ///
  ///   Each dimension group is re-normalised after the update.
  ///
  /// Parameters:
  ///   [rating]       — learner's 1–5 star rating (clamped to range).
  ///   [courseVector] — 15-dim feature vector of the rated content item.
  ///   [alpha]        — EMA step size (default [kFeedbackAlpha] = 0.25).
  ///
  /// Returns [this] unchanged when [courseVector] has wrong dimensions.
  LearnerPreferences updateFromFeedback(
      double rating,
      List<double> courseVector, {
        double alpha = kFeedbackAlpha,
      }) {
    if (courseVector.length != kPrefVectorSize) return this;

    final normRating = (rating.clamp(1.0, 5.0) - 1.0) / 4.0;
    final updated = List<double>.from(shortTermVector);

    if (normRating >= 0.5) {
      // Positive feedback — reinforce matching dimensions.
      for (var i = 0; i < kPrefVectorSize; i++) {
        updated[i] += alpha * normRating * courseVector[i];
      }
    } else {
      // Negative feedback — suppress matching dimensions.
      for (var i = 0; i < kPrefVectorSize; i++) {
        updated[i] = max(
          0.0,
          updated[i] - alpha * (1.0 - normRating) * courseVector[i],
        );
      }
    }

    return copyWith(
      shortTermVector: _normaliseGroups(updated),
      lastUpdated: DateTime.now(),
      interactionCount: interactionCount + 1,
    );
  }

  /// [TAV22 §3.5.1 — Monthly long-term EMA blend]
  ///
  /// Blends [shortTermVector] into [longTermVector] via EMA, then resets
  /// [shortTermVector] to cold-start equal weights for the next 30-day window.
  ///
  /// Formula (per dimension i):
  ///   new_long[i] = alpha × short[i] + (1 − alpha) × long[i]
  ///
  /// [alpha] — short-term blend weight (default [kMonthlyBlendAlpha] = 0.40).
  LearnerPreferences performMonthlyUpdate({
    double alpha = kMonthlyBlendAlpha,
  }) {
    final newLong = List<double>.generate(
      kPrefVectorSize,
          (i) => alpha * shortTermVector[i] + (1.0 - alpha) * longTermVector[i],
    );
    return copyWith(
      longTermVector: _normaliseGroups(newLong),
      shortTermVector: _defaultVector(), // reset for the next 30-day window
      lastUpdated: DateTime.now(),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SCORING METHODS
  // ══════════════════════════════════════════════════════════════════════════

  /// [TAV22 §3.5.2 — Dot-product content scoring]
  ///
  /// Returns the dot product of [longTermVector] × [contentVector].
  /// Higher scores indicate a better preference match.
  /// Returns 0.0 on dimension mismatch (safe fallback).
  double scoreContent(List<double> contentVector) {
    if (contentVector.length != kPrefVectorSize) return 0.0;
    var dot = 0.0;
    for (var i = 0; i < kPrefVectorSize; i++) {
      dot += longTermVector[i] * contentVector[i];
    }
    return dot.clamp(0.0, double.infinity);
  }

  /// [ALS22 — Weighted cosine-similarity scoring]
  ///
  /// Returns the cosine similarity between [longTermVector] and [contentVector],
  /// normalised to [0.0, 1.0]. Preferred over [scoreContent] when content
  /// vectors may differ in magnitude across the catalogue.
  ///
  /// Returns 0.0 on dimension mismatch or zero-magnitude vectors.
  double cosineScoreContent(List<double> contentVector) {
    if (contentVector.length != kPrefVectorSize) return 0.0;
    return _cosineSimilarity(longTermVector, contentVector);
  }

  /// Returns per-dimension-group dot-product scores for explainability.
  ///
  /// Keys: 'length', 'detail', 'strategy', 'classroom', 'format'.
  /// Each value lies in [0.0, 1.0] (normalised vectors guarantee this).
  /// Returns an empty map on dimension mismatch.
  Map<String, double> dimensionScores(List<double> contentVector) {
    if (contentVector.length != kPrefVectorSize) {
      return <String, double>{};
    }
    return <String, double>{
      'length':    _groupDot(longTermVector, contentVector, [0, 1, 2]),
      'detail':    _groupDot(longTermVector, contentVector, [3, 4, 5]),
      'strategy':  _groupDot(longTermVector, contentVector, [6, 7, 8]),
      'classroom': _groupDot(longTermVector, contentVector, [9, 10]),
      'format':    _groupDot(longTermVector, contentVector, [11, 12, 13, 14]),
    };
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PREFERRED-DIMENSION GETTERS
  // ══════════════════════════════════════════════════════════════════════════

  /// [ContentLength] with the highest weight in [longTermVector] (indices 0–2).
  ContentLength get preferredLength {
    // ContentLength.values order: short(0) medium(1) long(2) — matches vector.
    return ContentLength.values[_argMax(longTermVector.sublist(0, 3))];
  }

  /// [DetailLevel] with the highest weight (indices 3–5).
  DetailLevel get preferredDetailLevel {
    // DetailLevel.values order: low(0) medium(1) high(2) — matches vector.
    return DetailLevel.values[_argMax(longTermVector.sublist(3, 6))];
  }

  /// [LearningStrategy] with the highest weight (indices 6–8).
  LearningStrategy get preferredStrategy {
    // LearningStrategy.values: theoryOnly(0) exampleOnly(1) both(2).
    return LearningStrategy.values[_argMax(longTermVector.sublist(6, 9))];
  }

  /// [ContentFormat] with the highest weight in the format group (indices 11–14).
  ContentFormat get preferredFormat {
    const formats = <ContentFormat>[
      ContentFormat.video,
      ContentFormat.bookChapter,
      ContentFormat.webPage,
      ContentFormat.slide,
    ];
    return formats[_argMax(longTermVector.sublist(11, 15))];
  }

  /// True when classroom-based content is preferred (index 9 > index 10).
  bool get prefersClassroomContent => longTermVector[9] > longTermVector[10];

  // ══════════════════════════════════════════════════════════════════════════
  // ANALYTICAL GETTERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Cosine similarity between [shortTermVector] and [longTermVector].
  ///   1.0 = perfectly aligned · 0.0 = orthogonal (maximum drift).
  /// [ALS22]
  double get shortLongCosineSimilarity =>
      _cosineSimilarity(shortTermVector, longTermVector);

  /// True when [lastUpdated] is ≥ 30 days ago — monthly EMA blend is overdue.
  bool get isMonthlyUpdateDue =>
      DateTime.now().difference(lastUpdated).inDays >= 30;

  /// True when [longTermVector] still matches the cold-start equal-weight
  /// vector within a floating-point tolerance of 1 × 10⁻⁶.
  bool get isAtDefaults {
    final def = _defaultVector();
    for (var i = 0; i < kPrefVectorSize; i++) {
      if ((longTermVector[i] - def[i]).abs() > 1e-6) return false;
    }
    return true;
  }

  /// Confidence score [0.0, 1.0] derived from [interactionCount].
  /// Saturates at [kConfidenceThreshold] interactions.
  /// [TAV22 §3.5.1 — cold-start vs. warm-profile distinction]
  double get confidenceScore =>
      (interactionCount / kConfidenceThreshold).clamp(0.0, 1.0);

  /// Overall [PreferenceStrength] — how well-defined the dominant preferences
  /// are, averaged across all five dimension groups.
  ///
  /// Each group contributes: excess = max_weight − uniform_weight.
  ///   avgExcess ≥ 0.20 → strong · ≥ 0.08 → moderate · else → weak.
  PreferenceStrength get preferenceStrength {
    const groups = <List<int>>[
      [0, 1, 2],
      [3, 4, 5],
      [6, 7, 8],
      [9, 10],
      [11, 12, 13, 14],
    ];

    var totalExcess = 0.0;
    for (final grp in groups) {
      final n = grp.length;
      final maxVal = grp.fold<double>(
        0.0,
            (m, i) => max(m, longTermVector[i]),
      );
      final uniform = 1.0 / n;
      totalExcess += (maxVal - uniform).clamp(0.0, 1.0 - uniform);
    }

    final avgExcess = totalExcess / groups.length;
    if (avgExcess >= 0.20) return PreferenceStrength.strong;
    if (avgExcess >= 0.08) return PreferenceStrength.moderate;
    return PreferenceStrength.weak;
  }

  /// [DriftLevel] derived from [shortLongCosineSimilarity].
  DriftLevel get driftLevel {
    final sim = shortLongCosineSimilarity;
    if (sim >= 0.95) return DriftLevel.none;
    if (sim >= 0.80) return DriftLevel.mild;
    return DriftLevel.significant;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PRESENTATION HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Returns [longTermVector] as a [Map<String, double>] keyed by
  /// [PreferenceKeys] constants. Suitable for building preference sliders.
  Map<String, double> get longTermKeyMap {
    final result = <String, double>{};
    for (var i = 0; i < PreferenceKeys.allKeys.length; i++) {
      result[PreferenceKeys.allKeys[i]] =
      i < longTermVector.length ? longTermVector[i] : 0.0;
    }
    return result;
  }

  /// A single-sentence human-readable summary of the learner's top preferences.
  ///
  /// Example: "You prefer short, in-depth video content with a mixed approach."
  ///
  /// Uses [shortLabel] on each enum value to avoid fragile string splitting.
  String get preferenceExplanation {
    final lengthWord   = preferredLength.shortLabel;
    final detailWord   = preferredDetailLevel.shortLabel;
    final formatWord   = preferredFormat.shortLabel;
    final strategyWord = preferredStrategy.shortLabel;
    return 'You prefer $lengthWord, $detailWord $formatWord content '
        'with a $strategyWord approach.';
  }

  /// Returns a breakdown of all five preference dimensions for dashboard cards.
  ///
  /// Confidence is the normalised excess above a uniform distribution:
  ///   0.0 = no preference signal · 1.0 = fully determined preference.
  List<PreferenceDimension> get dimensionBreakdown {
    // Local helper: normalised confidence for a group defined by [indices].
    double groupConfidence(List<int> indices) {
      final n = indices.length;
      final maxVal = indices.fold<double>(
        0.0,
            (m, i) => max(m, longTermVector[i]),
      );
      final uniform = 1.0 / n;
      return ((maxVal - uniform) / (1.0 - uniform)).clamp(0.0, 1.0);
    }

    return <PreferenceDimension>[
      PreferenceDimension(
        label: 'Content Length',
        preferredValue: preferredLength.displayName,
        confidence: groupConfidence([0, 1, 2]),
        icon: preferredLength.icon,
      ),
      PreferenceDimension(
        label: 'Detail Level',
        preferredValue: preferredDetailLevel.displayName,
        confidence: groupConfidence([3, 4, 5]),
        icon: preferredDetailLevel.icon,
      ),
      PreferenceDimension(
        label: 'Learning Strategy',
        preferredValue: preferredStrategy.displayName,
        confidence: groupConfidence([6, 7, 8]),
        icon: preferredStrategy.icon,
      ),
      PreferenceDimension(
        label: 'Delivery Mode',
        preferredValue: prefersClassroomContent ? 'Lecture' : 'Self-paced',
        confidence: groupConfidence([9, 10]),
        icon: prefersClassroomContent ? '🏫' : '🖥️',
      ),
      PreferenceDimension(
        label: 'Content Format',
        preferredValue: preferredFormat.displayName,
        confidence: groupConfidence([11, 12, 13, 14]),
        icon: preferredFormat.icon,
      ),
    ];
  }

  // ══════════════════════════════════════════════════════════════════════════
  // copyWith / SERIALISATION / EQUALITY
  // ══════════════════════════════════════════════════════════════════════════

  LearnerPreferences copyWith({
    List<double>? shortTermVector,
    List<double>? longTermVector,
    DateTime? lastUpdated,
    int? interactionCount,
  }) =>
      LearnerPreferences(
        shortTermVector: shortTermVector != null
            ? List<double>.from(shortTermVector)
            : List<double>.from(this.shortTermVector),
        longTermVector: longTermVector != null
            ? List<double>.from(longTermVector)
            : List<double>.from(this.longTermVector),
        lastUpdated: lastUpdated ?? this.lastUpdated,
        interactionCount: interactionCount ?? this.interactionCount,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
    'shortTermVector': shortTermVector,
    'longTermVector': longTermVector,
    'lastUpdated': lastUpdated.millisecondsSinceEpoch,
    'interactionCount': interactionCount,
  };

  Map<String, dynamic> toJson() => toMap();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          (other is LearnerPreferences &&
              _listEquals(other.shortTermVector, shortTermVector) &&
              _listEquals(other.longTermVector, longTermVector) &&
              other.lastUpdated == lastUpdated &&
              other.interactionCount == interactionCount);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(shortTermVector),
    Object.hashAll(longTermVector),
    lastUpdated,
    interactionCount,
  );

  @override
  String toString() =>
      'LearnerPreferences('
          'length: ${preferredLength.displayName}, '
          'detail: ${preferredDetailLevel.displayName}, '
          'strategy: ${preferredStrategy.displayName}, '
          'format: ${preferredFormat.displayName}, '
          'classroom: $prefersClassroomContent, '
          'confidence: ${(confidenceScore * 100).toStringAsFixed(0)}%, '
          'strength: ${preferenceStrength.displayName}, '
          'drift: ${driftLevel.displayName}, '
          'interactions: $interactionCount, '
          'lastUpdated: $lastUpdated)';
}

// ══════════════════════════════════════════════════════════════════════════════
// §10  PRIVATE UTILITIES
// ══════════════════════════════════════════════════════════════════════════════

/// Returns the index of the maximum value in [slice].
/// Ties favour the lower index (stable ordering).
int _argMax(List<double> slice) {
  var best = 0;
  for (var i = 1; i < slice.length; i++) {
    if (slice[i] > slice[best]) best = i;
  }
  return best;
}

/// Cosine similarity between vectors [a] and [b], clamped to [0.0, 1.0].
///
/// Returns 0.0 when [a] and [b] have different lengths, or when either
/// vector has zero magnitude.  Uses a runtime guard (not an `assert`) so
/// that the check is preserved in release builds.
///
/// [ALS22 — weighted cosine similarity]
double _cosineSimilarity(List<double> a, List<double> b) {
  if (a.length != b.length) return 0.0; // safe guard — not stripped in release
  var dot   = 0.0;
  var normA = 0.0;
  var normB = 0.0;
  for (var i = 0; i < a.length; i++) {
    dot   += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  final denom = sqrt(normA) * sqrt(normB);
  return denom == 0.0 ? 0.0 : (dot / denom).clamp(0.0, 1.0);
}

/// Dot product of [a] × [b] restricted to the specified [indices].
double _groupDot(
    List<double> a,
    List<double> b,
    List<int> indices,
    ) =>
    indices.fold(0.0, (sum, i) => sum + a[i] * b[i]);

/// Re-normalises [v] so values within each dimension group sum to 1.0.
///
/// Groups and their vector indices:
///   0–2   (length · 3 values)
///   3–5   (detail · 3 values)
///   6–8   (strategy · 3 values)
///   9–10  (classroom · 2 values)
///   11–14 (format · 4 values)
///
/// If an entire group sums to zero, equal weights are restored for that group.
List<double> _normaliseGroups(List<double> v) {
  final out = List<double>.from(v);
  const groups = <List<int>>[
    [0, 1, 2],
    [3, 4, 5],
    [6, 7, 8],
    [9, 10],
    [11, 12, 13, 14],
  ];
  for (final grp in groups) {
    final total = grp.fold<double>(0.0, (s, i) => s + out[i]);
    if (total > 0.0) {
      for (final i in grp) {
        out[i] = out[i] / total;
      }
    } else {
      // Restore equal weights when the group is fully zeroed.
      final eq = 1.0 / grp.length;
      for (final i in grp) {
        out[i] = eq;
      }
    }
  }
  return out;
}

/// Safely parses a dynamic list (from JSON / SharedPreferences) to
/// [List<double>]. Falls back to [_defaultVector()] on null, type mismatch,
/// or incorrect length.
List<double> _parseVector(dynamic raw) {
  if (raw == null) return _defaultVector();
  try {
    final list = (raw as List<dynamic>)
        .map((e) => (e as num).toDouble())
        .toList();
    return list.length == kPrefVectorSize ? list : _defaultVector();
  } catch (_) {
    return _defaultVector();
  }
}

/// Structural equality for two [List<double>] instances (element-wise).
bool _listEquals(List<double> a, List<double> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}