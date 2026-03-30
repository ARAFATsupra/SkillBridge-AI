// lib/ml/recommender.dart — SkillBridge AI
// ──────────────────────────────────────────────────────────────────────────────
// Hybrid Job Recommendation Engine v3.0
//
// Algorithms:
// • Weighted TF-IDF + Cosine Similarity (primary signal)
// • Jaccard Coefficient (set-overlap signal)
// • Skill Coverage Score (completeness signal)
// • BM25-inspired Term Saturation (frequency dampening)
// • Temporal Decay Weighting (recency bias)
// • MMR Diversity Re-ranking (result diversification)
// • Cross-Domain Transfer Detection (bridge map + semantic θ)
//
// Post-processing:
// • Negative Sampling filter
// • Greedy One-to-One matching
// • Bias Audit (industry / company dominance)
// • Percentile rank normalisation
//
// Explainability:
// • Per-term contribution breakdown (top 5)
// • Human-readable match explanation
// • Skill gap report with course suggestions
//
// Evaluation:
// • Precision@K / Recall@K / F1@K
// • NDCG@K (Normalised Discounted Cumulative Gain)
// • MRR (Mean Reciprocal Rank)
// • AUC (approximation)
// ──────────────────────────────────────────────────────────────────────────────

import 'dart:math';
import 'package:flutter/foundation.dart';

// ── Data layer ────────────────────────────────────────────────────────────────
import '../data/courses.dart' show courses, Course;
import '../data/jobs.dart';
// ── Models ────────────────────────────────────────────────────────────────────
import '../models/career_profile.dart';
// ── ML utilities ─────────────────────────────────────────────────────────────
// Hide `cosineSimilarity` from tfidf.dart to resolve the name conflict.
// The canonical implementation lives in cosine.dart.
import 'tfidf.dart' hide cosineSimilarity;
import 'cosine.dart';
import 'skill_similarity.dart';
import 'rca_calculator.dart';

// =============================================================================
// §0  LOCAL COSINE WRAPPER
// =============================================================================
// `cosineSimilarity` (cosine.dart) already declares `normalize` and
// `attentionWeights` as named parameters, so this private wrapper adds only
// the optional pre-processing step and then delegates with `normalize: false`
// to avoid a redundant second normalisation pass.
// =============================================================================

/// Weighted cosine similarity with optional L2 normalisation and
/// attention-weight scaling.
///
/// [normalize] — when `true` the vectors are L2-normalised before the dot
///               product, preventing magnitude differences from affecting the
///               score. The downstream [cosineSimilarity] call is made with
///               `normalize: false` so the vectors are never normalised twice.
/// [attentionWeights] — per-term multiplier applied to both vectors before the
///                      similarity computation.
double _cosineSim(
    Map<String, double> a,
    Map<String, double> b, {
      bool normalize = false,
      Map<String, double>? attentionWeights,
    }) {
  // Apply per-term attention weights when supplied.
  Map<String, double> vecA = a;
  Map<String, double> vecB = b;
  if (attentionWeights != null && attentionWeights.isNotEmpty) {
    vecA = {
      for (final e in a.entries)
        e.key: e.value * (attentionWeights[e.key] ?? 1.0),
    };
    vecB = {
      for (final e in b.entries)
        e.key: e.value * (attentionWeights[e.key] ?? 1.0),
    };
  }

  if (normalize) {
    // L2-normalise in-place before delegating.
    double normA = 0.0;
    double normB = 0.0;
    for (final v in vecA.values) {
      normA += v * v;
    }
    for (final v in vecB.values) {
      normB += v * v;
    }
    normA = sqrt(normA);
    normB = sqrt(normB);
    if (normA > 0.0) {
      vecA = {for (final e in vecA.entries) e.key: e.value / normA};
    }
    if (normB > 0.0) {
      vecB = {for (final e in vecB.entries) e.key: e.value / normB};
    }
  }

  // Pass normalize: false — vectors are already unit-length when normalize was
  // true above, and the caller explicitly opted out when normalize is false.
  // This prevents a redundant second normalisation pass inside cosineSimilarity.
  return cosineSimilarity(vecA, vecB, normalize: false);
}

// =============================================================================
// §1 DOMAIN-WEIGHT DICTIONARY
// =============================================================================
// Keys are lowercase; values are importance weights (0.0–1.0).
// Applied during TF-IDF vectorisation to boost signal from critical terms.
// =============================================================================

/// Master keyword-weight dictionary used across all scoring functions.
const Map<String, double> kDomainWeights = {
  // ── Tier 1: core technical skills (0.83–0.95) ─────────────────────────────
  'python': 0.95,
  'tensorflow': 0.92,
  'pytorch': 0.92,
  'postgresql': 0.91,
  'sql': 0.90,
  'machine learning': 0.90,
  'deep learning': 0.90,
  'nlp': 0.88,
  'docker': 0.88,
  'mongodb': 0.86,
  'azure': 0.86,
  'gcp': 0.86,
  'kubernetes': 0.87,
  'aws': 0.87,
  'flutter': 0.87,
  'typescript': 0.84,
  'golang': 0.84,
  'rust': 0.84,
  'react': 0.85,
  'nodejs': 0.85,
  'java': 0.85,
  'kotlin': 0.85,
  'swift': 0.85,
  'microservices': 0.85,
  'devops': 0.85,
  'phd': 0.83,
  'c++': 0.83,
  'graphql': 0.83,
  'airflow': 0.83,
  'kafka': 0.83,
  'tableau': 0.83,
  'power bi': 0.83,
  'scrum': 0.82,
  'agile': 0.82,
  'etl': 0.82,
  'hadoop': 0.82,
  'spark': 0.82,
  'scala': 0.82,
  'dbt': 0.82,
  'redis': 0.84,
  'ci/cd': 0.84,
  'r': 0.80,
  // ── Tier 2: professional / analytical skills (0.50–0.75) ──────────────────
  'data analysis': 0.72,
  'statistical analysis': 0.70,
  'data visualization': 0.70,
  'project management': 0.68,
  'database': 0.66,
  'api': 0.65,
  'git': 0.65,
  'linux': 0.65,
  'testing': 0.64,
  'excel': 0.62,
  'leadership': 0.60,
  'communication': 0.57,
  'research': 0.58,
  'stakeholder': 0.57,
  'problem solving': 0.56,
  'documentation': 0.55,
  'cross-functional': 0.52,
  'mentoring': 0.52,
  'presentation': 0.53,
  // ── Tier 3: generic filler (0.10–0.20) ────────────────────────────────────
  'team': 0.15,
  'experience': 0.20,
  'knowledge': 0.18,
  'skills': 0.15,
  'professional': 0.15,
  'fast': 0.12,
  'detail': 0.15,
  'strong': 0.12,
  'ability': 0.12,
  'motivated': 0.10,
  'passion': 0.10,
  'dynamic': 0.10,
  'driven': 0.10,
  'oriented': 0.10,
  'responsible': 0.10,
  'work': 0.10,
  'good': 0.10,
  'excellent': 0.10,
};

// =============================================================================
// §2 ENUMS & SEALED RESULT TYPE
// =============================================================================

/// Feedback polarity for online preference-update stubs.
enum FeedbackSignal { positive, negative, neutral }

/// Strategy used to compute the primary similarity signal.
enum ScoringStrategy {
  /// Weighted TF-IDF + cosine (default, most accurate).
  tfidfCosine,

  /// Pure Jaccard set-overlap (fast, no weighting).
  jaccard,

  /// Ensemble of TF-IDF cosine + BM25 saturation term.
  bm25Ensemble,
}

/// Match tier for a single recommendation.
enum MatchTier { strong, partial, weak }

extension MatchTierExtension on MatchTier {
  String get label => switch (this) {
    MatchTier.strong => 'Strong Match',
    MatchTier.partial => 'Partial Match',
    MatchTier.weak => 'Weak Match',
  };

  /// Hex colour for UI rendering.
  String get hexColor => switch (this) {
    MatchTier.strong => '#10B981',
    MatchTier.partial => '#F59E0B',
    MatchTier.weak => '#EF4444',
  };

  /// 0–255 opacity-safe ARGB int for Flutter Color().
  int get argb => switch (this) {
    MatchTier.strong => 0xFF10B981,
    MatchTier.partial => 0xFFF59E0B,
    MatchTier.weak => 0xFFEF4444,
  };
}

// =============================================================================
// §3 VALUE OBJECTS
// =============================================================================

/// Immutable scoring-weight configuration.
///
/// [cosine] + [jaccard] + [coverage] must sum to 1.0 (±1e-9 tolerance).
@immutable
final class ScoringWeights {
  final double cosine;
  final double jaccard;
  final double coverage;

  // The assert message must be a compile-time constant string — no interpolation.
  // The condition uses a range check instead of .abs() to remain a valid
  // constant expression accepted by all Dart 3 const constructors.
  const ScoringWeights({
    this.cosine = 0.55,
    this.jaccard = 0.20,
    this.coverage = 0.25,
  }) : assert(
  cosine + jaccard + coverage >= 1.0 - 1e-9 &&
      cosine + jaccard + coverage <= 1.0 + 1e-9,
  'ScoringWeights must sum to 1.0',
  );

  ScoringWeights copyWith({
    double? cosine,
    double? jaccard,
    double? coverage,
  }) =>
      ScoringWeights(
        cosine: cosine ?? this.cosine,
        jaccard: jaccard ?? this.jaccard,
        coverage: coverage ?? this.coverage,
      );

  @override
  String toString() =>
      'ScoringWeights(cosine: $cosine, jaccard: $jaccard, coverage: $coverage)';
}

/// Central configuration object — replaces per-call parameter sprawl.
@immutable
final class RecommendationConfig {
  final int? topN;
  final double minScore;
  final bool? remoteOnly;
  final String? industry;
  final String? level;
  final int? maxExperience;
  final ScoringStrategy strategy;

  /// `const ScoringWeights()` is a valid constant default value because
  /// [ScoringWeights] has a `const` constructor.
  final ScoringWeights weights;
  final Map<String, double>? attentionWeights;
  final List<List<String>>? skillsByPeriod;
  final double temporalDecayRate;
  final List<String>? negativeJobSkills;
  final double negativeSamplingThreshold;
  final bool runBiasAudit;
  final double biasThreshold;
  final int biasWindow;
  final bool greedyMatchDedup;
  final bool withExplainability;
  final bool includeTransfer;
  final bool includeMmrReranking;
  final double mmrLambda;

  const RecommendationConfig({
    this.topN,
    this.minScore = 0.15,
    this.remoteOnly,
    this.industry,
    this.level,
    this.maxExperience,
    this.strategy = ScoringStrategy.tfidfCosine,
    this.weights = const ScoringWeights(),
    this.attentionWeights,
    this.skillsByPeriod,
    this.temporalDecayRate = 0.4,
    this.negativeJobSkills,
    this.negativeSamplingThreshold = 0.70,
    this.runBiasAudit = false,
    this.biasThreshold = 0.60,
    this.biasWindow = 10,
    this.greedyMatchDedup = false,
    this.withExplainability = true,
    this.includeTransfer = false,
    this.includeMmrReranking = false,
    this.mmrLambda = 0.5,
  });

  RecommendationConfig copyWith({
    int? topN,
    double? minScore,
    bool? remoteOnly,
    String? industry,
    String? level,
    int? maxExperience,
    ScoringStrategy? strategy,
    ScoringWeights? weights,
    Map<String, double>? attentionWeights,
    List<List<String>>? skillsByPeriod,
    double? temporalDecayRate,
    List<String>? negativeJobSkills,
    double? negativeSamplingThreshold,
    bool? runBiasAudit,
    double? biasThreshold,
    int? biasWindow,
    bool? greedyMatchDedup,
    bool? withExplainability,
    bool? includeTransfer,
    bool? includeMmrReranking,
    double? mmrLambda,
  }) =>
      RecommendationConfig(
        topN: topN ?? this.topN,
        minScore: minScore ?? this.minScore,
        remoteOnly: remoteOnly ?? this.remoteOnly,
        industry: industry ?? this.industry,
        level: level ?? this.level,
        maxExperience: maxExperience ?? this.maxExperience,
        strategy: strategy ?? this.strategy,
        weights: weights ?? this.weights,
        attentionWeights: attentionWeights ?? this.attentionWeights,
        skillsByPeriod: skillsByPeriod ?? this.skillsByPeriod,
        temporalDecayRate: temporalDecayRate ?? this.temporalDecayRate,
        negativeJobSkills: negativeJobSkills ?? this.negativeJobSkills,
        negativeSamplingThreshold:
        negativeSamplingThreshold ?? this.negativeSamplingThreshold,
        runBiasAudit: runBiasAudit ?? this.runBiasAudit,
        biasThreshold: biasThreshold ?? this.biasThreshold,
        biasWindow: biasWindow ?? this.biasWindow,
        greedyMatchDedup: greedyMatchDedup ?? this.greedyMatchDedup,
        withExplainability: withExplainability ?? this.withExplainability,
        includeTransfer: includeTransfer ?? this.includeTransfer,
        includeMmrReranking: includeMmrReranking ?? this.includeMmrReranking,
        mmrLambda: mmrLambda ?? this.mmrLambda,
      );
}

/// Detailed skill-gap analysis for a single job.
@immutable
final class SkillGapReport {
  /// Skills the candidate already has that the job requires.
  final List<String> matchedSkills;

  /// Skills the job requires that the candidate is missing.
  final List<String> missingSkills;

  /// Missing skills classified as high-priority (weight ≥ 0.80).
  final List<String> criticalGaps;

  /// Missing skills classified as medium-priority (0.50–0.79).
  final List<String> developmentGaps;

  /// Missing skills classified as low-priority (< 0.50).
  final List<String> niceToHaveGaps;

  /// Best matching course for each critical gap.
  final Map<String, Course?> suggestedCourses;

  /// Overall readiness score 0–1 (matchedSkills / totalRequired).
  final double readinessScore;

  /// Estimated learning effort in weeks to close critical gaps.
  final int estimatedWeeksToReady;

  const SkillGapReport({
    required this.matchedSkills,
    required this.missingSkills,
    required this.criticalGaps,
    required this.developmentGaps,
    required this.niceToHaveGaps,
    required this.suggestedCourses,
    required this.readinessScore,
    required this.estimatedWeeksToReady,
  });

  bool get isJobReady => readinessScore >= 0.80;
  bool get hasAnyGaps => missingSkills.isNotEmpty;
  int get totalRequired => matchedSkills.length + missingSkills.length;
  int get criticalGapCount => criticalGaps.length;
}

// =============================================================================
// §4 JOB RECOMMENDATION RESULT
// =============================================================================

@immutable
final class JobRecommendation {
  final int id;
  final String title;
  final String company;
  final double score;
  final double matchRatio;
  final double coverageRatio;
  final double bm25Component;
  final List<String> matching;
  final List<String> missing;
  final String location;
  final String type;
  final String level;
  final String salary;
  final bool remote;
  final String industry;
  final String workingMode;
  final int experience;
  final bool biasFlag;

  /// Percentile rank within the current result set (0–100).
  final double percentileRank;

  /// Top matched keyword pairs for explainability.
  final List<Map<String, dynamic>> topMatchedPairs;

  /// Human-readable match explanation.
  final String matchExplanation;

  /// Transferable skills from a different domain.
  final List<Map<String, dynamic>> transferableSkills;

  /// Full skill-gap report (populated when [withExplainability] is true).
  final SkillGapReport? gapReport;

  const JobRecommendation({
    required this.id,
    required this.title,
    required this.company,
    required this.score,
    required this.matchRatio,
    required this.coverageRatio,
    required this.matching,
    required this.missing,
    required this.location,
    required this.type,
    required this.level,
    required this.salary,
    required this.remote,
    required this.industry,
    required this.workingMode,
    required this.experience,
    this.bm25Component = 0.0,
    this.biasFlag = false,
    this.percentileRank = 0.0,
    this.topMatchedPairs = const [],
    this.matchExplanation = '',
    this.transferableSkills = const [],
    this.gapReport,
  });

  // ── Derived display helpers ─────────────────────────────────────────────
  String get matchPercent => formatScoreAsPercent(score);
  String get coveragePercent => formatScoreAsPercent(coverageRatio);
  String get formattedSalary => salary.isEmpty ? 'Not specified' : salary;
  String get matchColor => tier.hexColor;
  String get matchLabel => tier.label;
  double get simScore => score;
  int get scoreAsInt => scoreToInt(score);
  MatchTier get tier => getMatchTier(score);

  /// Returns a copy of this result with [biasFlag] set to `true`.
  JobRecommendation withBiasFlag() => _copyWith(biasFlag: true);

  /// Returns a copy with an updated [percentileRank].
  JobRecommendation withPercentileRank(double rank) =>
      _copyWith(percentileRank: rank);

  JobRecommendation _copyWith({
    double? score,
    bool? biasFlag,
    double? percentileRank,
    String? matchExplanation,
    List<Map<String, dynamic>>? topMatchedPairs,
    List<Map<String, dynamic>>? transferableSkills,
    SkillGapReport? gapReport,
  }) {
    return JobRecommendation(
      id: id,
      title: title,
      company: company,
      score: score ?? this.score,
      matchRatio: matchRatio,
      coverageRatio: coverageRatio,
      bm25Component: bm25Component,
      matching: matching,
      missing: missing,
      location: location,
      type: type,
      level: level,
      salary: salary,
      remote: remote,
      industry: industry,
      workingMode: workingMode,
      experience: experience,
      biasFlag: biasFlag ?? this.biasFlag,
      percentileRank: percentileRank ?? this.percentileRank,
      topMatchedPairs: topMatchedPairs ?? this.topMatchedPairs,
      matchExplanation: matchExplanation ?? this.matchExplanation,
      transferableSkills: transferableSkills ?? this.transferableSkills,
      gapReport: gapReport ?? this.gapReport,
    );
  }

  @override
  String toString() =>
      'JobRecommendation(id: $id, title: "$title", score: '
          '${score.toStringAsFixed(3)}, tier: ${tier.label})';
}

// =============================================================================
// §5 DISPLAY / SCORING HELPERS
// =============================================================================

/// Derives the [MatchTier] for a similarity score.
MatchTier getMatchTier(double score) {
  if (score > 0.70) return MatchTier.strong;
  if (score >= 0.40) return MatchTier.partial;
  return MatchTier.weak;
}

/// Returns a human-readable match label (legacy API compatibility).
String getMatchLabel(double score) => getMatchTier(score).label;

/// Returns a hex colour string for a similarity score (legacy API compat).
String getMatchColor(double score) => getMatchTier(score).hexColor;

/// Converts a 0–1 score to a percentage string with one decimal place.
///
/// Example: `0.734 → "73.4%"`
String formatScoreAsPercent(double score) {
  final clamped = score.clamp(0.0, 1.0);
  return '${(clamped * 100).toStringAsFixed(1)}%';
}

/// Returns an integer [0, 100] suitable for progress-bar widgets.
int scoreToInt(double score) => (score.clamp(0.0, 1.0) * 100).round();

// =============================================================================
// §6 BM25 SATURATION TERM
// =============================================================================
// Dampens high term frequencies to prevent single-term domination.
//
// BM25 term score:
//   tf_bm25 = tf × (k1 + 1) / (tf + k1 × (1 − b + b × dl / avgdl))
// =============================================================================

/// Computes a BM25-inspired term-frequency saturation score for a skill list.
///
/// [k1] — term saturation factor (default 1.5, typical BM25 range 1.2–2.0).
/// [b]  — length normalisation factor (default 0.75).
///
/// Returns a weight-adjusted BM25 component in [0.0, 1.0].
double _bm25Score(
    Set<String> userSkills,
    Set<String> jobSkills, {
      double k1 = 1.5,
      double b = 0.75,
      double avgDocLength = 15.0,
    }) {
  if (userSkills.isEmpty || jobSkills.isEmpty) return 0.0;
  final dl = jobSkills.length.toDouble();
  final normDl = 1.0 - b + b * (dl / avgDocLength);
  double bm25Sum = 0.0;
  double maxPossible = 0.0;

  for (final skill in jobSkills) {
    final w = kDomainWeights[skill] ?? 0.35;
    final tf = userSkills.contains(skill) ? 1.0 : 0.0;
    final tfBm25 = tf * (k1 + 1.0) / (tf + k1 * normDl);
    bm25Sum += tfBm25 * w;
    maxPossible += (k1 + 1.0) / (1.0 + k1 * normDl) * w;
  }

  if (maxPossible == 0.0) return 0.0;
  return (bm25Sum / maxPossible).clamp(0.0, 1.0);
}

// =============================================================================
// §7 TEMPORAL DECAY WEIGHTING
// =============================================================================

/// Applies recency weighting to skill lists ordered oldest → newest.
///
/// `weight[i] = exp(λ × (i − (n − 1)))` → most recent period = 1.0.
List<String> applyTemporalDecay(
    List<List<String>> skillsByPeriod, {
      double decayRate = 0.4,
    }) {
  if (skillsByPeriod.isEmpty) return [];
  final n = skillsByPeriod.length;
  final result = <String>[];
  for (int i = 0; i < n; i++) {
    final weight = exp(decayRate * (i - (n - 1)));
    final repeats = (weight * 10).round().clamp(1, 10);
    for (final skill in skillsByPeriod[i]) {
      for (int r = 0; r < repeats; r++) {
        result.add(skill);
      }
    }
  }
  return result;
}

// =============================================================================
// §8 NEGATIVE SAMPLING
// =============================================================================

/// Removes recommendations that are too similar to a known negative experience.
List<JobRecommendation> applyNegativeSampling(
    List<JobRecommendation> recommendations,
    List<String> negativeJobSkills, {
      double threshold = 0.70,
      Map<String, double>? attentionWeights,
    }) {
  if (negativeJobSkills.isEmpty) return recommendations;
  final aw = attentionWeights ?? kDomainWeights;
  final normNeg = negativeJobSkills
      .map((s) => s.trim().toLowerCase())
      .where((s) => s.isNotEmpty)
      .toList();

  final negVector = termFrequency(
    normNeg,
    attentionWeights: aw,
    skillTerms: normNeg.toSet(),
  );

  return recommendations.where((rec) {
    final allSkills = [...rec.matching, ...rec.missing]
        .map((s) => s.trim().toLowerCase())
        .toList();
    final recVector = termFrequency(
      allSkills,
      attentionWeights: aw,
      skillTerms: allSkills.toSet(),
    );
    final sim = _cosineSim(
      recVector,
      negVector,
      normalize: true,
      attentionWeights: aw,
    );
    return sim < threshold;
  }).toList();
}

// =============================================================================
// §9 GREEDY MATCHING
// =============================================================================

/// Deduplicates a recommendation list so each job ID appears at most once,
/// preserving descending score order.
List<JobRecommendation> greedyOneToOne(
    List<JobRecommendation> recommendations,
    ) {
  final seen = <int>{};
  final result = <JobRecommendation>[];
  for (final rec in recommendations) {
    if (seen.add(rec.id)) result.add(rec);
  }
  return result;
}

/// Optimal greedy matching across multiple users and jobs.
///
/// Algorithm:
/// 1. Compute all (user, job) weighted TF-IDF cosine scores.
/// 2. Sort all pairs descending.
/// 3. Pick the best unmatched (user, job) pair.
/// 4. Remove both from the candidate pool.
/// 5. Repeat until exhaustion.
///
/// Returns a list of maps:
/// `{ 'userId', 'jobId', 'score', 'matchLabel', 'matchColor', 'matchPct' }`
List<Map<String, dynamic>> greedyMatch(
    Map<String, List<String>> userSkillsMap,
    Map<String, List<String>> jobSkillsMap,
    ) {
  if (userSkillsMap.isEmpty || jobSkillsMap.isEmpty) return [];

  // Pre-compute all (user × job) pair scores.
  final allPairs = <Map<String, dynamic>>[];

  for (final userEntry in userSkillsMap.entries) {
    final userId = userEntry.key;
    final userSkills = _normalise(userEntry.value);
    if (userSkills.isEmpty) continue;
    final userVector = termFrequency(
      userSkills,
      attentionWeights: kDomainWeights,
      skillTerms: userSkills.toSet(),
    );

    for (final jobEntry in jobSkillsMap.entries) {
      final jobId = jobEntry.key;
      final jobSkills = _normalise(jobEntry.value);
      if (jobSkills.isEmpty) continue;
      final jobVector = termFrequency(
        jobSkills,
        attentionWeights: kDomainWeights,
        skillTerms: jobSkills.toSet(),
      );

      final score = _cosineSim(
        userVector,
        jobVector,
        normalize: true,
        attentionWeights: kDomainWeights,
      );

      allPairs.add({
        'userId': userId,
        'jobId': jobId,
        'score': score,
        'matchLabel': getMatchLabel(score),
        'matchColor': getMatchColor(score),
        'matchPct': formatScoreAsPercent(score),
      });
    }
  }

  allPairs.sort(
        (a, b) => (b['score'] as double).compareTo(a['score'] as double),
  );

  final matchedUsers = <String>{};
  final matchedJobs = <String>{};
  final results = <Map<String, dynamic>>[];

  for (final pair in allPairs) {
    final userId = pair['userId'] as String;
    final jobId = pair['jobId'] as String;
    if (matchedUsers.contains(userId) || matchedJobs.contains(jobId)) continue;
    results.add(pair);
    matchedUsers.add(userId);
    matchedJobs.add(jobId);
    if (matchedUsers.length >= userSkillsMap.length) break;
  }

  return results;
}

// =============================================================================
// §10 MMR DIVERSITY RE-RANKING
// =============================================================================
// Maximal Marginal Relevance balances relevance and novelty to diversify
// the top-K result list.
//
// MMR(d) = λ × sim(d, query) − (1 − λ) × max_{d′ ∈ S} sim(d, d′)
//
// λ = 1.0 → pure relevance | λ = 0.0 → pure diversity.
// =============================================================================

/// Re-ranks [candidates] using Maximal Marginal Relevance.
///
/// [userVector] — TF-IDF vector for the query (user skills).
/// [lambda]     — trade-off: 1.0 = pure relevance, 0.0 = pure diversity.
/// [topN]       — number of results to return.
List<JobRecommendation> mmrRerank(
    List<JobRecommendation> candidates,
    Map<String, double> userVector, {
      double lambda = 0.5,
      int? topN,
    }) {
  if (candidates.isEmpty) return candidates;
  final k = (topN ?? candidates.length).clamp(1, candidates.length);

  // Pre-build job vectors once to avoid repeated computation in the loop.
  final jobVectors = <int, Map<String, double>>{};
  for (final rec in candidates) {
    final skills = [...rec.matching, ...rec.missing]
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toList();
    jobVectors[rec.id] = termFrequency(
      skills,
      attentionWeights: kDomainWeights,
      skillTerms: skills.toSet(),
    );
  }

  final selected = <JobRecommendation>[];
  final remaining = List<JobRecommendation>.from(candidates);

  while (selected.length < k && remaining.isNotEmpty) {
    double bestMmr = double.negativeInfinity;
    int bestIdx = 0;

    for (int i = 0; i < remaining.length; i++) {
      final rec = remaining[i];
      final jVec = jobVectors[rec.id]!;

      final relScore = _cosineSim(
        userVector,
        jVec,
        normalize: true,
        attentionWeights: kDomainWeights,
      );

      double maxSimToSelected = 0.0;
      for (final sel in selected) {
        final sVec = jobVectors[sel.id]!;
        final s = _cosineSim(
          jVec,
          sVec,
          normalize: true,
          attentionWeights: kDomainWeights,
        );
        if (s > maxSimToSelected) maxSimToSelected = s;
      }

      final mmrScore = lambda * relScore - (1.0 - lambda) * maxSimToSelected;
      if (mmrScore > bestMmr) {
        bestMmr = mmrScore;
        bestIdx = i;
      }
    }
    selected.add(remaining.removeAt(bestIdx));
  }

  return selected;
}

// =============================================================================
// §11 EXPLAINABILITY — "WHY MATCHED"
// =============================================================================

double _termContribution(
    String term,
    Map<String, double> userVector,
    Map<String, double> jobVector,
    ) {
  final u = userVector[term] ?? 0.0;
  final j = jobVector[term] ?? 0.0;
  final w = kDomainWeights[term] ?? 0.5;
  return u * j * w * w;
}

/// Returns the top-5 keyword pairs that most drove the match score,
/// with normalised contribution percentages.
///
/// Each map contains:
/// `{ 'userTerm', 'jobTerm', 'contribution' (0–1), 'contributionPct', 'weight' }`
List<Map<String, dynamic>> explainMatch(List<String> userSkills, Job job) {
  if (userSkills.isEmpty || job.skills.isEmpty) return [];
  final normUser = _normalise(userSkills);
  final normJob = _normalise(job.skills);
  final userSet = normUser.toSet();
  final jobSet = normJob.toSet();
  final shared = userSet.intersection(jobSet);
  if (shared.isEmpty) return [];

  final userVector = termFrequency(
    normUser,
    attentionWeights: kDomainWeights,
    skillTerms: userSet,
  );
  final jobVector = termFrequency(
    normJob,
    attentionWeights: kDomainWeights,
    skillTerms: jobSet,
  );

  final rawContribs = <String, double>{};
  var total = 0.0;
  for (final term in shared) {
    final c = _termContribution(term, userVector, jobVector);
    if (c > 0.0) {
      rawContribs[term] = c;
      total += c;
    }
  }

  if (total == 0.0) {
    for (final term in shared) {
      rawContribs[term] = 1.0 / shared.length;
    }
    total = 1.0;
  }

  final sorted = rawContribs.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return sorted.take(5).map((e) {
    final norm = e.value / total;
    return {
      'userTerm': e.key,
      'jobTerm': e.key,
      'contribution': double.parse(norm.toStringAsFixed(4)),
      'contributionPct': '${(norm * 100).toStringAsFixed(0)}%',
      'weight': kDomainWeights[e.key] ?? 0.5,
    };
  }).toList();
}

/// Returns a human-readable explanation string for a user–job match.
///
/// Example: `"Matched because: Python (34%), SQL (22%), Machine Learning (18%)"`
String getMatchExplanation(List<String> userSkills, Job job) {
  final pairs = explainMatch(userSkills, job);
  if (pairs.isEmpty) {
    final commonCount = userSkills
        .map((s) => s.toLowerCase().trim())
        .where(job.skills.map((s) => s.toLowerCase().trim()).toSet().contains)
        .length;
    return commonCount == 0
        ? 'Low match — few overlapping skills with this role.'
        : 'Matched on $commonCount shared skill${commonCount == 1 ? '' : 's'}.';
  }
  final parts = pairs.map((p) {
    final term = _capitaliseFirst(p['userTerm'] as String);
    final pct = p['contributionPct'] as String;
    return '$term ($pct)';
  }).join(', ');
  return 'Matched because: $parts';
}

// =============================================================================
// §12 SKILL GAP ANALYSIS
// =============================================================================

/// Builds a detailed [SkillGapReport] for a single candidate–job pair.
SkillGapReport buildSkillGapReport(
    List<String> userSkills,
    Job job,
    CareerProfile? profile,
    ) {
  final userSet = _normalise(userSkills).toSet();
  final jobNorm = _normalise(job.skills);

  final matched = jobNorm.where(userSet.contains).toList();
  final missing = jobNorm.where((s) => !userSet.contains(s)).toList();

  final criticals = missing
      .where((s) => (kDomainWeights[s] ?? 0.0) >= 0.80)
      .toList();
  final devGaps = missing
      .where((s) {
    final w = kDomainWeights[s] ?? 0.0;
    return w >= 0.50 && w < 0.80;
  })
      .toList();
  final niceToHave = missing
      .where((s) => (kDomainWeights[s] ?? 0.0) < 0.50)
      .toList();

  final suggestedCourses = <String, Course?>{};
  for (final gap in criticals) {
    suggestedCourses[gap] = _findBestCourse(gap, profile);
  }

  final readiness = job.skills.isEmpty
      ? 0.0
      : (matched.length / job.skills.length).clamp(0.0, 1.0);

  // Rough effort estimate: ~3 weeks per critical gap, ~1.5 per development gap.
  final weeksToReady = (criticals.length * 3 + devGaps.length * 1.5).round();

  return SkillGapReport(
    matchedSkills: matched,
    missingSkills: missing,
    criticalGaps: criticals,
    developmentGaps: devGaps,
    niceToHaveGaps: niceToHave,
    suggestedCourses: suggestedCourses,
    readinessScore: readiness,
    estimatedWeeksToReady: weeksToReady,
  );
}

// =============================================================================
// §13 CROSS-DOMAIN TRANSFER DETECTION
// =============================================================================

/// Curated cross-domain bridge map.
/// Maps a source skill → list of `{ 'target', 'score' }` bridges.
const Map<String, List<Map<String, dynamic>>> _kTransferBridges = {
  // Civil / Mechanical Engineering → Data
  'autocad': [
    {'target': 'data visualization', 'score': 0.45},
  ],
  'structural analysis': [
    {'target': 'data analysis', 'score': 0.62},
  ],
  'qa/qc': [
    {'target': 'data validation', 'score': 0.71},
    {'target': 'testing', 'score': 0.68},
  ],
  'project scheduling': [
    {'target': 'project management', 'score': 0.78},
    {'target': 'agile', 'score': 0.55},
  ],
  'cost estimation': [
    {'target': 'data analysis', 'score': 0.58},
    {'target': 'excel', 'score': 0.72},
  ],
  'site supervision': [
    {'target': 'stakeholder', 'score': 0.60},
    {'target': 'leadership', 'score': 0.65},
  ],
  // Finance / Accounting → Data
  'financial modeling': [
    {'target': 'data analysis', 'score': 0.74},
    {'target': 'excel', 'score': 0.85},
    {'target': 'sql', 'score': 0.55},
  ],
  'risk analysis': [
    {'target': 'statistical analysis', 'score': 0.70},
    {'target': 'machine learning', 'score': 0.50},
  ],
  'forecasting': [
    {'target': 'statistical analysis', 'score': 0.75},
    {'target': 'python', 'score': 0.45},
  ],
  'pivot tables': [
    {'target': 'data analysis', 'score': 0.68},
    {'target': 'tableau', 'score': 0.60},
  ],
  // Marketing → Data / Product
  'a/b testing': [
    {'target': 'statistical analysis', 'score': 0.72},
    {'target': 'testing', 'score': 0.65},
  ],
  'google analytics': [
    {'target': 'data analysis', 'score': 0.75},
    {'target': 'sql', 'score': 0.52},
  ],
  'seo': [
    {'target': 'data analysis', 'score': 0.58},
    {'target': 'api', 'score': 0.42},
  ],
  'campaign management': [
    {'target': 'project management', 'score': 0.68},
    {'target': 'stakeholder', 'score': 0.62},
  ],
  // Healthcare → Data Science
  'clinical research': [
    {'target': 'research', 'score': 0.82},
    {'target': 'statistical analysis', 'score': 0.73},
  ],
  'patient data': [
    {'target': 'database', 'score': 0.65},
    {'target': 'data analysis', 'score': 0.70},
  ],
  'ehr': [
    {'target': 'database', 'score': 0.68},
    {'target': 'sql', 'score': 0.55},
  ],
  // General transferable
  'report writing': [
    {'target': 'documentation', 'score': 0.75},
    {'target': 'communication', 'score': 0.70},
  ],
  'data collection': [
    {'target': 'data analysis', 'score': 0.72},
    {'target': 'etl', 'score': 0.58},
  ],
  'presentation': [
    {'target': 'communication', 'score': 0.78},
    {'target': 'stakeholder', 'score': 0.65},
  ],
  'team management': [
    {'target': 'leadership', 'score': 0.75},
    {'target': 'scrum', 'score': 0.60},
  ],
  'problem solving': [
    {'target': 'machine learning', 'score': 0.42},
    {'target': 'research', 'score': 0.55},
  ],
  'mathematics': [
    {'target': 'machine learning', 'score': 0.68},
    {'target': 'statistical analysis', 'score': 0.75},
    {'target': 'python', 'score': 0.52},
  ],
  'statistics': [
    {'target': 'machine learning', 'score': 0.72},
    {'target': 'statistical analysis', 'score': 0.90},
    {'target': 'r', 'score': 0.65},
  ],
  'matlab': [
    {'target': 'python', 'score': 0.65},
    {'target': 'machine learning', 'score': 0.58},
    {'target': 'r', 'score': 0.60},
  ],
};

/// Detects cross-domain skills that transfer from a user's background to
/// the target job's required skills.
///
/// Pass 1: curated bridge map (high precision).
/// Pass 2: semantic θ fallback via [SkillSimilarityEngine] (higher recall).
///
/// Minimum transfer score to include: 0.35.
List<Map<String, dynamic>> detectTransferableSkills(
    List<String> userSkills,
    Job job,
    ) {
  if (userSkills.isEmpty || job.skills.isEmpty) return [];
  final normUser = _normalise(userSkills).toSet();
  final normJob = _normalise(job.skills).toSet();
  final direct = normUser.intersection(normJob);
  final transfers = <Map<String, dynamic>>[];
  final addedPairs = <String>{};

  // ── Pass 1: curated bridge map ───────────────────────────────────────────
  for (final userSkill in normUser) {
    if (direct.contains(userSkill)) continue;
    final bridges = _kTransferBridges[userSkill];
    if (bridges == null) continue;
    for (final bridge in bridges) {
      final target = bridge['target'] as String;
      final baseScore = bridge['score'] as double;
      if (!normJob.contains(target)) continue;
      final key = '$userSkill→$target';
      if (!addedPairs.add(key)) continue;
      transfers.add({
        'userSkill': userSkill,
        'jobSkill': target,
        'transferScore': baseScore,
        'transferPct': formatScoreAsPercent(baseScore),
        'source': 'domain_bridge',
        'explanation':
        'Your ${_capitaliseFirst(userSkill)} experience is transferable '
            'to ${_capitaliseFirst(target)} '
            '(${formatScoreAsPercent(baseScore)} compatibility).',
      });
    }
  }

  // ── Pass 2: semantic θ fallback ──────────────────────────────────────────
  // SkillSimilarityEngine.calculateTheta takes exactly two positional args
  // (userSkill, jobSkill) — no third argument.
  final engine = SkillSimilarityEngine(
    jobIds: allJobs.map((j) => j.id.toString()).toList(),
    rcaCalculator: RCACalculator(
      {for (final j in allJobs) j.id.toString(): j.skills},
    ),
  );

  for (final userSkill in normUser) {
    if (direct.contains(userSkill)) continue;
    if (_kTransferBridges.containsKey(userSkill)) continue;

    for (final jobSkill in normJob) {
      if (direct.contains(jobSkill)) continue;
      final key = '$userSkill→$jobSkill';
      if (addedPairs.contains(key)) continue;

      final userTokens = userSkill.split(RegExp(r'[\s/\-_]'));
      final jobTokens = jobSkill.split(RegExp(r'[\s/\-_]'));
      final sharedToks = userTokens
          .where((t) => t.length > 2 && jobTokens.contains(t))
          .length;

      double theta = 0.0;
      try {
        theta = engine.calculateTheta(userSkill, jobSkill);
      } catch (_) {
        theta = 0.0;
      }

      final boost = sharedToks > 0
          ? (sharedToks / userTokens.length).clamp(0.0, 0.4)
          : 0.0;
      final transferScore = (theta + boost).clamp(0.0, 1.0);
      if (transferScore < 0.35) continue;

      addedPairs.add(key);
      transfers.add({
        'userSkill': userSkill,
        'jobSkill': jobSkill,
        'transferScore': transferScore,
        'transferPct': formatScoreAsPercent(transferScore),
        'source': 'semantic_similarity',
        'explanation':
        'Your ${_capitaliseFirst(userSkill)} skill shows semantic overlap '
            'with ${_capitaliseFirst(jobSkill)} required by this role '
            '(${formatScoreAsPercent(transferScore)} compatibility).',
      });
    }
  }

  transfers.sort(
        (a, b) =>
        (b['transferScore'] as double).compareTo(a['transferScore'] as double),
  );
  return transfers;
}

// =============================================================================
// §14 BIAS AUDIT
// =============================================================================

/// Flags recommendations when a single industry or company dominates the
/// top [auditWindow] results beyond [dominanceThreshold].
List<JobRecommendation> auditBias(
    List<JobRecommendation> recommendations, {
      double dominanceThreshold = 0.60,
      int auditWindow = 10,
    }) {
  if (recommendations.isEmpty) return recommendations;
  final window = recommendations.take(auditWindow).toList();
  final total = window.length.toDouble();

  final indCount = <String, int>{};
  final compCount = <String, int>{};
  for (final r in window) {
    indCount[r.industry] = (indCount[r.industry] ?? 0) + 1;
    compCount[r.company] = (compCount[r.company] ?? 0) + 1;
  }

  final domInd = indCount.entries
      .where((e) => e.value / total > dominanceThreshold)
      .map((e) => e.key)
      .toSet();
  final domComp = compCount.entries
      .where((e) => e.value / total > dominanceThreshold)
      .map((e) => e.key)
      .toSet();

  return recommendations.map((rec) {
    final flagged =
        domInd.contains(rec.industry) || domComp.contains(rec.company);
    return flagged ? rec.withBiasFlag() : rec;
  }).toList();
}

// =============================================================================
// §15 PERCENTILE RANK NORMALISATION
// =============================================================================

/// Annotates each recommendation with its percentile rank in the result list.
///
/// Rank 100 = highest score, rank 0 = lowest score.
List<JobRecommendation> attachPercentileRanks(
    List<JobRecommendation> sorted,
    ) {
  if (sorted.isEmpty) return sorted;
  final n = sorted.length;
  return List.generate(n, (i) {
    final pct = n == 1 ? 100.0 : (1.0 - i / (n - 1)) * 100.0;
    return sorted[i].withPercentileRank(double.parse(pct.toStringAsFixed(1)));
  });
}

// =============================================================================
// §16 RECOMMENDATION CACHE
// =============================================================================

/// Simple in-memory LRU-style cache for recommendation results.
///
/// Keyed by a canonical hash of `(userSkills, configHash)`.
final class RecommendationCache {
  RecommendationCache({this.maxSize = 50});

  final int maxSize;
  final _store = <String, List<JobRecommendation>>{};

  /// Returns cached results for [key], or `null` on a cache miss.
  List<JobRecommendation>? get(String key) => _store[key];

  /// Stores [results] under [key]. Evicts the oldest entry when at capacity.
  void put(String key, List<JobRecommendation> results) {
    if (_store.length >= maxSize) {
      _store.remove(_store.keys.first);
    }
    _store[key] = results;
  }

  /// Clears all cached entries.
  void clear() => _store.clear();

  int get size => _store.length;

  /// Builds a cache key from the user's normalised skills and config.
  static String buildKey(
      List<String> userSkills,
      RecommendationConfig config,
      ) {
    final skillsHash = userSkills.map((s) => s.toLowerCase().trim()).join('|');
    return '${skillsHash}_${config.minScore}_${config.industry}_'
        '${config.level}_${config.remoteOnly}_${config.strategy.name}';
  }
}

// =============================================================================
// §17 MAIN RECOMMENDER
// =============================================================================

/// Unified job recommendation function.
///
/// Combines weighted TF-IDF + Cosine, BM25 saturation, Jaccard, Skill
/// Coverage, temporal decay, negative sampling, MMR re-ranking, greedy
/// deduplication, bias audit, and full explainability in a single pipeline.
///
/// Pass a [RecommendationConfig] to control every aspect of the pipeline.
/// Use [cache] to avoid recomputing identical queries.
List<JobRecommendation> recommendJobs(
    List<String> userSkills, {
      RecommendationConfig config = const RecommendationConfig(),
      CareerProfile? profile,
      RecommendationCache? cache,
    }) {
  // ── Cache lookup ──────────────────────────────────────────────────────────
  final cacheKey = cache != null
      ? RecommendationCache.buildKey(userSkills, config)
      : null;
  if (cacheKey != null) {
    final cached = cache!.get(cacheKey);
    if (cached != null) return cached;
  }

  // ── Skill resolution ──────────────────────────────────────────────────────
  final effectiveSkills = (config.skillsByPeriod?.isNotEmpty ?? false)
      ? applyTemporalDecay(
    config.skillsByPeriod!,
    decayRate: config.temporalDecayRate,
  )
      : userSkills;
  if (effectiveSkills.isEmpty) return [];

  final aw = config.attentionWeights ?? kDomainWeights;
  final normUserSkills = _normalise(effectiveSkills);
  final userSkillSet = normUserSkills.toSet();
  final userVector = termFrequency(
    normUserSkills,
    attentionWeights: aw,
    skillTerms: userSkillSet,
  );

  final results = <JobRecommendation>[];

  // ── Per-job scoring ───────────────────────────────────────────────────────
  for (final job in allJobs) {
    // ── Filter guards ────────────────────────────────────────────────────────
    if (config.remoteOnly == true && !job.remote) continue;
    if (_activeFilter(config.industry) && job.industry != config.industry) {
      continue;
    }
    if (_activeFilter(config.level) && job.level != config.level) continue;
    if (config.maxExperience != null &&
        job.experience > config.maxExperience!) {
      continue;
    }

    final normJob = _normalise(job.skills);
    if (normJob.isEmpty) continue;
    final jobSet = normJob.toSet();
    final jobVector = termFrequency(
      normJob,
      attentionWeights: aw,
      skillTerms: jobSet,
    );

    final matching = normJob.where(userSkillSet.contains).toList();
    final missing = normJob.where((s) => !userSkillSet.contains(s)).toList();

    // ── Core scoring ─────────────────────────────────────────────────────────
    final cosineScore = _cosineSim(
      userVector,
      jobVector,
      normalize: true,
      attentionWeights: aw,
    );
    final jaccardScore = jaccardSimilarity(userSkillSet, jobSet);
    final coverageScore = skillCoverage(
      candidateSkills: userSkillSet,
      requiredSkills: jobSet,
    );
    final bm25Component = config.strategy == ScoringStrategy.bm25Ensemble
        ? _bm25Score(userSkillSet, jobSet)
        : 0.0;

    final double score;
    switch (config.strategy) {
      case ScoringStrategy.jaccard:
        score = jaccardScore;
      case ScoringStrategy.bm25Ensemble:
      // BM25 replaces the cosine component; weights still govern
      // jaccard and coverage.
        score = bm25Component * config.weights.cosine +
            jaccardScore * config.weights.jaccard +
            coverageScore * config.weights.coverage;
      case ScoringStrategy.tfidfCosine:
        score = cosineScore * config.weights.cosine +
            jaccardScore * config.weights.jaccard +
            coverageScore * config.weights.coverage;
    }

    // ── Career-profile experience penalty ─────────────────────────────────
    double finalScore = score;
    if (profile != null && job.experience > profile.experienceYears + 1) {
      finalScore *= 0.7;
    }
    if (finalScore < config.minScore) continue;

    // ── Explainability (lazy — skip for bulk scoring) ──────────────────────
    List<Map<String, dynamic>> topPairs = const [];
    String explanation = '';
    List<Map<String, dynamic>> transfers = const [];
    SkillGapReport? gapReport;

    if (config.withExplainability) {
      topPairs = explainMatch(userSkills, job);
      explanation = getMatchExplanation(userSkills, job);
      gapReport = buildSkillGapReport(userSkills, job, profile);
    }
    if (config.includeTransfer) {
      transfers = detectTransferableSkills(userSkills, job);
    }

    results.add(JobRecommendation(
      id: job.id,
      title: job.title,
      company: job.company,
      score: finalScore,
      matchRatio: jaccardScore,
      coverageRatio: coverageScore,
      bm25Component: bm25Component,
      matching: matching,
      missing: missing,
      location: job.location,
      type: job.type,
      level: job.level,
      salary: job.salary,
      remote: job.remote,
      industry: job.industry,
      workingMode: job.workingMode,
      experience: job.experience,
      topMatchedPairs: topPairs,
      matchExplanation: explanation,
      transferableSkills: transfers,
      gapReport: gapReport,
    ));
  }

  // ── Sort: score → coverage → fewest missing ───────────────────────────────
  results.sort((a, b) {
    final sc = b.score.compareTo(a.score);
    if (sc != 0) return sc;
    final cc = b.coverageRatio.compareTo(a.coverageRatio);
    if (cc != 0) return cc;
    return a.missing.length.compareTo(b.missing.length);
  });

  // ── Post-processing pipeline ──────────────────────────────────────────────
  List<JobRecommendation> output = results;

  if (config.negativeJobSkills?.isNotEmpty ?? false) {
    output = applyNegativeSampling(
      output,
      config.negativeJobSkills!,
      threshold: config.negativeSamplingThreshold,
      attentionWeights: aw,
    );
  }

  if (config.greedyMatchDedup) output = greedyOneToOne(output);

  if (config.runBiasAudit) {
    output = auditBias(
      output,
      dominanceThreshold: config.biasThreshold,
      auditWindow: config.biasWindow,
    );
  }

  if (config.includeMmrReranking && output.length > 1) {
    output = mmrRerank(
      output,
      userVector,
      lambda: config.mmrLambda,
      topN: config.topN,
    );
  }

  output = attachPercentileRanks(output);

  if (config.topN != null &&
      config.topN! > 0 &&
      config.topN! < output.length) {
    output = output.sublist(0, config.topN!);
  }

  // ── Cache store ───────────────────────────────────────────────────────────
  if (cacheKey != null) cache!.put(cacheKey, output);

  return output;
}

// =============================================================================
// §18 BATCH RECOMMENDATION
// =============================================================================

/// Runs [recommendJobs] for every user in [userSkillsMap] in a single call.
///
/// Returns a map of `{ userId → List<JobRecommendation> }`.
/// Each user is scored independently so results are not cross-contaminated.
Map<String, List<JobRecommendation>> recommendBatch(
    Map<String, List<String>> userSkillsMap, {
      RecommendationConfig config = const RecommendationConfig(),
      Map<String, CareerProfile>? profiles,
      RecommendationCache? cache,
    }) {
  final results = <String, List<JobRecommendation>>{};
  for (final entry in userSkillsMap.entries) {
    results[entry.key] = recommendJobs(
      entry.value,
      config: config,
      profile: profiles?[entry.key],
      cache: cache,
    );
  }
  return results;
}

// =============================================================================
// §19 COURSE RECOMMENDATION
// =============================================================================

/// Returns the highest-rated course whose title or skill set contains
/// [targetTopic]. Returns `null` if no match is found.
Course? recommendCourseForTopic(
    String targetTopic,
    CareerProfile profile,
    ) {
  final norm = targetTopic.trim().toLowerCase();
  if (norm.isEmpty) return null;
  return _findBestCourse(norm, profile);
}

// =============================================================================
// §20 PREFERENCE VECTOR FEEDBACK STUB
// =============================================================================

/// No-op stub — preserved for API compatibility with future learner
/// preference-vector updates.
void updatePreferenceOnFeedback(
    CareerProfile profile,
    String courseId,
    double rating,
    FeedbackSignal signal,
    ) {
  // No-op: implement when CareerProfile gains short-term vector support.
}

// =============================================================================
// §21 EVALUATION METRICS
// =============================================================================

/// Computes Precision@K, Recall@K, F1@K, NDCG@K, MRR, and AUC for each K.
///
/// Returns a nested map keyed by `'@K'`:
/// `{ 'precision', 'recall', 'f1', 'ndcg', 'mrr', 'auc' }`
///
/// **Note on NDCG log base:** Both DCG and IDCG use `log` (natural base)
/// consistently, so the bases cancel in the ratio. This differs from the
/// log2 convention in `cosine.dart` but produces identical NDCG values.
Map<String, Map<String, double>> evaluateRecommendations(
    List<JobRecommendation> recommendations,
    Set<int> relevantJobIds, {
      List<int> kValues = const [5, 10],
    }) {
  if (relevantJobIds.isEmpty || recommendations.isEmpty) {
    return {for (final k in kValues) '@$k': _zeroMetrics()};
  }

  final results = <String, Map<String, double>>{};

  // MRR (Mean Reciprocal Rank) — rank of the first relevant result.
  double mrr = 0.0;
  for (int i = 0; i < recommendations.length; i++) {
    if (relevantJobIds.contains(recommendations[i].id)) {
      mrr = 1.0 / (i + 1);
      break;
    }
  }

  for (final k in kValues) {
    final topK = recommendations.take(k).toList();
    final hits = topK.where((r) => relevantJobIds.contains(r.id)).length;
    final precision = hits / k;
    final recall = hits / relevantJobIds.length;
    final f1 = f1Score(precision, recall);

    // NDCG@K — both DCG and IDCG use natural log so bases cancel.
    double dcg = 0.0;
    double idcg = 0.0;
    for (int i = 0; i < topK.length; i++) {
      final rel = relevantJobIds.contains(topK[i].id) ? 1.0 : 0.0;
      dcg += rel / log(i + 2);
      idcg += (i < relevantJobIds.length ? 1.0 : 0.0) / log(i + 2);
    }
    final ndcg = idcg == 0.0 ? 0.0 : dcg / idcg;

    // AUC approximation: fraction of relevant items in the top 50%.
    final topHalf = recommendations
        .take((recommendations.length / 2).ceil())
        .where((r) => relevantJobIds.contains(r.id))
        .length;
    final auc = topHalf / relevantJobIds.length;

    results['@$k'] = {
      'precision': _r4(precision),
      'recall': _r4(recall),
      'f1': _r4(f1),
      'ndcg': _r4(ndcg),
      'mrr': _r4(mrr),
      'auc': _r4(auc),
    };
  }

  return results;
}

// =============================================================================
// §22 UTILITY BUILDERS
// =============================================================================

/// Builds a `{ jobId → [normalisedSkills] }` map from `allJobs`.
Map<String, List<String>> buildJobSkillsMap() {
  return {
    for (final job in allJobs) job.id.toString(): _normalise(job.skills),
  };
}

/// Extracts all unique skills from every job listing (sorted alphabetically).
List<String> extractAllJobSkills() {
  final skills = <String>{};
  for (final job in allJobs) {
    skills.addAll(job.skills.map((s) => s.trim().toLowerCase()));
  }
  return skills.toList()..sort();
}

/// Returns the top-K most in-demand skills across all jobs,
/// sorted by frequency descending.
List<MapEntry<String, int>> topInDemandSkills({int topK = 20}) {
  final freq = <String, int>{};
  for (final job in allJobs) {
    for (final skill in job.skills) {
      final s = skill.trim().toLowerCase();
      if (s.isNotEmpty) freq[s] = (freq[s] ?? 0) + 1;
    }
  }
  final sorted = freq.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted.take(topK).toList();
}

// =============================================================================
// §23 PRIVATE HELPERS
// =============================================================================

/// Normalises a skill list: trim, lowercase, remove empties.
List<String> _normalise(List<String> skills) => skills
    .map((s) => s.trim().toLowerCase())
    .where((s) => s.isNotEmpty)
    .toList();

/// Returns `true` when a filter string is active (not null / not 'All').
bool _activeFilter(String? v) => v != null && v != 'All';

/// Capitalises the first character of a string.
String _capitaliseFirst(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Rounds a double to 4 decimal places.
double _r4(double v) => double.parse(v.toStringAsFixed(4));

/// Returns a metrics map filled with zeros.
Map<String, double> _zeroMetrics() => {
  'precision': 0.0,
  'recall': 0.0,
  'f1': 0.0,
  'ndcg': 0.0,
  'mrr': 0.0,
  'auc': 0.0,
};

/// Returns the best-matching course for [topic] from the course catalogue.
Course? _findBestCourse(String topic, CareerProfile? profile) {
  final norm = topic.trim().toLowerCase();
  if (norm.isEmpty) return null;
  final candidates = courses.where((c) {
    return c.title.toLowerCase().contains(norm) ||
        c.skills.any((s) => s.toLowerCase().contains(norm));
  }).toList();
  if (candidates.isEmpty) return null;
  candidates.sort((a, b) => b.rating.compareTo(a.rating));
  return candidates.first;
}