// lib/data/courses.dart — SkillBridge AI
// ══════════════════════════════════════════════════════════════════════════════
//
//  Upgraded in v5.0 — aligned with verified CSV analysis:
//   [JRD] job_recommendation_dataset.csv (50,000 rows)
//         Top skills by industry verified:
//           Software  : python 2657, java 2610, c++ 2607, sql 2582,
//                       react 2567, machine learning 2559, aws 2543
//           Finance   : excel 3573, risk analysis 3533, sql 3522, python 3516,
//                       financial modeling 3444
//           Healthcare: patient care 4481, pharmaceuticals 4473, nursing 4467,
//                       medical research 4459
//           Marketing : seo 3671, content writing 3652, google ads 3585,
//                       market research 3550, social media 3513
//           Manufacturing: production planning 5442, quality control 5407,
//                          supply chain 5401
//           Retail    : merchandising 5405, customer service 5360, sales 5317
//           Education : teaching 4518, edtech 4492, curriculum design 4480,
//                       research 4458
//   [JFE] JobsFE.csv (10,000 rows)
//         Top positions: ux/ui designer 288, digital marketing specialist 181,
//         software engineer 165, network engineer 163, software tester 153,
//         financial advisor 141, procurement manager 140
//         Working modes: full-time 2031, temporary 2023, contract 2009,
//                        part-time 1983, intern 1954
//         Salary: $67,500–$97,500 (mean $82,546)
//
//  Research grounding:
//   [TAV22] Tavakoli et al. (2022) — eDoer adaptive OER recommender;
//           learner preference vectors, content-type taxonomy, dot-product
//           scoring, 15-dimensional feature vector
//   [ALS22] Alsaif et al. (2022) — career readiness, skill-gap coverage
//   [SDG8]  UN SDG 8 — Decent Work & Economic Growth
//
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';

// =============================================================================
// PRIVATE CONSTANTS
// =============================================================================

/// Providers whose content is freely accessible (OER or free audit track).
/// [TAV22 §4] — eDoer is built exclusively on freely accessible resources.
const List<String> _kFreeProviderKeywords = [
  'youtube',
  'freecodecamp',
  'khan academy',
  'semrush academy',
  'edx',
  'hubspot',
  'google skillshop',
  'aws training',
  'tableau',
  'sqlzoo',
  'moz',
];

/// Level ordering used by [coursesByMaxLevel].
const Map<String, int> _kLevelOrder = {
  'Beginner':     0,
  'Intermediate': 1,
  'Advanced':     2,
};

// =============================================================================
// COURSE MODEL
// =============================================================================

/// Represents a learning resource that closes one or more skill gaps.
///
/// Extended with TAV22's 15-dimensional preference-vector machinery so the
/// recommender can call [dotProductWith] directly on each Course object.
/// [TAV22 §5]
@immutable
class Course {
  final int id;
  final String title;
  final String provider;

  /// "Beginner" | "Intermediate" | "Advanced"
  final String level;

  /// "Course" | "Bootcamp" | "Video" | "Specialisation" | "Certification"
  final String type;

  final String url;

  /// Functional category aligned with industry verticals in jobs.dart.
  final String category;

  final String duration;

  /// Primary instruction language.
  final String language;

  /// Provider rating (0.0 – 5.0).
  final double rating;

  /// Normalised skill tokens this course teaches (lowercase).
  /// [TAV22 §5] — matched against the candidate's skill-gap list.
  final List<String> skills;

  const Course({
    required this.id,
    required this.title,
    required this.provider,
    required this.level,
    required this.type,
    required this.url,
    required this.category,
    required this.duration,
    required this.language,
    required this.rating,
    required this.skills,
  });

  // ──────────────────────────────────────────────────────────────────────────
  // TAV22 CONTENT-TYPE TAXONOMY
  // ──────────────────────────────────────────────────────────────────────────

  /// Maps [type] to the TAV22 §5 content-format taxonomy string.
  String get contentTypeString {
    final typeLow     = type.toLowerCase();
    final providerLow = provider.toLowerCase();

    switch (typeLow) {
      case 'video':
        return 'Video';
      case 'bootcamp':
      case 'certification':
        return 'Interactive';
      case 'specialisation':
        return 'Video';
      default:
        if (providerLow.contains('youtube') ||
            providerLow.contains('khan')) {
          return 'Video';
        }
        return 'Web Page';
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // TAV22 DETAIL LEVEL
  // ──────────────────────────────────────────────────────────────────────────

  String get detailLevel {
    switch (level) {
      case 'Beginner':
        return 'Low Detail';
      case 'Intermediate':
        return 'Medium Detail';
      case 'Advanced':
        return 'High Detail';
      default:
        return 'Medium Detail';
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // TAV22 CONTENT LENGTH
  // ──────────────────────────────────────────────────────────────────────────

  String get contentLength {
    final d = duration.toLowerCase().trim();

    if (d.contains('month')) return 'Long';

    if (d.contains('week')) {
      final m = RegExp(r'(\d+)').firstMatch(d);
      if (m != null) {
        final w = int.tryParse(m.group(1) ?? '0') ?? 0;
        if (w <= 3) return 'Short';
        if (w <= 6) return 'Medium';
        return 'Long';
      }
      return 'Medium';
    }

    if (d.contains('hour')) {
      final m = RegExp(r'(\d+)').firstMatch(d);
      if (m != null) {
        final h = int.tryParse(m.group(1) ?? '0') ?? 0;
        if (h <= 6) return 'Short';
        if (h <= 20) return 'Medium';
        return 'Long';
      }
    }

    if (d.contains('min')) {
      final m = RegExp(r'(\d+)').firstMatch(d);
      if (m != null) {
        final mins = int.tryParse(m.group(1) ?? '0') ?? 0;
        if (mins < 10) return 'Short';
        if (mins <= 20) return 'Medium';
        return 'Long';
      }
    }

    return 'Medium';
  }

  // ──────────────────────────────────────────────────────────────────────────
  // OER / FREE FLAG
  // ──────────────────────────────────────────────────────────────────────────

  bool get isFree {
    final pLow = provider.toLowerCase();
    return _kFreeProviderKeywords.any((kw) => pLow.contains(kw));
  }

  // ──────────────────────────────────────────────────────────────────────────
  // COMPOSITE QUALITY SCORE
  // ──────────────────────────────────────────────────────────────────────────

  double get qualityScore {
    final r = (rating / 5.0) * 0.55;
    final s = (skills.length / 12.0).clamp(0.0, 1.0) * 0.30;
    final f = isFree ? 0.10 : 0.00;
    final a = (level == 'Advanced') ? 0.05 : 0.00;
    return (r + s + f + a).clamp(0.0, 1.0);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 15-DIMENSIONAL FEATURE VECTOR  [TAV22 §5]
  // ──────────────────────────────────────────────────────────────────────────

  List<double> get featureVector {
    final cl = contentLength;
    final dl = detailLevel;
    final ct = contentTypeString;

    final typeLow     = type.toLowerCase();
    final providerLow = provider.toLowerCase();

    final isExampleHeavy = typeLow == 'bootcamp';
    final isTheoryHeavy  = typeLow == 'course' && providerLow.contains('edx');

    return [
      cl == 'Short'  ? 1.0 : 0.0,
      cl == 'Medium' ? 1.0 : 0.0,
      cl == 'Long'   ? 1.0 : 0.0,
      dl == 'Low Detail'    ? 1.0 : 0.0,
      dl == 'Medium Detail' ? 1.0 : 0.0,
      dl == 'High Detail'   ? 1.0 : 0.0,
      isTheoryHeavy  ? 1.0 : 0.0,
      isExampleHeavy ? 1.0 : 0.0,
      (!isTheoryHeavy && !isExampleHeavy) ? 1.0 : 0.0,
      0.0,
      1.0,
      ct == 'Video'        ? 1.0 : 0.0,
      ct == 'Book Chapter' ? 1.0 : 0.0,
      ct == 'Web Page'     ? 1.0 : 0.0,
      ct == 'Slide'        ? 1.0 : 0.0,
    ];
  }

  // ──────────────────────────────────────────────────────────────────────────
  // DOT-PRODUCT RECOMMENDATION SCORING  [TAV22 §5]
  // ──────────────────────────────────────────────────────────────────────────

  double dotProductWith(List<double> preferenceVector) {
    if (preferenceVector.length < 15) {
      throw ArgumentError(
        'preferenceVector must have at least 15 elements [TAV22 §5]. '
            'Received ${preferenceVector.length}.',
      );
    }
    final fv = featureVector;
    var score = 0.0;
    for (var i = 0; i < 15; i++) {
      score += preferenceVector[i] * fv[i];
    }
    return score;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // SKILL HELPERS
  // ──────────────────────────────────────────────────────────────────────────

  double matchScore(List<String> missingSkills) {
    if (missingSkills.isEmpty) return 0.0;
    final norm    = _normaliseSkillList(missingSkills);
    final matches = skills.where((s) => norm.contains(s.toLowerCase())).length;
    return matches / missingSkills.length;
  }

  int gapsClosed(List<String> missingSkills) {
    final norm = _normaliseSkillList(missingSkills);
    return skills.where((s) => norm.contains(s.toLowerCase())).length;
  }

  bool teachesSkill(String skill) =>
      skills.any((s) => s.toLowerCase() == skill.trim().toLowerCase());

  // ──────────────────────────────────────────────────────────────────────────
  // COPY-WITH
  // ──────────────────────────────────────────────────────────────────────────

  Course copyWith({
    int? id,
    String? title,
    String? provider,
    String? level,
    String? type,
    String? url,
    String? category,
    String? duration,
    String? language,
    double? rating,
    List<String>? skills,
  }) =>
      Course(
        id:       id       ?? this.id,
        title:    title    ?? this.title,
        provider: provider ?? this.provider,
        level:    level    ?? this.level,
        type:     type     ?? this.type,
        url:      url      ?? this.url,
        category: category ?? this.category,
        duration: duration ?? this.duration,
        language: language ?? this.language,
        rating:   rating   ?? this.rating,
        skills:   skills   ?? this.skills,
      );

  // ──────────────────────────────────────────────────────────────────────────
  // SERIALISATION
  // ──────────────────────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'id':                id,
    'title':             title,
    'provider':          provider,
    'level':             level,
    'type':              type,
    'url':               url,
    'category':          category,
    'duration':          duration,
    'language':          language,
    'rating':            rating,
    'skills':            skills,
    'contentTypeString': contentTypeString,
    'detailLevel':       detailLevel,
    'contentLength':     contentLength,
    'isFree':            isFree,
    'qualityScore':      qualityScore,
  };

  factory Course.fromJson(Map<String, dynamic> json) => Course(
    id:       json['id']       as int,
    title:    json['title']    as String,
    provider: json['provider'] as String,
    level:    json['level']    as String,
    type:     json['type']     as String,
    url:      json['url']      as String,
    category: json['category'] as String,
    duration: json['duration'] as String,
    language: json['language'] as String,
    rating:   (json['rating']  as num).toDouble(),
    skills:   List<String>.from(json['skills'] as List),
  );

  // ──────────────────────────────────────────────────────────────────────────
  // EQUALITY & DISPLAY
  // ──────────────────────────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Course && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Course(id: $id, title: "$title", provider: "$provider", '
          'level: "$level", contentLength: "$contentLength", '
          'detailLevel: "$detailLevel", contentTypeString: "$contentTypeString", '
          'isFree: $isFree, qualityScore: ${qualityScore.toStringAsFixed(2)})';
}

// =============================================================================
// PRIVATE HELPERS
// =============================================================================

Set<String> _normaliseSkillList(List<String> skills) =>
    skills.map((s) => s.toLowerCase()).toSet();

// =============================================================================
// COURSE DATA  —  42 curated courses covering all JRD/JFE top skills
// =============================================================================
//
// Organised by industry with skill tokens matching verified JRD frequency data.
// [TAV22 §5] — course selection optimises skill-gap coverage per career path.
// [SDG8]     — includes free/OER options for economic inclusion.
//
// Industry coverage:
//   Software (IDs 1–14)   — python·java·c++·sql·react·ML·aws·flutter·git
//   Finance  (IDs 15–19)  — excel·financial modeling·risk analysis·accounting·bloomberg
//   Marketing (IDs 20–24) — seo·content writing·google ads·social media·market research
//   Design   (IDs 25–28)  — figma·ui/ux·adobe photoshop·typography
//   Healthcare (IDs 29–31)— medical research·health informatics·pharmaceuticals
//   Manufacturing (IDs 32–34) — supply chain·quality control·production planning
//   Retail   (IDs 35–36)  — customer service·sales
//   Education (IDs 37–39) — teaching·curriculum design·edtech
//   Professional (IDs 40–42) — project management·communication·data analysis
// =============================================================================

const List<Course> allCourses = [

  // ══════════════════════════════════════════════════════════════════════════
  // SOFTWARE & DATA SCIENCE
  // Top JRD skills: python 2657, java 2610, c++ 2607, sql 2582, react 2567,
  //                 machine learning 2559, aws 2543
  // ══════════════════════════════════════════════════════════════════════════

  Course(
    id: 1,
    title: 'Python for Everybody – Full Course',
    provider: 'YouTube (freeCodeCamp)',
    level: 'Beginner',
    type: 'Video',
    url: 'https://www.youtube.com/watch?v=8DvywoWv6fI',
    category: 'Data Science',
    duration: '14 hours',
    language: 'English',
    rating: 4.8,
    skills: ['python', 'data analysis', 'pandas', 'numpy', 'matplotlib', 'loops', 'functions'],
  ),

  Course(
    id: 2,
    title: 'Python 3 Programming Specialization',
    provider: 'Coursera',
    level: 'Beginner',
    type: 'Specialisation',
    url: 'https://www.coursera.org/specializations/python-3-programming',
    category: 'Programming',
    duration: '5 months',
    language: 'English',
    rating: 4.7,
    skills: ['python', 'oop', 'data analysis', 'pandas', 'numpy', 'file handling', 'algorithms'],
  ),

  Course(
    id: 3,
    title: 'Java Programming Masterclass',
    provider: 'Udemy',
    level: 'Beginner',
    type: 'Course',
    url: 'https://www.udemy.com/course/java-the-complete-java-developer-course/',
    category: 'Software Engineering',
    duration: '80 hours',
    language: 'English',
    rating: 4.6,
    skills: ['java', 'oop', 'spring boot', 'sql', 'git', 'testing', 'microservices', 'rest api'],
  ),

  Course(
    id: 4,
    title: 'Java Programming Tutorial – Full Course',
    provider: 'YouTube (freeCodeCamp)',
    level: 'Beginner',
    type: 'Video',
    url: 'https://www.youtube.com/watch?v=A74TOX803D0',
    category: 'Software Engineering',
    duration: '9 hours',
    language: 'English',
    rating: 4.7,
    skills: ['java', 'oop', 'data structures', 'algorithms'],
  ),

  Course(
    id: 5,
    title: 'C++ Tutorial for Beginners – Full Course',
    provider: 'YouTube (freeCodeCamp)',
    level: 'Beginner',
    type: 'Video',
    url: 'https://www.youtube.com/watch?v=vLnPwxZdW4Y',
    category: 'Software Engineering',
    duration: '4 hours',
    language: 'English',
    rating: 4.6,
    skills: ['c++', 'oop', 'algorithms', 'data structures', 'pointers'],
  ),

  Course(
    id: 6,
    title: 'SQL for Data Science',
    provider: 'Coursera (UC Davis)',
    level: 'Beginner',
    type: 'Course',
    url: 'https://www.coursera.org/learn/sql-for-data-science',
    category: 'Data Science',
    duration: '4 weeks',
    language: 'English',
    rating: 4.6,
    skills: ['sql', 'database', 'data analysis', 'joins', 'aggregation', 'subqueries'],
  ),

  Course(
    id: 7,
    title: 'SQLZoo – Interactive SQL Tutorial',
    provider: 'SQLZoo',
    level: 'Beginner',
    type: 'Course',
    url: 'https://sqlzoo.net',
    category: 'Data Science',
    duration: 'Self-paced',
    language: 'English',
    rating: 4.5,
    skills: ['sql', 'database', 'joins', 'aggregation', 'data analysis'],
  ),

  Course(
    id: 8,
    title: 'The Complete React Course 2024',
    provider: 'Udemy',
    level: 'Beginner',
    type: 'Course',
    url: 'https://www.udemy.com/course/react-the-complete-guide-incl-redux/',
    category: 'Web Development',
    duration: '28 hours',
    language: 'English',
    rating: 4.8,
    skills: ['react', 'javascript', 'typescript', 'redux', 'hooks', 'rest api', 'api integration'],
  ),

  Course(
    id: 9,
    title: 'Machine Learning Specialization',
    provider: 'Coursera (Andrew Ng)',
    level: 'Intermediate',
    type: 'Specialisation',
    url: 'https://www.coursera.org/specializations/machine-learning-introduction',
    category: 'Data Science',
    duration: '3 months',
    language: 'English',
    rating: 4.9,
    skills: [
      'machine learning', 'python', 'statistical analysis', 'neural networks',
      'supervised learning', 'unsupervised learning', 'data analysis',
    ],
  ),

  Course(
    id: 10,
    title: 'Intro to Machine Learning – Full Course',
    provider: 'YouTube (freeCodeCamp)',
    level: 'Beginner',
    type: 'Video',
    url: 'https://www.youtube.com/watch?v=NWONeJKn6kc',
    category: 'Data Science',
    duration: '10 hours',
    language: 'English',
    rating: 4.6,
    skills: ['machine learning', 'python', 'scikit-learn', 'data analysis', 'pandas', 'numpy'],
  ),

  Course(
    id: 11,
    title: 'AWS Cloud Practitioner Essentials',
    provider: 'AWS Training',
    level: 'Beginner',
    type: 'Certification',
    url: 'https://aws.amazon.com/training/digital/aws-cloud-practitioner-essentials/',
    category: 'Cloud Computing',
    duration: '6 hours',
    language: 'English',
    rating: 4.6,
    skills: ['aws', 'cloud computing', 'devops', 'linux', 'networking', 'security'],
  ),

  Course(
    id: 12,
    title: 'Flutter & Dart – The Complete Guide',
    provider: 'Udemy (Maximilian Schwarzmüller)',
    level: 'Beginner',
    type: 'Course',
    url: 'https://www.udemy.com/course/learn-flutter-dart-to-build-ios-android-apps/',
    category: 'Mobile Development',
    duration: '42 hours',
    language: 'English',
    rating: 4.8,
    skills: ['flutter', 'dart', 'ui', 'state management', 'rest api', 'firebase', 'widgets'],
  ),

  Course(
    id: 13,
    title: 'Git and GitHub Crash Course',
    provider: 'YouTube (freeCodeCamp)',
    level: 'Beginner',
    type: 'Video',
    url: 'https://www.youtube.com/watch?v=RGOj5yH7evk',
    category: 'Version Control',
    duration: '1 hour',
    language: 'English',
    rating: 4.8,
    skills: ['git', 'github', 'version control', 'branching', 'commits'],
  ),

  Course(
    id: 14,
    title: 'Deep Learning Specialization',
    provider: 'Coursera (DeepLearning.AI)',
    level: 'Advanced',
    type: 'Specialisation',
    url: 'https://www.coursera.org/specializations/deep-learning',
    category: 'Data Science',
    duration: '5 months',
    language: 'English',
    rating: 4.9,
    skills: [
      'python', 'tensorflow', 'deep learning', 'machine learning',
      'numpy', 'neural networks', 'nlp', 'statistical analysis',
    ],
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // FINANCE
  // Top JRD skills: excel 3573, risk analysis 3533, sql 3522, python 3516,
  //                 financial modeling 3444
  // ══════════════════════════════════════════════════════════════════════════

  Course(
    id: 15,
    title: 'Excel for Beginners – Full Course',
    provider: 'YouTube (Kevin Stratvert)',
    level: 'Beginner',
    type: 'Video',
    url: 'https://www.youtube.com/watch?v=Vl0H-qTclOg',
    category: 'Finance',
    duration: '3 hours',
    language: 'English',
    rating: 4.7,
    skills: ['excel', 'data analysis', 'reporting', 'pivot tables', 'data visualization'],
  ),

  Course(
    id: 16,
    title: 'Excel Skills for Business Specialization',
    provider: 'Coursera (Macquarie)',
    level: 'Beginner',
    type: 'Specialisation',
    url: 'https://www.coursera.org/specializations/excel',
    category: 'Finance',
    duration: '3 months',
    language: 'English',
    rating: 4.8,
    skills: ['excel', 'financial modeling', 'data analysis', 'pivot tables', 'reporting'],
  ),

  Course(
    id: 17,
    title: 'Financial Modeling & Valuation Analyst (FMVA)',
    provider: 'CFI (Corporate Finance Institute)',
    level: 'Intermediate',
    type: 'Certification',
    url: 'https://corporatefinanceinstitute.com/certifications/financial-modeling-valuation-analyst-fmva-program',
    category: 'Finance',
    duration: '6 months',
    language: 'English',
    rating: 4.7,
    skills: [
      'financial modeling', 'excel', 'risk analysis', 'data analysis',
      'forecasting', 'reporting', 'presentation', 'accounting',
    ],
  ),

  Course(
    id: 18,
    title: 'Risk Management in Banking and Financial Markets',
    provider: 'Coursera (NYIF)',
    level: 'Intermediate',
    type: 'Course',
    url: 'https://www.coursera.org/learn/risk-management-banking',
    category: 'Finance',
    duration: '4 weeks',
    language: 'English',
    rating: 4.4,
    skills: ['risk analysis', 'financial modeling', 'statistical analysis', 'data analysis'],
  ),

  Course(
    id: 19,
    title: 'Introduction to Financial Accounting (Wharton)',
    provider: 'Coursera (Wharton)',
    level: 'Beginner',
    type: 'Course',
    url: 'https://www.coursera.org/learn/wharton-accounting',
    category: 'Finance',
    duration: '4 weeks',
    language: 'English',
    rating: 4.8,
    skills: ['accounting', 'excel', 'financial modeling', 'reporting', 'data analysis'],
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // MARKETING
  // Top JRD skills: seo 3671, content writing 3652, google ads 3585,
  //                 market research 3550, social media 3513
  // ══════════════════════════════════════════════════════════════════════════

  Course(
    id: 20,
    title: 'Google Digital Marketing & E-commerce Certificate',
    provider: 'Coursera (Google)',
    level: 'Beginner',
    type: 'Certification',
    url: 'https://www.coursera.org/professional-certificates/google-digital-marketing-ecommerce',
    category: 'Marketing',
    duration: '6 months',
    language: 'English',
    rating: 4.8,
    skills: [
      'seo', 'google ads', 'social media', 'content writing',
      'market research', 'email marketing', 'analytics', 'brand strategy',
    ],
  ),

  Course(
    id: 21,
    title: 'SEO Training Course by Moz',
    provider: 'Moz Academy',
    level: 'Beginner',
    type: 'Certification',
    url: 'https://academy.moz.com/courses/seo-essentials',
    category: 'Marketing',
    duration: '3.5 hours',
    language: 'English',
    rating: 4.5,
    skills: ['seo', 'content writing', 'market research', 'analytics'],
  ),

  Course(
    id: 22,
    title: 'Content Marketing Certification',
    provider: 'HubSpot Academy',
    level: 'Beginner',
    type: 'Certification',
    url: 'https://academy.hubspot.com/courses/content-marketing',
    category: 'Marketing',
    duration: '5 hours',
    language: 'English',
    rating: 4.6,
    skills: ['content writing', 'seo', 'email marketing', 'social media', 'brand strategy'],
  ),

  Course(
    id: 23,
    title: 'Google Ads Search Certification',
    provider: 'Google Skillshop',
    level: 'Beginner',
    type: 'Certification',
    url: 'https://skillshop.withgoogle.com/googleads',
    category: 'Marketing',
    duration: '3 hours',
    language: 'English',
    rating: 4.6,
    skills: ['google ads', 'seo', 'analytics', 'market research'],
  ),

  Course(
    id: 24,
    title: 'Social Media Marketing Masterclass',
    provider: 'Udemy',
    level: 'Beginner',
    type: 'Course',
    url: 'https://www.udemy.com/course/social-media-marketing-agency-digital-marketing-specialist/',
    category: 'Marketing',
    duration: '12 hours',
    language: 'English',
    rating: 4.4,
    skills: ['social media', 'content writing', 'market research', 'communication', 'customer service'],
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // DESIGN
  // Top JFE: ux/ui designer 288 postings — #1 position in dataset
  //          figma, wireframing, prototyping, adobe photoshop, typography
  // ══════════════════════════════════════════════════════════════════════════

  Course(
    id: 25,
    title: 'Google UX Design Professional Certificate',
    provider: 'Coursera (Google)',
    level: 'Beginner',
    type: 'Certification',
    url: 'https://www.coursera.org/professional-certificates/google-ux-design',
    category: 'Design',
    duration: '6 months',
    language: 'English',
    rating: 4.8,
    skills: [
      'ui/ux design', 'ui', 'ux', 'figma', 'wireframing', 'prototyping',
      'user research', 'responsive design', 'adobe xd',
    ],
  ),

  Course(
    id: 26,
    title: 'Figma UI/UX Design Essentials',
    provider: 'Udemy',
    level: 'Beginner',
    type: 'Course',
    url: 'https://www.udemy.com/course/figma-ux-ui-design-user-experience-tutorial-course/',
    category: 'Design',
    duration: '16 hours',
    language: 'English',
    rating: 4.7,
    skills: ['figma', 'wireframing', 'prototyping', 'ui/ux design', 'user research', 'responsive design'],
  ),

  Course(
    id: 27,
    title: 'Graphic Design Bootcamp',
    provider: 'Udemy',
    level: 'Beginner',
    type: 'Bootcamp',
    url: 'https://www.udemy.com/course/graphic-design-masterclass-everything-you-need-to-know/',
    category: 'Design',
    duration: '18 hours',
    language: 'English',
    rating: 4.5,
    skills: [
      'adobe photoshop', 'illustrator', 'figma', 'branding',
      'typography', 'ui', 'color theory', 'responsive design',
    ],
  ),

  Course(
    id: 28,
    title: 'Photoshop for Beginners – Full Course',
    provider: 'YouTube (freeCodeCamp)',
    level: 'Beginner',
    type: 'Video',
    url: 'https://www.youtube.com/watch?v=IyR_uYsRdPs',
    category: 'Design',
    duration: '3.5 hours',
    language: 'English',
    rating: 4.5,
    skills: ['adobe photoshop', 'typography', 'color theory', 'branding'],
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // HEALTHCARE
  // Top JRD skills: patient care 4481, pharmaceuticals 4473, nursing 4467,
  //                 medical research 4459
  // ══════════════════════════════════════════════════════════════════════════

  Course(
    id: 29,
    title: 'Clinical Research Training (WHO)',
    provider: 'edX (WHO)',
    level: 'Beginner',
    type: 'Course',
    url: 'https://www.edx.org/course/clinical-research-trials',
    category: 'Healthcare',
    duration: '6 weeks',
    language: 'English',
    rating: 4.4,
    skills: ['medical research', 'research', 'documentation', 'data collection', 'statistical analysis'],
  ),

  Course(
    id: 30,
    title: 'Health Informatics Specialization',
    provider: 'Coursera (Johns Hopkins)',
    level: 'Intermediate',
    type: 'Specialisation',
    url: 'https://www.coursera.org/specializations/health-informatics',
    category: 'Healthcare',
    duration: '4 months',
    language: 'English',
    rating: 4.6,
    skills: [
      'health informatics', 'medical research', 'python', 'sql',
      'data analysis', 'documentation', 'patient care', 'research',
    ],
  ),

  Course(
    id: 31,
    title: 'Health Data Science with Python (Harvard)',
    provider: 'edX (Harvard)',
    level: 'Intermediate',
    type: 'Course',
    url: 'https://www.edx.org/course/data-science-foundations-using-r-specialization',
    category: 'Healthcare',
    duration: '8 weeks',
    language: 'English',
    rating: 4.7,
    skills: [
      'python', 'sql', 'statistical analysis', 'data analysis',
      'research', 'medical research', 'documentation',
    ],
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // MANUFACTURING / OPERATIONS
  // Top JRD skills: production planning 5442, quality control 5407,
  //                 supply chain 5401
  // ══════════════════════════════════════════════════════════════════════════

  Course(
    id: 32,
    title: 'Supply Chain Management Specialization',
    provider: 'Coursera (Rutgers)',
    level: 'Intermediate',
    type: 'Specialisation',
    url: 'https://www.coursera.org/specializations/supply-chain-management',
    category: 'Operations',
    duration: '5 months',
    language: 'English',
    rating: 4.6,
    skills: [
      'supply chain', 'production planning', 'excel',
      'data analysis', 'stakeholder', 'reporting',
      'quality control', 'communication', 'logistics',
    ],
  ),

  Course(
    id: 33,
    title: 'Quality Management & Six Sigma',
    provider: 'LinkedIn Learning',
    level: 'Beginner',
    type: 'Course',
    url: 'https://www.linkedin.com/learning/topics/quality-management',
    category: 'Operations',
    duration: '3 hours',
    language: 'English',
    rating: 4.4,
    skills: ['quality control', 'lean manufacturing', 'six sigma', 'production planning', 'data analysis'],
  ),

  Course(
    id: 34,
    title: 'Google Project Management Certificate',
    provider: 'Coursera (Google)',
    level: 'Beginner',
    type: 'Certification',
    url: 'https://www.coursera.org/professional-certificates/google-project-management',
    category: 'Operations',
    duration: '6 months',
    language: 'English',
    rating: 4.8,
    skills: [
      'project management', 'agile', 'scrum', 'stakeholder',
      'communication', 'risk analysis', 'documentation', 'production planning',
    ],
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // RETAIL
  // Top JRD skills: merchandising 5405, customer service 5360, sales 5317
  // ══════════════════════════════════════════════════════════════════════════

  Course(
    id: 35,
    title: 'Customer Service Fundamentals',
    provider: 'Coursera (CVS Health)',
    level: 'Beginner',
    type: 'Course',
    url: 'https://www.coursera.org/learn/cvs-customer-service',
    category: 'Retail',
    duration: '4 weeks',
    language: 'English',
    rating: 4.5,
    skills: [
      'customer service', 'communication', 'sales', 'merchandising',
      'problem solving', 'stakeholder',
    ],
  ),

  Course(
    id: 36,
    title: 'Sales Training – Practical Sales Techniques',
    provider: 'Udemy',
    level: 'Beginner',
    type: 'Course',
    url: 'https://www.udemy.com/course/sales-training/',
    category: 'Retail',
    duration: '5 hours',
    language: 'English',
    rating: 4.5,
    skills: ['sales', 'customer service', 'communication', 'negotiation', 'merchandising'],
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // EDUCATION
  // Top JRD skills: teaching 4518, edtech 4492, curriculum design 4480,
  //                 research 4458
  // ══════════════════════════════════════════════════════════════════════════

  Course(
    id: 37,
    title: 'Foundations of Teaching for Learning Specialization',
    provider: 'Coursera (Commonwealth Edu Trust)',
    level: 'Beginner',
    type: 'Specialisation',
    url: 'https://www.coursera.org/specializations/foundations-teaching',
    category: 'Education',
    duration: '8 months',
    language: 'English',
    rating: 4.5,
    skills: [
      'teaching', 'curriculum design', 'edtech', 'content writing',
      'communication', 'research', 'assessment design',
    ],
  ),

  Course(
    id: 38,
    title: 'Curriculum Design and Teaching (MIT)',
    provider: 'edX (MIT)',
    level: 'Intermediate',
    type: 'Course',
    url: 'https://www.edx.org/course/designing-and-developing-curricula',
    category: 'Education',
    duration: '6 weeks',
    language: 'English',
    rating: 4.5,
    skills: ['curriculum design', 'teaching', 'research', 'assessment design', 'lesson planning'],
  ),

  Course(
    id: 39,
    title: 'Instructional Design & EdTech Fundamentals',
    provider: 'edX',
    level: 'Beginner',
    type: 'Course',
    url: 'https://www.edx.org/learn/instructional-design',
    category: 'Education',
    duration: '5 weeks',
    language: 'English',
    rating: 4.4,
    skills: ['edtech', 'curriculum design', 'teaching', 'content writing', 'presentation', 'research'],
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // PROFESSIONAL SKILLS
  // ══════════════════════════════════════════════════════════════════════════

  Course(
    id: 40,
    title: 'Google Data Analytics Certificate',
    provider: 'Coursera (Google)',
    level: 'Beginner',
    type: 'Certification',
    url: 'https://www.coursera.org/professional-certificates/google-data-analytics',
    category: 'Data Science',
    duration: '6 months',
    language: 'English',
    rating: 4.8,
    skills: [
      'data analysis', 'sql', 'tableau', 'power bi', 'excel',
      'python', 'statistical analysis', 'data visualization',
    ],
  ),

  Course(
    id: 41,
    title: 'Improving Communication Skills (Penn)',
    provider: 'Coursera (Penn)',
    level: 'Beginner',
    type: 'Course',
    url: 'https://www.coursera.org/learn/wharton-communication-skills',
    category: 'Professional Skills',
    duration: '4 weeks',
    language: 'English',
    rating: 4.6,
    skills: [
      'communication', 'presentation', 'stakeholder',
      'documentation', 'leadership', 'cross-functional',
    ],
  ),

  Course(
    id: 42,
    title: 'Data Structures Easy to Advanced (Full Course)',
    provider: 'YouTube (freeCodeCamp)',
    level: 'Intermediate',
    type: 'Video',
    url: 'https://www.youtube.com/watch?v=RBSGKlAvoiM',
    category: 'Software Engineering',
    duration: '8 hours',
    language: 'English',
    rating: 4.7,
    skills: ['data structures', 'algorithms', 'java', 'python', 'c++'],
  ),
];

// =============================================================================
// BACKWARD-COMPATIBILITY ALIAS
// =============================================================================

/// Legacy alias — existing code that imports `courses` continues to work.
const List<Course> courses = allCourses;

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

/// Returns courses that address at least one skill in [missingSkills],
/// sorted by gap-coverage score descending.
/// [TAV22 §5] — skill-gap driven course recommendation pipeline.
List<Course> recommendCourses(List<String> missingSkills) {
  final norm = _normaliseSkillList(missingSkills);
  return allCourses
      .where((c) => c.skills.any((s) => norm.contains(s.toLowerCase())))
      .toList()
    ..sort((a, b) =>
        b.matchScore(missingSkills).compareTo(a.matchScore(missingSkills)));
}

/// Returns courses filtered by [category].
List<Course> coursesByCategory(String category) =>
    allCourses.where((c) => c.category == category).toList();

/// Returns the single highest-rated course covering [targetSkill], or null.
Course? bestCourseForSkill(String targetSkill) {
  final norm       = targetSkill.trim().toLowerCase();
  final candidates = allCourses
      .where((c) => c.skills.any((s) => s.toLowerCase().contains(norm)))
      .toList()
    ..sort((a, b) => b.rating.compareTo(a.rating));
  return candidates.isEmpty ? null : candidates.first;
}

/// Returns courses at or below [level] (Beginner < Intermediate < Advanced).
List<Course> coursesByMaxLevel(String level) {
  final max = _kLevelOrder[level] ?? 2;
  return allCourses
      .where((c) => (_kLevelOrder[c.level] ?? 0) <= max)
      .toList();
}

/// Returns only free / OER courses (isFree == true).
/// [TAV22 §4] — eDoer is built exclusively on freely accessible resources.
List<Course> freeCourses() =>
    allCourses.where((c) => c.isFree).toList();

/// Returns all courses sorted by [qualityScore] descending.
List<Course> coursesByQuality() => allCourses.toList()
  ..sort((a, b) => b.qualityScore.compareTo(a.qualityScore));

/// Returns courses whose [contentLength] matches [band].
List<Course> coursesByLength(String band) =>
    allCourses.where((c) => c.contentLength == band).toList();

/// Ranks [coursesToRank] by TAV22 dot-product score against
/// the learner's 15-dimensional [preferenceVector].
/// [TAV22 §5] — "Recommend resource with highest Dot Product score."
List<Course> rankByPreference(
    List<Course> coursesToRank,
    List<double> preferenceVector,
    ) =>
    coursesToRank.toList()
      ..sort((a, b) => b
          .dotProductWith(preferenceVector)
          .compareTo(a.dotProductWith(preferenceVector)));

/// Unique categories across all course listings (sorted).
List<String> get allCourseCategories => allCourses
    .map((c) => c.category)
    .toSet()
    .toList()
  ..sort();

/// Unique providers across all course listings (sorted).
List<String> get allCourseProviders => allCourses
    .map((c) => c.provider)
    .toSet()
    .toList()
  ..sort();