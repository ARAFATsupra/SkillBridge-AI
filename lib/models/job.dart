// lib/models/job.dart — SkillBridge AI
// ─────────────────────────────────────────────────────────────────────────────
// SESSION 3 UPGRADE — Maximum-level rewrite, 100 % null-safe, zero breaking
// changes to existing constructor / toMap / fromMap call sites.
//
// PATCH NOTES (applied on top of Session 3)
// ──────────────────────────────────────────
// • CareerFitScore.weakestAxis / strongestAxis: replaced per-call Map
//   construction with direct sequential comparisons — eliminates one heap
//   allocation per call and avoids repeated .entries.reduce() iteration.
// • automationRiskFlutterColor: added @Deprecated annotation; the function
//   is kept for backward compatibility but callers should use
//   AutomationRiskTier.fromScore(risk).color directly.
// • _castStringList: return const [] (unmodifiable) is safe here because no
//   call site mutates the returned list; noted explicitly in the comment.
//
// References (unchanged)
// ──────────────────────
// [Alsaif 2022]  Alsaif et al. (MDPI Computers 11, 161)
// [Tavakoli 2022] Tavakoli et al. (Advanced Engineering Informatics 52, 101508)
// [F&O 2017]     Frey & Osborne (Oxford, 2013/2017 — automation risk)
// [SDG-8]        UN Sustainable Development Goal 8
// [RCA]          Balassa (1965) / Rodrik (2006) — Revealed Comparative Advantage
// ─────────────────────────────────────────────────────────────────────────────

// ignore_for_file: prefer_constructors_over_static_methods

import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════
// §1  SENTINEL — clean nullable copyWith without boolean clear-flags
// ═══════════════════════════════════════════════════════════════════════════

/// Private sentinel used to distinguish "not provided" from explicit `null`
/// in [Job.copyWith] nullable parameters.
class _Unset {
  const _Unset();
}

const _unset = _Unset();

// ═══════════════════════════════════════════════════════════════════════════
// §2  ENUMS
// ═══════════════════════════════════════════════════════════════════════════

// ── 2.1  JobType ─────────────────────────────────────────────────────────────

/// Type-safe job employment type, derived from the raw [Job.type] string.
enum JobType {
  fullTime('full-time'),
  partTime('part-time'),
  contract('contract'),
  temporary('temporary'),
  intern('intern');

  const JobType(this.value);

  /// Raw string value stored in the data model.
  final String value;

  /// Parse from raw string; defaults to [fullTime] on unknown values.
  static JobType fromString(String raw) {
    final lower = raw.toLowerCase().trim();
    for (final t in JobType.values) {
      if (t.value == lower) return t;
    }
    return JobType.fullTime;
  }

  /// Human-readable label for UI display.
  String get displayName => switch (this) {
    JobType.fullTime  => 'Full-Time',
    JobType.partTime  => 'Part-Time',
    JobType.contract  => 'Contract',
    JobType.temporary => 'Temporary',
    JobType.intern    => 'Internship',
  };

  /// True for permanent employment types.
  bool get isPermanent =>
      this == JobType.fullTime || this == JobType.partTime;
}

// ── 2.2  JobLevel ────────────────────────────────────────────────────────────

/// Type-safe seniority level.
enum JobLevel {
  entry('Entry Level'),
  mid('Mid Level'),
  senior('Senior Level');

  const JobLevel(this.value);
  final String value;

  static JobLevel fromString(String raw) {
    for (final l in JobLevel.values) {
      if (l.value == raw.trim()) return l;
    }
    return JobLevel.entry;
  }

  /// Numeric rank for ordering (entry=1, mid=2, senior=3).
  int get rank => index + 1;

  String get displayName => value;
}

// ── 2.3  WorkingModeEnum ─────────────────────────────────────────────────────

/// Type-safe working-mode classification.
enum WorkingModeEnum {
  remote('Remote'),
  onSite('On-site'),
  hybrid('Hybrid');

  const WorkingModeEnum(this.value);
  final String value;

  static WorkingModeEnum fromString(String raw) {
    for (final m in WorkingModeEnum.values) {
      if (m.value == raw.trim()) return m;
    }
    return WorkingModeEnum.onSite;
  }

  bool get allowsRemote =>
      this == WorkingModeEnum.remote || this == WorkingModeEnum.hybrid;
}

// ── 2.4  AutomationRiskTier ──────────────────────────────────────────────────

/// [F&O 2017] Probability-based automation risk classification.
/// Low < 0.30 | Medium 0.30–0.69 | High ≥ 0.70
enum AutomationRiskTier {
  low,
  medium,
  high,
  unknown;

  /// Derive tier from 0–1 probability score.
  static AutomationRiskTier fromScore(double? score) {
    if (score == null) return AutomationRiskTier.unknown;
    if (score < 0.30) return AutomationRiskTier.low;
    if (score < 0.70) return AutomationRiskTier.medium;
    return AutomationRiskTier.high;
  }

  String get label => switch (this) {
    AutomationRiskTier.low     => 'Low Risk',
    AutomationRiskTier.medium  => 'Medium Risk',
    AutomationRiskTier.high    => 'High Risk',
    AutomationRiskTier.unknown => 'Unknown',
  };

  /// Hex colour string for non-Flutter rendering (charts, exports).
  String get hexColor => switch (this) {
    AutomationRiskTier.low     => '#4CAF50',
    AutomationRiskTier.medium  => '#FF9800',
    AutomationRiskTier.high    => '#F44336',
    AutomationRiskTier.unknown => '#9E9E9E',
  };

  /// Flutter [Color] for widget rendering.
  Color get color => switch (this) {
    AutomationRiskTier.low     => Colors.green,
    AutomationRiskTier.medium  => Colors.orange,
    AutomationRiskTier.high    => Colors.red,
    AutomationRiskTier.unknown => Colors.grey,
  };

  bool get isSafe => this == AutomationRiskTier.low;
}

// ── 2.5  SdgImpactType ───────────────────────────────────────────────────────

/// [SDG-8] Controlled vocabulary for SDG-8 impact labels.
enum SdgImpactType {
  decentWork('Decent Work'),
  skillsTraining('Skills Training'),
  youthEmployment('Youth Employment'),
  inclusiveGrowth('Inclusive Growth'),
  productivity('Productivity');

  const SdgImpactType(this.label);
  final String label;

  /// Returns `null` when the raw string doesn't match any known label.
  static SdgImpactType? fromString(String raw) {
    for (final s in SdgImpactType.values) {
      if (s.label == raw.trim()) return s;
    }
    return null;
  }

  IconData get icon => switch (this) {
    SdgImpactType.decentWork      => Icons.work_outline_rounded,
    SdgImpactType.skillsTraining  => Icons.school_outlined,
    SdgImpactType.youthEmployment => Icons.people_outline_rounded,
    SdgImpactType.inclusiveGrowth => Icons.trending_up_rounded,
    SdgImpactType.productivity    => Icons.bolt_outlined,
  };
}

// ── 2.6  SimScoreTier ────────────────────────────────────────────────────────

/// [Alsaif 2022 §4.3, Table 2] Cosine-similarity tier classification.
/// Strong ≥ 0.75 | Moderate 0.40–0.74 | Weak < 0.40
enum SimScoreTier {
  strong,
  moderate,
  weak;

  static SimScoreTier fromScore(double score) {
    if (score >= 0.75) return SimScoreTier.strong;
    if (score >= 0.40) return SimScoreTier.moderate;
    return SimScoreTier.weak;
  }

  String get label => switch (this) {
    SimScoreTier.strong   => 'Strong Match',
    SimScoreTier.moderate => 'Moderate Match',
    SimScoreTier.weak     => 'Weak Match',
  };

  Color get color => switch (this) {
    SimScoreTier.strong   => Colors.green.shade700,
    SimScoreTier.moderate => Colors.orange.shade700,
    SimScoreTier.weak     => Colors.red.shade700,
  };

  bool get isActionable =>
      this == SimScoreTier.strong || this == SimScoreTier.moderate;
}

// ── 2.7  PostingGrowthCategory ───────────────────────────────────────────────

/// Classification of year-over-year posting growth rate.
enum PostingGrowthCategory {
  declining,  // < 0
  stable,     // 0 – 0.05
  growing,    // 0.05 – 0.20
  highGrowth; // > 0.20

  static PostingGrowthCategory fromRate(double? rate) {
    final r = rate ?? 0.0;
    if (r < 0.0) return PostingGrowthCategory.declining;
    if (r < 0.05) return PostingGrowthCategory.stable;
    if (r <= 0.20) return PostingGrowthCategory.growing;
    return PostingGrowthCategory.highGrowth;
  }

  String get label => switch (this) {
    PostingGrowthCategory.declining  => 'Declining',
    PostingGrowthCategory.stable     => 'Stable',
    PostingGrowthCategory.growing    => 'Growing',
    PostingGrowthCategory.highGrowth => 'High Growth',
  };

  Color get color => switch (this) {
    PostingGrowthCategory.declining  => Colors.red.shade600,
    PostingGrowthCategory.stable     => Colors.grey.shade600,
    PostingGrowthCategory.growing    => Colors.blue.shade600,
    PostingGrowthCategory.highGrowth => Colors.green.shade700,
  };
}

// ── 2.8  JobSortStrategy ─────────────────────────────────────────────────────

/// Strategy-pattern sort keys for [sortJobs].
enum JobSortStrategy {
  /// [Alsaif 2022 §4.3] Weighted cosine sim score — descending (best match first).
  simScore,

  /// YoY posting growth rate — descending (fastest-growing first).
  postingGrowthRate,

  /// Relative posting volume — descending (most-posted first).
  postingFrequency,

  /// [F&O 2017] Automation risk — ascending (safest first).
  automationRiskAsc,

  /// [Alsaif 2022 §4] Skill gap size — ascending (easiest transition first).
  transitionDistanceAsc,

  /// Posted date — descending (newest first).
  mostRecent,

  /// Years of experience required — ascending (entry-friendly first).
  experienceAsc,

  /// Composite career-fit score — descending (requires CareerFitScore attached).
  careerFitScore,
}

// ═══════════════════════════════════════════════════════════════════════════
// §3  JOBFILTER — immutable filter specification
// ═══════════════════════════════════════════════════════════════════════════

/// Encapsulates every filter dimension in one value-class.
/// Pass to [filterJobs], [recommendJobs], or [sortJobs].
@immutable
class JobFilter {
  final String industry;
  final String level;
  final bool remoteOnly;
  final String occupationalGroup;
  final double? maxAutomationRisk;
  final String? sdgImpact;
  final bool? essentialOnly;
  final bool? trendingOnly;
  final bool? pivotSkillOnly;
  final int? maxTransitionDistance;

  /// Jobs must contain ALL listed skills (case-insensitive).
  final List<String> requiredSkills;
  final int? maxExperienceYears;
  final PostingGrowthCategory? minGrowthCategory;

  const JobFilter({
    this.industry            = 'All',
    this.level               = 'All',
    this.remoteOnly          = false,
    this.occupationalGroup   = 'All',
    this.maxAutomationRisk,
    this.sdgImpact,
    this.essentialOnly,
    this.trendingOnly,
    this.pivotSkillOnly,
    this.maxTransitionDistance,
    this.requiredSkills      = const [],
    this.maxExperienceYears,
    this.minGrowthCategory,
  });

  /// Returns `true` when [job] satisfies every active criterion.
  bool matches(Job job) {
    if (industry != 'All' && job.industry != industry) return false;
    if (level != 'All' && job.level != level) return false;
    if (remoteOnly && !job.remote) return false;
    if (occupationalGroup != 'All' &&
        job.occupationalGroup != occupationalGroup) {
      return false;
    }
    if (maxAutomationRisk != null &&
        job.automationRisk != null &&
        job.automationRisk! > maxAutomationRisk!) {
      return false;
    }
    if (sdgImpact != null && job.sdgImpact != sdgImpact) return false;
    if (essentialOnly == true && !job.isEssentialDuringCrisis) return false;
    if (trendingOnly == true && !job.isTrending) return false;
    if (pivotSkillOnly == true && !job.isPivotSkillJob) return false;
    if (maxTransitionDistance != null &&
        job.transitionDistance > maxTransitionDistance!) {
      return false;
    }
    if (maxExperienceYears != null &&
        job.experience > maxExperienceYears!) {
      return false;
    }
    if (minGrowthCategory != null) {
      final cat = PostingGrowthCategory.fromRate(job.postingGrowthRate);
      if (cat.index < minGrowthCategory!.index) return false;
    }
    if (requiredSkills.isNotEmpty) {
      final jobLower = job.skills.map((s) => s.toLowerCase()).toSet();
      for (final req in requiredSkills) {
        if (!jobLower.contains(req.toLowerCase())) return false;
      }
    }
    return true;
  }

  /// Returns a new [JobFilter] with selected fields replaced.
  JobFilter copyWith({
    String? industry,
    String? level,
    bool? remoteOnly,
    String? occupationalGroup,
    Object? maxAutomationRisk    = _unset,
    Object? sdgImpact            = _unset,
    Object? essentialOnly        = _unset,
    Object? trendingOnly         = _unset,
    Object? pivotSkillOnly       = _unset,
    Object? maxTransitionDistance = _unset,
    List<String>? requiredSkills,
    Object? maxExperienceYears   = _unset,
    Object? minGrowthCategory    = _unset,
  }) {
    return JobFilter(
      industry: industry ?? this.industry,
      level: level ?? this.level,
      remoteOnly: remoteOnly ?? this.remoteOnly,
      occupationalGroup: occupationalGroup ?? this.occupationalGroup,
      maxAutomationRisk: maxAutomationRisk is _Unset
          ? this.maxAutomationRisk
          : maxAutomationRisk as double?,
      sdgImpact: sdgImpact is _Unset
          ? this.sdgImpact
          : sdgImpact as String?,
      essentialOnly: essentialOnly is _Unset
          ? this.essentialOnly
          : essentialOnly as bool?,
      trendingOnly: trendingOnly is _Unset
          ? this.trendingOnly
          : trendingOnly as bool?,
      pivotSkillOnly: pivotSkillOnly is _Unset
          ? this.pivotSkillOnly
          : pivotSkillOnly as bool?,
      maxTransitionDistance: maxTransitionDistance is _Unset
          ? this.maxTransitionDistance
          : maxTransitionDistance as int?,
      requiredSkills: requiredSkills ?? this.requiredSkills,
      maxExperienceYears: maxExperienceYears is _Unset
          ? this.maxExperienceYears
          : maxExperienceYears as int?,
      minGrowthCategory: minGrowthCategory is _Unset
          ? this.minGrowthCategory
          : minGrowthCategory as PostingGrowthCategory?,
    );
  }

  /// A permissive filter that matches every job (useful as a no-op default).
  static const JobFilter none = JobFilter();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is JobFilter &&
        other.industry            == industry &&
        other.level               == level &&
        other.remoteOnly          == remoteOnly &&
        other.occupationalGroup   == occupationalGroup &&
        other.maxAutomationRisk   == maxAutomationRisk &&
        other.sdgImpact           == sdgImpact &&
        other.essentialOnly       == essentialOnly &&
        other.trendingOnly        == trendingOnly &&
        other.pivotSkillOnly      == pivotSkillOnly &&
        other.maxTransitionDistance == maxTransitionDistance &&
        other.maxExperienceYears  == maxExperienceYears &&
        other.minGrowthCategory   == minGrowthCategory;
  }

  @override
  int get hashCode => Object.hash(
    industry, level, remoteOnly, occupationalGroup,
    maxAutomationRisk, sdgImpact, essentialOnly, trendingOnly,
    pivotSkillOnly, maxTransitionDistance, maxExperienceYears, minGrowthCategory,
  );

  @override
  String toString() =>
      'JobFilter(industry: $industry, level: $level, '
          'remoteOnly: $remoteOnly, maxAutoRisk: $maxAutomationRisk, '
          'essentialOnly: $essentialOnly, trendingOnly: $trendingOnly)';
}

// ═══════════════════════════════════════════════════════════════════════════
// §4  CAREERFITSCORE — composite 4-axis fit score
// ═══════════════════════════════════════════════════════════════════════════

/// Composite career-fit object built from four orthogonal axes.
///
/// Axes and weights
/// ─────────────────
///   skill match       40 % — [Alsaif 2022] simScore or matchScore fallback
///   growth potential  25 % — normalised postingGrowthRate
///   automation safety 20 % — 1 − automationRisk  [F&O 2017]
///   transition ease   15 % — 1 − (missing skills / total skills)
@immutable
class CareerFitScore {
  /// Skill similarity (0–1).
  final double skillMatch;

  /// Normalised posting-growth potential (0–1).
  final double growthPotential;

  /// Automation-safety score: 1 − automationRisk (0–1).
  final double automationSafety;

  /// Ease of skill transition: 1 − gapRatio (0–1).
  final double transitionEase;

  /// Weighted composite across all four axes (0–1).
  final double composite;

  /// Letter grade: A+ / A / B / C / D / F.
  final String grade;

  // Axis weights (sum = 1.0)
  static const double _wSkill      = 0.40;
  static const double _wGrowth     = 0.25;
  static const double _wSafety     = 0.20;
  static const double _wTransition = 0.15;

  const CareerFitScore({
    required this.skillMatch,
    required this.growthPotential,
    required this.automationSafety,
    required this.transitionEase,
    required this.composite,
    required this.grade,
  });

  /// Compute a [CareerFitScore] for [job] given [userSkills].
  factory CareerFitScore.compute(Job job, List<String> userSkills) {
    final skillMatch =
    job.simScore > 0.0 ? job.simScore : job.matchScore(userSkills);

    // Normalise growth rate: cap ±50 % → 0–1 scale.
    final growthRaw = (job.postingGrowthRate ?? 0.0).clamp(-0.50, 0.50);
    final growthPotential = ((growthRaw + 0.50) / 1.00).clamp(0.0, 1.0);

    final automationSafety =
    (1.0 - (job.automationRisk ?? 0.50)).clamp(0.0, 1.0);

    final totalSkills   = job.skills.length;
    final missingCount  = job.computeTransitionDistance(userSkills);
    final transitionEase = totalSkills > 0
        ? (1.0 - missingCount / totalSkills).clamp(0.0, 1.0)
        : 1.0;

    final composite = (skillMatch * _wSkill +
        growthPotential * _wGrowth +
        automationSafety * _wSafety +
        transitionEase * _wTransition)
        .clamp(0.0, 1.0);

    return CareerFitScore(
      skillMatch      : skillMatch,
      growthPotential : growthPotential,
      automationSafety: automationSafety,
      transitionEase  : transitionEase,
      composite       : composite,
      grade           : _gradeFromComposite(composite),
    );
  }

  static String _gradeFromComposite(double c) {
    if (c >= 0.90) return 'A+';
    if (c >= 0.80) return 'A';
    if (c >= 0.70) return 'B';
    if (c >= 0.60) return 'C';
    if (c >= 0.50) return 'D';
    return 'F';
  }

  /// Percentage + grade, e.g. "78% fit (B)".
  String get compositeLabel =>
      '${(composite * 100).round()}% fit ($grade)';

  /// Percentage string, e.g. "78%".
  String get compositePercent => '${(composite * 100).round()}%';

  /// True when the composite score is above the "Moderate Match" threshold.
  bool get isRecommended => composite >= 0.50;

  /// Returns the weakest axis name (for coaching feedback).
  ///
  /// FIX: replaced per-call Map construction + .entries.reduce() with direct
  /// sequential comparisons — eliminates one heap allocation per call.
  String get weakestAxis {
    double min = skillMatch;
    String name = 'Skill Match';
    if (growthPotential < min) {
      min = growthPotential;
      name = 'Growth Potential';
    }
    if (automationSafety < min) {
      min = automationSafety;
      name = 'Automation Safety';
    }
    if (transitionEase < min) {
      name = 'Transition Ease';
    }
    return name;
  }

  /// Returns the strongest axis name.
  ///
  /// FIX: same allocation fix as [weakestAxis].
  String get strongestAxis {
    double max = skillMatch;
    String name = 'Skill Match';
    if (growthPotential > max) {
      max = growthPotential;
      name = 'Growth Potential';
    }
    if (automationSafety > max) {
      max = automationSafety;
      name = 'Automation Safety';
    }
    if (transitionEase > max) {
      name = 'Transition Ease';
    }
    return name;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          (other is CareerFitScore &&
              other.composite == composite &&
              other.grade == grade);

  @override
  int get hashCode => Object.hash(composite, grade);

  @override
  String toString() =>
      'CareerFitScore(composite: ${composite.toStringAsFixed(2)}, '
          'grade: $grade, skillMatch: ${skillMatch.toStringAsFixed(2)}, '
          'growthPotential: ${growthPotential.toStringAsFixed(2)})';
}

// ═══════════════════════════════════════════════════════════════════════════
// §5  SKILLGAPANALYSIS — per-job/user skill-gap report
// ═══════════════════════════════════════════════════════════════════════════

/// [Alsaif 2022 §4] Detailed skill-gap breakdown for a specific job/user pair.
@immutable
class SkillGapAnalysis {
  final String jobTitle;
  final String jobId;

  /// Skills the user already possesses that this job requires.
  final List<String> matchedSkills;

  /// Skills this job requires that the user does NOT yet possess.
  final List<String> missingSkills;

  /// Proportion of required skills the user already has (0–1).
  final double coverageRatio;

  /// Readiness tier: 'Ready' ≥ 0.80 | 'Almost Ready' ≥ 0.50 | 'Needs Training'.
  final String readinessLabel;

  const SkillGapAnalysis({
    required this.jobTitle,
    required this.jobId,
    required this.matchedSkills,
    required this.missingSkills,
    required this.coverageRatio,
    required this.readinessLabel,
  });

  /// Factory: compute the full gap analysis for [job] given [userSkills].
  factory SkillGapAnalysis.compute(Job job, List<String> userSkills) {
    final lower   = userSkills.map((s) => s.toLowerCase()).toSet();
    final matched = job.skills
        .where((s) => lower.contains(s.toLowerCase()))
        .toList();
    final missing = job.skills
        .where((s) => !lower.contains(s.toLowerCase()))
        .toList();
    final coverage =
    job.skills.isEmpty ? 1.0 : matched.length / job.skills.length;

    final readiness = coverage >= 0.80
        ? 'Ready'
        : coverage >= 0.50
        ? 'Almost Ready'
        : 'Needs Training';

    return SkillGapAnalysis(
      jobTitle      : job.title,
      jobId         : job.id.toString(),
      matchedSkills : List.unmodifiable(matched),
      missingSkills : List.unmodifiable(missing),
      coverageRatio : coverage,
      readinessLabel: readiness,
    );
  }

  /// Coverage formatted as "73% skills matched".
  String get coverageLabel =>
      '${(coverageRatio * 100).round()}% skills matched';

  /// Number of skills the user still needs to acquire.
  int get gapCount => missingSkills.length;

  /// True when the user already meets ≥ 80 % of skill requirements.
  bool get isReady => readinessLabel == 'Ready';

  /// True when the user can close the gap with targeted upskilling.
  bool get isActionable => readinessLabel != 'Needs Training';

  /// Estimated weeks to close the gap (rough heuristic: 3 weeks / skill).
  int get estimatedWeeksToClose => gapCount * 3;

  @override
  String toString() =>
      'SkillGapAnalysis(job: "$jobTitle", coverage: '
          '${(coverageRatio * 100).round()}%, gap: $gapCount skills, '
          'readiness: $readinessLabel)';
}

// ═══════════════════════════════════════════════════════════════════════════
// §6  JOBSTATS — aggregate analytics across a List<Job>
// ═══════════════════════════════════════════════════════════════════════════

/// Aggregate statistics computed across any [List<Job>].
/// Construct via [JobStats.fromJobs].
class JobStats {
  final int total;
  final double meanSimScore;
  final double meanAutomationRisk;
  final Map<String, int> countByIndustry;
  final Map<String, int> countByLevel;
  final Map<String, int> countByWorkingMode;
  final Map<String, int> countByOccupationalGroup;
  final int remoteCount;
  final int trendingCount;
  final int essentialCount;
  final int pivotSkillCount;
  final double meanPostingGrowthRate;

  /// Top-10 most-required skills across the job list (by raw frequency).
  final List<String> topSkills;

  const JobStats({
    required this.total,
    required this.meanSimScore,
    required this.meanAutomationRisk,
    required this.countByIndustry,
    required this.countByLevel,
    required this.countByWorkingMode,
    required this.countByOccupationalGroup,
    required this.remoteCount,
    required this.trendingCount,
    required this.essentialCount,
    required this.pivotSkillCount,
    required this.meanPostingGrowthRate,
    required this.topSkills,
  });

  factory JobStats.fromJobs(List<Job> jobs) {
    if (jobs.isEmpty) {
      return const JobStats(
        total: 0, meanSimScore: 0, meanAutomationRisk: 0,
        countByIndustry: {}, countByLevel: {}, countByWorkingMode: {},
        countByOccupationalGroup: {}, remoteCount: 0, trendingCount: 0,
        essentialCount: 0, pivotSkillCount: 0, meanPostingGrowthRate: 0,
        topSkills: [],
      );
    }

    double simSum    = 0;
    double riskSum   = 0;
    int    riskCount = 0;
    double growthSum = 0;
    int growthCount  = 0;
    final byIndustry = <String, int>{};
    final byLevel    = <String, int>{};
    final byMode     = <String, int>{};
    final byGroup    = <String, int>{};
    final skillFreq  = <String, int>{};

    for (final j in jobs) {
      simSum += j.simScore;
      if (j.automationRisk != null) {
        riskSum  += j.automationRisk!;
        riskCount++;
      }
      if (j.postingGrowthRate != null) {
        growthSum += j.postingGrowthRate!;
        growthCount++;
      }
      byIndustry[j.industry]   = (byIndustry[j.industry]   ?? 0) + 1;
      byLevel[j.level]         = (byLevel[j.level]         ?? 0) + 1;
      byMode[j.workingMode]    = (byMode[j.workingMode]    ?? 0) + 1;
      if (j.occupationalGroup.isNotEmpty) {
        byGroup[j.occupationalGroup] =
            (byGroup[j.occupationalGroup] ?? 0) + 1;
      }
      for (final s in j.skills) {
        final key = s.toLowerCase();
        skillFreq[key] = (skillFreq[key] ?? 0) + 1;
      }
    }

    final topSkills = (skillFreq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)))
        .take(10)
        .map((e) => e.key)
        .toList();

    return JobStats(
      total                 : jobs.length,
      meanSimScore          : simSum / jobs.length,
      meanAutomationRisk    : riskCount > 0 ? riskSum / riskCount : 0.0,
      countByIndustry       : Map.unmodifiable(byIndustry),
      countByLevel          : Map.unmodifiable(byLevel),
      countByWorkingMode    : Map.unmodifiable(byMode),
      countByOccupationalGroup: Map.unmodifiable(byGroup),
      remoteCount           : jobs.where((j) => j.remote).length,
      trendingCount         : jobs.where((j) => j.isTrending).length,
      essentialCount        : jobs.where((j) => j.isEssentialDuringCrisis).length,
      pivotSkillCount       : jobs.where((j) => j.isPivotSkillJob).length,
      meanPostingGrowthRate : growthCount > 0 ? growthSum / growthCount : 0.0,
      topSkills             : topSkills,
    );
  }

  // ── Derived ratios ────────────────────────────────────────────────────────

  double get remoteRatio    => total > 0 ? remoteCount    / total : 0.0;
  double get trendingRatio  => total > 0 ? trendingCount  / total : 0.0;
  double get essentialRatio => total > 0 ? essentialCount / total : 0.0;

  /// Dominant industry by job count.
  String get dominantIndustry =>
      countByIndustry.isEmpty
          ? 'N/A'
          : (countByIndustry.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)))
          .first
          .key;

  @override
  String toString() =>
      'JobStats(total: $total, remote: $remoteCount, '
          'trending: $trendingCount, '
          'topSkill: ${topSkills.isNotEmpty ? topSkills.first : "N/A"})';
}

// ═══════════════════════════════════════════════════════════════════════════
// §7  LEGACY TOP-LEVEL HELPERS (kept for backward compat)
// ═══════════════════════════════════════════════════════════════════════════

/// [Alsaif 2022 §4.3, Table 2] Similarity tier label.
String _localSimScoreLabel(double score) =>
    SimScoreTier.fromScore(score).label;

/// [F&O 2017] Human-readable automation risk label.
String automationRiskLabelFromScore(double? risk) =>
    AutomationRiskTier.fromScore(risk).label;

/// [F&O 2017] Hex colour string for automation risk.
String automationRiskColorFromScore(double? risk) =>
    AutomationRiskTier.fromScore(risk).hexColor;

// ═══════════════════════════════════════════════════════════════════════════
// §8  JOB MODEL
// ═══════════════════════════════════════════════════════════════════════════

@immutable
class Job {
  // ── §8.1  Original fields (unchanged) ─────────────────────────────────────

  final int id;
  final String title;
  final String company;

  /// full-time | part-time | contract | temporary | intern
  final String type;

  /// Entry Level | Mid Level | Senior Level
  final String level;

  final String location;

  /// Salary as display string (BDT or USD depending on regional context).
  final String salary;

  /// Years of experience required.
  final int experience;

  final String industry;
  final bool remote;

  /// Remote | On-site | Hybrid
  final String workingMode;

  final DateTime posted;
  final List<String> skills;

  /// Key benefits derived from JobsFE offer_details column.
  final List<String> benefits;

  // ── §8.2  Session 1 fields (unchanged) ────────────────────────────────────

  /// [Alsaif 2022 §4.3] Weighted cosine similarity score (0–1).
  final double simScore;

  /// [Alsaif 2022 §4] Skill-weighted TF-IDF vector.
  final Map<String, double> weightedSkillVec;

  /// [SDG-8] Short impact label.
  final String sdgImpact;

  /// [Tavakoli 2022 §3.2] True when title/skill cluster is high-occurrence.
  final bool isTrending;

  /// High out-degree in skill-dependency graph.
  final bool isPivotSkillJob;

  /// [Alsaif 2022 §4] Count of user-missing skills for this job.
  final int transitionDistance;

  // ── §8.3  Session 2 fields (unchanged) ────────────────────────────────────

  /// [F&O 2017] Automation probability 0–1.
  final double? automationRisk;

  final bool isEssentialDuringCrisis;

  /// Education proportion map, e.g. {"Bachelor": 0.65, "Master": 0.25}.
  final Map<String, double>? educationRequirements;

  /// Geographic demand map, e.g. {"Dhaka": 0.60, "Chittagong": 0.25}.
  final Map<String, double>? cityDemand;

  /// [Tavakoli 2022 §3.2] Relative posting volume 0–1.
  final double? postingFrequency;

  /// Year-over-year posting growth rate (positive = growing).
  final double? postingGrowthRate;

  final String occupationalGroup;

  /// [RCA] Pre-computed RCA score; RCA > 1.0 → regional comparative advantage.
  final double? rcaScore;

  /// [Alsaif 2022 §4] Transition probability 0–1 for current user profile.
  final double? transitionProbability;

  // ── §8.4  Session 3 new fields ─────────────────────────────────────────────

  /// Pre-attached [CareerFitScore] — populated by [computeCareerFitScores].
  /// Null until explicitly computed.
  final CareerFitScore? careerFitScore;

  /// Pre-attached [SkillGapAnalysis] — populated by [attachSkillGapAnalysis].
  /// Null until explicitly computed.
  final SkillGapAnalysis? skillGapAnalysis;

  // ── §8.5  Constructor ──────────────────────────────────────────────────────

  const Job({
    // Original required fields
    required this.id,
    required this.title,
    required this.company,
    required this.type,
    required this.level,
    required this.location,
    required this.salary,
    required this.experience,
    required this.industry,
    required this.remote,
    required this.workingMode,
    required this.posted,
    required this.skills,
    this.benefits = const [],

    // Session 1
    this.simScore           = 0.0,
    this.weightedSkillVec   = const {},
    this.sdgImpact          = '',
    this.isTrending         = false,
    this.isPivotSkillJob    = false,
    this.transitionDistance = 0,

    // Session 2
    this.automationRisk,
    this.isEssentialDuringCrisis = false,
    this.educationRequirements,
    this.cityDemand,
    this.postingFrequency,
    this.postingGrowthRate,
    this.occupationalGroup       = '',
    this.rcaScore,
    this.transitionProbability,

    // Session 3
    this.careerFitScore,
    this.skillGapAnalysis,
  });

  // ═══════════════════════════════════════════════════════════════════════
  // §8.6  ENUM GETTERS — type-safe views on string fields
  // ═══════════════════════════════════════════════════════════════════════

  /// [JobType] derived from [type] string.
  JobType get jobTypeEnum => JobType.fromString(type);

  /// [JobLevel] derived from [level] string.
  JobLevel get jobLevelEnum => JobLevel.fromString(level);

  /// [WorkingModeEnum] derived from [workingMode] string.
  WorkingModeEnum get workingModeEnum => WorkingModeEnum.fromString(workingMode);

  /// [AutomationRiskTier] derived from [automationRisk] score.
  AutomationRiskTier get automationRiskTier =>
      AutomationRiskTier.fromScore(automationRisk);

  /// [SdgImpactType] parsed from [sdgImpact] string; nullable.
  SdgImpactType? get sdgImpactType => SdgImpactType.fromString(sdgImpact);

  /// [SimScoreTier] derived from [simScore].
  SimScoreTier get simScoreTier => SimScoreTier.fromScore(simScore);

  /// [PostingGrowthCategory] derived from [postingGrowthRate].
  PostingGrowthCategory get postingGrowthCategory =>
      PostingGrowthCategory.fromRate(postingGrowthRate);

  // ═══════════════════════════════════════════════════════════════════════
  // §8.7  SIMILARITY GETTERS [Alsaif 2022 §4.3]
  // ═══════════════════════════════════════════════════════════════════════

  /// Human-readable tier: "Strong Match" | "Moderate Match" | "Weak Match".
  String get simStrength => _localSimScoreLabel(simScore);

  /// True when simScore ≥ 0.75.
  bool get isStrongMatch => simScore >= 0.75;

  /// True when simScore ≥ 0.40.
  bool get isModerateOrBetter => simScore >= 0.40;

  /// Display string, e.g. "Strong Match (82%)".
  String get simLabel {
    final pct = (simScore * 100).round();
    return '$simStrength ($pct%)';
  }

  // ═══════════════════════════════════════════════════════════════════════
  // §8.8  AUTOMATION RISK GETTERS [F&O 2017]
  // ═══════════════════════════════════════════════════════════════════════

  /// "Low Risk" | "Medium Risk" | "High Risk" | "Unknown".
  String get automationRiskLabel =>
      automationRiskLabelFromScore(automationRisk);

  /// Hex colour for the risk tier.
  String get automationRiskColor =>
      automationRiskColorFromScore(automationRisk);

  /// True when automationRisk < 0.30 (low risk).
  bool get isLowAutomationRisk => (automationRisk ?? 1.0) < 0.30;

  // ═══════════════════════════════════════════════════════════════════════
  // §8.9  EDUCATION & GEOGRAPHY GETTERS
  // ═══════════════════════════════════════════════════════════════════════

  /// Qualification label with the highest proportion, or "Not Specified".
  String get primaryEducationRequirement {
    final reqs = educationRequirements;
    if (reqs == null || reqs.isEmpty) return 'Not Specified';
    return reqs.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  /// City/region with the highest demand share, or "Not Specified".
  String get topDemandCity {
    final demand = cityDemand;
    if (demand == null || demand.isEmpty) return 'Not Specified';
    return demand.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  bool get hasEducationData =>
      educationRequirements != null && educationRequirements!.isNotEmpty;

  bool get hasCityDemandData =>
      cityDemand != null && cityDemand!.isNotEmpty;

  // ═══════════════════════════════════════════════════════════════════════
  // §8.10  POSTING GROWTH GETTERS
  // ═══════════════════════════════════════════════════════════════════════

  bool get isGrowing     => (postingGrowthRate ?? 0.0) > 0.0;
  bool get isHighGrowth  => (postingGrowthRate ?? 0.0) > 0.20;
  bool get hasGrowthData => postingGrowthRate != null;

  /// "+15.0%" | "-3.2%" | "N/A"
  String get postingGrowthLabel {
    final rate = postingGrowthRate;
    if (rate == null) return 'N/A';
    final sign = rate >= 0 ? '+' : '';
    return '$sign${(rate * 100).toStringAsFixed(1)}%';
  }

  // ═══════════════════════════════════════════════════════════════════════
  // §8.11  TRANSITION PROBABILITY GETTERS
  // ═══════════════════════════════════════════════════════════════════════

  /// "73%" | "N/A"
  String get transitionProbabilityLabel {
    final prob = transitionProbability;
    if (prob == null) return 'N/A';
    return '${(prob * 100).round()}%';
  }

  // ═══════════════════════════════════════════════════════════════════════
  // §8.12  RCA GETTERS [RCA]
  // ═══════════════════════════════════════════════════════════════════════

  /// "Comparative Advantage" | "Near Parity" | "Below Average" | "N/A".
  String get rcaStatus {
    final r = rcaScore;
    if (r == null) return 'N/A';
    if (r >= 1.25) return 'Comparative Advantage';
    if (r >= 0.75) return 'Near Parity';
    return 'Below Average';
  }

  // ═══════════════════════════════════════════════════════════════════════
  // §8.13  POSTING DATE GETTERS
  // ═══════════════════════════════════════════════════════════════════════

  /// Days elapsed since the job was posted.
  int get daysPosted => DateTime.now().difference(posted).inDays.abs();

  /// True when the job was posted within the last 7 days.
  bool get isFreshPosting => daysPosted <= 7;

  /// True when the job was posted within the last 30 days.
  bool get isActivePosting => daysPosted <= 30;

  // ═══════════════════════════════════════════════════════════════════════
  // §8.14  EXPERIENCE LABEL
  // ═══════════════════════════════════════════════════════════════════════

  /// Human-readable experience requirement.
  String get experienceLabel {
    if (experience == 0) return 'No experience required';
    if (experience == 1) return '1 year';
    return '$experience years';
  }

  // ═══════════════════════════════════════════════════════════════════════
  // §8.15  COMPOSITE CONVENIENCE PREDICATES
  // ═══════════════════════════════════════════════════════════════════════

  /// True when both essential and low-automation-risk — highest resilience.
  bool get isEssentialAndLowRisk =>
      isEssentialDuringCrisis && isLowAutomationRisk;

  /// True when trending, growing, and low automation risk.
  bool get isFutureProof =>
      isTrending && isHighGrowth && isLowAutomationRisk;

  /// True when entry-level, no experience required, and posted recently.
  bool get isEntryFriendly =>
      jobLevelEnum == JobLevel.entry &&
          experience == 0 &&
          isActivePosting;

  // ═══════════════════════════════════════════════════════════════════════
  // §8.16  ORIGINAL INSTANCE METHODS
  // ═══════════════════════════════════════════════════════════════════════

  /// Skills this job requires that are absent from [userSkills].
  List<String> missingSkills(List<String> userSkills) {
    final lower = userSkills.map((s) => s.toLowerCase()).toSet();
    return skills
        .where((skill) => !lower.contains(skill.toLowerCase()))
        .toList();
  }

  /// Simple overlap ratio (0–1).  For weighted cosine see [simScore].
  double matchScore(List<String> userSkills) {
    if (skills.isEmpty) return 0.0;
    final lower   = userSkills.map((s) => s.toLowerCase()).toSet();
    final matched =
        skills.where((s) => lower.contains(s.toLowerCase())).length;
    return (matched / skills.length).clamp(0.0, 1.0);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // §8.17  NEW INSTANCE METHODS (Session 3)
  // ═══════════════════════════════════════════════════════════════════════

  /// [Alsaif 2022 §4] Count of missing skills (live computation).
  int computeTransitionDistance(List<String> userSkills) =>
      missingSkills(userSkills).length;

  /// [Tavakoli 2022 §3.5.1] True if this job requires [skill] (case-insensitive).
  bool requiresSkill(String skill) {
    final needle = skill.toLowerCase();
    return skills.any((s) => s.toLowerCase() == needle);
  }

  /// Compute and return a fresh [CareerFitScore] for [userSkills].
  CareerFitScore computeCareerFit(List<String> userSkills) =>
      CareerFitScore.compute(this, userSkills);

  /// Compute and return a fresh [SkillGapAnalysis] for [userSkills].
  SkillGapAnalysis computeSkillGap(List<String> userSkills) =>
      SkillGapAnalysis.compute(this, userSkills);

  /// True when the user's skills cover at least [threshold] proportion
  /// of the required skills.
  bool meetsSkillThreshold(List<String> userSkills,
      {double threshold = 0.80}) {
    if (skills.isEmpty) return true;
    return matchScore(userSkills) >= threshold;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // §8.18  FACTORY HELPERS
  // ═══════════════════════════════════════════════════════════════════════

  /// [Alsaif 2022 §4.3] Immutable copy with a new simScore applied.
  factory Job.fromSimScore(Job source, {required double score}) =>
      source.copyWith(simScore: score.clamp(0.0, 1.0));

  // ═══════════════════════════════════════════════════════════════════════
  // §8.19  copyWith
  // ═══════════════════════════════════════════════════════════════════════

  /// Immutable update.  Uses [_Unset] sentinel for nullable fields so the
  /// caller can explicitly pass `null` to clear a field.
  /// Boolean `clear*` flags are preserved for backward compatibility.
  Job copyWith({
    // Original fields
    int? id,
    String? title,
    String? company,
    String? type,
    String? level,
    String? location,
    String? salary,
    int? experience,
    String? industry,
    bool? remote,
    String? workingMode,
    DateTime? posted,
    List<String>? skills,
    List<String>? benefits,

    // Session 1
    double? simScore,
    Map<String, double>? weightedSkillVec,
    String? sdgImpact,
    bool? isTrending,
    bool? isPivotSkillJob,
    int? transitionDistance,

    // Session 2 — nullable via sentinel
    Object? automationRisk          = _unset,
    bool? isEssentialDuringCrisis,
    Object? educationRequirements   = _unset,
    Object? cityDemand              = _unset,
    Object? postingFrequency        = _unset,
    Object? postingGrowthRate       = _unset,
    String? occupationalGroup,
    Object? rcaScore                = _unset,
    Object? transitionProbability   = _unset,

    // Session 2 — legacy boolean clear flags (still supported)
    bool clearAutomationRisk        = false,
    bool clearEducationRequirements = false,
    bool clearCityDemand            = false,
    bool clearPostingFrequency      = false,
    bool clearPostingGrowthRate     = false,
    bool clearRcaScore              = false,
    bool clearTransitionProbability = false,

    // Session 3
    Object? careerFitScore          = _unset,
    Object? skillGapAnalysis        = _unset,
  }) {
    return Job(
      id              : id              ?? this.id,
      title           : title           ?? this.title,
      company         : company         ?? this.company,
      type            : type            ?? this.type,
      level           : level           ?? this.level,
      location        : location        ?? this.location,
      salary          : salary          ?? this.salary,
      experience      : experience      ?? this.experience,
      industry        : industry        ?? this.industry,
      remote          : remote          ?? this.remote,
      workingMode     : workingMode     ?? this.workingMode,
      posted          : posted          ?? this.posted,
      skills          : skills          ?? this.skills,
      benefits        : benefits        ?? this.benefits,
      simScore        : simScore        ?? this.simScore,
      weightedSkillVec: weightedSkillVec ?? this.weightedSkillVec,
      sdgImpact       : sdgImpact       ?? this.sdgImpact,
      isTrending      : isTrending      ?? this.isTrending,
      isPivotSkillJob : isPivotSkillJob  ?? this.isPivotSkillJob,
      transitionDistance: transitionDistance ?? this.transitionDistance,
      automationRisk  : clearAutomationRisk
          ? null
          : (automationRisk is _Unset
          ? this.automationRisk
          : automationRisk as double?),
      isEssentialDuringCrisis:
      isEssentialDuringCrisis ?? this.isEssentialDuringCrisis,
      educationRequirements: clearEducationRequirements
          ? null
          : (educationRequirements is _Unset
          ? this.educationRequirements
          : educationRequirements as Map<String, double>?),
      cityDemand      : clearCityDemand
          ? null
          : (cityDemand is _Unset
          ? this.cityDemand
          : cityDemand as Map<String, double>?),
      postingFrequency: clearPostingFrequency
          ? null
          : (postingFrequency is _Unset
          ? this.postingFrequency
          : postingFrequency as double?),
      postingGrowthRate: clearPostingGrowthRate
          ? null
          : (postingGrowthRate is _Unset
          ? this.postingGrowthRate
          : postingGrowthRate as double?),
      occupationalGroup: occupationalGroup ?? this.occupationalGroup,
      rcaScore        : clearRcaScore
          ? null
          : (rcaScore is _Unset ? this.rcaScore : rcaScore as double?),
      transitionProbability: clearTransitionProbability
          ? null
          : (transitionProbability is _Unset
          ? this.transitionProbability
          : transitionProbability as double?),
      careerFitScore  : careerFitScore is _Unset
          ? this.careerFitScore
          : careerFitScore as CareerFitScore?,
      skillGapAnalysis: skillGapAnalysis is _Unset
          ? this.skillGapAnalysis
          : skillGapAnalysis as SkillGapAnalysis?,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // §8.20  SERIALISATION — toMap / fromMap
  // ═══════════════════════════════════════════════════════════════════════

  Map<String, dynamic> toMap() {
    return {
      // Original
      'id'         : id,
      'title'      : title,
      'company'    : company,
      'type'       : type,
      'level'      : level,
      'location'   : location,
      'salary'     : salary,
      'experience' : experience,
      'industry'   : industry,
      'remote'     : remote,
      'workingMode': workingMode,
      'posted'     : posted.millisecondsSinceEpoch,
      'skills'     : skills,
      'benefits'   : benefits,
      // Session 1
      'simScore'           : simScore,
      'weightedSkillVec'   : weightedSkillVec,
      'sdgImpact'          : sdgImpact,
      'isTrending'         : isTrending,
      'isPivotSkillJob'    : isPivotSkillJob,
      'transitionDistance' : transitionDistance,
      // Session 2
      'automationRisk'          : automationRisk,
      'isEssentialDuringCrisis' : isEssentialDuringCrisis,
      'educationRequirements'   : educationRequirements,
      'cityDemand'              : cityDemand,
      'postingFrequency'        : postingFrequency,
      'postingGrowthRate'       : postingGrowthRate,
      'occupationalGroup'       : occupationalGroup,
      'rcaScore'                : rcaScore,
      'transitionProbability'   : transitionProbability,
      // Session 3 — computed objects are NOT persisted (re-computed on load)
    };
  }

  factory Job.fromMap(Map<String, dynamic> map) {
    Map<String, double>? parseDoubleMap(dynamic raw) {
      if (raw == null) return null;
      if (raw is Map<String, double>) return raw;
      try {
        return (raw as Map)
            .map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
      } catch (_) {
        return null;
      }
    }

    return Job(
      // Original
      id          : (map['id']         as num?)?.toInt() ?? 0,
      title       : (map['title']      as String?)       ?? '',
      company     : (map['company']    as String?)       ?? '',
      type        : (map['type']       as String?)       ?? 'full-time',
      level       : (map['level']      as String?)       ?? 'Entry Level',
      location    : (map['location']   as String?)       ?? '',
      salary      : (map['salary']     as String?)       ?? '',
      experience  : (map['experience'] as num?)?.toInt() ?? 0,
      industry    : (map['industry']   as String?)       ?? '',
      remote      : (map['remote']     as bool?)         ?? false,
      workingMode : (map['workingMode'] as String?)      ?? 'On-site',
      posted      : map['posted'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
          (map['posted'] as num).toInt())
          : DateTime.now(),
      skills      : _castStringList(map['skills']),
      benefits    : _castStringList(map['benefits']),
      // Session 1
      simScore           : (map['simScore']           as num?)?.toDouble() ?? 0.0,
      weightedSkillVec   : parseDoubleMap(map['weightedSkillVec']) ?? const {},
      sdgImpact          : (map['sdgImpact']          as String?) ?? '',
      isTrending         : (map['isTrending']         as bool?)   ?? false,
      isPivotSkillJob    : (map['isPivotSkillJob']    as bool?)   ?? false,
      transitionDistance : (map['transitionDistance'] as num?)?.toInt() ?? 0,
      // Session 2
      automationRisk        : (map['automationRisk']        as num?)?.toDouble(),
      isEssentialDuringCrisis:
      (map['isEssentialDuringCrisis'] as bool?) ?? false,
      educationRequirements : parseDoubleMap(map['educationRequirements']),
      cityDemand            : parseDoubleMap(map['cityDemand']),
      postingFrequency      : (map['postingFrequency']      as num?)?.toDouble(),
      postingGrowthRate     : (map['postingGrowthRate']     as num?)?.toDouble(),
      occupationalGroup     : (map['occupationalGroup']     as String?) ?? '',
      rcaScore              : (map['rcaScore']              as num?)?.toDouble(),
      transitionProbability : (map['transitionProbability'] as num?)?.toDouble(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // §8.21  EQUALITY, HASH, toString
  // ═══════════════════════════════════════════════════════════════════════

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          (other is Job &&
              other.id      == id &&
              other.title   == title &&
              other.company == company);

  @override
  int get hashCode => Object.hash(id, title, company);

  @override
  String toString() =>
      'Job(id: $id, title: "$title", industry: "$industry", '
          'simScore: ${simScore.toStringAsFixed(2)} ($simStrength), '
          'automationRisk: ${automationRisk?.toStringAsFixed(2) ?? "null"} '
          '($automationRiskLabel), '
          'isTrending: $isTrending, '
          'transitionDistance: $transitionDistance, '
          'rcaScore: ${rcaScore?.toStringAsFixed(3) ?? "null"}, '
          'postingGrowthRate: $postingGrowthLabel, '
          'isFutureProof: $isFutureProof)';
}

// ═══════════════════════════════════════════════════════════════════════════
// §9  JOB EXTENSIONS
// ═══════════════════════════════════════════════════════════════════════════

extension JobComparison on Job {
  /// Compare automation risk to another job (lower = safer = 1 wins).
  int compareAutomationRiskTo(Job other) {
    final a = automationRisk ?? 0.5;
    final b = other.automationRisk ?? 0.5;
    return a.compareTo(b);
  }

  /// Compare posting growth — higher growth wins (descending).
  int compareGrowthTo(Job other) {
    final a = postingGrowthRate ?? 0.0;
    final b = other.postingGrowthRate ?? 0.0;
    return b.compareTo(a);
  }

  /// Compare similarity scores — higher wins (descending).
  int compareSimScoreTo(Job other) => other.simScore.compareTo(simScore);
}

extension JobNullableHelpers on Job {
  /// Returns [automationRisk] formatted to 2 dp, or "N/A".
  String get automationRiskDisplay =>
      automationRisk != null
          ? automationRisk!.toStringAsFixed(2)
          : 'N/A';

  /// Returns [rcaScore] formatted to 3 dp, or "N/A".
  String get rcaScoreDisplay =>
      rcaScore != null ? rcaScore!.toStringAsFixed(3) : 'N/A';

  /// Returns [postingFrequency] as a percentage string, or "N/A".
  String get postingFrequencyDisplay =>
      postingFrequency != null
          ? '${(postingFrequency! * 100).round()}%'
          : 'N/A';
}

// ═══════════════════════════════════════════════════════════════════════════
// §10  PRIVATE HELPERS
// ═══════════════════════════════════════════════════════════════════════════

/// Returns a growable-friendly list of strings from a dynamic value.
/// Intentionally returns const [] (unmodifiable) — no call site mutates the
/// result. If mutation is ever needed, change to return [].
List<String> _castStringList(dynamic raw) {
  if (raw == null) return const [];
  if (raw is List<String>) return raw;
  try {
    return (raw as List).map((e) => e.toString()).toList();
  } catch (_) {
    return const [];
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// §11  INDUSTRY & ICON HELPERS (unchanged)
// ═══════════════════════════════════════════════════════════════════════════

Color industryColor(String industry) {
  switch (industry) {
    case 'Software':      return Colors.blue.shade700;
    case 'Finance':       return Colors.green.shade700;
    case 'Healthcare':    return Colors.red.shade700;
    case 'Marketing':     return Colors.purple.shade700;
    case 'Manufacturing': return Colors.orange.shade700;
    case 'Retail':        return Colors.pink.shade700;
    case 'Education':     return Colors.teal.shade700;
    default:              return Colors.grey.shade700;
  }
}

IconData industryIcon(String industry) {
  switch (industry) {
    case 'Software':      return Icons.code_rounded;
    case 'Finance':       return Icons.account_balance_outlined;
    case 'Healthcare':    return Icons.local_hospital_outlined;
    case 'Marketing':     return Icons.campaign_outlined;
    case 'Manufacturing': return Icons.precision_manufacturing_outlined;
    case 'Retail':        return Icons.storefront_outlined;
    case 'Education':     return Icons.school_outlined;
    default:              return Icons.work_outline_rounded;
  }
}

/// Flutter [Color] for automation risk tier.
///
/// @deprecated Use [AutomationRiskTier.fromScore(risk).color] directly.
/// This wrapper is kept for backward compatibility and will be removed in a
/// future session.
@Deprecated(
  'Use AutomationRiskTier.fromScore(risk).color instead. '
      'This function duplicates AutomationRiskTier.color and will be removed.',
)
Color automationRiskFlutterColor(double? risk) =>
    AutomationRiskTier.fromScore(risk).color;

// ═══════════════════════════════════════════════════════════════════════════
// §12  CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════

const List<String> allIndustries = [
  'All', 'Software', 'Finance', 'Healthcare',
  'Marketing', 'Manufacturing', 'Retail', 'Education',
];

const List<String> allLevels = [
  'All', 'Entry Level', 'Mid Level', 'Senior Level',
];

const List<String> allOccupationalGroups = [
  'All', 'Technology', 'Healthcare', 'Finance',
  'Creative', 'Operations', 'Education', 'Sales',
];

const List<String> allSdgImpacts = [
  'Decent Work', 'Skills Training', 'Youth Employment',
  'Inclusive Growth', 'Productivity',
];

// Benefits bundles sampled from JobsFE offer_details.
const _b1 = ['Health insurance', 'Retirement plans', 'Paid time off', 'Flexible work'];
const _b2 = ['Tuition reimbursement', 'Parental leave', 'Wellness programs', 'Bonuses'];
const _b3 = ['Professional development', 'Profit sharing', 'Employee discounts', 'Transport'];
const _b4 = ['Stock options', 'Employee recognition', 'Life insurance', 'Casual dress code'];
const _b5 = ['Childcare assistance', 'Relocation assistance', 'Financial counseling', 'EAP'];

// ═══════════════════════════════════════════════════════════════════════════
// §13  JOB DATA (45 jobs, unchanged from Session 2)
// ═══════════════════════════════════════════════════════════════════════════

final List<Job> allJobs = [

  // ════════════════ SOFTWARE (12) ════════════════════════════════════════

  Job(
    id: 1, title: 'Junior Data Analyst', company: 'Tech Solutions Ltd.',
    type: 'full-time', level: 'Entry Level', location: 'Remote',
    salary: '30k–45k BDT', experience: 0, industry: 'Software',
    remote: true, workingMode: 'Remote', posted: DateTime(2026, 1, 28),
    skills: const ['python', 'sql', 'excel', 'data analysis', 'pandas', 'reporting'],
    benefits: _b1,
    sdgImpact: 'Decent Work', isTrending: true, isPivotSkillJob: true,
    transitionDistance: 0,
    automationRisk: 0.65, isEssentialDuringCrisis: false,
    educationRequirements: const {'Bachelor': 0.60, 'Master': 0.30, 'Self-taught': 0.10},
    cityDemand: const {'Dhaka': 0.55, 'Chittagong': 0.25, 'Sylhet': 0.20},
    postingFrequency: 0.72, postingGrowthRate: 0.18,
    occupationalGroup: 'Technology',
  ),

  Job(
    id: 2, title: 'Flutter Developer', company: 'MobileSoft Ltd.',
    type: 'full-time', level: 'Mid Level', location: 'London',
    salary: r'$82,500', experience: 1, industry: 'Software',
    remote: false, workingMode: 'On-site', posted: DateTime(2026, 1, 30),
    skills: const ['dart', 'flutter', 'firebase', 'rest api', 'state management', 'ui'],
    benefits: _b2,
    sdgImpact: 'Productivity', isTrending: true, isPivotSkillJob: false,
    automationRisk: 0.04, isEssentialDuringCrisis: false,
    educationRequirements: const {'Bachelor': 0.55, 'Master': 0.20, 'Self-taught': 0.25},
    cityDemand: const {'London': 0.45, 'Manchester': 0.25, 'Remote-UK': 0.30},
    postingFrequency: 0.68, postingGrowthRate: 0.25,
    occupationalGroup: 'Technology',
  ),

  Job(
    id: 3, title: 'Web Developer (React)', company: 'TechWave',
    type: 'full-time', level: 'Mid Level', location: 'Dhaka',
    salary: '45k–65k BDT', experience: 1, industry: 'Software',
    remote: false, workingMode: 'On-site', posted: DateTime(2026, 1, 27),
    skills: const ['javascript', 'react', 'html', 'css', 'responsive design', 'api integration'],
    benefits: _b3,
    sdgImpact: 'Youth Employment', isTrending: true, isPivotSkillJob: true,
    automationRisk: 0.08, isEssentialDuringCrisis: false,
    educationRequirements: const {'Bachelor': 0.50, 'Self-taught': 0.35, 'Diploma': 0.15},
    cityDemand: const {'Dhaka': 0.70, 'Chittagong': 0.20, 'Khulna': 0.10},
    postingFrequency: 0.80, postingGrowthRate: 0.20,
    occupationalGroup: 'Technology',
  ),

  Job(
    id: 4, title: 'Machine Learning Engineer', company: 'AI Labs Inc.',
    type: 'full-time', level: 'Mid Level', location: 'San Francisco',
    salary: r'$97,500', experience: 2, industry: 'Software',
    remote: true, workingMode: 'Remote', posted: DateTime(2026, 1, 28),
    skills: const ['python', 'machine learning', 'scikit-learn', 'pandas', 'numpy', 'tensorflow'],
    benefits: _b4,
    sdgImpact: 'Productivity', isTrending: true, isPivotSkillJob: true,
    automationRisk: 0.03, isEssentialDuringCrisis: false,
    educationRequirements: const {'Master': 0.50, 'Bachelor': 0.30, 'PhD': 0.20},
    cityDemand: const {'San Francisco': 0.40, 'New York': 0.25, 'Seattle': 0.20, 'Remote-US': 0.15},
    postingFrequency: 0.88, postingGrowthRate: 0.35,
    occupationalGroup: 'Technology',
  ),

  Job(
    id: 5, title: 'Software Engineer', company: 'TechCore Solutions',
    type: 'full-time', level: 'Entry Level', location: 'Remote',
    salary: r'$75,500', experience: 0, industry: 'Software',
    remote: true, workingMode: 'Remote', posted: DateTime(2026, 2, 10),
    skills: const ['python', 'java', 'sql', 'git', 'problem solving', 'oop'],
    benefits: _b1,
    sdgImpact: 'Youth Employment', isTrending: true, isPivotSkillJob: true,
    automationRisk: 0.04, isEssentialDuringCrisis: false,
    educationRequirements: const {'Bachelor': 0.65, 'Master': 0.20, 'Self-taught': 0.15},
    cityDemand: const {'Remote-US': 0.50, 'New York': 0.25, 'Austin': 0.25},
    postingFrequency: 0.95, postingGrowthRate: 0.12,
    occupationalGroup: 'Technology',
  ),

  Job(
    id: 6, title: 'Backend Developer (Node.js)', company: 'CloudNext Systems',
    type: 'full-time', level: 'Mid Level', location: 'Remote',
    salary: r'$90,000', experience: 1, industry: 'Software',
    remote: true, workingMode: 'Remote', posted: DateTime(2026, 2, 1),
    skills: const ['javascript', 'node.js', 'express', 'mongodb', 'rest api', 'sql'],
    benefits: _b2,
    sdgImpact: 'Decent Work', isTrending: false, isPivotSkillJob: false,
    automationRisk: 0.05, isEssentialDuringCrisis: false,
    educationRequirements: const {'Bachelor': 0.55, 'Self-taught': 0.30, 'Master': 0.15},
    cityDemand: const {'Remote-US': 0.60, 'New York': 0.20, 'Chicago': 0.20},
    postingFrequency: 0.74, postingGrowthRate: 0.10,
    occupationalGroup: 'Technology',
  ),

  Job(
    id: 7, title: 'Network Engineer', company: 'NetSecure Ltd.',
    type: 'full-time', level: 'Mid Level', location: 'New York',
    salary: r'$85,500', experience: 2, industry: 'Software',
    remote: false, workingMode: 'Hybrid', posted: DateTime(2026, 2, 12),
    skills: const ['networking', 'aws', 'linux', 'cybersecurity', 'troubleshooting', 'cloud computing'],
    benefits: _b3,
    sdgImpact: 'Productivity', isTrending: true, isPivotSkillJob: false,
    automationRisk: 0.30, isEssentialDuringCrisis: true,
    educationRequirements: const {'Bachelor': 0.60, 'Master': 0.15, 'Certification': 0.25},
    cityDemand: const {'New York': 0.35, 'Washington DC': 0.30, 'San Francisco': 0.35},
    postingFrequency: 0.78, postingGrowthRate: 0.08,
    occupationalGroup: 'Technology',
  ),

  Job(
    id: 8, title: 'Software Tester / QA Engineer', company: 'QualityFirst Tech',
    type: 'contract', level: 'Entry Level', location: 'Remote',
    salary: r'$72,500', experience: 0, industry: 'Software',
    remote: true, workingMode: 'Remote', posted: DateTime(2026, 2, 8),
    skills: const ['software testing', 'qa', 'python', 'sql', 'automated testing', 'bug tracking'],
    benefits: _b4,
    sdgImpact: 'Youth Employment', isTrending: true, isPivotSkillJob: false,
    automationRisk: 0.52, isEssentialDuringCrisis: false,
    educationRequirements: const {'Bachelor': 0.55, 'Self-taught': 0.30, 'Diploma': 0.15},
    cityDemand: const {'Remote-US': 0.50, 'Austin': 0.25, 'Raleigh': 0.25},
    postingFrequency: 0.70, postingGrowthRate: 0.05,
    occupationalGroup: 'Technology',
  ),

  Job(
    id: 9, title: 'UI Developer', company: 'PixelCraft Studios',
    type: 'full-time', level: 'Mid Level', location: 'Berlin',
    salary: r'$82,000', experience: 2, industry: 'Software',
    remote: false, workingMode: 'Hybrid', posted: DateTime(2026, 2, 5),
    skills: const ['javascript', 'react', 'html', 'css', 'figma', 'responsive design'],
    benefits: _b5,
    sdgImpact: 'Decent Work', isTrending: false, isPivotSkillJob: false,
    automationRisk: 0.07, isEssentialDuringCrisis: false,
    educationRequirements: const {'Bachelor': 0.45, 'Self-taught': 0.40, 'Master': 0.15},
    cityDemand: const {'Berlin': 0.40, 'Munich': 0.30, 'Hamburg': 0.30},
    postingFrequency: 0.65, postingGrowthRate: 0.09,
    occupationalGroup: 'Technology',
  ),

  Job(
    id: 10, title: 'Systems Administrator', company: 'DataSphere Corp.',
    type: 'full-time', level: 'Mid Level', location: 'Chicago',
    salary: r'$82,500', experience: 3, industry: 'Software',
    remote: false, workingMode: 'On-site', posted: DateTime(2026, 1, 20),
    skills: const ['linux', 'aws', 'networking', 'cloud computing', 'scripting', 'troubleshooting'],
    benefits: _b1,
    sdgImpact: 'Productivity', isTrending: false, isPivotSkillJob: false,
    automationRisk: 0.40, isEssentialDuringCrisis: true,
    educationRequirements: const {'Bachelor': 0.55, 'Certification': 0.30, 'Master': 0.15},
    cityDemand: const {'Chicago': 0.40, 'Detroit': 0.30, 'Indianapolis': 0.30},
    postingFrequency: 0.60, postingGrowthRate: -0.02,
    occupationalGroup: 'Technology',
  ),

  Job(
    id: 11, title: 'DevOps Engineer', company: 'CloudOps Inc.',
    type: 'full-time', level: 'Senior Level', location: 'Dhaka',
    salary: '60k–80k BDT', experience: 4, industry: 'Software',
    remote: false, workingMode: 'Hybrid', posted: DateTime(2026, 2, 10),
    skills: const ['docker', 'kubernetes', 'aws', 'ci/cd', 'linux', 'scripting', 'cloud computing'],
    benefits: _b2,
    sdgImpact: 'Productivity', isTrending: true, isPivotSkillJob: false,
    automationRisk: 0.06, isEssentialDuringCrisis: true,
    educationRequirements: const {'Bachelor': 0.60, 'Master': 0.20, 'Certification': 0.20},
    cityDemand: const {'Dhaka': 0.65, 'Chittagong': 0.20, 'Sylhet': 0.15},
    postingFrequency: 0.82, postingGrowthRate: 0.30,
    occupationalGroup: 'Technology',
  ),

  Job(
    id: 12, title: 'Data Science Intern', company: 'Innovate Analytics',
    type: 'intern', level: 'Entry Level', location: 'Remote',
    salary: r'$67,500', experience: 0, industry: 'Software',
    remote: true, workingMode: 'Remote', posted: DateTime(2026, 2, 14),
    skills: const ['python', 'pandas', 'numpy', 'machine learning', 'data analysis', 'sql'],
    benefits: _b3,
    sdgImpact: 'Skills Training', isTrending: true, isPivotSkillJob: true,
    automationRisk: 0.60, isEssentialDuringCrisis: false,
    educationRequirements: const {'Bachelor': 0.50, 'Master': 0.40, 'PhD': 0.10},
    cityDemand: const {'Remote-US': 0.55, 'New York': 0.25, 'Boston': 0.20},
    postingFrequency: 0.55, postingGrowthRate: 0.22,
    occupationalGroup: 'Technology',
  ),

  // ════════════════ FINANCE (8) ══════════════════════════════════════════

  Job(
    id: 13, title: 'Financial Analyst', company: 'GlobalBank PLC',
    type: 'full-time', level: 'Entry Level', location: 'London',
    salary: r'$72,500', experience: 0, industry: 'Finance',
    remote: false, workingMode: 'Hybrid', posted: DateTime(2026, 2, 12),
    skills: const ['financial modeling', 'excel', 'sql', 'risk analysis', 'data analysis'],
    benefits: _b1,
    sdgImpact: 'Inclusive Growth', isTrending: true, isPivotSkillJob: true,
    automationRisk: 0.58, isEssentialDuringCrisis: true,
    educationRequirements: const {'Bachelor': 0.55, 'Master': 0.35, 'CFA/CPA': 0.10},
    cityDemand: const {'London': 0.50, 'Manchester': 0.25, 'Edinburgh': 0.25},
    postingFrequency: 0.78, postingGrowthRate: 0.07,
    occupationalGroup: 'Finance',
  ),

  Job(
    id: 14, title: 'Junior Data Analyst (Finance)', company: 'FinTech Analytics',
    type: 'full-time', level: 'Entry Level', location: 'Remote',
    salary: r'$75,500', experience: 0, industry: 'Finance',
    remote: true, workingMode: 'Remote', posted: DateTime(2026, 2, 3),
    skills: const ['python', 'sql', 'excel', 'data analysis', 'financial modeling', 'reporting'],
    benefits: _b2,
    sdgImpact: 'Decent Work', isTrending: true, isPivotSkillJob: true,
    automationRisk: 0.62, isEssentialDuringCrisis: false,
    educationRequirements: const {'Bachelor': 0.60, 'Master': 0.30, 'Self-taught': 0.10},
    cityDemand: const {'Remote-US': 0.50, 'New York': 0.30, 'Chicago': 0.20},
    postingFrequency: 0.72, postingGrowthRate: 0.15,
    occupationalGroup: 'Finance',
  ),

  Job(
    id: 15, title: 'Risk Analyst', company: 'Apex Capital',
    type: 'full-time', level: 'Mid Level', location: 'New York',
    salary: r'$95,000', experience: 2, industry: 'Finance',
    remote: false, workingMode: 'On-site', posted: DateTime(2026, 1, 22),
    skills: const ['risk analysis', 'python', 'sql', 'financial modeling', 'statistics', 'excel'],
    benefits: _b4,
    sdgImpact: 'Inclusive Growth', isTrending: true, isPivotSkillJob: false,
    automationRisk: 0.45, isEssentialDuringCrisis: true,
    educationRequirements: const {'Master': 0.50, 'Bachelor': 0.40, 'FRM/PRM': 0.10},
    cityDemand: const {'New York': 0.55, 'Chicago': 0.25, 'Boston': 0.20},
    postingFrequency: 0.76, postingGrowthRate: 0.10,
    occupationalGroup: 'Finance',
  ),

  Job(
    id: 16, title: 'Financial Advisor', company: 'WealthPath Advisory',
    type: 'full-time', level: 'Mid Level', location: 'Sydney',
    salary: r'$87,500', experience: 2, industry: 'Finance',
    remote: false, workingMode: 'Hybrid', posted: DateTime(2026, 2, 9),
    skills: const ['financial modeling', 'risk analysis', 'excel', 'communication skills', 'reporting', 'statistics'],
    benefits: _b3,
    sdgImpact: 'Decent Work', isTrending: true, isPivotSkillJob: false,
    automationRisk: 0.58, isEssentialDuringCrisis: false,
    educationRequirements: const {'Bachelor': 0.60, 'Master': 0.25, 'CFP': 0.15},
    cityDemand: const {'Sydney': 0.45, 'Melbourne': 0.35, 'Brisbane': 0.20},
    postingFrequency: 0.80, postingGrowthRate: 0.06,
    occupationalGroup: 'Finance',
  ),

  Job(
    id: 17, title: 'Account Manager', company: 'Prime Investments',
    type: 'full-time', level: 'Mid Level', location: 'Toronto',
    salary: r'$82,500', experience: 2, industry: 'Finance',
    remote: false, workingMode: 'Hybrid', posted: DateTime(2026, 2, 7),
    skills: const ['account management', 'financial modeling', 'excel', 'client relations', 'communication skills'],
    benefits: _b5,
    sdgImpact: 'Decent Work', isTrending: false, isPivotSkillJob: false,
    automationRisk: 0.55, isEssentialDuringCrisis: false,
    educationRequirements: const {'Bachelor': 0.65, 'Master': 0.25, 'Self-taught': 0.10},
    cityDemand: const {'Toronto': 0.55, 'Vancouver': 0.25, 'Ottawa': 0.20},
    postingFrequency: 0.65, postingGrowthRate: 0.03,
    occupationalGroup: 'Finance',
  ),

  Job(
    id: 18, title: 'HR Coordinator', company: 'PeopleFirst Ltd.',
    type: 'full-time', level: 'Entry Level', location: 'London',
    salary: r'$69,500', experience: 0, industry: 'Finance',
    remote: false, workingMode: 'Hybrid', posted: DateTime(2026, 2, 6),
    skills: const ['communication skills', 'recruitment', 'excel', 'reporting', 'team leadership'],
    benefits: _b1,
    sdgImpact: 'Youth Employment', isTrending: false, isPivotSkillJob: false,
    automationRisk: 0.55, isEssentialDuringCrisis: false,
    educationRequirements: const {'Bachelor': 0.65, 'Master': 0.20, 'CIPD': 0.15},
    cityDemand: const {'London': 0.50, 'Birmingham': 0.25, 'Manchester': 0.25},
    postingFrequency: 0.62, postingGrowthRate: 0.04,
    occupationalGroup: 'Operations',
  ),

  Job(
    id: 19, title: 'Investment Analyst (Intern)', company: 'BlueSky Capital',
    type: 'intern', level: 'Entry Level', location: 'Remote',
    salary: r'$67,500', experience: 0, industry: 'Finance',
    remote: true, workingMode: 'Remote', posted: DateTime(2026, 2, 14),
    skills: const ['financial modeling', 'excel', 'data analysis', 'sql', 'reporting'],
    benefits: _b2,
    sdgImpact: 'Skills Training', isTrending: false, isPivotSkillJob: false,
    automationRisk: 0.60, isEssentialDuringCrisis: false,
    educationRequirements: const {'Bachelor': 0.60, 'Master': 0.35, 'CFA (in progress)': 0.05},
    cityDemand: const {'Remote-US': 0.50, 'New York': 0.30, 'Boston': 0.20},
    postingFrequency: 0.50, postingGrowthRate: 0.08,
    occupationalGroup: 'Finance',
  ),

  Job(
    id: 20, title: 'Senior Risk Manager', company: 'Meridian Bank',
    type: 'contract', level: 'Senior Level', location: 'Frankfurt',
    salary: r'$97,500', experience: 6, industry: 'Finance',
    remote: false, workingMode: 'On-site', posted: DateTime(2026, 1, 15),
    skills: const ['risk analysis', 'financial modeling', 'python', 'statistics', 'reporting', 'team leadership'],
    benefits: _b4,
    sdgImpact: 'Inclusive Growth', isTrending: true, isPivotSkillJob: false,
    automationRisk: 0.38, isEssentialDuringCrisis: true,
    educationRequirements: const {'Master': 0.55, 'Bachelor': 0.30, 'PhD': 0.15},
    cityDemand: const {'Frankfurt': 0.50, 'Munich': 0.30, 'Hamburg': 0.20},
    postingFrequency: 0.68, postingGrowthRate: 0.12,
    occupationalGroup: 'Finance',
  ),

  // ════════════════ HEALTHCARE (6) ═══════════════════════════════════════

  Job(
    id: 21, title: 'Healthcare Data Analyst', company: 'MedInsight',
    type: 'full-time', level: 'Entry Level', location: 'Remote',
    salary: r'$75,000', experience: 0, industry: 'Healthcare',
    remote: true, workingMode: 'Remote', posted: DateTime(2026, 2, 6),
    skills: const ['data analysis', 'sql', 'excel', 'medical research', 'reporting', 'python'],
    benefits: _b3,
    sdgImpact: 'Decent Work', isTrending: false, isPivotSkillJob: true,
    automationRisk: 0.50, isEssentialDuringCrisis: true,
    educationRequirements: const {'Bachelor': 0.55, 'Master': 0.35, 'PhD': 0.10},
    cityDemand: const {'Remote-US': 0.55, 'Boston': 0.25, 'Chicago': 0.20},
    postingFrequency: 0.70, postingGrowthRate: 0.20,
    occupationalGroup: 'Healthcare',
  ),

  Job(
    id: 22, title: 'Clinical Research Assistant', company: 'PharmaCorp',
    type: 'full-time', level: 'Entry Level', location: 'Boston',
    salary: r'$69,500', experience: 0, industry: 'Healthcare',
    remote: false, workingMode: 'On-site', posted: DateTime(2026, 1, 30),
    skills: const ['medical research', 'pharmaceuticals', 'data collection', 'patient care', 'reporting'],
    benefits: _b1,
    sdgImpact: 'Skills Training', isTrending: true, isPivotSkillJob: false,
    automationRisk: 0.25, isEssentialDuringCrisis: true,
    educationRequirements: const {'Bachelor': 0.60, 'Master': 0.30, 'PhD': 0.10},
    cityDemand: const {'Boston': 0.45, 'San Francisco': 0.30, 'Raleigh': 0.25},
    postingFrequency: 0.68, postingGrowthRate: 0.14,
    occupationalGroup: 'Healthcare',
  ),

  Job(
    id: 23, title: 'Pharmaceutical Sales Representative', company: 'BioMed Solutions',
    type: 'full-time', level: 'Entry Level', location: 'Sydney',
    salary: r'$77,500', experience: 0, industry: 'Healthcare',
    remote: false, workingMode: 'Hybrid', posted: DateTime(2026, 2, 9),
    skills: const ['pharmaceuticals', 'sales', 'communication skills', 'customer service', 'product knowledge'],
    benefits: _b2,
    sdgImpact: 'Decent Work', isTrending: true, isPivotSkillJob: false,
    automationRisk: 0.50, isEssentialDuringCrisis: true,
    educationRequirements: const {'Bachelor': 0.70, 'Master': 0.20, 'Diploma': 0.10},
    cityDemand: const {'Sydney': 0.40, 'Melbourne': 0.35, 'Brisbane': 0.25},
    postingFrequency: 0.72, postingGrowthRate: 0.08,
    occupationalGroup: 'Healthcare',
  ),

  Job(
    id: 24, title: 'Nursing Staff Coordinator', company: 'City Medical Center',
    type: 'full-time', level: 'Mid Level', location: 'Chicago',
    salary: r'$82,500', experience: 2, industry: 'Healthcare',
    remote: false, workingMode: 'On-site', posted: DateTime(2026, 1, 25),
    skills: const ['nursing', 'patient care', 'medical research', 'team leadership', 'pharmaceuticals'],
    benefits: _b5,
    sdgImpact: 'Decent Work', isTrending: true, isPivotSkillJob: false,
    automationRisk: 0.09, isEssentialDuringCrisis: true,
    educationRequirements: const {'Bachelor (Nursing)': 0.55, 'Master (Nursing)': 0.35, 'Associate': 0.10},
    cityDemand: const {'Chicago': 0.40, 'Houston': 0.30, 'Phoenix': 0.30},
    postingFrequency: 0.90, postingGrowthRate: 0.16,
    occupationalGroup: 'Healthcare',
  ),

  Job(
    id: 25, title: 'Psychologist / Counsellor', company: 'MindWell Health',
    type: 'part-time', level: 'Mid Level', location: 'Remote',
    salary: r'$80,000', experience: 2, industry: 'Healthcare',
    remote: true, workingMode: 'Remote', posted: DateTime(2026, 2, 11),
    skills: const ['patient care', 'communication skills', 'research', 'reporting', 'medical research'],
    benefits: _b4,
    sdgImpact: 'Inclusive Growth', isTrending: false, isPivotSkillJob: false,
    automationRisk: 0.008, isEssentialDuringCrisis: true,
    educationRequirements: const {'Master': 0.55, 'PhD': 0.35, 'Bachelor': 0.10},
    cityDemand: const {'Remote-US': 0.60, 'New York': 0.20, 'Los Angeles': 0.20},
    postingFrequency: 0.75, postingGrowthRate: 0.22,
    occupationalGroup: 'Healthcare',
  ),

  Job(
    id: 26, title: 'Healthcare IT Analyst', company: 'Epic Systems',
    type: 'full-time', level: 'Entry Level', location: 'Remote',
    salary: r'$77,500', experience: 0, industry: 'Healthcare',
    remote: true, workingMode: 'Remote', posted: DateTime(2026, 2, 5),
    skills: const ['data analysis', 'sql', 'python', 'medical research', 'reporting', 'excel'],
    benefits: _b1,
    sdgImpact: 'Productivity', isTrending: false, isPivotSkillJob: true,
    automationRisk: 0.45, isEssentialDuringCrisis: true,
    educationRequirements: const {'Bachelor': 0.60, 'Master': 0.30, 'Certification': 0.10},
    cityDemand: const {'Remote-US': 0.55, 'Madison': 0.25, 'Chicago': 0.20},
    postingFrequency: 0.68, postingGrowthRate: 0.18,
    occupationalGroup: 'Healthcare',
  ),

  // ════════════════ MARKETING (8) ════════════════════════════════════════

  Job(
    id: 27, title: 'Digital Marketing Specialist', company: 'BrandBoost Agency',
    type: 'full-time', level: 'Entry Level', location: 'Remote',
    salary: r'$72,500', experience: 0, industry: 'Marketing',
    remote: true, workingMode: 'Remote', posted: DateTime(2026, 2, 11),
    skills: const ['seo', 'google ads', 'social media', 'content writing', 'analytics'],
    benefits: _b2,
    sdgImpact: 'Youth Employment', isTrending: true, isPivotSkillJob: true,
    automationRisk: 0.60, isEssentialDuringCrisis: false,
    educationRequirements: const {'Bachelor': 0.50, 'Self-taught': 0.35, 'Master': 0.15},
    cityDemand: const {'Remote-US': 0.50, 'New York': 0.25, 'Los Angeles': 0.25},
    postingFrequency: 0.85, postingGrowthRate: 0.15,
    occupationalGroup: 'Creative',
  ),

  Job(
    id: 28, title: 'UX/UI Designer', company: 'CreativeLabs',
    type: 'full-time', level: 'Mid Level', location: 'Remote',
    salary: r'$87,500', experience: 2, industry: 'Marketing',
    remote: true, workingMode: 'Remote', posted: DateTime(2026, 2, 15),
    skills: const ['ux design', 'figma', 'user research', 'prototyping', 'wireframing', 'communication skills'],
    benefits: _b3,
    sdgImpact: 'Productivity', isTrending: true, isPivotSkillJob: true,
    automationRisk: 0.06, isEssentialDuringCrisis: false,
    educationRequirements: const {'Bachelor': 0.50, 'Self-taught': 0.35, 'Master': 0.15},
    cityDemand: const {'Remote-US': 0.55, 'San Francisco': 0.25, 'New York': 0.20},
    postingFrequency: 0.88, postingGrowthRate: 0.20,
    occupationalGroup: 'Creative',
  ),

  Job(
    id: 29, title: 'Content Writer', company: 'ContentHub',
    type: 'part-time', level: 'Entry Level', location: 'Remote',
    salary: r'$69,500', experience: 0, industry: 'Marketing',
    remote: true, workingMode: 'Remote', posted: DateTime(2026, 2, 4),
    skills: const ['content writing', 'seo', 'social media', 'copywriting', 'research'],
    benefits: _b4,
    sdgImpact: 'Decent Work', isTrending: true, isPivotSkillJob: false,
    automationRisk: 0.65, isEssentialDuringCrisis: false,
    educationRequirements: const {'Bachelor': 0.40, 'Self-taught': 0.50, 'Master': 0.10},
    cityDemand: const {'Remote-US': 0.65, 'New York': 0.20, 'Los Angeles': 0.15},
    postingFrequency: 0.70, postingGrowthRate: 0.05,
    occupationalGroup: 'Creative',
  ),

  Job(
    id: 30, title: 'Market Research Analyst', company: 'InsightFirm',
    type: 'full-time', level: 'Mid Level', location: 'London',
    salary: r'$80,000', experience: 1, industry: 'Marketing',
    remote: false, workingMode: 'Hybrid', posted: DateTime(2026, 1, 27),
    skills: const ['market research', 'data analysis', 'excel', 'reporting', 'seo', 'google ads'],
    benefits: _b5,
    sdgImpact: 'Inclusive Growth', isTrending: false, isPivotSkillJob: false,
    automationRisk: 0.61, isEssentialDuringCrisis: false,
    educationRequirements: const {'Bachelor': 0.55, 'Master': 0.35, 'Self-taught': 0.10},
    cityDemand: const {'London': 0.55, 'Manchester': 0.25, 'Birmingham': 0.20},
    postingFrequency: 0.65, postingGrowthRate: 0.06,
    occupationalGroup: 'Creative',
  ),

  Job(
    id: 31, title: 'Social Media Manager', company: 'ViralConnect',
    type: 'full-time', level: 'Entry Level', location: 'Remote',
    salary: r'$72,500', experience: 0, industry: 'Marketing',
    remote: true, workingMode: 'Remote', posted: DateTime(2026, 2, 2),
    skills: const ['social media', 'content writing', 'google ads', 'copywriting', 'analytics', 'seo'],
    benefits: _b1,
    sdgImpact: 'Youth Employment', isTrending: true, isPivotSkillJob: false,
    automationRisk: 0.67, isEssentialDuringCrisis: false,
    educationRequirements: const {'Bachelor': 0.45, 'Self-taught': 0.45, 'Master': 0.10},
    cityDemand: const {'Remote-US': 0.60, 'New York': 0.20, 'Los Angeles': 0.20},
    postingFrequency: 0.78, postingGrowthRate: 0.10,
    occupationalGroup: 'Creative',
  ),

  Job(
    id: 32, title: 'Marketing Analyst', company: 'DataDriven Agency',
    type: 'full-time', level: 'Entry Level', location: 'Berlin',
    salary: r'$75,000', experience: 0, industry: 'Marketing',
    remote: false, workingMode: 'Hybrid', posted: DateTime(2026, 2, 8),
    skills: const ['analytics', 'google ads', 'seo', 'excel', 'market research', 'reporting'],
    benefits: _b2,
    sdgImpact: 'Decent Work', isTrending: false, isPivotSkillJob: false,
    automationRisk: 0.61, isEssentialDuringCrisis: false,
    educationRequirements: const {'Bachelor': 0.55, 'Master': 0.30, 'Self-taught': 0.15},
    cityDemand: const {'Berlin': 0.45, 'Hamburg': 0.30, 'Frankfurt': 0.25},
    postingFrequency: 0.68, postingGrowthRate: 0.08,
    occupationalGroup: 'Creative',
  ),

  Job(
    id: 33, title: 'Graphic Designer', company: 'VisualStudio Inc.',
    type: 'contract', level: 'Mid Level', location: 'Remote',
    salary: r'$80,000', experience: 2, industry: 'Marketing',
    remote: true, workingMode: 'Remote', posted: DateTime(2026, 2, 3),
    skills: const ['ux design', 'figma', 'adobe creative suite', 'content writing', 'communication skills'],
    benefits: _b3,
    sdgImpact: 'Decent Work', isTrending: false, isPivotSkillJob: false,
    automationRisk: 0.22, isEssentialDuringCrisis: false,
    educationRequirements: const {'Bachelor': 0.50, 'Self-taught': 0.40, 'Diploma': 0.10},
    cityDemand: const {'Remote-US': 0.55, 'New York': 0.25, 'Los Angeles': 0.20},
    postingFrequency: 0.62, postingGrowthRate: 0.04,
    occupationalGroup: 'Creative',
  ),

  Job(
    id: 34, title: 'Event Planner', company: 'EventPro',
    type: 'temporary', level: 'Entry Level', location: 'Dubai',
    salary: r'$72,500', experience: 0, industry: 'Marketing',
    remote: false, workingMode: 'On-site', posted: DateTime(2026, 2, 6),
    skills: const ['communication skills', 'project management', 'negotiation', 'customer service', 'social media'],
    benefits: _b4,
    sdgImpact: 'Youth Employment', isTrending: false, isPivotSkillJob: false,
    automationRisk: 0.43, isEssentialDuringCrisis: false,
    educationRequirements: const {'Bachelor': 0.50, 'Self-taught': 0.35, 'Diploma': 0.15},
    cityDemand: const {'Dubai': 0.50, 'Abu Dhabi': 0.30, 'Sharjah': 0.20},
    postingFrequency: 0.55, postingGrowthRate: 0.02,
    occupationalGroup: 'Creative',
  ),

  // ════════════════ MANUFACTURING (6) ═════════════════════════════════════

  Job(
    id: 35, title: 'Supply Chain Coordinator', company: 'LogiTech Manufacturing',
    type: 'full-time', level: 'Entry Level', location: 'Detroit',
    salary: r'$72,500', experience: 0, industry: 'Manufacturing',
    remote: false, workingMode: 'On-site', posted: DateTime(2026, 2, 1),
    skills: const ['supply chain', 'logistics', 'excel', 'inventory management', 'communication skills'],
    benefits: _b5,
    sdgImpact: 'Decent Work', isTrending: true, isPivotSkillJob: true,
    automationRisk: 0.72, isEssentialDuringCrisis: true,
    educationRequirements: const {'Bachelor': 0.55, 'Associate': 0.30, 'Master': 0.15},
    cityDemand: const {'Detroit': 0.40, 'Chicago': 0.30, 'Cleveland': 0.30},
    postingFrequency: 0.78, postingGrowthRate: 0.10,
    occupationalGroup: 'Operations',
  ),

  Job(
    id: 36, title: 'Quality Control Inspector', company: 'PrecisionMfg',
    type: 'full-time', level: 'Entry Level', location: 'Stuttgart',
    salary: r'$72,500', experience: 0, industry: 'Manufacturing',
    remote: false, workingMode: 'On-site', posted: DateTime(2026, 1, 26),
    skills: const ['quality control', 'production planning', 'supply chain', 'inspection', 'reporting'],
    benefits: _b1,
    sdgImpact: 'Productivity', isTrending: true, isPivotSkillJob: false,
    automationRisk: 0.78, isEssentialDuringCrisis: true,
    educationRequirements: const {'Associate': 0.45, 'Bachelor': 0.40, 'Vocational': 0.15},
    cityDemand: const {'Stuttgart': 0.45, 'Munich': 0.35, 'Nuremberg': 0.20},
    postingFrequency: 0.72, postingGrowthRate: 0.05,
    occupationalGroup: 'Operations',
  ),

  Job(
    id: 37, title: 'Production Planning Manager', company: 'IndusTech Corp.',
    type: 'full-time', level: 'Mid Level', location: 'Berlin',
    salary: r'$87,500', experience: 3, industry: 'Manufacturing',
    remote: false, workingMode: 'On-site', posted: DateTime(2026, 1, 18),
    skills: const ['production planning', 'supply chain', 'quality control', 'team leadership', 'erp systems'],
    benefits: _b2,
    sdgImpact: 'Productivity', isTrending: true, isPivotSkillJob: false,
    automationRisk: 0.65, isEssentialDuringCrisis: true,
    educationRequirements: const {'Bachelor': 0.55, 'Master': 0.30, 'MBA': 0.15},
    cityDemand: const {'Berlin': 0.40, 'Munich': 0.35, 'Stuttgart': 0.25},
    postingFrequency: 0.75, postingGrowthRate: 0.08,
    occupationalGroup: 'Operations',
  ),

  Job(
    id: 38, title: 'Procurement Manager', company: 'GlobalSupply Inc.',
    type: 'contract', level: 'Senior Level', location: 'Panama City',
    salary: r'$97,500', experience: 5, industry: 'Manufacturing',
    remote: false, workingMode: 'On-site', posted: DateTime(2026, 1, 15),
    skills: const ['supply chain', 'vendor management', 'negotiation', 'communication skills', 'strategic planning', 'reporting'],
    benefits: _b3,
    sdgImpact: 'Inclusive Growth', isTrending: true, isPivotSkillJob: false,
    automationRisk: 0.62, isEssentialDuringCrisis: true,
    educationRequirements: const {'Bachelor': 0.50, 'Master': 0.35, 'MBA': 0.15},
    cityDemand: const {'Panama City': 0.40, 'Bogotá': 0.35, 'Lima': 0.25},
    postingFrequency: 0.70, postingGrowthRate: 0.07,
    occupationalGroup: 'Operations',
  ),

  Job(
    id: 39, title: 'Supply Chain Manager', company: 'MegaLogistics',
    type: 'full-time', level: 'Mid Level', location: 'Dubai',
    salary: r'$90,000', experience: 3, industry: 'Manufacturing',
    remote: false, workingMode: 'Hybrid', posted: DateTime(2026, 2, 6),
    skills: const ['supply chain', 'logistics', 'inventory management', 'erp systems', 'team leadership', 'reporting'],
    benefits: _b4,
    sdgImpact: 'Productivity', isTrending: true, isPivotSkillJob: true,
    automationRisk: 0.68, isEssentialDuringCrisis: true,
    educationRequirements: const {'Bachelor': 0.50, 'Master': 0.35, 'MBA': 0.15},
    cityDemand: const {'Dubai': 0.45, 'Abu Dhabi': 0.30, 'Sharjah': 0.25},
    postingFrequency: 0.80, postingGrowthRate: 0.12,
    occupationalGroup: 'Operations',
  ),

  Job(
    id: 40, title: 'Manufacturing Intern', company: 'AutoTech GmbH',
    type: 'intern', level: 'Entry Level', location: 'Munich',
    salary: r'$67,500', experience: 0, industry: 'Manufacturing',
    remote: false, workingMode: 'On-site', posted: DateTime(2026, 2, 13),
    skills: const ['quality control', 'production planning', 'supply chain', 'reporting', 'excel'],
    benefits: _b5,
    sdgImpact: 'Youth Employment', isTrending: false, isPivotSkillJob: false,
    automationRisk: 0.75, isEssentialDuringCrisis: false,
    educationRequirements: const {'Bachelor (in progress)': 0.60, 'Associate': 0.25, 'Vocational': 0.15},
    cityDemand: const {'Munich': 0.50, 'Stuttgart': 0.30, 'Ingolstadt': 0.20},
    postingFrequency: 0.48, postingGrowthRate: 0.03,
    occupationalGroup: 'Operations',
  ),

  // ════════════════ RETAIL (5) ════════════════════════════════════════════

  Job(
    id: 41, title: 'Retail Sales Associate', company: 'ShopNow',
    type: 'part-time', level: 'Entry Level', location: 'Toronto',
    salary: r'$67,500', experience: 0, industry: 'Retail',
    remote: false, workingMode: 'On-site', posted: DateTime(2026, 2, 10),
    skills: const ['sales', 'customer service', 'merchandising', 'communication skills'],
    benefits: _b1,
    sdgImpact: 'Youth Employment', isTrending: true, isPivotSkillJob: false,
    automationRisk: 0.92, isEssentialDuringCrisis: true,
    educationRequirements: const {'High School': 0.55, 'Associate': 0.30, 'Bachelor': 0.15},
    cityDemand: const {'Toronto': 0.45, 'Vancouver': 0.30, 'Calgary': 0.25},
    postingFrequency: 0.88, postingGrowthRate: -0.05,
    occupationalGroup: 'Sales',
  ),

  Job(
    id: 42, title: 'E-Commerce Analyst', company: 'RetailEdge',
    type: 'full-time', level: 'Entry Level', location: 'Remote',
    salary: r'$75,000', experience: 0, industry: 'Retail',
    remote: true, workingMode: 'Remote', posted: DateTime(2026, 2, 3),
    skills: const ['data analysis', 'excel', 'merchandising', 'market research', 'customer service', 'seo'],
    benefits: _b2,
    sdgImpact: 'Productivity', isTrending: false, isPivotSkillJob: true,
    automationRisk: 0.58, isEssentialDuringCrisis: false,
    educationRequirements: const {'Bachelor': 0.60, 'Self-taught': 0.25, 'Master': 0.15},
    cityDemand: const {'Remote-US': 0.55, 'Seattle': 0.25, 'New York': 0.20},
    postingFrequency: 0.65, postingGrowthRate: 0.18,
    occupationalGroup: 'Sales',
  ),

  Job(
    id: 43, title: 'Business Development Manager', company: 'RetailPros',
    type: 'full-time', level: 'Mid Level', location: 'New York',
    salary: r'$85,000', experience: 2, industry: 'Retail',
    remote: false, workingMode: 'Hybrid', posted: DateTime(2026, 1, 29),
    skills: const ['sales', 'business development', 'customer service', 'communication skills', 'market research', 'negotiation'],
    benefits: _b3,
    sdgImpact: 'Inclusive Growth', isTrending: false, isPivotSkillJob: false,
    automationRisk: 0.35, isEssentialDuringCrisis: false,
    educationRequirements: const {'Bachelor': 0.60, 'MBA': 0.30, 'Self-taught': 0.10},
    cityDemand: const {'New York': 0.45, 'Chicago': 0.30, 'Los Angeles': 0.25},
    postingFrequency: 0.72, postingGrowthRate: 0.08,
    occupationalGroup: 'Sales',
  ),

  Job(
    id: 44, title: 'Purchasing Agent', company: 'BuyCo Retail',
    type: 'full-time', level: 'Entry Level', location: 'Los Angeles',
    salary: r'$75,000', experience: 0, industry: 'Retail',
    remote: false, workingMode: 'On-site', posted: DateTime(2026, 2, 7),
    skills: const ['supply chain', 'negotiation', 'communication skills', 'merchandising', 'vendor management'],
    benefits: _b4,
    sdgImpact: 'Decent Work', isTrending: false, isPivotSkillJob: false,
    automationRisk: 0.80, isEssentialDuringCrisis: false,
    educationRequirements: const {'Bachelor': 0.55, 'Associate': 0.30, 'High School': 0.15},
    cityDemand: const {'Los Angeles': 0.45, 'San Diego': 0.30, 'Riverside': 0.25},
    postingFrequency: 0.60, postingGrowthRate: -0.02,
    occupationalGroup: 'Operations',
  ),

  Job(
    id: 45, title: 'Customer Support Specialist', company: 'HelpDesk Pro',
    type: 'full-time', level: 'Entry Level', location: 'Remote',
    salary: r'$69,500', experience: 0, industry: 'Retail',
    remote: true, workingMode: 'Remote', posted: DateTime(2026, 2, 9),
    skills: const ['customer service', 'communication skills', 'sales', 'product knowledge', 'reporting'],
    benefits: _b5,
    sdgImpact: 'Youth Employment', isTrending: false, isPivotSkillJob: false,
    automationRisk: 0.55, isEssentialDuringCrisis: false,
    educationRequirements: const {'High School': 0.45, 'Associate': 0.35, 'Bachelor': 0.20},
    cityDemand: const {'Remote-US': 0.65, 'Phoenix': 0.20, 'Tampa': 0.15},
    postingFrequency: 0.75, postingGrowthRate: 0.02,
    occupationalGroup: 'Sales',
  ),
];

// ═══════════════════════════════════════════════════════════════════════════
// §14  CORE RECOMMENDATION & FILTER FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════

/// [Alsaif 2022 §4, Fig. 4 — Step 3: Rank]
/// Recommends jobs sorted by simScore (or matchScore fallback).
/// Accepts a [JobFilter] for multi-dimensional filtering.
///
/// Legacy positional parameters are kept for backward compatibility.
List<Job> recommendJobs(
    List<String> userSkills, {
      String industry          = 'All',
      String level             = 'All',
      bool remoteOnly          = false,
      double? maxAutomationRisk,
      int? topN,
      // New in Session 3: pass a full JobFilter to override individual params.
      JobFilter? filter,
    }) {
  final effectiveFilter = filter ??
      JobFilter(
        industry: industry,
        level: level,
        remoteOnly: remoteOnly,
        maxAutomationRisk: maxAutomationRisk,
      );

  final ranked = allJobs
      .where(effectiveFilter.matches)
      .map((j) {
    final score =
    j.simScore > 0.0 ? j.simScore : j.matchScore(userSkills);
    final dist = j.computeTransitionDistance(userSkills);
    return (job: j.copyWith(transitionDistance: dist), score: score);
  })
      .where((e) => e.score > 0)
      .toList()
    ..sort((a, b) => b.score.compareTo(a.score));

  final results = ranked.map((e) => e.job).toList();
  return topN != null ? results.take(topN).toList() : results;
}

/// Filter jobs without skill matching (for browsing / dashboard).
/// Accepts a [JobFilter] to replace individual parameters.
List<Job> filterJobs({
  String industry          = 'All',
  String level             = 'All',
  bool remoteOnly          = false,
  String occupationalGroup = 'All',
  JobFilter? filter,
}) {
  final effectiveFilter = filter ??
      JobFilter(
        industry: industry,
        level: level,
        remoteOnly: remoteOnly,
        occupationalGroup: occupationalGroup,
      );
  return allJobs.where(effectiveFilter.matches).toList();
}

// ═══════════════════════════════════════════════════════════════════════════
// §15  SORT
// ═══════════════════════════════════════════════════════════════════════════

/// Sort [jobs] according to [strategy].
/// Returns a new sorted list — does NOT mutate the input.
List<Job> sortJobs(List<Job> jobs, JobSortStrategy strategy) {
  final sorted = List<Job>.from(jobs);
  switch (strategy) {
    case JobSortStrategy.simScore:
      sorted.sort((a, b) => b.simScore.compareTo(a.simScore));
    case JobSortStrategy.postingGrowthRate:
      sorted.sort((a, b) => (b.postingGrowthRate ?? 0.0)
          .compareTo(a.postingGrowthRate ?? 0.0));
    case JobSortStrategy.postingFrequency:
      sorted.sort((a, b) => (b.postingFrequency ?? 0.0)
          .compareTo(a.postingFrequency ?? 0.0));
    case JobSortStrategy.automationRiskAsc:
      sorted.sort((a, b) => (a.automationRisk ?? 0.5)
          .compareTo(b.automationRisk ?? 0.5));
    case JobSortStrategy.transitionDistanceAsc:
      sorted.sort(
              (a, b) => a.transitionDistance.compareTo(b.transitionDistance));
    case JobSortStrategy.mostRecent:
      sorted.sort((a, b) => b.posted.compareTo(a.posted));
    case JobSortStrategy.experienceAsc:
      sorted.sort((a, b) => a.experience.compareTo(b.experience));
    case JobSortStrategy.careerFitScore:
      sorted.sort((a, b) => (b.careerFitScore?.composite ?? 0.0)
          .compareTo(a.careerFitScore?.composite ?? 0.0));
  }
  return sorted;
}

// ═══════════════════════════════════════════════════════════════════════════
// §16  SESSION 3 — NEW TOP-LEVEL HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════

/// Compute and attach [CareerFitScore] to each job in [jobs].
/// Returns a new list — originals are NOT mutated.
List<Job> computeCareerFitScores(
    List<Job> jobs, List<String> userSkills) {
  return jobs
      .map((j) =>
      j.copyWith(careerFitScore: CareerFitScore.compute(j, userSkills)))
      .toList();
}

/// Compute and attach [SkillGapAnalysis] to each job in [jobs].
/// Returns a new list — originals are NOT mutated.
List<Job> attachSkillGapAnalysis(
    List<Job> jobs, List<String> userSkills) {
  return jobs
      .map((j) => j.copyWith(
      skillGapAnalysis: SkillGapAnalysis.compute(j, userSkills)))
      .toList();
}

/// Returns a skill → occurrence-count map across [jobs].
/// Useful for building word-clouds or ranked skill tables.
Map<String, int> skillDemandMap([List<Job>? jobs]) {
  final source = jobs ?? allJobs;
  final freq   = <String, int>{};
  for (final j in source) {
    for (final s in j.skills) {
      final key = s.toLowerCase();
      freq[key] = (freq[key] ?? 0) + 1;
    }
  }
  return freq;
}

/// Returns the [topN] most-demanded skills across [jobs], sorted descending.
List<String> topSkillsByFrequency({int topN = 10, List<Job>? jobs}) {
  final freq = skillDemandMap(jobs);
  final entries = freq.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return entries.take(topN).map((e) => e.key).toList();
}

/// Groups jobs by their [occupationalGroup].
Map<String, List<Job>> clusterByOccupationalGroup([List<Job>? jobs]) {
  final source = jobs ?? allJobs;
  final map    = <String, List<Job>>{};
  for (final j in source) {
    final key =
    j.occupationalGroup.isEmpty ? 'Unclassified' : j.occupationalGroup;
    map.putIfAbsent(key, () => []).add(j);
  }
  return map;
}

/// Groups jobs by [PostingGrowthCategory].
Map<PostingGrowthCategory, List<Job>> jobsByPostingGrowthCategory(
    [List<Job>? jobs]) {
  final source = jobs ?? allJobs;
  final map    = <PostingGrowthCategory, List<Job>>{};
  for (final j in source) {
    final cat = j.postingGrowthCategory;
    map.putIfAbsent(cat, () => []).add(j);
  }
  return map;
}

/// Returns jobs from [jobs] (defaults to [allJobs]) that contain AT LEAST
/// [minMatchCount] of the specified [skills].
List<Job> matchingJobsForSkillSet(
    List<String> skills, {
      int minMatchCount = 1,
      List<Job>? jobs,
    }) {
  final source = jobs ?? allJobs;
  final lower  = skills.map((s) => s.toLowerCase()).toSet();
  return source.where((j) {
    final matched = j.skills
        .where((s) => lower.contains(s.toLowerCase()))
        .length;
    return matched >= minMatchCount;
  }).toList();
}

// ═══════════════════════════════════════════════════════════════════════════
// §17  LEGACY SESSION 2 HELPER FUNCTIONS (unchanged signatures)
// ═══════════════════════════════════════════════════════════════════════════

/// Jobs posted within the last [days] days.
List<Job> recentJobs({int days = 30}) {
  final cutoff = DateTime.now().subtract(Duration(days: days));
  return allJobs.where((j) => j.posted.isAfter(cutoff)).toList();
}

/// Job count by industry.
Map<String, int> jobCountByIndustry() {
  final map = <String, int>{};
  for (final j in allJobs) {
    map[j.industry] = (map[j.industry] ?? 0) + 1;
  }
  return map;
}

/// [Tavakoli 2022 §3.2] High-occurrence (trending) jobs.
List<Job> trendingJobs({int? topN}) {
  final results = allJobs.where((j) => j.isTrending).toList();
  return topN != null ? results.take(topN).toList() : results;
}

/// [Alsaif 2022 §4] Pivot-skill jobs that unlock wide career paths.
List<Job> pivotSkillJobs({String industry = 'All'}) {
  return allJobs.where((j) {
    final matchInd = industry == 'All' || j.industry == industry;
    return matchInd && j.isPivotSkillJob;
  }).toList();
}

/// [SDG-8] Jobs filtered by SDG-8 impact label.
List<Job> sdgFilteredJobs(String sdgImpact) =>
    allJobs.where((j) => j.sdgImpact == sdgImpact).toList();

/// [F&O 2017] Jobs grouped by automation risk tier.
Map<String, List<Job>> jobsByAutomationRiskTier() {
  final map = <String, List<Job>>{
    'Low Risk': [],
    'Medium Risk': [],
    'High Risk': [],
  };
  for (final j in allJobs) {
    map[j.automationRiskLabel]!.add(j);
  }
  return map;
}

/// Jobs flagged as essential workers.
List<Job> essentialJobs() =>
    allJobs.where((j) => j.isEssentialDuringCrisis).toList();

/// Jobs sorted by posting growth rate (fastest-growing first).
List<Job> fastestGrowingJobs({int? topN}) {
  final sorted = [...allJobs]
    ..sort((a, b) =>
        (b.postingGrowthRate ?? 0.0).compareTo(a.postingGrowthRate ?? 0.0));
  return topN != null ? sorted.take(topN).toList() : sorted;
}

/// Jobs whose peak demand city matches [city] (case-insensitive).
List<Job> jobsInDemandCity(String city) {
  final needle = city.toLowerCase();
  return allJobs
      .where((j) => j.topDemandCity.toLowerCase() == needle)
      .toList();
}

/// Jobs whose primary education requirement matches [educationLevel].
List<Job> jobsByEducation(String educationLevel) {
  return allJobs
      .where((j) => j.primaryEducationRequirement == educationLevel)
      .toList();
}

/// [Session 3] Compute [JobStats] for all jobs.
JobStats allJobStats() => JobStats.fromJobs(allJobs);

/// [Session 3] Future-proof jobs: trending + high-growth + low automation.
List<Job> futureProofJobs({int? topN}) {
  final results = allJobs.where((j) => j.isFutureProof).toList();
  return topN != null ? results.take(topN).toList() : results;
}

/// [Session 3] Entry-friendly jobs: entry level, zero experience, active posting.
List<Job> entryFriendlyJobs() =>
    allJobs.where((j) => j.isEntryFriendly).toList();