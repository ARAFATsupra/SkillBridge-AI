// lib/models/career_profile.dart — SkillBridge AI  (Upgraded v3)
// ──────────────────────────────────────────────────────────────────────────────
// Research grounding:
//   [AJJ26] Ajjam & Al-Raweshidy (2026) — AI semantic job matching (§3–4)
//   [ZC22]  Zhisheng Chen (2022)         — P-J Fit, P-O Fit, 6-stage recruitment
//   [ALA23] Alaql et al. (2023)          — Multi-generational workforce insights
//   [XZ25]  Xiao & Zheng (2025)          — Career confidence tracking
//   [LH22]  Li Huang (2022)              — Employment intention evolution
//   [TAV22] Tavakoli et al. (2022)       — eDoer learner preference model
//   [DAW21] Dawson et al. (2021)         — Skill-driven job transition pathways
//
// UPGRADE NOTES v3 (patched):
//   • fromMap uses EntrepreneurialAspiration.fromKey() for round-trip symmetry.
//   • _parseDoubleMap returns an empty growable map (not const) on failure so
//     callers can safely merge into it without type errors.
//   • copyWith clamp results explicitly cast to int/double to avoid num issues
//     on Dart SDKs that widen clamp() return to num.
//   • missingCoreSkills removes redundant double-lowercase on coreSkills entries
//     (coreSkills already returns lowercase strings).
//   • learnerColdStartVector inline comment clarifies per-axis softmax intent.
//   • All original business logic, field names, and research citations preserved.
// ──────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:skillbridge_ai/services/api_service.dart';

// =============================================================================
// FIELD OF STUDY  [AJJ26 §3.3]
// =============================================================================

/// Fields of study drawn from career_guidance_dataset.csv (Arts, Business,
/// Engineering, Law, Science) plus app-extended entries.
enum FieldOfStudy {
  science,
  engineering,
  business,
  arts,
  finance,
  it,
  education,
  healthcare,
  marketing,
  law,
  other;

  // ── Labels ────────────────────────────────────────────────
  String get label {
    switch (this) {
      case FieldOfStudy.science:     return 'Science';
      case FieldOfStudy.engineering: return 'Engineering';
      case FieldOfStudy.business:    return 'Business';
      case FieldOfStudy.arts:        return 'Arts & Design';
      case FieldOfStudy.finance:     return 'Finance';
      case FieldOfStudy.it:          return 'Information Technology';
      case FieldOfStudy.education:   return 'Education';
      case FieldOfStudy.healthcare:  return 'Healthcare';
      case FieldOfStudy.marketing:   return 'Marketing';
      case FieldOfStudy.law:         return 'Law';
      case FieldOfStudy.other:       return 'Other';
    }
  }

  String get shortLabel {
    switch (this) {
      case FieldOfStudy.science:     return 'Science';
      case FieldOfStudy.engineering: return 'Engineering';
      case FieldOfStudy.business:    return 'Business';
      case FieldOfStudy.arts:        return 'Arts';
      case FieldOfStudy.finance:     return 'Finance';
      case FieldOfStudy.it:          return 'IT';
      case FieldOfStudy.education:   return 'Education';
      case FieldOfStudy.healthcare:  return 'Healthcare';
      case FieldOfStudy.marketing:   return 'Marketing';
      case FieldOfStudy.law:         return 'Law';
      case FieldOfStudy.other:       return 'Other';
    }
  }

  /// Serialisation key — equals the Dart enum name (lowercase).
  String get key => name;

  // ── Parse ─────────────────────────────────────────────────
  static FieldOfStudy fromKey(String key) => FieldOfStudy.values.firstWhere(
        (e) => e.name == key.trim().toLowerCase(),
    orElse: () => FieldOfStudy.other,
  );

  static FieldOfStudy fromLabel(String label) =>
      FieldOfStudy.values.firstWhere(
            (e) =>
        e.label.toLowerCase() == label.trim().toLowerCase() ||
            e.shortLabel.toLowerCase() == label.trim().toLowerCase(),
        orElse: () => FieldOfStudy.other,
      );

  // ── Dataset flags ─────────────────────────────────────────
  /// True only for fields directly observed in career_guidance_dataset.csv.
  bool get isDatasetBacked =>
      this == FieldOfStudy.science ||
          this == FieldOfStudy.engineering ||
          this == FieldOfStudy.business ||
          this == FieldOfStudy.arts ||
          this == FieldOfStudy.law;

  // ── Recommended industries ────────────────────────────────
  /// Top industries — dataset-backed frequencies for 5 CSV fields.
  /// Source: career_guidance_dataset.csv Top_Recommended_Industries column.
  List<String> get recommendedIndustries {
    switch (this) {
      case FieldOfStudy.science:
        return ['Software', 'Finance', 'Healthcare', 'Education'];
      case FieldOfStudy.engineering:
        return ['Finance', 'Software', 'Education', 'Manufacturing'];
      case FieldOfStudy.business:
        return ['Finance', 'Healthcare', 'Education', 'Retail'];
      case FieldOfStudy.arts:
        return ['Finance', 'Software', 'Healthcare', 'Marketing'];
      case FieldOfStudy.law:
        return ['Finance', 'Education', 'Software'];
      case FieldOfStudy.it:
        return ['Software', 'Finance', 'Healthcare', 'Manufacturing'];
      case FieldOfStudy.finance:
        return ['Finance', 'Retail', 'Software'];
      case FieldOfStudy.healthcare:
        return ['Healthcare', 'Education', 'Finance'];
      case FieldOfStudy.marketing:
        return ['Marketing', 'Retail', 'Software', 'Education'];
      case FieldOfStudy.education:
        return ['Education', 'Healthcare', 'Retail', 'Finance'];
      case FieldOfStudy.other:
        return ['Finance', 'Software', 'Marketing'];
    }
  }

  // ── Core skills ───────────────────────────────────────────
  /// All strings LOWERCASE to match the 50 k-row dataset skill column.
  List<String> get coreSkills {
    switch (this) {
      case FieldOfStudy.engineering:
        return [
          'python', 'java', 'c++', 'sql', 'git',
          'problem solving', 'oop',
        ];
      case FieldOfStudy.it:
        return [
          'python', 'java', 'sql', 'networking',
          'aws', 'cloud computing', 'linux',
        ];
      case FieldOfStudy.business:
        return [
          'excel', 'data analysis', 'communication skills',
          'financial modeling', 'sql',
        ];
      case FieldOfStudy.finance:
        return [
          'excel', 'financial modeling', 'risk analysis', 'sql', 'python',
        ];
      case FieldOfStudy.science:
        return [
          'python', 'data analysis', 'statistics', 'research', 'sql',
        ];
      case FieldOfStudy.healthcare:
        return [
          'patient care', 'medical research', 'pharmaceuticals',
          'nursing', 'communication skills',
        ];
      case FieldOfStudy.marketing:
        return [
          'seo', 'social media', 'content writing', 'google ads', 'analytics',
        ];
      case FieldOfStudy.education:
        return [
          'teaching', 'curriculum design', 'edtech',
          'research', 'communication skills',
        ];
      case FieldOfStudy.arts:
        return [
          'ux design', 'figma', 'content writing',
          'copywriting', 'adobe creative suite',
        ];
      case FieldOfStudy.law:
        return [
          'research', 'communication skills', 'risk analysis',
          'reporting', 'negotiation',
        ];
      case FieldOfStudy.other:
        return [
          'communication skills', 'excel', 'data analysis',
          'problem solving', 'sql',
        ];
    }
  }

  // ── TAV22 content-topic weight ────────────────────────────
  /// Learning-domain weight used in TAV22-based preference scoring.
  /// Engineering / IT = high weight on technical content.
  double get learningDomainWeight {
    switch (this) {
      case FieldOfStudy.engineering:
      case FieldOfStudy.it:
      case FieldOfStudy.science:
        return 1.0;
      case FieldOfStudy.finance:
      case FieldOfStudy.business:
        return 0.8;
      case FieldOfStudy.healthcare:
      case FieldOfStudy.law:
        return 0.7;
      case FieldOfStudy.marketing:
      case FieldOfStudy.arts:
      case FieldOfStudy.education:
        return 0.6;
      case FieldOfStudy.other:
        return 0.5;
    }
  }

  // ── Post-grad stats ───────────────────────────────────────
  /// Employment outcome statistics from career_guidance_dataset.csv.
  PostGradStats? get postGradStats {
    switch (this) {
      case FieldOfStudy.arts:
        return const PostGradStats(
            employed: 0.31, selfEmployed: 0.38, unemployed: 0.31);
      case FieldOfStudy.business:
        return const PostGradStats(
            employed: 0.29, selfEmployed: 0.36, unemployed: 0.35);
      case FieldOfStudy.engineering:
        return const PostGradStats(
            employed: 0.34, selfEmployed: 0.33, unemployed: 0.33);
      case FieldOfStudy.law:
        return const PostGradStats(
            employed: 0.31, selfEmployed: 0.35, unemployed: 0.34);
      case FieldOfStudy.science:
        return const PostGradStats(
            employed: 0.30, selfEmployed: 0.31, unemployed: 0.39);
      default:
        return null;
    }
  }
}

// =============================================================================
// CAREER PATH
// =============================================================================

/// Exact Recommended_Career_Path column values from career_guidance_dataset.csv:
/// Business, Design, Finance, Healthcare, Tech.
enum CareerPath {
  business,
  design,
  finance,
  healthcare,
  tech,
  other;

  String get label {
    switch (this) {
      case CareerPath.business:   return 'Business';
      case CareerPath.design:     return 'Design';
      case CareerPath.finance:    return 'Finance';
      case CareerPath.healthcare: return 'Healthcare';
      case CareerPath.tech:       return 'Tech';
      case CareerPath.other:      return 'Other';
    }
  }

  String get key => name;

  static CareerPath fromLabel(String? label) {
    const map = {
      'business':   CareerPath.business,
      'design':     CareerPath.design,
      'finance':    CareerPath.finance,
      'healthcare': CareerPath.healthcare,
      'tech':       CareerPath.tech,
    };
    return map[label?.toLowerCase().trim()] ?? CareerPath.other;
  }

  static CareerPath fromKey(String key) => CareerPath.values.firstWhere(
        (e) => e.name == key.trim().toLowerCase(),
    orElse: () => CareerPath.other,
  );

  /// Average career-success probability from dataset [n=1000].
  double get avgSuccessProbability {
    switch (this) {
      case CareerPath.healthcare: return 0.529;
      case CareerPath.finance:    return 0.509;
      case CareerPath.business:   return 0.503;
      case CareerPath.design:     return 0.502;
      case CareerPath.tech:       return 0.488;
      case CareerPath.other:      return 0.504;
    }
  }

  /// Delta vs overall mean (0.504) — used in success-probability formula.
  double get successBoost {
    switch (this) {
      case CareerPath.healthcare: return  0.025;
      case CareerPath.finance:    return  0.005;
      case CareerPath.business:   return -0.001;
      case CareerPath.design:     return -0.002;
      case CareerPath.tech:       return -0.016;
      case CareerPath.other:      return  0.000;
    }
  }

  IconData get icon {
    switch (this) {
      case CareerPath.business:   return Icons.business_rounded;
      case CareerPath.design:     return Icons.palette_rounded;
      case CareerPath.finance:    return Icons.account_balance_rounded;
      case CareerPath.healthcare: return Icons.health_and_safety_rounded;
      case CareerPath.tech:       return Icons.computer_rounded;
      case CareerPath.other:      return Icons.work_outline_rounded;
    }
  }
}

// =============================================================================
// ENTREPRENEURIAL ASPIRATION
// =============================================================================

/// Exact Entrepreneurial_Aspirations column values: High, Medium, Low.
enum EntrepreneurialAspiration {
  high,
  medium,
  low;

  String get label {
    switch (this) {
      case EntrepreneurialAspiration.high:   return 'High';
      case EntrepreneurialAspiration.medium: return 'Medium';
      case EntrepreneurialAspiration.low:    return 'Low';
    }
  }

  /// Serialisation key — equals the Dart enum name (lowercase).
  String get key => name;

  static EntrepreneurialAspiration fromLabel(String? label) {
    const map = {
      'high':   EntrepreneurialAspiration.high,
      'medium': EntrepreneurialAspiration.medium,
      'low':    EntrepreneurialAspiration.low,
    };
    return map[label?.toLowerCase().trim()] ?? EntrepreneurialAspiration.low;
  }

  /// Parse from the serialisation key (enum name).  Preferred over
  /// [fromLabel] when reading back values written by [toMap].
  static EntrepreneurialAspiration fromKey(String key) =>
      EntrepreneurialAspiration.values.firstWhere(
            (e) => e.name == key.trim().toLowerCase(),
        orElse: () => EntrepreneurialAspiration.low,
      );

  /// Delta vs mean — dataset-backed. [ALA23]
  double get successBoost {
    switch (this) {
      case EntrepreneurialAspiration.high:   return  0.024;
      case EntrepreneurialAspiration.medium: return -0.004;
      case EntrepreneurialAspiration.low:    return -0.014;
    }
  }

  double get avgSuccessProbability {
    switch (this) {
      case EntrepreneurialAspiration.high:   return 0.5275;
      case EntrepreneurialAspiration.medium: return 0.4997;
      case EntrepreneurialAspiration.low:    return 0.4900;
    }
  }

  String get description {
    switch (this) {
      case EntrepreneurialAspiration.high:
        return 'Eager to launch or co-found a venture.';
      case EntrepreneurialAspiration.medium:
        return 'Open to entrepreneurship as a future option.';
      case EntrepreneurialAspiration.low:
        return 'Prefers structured employment over self-employment.';
    }
  }
}

// =============================================================================
// EXPERIENCE TYPE
// =============================================================================

enum ExperienceType {
  none,
  internship,
  partTime,
  fullTime;

  String get label {
    switch (this) {
      case ExperienceType.none:       return 'No Experience';
      case ExperienceType.internship: return 'Internship';
      case ExperienceType.partTime:   return 'Part-time';
      case ExperienceType.fullTime:   return 'Full-time';
    }
  }

  String get key => name;

  static ExperienceType fromKey(String key) => ExperienceType.values.firstWhere(
        (e) => e.name == key.trim(),
    orElse: () => ExperienceType.none,
  );

  static ExperienceType fromDatasetLabel(String? label) {
    final l = label?.toLowerCase().trim() ?? '';
    if (l == 'full-time' || l == 'fulltime' ||
        l == 'contract'  || l == 'temporary') {
      return ExperienceType.fullTime;
    }
    if (l == 'part-time' || l == 'parttime') return ExperienceType.partTime;
    if (l == 'internship' || l == 'intern')  return ExperienceType.internship;
    return ExperienceType.none;
  }

  double get yearsEquivalent {
    switch (this) {
      case ExperienceType.none:       return 0.0;
      case ExperienceType.internship: return 0.5;
      case ExperienceType.partTime:   return 1.0;
      case ExperienceType.fullTime:   return 2.0;
    }
  }

  /// Dataset-backed success-probability delta.
  double get successBoost {
    switch (this) {
      case ExperienceType.partTime:   return  0.007;
      case ExperienceType.internship: return  0.001;
      case ExperienceType.fullTime:   return -0.003;
      case ExperienceType.none:       return -0.010;
    }
  }

  /// Additive match-score boost applied in the AJJ26 cosine scorer.
  double get matchBoost {
    switch (this) {
      case ExperienceType.none:       return 0.00;
      case ExperienceType.internship: return 0.03;
      case ExperienceType.partTime:   return 0.05;
      case ExperienceType.fullTime:   return 0.08;
    }
  }

  IconData get icon {
    switch (this) {
      case ExperienceType.none:       return Icons.person_outline_rounded;
      case ExperienceType.internship: return Icons.school_outlined;
      case ExperienceType.partTime:   return Icons.access_time_rounded;
      case ExperienceType.fullTime:   return Icons.business_center_rounded;
    }
  }
}

// =============================================================================
// WORKFORCE GENERATION  [ALA23]
// =============================================================================

/// Multi-generational workforce classification.
/// Source: Alaql et al. (2023) — Multi-generational Labour Market Analysis.
///
/// Birth-year boundaries (standard sociological definitions):
///   Gen Z         1997–2012  — digital natives, purpose-driven, remote-first
///   Millennial    1981–1996  — career-switchers, work-life balance
///   Gen X         1965–1980  — autonomous, value stability
///   Baby Boomer   1946–1964  — mentoring, traditional roles
enum WorkforceGeneration {
  genZ,
  millennial,
  genX,
  babyBoomer;

  String get label {
    switch (this) {
      case WorkforceGeneration.genZ:       return 'Gen Z';
      case WorkforceGeneration.millennial: return 'Millennial';
      case WorkforceGeneration.genX:       return 'Gen X';
      case WorkforceGeneration.babyBoomer: return 'Baby Boomer';
    }
  }

  String get key => name;

  String get yearRange {
    switch (this) {
      case WorkforceGeneration.genZ:       return '1997–2012';
      case WorkforceGeneration.millennial: return '1981–1996';
      case WorkforceGeneration.genX:       return '1965–1980';
      case WorkforceGeneration.babyBoomer: return '1946–1964';
    }
  }

  /// Characteristic work preferences (Alaql et al. 2023 — LDA topic findings).
  String get workPreference {
    switch (this) {
      case WorkforceGeneration.genZ:
        return 'Remote-first, purpose-driven, tech-enabled, entrepreneurial';
      case WorkforceGeneration.millennial:
        return 'Work-life balance, career development, collaborative culture';
      case WorkforceGeneration.genX:
        return 'Autonomy, stability, results-oriented, cross-functional skills';
      case WorkforceGeneration.babyBoomer:
        return 'Mentoring, traditional roles, institutional loyalty, face-to-face';
    }
  }

  List<String> get preferredJobCategories {
    switch (this) {
      case WorkforceGeneration.genZ:
        return ['Software', 'Marketing', 'Education', 'Healthcare'];
      case WorkforceGeneration.millennial:
        return ['Software', 'Finance', 'Marketing', 'Healthcare'];
      case WorkforceGeneration.genX:
        return ['Finance', 'Manufacturing', 'Software', 'Healthcare'];
      case WorkforceGeneration.babyBoomer:
        return ['Healthcare', 'Education', 'Finance', 'Manufacturing'];
    }
  }

  Color get color {
    switch (this) {
      case WorkforceGeneration.genZ:       return const Color(0xFF6A1B9A);
      case WorkforceGeneration.millennial: return const Color(0xFF1565C0);
      case WorkforceGeneration.genX:       return const Color(0xFF2E7D32);
      case WorkforceGeneration.babyBoomer: return const Color(0xFFE65100);
    }
  }

  IconData get icon {
    switch (this) {
      case WorkforceGeneration.genZ:       return Icons.phone_android_rounded;
      case WorkforceGeneration.millennial: return Icons.laptop_rounded;
      case WorkforceGeneration.genX:       return Icons.business_center_rounded;
      case WorkforceGeneration.babyBoomer: return Icons.account_balance_rounded;
    }
  }

  static WorkforceGeneration fromBirthYear(int year) {
    if (year >= 1997) return WorkforceGeneration.genZ;
    if (year >= 1981) return WorkforceGeneration.millennial;
    if (year >= 1965) return WorkforceGeneration.genX;
    return WorkforceGeneration.babyBoomer;
  }

  static WorkforceGeneration fromKey(String key) =>
      WorkforceGeneration.values.firstWhere(
            (e) => e.name == key.trim(),
        orElse: () => WorkforceGeneration.millennial,
      );
}

// =============================================================================
// CAREER CONFIDENCE CATEGORY  [XZ25]
// =============================================================================

/// Five confidence dimensions from Xiao & Zheng (2025) — ChatGPT & Employment
/// Confidence.  Each scored 1.0–5.0 (1 = not confident, 5 = extremely).
enum CareerConfidenceCategory {
  technicalSkills,
  communication,
  jobSearch,
  interview,
  salaryNegotiation;

  String get label {
    switch (this) {
      case CareerConfidenceCategory.technicalSkills:   return 'Technical Skills';
      case CareerConfidenceCategory.communication:     return 'Communication';
      case CareerConfidenceCategory.jobSearch:         return 'Job Search';
      case CareerConfidenceCategory.interview:         return 'Interview';
      case CareerConfidenceCategory.salaryNegotiation: return 'Salary Negotiation';
    }
  }

  String get key => name;

  String get boostTip {
    switch (this) {
      case CareerConfidenceCategory.technicalSkills:
        return 'Complete one skill-specific course or project this week to '
            'reinforce your technical foundation.';
      case CareerConfidenceCategory.communication:
        return 'Practice the STAR method for behavioural questions and record '
            'a 2-minute self-introduction video.';
      case CareerConfidenceCategory.jobSearch:
        return 'Set daily application targets and use keyword-optimised '
            'résumés tailored to each role.';
      case CareerConfidenceCategory.interview:
        return 'Run 3 mock interviews this week — even self-recorded ones '
            'measurably improve performance.';
      case CareerConfidenceCategory.salaryNegotiation:
        return 'Research salary benchmarks for your target role and practise '
            'counter-offer scripts out loud.';
    }
  }

  IconData get icon {
    switch (this) {
      case CareerConfidenceCategory.technicalSkills:
        return Icons.code_rounded;
      case CareerConfidenceCategory.communication:
        return Icons.record_voice_over_rounded;
      case CareerConfidenceCategory.jobSearch:
        return Icons.search_rounded;
      case CareerConfidenceCategory.interview:
        return Icons.people_outlined;
      case CareerConfidenceCategory.salaryNegotiation:
        return Icons.attach_money_rounded;
    }
  }

  Color get color {
    switch (this) {
      case CareerConfidenceCategory.technicalSkills:
        return const Color(0xFF1565C0);
      case CareerConfidenceCategory.communication:
        return const Color(0xFF2E7D32);
      case CareerConfidenceCategory.jobSearch:
        return const Color(0xFFE65100);
      case CareerConfidenceCategory.interview:
        return const Color(0xFF6A1B9A);
      case CareerConfidenceCategory.salaryNegotiation:
        return const Color(0xFF00695C);
    }
  }

  static CareerConfidenceCategory fromKey(String key) =>
      CareerConfidenceCategory.values.firstWhere(
            (e) => e.name == key.trim(),
        orElse: () => CareerConfidenceCategory.technicalSkills,
      );
}

// =============================================================================
// GPA TIER
// =============================================================================

enum GpaTier {
  distinction, // ≥ 3.7
  merit,       // ≥ 3.3
  pass,        // ≥ 2.7
  developing;  // < 2.7

  String get label {
    switch (this) {
      case GpaTier.distinction: return 'Distinction';
      case GpaTier.merit:       return 'Merit';
      case GpaTier.pass:        return 'Pass';
      case GpaTier.developing:  return 'Developing';
    }
  }

  Color get color {
    switch (this) {
      case GpaTier.distinction: return const Color(0xFF1565C0);
      case GpaTier.merit:       return const Color(0xFF2E7D32);
      case GpaTier.pass:        return const Color(0xFFE65100);
      case GpaTier.developing:  return const Color(0xFF757575);
    }
  }

  IconData get icon {
    switch (this) {
      case GpaTier.distinction: return Icons.star_rounded;
      case GpaTier.merit:       return Icons.star_half_rounded;
      case GpaTier.pass:        return Icons.check_circle_outline_rounded;
      case GpaTier.developing:  return Icons.trending_up_rounded;
    }
  }

  String get advice {
    switch (this) {
      case GpaTier.distinction:
        return 'Dataset insight: GPA ≥3.5 has the highest self-employment '
            'rate (40%) but the lowest formal employment rate (27%). '
            'Build a portfolio alongside your grades.';
      case GpaTier.merit:
        return 'Your GPA range (3.0–3.5) has the highest formal employment '
            'rate in our dataset (34%). Complement with projects and '
            'certifications to maintain that edge.';
      case GpaTier.pass:
        return 'GPA 2.5–3.0 has a 33% employment rate — only 1 pp behind '
            'the highest band. Practical skills and experience matter '
            'more than GPA alone.';
      case GpaTier.developing:
        return 'Dataset: GPA <2.5 still achieves 30% formal employment. '
            'Internships, certifications, and projects compensate '
            'significantly for lower grades.';
    }
  }

  static GpaTier fromGpa(double gpa) {
    if (gpa >= 3.7) return GpaTier.distinction;
    if (gpa >= 3.3) return GpaTier.merit;
    if (gpa >= 2.7) return GpaTier.pass;
    return GpaTier.developing;
  }
}

// =============================================================================
// POST-GRAD STATS
// =============================================================================

@immutable
class PostGradStats {
  final double employed;
  final double selfEmployed;
  final double unemployed;

  const PostGradStats({
    required this.employed,
    required this.selfEmployed,
    required this.unemployed,
  });

  /// Overall dataset average (career_guidance_dataset.csv, n=1000).
  static const PostGradStats overall = PostGradStats(
    employed:     0.311,
    selfEmployed: 0.343,
    unemployed:   0.346,
  );

  String get summary =>
      'Employed ${(employed * 100).round()}% · '
          'Self-employed ${(selfEmployed * 100).round()}% · '
          'Unemployed ${(unemployed * 100).round()}%';

  Map<String, double> toMap() => {
    'employed':     employed,
    'selfEmployed': selfEmployed,
    'unemployed':   unemployed,
  };

  factory PostGradStats.fromMap(Map<String, dynamic> map) => PostGradStats(
    employed:     (map['employed']     as num? ?? 0.0).toDouble(),
    selfEmployed: (map['selfEmployed'] as num? ?? 0.0).toDouble(),
    unemployed:   (map['unemployed']   as num? ?? 0.0).toDouble(),
  );
}

// =============================================================================
// WEIGHTED SKILL  (P-J Fit scoring)  [ZC22 §3, AJJ26 §4]
// =============================================================================

/// A skill paired with an importance weight (1.0 = required, 0.5 = nice-to-have).
@immutable
class WeightedSkill {
  final String skill;
  final double weight; // 0.0–1.0

  const WeightedSkill({required this.skill, this.weight = 1.0});

  String get normalised => skill.trim().toLowerCase();

  Map<String, dynamic> toMap() => {'skill': skill, 'weight': weight};

  factory WeightedSkill.fromMap(Map<String, dynamic> m) => WeightedSkill(
    skill:  (m['skill']  as String? ?? '').trim(),
    weight: (m['weight'] as num?   ?? 1.0).toDouble().clamp(0.0, 1.0),
  );

  @override
  bool operator ==(Object other) =>
      other is WeightedSkill && other.normalised == normalised;

  @override
  int get hashCode => normalised.hashCode;
}

// =============================================================================
// CAREER PROFILE  (main model)
// =============================================================================

@immutable
class CareerProfile {
  // ── Core profile ─────────────────────────────────────────
  final String       name;
  final FieldOfStudy fieldOfStudy;

  /// 1–5. Dataset max is Year 5.
  final int yearOfStudy;

  /// 0.0–4.0. Dataset range 2.00–4.00 (mean 2.978). 0.0 = sentinel (not set).
  final double gpa;

  final ExperienceType            employmentType;
  final bool                      hasEntrepreneurialExperience;
  final List<String>              careerInterests;
  final List<String>              skills;
  final EntrepreneurialAspiration entrepreneurialAspiration;

  // ── [ALA23] Generation ───────────────────────────────────
  /// Birth year for workforce-generation classification. Null = not provided.
  final int? birthYear;

  // ── [DAW21] Transition ───────────────────────────────────
  /// Target job title the user wants to transition into.
  final String targetJobTitle;

  // ── [ZC22] Person-Organisation fit ───────────────────────
  /// Values the user wants in an organisation.
  /// Compared via Jaccard similarity with job-posting values.
  final List<String> preferredOrgValues;

  // ── [XZ25] Confidence ────────────────────────────────────
  /// Confidence scores keyed by [CareerConfidenceCategory.key] (1.0–5.0).
  final Map<String, double> confidenceScores;

  // ── [LH22] Intention ─────────────────────────────────────
  /// Current stated employment intention.
  /// Values mirror EmploymentIntention enum keys:
  ///   'studyAbroad' | 'furtherEducation' | 'employment' | 'undecided'
  final String employmentIntention;

  // ── [AJJ26] CV text ──────────────────────────────────────
  /// Raw CV text extracted from uploaded document. Used in TF-IDF matching.
  final String cvText;

  // ── Constructor ───────────────────────────────────────────
  const CareerProfile({
    required this.name,
    required this.fieldOfStudy,
    required this.yearOfStudy,
    required this.gpa,
    required this.employmentType,
    this.hasEntrepreneurialExperience = false,
    this.careerInterests              = const [],
    this.skills                       = const [],
    this.entrepreneurialAspiration    = EntrepreneurialAspiration.low,
    this.birthYear,
    this.targetJobTitle      = '',
    this.preferredOrgValues  = const [],
    this.confidenceScores    = const {},
    this.employmentIntention = 'undecided',
    this.cvText              = '',
  });

  // ── Factory — validated construction ─────────────────────
  /// Use this factory when building a profile from user-provided data.
  /// Applies normalisation, deduplication, and clamping automatically.
  factory CareerProfile.build({
    required String         name,
    required FieldOfStudy   fieldOfStudy,
    required int            yearOfStudy,
    required double         gpa,
    required ExperienceType employmentType,
    bool                       hasEntrepreneurialExperience = false,
    List<String>               careerInterests              = const [],
    List<String>               skills                       = const [],
    EntrepreneurialAspiration  entrepreneurialAspiration    =
        EntrepreneurialAspiration.low,
    int?                birthYear,
    String              targetJobTitle      = '',
    List<String>        preferredOrgValues  = const [],
    Map<String, double> confidenceScores    = const {},
    String              employmentIntention = 'undecided',
    String              cvText              = '',
  }) {
    // Normalise skills: lowercase, trimmed, unique
    final normSkills = skills
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();

    // Normalise interests: trimmed, unique, non-empty
    final normInterests = careerInterests
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();

    // Normalise org values: lowercase, trimmed, unique
    final normValues = preferredOrgValues
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();

    // Clamp confidence scores to 1.0–5.0 range
    final normConf =
    confidenceScores.map((k, v) => MapEntry(k, v.clamp(1.0, 5.0)));

    return CareerProfile(
      name:                        name.trim(),
      fieldOfStudy:                fieldOfStudy,
      yearOfStudy:                 yearOfStudy.clamp(1, 5),
      gpa:                         gpa.clamp(0.0, 4.0),
      employmentType:              employmentType,
      hasEntrepreneurialExperience: hasEntrepreneurialExperience,
      careerInterests:             normInterests,
      skills:                      normSkills,
      entrepreneurialAspiration:   entrepreneurialAspiration,
      birthYear:                   birthYear,
      targetJobTitle:              targetJobTitle.trim(),
      preferredOrgValues:          normValues,
      confidenceScores:            normConf,
      employmentIntention:         employmentIntention.trim(),
      cvText:                      cvText.trim(),
    );
  }

  // ── Empty / sentinel ──────────────────────────────────────
  factory CareerProfile.empty() => const CareerProfile(
    name:           '',
    fieldOfStudy:   FieldOfStudy.other,
    yearOfStudy:    1,
    gpa:            0.0,
    employmentType: ExperienceType.none,
  );

  bool get isEmpty  => name.isEmpty && gpa == 0.0 && skills.isEmpty;

  bool get isComplete =>
      name.isNotEmpty &&
          gpa > 0.0 &&
          skills.isNotEmpty &&
          careerInterests.isNotEmpty;

  // ── Field delegates ───────────────────────────────────────
  String       get fieldLabel            => fieldOfStudy.label;
  String       get experienceLabel       => employmentType.label;
  double       get experienceYears       => employmentType.yearsEquivalent;
  List<String> get recommendedIndustries => fieldOfStudy.recommendedIndustries;

  // ── GPA helpers ───────────────────────────────────────────
  GpaTier get gpaTier           => GpaTier.fromGpa(gpa);
  bool    get gpaInDatasetRange => gpa >= 2.0 && gpa <= 4.0;

  // ── Career path helpers ───────────────────────────────────
  CareerPath get primaryCareerPath {
    for (final interest in careerInterests) {
      final path = CareerPath.fromLabel(interest);
      if (path != CareerPath.other) return path;
    }
    return CareerPath.other;
  }

  bool get interestPathAligned =>
      careerInterests.any((i) => CareerPath.fromLabel(i) != CareerPath.other);

  // ── Post-grad stats ───────────────────────────────────────
  PostGradStats? get postGradStats        => fieldOfStudy.postGradStats;
  PostGradStats  get overallPostGradStats => PostGradStats.overall;

  // ── Missing core skills ───────────────────────────────────
  /// Returns core skills for this field that are absent from the user profile.
  /// Comparison is already lowercase on both sides — no redundant transform.
  List<String> get missingCoreSkills {
    final userNorm = skills.toSet(); // already lowercase from CareerProfile.build
    return fieldOfStudy.coreSkills   // already lowercase from FieldOfStudy getter
        .where((s) => !userNorm.contains(s))
        .toList();
  }

  bool isRecommendedIndustry(String industry) =>
      recommendedIndustries
          .any((i) => i.toLowerCase() == industry.toLowerCase());

  // ── [ALA23] Workforce generation ──────────────────────────
  WorkforceGeneration? get workforceGeneration =>
      birthYear != null ? WorkforceGeneration.fromBirthYear(birthYear!) : null;

  int? get age =>
      birthYear != null ? DateTime.now().year - birthYear! : null;

  List<String> get generationPreferredCategories =>
      workforceGeneration?.preferredJobCategories ?? [];

  // ─────────────────────────────────────────────────────────
  // SUCCESS PROBABILITY  (all weights from dataset, n=1000)
  // ─────────────────────────────────────────────────────────
  double get successProbability {
    var p = 0.504; // overall dataset mean

    p += employmentType.successBoost;
    p += entrepreneurialAspiration.successBoost;
    if (interestPathAligned)        p += 0.023;
    p += primaryCareerPath.successBoost;
    p += (yearOfStudy - 1) * 0.002;
    if (hasEntrepreneurialExperience) p += 0.007;
    if (gpa >= 3.8)                   p += 0.010;

    return p.clamp(0.0, 0.95);
  }

  String get successLabel {
    final p = successProbability;
    if (p >= 0.58) return 'High';
    if (p >= 0.53) return 'Good';
    if (p >= 0.50) return 'Moderate';
    return 'Building';
  }

  String get successAdvice {
    final p = successProbability;
    if (p >= 0.58) {
      return 'Strong profile — follow career recommendations '
          '(dataset: +0.5 pp success for followers).';
    }
    if (p >= 0.53) {
      return 'Good foundation. Raise aspiration to High: '
          'dataset shows +3.75 pp success vs Low.';
    }
    if (p >= 0.50) {
      return 'Part-time experience is the strongest single signal — '
          'seek one now.';
    }
    return 'Any work experience (even an internship) has the largest '
        'dataset-backed impact on your success probability.';
  }

  // ─────────────────────────────────────────────────────────
  // [XZ25] CAREER CONFIDENCE
  // ─────────────────────────────────────────────────────────

  /// Average confidence score across all rated categories (0.0 if none rated).
  double get overallConfidenceScore {
    if (confidenceScores.isEmpty) return 0.0;
    final sum = confidenceScores.values.fold(0.0, (a, b) => a + b);
    return (sum / confidenceScores.length).clamp(0.0, 5.0);
  }

  /// Normalised 0.0–1.0 for gauge widgets.
  double get normalizedConfidenceScore =>
      (overallConfidenceScore / 5.0).clamp(0.0, 1.0);

  String get confidenceLabel {
    final s = overallConfidenceScore;
    if (s >= 4.0) return 'Excellent';
    if (s >= 3.0) return 'Good';
    if (s >= 2.0) return 'Developing';
    return 'Needs Support';
  }

  bool get isConfident => overallConfidenceScore >= 3.5;

  /// Category with the lowest confidence score (null if none rated).
  CareerConfidenceCategory? get weakestConfidenceCategory {
    if (confidenceScores.isEmpty) return null;
    String? lowestKey;
    var lowestVal = double.infinity;
    for (final e in confidenceScores.entries) {
      if (e.value < lowestVal) {
        lowestVal = e.value;
        lowestKey = e.key;
      }
    }
    return lowestKey != null
        ? CareerConfidenceCategory.fromKey(lowestKey)
        : null;
  }

  /// Category with the highest confidence score (null if none rated).
  CareerConfidenceCategory? get strongestConfidenceCategory {
    if (confidenceScores.isEmpty) return null;
    String? highestKey;
    var highestVal = double.negativeInfinity;
    for (final e in confidenceScores.entries) {
      if (e.value > highestVal) {
        highestVal = e.value;
        highestKey = e.key;
      }
    }
    return highestKey != null
        ? CareerConfidenceCategory.fromKey(highestKey)
        : null;
  }

  double confidenceScoreFor(CareerConfidenceCategory cat) =>
      confidenceScores[cat.key] ?? 0.0;

  // ─────────────────────────────────────────────────────────
  // [ZC22] PERSON-JOB FIT
  // ─────────────────────────────────────────────────────────

  /// Weighted P-J Fit score (0.0–1.0).  [ZC22 §3 + AJJ26 §4]
  ///
  /// Each entry in [weightedJobSkills] carries an importance weight
  /// (1.0 = required, lower = nice-to-have). Matching a required skill
  /// contributes proportionally more to the final score than a
  /// nice-to-have skill.
  ///
  /// Formula:
  ///   score = Σ(weight_i × match_i) / Σ(weight_i)
  double pjFitScore(List<WeightedSkill> weightedJobSkills) {
    if (skills.isEmpty || weightedJobSkills.isEmpty) return 0.0;
    final userSet    = skills.toSet(); // already normalised
    var totalWeight  = 0.0;
    var matchWeight  = 0.0;
    for (final ws in weightedJobSkills) {
      totalWeight += ws.weight;
      if (userSet.contains(ws.normalised)) matchWeight += ws.weight;
    }
    if (totalWeight == 0) return 0.0;
    return (matchWeight / totalWeight).clamp(0.0, 1.0);
  }

  /// Convenience overload: unweighted list (all skills weight = 1.0).
  double pjFitScoreSimple(List<String> jobSkills) {
    if (skills.isEmpty || jobSkills.isEmpty) return 0.0;
    final userSet = skills.toSet(); // already normalised
    final matched = jobSkills
        .where((s) => userSet.contains(s.toLowerCase().trim()))
        .length;
    return (matched / jobSkills.length).clamp(0.0, 1.0);
  }

  String pjFitLabel(List<WeightedSkill> weightedJobSkills) {
    final s = pjFitScore(weightedJobSkills);
    if (s >= 0.75) return 'Strong Fit';
    if (s >= 0.50) return 'Good Fit';
    if (s >= 0.30) return 'Partial Fit';
    return 'Skill Gap';
  }

  // ─────────────────────────────────────────────────────────
  // [ZC22] PERSON-ORGANISATION FIT
  // ─────────────────────────────────────────────────────────

  /// Jaccard similarity between user's org-value preferences and job-posting
  /// values (0.0–1.0).  [ZC22 §3]
  double poFitScore(List<String> orgValues) {
    if (preferredOrgValues.isEmpty || orgValues.isEmpty) return 0.0;
    final userSet   = preferredOrgValues.toSet(); // already normalised
    final orgSet    = orgValues.map((v) => v.toLowerCase().trim()).toSet();
    final intersect = userSet.intersection(orgSet).length;
    final union     = userSet.union(orgSet).length;
    if (union == 0) return 0.0;
    return (intersect / union).clamp(0.0, 1.0);
  }

  String poFitLabel(List<String> orgValues) {
    final s = poFitScore(orgValues);
    if (s >= 0.60) return 'High Alignment';
    if (s >= 0.35) return 'Moderate Alignment';
    if (s >= 0.15) return 'Some Alignment';
    return 'Low Alignment';
  }

  // ─────────────────────────────────────────────────────────
  // [DAW21] TRANSITION READINESS
  // ─────────────────────────────────────────────────────────

  /// Readiness score (0.0–1.0) for transitioning into a target role defined
  /// by [targetRoleSkills].  Based on the Dawson et al. (2021) skill-gap
  /// framework: P-J Fit × experience boost × confidence normalised.
  ///
  /// Components:
  ///   • Weighted P-J Fit (skills coverage)    — 60%
  ///   • Experience type boost                 — 20%
  ///   • Normalised overall confidence [XZ25]  — 20%
  double transitionReadinessScore(List<WeightedSkill> targetRoleSkills) {
    final fit      = pjFitScore(targetRoleSkills);
    final expBoost = (employmentType.matchBoost / 0.08).clamp(0.0, 1.0);
    final conf     = normalizedConfidenceScore;
    return ((fit * 0.6) + (expBoost * 0.2) + (conf * 0.2)).clamp(0.0, 1.0);
  }

  String transitionReadinessLabel(List<WeightedSkill> targetRoleSkills) {
    final s = transitionReadinessScore(targetRoleSkills);
    if (s >= 0.75) return 'Ready';
    if (s >= 0.50) return 'Almost Ready';
    if (s >= 0.30) return 'Building Towards';
    return 'Early Stage';
  }

  // ─────────────────────────────────────────────────────────
  // [ALS22 §1] SDG-8 ALIGNMENT SCORE
  // ─────────────────────────────────────────────────────────

  /// 0.0–1.0 indicator of how well this profile aligns with SDG-8
  /// (Decent Work & Economic Growth) based on field, aspiration, and skills.
  ///
  /// Heuristic components:
  ///   • SDG-8 priority field of study    → 0.35
  ///   • High entrepreneurial aspiration  → 0.25
  ///   • At least 3 market-ready skills   → 0.20
  ///   • Any work experience              → 0.20
  double get sdg8AlignmentScore {
    var score = 0.0;

    const sdg8Fields = {
      FieldOfStudy.finance,
      FieldOfStudy.business,
      FieldOfStudy.it,
      FieldOfStudy.engineering,
      FieldOfStudy.marketing,
    };
    if (sdg8Fields.contains(fieldOfStudy)) score += 0.35;

    switch (entrepreneurialAspiration) {
      case EntrepreneurialAspiration.high:
        score += 0.25;
        break;
      case EntrepreneurialAspiration.medium:
        score += 0.12;
        break;
      case EntrepreneurialAspiration.low:
        break;
    }

    if (skills.length >= 5) {
      score += 0.20;
    } else if (skills.length >= 3) {
      score += 0.10;
    }

    if (employmentType != ExperienceType.none) score += 0.20;

    return score.clamp(0.0, 1.0);
  }

  // ─────────────────────────────────────────────────────────
  // [TAV22 §3.5.1] LEARNER FEATURE VECTOR
  // ─────────────────────────────────────────────────────────

  /// Extracts a TAV22-compatible content-format preference vector from the
  /// profile's field of study and experience type.  Used as the cold-start
  /// vector before the user provides explicit feedback.
  ///
  /// Keys align with [PreferenceKeys.allKeys] (defined in app_state.dart).
  /// Note: per-axis values are relative weights, not probabilities — they do
  /// not need to sum to 1.0; the TAV22 scorer normalises them internally.
  Map<String, double> get learnerColdStartVector => {
    // Length preference — technical fields skew towards longer content
    'length_short':  fieldOfStudy.learningDomainWeight < 0.7 ? 0.50 : 0.25,
    'length_medium': 0.40,
    'length_long':   fieldOfStudy.learningDomainWeight >= 0.8 ? 0.35 : 0.25,
    // Detail — senior learners prefer higher detail
    'detail_low':    yearOfStudy <= 2 ? 0.40 : 0.20,
    'detail_medium': 0.40,
    'detail_high':   yearOfStudy >= 4 ? 0.40 : 0.20,
    // Strategy — engineering favours examples, arts favours theory
    'strategy_theory':
    fieldOfStudy == FieldOfStudy.arts ? 0.40 : 0.30,
    'strategy_example':
    (fieldOfStudy == FieldOfStudy.engineering ||
        fieldOfStudy == FieldOfStudy.it)
        ? 0.45
        : 0.35,
    'strategy_both': 0.35,
    // Classroom preference — working learners prefer async
    'class_based':     employmentType == ExperienceType.none ? 0.55 : 0.35,
    'non_class_based': employmentType != ExperienceType.none ? 0.65 : 0.45,
    // Content format
    'format_video':    0.40,
    'format_book':     fieldOfStudy == FieldOfStudy.law ? 0.50 : 0.25,
    'format_web_page': 0.25,
    'format_slide':    0.25,
  };

  // ─────────────────────────────────────────────────────────
  // copyWith
  // ─────────────────────────────────────────────────────────

  CareerProfile copyWith({
    String?                    name,
    FieldOfStudy?              fieldOfStudy,
    int?                       yearOfStudy,
    double?                    gpa,
    ExperienceType?            employmentType,
    bool?                      hasEntrepreneurialExperience,
    List<String>?              careerInterests,
    List<String>?              skills,
    EntrepreneurialAspiration? entrepreneurialAspiration,
    int?                       birthYear,
    String?                    targetJobTitle,
    List<String>?              preferredOrgValues,
    Map<String, double>?       confidenceScores,
    String?                    employmentIntention,
    String?                    cvText,
    bool                       clearBirthYear = false,
  }) =>
      CareerProfile(
        name:         name         ?? this.name,
        fieldOfStudy: fieldOfStudy ?? this.fieldOfStudy,
        // Explicit toInt()/toDouble() to avoid num widening on older SDKs.
        yearOfStudy:  ((yearOfStudy ?? this.yearOfStudy).clamp(1, 5))
            .toInt(),
        gpa:          ((gpa ?? this.gpa).clamp(0.0, 4.0)).toDouble(),
        employmentType: employmentType ?? this.employmentType,
        hasEntrepreneurialExperience:
        hasEntrepreneurialExperience ?? this.hasEntrepreneurialExperience,
        careerInterests:
        careerInterests ?? List<String>.from(this.careerInterests),
        skills:
        skills ?? List<String>.from(this.skills),
        entrepreneurialAspiration:
        entrepreneurialAspiration ?? this.entrepreneurialAspiration,
        birthYear: clearBirthYear ? null : (birthYear ?? this.birthYear),
        targetJobTitle:
        targetJobTitle ?? this.targetJobTitle,
        preferredOrgValues:
        preferredOrgValues ?? List<String>.from(this.preferredOrgValues),
        confidenceScores:
        confidenceScores ?? Map<String, double>.from(this.confidenceScores),
        employmentIntention:
        employmentIntention ?? this.employmentIntention,
        cvText: cvText ?? this.cvText,
      );

  // ─────────────────────────────────────────────────────────
  // Serialisation
  // ─────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
    'name':                         name,
    'fieldOfStudy':                 fieldOfStudy.key,
    'yearOfStudy':                  yearOfStudy,
    'gpa':                          gpa,
    'employmentType':               employmentType.key,
    'hasEntrepreneurialExperience': hasEntrepreneurialExperience,
    'careerInterests':              careerInterests,
    'skills':                       skills,
    'entrepreneurialAspiration':    entrepreneurialAspiration.key,
    'birthYear':                    birthYear,
    'targetJobTitle':               targetJobTitle,
    'preferredOrgValues':           preferredOrgValues,
    'confidenceScores':             confidenceScores,
    'employmentIntention':          employmentIntention,
    'cvText':                       cvText,
  };

  factory CareerProfile.fromMap(Map<String, dynamic> map) => CareerProfile(
    name:         (map['name'] as String? ?? '').trim(),
    fieldOfStudy: FieldOfStudy.fromKey(
        map['fieldOfStudy'] as String? ?? ''),
    yearOfStudy:  (map['yearOfStudy'] as int? ?? 1).clamp(1, 5),
    gpa: (map['gpa'] as num? ?? 0.0).toDouble().clamp(0.0, 4.0),
    employmentType: ExperienceType.fromKey(
        map['employmentType'] as String? ?? ''),
    hasEntrepreneurialExperience:
    map['hasEntrepreneurialExperience'] as bool? ?? false,
    careerInterests: List<String>.from(
        map['careerInterests'] as List? ?? const []),
    skills: List<String>.from(
        map['skills'] as List? ?? const []),
    // FIX: use fromKey() — toMap() stores the enum key (name), not the label.
    entrepreneurialAspiration: EntrepreneurialAspiration.fromKey(
        map['entrepreneurialAspiration'] as String? ?? 'low'),
    birthYear:      map['birthYear'] as int?,
    targetJobTitle: (map['targetJobTitle'] as String? ?? '').trim(),
    preferredOrgValues: List<String>.from(
        map['preferredOrgValues'] as List? ?? const []),
    confidenceScores: _parseDoubleMap(map['confidenceScores']),
    employmentIntention:
    (map['employmentIntention'] as String? ?? 'undecided').trim(),
    cvText: (map['cvText'] as String? ?? '').trim(),
  );

  factory CareerProfile.fromJson(Map<String, dynamic> json) =>
      CareerProfile.fromMap(json);

  Map<String, dynamic> toJson() => toMap();

  // ─────────────────────────────────────────────────────────
  // Equality & hashing
  // ─────────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          (other is CareerProfile &&
              other.name == name &&
              other.fieldOfStudy == fieldOfStudy &&
              other.gpa == gpa &&
              other.employmentType == employmentType &&
              other.yearOfStudy == yearOfStudy &&
              other.entrepreneurialAspiration == entrepreneurialAspiration);

  @override
  int get hashCode => Object.hash(
    name,
    fieldOfStudy,
    gpa,
    employmentType,
    yearOfStudy,
    entrepreneurialAspiration,
  );

  @override
  String toString() => 'CareerProfile('
      'name: $name, '
      'field: ${fieldOfStudy.label}, '
      'year: $yearOfStudy, '
      'gpa: $gpa, '
      'exp: ${employmentType.label}, '
      'aspiration: ${entrepreneurialAspiration.label}, '
      'generation: ${workforceGeneration?.label ?? "unknown"}, '
      'confidence: ${overallConfidenceScore.toStringAsFixed(1)}/5, '
      'success: ${(successProbability * 100).toStringAsFixed(1)}%, '
      'sdg8: ${(sdg8AlignmentScore * 100).toStringAsFixed(0)}%)';

  factory CareerProfile.fromPredictionResult(PredictionResult result) {
    final topJob = result.jobs.isNotEmpty ? result.jobs.first : null;

    // Map confidence list → CareerConfidenceCategory scores (backend returns
    // raw 0.0–1.0 values; scale to the 1.0–5.0 range CareerProfile expects).
    final confidenceScores = <String, double>{};
    for (var i = 0; i < result.confidence.length; i++) {
      if (i >= CareerConfidenceCategory.values.length) break;
      final cat   = CareerConfidenceCategory.values[i];
      final score = (result.confidence[i] * 5.0).clamp(1.0, 5.0);
      confidenceScores[cat.key] = score;
    }

    // Derive the career path from the top job's industry field, falling back
    // to the job title itself so CareerPath.fromLabel still finds a match.
    final industryHint = topJob?.industry ?? topJob?.title ?? '';

    return CareerProfile.build(
      name:                '',
      fieldOfStudy:        FieldOfStudy.other,
      yearOfStudy:         1,
      gpa:                 0.0,
      employmentType:      ExperienceType.none,
      // Populate interests from every predicted job title — drives
      // primaryCareerPath, interestPathAligned, and successProbability.
      careerInterests:     result.jobs.map((j) => j.title).toList(),
      // Skills gap returned by the backend becomes the user's skill list so
      // missingCoreSkills and pjFitScore reflect the backend analysis.
      skills:              result.skillsGap,
      targetJobTitle:      topJob?.title ?? '',
      confidenceScores:    confidenceScores,
      entrepreneurialAspiration: EntrepreneurialAspiration.fromLabel(
        industryHint.toLowerCase().contains('finance') ? 'high' : 'medium',
      ),
    );
  }
}

// =============================================================================
// PRIVATE HELPERS
// =============================================================================

/// Safely converts a dynamic value (from JSON / SharedPreferences) to
/// [Map<String, double>].  Returns a new empty growable map on failure so
/// callers can safely add entries without hitting an unmodifiable-map error.
Map<String, double> _parseDoubleMap(dynamic raw) {
  if (raw == null) return {};
  if (raw is Map<String, double>) return Map<String, double>.from(raw);
  try {
    return Map<String, double>.fromEntries(
      (raw as Map).entries.map(
            (e) => MapEntry(
          e.key.toString(),
          (e.value as num).toDouble(),
        ),
      ),
    );
  } catch (_) {
    return {};
  }
}