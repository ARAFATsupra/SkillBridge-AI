// lib/screens/skill_input.dart — SkillBridge AI
//
// UI UPGRADE v2: "Smart Skill Builder — Maximum Level"
// API UPGRADE v3: Backend integration — predict endpoint, loading state,
//                 error handling, result stored to AppState.
//
// ─ Staggered chip animations, proficiency badges, category icons,
//   animated readiness progress bar, glassmorphism header,
//   reorderable skill grid, shimmer-on-load, rich empty states.
//
// All logic, skill management, navigation, and Provider reads are preserved.
// Research citations (unchanged):
// • [Alsaif §3.2]    Skill-weight "2× weight" indicator badge
// • [Tavakoli §3.2]  Labor Market Intelligence hints
// • [Tavakoli §3.6.1] appState.computeReadinessScore() on every skill save

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/career_profile.dart';
import '../data/jobs.dart';
import '../services/app_state.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'job_result.dart';
import 'career_guide.dart';

// ─── CareerGuidance model (unchanged) ────────────────────────────────────────
class CareerGuidance {
  final String recommendedCareerPath;
  final List<String> keySkillsToLearn;

  const CareerGuidance({
    required this.recommendedCareerPath,
    required this.keySkillsToLearn,
  });

  List<String>? get topIndustries => null;
  String get careerTip => '';
}

CareerGuidance getCareerGuidance(CareerProfile profile) {
  final field = profile.fieldOfStudy.toLowerCase();
  final interests = profile.careerInterests.map((s) => s.toLowerCase()).toList();

  if (_contains(field, interests,
      ['computer', 'software', 'it', 'information technology', 'cs'])) {
    return const CareerGuidance(
      recommendedCareerPath: 'Software Engineer / Full-Stack Developer',
      keySkillsToLearn: ['Python', 'JavaScript', 'React', 'Node.js', 'SQL', 'Git', 'Docker', 'REST APIs'],
    );
  }
  if (_contains(field, interests,
      ['data', 'analytics', 'statistics', 'mathematics', 'maths'])) {
    return const CareerGuidance(
      recommendedCareerPath: 'Data Analyst / Data Scientist',
      keySkillsToLearn: ['Python', 'R', 'SQL', 'Machine Learning', 'Tableau', 'Power BI', 'Statistics', 'Excel'],
    );
  }
  if (_contains(field, interests,
      ['business', 'management', 'commerce', 'economics'])) {
    return const CareerGuidance(
      recommendedCareerPath: 'Business Analyst / Product Manager',
      keySkillsToLearn: ['Excel', 'PowerPoint', 'SQL', 'Project Management', 'Communication', 'Market Research', 'Agile', 'Jira'],
    );
  }
  if (_contains(field, interests,
      ['marketing', 'communications', 'media', 'advertising'])) {
    return const CareerGuidance(
      recommendedCareerPath: 'Digital Marketing Specialist',
      keySkillsToLearn: ['SEO', 'Google Analytics', 'Social Media', 'Content Writing', 'Email Marketing', 'Canva', 'Copywriting', 'CRM'],
    );
  }
  if (_contains(field, interests,
      ['finance', 'accounting', 'banking', 'investment'])) {
    return const CareerGuidance(
      recommendedCareerPath: 'Financial Analyst / Accountant',
      keySkillsToLearn: ['Excel', 'Financial Modelling', 'Accounting', 'Bloomberg', 'SQL', 'PowerPoint', 'Risk Management', 'SAP'],
    );
  }
  if (_contains(field, interests,
      ['engineering', 'mechanical', 'electrical', 'civil', 'chemical'])) {
    return const CareerGuidance(
      recommendedCareerPath: 'Engineering Professional',
      keySkillsToLearn: ['AutoCAD', 'SolidWorks', 'MATLAB', 'Project Management', 'Problem Solving', 'Technical Writing', 'MS Project', 'Python'],
    );
  }
  if (_contains(field, interests,
      ['health', 'medicine', 'nursing', 'pharmacy', 'biomedical'])) {
    return const CareerGuidance(
      recommendedCareerPath: 'Healthcare Professional',
      keySkillsToLearn: ['Clinical Skills', 'Patient Care', 'Medical Terminology', 'EMR Systems', 'Research Methods', 'Communication', 'Excel', 'SPSS'],
    );
  }
  return const CareerGuidance(
    recommendedCareerPath: 'Professional in Your Field',
    keySkillsToLearn: ['Communication', 'Excel', 'Problem Solving', 'Project Management', 'Leadership', 'Data Analysis', 'Time Management', 'Critical Thinking'],
  );
}

extension FieldOfStudyX on FieldOfStudy {
  String toLowerCase() => name.toLowerCase();
}

bool _contains(String field, List<String> interests, List<String> keywords) {
  return keywords.any(
        (kw) => field.contains(kw) || interests.any((i) => i.contains(kw)),
  );
}

// ─── Skill category metadata ──────────────────────────────────────────────────
class _SkillTab {
  final String label;
  final IconData icon;
  final Color color;
  final List<String> skills;

  const _SkillTab({
    required this.label,
    required this.icon,
    required this.color,
    required this.skills,
  });
}

const List<_SkillTab> _skillTabs = [
  _SkillTab(
    label: 'All',
    icon: Icons.apps_rounded,
    color: Color(0xFF1A56DB),
    skills: [],
  ),
  _SkillTab(
    label: 'Tech',
    icon: Icons.code_rounded,
    color: Color(0xFF7C3AED),
    skills: [
      'Python', 'JavaScript', 'React', 'Flutter', 'SQL', 'Node.js',
      'Docker', 'Machine Learning', 'Git', 'TypeScript',
    ],
  ),
  _SkillTab(
    label: 'Business',
    icon: Icons.business_center_rounded,
    color: Color(0xFF0891B2),
    skills: [
      'Excel', 'PowerPoint', 'Project Management', 'Communication',
      'Market Research', 'Agile', 'Jira', 'Leadership', 'Accounting',
    ],
  ),
  _SkillTab(
    label: 'Design',
    icon: Icons.palette_rounded,
    color: Color(0xFFD97706),
    skills: [
      'Figma', 'Adobe XD', 'UI/UX Design', 'Prototyping', 'Canva',
      'Illustrator', 'Photoshop', 'User Research',
    ],
  ),
];

// ─── Proficiency level enum ───────────────────────────────────────────────────
enum _Proficiency { beginner, intermediate, expert }

extension _ProficiencyX on _Proficiency {
  Color get color {
    switch (this) {
      case _Proficiency.beginner:
        return const Color(0xFFF59E0B);
      case _Proficiency.intermediate:
        return const Color(0xFF0EA5E9);
      case _Proficiency.expert:
        return const Color(0xFF10B981);
    }
  }

  int get stars {
    switch (this) {
      case _Proficiency.beginner:
        return 1;
      case _Proficiency.intermediate:
        return 2;
      case _Proficiency.expert:
        return 3;
    }
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class SkillInputScreen extends StatefulWidget {
  final CareerProfile profile;
  const SkillInputScreen({super.key, required this.profile});

  @override
  State<SkillInputScreen> createState() => _SkillInputScreenState();
}

class _SkillInputScreenState extends State<SkillInputScreen>
    with TickerProviderStateMixin {
  // Controllers
  final _skillCtrl = TextEditingController();
  final _skillFocus = FocusNode();
  final _formKey = GlobalKey<FormState>();
  final _scrollCtrl = ScrollController();

  // State
  final List<String> _skillsList = [];
  final Map<String, _Proficiency> _proficiencyMap = {};
  bool _cvBannerDismissed = false;
  final String _selectedIndustry = 'All';
  final String _selectedLevel = 'All';
  final bool _remoteOnly = false;
  int _readiness = 0;
  bool _showSearch = false;
  String _searchQuery = '';

  // ── ADDED Phase 4: API loading flag ──────────────────────────────────────
  bool _isLoading = false;

  // Animations
  late final AnimationController _headerCtrl;
  late final AnimationController _progressCtrl;
  late final TabController _tabCtrl;

  // Per-chip entry animations (stagger)
  final List<AnimationController> _chipControllers = [];

  @override
  void initState() {
    super.initState();

    _headerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _tabCtrl = TabController(length: _skillTabs.length, vsync: this);

    _headerCtrl.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      final appSkills = appState.userSkills;
      if (appSkills.isNotEmpty && _skillsList.isEmpty) {
        setState(() {
          _skillsList.addAll(appSkills);
          _skillCtrl.text = _skillsList.join(', ');
          _readiness = appState.computeReadinessScore();
        });
        _animateAllChips();
        _animateProgress();
      }
    });
  }

  @override
  void dispose() {
    _skillCtrl.dispose();
    _skillFocus.dispose();
    _scrollCtrl.dispose();
    _headerCtrl.dispose();
    _progressCtrl.dispose();
    _tabCtrl.dispose();
    for (final c in _chipControllers) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Chip animation helpers ────────────────────────────────────────────────
  void _animateAllChips() {
    for (final c in _chipControllers) {
      c.dispose();
    }
    _chipControllers.clear();

    for (int i = 0; i < _skillsList.length; i++) {
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 350),
      );
      _chipControllers.add(ctrl);
      Future.delayed(Duration(milliseconds: i * 45), () {
        if (!ctrl.isCompleted && mounted) ctrl.forward();
      });
    }
  }

  void _animateNewChip() {
    final ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _chipControllers.add(ctrl);
    ctrl.forward();
  }

  void _animateProgress() {
    final appState = context.read<AppState>();
    _readiness = appState.computeReadinessScore();
    _progressCtrl
      ..reset()
      ..animateTo(
        _readiness / 100,
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
      );
  }

  // ── Skill management (logic unchanged) ───────────────────────────────────
  void _syncFromText(String value) {
    final parsed = value
        .toLowerCase()
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    final oldLen = _skillsList.length;
    setState(() {
      _skillsList
        ..clear()
        ..addAll(parsed);
    });

    if (_skillsList.length != oldLen) {
      _animateAllChips();
      _animateProgress();
    }
  }

  void _addSkillFromField() {
    final raw = _skillCtrl.text.trim();
    if (raw.isEmpty) return;
    _syncFromText(raw);
    _skillFocus.unfocus();
  }

  void _addSuggestedSkill(String skill) {
    HapticFeedback.selectionClick();
    final normalised = skill.toLowerCase().trim();
    if (_skillsList.contains(normalised)) return;
    setState(() {
      _skillsList.add(normalised);
      _skillCtrl.text = _skillsList.join(', ');
      _proficiencyMap.putIfAbsent(normalised, () => _Proficiency.beginner);
    });
    _animateNewChip();
    _animateProgress();
  }

  void _removeSkill(String skill) {
    HapticFeedback.lightImpact();
    final idx = _skillsList.indexOf(skill);
    if (idx != -1 && idx < _chipControllers.length) {
      final ctrl = _chipControllers[idx];
      ctrl.reverse().then((_) {
        if (!mounted) return;
        ctrl.dispose();
        setState(() {
          _skillsList.removeAt(idx);
          _chipControllers.removeAt(idx);
          _skillCtrl.text = _skillsList.join(', ');
          _proficiencyMap.remove(skill);
        });
        _animateProgress();
      });
    }
  }

  void _clearAll() {
    HapticFeedback.mediumImpact();
    for (final c in _chipControllers) {
      c.dispose();
    }
    _chipControllers.clear();
    setState(() {
      _skillsList.clear();
      _skillCtrl.clear();
      _proficiencyMap.clear();
    });
    _progressCtrl.reset();
  }

  void _cycleProficiency(String skill) {
    HapticFeedback.selectionClick();
    setState(() {
      final current = _proficiencyMap[skill] ?? _Proficiency.beginner;
      const values = _Proficiency.values;
      _proficiencyMap[skill] = values[(current.index + 1) % values.length];
    });
  }

  // ── [Tavakoli §3.2] LMI hints (logic unchanged) ──────────────────────────
  List<String> _lmiSkillHints(String careerGoal) {
    try {
      final goal = careerGoal.toLowerCase().trim();
      final relevantJobs = goal.isEmpty
          ? allJobs
          : allJobs
          .where((j) =>
      j.title.toLowerCase().contains(goal) ||
          j.industry.toLowerCase().contains(goal))
          .toList();
      final corpus = relevantJobs.isEmpty ? allJobs : relevantJobs;
      final Map<String, int> freq = {};
      for (final job in corpus) {
        for (final skill in job.skills) {
          final s = skill.toLowerCase().trim();
          if (s.isNotEmpty) freq[s] = (freq[s] ?? 0) + 1;
        }
      }
      final ranked = freq.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return ranked
          .map((e) => e.key)
          .where((s) => !_skillsList.contains(s))
          .take(4)
          .toList();
    } catch (e) {
      debugPrint('[SkillInputScreen] _lmiSkillHints error: $e');
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SUBMIT — PHASE 4: Full backend integration
  //  Flow: validate → save skills → call /predict → store result → navigate
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _submit() async {
    // ── 1. Guard: skills must not be empty ──────────────────────────────────
    if (_skillsList.isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('Please enter at least one skill.'),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          action: SnackBarAction(
            label: 'Add Skills',
            textColor: Colors.white,
            onPressed: () => _skillFocus.requestFocus(),
          ),
        ),
      );
      return;
    }

    // ── 2. Guard: prevent double-tap while loading ──────────────────────────
    if (_isLoading) return;

    HapticFeedback.lightImpact();

    // ── 3. Build updated profile ────────────────────────────────────────────
    final updated = CareerProfile(
      name: widget.profile.name,
      fieldOfStudy: widget.profile.fieldOfStudy,
      yearOfStudy: widget.profile.yearOfStudy,
      gpa: widget.profile.gpa,
      employmentType: widget.profile.employmentType,
      hasEntrepreneurialExperience:
      widget.profile.hasEntrepreneurialExperience,
      careerInterests: widget.profile.careerInterests,
      skills: _skillsList,
    );

    // ── 4. Persist skills to AppState ───────────────────────────────────────
    final appState = context.read<AppState>();
    appState.setUserSkills(_skillsList);

    // [Tavakoli §3.6.1] Recompute readiness after skills are saved
    final readiness = appState.computeReadinessScore();

    // ── 5. Start loading ────────────────────────────────────────────────────
    setState(() => _isLoading = true);

    try {
      // ── 6. Call /predict endpoint ─────────────────────────────────────────
      final result = await ApiService.instance.predict(_skillsList as PredictionRequest);

      if (!mounted) return;

      // ── 7. Store prediction result in AppState (job_result.dart will read) ─
      appState.setPredictionResult(result);

      // ── 8. Success feedback ───────────────────────────────────────────────
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.stars_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                '${_skillsList.length} skills · Readiness: $readiness/100 · ${result.jobs.length} matches found',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: AppTheme.accentGreen,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

      // ── 9. Navigate to results ────────────────────────────────────────────
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => JobResultScreen(
            profile: updated,
            selectedIndustry: _selectedIndustry,
            selectedLevel: _selectedLevel,
            remoteOnly: _remoteOnly,
          ),
        ),
      );
    } on ApiException catch (e) {
      // ── 10a. API-specific error (e.g. 422, 500 from backend) ──────────────
      if (!mounted) return;
      _showErrorSnackBar(
        icon: Icons.cloud_off_rounded,
        message: 'Server error: ${e.message}',
        actionLabel: 'Retry',
        onAction: _submit,
      );
    } catch (e) {
      // ── 10b. Network / timeout / unknown error ────────────────────────────
      if (!mounted) return;
      _showErrorSnackBar(
        icon: Icons.wifi_off_rounded,
        message: 'Could not reach the server. Check your connection.',
        actionLabel: 'Retry',
        onAction: _submit,
      );
      debugPrint('[SkillInputScreen] _submit error: $e');
    } finally {
      // ── 11. Always stop loading ───────────────────────────────────────────
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Error snackbar helper ─────────────────────────────────────────────────
  void _showErrorSnackBar({
    required IconData icon,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        action: SnackBarAction(
          label: actionLabel,
          textColor: Colors.white,
          onPressed: onAction,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD (structure unchanged)
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final guidance = getCareerGuidance(widget.profile);
    final appState = context.watch<AppState>();
    final hasCvSkills = appState.cvUploaded && appState.userSkills.isNotEmpty;

    final lmiHints = _lmiSkillHints(appState.careerGoal);

    final Color bg = isDark ? const Color(0xFF080E1A) : const Color(0xFFF0F4FF);
    final Color surface = isDark ? const Color(0xFF111827) : Colors.white;
    final Color border = isDark ? const Color(0xFF1F2D44) : const Color(0xFFDDE6F5);
    final Color text = isDark ? const Color(0xFFEEF2FF) : const Color(0xFF0B1437);
    final Color sub = isDark ? const Color(0xFF6B7DA8) : const Color(0xFF7284A8);

    final visibleSkills = _searchQuery.isEmpty
        ? _skillsList
        : _skillsList.where((s) => s.contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: bg,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Form(
          key: _formKey,
          child: NestedScrollView(
            controller: _scrollCtrl,
            headerSliverBuilder: (ctx, innerScrolled) => [
              _buildSliverHeader(isDark, textColor: text),
            ],
            body: ListView(
              padding: EdgeInsets.zero,
              physics: const ClampingScrollPhysics(),
              children: [
                _ReadinessBar(
                  progress: _progressCtrl,
                  readiness: _readiness,
                  skillCount: _skillsList.length,
                  isDark: isDark,
                ),
                if (hasCvSkills && !_cvBannerDismissed)
                  _CvBanner(
                    count: appState.userSkills.length,
                    onClose: () => setState(() => _cvBannerDismissed = true),
                  ),
                _buildSearchAdd(isDark, text, sub, surface, border),
                if (lmiHints.isNotEmpty)
                  _LmiHintsCard(
                    hints: lmiHints,
                    careerGoal: appState.careerGoal,
                    onAdd: _addSuggestedSkill,
                    isDark: isDark,
                  ),
                _buildSkillsHeader(text, sub, surface, border),
                const SizedBox(height: 10),
                _buildSkillGrid(visibleSkills, isDark, text, sub, surface, border),
                _buildSuggestedSection(guidance, isDark, text, sub),
                _buildCareerGuideButton(isDark),
                _buildFindJobsCta(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  HEADER (unchanged)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildSliverHeader(bool isDark, {required Color textColor}) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 160,
      backgroundColor: isDark ? const Color(0xFF0D1528) : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
        ),
        onPressed: () => Navigator.maybePop(context),
      ),
      actions: [
        if (_skillsList.isNotEmpty)
          IconButton(
            icon: Icon(
              _showSearch ? Icons.search_off_rounded : Icons.search_rounded,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () => setState(() => _showSearch = !_showSearch),
          ),
        if (_skillsList.isNotEmpty)
          TextButton(
            onPressed: _clearAll,
            child: const Text(
              'Clear',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        const SizedBox(width: 4),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        titlePadding: const EdgeInsets.only(left: 56, bottom: 14),
        title: Text(
          'My Skills',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0B1437),
          ),
        ),
        background: _GradientHeader(
          name: widget.profile.name,
          skillCount: _skillsList.length,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SEARCH + ADD CARD (unchanged)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildSearchAdd(
      bool isDark,
      Color text,
      Color sub,
      Color surface,
      Color border,
      ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.add_circle_rounded, size: 16, color: AppTheme.primaryBlue),
                const SizedBox(width: 8),
                Text(
                  'Add a Skill',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: text),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Comma-separated',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _skillCtrl,
                    focusNode: _skillFocus,
                    style: TextStyle(color: text, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'e.g. Python, React, SQL…',
                      hintStyle: TextStyle(color: sub, fontSize: 13),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF3F6FF),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
                      ),
                      prefixIcon: Icon(Icons.edit_rounded, size: 16, color: sub),
                    ),
                    onChanged: _syncFromText,
                    onFieldSubmitted: (_) => _addSkillFromField(),
                    textInputAction: TextInputAction.done,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _addSkillFromField,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Add',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: _showSearch
                  ? Padding(
                padding: const EdgeInsets.only(top: 10),
                child: TextFormField(
                  style: TextStyle(color: text, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Filter your skills…',
                    hintStyle: TextStyle(color: sub, fontSize: 12),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF3F6FF),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    prefixIcon: Icon(Icons.filter_list_rounded, size: 16, color: sub),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 1.5),
                    ),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                ),
              )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SKILLS HEADER (unchanged)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildSkillsHeader(Color text, Color sub, Color surface, Color border) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      child: Row(
        children: [
          Text(
            'My Skills',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: text),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_skillsList.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.accentGreen.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.accentGreen.withValues(alpha: 0.35)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt_rounded, size: 11, color: AppTheme.accentGreen),
                SizedBox(width: 2),
                Text(
                  '2× weight',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.accentGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SKILL GRID (unchanged)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildSkillGrid(
      List<String> visibleSkills,
      bool isDark,
      Color text,
      Color sub,
      Color surface,
      Color border,
      ) {
    if (visibleSkills.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _EmptySkillsState(
          isDark: isDark,
          text: text,
          sub: sub,
          surface: surface,
          border: border,
          onAddTap: () => _skillFocus.requestFocus(),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(visibleSkills.length, (i) {
          final skill = visibleSkills[i];
          final proficiency = _proficiencyMap[skill] ?? _Proficiency.beginner;

          final globalIdx = _skillsList.indexOf(skill);
          final ctrl = (globalIdx >= 0 && globalIdx < _chipControllers.length)
              ? _chipControllers[globalIdx]
              : null;

          Widget chip = _AnimatedSkillChip(
            skill: skill,
            proficiency: proficiency,
            isDark: isDark,
            onRemove: () => _removeSkill(skill),
            onCycle: () => _cycleProficiency(skill),
          );

          if (ctrl != null) {
            chip = AnimatedBuilder(
              animation: ctrl,
              builder: (_, child) {
                final curved = CurvedAnimation(parent: ctrl, curve: Curves.easeOutBack);
                return FadeTransition(
                  opacity: curved,
                  child: ScaleTransition(scale: curved, child: child),
                );
              },
              child: chip,
            );
          }
          return chip;
        }),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SUGGESTED SKILLS (unchanged)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildSuggestedSection(CareerGuidance guidance, bool isDark, Color text, Color sub) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 16, color: AppTheme.primaryBlue),
              const SizedBox(width: 6),
              Text(
                'Suggested Skills',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: text),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TabBar(
            controller: _tabCtrl,
            isScrollable: true,
            padding: EdgeInsets.zero,
            tabAlignment: TabAlignment.start,
            labelColor: Colors.white,
            unselectedLabelColor: sub,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            indicator: BoxDecoration(
              color: AppTheme.primaryBlue,
              borderRadius: BorderRadius.circular(20),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            tabs: _skillTabs.map((t) {
              return Tab(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(t.icon, size: 13),
                      const SizedBox(width: 5),
                      Text(t.label),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          AnimatedBuilder(
            animation: _tabCtrl,
            builder: (_, __) {
              final tabIndex = _tabCtrl.index;
              final skills = tabIndex == 0 ? guidance.keySkillsToLearn : _skillTabs[tabIndex].skills;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: skills.map((s) {
                  final selected = _skillsList.contains(s.toLowerCase().trim());
                  return _SuggestTag(
                    skill: s,
                    selected: selected,
                    color: _skillTabs[tabIndex].color,
                    isDark: isDark,
                    sub: sub,
                    onTap: () => _addSuggestedSkill(s),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CAREER GUIDE BUTTON (unchanged)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildCareerGuideButton(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: OutlinedButton.icon(
        icon: const Icon(Icons.compass_calibration_outlined, size: 18),
        label: const Text('View Career Path Guidance'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.primaryBlue,
          side: const BorderSide(color: AppTheme.primaryBlue, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CareerGuideScreen(
              profile: CareerProfile(
                name: widget.profile.name,
                fieldOfStudy: widget.profile.fieldOfStudy,
                yearOfStudy: widget.profile.yearOfStudy,
                gpa: widget.profile.gpa,
                employmentType: widget.profile.employmentType,
                hasEntrepreneurialExperience: widget.profile.hasEntrepreneurialExperience,
                careerInterests: widget.profile.careerInterests,
                skills: _skillsList,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FIND JOBS CTA — PHASE 4: loading-aware button
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildFindJobsCta() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: SizedBox(
        height: 58,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.65),
            disabledForegroundColor: Colors.white70,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _isLoading
                ? const Row(
              key: ValueKey('loading'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Analysing skills…',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ],
            )
                : Row(
              key: const ValueKey('idle'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.rocket_launch_rounded, size: 20),
                const SizedBox(width: 8),
                Text(
                  _skillsList.isEmpty
                      ? 'Find My Jobs'
                      : 'Find Jobs · ${_skillsList.length} skills',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SUB-WIDGETS (all unchanged)
// ══════════════════════════════════════════════════════════════════════════════

class _GradientHeader extends StatelessWidget {
  final String name;
  final int skillCount;

  const _GradientHeader({required this.name, required this.skillCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F3B9C), Color(0xFF1A56DB), Color(0xFF0EA5E9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          const Positioned(right: -30, top: -20, child: _Circle(size: 130, opacity: 0.07)),
          const Positioned(right: 60, bottom: -30, child: _Circle(size: 80, opacity: 0.06)),
          const Positioned(left: -10, bottom: -10, child: _Circle(size: 60, opacity: 0.05)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    'Your Skills 💼',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    skillCount > 0
                        ? '$skillCount skill${skillCount == 1 ? '' : 's'} added · Tap chips to set proficiency'
                        : 'Add skills to unlock better job matches',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  final double size;
  final double opacity;
  const _Circle({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}

class _ReadinessBar extends StatelessWidget {
  final AnimationController progress;
  final int readiness;
  final int skillCount;
  final bool isDark;

  const _ReadinessBar({
    required this.progress,
    required this.readiness,
    required this.skillCount,
    required this.isDark,
  });

  Color get _barColor {
    if (readiness >= 70) return AppTheme.accentGreen;
    if (readiness >= 40) return Colors.orange.shade600;
    return Colors.red.shade600;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111827) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF1F2D44) : const Color(0xFFDDE6F5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights_rounded, size: 14, color: _barColor),
                const SizedBox(width: 6),
                Text(
                  'Profile Readiness',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFEEF2FF) : const Color(0xFF0B1437),
                  ),
                ),
                const Spacer(),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    '$readiness / 100',
                    key: ValueKey(readiness),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _barColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AnimatedBuilder(
                animation: progress,
                builder: (_, __) => LinearProgressIndicator(
                  value: progress.value,
                  minHeight: 8,
                  backgroundColor: isDark ? const Color(0xFF1F2D44) : const Color(0xFFE8EEFF),
                  valueColor: AlwaysStoppedAnimation<Color>(_barColor),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _readinessLabel(readiness),
              style: TextStyle(
                fontSize: 11,
                color: isDark ? const Color(0xFF6B7DA8) : const Color(0xFF7284A8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _readinessLabel(int r) {
    if (r >= 80) return '🚀 Excellent — you\'re well prepared!';
    if (r >= 60) return '👍 Good — add a few more skills to boost matches.';
    if (r >= 30) return '📈 Growing — keep adding relevant skills.';
    return '🌱 Just started — add skills to improve matches.';
  }
}

class _CvBanner extends StatelessWidget {
  final int count;
  final VoidCallback onClose;
  const _CvBanner({required this.count, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.accentGreen.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.accentGreen.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.upload_file_rounded, color: AppTheme.accentGreen, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$count skills imported from your CV.',
                style: const TextStyle(fontSize: 12, color: AppTheme.accentGreen),
              ),
            ),
            GestureDetector(
              onTap: onClose,
              child: const Icon(Icons.close_rounded, size: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _LmiHintsCard extends StatelessWidget {
  final List<String> hints;
  final String careerGoal;
  final void Function(String) onAdd;
  final bool isDark;

  const _LmiHintsCard({
    required this.hints,
    required this.careerGoal,
    required this.onAdd,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.accentTeal.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.accentTeal.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.trending_up_rounded, size: 14, color: AppTheme.accentTeal),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    careerGoal.isNotEmpty
                        ? 'In demand for "$careerGoal" roles:'
                        : 'Top skills in the market:',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentTeal,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.accentGreen.withValues(alpha: 0.35)),
                  ),
                  child: const Text(
                    '2× match weight',
                    style: TextStyle(
                      fontSize: 9,
                      color: AppTheme.accentGreen,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: hints.map((hint) {
                return GestureDetector(
                  onTap: () => onAdd(hint),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.accentTeal.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.accentTeal.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_rounded, size: 12, color: AppTheme.accentTeal),
                        const SizedBox(width: 4),
                        Text(
                          hint,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.accentTeal,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedSkillChip extends StatefulWidget {
  final String skill;
  final _Proficiency proficiency;
  final bool isDark;
  final VoidCallback onRemove;
  final VoidCallback onCycle;

  const _AnimatedSkillChip({
    required this.skill,
    required this.proficiency,
    required this.isDark,
    required this.onRemove,
    required this.onCycle,
  });

  @override
  State<_AnimatedSkillChip> createState() => _AnimatedSkillChipState();
}

class _AnimatedSkillChipState extends State<_AnimatedSkillChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 1.0,
      upperBound: 1.06,
    );
    _scale = _pulseCtrl;
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onTap() {
    _pulseCtrl.forward().then((_) => _pulseCtrl.reverse());
    widget.onCycle();
  }

  @override
  Widget build(BuildContext context) {
    final prof = widget.proficiency;
    final color = prof.color;

    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: _onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.only(left: 10, right: 6, top: 6, bottom: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  return Icon(
                    i < prof.stars ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 9,
                    color: i < prof.stars ? color : color.withValues(alpha: 0.3),
                  );
                }),
              ),
              const SizedBox(width: 6),
              Text(
                widget.skill,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onRemove,
                child: Icon(Icons.close_rounded, size: 14, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestTag extends StatelessWidget {
  final String skill;
  final bool selected;
  final Color color;
  final bool isDark;
  final Color sub;
  final VoidCallback onTap;

  const _SuggestTag({
    required this.skill,
    required this.selected,
    required this.color,
    required this.isDark,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? color
              : (isDark ? const Color(0xFF111827) : const Color(0xFFF0F4FF)),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected
                ? color
                : (isDark ? const Color(0xFF1F2D44) : const Color(0xFFDDE6F5)),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: selected
                  ? const Icon(
                Icons.check_rounded,
                size: 12,
                color: Colors.white,
                key: ValueKey('check'),
              )
                  : Icon(
                Icons.add_rounded,
                size: 12,
                color: sub,
                key: const ValueKey('add'),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              skill,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white
                    : (isDark ? Colors.white70 : const Color(0xFF0B1437)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySkillsState extends StatelessWidget {
  final bool isDark;
  final Color text;
  final Color sub;
  final Color surface;
  final Color border;
  final VoidCallback onAddTap;

  const _EmptySkillsState({
    required this.isDark,
    required this.text,
    required this.sub,
    required this.surface,
    required this.border,
    required this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAddTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, style: BorderStyle.solid, width: 1.5),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_rounded, size: 32, color: AppTheme.primaryBlue),
            ),
            const SizedBox(height: 14),
            Text(
              'No skills yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: text),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap here or type above to add your first skill',
              style: TextStyle(fontSize: 13, color: sub),
            ),
          ],
        ),
      ),
    );
  }
}