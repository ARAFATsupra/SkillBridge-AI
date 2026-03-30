// lib/ml/skill_similarity.dart — SkillBridge AI
// Skill co-occurrence similarity engine.
//
// Research foundation:
//   Dawson et al. (2021) — SKILLS SPACE: Measuring the "distance" between
//   occupations using skill co-occurrence patterns from job postings.
//
// Formula:
//   θ(s1, s2) = Σ_j [e(j,s1) · e(j,s2)] / max(Σ_j e(j,s1), Σ_j e(j,s2))
//   where e(j,s) = 1 when RCA(j,s) ≥ 1.0, else 0.
//
// Refactor notes vs previous version:
//   • Dart 3: getSimilarityLabel uses a switch expression instead of
//     if-else chain — more concise, exhaustive, and compiler-verified.
//   • explainSuggestion: interpolation simplified (no redundant temp vars).
//   • buildSimilarityMatrix: intermediate .toSet().toList()..sort() chain
//     preserved but extracted to a named variable for readability.
//   • All caches, algorithms, and public APIs are unchanged.

import 'rca_calculator.dart';

// ── File-level helpers ────────────────────────────────────────────────────────

/// Normalises a raw skill string: trims whitespace and lowercases.
String _norm(String s) => s.trim().toLowerCase();

/// Returns a canonical symmetric pair key using U+0000 as separator.
///
/// Skill strings never contain null bytes, so collisions are impossible.
/// Lexicographic ordering ensures θ(a,b) and θ(b,a) share the same slot.
String _pairKey(String a, String b) =>
    a.compareTo(b) <= 0 ? '$a\x00$b' : '$b\x00$a';

// ── Public types ──────────────────────────────────────────────────────────────

/// Immutable result for a pairwise skill θ computation.
class ThetaResult {
  /// First skill (normalised).
  final String skill1;

  /// Second skill (normalised).
  final String skill2;

  /// Co-occurrence similarity θ ∈ [0.0, 1.0].
  ///
  /// 1.0 = skills always co-occur as core (or identical skills).
  /// 0.0 = skills never co-occur as core.
  final double theta;

  /// Human-readable label from [SkillSimilarityEngine.getSimilarityLabel].
  final String label;

  const ThetaResult({
    required this.skill1,
    required this.skill2,
    required this.theta,
    required this.label,
  });

  @override
  String toString() =>
      'ThetaResult("$skill1" ↔ "$skill2": '
          '${theta.toStringAsFixed(4)} [$label])';
}

// ── Main class ────────────────────────────────────────────────────────────────

/// Computes pairwise skill co-occurrence similarities (θ) using cached
/// per-job core-skill indicators derived from a shared [RCACalculator].
///
/// ### Construction
/// ```dart
/// final rca = RCACalculator(jobSkillsMap);
/// final sim = SkillSimilarityEngine(
///   rcaCalculator: rca,
///   jobIds: jobSkillsMap.keys,
/// );
/// ```
///
/// Pass the same [RCACalculator] instance to [SkillsSpaceEngine] and
/// [SkillPrioritizer] so the underlying RCA index is built only once.
class SkillSimilarityEngine {
  final RCACalculator _rca;

  /// Ordered snapshot of all job IDs — used for co-occurrence counting.
  ///
  /// Matches the jobs in [_rca]; stored as an unmodifiable list so the
  /// cache remains consistent across the engine's lifetime.
  final List<String> _jobIds;

  // ── Caches (populated lazily, symmetric where applicable) ──────────────────

  /// Σ_j e(j, s) — number of jobs where [s] has RCA ≥ 1.0.
  final Map<String, int> _coreCountCache = {};

  /// Σ_j [e(j,s1) · e(j,s2)] — jobs where BOTH skills are core.
  /// Key = [_pairKey](s1, s2) (symmetric).
  final Map<String, int> _coOccCache = {};

  /// θ(s1, s2) values.
  /// Key = [_pairKey](s1, s2) (symmetric).
  final Map<String, double> _thetaCache = {};

  // ── Constructor ────────────────────────────────────────────────────────────

  /// Creates a [SkillSimilarityEngine] backed by [rcaCalculator].
  ///
  /// [jobIds] must contain every job ID present in [rcaCalculator]; typically
  /// `jobSkillsMap.keys`. The list is snapshotted at construction time.
  ///
  /// Throws [ArgumentError] if [jobIds] is empty.
  SkillSimilarityEngine({
    required RCACalculator rcaCalculator,
    required Iterable<String> jobIds,
  })  : _rca = rcaCalculator,
        _jobIds = List.unmodifiable(jobIds) {
    if (_jobIds.isEmpty) {
      throw ArgumentError('jobIds must not be empty.');
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Σ_j e(j, [skill]) — cached count of jobs where [skill] is core.
  int _coreCount(String skill) =>
      _coreCountCache.putIfAbsent(skill, () {
        int n = 0;
        for (final String jobId in _jobIds) {
          if (_rca.isCoreSkill(skill, jobId)) n++;
        }
        return n;
      });

  /// Σ_j [e(j,s1) · e(j,s2)] — cached co-occurrence count (symmetric).
  int _coOcc(String s1, String s2) {
    final String key = _pairKey(s1, s2);
    return _coOccCache.putIfAbsent(key, () {
      int n = 0;
      for (final String jobId in _jobIds) {
        if (_rca.isCoreSkill(s1, jobId) && _rca.isCoreSkill(s2, jobId)) n++;
      }
      return n;
    });
  }

  // ── Public: core theta ─────────────────────────────────────────────────────

  /// Computes the co-occurrence similarity θ between two skills.
  ///
  /// **Formula** (Dawson et al. 2021):
  /// ```
  /// θ(s1,s2) = Σ_j [e(j,s1)·e(j,s2)] / max(Σ_j e(j,s1), Σ_j e(j,s2))
  /// ```
  ///
  /// - **Symmetric**: `calculateTheta(a, b) == calculateTheta(b, a)`.
  /// - **Self-similarity**: returns `1.0` when `s1 == s2` (after normalisation).
  /// - **Cached**: O(J) on the first call per unique pair; O(1) thereafter.
  /// - Returns `0.0` for empty inputs or when neither skill is core in any job.
  double calculateTheta(String skill1, String skill2) {
    if (skill1.isEmpty || skill2.isEmpty) return 0.0;

    final String s1 = _norm(skill1);
    final String s2 = _norm(skill2);
    if (s1 == s2) return 1.0;

    final String key = _pairKey(s1, s2);
    return _thetaCache.putIfAbsent(key, () {
      final int co = _coOcc(s1, s2);
      if (co == 0) return 0.0;
      final int c1 = _coreCount(s1);
      final int c2 = _coreCount(s2);
      final int maxC = c1 >= c2 ? c1 : c2;
      return maxC == 0 ? 0.0 : (co / maxC).clamp(0.0, 1.0);
    });
  }

  /// Computes θ and returns a [ThetaResult] including the similarity label.
  ///
  /// Prefer [calculateTheta] when only the scalar value is needed.
  ThetaResult thetaResult(String skill1, String skill2) {
    final double theta = calculateTheta(skill1, skill2);
    return ThetaResult(
      skill1: _norm(skill1),
      skill2: _norm(skill2),
      theta: theta,
      label: getSimilarityLabel(theta),
    );
  }

  // ── Public: similar-skill lookup ───────────────────────────────────────────

  /// Returns up to [topN] skills from [candidateSkills] most similar to
  /// [skill], sorted by θ descending.
  ///
  /// - [skill] itself is excluded from results.
  /// - Candidates with θ == 0.0 are excluded.
  /// - Duplicate candidates (after normalisation) are de-duplicated.
  ///
  /// Returns an empty list when [skill] or [candidateSkills] is empty, or
  /// when [topN] ≤ 0.
  List<ThetaResult> getMostSimilarSkills(
      String skill,
      List<String> candidateSkills, {
        int topN = 5,
      }) {
    if (skill.isEmpty || candidateSkills.isEmpty || topN <= 0) {
      return const <ThetaResult>[];
    }

    final String qNorm = _norm(skill);
    final Set<String> seen = <String>{};
    final List<ThetaResult> results = <ThetaResult>[];

    for (final String candidate in candidateSkills) {
      final String cNorm = _norm(candidate);
      if (cNorm.isEmpty || cNorm == qNorm || !seen.add(cNorm)) continue;
      final double theta = calculateTheta(qNorm, cNorm);
      if (theta > 0.0) {
        results.add(ThetaResult(
          skill1: qNorm,
          skill2: cNorm,
          theta: theta,
          label: getSimilarityLabel(theta),
        ));
      }
    }

    results.sort(
          (ThetaResult a, ThetaResult b) => b.theta.compareTo(a.theta),
    );
    return results.take(topN).toList();
  }

  // ── Public: similarity matrix ──────────────────────────────────────────────

  /// Builds a pairwise similarity matrix for a list of skills.
  ///
  /// Keys use the canonical format `"s1\x00s2"` (lexicographic order via
  /// [_pairKey]) so each unique pair appears exactly once.
  ///
  /// For *n* distinct skills this produces n(n−1)/2 entries. Results are
  /// cached so overlapping calls on shared skill sets are efficient.
  ///
  /// Returns an empty map for empty or single-element [skills] lists.
  Map<String, double> buildSimilarityMatrix(List<String> skills) {
    if (skills.isEmpty) return const <String, double>{};

    final List<String> normed = (skills
        .map(_norm)
        .where((String s) => s.isNotEmpty)
        .toSet()
        .toList())
      ..sort();

    if (normed.length < 2) return const <String, double>{};

    final Map<String, double> matrix = <String, double>{};
    for (int i = 0; i < normed.length; i++) {
      for (int j = i + 1; j < normed.length; j++) {
        matrix[_pairKey(normed[i], normed[j])] =
            calculateTheta(normed[i], normed[j]);
      }
    }
    return matrix;
  }

  // ── Public: complementary skill suggestions ────────────────────────────────

  /// Suggests [topN] complementary skills from [candidateSkills] for a user
  /// who already knows [userSkills].
  ///
  /// **Algorithm**:
  ///   1. For every user skill, compute θ against every candidate.
  ///   2. Accumulate θ contributions (sum) across user skills per candidate.
  ///   3. Exclude skills already in [userSkills].
  ///   4. Return top-[topN] by accumulated score.
  ///
  /// Candidates are de-duplicated (after normalisation) before scoring to
  /// avoid inflated scores from repeated entries.
  ///
  /// Returns an empty list when any required parameter is empty or [topN] ≤ 0.
  List<String> suggestComplementarySkills(
      List<String> userSkills,
      List<String> candidateSkills, {
        int topN = 5,
      }) {
    if (userSkills.isEmpty || candidateSkills.isEmpty || topN <= 0) {
      return const <String>[];
    }

    final Set<String> userSet = userSkills
        .map(_norm)
        .where((String s) => s.isNotEmpty)
        .toSet();

    // De-duplicate candidates up-front: O(C) work before the O(U×C) loop.
    final Set<String> candidateSet = candidateSkills
        .map(_norm)
        .where((String c) => c.isNotEmpty && !userSet.contains(c))
        .toSet();

    if (candidateSet.isEmpty) return const <String>[];

    final Map<String, double> scores = <String, double>{};
    for (final String us in userSet) {
      for (final String candidate in candidateSet) {
        final double theta = calculateTheta(us, candidate);
        if (theta > 0.0) {
          scores[candidate] = (scores[candidate] ?? 0.0) + theta;
        }
      }
    }

    if (scores.isEmpty) return const <String>[];

    return (scores.entries.toList()
      ..sort(
            (MapEntry<String, double> a, MapEntry<String, double> b) =>
            b.value.compareTo(a.value),
      ))
        .take(topN)
        .map((MapEntry<String, double> e) => e.key)
        .toList();
  }

  // ── Public: utilities ──────────────────────────────────────────────────────

  /// Returns `true` when θ(s1, s2) > [threshold] (default 0.3).
  ///
  /// Threshold follows the "Somewhat Related" boundary used by
  /// [getSimilarityLabel].
  bool areComplementary(
      String skill1,
      String skill2, {
        double threshold = 0.3,
      }) =>
      calculateTheta(skill1, skill2) > threshold;

  /// Maps a θ score to a human-readable relationship label.
  ///
  /// | θ        | Label               |
  /// |----------|---------------------|
  /// | ≥ 0.8    | Strongly Related    |
  /// | ≥ 0.5    | Moderately Related  |
  /// | ≥ 0.3    | Somewhat Related    |
  /// | > 0.0    | Weakly Related      |
  /// | == 0.0   | Unrelated           |
  String getSimilarityLabel(double theta) => switch (theta) {
    >= 0.8 => 'Strongly Related',
    >= 0.5 => 'Moderately Related',
    >= 0.3 => 'Somewhat Related',
    > 0.0  => 'Weakly Related',
    _      => 'Unrelated',
  };

  /// Returns a user-facing sentence explaining why [suggestedSkill]
  /// complements [userSkill], including the θ score and its label.
  String explainSuggestion(String userSkill, String suggestedSkill) {
    final double theta = calculateTheta(userSkill, suggestedSkill);
    final String label = getSimilarityLabel(theta);
    final String pct = (theta * 100).toStringAsFixed(0);
    return '$suggestedSkill is $label to $userSkill '
        '(co-occurrence score: $pct%). '
        'Professionals who know $userSkill frequently also use '
        '$suggestedSkill.';
  }

  // ── Cache management ───────────────────────────────────────────────────────

  /// Clears all internal caches.
  ///
  /// Use in development hot-reload scenarios. In production, construct a
  /// fresh instance when the underlying dataset changes.
  void clearCache() {
    _coreCountCache.clear();
    _coOccCache.clear();
    _thetaCache.clear();
  }

  /// Number of θ values currently held in the cache.
  int get thetaCacheSize => _thetaCache.length;

  /// Number of core-count values currently held in the cache.
  int get coreCountCacheSize => _coreCountCache.length;
}