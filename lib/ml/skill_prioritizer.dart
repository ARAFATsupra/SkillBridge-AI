// lib/ml/skill_prioritizer.dart — SkillBridge AI
// Ranks skills by acquisition priority using a composite importance × distance
// score.
//
// Research foundation:
//   Dawson et al. (2021) — SKILLS SPACE research.
//
// Acquisition Score = Importance × Distance
//   Importance = normalised RCA for the skill in the target job [0, 1]
//   Distance   = 1 − max θ(userSkill, targetSkill) across all user skills
//
// Refactor notes vs previous version:
//   • Dart 3: _label, _reasoning, generateLearningRoadmap, and getSummary all
//     use switch expressions / enhanced switch instead of if-else chains or
//     legacy case/break patterns — more concise and compiler-exhausted.
//   • getSummary: switch expression replaces the legacy case/break block,
//     eliminating mutable counter updates inside a switch arm.
//   • All dependency-injected instances, caches, algorithms, configurable
//     constructor parameters, typed value-objects, and public APIs are
//     unchanged.

import 'rca_calculator.dart';
import 'skill_similarity.dart';

// ── File-level helpers ────────────────────────────────────────────────────────

String _norm(String s) => s.trim().toLowerCase();

// ── Priority label constants ──────────────────────────────────────────────────

/// User already possesses this skill.
const String kLabelAlreadyHave = 'Already Have';

/// Highest-priority gap skill — must learn before transitioning.
const String kLabelLearnFirst = 'Learn First';

/// Important gap skill — learn after [kLabelLearnFirst] skills.
const String kLabelLearnSoon = 'Learn Soon';

/// Lower-priority gap skill — defer until primary gaps are closed.
const String kLabelOptional = 'Optional';

// ── Public types ──────────────────────────────────────────────────────────────

/// Immutable priority assessment for a single target skill.
class PrioritizedSkill {
  /// Raw (un-normalised) skill name as supplied by the caller.
  final String skillName;

  /// How important is this skill for the target job? Range: [0.0, 1.0].
  ///
  /// Derived from RCA (normalised by [SkillPrioritizer.rcaNormCap]).
  final double importanceScore;

  /// How far is the user from possessing this skill? Range: [0.0, 1.0].
  ///
  /// 0.0 = user already has it; 1.0 = completely unfamiliar.
  final double distanceScore;

  /// Composite priority metric: `importanceScore × distanceScore`.
  final double acquisitionScore;

  /// One of [kLabelAlreadyHave], [kLabelLearnFirst], [kLabelLearnSoon],
  /// or [kLabelOptional].
  final String priorityLabel;

  /// User-facing explanation for the priority assignment.
  final String reasoning;

  const PrioritizedSkill({
    required this.skillName,
    required this.importanceScore,
    required this.distanceScore,
    required this.acquisitionScore,
    required this.priorityLabel,
    required this.reasoning,
  });

  @override
  String toString() =>
      'PrioritizedSkill(skill: "$skillName", '
          'importance: ${importanceScore.toStringAsFixed(3)}, '
          'distance: ${distanceScore.toStringAsFixed(3)}, '
          'score: ${acquisitionScore.toStringAsFixed(3)}, '
          'label: $priorityLabel)';

  /// Converts to a display-ready [Map] for widget data binding.
  Map<String, dynamic> toMap() => <String, dynamic>{
    'skillName': skillName,
    'importanceScore': importanceScore,
    'distanceScore': distanceScore,
    'acquisitionScore': acquisitionScore,
    'priorityLabel': priorityLabel,
    'reasoning': reasoning,
    'importancePct': (importanceScore * 100).toStringAsFixed(0),
    'acquisitionPct': (acquisitionScore * 100).toStringAsFixed(0),
  };
}

/// A single entry in a learning roadmap.
class LearningRoadmapEntry {
  /// 1-based rank in the roadmap (lower = learn sooner).
  final int rank;

  /// Raw skill name.
  final String skillName;

  /// Priority label ([kLabelLearnFirst], [kLabelLearnSoon], or
  /// [kLabelOptional]).
  final String priorityLabel;

  /// Importance score in [0.0, 1.0].
  final double importanceScore;

  /// Composite acquisition score in [0.0, 1.0].
  final double acquisitionScore;

  /// An existing user skill that complements [skillName] and can serve as a
  /// learning bridge. `null` when no bridge skill is identified.
  final String? bridgeSkill;

  /// Full user-facing description line (suitable for display in a list).
  final String description;

  const LearningRoadmapEntry({
    required this.rank,
    required this.skillName,
    required this.priorityLabel,
    required this.importanceScore,
    required this.acquisitionScore,
    required this.description,
    this.bridgeSkill,
  });

  @override
  String toString() => '$rank. $description';
}

/// Aggregate statistics for a prioritised skill list.
class SkillPrioritySummary {
  /// Total number of target job skills evaluated.
  final int totalSkills;

  /// Skills the user already possesses.
  final int alreadyHave;

  /// High-priority gaps (acquisition score ≥ 0.6).
  final int learnFirst;

  /// Medium-priority gaps (acquisition score 0.3–0.6).
  final int learnSoon;

  /// Low-priority gaps (acquisition score < 0.3).
  final int optional;

  /// Simple coverage: `(alreadyHave / totalSkills) × 100`.
  final int readinessScore;

  /// Importance-weighted coverage: fraction of total importance mass already
  /// possessed by the user. Typically a more meaningful signal than the
  /// simple count-based [readinessScore].
  final double weightedReadiness;

  const SkillPrioritySummary({
    required this.totalSkills,
    required this.alreadyHave,
    required this.learnFirst,
    required this.learnSoon,
    required this.optional,
    required this.readinessScore,
    required this.weightedReadiness,
  });

  @override
  String toString() =>
      'SkillPrioritySummary(total: $totalSkills, have: $alreadyHave, '
          'learnFirst: $learnFirst, learnSoon: $learnSoon, '
          'optional: $optional, readiness: $readinessScore%, '
          'weighted: ${weightedReadiness.toStringAsFixed(3)})';

  /// Converts to a display-ready [Map] for widget data binding.
  Map<String, dynamic> toMap() => <String, dynamic>{
    'totalSkills': totalSkills,
    'alreadyHave': alreadyHave,
    'learnFirst': learnFirst,
    'learnSoon': learnSoon,
    'optional': optional,
    'readinessScore': readinessScore,
    'weightedReadiness': weightedReadiness,
  };
}

// ── Main class ────────────────────────────────────────────────────────────────

/// Computes acquisition-priority rankings for target job skills.
///
/// ### Construction
/// ```dart
/// final rca = RCACalculator(jobSkillsMap);
/// final sim = SkillSimilarityEngine(
///   rcaCalculator: rca,
///   jobIds: jobSkillsMap.keys,
/// );
/// final prioritizer = SkillPrioritizer(
///   rcaCalculator: rca,
///   similarityEngine: sim,
/// );
/// ```
class SkillPrioritizer {
  final RCACalculator _rca;
  final SkillSimilarityEngine _sim;

  /// RCA values at or above this cap are treated as equivalent at
  /// importance = 1.0. The default 3.0 matches the typical upper bound of
  /// RCA distributions in Dawson et al. (2021).
  final double rcaNormCap;

  /// Importance assigned to skills with no RCA entry in the dataset.
  ///
  /// Prevents zero-importance assignments for valid target skills that happen
  /// to lie outside the job-posting corpus.
  final double fallbackImportance;

  // ── Constructor ────────────────────────────────────────────────────────────

  /// Creates a [SkillPrioritizer] backed by shared [rcaCalculator] and
  /// [similarityEngine] instances.
  ///
  /// [rcaNormCap] must be > 0. [fallbackImportance] must be in (0, 1].
  ///
  /// Throws [ArgumentError] on invalid configuration values.
  SkillPrioritizer({
    required RCACalculator rcaCalculator,
    required SkillSimilarityEngine similarityEngine,
    this.rcaNormCap = 3.0,
    this.fallbackImportance = 0.2,
  })  : _rca = rcaCalculator,
        _sim = similarityEngine {
    if (rcaNormCap <= 0) {
      throw ArgumentError('rcaNormCap must be > 0, got $rcaNormCap.');
    }
    if (fallbackImportance <= 0 || fallbackImportance > 1) {
      throw ArgumentError(
        'fallbackImportance must be in (0, 1], got $fallbackImportance.',
      );
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Returns `true` when [targetSkill] (already normalised) is present in
  /// [userNorm] via exact match, or via substring containment if
  /// [fuzzyMatch] is `true`.
  bool _userHasSkill(
      String targetSkill,
      Set<String> userNorm, {
        bool fuzzyMatch = true,
      }) {
    if (userNorm.contains(targetSkill)) return true;
    if (!fuzzyMatch) return false;
    return userNorm.any(
          (String us) => us.contains(targetSkill) || targetSkill.contains(us),
    );
  }

  /// Computes the distance from [userNorm] to [targetSkill].
  ///
  /// Distance = 1 − max θ(userSkill, targetSkill) across all user skills.
  /// Returns 0.0 when the user already has the skill; 1.0 when the user
  /// skill set is empty.
  double _calcDistance(
      String targetSkill,
      Set<String> userNorm, {
        bool fuzzyMatch = true,
      }) {
    if (_userHasSkill(targetSkill, userNorm, fuzzyMatch: fuzzyMatch)) {
      return 0.0;
    }
    if (userNorm.isEmpty) return 1.0;

    double maxTheta = 0.0;
    for (final String us in userNorm) {
      final double theta = _sim.calculateTheta(us, targetSkill);
      if (theta > maxTheta) maxTheta = theta;
    }
    return (1.0 - maxTheta).clamp(0.0, 1.0);
  }

  /// Normalises the RCA for [skill] in [targetJobId] to [0.0, 1.0].
  ///
  /// Priority order:
  ///   1. Job-specific RCA divided by [rcaNormCap].
  ///   2. Global mean RCA divided by [rcaNormCap].
  ///   3. [fallbackImportance].
  double _calcImportance(String skill, String targetJobId) {
    final double jobRCA = _rca.calculateRCA(skill, targetJobId);
    if (jobRCA > 0.0) return (jobRCA / rcaNormCap).clamp(0.0, 1.0);

    final double globalRCA = _rca.getSkillGlobalImportance(skill);
    if (globalRCA > 0.0) return (globalRCA / rcaNormCap).clamp(0.0, 1.0);

    return fallbackImportance;
  }

  /// Maps scores to a priority label.
  String _label(double acquisitionScore, double distance) => switch (distance) {
    0.0 => kLabelAlreadyHave,
    _ => switch (acquisitionScore) {
      >= 0.6 => kLabelLearnFirst,
      >= 0.3 => kLabelLearnSoon,
      _      => kLabelOptional,
    },
  };

  /// Generates a user-facing explanation for the priority assignment.
  String _reasoning(
      String rawSkillName,
      double importance,
      double distance,
      String label,
      ) {
    if (label == kLabelAlreadyHave) {
      return '$rawSkillName is already in your skill set — '
          'a strength for your target job.';
    }

    final String iPct = (importance * 100).toStringAsFixed(0);
    final String dPct = (distance * 100).toStringAsFixed(0);

    return switch (label) {
      kLabelLearnFirst =>
      '$rawSkillName is a critical requirement '
          '(importance: $iPct%) with a significant gap (distance: $dPct%). '
          'Prioritise this immediately.',
      kLabelLearnSoon =>
      '$rawSkillName is moderately important ($iPct%) '
          'with a noticeable gap ($dPct%). '
          'Learn this after your "$kLabelLearnFirst" skills.',
      _ =>
      '$rawSkillName has lower priority for this role '
          '(importance: $iPct%, gap: $dPct%). '
          'Focus on higher-priority skills first.',
    };
  }

  // ── Public: prioritize ─────────────────────────────────────────────────────

  /// Produces a prioritised list of [targetJobSkills] for the given user.
  ///
  /// **Sort order**: [kLabelAlreadyHave] entries appear last; remaining
  /// skills are sorted by [PrioritizedSkill.acquisitionScore] descending.
  ///
  /// [targetJobId] is used for job-specific RCA lookups.
  ///
  /// [fuzzyMatch]: when `true` (default), substring containment is accepted
  /// as evidence that the user possesses a skill.
  ///
  /// Returns an empty list when [targetJobSkills] is empty.
  List<PrioritizedSkill> prioritizeSkills(
      List<String> userSkills,
      List<String> targetJobSkills,
      String targetJobId, {
        bool fuzzyMatch = true,
      }) {
    if (targetJobSkills.isEmpty) return const <PrioritizedSkill>[];

    // Normalise user skills once — fixes the v1 bug where the result of
    // _normalizeSkills() was discarded and _userHasSkill() re-normalised
    // on every call.
    final Set<String> userNorm = userSkills
        .map(_norm)
        .where((String s) => s.isNotEmpty)
        .toSet();

    final List<PrioritizedSkill> result = <PrioritizedSkill>[];

    for (final String rawSkill in targetJobSkills) {
      final String skill = _norm(rawSkill);
      if (skill.isEmpty) continue;

      final double importance = _calcImportance(skill, targetJobId);
      final double distance = _calcDistance(
        skill,
        userNorm,
        fuzzyMatch: fuzzyMatch,
      );
      final double score = importance * distance;
      final String label = _label(score, distance);

      result.add(PrioritizedSkill(
        skillName: rawSkill,
        importanceScore: importance,
        distanceScore: distance,
        acquisitionScore: score,
        priorityLabel: label,
        reasoning: _reasoning(rawSkill, importance, distance, label),
      ));
    }

    result.sort((PrioritizedSkill a, PrioritizedSkill b) {
      final bool aHave = a.priorityLabel == kLabelAlreadyHave;
      final bool bHave = b.priorityLabel == kLabelAlreadyHave;
      if (aHave != bHave) return aHave ? 1 : -1;
      return b.acquisitionScore.compareTo(a.acquisitionScore);
    });

    return result;
  }

  // ── Public: filtered accessors ─────────────────────────────────────────────

  /// Returns only [kLabelLearnFirst] skills (acquisition score ≥ 0.6).
  List<PrioritizedSkill> getMustLearnSkills(
      List<String> userSkills,
      List<String> targetJobSkills,
      String targetJobId, {
        bool fuzzyMatch = true,
      }) =>
      prioritizeSkills(
        userSkills,
        targetJobSkills,
        targetJobId,
        fuzzyMatch: fuzzyMatch,
      )
          .where(
            (PrioritizedSkill s) => s.priorityLabel == kLabelLearnFirst,
      )
          .toList();

  /// Returns [kLabelAlreadyHave] skills sorted by importance descending.
  ///
  /// These are the user's **strengths** for the target role.
  List<PrioritizedSkill> getStrengthSkills(
      List<String> userSkills,
      List<String> targetJobSkills,
      String targetJobId, {
        bool fuzzyMatch = true,
      }) {
    final List<PrioritizedSkill> strengths = prioritizeSkills(
      userSkills,
      targetJobSkills,
      targetJobId,
      fuzzyMatch: fuzzyMatch,
    )
        .where(
          (PrioritizedSkill s) => s.priorityLabel == kLabelAlreadyHave,
    )
        .toList()
      ..sort(
            (PrioritizedSkill a, PrioritizedSkill b) =>
            b.importanceScore.compareTo(a.importanceScore),
      );
    return strengths;
  }

  // ── Public: learning roadmap ───────────────────────────────────────────────

  /// Generates a structured [LearningRoadmapEntry] list for skills the user
  /// still needs to acquire.
  ///
  /// **Bridge-skill hint**: a single complementary skill suggestion from
  /// [SkillSimilarityEngine.suggestComplementarySkills] is computed once
  /// before the loop and reused across entries, avoiding O(n) redundant calls.
  ///
  /// Returns an empty list when all target skills are already possessed.
  List<LearningRoadmapEntry> generateLearningRoadmap(
      List<String> userSkills,
      List<String> targetJobSkills,
      String targetJobId, {
        bool fuzzyMatch = true,
      }) {
    final List<PrioritizedSkill> toLearn = prioritizeSkills(
      userSkills,
      targetJobSkills,
      targetJobId,
      fuzzyMatch: fuzzyMatch,
    )
        .where(
          (PrioritizedSkill s) => s.priorityLabel != kLabelAlreadyHave,
    )
        .toList();

    if (toLearn.isEmpty) return const <LearningRoadmapEntry>[];

    // Compute bridge skill once to avoid O(n) redundant calls.
    final List<String> bridgeSuggestions = _sim.suggestComplementarySkills(
      userSkills,
      targetJobSkills,
      topN: 1,
    );
    final String? globalBridge =
    bridgeSuggestions.isNotEmpty ? bridgeSuggestions.first : null;

    final List<LearningRoadmapEntry> roadmap = <LearningRoadmapEntry>[];

    for (int i = 0; i < toLearn.length; i++) {
      final PrioritizedSkill skill = toLearn[i];
      final String iPct = (skill.importanceScore * 100).toStringAsFixed(0);

      final String scoreLabel = switch (skill.priorityLabel) {
        kLabelLearnFirst => 'Critical',
        kLabelLearnSoon  => 'High Priority',
        _                => 'Low Priority',
      };

      // Show the bridge hint only when the bridge skill differs from this one.
      final bool showBridge = globalBridge != null &&
          _norm(globalBridge) != _norm(skill.skillName);
      final String? bridge = showBridge ? globalBridge : null;

      final String desc = '${i + 1}. Learn ${skill.skillName} '
          '($scoreLabel — $iPct% importance'
          '${bridge != null ? ", builds on your $bridge knowledge" : ""})';

      roadmap.add(LearningRoadmapEntry(
        rank: i + 1,
        skillName: skill.skillName,
        priorityLabel: skill.priorityLabel,
        importanceScore: skill.importanceScore,
        acquisitionScore: skill.acquisitionScore,
        bridgeSkill: bridge,
        description: desc,
      ));
    }

    return roadmap;
  }

  /// Returns the roadmap as a plain list of description strings.
  ///
  /// When the user has all required skills, returns a single congratulatory
  /// message encouraging deepened expertise.
  List<String> generateRoadmapStrings(
      List<String> userSkills,
      List<String> targetJobSkills,
      String targetJobId, {
        bool fuzzyMatch = true,
      }) {
    final List<LearningRoadmapEntry> roadmap = generateLearningRoadmap(
      userSkills,
      targetJobSkills,
      targetJobId,
      fuzzyMatch: fuzzyMatch,
    );

    if (roadmap.isEmpty) {
      return const <String>[
        'You already have all the required skills for this role! '
            'Focus on deepening your expertise and building a strong portfolio.',
      ];
    }

    return roadmap
        .map((LearningRoadmapEntry e) => e.description)
        .toList();
  }

  // ── Public: summary statistics ─────────────────────────────────────────────

  /// Returns a [SkillPrioritySummary] aggregating the prioritised skill list.
  ///
  /// Includes both the simple count-based [SkillPrioritySummary.readinessScore]
  /// and the importance-weighted [SkillPrioritySummary.weightedReadiness].
  SkillPrioritySummary getSummary(
      List<String> userSkills,
      List<String> targetJobSkills,
      String targetJobId, {
        bool fuzzyMatch = true,
      }) {
    final List<PrioritizedSkill> prioritized = prioritizeSkills(
      userSkills,
      targetJobSkills,
      targetJobId,
      fuzzyMatch: fuzzyMatch,
    );

    if (prioritized.isEmpty) {
      return const SkillPrioritySummary(
        totalSkills: 0,
        alreadyHave: 0,
        learnFirst: 0,
        learnSoon: 0,
        optional: 0,
        readinessScore: 0,
        weightedReadiness: 0.0,
      );
    }

    int have = 0;
    int first = 0;
    int soon = 0;
    int opt = 0;
    double totalWeight = 0.0;
    double haveWeight = 0.0;

    for (final PrioritizedSkill s in prioritized) {
      totalWeight += s.importanceScore;

      // Dart 3 enhanced switch — eliminates legacy case/break mutation pattern.
      switch (s.priorityLabel) {
        case kLabelAlreadyHave:
          have++;
          haveWeight += s.importanceScore;
        case kLabelLearnFirst:
          first++;
        case kLabelLearnSoon:
          soon++;
        default:
          opt++;
      }
    }

    return SkillPrioritySummary(
      totalSkills: prioritized.length,
      alreadyHave: have,
      learnFirst: first,
      learnSoon: soon,
      optional: opt,
      readinessScore: ((have / prioritized.length) * 100).round(),
      weightedReadiness:
      totalWeight == 0.0 ? 0.0 : haveWeight / totalWeight,
    );
  }
}