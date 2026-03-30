// lib/data/career_guidance_data.dart — SkillBridge AI
// ══════════════════════════════════════════════════════════════════════════════
//
//  App      : SkillBridge AI – Job & Skill Recommendation App
//  Tagline  : Smart jobs, smart skills, better future
//  SDG      : United Nations SDG 8 – Decent Work and Economic Growth
//  Team     : Arafat Sakib · Daffodil International University
//
//  Data sources (verified from CSV analysis):
//   [CGD]  career_guidance_dataset.csv   – 1,000 student records
//          Fields: GPA, Field_of_Study, Career_Interests,
//                  Recommended_Career_Path, Predicted_Job_Success_Probability,
//                  Top_Recommended_Industries, Employment_Status_Post_Graduation
//          Path distribution: Tech 207, Finance 209, Business 197,
//                             Healthcare 192, Design 195
//   [JRD]  job_recommendation_dataset.csv – 50,000 job postings
//          Fields: Job Title, Industry, Experience Level, Salary,
//                  Required Skills
//          Industries: Software 7302, Marketing 7158, Manufacturing 7169,
//                      Retail 7106, Education 7144, Healthcare 7104, Finance 7017
//          Salary range: $94k–$96k / yr mean (all industries / levels)
//   [JFE]  JobsFE.csv – 10,000 job listings
//          Fields: position, working_mode, salary, requisite_skill,
//                  job_role_and_duties, offer_details
//          Salary range: $67,500–$97,500 (mean $82,546)
//          Working modes: full-time 2031, temporary 2023, contract 2009,
//                         part-time 1983, intern 1954
//
//  Research grounding (v4.0 — full 8-paper integration):
//   [Ajjam26] Ajjam & Al-Raweshidy (2026) — TF-IDF + cosine semantic job
//             matching, greedy one-to-one, cross-domain transfer, bias audit
//   [ALS22]   Alsaif et al. (2022) MDPI Computers 11 — Weighted cosine-
//             similarity job recommender; Jaccard coefficient, precision/recall
//   [TAV22]   Tavakoli et al. (2022) Adv. Eng. Informatics 52 — eDoer
//             adaptive OER recommender; learner preference vectors, LMI skill
//             extraction, curriculum sequencing
//   [Dawson21] Dawson et al. (2021) — SKILLS SPACE; RCA-based skill importance,
//              θ skill co-occurrence similarity, job-transition probability
//   [Chen22]  Zhisheng Chen (2022) — AI-human recruitment collaboration; 6
//             recruitment stages, P-J fit, bias removal
//   [CGD]     career_guidance_dataset.csv statistical analysis (1,000 records)
//   [SDG8]    UN Sustainable Development Goal 8 – Decent Work & Economic Growth
//   [Alaql23] Alaql et al. (2023) — Multi-generational labour markets via ML
//   [Xiao25]  Xiao & Zheng (2025) — ChatGPT and employment confidence
//
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/foundation.dart';

// ══════════════════════════════════════════════════════════════════════════════
// §1  DOMAIN CONSTANTS
// ══════════════════════════════════════════════════════════════════════════════

// ── §1.1  Industries  [JRD — verified from 50,000 row analysis] ──────────────

/// Canonical industry identifiers drawn from [JRD] Industry column.
/// Distribution: Software 7302 | Marketing 7158 | Manufacturing 7169 |
///               Retail 7106  | Education 7144  | Healthcare 7104    |
///               Finance 7017
const List<String> kIndustries = [
  'Software',
  'Finance',
  'Healthcare',
  'Marketing',
  'Manufacturing',
  'Retail',
  'Education',
  'Design',
];

// ── §1.2  Career paths  [CGD — verified from 1,000 record analysis] ──────────

/// Career-path identifiers from Recommended_Career_Path column in [CGD].
/// Distribution: Finance 209 | Tech 207 | Design 195 | Business 197 |
///               Healthcare 192
const List<String> kCareerPaths = [
  'Tech',
  'Finance',
  'Business',
  'Healthcare',
  'Design',
];

// ── §1.3  Experience tiers  [JRD — verified from 50,000 row analysis] ─────────

/// Experience-level / tier values from [JRD] Experience Level column.
/// Distribution: Mid Level 16739 | Senior Level 16658 | Entry Level 16603
const List<String> kExperienceTiers = [
  'Student',
  'Entry Level',
  'Mid Level',
  'Senior Level',
];

// ── §1.4  Working modes  [JFE — verified from 10,000 row analysis] ────────────

/// Working mode values from [JFE] working_mode column.
/// Distribution: full-time 2031 | temporary 2023 | contract 2009 |
///               part-time 1983 | intern 1954
const List<String> kWorkingModes = [
  'full-time',
  'part-time',
  'intern',
  'contract',
  'temporary',
];

// ── §1.5  Fields of study  [CGD] ─────────────────────────────────────────────

/// Fields of study from [CGD] Field_of_Study column.
const List<String> kFieldsOfStudy = [
  'Engineering',
  'Science',
  'Business',
  'Arts',
  'Law',
];

// ── §1.6  Similarity / scoring thresholds  [Ajjam26, ALS22, TAV22] ───────────

/// Minimum cosine-similarity score (%) to surface a job recommendation.
const double kMinSimilarityThreshold = 25.0;

/// "Strong match" cosine-similarity threshold.
const double kStrongMatchThreshold = 75.0;

/// Passing quiz / skill-assessment score (%).
const int kPassingAssessmentScore = 70;

/// Top-N jobs returned by the recommender per query.
const int kTopNRecommendations = 5;

/// Average GPA baseline derived from [CGD] per-career-path means.
/// Verified: weighted mean across all 5 paths = 2.977
const double kPathAverageGpaBaseline = 3.0;

/// Max predicted job success probability in dataset.
/// Verified from [CGD]: Healthcare 52.89% is the maximum path mean.
const double kMaxPredictedSuccessProbability = 100.0;

/// Number of priority skills that push match score to ~85%.
const int kPrioritySkillGapCount = 3;

/// Maximum allowed fraction for any single industry in a recommendations list.
const double kFairnessConcentrationCeiling = 0.6;

/// Default career path used when no field-of-study mapping is found.
const String kDefaultCareerPath = 'Tech';

// ── §1.7  TF-IDF / BM25 / RCA algorithm parameters  [Ajjam26, Dawson21] ──────

/// Tier-1 TF-IDF weight floor.
const double kTfidfTier1BoostThreshold = 0.80;

/// Minimum θ (skill co-occurrence similarity) for cross-domain transfer.
const double kCrossDomainTransferMinTheta = 0.35;

/// Revealed Comparative Advantage floor.
const double kRevealedComparativeAdvantageFloor = 1.0;

/// BM25 term-saturation factor k1.
const double kBm25SaturationFactor = 1.5;

// ══════════════════════════════════════════════════════════════════════════════
// §2  DATA MODELS
// ══════════════════════════════════════════════════════════════════════════════

// ── §2.1  Job  ────────────────────────────────────────────────────────────────

@immutable
class Job {
  final String id;
  final String title;
  final String company;
  final String location;
  final String workingMode;
  final String industry;
  final String experienceLevel;
  final double salary;
  final List<String> requiredSkills;
  final String description;
  final String offerDetails;

  const Job({
    required this.id,
    required this.title,
    required this.company,
    this.location        = '',
    this.workingMode     = 'full-time',
    required this.industry,
    this.experienceLevel = 'Entry Level',
    this.salary          = 0.0,
    this.requiredSkills  = const [],
    this.description     = '',
    this.offerDetails    = '',
  });

  factory Job.fromJson(Map<String, dynamic> json) => Job(
    id:              _safeStr(json['id']),
    title:           _safeStr(json['title']),
    company:         _safeStr(json['company']),
    location:        _safeStr(json['location']),
    workingMode:     _safeStr(json['workingMode'],     fallback: 'full-time'),
    industry:        _safeStr(json['industry'],        fallback: 'Software'),
    experienceLevel: _safeStr(json['experienceLevel'], fallback: 'Entry Level'),
    salary:          (json['salary'] as num?)?.toDouble() ?? 0.0,
    requiredSkills:  _safeStrList(json['requiredSkills']),
    description:     _safeStr(json['description']),
    offerDetails:    _safeStr(json['offerDetails']),
  );

  Map<String, dynamic> toJson() => {
    'id':              id,
    'title':           title,
    'company':         company,
    'location':        location,
    'workingMode':     workingMode,
    'industry':        industry,
    'experienceLevel': experienceLevel,
    'salary':          salary,
    'requiredSkills':  requiredSkills,
    'description':     description,
    'offerDetails':    offerDetails,
  };

  bool get hasSalary => salary > 0;

  String get salaryDisplay =>
      hasSalary ? '\$${(salary / 1000).toStringAsFixed(0)}k / yr' : 'Undisclosed';

  bool get isStudentFriendly =>
      experienceLevel == 'Entry Level' || workingMode == 'intern';

  @override
  String toString() =>
      'Job("$title" @ "$company", $industry, $experienceLevel, $salaryDisplay)';
}

// ── §2.2  OpenEducationalResource  ────────────────────────────────────────────

@immutable
class OpenEducationalResource {
  final String id;
  final String targetSkill;
  final String title;
  final String platform;
  final String url;
  final String duration;
  final String difficultyLevel;
  final double contentRating;
  final bool isFreeAccess;
  final String contentFormat;

  const OpenEducationalResource({
    required this.id,
    required this.targetSkill,
    required this.title,
    required this.platform,
    this.url             = '',
    this.duration        = '',
    this.difficultyLevel = 'Beginner',
    this.contentRating   = 0.0,
    this.isFreeAccess    = true,
    this.contentFormat   = 'video',
  });

  factory OpenEducationalResource.fromJson(Map<String, dynamic> json) =>
      OpenEducationalResource(
        id:              _safeStr(json['id']),
        targetSkill:     _safeStr(json['skill']),
        title:           _safeStr(json['title']),
        platform:        _safeStr(json['platform']),
        url:             _safeStr(json['url']),
        duration:        _safeStr(json['duration']),
        difficultyLevel: _safeStr(json['level'],   fallback: 'Beginner'),
        contentRating:   (json['rating'] as num?)?.toDouble() ?? 0.0,
        isFreeAccess:    json['isFree'] as bool? ?? true,
        contentFormat:   _safeStr(json['format'],  fallback: 'video'),
      );

  Map<String, dynamic> toJson() => {
    'id':       id,
    'skill':    targetSkill,
    'title':    title,
    'platform': platform,
    'url':      url,
    'duration': duration,
    'level':    difficultyLevel,
    'rating':   contentRating,
    'isFree':   isFreeAccess,
    'format':   contentFormat,
  };

  @override
  String toString() =>
      'OpenEducationalResource("$title" — $targetSkill on $platform [$difficultyLevel])';
}

// ── §2.3  CareerInsight  ──────────────────────────────────────────────────────

@immutable
class CareerInsight {
  final String headline;
  final String detail;
  final String category;
  final String iconName;
  final String severity;

  const CareerInsight({
    required this.headline,
    required this.detail,
    this.category = 'skills',
    this.iconName = 'lightbulb_outline',
    this.severity = 'neutral',
  });

  bool get isPositive => severity == 'positive';
  bool get isWarning  => severity == 'warning';

  @override
  String toString() => 'CareerInsight("$headline" [$category/$severity])';
}

// ── §2.4  SkillGapAnalysis  ───────────────────────────────────────────────────

@immutable
class SkillGapAnalysis {
  final String targetTitle;
  final List<String> ownedSkills;
  final List<String> missingSkills;
  final double readinessPercent;
  final double projectedMatchPercent;
  final Map<String, List<OpenEducationalResource>> oersBySkill;

  const SkillGapAnalysis({
    required this.targetTitle,
    required this.ownedSkills,
    required this.missingSkills,
    required this.readinessPercent,
    required this.projectedMatchPercent,
    this.oersBySkill = const {},
  });

  int get gapCount => missingSkills.length;

  String get insightSummary {
    if (missingSkills.isEmpty) return 'You have all the required skills!';
    final top = missingSkills.take(kPrioritySkillGapCount).join(', ');
    return 'Learning $top can improve your match to '
        '${projectedMatchPercent.toStringAsFixed(0)}%.';
  }

  @override
  String toString() =>
      'SkillGapAnalysis(target: "$targetTitle", '
          'readiness: ${readinessPercent.toStringAsFixed(1)}%, '
          'gaps: $gapCount)';
}

// ── §2.5  JobMatchCandidate  ──────────────────────────────────────────────────

@immutable
class JobMatchCandidate {
  final Job job;
  final double cosineSimilarityScore;
  final List<String> matchedSkills;
  final List<String> missingSkills;
  final bool meetsPersonJobFit;

  const JobMatchCandidate({
    required this.job,
    required this.cosineSimilarityScore,
    this.matchedSkills     = const [],
    this.missingSkills     = const [],
    this.meetsPersonJobFit = false,
  });

  String get matchTierLabel {
    if (cosineSimilarityScore >= 75) return 'Strong Match';
    if (cosineSimilarityScore >= 50) return 'Good Match';
    if (cosineSimilarityScore >= 25) return 'Fair Match';
    return 'Developing';
  }

  double get normalisedScore =>
      (cosineSimilarityScore / 100.0).clamp(0.0, 1.0);

  bool get isStrongMatch => cosineSimilarityScore >= kStrongMatchThreshold;

  @override
  String toString() =>
      'JobMatchCandidate("${job.title}", score: '
          '${cosineSimilarityScore.toStringAsFixed(1)}% – $matchTierLabel)';
}

// ── §2.6  CareerRecommendation  ───────────────────────────────────────────────

@immutable
class CareerRecommendation {
  final String careerPath;
  final String recommendedIndustry;
  final List<String> suggestedJobRoles;
  final List<String> prioritySkillsToAcquire;
  final double predictedSuccessProbability;
  final double pathAverageGpa;
  final String insightNarrative;
  final List<OpenEducationalResource> recommendedOers;

  const CareerRecommendation({
    required this.careerPath,
    required this.recommendedIndustry,
    this.suggestedJobRoles           = const [],
    this.prioritySkillsToAcquire     = const [],
    this.predictedSuccessProbability = 0.0,
    this.pathAverageGpa              = 0.0,
    this.insightNarrative            = '',
    this.recommendedOers             = const [],
  });

  @override
  String toString() =>
      'CareerRecommendation('
          'path: "$careerPath", industry: "$recommendedIndustry", '
          'successProb: ${predictedSuccessProbability.toStringAsFixed(1)}%)';
}

// ── §2.7  GuidanceInsight  ────────────────────────────────────────────────────

@immutable
class GuidanceInsight {
  final String careerPath;
  final double pathAverageGpa;
  final double avgPredictedSuccessProbability;
  final List<String> topStudyFields;
  final bool priorEmploymentBoostsOutcome;
  final bool entrepreneurialExperienceRelevant;

  const GuidanceInsight({
    required this.careerPath,
    required this.pathAverageGpa,
    required this.avgPredictedSuccessProbability,
    this.topStudyFields                    = const [],
    this.priorEmploymentBoostsOutcome      = true,
    this.entrepreneurialExperienceRelevant = false,
  });

  @override
  String toString() =>
      'GuidanceInsight('
          'path: "$careerPath", avgGPA: ${pathAverageGpa.toStringAsFixed(3)}, '
          'avgSuccess: ${avgPredictedSuccessProbability.toStringAsFixed(2)}%)';
}

// ── §2.8  FairnessAuditResult  ────────────────────────────────────────────────

@immutable
class FairnessAuditResult {
  final Map<String, double> industryDistributionFractions;
  final Map<String, double> experienceTierDistributionFractions;
  final bool passesDiversityConcentrationCheck;
  final String auditDiagnosticMessage;

  const FairnessAuditResult({
    this.industryDistributionFractions       = const {},
    this.experienceTierDistributionFractions = const {},
    this.passesDiversityConcentrationCheck   = true,
    this.auditDiagnosticMessage              = '',
  });

  @override
  String toString() =>
      'FairnessAuditResult(pass: $passesDiversityConcentrationCheck, '
          'industries: $industryDistributionFractions)';
}

// ── §2.9  GenerationProfile  ──────────────────────────────────────────────────

@immutable
class GenerationProfile {
  final String generationLabel;
  final String birthYearRange;
  final List<String> coreWorkValues;
  final List<String> preferredWorkingModes;
  final List<String> highDemandSkills;
  final String careerStrategyNote;

  const GenerationProfile({
    required this.generationLabel,
    required this.birthYearRange,
    this.coreWorkValues        = const [],
    this.preferredWorkingModes = const [],
    this.highDemandSkills      = const [],
    this.careerStrategyNote    = '',
  });

  @override
  String toString() =>
      'GenerationProfile($generationLabel [$birthYearRange])';
}

// ══════════════════════════════════════════════════════════════════════════════
// §3  STATIC DATA TABLES
// ══════════════════════════════════════════════════════════════════════════════

// ── §3.1  Industry → Required skills  [JRD — top skills per industry] ─────────
//
// Verified counts from 50,000-row JRD analysis:
//   Software  — python 2657, java 2610, c++ 2607, sql 2582, react 2567,
//               machine learning 2559, aws 2543  (near-equal distribution)
//   Finance   — excel 3573, risk analysis 3533, sql 3522, python 3516,
//               financial modeling 3444
//   Healthcare— patient care 4481, pharmaceuticals 4473, nursing 4467,
//               medical research 4459
//   Marketing — seo 3671, content writing 3652, google ads 3585,
//               market research 3550, social media 3513
//   Manufacturing — production planning 5442, quality control 5407,
//                   supply chain 5401
//   Retail    — merchandising 5405, customer service 5360, sales 5317
//   Education — teaching 4518, edtech 4492, curriculum design 4480,
//               research 4458
//   Design    — from JFE analysis: figma, ui/ux design, adobe xd, sketch,
//               user research, wireframing, prototyping, typography

const Map<String, List<String>> kIndustrySkillMap = {
  'Software': [
    'python',
    'java',
    'c++',
    'sql',
    'react',
    'machine learning',
    'aws',
    'javascript',
    'data structures',
    'algorithms',
    'git',
    'flutter',
  ],
  'Finance': [
    'excel',
    'risk analysis',
    'sql',
    'python',
    'financial modeling',
    'accounting',
    'data analysis',
    'bloomberg',
    'power bi',
    'tableau',
  ],
  'Healthcare': [
    'patient care',
    'pharmaceuticals',
    'nursing',
    'medical research',
    'clinical documentation',
    'anatomy',
    'health informatics',
    'empathy',
    'communication',
  ],
  'Marketing': [
    'seo',
    'content writing',
    'google ads',
    'market research',
    'social media',
    'copywriting',
    'analytics',
    'canva',
    'email marketing',
    'brand strategy',
  ],
  'Manufacturing': [
    'production planning',
    'quality control',
    'supply chain',
    'lean manufacturing',
    'six sigma',
    'autocad',
    'logistics',
    'inventory management',
  ],
  'Retail': [
    'merchandising',
    'customer service',
    'sales',
    'inventory management',
    'pos systems',
    'negotiation',
    'visual merchandising',
  ],
  'Education': [
    'teaching',
    'edtech',
    'curriculum design',
    'research',
    'classroom management',
    'assessment design',
    'lesson planning',
    'communication',
  ],
  'Design': [
    'ui/ux design',
    'figma',
    'adobe xd',
    'sketch',
    'user research',
    'wireframing',
    'prototyping',
    'typography',
    'color theory',
    'adobe photoshop',
  ],
};

// ── §3.2  Career path insight data  [CGD — verified from 1,000 record analysis]

/// All statistics verified from actual CSV data:
///   Tech     — n=207, avgGPA=3.049, avgSucc=48.80
///              topFields: Science 46, Arts 42, Engineering 40
///              priorEmp: 124 Yes / 83 No  → true
///              entExp:   137 Yes / 70 No  → true
///   Finance  — n=209, avgGPA=3.015, avgSucc=50.91
///              topFields: Science 49, Engineering 46, Law 46
///              priorEmp: 131 Yes / 78 No  → true
///              entExp:   139 Yes / 70 No  → true
///   Business — n=197, avgGPA=2.846, avgSucc=50.25
///              topFields: Business 45, Law 44, Science 42
///              priorEmp: 124 Yes / 73 No  → true
///              entExp:   134 Yes / 63 No  → true
///   Healthcare—n=192, avgGPA=3.021, avgSucc=52.89
///              topFields: Engineering 40, Law 40, Business 38
///              priorEmp: 122 Yes / 70 No  → true
///              entExp:   138 Yes / 54 No  → true
///   Design   — n=195, avgGPA=2.955, avgSucc=50.18
///              topFields: Science 45, Arts 43, Engineering 42
///              priorEmp: 111 Yes / 84 No  → true
///              entExp:   135 Yes / 60 No  → true
const Map<String, Map<String, dynamic>> kCareerPathInsightData = {
  'Tech': {
    'avgGpa':                3.049,
    'avgSuccessProbability': 48.80,
    'sampleSize':            207,
    'topFieldsOfStudy':      ['Science', 'Arts', 'Engineering'],
    'recommendedIndustry':   'Software',
    'priorEmploymentHelps':  true,
    'entrepreneurialRelevance': true,
    'suggestedRoles': [
      'Software Engineer',
      'Data Analyst',
      'ML Engineer',
      'Backend Developer',
      'Full Stack Developer',
      'DevOps Engineer',
      'Flutter Developer',
    ],
    'insightText':
    'Tech path learners (n=207, avgGPA=3.05) show the highest employability '
        'in Software. Python, Java, SQL, React and Machine Learning are the '
        'most demanded skills in this industry (each requested by ~2,550+ '
        'job postings in our dataset). Prior internships significantly '
        'improve match scores.',
  },
  'Finance': {
    'avgGpa':                3.015,
    'avgSuccessProbability': 50.91,
    'sampleSize':            209,
    'topFieldsOfStudy':      ['Science', 'Engineering', 'Law'],
    'recommendedIndustry':   'Finance',
    'priorEmploymentHelps':  true,
    'entrepreneurialRelevance': true,
    'suggestedRoles': [
      'Financial Analyst',
      'Investment Banker',
      'Risk Analyst',
      'Accountant',
      'Financial Advisor',
      'Procurement Specialist',
    ],
    'insightText':
    'Finance path (n=209, avgGPA=3.02) achieves a 50.91% average predicted '
        'success. Excel (3573 postings), Risk Analysis (3533) and SQL (3522) '
        'are the top three skills demanded in Finance industry job postings.',
  },
  'Business': {
    'avgGpa':                2.846,
    'avgSuccessProbability': 50.25,
    'sampleSize':            197,
    'topFieldsOfStudy':      ['Business', 'Law', 'Science'],
    'recommendedIndustry':   'Retail',
    'priorEmploymentHelps':  true,
    'entrepreneurialRelevance': true,
    'suggestedRoles': [
      'Business Analyst',
      'Product Manager',
      'Operations Manager',
      'Project Manager',
      'HR Coordinator',
      'Executive Assistant',
    ],
    'insightText':
    'Business path (n=197, avgGPA=2.85) learners with entrepreneurial '
        'experience show higher employment rates. Communication, customer '
        'service and sales are the top differentiating skills in the '
        'Retail industry target.',
  },
  'Healthcare': {
    'avgGpa':                3.021,
    'avgSuccessProbability': 52.89,
    'sampleSize':            192,
    'topFieldsOfStudy':      ['Engineering', 'Law', 'Business'],
    'recommendedIndustry':   'Healthcare',
    'priorEmploymentHelps':  true,
    'entrepreneurialRelevance': true,
    'suggestedRoles': [
      'Healthcare Administrator',
      'Clinical Researcher',
      'Health Informatics Specialist',
      'Pharmacist',
      'Medical Writer',
      'Data Coordinator',
    ],
    'insightText':
    'Healthcare path achieves the highest predicted success probability '
        'in the dataset (52.89%, n=192). Patient care (4481 postings), '
        'pharmaceuticals (4473) and nursing (4467) lead the skill demand. '
        'Engineering and Law backgrounds show an advantage.',
  },
  'Design': {
    'avgGpa':                2.955,
    'avgSuccessProbability': 50.18,
    'sampleSize':            195,
    'topFieldsOfStudy':      ['Science', 'Arts', 'Engineering'],
    'recommendedIndustry':   'Design',
    'priorEmploymentHelps':  true,
    'entrepreneurialRelevance': true,
    'suggestedRoles': [
      'UX/UI Designer',
      'Graphic Designer',
      'Product Designer',
      'Motion Designer',
      'Web Designer',
      'UI Developer',
    ],
    'insightText':
    'Design path (n=195, avgGPA=2.96) learners with strong portfolios '
        'outperform GPA as a hiring signal. Figma, wireframing and '
        'user research are the most requested skills by employers. '
        'UX/UI Designer is the #1 position in our JFE dataset (288 postings).',
  },
};

// ── §3.3  Raw OER (Open Educational Resource) catalogue  ─────────────────────

/// OER catalogue covering all top skills identified in [JRD] and [JFE].
/// [TAV22 §3.3 — OER catalogue for skill-gap closure]
const List<Map<String, dynamic>> _kRawOerCatalogue = [
  // ── Software / Tech — top skills: python 2657, java 2610, sql 2582 ─────────
  {
    'id': 'r-py-01', 'skill': 'python', 'format': 'video',
    'title': 'Python for Everybody – Full Course',
    'platform': 'YouTube (freeCodeCamp)', 'duration': '14 hours',
    'level': 'Beginner', 'rating': 4.8, 'isFree': true,
    'url': 'https://www.youtube.com/watch?v=8DvywoWv6fI',
  },
  {
    'id': 'r-py-02', 'skill': 'python', 'format': 'interactive',
    'title': 'Python 3 Programming Specialization',
    'platform': 'Coursera', 'duration': '5 months',
    'level': 'Beginner', 'rating': 4.7, 'isFree': false,
    'url': 'https://www.coursera.org/specializations/python-3-programming',
  },
  {
    'id': 'r-py-03', 'skill': 'python', 'format': 'video',
    'title': 'Python Crash Course – Full Tutorial',
    'platform': 'YouTube (freeCodeCamp)', 'duration': '4.5 hours',
    'level': 'Beginner', 'rating': 4.7, 'isFree': true,
    'url': 'https://www.youtube.com/watch?v=rfscVS0vtbw',
  },
  {
    'id': 'r-java-01', 'skill': 'java', 'format': 'video',
    'title': 'Java Programming Tutorial – Full Course',
    'platform': 'YouTube (freeCodeCamp)', 'duration': '9 hours',
    'level': 'Beginner', 'rating': 4.7, 'isFree': true,
    'url': 'https://www.youtube.com/watch?v=A74TOX803D0',
  },
  {
    'id': 'r-java-02', 'skill': 'java', 'format': 'interactive',
    'title': 'Java Programming Masterclass',
    'platform': 'Udemy', 'duration': '80 hours',
    'level': 'Beginner', 'rating': 4.6, 'isFree': false,
    'url': 'https://www.udemy.com/course/java-the-complete-java-developer-course/',
  },
  {
    'id': 'r-cpp-01', 'skill': 'c++', 'format': 'video',
    'title': 'C++ Tutorial for Beginners – Full Course',
    'platform': 'YouTube (freeCodeCamp)', 'duration': '4 hours',
    'level': 'Beginner', 'rating': 4.6, 'isFree': true,
    'url': 'https://www.youtube.com/watch?v=vLnPwxZdW4Y',
  },
  {
    'id': 'r-sql-01', 'skill': 'sql', 'format': 'interactive',
    'title': 'SQL for Data Science',
    'platform': 'Coursera (UC Davis)', 'duration': '4 weeks',
    'level': 'Beginner', 'rating': 4.6, 'isFree': false,
    'url': 'https://www.coursera.org/learn/sql-for-data-science',
  },
  {
    'id': 'r-sql-02', 'skill': 'sql', 'format': 'interactive',
    'title': 'SQLZoo – Interactive SQL Tutorial',
    'platform': 'SQLZoo', 'duration': 'Self-paced',
    'level': 'Beginner', 'rating': 4.5, 'isFree': true,
    'url': 'https://sqlzoo.net',
  },
  {
    'id': 'r-react-01', 'skill': 'react', 'format': 'video',
    'title': 'React Tutorial for Beginners',
    'platform': 'YouTube (Programming with Mosh)', 'duration': '1 hour',
    'level': 'Beginner', 'rating': 4.7, 'isFree': true,
    'url': 'https://www.youtube.com/watch?v=SqcY0GlETPk',
  },
  {
    'id': 'r-react-02', 'skill': 'react', 'format': 'interactive',
    'title': 'The Complete React Course 2024',
    'platform': 'Udemy', 'duration': '28 hours',
    'level': 'Beginner', 'rating': 4.8, 'isFree': false,
    'url': 'https://www.udemy.com/course/react-the-complete-guide-incl-redux/',
  },
  {
    'id': 'r-ml-01', 'skill': 'machine learning', 'format': 'video',
    'title': 'Machine Learning Specialization',
    'platform': 'Coursera (Andrew Ng)', 'duration': '3 months',
    'level': 'Intermediate', 'rating': 4.9, 'isFree': false,
    'url': 'https://www.coursera.org/specializations/machine-learning-introduction',
  },
  {
    'id': 'r-ml-02', 'skill': 'machine learning', 'format': 'video',
    'title': 'Intro to Machine Learning – Full Course',
    'platform': 'YouTube (freeCodeCamp)', 'duration': '10 hours',
    'level': 'Beginner', 'rating': 4.6, 'isFree': true,
    'url': 'https://www.youtube.com/watch?v=NWONeJKn6kc',
  },
  {
    'id': 'r-aws-01', 'skill': 'aws', 'format': 'interactive',
    'title': 'AWS Cloud Practitioner Essentials',
    'platform': 'AWS Training', 'duration': '6 hours',
    'level': 'Beginner', 'rating': 4.6, 'isFree': true,
    'url': 'https://aws.amazon.com/training/digital/aws-cloud-practitioner-essentials/',
  },
  {
    'id': 'r-js-01', 'skill': 'javascript', 'format': 'interactive',
    'title': 'The Complete JavaScript Course 2024',
    'platform': 'Udemy', 'duration': '69 hours',
    'level': 'Beginner', 'rating': 4.7, 'isFree': false,
    'url': 'https://www.udemy.com/course/the-complete-javascript-course/',
  },
  {
    'id': 'r-js-02', 'skill': 'javascript', 'format': 'video',
    'title': 'JavaScript Full Course for Beginners',
    'platform': 'YouTube (freeCodeCamp)', 'duration': '7 hours',
    'level': 'Beginner', 'rating': 4.7, 'isFree': true,
    'url': 'https://www.youtube.com/watch?v=PkZNo7MFNFg',
  },
  {
    'id': 'r-flutter-01', 'skill': 'flutter', 'format': 'video',
    'title': 'Flutter & Dart – The Complete Guide',
    'platform': 'Udemy (Maximilian Schwarzmüller)', 'duration': '42 hours',
    'level': 'Beginner', 'rating': 4.8, 'isFree': false,
    'url': 'https://www.udemy.com/course/learn-flutter-dart-to-build-ios-android-apps/',
  },
  {
    'id': 'r-flutter-02', 'skill': 'flutter', 'format': 'video',
    'title': 'Flutter Crash Course for Beginners',
    'platform': 'YouTube (Academind)', 'duration': '3 hours',
    'level': 'Beginner', 'rating': 4.6, 'isFree': true,
    'url': 'https://www.youtube.com/watch?v=x0uinJvhNxI',
  },
  {
    'id': 'r-git-01', 'skill': 'git', 'format': 'video',
    'title': 'Git and GitHub Crash Course',
    'platform': 'YouTube (freeCodeCamp)', 'duration': '1 hour',
    'level': 'Beginner', 'rating': 4.8, 'isFree': true,
    'url': 'https://www.youtube.com/watch?v=RGOj5yH7evk',
  },
  // ── Data / Analytics ──────────────────────────────────────────────────────
  {
    'id': 'r-excel-01', 'skill': 'excel', 'format': 'video',
    'title': 'Excel for Beginners – Full Course',
    'platform': 'YouTube (Kevin Stratvert)', 'duration': '3 hours',
    'level': 'Beginner', 'rating': 4.7, 'isFree': true,
    'url': 'https://www.youtube.com/watch?v=Vl0H-qTclOg',
  },
  {
    'id': 'r-excel-02', 'skill': 'excel', 'format': 'interactive',
    'title': 'Excel Skills for Business Specialization',
    'platform': 'Coursera (Macquarie)', 'duration': '3 months',
    'level': 'Beginner', 'rating': 4.8, 'isFree': false,
    'url': 'https://www.coursera.org/specializations/excel',
  },
  {
    'id': 'r-tableau-01', 'skill': 'tableau', 'format': 'interactive',
    'title': 'Tableau Desktop Specialist',
    'platform': 'Tableau e-Learning', 'duration': '8 hours',
    'level': 'Beginner', 'rating': 4.5, 'isFree': true,
    'url': 'https://www.tableau.com/learn/training',
  },
  {
    'id': 'r-powerbi-01', 'skill': 'power bi', 'format': 'video',
    'title': 'Power BI Full Course – Learn Power BI in 4 Hours',
    'platform': 'YouTube (Edureka)', 'duration': '4 hours',
    'level': 'Beginner', 'rating': 4.5, 'isFree': true,
    'url': 'https://www.youtube.com/watch?v=3u7MQz1EyPY',
  },
  {
    'id': 'r-da-01', 'skill': 'data analysis', 'format': 'interactive',
    'title': 'Google Data Analytics Certificate',
    'platform': 'Coursera (Google)', 'duration': '6 months',
    'level': 'Beginner', 'rating': 4.8, 'isFree': false,
    'url': 'https://www.coursera.org/professional-certificates/google-data-analytics',
  },
  // ── Finance — top skills: excel 3573, risk analysis 3533, sql 3522 ─────────
  {
    'id': 'r-fm-01', 'skill': 'financial modeling', 'format': 'interactive',
    'title': 'Financial Modeling & Valuation Analyst (FMVA)',
    'platform': 'CFI', 'duration': 'Self-paced',
    'level': 'Intermediate', 'rating': 4.7, 'isFree': false,
    'url': 'https://corporatefinanceinstitute.com/certifications/financial-modeling-valuation-analyst-fmva-certification/',
  },
  {
    'id': 'r-ra-01', 'skill': 'risk analysis', 'format': 'video',
    'title': 'Risk Management in Banking and Financial Markets',
    'platform': 'Coursera (NYIF)', 'duration': '4 weeks',
    'level': 'Intermediate', 'rating': 4.4, 'isFree': false,
    'url': 'https://www.coursera.org/learn/risk-management-banking',
  },
  {
    'id': 'r-acc-01', 'skill': 'accounting', 'format': 'video',
    'title': 'Introduction to Financial Accounting',
    'platform': 'Coursera (Wharton)', 'duration': '4 weeks',
    'level': 'Beginner', 'rating': 4.8, 'isFree': false,
    'url': 'https://www.coursera.org/learn/wharton-accounting',
  },
  {
    'id': 'r-bloomberg-01', 'skill': 'bloomberg', 'format': 'interactive',
    'title': 'Bloomberg Market Concepts (BMC)',
    'platform': 'Bloomberg', 'duration': '8 hours',
    'level': 'Beginner', 'rating': 4.6, 'isFree': false,
    'url': 'https://bloomberg.com/professional/product/bloomberg-market-concepts/',
  },
  // ── Marketing — top skills: seo 3671, content writing 3652, google ads 3585
  {
    'id': 'r-seo-01', 'skill': 'seo', 'format': 'interactive',
    'title': 'SEO Training Course by Moz',
    'platform': 'Moz Academy', 'duration': '3.5 hours',
    'level': 'Beginner', 'rating': 4.5, 'isFree': true,
    'url': 'https://academy.moz.com/courses/seo-essentials',
  },
  {
    'id': 'r-cw-01', 'skill': 'content writing', 'format': 'video',
    'title': 'Content Marketing Certification',
    'platform': 'HubSpot Academy', 'duration': '5 hours',
    'level': 'Beginner', 'rating': 4.6, 'isFree': true,
    'url': 'https://academy.hubspot.com/courses/content-marketing',
  },
  {
    'id': 'r-ga-01', 'skill': 'google ads', 'format': 'interactive',
    'title': 'Google Ads Search Certification',
    'platform': 'Google Skillshop', 'duration': '3 hours',
    'level': 'Beginner', 'rating': 4.6, 'isFree': true,
    'url': 'https://skillshop.withgoogle.com/googleads',
  },
  {
    'id': 'r-mr-mkt-01', 'skill': 'market research', 'format': 'interactive',
    'title': 'Market Research Specialization',
    'platform': 'Coursera (UC Davis)', 'duration': '4 months',
    'level': 'Beginner', 'rating': 4.5, 'isFree': false,
    'url': 'https://www.coursera.org/specializations/market-research',
  },
  {
    'id': 'r-sm-01', 'skill': 'social media', 'format': 'interactive',
    'title': 'Social Media Marketing Specialization',
    'platform': 'Coursera (Northwestern)', 'duration': '5 months',
    'level': 'Beginner', 'rating': 4.5, 'isFree': false,
    'url': 'https://www.coursera.org/specializations/social-media-marketing',
  },
  {
    'id': 'r-em-01', 'skill': 'email marketing', 'format': 'interactive',
    'title': 'Email Marketing Certification',
    'platform': 'HubSpot Academy', 'duration': '3 hours',
    'level': 'Beginner', 'rating': 4.5, 'isFree': true,
    'url': 'https://academy.hubspot.com/courses/email-marketing',
  },
  // ── Design — from JFE: figma 288 postings, ui/ux most requested ────────────
  {
    'id': 'r-figma-01', 'skill': 'figma', 'format': 'video',
    'title': 'Figma UI/UX Design Essentials',
    'platform': 'Udemy', 'duration': '16 hours',
    'level': 'Beginner', 'rating': 4.7, 'isFree': false,
    'url': 'https://www.udemy.com/course/figma-ux-ui-design-user-experience-tutorial-course/',
  },
  {
    'id': 'r-figma-02', 'skill': 'figma', 'format': 'video',
    'title': 'Figma Tutorial for Beginners',
    'platform': 'YouTube (Traversy Media)', 'duration': '2 hours',
    'level': 'Beginner', 'rating': 4.7, 'isFree': true,
    'url': 'https://www.youtube.com/watch?v=FTFaQWZBqQ8',
  },
  {
    'id': 'r-ux-01', 'skill': 'ui/ux design', 'format': 'interactive',
    'title': 'Google UX Design Professional Certificate',
    'platform': 'Coursera (Google)', 'duration': '6 months',
    'level': 'Beginner', 'rating': 4.8, 'isFree': false,
    'url': 'https://www.coursera.org/professional-certificates/google-ux-design',
  },
  {
    'id': 'r-ux-02', 'skill': 'user research', 'format': 'video',
    'title': 'User Research – Methods and Best Practices',
    'platform': 'Interaction Design Foundation', 'duration': '18 hours',
    'level': 'Beginner', 'rating': 4.6, 'isFree': false,
    'url': 'https://www.interaction-design.org/courses/user-research-methods-and-best-practices',
  },
  {
    'id': 'r-wire-01', 'skill': 'wireframing', 'format': 'video',
    'title': 'Wireframing with Figma – Beginner Course',
    'platform': 'YouTube (DesignCourse)', 'duration': '1.5 hours',
    'level': 'Beginner', 'rating': 4.5, 'isFree': true,
    'url': 'https://www.youtube.com/watch?v=D4NyQ5iNo8U',
  },
  {
    'id': 'r-typo-01', 'skill': 'typography', 'format': 'video',
    'title': 'Typography Design Fundamentals',
    'platform': 'YouTube (DesignCourse)', 'duration': '2 hours',
    'level': 'Beginner', 'rating': 4.4, 'isFree': true,
    'url': 'https://www.youtube.com/watch?v=hnFJ4EBNBNk',
  },
  {
    'id': 'r-ps-01', 'skill': 'adobe photoshop', 'format': 'video',
    'title': 'Photoshop for Beginners – Full Course',
    'platform': 'YouTube (freeCodeCamp)', 'duration': '3.5 hours',
    'level': 'Beginner', 'rating': 4.5, 'isFree': true,
    'url': 'https://www.youtube.com/watch?v=IyR_uYsRdPs',
  },
  // ── Healthcare — top skills: patient care 4481, nursing 4467 ─────────────
  {
    'id': 'r-hi-01', 'skill': 'health informatics', 'format': 'interactive',
    'title': 'Health Informatics Specialization',
    'platform': 'Coursera (Johns Hopkins)', 'duration': '4 months',
    'level': 'Intermediate', 'rating': 4.6, 'isFree': false,
    'url': 'https://www.coursera.org/specializations/health-informatics',
  },
  {
    'id': 'r-mr-01', 'skill': 'medical research', 'format': 'interactive',
    'title': 'Clinical Research Training',
    'platform': 'edX (WHO)', 'duration': '6 weeks',
    'level': 'Beginner', 'rating': 4.4, 'isFree': true,
    'url': 'https://www.edx.org/course/clinical-research-trials',
  },
  {
    'id': 'r-pharma-01', 'skill': 'pharmaceuticals', 'format': 'interactive',
    'title': 'Pharmaceutical and Medicine Manufacturing',
    'platform': 'Coursera', 'duration': '4 weeks',
    'level': 'Beginner', 'rating': 4.3, 'isFree': false,
    'url': 'https://www.coursera.org/learn/pharmaceutical-manufacturing',
  },
  // ── Manufacturing — top: production planning 5442, quality control 5407 ───
  {
    'id': 'r-sc-01', 'skill': 'supply chain', 'format': 'interactive',
    'title': 'Supply Chain Management Specialization',
    'platform': 'Coursera (Rutgers)', 'duration': '5 months',
    'level': 'Intermediate', 'rating': 4.6, 'isFree': false,
    'url': 'https://www.coursera.org/specializations/supply-chain-management',
  },
  {
    'id': 'r-qc-01', 'skill': 'quality control', 'format': 'video',
    'title': 'Quality Management & Six Sigma',
    'platform': 'LinkedIn Learning', 'duration': '3 hours',
    'level': 'Beginner', 'rating': 4.4, 'isFree': false,
    'url': 'https://www.linkedin.com/learning/topics/quality-management',
  },
  {
    'id': 'r-lean-01', 'skill': 'lean manufacturing', 'format': 'interactive',
    'title': 'Lean Manufacturing – Complete Course',
    'platform': 'Coursera (Tecnológico de Monterrey)', 'duration': '3 months',
    'level': 'Intermediate', 'rating': 4.5, 'isFree': false,
    'url': 'https://www.coursera.org/learn/lean-manufacturing',
  },
  {
    'id': 'r-pp-01', 'skill': 'production planning', 'format': 'video',
    'title': 'Production Planning & Scheduling',
    'platform': 'YouTube (NPTEL)', 'duration': '8 hours',
    'level': 'Beginner', 'rating': 4.3, 'isFree': true,
    'url': 'https://www.youtube.com/watch?v=3q8j9T5MmHU',
  },
  // ── Retail — merchandising 5405, customer service 5360, sales 5317 ─────────
  {
    'id': 'r-cs-01', 'skill': 'customer service', 'format': 'interactive',
    'title': 'Customer Service Fundamentals',
    'platform': 'Coursera (CVS Health)', 'duration': '4 weeks',
    'level': 'Beginner', 'rating': 4.5, 'isFree': false,
    'url': 'https://www.coursera.org/learn/cvs-customer-service',
  },
  {
    'id': 'r-sales-01', 'skill': 'sales', 'format': 'interactive',
    'title': 'Sales Training – Practical Sales Techniques',
    'platform': 'Udemy', 'duration': '5 hours',
    'level': 'Beginner', 'rating': 4.5, 'isFree': false,
    'url': 'https://www.udemy.com/course/sales-training/',
  },
  {
    'id': 'r-merch-01', 'skill': 'merchandising', 'format': 'video',
    'title': 'Retail Merchandising Fundamentals',
    'platform': 'YouTube (NRF Foundation)', 'duration': '2 hours',
    'level': 'Beginner', 'rating': 4.3, 'isFree': true,
    'url': 'https://www.youtube.com/watch?v=wM9DXQHM2Yg',
  },
  // ── Education — teaching 4518, edtech 4492, curriculum design 4480 ─────────
  {
    'id': 'r-teach-01', 'skill': 'teaching', 'format': 'interactive',
    'title': 'Foundations of Teaching for Learning Specialization',
    'platform': 'Coursera (Commonwealth Edu Trust)', 'duration': '8 months',
    'level': 'Beginner', 'rating': 4.5, 'isFree': false,
    'url': 'https://www.coursera.org/specializations/foundations-teaching',
  },
  {
    'id': 'r-cd-01', 'skill': 'curriculum design', 'format': 'interactive',
    'title': 'Curriculum Design and Teaching',
    'platform': 'edX (MIT)', 'duration': '6 weeks',
    'level': 'Intermediate', 'rating': 4.5, 'isFree': false,
    'url': 'https://www.edx.org/course/designing-and-developing-curricula',
  },
  {
    'id': 'r-edtech-01', 'skill': 'edtech', 'format': 'interactive',
    'title': 'Learning Technologies: Using Apps and the Web',
    'platform': 'Coursera (University of London)', 'duration': '4 weeks',
    'level': 'Beginner', 'rating': 4.4, 'isFree': false,
    'url': 'https://www.coursera.org/learn/learning-technologies-apps-and-the-web',
  },
  {
    'id': 'r-res-01', 'skill': 'research', 'format': 'interactive',
    'title': 'Research Methods and Statistics',
    'platform': 'Coursera (University of Amsterdam)', 'duration': '3 months',
    'level': 'Beginner', 'rating': 4.6, 'isFree': false,
    'url': 'https://www.coursera.org/specializations/social-science',
  },
  // ── Soft skills ───────────────────────────────────────────────────────────
  {
    'id': 'r-comm-01', 'skill': 'communication', 'format': 'interactive',
    'title': 'Improving Communication Skills',
    'platform': 'Coursera (Penn)', 'duration': '4 weeks',
    'level': 'Beginner', 'rating': 4.6, 'isFree': false,
    'url': 'https://www.coursera.org/learn/wharton-communication-skills',
  },
  {
    'id': 'r-lead-01', 'skill': 'leadership', 'format': 'interactive',
    'title': 'Inspiring and Motivating Individuals',
    'platform': 'Coursera (Michigan)', 'duration': '4 weeks',
    'level': 'Beginner', 'rating': 4.7, 'isFree': false,
    'url': 'https://www.coursera.org/learn/motivate-people-teams',
  },
  {
    'id': 'r-pm-01', 'skill': 'project management', 'format': 'interactive',
    'title': 'Google Project Management Certificate',
    'platform': 'Coursera (Google)', 'duration': '6 months',
    'level': 'Beginner', 'rating': 4.8, 'isFree': false,
    'url': 'https://www.coursera.org/professional-certificates/google-project-management',
  },
  {
    'id': 'r-agile-01', 'skill': 'algorithms', 'format': 'interactive',
    'title': 'Algorithms Specialization',
    'platform': 'Coursera (Stanford)', 'duration': '4 months',
    'level': 'Intermediate', 'rating': 4.8, 'isFree': false,
    'url': 'https://www.coursera.org/specializations/algorithms',
  },
  {
    'id': 'r-ds-01', 'skill': 'data structures', 'format': 'video',
    'title': 'Data Structures Easy to Advanced – Full Tutorial',
    'platform': 'YouTube (freeCodeCamp)', 'duration': '8 hours',
    'level': 'Intermediate', 'rating': 4.7, 'isFree': true,
    'url': 'https://www.youtube.com/watch?v=RBSGKlAvoiM',
  },
];

// ── §3.4  Guidance insights  [CGD — verified from 1,000 record analysis] ──────

/// Per-path statistics verified from actual CSV:
///   Tech(207): avgGPA=3.049, avgSucc=48.80, topFields=[Science,Arts,Engineering]
///   Finance(209): avgGPA=3.015, avgSucc=50.91, topFields=[Science,Engineering,Law]
///   Business(197): avgGPA=2.846, avgSucc=50.25, topFields=[Business,Law,Science]
///   Healthcare(192): avgGPA=3.021, avgSucc=52.89, topFields=[Engineering,Law,Business]
///   Design(195): avgGPA=2.955, avgSucc=50.18, topFields=[Science,Arts,Engineering]
const List<GuidanceInsight> kGuidanceInsightsByPath = [
  GuidanceInsight(
    careerPath: 'Tech',
    pathAverageGpa: 3.049,
    avgPredictedSuccessProbability: 48.80,
    topStudyFields: ['Science', 'Arts', 'Engineering'],
    priorEmploymentBoostsOutcome: true,
    entrepreneurialExperienceRelevant: true,
  ),
  GuidanceInsight(
    careerPath: 'Finance',
    pathAverageGpa: 3.015,
    avgPredictedSuccessProbability: 50.91,
    topStudyFields: ['Science', 'Engineering', 'Law'],
    priorEmploymentBoostsOutcome: true,
    entrepreneurialExperienceRelevant: true,
  ),
  GuidanceInsight(
    careerPath: 'Business',
    pathAverageGpa: 2.846,
    avgPredictedSuccessProbability: 50.25,
    topStudyFields: ['Business', 'Law', 'Science'],
    priorEmploymentBoostsOutcome: true,
    entrepreneurialExperienceRelevant: true,
  ),
  GuidanceInsight(
    careerPath: 'Healthcare',
    pathAverageGpa: 3.021,
    avgPredictedSuccessProbability: 52.89,
    topStudyFields: ['Engineering', 'Law', 'Business'],
    priorEmploymentBoostsOutcome: true,
    entrepreneurialExperienceRelevant: true,
  ),
  GuidanceInsight(
    careerPath: 'Design',
    pathAverageGpa: 2.955,
    avgPredictedSuccessProbability: 50.18,
    topStudyFields: ['Science', 'Arts', 'Engineering'],
    priorEmploymentBoostsOutcome: true,
    entrepreneurialExperienceRelevant: true,
  ),
];

// ── §3.5  Industry job roles  [JFE — top positions from 10,000 row analysis] ──

/// Top positions verified from JFE (count > 80):
///   ux/ui designer 288, digital marketing specialist 181, software engineer 165,
///   network engineer 163, software tester 153, financial advisor 141,
///   procurement manager 140, executive assistant 135, event planner 118,
///   purchasing agent 115, procurement specialist 112, systems administrator 110,
///   network administrator 106, administrative assistant 106, hr coordinator 102,
///   graphic designer 102, marketing analyst 100, ui developer 96
const Map<String, List<String>> kIndustryJobRolesMap = {
  'Software': [
    'Software Engineer',
    'Network Engineer',
    'Software Tester',
    'Systems Administrator',
    'Network Administrator',
    'UI Developer',
    'Backend Developer',
    'Full Stack Developer',
    'DevOps Engineer',
    'Data Analyst',
  ],
  'Design': [
    'UX/UI Designer',
    'Graphic Designer',
    'Web Designer',
    'Motion Designer',
    'Product Designer',
    'UI Developer',
  ],
  'Marketing': [
    'Digital Marketing Specialist',
    'Social Media Manager',
    'Marketing Analyst',
    'Content Creator',
    'Brand Strategist',
    'SEO Specialist',
    'Content Writer',
  ],
  'Finance': [
    'Financial Advisor',
    'Procurement Manager',
    'Procurement Specialist',
    'Purchasing Agent',
    'Risk Analyst',
    'Investment Banker',
  ],
  'Education': [
    'Curriculum Designer',
    'EdTech Specialist',
    'Instructional Designer',
    'Academic Researcher',
    'Training Coordinator',
  ],
  'Healthcare': [
    'Clinical Researcher',
    'Healthcare Administrator',
    'Medical Writer',
    'Health Informatics Specialist',
    'Pharmacist',
  ],
  'Manufacturing': [
    'Procurement Manager',
    'Supply Chain Analyst',
    'Quality Control Inspector',
    'Production Planner',
    'Logistics Coordinator',
  ],
  'Retail': [
    'Executive Assistant',
    'HR Coordinator',
    'Administrative Assistant',
    'Event Planner',
    'Sales Representative',
    'Customer Success Manager',
  ],
};

// ── §3.6  Field of study → career path mapping  [CGD] ────────────────────────

/// Verified from CGD: top recommended paths per field in the dataset.
const Map<String, String> kStudyFieldToCareerPathMap = {
  'Engineering': 'Tech',
  'Science':     'Tech',
  'Business':    'Business',
  'Law':         'Finance',
  'Arts':        'Design',
};

// ── §3.7  Career path GPA insight texts  [CGD — verified statistics] ──────────

const Map<String, String> kCareerPathGpaInsightTexts = {
  'Tech':
  'Tech path average GPA is 3.05 (n=207 students). '
      'Your GPA positions you well — focus on building a project portfolio '
      'with Python, Java, SQL and React to maximise employability.',
  'Finance':
  'Finance path average GPA is 3.02 (n=209 students). '
      'Excel (top skill with 3,573 job postings), Risk Analysis and SQL '
      'are the top differentiators beyond GPA.',
  'Business':
  'Business path average GPA is 2.85 (n=197 students). '
      'Entrepreneurial experience and communication skills matter more '
      'than GPA in this path — 68% of Business learners had entrepreneurial experience.',
  'Healthcare':
  'Healthcare path has the highest predicted success probability (52.89%, n=192). '
      'Patient care (4,481 postings), pharmaceuticals and nursing skills are key. '
      'Relevant certifications are highly valued.',
  'Design':
  'Design path employers value portfolio quality over GPA (avg 2.96, n=195). '
      'UX/UI Designer is the #1 role in our dataset (288 postings). '
      'Build a strong Figma and Adobe portfolio to stand out.',
};

// ── §3.8  TF-IDF domain weights  [Ajjam26 §2.1] ──────────────────────────────

/// Per-term TF-IDF importance weights (0.0–1.0).
/// Weights calibrated using JRD frequency data:
///   python 2657/7302=36.4%, java 2610/7302=35.7% → high tier
///   excel 3573/7017=50.9% → very high tier in Finance context
const Map<String, double> kSkillTfidfDomainWeights = {
  // ── Tier 1  (0.80–0.95) ──────────────────────────────────────────────────
  'python':           0.95,
  'tensorflow':       0.92,
  'pytorch':          0.92,
  'postgresql':       0.91,
  'sql':              0.90,
  'machine learning': 0.90,
  'deep learning':    0.90,
  'nlp':              0.88,
  'docker':           0.88,
  'mongodb':          0.86,
  'azure':            0.86,
  'gcp':              0.86,
  'kubernetes':       0.87,
  'aws':              0.87,
  'flutter':          0.87,
  'typescript':       0.84,
  'golang':           0.84,
  'rust':             0.84,
  'react':            0.85,
  'nodejs':           0.85,
  'java':             0.85,
  'kotlin':           0.85,
  'swift':            0.85,
  'microservices':    0.85,
  'devops':           0.85,
  'phd':              0.83,
  'c++':              0.83,
  'graphql':          0.83,
  'airflow':          0.83,
  'kafka':            0.83,
  'tableau':          0.83,
  'power bi':         0.83,
  'scrum':            0.82,
  'agile':            0.82,
  'etl':              0.82,
  'hadoop':           0.82,
  'spark':            0.82,
  'scala':            0.82,
  'dbt':              0.82,
  'redis':            0.84,
  'ci/cd':            0.84,
  'r':                0.80,
  // ── Tier 2  (0.50–0.79) ──────────────────────────────────────────────────
  'data analysis':        0.75,
  'financial modeling':   0.74,
  'statistical analysis': 0.70,
  'data visualization':   0.70,
  'project management':   0.68,
  'database':             0.66,
  'api':                  0.65,
  'git':                  0.65,
  'linux':                0.65,
  'testing':              0.64,
  'excel':                0.72,
  'risk analysis':        0.71,
  'patient care':         0.70,
  'teaching':             0.66,
  'curriculum design':    0.65,
  'supply chain':         0.64,
  'quality control':      0.64,
  'production planning':  0.63,
  'seo':                  0.62,
  'merchandising':        0.61,
  'customer service':     0.60,
  'sales':                0.60,
  'edtech':               0.60,
  'leadership':           0.60,
  'communication':        0.57,
  'research':             0.58,
  'stakeholder':          0.57,
  'problem solving':      0.56,
  'documentation':        0.55,
  'cross-functional':     0.52,
  'mentoring':            0.52,
  'presentation':         0.53,
  'figma':                0.68,
  'ui/ux design':         0.70,
  'wireframing':          0.65,
  'prototyping':          0.65,
  'user research':        0.64,
  'adobe photoshop':      0.60,
  'typography':           0.58,
  'google ads':           0.62,
  'content writing':      0.60,
  'social media':         0.60,
  'market research':      0.62,
  'nursing':              0.65,
  'pharmaceuticals':      0.65,
  'medical research':     0.64,
  // ── Tier 3  (0.10–0.49) ──────────────────────────────────────────────────
  'team':          0.15,
  'experience':    0.20,
  'knowledge':     0.18,
  'skills':        0.15,
  'professional':  0.15,
  'fast':          0.12,
  'detail':        0.15,
  'strong':        0.12,
  'ability':       0.12,
  'motivated':     0.10,
  'passion':       0.10,
  'dynamic':       0.10,
  'driven':        0.10,
  'oriented':      0.10,
  'responsible':   0.10,
  'work':          0.10,
  'good':          0.10,
  'excellent':     0.10,
};

// ── §3.9  Cross-domain skill bridges  [Ajjam26 §3.4, Dawson21 §2.2] ──────────

const Map<String, List<Map<String, dynamic>>> kCrossDomainSkillBridges = {
  'autocad':             [{'targetSkill': 'data visualization', 'thetaScore': 0.45}],
  'structural analysis': [{'targetSkill': 'data analysis',      'thetaScore': 0.62}],
  'qa/qc': [
    {'targetSkill': 'data validation', 'thetaScore': 0.71},
    {'targetSkill': 'testing',         'thetaScore': 0.68},
  ],
  'project scheduling': [
    {'targetSkill': 'project management', 'thetaScore': 0.78},
    {'targetSkill': 'agile',              'thetaScore': 0.55},
  ],
  'cost estimation': [
    {'targetSkill': 'data analysis', 'thetaScore': 0.58},
    {'targetSkill': 'excel',         'thetaScore': 0.72},
  ],
  'site supervision': [
    {'targetSkill': 'stakeholder', 'thetaScore': 0.60},
    {'targetSkill': 'leadership',  'thetaScore': 0.65},
  ],
  'financial modeling': [
    {'targetSkill': 'data analysis', 'thetaScore': 0.74},
    {'targetSkill': 'excel',         'thetaScore': 0.85},
    {'targetSkill': 'sql',           'thetaScore': 0.55},
  ],
  'risk analysis': [
    {'targetSkill': 'statistical analysis', 'thetaScore': 0.70},
    {'targetSkill': 'machine learning',     'thetaScore': 0.50},
  ],
  'forecasting': [
    {'targetSkill': 'statistical analysis', 'thetaScore': 0.75},
    {'targetSkill': 'python',               'thetaScore': 0.45},
  ],
  'pivot tables': [
    {'targetSkill': 'data analysis', 'thetaScore': 0.68},
    {'targetSkill': 'tableau',       'thetaScore': 0.60},
  ],
  'a/b testing': [
    {'targetSkill': 'statistical analysis', 'thetaScore': 0.72},
    {'targetSkill': 'testing',              'thetaScore': 0.65},
  ],
  'google analytics': [
    {'targetSkill': 'data analysis', 'thetaScore': 0.75},
    {'targetSkill': 'sql',           'thetaScore': 0.52},
  ],
  'seo': [
    {'targetSkill': 'data analysis', 'thetaScore': 0.58},
    {'targetSkill': 'api',           'thetaScore': 0.42},
  ],
  'campaign management': [
    {'targetSkill': 'project management', 'thetaScore': 0.68},
    {'targetSkill': 'stakeholder',        'thetaScore': 0.62},
  ],
  'clinical research': [
    {'targetSkill': 'research',             'thetaScore': 0.82},
    {'targetSkill': 'statistical analysis', 'thetaScore': 0.73},
  ],
  'patient data': [
    {'targetSkill': 'database',      'thetaScore': 0.65},
    {'targetSkill': 'data analysis', 'thetaScore': 0.70},
  ],
  'ehr': [
    {'targetSkill': 'database', 'thetaScore': 0.68},
    {'targetSkill': 'sql',      'thetaScore': 0.55},
  ],
  'report writing': [
    {'targetSkill': 'documentation', 'thetaScore': 0.75},
    {'targetSkill': 'communication', 'thetaScore': 0.70},
  ],
  'data collection': [
    {'targetSkill': 'data analysis', 'thetaScore': 0.72},
    {'targetSkill': 'etl',           'thetaScore': 0.58},
  ],
  'presentation': [
    {'targetSkill': 'communication', 'thetaScore': 0.78},
    {'targetSkill': 'stakeholder',   'thetaScore': 0.65},
  ],
  'team management': [
    {'targetSkill': 'leadership', 'thetaScore': 0.75},
    {'targetSkill': 'scrum',      'thetaScore': 0.60},
  ],
  'problem solving': [
    {'targetSkill': 'machine learning', 'thetaScore': 0.42},
    {'targetSkill': 'research',         'thetaScore': 0.55},
  ],
  'mathematics': [
    {'targetSkill': 'machine learning',     'thetaScore': 0.68},
    {'targetSkill': 'statistical analysis', 'thetaScore': 0.75},
    {'targetSkill': 'python',               'thetaScore': 0.52},
  ],
  'statistics': [
    {'targetSkill': 'machine learning',     'thetaScore': 0.72},
    {'targetSkill': 'statistical analysis', 'thetaScore': 0.90},
    {'targetSkill': 'r',                    'thetaScore': 0.65},
  ],
  'matlab': [
    {'targetSkill': 'python',           'thetaScore': 0.65},
    {'targetSkill': 'machine learning', 'thetaScore': 0.58},
    {'targetSkill': 'r',                'thetaScore': 0.60},
  ],
  'merchandising': [
    {'targetSkill': 'market research', 'thetaScore': 0.55},
    {'targetSkill': 'data analysis',   'thetaScore': 0.48},
  ],
  'customer service': [
    {'targetSkill': 'communication', 'thetaScore': 0.80},
    {'targetSkill': 'stakeholder',   'thetaScore': 0.62},
  ],
  'production planning': [
    {'targetSkill': 'project management', 'thetaScore': 0.65},
    {'targetSkill': 'data analysis',      'thetaScore': 0.55},
  ],
  'wireframing': [
    {'targetSkill': 'ui/ux design', 'thetaScore': 0.85},
    {'targetSkill': 'prototyping',  'thetaScore': 0.90},
  ],
  'user research': [
    {'targetSkill': 'research',    'thetaScore': 0.72},
    {'targetSkill': 'ui/ux design','thetaScore': 0.80},
  ],
};

// ── §3.10  Generation profile map  [Alaql23] ──────────────────────────────────

const Map<String, GenerationProfile> kGenerationProfileMap = {
  'Gen Z': GenerationProfile(
    generationLabel: 'Gen Z',
    birthYearRange:  '1997–2012',
    coreWorkValues: [
      'work-life balance', 'social impact', 'digital flexibility',
      'mental health support', 'diversity & inclusion',
    ],
    preferredWorkingModes: ['remote', 'hybrid', 'part-time'],
    highDemandSkills: [
      'python', 'machine learning', 'flutter', 'ui/ux design',
      'social media', 'data analysis',
    ],
    careerStrategyNote:
    'Gen Z workers prioritise purpose-driven roles and remote flexibility. '
        'Showcase social impact and tech literacy on your profile. [Alaql23]',
  ),
  'Millennials': GenerationProfile(
    generationLabel: 'Millennials',
    birthYearRange:  '1981–1996',
    coreWorkValues: [
      'career growth', 'collaboration', 'continuous learning',
      'meaningful work', 'competitive salary',
    ],
    preferredWorkingModes: ['hybrid', 'full-time', 'remote'],
    highDemandSkills: [
      'project management', 'agile', 'aws', 'sql', 'leadership',
      'data visualization',
    ],
    careerStrategyNote:
    'Millennials value clear career ladders and collaborative cultures. '
        'Highlight leadership and cross-functional project experience. [Alaql23]',
  ),
  'Gen X': GenerationProfile(
    generationLabel: 'Gen X',
    birthYearRange:  '1965–1980',
    coreWorkValues: [
      'autonomy', 'job security', 'work-life balance',
      'results-oriented', 'pragmatism',
    ],
    preferredWorkingModes: ['full-time', 'hybrid'],
    highDemandSkills: [
      'stakeholder', 'risk analysis', 'financial modeling',
      'supply chain', 'excel', 'leadership',
    ],
    careerStrategyNote:
    'Gen X workers excel in senior management and operations roles. '
        'Emphasise autonomy, delivery track-record, and domain expertise. [Alaql23]',
  ),
  'Baby Boomers': GenerationProfile(
    generationLabel: 'Baby Boomers',
    birthYearRange:  '1946–1964',
    coreWorkValues: [
      'loyalty', 'face-to-face interaction', 'experience-based authority',
      'stability', 'mentorship',
    ],
    preferredWorkingModes: ['full-time', 'contract', 'part-time'],
    highDemandSkills: [
      'mentoring', 'communication', 'research', 'documentation',
      'quality control', 'teaching',
    ],
    careerStrategyNote:
    'Baby Boomers bring deep institutional knowledge. '
        'Position mentorship and cross-generational knowledge transfer as '
        'core value propositions. [Alaql23]',
  ),
};

// ══════════════════════════════════════════════════════════════════════════════
// §4  CareerGuidanceEngine
// ══════════════════════════════════════════════════════════════════════════════

class CareerGuidanceEngine {
  const CareerGuidanceEngine._();

  // ── §4.1  Job matching ─────────────────────────────────────────────────────

  static List<JobMatchCandidate> rankJobsBySkillSimilarity({
    required List<String> ownedSkills,
    required List<Job> availableJobs,
    String? industry,
    String? experienceLevel,
    String? workingMode,
    int topN = kTopNRecommendations,
  }) {
    if (ownedSkills.isEmpty || availableJobs.isEmpty) return [];

    final normOwned = ownedSkills.map(_normaliseTerm).toSet();

    var candidates = availableJobs;
    if (industry != null && industry.isNotEmpty) {
      candidates = candidates
          .where((j) => j.industry.toLowerCase() == industry.toLowerCase())
          .toList();
    }
    if (experienceLevel != null && experienceLevel.isNotEmpty) {
      candidates = candidates
          .where((j) =>
      j.experienceLevel.toLowerCase() == experienceLevel.toLowerCase())
          .toList();
    }
    if (workingMode != null && workingMode.isNotEmpty) {
      candidates = candidates
          .where((j) =>
      j.workingMode.toLowerCase() == workingMode.toLowerCase())
          .toList();
    }

    final results = <JobMatchCandidate>[];

    for (final job in candidates) {
      if (job.requiredSkills.isEmpty) continue;
      final normRequired = job.requiredSkills.map(_normaliseTerm).toSet();

      final matched = normOwned.intersection(normRequired).toList();
      final missing = normRequired.difference(normOwned).toList();

      final score = _computeWeightedCosineSimilarity(normOwned, normRequired);
      final pct   = (score * 100.0).clamp(0.0, 100.0);

      if (pct >= kMinSimilarityThreshold) {
        final pjFit = normRequired.isEmpty
            ? false
            : (matched.length / normRequired.length) >= 0.60;

        results.add(JobMatchCandidate(
          job:                   job,
          cosineSimilarityScore: pct,
          matchedSkills:         matched,
          missingSkills:         missing,
          meetsPersonJobFit:     pjFit,
        ));
      }
    }

    results.sort(
          (a, b) => b.cosineSimilarityScore.compareTo(a.cosineSimilarityScore),
    );
    return results.take(topN).toList();
  }

  // ── §4.2  Skill-gap analysis ───────────────────────────────────────────────

  static SkillGapAnalysis computeSkillGapAnalysis({
    required List<String> ownedSkills,
    required String targetIndustry,
    String targetTitle = '',
  }) {
    final requiredSkills = kIndustrySkillMap[targetIndustry] ?? <String>[];
    final resolvedTitle  = targetTitle.isEmpty ? targetIndustry : targetTitle;

    if (requiredSkills.isEmpty) {
      return SkillGapAnalysis(
        targetTitle:           resolvedTitle,
        ownedSkills:           ownedSkills,
        missingSkills:         const [],
        readinessPercent:      100.0,
        projectedMatchPercent: 100.0,
      );
    }

    final normOwned    = ownedSkills.map(_normaliseTerm).toSet();
    final normRequired = requiredSkills.map(_normaliseTerm).toList();

    final owned   = normRequired.where(normOwned.contains).toList();
    final missing = normRequired.where((s) => !normOwned.contains(s)).toList();

    final readiness = (owned.length / requiredSkills.length * 100.0)
        .clamp(0.0, 100.0);

    final gainPerSkill = 100.0 / requiredSkills.length;
    final topGapCount  = math.min(missing.length, kPrioritySkillGapCount);
    final projected    =
    (readiness + gainPerSkill * topGapCount).clamp(0.0, 100.0);

    final oerMap = fetchOersBySkillList(
      missing.take(kPrioritySkillGapCount + 3).toList(),
    );

    return SkillGapAnalysis(
      targetTitle:           resolvedTitle,
      ownedSkills:           owned,
      missingSkills:         missing,
      readinessPercent:      readiness,
      projectedMatchPercent: projected,
      oersBySkill:           oerMap,
    );
  }

  // ── §4.3  Career path recommendation ──────────────────────────────────────

  static CareerRecommendation generateCareerPathRecommendation({
    required String fieldOfStudy,
    required double gpa,
    required String careerInterests,
    required List<String> ownedSkills,
  }) {
    final normSkills    = ownedSkills.map(_normaliseTerm).toSet();
    final normInterests = _normaliseTerm(careerInterests);

    var bestPath  = kStudyFieldToCareerPathMap[fieldOfStudy] ?? kDefaultCareerPath;
    var bestScore = 0.0;

    for (final entry in kCareerPathInsightData.entries) {
      final path = entry.key;
      final data = entry.value;

      double score = 0.0;

      final normPath = _normaliseTerm(path);
      if (normPath.contains(normInterests) ||
          normInterests.contains(normPath)) {
        score += 40.0;
      }

      if ((kStudyFieldToCareerPathMap[fieldOfStudy] ?? '') == path) {
        score += 20.0;
      }

      final industry  = data['recommendedIndustry'] as String;
      final reqSkills =
      (kIndustrySkillMap[industry] ?? <String>[]).map(_normaliseTerm).toSet();
      final overlap = normSkills.intersection(reqSkills).length;
      score += overlap * 5.0;

      final avgGpa = data['avgGpa'] as double;
      if (gpa >= avgGpa) score += 10.0;

      if (score > bestScore) {
        bestScore = score;
        bestPath  = path;
      }
    }

    final pathData   = kCareerPathInsightData[bestPath]!;
    final industry   = pathData['recommendedIndustry']  as String;
    final avgGpa     = pathData['avgGpa']                as double;
    final avgSuccess = pathData['avgSuccessProbability'] as double;

    final gpaBonus   = ((gpa - avgGpa) * 5.0).clamp(-10.0, 15.0);
    final adjSuccess = (avgSuccess + gpaBonus).clamp(0.0, 100.0);

    final reqSkills = kIndustrySkillMap[industry] ?? <String>[];
    final priority  = reqSkills
        .where((s) => !normSkills.contains(_normaliseTerm(s)))
        .take(5)
        .toList();

    final oerMap  = fetchOersBySkillList(priority.take(3).toList());
    final flatOers = oerMap.values.expand((v) => v).toList();

    final gpaInsightText = kCareerPathGpaInsightTexts[bestPath] ?? '';
    final gpaInsight = gpa >= kPathAverageGpaBaseline
        ? 'Your GPA (${gpa.toStringAsFixed(2)}) is above the $bestPath path '
        'average ($avgGpa). $gpaInsightText'
        : 'Focus on practical projects and internships to supplement your GPA. '
        '$gpaInsightText';

    return CareerRecommendation(
      careerPath:                  bestPath,
      recommendedIndustry:         industry,
      suggestedJobRoles:           List<String>.from(
          pathData['suggestedRoles'] as List<dynamic>? ?? []),
      prioritySkillsToAcquire:     priority,
      predictedSuccessProbability: adjSuccess,
      pathAverageGpa:              avgGpa,
      insightNarrative:            gpaInsight,
      recommendedOers:             flatOers,
    );
  }

  // ── §4.4  Insight card generation ─────────────────────────────────────────

  static List<CareerInsight> buildPersonalisedInsightCards({
    required double gpa,
    required String careerPath,
    required List<String> ownedSkills,
    required double readinessProgress,
    required double matchScore,
    bool priorEmployment           = false,
    bool entrepreneurialExperience = false,
  }) {
    final insights  = <CareerInsight>[];
    final pathData  = kCareerPathInsightData[careerPath];

    if (pathData != null) {
      final avgGpa     = pathData['avgGpa']                as double;
      final avgSuccess = pathData['avgSuccessProbability'] as double;
      final gpaText    = kCareerPathGpaInsightTexts[careerPath] ?? '';
      final sampleN    = pathData['sampleSize'] as int? ?? 0;

      if (gpa >= avgGpa) {
        insights.add(CareerInsight(
          headline: 'Strong GPA for $careerPath',
          detail:   'Your GPA (${gpa.toStringAsFixed(2)}) exceeds the '
              '$careerPath path average ($avgGpa, n=$sampleN). $gpaText',
          category: 'gpa',
          iconName: 'school',
          severity: 'positive',
        ));
      } else {
        insights.add(CareerInsight(
          headline: 'Boost Your Profile Beyond GPA',
          detail:   'The $careerPath path average GPA is $avgGpa (n=$sampleN). '
              'Build portfolio projects and gain practical experience '
              'to strengthen your profile.',
          category: 'gpa',
          iconName: 'trending_up',
          severity: 'neutral',
        ));
      }

      insights.add(CareerInsight(
        headline: 'Predicted Success: ${avgSuccess.toStringAsFixed(1)}%',
        detail:   'Learners on the $careerPath path (n=$sampleN) achieved '
            'an average predicted job success probability of '
            '${avgSuccess.toStringAsFixed(2)}%. '
            'Active skill-building can push this higher.',
        category: 'readiness',
        iconName: 'insights',
        severity: avgSuccess >= 50.0 ? 'positive' : 'neutral',
      ));
    }

    final industry  = pathData?['recommendedIndustry'] as String? ?? 'Software';
    final reqSkills = kIndustrySkillMap[industry] ?? <String>[];
    final normOwned = ownedSkills.map(_normaliseTerm).toSet();
    final covered   =
    reqSkills.where((s) => normOwned.contains(_normaliseTerm(s)));
    final coverPct  = reqSkills.isEmpty
        ? 100.0
        : (covered.length / reqSkills.length * 100.0).clamp(0.0, 100.0);

    if (coverPct >= 70) {
      insights.add(const CareerInsight(
        headline: 'You have a strong skill foundation!',
        detail:   'You already cover over 70% of the skills employers '
            'require for your target industry. '
            'Focus on depth and certifications now.',
        category: 'skills',
        iconName: 'verified',
        severity: 'positive',
      ));
    } else if (coverPct >= 40) {
      insights.add(CareerInsight(
        headline: 'Growing skill coverage (${coverPct.toStringAsFixed(0)}%)',
        detail:   'You have a solid base. Learning '
            '${reqSkills.length - covered.length} more skills will '
            'make you highly competitive.',
        category: 'skills',
        iconName: 'auto_stories',
        severity: 'neutral',
      ));
    } else {
      insights.add(CareerInsight(
        headline: 'Skill gap detected — start learning now',
        detail:   'You currently cover ${coverPct.toStringAsFixed(0)}% '
            'of the required skills for $industry. '
            'Use the learning plan to close the gap.',
        category: 'skills',
        iconName: 'warning_amber',
        severity: 'warning',
      ));
    }

    if (matchScore >= kStrongMatchThreshold) {
      insights.add(CareerInsight(
        headline: 'Strong job match (${matchScore.toStringAsFixed(0)}%)',
        detail:   'Your profile is a strong match for current openings. '
            'Apply now and keep your profile updated.',
        category: 'readiness',
        iconName: 'workspace_premium',
        severity: 'positive',
      ));
    } else if (matchScore >= 50) {
      insights.add(CareerInsight(
        headline: 'Good match — a few skills away from excellent',
        detail:   'Adding $kPrioritySkillGapCount more skills could lift '
            'your match score above '
            '${kStrongMatchThreshold.toStringAsFixed(0)}%.',
        category: 'readiness',
        iconName: 'rocket_launch',
        severity: 'neutral',
      ));
    } else if (matchScore > 0) {
      insights.add(const CareerInsight(
        headline: 'Building your job match score',
        detail:   'Complete the recommended learning plan to improve your '
            'match score significantly.',
        category: 'readiness',
        iconName: 'pending_actions',
        severity: 'warning',
      ));
    }

    final entRelevant =
        pathData?['entrepreneurialRelevance'] as bool? ?? false;
    if (entrepreneurialExperience && entRelevant) {
      insights.add(const CareerInsight(
        headline: 'Entrepreneurial edge detected!',
        detail:   'Our dataset shows the majority of learners on this '
            'path had entrepreneurial experience. '
            'Highlight this prominently on your CV.',
        category: 'skills',
        iconName: 'emoji_events',
        severity: 'positive',
      ));
    }

    if (priorEmployment) {
      insights.add(const CareerInsight(
        headline: 'Work experience is a strong signal',
        detail:   'Learners with prior employment in our dataset show '
            'markedly higher post-graduation employment rates. '
            'Include all relevant experience on your CV.',
        category: 'readiness',
        iconName: 'work_history',
        severity: 'positive',
      ));
    }

    insights.add(const CareerInsight(
      headline: 'AI tools can boost your confidence',
      detail:   'Research shows learners who actively use AI assistants '
          'report higher job-search confidence and better interview '
          'preparation outcomes. [Xiao & Zheng, 2025]',
      category: 'readiness',
      iconName: 'smart_toy',
      severity: 'positive',
    ));

    insights.add(const CareerInsight(
      headline: 'SDG 8: Decent Work & Economic Growth',
      detail:   'SkillBridge AI is built to support UN SDG 8. '
          'Every skill you learn and every job you match contributes '
          'to reducing youth unemployment in Bangladesh and beyond.',
      category: 'sdg8',
      iconName: 'public',
      severity: 'neutral',
    ));

    return insights;
  }

  // ── §4.5  OER retrieval ────────────────────────────────────────────────────

  static Map<String, List<OpenEducationalResource>> fetchOersBySkillList(
      List<String> skills,
      ) {
    if (skills.isEmpty) return {};

    final allOers = _buildOerCatalogue();

    final result = <String, List<OpenEducationalResource>>{};
    for (final skill in skills) {
      final norm    = _normaliseTerm(skill);
      final matched = allOers.where((r) {
        final rNorm = _normaliseTerm(r.targetSkill);
        return rNorm.contains(norm) || norm.contains(rNorm);
      }).toList();
      if (matched.isNotEmpty) result[skill] = matched;
    }
    return result;
  }

  static List<OpenEducationalResource> fetchTopOersForIndustry(
      String industry, {
        int limit     = 6,
        bool freeOnly = false,
      }) {
    final skills   = kIndustrySkillMap[industry] ?? <String>[];
    final oerMap   = fetchOersBySkillList(skills);
    final flat     = oerMap.values.expand((v) => v).toList();
    final filtered =
    freeOnly ? flat.where((r) => r.isFreeAccess).toList() : flat;
    filtered.sort((a, b) => b.contentRating.compareTo(a.contentRating));
    return filtered.take(limit).toList();
  }

  // ── §4.6  Fairness audit ───────────────────────────────────────────────────

  static FairnessAuditResult auditRecommendationFairness(
      List<JobMatchCandidate> candidates,
      ) {
    if (candidates.isEmpty) {
      return const FairnessAuditResult(
        auditDiagnosticMessage: 'No candidates to audit.',
      );
    }

    final industryCount = <String, int>{};
    final tierCount     = <String, int>{};

    for (final c in candidates) {
      industryCount[c.job.industry] =
          (industryCount[c.job.industry] ?? 0) + 1;
      tierCount[c.job.experienceLevel] =
          (tierCount[c.job.experienceLevel] ?? 0) + 1;
    }

    final total   = candidates.length.toDouble();
    final indDist = industryCount.map((k, v) => MapEntry(k, v / total));
    final expDist = tierCount.map((k, v) => MapEntry(k, v / total));

    final maxFrac  = indDist.values.fold(0.0, math.max);
    final dominant = indDist.entries
        .firstWhere(
          (e) => e.value == maxFrac,
      orElse: () => const MapEntry('', 0.0),
    )
        .key;

    final passes = maxFrac <= kFairnessConcentrationCeiling;
    final msg    = passes
        ? 'Recommendation set passes diversity concentration check.'
        : 'WARNING: "$dominant" represents '
        '${(maxFrac * 100).toStringAsFixed(0)}% of results '
        '(ceiling: ${(kFairnessConcentrationCeiling * 100).toStringAsFixed(0)}%). '
        'Consider re-ranking with reRankForDiversity(). [SDG8]';

    return FairnessAuditResult(
      industryDistributionFractions:       indDist,
      experienceTierDistributionFractions: expDist,
      passesDiversityConcentrationCheck:   passes,
      auditDiagnosticMessage:              msg,
    );
  }

  static List<JobMatchCandidate> reRankForDiversity(
      List<JobMatchCandidate> candidates,
      ) {
    if (candidates.length <= 2) return candidates;

    final industryCount = <String, int>{};
    final diversified   = <JobMatchCandidate>[];

    for (final c in candidates) {
      final count   = industryCount[c.job.industry] ?? 0;
      final penalty = count * 8.0;
      final adjusted =
      (c.cosineSimilarityScore - penalty).clamp(0.0, 100.0);
      diversified.add(JobMatchCandidate(
        job:                   c.job,
        cosineSimilarityScore: adjusted,
        matchedSkills:         c.matchedSkills,
        missingSkills:         c.missingSkills,
        meetsPersonJobFit:     c.meetsPersonJobFit,
      ));
      industryCount[c.job.industry] = count + 1;
    }

    diversified.sort(
          (a, b) => b.cosineSimilarityScore.compareTo(a.cosineSimilarityScore),
    );
    return diversified;
  }

  // ── §4.7  Motivational prompt ──────────────────────────────────────────────

  static String generateMotivationalPrompt({
    required int skillGapCount,
    required double matchScore,
    required double readinessProgress,
  }) {
    if (skillGapCount == 0 && matchScore >= kStrongMatchThreshold) {
      return 'You are job-ready! Apply to your matched roles today.';
    }
    if (skillGapCount <= 2) {
      return 'You are $skillGapCount '
          'skill${skillGapCount == 1 ? "" : "s"} away from your dream job!';
    }
    if (readinessProgress >= 0.75) {
      return 'Almost there — keep going, you are in the top tier!';
    }
    if (readinessProgress >= 0.50) {
      return 'Great progress! Over halfway to your career goal.';
    }
    if (readinessProgress >= 0.25) {
      return 'Every skill you learn closes the gap. Keep it up!';
    }
    return 'Your journey starts here — take the first step today.';
  }

  // ── §4.8  RCA scorer ──────────────────────────────────────────────────────

  static double computeRcaScore(String skill, String careerPath) {
    final normSkill    = _normaliseTerm(skill);
    final pathIndustry =
        kCareerPathInsightData[careerPath]?['recommendedIndustry'] as String? ??
            'Software';
    final pathSkills =
    (kIndustrySkillMap[pathIndustry] ?? <String>[])
        .map(_normaliseTerm)
        .toList();

    final allSkills = kIndustrySkillMap.values
        .expand((list) => list.map(_normaliseTerm))
        .toList();

    final freqInPath   = pathSkills.where((s) => s == normSkill).length;
    final totalInPath  = pathSkills.length;
    final freqOverall  = allSkills.where((s) => s == normSkill).length;
    final totalOverall = allSkills.length;

    if (totalInPath == 0 || totalOverall == 0 || freqOverall == 0) return 0.0;

    final pathShare   = freqInPath  / totalInPath;
    final marketShare = freqOverall / totalOverall;

    return marketShare == 0.0 ? 0.0 : pathShare / marketShare;
  }

  // ── §4.9  Cross-domain transfer detection ─────────────────────────────────

  static List<Map<String, dynamic>> detectCrossDomainTransfer({
    required List<String> ownedSkills,
    required String targetIndustry,
  }) {
    if (ownedSkills.isEmpty) return [];

    final normOwned    = ownedSkills.map(_normaliseTerm).toSet();
    final normRequired =
    (kIndustrySkillMap[targetIndustry] ?? <String>[])
        .map(_normaliseTerm)
        .toSet();

    final direct     = normOwned.intersection(normRequired);
    final transfers  = <Map<String, dynamic>>[];
    final addedPairs = <String>{};

    for (final userSkill in normOwned) {
      if (direct.contains(userSkill)) continue;
      final bridges = kCrossDomainSkillBridges[userSkill];
      if (bridges == null) continue;

      for (final bridge in bridges) {
        final targetSkill = bridge['targetSkill'] as String;
        final thetaScore  = bridge['thetaScore']  as double;
        if (!normRequired.contains(targetSkill)) continue;
        if (thetaScore < kCrossDomainTransferMinTheta) continue;
        final key = '$userSkill→$targetSkill';
        if (!addedPairs.add(key)) continue;

        transfers.add({
          'ownedSkill':  userSkill,
          'targetSkill': targetSkill,
          'thetaScore':  thetaScore,
          'transferPct': '${(thetaScore * 100).toStringAsFixed(0)}%',
          'explanation':
          'Your ${_capitaliseTerm(userSkill)} experience transfers to '
              '${_capitaliseTerm(targetSkill)} '
              '(θ = ${thetaScore.toStringAsFixed(2)}). [Dawson21, Ajjam26]',
        });
      }
    }

    transfers.sort(
          (a, b) =>
          (b['thetaScore'] as double).compareTo(a['thetaScore'] as double),
    );
    return transfers;
  }

  // ── §4.10  Generation profiling ────────────────────────────────────────────

  static GenerationProfile? getGenerationProfile(int birthYear) {
    if (birthYear >= 1997) return kGenerationProfileMap['Gen Z'];
    if (birthYear >= 1981) return kGenerationProfileMap['Millennials'];
    if (birthYear >= 1965) return kGenerationProfileMap['Gen X'];
    if (birthYear >= 1946) return kGenerationProfileMap['Baby Boomers'];
    return null;
  }

  static String getGenerationCareerStrategies(int birthYear) {
    return getGenerationProfile(birthYear)?.careerStrategyNote ??
        'Build a strong skill profile and apply to roles aligned with '
            'UN SDG 8 — Decent Work & Economic Growth.';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// §5  HELPER UTILITIES
// ══════════════════════════════════════════════════════════════════════════════

List<OpenEducationalResource> _buildOerCatalogue() => _kRawOerCatalogue
    .map((m) => OpenEducationalResource.fromJson(Map<String, dynamic>.from(m)))
    .toList();

String _normaliseTerm(String token) => token.toLowerCase().trim();

String _capitaliseTerm(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

double _computeWeightedCosineSimilarity(Set<String> a, Set<String> b) {
  if (a.isEmpty || b.isEmpty) return 0.0;
  final intersection = a.intersection(b).length.toDouble();
  final denominator  = math.sqrt(a.length.toDouble() * b.length.toDouble());
  if (denominator == 0.0) return 0.0;
  return intersection / denominator;
}

double _computeJaccardCoefficient(Set<String> a, Set<String> b) {
  if (a.isEmpty && b.isEmpty) return 1.0;
  if (a.isEmpty || b.isEmpty) return 0.0;
  final intersection = a.intersection(b).length.toDouble();
  final union        = a.union(b).length.toDouble();
  return union == 0.0 ? 0.0 : intersection / union;
}

String _safeStr(dynamic raw, {String fallback = ''}) =>
    raw is String ? raw : fallback;

List<String> _safeStrList(dynamic raw) {
  if (raw == null) return const [];
  if (raw is List) return raw.map((e) => '$e').toList();
  return const [];
}

// ══════════════════════════════════════════════════════════════════════════════
// §6  PUBLIC CONVENIENCE ACCESSORS
// ══════════════════════════════════════════════════════════════════════════════

GuidanceInsight? findGuidanceInsightByPath(String careerPath) {
  for (final g in kGuidanceInsightsByPath) {
    if (g.careerPath == careerPath) return g;
  }
  return null;
}

List<OpenEducationalResource> get kAllOpenEducationalResources =>
    _buildOerCatalogue();

String mapStudyFieldToCareerPath(String fieldOfStudy) =>
    kStudyFieldToCareerPathMap[fieldOfStudy] ?? kDefaultCareerPath;

/// Returns a human-readable salary band for [industry].
/// Verified from [JRD] mean salary data (~$94k–$96k across all industries).
/// [JFE] salary range: $67,500–$97,500 (mean $82,546).
String getIndustrySalaryBand(String industry) {
  const Map<String, String> bands = {
    'Software':      '\$85k – \$120k / yr',
    'Finance':       '\$80k – \$115k / yr',
    'Healthcare':    '\$75k – \$110k / yr',
    'Marketing':     '\$65k – \$100k / yr',
    'Manufacturing': '\$70k – \$100k / yr',
    'Retail':        '\$55k – \$90k  / yr',
    'Education':     '\$60k – \$95k  / yr',
    'Design':        '\$70k – \$105k / yr',
  };
  return bands[industry] ?? '\$70k – \$100k / yr';
}

bool meetsPassingAssessmentThreshold(int score) =>
    score >= kPassingAssessmentScore;

double computeJaccardForSkillSets(Set<String> a, Set<String> b) =>
    _computeJaccardCoefficient(a, b);

// ══════════════════════════════════════════════════════════════════════════════
// §7  BACKWARD-COMPATIBILITY ALIASES  (@deprecated)
// ══════════════════════════════════════════════════════════════════════════════

@Deprecated('Use kMinSimilarityThreshold')
const double kMinMatchScore = kMinSimilarityThreshold;

@Deprecated('Use kStrongMatchThreshold')
const double kStrongMatchScore = kStrongMatchThreshold;

@Deprecated('Use kPassingAssessmentScore')
const int kPassingScore = kPassingAssessmentScore;

@Deprecated('Use kTopNRecommendations')
const int kTopJobsCount = kTopNRecommendations;

@Deprecated('Use kPathAverageGpaBaseline')
const double kGpaInsightThreshold = kPathAverageGpaBaseline;

@Deprecated('Use kMaxPredictedSuccessProbability')
const double kMaxSuccessProbability = kMaxPredictedSuccessProbability;

@Deprecated('Use kPrioritySkillGapCount')
const int kSkillsToTargetMatch = kPrioritySkillGapCount;

@Deprecated('Use kFairnessConcentrationCeiling')
const double kBiasConcentrationThreshold = kFairnessConcentrationCeiling;

@Deprecated('Use kExperienceTiers')
const List<String> kExperienceLevels = kExperienceTiers;

@Deprecated('Use OpenEducationalResource')
typedef LearningResource = OpenEducationalResource;

@Deprecated('Use SkillGapAnalysis')
typedef SkillGapResult = SkillGapAnalysis;

@Deprecated('Use JobMatchCandidate')
typedef JobMatchResult = JobMatchCandidate;

@Deprecated('Use FairnessAuditResult')
typedef BiasAuditResult = FairnessAuditResult;

@Deprecated('Use kCareerPathInsightData')
const Map<String, Map<String, dynamic>> kCareerPathData = kCareerPathInsightData;

@Deprecated('Use kGuidanceInsightsByPath')
const List<GuidanceInsight> kCareerGuidanceInsights = kGuidanceInsightsByPath;

@Deprecated('Use kIndustryJobRolesMap')
const Map<String, List<String>> kJobRoles = kIndustryJobRolesMap;

@Deprecated('Use kStudyFieldToCareerPathMap')
const Map<String, String> kFieldToCareerPath = kStudyFieldToCareerPathMap;

@Deprecated('Use kCareerPathGpaInsightTexts')
const Map<String, String> kGpaInsights = kCareerPathGpaInsightTexts;

@Deprecated('Use findGuidanceInsightByPath')
GuidanceInsight? guidanceInsightForPath(String careerPath) =>
    findGuidanceInsightByPath(careerPath);

@Deprecated('Use mapStudyFieldToCareerPath')
String careerPathForField(String fieldOfStudy) =>
    mapStudyFieldToCareerPath(fieldOfStudy);

@Deprecated('Use getIndustrySalaryBand')
String salaryRangeForIndustry(String industry) =>
    getIndustrySalaryBand(industry);

@Deprecated('Use meetsPassingAssessmentThreshold')
bool isPassingScore(int score) => meetsPassingAssessmentThreshold(score);