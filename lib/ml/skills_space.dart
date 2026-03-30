// lib/ml/skills_space.dart — SkillBridge AI
// SKILLS SPACE occupation similarity engine.
//
// Research foundation:
//   Dawson et al. (2021) — SKILLS SPACE: Measuring the "distance" between
//   occupations using skill co-occurrence patterns from job postings.
//
// Formula:
//   Θ(S1,S2) = (1/C) × Σ_{s1∈S1} Σ_{s2∈S2} [w(s1,S1) · w(s2,S2) · θ(s1,s2)]
//   C (normalisation) = Σ_{s1∈S1} Σ_{s2∈S2} [w(s1,S1) · w(s2,S2)]
//   w(s, S) = mean RCA of skill s across all jobs in occupation S.
//
// Refactor notes vs previous version:
//   • Bug fix: TransitionReport.toString() used '$aToB.similarityPct%' which
//     interpolates the object reference string, not the field value. Corrected
//     to '${aToB.similarityPct}%' (both occurrences).
//   • Dart 3: getTransitionDifficulty and getTransitionDifficultyColor use
//     switch expressions instead of if-else chains.
//   • rankOccupationsByProximity: sort lambda uses explicit named-record
//     parameter types instead of bare `a`/`b`.
//   • All dependency-injected instances, weight caches, algorithms, typed
//     value-objects, and public APIs are unchanged.

import 'rca_calculator.dart';
import 'skill_similarity.dart';

// ── File-level helpers ────────────────────────────────────────────────────────

String _norm(String s) => s.trim().toLowerCase();

// ── Public types ──────────────────────────────────────────────────────────────

/// Immutable result for a single directed occupation-similarity computation.
class OccupationSimilarityResult {
  /// Θ score in [0.0, 1.0].
  final double score;

  /// [score] expressed as an integer percentage (0–100).
  final int similarityPct;

  /// Difficulty label: `"Easy"`, `"Medium"`, or `"Hard"`.
  final String difficulty;

  /// Hex colour for the difficulty badge.
  final String difficultyColor;

  const OccupationSimilarityResult({
    required this.score,
    required this.similarityPct,
    required this.difficulty,
    required this.difficultyColor,
  });

  @override
  String toString() =>
      'OccupationSimilarityResult(score: ${score.toStringAsFixed(4)}, '
          '$similarityPct%, difficulty: $difficulty)';
}

/// Bidirectional transition analysis between two named occupations.
class TransitionReport {
  /// Name of occupation A (the "from" occupation in [aToB]).
  final String occA;

  /// Name of occupation B (the "to" occupation in [aToB]).
  final String occB;

  /// Similarity when transitioning from A to B.
  final OccupationSimilarityResult aToB;

  /// Similarity when transitioning from B to A.
  final OccupationSimilarityResult bToA;

  /// `true` when |Θ(A→B) − Θ(B→A)| ≥ the asymmetry threshold.
  final bool isAsymmetric;

  /// Human-readable explanation of the directional difference.
  final String asymmetryExplanation;

  const TransitionReport({
    required this.occA,
    required this.occB,
    required this.aToB,
    required this.bToA,
    required this.isAsymmetric,
    required this.asymmetryExplanation,
  });

  /// Bug fix: previous version used '$aToB.similarityPct%' which interpolated
  /// the object's toString(), not the int field. Both occurrences corrected
  /// to '${...}' interpolation.
  @override
  String toString() =>
      'TransitionReport($occA → $occB: ${aToB.difficulty} '
          '[${aToB.similarityPct}%], '
          '$occB → $occA: ${bToA.difficulty} [${bToA.similarityPct}%])';
}

// ── Main class ────────────────────────────────────────────────────────────────

/// Computes occupation-level SKILLS SPACE similarity scores.
///
/// ### Construction
/// ```dart
/// final rca = RCACalculator(jobSkillsMap);
/// final sim = SkillSimilarityEngine(
///   rcaCalculator: rca,
///   jobIds: jobSkillsMap.keys,
/// );
/// final space = SkillsSpaceEngine(
///   rcaCalculator: rca,
///   similarityEngine: sim,
/// );
/// ```
///
/// All three objects share the same [RCACalculator] so the O(J×S) index is
/// computed only once for the lifetime of the feature session.
class SkillsSpaceEngine {
  final RCACalculator _rca;
  final SkillSimilarityEngine _sim;

  /// Cache: stable occupation key → skill-weight map.
  ///
  /// Keyed by [_weightVectorKey] which encodes the sorted skill list and
  /// sorted job IDs, so calling with a different skill/job combination always
  /// produces a fresh entry.
  final Map<String, Map<String, double>> _weightCache = {};

  // ── Constructor ────────────────────────────────────────────────────────────

  /// Creates a [SkillsSpaceEngine] using pre-built shared dependencies.
  ///
  /// [rcaCalculator] and [similarityEngine] must have been built from the
  /// same job→skills dataset.
  SkillsSpaceEngine({
    required RCACalculator rcaCalculator,
    required SkillSimilarityEngine similarityEngine,
  })  : _rca = rcaCalculator,
        _sim = similarityEngine;

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Stable cache key encoding both the skill set and the occupation job IDs.
  ///
  /// Uses sorted, null-byte-joined strings separated by U+0001 so the two
  /// components never collide.
  String _weightVectorKey(List<String> skills, List<String> jobIds) {
    final String sSkills =
    (skills.map(_norm).where((String s) => s.isNotEmpty).toSet().toList()
      ..sort())
        .join('\x00');
    final String sJobs = (List<String>.of(jobIds)..sort()).join('\x00');
    return '$sSkills\x01$sJobs';
  }

  /// Builds and caches the weight vector w(s, S) for an occupation.
  ///
  /// w(s, S) = mean RCA of skill s across jobs in [occupationJobIds] that
  /// actually list the skill.  Stored as `{normalisedSkill: meanRCA}`.
  Map<String, double> _buildWeightVector(
      List<String> skills,
      List<String> occupationJobIds,
      ) {
    final String cacheKey = _weightVectorKey(skills, occupationJobIds);
    return _weightCache.putIfAbsent(cacheKey, () {
      final Map<String, double> weights = <String, double>{};
      for (final String rawSkill in skills) {
        final String s = _norm(rawSkill);
        if (s.isEmpty) continue;

        double totalRCA = 0.0;
        int count = 0;

        for (final String jobId in occupationJobIds) {
          final double rca = _rca.calculateRCA(s, jobId);
          if (rca > 0.0) {
            totalRCA += rca;
            count++;
          }
        }
        weights[s] = count == 0 ? 0.0 : totalRCA / count;
      }
      return weights;
    });
  }

  /// Wraps a raw score into an [OccupationSimilarityResult].
  OccupationSimilarityResult _makeResult(double score) {
    return OccupationSimilarityResult(
      score: score,
      similarityPct: (score * 100).round(),
      difficulty: getTransitionDifficulty(score),
      difficultyColor: getTransitionDifficultyColor(score),
    );
  }

  // ── Public: core similarity ────────────────────────────────────────────────

  /// Computes the directed SKILLS SPACE similarity Θ(S1 → S2).
  ///
  /// **Formula** (Dawson et al. 2021):
  /// ```
  /// Θ(S1,S2) = (1/C) × Σ_{s1∈S1} Σ_{s2∈S2} [w(s1,S1)·w(s2,S2)·θ(s1,s2)]
  /// C         = Σ_{s1∈S1} Σ_{s2∈S2} [w(s1,S1)·w(s2,S2)]
  /// ```
  ///
  /// Zero-weight skills are skipped in the inner loop for efficiency —
  /// they contribute 0 to both the numerator and C.
  ///
  /// Returns an [OccupationSimilarityResult] with score in [0.0, 1.0].
  /// Returns a result with score 0.0 when any required parameter is empty.
  OccupationSimilarityResult calculateOccupationSimilarity(
      List<String> skills1,
      List<String> occupationJobIds1,
      List<String> skills2,
      List<String> occupationJobIds2,
      ) {
    if (skills1.isEmpty ||
        skills2.isEmpty ||
        occupationJobIds1.isEmpty ||
        occupationJobIds2.isEmpty) {
      return _makeResult(0.0);
    }

    final Map<String, double> w1 =
    _buildWeightVector(skills1, occupationJobIds1);
    final Map<String, double> w2 =
    _buildWeightVector(skills2, occupationJobIds2);

    double numerator = 0.0;
    double c = 0.0;

    for (final MapEntry<String, double> e1 in w1.entries) {
      final double wA = e1.value;
      if (wA == 0.0) continue; // zero-weight: skip entire row

      for (final MapEntry<String, double> e2 in w2.entries) {
        final double wB = e2.value;
        if (wB == 0.0) continue; // zero-weight: skip cell

        final double wp = wA * wB;
        c += wp;
        numerator += wp * _sim.calculateTheta(e1.key, e2.key);
      }
    }

    final double score = c == 0.0 ? 0.0 : (numerator / c).clamp(0.0, 1.0);
    return _makeResult(score);
  }

  // ── Public: skill weight ───────────────────────────────────────────────────

  /// Calculates the weight of a single skill within an occupation.
  ///
  /// w(s, S) = mean RCA of [skill] across all jobs in [occupationJobIds]
  /// that list the skill. Returns 0.0 for empty inputs.
  double calculateSkillWeight(String skill, List<String> occupationJobIds) {
    if (skill.isEmpty || occupationJobIds.isEmpty) return 0.0;

    final String s = _norm(skill);
    double totalRCA = 0.0;
    int count = 0;

    for (final String jobId in occupationJobIds) {
      final double rca = _rca.calculateRCA(s, jobId);
      if (rca > 0.0) {
        totalRCA += rca;
        count++;
      }
    }
    return count == 0 ? 0.0 : totalRCA / count;
  }

  // ── Public: user transition readiness ─────────────────────────────────────

  /// Estimates how ready a user is for a target job based on skill overlap.
  ///
  /// Each target skill is weighted by its global importance (mean RCA across
  /// all jobs). Skills are matched using exact normalised comparison plus,
  /// when [fuzzyMatch] is `true` (the default), substring containment
  /// (e.g. `"python"` satisfies `"python3"` and vice-versa).
  ///
  /// **Note**: substring matching is a heuristic. Disable it with
  /// `fuzzyMatch: false` for strict exact-match evaluation.
  ///
  /// Returns a score in [0.0, 1.0] where 1.0 = fully ready.
  double calculateUserTransitionReadiness(
      List<String> userSkills,
      List<String> targetJobSkills, {
        bool fuzzyMatch = true,
      }) {
    if (userSkills.isEmpty || targetJobSkills.isEmpty) return 0.0;

    final Set<String> userNorm = userSkills
        .map(_norm)
        .where((String s) => s.isNotEmpty)
        .toSet();

    double weightedMatch = 0.0;
    double totalWeight = 0.0;

    for (final String rawTarget in targetJobSkills) {
      final String ts = _norm(rawTarget);
      if (ts.isEmpty) continue;

      final double importance = _rca.getSkillGlobalImportance(ts);
      // Fallback weight of 1.0 when the skill is not in the RCA index.
      final double weight = importance > 0.0 ? importance : 1.0;
      totalWeight += weight;

      final bool hasExact = userNorm.contains(ts);
      final bool hasFuzzy = fuzzyMatch &&
          !hasExact &&
          userNorm.any(
                (String us) => us.contains(ts) || ts.contains(us),
          );

      if (hasExact || hasFuzzy) weightedMatch += weight;
    }

    return totalWeight == 0.0
        ? 0.0
        : (weightedMatch / totalWeight).clamp(0.0, 1.0);
  }

  // ── Public: difficulty labels ──────────────────────────────────────────────

  /// Maps Θ to a transition difficulty label.
  ///
  /// | Θ        | Label    |
  /// |----------|----------|
  /// | > 0.7    | Easy     |
  /// | 0.4–0.7  | Medium   |
  /// | < 0.4    | Hard     |
  String getTransitionDifficulty(double score) => switch (score) {
    > 0.7  => 'Easy',
    >= 0.4 => 'Medium',
    _      => 'Hard',
  };

  /// Hex colour for the transition difficulty badge.
  ///
  /// Easy → #4CAF50 (green) · Medium → #FF9800 (orange) · Hard → #F44336 (red)
  String getTransitionDifficultyColor(double score) => switch (score) {
    > 0.7  => '#4CAF50',
    >= 0.4 => '#FF9800',
    _      => '#F44336',
  };

  /// Converts a Θ score to an integer percentage (0–100).
  int getSimilarityPercentage(double score) =>
      (score.clamp(0.0, 1.0) * 100).round();

  // ── Public: asymmetry explanation ─────────────────────────────────────────

  /// Returns a human-readable explanation of any directional asymmetry.
  ///
  /// The transition is considered symmetric when
  /// |[scoreAtoB] − [scoreBtoA]| < [asymmetryThreshold] (default 0.05).
  String explainAsymmetry(
      double scoreAtoB,
      double scoreBtoA,
      String occA,
      String occB, {
        double asymmetryThreshold = 0.05,
      }) {
    if ((scoreAtoB - scoreBtoA).abs() < asymmetryThreshold) {
      return 'Transition between $occA and $occB is roughly symmetric — '
          'equally feasible in both directions '
          '(Θ ≈ ${(scoreAtoB * 100).toStringAsFixed(0)}%).';
    }

    final bool aToBEasier = scoreAtoB > scoreBtoA;
    final String easier = aToBEasier ? '$occA → $occB' : '$occB → $occA';
    final String harder = aToBEasier ? '$occB → $occA' : '$occA → $occB';
    final double easierScore = aToBEasier ? scoreAtoB : scoreBtoA;
    final double harderScore = aToBEasier ? scoreBtoA : scoreAtoB;

    return 'This transition is asymmetric. '
        '$easier is ${getTransitionDifficulty(easierScore)} '
        '(${(easierScore * 100).toStringAsFixed(0)}% match), '
        'while $harder is ${getTransitionDifficulty(harderScore)} '
        '(${(harderScore * 100).toStringAsFixed(0)}% match). '
        'Moving $easier is more natural due to better skill-profile overlap '
        'in that direction.';
  }

  // ── Public: full bidirectional report ─────────────────────────────────────

  /// Produces a complete [TransitionReport] for both directions A→B and B→A.
  ///
  /// Calls [calculateOccupationSimilarity] twice — once per direction —
  /// then combines the results with an asymmetry explanation.
  ///
  /// [occName1] / [occName2] are display names used in the explanation text.
  TransitionReport getTransitionReport({
    required List<String> skills1,
    required List<String> occupationJobIds1,
    required List<String> skills2,
    required List<String> occupationJobIds2,
    required String occName1,
    required String occName2,
    double asymmetryThreshold = 0.05,
  }) {
    final OccupationSimilarityResult aToB = calculateOccupationSimilarity(
      skills1,
      occupationJobIds1,
      skills2,
      occupationJobIds2,
    );
    final OccupationSimilarityResult bToA = calculateOccupationSimilarity(
      skills2,
      occupationJobIds2,
      skills1,
      occupationJobIds1,
    );

    return TransitionReport(
      occA: occName1,
      occB: occName2,
      aToB: aToB,
      bToA: bToA,
      isAsymmetric: (aToB.score - bToA.score).abs() >= asymmetryThreshold,
      asymmetryExplanation: explainAsymmetry(
        aToB.score,
        bToA.score,
        occName1,
        occName2,
        asymmetryThreshold: asymmetryThreshold,
      ),
    );
  }

  // ── Public: batch ranking ──────────────────────────────────────────────────

  /// Ranks multiple target occupations by their Θ proximity to a source,
  /// sorted by score descending.
  ///
  /// [targetOccupationSkills] maps occupation name → skill list.
  /// [targetOccupationJobIds] maps occupation name → job ID list.
  ///
  /// Entries whose job ID list is empty are silently skipped.
  ///
  /// Returns a list of `({String occName, OccupationSimilarityResult result})`
  /// records sorted by `result.score` descending.
  List<({String occName, OccupationSimilarityResult result})>
  rankOccupationsByProximity({
    required List<String> sourceSkills,
    required List<String> sourceJobIds,
    required Map<String, List<String>> targetOccupationSkills,
    required Map<String, List<String>> targetOccupationJobIds,
  }) {
    if (sourceSkills.isEmpty ||
        sourceJobIds.isEmpty ||
        targetOccupationSkills.isEmpty) {
      return const <({String occName, OccupationSimilarityResult result})>[];
    }

    final List<({String occName, OccupationSimilarityResult result})>
    results = [];

    for (final MapEntry<String, List<String>> entry
    in targetOccupationSkills.entries) {
      final String occName = entry.key;
      final List<String> tJobIds =
          targetOccupationJobIds[occName] ?? const <String>[];
      if (tJobIds.isEmpty) continue;

      results.add((
      occName: occName,
      result: calculateOccupationSimilarity(
        sourceSkills,
        sourceJobIds,
        entry.value,
        tJobIds,
      ),
      ));
    }

    results.sort(
          (
          ({String occName, OccupationSimilarityResult result}) a,
          ({String occName, OccupationSimilarityResult result}) b,
          ) =>
          b.result.score.compareTo(a.result.score),
    );
    return results;
  }

  // ── Cache management ───────────────────────────────────────────────────────

  /// Clears the occupation weight-vector cache.
  ///
  /// The θ cache lives in [SkillSimilarityEngine] and is not affected here.
  void clearWeightCache() => _weightCache.clear();

  /// Number of occupation weight vectors currently cached.
  int get weightCacheSize => _weightCache.length;
}