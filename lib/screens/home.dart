// screens/home.dart — SkillBridge AI
// ══════════════════════════════════════════════════════════════════════════════
//  PROFESSIONAL JOB FEED
//
//  Fix applied:
//  • Dark-mode toggle now calls context.read<AppState>().setThemeMode()
//    directly, toggling between ThemeMode.light and ThemeMode.dark.
//    No longer depends on the optional onToggleTheme callback being wired
//    by the parent — the button always works.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:skillbridge_ai/models/career_profile.dart';
import '../services/app_state.dart';
import 'profile_input.dart';
import 'cv_upload_screen.dart';
import 'job_result.dart';

// ══════════════════════════════════════════════════════════════════════════════
// DESIGN TOKENS
// ══════════════════════════════════════════════════════════════════════════════

const _kPrimaryBlue  = Color(0xFF1A56DB);
const _kPurple       = Color(0xFF7C3AED);
const _kGreen        = Color(0xFF10B981);
const _kOrange       = Color(0xFFF59E0B);
const _kError        = Color(0xFFEF4444);
const _kMatchGreen   = Color(0xFF10B981);
const _kMatchGreenBg = Color(0xFFD1FAE5);
const _kDarkBg       = Color(0xFF0F172A);
const _kDarkCard     = Color(0xFF1E293B);
const _kDarkBorder   = Color(0xFF334155);
const _kLightBg      = Colors.white;
const _kLightBorder  = Color(0xFFE2E8F0);

// ══════════════════════════════════════════════════════════════════════════════
// UTILITIES
// ══════════════════════════════════════════════════════════════════════════════

Color _withA(Color c, double opacity) =>
    c.withValues(alpha: opacity.clamp(0.0, 1.0));

BoxDecoration _cardDeco(
    bool dark, {
      double radius = 16,
      Color? bg,
      Color? borderColor,
      List<BoxShadow>? shadows,
    }) =>
    BoxDecoration(
      color: bg ?? (dark ? _kDarkCard : _kLightBg),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? (dark ? _kDarkBorder : _kLightBorder),
      ),
      boxShadow: dark
          ? [
        BoxShadow(
          color: _withA(Colors.black, 0.35),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ]
          : shadows ??
          [
            BoxShadow(
              color: _withA(Colors.black, 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
    );

// ══════════════════════════════════════════════════════════════════════════════
// SAFE PROPERTY ACCESSORS
// ══════════════════════════════════════════════════════════════════════════════

String _safeJobSalaryRange(dynamic job) {
  try {
    final dynamic v = job.salaryRange;
    if (v is String && v.isNotEmpty) return v;
  } catch (_) {}
  return '30,000–60,000';
}

List<String> _safeJobRequiredSkills(dynamic job) {
  try {
    final dynamic v = job.requiredSkills;
    if (v is List) return v.map((e) => e.toString()).toList();
  } catch (_) {}
  return const <String>[];
}

String _safeCoursePlatform(dynamic course) {
  try {
    final dynamic v = course.platform;
    if (v is String) return v;
  } catch (_) {}
  return '';
}

String _safeCourseFormat(dynamic course) {
  try {
    final dynamic v = course.format;
    if (v is String && v.isNotEmpty) return v;
  } catch (_) {}
  return 'Video';
}

int _safeMissingSkillCount(AppState s) {
  try {
    final dynamic v = (s as dynamic).missingSkillCount;
    if (v is int) return v;
  } catch (_) {}
  return 0;
}

List<String> _safeEnrolledCourseIds(AppState s) {
  try {
    final dynamic v = (s as dynamic).enrolledCourseIds;
    if (v is List) return v.map((e) => e.toString()).toList();
    if (v is Set) return v.map((e) => e.toString()).toList();
    if (v is int) return List.generate(v, (i) => 'course_$i');
  } catch (_) {}
  return const <String>[];
}

Map<String, double> _safeCourseProgress(AppState s) {
  try {
    final dynamic v = (s as dynamic).courseProgress;
    if (v is Map) {
      return v.map<String, double>(
            (k, val) => MapEntry(k.toString(), val is num ? val.toDouble() : 0.0),
      );
    }
  } catch (_) {}
  return const <String, double>{};
}

ExperienceType _safeEmploymentType(AppState s) {
  const accessors = [
    'experienceType',
    'employmentType',
    'preferredEmploymentType',
    'expType',
  ];
  for (final key in accessors) {
    try {
      final dynamic val = (s as dynamic)[key] ?? (s as dynamic).noSuchMethod(
        Invocation.getter(Symbol(key)),
      );
      if (val is ExperienceType) return val;
    } catch (_) {}
  }
  return ExperienceType.none;
}

// ══════════════════════════════════════════════════════════════════════════════
// HOME SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class HomeScreen extends StatefulWidget {
  /// Kept for API compatibility but the toggle now works independently
  /// by reading AppState directly — this callback is optional.
  final VoidCallback? onToggleTheme;

  const HomeScreen({super.key, this.onToggleTheme});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late final AnimationController _heroCtrl;
  late final AnimationController _contentCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _statCtrl;

  late final Animation<double> _heroFade;
  late final Animation<Offset> _heroSlide;
  late final Animation<double> _contentFade;

  static const List<String> _trendingSkills = [
    '🤖 Prompt Engineering',
    '📊 Power BI',
    '🐍 Python',
    '☁️ AWS',
    '📱 Flutter',
    '🔐 Cybersecurity',
    '📈 Data Analytics',
    '🧠 Machine Learning',
  ];

  @override
  void initState() {
    super.initState();

    _heroCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _contentCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _statCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

    _heroFade = CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut);

    _heroSlide = Tween<Offset>(
      begin: const Offset(0, -0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut));

    _contentFade = CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    _contentCtrl.dispose();
    _pulseCtrl.dispose();
    _statCtrl.dispose();
    super.dispose();
  }

  // ── FIX: toggle directly via AppState, ignoring the optional callback ──────
  void _doToggleTheme() {
    HapticFeedback.selectionClick();
    final appState = context.read<AppState>();
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    appState.setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }

  String _greeting() {
    final int h = DateTime.now().hour;
    if (h < 12) return 'Good morning 👋';
    if (h < 17) return 'Good afternoon 👋';
    return 'Good evening 👋';
  }

  Color _textColor(bool dark) => dark ? Colors.white : const Color(0xFF0F172A);
  Color _subColor(bool dark) =>
      dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

  CareerProfile _buildProfileFromState(AppState s) {
    final FieldOfStudy fos = FieldOfStudy.values.firstWhere(
          (e) => e.name.toLowerCase() == s.fieldOfStudy.toLowerCase(),
      orElse: () => FieldOfStudy.values.first,
    );
    return CareerProfile(
      name:            s.userName.isNotEmpty ? s.userName : 'User',
      fieldOfStudy:    fos,
      gpa:             s.gpa,
      yearOfStudy:     s.yearOfStudy,
      skills:          s.userSkills,
      careerInterests: const [],
      hasEntrepreneurialExperience: false,
      employmentType:  _safeEmploymentType(s),
    );
  }

  // ── Dark-mode toggle widget ───────────────────────────────────────────────
  Widget _buildDarkToggle(bool isDark, {bool onGradient = false}) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: _doToggleTheme,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: onGradient ? _withA(Colors.white, 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            color: onGradient
                ? Colors.white
                : (isDark ? Colors.white70 : Colors.black54),
            size: 18,
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(
      BuildContext ctx,
      String title, {
        String? action,
        VoidCallback? onAction,
        required bool isDark,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _textColor(isDark),
                letterSpacing: -0.3,
              ),
            ),
          ),
          Container(
            height: 1,
            width: 40,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_withA(_kPrimaryBlue, 0.6), Colors.transparent],
              ),
            ),
          ),
          if (action != null)
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onAction?.call();
                },
                borderRadius: BorderRadius.circular(20),
                child: Ink(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _withA(_kPrimaryBlue, isDark ? 0.16 : 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    action,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _kPrimaryBlue,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyJobsPlaceholder(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.work_outline_rounded, size: 36, color: _subColor(isDark)),
            const SizedBox(height: 10),
            Text(
              'Complete your profile to see matches',
              style: TextStyle(color: _subColor(isDark), fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyCoursesPlaceholder(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.school_outlined, size: 36, color: _subColor(isDark)),
          const SizedBox(height: 10),
          Text(
            'No courses recommended yet.\nComplete your profile first.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _subColor(isDark), fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final AppState appState = context.watch<AppState>();

    final String userName =
    appState.userName.isNotEmpty ? appState.userName : 'Student';
    final String initials = userName
        .trim()
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    final int readinessScore         = appState.readinessScore;
    final int savedCount             = appState.savedJobIds.length;
    final int completedCount         = appState.completedTopics.length;
    final int learningStreak         = appState.learningStreak;
    final List<String> enrolledIds   = _safeEnrolledCourseIds(appState);
    final bool hasContinueLearning   = enrolledIds.isNotEmpty;
    final List<dynamic> recJobs      = appState.recommendedJobs;
    final List<dynamic> recCourses   = appState.recommendedCourses;
    final int missingSkills          = _safeMissingSkillCount(appState);
    final Map<String, double> progMap = _safeCourseProgress(appState);
    final CareerProfile profile      = _buildProfileFromState(appState);

    return Scaffold(
      backgroundColor: isDark ? _kDarkBg : _kLightBg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // ──────────────────────────────────────────────────────────────
          // SLIVER APP BAR
          // ──────────────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            floating: true,
            snap: true,
            pinned: false,
            automaticallyImplyLeading: false,
            backgroundColor: isDark ? _kDarkCard : _kLightBg,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: Text(
              'SkillBridge AI',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _textColor(isDark),
              ),
            ),
            actions: const [],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: RepaintBoundary(
                child: FadeTransition(
                  opacity: _heroFade,
                  child: SlideTransition(
                    position: _heroSlide,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1A56DB), Color(0xFF0EA5E9)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: SafeArea(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding:
                              const EdgeInsets.fromLTRB(20, 16, 16, 0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _greeting(),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: _withA(Colors.white, 0.85),
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        userName,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  // ── Dark toggle — calls AppState directly ──
                                  _buildDarkToggle(isDark, onGradient: true),
                                  const SizedBox(width: 8),
                                  // Avatar
                                  Material(
                                    color: Colors.transparent,
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                            const ProfileInputScreen(),
                                          ),
                                        );
                                      },
                                      customBorder: const CircleBorder(),
                                      child: Ink(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _withA(Colors.white, 0.2),
                                          border: Border.all(
                                            color:
                                            _withA(Colors.white, 0.6),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            initials.isNotEmpty
                                                ? initials
                                                : 'SK',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            // ── Search bar ───────────────────────────────
                            Padding(
                              padding:
                              const EdgeInsets.symmetric(horizontal: 20),
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                        const ProfileInputScreen(),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Ink(
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius:
                                      BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                          _withA(Colors.black, 0.12),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        const SizedBox(width: 16),
                                        const Icon(
                                          Icons.search_rounded,
                                          color: _kPrimaryBlue,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          'Search jobs, skills, courses...',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          margin: const EdgeInsets.only(
                                              right: 10),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _withA(
                                                _kPrimaryBlue, 0.08),
                                            borderRadius:
                                            BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'Filter',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: _kPrimaryBlue,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ──────────────────────────────────────────────────────────────
          // SECTION A — Quick Stats
          // ──────────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: RepaintBoundary(
              child: FadeTransition(
                opacity: _contentFade,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 0, 0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _AnimatedStatCard(
                          index: 0,
                          value: '$readinessScore%',
                          label: 'Readiness',
                          icon: Icons.rocket_launch_rounded,
                          iconColor: _kPrimaryBlue,
                          isDark: isDark,
                          anim: _statCtrl,
                        ),
                        const SizedBox(width: 10),
                        _AnimatedStatCard(
                          index: 1,
                          value: '$savedCount',
                          label: 'Saved',
                          icon: Icons.bookmark_rounded,
                          iconColor: _kPurple,
                          isDark: isDark,
                          anim: _statCtrl,
                        ),
                        const SizedBox(width: 10),
                        _AnimatedStatCard(
                          index: 2,
                          value: '$completedCount',
                          label: 'Completed',
                          icon: Icons.check_circle_rounded,
                          iconColor: _kGreen,
                          isDark: isDark,
                          anim: _statCtrl,
                        ),
                        const SizedBox(width: 10),
                        _AnimatedStatCard(
                          index: 3,
                          value: '$learningStreak',
                          label: 'Streak 🔥',
                          icon: Icons.local_fire_department_rounded,
                          iconColor: _kOrange,
                          isDark: isDark,
                          anim: _statCtrl,
                        ),
                        const SizedBox(width: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ──────────────────────────────────────────────────────────────
          // SECTION B — Continue Learning Banner (conditional)
          // ──────────────────────────────────────────────────────────────
          if (hasContinueLearning)
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _contentFade,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _ContinueLearningBanner(
                    courseId: enrolledIds.first,
                    courseProgressMap: progMap,
                    onResume: () {
                      HapticFeedback.mediumImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CvUploadScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

          // ──────────────────────────────────────────────────────────────
          // SECTION F — Daily Activity Ring
          // ──────────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _contentFade,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _DailyActivityCard(
                  readiness: readinessScore,
                  streak: learningStreak,
                  courseDone: completedCount,
                  isDark: isDark,
                ),
              ),
            ),
          ),

          // ──────────────────────────────────────────────────────────────
          // SECTION C — Top Job Matches header
          // ──────────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _contentFade,
              child: Padding(
                padding: const EdgeInsets.only(top: 24),
                child: _sectionHeader(
                  context,
                  'Top Job Matches',
                  action: 'See All',
                  onAction: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => JobResultScreen(
                        profile:          profile,
                        selectedIndustry: 'All',
                        selectedLevel:    'All',
                        remoteOnly:       false,
                      ),
                    ),
                  ),
                  isDark: isDark,
                ),
              ),
            ),
          ),

          // ──────────────────────────────────────────────────────────────
          // SECTION C — Top Job Matches list
          // ──────────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _contentFade,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  height: 192,
                  child: recJobs.isEmpty
                      ? _emptyJobsPlaceholder(isDark)
                      : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding:
                    const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: recJobs.length.clamp(0, 8),
                    itemBuilder: (ctx, i) {
                      final dynamic job = recJobs[i];
                      final int score =
                      (job.simScore * 100).round() as int;
                      return _JobCard(
                        heroTag:    'job_card_$i',
                        jobTitle:   job.title as String,
                        company:    job.industry as String,
                        matchScore: score,
                        salary:     _safeJobSalaryRange(job),
                        skills:     _safeJobRequiredSkills(job),
                        isDark:     isDark,
                        onApply: () {
                          HapticFeedback.mediumImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => JobResultScreen(
                                profile:          profile,
                                selectedIndustry: 'All',
                                selectedLevel:    'All',
                                remoteOnly:       false,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          // ──────────────────────────────────────────────────────────────
          // SECTION D — Skill Gap Alert (conditional)
          // ──────────────────────────────────────────────────────────────
          if (missingSkills > 0)
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _contentFade,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _SkillGapBanner(
                    count:  missingSkills,
                    isDark: isDark,
                    pulse:  _pulseCtrl,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfileInputScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

          // ──────────────────────────────────────────────────────────────
          // SECTION G — Trending Skills
          // ──────────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _contentFade,
              child: Padding(
                padding: const EdgeInsets.only(top: 24),
                child: _sectionHeader(
                  context,
                  'Trending Skills',
                  isDark: isDark,
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _contentFade,
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _trendingSkills.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _TrendingChip(
                        label: _trendingSkills[i],
                        isDark: isDark,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ──────────────────────────────────────────────────────────────
          // SECTION E — Recommended Courses header
          // ──────────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _contentFade,
              child: Padding(
                padding: const EdgeInsets.only(top: 24),
                child: _sectionHeader(
                  context,
                  'Recommended Courses',
                  action: 'Browse All',
                  onAction: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CvUploadScreen(),
                    ),
                  ),
                  isDark: isDark,
                ),
              ),
            ),
          ),

          // ──────────────────────────────────────────────────────────────
          // SECTION E — Recommended Courses list
          // ──────────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _contentFade,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                child: recCourses.isEmpty
                    ? _emptyCoursesPlaceholder(isDark)
                    : Column(
                  children: recCourses
                      .take(3)
                      .map(
                        (course) => _CourseCard(
                      courseTitle: course.title as String,
                      platform:    _safeCoursePlatform(course),
                      rating:      (course.rating as num).toDouble(),
                      format:      _safeCourseFormat(course),
                      isDark:      isDark,
                      onEnroll: () {
                        HapticFeedback.mediumImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CvUploadScreen(),
                          ),
                        );
                      },
                    ),
                  )
                      .toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ANIMATED STAT CARD
// ══════════════════════════════════════════════════════════════════════════════

class _AnimatedStatCard extends StatelessWidget {
  final int index;
  final String value;
  final String label;
  final IconData icon;
  final Color iconColor;
  final bool isDark;
  final AnimationController anim;

  const _AnimatedStatCard({
    required this.index,
    required this.value,
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.isDark,
    required this.anim,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, Widget? child) {
        final double delay = (index * 0.12).clamp(0.0, 0.88);
        final double t =
        ((anim.value - delay) / (1.0 - delay)).clamp(0.0, 1.0);
        return Transform.scale(
          scale: Curves.elasticOut.transform(t),
          child: child,
        );
      },
      child: Container(
        width: 104,
        height: 100,
        decoration: _cardDeco(isDark, radius: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _withA(iconColor, isDark ? 0.16 : 0.09),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CONTINUE LEARNING BANNER
// ══════════════════════════════════════════════════════════════════════════════

class _ContinueLearningBanner extends StatelessWidget {
  final String courseId;
  final Map<String, double> courseProgressMap;
  final VoidCallback onResume;

  const _ContinueLearningBanner({
    required this.courseId,
    required this.courseProgressMap,
    required this.onResume,
  });

  @override
  Widget build(BuildContext context) {
    final String courseName = courseId.isNotEmpty ? courseId : 'Your Course';
    final double progress =
    (courseProgressMap[courseId] ?? 0.0).clamp(0.0, 1.0);
    final String pctText = '${(progress * 100).round()}% complete';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF1A56DB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _withA(const Color(0xFF1A56DB), 0.24),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _withA(Colors.white, 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.play_circle_filled_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Continue Learning',
                  style: TextStyle(
                    fontSize: 12,
                    color: _withA(Colors.white, 0.7),
                  ),
                ),
                Text(
                  courseName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (_, double val, __) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: val,
                          backgroundColor: _withA(Colors.white, 0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white),
                          minHeight: 5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pctText,
                        style: TextStyle(
                          fontSize: 10,
                          color: _withA(Colors.white, 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: _withA(Colors.white, 0.15),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: onResume,
              borderRadius: BorderRadius.circular(10),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Text(
                  'Resume',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DAILY ACTIVITY CARD
// ══════════════════════════════════════════════════════════════════════════════

class _DailyActivityCard extends StatelessWidget {
  final int readiness;
  final int streak;
  final int courseDone;
  final bool isDark;

  const _DailyActivityCard({
    required this.readiness,
    required this.streak,
    required this.courseDone,
    required this.isDark,
  });

  Color get _ringColor {
    if (readiness >= 75) return _kGreen;
    if (readiness >= 45) return _kOrange;
    return _kError;
  }

  @override
  Widget build(BuildContext context) {
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor =
    isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDeco(isDark, radius: 20),
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: readiness / 100),
            duration: const Duration(milliseconds: 1100),
            curve: Curves.easeOutCubic,
            builder: (_, double val, __) => SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 8,
                    color: _withA(_ringColor, 0.14),
                  ),
                  CircularProgressIndicator(
                    value: val,
                    strokeWidth: 8,
                    color: _ringColor,
                    strokeCap: StrokeCap.round,
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(val * 100).round()}%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _ringColor,
                          height: 1,
                        ),
                      ),
                      Text(
                        'Ready',
                        style: TextStyle(fontSize: 9, color: subColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Activity',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _ActivityPill(
                      icon: Icons.local_fire_department_rounded,
                      color: _kOrange,
                      value: '${streak}d',
                      label: 'Streak',
                      isDark: isDark,
                    ),
                    const SizedBox(width: 10),
                    _ActivityPill(
                      icon: Icons.check_circle_rounded,
                      color: _kGreen,
                      value: '$courseDone',
                      label: 'Done',
                      isDark: isDark,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  streak == 0
                      ? 'Start a course to build your streak! 💪'
                      : streak >= 7
                      ? '🎉 Outstanding! $streak-day streak!'
                      : '🔥 Keep going — $streak days and counting!',
                  style: TextStyle(fontSize: 12, color: subColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityPill extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final bool isDark;

  const _ActivityPill({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _withA(color, 0.1),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: _withA(color, 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(
            '$value $label',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// JOB CARD
// ══════════════════════════════════════════════════════════════════════════════

class _JobCard extends StatelessWidget {
  final String heroTag;
  final String jobTitle;
  final String company;
  final int matchScore;
  final String salary;
  final List<String> skills;
  final bool isDark;
  final VoidCallback onApply;

  const _JobCard({
    required this.heroTag,
    required this.jobTitle,
    required this.company,
    required this.matchScore,
    required this.salary,
    required this.skills,
    required this.isDark,
    required this.onApply,
  });

  String get _initials {
    final List<String> words = company.trim().split(' ');
    if (words.isEmpty) return '?';
    if (words.length == 1) return words[0][0].toUpperCase();
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final Color surfaceBg = isDark
        ? _withA(_kDarkBg, 0.47)
        : const Color(0xFFF1F5F9);
    final Color subColor =
    isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Hero(
      tag: heroTag,
      child: Container(
        width: 278,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: _cardDeco(isDark, radius: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _withA(_kPrimaryBlue, 0.08),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Center(
                    child: Text(
                      _initials,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _kPrimaryBlue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(company,
                          style: TextStyle(fontSize: 11, color: subColor)),
                      Text(
                        jobTitle,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _MatchChip(score: matchScore),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _InfoChip(label: '📍 Dhaka', bg: surfaceBg, fg: subColor),
                _InfoChip(label: '💼 Full-time', bg: surfaceBg, fg: subColor),
              ],
            ),
            const SizedBox(height: 8),
            if (skills.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  ...skills.take(2).map((s) => _SkillBadge(label: s)),
                  if (skills.length > 2)
                    _SkillBadge(label: '+${skills.length - 2}'),
                ],
              ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Salary',
                        style: TextStyle(fontSize: 10, color: subColor)),
                    Text(
                      '৳ $salary',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kPrimaryBlue,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(100),
                  child: InkWell(
                    onTap: onApply,
                    borderRadius: BorderRadius.circular(100),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1A56DB), Color(0xFF0EA5E9)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [
                          BoxShadow(
                            color: _withA(_kPrimaryBlue, 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Apply →',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SKILL GAP BANNER
// ══════════════════════════════════════════════════════════════════════════════

class _SkillGapBanner extends StatelessWidget {
  final int count;
  final bool isDark;
  final AnimationController pulse;
  final VoidCallback onTap;

  const _SkillGapBanner({
    required this.count,
    required this.isDark,
    required this.pulse,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor =
    isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return AnimatedBuilder(
      animation: pulse,
      builder: (_, Widget? child) {
        final double borderOpacity = 0.3 + 0.5 * pulse.value;
        return Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Ink(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? _kDarkCard : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _withA(const Color(0xFF1A56DB), borderOpacity),
                  width: 1.5,
                ),
              ),
              child: child,
            ),
          ),
        );
      },
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A56DB), Color(0xFF0EA5E9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: _withA(_kPrimaryBlue, 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.trending_up_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Skill Gap Detected 🎯',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Learn $count skill${count == 1 ? '' : 's'} to boost job matches by up to 40%',
                  style: TextStyle(fontSize: 13, color: subColor),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: subColor),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TRENDING CHIP
// ══════════════════════════════════════════════════════════════════════════════

class _TrendingChip extends StatelessWidget {
  final String label;
  final bool isDark;

  const _TrendingChip({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        onTap: () => HapticFeedback.selectionClick(),
        borderRadius: BorderRadius.circular(100),
        child: Ink(
          padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? _kDarkCard : _kLightBg,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: isDark ? _kDarkBorder : _kLightBorder,
            ),
            boxShadow: isDark
                ? null
                : [
              BoxShadow(
                color: _withA(Colors.black, 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MATCH CHIP
// ══════════════════════════════════════════════════════════════════════════════

class _MatchChip extends StatelessWidget {
  final int score;

  const _MatchChip({required this.score});

  Color get _color {
    if (score >= 75) return _kMatchGreen;
    if (score >= 50) return _kOrange;
    return _kError;
  }

  Color get _bg {
    if (score >= 75) return _kMatchGreenBg;
    if (score >= 50) return const Color(0xFFFEF3C7);
    return const Color(0xFFFEE2E2);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
      ),
      child: Text(
        '$score%',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _color,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// INFO CHIP
// ══════════════════════════════════════════════════════════════════════════════

class _InfoChip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const _InfoChip({
    required this.label,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: fg)),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SKILL BADGE
// ══════════════════════════════════════════════════════════════════════════════

class _SkillBadge extends StatelessWidget {
  final String label;

  const _SkillBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _withA(_kPrimaryBlue, 0.07),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
        border: Border.all(color: _withA(_kPrimaryBlue, 0.2)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: _kPrimaryBlue,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// COURSE CARD
// ══════════════════════════════════════════════════════════════════════════════

class _CourseCard extends StatelessWidget {
  final String courseTitle;
  final String platform;
  final double rating;
  final String format;
  final bool isDark;
  final VoidCallback onEnroll;

  const _CourseCard({
    required this.courseTitle,
    required this.platform,
    required this.rating,
    required this.format,
    required this.isDark,
    required this.onEnroll,
  });

  Color get _platformColor {
    final String p = platform.toLowerCase();
    if (p.contains('coursera')) return const Color(0xFF0056D2);
    if (p.contains('udemy')) return const Color(0xFFEC5252);
    if (p.contains('edx')) return const Color(0xFF02262B);
    if (p.contains('linkedin')) return const Color(0xFF0077B5);
    return _kPrimaryBlue;
  }

  @override
  Widget build(BuildContext context) {
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor =
    isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color formatBg =
    isDark ? _withA(_kPrimaryBlue, 0.16) : const Color(0xFFDBEAFE);

    final double ratingVal = rating > 0 ? rating : 4.5;
    final String ratingStr = ratingVal.toStringAsFixed(1);
    final int starsFull = ratingVal.floor();
    final bool hasHalf = (ratingVal - starsFull) >= 0.5;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(isDark, radius: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _platformColor,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: _withA(_platformColor, 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.play_lesson_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  courseTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  platform.isNotEmpty ? platform : 'Coursera',
                  style: TextStyle(fontSize: 12, color: subColor),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    ...List.generate(5, (i) {
                      if (i < starsFull) {
                        return const Icon(Icons.star_rounded,
                            color: _kOrange, size: 13);
                      }
                      if (i == starsFull && hasHalf) {
                        return const Icon(Icons.star_half_rounded,
                            color: _kOrange, size: 13);
                      }
                      return Icon(Icons.star_outline_rounded,
                          color: _withA(_kOrange, 0.35), size: 13);
                    }),
                    const SizedBox(width: 5),
                    Text(
                      ratingStr,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _kOrange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: formatBg,
                  borderRadius: const BorderRadius.all(Radius.circular(20)),
                ),
                child: Text(
                  format.isNotEmpty ? format : 'Video',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _kPrimaryBlue,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: onEnroll,
                  borderRadius: BorderRadius.circular(8),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1A56DB), Color(0xFF0EA5E9)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Enroll →',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}