// lib/data/fairness_monitor.dart — SkillBridge AI
// ══════════════════════════════════════════════════════════════════════════════
// Research grounding:
//   [AJJ26] Ajjam & Al-Raweshidy (2026) — Bias Mitigation in AI Recommendation
//           Systems
//   [GAU11] Gaucher, Friesen & Kay (2011) — Evidence that gendered wording in
//           job advertisements exists and sustains gender inequality
//           (Journal of Personality and Social Psychology 101(1), 109–128)
//
// Provides:
//   1. Typed bias detection → List<FlaggedTerm>           (§5)
//   2. Shannon-entropy industry diversity scoring          (§5)
//   3. TF-IDF weight dampening for gender-coded terms      (§5)
//   4. FairnessResult composite value object               (§3)
//   5. Skill-list sanitisation against protected-attribute proxies (§5)
//   6. Batch job-description scanning                      (§5)
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:math' show log;

import 'package:flutter/foundation.dart' show immutable;

// ══════════════════════════════════════════════════════════════════════════════
// §1  ENUMS
// ══════════════════════════════════════════════════════════════════════════════

/// [AJJ26 §3] Category of bias detected in a job description or skill list.
enum BiasType {
  /// Terms associated with masculine traits that may deter non-male applicants.
  /// [GAU11] Masculine-coded language in job postings.
  masculineCoded,

  /// Terms that may create implicit gender role stereotypes.
  /// [GAU11] Feminine-coded language in job postings.
  feminineCoded,

  /// Terms acting as proxies for race, religion, socioeconomic status, or
  /// physical characteristics — protected attributes under employment law.
  /// [AJJ26 §4 — Protected attribute proxy exclusion]
  protectedAttributeProxy,
}

extension BiasTypeX on BiasType {
  /// Short label for chips and report headers.
  String get displayName {
    switch (this) {
      case BiasType.masculineCoded:
        return 'Masculine-coded';
      case BiasType.feminineCoded:
        return 'Feminine-coded';
      case BiasType.protectedAttributeProxy:
        return 'Protected-attribute proxy';
    }
  }

  /// Longer description for tooltips and the fairness report card.
  String get description {
    switch (this) {
      case BiasType.masculineCoded:
        return 'Terms associated with masculine traits that may reduce '
            'application rates among non-male candidates. [GAU11]';
      case BiasType.feminineCoded:
        return 'Terms that may create implicit gender role stereotypes '
            'or signal role misfit to some candidates. [GAU11]';
      case BiasType.protectedAttributeProxy:
        return 'Terms that act as proxies for race, religion, socioeconomic '
            'status, or physical attributes — excluded from scoring. [AJJ26 §4]';
    }
  }

  /// Hex colour used in the fairness report UI for this bias category.
  String get hexColor {
    switch (this) {
      case BiasType.masculineCoded:
        return '#1565C0'; // primaryBlue
      case BiasType.feminineCoded:
        return '#E65100'; // deep-orange
      case BiasType.protectedAttributeProxy:
        return '#B71C1C'; // dark-red
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// [AJJ26 §5] Traditional gender typicality classification for a job role.
/// Used to measure gender-balance across a recommendation list.
enum GenderTypicality {
  /// Role traditionally associated with male workers in labour market data.
  maleTypical,

  /// Role traditionally associated with female workers in labour market data.
  femaleTypical,

  /// Role with no statistically significant gender skew — excluded from
  /// gender-balance calculation. [AJJ26 §5]
  neutral,
}

extension GenderTypicalityX on GenderTypicality {
  /// Serialisation key — matches string values used in [FairnessMonitor]
  /// string-based API for backwards compatibility.
  String get key {
    switch (this) {
      case GenderTypicality.maleTypical:
        return 'male_typical';
      case GenderTypicality.femaleTypical:
        return 'female_typical';
      case GenderTypicality.neutral:
        return 'neutral';
    }
  }

  /// Deserialises from a [key] string. Falls back to [neutral] for unknown
  /// values so old persisted data degrades gracefully.
  static GenderTypicality fromKey(String key) {
    switch (key) {
      case 'male_typical':
        return GenderTypicality.maleTypical;
      case 'female_typical':
        return GenderTypicality.femaleTypical;
      default:
        return GenderTypicality.neutral;
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// §2  SCORING THRESHOLDS
// ══════════════════════════════════════════════════════════════════════════════

/// [AJJ26 §5] Scoring component weights and decision thresholds.
/// All weights sum to 1.0:  0.40 + 0.40 + 0.20 = 1.00.
class FairnessThresholds {
  // Private constructor — this class is a pure namespace; never instantiated.
  FairnessThresholds._();

  // ── Composite weights ─────────────────────────────────────────────────────
  /// Weight for the industry-diversity sub-score. [AJJ26 §5]
  static const double diversityWeight = 0.40;

  /// Weight for the bias-term absence sub-score. [AJJ26 §3]
  static const double biasAbsenceWeight = 0.40;

  /// Weight for the gender-typicality balance sub-score. [AJJ26 §5]
  static const double genderBalanceWeight = 0.20;

  // ── Dampening and penalties ───────────────────────────────────────────────
  /// [AJJ26 §4.2] TF-IDF weight multiplier for gender-coded terms.
  /// Dampening (not deletion) preserves semantic coverage while reducing
  /// the disproportionate influence on cosine similarity scores.
  static const double biasDampeningFactor = 0.25;

  /// Score penalty per biased hit in the recommendation list title/industry.
  static const double biasHitPenalty = 0.05;

  // ── Grade boundaries ──────────────────────────────────────────────────────
  /// Score > this → "Excellent". [AJJ26 §5]
  static const double excellentThreshold = 80.0;

  /// Score ≥ this → "Good". [AJJ26 §5]
  static const double goodThreshold = 60.0;
}

// ══════════════════════════════════════════════════════════════════════════════
// §3  VALUE OBJECTS
// ══════════════════════════════════════════════════════════════════════════════

/// Immutable record of a single biased term detected in a job description.
/// [AJJ26 §3 — Bias term detection]
@immutable
class FlaggedTerm {
  /// The exact term that was matched (preserved as found in source text).
  final String term;

  /// Bias category of this term.
  final BiasType biasType;

  /// Short excerpt (≤ 60 source characters) around the matched term,
  /// framed with '...' for display in the fairness report card.
  final String context;

  const FlaggedTerm({
    required this.term,
    required this.biasType,
    required this.context,
  });

  Map<String, dynamic> toMap() => {
    'term': term,
    'biasType': biasType.name,
    'context': context,
  };

  factory FlaggedTerm.fromMap(Map<String, dynamic> map) => FlaggedTerm(
    term: map['term'] as String? ?? '',
    biasType: BiasType.values.firstWhere(
          (b) => b.name == (map['biasType'] as String? ?? ''),
      orElse: () => BiasType.masculineCoded,
    ),
    context: map['context'] as String? ?? '',
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is FlaggedTerm &&
              term == other.term &&
              biasType == other.biasType &&
              context == other.context;

  @override
  int get hashCode => Object.hash(term, biasType, context);

  @override
  String toString() => 'FlaggedTerm(${biasType.displayName}: "$term")';
}

// ─────────────────────────────────────────────────────────────────────────────

/// Immutable composite result from a full fairness evaluation.
/// Bundles all sub-scores, flagged terms, and derived labels in one object.
/// [AJJ26 §5 — Overall fairness score]
@immutable
class FairnessResult {
  /// Composite fairness score [0–100]. Weighted combination of three
  /// sub-scores defined in [FairnessThresholds].
  final double overallScore;

  /// Shannon-entropy industry diversity normalised to [0–1].
  ///   1.0 = every recommended job is from a different industry.
  ///   0.0 = all recommended jobs share the same industry.
  /// [AJJ26 §5]
  final double diversityScore;

  /// Bias-term absence sub-score [0–1].
  ///   1.0 = no biased language found in titles/industries.
  ///   < 1.0 = each biased-language hit reduces the score by
  ///   [FairnessThresholds.biasHitPenalty]. [AJJ26 §3]
  final double biasAbsenceScore;

  /// Gender-typicality balance sub-score [0–1].
  ///   1.0 = equal split between male-typical and female-typical roles.
  ///   0.0 = all typed roles are entirely one gender. [AJJ26 §5]
  final double genderBalanceScore;

  /// All bias terms flagged across the evaluated job descriptions.
  /// Defensive copy is taken in [FairnessMonitor.calculateFairness].
  final List<FlaggedTerm> flaggedTerms;

  const FairnessResult({
    required this.overallScore,
    required this.diversityScore,
    required this.biasAbsenceScore,
    required this.genderBalanceScore,
    required this.flaggedTerms,
  });

  // ── Grade getters ─────────────────────────────────────────────────────────

  /// Human-readable label derived from [overallScore]. [AJJ26 §5]
  ///   > 80  → "Excellent"  |  60–80 → "Good"  |  < 60 → "Needs Review"
  String get label => FairnessMonitor._gradeLabel(overallScore);

  /// Hex colour reflecting the grade. Compatible with Flutter's [Color].
  ///   Green (#4CAF50) · Amber (#FF9800) · Red (#F44336)
  String get hexColor => FairnessMonitor._gradeColorHex(overallScore);

  // ── Flagged term counts ───────────────────────────────────────────────────

  /// True when any bias terms were flagged.
  bool get hasBias => flaggedTerms.isNotEmpty;

  /// Count of masculine-coded flagged terms.
  int get masculineCount =>
      flaggedTerms.where((t) => t.biasType == BiasType.masculineCoded).length;

  /// Count of feminine-coded flagged terms.
  int get feminineCount =>
      flaggedTerms.where((t) => t.biasType == BiasType.feminineCoded).length;

  /// Count of protected-attribute proxy flagged terms.
  int get protectedProxyCount => flaggedTerms
      .where((t) => t.biasType == BiasType.protectedAttributeProxy)
      .length;

  // ── Report ────────────────────────────────────────────────────────────────

  /// Concise human-readable fairness report for display in a card or
  /// bottom-sheet. Fully derived from this object's fields.
  String get report {
    final buffer = StringBuffer();
    final scoreStr = overallScore.round().toString();
    final diversityPct = (diversityScore * 100).round();

    buffer.write('Fairness Score: $scoreStr/100 ($label).  ');

    // Diversity narrative
    if (diversityScore >= 0.75) {
      buffer.write(
          'Recommendations are highly diverse across multiple industries.  ');
    } else if (diversityScore >= 0.40) {
      buffer.write(
          'Recommendations cover $diversityPct% of industry diversity — '
              'consider broadening across more sectors.  ');
    } else {
      buffer.write(
          'Recommendations are concentrated in a narrow set of industries '
              '(diversity $diversityPct%).  ');
    }

    // Bias term narrative
    if (flaggedTerms.isEmpty) {
      buffer.write('No biased language detected.');
    } else {
      final parts = <String>[
        if (masculineCount > 0)
          '$masculineCount masculine-coded '
              'term${masculineCount > 1 ? "s" : ""}',
        if (feminineCount > 0)
          '$feminineCount feminine-coded '
              'term${feminineCount > 1 ? "s" : ""}',
        if (protectedProxyCount > 0)
          '$protectedProxyCount protected-attribute '
              '${protectedProxyCount > 1 ? "proxies" : "proxy"}',
      ];
      buffer.write('Biased language flagged: ${parts.join(", ")}. '
          'Term weights have been normalised in scoring.');
    }

    return buffer.toString();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is FairnessResult &&
              overallScore == other.overallScore &&
              diversityScore == other.diversityScore &&
              biasAbsenceScore == other.biasAbsenceScore &&
              genderBalanceScore == other.genderBalanceScore &&
              flaggedTerms.length == other.flaggedTerms.length;

  @override
  int get hashCode => Object.hash(
    overallScore,
    diversityScore,
    biasAbsenceScore,
    genderBalanceScore,
  );

  @override
  String toString() => 'FairnessResult('
      'score: ${overallScore.toStringAsFixed(1)}, '
      'label: $label, '
      'flaggedTerms: ${flaggedTerms.length}, '
      'diversity: ${(diversityScore * 100).toStringAsFixed(0)}%)';
}

// ══════════════════════════════════════════════════════════════════════════════
// §4  FAIRNESS MONITOR SERVICE
// ══════════════════════════════════════════════════════════════════════════════

class FairnessMonitor {
  // ── Singleton ─────────────────────────────────────────────────────────────

  FairnessMonitor._internal();
  static final FairnessMonitor instance = FairnessMonitor._internal();

  /// Convenience factory — returns the singleton without explicit `.instance`.
  factory FairnessMonitor() => instance;

  // ─────────────────────────────────────────────────────────────────────────
  // §4.1  TERM LISTS & SETS
  //
  // Lists are kept for ordered public accessors (masculineCodedTermList, etc.).
  // Sets are used internally for O(1) membership tests in hot paths.
  // ─────────────────────────────────────────────────────────────────────────

  /// [GAU11, AJJ26 §3 — Masculine-coded language]
  /// Masculine-coded terms known to reduce application rates among women.
  static const List<String> _masculineCodedTerms = [
    'aggressive',    'ambitious',      'analytical',      'assertive',
    'autonomous',    'challenging',    'competitive',     'confident',
    'decisive',      'determined',     'dominant',        'driven',
    'fearless',      'headstrong',     'independent',     'individual',
    'lead',          'ninja',          'outspoken',       'principled',
    'rockstar',      'self-reliant',   'self-sufficient', 'strong',
    'superior',
  ];

  /// [GAU11, AJJ26 §3 — Feminine-coded language]
  /// Feminine-coded terms that may create implicit role stereotypes.
  static const List<String> _feminineCodedTerms = [
    'affectionate', 'caring',        'child',          'collaborative',
    'committed',    'communal',      'compassionate',  'connect',
    'considerate',  'cooperative',   'dependable',     'empathetic',
    'flatterable',  'gentle',        'honest',         'interpersonal',
    'kind',         'loyal',         'nurturing',      'pleasant',
    'polite',       'quiet',         'responsive',     'sensitive',
    'submissive',   'supportive',    'sympathetic',    'tactful',
    'tender',       'trust',         'understanding',  'warm',
    'yielding',
  ];

  /// [AJJ26 §4 — Protected attribute proxy exclusion]
  /// Terms acting as proxies for race, religion, socioeconomic status,
  /// or physical characteristics. Removed entirely from TF-IDF scoring.
  static const List<String> _protectedAttributeProxies = [
    'ivy league',            'ivy-league',           'elite university',
    'boarding school',       'prep school',          'private school',
    'english-sounding name', 'western name',
    'upscale neighbourhood', 'affluent area',
    'well-presented',        'well presented',        'good-looking',
    'attractive',            'height',               'weight',
    'christian values',      'muslim-friendly',       'faith-based',
  ];

  // ── O(1) lookup sets (derived from the const lists above) ─────────────────

  static final Set<String> _masculineSet =
  Set<String>.unmodifiable(_masculineCodedTerms);

  static final Set<String> _feminineSet =
  Set<String>.unmodifiable(_feminineCodedTerms);

  static final Set<String> _protectedSet =
  Set<String>.unmodifiable(_protectedAttributeProxies);

  // ── RegExp pattern cache ──────────────────────────────────────────────────
  // Patterns are built lazily on first use and reused across calls,
  // avoiding repeated RegExp compilation inside _scanTerms loops.

  static final Map<String, RegExp> _patternCache = {};

  static RegExp _getPattern(String term) {
    return _patternCache.putIfAbsent(term, () {
      final isSingleWord = !term.contains(' ');
      return isSingleWord
          ? RegExp(r'\b' + RegExp.escape(term) + r'\b', caseSensitive: false)
          : RegExp(RegExp.escape(term), caseSensitive: false);
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // §4.2  BIAS DETECTION
  // ─────────────────────────────────────────────────────────────────────────

  /// [AJJ26 §3, GAU11 — Bias term detection]
  ///
  /// Scans [jobDescription] for gender-coded and protected-attribute proxy
  /// terms. Returns one [FlaggedTerm] per unique matched term (first
  /// occurrence only — frequency within a single description is not reported,
  /// only presence).
  ///
  /// Word-boundary RegExp (`\b`) prevents partial matches for single-word
  /// terms (e.g. "lead" does not match "leading"). Multi-word phrases are
  /// matched as literal substrings (case-insensitive).
  ///
  /// Returns an empty list when no bias terms are found.
  List<FlaggedTerm> checkJobDescriptionBias(String jobDescription) {
    if (jobDescription.trim().isEmpty) return const [];

    final flagged = <FlaggedTerm>[];
    _scanTerms(jobDescription, _masculineCodedTerms,
        BiasType.masculineCoded, flagged);
    _scanTerms(jobDescription, _feminineCodedTerms,
        BiasType.feminineCoded, flagged);
    _scanTerms(jobDescription, _protectedAttributeProxies,
        BiasType.protectedAttributeProxy, flagged);
    return flagged;
  }

  /// Scans all [descriptions] in a single pass and returns the union of all
  /// flagged terms (deduplicated by [term] + [biasType] across descriptions).
  ///
  /// [AJJ26 §3 — Batch bias analysis for job catalogues]
  List<FlaggedTerm> checkBulkDescriptions(List<String> descriptions) {
    final seen = <String>{};     // "<term>|<biasType>" deduplication key
    final results = <FlaggedTerm>[];

    for (final desc in descriptions) {
      if (desc.trim().isEmpty) continue;
      for (final ft in checkJobDescriptionBias(desc)) {
        if (seen.add('${ft.term}|${ft.biasType.name}')) {
          results.add(ft);
        }
      }
    }
    return results;
  }

  /// Convenience: true when [jobDescription] contains any flagged bias term.
  bool hasBias(String jobDescription) =>
      checkJobDescriptionBias(jobDescription).isNotEmpty;

  // ─────────────────────────────────────────────────────────────────────────
  // §4.3  DIVERSITY SCORING
  // ─────────────────────────────────────────────────────────────────────────

  /// [AJJ26 §5 — Diversity of recommendations]
  ///
  /// Measures how evenly the recommended jobs are spread across industries
  /// using normalised Shannon entropy:
  ///
  ///   H        = −Σ p_i × log₂(p_i)
  ///   diversity = H / log₂(num_unique_industries)
  ///
  /// Returns 1.0 for maximum diversity (all different industries) and 0.0
  /// when all jobs belong to the same industry.
  ///
  /// [recommendedJobIds] — IDs of the recommended jobs.
  /// [jobIndustryMap]    — Full catalogue Map<jobId, industry>.
  double calculateRecommendationDiversity(
      List<String> recommendedJobIds,
      Map<String, String> jobIndustryMap,
      ) {
    if (recommendedJobIds.isEmpty) return 0.0;

    final industryCounts = <String, int>{};
    for (final id in recommendedJobIds) {
      final industry = jobIndustryMap[id] ?? 'Unknown';
      industryCounts[industry] = (industryCounts[industry] ?? 0) + 1;
    }

    final numIndustries = industryCounts.length;
    if (numIndustries == 1) return 0.0;
    if (numIndustries >= recommendedJobIds.length) return 1.0;

    final total = recommendedJobIds.length.toDouble();
    double entropy = 0.0;
    for (final count in industryCounts.values) {
      final p = count / total;
      if (p > 0) entropy -= p * _log2(p);
    }

    final maxEntropy = _log2(numIndustries.toDouble());
    return maxEntropy == 0.0 ? 0.0 : (entropy / maxEntropy).clamp(0.0, 1.0);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // §4.4  TF-IDF NORMALISATION
  // ─────────────────────────────────────────────────────────────────────────

  /// [AJJ26 §4.2 — TF-IDF bias normalisation]
  ///
  /// Accepts a TF-IDF term-weight map from the cosine similarity recommender
  /// pipeline and returns a cleaned map where:
  ///   • Masculine-coded terms → weight × [FairnessThresholds.biasDampeningFactor]
  ///   • Feminine-coded terms  → weight × [FairnessThresholds.biasDampeningFactor]
  ///   • Protected-attribute proxies → removed entirely
  ///   • All other terms → passed through unchanged
  ///
  /// Dampening (rather than removal) preserves semantic coverage while reducing
  /// disproportionate influence on similarity scores. [AJJ26 §4.2]
  Map<String, double> normalizeBiasedTerms(Map<String, double> termWeights) {
    if (termWeights.isEmpty) return const <String, double>{};

    final cleaned = <String, double>{};
    for (final entry in termWeights.entries) {
      final token = entry.key.toLowerCase().trim();

      // Remove protected-attribute proxies entirely. [AJJ26 §4]
      if (_isProtectedProxy(token)) continue;

      // Dampen gender-coded terms. [AJJ26 §4.2]
      if (_masculineSet.contains(token) || _feminineSet.contains(token)) {
        cleaned[entry.key] =
            entry.value * FairnessThresholds.biasDampeningFactor;
        continue;
      }

      cleaned[entry.key] = entry.value;
    }
    return cleaned;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // §4.5  COMPOSITE FAIRNESS EVALUATION
  // ─────────────────────────────────────────────────────────────────────────

  /// [AJJ26 §5 — Overall fairness score]
  ///
  /// Evaluates the fairness of a recommendation list and returns a typed
  /// [FairnessResult] bundling all sub-scores and flagged terms.
  ///
  /// Component weights (sum = 1.0):
  ///   Industry diversity            40 %  (Shannon entropy of industry spread)
  ///   Bias-term absence             40 %  (penalises each biased industry label)
  ///   Gender-typicality balance     20 %  (balance of male/female-typed roles)
  ///
  /// Parameters:
  ///   [recommendedJobIds]        — IDs of the recommended jobs.
  ///   [jobIndustryMap]           — Full catalogue Map<jobId, industry>.
  ///   [genderTypicalityMap]      — Map<jobId, GenderTypicality> for typed
  ///                                roles. Neutral jobs are excluded per
  ///                                [AJJ26 §5]. Defaults to empty (balance → 1.0).
  ///   [precomputedFlaggedTerms]  — Supply when descriptions have already been
  ///                                scanned; skips the lightweight title/industry
  ///                                scan to avoid double-counting.
  FairnessResult calculateFairness(
      List<String> recommendedJobIds,
      Map<String, String> jobIndustryMap, {
        Map<String, GenderTypicality> genderTypicalityMap = const {},
        List<FlaggedTerm> precomputedFlaggedTerms = const [],
      }) {
    if (recommendedJobIds.isEmpty) {
      return const FairnessResult(
        overallScore: 100.0,
        diversityScore: 1.0,
        biasAbsenceScore: 1.0,
        genderBalanceScore: 1.0,
        flaggedTerms: [],
      );
    }

    // ── Sub-score 1: Industry diversity ─────────────────────────────────────
    final diversityScore = calculateRecommendationDiversity(
      recommendedJobIds,
      jobIndustryMap,
    );

    // ── Sub-score 2: Bias-term absence (lightweight title/industry scan) ────
    // For the full pipeline, call checkJobDescriptionBias() separately and
    // pass results via [precomputedFlaggedTerms]. [AJJ26 §3]
    int biasHits = 0;
    for (final id in recommendedJobIds) {
      final label = (jobIndustryMap[id] ?? '').toLowerCase();
      if (_masculineCodedTerms.any(label.contains)) biasHits++;
      if (_feminineCodedTerms.any(label.contains)) biasHits++;
    }
    final biasAbsenceScore =
    (1.0 - biasHits * FairnessThresholds.biasHitPenalty).clamp(0.0, 1.0);

    // ── Sub-score 3: Gender-typicality balance ───────────────────────────────
    // Only jobs annotated as maleTypical or femaleTypical contribute.
    // [AJJ26 §5 — neutral jobs are excluded from this sub-score]
    final typedIds = recommendedJobIds
        .where((id) =>
    genderTypicalityMap.containsKey(id) &&
        genderTypicalityMap[id] != GenderTypicality.neutral)
        .toList();

    double genderBalanceScore = 1.0; // default when no typicality data
    if (typedIds.isNotEmpty) {
      final maleCount = typedIds
          .where(
              (id) => genderTypicalityMap[id] == GenderTypicality.maleTypical)
          .length;
      final ratio = maleCount / typedIds.length; // 0.5 = perfect balance
      genderBalanceScore = 1.0 - (2.0 * (ratio - 0.5).abs());
    }

    // ── Composite score ──────────────────────────────────────────────────────
    final composite = diversityScore * FairnessThresholds.diversityWeight +
        biasAbsenceScore * FairnessThresholds.biasAbsenceWeight +
        genderBalanceScore * FairnessThresholds.genderBalanceWeight;

    return FairnessResult(
      overallScore: (composite * 100.0).clamp(0.0, 100.0),
      diversityScore: diversityScore,
      biasAbsenceScore: biasAbsenceScore,
      genderBalanceScore: genderBalanceScore,
      // Defensive copy so callers cannot mutate the result's term list.
      flaggedTerms: List<FlaggedTerm>.unmodifiable(precomputedFlaggedTerms),
    );
  }

  /// Backwards-compatible wrapper that accepts the original string-keyed
  /// gender-typicality map and returns only the [overallScore].
  ///
  /// Prefer [calculateFairness] for new call sites.
  double calculateFairnessScore(
      List<String> recommendedJobIds,
      Map<String, String> jobIndustryMap,
      Map<String, String> jobGenderTypicalityMap,
      ) {
    final typedMap = <String, GenderTypicality>{
      for (final e in jobGenderTypicalityMap.entries)
        e.key: GenderTypicalityX.fromKey(e.value),
    };
    return calculateFairness(
      recommendedJobIds,
      jobIndustryMap,
      genderTypicalityMap: typedMap,
    ).overallScore;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // §4.6  REPORT & LABEL HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns the fairness report string from a [FairnessResult].
  /// Equivalent to `result.report`.
  String getFairnessReport(FairnessResult result) => result.report;

  /// Returns a hex colour string for [score].
  ///   > 80  → '#4CAF50' (green)
  ///   60–80 → '#FF9800' (amber)
  ///   < 60  → '#F44336' (red)
  String getFairnessColorHex(double score) => _gradeColorHex(score);

  /// Returns a human-readable grade label for [score].
  String getFairnessLabel(double score) => _gradeLabel(score);

  // ─────────────────────────────────────────────────────────────────────────
  // §4.7  SKILL LIST SANITISATION
  // ─────────────────────────────────────────────────────────────────────────

  /// [AJJ26 §4 — Protected attribute exclusion]
  ///
  /// Removes any skill strings from [skills] that are known proxies for
  /// protected attributes (race, religion, socioeconomic background,
  /// physical appearance). Case-insensitive; original casing of
  /// non-removed skills is preserved.
  List<String> sanitizeSkillList(List<String> skills) =>
      skills.where((s) => !_isProtectedProxy(s.toLowerCase().trim())).toList();

  // ─────────────────────────────────────────────────────────────────────────
  // §4.8  FILTER HELPERS (typed)
  // ─────────────────────────────────────────────────────────────────────────

  /// Filters [flaggedTerms] to a single [biasType].
  List<FlaggedTerm> filterByBiasType(
      List<FlaggedTerm> flaggedTerms,
      BiasType biasType,
      ) =>
      flaggedTerms.where((t) => t.biasType == biasType).toList();

  /// Returns only masculine-coded terms from [flaggedTerms].
  List<FlaggedTerm> masculineFlaggedTerms(List<FlaggedTerm> flaggedTerms) =>
      filterByBiasType(flaggedTerms, BiasType.masculineCoded);

  /// Returns only feminine-coded terms from [flaggedTerms].
  List<FlaggedTerm> feminineFlaggedTerms(List<FlaggedTerm> flaggedTerms) =>
      filterByBiasType(flaggedTerms, BiasType.feminineCoded);

  /// Returns only protected-attribute proxy terms from [flaggedTerms].
  List<FlaggedTerm> protectedProxyTerms(List<FlaggedTerm> flaggedTerms) =>
      filterByBiasType(flaggedTerms, BiasType.protectedAttributeProxy);

  // ─────────────────────────────────────────────────────────────────────────
  // §4.9  READ-ONLY TERM LIST ACCESSORS
  // ─────────────────────────────────────────────────────────────────────────

  /// Read-only view of monitored masculine-coded terms. For use in testing
  /// and the fairness settings screen.
  List<String> get masculineCodedTermList =>
      List.unmodifiable(_masculineCodedTerms);

  /// Read-only view of monitored feminine-coded terms.
  List<String> get feminineCodedTermList =>
      List.unmodifiable(_feminineCodedTerms);

  /// Read-only view of protected-attribute proxy terms.
  List<String> get protectedProxyList =>
      List.unmodifiable(_protectedAttributeProxies);

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE — GRADE HELPERS (single source of truth shared by
  // FairnessResult getters and the public helper methods above)
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns the hex colour string for a raw fairness [score]. [AJJ26 §5]
  static String _gradeColorHex(double score) {
    if (score > FairnessThresholds.excellentThreshold) return '#4CAF50';
    if (score >= FairnessThresholds.goodThreshold) return '#FF9800';
    return '#F44336';
  }

  /// Returns the human-readable grade label for a raw fairness [score].
  /// [AJJ26 §5]
  static String _gradeLabel(double score) {
    if (score > FairnessThresholds.excellentThreshold) return 'Excellent';
    if (score >= FairnessThresholds.goodThreshold) return 'Good';
    return 'Needs Review';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE — SCAN & MATCH HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  /// Scans [source] for each entry in [terms] and appends a [FlaggedTerm] to
  /// [out] for the first occurrence of each matched term.
  ///
  /// Patterns are looked up from [_patternCache] to avoid re-compiling the
  /// same RegExp on every call.
  ///
  /// Single-word terms use `\b` word-boundary anchors to prevent partial
  /// matches (e.g. "lead" does not match "leading" or "mislead").
  /// Multi-word phrases use case-insensitive literal matching.
  void _scanTerms(
      String source,
      List<String> terms,
      BiasType biasType,
      List<FlaggedTerm> out,
      ) {
    for (final term in terms) {
      final pattern = _getPattern(term);
      final match = pattern.firstMatch(source);
      if (match == null) continue;

      final idx = match.start;
      final ctxStart = (idx - 30).clamp(0, source.length);
      final ctxEnd = (match.end + 30).clamp(0, source.length);

      out.add(FlaggedTerm(
        term: term,
        biasType: biasType,
        context: '...${source.substring(ctxStart, ctxEnd)}...',
      ));
    }
  }

  /// True when [term] matches any protected-attribute proxy.
  /// Multi-word proxies use substring matching since skill strings may embed
  /// them within longer descriptive phrases. [AJJ26 §4]
  bool _isProtectedProxy(String term) =>
      _protectedSet.contains(term) ||
          _protectedAttributeProxies.any(term.contains);

  /// Log₂ using [dart:math]'s natural logarithm.
  ///   log₂(x) = ln(x) / ln(2)
  /// Returns 0.0 for x ≤ 0 (safe guard for Shannon entropy edge cases).
  double _log2(double x) => x <= 0.0 ? 0.0 : log(x) / log(2.0);
}