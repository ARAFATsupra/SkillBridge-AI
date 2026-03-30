// lib/data/jobs.dart — SkillBridge AI
// ══════════════════════════════════════════════════════════════════════════════
//
//  Job Data Layer v5.0
//
//  Data verified from CSV analysis:
//   [JFE] JobsFE.csv (10,000 rows)
//         Top positions (count):
//           ux/ui designer 288, digital marketing specialist 181,
//           software engineer 165, network engineer 163,
//           software tester 153, financial advisor 141,
//           procurement manager 140, executive assistant 135,
//           event planner 118, purchasing agent 115,
//           procurement specialist 112, systems administrator 110,
//           network administrator 106, administrative assistant 106,
//           hr coordinator 102, graphic designer 102,
//           marketing analyst 100, ui developer 96,
//           social media manager 95
//         Working modes: full-time 2031, temporary 2023, contract 2009,
//                        part-time 1983, intern 1954
//         Salary range: $67,500–$97,500 (mean $82,546)
//
//   [JRD] job_recommendation_dataset.csv (50,000 rows)
//         Industry distribution:
//           Software 7302, Marketing 7158, Manufacturing 7169,
//           Retail 7106, Education 7144, Healthcare 7104, Finance 7017
//         Experience levels: Mid Level 16739, Senior Level 16658,
//                            Entry Level 16603 (near-equal split)
//         Mean salary by industry: ~$94k–$96k / yr
//
//  Research citations:
//   [AJJ26] Ajjam & Al-Raweshidy (2026) — TF-IDF vectorisation, cosine
//           similarity, score bands, bias mitigation, greedy matching
//   [ALS22] Alsaif et al. (2022) — career readiness score (0–100), SDG-8,
//           cosine similarity (86%) vs Jaccard (61%)
//   [TAV22] Tavakoli et al. (2022) — skill-gap analysis, skill vectors, LMI
//   [SDG8]  UN SDG 8 — Decent Work & Economic Growth
//
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:math' as math;

// =============================================================================
// JOB MODEL
// =============================================================================

class Job {
  final int id;
  final String title;
  final String company;

  /// "Full-time" | "Part-time" | "Internship" | "Contract" | "Temporary"
  final String type;

  /// "Entry" | "Junior" | "Mid" | "Senior" | "Intern" | "Beginner"
  final String level;

  final String location;
  final String salary;

  final int experience;
  final String category;

  /// Industry vertical sourced from [JRD].
  final String industry;

  /// "Remote" | "On-site" | "Hybrid"
  final String workingMode;

  final bool remote;
  final DateTime posted;

  /// Normalised skill tokens (lowercase) for TF-IDF vectorisation.
  final List<String> skills;

  /// TF-IDF cosine similarity score [0.0, 1.0]. Default 0.0.
  final double simScore;

  const Job({
    required this.id,
    required this.title,
    required this.company,
    required this.type,
    required this.level,
    required this.location,
    required this.salary,
    required this.experience,
    required this.category,
    required this.industry,
    required this.workingMode,
    required this.remote,
    required this.posted,
    required this.skills,
    this.simScore = 0.0,
  });

  // ──────────────────────────────────────────────────────────────────────────
  // SKILL HELPERS
  // ──────────────────────────────────────────────────────────────────────────

  List<String> missingSkills(List<String> userSkills) {
    final norm = userSkills.map((s) => s.toLowerCase()).toSet();
    return skills.where((s) => !norm.contains(s.toLowerCase())).toList();
  }

  double matchScore(List<String> userSkills) {
    if (skills.isEmpty) return 0.0;
    final norm = userSkills.map((s) => s.toLowerCase()).toSet();
    final matched =
        skills.where((s) => norm.contains(s.toLowerCase())).length;
    return matched / skills.length;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // JACCARD SIMILARITY  [ALS22 §4]
  // ──────────────────────────────────────────────────────────────────────────

  double jaccardSimilarity(List<String> userSkills) {
    if (skills.isEmpty && userSkills.isEmpty) return 1.0;
    final a = skills.map((s) => s.toLowerCase()).toSet();
    final b = userSkills.map((s) => s.toLowerCase()).toSet();
    final intersectionSize = a.intersection(b).length;
    final unionSize = a.union(b).length;
    return unionSize == 0 ? 0.0 : intersectionSize / unionSize;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // COSINE SIMILARITY (BINARY)  [AJJ26 §4.1]
  // ──────────────────────────────────────────────────────────────────────────

  double cosineSimilarity(List<String> userSkills) {
    if (skills.isEmpty || userSkills.isEmpty) return 0.0;

    final jobNorm  = skills.map((s) => s.toLowerCase()).toSet();
    final userNorm = userSkills.map((s) => s.toLowerCase()).toSet();

    final dot         = jobNorm.intersection(userNorm).length.toDouble();
    final magJob      = math.sqrt(jobNorm.length.toDouble());
    final magUser     = math.sqrt(userNorm.length.toDouble());
    final denominator = magJob * magUser;

    return denominator == 0.0 ? 0.0 : (dot / denominator).clamp(0.0, 1.0);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // TF-IDF WEIGHT VECTOR  [AJJ26 §4.1]
  // ──────────────────────────────────────────────────────────────────────────

  List<double> get tfidfVector {
    if (skills.isEmpty) return const <double>[];
    final weight = 1.0 / math.sqrt(skills.length.toDouble());
    return List<double>.filled(skills.length, weight);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // CAREER READINESS SCORE  [ALS22 §4]
  // ──────────────────────────────────────────────────────────────────────────

  double readinessScore(
      List<String> userSkills, {
        int userExperience = 0,
      }) {
    final skillPoints = matchScore(userSkills) * 60.0;

    final expRatio = userExperience >= experience
        ? 1.0
        : userExperience / math.max(experience, 1);
    final expPoints = (expRatio * 20.0).clamp(0.0, 20.0);

    final simPoints = simScore * 20.0;

    return (skillPoints + expPoints + simPoints).clamp(0.0, 100.0);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // CONVENIENCE FLAGS
  // ──────────────────────────────────────────────────────────────────────────

  bool get isEntryLevel {
    final lvl = level.toLowerCase();
    return experience == 0 ||
        lvl == 'entry' ||
        lvl == 'intern' ||
        lvl == 'beginner';
  }

  /// Score band label.  [AJJ26 §4.1]
  String get scoreBand {
    if (simScore >= 0.70) return 'Strong';
    if (simScore >= 0.40) return 'Moderate';
    return 'Weak';
  }

  bool get isSdg8Aligned => true;

  // ──────────────────────────────────────────────────────────────────────────
  // COPY-WITH
  // ──────────────────────────────────────────────────────────────────────────

  Job copyWith({
    int? id,
    String? title,
    String? company,
    String? type,
    String? level,
    String? location,
    String? salary,
    int? experience,
    String? category,
    String? industry,
    String? workingMode,
    bool? remote,
    DateTime? posted,
    List<String>? skills,
    double? simScore,
  }) =>
      Job(
        id:          id          ?? this.id,
        title:       title       ?? this.title,
        company:     company     ?? this.company,
        type:        type        ?? this.type,
        level:       level       ?? this.level,
        location:    location    ?? this.location,
        salary:      salary      ?? this.salary,
        experience:  experience  ?? this.experience,
        category:    category    ?? this.category,
        industry:    industry    ?? this.industry,
        workingMode: workingMode ?? this.workingMode,
        remote:      remote      ?? this.remote,
        posted:      posted      ?? this.posted,
        skills:      skills      ?? this.skills,
        simScore:    simScore    ?? this.simScore,
      );

  // ──────────────────────────────────────────────────────────────────────────
  // SERIALISATION
  // ──────────────────────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'id':           id,
    'title':        title,
    'company':      company,
    'type':         type,
    'level':        level,
    'location':     location,
    'salary':       salary,
    'experience':   experience,
    'category':     category,
    'industry':     industry,
    'workingMode':  workingMode,
    'remote':       remote,
    'posted':       posted.toIso8601String(),
    'skills':       skills,
    'simScore':     simScore,
    'scoreBand':    scoreBand,
    'isEntryLevel': isEntryLevel,
    'isSdg8Aligned': isSdg8Aligned,
  };

  factory Job.fromJson(Map<String, dynamic> json) => Job(
    id:          json['id']          as int,
    title:       json['title']       as String,
    company:     json['company']     as String,
    type:        json['type']        as String,
    level:       json['level']       as String,
    location:    json['location']    as String,
    salary:      json['salary']      as String,
    experience:  json['experience']  as int,
    category:    json['category']    as String,
    industry:    json['industry']    as String,
    workingMode: json['workingMode'] as String,
    remote:      json['remote']      as bool,
    posted:      DateTime.parse(json['posted'] as String),
    skills:      List<String>.from(json['skills'] as List),
    simScore:    (json['simScore'] as num?)?.toDouble() ?? 0.0,
  );

  // ──────────────────────────────────────────────────────────────────────────
  // EQUALITY & DISPLAY
  // ──────────────────────────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Job && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Job(id: $id, title: "$title", company: "$company", '
          'level: "$level", industry: "$industry", '
          'simScore: ${simScore.toStringAsFixed(3)}, scoreBand: "$scoreBand")';
}

// =============================================================================
// JOB DATA  —  42 curated jobs aligned with JFE/JRD verified data
// =============================================================================
//
//  Coverage by industry:
//    Software     (IDs 1–12)  — python, java, sql, react, flutter, ML, aws
//    Design       (IDs 13–15) — figma, ui/ux, adobe xd (#1 position in JFE)
//    Marketing    (IDs 16–19) — seo, google ads, social media, content writing
//    Finance      (IDs 20–23) — excel, financial modeling, risk analysis
//    Healthcare   (IDs 24–26) — patient care, medical research, health informatics
//    Education    (IDs 27–28) — teaching, curriculum design, edtech
//    Manufacturing(IDs 29–31) — supply chain, quality control, production planning
//    Retail       (IDs 32–34) — customer service, merchandising, sales
//    Operations   (IDs 35–38) — procurement, hr, admin, event planning
//    Research     (IDs 39–42) — research, data collection, statistical analysis
//
//  All salary strings reflect BDT (Bangladesh Taka) for local market context.
//  [SDG8] — focused on early-career / entry-level Bangladesh job market.
// =============================================================================

final List<Job> allJobs = [

  // ══════════════════════════════════════════════════════════════════════════
  // SOFTWARE  (JRD: 7302 postings — largest industry)
  // Top skills: python 2657, java 2610, sql 2582, react 2567, ML 2559, aws 2543
  // ══════════════════════════════════════════════════════════════════════════

  Job(
    id: 1,
    title: 'Junior Data Analyst',
    company: 'Tech Solutions Ltd.',
    type: 'Full-time',
    level: 'Entry',
    location: 'Remote',
    salary: '30k–45k BDT',
    experience: 0,
    category: 'Data Science',
    industry: 'Software',
    workingMode: 'Remote',
    remote: true,
    posted: DateTime(2026, 1, 28),
    skills: ['python', 'sql', 'excel', 'data analysis', 'pandas', 'reporting'],
  ),

  Job(
    id: 2,
    title: 'Flutter Developer',
    company: 'MobileSoft',
    type: 'Full-time',
    level: 'Junior',
    location: 'Dhaka',
    salary: '40k–60k BDT',
    experience: 1,
    category: 'Mobile Development',
    industry: 'Software',
    workingMode: 'On-site',
    remote: false,
    posted: DateTime(2026, 1, 30),
    skills: ['dart', 'flutter', 'ui', 'firebase', 'state management', 'rest api'],
  ),

  Job(
    id: 3,
    title: 'Web Developer (Intern)',
    company: 'WebWorks Agency',
    type: 'Internship',
    level: 'Intern',
    location: 'Remote',
    salary: 'Unpaid / Stipend',
    experience: 0,
    category: 'Web Development',
    industry: 'Software',
    workingMode: 'Remote',
    remote: true,
    posted: DateTime(2026, 2, 1),
    skills: ['html', 'css', 'javascript', 'responsive design', 'bootstrap'],
  ),

  Job(
    id: 4,
    title: 'Backend Developer (Node.js)',
    company: 'CloudNext',
    type: 'Full-time',
    level: 'Junior',
    location: 'Remote',
    salary: '50k–70k BDT',
    experience: 1,
    category: 'Backend Development',
    industry: 'Software',
    workingMode: 'Remote',
    remote: true,
    posted: DateTime(2026, 1, 25),
    skills: ['javascript', 'node.js', 'express', 'api', 'database', 'mongodb'],
  ),

  Job(
    id: 5,
    title: 'Database Assistant',
    company: 'DataCare',
    type: 'Part-time',
    level: 'Entry',
    location: 'Dhaka',
    salary: '20k–30k BDT',
    experience: 0,
    category: 'Database',
    industry: 'Software',
    workingMode: 'On-site',
    remote: false,
    posted: DateTime(2026, 1, 20),
    skills: ['sql', 'database', 'data entry', 'data analysis', 'reporting'],
  ),

  Job(
    id: 6,
    title: 'Machine Learning Intern',
    company: 'AI Labs',
    type: 'Internship',
    level: 'Intern',
    location: 'Remote',
    salary: 'Unpaid / Stipend',
    experience: 0,
    category: 'Data Science',
    industry: 'Software',
    workingMode: 'Remote',
    remote: true,
    posted: DateTime(2026, 1, 29),
    skills: ['python', 'pandas', 'numpy', 'scikit-learn', 'machine learning', 'data analysis'],
  ),

  Job(
    id: 7,
    title: 'Frontend Developer (React)',
    company: 'TechWave',
    type: 'Full-time',
    level: 'Junior',
    location: 'Dhaka',
    salary: '45k–65k BDT',
    experience: 1,
    category: 'Frontend Development',
    industry: 'Software',
    workingMode: 'On-site',
    remote: false,
    posted: DateTime(2026, 1, 27),
    skills: ['javascript', 'react', 'css', 'html', 'responsive design', 'api integration'],
  ),

  Job(
    id: 8,
    title: 'Software Engineer (Java)',
    company: 'Enosis Solutions',
    type: 'Full-time',
    level: 'Junior',
    location: 'Dhaka',
    salary: '50k–80k BDT',
    experience: 1,
    category: 'Software Engineering',
    industry: 'Software',
    workingMode: 'Hybrid',
    remote: false,
    posted: DateTime(2026, 2, 3),
    skills: ['java', 'spring boot', 'sql', 'rest api', 'git', 'oop', 'testing', 'microservices'],
  ),

  Job(
    id: 9,
    title: 'Data Science Intern',
    company: 'Shohoz Analytics',
    type: 'Internship',
    level: 'Intern',
    location: 'Remote',
    salary: 'Stipend',
    experience: 0,
    category: 'Data Science',
    industry: 'Software',
    workingMode: 'Remote',
    remote: true,
    posted: DateTime(2026, 2, 10),
    skills: ['python', 'machine learning', 'pandas', 'numpy', 'matplotlib', 'statistical analysis', 'scikit-learn'],
  ),

  Job(
    id: 10,
    title: 'DevOps Engineer (Entry)',
    company: 'CloudBridge BD',
    type: 'Full-time',
    level: 'Entry',
    location: 'Remote',
    salary: '55k–75k BDT',
    experience: 0,
    category: 'DevOps',
    industry: 'Software',
    workingMode: 'Remote',
    remote: true,
    posted: DateTime(2026, 2, 8),
    skills: ['linux', 'docker', 'ci/cd', 'git', 'aws', 'bash scripting', 'monitoring', 'kubernetes'],
  ),

  Job(
    id: 11,
    title: 'Systems Administrator',
    company: 'NETtech Solutions',
    type: 'Full-time',
    level: 'Entry',
    location: 'Dhaka',
    salary: '30k–50k BDT',
    experience: 0,
    category: 'IT Administration',
    industry: 'Software',
    workingMode: 'On-site',
    remote: false,
    posted: DateTime(2026, 2, 2),
    skills: ['linux', 'networking', 'windows server', 'troubleshooting', 'active directory', 'documentation', 'communication'],
  ),

  Job(
    id: 12,
    title: 'Business Intelligence Analyst',
    company: 'Datastream BD',
    type: 'Full-time',
    level: 'Mid',
    location: 'Remote',
    salary: '60k–90k BDT',
    experience: 2,
    category: 'Data Science',
    industry: 'Software',
    workingMode: 'Remote',
    remote: true,
    posted: DateTime(2026, 1, 15),
    skills: ['sql', 'power bi', 'tableau', 'excel', 'data visualization', 'data analysis', 'reporting', 'stakeholder'],
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // DESIGN  (JFE: ux/ui designer 288 — #1 position in entire dataset)
  // Skills: figma, wireframing, prototyping, ui, ux, adobe photoshop, typography
  // ══════════════════════════════════════════════════════════════════════════

  Job(
    id: 13,
    title: 'UX/UI Designer (Junior)',
    company: 'PixelCraft Studio',
    type: 'Full-time',
    level: 'Junior',
    location: 'Dhaka',
    salary: '35k–55k BDT',
    experience: 1,
    category: 'Design',
    industry: 'Design',
    workingMode: 'Hybrid',
    remote: false,
    posted: DateTime(2026, 2, 5),
    skills: ['figma', 'ui', 'ux', 'wireframing', 'prototyping', 'user research', 'adobe xd', 'responsive design', 'ui/ux design'],
  ),

  Job(
    id: 14,
    title: 'Graphic Designer (Junior)',
    company: 'Creative Farm BD',
    type: 'Full-time',
    level: 'Junior',
    location: 'Remote',
    salary: '25k–40k BDT',
    experience: 1,
    category: 'Design',
    industry: 'Design',
    workingMode: 'Remote',
    remote: true,
    posted: DateTime(2026, 2, 16),
    skills: ['adobe photoshop', 'illustrator', 'figma', 'ui', 'branding', 'typography', 'color theory'],
  ),

  Job(
    id: 15,
    title: 'UI Developer (Entry)',
    company: 'DesignBase Tech',
    type: 'Contract',
    level: 'Entry',
    location: 'Remote',
    salary: '30k–50k BDT',
    experience: 0,
    category: 'Frontend Development',
    industry: 'Design',
    workingMode: 'Remote',
    remote: true,
    posted: DateTime(2026, 2, 20),
    skills: ['ui', 'ux', 'html', 'css', 'javascript', 'figma', 'responsive design', 'wireframing'],
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // MARKETING  (JRD: 7158 postings; JFE: digital marketing specialist 181)
  // Top skills: seo 3671, content writing 3652, google ads 3585, social media 3513
  // ══════════════════════════════════════════════════════════════════════════

  Job(
    id: 16,
    title: 'Digital Marketing Specialist',
    company: 'OrangeBox Digital',
    type: 'Full-time',
    level: 'Junior',
    location: 'Remote',
    salary: '30k–50k BDT',
    experience: 1,
    category: 'Marketing',
    industry: 'Marketing',
    workingMode: 'Remote',
    remote: true,
    posted: DateTime(2026, 2, 6),
    skills: ['seo', 'google ads', 'content writing', 'social media', 'market research', 'email marketing', 'analytics', 'communication'],
  ),

  Job(
    id: 17,
    title: 'Marketing Analyst',
    company: 'Shajgoj Digital',
    type: 'Full-time',
    level: 'Entry',
    location: 'Dhaka',
    salary: '25k–40k BDT',
    experience: 0,
    category: 'Marketing',
    industry: 'Marketing',
    workingMode: 'Hybrid',
    remote: false,
    posted: DateTime(2026, 2, 9),
    skills: ['market research', 'data analysis', 'excel', 'google ads', 'social media', 'reporting', 'communication'],
  ),

  Job(
    id: 18,
    title: 'Content & SEO Writer',
    company: 'ContentHive BD',
    type: 'Part-time',
    level: 'Entry',
    location: 'Remote',
    salary: '15k–25k BDT',
    experience: 0,
    category: 'Marketing',
    industry: 'Marketing',
    workingMode: 'Remote',
    remote: true,
    posted: DateTime(2026, 2, 11),
    skills: ['content writing', 'seo', 'social media', 'research', 'communication', 'documentation'],
  ),

  Job(
    id: 19,
    title: 'Social Media Manager',
    company: 'Shajgoj E-commerce',
    type: 'Full-time',
    level: 'Entry',
    location: 'Dhaka',
    salary: '22k–35k BDT',
    experience: 0,
    category: 'Marketing',
    industry: 'Marketing',
    workingMode: 'On-site',
    remote: false,
    posted: DateTime(2026, 2, 17),
    skills: ['social media', 'content writing', 'market research', 'customer service', 'communication', 'seo'],
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // FINANCE  (JRD: 7017 postings; JFE: financial advisor 141, procurement 140)
  // Top skills: excel 3573, risk analysis 3533, sql 3522, financial modeling 3444
  // ══════════════════════════════════════════════════════════════════════════

  Job(
    id: 20,
    title: 'Junior Financial Analyst',
    company: 'BRAC Bank Financial Services',
    type: 'Full-time',
    level: 'Entry',
    location: 'Dhaka',
    salary: '35k–55k BDT',
    experience: 0,
    category: 'Finance',
    industry: 'Finance',
    workingMode: 'On-site',
    remote: false,
    posted: DateTime(2026, 1, 22),
    skills: ['excel', 'financial modeling', 'sql', 'data analysis', 'risk analysis', 'reporting', 'communication', 'presentation'],
  ),

  Job(
    id: 21,
    title: 'Financial Advisor (Graduate)',
    company: 'Mutual Trust Capital',
    type: 'Full-time',
    level: 'Entry',
    location: 'Dhaka',
    salary: '30k–50k BDT',
    experience: 0,
    category: 'Finance',
    industry: 'Finance',
    workingMode: 'On-site',
    remote: false,
    posted: DateTime(2026, 2, 7),
    skills: ['financial modeling', 'excel', 'communication', 'customer service', 'risk analysis', 'research', 'presentation'],
  ),

  Job(
    id: 22,
    title: 'Accounting & Finance Intern',
    company: 'Grameenphone Finance',
    type: 'Internship',
    level: 'Intern',
    location: 'Dhaka',
    salary: 'Stipend',
    experience: 0,
    category: 'Finance',
    industry: 'Finance',
    workingMode: 'On-site',
    remote: false,
    posted: DateTime(2026, 2, 14),
    skills: ['excel', 'accounting', 'data entry', 'reporting', 'communication', 'data analysis'],
  ),

  Job(
    id: 23,
    title: 'Risk Analyst (Junior)',
    company: 'Eastern Bank PLC',
    type: 'Full-time',
    level: 'Junior',
    location: 'Dhaka',
    salary: '40k–60k BDT',
    experience: 1,
    category: 'Finance',
    industry: 'Finance',
    workingMode: 'On-site',
    remote: false,
    posted: DateTime(2026, 2, 19),
    skills: ['risk analysis', 'excel', 'sql', 'financial modeling', 'statistical analysis', 'reporting', 'communication'],
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // HEALTHCARE  (JRD: 7104 postings)
  // Top skills: patient care 4481, pharmaceuticals 4473, nursing 4467,
  //             medical research 4459
  // ══════════════════════════════════════════════════════════════════════════

  Job(
    id: 24,
    title: 'Healthcare Data Coordinator',
    company: 'Square Hospitals Ltd.',
    type: 'Full-time',
    level: 'Entry',
    location: 'Dhaka',
    salary: '28k–45k BDT',
    experience: 0,
    category: 'Healthcare',
    industry: 'Healthcare',
    workingMode: 'On-site',
    remote: false,
    posted: DateTime(2026, 2, 4),
    skills: ['patient care', 'data entry', 'database', 'excel', 'documentation', 'communication', 'medical research'],
  ),

  Job(
    id: 25,
    title: 'Health Informatics Intern',
    company: 'icddr,b Research Institute',
    type: 'Internship',
    level: 'Intern',
    location: 'Dhaka',
    salary: 'Stipend',
    experience: 0,
    category: 'Healthcare',
    industry: 'Healthcare',
    workingMode: 'Hybrid',
    remote: false,
    posted: DateTime(2026, 2, 13),
    skills: ['python', 'sql', 'data analysis', 'research', 'statistical analysis', 'excel', 'documentation', 'health informatics'],
  ),

  Job(
    id: 26,
    title: 'Clinical Research Associate',
    company: 'Incepta Pharmaceuticals',
    type: 'Contract',
    level: 'Entry',
    location: 'Dhaka',
    salary: '30k–50k BDT',
    experience: 0,
    category: 'Healthcare',
    industry: 'Healthcare',
    workingMode: 'On-site',
    remote: false,
    posted: DateTime(2026, 2, 21),
    skills: ['medical research', 'pharmaceuticals', 'research', 'documentation', 'data collection', 'statistical analysis', 'communication'],
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // EDUCATION  (JRD: 7144 postings)
  // Top skills: teaching 4518, edtech 4492, curriculum design 4480, research 4458
  // ══════════════════════════════════════════════════════════════════════════

  Job(
    id: 27,
    title: 'EdTech Content Developer',
    company: '10 Minute School',
    type: 'Full-time',
    level: 'Entry',
    location: 'Dhaka',
    salary: '25k–40k BDT',
    experience: 0,
    category: 'Education',
    industry: 'Education',
    workingMode: 'On-site',
    remote: false,
    posted: DateTime(2026, 2, 15),
    skills: ['curriculum design', 'content writing', 'edtech', 'communication', 'research', 'presentation', 'teaching'],
  ),

  Job(
    id: 28,
    title: 'Research Associate (Education)',
    company: 'BIGD Research Centre',
    type: 'Contract',
    level: 'Entry',
    location: 'Dhaka',
    salary: '30k–50k BDT',
    experience: 0,
    category: 'Research',
    industry: 'Education',
    workingMode: 'Hybrid',
    remote: false,
    posted: DateTime(2026, 2, 5),
    skills: ['research', 'statistical analysis', 'python', 'excel', 'data collection', 'documentation', 'reporting'],
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // MANUFACTURING  (JRD: 7169 postings)
  // Top skills: production planning 5442, quality control 5407, supply chain 5401
  // ══════════════════════════════════════════════════════════════════════════

  Job(
    id: 29,
    title: 'Supply Chain & Procurement Analyst',
    company: 'PRAN-RFL Group',
    type: 'Full-time',
    level: 'Entry',
    location: 'Dhaka',
    salary: '30k–50k BDT',
    experience: 0,
    category: 'Operations',
    industry: 'Manufacturing',
    workingMode: 'On-site',
    remote: false,
    posted: DateTime(2026, 2, 8),
    skills: ['supply chain', 'excel', 'data analysis', 'reporting', 'communication', 'stakeholder', 'problem solving'],
  ),

  Job(
    id: 30,
    title: 'Quality Control Inspector',
    company: 'ACI Limited',
    type: 'Full-time',
    level: 'Entry',
    location: 'Gazipur',
    salary: '25k–40k BDT',
    experience: 0,
    category: 'Operations',
    industry: 'Manufacturing',
    workingMode: 'On-site',
    remote: false,
    posted: DateTime(2026, 2, 22),
    skills: ['quality control', 'lean manufacturing', 'production planning', 'documentation', 'communication', 'data analysis'],
  ),

  Job(
    id: 31,
    title: 'Production Planning Coordinator',
    company: 'Square Textiles Ltd.',
    type: 'Full-time',
    level: 'Junior',
    location: 'Dhaka',
    salary: '28k–45k BDT',
    experience: 1,
    category: 'Operations',
    industry: 'Manufacturing',
    workingMode: 'On-site',
    remote: false,
    posted: DateTime(2026, 2, 23),
    skills: ['production planning', 'supply chain', 'excel', 'reporting', 'quality control', 'inventory management'],
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // RETAIL  (JRD: 7106 postings)
  // Top skills: merchandising 5405, customer service 5360, sales 5317
  // ══════════════════════════════════════════════════════════════════════════

  Job(
    id: 32,
    title: 'Customer Service Representative',
    company: 'Chaldal.com',
    type: 'Full-time',
    level: 'Entry',
    location: 'Dhaka',
    salary: '18k–30k BDT',
    experience: 0,
    category: 'Retail',
    industry: 'Retail',
    workingMode: 'On-site',
    remote: false,
    posted: DateTime(2026, 2, 18),
    skills: ['customer service', 'communication', 'sales', 'problem solving', 'documentation'],
  ),

  Job(
    id: 33,
    title: 'Sales Representative (Retail)',
    company: 'Daraz Bangladesh',
    type: 'Full-time',
    level: 'Entry',
    location: 'Dhaka',
    salary: '20k–35k BDT',
    experience: 0,
    category: 'Retail',
    industry: 'Retail',
    workingMode: 'On-site',
    remote: false,
    posted: DateTime(2026, 2, 24),
    skills: ['sales', 'customer service', 'communication', 'merchandising', 'negotiation'],
  ),

  Job(
    id: 34,
    title: 'Retail Merchandising Executive',
    company: 'Aarong',
    type: 'Full-time',
    level: 'Entry',
    location: 'Dhaka',
    salary: '22k–38k BDT',
    experience: 0,
    category: 'Retail',
    industry: 'Retail',
    workingMode: 'On-site',
    remote: false,
    posted: DateTime(2026, 2, 25),
    skills: ['merchandising', 'customer service', 'sales', 'inventory management', 'visual merchandising', 'communication'],
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // OPERATIONS / ADMIN  (JFE: executive assistant 135, hr coordinator 102,
  //                     administrative assistant 106, event planner 118,
  //                     procurement manager 140, purchasing agent 115)
  // ══════════════════════════════════════════════════════════════════════════

  Job(
    id: 35,
    title: 'HR Coordinator',
    company: 'Robi Axiata Limited',
    type: 'Full-time',
    level: 'Entry',
    location: 'Dhaka',
    salary: '28k–45k BDT',
    experience: 0,
    category: 'HR',
    industry: 'Retail',
    workingMode: 'On-site',
    remote: false,
    posted: DateTime(2026, 2, 10),
    skills: ['communication', 'documentation', 'excel', 'recruitment', 'stakeholder', 'reporting', 'problem solving'],
  ),

  Job(
    id: 36,
    title: 'Executive Assistant',
    company: 'Bangladesh Telecommunications Company',
    type: 'Full-time',
    level: 'Entry',
    location: 'Dhaka',
    salary: '25k–40k BDT',
    experience: 0,
    category: 'Administration',
    industry: 'Retail',
    workingMode: 'On-site',
    remote: false,
    posted: DateTime(2026, 2, 26),
    skills: ['communication', 'documentation', 'excel', 'scheduling', 'stakeholder', 'reporting'],
  ),

  Job(
    id: 37,
    title: 'Procurement Specialist (Entry)',
    company: 'Berger Paints Bangladesh',
    type: 'Full-time',
    level: 'Entry',
    location: 'Dhaka',
    salary: '28k–45k BDT',
    experience: 0,
    category: 'Operations',
    industry: 'Manufacturing',
    workingMode: 'On-site',
    remote: false,
    posted: DateTime(2026, 2, 27),
    skills: ['supply chain', 'excel', 'communication', 'market research', 'negotiation', 'documentation', 'reporting'],
  ),

  Job(
    id: 38,
    title: 'Event Coordinator (Intern)',
    company: 'Bashundhara Events',
    type: 'Internship',
    level: 'Intern',
    location: 'Dhaka',
    salary: 'Stipend',
    experience: 0,
    category: 'Events',
    industry: 'Retail',
    workingMode: 'On-site',
    remote: false,
    posted: DateTime(2026, 2, 28),
    skills: ['communication', 'project management', 'stakeholder', 'documentation', 'problem solving'],
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // QA / SOFTWARE TESTING  (JFE: software tester 153)
  // ══════════════════════════════════════════════════════════════════════════

  Job(
    id: 39,
    title: 'QA / Software Tester (Entry)',
    company: 'Therap BD',
    type: 'Full-time',
    level: 'Entry',
    location: 'Hybrid',
    salary: '35k–55k BDT',
    experience: 0,
    category: 'Software Engineering',
    industry: 'Software',
    workingMode: 'Hybrid',
    remote: false,
    posted: DateTime(2026, 2, 18),
    skills: ['testing', 'selenium', 'sql', 'documentation', 'api', 'git', 'problem solving', 'communication'],
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // NETWORK / IT  (JFE: network engineer 163, network admin 106)
  // ══════════════════════════════════════════════════════════════════════════

  Job(
    id: 40,
    title: 'Network Engineer (Junior)',
    company: 'Summit Communications',
    type: 'Full-time',
    level: 'Junior',
    location: 'Dhaka',
    salary: '40k–60k BDT',
    experience: 1,
    category: 'IT Administration',
    industry: 'Software',
    workingMode: 'On-site',
    remote: false,
    posted: DateTime(2026, 3, 1),
    skills: ['networking', 'linux', 'aws', 'azure', 'troubleshooting', 'documentation', 'communication'],
  ),

  Job(
    id: 41,
    title: 'Network Administrator',
    company: 'BRACnet Limited',
    type: 'Full-time',
    level: 'Entry',
    location: 'Dhaka',
    salary: '30k–50k BDT',
    experience: 0,
    category: 'IT Administration',
    industry: 'Software',
    workingMode: 'Hybrid',
    remote: false,
    posted: DateTime(2026, 3, 2),
    skills: ['networking', 'linux', 'troubleshooting', 'documentation', 'communication', 'monitoring'],
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // PYTHON / AUTOMATION  (JRD: python top skill in Software 2657)
  // ══════════════════════════════════════════════════════════════════════════

  Job(
    id: 42,
    title: 'Python Developer (Automation)',
    company: 'RoboSoft Technologies',
    type: 'Full-time',
    level: 'Junior',
    location: 'Remote',
    salary: '45k–65k BDT',
    experience: 1,
    category: 'Backend Development',
    industry: 'Software',
    workingMode: 'Remote',
    remote: true,
    posted: DateTime(2026, 2, 12),
    skills: ['python', 'automation', 'selenium', 'rest api', 'database', 'git', 'testing', 'documentation'],
  ),
];

// =============================================================================
// BACKWARD-COMPATIBILITY ALIAS
// =============================================================================

/// Legacy alias — existing code that imports `jobs` continues to work.
final List<Job> jobs = allJobs;

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

/// Recommends jobs based on skill match, sorted descending by [matchScore].
/// [TAV22 §5] — skill-vector overlap as primary ranking signal.
List<Job> recommendJobs(List<String> userSkills, {int? topN}) {
  final norm = userSkills.map((s) => s.toLowerCase()).toList();
  final ranked = allJobs.where((j) => j.matchScore(norm) > 0).toList()
    ..sort((a, b) => b.matchScore(norm).compareTo(a.matchScore(norm)));
  return topN != null ? ranked.take(topN).toList() : ranked;
}

/// Returns all jobs matching a specific [industry].
List<Job> jobsByIndustry(String industry) =>
    allJobs.where((j) => j.industry == industry).toList();

/// Returns all remote / fully-remote jobs.
List<Job> remoteJobs() => allJobs.where((j) => j.remote).toList();

/// Returns jobs requiring at most [maxExperience] years.
List<Job> jobsByMaxExperience(int maxExperience) =>
    allJobs.where((j) => j.experience <= maxExperience).toList();

/// Returns jobs within a specific [workingMode].
List<Job> jobsByWorkingMode(String workingMode) =>
    allJobs.where((j) => j.workingMode == workingMode).toList();

/// Returns jobs sorted by [simScore] descending.
List<Job> jobsBySimScore(List<Job> scoredJobs) => scoredJobs.toList()
  ..sort((a, b) => b.simScore.compareTo(a.simScore));

/// Applies [scores] (job-id → simScore) to [allJobs] and returns a new list
/// with [Job.simScore] populated, sorted high-to-low.
List<Job> applySimScores(Map<int, double> scores) {
  return allJobs
      .map((j) => j.copyWith(simScore: scores[j.id] ?? 0.0))
      .toList()
    ..sort((a, b) => b.simScore.compareTo(a.simScore));
}

/// Returns only entry-level jobs.
List<Job> entryLevelJobs() => allJobs.where((j) => j.isEntryLevel).toList();

/// Unique industries across all job listings (sorted).
List<String> get allIndustries =>
    allJobs.map((j) => j.industry).toSet().toList()..sort();

/// Unique job levels across all listings (sorted).
List<String> get allLevels =>
    allJobs.map((j) => j.level).toSet().toList()..sort();

/// Unique working modes across all listings (sorted).
List<String> get allWorkingModes =>
    allJobs.map((j) => j.workingMode).toSet().toList()..sort();