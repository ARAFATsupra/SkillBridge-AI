// lib/ml/rca_calculator.dart — SkillBridge AI
// Revealed Comparative Advantage (RCA) calculator for skill importance measurement.
//
// Research foundation:
//   Dawson et al. (2021) — SKILLS SPACE: Measuring the "distance" between
//   occupations using skill co-occurrence patterns from job postings.
//
// Formula:
//   RCA(j, s) = [x(j,s) / Σ_s' x(j,s')] / [Σ_j' x(j',s) / Σ_j' Σ_s' x(j',s')]
//
// Interpretation:
//   RCA ≥ 2.0  → "Critical"   — strongly over-represented in this job
//   RCA ≥ 1.0  → "Core"       — comparative advantage (more prominent here
//                                 than in the labour market on average)
//   RCA ≥ 0.5  → "Supporting" — moderately present but not distinctive
//   RCA < 0.5  → "Peripheral" — generic or under-represented
//
// Upgrade notes vs v1:
//   • Lazy-computed, invalidation-aware caches for partial sums and per-skill
//     RCA values — O(1) lookup after the first call per (job, skill) pair.
//   • Normalised skill representation: all comparisons are case-insensitive with
//     whitespace stripped at ingestion time, not at call time.
//   • Batch APIs for bulk scoring without repeated cache misses.
//   • Percentile ranking for skills within a job (relative standing, not
//     just absolute RCA).
//   • Skill gap analysis: which high-RCA skills does a user still lack?
//   • Global importance score: average RCA across every job that lists a skill.
//   • Thread-safety note: this class is not designed for concurrent mutation.
//     Construct a new instance per isolate if parallel processing is required.

import 'package:meta/meta.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PRIVATE NORMALISATION HELPERS
// ─────────────────────────────────────────────────────────────────────────────

/// Normalises a raw skill string for consistent storage and lookup.
String _norm(String s) => s.trim().toLowerCase();

/// Normalises every skill list in a raw jobs map and returns a clean copy.
///
/// Called once at [RCACalculator] construction time; all internal logic then
/// uses the clean map to avoid repeated normalisation overhead.
Map<String, List<String>> _normalizeMap(Map<String, List<String>> raw) {
  return raw.map(
        (jobId, skills) => MapEntry(
      jobId,
      skills.map(_norm).where((s) => s.isNotEmpty).toList(),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// PUBLIC TYPES
// ─────────────────────────────────────────────────────────────────────────────

/// Immutable RCA result for a single (job, skill) pair.
@immutable
class RCAResult {
  /// The normalised skill name.
  final String skill;

  /// Computed RCA value. ≥ 1.0 indicates comparative advantage.
  final double rca;

  /// Human-readable tier: "Critical", "Core", "Supporting", or "Peripheral".
  final String label;

  /// Hex colour for the tier (suitable for Flutter's `Color.parse`).
  final String color;

  /// Whether RCA ≥ 1.0 (i.e. the skill has comparative advantage).
  final bool isCore;

  /// Percentile rank among all skills in the same job (0–100).
  ///
  /// Populated only when requested via [RCACalculator.buildJobRCAProfile]
  /// with `includePercentiles: true` (the default).
  final double? percentile;

  const RCAResult({
    required this.skill,
    required this.rca,
    required this.label,
    required this.color,
    required this.isCore,
    this.percentile,
  });

  @override
  String toString() =>
      'RCAResult(skill: "$skill", rca: ${rca.toStringAsFixed(4)}, '
          'label: "$label", isCore: $isCore)';
}

/// Summary of a user's skill alignment with a target job.
@immutable
class UserSkillAlignmentReport {
  /// Target job identifier.
  final String jobId;

  /// 0–100 score: percentage of the user's skills that are high-RCA for this job.
  final double valueScore;

  /// User skills that are high-RCA (≥ 1.0) for the target job.
  final List<String> highValueSkills;

  /// High-RCA job skills the user does NOT yet possess (priority learning list).
  final List<String> skillGap;

  /// All job skills sorted by RCA descending, with full metadata.
  final List<RCAResult> jobSkillProfile;

  const UserSkillAlignmentReport({
    required this.jobId,
    required this.valueScore,
    required this.highValueSkills,
    required this.skillGap,
    required this.jobSkillProfile,
  });

  @override
  String toString() =>
      'UserSkillAlignmentReport(jobId: "$jobId", valueScore: '
          '${valueScore.toStringAsFixed(1)}, highValue: ${highValueSkills.length}, '
          'gap: ${skillGap.length})';
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN CLASS
// ─────────────────────────────────────────────────────────────────────────────

class RCACalculator {
  // ── Normalised source data ─────────────────────────────────────────────────

  /// Internal normalised copy of the job→skills map.
  late final Map<String, List<String>> _jobs;

  // ── Cached partial sums ────────────────────────────────────────────────────

  /// Σ_s' x(j, s') for each job — total skill count per job.
  late final Map<String, int> _totalSkillsPerJob;

  /// Σ_j' x(j', s) for each skill — number of jobs requiring the skill.
  late final Map<String, int> _jobCountPerSkill;

  /// Σ_j' Σ_s' x(j', s') — total (job, skill) pairs in the entire dataset.
  late final int _totalPairs;

  /// Per-(jobId, skill) RCA cache. Populated lazily on first access.
  final Map<String, Map<String, double>> _rcaCache = {};

  // ── Constructor ────────────────────────────────────────────────────────────

  /// Constructs an [RCACalculator] from a raw job→skills map.
  ///
  /// [jobSkillsMap] may use any casing / whitespace; all values are normalised
  /// internally. Jobs with empty skill lists are retained in the index
  /// (zero denominators are handled gracefully).
  ///
  /// Throws [ArgumentError] if [jobSkillsMap] is empty.
  RCACalculator(Map<String, List<String>> jobSkillsMap) {
    if (jobSkillsMap.isEmpty) {
      throw ArgumentError('jobSkillsMap must not be empty.');
    }
    _jobs = _normalizeMap(jobSkillsMap);
    _buildIndexes();
  }

  /// Builds cached partial sums in O(J × S) time — called once at construction.
  void _buildIndexes() {
    // Σ_s' x(j, s') per job.
    _totalSkillsPerJob = {
      for (final e in _jobs.entries) e.key: e.value.length,
    };

    // Σ_j' x(j', s) per skill and Σ_j' Σ_s' x(j', s').
    final Map<String, int> jobCount = {};
    int total = 0;

    for (final skills in _jobs.values) {
      total += skills.length;
      for (final skill in skills) {
        jobCount[skill] = (jobCount[skill] ?? 0) + 1;
      }
    }

    _jobCountPerSkill = jobCount;
    _totalPairs = total;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CORE RCA COMPUTATION
  // ─────────────────────────────────────────────────────────────────────────

  /// Calculates the RCA score for [skill] in [jobId].
  ///
  /// Uses cached partial sums — O(1) after the first call per (job, skill) pair.
  ///
  /// - Returns **0.0** for unknown job IDs, empty inputs, or if the job does
  ///   not list the skill.
  /// - RCA ≥ 1.0 indicates the skill has comparative advantage for this job.
  double calculateRCA(String skill, String jobId) {
    if (skill.isEmpty || jobId.isEmpty) return 0.0;

    final String nSkill = _norm(skill);
    final List<String>? jobSkills = _jobs[jobId];
    if (jobSkills == null || jobSkills.isEmpty) return 0.0;
    if (!jobSkills.contains(nSkill)) return 0.0;

    // Cache lookup.
    final Map<String, double> jobCache =
    _rcaCache.putIfAbsent(jobId, () => {});
    final double? cached = jobCache[nSkill];
    if (cached != null) return cached;

    final int skillsForJob = _totalSkillsPerJob[jobId]!;
    final int jobsWithSkill = _jobCountPerSkill[nSkill] ?? 0;

    if (skillsForJob == 0 || _totalPairs == 0 || jobsWithSkill == 0) {
      jobCache[nSkill] = 0.0;
      return 0.0;
    }

    // Numerator:   x(j,s) / Σ_s' x(j,s')  →  1 / skillsForJob
    // Denominator: Σ_j' x(j',s) / Σ_j' Σ_s' x(j',s')
    final double numerator = 1.0 / skillsForJob;
    final double denominator = jobsWithSkill / _totalPairs;

    final double rca = numerator / denominator;
    jobCache[nSkill] = rca;
    return rca;
  }

  /// Batch: calculates RCA for every skill listed in [jobId].
  ///
  /// Returns a `Map<String, double>` of `{skillName: rcaScore}` sorted by
  /// RCA descending (insertion order preserved via [LinkedHashMap] semantics).
  ///
  /// Returns an empty map for unknown or empty jobs.
  Map<String, double> getRankedSkillsForJob(String jobId) {
    final List<String>? skills = _jobs[jobId];
    if (skills == null || skills.isEmpty) return const {};

    final entries = skills
        .map((s) => MapEntry(s, calculateRCA(s, jobId)))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Map.fromEntries(entries);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CLASSIFICATION HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns `true` when RCA ≥ 1.0 (comparative advantage).
  bool isCoreSkill(String skill, String jobId) =>
      calculateRCA(skill, jobId) >= 1.0;

  /// Human-readable tier for an RCA score.
  ///
  /// | RCA        | Label       |
  /// |------------|-------------|
  /// | ≥ 2.0      | Critical    |
  /// | ≥ 1.0      | Core        |
  /// | ≥ 0.5      | Supporting  |
  /// | < 0.5      | Peripheral  |
  String getRCALabel(double rcaScore) {
    if (rcaScore >= 2.0) return 'Critical';
    if (rcaScore >= 1.0) return 'Core';
    if (rcaScore >= 0.5) return 'Supporting';
    return 'Peripheral';
  }

  /// Hex colour suitable for Flutter's `Color.fromARGB` / `HexColor` packages.
  ///
  /// | Tier        | Colour               |
  /// |-------------|----------------------|
  /// | Critical    | #E53935 (red)        |
  /// | Core        | #FB8C00 (orange)     |
  /// | Supporting  | #43A047 (green)      |
  /// | Peripheral  | #757575 (grey)       |
  String getRCAColor(double rcaScore) {
    if (rcaScore >= 2.0) return '#E53935';
    if (rcaScore >= 1.0) return '#FB8C00';
    if (rcaScore >= 0.5) return '#43A047';
    return '#757575';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // JOB SKILL PROFILE
  // ─────────────────────────────────────────────────────────────────────────

  /// Builds a full RCA profile for [jobId], with optional percentile ranks.
  ///
  /// Returns an ordered [List<RCAResult>] sorted by RCA descending.
  /// Each entry includes skill, rca, label, color, isCore, and — when
  /// [includePercentiles] is `true` — the skill's percentile rank among all
  /// skills in this job (0 = lowest, 100 = highest).
  ///
  /// Returns an empty list for unknown job IDs.
  List<RCAResult> buildJobRCAProfile(
      String jobId, {
        bool includePercentiles = true,
      }) {
    final Map<String, double> ranked = getRankedSkillsForJob(jobId);
    if (ranked.isEmpty) return const [];

    final List<MapEntry<String, double>> entries = ranked.entries.toList();
    final int n = entries.length;

    return entries.asMap().entries.map((indexedEntry) {
      final int rank = indexedEntry.key; // 0 = highest RCA
      final MapEntry<String, double> e = indexedEntry.value;
      final double rca = e.value;

      // Percentile: 100 for the top skill, 0 for the bottom (when n > 1).
      final double? percentile = includePercentiles
          ? (n == 1 ? 100.0 : (1.0 - rank / (n - 1)) * 100.0)
          : null;

      return RCAResult(
        skill: e.key,
        rca: rca,
        label: getRCALabel(rca),
        color: getRCAColor(rca),
        isCore: rca >= 1.0,
        percentile: percentile,
      );
    }).toList();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TOP / CORE SKILL ACCESSORS
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns the top-[topN] core skills (RCA ≥ 1.0) for [jobId], sorted by
  /// RCA descending. Returns an empty list for unknown or empty jobs.
  List<String> getCoreSkills(String jobId, {int topN = 10}) {
    if (topN <= 0) return const [];
    return getRankedSkillsForJob(jobId)
        .entries
        .where((e) => e.value >= 1.0)
        .take(topN)
        .map((e) => e.key)
        .toList();
  }

  /// Returns top-[topN] skills regardless of RCA tier, sorted descending.
  List<String> getTopSkills(String jobId, {int topN = 10}) {
    if (topN <= 0) return const [];
    return getRankedSkillsForJob(jobId).keys.take(topN).toList();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // USER-FACING ANALYSIS
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns which of [userSkills] are high-RCA (≥ 1.0) for [targetJobId].
  ///
  /// Comparison is case-insensitive. Returns an empty list for invalid inputs.
  List<String> getUserHighValueSkills(
      List<String> userSkills,
      String targetJobId,
      ) {
    if (userSkills.isEmpty || targetJobId.isEmpty) return const [];
    if (!_jobs.containsKey(targetJobId)) return const [];

    return userSkills
        .map(_norm)
        .where((s) => s.isNotEmpty && isCoreSkill(s, targetJobId))
        .toList();
  }

  /// Scores a user's skill set against [targetJobId].
  ///
  /// Score = (high-RCA user skills / total user skills) × 100.
  ///
  /// Returns **0.0** when [userSkills] is empty or the job is unknown.
  double getUserSkillValueScore(
      List<String> userSkills,
      String targetJobId,
      ) {
    if (userSkills.isEmpty) return 0.0;
    if (targetJobId.isEmpty || !_jobs.containsKey(targetJobId)) return 0.0;

    final int highValue =
        getUserHighValueSkills(userSkills, targetJobId).length;
    return (highValue / userSkills.length) * 100.0;
  }

  /// Returns core job skills (RCA ≥ 1.0) that [userSkills] does NOT cover —
  /// i.e. the priority learning list for this transition.
  ///
  /// Results are sorted by RCA descending (highest-priority gap first).
  List<String> getCoreSkillGap(
      List<String> userSkills,
      String targetJobId,
      ) {
    if (targetJobId.isEmpty || !_jobs.containsKey(targetJobId)) return const [];

    final Set<String> userSet = userSkills.map(_norm).toSet();
    return getRankedSkillsForJob(targetJobId)
        .entries
        .where((e) => e.value >= 1.0 && !userSet.contains(e.key))
        .map((e) => e.key)
        .toList();
  }

  /// Returns a complete alignment report for a user against [targetJobId].
  ///
  /// Combines [getUserSkillValueScore], [getUserHighValueSkills],
  /// [getCoreSkillGap], and [buildJobRCAProfile] into a single object,
  /// minimising redundant computation.
  UserSkillAlignmentReport buildAlignmentReport(
      List<String> userSkills,
      String targetJobId,
      ) {
    final List<RCAResult> profile =
    buildJobRCAProfile(targetJobId, includePercentiles: true);

    if (profile.isEmpty) {
      return const UserSkillAlignmentReport(
        jobId: '',
        valueScore: 0.0,
        highValueSkills: [],
        skillGap: [],
        jobSkillProfile: [],
      );
    }

    final Set<String> userSet = userSkills.map(_norm).toSet();

    final List<String> highValue = [];
    final List<String> gap = [];

    for (final r in profile) {
      final bool userHas = userSet.contains(r.skill);
      if (r.isCore) {
        if (userHas) {
          highValue.add(r.skill);
        } else {
          gap.add(r.skill);
        }
      }
    }

    final double score = userSkills.isEmpty
        ? 0.0
        : (highValue.length / userSkills.length) * 100.0;

    return UserSkillAlignmentReport(
      jobId: targetJobId,
      valueScore: score,
      highValueSkills: highValue,
      skillGap: gap,
      jobSkillProfile: profile,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GLOBAL IMPORTANCE
  // ─────────────────────────────────────────────────────────────────────────

  /// Average RCA of [skill] across every job that lists it.
  ///
  /// Provides a labour-market-wide "importance" signal — useful in
  /// `SkillPrioritizer` to rank which skills a user should learn regardless
  /// of a specific target job.
  ///
  /// Returns **0.0** if no job in the dataset lists the skill.
  double getSkillGlobalImportance(String skill) {
    if (skill.isEmpty) return 0.0;
    final String nSkill = _norm(skill);

    if (!_jobCountPerSkill.containsKey(nSkill)) return 0.0;

    double totalRCA = 0.0;
    int count = 0;

    for (final jobId in _jobs.keys) {
      final double rca = calculateRCA(nSkill, jobId);
      if (rca > 0.0) {
        totalRCA += rca;
        count++;
      }
    }

    return count == 0 ? 0.0 : totalRCA / count;
  }

  /// Returns all skills in the dataset ranked by global importance descending.
  ///
  /// **Performance note:** this is O(J × S) — cache the result on the caller
  /// side and avoid repeated calls in build methods.
  List<MapEntry<String, double>> getRankedSkillsByGlobalImportance() {
    final entries = _jobCountPerSkill.keys
        .map((s) => MapEntry(s, getSkillGlobalImportance(s)))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BATCH UTILITIES
  // ─────────────────────────────────────────────────────────────────────────

  /// Batch-scores [userSkills] against every job in the dataset.
  ///
  /// Returns a list of alignment summaries sorted by [valueScore] descending —
  /// i.e. the jobs where the user's existing skills are most "core".
  ///
  /// Useful for the "best-fit jobs" dashboard panel.
  List<UserSkillAlignmentReport> rankJobsForUser(List<String> userSkills) {
    if (userSkills.isEmpty) return const [];

    return _jobs.keys
        .map((jobId) => buildAlignmentReport(userSkills, jobId))
        .toList()
      ..sort((a, b) => b.valueScore.compareTo(a.valueScore));
  }

  /// Returns the complete RCA matrix for all jobs.
  ///
  /// Structure: `{ jobId: { skill: rcaScore } }`
  ///
  /// **Performance note:** O(J × S) — intended for export / offline analysis.
  /// For UI use, prefer [buildJobRCAProfile] which includes labels and
  /// percentiles and benefits from the RCA cache.
  Map<String, Map<String, double>> buildFullRCAMatrix() {
    return {
      for (final jobId in _jobs.keys) jobId: getRankedSkillsForJob(jobId),
    };
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CACHE MANAGEMENT
  // ─────────────────────────────────────────────────────────────────────────

  /// Clears the RCA value cache.
  ///
  /// Call after hot-reloading [jobSkillsMap] in dev mode. In production, prefer
  /// constructing a fresh [RCACalculator] instance instead.
  void clearCache() => _rcaCache.clear();

  /// Number of (jobId, skill) pairs currently in the RCA cache.
  int get cacheSize => _rcaCache.values.fold(0, (sum, m) => sum + m.length);

  /// Number of distinct jobs in the dataset.
  int get jobCount => _jobs.length;

  /// Number of distinct skills across all jobs.
  int get skillCount => _jobCountPerSkill.length;

  /// Total (job, skill) pairs in the dataset.
  int get totalPairs => _totalPairs;
}