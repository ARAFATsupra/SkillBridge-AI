// lib/services/app_state.dart — SkillBridge AI
//
// Central state manager — Provider / ChangeNotifier pattern.
//
// Research grounding:
//   [TAV22] Tavakoli et al. (2022) — eDoer: 15-dim learner preference
//           vector, short/long-term update algorithm (§3.5.1).
//   [ALS22] Alsaif et al. (2022) — Learning-Based JRS: career readiness
//           scoring, weighted skill vectors, SDG-8 alignment (§4).
//   [AJJ26] Ajjam & Al-Raweshidy (2026) — TF-IDF/cosine semantic
//           similarity job-matching framework (§3–4).
//   [LH22]  Li Huang (2022) — Employment intention evolution tracker.
//   [XZ25]  Xiao & Zheng (2025) — Confidence self-assessment model.
//   [ZC22]  Zhisheng Chen (2022) — Recommender fairness monitor.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/courses.dart' show Course;
import '../data/jobs.dart' show Job;
import '../models/career_profile.dart';
import 'api_service.dart'
    show ApiException, ApiService, PredictionRequest, PredictionResult;

// =============================================================================
// PREFERENCE-KEY CONSTANTS  [TAV22 §3.5.1, Table 4]
// =============================================================================

class PreferenceKeys {
  PreferenceKeys._();

  static const String lengthShort  = 'length_short';
  static const String lengthMedium = 'length_medium';
  static const String lengthLong   = 'length_long';

  static const String detailLow    = 'detail_low';
  static const String detailMedium = 'detail_medium';
  static const String detailHigh   = 'detail_high';

  static const String strategyTheory  = 'strategy_theory';
  static const String strategyExample = 'strategy_example';
  static const String strategyBoth    = 'strategy_both';

  static const String classBased    = 'class_based';
  static const String nonClassBased = 'non_class_based';

  static const String contentVideo   = 'content_video';
  static const String contentBook    = 'content_book';
  static const String contentWebpage = 'content_webpage';
  static const String contentSlide   = 'content_slide';

  static const List<String> allKeys = [
    lengthShort,  lengthMedium,  lengthLong,
    detailLow,    detailMedium,  detailHigh,
    strategyTheory, strategyExample, strategyBoth,
    classBased,   nonClassBased,
    contentVideo, contentBook,   contentWebpage, contentSlide,
  ];

  static Map<String, double> get defaultVector =>
      {for (final k in allKeys) k: 0.5};
}

// =============================================================================
// CONFIDENCE CATEGORY KEYS  [XZ25]
// =============================================================================

class ConfidenceKeys {
  ConfidenceKeys._();

  static const String technical     = 'technical';
  static const String jobSearch     = 'jobSearch';
  static const String interview     = 'interview';
  static const String communication = 'communication';
  static const String salary        = 'salary';

  static const List<String> all = [
    technical, jobSearch, interview, communication, salary,
  ];

  static Map<String, double> get defaults =>
      {for (final k in all) k: 0.5};
}

// =============================================================================
// LEARNER PREFERENCES  [TAV22 §3.5.1]
// =============================================================================

@immutable
class LearnerPreferences {
  final Map<String, double> longTermVector;
  final Map<String, double> shortTermVector;
  final Map<String, int>    shortTermCounts;

  const LearnerPreferences({
    required this.longTermVector,
    required this.shortTermVector,
    required this.shortTermCounts,
  });

  factory LearnerPreferences.defaults() => LearnerPreferences(
    longTermVector:  PreferenceKeys.defaultVector,
    shortTermVector: const {},
    shortTermCounts: const {},
  );

  double scoreContent(Map<String, double> courseFeatureVector) {
    var score = 0.0;
    for (final entry in courseFeatureVector.entries) {
      score += (longTermVector[entry.key] ?? 0.5) * entry.value;
    }
    return score;
  }

  LearnerPreferences copyWith({
    Map<String, double>? longTermVector,
    Map<String, double>? shortTermVector,
    Map<String, int>?    shortTermCounts,
  }) =>
      LearnerPreferences(
        longTermVector:  longTermVector  ?? this.longTermVector,
        shortTermVector: shortTermVector ?? this.shortTermVector,
        shortTermCounts: shortTermCounts ?? this.shortTermCounts,
      );

  Map<String, dynamic> toJson() => {
    'longTermVector':  longTermVector,
    'shortTermVector': shortTermVector,
    'shortTermCounts': shortTermCounts,
  };

  factory LearnerPreferences.fromJson(Map<String, dynamic> json) =>
      LearnerPreferences(
        longTermVector: _toDoubleMap(json['longTermVector'],
            fallback: PreferenceKeys.defaultVector),
        shortTermVector: _toDoubleMap(json['shortTermVector'], fallback: {}),
        shortTermCounts: _toIntMap(json['shortTermCounts'],    fallback: {}),
      );

  static Map<String, double> _toDoubleMap(
      dynamic raw, {
        required Map<String, double> fallback,
      }) {
    if (raw is Map) {
      try {
        return raw.map((k, v) =>
            MapEntry(k.toString(), (v as num).toDouble()));
      } catch (_) {}
    }
    return Map.from(fallback);
  }

  static Map<String, int> _toIntMap(
      dynamic raw, {
        required Map<String, int> fallback,
      }) {
    if (raw is Map) {
      try {
        return raw.map((k, v) =>
            MapEntry(k.toString(), (v as num).toInt()));
      } catch (_) {}
    }
    return Map.from(fallback);
  }
}

// =============================================================================
// EMPLOYMENT INTENTION  [LH22]
// =============================================================================

enum EmploymentIntention {
  studyAbroad,
  furtherEducation,
  employment,
  undecided,
}

extension EmploymentIntentionX on EmploymentIntention {
  String get label {
    switch (this) {
      case EmploymentIntention.studyAbroad:      return 'Study Abroad';
      case EmploymentIntention.furtherEducation: return 'Further Education';
      case EmploymentIntention.employment:       return 'Employment';
      case EmploymentIntention.undecided:        return 'Undecided';
    }
  }

  String get emoji {
    switch (this) {
      case EmploymentIntention.studyAbroad:      return '✈️';
      case EmploymentIntention.furtherEducation: return '🎓';
      case EmploymentIntention.employment:       return '💼';
      case EmploymentIntention.undecided:        return '🤔';
    }
  }

  static EmploymentIntention fromString(String s) =>
      EmploymentIntention.values.firstWhere(
            (e) => e.name == s,
        orElse: () => EmploymentIntention.undecided,
      );
}

@immutable
class IntentionEntry {
  final DateTime            date;
  final EmploymentIntention intention;
  final String?             note;
  final double?             confidenceLevel;

  const IntentionEntry({
    required this.date,
    required this.intention,
    this.note,
    this.confidenceLevel,
  });

  Map<String, dynamic> toJson() => {
    'date':      date.toIso8601String(),
    'intention': intention.name,
    if (note != null)            'note': note,
    if (confidenceLevel != null) 'confidenceLevel': confidenceLevel,
  };

  factory IntentionEntry.fromJson(Map<String, dynamic> json) =>
      IntentionEntry(
        date:            DateTime.parse(json['date'] as String),
        intention:       EmploymentIntentionX.fromString(
            json['intention'] as String),
        note:            json['note'] as String?,
        confidenceLevel: (json['confidenceLevel'] as num?)?.toDouble(),
      );
}

@immutable
class IntentionTracker {
  final List<IntentionEntry> entries;

  const IntentionTracker({required this.entries});

  factory IntentionTracker.empty() => const IntentionTracker(entries: []);

  EmploymentIntention? get currentIntention =>
      entries.isEmpty ? null : entries.last.intention;

  double? get latestConfidence =>
      entries.isEmpty ? null : entries.last.confidenceLevel;

  String? get latestNote =>
      entries.isEmpty ? null : entries.last.note;

  int get distinctIntentionCount =>
      entries.map((e) => e.intention).toSet().length;

  IntentionTracker withEntry(IntentionEntry entry) =>
      IntentionTracker(entries: [...entries, entry]);

  Map<String, dynamic> toJson() => {
    'entries': entries.map((e) => e.toJson()).toList(),
  };

  factory IntentionTracker.fromJson(Map<String, dynamic> json) {
    final raw = json['entries'] as List<dynamic>? ?? [];
    return IntentionTracker(
      entries: raw
          .map((e) => IntentionEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// =============================================================================
// APPLICATION STATUS
// =============================================================================

enum ApplicationStatus {
  applied,
  screening,
  interview,
  offer,
  rejected,
  withdrawn,
}

extension ApplicationStatusX on ApplicationStatus {
  String get label {
    switch (this) {
      case ApplicationStatus.applied:   return 'Applied';
      case ApplicationStatus.screening: return 'Screening';
      case ApplicationStatus.interview: return 'Interview';
      case ApplicationStatus.offer:     return 'Offer';
      case ApplicationStatus.rejected:  return 'Rejected';
      case ApplicationStatus.withdrawn: return 'Withdrawn';
    }
  }

  static ApplicationStatus fromString(String s) =>
      ApplicationStatus.values.firstWhere(
            (e) =>
        e.name.toLowerCase()  == s.toLowerCase() ||
            e.label.toLowerCase() == s.toLowerCase(),
        orElse: () => ApplicationStatus.applied,
      );
}

// =============================================================================
// SHARED PREFS KEYS
// =============================================================================

class _PK {
  _PK._();
  static const String isLoggedIn         = 'isLoggedIn';
  static const String userName           = 'userName';
  static const String userEmail          = 'userEmail';
  static const String currentUserId      = 'currentUserId';
  static const String fieldOfStudy       = 'fieldOfStudy';
  static const String gpa                = 'gpa';
  static const String careerGoal         = 'careerGoal';
  static const String experienceLevel    = 'experienceLevel';
  static const String yearOfStudy        = 'yearOfStudy';
  static const String userSkills         = 'userSkills';
  static const String savedJobIds        = 'savedJobIds';
  static const String jobsMatchedCount   = 'jobsMatchedCount';
  static const String lastIndustryFilter = 'lastIndustryFilter';
  static const String lastLevelFilter    = 'lastLevelFilter';
  static const String completedCourseIds = 'completedCourseIds';
  static const String enrolledCourseIds  = 'enrolledCourseIds';
  static const String learningStreak     = 'learningStreak';
  static const String longestStreak      = 'longestStreak';
  static const String lastLearningDate   = 'lastLearningDate';
  static const String totalStudyMinutes  = 'totalStudyMinutes';
  static const String cvFileName         = 'cvFileName';
  static const String cvUploaded         = 'cvUploaded';
  static const String cvRawText          = 'cvRawText';
  static const String quizScores         = 'quizScores';
  static const String completedTopics    = 'completedTopics';
  static const String learningHistory    = 'learningHistory';
  static const String readinessScore     = 'readinessScore';
  static const String learnerPreferences = 'learnerPreferences';
  static const String intentionTracker   = 'intentionTracker';
  static const String confidenceScores   = 'confidenceScores';
  static const String confidenceHistory  = 'confidenceHistory';
  static const String jobApplications    = 'jobApplications';
  static const String jobAlerts          = 'jobAlerts';
  static const String skillTrends        = 'skillTrends';
  static const String fairnessScore      = 'fairnessScore';
  static const String themeMode          = 'themeMode';
}

// =============================================================================
// APP STATE
// =============================================================================

class AppState extends ChangeNotifier {
  // ── Auth ──────────────────────────────────────────────────────────────────
  bool    _isLoggedIn    = false;
  String  _userName      = '';
  String  _userEmail     = '';
  String? _currentUserId;

  // ── Career Profile ────────────────────────────────────────────────────────
  CareerProfile? _careerProfile;
  String _fieldOfStudy    = '';
  double _gpa             = 0.0;
  String _careerGoal      = '';
  String _experienceLevel = 'none';
  int    _yearOfStudy     = 1;

  // ── Skills ────────────────────────────────────────────────────────────────
  List<String> _userSkills = [];

  // ── Recommendations (local ML layer) ─────────────────────────────────────
  List<Job>    _recommendedJobs    = [];
  List<Course> _recommendedCourses = [];

  // ── API prediction state ──────────────────────────────────────────────── NEW
  PredictionResult? _lastPredictionResult;
  List<String>      _skillsGap             = [];
  List<double>      _predictionConfidences = [];

  // ── Job tracking ──────────────────────────────────────────────────────────
  Set<int> _savedJobIds        = {};
  int      _jobsMatchedCount   = 0;
  String   _lastIndustryFilter = '';
  String   _lastLevelFilter    = '';

  // ── Course tracking ───────────────────────────────────────────────────────
  Set<int> _completedCourseIds = {};
  Set<int> _enrolledCourseIds  = {};

  // ── Learning streak ───────────────────────────────────────────────────────
  int    _learningStreak    = 0;
  int    _longestStreak     = 0;
  String _lastLearningDate  = '';
  int    _totalStudyMinutes = 0;

  // ── CV ────────────────────────────────────────────────────────────────────
  String _cvFileName = '';
  String _cvRawText  = '';
  bool   _cvUploaded = false;

  // ── Quiz / assessment ─────────────────────────────────────────────────────
  Map<String, int> _quizScores      = {};
  List<String>     _completedTopics = [];

  // ── Learning history ──────────────────────────────────────────────────────
  List<String> _learningHistory = [];

  // ── Readiness score ───────────────────────────────────────────────────────
  int _readinessScore = 0;

  // ── UI state ──────────────────────────────────────────────────────────────
  bool    _isLoading    = false;
  String? _errorMessage;

  // ── Theme ─────────────────────────────────────────────────────────────────
  ThemeMode _themeMode = ThemeMode.system;

  // ── [TAV22] Learner preference vector ────────────────────────────────────
  LearnerPreferences _learnerPreferences = LearnerPreferences.defaults();

  // ── [LH22] Employment intention tracker ──────────────────────────────────
  IntentionTracker _intentionTracker = IntentionTracker.empty();

  // ── [XZ25] Confidence scores per category (0.0 – 1.0) ───────────────────
  Map<String, double>        _confidenceScores   = ConfidenceKeys.defaults;
  List<Map<String, dynamic>> _confidenceHistory  = [];

  // ── Application tracker ───────────────────────────────────────────────────
  List<Map<String, dynamic>> _jobApplications = [];

  // ── Job alerts ────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _jobAlerts = [];

  // ── Skill trends cache ────────────────────────────────────────────────────
  List<Map<String, dynamic>> _skillTrends = [];

  // ── [ZC22] Fairness score (0.0 – 1.0) ────────────────────────────────────
  double _fairnessScore = 1.0;

  Timer? _saveDebounce;

  // ==========================================================================
  // GETTERS — AUTH
  // ==========================================================================

  bool    get isLoggedIn       => _isLoggedIn;
  String  get userName         => _userName;
  String  get userEmail        => _userEmail;
  String? get currentUserId    => _currentUserId;
  String? get currentUserEmail => _userEmail.isEmpty ? null : _userEmail;

  // ==========================================================================
  // GETTERS — PROFILE
  // ==========================================================================

  CareerProfile? get careerProfile   => _careerProfile;
  String         get fieldOfStudy    => _fieldOfStudy;
  double         get gpa             => _gpa;
  String         get careerGoal      => _careerGoal;
  String         get experienceLevel => _experienceLevel;
  int            get yearOfStudy     => _yearOfStudy;
  String         get cvFileName      => _cvFileName;
  String         get cvRawText       => _cvRawText;
  bool           get cvUploaded      => _cvUploaded;

  int get experienceYears {
    switch (_experienceLevel) {
      case 'internship': return 0;
      case 'part-time':  return 1;
      case 'full-time':  return 2;
      default:           return 0;
    }
  }

  // ==========================================================================
  // GETTERS — SKILLS
  // ==========================================================================

  List<String> get userSkills => List.unmodifiable(_userSkills);

  int get skillsMissingCount {
    const avgJobSkillCount = 6;
    return (avgJobSkillCount - _userSkills.length.clamp(0, avgJobSkillCount))
        .clamp(0, avgJobSkillCount);
  }

  // ==========================================================================
  // GETTERS — RECOMMENDATIONS (local ML layer)
  // ==========================================================================

  List<Job>    get recommendedJobs    => List.unmodifiable(_recommendedJobs);
  List<Course> get recommendedCourses => List.unmodifiable(_recommendedCourses);

  // ==========================================================================
  // GETTERS — API PREDICTION STATE                                      ── NEW
  // ==========================================================================

  /// The full typed result from the last successful /predict call.
  /// Null if no prediction has been made this session.
  PredictionResult? get lastPredictionResult => _lastPredictionResult;

  /// Skills the user is missing, as returned by the backend.
  List<String> get skillsGap =>
      List.unmodifiable(_skillsGap);

  /// Per-job confidence scores (0.0 – 1.0) from the backend.
  List<double> get predictionConfidences =>
      List.unmodifiable(_predictionConfidences);

  /// True when a non-empty prediction result is held in state.
  bool get hasPredictionResult =>
      _lastPredictionResult?.isNotEmpty ?? false;

  /// Highest confidence value from the last prediction, or null.
  double? get topPredictionConfidence =>
      _lastPredictionResult?.topConfidence;

  // ==========================================================================
  // GETTERS — JOB TRACKING
  // ==========================================================================

  Set<int> get savedJobIds        => Set.unmodifiable(_savedJobIds);
  int      get jobsMatchedCount   => _jobsMatchedCount;
  String   get lastIndustryFilter => _lastIndustryFilter;
  String   get lastLevelFilter    => _lastLevelFilter;
  bool isJobSaved(int id)         => _savedJobIds.contains(id);

  // ==========================================================================
  // GETTERS — COURSE TRACKING
  // ==========================================================================

  Set<int> get completedCourseIds => Set.unmodifiable(_completedCourseIds);
  Set<int> get enrolledCourseIds  => Set.unmodifiable(_enrolledCourseIds);
  int      get completedCount     => _completedCourseIds.length;
  bool isCourseCompleted(int id)  => _completedCourseIds.contains(id);
  bool isCourseEnrolled(int id)   => _enrolledCourseIds.contains(id);

  // ==========================================================================
  // GETTERS — STREAK & STUDY TIME
  // ==========================================================================

  int get learningStreak    => _learningStreak;
  int get longestStreak     => _longestStreak;
  int get totalStudyMinutes => _totalStudyMinutes;

  // ==========================================================================
  // GETTERS — QUIZ
  // ==========================================================================

  Map<String, int> get quizScores      => Map.unmodifiable(_quizScores);
  List<String>     get completedTopics => List.unmodifiable(_completedTopics);
  bool isTopicCompleted(String key)    => _completedTopics.contains(key);

  // ==========================================================================
  // GETTERS — LEARNING HISTORY
  // ==========================================================================

  List<String> get learningHistory => List.unmodifiable(_learningHistory);

  // ==========================================================================
  // GETTERS — UI
  // ==========================================================================

  bool      get isLoading    => _isLoading;
  String?   get errorMessage => _errorMessage;
  ThemeMode get themeMode    => _themeMode;

  // ==========================================================================
  // GETTERS — READINESS & PROFILE COMPLETION
  // ==========================================================================

  int get readinessScore => _readinessScore;

  int get profileCompletionPercent {
    var s = 0;
    if (_userName.isNotEmpty)     s += 15;
    if (_userEmail.isNotEmpty)    s += 10;
    if (_fieldOfStudy.isNotEmpty) s += 15;
    if (_gpa > 0)                 s += 10;
    if (_userSkills.isNotEmpty)   s += 20;
    if (_careerGoal.isNotEmpty)   s += 15;
    if (_cvUploaded)              s += 15;
    return s.clamp(0, 100);
  }

  // ==========================================================================
  // GETTERS — [TAV22] LEARNER PREFERENCES
  // ==========================================================================

  LearnerPreferences get learnerPreferences => _learnerPreferences;

  // ==========================================================================
  // GETTERS — [LH22] INTENTION
  // ==========================================================================

  IntentionTracker     get intentionTracker => _intentionTracker;
  EmploymentIntention? get currentIntention =>
      _intentionTracker.currentIntention;

  // ==========================================================================
  // GETTERS — [XZ25] CONFIDENCE
  // ==========================================================================

  Map<String, double> get confidenceScores =>
      Map.unmodifiable(_confidenceScores);

  List<Map<String, dynamic>> get confidenceHistory =>
      List.unmodifiable(_confidenceHistory);

  double get overallConfidenceScore {
    if (_confidenceScores.isEmpty) return 0.5;
    return _confidenceScores.values.fold(0.0, (s, v) => s + v) /
        _confidenceScores.length;
  }

  // ==========================================================================
  // GETTERS — APPLICATIONS
  // ==========================================================================

  List<Map<String, dynamic>> get jobApplications =>
      List.unmodifiable(_jobApplications);

  int get activeApplicationCount => _jobApplications.where((a) {
    final status = (a['status'] as String? ?? '').toLowerCase();
    return status != 'rejected' && status != 'withdrawn';
  }).length;

  // ==========================================================================
  // GETTERS — ALERTS
  // ==========================================================================

  List<Map<String, dynamic>> get jobAlerts =>
      List.unmodifiable(_jobAlerts);

  List<Map<String, dynamic>> get activeJobAlerts =>
      _jobAlerts.where((a) => a['isActive'] == true).toList();

  // ==========================================================================
  // GETTERS — SKILL TRENDS
  // ==========================================================================

  List<Map<String, dynamic>> get skillTrends =>
      List.unmodifiable(_skillTrends);

  // ==========================================================================
  // GETTERS — [ZC22] FAIRNESS
  // ==========================================================================

  double get fairnessScore => _fairnessScore;

  bool get isDark => _themeMode == ThemeMode.dark;

  // ==========================================================================
  // INIT — load persisted state
  // ==========================================================================

  Future<void> loadFromPrefs() async {
    _setLoading(true);
    try {
      final prefs = await SharedPreferences.getInstance();

      _isLoggedIn    = prefs.getBool(_PK.isLoggedIn)     ?? false;
      _userName      = prefs.getString(_PK.userName)     ?? '';
      _userEmail     = prefs.getString(_PK.userEmail)    ?? '';
      _currentUserId = prefs.getString(_PK.currentUserId);

      _fieldOfStudy    = prefs.getString(_PK.fieldOfStudy)    ?? '';
      _gpa             = prefs.getDouble(_PK.gpa)             ?? 0.0;
      _careerGoal      = prefs.getString(_PK.careerGoal)      ?? '';
      _experienceLevel = prefs.getString(_PK.experienceLevel) ?? 'none';
      _yearOfStudy     = prefs.getInt(_PK.yearOfStudy)        ?? 1;
      _userSkills      = prefs.getStringList(_PK.userSkills)  ?? [];

      _savedJobIds =
          _intSetFromPrefs(prefs.getStringList(_PK.savedJobIds));
      _jobsMatchedCount   = prefs.getInt(_PK.jobsMatchedCount)      ?? 0;
      _lastIndustryFilter = prefs.getString(_PK.lastIndustryFilter) ?? '';
      _lastLevelFilter    = prefs.getString(_PK.lastLevelFilter)    ?? '';

      _completedCourseIds =
          _intSetFromPrefs(prefs.getStringList(_PK.completedCourseIds));
      _enrolledCourseIds =
          _intSetFromPrefs(prefs.getStringList(_PK.enrolledCourseIds));

      _learningStreak    = prefs.getInt(_PK.learningStreak)       ?? 0;
      _longestStreak     = prefs.getInt(_PK.longestStreak)        ?? 0;
      _lastLearningDate  = prefs.getString(_PK.lastLearningDate)  ?? '';
      _totalStudyMinutes = prefs.getInt(_PK.totalStudyMinutes)    ?? 0;

      _cvFileName = prefs.getString(_PK.cvFileName) ?? '';
      _cvRawText  = prefs.getString(_PK.cvRawText)  ?? '';
      _cvUploaded = prefs.getBool(_PK.cvUploaded)   ?? false;

      _quizScores      = _decodeIntMap(prefs.getString(_PK.quizScores));
      _completedTopics = prefs.getStringList(_PK.completedTopics) ?? [];

      _learningHistory = prefs.getStringList(_PK.learningHistory) ?? [];
      _readinessScore  = prefs.getInt(_PK.readinessScore) ?? 0;

      _themeMode = _decodeThemeMode(prefs.getInt(_PK.themeMode));

      _learnerPreferences = _decodeJson(
        prefs.getString(_PK.learnerPreferences),
        LearnerPreferences.fromJson,
        orElse: LearnerPreferences.defaults(),
      );

      _intentionTracker = _decodeJson(
        prefs.getString(_PK.intentionTracker),
        IntentionTracker.fromJson,
        orElse: IntentionTracker.empty(),
      );

      _confidenceScores = _decodeDoubleMap(
        prefs.getString(_PK.confidenceScores),
        fallback: ConfidenceKeys.defaults,
      );

      _confidenceHistory =
          _decodeListOfMaps(prefs.getString(_PK.confidenceHistory));
      _jobApplications =
          _decodeListOfMaps(prefs.getString(_PK.jobApplications));
      _jobAlerts   = _decodeListOfMaps(prefs.getString(_PK.jobAlerts));
      _skillTrends = _decodeListOfMaps(prefs.getString(_PK.skillTrends));

      _fairnessScore = prefs.getDouble(_PK.fairnessScore) ?? 1.0;

      _checkStreakExpiry();
      computeReadinessScore();
    } catch (e, st) {
      _errorMessage = 'Failed to load saved data.';
      debugPrint('[AppState] loadFromPrefs error: $e\n$st');
    } finally {
      _setLoading(false);
    }
  }

  // ==========================================================================
  // SAVE ALL (debounced)
  // ==========================================================================

  void scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), saveToPrefs);
  }

  Future<void> saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(_PK.isLoggedIn, _isLoggedIn);
      await prefs.setString(_PK.userName,  _userName);
      await prefs.setString(_PK.userEmail, _userEmail);
      if (_currentUserId != null) {
        await prefs.setString(_PK.currentUserId, _currentUserId!);
      } else {
        await prefs.remove(_PK.currentUserId);
      }

      await prefs.setString(_PK.fieldOfStudy,    _fieldOfStudy);
      await prefs.setDouble(_PK.gpa,             _gpa);
      await prefs.setString(_PK.careerGoal,      _careerGoal);
      await prefs.setString(_PK.experienceLevel, _experienceLevel);
      await prefs.setInt(_PK.yearOfStudy,        _yearOfStudy);
      await prefs.setStringList(_PK.userSkills,  _userSkills);

      await _writeIntSet(prefs, _PK.savedJobIds, _savedJobIds);
      await prefs.setInt(_PK.jobsMatchedCount,       _jobsMatchedCount);
      await prefs.setString(_PK.lastIndustryFilter,  _lastIndustryFilter);
      await prefs.setString(_PK.lastLevelFilter,     _lastLevelFilter);

      await _writeIntSet(prefs, _PK.completedCourseIds, _completedCourseIds);
      await _writeIntSet(prefs, _PK.enrolledCourseIds,  _enrolledCourseIds);

      await prefs.setInt(_PK.learningStreak,      _learningStreak);
      await prefs.setInt(_PK.longestStreak,       _longestStreak);
      await prefs.setString(_PK.lastLearningDate, _lastLearningDate);
      await prefs.setInt(_PK.totalStudyMinutes,   _totalStudyMinutes);

      await prefs.setString(_PK.cvFileName, _cvFileName);
      await prefs.setString(_PK.cvRawText,  _cvRawText);
      await prefs.setBool(_PK.cvUploaded,   _cvUploaded);

      await prefs.setString(_PK.quizScores, jsonEncode(_quizScores));
      await prefs.setStringList(_PK.completedTopics, _completedTopics);
      await prefs.setStringList(_PK.learningHistory, _learningHistory);
      await prefs.setInt(_PK.readinessScore, _readinessScore);

      await prefs.setInt(_PK.themeMode, _themeMode.index);

      await prefs.setString(_PK.learnerPreferences,
          jsonEncode(_learnerPreferences.toJson()));
      await prefs.setString(_PK.intentionTracker,
          jsonEncode(_intentionTracker.toJson()));
      await prefs.setString(_PK.confidenceScores,
          jsonEncode(_confidenceScores));
      await prefs.setString(_PK.confidenceHistory,
          jsonEncode(_confidenceHistory));
      await prefs.setString(_PK.jobApplications,
          jsonEncode(_jobApplications));
      await prefs.setString(_PK.jobAlerts,
          jsonEncode(_jobAlerts));
      await prefs.setString(_PK.skillTrends,
          jsonEncode(_skillTrends));
      await prefs.setDouble(_PK.fairnessScore, _fairnessScore);
    } catch (e, st) {
      debugPrint('[AppState] saveToPrefs error: $e\n$st');
    }
  }

  // ==========================================================================
  // AUTH
  // ==========================================================================

  Future<void> login({
    required String name,
    required String email,
  }) async {
    final cleanName  = name.trim();
    final cleanEmail = email.trim().toLowerCase();
    if (cleanName.isEmpty || cleanEmail.isEmpty) return;

    _isLoggedIn    = true;
    _userName      = cleanName;
    _userEmail     = cleanEmail;
    _currentUserId = cleanEmail;
    _clearError();
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_PK.isLoggedIn,      true);
      await prefs.setString(_PK.userName,      _userName);
      await prefs.setString(_PK.userEmail,     _userEmail);
      await prefs.setString(_PK.currentUserId, _currentUserId!);
    } catch (e) {
      debugPrint('[AppState] login persist error: $e');
    }
  }

  Future<void> logout() async {
    _isLoggedIn    = false;
    _currentUserId = null;
    _clearError();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_PK.isLoggedIn, false);
      await prefs.remove(_PK.currentUserId);
    } catch (e) {
      debugPrint('[AppState] logout persist error: $e');
    }
  }

  Future<void> clearAllData() async {
    _saveDebounce?.cancel();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      debugPrint('[AppState] clearAllData error: $e');
    }
    _resetAllState();
    notifyListeners();
  }

  /// Alias kept for backward compatibility.
  Future<void> deleteAccount() => clearAllData();

  // ==========================================================================
  // THEME
  // ==========================================================================

  Future<void> toggleTheme() async {
    final next = switch (_themeMode) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light  => ThemeMode.dark,
      ThemeMode.dark   => ThemeMode.system,
    };
    await setThemeMode(next);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_PK.themeMode, mode.index);
    } catch (e) {
      debugPrint('[AppState] setThemeMode persist error: $e');
    }
  }

  // ==========================================================================
  // PROFILE
  // ==========================================================================

  Future<void> setProfileInfo({
    required String fieldOfStudy,
    required double gpa,
    String careerGoal      = '',
    String experienceLevel = 'none',
    int    yearOfStudy     = 1,
  }) async {
    _fieldOfStudy    = fieldOfStudy.trim();
    _gpa             = gpa.clamp(0.0, 4.0);
    _experienceLevel = experienceLevel;
    _yearOfStudy     = yearOfStudy.clamp(1, 6);
    if (careerGoal.isNotEmpty) _careerGoal = careerGoal.trim();
    _computeAndNotify();
    scheduleSave();
  }

  Future<void> setCareerGoal(String goal) async {
    _careerGoal = goal.trim();
    notifyListeners();
    scheduleSave();
  }

  Future<void> setCareerProfile(CareerProfile profile) async {
    _careerProfile = profile;
    notifyListeners();
  }

  Future<void> setCvUploaded({
    required String fileName,
    String rawText = '',
  }) async {
    if (fileName.trim().isEmpty) return;
    _cvFileName = fileName.trim();
    _cvRawText  = rawText.trim();
    _cvUploaded = true;
    _computeAndNotify();
    scheduleSave();
  }

  Future<void> removeCv() async {
    _cvFileName = '';
    _cvRawText  = '';
    _cvUploaded = false;
    _computeAndNotify();
    scheduleSave();
  }

  // ==========================================================================
  // SKILLS
  // ==========================================================================

  Future<void> setUserSkills(List<String> skills) async {
    _userSkills = skills
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    _computeAndNotify();
    scheduleSave();
  }

  Future<void> addSkill(String skill) async {
    final clean = skill.trim().toLowerCase();
    if (clean.isEmpty || _userSkills.contains(clean)) return;
    _userSkills = [..._userSkills, clean];
    _computeAndNotify();
    scheduleSave();
  }

  Future<void> removeSkill(String skill) async {
    final clean = skill.trim().toLowerCase();
    if (!_userSkills.contains(clean)) return;
    _userSkills = _userSkills.where((s) => s != clean).toList();
    _computeAndNotify();
    scheduleSave();
  }

  // ==========================================================================
  // RECOMMENDATIONS (local ML layer — kept for offline / fallback use)
  // ==========================================================================

  void setRecommendedJobs(List<Job> jobs) {
    _recommendedJobs = List.from(jobs);
    updateFairnessScore();
    notifyListeners();
  }

  void setRecommendedCourses(List<Course> courses) {
    _recommendedCourses = List.from(courses);
    notifyListeners();
  }

  // ==========================================================================
  // PREDICTIONS — Backend API                                           ── NEW
  // ==========================================================================

  /// Calls POST /predict with the user's skill list.
  /// Populates [lastPredictionResult], [skillsGap], and
  /// [predictionConfidences]. Sets [isLoading] and [errorMessage] correctly.
  ///
  /// Usage:
  ///   await context.read AppState().predictFromSkills(state.userSkills);
  Future<void> predictFromSkills(List<String> skills) async {
    final clean = skills
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toList();

    if (clean.isEmpty) {
      setError('Please add at least one skill before running a prediction.');
      return;
    }

    _setLoading(true);
    _clearError();

    try {
      final result = await ApiService.instance.predict(
        PredictionRequest(skills: clean),
      );
      _applyPredictionResult(result);
    } on ApiException catch (e) {
      setError(e.message);
      debugPrint('[AppState] predictFromSkills ApiException: $e');
    } catch (e, st) {
      setError('Prediction failed. Please check your connection and try again.');
      debugPrint('[AppState] predictFromSkills unexpected error: $e\n$st');
    } finally {
      _setLoading(false);
    }
  }

  /// Calls POST /predict with the user's raw CV text.
  /// Populates [lastPredictionResult], [skillsGap], and
  /// [predictionConfidences]. Sets [isLoading] and [errorMessage] correctly.
  ///
  /// Usage:
  ///   await context.read AppState().predictFromCv(state.cvRawText);
  Future<void> predictFromCv(String cvText) async {
    final clean = cvText.trim();

    if (clean.isEmpty) {
      setError('CV text is empty. Please upload or paste your CV first.');
      return;
    }

    _setLoading(true);
    _clearError();

    try {
      final result = await ApiService.instance.predict(
        PredictionRequest(cvText: clean),
      );
      _applyPredictionResult(result);
    } on ApiException catch (e) {
      setError(e.message);
      debugPrint('[AppState] predictFromCv ApiException: $e');
    } catch (e, st) {
      setError('CV prediction failed. Please check your connection and try again.');
      debugPrint('[AppState] predictFromCv unexpected error: $e\n$st');
    } finally {
      _setLoading(false);
    }
  }

  /// Clears the current prediction result and resets related state.
  /// Call this when navigating away from job_result.dart.
  void clearPredictionResult() {
    _lastPredictionResult  = null;
    _skillsGap             = [];
    _predictionConfidences = [];
    notifyListeners();
  }

  /// Applies a successful [PredictionResult] atomically to all related
  /// state fields and triggers a single [notifyListeners] call.
  void _applyPredictionResult(PredictionResult result) {
    _lastPredictionResult  = result;
    _skillsGap             = result.skillsGap;
    _predictionConfidences = result.confidence;
    // Update matched count so dashboard stats reflect API results.
    _jobsMatchedCount      = result.jobs.length;
    updateFairnessScore();
    _computeAndNotify();
  }

  // ==========================================================================
  // JOB TRACKING
  // ==========================================================================

  Future<void> toggleSaveJob(int jobId) async {
    if (_savedJobIds.contains(jobId)) {
      _savedJobIds.remove(jobId);
    } else {
      _savedJobIds.add(jobId);
    }
    _computeAndNotify();
    scheduleSave();
  }

  Future<void> setJobsMatchedCount(int count) async {
    _jobsMatchedCount = count.clamp(0, 9999999);
    notifyListeners();
    scheduleSave();
  }

  Future<void> saveLastFilters({
    required String industry,
    required String level,
  }) async {
    _lastIndustryFilter = industry;
    _lastLevelFilter    = level;
    scheduleSave();
  }

  // ==========================================================================
  // COURSE TRACKING
  // ==========================================================================

  Future<void> toggleCourseCompleted(int courseId) async {
    if (_completedCourseIds.contains(courseId)) {
      _completedCourseIds.remove(courseId);
    } else {
      _completedCourseIds.add(courseId);
      await _tickStreak();
    }
    _computeAndNotify();
    scheduleSave();
  }

  Future<void> toggleCourseEnrolled(int courseId) async {
    if (_enrolledCourseIds.contains(courseId)) {
      _enrolledCourseIds.remove(courseId);
    } else {
      _enrolledCourseIds.add(courseId);
    }
    notifyListeners();
    scheduleSave();
  }

  // ==========================================================================
  // STUDY TIME
  // ==========================================================================

  Future<void> addStudyMinutes(int minutes) async {
    if (minutes <= 0) return;
    _totalStudyMinutes += minutes;
    _computeAndNotify();
    scheduleSave();
  }

  // ==========================================================================
  // QUIZ / ASSESSMENT
  // ==========================================================================

  Future<void> recordQuizScore(String topicKey, int score) async {
    try {
      final clamped = score.clamp(0, 100);
      _quizScores = {..._quizScores, topicKey: clamped};
      if (clamped >= 70 && !_completedTopics.contains(topicKey)) {
        _completedTopics = [..._completedTopics, topicKey];
      }
      await _tickStreak();
      _computeAndNotify();
      scheduleSave();
    } catch (e) {
      debugPrint('[AppState] recordQuizScore error: $e');
    }
  }

  // ==========================================================================
  // LEARNING HISTORY
  // ==========================================================================

  Future<void> addToHistory(String courseId) async {
    try {
      final id = courseId.trim();
      if (id.isEmpty) return;
      const max = 100;
      final updated = [..._learningHistory, id];
      _learningHistory = updated.length > max
          ? updated.sublist(updated.length - max)
          : updated;
      notifyListeners();
      scheduleSave();
    } catch (e) {
      debugPrint('[AppState] addToHistory error: $e');
    }
  }

  // ==========================================================================
  // [TAV22 §3.5.1] LEARNER PREFERENCES
  // ==========================================================================

  Future<void> setInitialPreferences(Map<String, double> values) async {
    try {
      final updated =
      Map<String, double>.from(_learnerPreferences.longTermVector);
      for (final entry in values.entries) {
        if (PreferenceKeys.allKeys.contains(entry.key)) {
          updated[entry.key] = entry.value.clamp(0.0, 1.0);
        }
      }
      _learnerPreferences =
          _learnerPreferences.copyWith(longTermVector: updated);
      notifyListeners();
      await _persistLearnerPreferences();
    } catch (e) {
      debugPrint('[AppState] setInitialPreferences error: $e');
    }
  }

  void updatePreferencesFromFeedback(
      double rating,
      List<double> courseVector,
      ) {
    try {
      if (courseVector.length != PreferenceKeys.allKeys.length) return;
      final r = rating.clamp(0.0, 1.0);

      final st     = Map<String, double>.from(
          _learnerPreferences.shortTermVector);
      final counts = Map<String, int>.from(
          _learnerPreferences.shortTermCounts);

      for (var i = 0; i < PreferenceKeys.allKeys.length; i++) {
        final key          = PreferenceKeys.allKeys[i];
        final contribution = r * courseVector[i];
        final oldAvg       = st[key]     ?? 0.0;
        final oldCount     = counts[key] ?? 0;
        final newCount     = oldCount + 1;
        st[key]            = ((oldAvg * oldCount) + contribution) / newCount;
        counts[key]        = newCount;
      }

      _learnerPreferences = _learnerPreferences.copyWith(
        shortTermVector: st,
        shortTermCounts: counts,
      );
      notifyListeners();
      _persistLearnerPreferences();
    } catch (e) {
      debugPrint('[AppState] updatePreferencesFromFeedback error: $e');
    }
  }

  void rateContent(String featureKey, double rating) {
    try {
      final r    = rating.clamp(0.0, 1.0);
      final st   = Map<String, double>.from(
          _learnerPreferences.shortTermVector);
      final cnts = Map<String, int>.from(
          _learnerPreferences.shortTermCounts);
      final old    = st[featureKey]    ?? 0.0;
      final cnt    = cnts[featureKey] ?? 0;
      final newCnt = cnt + 1;
      st[featureKey]   = ((old * cnt) + r) / newCnt;
      cnts[featureKey] = newCnt;
      _learnerPreferences = _learnerPreferences.copyWith(
          shortTermVector: st, shortTermCounts: cnts);
      notifyListeners();
      _persistLearnerPreferences();
    } catch (e) {
      debugPrint('[AppState] rateContent error: $e');
    }
  }

  Future<void> mergeLongTermVector() async {
    try {
      if (_learnerPreferences.shortTermVector.isEmpty) return;
      final merged =
      Map<String, double>.from(_learnerPreferences.longTermVector);
      for (final key in PreferenceKeys.allKeys) {
        final shortVal = _learnerPreferences.shortTermVector[key];
        if (shortVal != null) {
          merged[key] = ((merged[key] ?? 0.5) + shortVal) / 2.0;
        }
      }
      _learnerPreferences = _learnerPreferences.copyWith(
        longTermVector:  merged,
        shortTermVector: const {},
        shortTermCounts: const {},
      );
      notifyListeners();
      await _persistLearnerPreferences();
    } catch (e) {
      debugPrint('[AppState] mergeLongTermVector error: $e');
    }
  }

  // ==========================================================================
  // [LH22] EMPLOYMENT INTENTION
  // ==========================================================================

  Future<void> updateIntention(
      EmploymentIntention intention, {
        String? note,
        double? confidenceLevel,
      }) async {
    try {
      _intentionTracker = _intentionTracker.withEntry(
        IntentionEntry(
          date:            DateTime.now(),
          intention:       intention,
          note:            note,
          confidenceLevel: confidenceLevel?.clamp(0.0, 1.0),
        ),
      );
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _PK.intentionTracker, jsonEncode(_intentionTracker.toJson()));
    } catch (e) {
      debugPrint('[AppState] updateIntention error: $e');
    }
  }

  // ==========================================================================
  // [XZ25] CONFIDENCE TRACKER
  // ==========================================================================

  Future<void> updateConfidenceScore(String category, double score) async {
    try {
      if (!ConfidenceKeys.all.contains(category)) return;
      _confidenceScores = {
        ..._confidenceScores,
        category: score.clamp(0.0, 1.0),
      };
      _appendConfidenceSnapshot();
      notifyListeners();
      scheduleSave();
    } catch (e) {
      debugPrint('[AppState] updateConfidenceScore error: $e');
    }
  }

  Future<void> updateAllConfidenceScores(
      Map<String, double> scores) async {
    try {
      final updated = Map<String, double>.from(_confidenceScores);
      for (final entry in scores.entries) {
        if (ConfidenceKeys.all.contains(entry.key)) {
          updated[entry.key] = entry.value.clamp(0.0, 1.0);
        }
      }
      _confidenceScores = updated;
      _appendConfidenceSnapshot();
      notifyListeners();
      scheduleSave();
    } catch (e) {
      debugPrint('[AppState] updateAllConfidenceScores error: $e');
    }
  }

  // ==========================================================================
  // APPLICATION TRACKER
  // ==========================================================================

  Future<void> addJobApplication(Map<String, dynamic> application) async {
    try {
      final entry = Map<String, dynamic>.from(application)
        ..putIfAbsent(
            'id', () => DateTime.now().millisecondsSinceEpoch.toString())
        ..putIfAbsent('appliedDate', () => DateTime.now().toIso8601String())
        ..putIfAbsent('status', () => ApplicationStatus.applied.label);
      _jobApplications = [..._jobApplications, entry];
      notifyListeners();
      scheduleSave();
    } catch (e) {
      debugPrint('[AppState] addJobApplication error: $e');
    }
  }

  Future<void> updateApplicationStatus(
      String applicationId,
      String newStatus,
      ) async {
    try {
      _jobApplications = _jobApplications.map((app) {
        if (app['id'] == applicationId) {
          return Map<String, dynamic>.from(app)
            ..['status']          = newStatus
            ..['statusUpdatedAt'] = DateTime.now().toIso8601String();
        }
        return app;
      }).toList();
      notifyListeners();
      scheduleSave();
    } catch (e) {
      debugPrint('[AppState] updateApplicationStatus error: $e');
    }
  }

  Future<void> updateApplication(
      String applicationId,
      Map<String, dynamic> updates,
      ) async {
    try {
      _jobApplications = _jobApplications.map((app) {
        if (app['id'] == applicationId) {
          return Map<String, dynamic>.from(app)..addAll(updates);
        }
        return app;
      }).toList();
      notifyListeners();
      scheduleSave();
    } catch (e) {
      debugPrint('[AppState] updateApplication error: $e');
    }
  }

  Future<void> deleteJobApplication(String applicationId) async {
    try {
      _jobApplications =
          _jobApplications.where((a) => a['id'] != applicationId).toList();
      notifyListeners();
      scheduleSave();
    } catch (e) {
      debugPrint('[AppState] deleteJobApplication error: $e');
    }
  }

  // ==========================================================================
  // JOB ALERTS
  // ==========================================================================

  Future<void> addJobAlert(Map<String, dynamic> alert) async {
    try {
      final entry = Map<String, dynamic>.from(alert)
        ..putIfAbsent(
            'id', () => DateTime.now().millisecondsSinceEpoch.toString())
        ..putIfAbsent('isActive',    () => true)
        ..putIfAbsent('createdDate', () => DateTime.now().toIso8601String());
      _jobAlerts = [..._jobAlerts, entry];
      notifyListeners();
      scheduleSave();
    } catch (e) {
      debugPrint('[AppState] addJobAlert error: $e');
    }
  }

  Future<void> toggleJobAlert(String alertId) async {
    try {
      _jobAlerts = _jobAlerts.map((alert) {
        if (alert['id'] == alertId) {
          return Map<String, dynamic>.from(alert)
            ..['isActive'] = !(alert['isActive'] as bool? ?? true);
        }
        return alert;
      }).toList();
      notifyListeners();
      scheduleSave();
    } catch (e) {
      debugPrint('[AppState] toggleJobAlert error: $e');
    }
  }

  Future<void> updateJobAlert(
      String alertId,
      Map<String, dynamic> updates,
      ) async {
    try {
      _jobAlerts = _jobAlerts.map((alert) {
        if (alert['id'] == alertId) {
          return Map<String, dynamic>.from(alert)..addAll(updates);
        }
        return alert;
      }).toList();
      notifyListeners();
      scheduleSave();
    } catch (e) {
      debugPrint('[AppState] updateJobAlert error: $e');
    }
  }

  Future<void> deleteJobAlert(String alertId) async {
    try {
      _jobAlerts = _jobAlerts.where((a) => a['id'] != alertId).toList();
      notifyListeners();
      scheduleSave();
    } catch (e) {
      debugPrint('[AppState] deleteJobAlert error: $e');
    }
  }

  // ==========================================================================
  // SKILL TRENDS
  // ==========================================================================

  Future<void> updateSkillTrends(
      List<Map<String, dynamic>> trends) async {
    try {
      _skillTrends = List.from(trends);
      notifyListeners();
      scheduleSave();
    } catch (e) {
      debugPrint('[AppState] updateSkillTrends error: $e');
    }
  }

  // ==========================================================================
  // [ZC22] FAIRNESS MONITOR
  // ==========================================================================

  void updateFairnessScore() {
    try {
      // Prioritise API job titles if available; fall back to local jobs.
      final apiJobs = _lastPredictionResult?.jobs ?? [];

      if (apiJobs.isNotEmpty) {
        final window     = apiJobs.take(10).toList();
        final industries = window
            .map((j) => j.industry ?? 'Unknown')
            .toSet();
        _fairnessScore   = (industries.length / window.length).clamp(0.0, 1.0);
      } else if (_recommendedJobs.isNotEmpty) {
        final window     = _recommendedJobs.take(10).toList();
        final industries = window.map((j) => j.industry).toSet();
        _fairnessScore   = (industries.length / window.length).clamp(0.0, 1.0);
      } else {
        _fairnessScore = 1.0;
      }
      _persistFairnessScore();
    } catch (e) {
      debugPrint('[AppState] updateFairnessScore error: $e');
    }
  }

  // ==========================================================================
  // READINESS SCORE  [ALS22 §4]
  // ==========================================================================

  int computeReadinessScore() {
    var score = 0;
    if (_cvUploaded)                    score += 20;
    if (profileCompletionPercent >= 80) score += 20;
    score += (_userSkills.length * 2).clamp(0, 20);
    if (_savedJobIds.isNotEmpty)        score += 10;
    score += (_completedCourseIds.length * 5).clamp(0, 20);
    if (_learningStreak >= 3)           score += 5;
    if (_totalStudyMinutes >= 60)       score += 5;

    _readinessScore = score.clamp(0, 100);
    _persistReadinessScore();
    return _readinessScore;
  }

  // ==========================================================================
  // ERROR HANDLING
  // ==========================================================================

  void setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void clearError() => _clearError();

  // ==========================================================================
  // PRIVATE — STREAK
  // ==========================================================================

  Future<void> _tickStreak() async {
    final today = _todayString();
    if (_lastLearningDate == today) return;

    if (_lastLearningDate.isNotEmpty) {
      final last = DateTime.tryParse(_lastLearningDate);
      if (last != null) {
        final diffDays = DateTime.now()
            .difference(DateTime(last.year, last.month, last.day))
            .inDays;
        _learningStreak = diffDays == 1 ? _learningStreak + 1 : 1;
      } else {
        _learningStreak = 1;
      }
    } else {
      _learningStreak = 1;
    }

    if (_learningStreak > _longestStreak) _longestStreak = _learningStreak;
    _lastLearningDate = today;
  }

  void _checkStreakExpiry() {
    if (_lastLearningDate.isEmpty) return;
    final last = DateTime.tryParse(_lastLearningDate);
    if (last == null) return;
    final diffDays = DateTime.now()
        .difference(DateTime(last.year, last.month, last.day))
        .inDays;
    if (diffDays > 1) _learningStreak = 0;
  }

  // ==========================================================================
  // PRIVATE — CONFIDENCE HISTORY
  // ==========================================================================

  void _appendConfidenceSnapshot() {
    const maxHistory = 365;
    final snapshot = <String, dynamic>{
      'date':   DateTime.now().toIso8601String(),
      'scores': Map<String, double>.from(_confidenceScores),
    };
    _confidenceHistory = [..._confidenceHistory, snapshot];
    if (_confidenceHistory.length > maxHistory) {
      _confidenceHistory =
          _confidenceHistory.sublist(_confidenceHistory.length - maxHistory);
    }
  }

  // ==========================================================================
  // PRIVATE — COMPUTED NOTIFY HELPER
  // ==========================================================================

  void _computeAndNotify() {
    computeReadinessScore();
    notifyListeners();
  }

  // ==========================================================================
  // PRIVATE — PERSIST HELPERS
  // ==========================================================================

  Future<void> _persistLearnerPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_PK.learnerPreferences,
          jsonEncode(_learnerPreferences.toJson()));
    } catch (e) {
      debugPrint('[AppState] _persistLearnerPreferences error: $e');
    }
  }

  Future<void> _persistReadinessScore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_PK.readinessScore, _readinessScore);
    } catch (e) {
      debugPrint('[AppState] _persistReadinessScore error: $e');
    }
  }

  Future<void> _persistFairnessScore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_PK.fairnessScore, _fairnessScore);
    } catch (e) {
      debugPrint('[AppState] _persistFairnessScore error: $e');
    }
  }

  // ==========================================================================
  // PRIVATE — RESET
  // ==========================================================================

  void _resetAllState() {
    _isLoggedIn         = false;
    _userName           = '';
    _userEmail          = '';
    _currentUserId      = null;
    _careerProfile      = null;
    _fieldOfStudy       = '';
    _gpa                = 0.0;
    _careerGoal         = '';
    _experienceLevel    = 'none';
    _yearOfStudy        = 1;
    _userSkills         = [];
    _recommendedJobs    = [];
    _recommendedCourses = [];
    // ── NEW ──────────────────────────────────────────────────────────────────
    _lastPredictionResult  = null;
    _skillsGap             = [];
    _predictionConfidences = [];
    // ─────────────────────────────────────────────────────────────────────────
    _savedJobIds        = {};
    _jobsMatchedCount   = 0;
    _lastIndustryFilter = '';
    _lastLevelFilter    = '';
    _completedCourseIds = {};
    _enrolledCourseIds  = {};
    _learningStreak     = 0;
    _longestStreak      = 0;
    _lastLearningDate   = '';
    _totalStudyMinutes  = 0;
    _cvFileName         = '';
    _cvRawText          = '';
    _cvUploaded         = false;
    _quizScores         = {};
    _completedTopics    = [];
    _learningHistory    = [];
    _readinessScore     = 0;
    _isLoading          = false;
    _errorMessage       = null;
    _themeMode          = ThemeMode.system;
    _learnerPreferences = LearnerPreferences.defaults();
    _intentionTracker   = IntentionTracker.empty();
    _confidenceScores   = ConfidenceKeys.defaults;
    _confidenceHistory  = [];
    _jobApplications    = [];
    _jobAlerts          = [];
    _skillTrends        = [];
    _fairnessScore      = 1.0;
  }

  void _clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  // ==========================================================================
  // PRIVATE — SERIALISATION HELPERS
  // ==========================================================================

  static String _todayString() =>
      DateTime.now().toIso8601String().substring(0, 10);

  static Set<int> _intSetFromPrefs(List<String>? raw) {
    if (raw == null || raw.isEmpty) return {};
    return raw.map(int.tryParse).whereType<int>().toSet();
  }

  static Future<void> _writeIntSet(
      SharedPreferences prefs,
      String key,
      Set<int> value,
      ) async {
    await prefs.setStringList(
        key, value.map((e) => e.toString()).toList());
  }

  static Map<String, int> _decodeIntMap(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      return (jsonDecode(raw) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  static Map<String, double> _decodeDoubleMap(
      String? raw, {
        required Map<String, double> fallback,
      }) {
    if (raw == null || raw.isEmpty) return Map.from(fallback);
    try {
      return (jsonDecode(raw) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toDouble()));
    } catch (_) {
      return Map.from(fallback);
    }
  }

  static List<Map<String, dynamic>> _decodeListOfMaps(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static T _decodeJson<T>(
      String? raw,
      T Function(Map<String, dynamic>) fromJson, {
        required T orElse,
      }) {
    if (raw == null || raw.isEmpty) return orElse;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return fromJson(decoded);
    } catch (_) {}
    return orElse;
  }

  static ThemeMode _decodeThemeMode(int? index) {
    if (index == null) return ThemeMode.system;
    if (index >= 0 && index < ThemeMode.values.length) {
      return ThemeMode.values[index];
    }
    return ThemeMode.system;
  }

  // ==========================================================================
  // DISPOSE
  // ==========================================================================

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }
  dynamic _predictionResult;
  dynamic get predictionResult => _predictionResult;

  void setPredictionResult(dynamic result) {
    _predictionResult = result;
    notifyListeners();
  }
}