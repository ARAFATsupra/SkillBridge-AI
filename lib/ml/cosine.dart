// lib/ml/cosine.dart — SkillBridge AI
// Cosine Similarity + Jaccard Coefficient + Hybrid Scorer + Evaluation Metrics
//
// Research foundations:
//   - Ajjam & Al-Raweshidy (2026): TF-IDF cosine similarity for semantic job matching
//   - Alsaif et al. (2022): Jaccard Coefficient (JC) + Cosine Similarity (CS) comparison
//       → Cosine accuracy 0.86 vs Jaccard 0.61 across 159 resumes
//       → CS(A,B) = dot(A,B) / (|A| × |B|)  [Alsaif et al. §4.3, Eq.12]
//   - Huang (2022): Attention-weighted feature selection for student/employer matching
//   - Dawson et al. (2021): Skill-space distance and asymmetric skill overlap
//   - Tavakoli et al. (2022): Dot-product preference-vector recommendation engine
//       → Highest dot-product score → recommended course per topic  [§3.5.2]

import 'dart:math' show sqrt, max, log;
import 'package:flutter/foundation.dart';

// Re-exports so callers import a single file for all similarity utilities.
// SimScoreBadge tiers [Alsaif et al. §4.3]:
//   ≥ 0.75 → strong, 0.40–0.74 → moderate, < 0.40 → weak.
export 'package:skillbridge_ai/main.dart' show simScoreLabel, simScoreColor;

// ─────────────────────────────────────────────────────────────────────────────
// PUBLIC TYPES
// ─────────────────────────────────────────────────────────────────────────────

/// Result bundle returned by [hybridSimilarity].
///
/// Carries the weighted composite score alongside each individual signal so
/// callers can surface per-component breakdowns in the UI without recomputing.
@immutable
class HybridSimilarityResult {
  /// Final weighted score in [0.0, 1.0].
  final double score;

  /// Raw cosine similarity component (post-normalisation + attention).
  final double cosineScore;

  /// Jaccard coefficient component.
  final double jaccardScore;

  /// Asymmetric skill-coverage component.
  final double coverageScore;

  const HybridSimilarityResult({
    required this.score,
    required this.cosineScore,
    required this.jaccardScore,
    required this.coverageScore,
  });

  @override
  String toString() =>
      'HybridSimilarityResult(score: ${score.toStringAsFixed(4)}, '
          'cosine: ${cosineScore.toStringAsFixed(4)}, '
          'jaccard: ${jaccardScore.toStringAsFixed(4)}, '
          'coverage: ${coverageScore.toStringAsFixed(4)})';
}

/// Encapsulates Precision@K, Recall@K, and F1 for a single ranked list.
@immutable
class RankingMetrics {
  final double precision;
  final double recall;
  final double f1;
  final int k;
  final int totalRelevant;

  const RankingMetrics({
    required this.precision,
    required this.recall,
    required this.f1,
    required this.k,
    required this.totalRelevant,
  });

  @override
  String toString() =>
      'RankingMetrics(k: $k, P@K: ${precision.toStringAsFixed(4)}, '
          'R@K: ${recall.toStringAsFixed(4)}, F1: ${f1.toStringAsFixed(4)})';
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. COSINE SIMILARITY  [Alsaif et al. §4.3, Eq.12; Ajjam & Al-Raweshidy 2026]
// ─────────────────────────────────────────────────────────────────────────────

/// Computes cosine similarity between two sparse TF-IDF vectors.
///
/// Formula: CS(A, B) = dot(A, B) / (|A| × |B|)
/// Matches [Alsaif et al. (2022) §4.3 Equation 12] exactly.
///
/// - Returns a value in **[0.0, 1.0]**: 1.0 = identical direction.
/// - Returns **0.0** when either vector is empty or has zero magnitude.
///
/// ### Parameters
/// - [normalize]: pre-normalises each vector to unit length before computing.
///   Default `true`. Set `false` only when vectors are already unit-normalised
///   upstream (avoids a redundant pass).
/// - [attentionWeights]: optional term → importance scalar applied *after*
///   normalisation [Huang, 2022]. Domain-critical terms such as "python" or
///   "machine learning" are amplified so they dominate the angular distance.
///
/// ### Numerical stability
/// - Negative TF-IDF residuals are clamped to 0.0 during normalisation
///   [Ajjam & Al-Raweshidy, 2026].
/// - Final result is clamped to [0.0, 1.0] to absorb floating-point drift.
double cosineSimilarity(
    Map<String, double> a,
    Map<String, double> b, {
      bool normalize = true,
      Map<String, double>? attentionWeights,
    }) {
  if (a.isEmpty || b.isEmpty) return 0.0;

  // Build working copies; avoid mutating caller-owned maps.
  Map<String, double> va = normalize ? _normalize(a) : Map.of(a);
  Map<String, double> vb = normalize ? _normalize(b) : Map.of(b);

  if (attentionWeights != null && attentionWeights.isNotEmpty) {
    va = _applyAttention(va, attentionWeights);
    vb = _applyAttention(vb, attentionWeights);
  }

  // CS(A, B) = dot(A, B) / (|A| × |B|)  [Alsaif et al. §4.3, Eq.12]
  final double magA = _magnitude(va);
  final double magB = _magnitude(vb);
  if (magA == 0.0 || magB == 0.0) return 0.0;

  return (_dot(va, vb) / (magA * magB)).clamp(0.0, 1.0);
}

/// Batch cosine similarity: scores a single [query] vector against every
/// vector in [candidates] and returns results sorted by score descending.
///
/// More efficient than repeated [cosineSimilarity] calls because [query] is
/// normalised only once.
///
/// Returns a list of `(key, score)` records in descending order.
List<({String key, double score})> batchCosineSimilarity(
    Map<String, double> query,
    Map<String, Map<String, double>> candidates, {
      bool normalize = true,
      Map<String, double>? attentionWeights,
    }) {
  if (query.isEmpty || candidates.isEmpty) return const [];

  // Normalise + apply attention to query once.
  Map<String, double> q = normalize ? _normalize(query) : Map.of(query);
  if (attentionWeights != null && attentionWeights.isNotEmpty) {
    q = _applyAttention(q, attentionWeights);
  }
  final double magQ = _magnitude(q);
  if (magQ == 0.0) return const [];

  final results = <({String key, double score})>[];

  for (final entry in candidates.entries) {
    Map<String, double> v =
    normalize ? _normalize(entry.value) : Map.of(entry.value);
    if (attentionWeights != null && attentionWeights.isNotEmpty) {
      v = _applyAttention(v, attentionWeights);
    }
    final double magV = _magnitude(v);
    if (magV == 0.0) {
      results.add((key: entry.key, score: 0.0));
      continue;
    }
    final double score = (_dot(q, v) / (magQ * magV)).clamp(0.0, 1.0);
    results.add((key: entry.key, score: score));
  }

  results.sort((a, b) => b.score.compareTo(a.score));
  return results;
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. DOT PRODUCT  [Tavakoli et al. §3.5.2]
// ─────────────────────────────────────────────────────────────────────────────

/// Computes the dot product of two sparse preference/feature vectors.
///
/// Used by the eDoer recommendation engine: for each in-progress topic the
/// learner's 15-dimensional long-term preference vector is dot-producted with
/// each course's 15-dimensional feature vector; the course yielding the
/// **highest score** is recommended.  [Tavakoli et al. §3.5.2]
///
/// Both maps share the same 15 keys defined in `PreferenceKeys` in `main.dart`.
/// Missing keys are treated as **0.0** (sparse representation).
///
/// Returns the raw scalar — **no normalisation applied** — so that the relative
/// magnitude of learner preferences is preserved.
double dotProduct(Map<String, double> a, Map<String, double> b) => _dot(a, b);

/// Ranks [candidates] against [query] by dot product (descending).
///
/// Useful when raw magnitude is semantically meaningful (e.g. long-term
/// preference accumulators grow with engagement).
List<({String key, double score})> rankByDotProduct(
    Map<String, double> query,
    Map<String, Map<String, double>> candidates,
    ) {
  if (query.isEmpty || candidates.isEmpty) return const [];

  final results = candidates.entries
      .map((e) => (key: e.key, score: _dot(query, e.value)))
      .toList();

  results.sort((a, b) => b.score.compareTo(a.score));
  return results;
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. JACCARD COEFFICIENT  [Alsaif et al. §3.2, 2022]
// ─────────────────────────────────────────────────────────────────────────────

/// Computes the Jaccard Coefficient between two skill sets.
///
/// Formula: JC(A, B) = |A ∩ B| / |A ∪ B|
///
/// [Alsaif et al. 2022, §3.2] used this as a fallback metric for sparse
/// vectors where cosine similarity may be unreliable due to low term overlap.
/// Their evaluation on 159 resumes found:
///   - Cosine accuracy: **0.86**
///   - Jaccard accuracy: **0.61**
///
/// Cosine is preferred for semantic matching; Jaccard provides a complementary
/// exact-overlap signal.
///
/// - Returns **1.0** when both sets are empty (vacuously identical).
/// - Returns **0.0** when exactly one set is empty.
double jaccardSimilarity(Set<String> setA, Set<String> setB) {
  if (setA.isEmpty && setB.isEmpty) return 1.0;
  if (setA.isEmpty || setB.isEmpty) return 0.0;

  final int intersectionSize = setA.intersection(setB).length;
  final int unionSize = setA.union(setB).length;
  return unionSize == 0 ? 0.0 : intersectionSize / unionSize;
}

/// Convenience overload: accepts raw lists (lowercased and trimmed internally).
/// [Alsaif et al. §3.2]
double jaccardSimilarityFromLists(List<String> a, List<String> b) {
  final Set<String> setA = _normalizeStringList(a);
  final Set<String> setB = _normalizeStringList(b);
  return jaccardSimilarity(setA, setB);
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. ASYMMETRIC SKILL COVERAGE  [Dawson et al., 2021]
// ─────────────────────────────────────────────────────────────────────────────

/// Measures the fraction of *required* job skills covered by the candidate.
///
/// Unlike symmetric Jaccard, this metric is **directional** [Dawson et al. 2021]:
/// a candidate may cover all required skills while the job covers only half of
/// theirs — the asymmetry is critical for transition-difficulty estimation.
///
/// - Returns **1.0** when [requiredSkills] is empty (nothing to satisfy).
/// - Returns **0.0** when [candidateSkills] is empty but requirements exist.
/// - Comparison is **case-insensitive** with leading/trailing whitespace stripped.
///
/// Returns a value in **[0.0, 1.0]** where 1.0 = full coverage.
double skillCoverage({
  required Set<String> candidateSkills,
  required Set<String> requiredSkills,
}) {
  if (requiredSkills.isEmpty) return 1.0;
  if (candidateSkills.isEmpty) return 0.0;

  final Set<String> normCandidate =
  candidateSkills.map((s) => s.trim().toLowerCase()).toSet();
  final Set<String> normRequired =
  requiredSkills.map((s) => s.trim().toLowerCase()).toSet();

  final int covered = normRequired.intersection(normCandidate).length;
  return covered / normRequired.length;
}

/// Returns the **uncovered** required skills — useful for gap-analysis UIs.
///
/// All strings are normalised (lowercased + trimmed) before comparison.
Set<String> skillGap({
  required Set<String> candidateSkills,
  required Set<String> requiredSkills,
}) {
  if (requiredSkills.isEmpty) return const {};
  if (candidateSkills.isEmpty) {
    return requiredSkills.map((s) => s.trim().toLowerCase()).toSet();
  }

  final Set<String> normCandidate =
  candidateSkills.map((s) => s.trim().toLowerCase()).toSet();
  final Set<String> normRequired =
  requiredSkills.map((s) => s.trim().toLowerCase()).toSet();

  return normRequired.difference(normCandidate);
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. HYBRID SIMILARITY SCORER
// ─────────────────────────────────────────────────────────────────────────────

/// Hybrid similarity combining TF-IDF cosine + Jaccard + asymmetric coverage.
///
/// ### Weight defaults (must sum to 1.0)
/// | Component       | Default | Source                               |
/// |-----------------|---------|--------------------------------------|
/// | cosineWeight    | 0.55    | Ajjam & Al-Raweshidy (2026)          |
/// | jaccardWeight   | 0.20    | Alsaif et al. §3.2 (2022)            |
/// | coverageWeight  | 0.25    | Dawson et al. (2021)                 |
///
/// Returns a [HybridSimilarityResult] containing the composite [score] and
/// every individual component, enabling per-signal UI breakdowns without
/// recomputation.
///
/// Throws [ArgumentError] if weights do not sum to 1.0 within a 1e-6 tolerance.
HybridSimilarityResult hybridSimilarity({
  required Map<String, double> userVector,
  required Map<String, double> jobVector,
  required List<String> userSkills,
  required List<String> jobSkills,
  double cosineWeight = 0.55,
  double jaccardWeight = 0.20,
  double coverageWeight = 0.25,
  Map<String, double>? attentionWeights,
}) {
  final double weightSum = cosineWeight + jaccardWeight + coverageWeight;
  if ((weightSum - 1.0).abs() > 1e-6) {
    throw ArgumentError(
      'Weights must sum to 1.0 — got ${weightSum.toStringAsFixed(6)}.',
    );
  }

  final double cosine = cosineSimilarity(
    userVector,
    jobVector,
    normalize: true,
    attentionWeights: attentionWeights,
  );

  final double jaccard = jaccardSimilarityFromLists(userSkills, jobSkills);

  final double coverage = skillCoverage(
    candidateSkills: userSkills.toSet(),
    requiredSkills: jobSkills.toSet(),
  );

  final double composite = (cosine * cosineWeight +
      jaccard * jaccardWeight +
      coverage * coverageWeight)
      .clamp(0.0, 1.0);

  return HybridSimilarityResult(
    score: composite,
    cosineScore: cosine,
    jaccardScore: jaccard,
    coverageScore: coverage,
  );
}

/// Batch hybrid scoring: ranks [jobs] against a single user profile.
///
/// Avoids re-normalising [userVector] on every iteration by normalising once
/// before entering the loop. Returns entries sorted by composite score
/// descending.
List<({String jobId, HybridSimilarityResult result})> batchHybridSimilarity({
  required Map<String, double> userVector,
  required List<String> userSkills,
  required Map<String, Map<String, double>> jobVectors,
  required Map<String, List<String>> jobSkillsMap,
  double cosineWeight = 0.55,
  double jaccardWeight = 0.20,
  double coverageWeight = 0.25,
  Map<String, double>? attentionWeights,
}) {
  final double weightSum = cosineWeight + jaccardWeight + coverageWeight;
  if ((weightSum - 1.0).abs() > 1e-6) {
    throw ArgumentError(
      'Weights must sum to 1.0 — got ${weightSum.toStringAsFixed(6)}.',
    );
  }

  if (jobVectors.isEmpty) return const [];

  // Pre-compute user side once.
  Map<String, double> normUser = _normalize(userVector);
  if (attentionWeights != null && attentionWeights.isNotEmpty) {
    normUser = _applyAttention(normUser, attentionWeights);
  }
  final double magUser = _magnitude(normUser);

  final results = <({String jobId, HybridSimilarityResult result})>[];

  for (final entry in jobVectors.entries) {
    final String jobId = entry.key;
    final List<String> jobSkills = jobSkillsMap[jobId] ?? const [];

    double cosine = 0.0;
    if (magUser > 0.0) {
      Map<String, double> normJob = _normalize(entry.value);
      if (attentionWeights != null && attentionWeights.isNotEmpty) {
        normJob = _applyAttention(normJob, attentionWeights);
      }
      final double magJob = _magnitude(normJob);
      if (magJob > 0.0) {
        cosine =
            (_dot(normUser, normJob) / (magUser * magJob)).clamp(0.0, 1.0);
      }
    }

    final double jaccard = jaccardSimilarityFromLists(userSkills, jobSkills);
    final double coverage = skillCoverage(
      candidateSkills: userSkills.toSet(),
      requiredSkills: jobSkills.toSet(),
    );
    final double composite = (cosine * cosineWeight +
        jaccard * jaccardWeight +
        coverage * coverageWeight)
        .clamp(0.0, 1.0);

    results.add((
    jobId: jobId,
    result: HybridSimilarityResult(
      score: composite,
      cosineScore: cosine,
      jaccardScore: jaccard,
      coverageScore: coverage,
    ),
    ));
  }

  results.sort((a, b) => b.result.score.compareTo(a.result.score));
  return results;
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. EVALUATION METRICS  [Ajjam & Al-Raweshidy 2026; Alsaif et al. 2022]
// ─────────────────────────────────────────────────────────────────────────────

/// Computes Precision@K, Recall@K, and F1 in a single pass.
///
/// - [relevanceFlags]: ordered list of booleans where `true` = relevant.
///   Order must match the ranked recommendation list (index 0 = top result).
/// - [k]: cutoff rank.
/// - [totalRelevant]: total relevant items in the full collection (for recall).
///
/// Used by [Ajjam & Al-Raweshidy 2026] to compare semantic vs keyword models.
///
/// Throws [ArgumentError] if [k] ≤ 0 or [totalRelevant] < 0.
RankingMetrics computeRankingMetrics(
    List<bool> relevanceFlags,
    int k, {
      required int totalRelevant,
    }) {
  if (k <= 0) throw ArgumentError('k must be > 0, got $k.');
  if (totalRelevant < 0) {
    throw ArgumentError('totalRelevant must be ≥ 0, got $totalRelevant.');
  }
  if (relevanceFlags.isEmpty || totalRelevant == 0) {
    return RankingMetrics(
      precision: 0.0,
      recall: 0.0,
      f1: 0.0,
      k: k,
      totalRelevant: totalRelevant,
    );
  }

  final int cutoff = k.clamp(0, relevanceFlags.length);
  final int hits = relevanceFlags.take(cutoff).where((r) => r).length;

  final double precision = hits / k;
  final double recall = hits / totalRelevant;
  final double f1 = _f1(precision, recall);

  return RankingMetrics(
    precision: precision,
    recall: recall,
    f1: f1,
    k: k,
    totalRelevant: totalRelevant,
  );
}

/// Precision@K — fraction of top-K recommendations that are relevant.
///
/// [Ajjam & Al-Raweshidy 2026] §5 evaluation metric.
double precisionAtK(List<bool> relevanceFlags, int k) {
  if (k <= 0 || relevanceFlags.isEmpty) return 0.0;
  final int cutoff = k.clamp(0, relevanceFlags.length);
  return relevanceFlags.take(cutoff).where((r) => r).length / k;
}

/// Recall@K — fraction of all relevant items appearing in the top-K.
///
/// Paired with [precisionAtK] in [Ajjam & Al-Raweshidy 2026] evaluation.
double recallAtK(List<bool> relevanceFlags, int k, int totalRelevant) {
  if (totalRelevant <= 0 || k <= 0 || relevanceFlags.isEmpty) return 0.0;
  final int cutoff = k.clamp(0, relevanceFlags.length);
  return relevanceFlags.take(cutoff).where((r) => r).length / totalRelevant;
}

/// F1 score balancing Precision@K and Recall@K.  [Alsaif et al. 2022]
double f1Score(double precision, double recall) => _f1(precision, recall);

/// Average Precision (AP) for a single query.
///
/// AP = (1 / R) × Σ_k [P@k × rel(k)]
/// where R is the total number of relevant items in the collection.
///
/// Provides a single-number summary that rewards systems placing relevant items
/// higher in the list. Used alongside MAP for system-level evaluation.
double averagePrecision(List<bool> relevanceFlags, int totalRelevant) {
  if (totalRelevant <= 0 || relevanceFlags.isEmpty) return 0.0;

  double sum = 0.0;
  int hits = 0;

  for (int i = 0; i < relevanceFlags.length; i++) {
    if (relevanceFlags[i]) {
      hits++;
      sum += hits / (i + 1);
    }
  }

  return sum / totalRelevant;
}

/// Mean Average Precision (MAP) across multiple queries.
///
/// MAP = (1 / Q) × Σ_q AP(q)
///
/// [queries]: each entry is a `(relevanceFlags, totalRelevant)` pair for one
/// query. Queries with [totalRelevant] == 0 are skipped.
double meanAveragePrecision(
    List<({List<bool> relevanceFlags, int totalRelevant})> queries,
    ) {
  if (queries.isEmpty) return 0.0;

  double totalAP = 0.0;
  int validQueries = 0;

  for (final q in queries) {
    if (q.totalRelevant <= 0) continue;
    totalAP += averagePrecision(q.relevanceFlags, q.totalRelevant);
    validQueries++;
  }

  return validQueries == 0 ? 0.0 : totalAP / validQueries;
}

/// Normalised Discounted Cumulative Gain @ K (NDCG@K).
///
/// Handles graded relevance (not just binary). Use integer relevance grades:
///   0 = not relevant, 1 = partially relevant, 2 = highly relevant, etc.
///
/// DCG@K  = Σ_{i=1}^{K} (2^rel_i − 1) / log2(i + 1)
/// NDCG@K = DCG@K / IDCG@K  (where IDCG = DCG of ideal ranking)
///
/// Returns 0.0 if all grades are 0 or [k] ≤ 0.
double ndcgAtK(List<int> relevanceGrades, int k) {
  if (k <= 0 || relevanceGrades.isEmpty) return 0.0;

  final int cutoff = k.clamp(0, relevanceGrades.length);
  final double dcg = _dcg(relevanceGrades.take(cutoff).toList());

  // Ideal DCG: sort grades descending and recompute.
  final List<int> ideal = List.of(relevanceGrades)
    ..sort((a, b) => b.compareTo(a));
  final double idcg = _dcg(ideal.take(cutoff).toList());

  return idcg == 0.0 ? 0.0 : (dcg / idcg).clamp(0.0, 1.0);
}

// ─────────────────────────────────────────────────────────────────────────────
// PRIVATE HELPERS
// ─────────────────────────────────────────────────────────────────────────────

/// Inner dot product over the shared (non-zero) keys of two sparse vectors.
/// Iterates the smaller map to minimise lookups — O(min(|a|,|b|)).
double _dot(Map<String, double> a, Map<String, double> b) {
  if (a.isEmpty || b.isEmpty) return 0.0;

  final Map<String, double> smaller = a.length <= b.length ? a : b;
  final Map<String, double> larger = a.length <= b.length ? b : a;

  double sum = 0.0;
  for (final MapEntry<String, double> e in smaller.entries) {
    final double? bVal = larger[e.key];
    if (bVal != null) sum += e.value * bVal;
  }
  return sum;
}

/// Euclidean (L2) magnitude of a sparse vector.
double _magnitude(Map<String, double> v) {
  double sumSq = 0.0;
  for (final double val in v.values) {
    sumSq += val * val;
  }
  return sqrt(sumSq);
}

/// Normalises a sparse vector to unit length.
///
/// Non-negative clamp prevents numerical instability from negative TF-IDF
/// residuals [Ajjam & Al-Raweshidy 2026]. Returns the original map unchanged
/// when magnitude is zero.
Map<String, double> _normalize(Map<String, double> v) {
  if (v.isEmpty) return v;
  final double mag = _magnitude(v);
  if (mag == 0.0) return v;
  return v.map((String k, double val) => MapEntry(k, max(0.0, val) / mag));
}

/// Applies per-term attention weights to a vector.
///
/// Amplifies domain-critical terms (e.g. "python", "machine learning") so that
/// they dominate the cosine angle. Simulates the attention mechanism described
/// in [Huang, 2022] at the vector level. Terms absent from [weights] receive a
/// multiplier of **1.0** (identity).
Map<String, double> _applyAttention(
    Map<String, double> v,
    Map<String, double> weights,
    ) {
  return v.map(
        (String k, double val) => MapEntry(k, val * (weights[k] ?? 1.0)),
  );
}

/// Lowercases, trims, and deduplicates a list of skill strings into a Set.
Set<String> _normalizeStringList(List<String> list) =>
    list.map((s) => s.trim().toLowerCase()).where((s) => s.isNotEmpty).toSet();

/// Harmonic mean of precision and recall.
double _f1(double precision, double recall) {
  final double denom = precision + recall;
  return denom == 0.0 ? 0.0 : (2.0 * precision * recall) / denom;
}

/// Discounted Cumulative Gain for a list of graded relevance scores.
///
/// DCG = Σ (2^rel_i − 1) / log2(i + 2)   (1-indexed as i+1, log2(i+1))
double _dcg(List<int> grades) {
  double dcg = 0.0;
  for (int i = 0; i < grades.length; i++) {
    final int rel = grades[i];
    if (rel > 0) {
      // log2(i + 2): position is 1-indexed → denominator = log2(pos + 1)
      dcg += (_pow2(rel) - 1.0) / _log2(i + 2);
    }
  }
  return dcg;
}

/// 2^n as a double. Kept private — only used internally by [_dcg].
///
/// Avoids the dart:math [pow] dependency for small integer exponents.
double _pow2(int n) {
  double result = 1.0;
  for (int i = 0; i < n; i++) {
    result *= 2.0;
  }
  return result;
}

/// log base-2 of [x]. Returns 0.0 for x ≤ 1 to avoid division-by-zero in DCG.
double _log2(num x) {
  if (x <= 1) return 0.0;
  const double ln2 = 0.6931471805599453; // ln(2)
  return log(x.toDouble()) / ln2;
}