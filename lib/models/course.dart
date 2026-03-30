// lib/models/course.dart — SkillBridge AI
// ─────────────────────────────────────────────────────────────────────────────
// SESSION 3 UPGRADE — Maximum-level rewrite, 100 % null-safe, zero breaking
// changes to existing constructor / toMap / fromMap / helper call sites.
//
// PATCH NOTES (applied on top of Session 3)
// ──────────────────────────────────────────
// • PreferenceKeys format-dimension keys fixed:
//     OLD  content_video / content_book / content_webpage / content_slide
//     NEW  format_video  / format_book  / format_web_page / format_slide
//   These now match the keys emitted by CareerProfile.learnerColdStartVector
//   (career_profile.dart) so the dot-product recommender no longer silently
//   scores 0 on the format dimension.
// • cosineSimilarity: removed redundant inner ternary — the outer denom==0
//   guard already ensures dartSqrt is called only when denom > 0.
// • _parseDoubleMap: changed return type from Map<String,double>? to
//   Map<String,double> (returns growable {} on failure) and removed all
//   nullable ?? const {} fall-backs at every call site so callers receive
//   a consistent, mutable map.
// • CareerFitScore.weakestAxis / strongestAxis: replaced per-call Map
//   construction with direct value comparisons (no allocation on every call).
//
// References (unchanged)
// ──────────────────────
// [Tavakoli 2022] Tavakoli et al. (Advanced Engineering Informatics 52, 101508)
// [Alsaif 2022]   Alsaif et al.  (MDPI Computers 11, 161)
// ─────────────────────────────────────────────────────────────────────────────

// ignore_for_file: prefer_constructors_over_static_methods

import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════
// §1  SENTINEL — clean nullable copyWith without boolean clear-flags
// ═══════════════════════════════════════════════════════════════════════════

class _Unset {
  const _Unset();
}

const _unset = _Unset();

// ═══════════════════════════════════════════════════════════════════════════
// §2  PreferenceKeys (mirrored — keep in sync with main.dart / app_state.dart)
// ═══════════════════════════════════════════════════════════════════════════

/// [Tavakoli 2022 §3.5.1, Table 4]
/// The 15 canonical feature keys forming both the learner preference vector
/// and the course feature vector used by the dot-product recommender.
///
/// IMPORTANT: These string values must match the keys produced by
/// [CareerProfile.learnerColdStartVector] (career_profile.dart) so that
/// dot-product and cosine-similarity scoring works correctly across both
/// directions of the vector.
abstract class PreferenceKeys {
  // Length dimension  (indices 0–2)
  static const String lengthShort  = 'length_short';
  static const String lengthMedium = 'length_medium';
  static const String lengthLong   = 'length_long';

  // Detail dimension  (indices 3–5)
  static const String detailLow    = 'detail_low';
  static const String detailMedium = 'detail_medium';
  static const String detailHigh   = 'detail_high';

  // Strategy dimension  (indices 6–8)
  static const String strategyTheory  = 'strategy_theory';
  static const String strategyExample = 'strategy_example';
  static const String strategyBoth    = 'strategy_both';

  // Classroom dimension  (indices 9–10)
  static const String classBased    = 'class_based';
  static const String nonClassBased = 'non_class_based';

  // Content format dimension  (indices 11–14)
  // FIX: keys changed from 'content_*' to 'format_*' to match the keys
  // emitted by CareerProfile.learnerColdStartVector in career_profile.dart.
  static const String contentVideo   = 'format_video';
  static const String contentBook    = 'format_book';
  static const String contentWebpage = 'format_web_page';
  static const String contentSlide   = 'format_slide';

  /// All 15 keys in canonical index order.
  static const List<String> all = [
    lengthShort,  lengthMedium,  lengthLong,
    detailLow,    detailMedium,  detailHigh,
    strategyTheory, strategyExample, strategyBoth,
    classBased,   nonClassBased,
    contentVideo, contentBook,   contentWebpage, contentSlide,
  ];
}

// ═══════════════════════════════════════════════════════════════════════════
// §3  ENUMS — all upgraded to Dart 3 switch-expression style
// ═══════════════════════════════════════════════════════════════════════════

// ── 3.1  ContentLength ────────────────────────────────────────────────────────

/// [Tavakoli 2022 §3.4.3 — Length labeling]
/// Short < 10 min | Medium 10–20 min | Long > 20 min (video proxy for courses).
enum ContentLength { short, medium, long }

extension ContentLengthExtension on ContentLength {
  /// Human-readable label for filter chips and learner profile UI.
  String get displayName => switch (this) {
    ContentLength.short  => 'Short',
    ContentLength.medium => 'Medium',
    ContentLength.long   => 'Long',
  };

  /// Tooltip description used in onboarding preference survey.
  String get description => switch (this) {
    ContentLength.short  => 'Under 10 minutes — quick overviews or micro-lessons',
    ContentLength.medium => '10–20 minutes — focused lessons with some depth',
    ContentLength.long   => 'Over 20 minutes — comprehensive deep-dives',
  };

  /// Icon for content cards and preference selection UI.
  IconData get icon => switch (this) {
    ContentLength.short  => Icons.flash_on_rounded,
    ContentLength.medium => Icons.schedule_rounded,
    ContentLength.long   => Icons.hourglass_bottom_rounded,
  };

  /// Serialisation key stored in toMap / SharedPreferences.
  String get key => switch (this) {
    ContentLength.short  => 'short',
    ContentLength.medium => 'medium',
    ContentLength.long   => 'long',
  };

  /// The [PreferenceKeys] constant this enum value maps to in the feature vector.
  String get preferenceKey => switch (this) {
    ContentLength.short  => PreferenceKeys.lengthShort,
    ContentLength.medium => PreferenceKeys.lengthMedium,
    ContentLength.long   => PreferenceKeys.lengthLong,
  };

  /// Feature-vector index for this length (0 = short, 1 = medium, 2 = long).
  int get vectorIndex => switch (this) {
    ContentLength.short  => 0,
    ContentLength.medium => 1,
    ContentLength.long   => 2,
  };

  /// Rough maximum duration estimate in hours for ordering purposes.
  double get maxHours => switch (this) {
    ContentLength.short  => 0.17,  // ~10 min
    ContentLength.medium => 0.33,  // ~20 min
    ContentLength.long   => double.infinity,
  };

  /// Deserialise from stored key string.
  static ContentLength fromKey(String key) => switch (key.toLowerCase().trim()) {
    'short' => ContentLength.short,
    'long'  => ContentLength.long,
    _       => ContentLength.medium,
  };
}

// ── 3.2  DetailLevel ──────────────────────────────────────────────────────────

/// [Tavakoli 2022 §3.4.3 — Level of detail labeling]
enum DetailLevel { low, medium, high }

extension DetailLevelExtension on DetailLevel {
  /// Human-readable label.
  String get displayName => switch (this) {
    DetailLevel.low    => 'Overview',
    DetailLevel.medium => 'Standard',
    DetailLevel.high   => 'In-Depth',
  };

  /// Brief description of the depth tier.
  String get description => switch (this) {
    DetailLevel.low    => 'High-level survey — key concepts without deep technical detail',
    DetailLevel.medium => 'Balanced coverage — concepts plus practical application',
    DetailLevel.high   => 'Expert depth — full theory, edge cases, and advanced patterns',
  };

  /// Brand colour for detail-level badges.
  Color get color => switch (this) {
    DetailLevel.low    => const Color(0xFF78909C),
    DetailLevel.medium => const Color(0xFF1976D2),
    DetailLevel.high   => const Color(0xFF6A1B9A),
  };

  /// Icon representing the depth tier.
  IconData get icon => switch (this) {
    DetailLevel.low    => Icons.layers_outlined,
    DetailLevel.medium => Icons.layers_rounded,
    DetailLevel.high   => Icons.science_outlined,
  };

  /// Serialisation key.
  String get key => switch (this) {
    DetailLevel.low    => 'low',
    DetailLevel.medium => 'medium',
    DetailLevel.high   => 'high',
  };

  /// The [PreferenceKeys] constant for the feature vector.
  String get preferenceKey => switch (this) {
    DetailLevel.low    => PreferenceKeys.detailLow,
    DetailLevel.medium => PreferenceKeys.detailMedium,
    DetailLevel.high   => PreferenceKeys.detailHigh,
  };

  /// Feature-vector index (3 = low, 4 = medium, 5 = high).
  int get vectorIndex => switch (this) {
    DetailLevel.low    => 3,
    DetailLevel.medium => 4,
    DetailLevel.high   => 5,
  };

  /// Numeric depth rank for ordering (low=1, medium=2, high=3).
  int get rank => switch (this) {
    DetailLevel.low    => 1,
    DetailLevel.medium => 2,
    DetailLevel.high   => 3,
  };

  static DetailLevel fromKey(String key) => switch (key.toLowerCase().trim()) {
    'low'  => DetailLevel.low,
    'high' => DetailLevel.high,
    _      => DetailLevel.medium,
  };
}

// ── 3.3  LearningStrategy ─────────────────────────────────────────────────────

/// [Tavakoli 2022 §3.4.3 — Learning strategy labeling]
enum LearningStrategy { theoryOnly, exampleOnly, both }

extension LearningStrategyExtension on LearningStrategy {
  /// Human-readable label.
  String get displayName => switch (this) {
    LearningStrategy.theoryOnly  => 'Theory',
    LearningStrategy.exampleOnly => 'Examples',
    LearningStrategy.both        => 'Theory + Examples',
  };

  /// Tooltip description used in onboarding.
  String get description => switch (this) {
    LearningStrategy.theoryOnly  =>
    'Conceptual explanations, definitions, and principles',
    LearningStrategy.exampleOnly =>
    'Worked examples, tutorials, and hands-on practice',
    LearningStrategy.both        =>
    'Balanced mix of theory and practical examples',
  };

  /// Icon representing the strategy tier.
  IconData get icon => switch (this) {
    LearningStrategy.theoryOnly  => Icons.menu_book_outlined,
    LearningStrategy.exampleOnly => Icons.build_outlined,
    LearningStrategy.both        => Icons.balance_outlined,
  };

  /// Serialisation key.
  String get key => switch (this) {
    LearningStrategy.theoryOnly  => 'theory',
    LearningStrategy.exampleOnly => 'example',
    LearningStrategy.both        => 'both',
  };

  /// The [PreferenceKeys] constant for the feature vector.
  String get preferenceKey => switch (this) {
    LearningStrategy.theoryOnly  => PreferenceKeys.strategyTheory,
    LearningStrategy.exampleOnly => PreferenceKeys.strategyExample,
    LearningStrategy.both        => PreferenceKeys.strategyBoth,
  };

  /// Feature-vector index (6 = theory, 7 = example, 8 = both).
  int get vectorIndex => switch (this) {
    LearningStrategy.theoryOnly  => 6,
    LearningStrategy.exampleOnly => 7,
    LearningStrategy.both        => 8,
  };

  /// True when the strategy includes worked examples.
  bool get includesExamples =>
      this == LearningStrategy.exampleOnly || this == LearningStrategy.both;

  /// True when the strategy includes conceptual theory.
  bool get includesTheory =>
      this == LearningStrategy.theoryOnly || this == LearningStrategy.both;

  static LearningStrategy fromKey(String key) =>
      switch (key.toLowerCase().trim()) {
        'theory'  => LearningStrategy.theoryOnly,
        'example' => LearningStrategy.exampleOnly,
        _         => LearningStrategy.both,
      };
}

// ── 3.4  ContentFormat ────────────────────────────────────────────────────────

/// [Tavakoli 2022 §3.4.1 — Collection of online educational resources]
enum ContentFormat { video, bookChapter, webPage, slide }

extension ContentFormatExtension on ContentFormat {
  /// Human-readable label.
  String get displayName => switch (this) {
    ContentFormat.video       => 'Video',
    ContentFormat.bookChapter => 'Book Chapter',
    ContentFormat.webPage     => 'Web Page',
    ContentFormat.slide       => 'Slides',
  };

  /// Icon for filter chips and course cards.
  IconData get icon => switch (this) {
    ContentFormat.video       => Icons.play_circle_outline_rounded,
    ContentFormat.bookChapter => Icons.menu_book_rounded,
    ContentFormat.webPage     => Icons.language_rounded,
    ContentFormat.slide       => Icons.slideshow_rounded,
  };

  /// Brand colour for format badge.
  Color get color => switch (this) {
    ContentFormat.video       => const Color(0xFFD32F2F),
    ContentFormat.bookChapter => const Color(0xFF388E3C),
    ContentFormat.webPage     => const Color(0xFF1976D2),
    ContentFormat.slide       => const Color(0xFFF57C00),
  };

  /// Serialisation key (stored in toMap / SharedPreferences).
  String get key => switch (this) {
    ContentFormat.video       => 'video',
    ContentFormat.bookChapter => 'book',
    ContentFormat.webPage     => 'webpage',
    ContentFormat.slide       => 'slide',
  };

  /// The [PreferenceKeys] constant for the feature vector.
  /// NOTE: values are 'format_*' to match CareerProfile.learnerColdStartVector.
  String get preferenceKey => switch (this) {
    ContentFormat.video       => PreferenceKeys.contentVideo,   // 'format_video'
    ContentFormat.bookChapter => PreferenceKeys.contentBook,    // 'format_book'
    ContentFormat.webPage     => PreferenceKeys.contentWebpage, // 'format_web_page'
    ContentFormat.slide       => PreferenceKeys.contentSlide,   // 'format_slide'
  };

  /// Feature-vector index (11 = video, 12 = book, 13 = webpage, 14 = slide).
  int get vectorIndex => switch (this) {
    ContentFormat.video       => 11,
    ContentFormat.bookChapter => 12,
    ContentFormat.webPage     => 13,
    ContentFormat.slide       => 14,
  };

  /// True for formats that are primarily self-paced and asynchronous.
  bool get isAsynchronous => this != ContentFormat.slide;

  static ContentFormat fromKey(String key) => switch (key.toLowerCase().trim()) {
    'book'    => ContentFormat.bookChapter,
    'webpage' => ContentFormat.webPage,
    'web'     => ContentFormat.webPage,
    'slide'   => ContentFormat.slide,
    'slides'  => ContentFormat.slide,
    _         => ContentFormat.video,
  };
}

// ── 3.5  CourseLevel ─────────────────────────────────────────────────────────

/// Type-safe seniority level for a course.
enum CourseLevel {
  beginner('Beginner'),
  intermediate('Intermediate'),
  advanced('Advanced');

  const CourseLevel(this.value);
  final String value;

  static CourseLevel fromString(String raw) {
    for (final l in CourseLevel.values) {
      if (l.value.toLowerCase() == raw.toLowerCase().trim()) return l;
    }
    return CourseLevel.beginner;
  }

  /// Numeric rank for ordering (beginner=1, intermediate=2, advanced=3).
  int get rank => index + 1;

  Color get color => switch (this) {
    CourseLevel.beginner     => const Color(0xFF388E3C),
    CourseLevel.intermediate => const Color(0xFF1976D2),
    CourseLevel.advanced     => const Color(0xFF6A1B9A),
  };

  IconData get icon => switch (this) {
    CourseLevel.beginner     => Icons.star_border_rounded,
    CourseLevel.intermediate => Icons.star_half_rounded,
    CourseLevel.advanced     => Icons.star_rounded,
  };

  String get displayName => value;
}

// ── 3.6  CourseType ──────────────────────────────────────────────────────────

/// Type-safe course type classification.
enum CourseType {
  course('Course'),
  bootcamp('Bootcamp'),
  video('Video'),
  certificate('Certificate');

  const CourseType(this.value);
  final String value;

  static CourseType fromString(String raw) {
    for (final t in CourseType.values) {
      if (t.value.toLowerCase() == raw.toLowerCase().trim()) return t;
    }
    return CourseType.course;
  }

  bool get isCredential =>
      this == CourseType.certificate || this == CourseType.bootcamp;

  bool get isQuickFormat => this == CourseType.video;

  String get displayName => value;

  IconData get icon => switch (this) {
    CourseType.course       => Icons.school_outlined,
    CourseType.bootcamp     => Icons.rocket_launch_outlined,
    CourseType.video        => Icons.play_circle_outline_rounded,
    CourseType.certificate  => Icons.workspace_premium_outlined,
  };
}

// ── 3.7  CourseSortStrategy ───────────────────────────────────────────────────

/// Sort strategies for [sortCourses].
enum CourseSortStrategy {
  /// Highest user rating first.
  ratingDesc,

  /// Highest quality score first (Tavakoli §3.4.2).
  qualityScoreDesc,

  /// Most views / enrolments first.
  viewCountDesc,

  /// Dot-product preference match — requires pre-attached recommendation score.
  recommendationScoreDesc,

  /// Lowest detail level first (easiest entry point).
  detailLevelAsc,

  /// Highest detail level first (deepest content).
  detailLevelDesc,

  /// Alphabetical by title.
  titleAZ,

  /// Free courses first, then paid.
  freeFirst,
}

// ═══════════════════════════════════════════════════════════════════════════
// §4  COURSEFILTER — immutable multi-dimension filter specification
// ═══════════════════════════════════════════════════════════════════════════

/// Encapsulates every filter dimension in one value-class.
/// Pass to [coursesByFilter], [recommendByFilter], or any helper.
@immutable
class CourseFilter {
  final String category;
  final String provider;
  final CourseLevel? level;
  final CourseType? type;
  final ContentFormat? format;
  final ContentLength? length;
  final DetailLevel? detail;
  final LearningStrategy? strategy;
  final bool? isClassroomBased;
  final bool? isFree;
  final double minRating;
  final double minQualityScore;

  /// Course must cover at least one of these skills (case-insensitive).
  final List<String> anyOfSkills;

  /// Course must cover ALL of these skills (case-insensitive).
  final List<String> allOfSkills;

  const CourseFilter({
    this.category         = 'All',
    this.provider         = 'All',
    this.level,
    this.type,
    this.format,
    this.length,
    this.detail,
    this.strategy,
    this.isClassroomBased,
    this.isFree,
    this.minRating        = 0.0,
    this.minQualityScore  = 0.0,
    this.anyOfSkills      = const [],
    this.allOfSkills      = const [],
  });

  /// Returns `true` when [course] satisfies every active criterion.
  bool matches(Course course) {
    if (category != 'All' && course.category != category) return false;
    if (provider != 'All' && course.provider != provider) return false;
    if (level != null && course.courseLevelEnum != level) return false;
    if (type != null && course.courseTypeEnum != type) return false;
    if (format != null && course.contentFormat != format) return false;
    if (length != null && course.contentLength != length) return false;
    if (detail != null && course.detailLevel != detail) return false;
    if (strategy != null && course.learningStrategy != strategy) return false;
    if (isClassroomBased != null &&
        course.isClassroomBased != isClassroomBased) {
      return false;
    }
    if (isFree != null && course.isFree != isFree) return false;
    if (course.rating < minRating) return false;
    if (minQualityScore > 0.0 &&
        (course.qualityScore ?? 0.0) < minQualityScore) {
      return false;
    }

    if (anyOfSkills.isNotEmpty) {
      final lower = course.skills.map((s) => s.toLowerCase()).toSet();
      if (!anyOfSkills.any((s) => lower.contains(s.toLowerCase()))) {
        return false;
      }
    }

    if (allOfSkills.isNotEmpty) {
      final lower = course.skills.map((s) => s.toLowerCase()).toSet();
      if (!allOfSkills.every((s) => lower.contains(s.toLowerCase()))) {
        return false;
      }
    }

    return true;
  }

  /// Returns a new [CourseFilter] with selected fields replaced.
  CourseFilter copyWith({
    String? category,
    String? provider,
    Object? level             = _unset,
    Object? type              = _unset,
    Object? format            = _unset,
    Object? length            = _unset,
    Object? detail            = _unset,
    Object? strategy          = _unset,
    Object? isClassroomBased  = _unset,
    Object? isFree            = _unset,
    double? minRating,
    double? minQualityScore,
    List<String>? anyOfSkills,
    List<String>? allOfSkills,
  }) {
    return CourseFilter(
      category        : category        ?? this.category,
      provider        : provider        ?? this.provider,
      level           : level is _Unset
          ? this.level           : level as CourseLevel?,
      type            : type is _Unset
          ? this.type            : type as CourseType?,
      format          : format is _Unset
          ? this.format          : format as ContentFormat?,
      length          : length is _Unset
          ? this.length          : length as ContentLength?,
      detail          : detail is _Unset
          ? this.detail          : detail as DetailLevel?,
      strategy        : strategy is _Unset
          ? this.strategy        : strategy as LearningStrategy?,
      isClassroomBased: isClassroomBased is _Unset
          ? this.isClassroomBased : isClassroomBased as bool?,
      isFree          : isFree is _Unset
          ? this.isFree          : isFree as bool?,
      minRating       : minRating       ?? this.minRating,
      minQualityScore : minQualityScore ?? this.minQualityScore,
      anyOfSkills     : anyOfSkills     ?? this.anyOfSkills,
      allOfSkills     : allOfSkills     ?? this.allOfSkills,
    );
  }

  /// A permissive filter that matches every course.
  static const CourseFilter none = CourseFilter();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CourseFilter &&
        other.category        == category &&
        other.provider        == provider &&
        other.level           == level &&
        other.type            == type &&
        other.format          == format &&
        other.length          == length &&
        other.detail          == detail &&
        other.strategy        == strategy &&
        other.isClassroomBased == isClassroomBased &&
        other.isFree          == isFree &&
        other.minRating       == minRating &&
        other.minQualityScore == minQualityScore;
  }

  @override
  int get hashCode => Object.hash(
    category, provider, level, type, format,
    length, detail, strategy, isClassroomBased,
    isFree, minRating, minQualityScore,
  );

  @override
  String toString() =>
      'CourseFilter(category: $category, level: $level, format: $format, '
          'isFree: $isFree, minRating: $minRating)';
}

// ═══════════════════════════════════════════════════════════════════════════
// §5  COURSESTATS — aggregate analytics across a List<Course>
// ═══════════════════════════════════════════════════════════════════════════

/// Aggregate statistics computed across any [List<Course>].
class CourseStats {
  final int total;
  final int freeCount;
  final double meanRating;
  final double meanQualityScore;
  final Map<String, int> countByCategory;
  final Map<String, int> countByProvider;
  final Map<String, int> countByLevel;
  final Map<String, int> countByFormat;
  final Map<String, int> countByLength;
  final int classroomCount;
  final int highDetailCount;
  final List<String> topSkills;

  const CourseStats({
    required this.total,
    required this.freeCount,
    required this.meanRating,
    required this.meanQualityScore,
    required this.countByCategory,
    required this.countByProvider,
    required this.countByLevel,
    required this.countByFormat,
    required this.countByLength,
    required this.classroomCount,
    required this.highDetailCount,
    required this.topSkills,
  });

  factory CourseStats.fromCourses(List<Course> list) {
    if (list.isEmpty) {
      return const CourseStats(
        total: 0, freeCount: 0, meanRating: 0, meanQualityScore: 0,
        countByCategory: {}, countByProvider: {}, countByLevel: {},
        countByFormat: {}, countByLength: {}, classroomCount: 0,
        highDetailCount: 0, topSkills: [],
      );
    }

    double ratingSum  = 0;
    double qualitySum = 0;
    int qualityCount  = 0;
    final byCategory = <String, int>{};
    final byProvider = <String, int>{};
    final byLevel    = <String, int>{};
    final byFormat   = <String, int>{};
    final byLength   = <String, int>{};
    final skillFreq  = <String, int>{};

    for (final c in list) {
      ratingSum += c.rating;
      if (c.qualityScore != null) {
        qualitySum += c.qualityScore!;
        qualityCount++;
      }
      byCategory[c.category] = (byCategory[c.category] ?? 0) + 1;
      byProvider[c.provider] = (byProvider[c.provider] ?? 0) + 1;
      byLevel[c.level]       = (byLevel[c.level]       ?? 0) + 1;
      byFormat[c.contentFormat.displayName] =
          (byFormat[c.contentFormat.displayName] ?? 0) + 1;
      byLength[c.contentLength.displayName] =
          (byLength[c.contentLength.displayName] ?? 0) + 1;
      for (final s in c.skills) {
        final k = s.toLowerCase();
        skillFreq[k] = (skillFreq[k] ?? 0) + 1;
      }
    }

    final topSkills = (skillFreq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)))
        .take(10)
        .map((e) => e.key)
        .toList();

    return CourseStats(
      total            : list.length,
      freeCount        : list.where((c) => c.isFree).length,
      meanRating       : ratingSum / list.length,
      meanQualityScore : qualityCount > 0 ? qualitySum / qualityCount : 0.0,
      countByCategory  : Map.unmodifiable(byCategory),
      countByProvider  : Map.unmodifiable(byProvider),
      countByLevel     : Map.unmodifiable(byLevel),
      countByFormat    : Map.unmodifiable(byFormat),
      countByLength    : Map.unmodifiable(byLength),
      classroomCount   : list.where((c) => c.isClassroomBased).length,
      highDetailCount  : list.where((c) => c.detailLevel == DetailLevel.high).length,
      topSkills        : topSkills,
    );
  }

  double get freeRatio      => total > 0 ? freeCount      / total : 0.0;
  double get classroomRatio => total > 0 ? classroomCount / total : 0.0;

  String get dominantCategory =>
      countByCategory.isEmpty
          ? 'N/A'
          : (countByCategory.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)))
          .first.key;

  @override
  String toString() =>
      'CourseStats(total: $total, free: $freeCount, '
          'meanRating: ${meanRating.toStringAsFixed(2)}, '
          'dominantCategory: $dominantCategory)';
}

// ═══════════════════════════════════════════════════════════════════════════
// §6  COURSERECOMMENDATION — scored recommendation record
// ═══════════════════════════════════════════════════════════════════════════

/// Wraps a [Course] with its computed recommendation score and breakdown.
@immutable
class CourseRecommendation {
  final Course course;

  /// Composite score (dot product + overlap boost).
  final double score;

  /// Raw dot product between learner preference vector and course feature vector.
  final double dotProduct;

  /// Skill overlap boost component (0–0.5).
  final double skillBoost;

  const CourseRecommendation({
    required this.course,
    required this.score,
    required this.dotProduct,
    required this.skillBoost,
  });

  /// Percentage display: "84%".
  String get scorePercent => '${(score * 100).round()}%';

  /// True when score exceeds threshold for display-worthy recommendations.
  bool get isHighRelevance => score >= 0.5;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          (other is CourseRecommendation && other.course.id == course.id);

  @override
  int get hashCode => course.id.hashCode;

  @override
  String toString() =>
      'CourseRecommendation(course: "${course.title}", '
          'score: ${score.toStringAsFixed(3)})';
}

// ═══════════════════════════════════════════════════════════════════════════
// §7  LEARNERPROGRESSSNAPSHOT — per-course learner progress state
// ═══════════════════════════════════════════════════════════════════════════

/// Lightweight snapshot of a learner's progress in a single course.
@immutable
class LearnerProgressSnapshot {
  final int courseId;
  final String courseTitle;

  /// Completion ratio 0–1 (0 = not started, 1 = completed).
  final double completionRatio;

  /// True when the learner has passed the skill-assessment MCQs.
  final bool passedSkillAssessment;

  /// ISO-8601 timestamp of last interaction.
  final String? lastAccessedAt;

  const LearnerProgressSnapshot({
    required this.courseId,
    required this.courseTitle,
    required this.completionRatio,
    required this.passedSkillAssessment,
    this.lastAccessedAt,
  });

  /// Completion formatted as "73%".
  String get completionPercent => '${(completionRatio * 100).round()}%';

  /// "Not Started" | "In Progress" | "Completed".
  String get statusLabel {
    if (completionRatio <= 0.0) return 'Not Started';
    if (completionRatio >= 1.0) return 'Completed';
    return 'In Progress';
  }

  bool get isCompleted => completionRatio >= 1.0;
  bool get isStarted   => completionRatio > 0.0;

  /// Estimate remaining time in minutes given [totalEstimatedMinutes].
  int estimatedMinutesRemaining(int totalEstimatedMinutes) =>
      ((1.0 - completionRatio) * totalEstimatedMinutes).round();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          (other is LearnerProgressSnapshot && other.courseId == courseId);

  @override
  int get hashCode => courseId.hashCode;

  @override
  String toString() =>
      'LearnerProgressSnapshot(course: "$courseTitle", '
          'completion: $completionPercent, status: $statusLabel)';
}

// ═══════════════════════════════════════════════════════════════════════════
// §8  COURSE MODEL
// ═══════════════════════════════════════════════════════════════════════════

@immutable
class Course {
  // ── §8.1  Original fields (unchanged order & types) ────────────────────────

  final int id;
  final String title;
  final String provider;

  /// Beginner | Intermediate | Advanced
  final String level;

  /// Course | Bootcamp | Video | Certificate
  final String type;

  final String url;
  final String category;
  final String duration;
  final String language;

  /// User rating 0.0–5.0.
  /// [Tavakoli 2022 §3.4.1 — normalised rating signal]
  final double rating;

  final List<String> skills;
  final bool isFree;

  // ── §8.2  Session 1 fields (unchanged) ────────────────────────────────────

  /// [Tavakoli 2022 §3.3 — LDA topic extraction]
  final List<String> topics;

  /// [Tavakoli 2022 §3.4.2 — Three-stage quality filter] 0.0–1.0.
  final double? qualityScore;

  /// Legacy format string — superseded by [contentFormat] enum.
  final String contentTypeString;

  /// Legacy detail string — superseded by [detailLevel] enum.
  final String detailLevelString;

  /// Legacy length string — superseded by [contentLength] enum.
  final String lengthCategoryString;

  /// Legacy strategy string — superseded by [learningStrategy] enum.
  final String strategyString;

  /// Legacy classroom flag — superseded by [isClassroomBased].
  final bool isClassBased;

  /// Pre-computed 15-key feature vector (map form) — superseded by
  /// [toFeatureVector] / [computeFeatureVector].
  final Map<String, double> featureVector;

  /// [Tavakoli 2022 §3.4.4] MCQ question bank.
  final List<Map<String, dynamic>> mcqQuestions;

  /// [Tavakoli 2022 §3.4.1] Total views / enrolments.
  final int? viewCount;

  // ── §8.3  Session 2 typed enum fields (unchanged) ─────────────────────────

  /// [Tavakoli 2022 §3.4.3] Typed length enum.
  final ContentLength contentLength;

  /// [Tavakoli 2022 §3.4.3] Typed detail enum.
  final DetailLevel detailLevel;

  /// [Tavakoli 2022 §3.4.3] Typed strategy enum.
  final LearningStrategy learningStrategy;

  /// [Tavakoli 2022 §3.4.3] Classroom flag (typed alias for [isClassBased]).
  final bool isClassroomBased;

  /// [Tavakoli 2022 §3.4.1] Typed format enum.
  final ContentFormat contentFormat;

  /// [Tavakoli 2022 §3.3] Granular LDA topic list.
  final List<String> topicsCovert;

  /// Brief course summary shown in detail screen.
  final String? transcriptSummary;

  /// URL to course thumbnail image.
  final String? thumbnailUrl;

  // ── §8.4  Session 3 new fields ─────────────────────────────────────────────

  /// Pre-attached [CourseRecommendation] score — null until computed.
  final CourseRecommendation? recommendation;

  /// Pre-attached [LearnerProgressSnapshot] — null until populated.
  final LearnerProgressSnapshot? progress;

  // ── §8.5  Constructor ──────────────────────────────────────────────────────

  const Course({
    // Original required fields
    required this.id,
    required this.title,
    required this.provider,
    required this.level,
    required this.type,
    required this.url,
    required this.category,
    required this.duration,
    required this.language,
    required this.rating,
    required this.skills,
    this.isFree = false,

    // Session 1
    this.topics               = const [],
    this.qualityScore,
    this.contentTypeString    = 'video',
    this.detailLevelString    = 'medium',
    this.lengthCategoryString = 'medium',
    this.strategyString       = 'both',
    this.isClassBased         = false,
    this.featureVector        = const {},
    this.mcqQuestions         = const [],
    this.viewCount,

    // Session 2
    this.contentLength    = ContentLength.medium,
    this.detailLevel      = DetailLevel.medium,
    this.learningStrategy = LearningStrategy.both,
    this.isClassroomBased = false,
    this.contentFormat    = ContentFormat.video,
    this.topicsCovert     = const [],
    this.transcriptSummary,
    this.thumbnailUrl,

    // Session 3
    this.recommendation,
    this.progress,
  });

  // ═══════════════════════════════════════════════════════════════════════
  // §8.6  TYPED ENUM GETTERS — type-safe views on string fields
  // ═══════════════════════════════════════════════════════════════════════

  /// [CourseLevel] derived from the [level] string field.
  CourseLevel get courseLevelEnum => CourseLevel.fromString(level);

  /// [CourseType] derived from the [type] string field.
  CourseType get courseTypeEnum => CourseType.fromString(type);

  // ═══════════════════════════════════════════════════════════════════════
  // §8.7  FEATURE VECTOR METHODS [Tavakoli 2022 §3.5.2]
  // ═══════════════════════════════════════════════════════════════════════

  /// Returns a 15-dimensional one-hot feature vector as [List<double>].
  ///
  ///  Index  Key                  Dimension
  ///  0      length_short         ContentLength
  ///  1      length_medium
  ///  2      length_long
  ///  3      detail_low           DetailLevel
  ///  4      detail_medium
  ///  5      detail_high
  ///  6      strategy_theory      LearningStrategy
  ///  7      strategy_example
  ///  8      strategy_both
  ///  9      class_based          Classroom
  ///  10     non_class_based
  ///  11     format_video         ContentFormat  (keys match career_profile.dart)
  ///  12     format_book
  ///  13     format_web_page
  ///  14     format_slide
  List<double> toFeatureVector() {
    final v = List<double>.filled(15, 0.0);
    v[contentLength.vectorIndex]    = 1.0;
    v[detailLevel.vectorIndex]      = 1.0;
    v[learningStrategy.vectorIndex] = 1.0;
    v[isClassroomBased ? 9 : 10]    = 1.0;
    v[contentFormat.vectorIndex]    = 1.0;
    return v;
  }

  /// Map-based variant for backward compatibility with Session 1 dot-product code.
  Map<String, double> computeFeatureVector() {
    const keys = PreferenceKeys.all;
    final list = toFeatureVector();
    return {for (var i = 0; i < keys.length; i++) keys[i]: list[i]};
  }

  /// [Tavakoli 2022 §3.5.2] Dot product with a map-based preference vector.
  double dotProductWith(Map<String, double> prefVector) {
    if (prefVector.isEmpty) return 0.0;
    final vec = featureVector.isEmpty ? computeFeatureVector() : featureVector;
    return PreferenceKeys.all.fold(0.0, (sum, key) {
      return sum + (vec[key] ?? 0.0) * (prefVector[key] ?? 0.0);
    });
  }

  /// Dot product with a [List<double>] preference vector (15 elements).
  double dotProductWithList(List<double> prefVector) {
    assert(
    prefVector.length == 15,
    'prefVector must be 15-dimensional; got ${prefVector.length}',
    );
    final courseVec = toFeatureVector();
    double dot = 0.0;
    for (int i = 0; i < 15; i++) {
      dot += courseVec[i] * prefVector[i];
    }
    return dot;
  }

  /// Cosine similarity between this course's feature vector and [prefVector].
  /// Returns 0.0 when either vector is the zero vector.
  ///
  /// FIX: removed the redundant inner ternary — the outer `denom == 0.0`
  /// guard already ensures we only reach dartSqrt when denom > 0.
  double cosineSimilarity(List<double> prefVector) {
    assert(
    prefVector.length == 15,
    'prefVector must be 15-dimensional; got ${prefVector.length}',
    );
    final a = toFeatureVector();
    double dot   = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    for (int i = 0; i < 15; i++) {
      dot   += a[i] * prefVector[i];
      normA += a[i] * a[i];
      normB += prefVector[i] * prefVector[i];
    }
    final denom = normA * normB;
    return denom == 0.0 ? 0.0 : dot / dartSqrt(denom);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // §8.8  DURATION GETTERS
  // ═══════════════════════════════════════════════════════════════════════

  /// Human-readable condensed duration string.
  ///
  /// Examples:
  ///   "6 weeks"      → "6 wks"
  ///   "80 hours"     → "80 h"
  ///   "6 months"     → "6 mo"
  ///   "11 months"    → "11 mo"
  ///   "2 hours"      → "2 h"
  ///   "45 min"       → "45 min"
  ///   "Self-paced"   → "Self-paced"
  String get formattedDuration {
    final raw = duration.trim().toLowerCase();

    if (raw.contains('self') || raw.contains('paced')) return 'Self-paced';

    final weeksMatch  = RegExp(r'^(\d+)\s*week').firstMatch(raw);
    if (weeksMatch  != null) return '${weeksMatch.group(1)} wks';

    final monthsMatch = RegExp(r'^(\d+)\s*month').firstMatch(raw);
    if (monthsMatch != null) return '${monthsMatch.group(1)} mo';

    final hoursMatch  = RegExp(r'^(\d+)\s*h').firstMatch(raw);
    if (hoursMatch  != null) return '${hoursMatch.group(1)} h';

    final minsMatch   = RegExp(r'^(\d+)\s*min').firstMatch(raw);
    if (minsMatch   != null) return '${minsMatch.group(1)} min';

    return duration;
  }

  /// Estimated total hours as a double (best-effort parse; null on failure).
  double? get estimatedHours {
    final raw = duration.trim().toLowerCase();
    if (raw.contains('self') || raw.contains('paced')) return null;

    final weeks  = RegExp(r'^(\d+)\s*week').firstMatch(raw);
    if (weeks  != null) return double.tryParse(weeks.group(1)!)! * 5.0;

    final months = RegExp(r'^(\d+)\s*month').firstMatch(raw);
    if (months != null) return double.tryParse(months.group(1)!)! * 20.0;

    final hours  = RegExp(r'^(\d+(?:\.\d+)?)\s*h').firstMatch(raw);
    if (hours  != null) return double.tryParse(hours.group(1)!);

    final mins   = RegExp(r'^(\d+)\s*min').firstMatch(raw);
    if (mins   != null) {
      final m = double.tryParse(mins.group(1)!);
      return m != null ? m / 60.0 : null;
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // §8.9  QUALITY & RATING GETTERS [Tavakoli 2022 §3.4.2]
  // ═══════════════════════════════════════════════════════════════════════

  /// True when qualityScore is null or ≥ 0.5.
  bool get passesQualityFilter =>
      qualityScore == null || qualityScore! >= 0.5;

  bool get isHighQuality  => (qualityScore ?? 0.0) >= 0.85;
  bool get isTopRated     => rating >= 4.7;
  bool get hasThumbnail   => thumbnailUrl != null && thumbnailUrl!.isNotEmpty;
  bool get hasSummary     => transcriptSummary != null &&
      transcriptSummary!.isNotEmpty;

  /// Rating normalised to 0–1 (divides by 5).
  double get normalizedRating => (rating / 5.0).clamp(0.0, 1.0);

  /// Composite quality-and-rating score: 60 % quality + 40 % normalised rating.
  double get compositeScore =>
      ((qualityScore ?? 0.5) * 0.60 + normalizedRating * 0.40)
          .clamp(0.0, 1.0);

  /// Composite score as percentage string, e.g. "82%".
  String get compositeScorePercent => '${(compositeScore * 100).round()}%';

  // ═══════════════════════════════════════════════════════════════════════
  // §8.10  MCQ / ASSESSMENT GETTERS [Tavakoli 2022 §3.4.4]
  // ═══════════════════════════════════════════════════════════════════════

  /// Progress-gate MCQ questions (type == 'progress').
  List<Map<String, dynamic>> get progressQuestions =>
      mcqQuestions.where((q) => q['type'] == 'progress').toList();

  /// Skill-assessment MCQ questions (type == 'skill').
  List<Map<String, dynamic>> get skillQuestions =>
      mcqQuestions.where((q) => q['type'] == 'skill').toList();

  bool get hasMcqQuestions => mcqQuestions.isNotEmpty;

  // ═══════════════════════════════════════════════════════════════════════
  // §8.11  TOPIC & SKILL GETTERS
  // ═══════════════════════════════════════════════════════════════════════

  /// Combined topic list (coarse [topics] + granular [topicsCovert]).
  List<String> get allTopics => [...topics, ...topicsCovert];

  /// Total unique topic count across both lists.
  int get totalTopicCount => allTopics.toSet().length;

  /// True when [topic] appears in either topic list (case-insensitive).
  bool coversTopic(String topic) {
    final needle = topic.toLowerCase();
    return allTopics.any((t) => t.toLowerCase().contains(needle));
  }

  /// Skill overlap ratio against [missingSkills]. 0.0–1.0.
  double matchScore(List<String> missingSkills) {
    if (missingSkills.isEmpty) return 0.0;
    final lower   = missingSkills.map((s) => s.toLowerCase()).toSet();
    final matched =
        skills.where((s) => lower.contains(s.toLowerCase())).length;
    return (matched / missingSkills.length).clamp(0.0, 1.0);
  }

  /// True when this course covers at least one of [targetSkills].
  bool coversAnySkill(List<String> targetSkills) {
    final lower = skills.map((s) => s.toLowerCase()).toSet();
    return targetSkills.any((s) => lower.contains(s.toLowerCase()));
  }

  /// True when this course covers ALL of [targetSkills].
  bool coversAllSkills(List<String> targetSkills) {
    final lower = skills.map((s) => s.toLowerCase()).toSet();
    return targetSkills.every((s) => lower.contains(s.toLowerCase()));
  }

  // ═══════════════════════════════════════════════════════════════════════
  // §8.12  CLASSROOM & DELIVERY GETTERS
  // ═══════════════════════════════════════════════════════════════════════

  bool get isSelfPaced =>
      !isClassroomBased && duration.toLowerCase().contains('self');

  bool get isStructuredSchedule =>
      isClassroomBased || duration.toLowerCase().contains('week');

  bool get isCertificateLevel => courseTypeEnum.isCredential;

  // ═══════════════════════════════════════════════════════════════════════
  // §8.13  PROGRESS GETTERS (Session 3)
  // ═══════════════════════════════════════════════════════════════════════

  bool get hasProgress => progress != null;
  bool get isCompleted => progress?.isCompleted ?? false;
  bool get isStarted   => progress?.isStarted   ?? false;

  /// Progress percentage string (e.g. "73%"), or "Not Started".
  String get progressLabel => progress?.completionPercent ?? 'Not Started';

  // ═══════════════════════════════════════════════════════════════════════
  // §8.14  COMPOSITE CONVENIENCE PREDICATES
  // ═══════════════════════════════════════════════════════════════════════

  /// True when the course is free, high quality, and top-rated.
  bool get isPremiumFree => isFree && isHighQuality && isTopRated;

  /// True when the course targets beginners with ≤ medium detail.
  bool get isEntryFriendly =>
      courseLevelEnum == CourseLevel.beginner &&
          detailLevel.rank <= DetailLevel.medium.rank;

  // ═══════════════════════════════════════════════════════════════════════
  // §8.15  copyWith
  // ═══════════════════════════════════════════════════════════════════════

  /// Immutable update helper — covers every field.
  /// Nullable fields use [_Unset] sentinel; legacy boolean `clear*` flags
  /// are preserved for backward compatibility.
  Course copyWith({
    // Original
    int? id,
    String? title,
    String? provider,
    String? level,
    String? type,
    String? url,
    String? category,
    String? duration,
    String? language,
    double? rating,
    List<String>? skills,
    bool? isFree,

    // Session 1
    List<String>? topics,
    Object? qualityScore              = _unset,
    String? contentTypeString,
    String? detailLevelString,
    String? lengthCategoryString,
    String? strategyString,
    bool? isClassBased,
    Map<String, double>? featureVector,
    List<Map<String, dynamic>>? mcqQuestions,
    Object? viewCount                 = _unset,

    // Session 2
    ContentLength? contentLength,
    DetailLevel? detailLevel,
    LearningStrategy? learningStrategy,
    bool? isClassroomBased,
    ContentFormat? contentFormat,
    List<String>? topicsCovert,
    Object? transcriptSummary         = _unset,
    Object? thumbnailUrl              = _unset,

    // Session 3
    Object? recommendation            = _unset,
    Object? progress                  = _unset,

    // Legacy clear flags (backward compat)
    bool clearQualityScore      = false,
    bool clearViewCount         = false,
    bool clearTranscriptSummary = false,
    bool clearThumbnailUrl      = false,
  }) {
    return Course(
      id       : id       ?? this.id,
      title    : title    ?? this.title,
      provider : provider ?? this.provider,
      level    : level    ?? this.level,
      type     : type     ?? this.type,
      url      : url      ?? this.url,
      category : category ?? this.category,
      duration : duration ?? this.duration,
      language : language ?? this.language,
      rating   : rating   ?? this.rating,
      skills   : skills   ?? this.skills,
      isFree   : isFree   ?? this.isFree,

      topics              : topics              ?? this.topics,
      qualityScore        : clearQualityScore
          ? null
          : (qualityScore is _Unset
          ? this.qualityScore
          : qualityScore as double?),
      contentTypeString   : contentTypeString    ?? this.contentTypeString,
      detailLevelString   : detailLevelString    ?? this.detailLevelString,
      lengthCategoryString: lengthCategoryString ?? this.lengthCategoryString,
      strategyString      : strategyString       ?? this.strategyString,
      isClassBased        : isClassBased         ?? this.isClassBased,
      featureVector       : featureVector        ?? this.featureVector,
      mcqQuestions        : mcqQuestions         ?? this.mcqQuestions,
      viewCount           : clearViewCount
          ? null
          : (viewCount is _Unset ? this.viewCount : viewCount as int?),

      contentLength   : contentLength    ?? this.contentLength,
      detailLevel     : detailLevel      ?? this.detailLevel,
      learningStrategy: learningStrategy ?? this.learningStrategy,
      isClassroomBased: isClassroomBased ?? this.isClassroomBased,
      contentFormat   : contentFormat    ?? this.contentFormat,
      topicsCovert    : topicsCovert     ?? this.topicsCovert,
      transcriptSummary: clearTranscriptSummary
          ? null
          : (transcriptSummary is _Unset
          ? this.transcriptSummary
          : transcriptSummary as String?),
      thumbnailUrl    : clearThumbnailUrl
          ? null
          : (thumbnailUrl is _Unset
          ? this.thumbnailUrl
          : thumbnailUrl as String?),

      recommendation  : recommendation is _Unset
          ? this.recommendation
          : recommendation as CourseRecommendation?,
      progress        : progress is _Unset
          ? this.progress
          : progress as LearnerProgressSnapshot?,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // §8.16  SERIALISATION — toMap / fromMap
  // ═══════════════════════════════════════════════════════════════════════

  Map<String, dynamic> toMap() {
    return {
      // Original
      'id': id, 'title': title, 'provider': provider, 'level': level,
      'type': type, 'url': url, 'category': category, 'duration': duration,
      'language': language, 'rating': rating, 'skills': skills,
      'isFree': isFree,
      // Session 1
      'topics': topics, 'qualityScore': qualityScore,
      'contentTypeString': contentTypeString,
      'detailLevelString': detailLevelString,
      'lengthCategoryString': lengthCategoryString,
      'strategyString': strategyString,
      'isClassBased': isClassBased, 'featureVector': featureVector,
      'mcqQuestions': mcqQuestions, 'viewCount': viewCount,
      // Session 2
      'contentLength'    : contentLength.key,
      'detailLevel'      : detailLevel.key,
      'learningStrategy' : learningStrategy.key,
      'isClassroomBased' : isClassroomBased,
      'contentFormat'    : contentFormat.key,
      'topicsCovert'     : topicsCovert,
      'transcriptSummary': transcriptSummary,
      'thumbnailUrl'     : thumbnailUrl,
      // Session 3 — computed objects are NOT persisted (re-computed on load)
    };
  }

  factory Course.fromMap(Map<String, dynamic> map) {
    return Course(
      id      : (map['id']       as num?)?.toInt() ?? 0,
      title   : (map['title']    as String?) ?? '',
      provider: (map['provider'] as String?) ?? '',
      level   : (map['level']    as String?) ?? 'Beginner',
      type    : (map['type']     as String?) ?? 'Course',
      url     : (map['url']      as String?) ?? '',
      category: (map['category'] as String?) ?? '',
      duration: (map['duration'] as String?) ?? '',
      language: (map['language'] as String?) ?? 'English',
      rating  : (map['rating']   as num?)?.toDouble() ?? 0.0,
      skills  : _castStringList(map['skills']),
      isFree  : (map['isFree']   as bool?) ?? false,

      topics              : _castStringList(map['topics']),
      qualityScore        : (map['qualityScore']        as num?)?.toDouble(),
      contentTypeString   : (map['contentTypeString']    as String?) ?? 'video',
      detailLevelString   : (map['detailLevelString']    as String?) ?? 'medium',
      lengthCategoryString: (map['lengthCategoryString'] as String?) ?? 'medium',
      strategyString      : (map['strategyString']       as String?) ?? 'both',
      isClassBased        : (map['isClassBased']  as bool?) ?? false,
      // FIX: _parseDoubleMap now returns Map<String,double> (never null).
      featureVector       : _parseDoubleMap(map['featureVector']),
      mcqQuestions        : _parseMcqList(map['mcqQuestions']),
      viewCount           : (map['viewCount']     as num?)?.toInt(),

      contentLength   : ContentLengthExtension.fromKey(
          (map['contentLength']    as String?) ?? 'medium'),
      detailLevel     : DetailLevelExtension.fromKey(
          (map['detailLevel']      as String?) ?? 'medium'),
      learningStrategy: LearningStrategyExtension.fromKey(
          (map['learningStrategy'] as String?) ?? 'both'),
      isClassroomBased: (map['isClassroomBased'] as bool?) ?? false,
      contentFormat   : ContentFormatExtension.fromKey(
          (map['contentFormat']    as String?) ?? 'video'),
      topicsCovert    : _castStringList(map['topicsCovert']),
      transcriptSummary: map['transcriptSummary'] as String?,
      thumbnailUrl    : map['thumbnailUrl']       as String?,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // §8.17  EQUALITY, HASH, toString
  // ═══════════════════════════════════════════════════════════════════════

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          (other is Course && other.id == id && other.title == title);

  @override
  int get hashCode => Object.hash(id, title);

  @override
  String toString() =>
      'Course(id: $id, title: "$title", provider: "$provider", '
          'level: ${courseLevelEnum.displayName}, '
          'type: ${courseTypeEnum.displayName}, '
          'contentLength: ${contentLength.displayName}, '
          'detailLevel: ${detailLevel.displayName}, '
          'format: ${contentFormat.displayName}, '
          'rating: $rating, '
          'qualityScore: ${qualityScore?.toStringAsFixed(2) ?? "null"}, '
          'isFree: $isFree)';
}

// ═══════════════════════════════════════════════════════════════════════════
// §9  COURSE EXTENSIONS
// ═══════════════════════════════════════════════════════════════════════════

extension CourseComparison on Course {
  int compareRatingTo(Course other)   => other.rating.compareTo(rating);

  int compareQualityTo(Course other)  =>
      (other.qualityScore ?? 0.0).compareTo(qualityScore ?? 0.0);

  int compareViewCountTo(Course other) =>
      (other.viewCount ?? 0).compareTo(viewCount ?? 0);
}

extension CourseNullableHelpers on Course {
  String get qualityDisplay =>
      qualityScore != null ? '${(qualityScore! * 100).round()}%' : 'Unscored';

  String get viewCountDisplay =>
      viewCount != null ? _formatViewCount(viewCount!) : 'N/A';

  static String _formatViewCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(0)}K';
    return n.toString();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// §10  MATH HELPER (avoids dart:math import to keep file standalone)
// ═══════════════════════════════════════════════════════════════════════════

/// Newton-Raphson square root (keeps file standalone without dart:math).
/// Converges in ~20 iterations for all positive doubles.
double dartSqrt(double x) {
  if (x <= 0.0) return 0.0;
  double r = x;
  for (int i = 0; i < 20; i++) {
    r = (r + x / r) * 0.5;
  }
  return r;
}

// ═══════════════════════════════════════════════════════════════════════════
// §11  PRIVATE HELPERS
// ═══════════════════════════════════════════════════════════════════════════

List<String> _castStringList(dynamic raw) {
  if (raw == null) return const [];
  if (raw is List<String>) return raw;
  try {
    return (raw as List).map((e) => e.toString()).toList();
  } catch (_) {
    return const [];
  }
}

/// FIX: return type changed from [Map<String,double>?] to [Map<String,double>].
/// Returns a new growable empty map on failure instead of null, eliminating
/// the `?? const {}` (unmodifiable map) pattern at every call site.
Map<String, double> _parseDoubleMap(dynamic raw) {
  if (raw == null) return {};
  if (raw is Map<String, double>) return Map<String, double>.from(raw);
  try {
    return Map<String, double>.fromEntries(
      (raw as Map).entries.map(
            (e) => MapEntry(e.key.toString(), (e.value as num).toDouble()),
      ),
    );
  } catch (_) {
    return {};
  }
}

List<Map<String, dynamic>> _parseMcqList(dynamic raw) {
  if (raw == null) return const [];
  try {
    return (raw as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  } catch (_) {
    return const [];
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// §12  COURSE DATA (36 courses — all fields verified)
// ═══════════════════════════════════════════════════════════════════════════

final List<Course> courses = [

  // ════════════ SOFTWARE / DATA SCIENCE ═══════════════════════════════════

  const Course(
    id: 1, title: 'Python for Data Analysis', provider: 'Coursera',
    level: 'Beginner', type: 'Course',
    url: 'https://www.coursera.org/learn/python-data-analysis',
    category: 'Data Science', duration: '6 weeks', language: 'English',
    rating: 4.7, isFree: false,
    skills: ['python', 'data analysis', 'pandas', 'numpy', 'matplotlib', 'reporting'],
    topics: ['python basics', 'data wrangling', 'pandas dataframes',
      'numpy arrays', 'data visualisation', 'reporting'],
    qualityScore: 0.88, contentTypeString: 'video', detailLevelString: 'high',
    lengthCategoryString: 'long', strategyString: 'both', isClassBased: false,
    viewCount: 450000,
    contentLength: ContentLength.long, detailLevel: DetailLevel.high,
    learningStrategy: LearningStrategy.both, isClassroomBased: false,
    contentFormat: ContentFormat.video,
    topicsCovert: ['variables', 'lists', 'dicts', 'dataframe operations',
      'groupby', 'matplotlib basics', 'seaborn charts'],
    transcriptSummary:
    'A practical 6-week MOOC covering Python, pandas, and numpy for '
        'end-to-end data analysis with real-world datasets.',
    thumbnailUrl: 'https://img-c.udemycdn.com/course/480x270/python-data-analysis.jpg',
  ),

  const Course(
    id: 2, title: 'SQL for Data Science', provider: 'edX',
    level: 'Beginner', type: 'Course',
    url: 'https://www.edx.org/learn/sql',
    category: 'Data Science', duration: '4 weeks', language: 'English',
    rating: 4.6, isFree: false,
    skills: ['sql', 'database', 'data analysis', 'joins', 'aggregation', 'reporting'],
    topics: ['sql syntax', 'joins', 'aggregation', 'subqueries',
      'database design', 'reporting'],
    qualityScore: 0.85, contentTypeString: 'video', detailLevelString: 'medium',
    lengthCategoryString: 'medium', strategyString: 'both', isClassBased: false,
    viewCount: 320000,
    contentLength: ContentLength.medium, detailLevel: DetailLevel.medium,
    learningStrategy: LearningStrategy.both, isClassroomBased: false,
    contentFormat: ContentFormat.video,
    topicsCovert: ['select', 'where', 'inner join', 'left join',
      'group by', 'having', 'window functions', 'cte'],
    transcriptSummary:
    'Four-week SQL course covering querying, joins, aggregation, and '
        'subqueries using real datasets.',
  ),

  const Course(
    id: 3, title: 'Java Programming Masterclass', provider: 'Udemy',
    level: 'Beginner', type: 'Course',
    url: 'https://www.udemy.com/course/java-the-complete-java-developer-course',
    category: 'Software Development', duration: '80 hours', language: 'English',
    rating: 4.7, isFree: false,
    skills: ['java', 'oop', 'data structures', 'algorithms', 'spring', 'git'],
    topics: ['java fundamentals', 'oop principles', 'collections',
      'generics', 'spring framework', 'git basics'],
    qualityScore: 0.87, contentTypeString: 'video', detailLevelString: 'high',
    lengthCategoryString: 'long', strategyString: 'both', isClassBased: false,
    viewCount: 670000,
    contentLength: ContentLength.long, detailLevel: DetailLevel.high,
    learningStrategy: LearningStrategy.both, isClassroomBased: false,
    contentFormat: ContentFormat.video,
    topicsCovert: ['data types', 'control flow', 'inheritance',
      'interfaces', 'generics', 'streams', 'spring boot', 'junit'],
    transcriptSummary:
    'Comprehensive 80-hour Java course from syntax basics through '
        'Spring framework, suitable for beginners to intermediate learners.',
  ),

  const Course(
    id: 4, title: 'Machine Learning A-Z', provider: 'Udemy',
    level: 'Intermediate', type: 'Course',
    url: 'https://www.udemy.com/course/machinelearning',
    category: 'Data Science', duration: '40 hours', language: 'English',
    rating: 4.6, isFree: false,
    skills: ['python', 'machine learning', 'scikit-learn', 'pandas',
      'regression', 'classification'],
    topics: ['linear regression', 'logistic regression', 'decision trees',
      'random forests', 'clustering', 'neural networks intro'],
    qualityScore: 0.86, contentTypeString: 'video', detailLevelString: 'high',
    lengthCategoryString: 'long', strategyString: 'both', isClassBased: false,
    viewCount: 890000,
    contentLength: ContentLength.long, detailLevel: DetailLevel.high,
    learningStrategy: LearningStrategy.both, isClassroomBased: false,
    contentFormat: ContentFormat.video,
    topicsCovert: ['train/test split', 'overfitting', 'cross-validation',
      'feature engineering', 'pca', 'k-means', 'svm', 'xgboost'],
    transcriptSummary:
    'Hands-on 40-hour ML course covering supervised and unsupervised '
        'algorithms with Python and scikit-learn.',
  ),

  const Course(
    id: 5, title: 'React \u2013 The Complete Guide', provider: 'Udemy',
    level: 'Intermediate', type: 'Course',
    url: 'https://www.udemy.com/course/react-the-complete-guide-incl-redux',
    category: 'Web Development', duration: '48 hours', language: 'English',
    rating: 4.7, isFree: false,
    skills: ['react', 'javascript', 'html', 'css', 'api integration',
      'responsive design'],
    topics: ['jsx', 'components', 'hooks', 'context api', 'redux',
      'routing', 'api calls'],
    qualityScore: 0.87, contentTypeString: 'video', detailLevelString: 'high',
    lengthCategoryString: 'long', strategyString: 'both', isClassBased: false,
    viewCount: 750000,
    contentLength: ContentLength.long, detailLevel: DetailLevel.high,
    learningStrategy: LearningStrategy.both, isClassroomBased: false,
    contentFormat: ContentFormat.video,
    topicsCovert: ['jsx syntax', 'functional components', 'usestate',
      'useeffect', 'usecontext', 'react router', 'redux toolkit', 'fetch api'],
    transcriptSummary:
    'Complete React course covering hooks, Redux, routing, and API '
        'integration for building modern SPAs.',
  ),

  const Course(
    id: 6, title: 'AWS Cloud Practitioner Essentials', provider: 'AWS',
    level: 'Beginner', type: 'Certificate',
    url: 'https://aws.amazon.com/training/learn-about/cloud-practitioner',
    category: 'Cloud Computing', duration: '8 hours', language: 'English',
    rating: 4.8, isFree: false,
    skills: ['aws', 'cloud computing', 'ec2', 's3', 'iam', 'cloud architecture'],
    topics: ['cloud concepts', 'ec2', 's3 storage', 'iam', 'pricing',
      'cloud architecture'],
    qualityScore: 0.92, contentTypeString: 'video', detailLevelString: 'medium',
    lengthCategoryString: 'short', strategyString: 'theory', isClassBased: false,
    viewCount: 510000,
    contentLength: ContentLength.short, detailLevel: DetailLevel.medium,
    learningStrategy: LearningStrategy.theoryOnly, isClassroomBased: false,
    contentFormat: ContentFormat.video,
    topicsCovert: ['regions and azs', 'ec2 types', 's3 buckets',
      'iam policies', 'vpc basics', 'billing dashboard',
      'well-architected framework'],
    transcriptSummary:
    'Official AWS 8-hour certification prep covering core cloud services, '
        'architecture, security, and pricing.',
    thumbnailUrl:
    'https://d1.awsstatic.com/logos/aws-logo-lockups/poweredbyaws/PB_AWS_logo_RGB_stacked.png',
  ),

  const Course(
    id: 7, title: 'Web Development Bootcamp', provider: 'freeCodeCamp',
    level: 'Beginner', type: 'Bootcamp',
    url: 'https://www.freecodecamp.org',
    category: 'Web Development', duration: '300 hours', language: 'English',
    rating: 4.8, isFree: true,
    skills: ['html', 'css', 'javascript', 'responsive design', 'bootstrap', 'git'],
    topics: ['html structure', 'css styling', 'flexbox', 'grid',
      'javascript dom', 'responsive design', 'accessibility'],
    qualityScore: 0.90, contentTypeString: 'webpage', detailLevelString: 'high',
    lengthCategoryString: 'long', strategyString: 'both', isClassBased: false,
    viewCount: 2000000,
    contentLength: ContentLength.long, detailLevel: DetailLevel.high,
    learningStrategy: LearningStrategy.both, isClassroomBased: false,
    contentFormat: ContentFormat.webPage,
    topicsCovert: ['semantic html', 'css box model', 'flexbox',
      'css grid', 'dom manipulation', 'es6', 'fetch api', 'bootstrap 5'],
    transcriptSummary:
    'Free self-paced interactive curriculum covering full front-end stack '
        'from HTML basics through JavaScript and responsive design.',
  ),

  const Course(
    id: 8, title: 'Git & GitHub Essentials', provider: 'YouTube',
    level: 'Beginner', type: 'Video',
    url: 'https://www.youtube.com/watch?v=RGOj5yH7evk',
    category: 'Version Control', duration: '2 hours', language: 'English',
    rating: 4.4, isFree: true,
    skills: ['git', 'github', 'version control', 'branching', 'commits'],
    topics: ['git init', 'commits', 'branching', 'merging', 'pull requests'],
    qualityScore: 0.72, contentTypeString: 'video', detailLevelString: 'low',
    lengthCategoryString: 'short', strategyString: 'example', isClassBased: false,
    viewCount: 3800000,
    contentLength: ContentLength.short, detailLevel: DetailLevel.low,
    learningStrategy: LearningStrategy.exampleOnly, isClassroomBased: false,
    contentFormat: ContentFormat.video,
    topicsCovert: ['git init', 'git add', 'git commit', 'git push',
      'branches', 'merge conflicts', 'pull requests', 'forks'],
    transcriptSummary:
    'Two-hour YouTube walkthrough of Git and GitHub fundamentals — ideal '
        'as a quick onboarding reference.',
  ),

  const Course(
    id: 9, title: 'Advanced Python Programming', provider: 'Udemy',
    level: 'Intermediate', type: 'Course',
    url: 'https://www.udemy.com/course/advanced-python',
    category: 'Programming', duration: '15 hours', language: 'English',
    rating: 4.7, isFree: false,
    skills: ['python', 'oop', 'decorators', 'generators', 'asyncio', 'testing'],
    topics: ['decorators', 'context managers', 'generators',
      'async/await', 'metaclasses', 'unit testing'],
    qualityScore: 0.85, contentTypeString: 'video', detailLevelString: 'high',
    lengthCategoryString: 'medium', strategyString: 'both', isClassBased: false,
    viewCount: 290000,
    contentLength: ContentLength.medium, detailLevel: DetailLevel.high,
    learningStrategy: LearningStrategy.both, isClassroomBased: false,
    contentFormat: ContentFormat.video,
    topicsCovert: ['closures', 'decorators', 'generators', 'coroutines',
      'asyncio event loop', 'dataclasses', 'typing module', 'pytest'],
    transcriptSummary:
    'Deep-dive into advanced Python features — decorators, async, '
        'metaclasses, and production testing patterns.',
  ),

  const Course(
    id: 10, title: 'Flutter & Dart \u2013 The Complete Guide', provider: 'Udemy',
    level: 'Beginner', type: 'Course',
    url: 'https://www.udemy.com/course/learn-flutter-dart-to-build-ios-android-apps',
    category: 'Mobile Development', duration: '42 hours', language: 'English',
    rating: 4.6, isFree: false,
    skills: ['dart', 'flutter', 'firebase', 'rest api', 'state management',
      'ui', 'widgets'],
    topics: ['dart basics', 'widgets', 'state management',
      'navigation', 'firebase', 'rest api', 'animations'],
    qualityScore: 0.86, contentTypeString: 'video', detailLevelString: 'high',
    lengthCategoryString: 'long', strategyString: 'both', isClassBased: false,
    viewCount: 310000,
    contentLength: ContentLength.long, detailLevel: DetailLevel.high,
    learningStrategy: LearningStrategy.both, isClassroomBased: false,
    contentFormat: ContentFormat.video,
    topicsCovert: ['dart null safety', 'stateful widgets', 'provider',
      'riverpod', 'firebase auth', 'firestore', 'http package', 'animations'],
    transcriptSummary:
    'Comprehensive Flutter and Dart course building real mobile apps '
        'with Firebase, REST APIs, and advanced state management.',
  ),

  const Course(
    id: 11, title: 'C++ Programming: From Beginner to Expert', provider: 'Udemy',
    level: 'Beginner', type: 'Course',
    url: 'https://www.udemy.com/course/cpp-programming',
    category: 'Software Development', duration: '45 hours', language: 'English',
    rating: 4.5, isFree: false,
    skills: ['c++', 'oop', 'memory management', 'algorithms', 'problem solving'],
    topics: ['c++ syntax', 'pointers', 'oop', 'templates',
      'stl', 'memory management', 'algorithms'],
    qualityScore: 0.82, contentTypeString: 'video', detailLevelString: 'high',
    lengthCategoryString: 'long', strategyString: 'both', isClassBased: false,
    viewCount: 200000,
    contentLength: ContentLength.long, detailLevel: DetailLevel.high,
    learningStrategy: LearningStrategy.both, isClassroomBased: false,
    contentFormat: ContentFormat.video,
    topicsCovert: ['pointers', 'references', 'vtables', 'raii',
      'smart pointers', 'stl containers', 'move semantics', 'templates'],
    transcriptSummary:
    '45-hour C++ course covering fundamentals through advanced memory '
        'management, STL, and modern C++17 features.',
  ),

  // ════════════ FINANCE ════════════════════════════════════════════════════

  const Course(
    id: 12, title: 'Microsoft Excel \u2013 Beginner to Advanced', provider: 'Udemy',
    level: 'Beginner', type: 'Course',
    url: 'https://www.udemy.com/course/microsoft-excel-2013-from-beginner-to-advanced-and-beyond',
    category: 'Finance', duration: '18 hours', language: 'English',
    rating: 4.7, isFree: false,
    skills: ['excel', 'financial modeling', 'data analysis', 'reporting',
      'pivot tables'],
    topics: ['spreadsheet basics', 'formulas', 'pivot tables',
      'vlookup', 'financial functions', 'charts', 'macros'],
    qualityScore: 0.87, contentTypeString: 'video', detailLevelString: 'high',
    lengthCategoryString: 'medium', strategyString: 'example',
    isClassBased: false, viewCount: 580000,
    contentLength: ContentLength.medium, detailLevel: DetailLevel.high,
    learningStrategy: LearningStrategy.exampleOnly, isClassroomBased: false,
    contentFormat: ContentFormat.video,
    topicsCovert: ['cell references', 'if/nested if', 'vlookup', 'xlookup',
      'pivot tables', 'power query', 'vba macros', 'financial functions'],
    transcriptSummary:
    '18-hour Excel course from basic spreadsheets through advanced pivot '
        'tables, financial functions, and VBA automation.',
  ),

  const Course(
    id: 13, title: 'Financial Modeling & Valuation (FMVA)',
    provider: 'Corporate Finance Institute',
    level: 'Intermediate', type: 'Certificate',
    url: 'https://corporatefinanceinstitute.com/certifications/fmva',
    category: 'Finance', duration: '120 hours', language: 'English',
    rating: 4.8, isFree: false,
    skills: ['financial modeling', 'excel', 'valuation', 'risk analysis',
      'reporting', 'accounting'],
    topics: ['dcf valuation', 'comparable analysis', '3-statement model',
      'lbo modeling', 'sensitivity analysis', 'scenario analysis'],
    qualityScore: 0.92, contentTypeString: 'video', detailLevelString: 'high',
    lengthCategoryString: 'long', strategyString: 'both', isClassBased: false,
    viewCount: 220000,
    contentLength: ContentLength.long, detailLevel: DetailLevel.high,
    learningStrategy: LearningStrategy.both, isClassroomBased: false,
    contentFormat: ContentFormat.video,
    topicsCovert: ['income statement', 'balance sheet', 'cash flow statement',
      'dcf model', 'wacc', 'terminal value', 'lbo model',
      'precedent transactions'],
    transcriptSummary:
    'Industry-standard 120-hour FMVA certification covering all core '
        'financial modeling and valuation methodologies.',
  ),

  const Course(
    id: 14, title: 'Risk Management Professional Certificate', provider: 'edX',
    level: 'Intermediate', type: 'Certificate',
    url: 'https://www.edx.org/professional-certificate/risk-management',
    category: 'Finance', duration: '16 weeks', language: 'English',
    rating: 4.6, isFree: false,
    skills: ['risk analysis', 'financial modeling', 'excel', 'statistics',
      'sql', 'reporting'],
    topics: ['risk identification', 'quantitative risk', 'credit risk',
      'market risk', 'operational risk', 'risk reporting'],
    qualityScore: 0.88, contentTypeString: 'video', detailLevelString: 'high',
    lengthCategoryString: 'long', strategyString: 'theory', isClassBased: true,
    viewCount: 180000,
    contentLength: ContentLength.long, detailLevel: DetailLevel.high,
    learningStrategy: LearningStrategy.theoryOnly, isClassroomBased: true,
    contentFormat: ContentFormat.video,
    topicsCovert: ['var calculation', 'credit scoring', 'stress testing',
      'basel framework', 'operational risk matrix', 'risk dashboards'],
    transcriptSummary:
    'University-style 16-week professional certificate covering quantitative '
        'and qualitative risk management frameworks.',
  ),

  const Course(
    id: 15, title: 'Python for Finance', provider: 'Udemy',
    level: 'Intermediate', type: 'Course',
    url: 'https://www.udemy.com/course/python-for-finance-investment-fundamentals',
    category: 'Finance', duration: '10 hours', language: 'English',
    rating: 4.5, isFree: false,
    skills: ['python', 'financial modeling', 'data analysis', 'pandas',
      'statistics', 'risk analysis'],
    topics: ['python finance libraries', 'time series',
      'portfolio optimisation', 'monte carlo', 'risk metrics'],
    qualityScore: 0.82, contentTypeString: 'video', detailLevelString: 'medium',
    lengthCategoryString: 'short', strategyString: 'example', isClassBased: false,
    viewCount: 145000,
    contentLength: ContentLength.short, detailLevel: DetailLevel.medium,
    learningStrategy: LearningStrategy.exampleOnly, isClassroomBased: false,
    contentFormat: ContentFormat.video,
    topicsCovert: ['yfinance', 'pandas datareader', 'portfolio returns',
      'sharpe ratio', 'monte carlo simulation', 'capm', 'markowitz'],
    transcriptSummary:
    'Practical 10-hour course applying Python to portfolio analysis, '
        'Monte Carlo simulation, and financial risk metrics.',
  ),

  // ════════════ HEALTHCARE ═════════════════════════════════════════════════

  const Course(
    id: 16, title: 'Patient Care & Clinical Fundamentals', provider: 'Coursera',
    level: 'Beginner', type: 'Course',
    url: 'https://www.coursera.org/learn/patient-care',
    category: 'Healthcare', duration: '6 weeks', language: 'English',
    rating: 4.6, isFree: false,
    skills: ['patient care', 'nursing', 'communication skills',
      'medical research', 'clinical documentation'],
    topics: ['patient assessment', 'vital signs', 'clinical communication',
      'documentation', 'infection control', 'nursing ethics'],
    qualityScore: 0.86, contentTypeString: 'video', detailLevelString: 'medium',
    lengthCategoryString: 'long', strategyString: 'both', isClassBased: true,
    viewCount: 270000,
    contentLength: ContentLength.long, detailLevel: DetailLevel.medium,
    learningStrategy: LearningStrategy.both, isClassroomBased: true,
    contentFormat: ContentFormat.video,
    topicsCovert: ['admission assessment', 'glasgow scale', 'handover protocol',
      'soap notes', 'hand hygiene', 'ppe', 'medication administration'],
    transcriptSummary:
    'Six-week clinical nursing fundamentals course covering patient '
        'assessment, documentation, and safe care practices.',
  ),

  const Course(
    id: 17, title: 'Pharmacology Essentials', provider: 'edX',
    level: 'Beginner', type: 'Course',
    url: 'https://www.edx.org/learn/pharmacology',
    category: 'Healthcare', duration: '8 weeks', language: 'English',
    rating: 4.5, isFree: false,
    skills: ['pharmaceuticals', 'medical research', 'patient care',
      'clinical documentation'],
    topics: ['drug classes', 'pharmacokinetics', 'pharmacodynamics',
      'adverse effects', 'clinical trials', 'drug safety'],
    qualityScore: 0.84, contentTypeString: 'video', detailLevelString: 'medium',
    lengthCategoryString: 'long', strategyString: 'theory', isClassBased: true,
    viewCount: 160000,
    contentLength: ContentLength.long, detailLevel: DetailLevel.medium,
    learningStrategy: LearningStrategy.theoryOnly, isClassroomBased: true,
    contentFormat: ContentFormat.video,
    topicsCovert: ['absorption', 'distribution', 'metabolism', 'excretion',
      'receptor binding', 'adrs', 'drug interactions', 'clinical trials phases'],
    transcriptSummary:
    'Eight-week pharmacology course covering drug mechanisms, clinical '
        'trials, and adverse event assessment.',
  ),

  const Course(
    id: 18, title: 'Healthcare Data Analytics', provider: 'Coursera',
    level: 'Intermediate', type: 'Course',
    url: 'https://www.coursera.org/learn/healthcare-data-analytics',
    category: 'Healthcare', duration: '8 weeks', language: 'English',
    rating: 4.7, isFree: false,
    skills: ['data analysis', 'sql', 'excel', 'medical research',
      'reporting', 'python'],
    topics: ['health data types', 'ehr systems', 'sql for health data',
      'predictive analytics', 'data visualisation', 'quality metrics'],
    qualityScore: 0.88, contentTypeString: 'video', detailLevelString: 'high',
    lengthCategoryString: 'long', strategyString: 'both', isClassBased: false,
    viewCount: 210000,
    contentLength: ContentLength.long, detailLevel: DetailLevel.high,
    learningStrategy: LearningStrategy.both, isClassroomBased: false,
    contentFormat: ContentFormat.video,
    topicsCovert: ['hl7 fhir', 'ehr data structures', 'icd codes',
      'survival analysis', 'cohort studies', 'tableau for health', 'hipaa'],
    transcriptSummary:
    'Eight-week course applying SQL, Python, and analytics to electronic '
        'health records and clinical quality improvement.',
  ),

  // ════════════ MARKETING ══════════════════════════════════════════════════

  const Course(
    id: 19,
    title: 'Google Digital Marketing & E-commerce Certificate',
    provider: 'Google',
    level: 'Beginner', type: 'Certificate',
    url: 'https://grow.google/certificates/digital-marketing-ecommerce',
    category: 'Marketing', duration: '6 months', language: 'English',
    rating: 4.8, isFree: false,
    skills: ['seo', 'google ads', 'analytics', 'social media',
      'content writing', 'email marketing'],
    topics: ['seo fundamentals', 'google ads', 'social media strategy',
      'email marketing', 'analytics', 'e-commerce basics'],
    qualityScore: 0.93, contentTypeString: 'video', detailLevelString: 'medium',
    lengthCategoryString: 'long', strategyString: 'both', isClassBased: false,
    viewCount: 920000,
    contentLength: ContentLength.long, detailLevel: DetailLevel.medium,
    learningStrategy: LearningStrategy.both, isClassroomBased: false,
    contentFormat: ContentFormat.video,
    topicsCovert: ['keyword research', 'on-page seo', 'google ads campaign',
      'search console', 'ga4 events', 'email funnels', 'shopify basics'],
    transcriptSummary:
    'Official Google 6-month certificate programme covering search, '
        'social, email marketing, and e-commerce fundamentals.',
    thumbnailUrl: 'https://grow.google/certificates/images/digital-marketing.png',
  ),

  const Course(
    id: 20, title: 'Market Research & Consumer Behaviour', provider: 'Coursera',
    level: 'Beginner', type: 'Course',
    url: 'https://www.coursera.org/learn/market-research',
    category: 'Marketing', duration: '5 weeks', language: 'English',
    rating: 4.4, isFree: false,
    skills: ['market research', 'data analysis', 'reporting', 'seo',
      'communication skills'],
    topics: ['primary research', 'secondary research', 'surveys',
      'focus groups', 'consumer psychology', 'competitive analysis'],
    qualityScore: 0.80, contentTypeString: 'video', detailLevelString: 'medium',
    lengthCategoryString: 'medium', strategyString: 'theory',
    isClassBased: false, viewCount: 140000,
    contentLength: ContentLength.medium, detailLevel: DetailLevel.medium,
    learningStrategy: LearningStrategy.theoryOnly, isClassroomBased: false,
    contentFormat: ContentFormat.video,
    topicsCovert: ['research design', 'survey construction', 'sampling',
      'focus group facilitation', 'conjoint analysis', 'perceptual mapping'],
    transcriptSummary:
    'Five-week course on research design, consumer psychology, and '
        'competitive analysis methodologies.',
  ),

  const Course(
    id: 21, title: 'Social Media Marketing Masterclass', provider: 'Udemy',
    level: 'Beginner', type: 'Course',
    url: 'https://www.udemy.com/course/social-media-marketing-masterclass',
    category: 'Marketing', duration: '14 hours', language: 'English',
    rating: 4.6, isFree: false,
    skills: ['social media', 'content writing', 'google ads', 'copywriting',
      'analytics', 'seo'],
    topics: ['instagram marketing', 'facebook ads', 'tiktok strategy',
      'content calendar', 'analytics', 'influencer outreach'],
    qualityScore: 0.82, contentTypeString: 'video', detailLevelString: 'medium',
    lengthCategoryString: 'medium', strategyString: 'example',
    isClassBased: false, viewCount: 380000,
    contentLength: ContentLength.medium, detailLevel: DetailLevel.medium,
    learningStrategy: LearningStrategy.exampleOnly, isClassroomBased: false,
    contentFormat: ContentFormat.video,
    topicsCovert: ['instagram reels', 'facebook pixel', 'tiktok ads',
      'content scheduling', 'meta ads manager', 'hashtag strategy',
      'social analytics'],
    transcriptSummary:
    '14-hour social media masterclass with hands-on platform walkthroughs '
        'for Instagram, Facebook, and TikTok.',
  ),

  const Course(
    id: 22, title: 'UX Design Professional Certificate', provider: 'Google',
    level: 'Beginner', type: 'Certificate',
    url: 'https://grow.google/certificates/ux-design',
    category: 'Design', duration: '6 months', language: 'English',
    rating: 4.8, isFree: false,
    skills: ['ux design', 'figma', 'user research', 'prototyping',
      'wireframing', 'communication skills'],
    topics: ['design thinking', 'user research', 'wireframing',
      'prototyping in figma', 'usability testing', 'design systems'],
    qualityScore: 0.93, contentTypeString: 'video', detailLevelString: 'high',
    lengthCategoryString: 'long', strategyString: 'both', isClassBased: false,
    viewCount: 840000,
    contentLength: ContentLength.long, detailLevel: DetailLevel.high,
    learningStrategy: LearningStrategy.both, isClassroomBased: false,
    contentFormat: ContentFormat.video,
    topicsCovert: ['empathy mapping', 'personas', 'user journeys',
      'low-fi wireframes', 'high-fi prototypes', 'usability testing scripts',
      'design handoff', 'design systems'],
    transcriptSummary:
    'Official Google 6-month UX certificate covering the full design '
        'process from user research through Figma prototyping and testing.',
    thumbnailUrl: 'https://grow.google/certificates/images/ux-design.png',
  ),

  // ════════════ MANUFACTURING ══════════════════════════════════════════════

  const Course(
    id: 23, title: 'Supply Chain Management Fundamentals', provider: 'Coursera',
    level: 'Beginner', type: 'Course',
    url: 'https://www.coursera.org/learn/supply-chain-management-a-learning-perspective',
    category: 'Manufacturing', duration: '8 weeks', language: 'English',
    rating: 4.6, isFree: false,
    skills: ['supply chain', 'logistics', 'inventory management',
      'communication skills', 'reporting'],
    topics: ['supply chain basics', 'procurement', 'logistics',
      'inventory control', 'demand forecasting', 'supplier relations'],
    qualityScore: 0.85, contentTypeString: 'video', detailLevelString: 'medium',
    lengthCategoryString: 'long', strategyString: 'theory', isClassBased: true,
    viewCount: 190000,
    contentLength: ContentLength.long, detailLevel: DetailLevel.medium,
    learningStrategy: LearningStrategy.theoryOnly, isClassroomBased: true,
    contentFormat: ContentFormat.video,
    topicsCovert: ['bull-whip effect', 'eoq model', 'jit', 'safety stock',
      'rfq process', 'incoterms', 'supplier scorecards'],
    transcriptSummary:
    'Eight-week university-level supply chain course covering procurement, '
        'inventory, and logistics frameworks.',
  ),

  const Course(
    id: 24, title: 'Quality Management & Six Sigma', provider: 'edX',
    level: 'Intermediate', type: 'Course',
    url: 'https://www.edx.org/learn/quality-management',
    category: 'Manufacturing', duration: '10 weeks', language: 'English',
    rating: 4.5, isFree: false,
    skills: ['quality control', 'production planning', 'supply chain',
      'reporting', 'inspection'],
    topics: ['six sigma dmaic', 'control charts', 'root cause analysis',
      'process capability', 'lean manufacturing', 'kaizen'],
    qualityScore: 0.84, contentTypeString: 'video', detailLevelString: 'high',
    lengthCategoryString: 'long', strategyString: 'both', isClassBased: true,
    viewCount: 120000,
    contentLength: ContentLength.long, detailLevel: DetailLevel.high,
    learningStrategy: LearningStrategy.both, isClassroomBased: true,
    contentFormat: ContentFormat.video,
    topicsCovert: ['define phase', 'measure phase', 'analyse phase',
      'improve phase', 'control charts', 'fishbone diagram', 'poka yoke', '5s'],
    transcriptSummary:
    '10-week Six Sigma DMAIC course covering lean manufacturing, '
        'control charts, and process improvement tools.',
  ),

  const Course(
    id: 25, title: 'Production Planning & Operations Management',
    provider: 'LinkedIn Learning',
    level: 'Intermediate', type: 'Course',
    url: 'https://www.linkedin.com/learning/production-planning',
    category: 'Manufacturing', duration: '8 hours', language: 'English',
    rating: 4.4, isFree: false,
    skills: ['production planning', 'quality control', 'supply chain',
      'erp systems', 'reporting'],
    topics: ['mrp', 'production scheduling', 'capacity planning',
      'erp systems', 'shop floor control', 'kpis'],
    qualityScore: 0.78, contentTypeString: 'video', detailLevelString: 'medium',
    lengthCategoryString: 'short', strategyString: 'example',
    isClassBased: false, viewCount: 95000,
    contentLength: ContentLength.short, detailLevel: DetailLevel.medium,
    learningStrategy: LearningStrategy.exampleOnly, isClassroomBased: false,
    contentFormat: ContentFormat.video,
    topicsCovert: ['mrp inputs', 'master production schedule',
      'rough cut capacity', 'erp modules', 'kanban boards', 'oee metrics'],
    transcriptSummary:
    'Eight-hour LinkedIn Learning course on production scheduling, MRP, '
        'ERP systems, and OEE performance metrics.',
  ),

  const Course(
    id: 26, title: 'Strategic Procurement & Sourcing', provider: 'Coursera',
    level: 'Intermediate', type: 'Course',
    url: 'https://www.coursera.org/learn/strategic-procurement',
    category: 'Manufacturing', duration: '6 weeks', language: 'English',
    rating: 4.5, isFree: false,
    skills: ['supply chain', 'vendor management', 'negotiation',
      'communication skills', 'strategic planning'],
    topics: ['sourcing strategy', 'supplier evaluation', 'contract negotiation',
      'spend analysis', 'risk management', 'e-procurement'],
    qualityScore: 0.83, contentTypeString: 'video', detailLevelString: 'medium',
    lengthCategoryString: 'long', strategyString: 'both', isClassBased: false,
    viewCount: 110000,
    contentLength: ContentLength.long, detailLevel: DetailLevel.medium,
    learningStrategy: LearningStrategy.both, isClassroomBased: false,
    contentFormat: ContentFormat.video,
    topicsCovert: ['make-or-buy decisions', 'rfp/rfq', 'supplier audits',
      'total cost of ownership', 'contract types', 'e-sourcing platforms'],
    transcriptSummary:
    'Six-week strategic procurement course covering sourcing strategy, '
        'supplier evaluation, and contract negotiation.',
  ),

  // ════════════ RETAIL ═════════════════════════════════════════════════════

  const Course(
    id: 27, title: 'Retail Sales & Customer Service Excellence',
    provider: 'Udemy',
    level: 'Beginner', type: 'Course',
    url: 'https://www.udemy.com/course/retail-sales-customer-service',
    category: 'Retail', duration: '4 hours', language: 'English',
    rating: 4.3, isFree: false,
    skills: ['customer service', 'sales', 'communication skills',
      'merchandising', 'product knowledge'],
    topics: ['retail fundamentals', 'customer service techniques',
      'upselling', 'merchandising', 'handling complaints'],
    qualityScore: 0.75, contentTypeString: 'video', detailLevelString: 'low',
    lengthCategoryString: 'short', strategyString: 'example',
    isClassBased: false, viewCount: 85000,
    contentLength: ContentLength.short, detailLevel: DetailLevel.low,
    learningStrategy: LearningStrategy.exampleOnly, isClassroomBased: false,
    contentFormat: ContentFormat.video,
    topicsCovert: ['greeting customers', 'needs analysis', 'upsell scripts',
      'planogram basics', 'complaint resolution', 'pos systems'],
    transcriptSummary:
    'Four-hour practical retail course covering customer service scripts, '
        'merchandising layout, and sales techniques.',
  ),

  const Course(
    id: 28, title: 'E-Commerce & Online Retail Strategy', provider: 'Coursera',
    level: 'Beginner', type: 'Course',
    url: 'https://www.coursera.org/learn/ecommerce-strategy',
    category: 'Retail', duration: '5 weeks', language: 'English',
    rating: 4.5, isFree: false,
    skills: ['merchandising', 'seo', 'customer service', 'data analysis',
      'market research', 'sales'],
    topics: ['e-commerce platforms', 'product listings', 'seo for retail',
      'conversion optimisation', 'fulfilment', 'customer retention'],
    qualityScore: 0.83, contentTypeString: 'video', detailLevelString: 'medium',
    lengthCategoryString: 'medium', strategyString: 'both', isClassBased: false,
    viewCount: 130000,
    contentLength: ContentLength.medium, detailLevel: DetailLevel.medium,
    learningStrategy: LearningStrategy.both, isClassroomBased: false,
    contentFormat: ContentFormat.video,
    topicsCovert: ['shopify setup', 'product photography', 'a/b testing',
      'cart abandonment', '3pl logistics', 'email retargeting',
      'reviews management'],
    transcriptSummary:
    'Five-week e-commerce strategy course covering platform setup, '
        'SEO, conversion optimisation, and fulfilment.',
  ),

  const Course(
    id: 29, title: 'Business Development & Negotiation Skills',
    provider: 'LinkedIn Learning',
    level: 'Intermediate', type: 'Course',
    url: 'https://www.linkedin.com/learning/negotiation-skills',
    category: 'Retail', duration: '6 hours', language: 'English',
    rating: 4.4, isFree: false,
    skills: ['sales', 'business development', 'negotiation',
      'communication skills', 'market research'],
    topics: ['negotiation tactics', 'persuasion', 'stakeholder management',
      'business development cycle', 'pitching', 'closing deals'],
    qualityScore: 0.78, contentTypeString: 'video', detailLevelString: 'medium',
    lengthCategoryString: 'short', strategyString: 'example',
    isClassBased: false, viewCount: 70000,
    contentLength: ContentLength.short, detailLevel: DetailLevel.medium,
    learningStrategy: LearningStrategy.exampleOnly, isClassroomBased: false,
    contentFormat: ContentFormat.video,
    topicsCovert: ['batna', 'anchoring', 'mirroring', 'objection handling',
      'discovery calls', 'pipeline management', 'contract negotiation'],
    transcriptSummary:
    'Six-hour LinkedIn Learning course on negotiation tactics, '
        'sales pipeline management, and deal-closing techniques.',
  ),

  // ════════════ EDUCATION ══════════════════════════════════════════════════

  const Course(
    id: 30, title: 'Instructional Design for E-Learning', provider: 'Coursera',
    level: 'Beginner', type: 'Course',
    url: 'https://www.coursera.org/learn/instructional-design-ell',
    category: 'Education', duration: '6 weeks', language: 'English',
    rating: 4.6, isFree: false,
    skills: ['curriculum design', 'edtech', 'content writing',
      'communication skills', 'research'],
    topics: ['addie model', 'learning objectives', 'storyboarding',
      'e-learning authoring', 'assessment design', 'accessibility'],
    qualityScore: 0.85, contentTypeString: 'video', detailLevelString: 'medium',
    lengthCategoryString: 'long', strategyString: 'both', isClassBased: false,
    viewCount: 160000,
    contentLength: ContentLength.long, detailLevel: DetailLevel.medium,
    learningStrategy: LearningStrategy.both, isClassroomBased: false,
    contentFormat: ContentFormat.video,
    topicsCovert: ['addie', 'blooms taxonomy', 'storyboard tools',
      'articulate storyline', 'scorm', 'accessibility wcag', 'lms integration'],
    transcriptSummary:
    'Six-week instructional design course covering ADDIE, learning '
        'objectives, and e-learning authoring tools.',
  ),

  const Course(
    id: 31, title: 'Teaching & Learning Online', provider: 'edX',
    level: 'Beginner', type: 'Course',
    url: 'https://www.edx.org/learn/teaching',
    category: 'Education', duration: '5 weeks', language: 'English',
    rating: 4.5, isFree: true,
    skills: ['teaching', 'curriculum design', 'edtech', 'research',
      'communication skills'],
    topics: ['pedagogy', 'online facilitation', 'learner engagement',
      'formative assessment', 'edtech tools', 'feedback'],
    qualityScore: 0.83, contentTypeString: 'video', detailLevelString: 'medium',
    lengthCategoryString: 'medium', strategyString: 'theory',
    isClassBased: true, viewCount: 200000,
    contentLength: ContentLength.medium, detailLevel: DetailLevel.medium,
    learningStrategy: LearningStrategy.theoryOnly, isClassroomBased: true,
    contentFormat: ContentFormat.video,
    topicsCovert: ['synchronous vs asynchronous', 'zoom facilitation',
      'discussion prompts', 'peer assessment', 'lms forums', 'rubric design'],
    transcriptSummary:
    'Five-week university-style course on online pedagogy, learner '
        'engagement strategies, and formative assessment design.',
  ),

  const Course(
    id: 32, title: 'Corporate Training & Facilitation',
    provider: 'LinkedIn Learning',
    level: 'Intermediate', type: 'Course',
    url: 'https://www.linkedin.com/learning/training-facilitation',
    category: 'Education', duration: '8 hours', language: 'English',
    rating: 4.4, isFree: false,
    skills: ['teaching', 'curriculum design', 'presentation skills',
      'communication skills', 'training'],
    topics: ['needs analysis', 'workshop design', 'facilitation techniques',
      'blended learning', 'evaluation', 'coaching'],
    qualityScore: 0.78, contentTypeString: 'video', detailLevelString: 'medium',
    lengthCategoryString: 'short', strategyString: 'both', isClassBased: false,
    viewCount: 88000,
    contentLength: ContentLength.short, detailLevel: DetailLevel.medium,
    learningStrategy: LearningStrategy.both, isClassroomBased: false,
    contentFormat: ContentFormat.video,
    topicsCovert: ['training needs analysis', 'icebreakers', 'breakout rooms',
      'kirkpatrick model', 'coaching conversations', 'hybrid facilitation'],
    transcriptSummary:
    'Eight-hour facilitation course covering training needs analysis, '
        'workshop design, and Kirkpatrick evaluation.',
  ),

  // ════════════ CROSS-INDUSTRY ═════════════════════════════════════════════

  const Course(
    id: 33, title: 'IBM Data Analyst Professional Certificate',
    provider: 'Coursera',
    level: 'Beginner', type: 'Certificate',
    url: 'https://www.coursera.org/professional-certificates/ibm-data-analyst',
    category: 'Data Science', duration: '11 months', language: 'English',
    rating: 4.7, isFree: false,
    skills: ['python', 'data analysis', 'sql', 'excel', 'pandas',
      'reporting', 'data visualisation'],
    topics: ['data analysis methodology', 'python basics', 'sql querying',
      'excel analytics', 'visualisation', 'capstone project'],
    qualityScore: 0.91, contentTypeString: 'video', detailLevelString: 'high',
    lengthCategoryString: 'long', strategyString: 'both', isClassBased: false,
    viewCount: 1100000,
    contentLength: ContentLength.long, detailLevel: DetailLevel.high,
    learningStrategy: LearningStrategy.both, isClassroomBased: false,
    contentFormat: ContentFormat.video,
    topicsCovert: ['data lifecycle', 'python lists/dicts', 'pandas merge',
      'sql window functions', 'cognos analytics', 'tableau', 'capstone dataset'],
    transcriptSummary:
    'IBM 11-month end-to-end data analyst certificate covering Python, '
        'SQL, Excel, and Tableau with a capstone project.',
    thumbnailUrl:
    'https://d3njjcbhbojbot.cloudfront.net/api/utilities/v1/imageproxy/ibm-data-analyst.jpg',
  ),

  const Course(
    id: 34, title: 'Project Management Professional (PMP) Prep',
    provider: 'Udemy',
    level: 'Intermediate', type: 'Course',
    url: 'https://www.udemy.com/course/pmp-pmbok6-exam',
    category: 'Management', duration: '35 hours', language: 'English',
    rating: 4.6, isFree: false,
    skills: ['project management', 'communication skills', 'leadership',
      'risk analysis', 'reporting'],
    topics: ['pmbok framework', 'project lifecycle', 'scope management',
      'risk management', 'stakeholder management', 'agile overview'],
    qualityScore: 0.85, contentTypeString: 'video', detailLevelString: 'high',
    lengthCategoryString: 'long', strategyString: 'theory', isClassBased: false,
    viewCount: 340000,
    contentLength: ContentLength.long, detailLevel: DetailLevel.high,
    learningStrategy: LearningStrategy.theoryOnly, isClassroomBased: false,
    contentFormat: ContentFormat.video,
    topicsCovert: ['initiating process group', 'wbs creation', 'earned value',
      'critical path method', 'risk register', 'change control',
      'agile sprints'],
    transcriptSummary:
    '35-hour PMP exam prep covering PMBOK 7 knowledge areas, '
        'agile hybrids, and 200 practice questions.',
  ),

  const Course(
    id: 35, title: 'Communication Skills for Professionals', provider: 'Coursera',
    level: 'Beginner', type: 'Course',
    url: 'https://www.coursera.org/learn/communication-skills',
    category: 'Soft Skills', duration: '4 weeks', language: 'English',
    rating: 4.5, isFree: false,
    skills: ['communication skills', 'presentation skills', 'negotiation',
      'teamwork', 'leadership'],
    topics: ['verbal communication', 'written communication', 'active listening',
      'presentations', 'conflict resolution', 'cross-cultural comms'],
    qualityScore: 0.82, contentTypeString: 'video', detailLevelString: 'low',
    lengthCategoryString: 'medium', strategyString: 'example',
    isClassBased: false, viewCount: 420000,
    contentLength: ContentLength.medium, detailLevel: DetailLevel.low,
    learningStrategy: LearningStrategy.exampleOnly, isClassroomBased: false,
    contentFormat: ContentFormat.video,
    topicsCovert: ['non-verbal cues', 'elevator pitch', 'email etiquette',
      'slide design', 'feedback frameworks', 'cultural intelligence'],
    transcriptSummary:
    'Four-week communication essentials course covering written, verbal, '
        'and presentation skills for professional contexts.',
  ),

  const Course(
    id: 36, title: 'Statistics & Probability for Data Science',
    provider: 'Khan Academy',
    level: 'Beginner', type: 'Video',
    url: 'https://www.khanacademy.org/math/statistics-probability',
    category: 'Data Science', duration: 'Self-paced', language: 'English',
    rating: 4.7, isFree: true,
    skills: ['statistics', 'data analysis', 'probability', 'python',
      'research', 'machine learning'],
    topics: ['descriptive statistics', 'probability', 'distributions',
      'hypothesis testing', 'regression', 'confidence intervals'],
    qualityScore: 0.89, contentTypeString: 'video', detailLevelString: 'medium',
    lengthCategoryString: 'long', strategyString: 'both', isClassBased: false,
    viewCount: 5000000,
    contentLength: ContentLength.long, detailLevel: DetailLevel.medium,
    learningStrategy: LearningStrategy.both, isClassroomBased: false,
    contentFormat: ContentFormat.video,
    topicsCovert: ['mean/median/mode', 'standard deviation',
      'normal distribution', 'z-scores', 'p-values', 'type I/II errors',
      'linear regression', 'chi-square'],
    transcriptSummary:
    'Free self-paced Khan Academy statistics curriculum covering '
        'descriptive stats, probability, and inferential testing.',
    thumbnailUrl: 'https://cdn.kastatic.org/images/khan-logo-dark-background.png',
  ),

];

// ═══════════════════════════════════════════════════════════════════════════
// §13  SORT
// ═══════════════════════════════════════════════════════════════════════════

/// Sort [list] according to [strategy].
/// Returns a new sorted list — does NOT mutate the input.
List<Course> sortCourses(List<Course> list, CourseSortStrategy strategy) {
  final sorted = List<Course>.from(list);
  switch (strategy) {
    case CourseSortStrategy.ratingDesc:
      sorted.sort((a, b) => b.rating.compareTo(a.rating));
    case CourseSortStrategy.qualityScoreDesc:
      sorted.sort((a, b) =>
          (b.qualityScore ?? 0.0).compareTo(a.qualityScore ?? 0.0));
    case CourseSortStrategy.viewCountDesc:
      sorted.sort((a, b) =>
          (b.viewCount ?? 0).compareTo(a.viewCount ?? 0));
    case CourseSortStrategy.recommendationScoreDesc:
      sorted.sort((a, b) =>
          (b.recommendation?.score ?? 0.0)
              .compareTo(a.recommendation?.score ?? 0.0));
    case CourseSortStrategy.detailLevelAsc:
      sorted.sort((a, b) => a.detailLevel.rank.compareTo(b.detailLevel.rank));
    case CourseSortStrategy.detailLevelDesc:
      sorted.sort((a, b) => b.detailLevel.rank.compareTo(a.detailLevel.rank));
    case CourseSortStrategy.titleAZ:
      sorted.sort((a, b) => a.title.compareTo(b.title));
    case CourseSortStrategy.freeFirst:
      sorted.sort((a, b) {
        if (a.isFree == b.isFree) return 0;
        return a.isFree ? -1 : 1;
      });
  }
  return sorted;
}

// ═══════════════════════════════════════════════════════════════════════════
// §14  RECOMMENDATION ENGINES [Tavakoli 2022 §3.5.2]
// ═══════════════════════════════════════════════════════════════════════════

/// Recommends courses ranked by dot product of [toFeatureVector] against
/// [prefVector] (15 elements), with an optional skill overlap boost.
/// Only returns courses that pass the quality filter (qualityScore ≥ 0.5).
List<Course> recommendByPreferenceVector(
    List<double> prefVector, {
      List<String> missingSkills = const [],
      int? topN,
    }) {
  if (prefVector.length != 15) {
    throw ArgumentError(
        'prefVector must be 15-dimensional; '
            'got ${prefVector.length} elements.');
  }

  final candidates = courses.where((c) => c.passesQualityFilter).map((c) {
    final dot     = c.dotProductWithList(prefVector);
    final overlap =
    missingSkills.isEmpty ? 0.0 : c.matchScore(missingSkills);
    final score   = dot + (overlap * 0.5);
    return (course: c, score: score, dot: dot, overlap: overlap);
  }).where((e) => e.score > 0).toList()
    ..sort((a, b) => b.score.compareTo(a.score));

  final results = candidates.map((e) => e.course).toList();
  return topN != null ? results.take(topN).toList() : results;
}

/// Returns [CourseRecommendation] records with score breakdown attached.
List<CourseRecommendation> rankByRecommendationScore(
    List<double> prefVector, {
      List<String> missingSkills = const [],
      int? topN,
    }) {
  if (prefVector.length != 15) {
    throw ArgumentError(
        'prefVector must be 15-dimensional; '
            'got ${prefVector.length} elements.');
  }

  final recs = courses.where((c) => c.passesQualityFilter).map((c) {
    final dot   = c.dotProductWithList(prefVector);
    final boost =
        (missingSkills.isEmpty ? 0.0 : c.matchScore(missingSkills)) * 0.5;
    final score = dot + boost;
    return CourseRecommendation(
        course: c, score: score, dotProduct: dot, skillBoost: boost);
  }).where((r) => r.score > 0).toList()
    ..sort((a, b) => b.score.compareTo(a.score));

  return topN != null ? recs.take(topN).toList() : recs;
}

/// Map-based preference variant (kept for backward compatibility).
List<Course> recommendByPreference(
    Map<String, double> prefVector, {
      List<String> missingSkills = const [],
      int? topN,
    }) {
  final candidates = courses.where((c) => c.passesQualityFilter).map((c) {
    final dot     = c.dotProductWith(prefVector);
    final overlap =
    missingSkills.isEmpty ? 0.0 : c.matchScore(missingSkills);
    final score   = dot + (overlap * 0.5);
    return (course: c, score: score);
  }).where((e) => e.score > 0).toList()
    ..sort((a, b) => b.score.compareTo(a.score));

  final results = candidates.map((e) => e.course).toList();
  return topN != null ? results.take(topN).toList() : results;
}

/// Ranks [courses] by cosine similarity to [prefVector].
List<Course> rankByCosineSimilarity(List<double> prefVector, {int? topN}) {
  if (prefVector.length != 15) {
    throw ArgumentError('prefVector must be 15-dimensional.');
  }
  final ranked = courses.map((c) {
    return (course: c, score: c.cosineSimilarity(prefVector));
  }).where((e) => e.score > 0).toList()
    ..sort((a, b) => b.score.compareTo(a.score));
  final results = ranked.map((e) => e.course).toList();
  return topN != null ? results.take(topN).toList() : results;
}

// ═══════════════════════════════════════════════════════════════════════════
// §15  FILTER & QUERY HELPERS
// ═══════════════════════════════════════════════════════════════════════════

/// Filter courses using a [CourseFilter] specification.
List<Course> coursesByFilter(CourseFilter filter) =>
    courses.where(filter.matches).toList();

/// Returns courses that cover ≥ 1 missing skill, sorted by match score desc.
List<Course> recommendCourses(List<String> missingSkills) {
  if (missingSkills.isEmpty) return [];
  final lower = missingSkills.map((s) => s.toLowerCase()).toSet();
  return courses
      .where((c) => c.skills.any((s) => lower.contains(s.toLowerCase())))
      .toList()
    ..sort((a, b) =>
        b.matchScore(missingSkills).compareTo(a.matchScore(missingSkills)));
}

/// Returns courses that cover at least one skill from [targetSkills].
List<Course> coursesMatchingAnySkill(List<String> targetSkills) {
  if (targetSkills.isEmpty) return [];
  return courses.where((c) => c.coversAnySkill(targetSkills)).toList();
}

/// Returns the [topN] highest-rated quality-filtered courses.
List<Course> topCoursesByRating({int topN = 10, double minRating = 4.0}) {
  return sortCourses(
    courses
        .where((c) => c.passesQualityFilter && c.rating >= minRating)
        .toList(),
    CourseSortStrategy.ratingDesc,
  ).take(topN).toList();
}

/// Attaches pre-computed feature vectors to all courses and returns new list.
/// Call at app startup to avoid recomputing on every recommendation request.
List<Course> computeAllFeatureVecs() {
  return courses.map((c) {
    final vec = c.computeFeatureVector();
    return c.copyWith(featureVector: vec);
  }).toList();
}

/// Aggregate statistics for all courses.
CourseStats courseStats() => CourseStats.fromCourses(courses);

/// Groups courses by [category].
Map<String, List<Course>> groupByCategory([List<Course>? list]) {
  final src = list ?? courses;
  final map = <String, List<Course>>{};
  for (final c in src) {
    map.putIfAbsent(c.category, () => []).add(c);
  }
  return map;
}

/// Groups courses by [provider].
Map<String, List<Course>> groupByProvider([List<Course>? list]) {
  final src = list ?? courses;
  final map = <String, List<Course>>{};
  for (final c in src) {
    map.putIfAbsent(c.provider, () => []).add(c);
  }
  return map;
}

// ═══════════════════════════════════════════════════════════════════════════
// §16  LEGACY SESSION 2 HELPER FUNCTIONS (unchanged signatures)
// ═══════════════════════════════════════════════════════════════════════════

List<Course> get freeCourses => courses.where((c) => c.isFree).toList();

List<Course> coursesByLevel(String level) =>
    courses.where((c) => c.level == level).toList();

List<Course> qualityFilteredCourses({double minScore = 0.5}) =>
    courses.where((c) => c.passesQualityFilter).toList();

List<Course> coursesByContentFormat(ContentFormat format) =>
    courses.where((c) => c.contentFormat == format).toList();

List<Course> coursesByContentLength(ContentLength length) =>
    courses.where((c) => c.contentLength == length).toList();

List<Course> coursesByDetailLevel(DetailLevel level) =>
    courses.where((c) => c.detailLevel == level).toList();

List<Course> coursesByStrategy(LearningStrategy strategy) =>
    courses.where((c) => c.learningStrategy == strategy).toList();

List<Course> coursesByTopic(String topic) {
  final needle = topic.toLowerCase();
  return courses
      .where((c) =>
  c.topics.any((t) => t.toLowerCase().contains(needle)) ||
      c.topicsCovert.any((t) => t.toLowerCase().contains(needle)))
      .toList();
}

/// [Session 3] Returns courses that are free, high quality, and top-rated.
List<Course> premiumFreeCourses() =>
    courses.where((c) => c.isPremiumFree).toList();

/// [Session 3] Returns beginner-friendly, low-or-medium detail courses.
List<Course> entryFriendlyCourses() =>
    courses.where((c) => c.isEntryFriendly).toList();

/// [Session 3] Returns all certificate-level courses.
List<Course> certificateCourses() =>
    courses.where((c) => c.isCertificateLevel).toList();