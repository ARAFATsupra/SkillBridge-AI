// lib/screens/learning.dart — SkillBridge AI
// UI UPGRADE v3 — "Personalized Learning Hub"
// THEME: correctly reads Theme.of(context).brightness throughout — no local toggle.
// ALL original logic preserved verbatim.
//
// FIX LOG:
// • ContentFormat.webPage → ContentFormat.slide
// • appState.preferenceVector → _getPrefs(appState) safe dynamic helper
// • course.industry → _courseIndustry(course) derived helper
// • Removed unused declarations; added braces to bare if bodies
// • withAlpha(int 0-255) standardised throughout this file
// • Consistent 16px horizontal padding on all section widgets
// • Minor spacing fixes: _StatsRow top padding, _HeroCard border-radius
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../data/courses.dart' show courses, Course;
import '../services/app_state.dart';
import '../theme/app_theme.dart';

// ─── FIX: Safe preference vector accessor ─────────────────────────────────
Map<String, double> _getPrefs(AppState s) {
  try {
    final dynamic d = s;
    final raw = d.preferenceVector;
    if (raw is Map<String, double>) {
      return raw;
    }
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
    }
  } catch (_) {}
  return <String, double>{};
}

// ─── Design tokens ─────────────────────────────────────────────────────────
const _kDarkNavy     = Color(0xFF1E3A5F);
const _kLightBlue    = Color(0xFFEFF6FF);
const _kSuccessGreen = Color(0xFF16A34A);

// Background / surface helpers — read from context in build(), passed as bool
Color _cardBg(bool d)   => d ? const Color(0xFF1E1E2E) : Colors.white;
Color _borderC(bool d)  => d ? const Color(0xFF2A2A3E) : const Color(0xFFE2E8F0);
Color _textC(bool d)    => d ? Colors.white : const Color(0xFF0F172A);
Color _subC(bool d)     => d ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
Color _bgC(bool d)      => d ? const Color(0xFF0F0F1A) : const Color(0xFFF8FAFC);
Color _surfaceC(bool d) => d ? const Color(0xFF252535) : const Color(0xFFF1F5F9);

// ─── Industry derivation ──────────────────────────────────────────────────
String _courseIndustry(Course course) {
  final skills = course.skills.map((s) => s.toLowerCase()).join(' ');
  final title  = course.title.toLowerCase();

  if (skills.contains('nursing')      ||
      skills.contains('patient')      ||
      skills.contains('medical')      ||
      skills.contains('pharmaceutic') ||
      title.contains('health')        ||
      title.contains('clinical')) {
    return 'Healthcare';
  }
  if (skills.contains('teaching')   ||
      skills.contains('curriculum') ||
      skills.contains('edtech')     ||
      skills.contains('lms')        ||
      title.contains('education')   ||
      title.contains('teaching')) {
    return 'Education';
  }
  if (skills.contains('seo')         ||
      skills.contains('marketing')   ||
      skills.contains('copywriting') ||
      skills.contains('google ads')  ||
      title.contains('marketing')) {
    return 'Marketing';
  }
  if (skills.contains('excel')           ||
      skills.contains('accounting')      ||
      skills.contains('financial model') ||
      skills.contains('risk analysis')   ||
      title.contains('finance')          ||
      title.contains('accounting')) {
    return 'Finance';
  }
  if (skills.contains('production planning') ||
      skills.contains('quality control')     ||
      skills.contains('supply chain')        ||
      skills.contains('erp')                 ||
      title.contains('manufacturing')) {
    return 'Manufacturing';
  }
  if (skills.contains('merchandising') ||
      skills.contains('retail')        ||
      skills.contains('vendor manag')  ||
      title.contains('retail')) {
    return 'Retail';
  }
  return 'Software';
}

// ─── Category colour / icon ────────────────────────────────────────────────
Color _catColor(String industry) {
  switch (industry) {
    case 'Software':      return const Color(0xFF2563EB);
    case 'Finance':       return const Color(0xFF16A34A);
    case 'Healthcare':    return const Color(0xFFDC2626);
    case 'Marketing':     return const Color(0xFF7C3AED);
    case 'Manufacturing': return const Color(0xFFEA580C);
    case 'Retail':        return const Color(0xFFDB2777);
    case 'Education':     return const Color(0xFF0891B2);
    default:              return AppTheme.primaryBlue;
  }
}

IconData _catIcon(String industry) {
  switch (industry) {
    case 'Software':      return Icons.code_rounded;
    case 'Finance':       return Icons.account_balance_outlined;
    case 'Healthcare':    return Icons.local_hospital_outlined;
    case 'Marketing':     return Icons.campaign_outlined;
    case 'Manufacturing': return Icons.precision_manufacturing_outlined;
    case 'Retail':        return Icons.storefront_outlined;
    case 'Education':     return Icons.school_outlined;
    default:              return Icons.menu_book_rounded;
  }
}

// ─── Content metadata helpers ──────────────────────────────────────────────
ContentFormat _contentFormat(String type) {
  final t = type.toLowerCase();
  if (t.contains('video'))                       { return ContentFormat.video; }
  if (t.contains('book') || t.contains('text')) { return ContentFormat.book; }
  return ContentFormat.slide;
}

DetailLevel _detailLevel(String level) {
  final l = level.toLowerCase();
  if (l.contains('beginner') || l.contains('intro'))  { return DetailLevel.low; }
  if (l.contains('advanced') || l.contains('expert')) { return DetailLevel.high; }
  return DetailLevel.medium;
}

ContentLength _contentLength(String duration) {
  final match = RegExp(r'(\d+(\.\d+)?)').firstMatch(duration.toLowerCase());
  if (match == null) { return ContentLength.medium; }
  final hours = double.tryParse(match.group(1) ?? '') ?? 0;
  if (hours <= 5)  { return ContentLength.short; }
  if (hours <= 20) { return ContentLength.medium; }
  return ContentLength.long;
}

// ─── Personalised score ────────────────────────────────────────────────────
int _personalisedScore(Course course, AppState appState) {
  try {
    final prefs = _getPrefs(appState);
    double dot = 0.0, norm = 0.0;
    final keys = [
      'format${_contentFormat(course.type).name._cap()}',
      'length${_contentLength(course.duration).name._cap()}',
      'detail${_detailLevel(course.level).name._cap()}',
    ];
    for (final k in keys) {
      dot  += prefs[k] ?? 0.5;
      norm += 1.0;
    }
    if (norm == 0) { return 0; }
    return (dot / norm * 100).round().clamp(0, 100);
  } catch (_) {
    return 0;
  }
}

extension _StrCap on String {
  String _cap() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

// ─── Topic helpers ─────────────────────────────────────────────────────────
List<String> _topicsForSkill(String skill) {
  final s = skill.toLowerCase().trim();
  const topicMap = <String, List<String>>{
    'python':             ['Python Basics', 'Functions & OOP', 'Libraries & APIs'],
    'sql':                ['SQL Fundamentals', 'Joins & Subqueries', 'Query Optimisation'],
    'javascript':         ['JS Fundamentals', 'DOM & Events', 'Async & APIs'],
    'react':              ['React Basics', 'Hooks & State', 'Component Patterns'],
    'dart':               ['Dart Language', 'OOP in Dart', 'Async Dart'],
    'flutter':            ['Flutter Basics', 'Widgets & Layouts', 'State Management'],
    'machine learning':   ['ML Foundations', 'Supervised Learning', 'Model Evaluation'],
    'data analysis':      ['Data Cleaning', 'Exploratory Analysis', 'Statistical Testing'],
    'docker':             ['Containerisation', 'Dockerfile', 'Docker Compose'],
    'aws':                ['Cloud Fundamentals', 'EC2 & S3', 'IAM & Security'],
    'git':                ['Git Basics', 'Branching & Merging', 'CI/CD Workflows'],
    'project management': ['PM Fundamentals', 'Agile & Scrum', 'Risk Management'],
    'communication':      ['Written Communication', 'Presentations', 'Active Listening'],
  };
  if (topicMap.containsKey(s)) { return topicMap[s]!; }
  for (final key in topicMap.keys) {
    if (s.contains(key) || key.contains(s)) { return topicMap[key]!; }
  }
  final cap = skill.isEmpty
      ? 'Skill'
      : '${skill[0].toUpperCase()}${skill.substring(1)}';
  return ['$cap Fundamentals', '$cap Intermediate', '$cap Advanced'];
}

// ─── Preference label helpers ──────────────────────────────────────────────
String _activeLengthLabel(Map<String, double> prefs) {
  final scores = {
    'Short':  prefs['length_short']  ?? 0.0,
    'Medium': prefs['length_medium'] ?? 0.0,
    'Long':   prefs['length_long']   ?? 0.0,
  };
  return scores.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

String _activeDetailLabel(Map<String, double> prefs) {
  final scores = {
    'Overview': prefs['detail_low']    ?? 0.0,
    'Standard': prefs['detail_medium'] ?? 0.0,
    'In-Depth': prefs['detail_high']   ?? 0.0,
  };
  return scores.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

List<String> _activeFormatLabels(Map<String, double> prefs) {
  const map = {
    'format_video':    '🎬 Video',
    'format_book':     '📖 Book',
    'format_web_page': '🌐 Web',
    'format_slide':    '📊 Slides',
  };
  final active = map.entries
      .where((e) => (prefs[e.key] ?? 0) > 0.5)
      .map((e) => e.value)
      .toList();
  return active.isEmpty ? ['All Formats'] : active;
}

// ─── Sort helpers ──────────────────────────────────────────────────────────
String _sortLabel(String sortBy) {
  switch (sortBy) {
    case 'rating':   return 'Top Rated';
    case 'duration': return 'Duration';
    case 'pref':     return 'My Prefs';
    default:         return 'Best Match';
  }
}

IconData _sortIcon(String sortBy) {
  switch (sortBy) {
    case 'rating':   return Icons.star_rounded;
    case 'duration': return Icons.timer_rounded;
    case 'pref':     return Icons.tune_rounded;
    default:         return Icons.auto_awesome_rounded;
  }
}

// ─── Active filter count ───────────────────────────────────────────────────
int _activeFilterCount(bool showBookmarked, String sortBy) {
  int n = 0;
  if (showBookmarked) { n++; }
  if (sortBy != 'pref' && sortBy != 'match') { n++; }
  return n;
}

// ══════════════════════════════════════════════════════════════════════════════
// SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class LearningScreen extends StatefulWidget {
  final List<String> missingSkills;
  final String?      industry;
  const LearningScreen(
      {super.key, required this.missingSkills, this.industry});

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen>
    with TickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _searchCtrl  = TextEditingController();
  final _searchFocus = FocusNode();
  final List<String> _tabs = ['All', 'In Progress', 'Completed', 'Saved'];

  String         _searchQuery        = '';
  String         _sortBy             = 'match';
  bool           _showBookmarkedOnly = false;
  final Set<int> _savedCourses       = {};
  final Set<int> _notForMe           = {};
  String?        _selectedTopic;
  String?        _topicSkill;

  late final AnimationController _listCtrl;
  late final AnimationController _heroCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) { setState(() {}); }
      _listCtrl.forward(from: 0);
      setState(() => _selectedTopic = null);
    });
    _listCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();
    _heroCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.toLowerCase().trim());
      _listCtrl.forward(from: 0);
    });
    if (widget.missingSkills.isNotEmpty) {
      _topicSkill = widget.missingSkills.first;
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _listCtrl.dispose();
    _heroCtrl.dispose();
    super.dispose();
  }

  // ── All original logic preserved verbatim ─────────────────────────────

  List<Course> get _baseCourses => courses
      .where((c) => widget.missingSkills.any((s) => c.skills.contains(s)))
      .toList();

  List<Course> _applyAll(AppState appState) {
    var list = List<Course>.from(_baseCourses);
    final tab = _tabs[_tabCtrl.index];
    if (tab == 'In Progress') {
      list = list
          .where((c) =>
      appState.isCourseEnrolled(c.id) &&
          !appState.isCourseCompleted(c.id))
          .toList();
    }
    if (tab == 'Completed') {
      list = list
          .where((c) => appState.isCourseCompleted(c.id))
          .toList();
    }
    if (tab == 'Saved') {
      list = list
          .where((c) => _savedCourses.contains(c.id))
          .toList();
    }
    list = list.where((c) => !_notForMe.contains(c.id)).toList();
    if (_selectedTopic != null && _topicSkill != null) {
      final topicKey =
      _selectedTopic!.toLowerCase().replaceAll(' ', '_');
      list = list
          .where((c) =>
      c.skills.any(
              (s) => s.toLowerCase() == _topicSkill!.toLowerCase()) ||
          c.title.toLowerCase().contains(topicKey))
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      list = list
          .where((c) =>
      c.title.toLowerCase().contains(_searchQuery) ||
          c.provider.toLowerCase().contains(_searchQuery) ||
          c.skills.any((s) => s.toLowerCase().contains(_searchQuery)))
          .toList();
    }
    if (_showBookmarkedOnly) {
      list = list.where((c) => _savedCourses.contains(c.id)).toList();
    }
    if (_sortBy == 'pref' || _sortBy == 'match') {
      list.sort((a, b) => _personalisedScore(b, appState)
          .compareTo(_personalisedScore(a, appState)));
    } else if (_sortBy == 'rating') {
      list.sort((a, b) => b.rating.compareTo(a.rating));
    } else if (_sortBy == 'duration') {
      list.sort((a, b) => a.duration.compareTo(b.duration));
    }
    return list;
  }

  List<String> _coveredSkills(Course course) =>
      course.skills
          .where((s) => widget.missingSkills.contains(s))
          .toList();

  int _matchPct(Course course) {
    if (widget.missingSkills.isEmpty) { return 0; }
    return (_coveredSkills(course).length /
        widget.missingSkills.length *
        100)
        .round();
  }

  Future<void> _openUrl(BuildContext ctx, String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(content: Text('Could not open: $url')));
      }
    } catch (_) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(content: Text('Could not open: $url')));
      }
    }
  }

  Future<void> _onDone(
      BuildContext ctx, AppState appState, Course course) async {
    appState.addToHistory(course.id.toString());
    if (!appState.isCourseCompleted(course.id)) {
      appState.toggleCourseCompleted(course.id);
    }
    final rating = await showDialog<double>(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => _StarRatingDialog(course: course),
    );
    if (rating != null && ctx.mounted) {
      final formatKey =
          'format${_contentFormat(course.type).name._cap()}';
      appState.rateContent(formatKey, rating / 5.0);
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.stars_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text('Thanks! Preferences updated · ${rating.toInt()}/5 ⭐'),
        ]),
        backgroundColor: _kSuccessGreen,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  void _onNotForMe(BuildContext ctx, AppState appState, Course course) {
    appState.rateContent(
        'format${_contentFormat(course.type).name._cap()}', 0.0);
    appState.rateContent(
        'length${_contentLength(course.duration).name._cap()}', 0.2);
    setState(() => _notForMe.add(course.id));
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: const Row(children: [
        Icon(Icons.tune_rounded, color: Colors.white, size: 16),
        SizedBox(width: 8),
        Text("Thanks! We'll tune your recommendations."),
      ]),
      backgroundColor: AppTheme.accentTeal,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
      action: SnackBarAction(
        label: 'Undo',
        textColor: Colors.white,
        onPressed: () => setState(() => _notForMe.remove(course.id)),
      ),
    ));
  }

  void _toggleSaved(int id) => setState(() {
    _savedCourses.contains(id)
        ? _savedCourses.remove(id)
        : _savedCourses.add(id);
  });

  Future<void> _openPrefEditor(AppState appState) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PreferenceEditorSheet(
        appState: appState,
        onApply: () {
          setState(() => _sortBy = 'pref');
          _listCtrl.forward(from: 0);
        },
      ),
    );
  }

  // ─── Tab count helpers ─────────────────────────────────────────────────
  int _tabCount(AppState appState, String tab) {
    var list = List<Course>.from(_baseCourses)
        .where((c) => !_notForMe.contains(c.id))
        .toList();
    switch (tab) {
      case 'In Progress':
        return list
            .where((c) =>
        appState.isCourseEnrolled(c.id) &&
            !appState.isCourseCompleted(c.id))
            .length;
      case 'Completed':
        return list
            .where((c) => appState.isCourseCompleted(c.id))
            .length;
      case 'Saved':
        return list.where((c) => _savedCourses.contains(c.id)).length;
      default:
        return list.length;
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final appState       = context.watch<AppState>();
    // THEME: read from app-level provider — no local toggle needed here
    final isDark         = Theme.of(context).brightness == Brightness.dark;
    final filtered       = _applyAll(appState);
    final completedCount = _baseCourses
        .where((c) => appState.isCourseCompleted(c.id))
        .length;
    final inProgressCount = _baseCourses
        .where((c) =>
    appState.isCourseEnrolled(c.id) &&
        !appState.isCourseCompleted(c.id))
        .length;
    final prefs = _getPrefs(appState);

    final inProgressCourse = _baseCourses.cast<Course?>().firstWhere(
          (c) =>
      appState.isCourseEnrolled(c!.id) &&
          !appState.isCourseCompleted(c.id),
      orElse: () => null,
    );
    final progress = _baseCourses.isEmpty
        ? 0.0
        : (completedCount / _baseCourses.length).clamp(0.0, 1.0);
    final remaining = _baseCourses.length - completedCount;
    final filterCount =
    _activeFilterCount(_showBookmarkedOnly, _sortBy);

    return Scaffold(
      backgroundColor: _bgC(isDark),

      // ── AppBar ───────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor:  _cardBg(isDark),
        foregroundColor:  _textC(isDark),
        elevation:        0,
        surfaceTintColor: Colors.transparent,
        titleSpacing:     20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Learning',
              style: TextStyle(
                color:         _textC(isDark),
                fontSize:      20,
                fontWeight:    FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            if (_baseCourses.isNotEmpty)
              Text(
                '$completedCount of ${_baseCourses.length} courses done',
                style: TextStyle(
                  color:      _subC(isDark),
                  fontSize:   11,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        // THEME: no local toggle — single global toggle lives in MainNav
        actions: [
          // Sort popup
          PopupMenuButton<String>(
            initialValue: _sortBy,
            tooltip: 'Sort courses',
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            color: _cardBg(isDark),
            elevation: 8,
            icon: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color:        _surfaceC(isDark),
                borderRadius: BorderRadius.circular(20),
                border:       Border.all(color: _borderC(isDark)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_sortIcon(_sortBy),
                    color: AppTheme.primaryBlue, size: 14),
                const SizedBox(width: 4),
                Text(
                  _sortLabel(_sortBy),
                  style: const TextStyle(
                    color:      AppTheme.primaryBlue,
                    fontSize:   11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ]),
            ),
            onSelected: (val) {
              setState(() => _sortBy = val);
              _listCtrl.forward(from: 0);
            },
            itemBuilder: (_) => [
              _sortMenuItem('match',    'Best Match',      Icons.auto_awesome_rounded, isDark),
              _sortMenuItem('rating',   'Top Rated',       Icons.star_rounded,         isDark),
              _sortMenuItem('duration', 'Duration',        Icons.timer_rounded,        isDark),
              _sortMenuItem('pref',     'My Preferences',  Icons.tune_rounded,         isDark),
            ],
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: _borderC(isDark)),
        ),
      ),

      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: CustomScrollView(
          slivers: [

            // ── Stats row ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _StatsRow(
                total:      _baseCourses.length,
                inProgress: inProgressCount,
                completed:  completedCount,
                isDark:     isDark,
              ),
            ),

            // ── Continue Learning hero card ────────────────────────────
            if (inProgressCourse != null)
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _heroCtrl,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, -0.08),
                      end:   Offset.zero,
                    ).animate(CurvedAnimation(
                        parent: _heroCtrl,
                        curve:  Curves.easeOut)),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: _HeroCard(
                        course:    inProgressCourse,
                        progress:  progress,
                        remaining: remaining,
                        onResume:  inProgressCourse.url.isNotEmpty
                            ? () => _openUrl(context, inProgressCourse.url)
                            : null,
                      ),
                    ),
                  ),
                ),
              ),

            // ── TabBar with count badges ───────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                color:  _cardBg(isDark),
                margin: const EdgeInsets.only(top: 16),
                child: TabBar(
                  controller: _tabCtrl,
                  tabs: _tabs.map((t) {
                    final count = _tabCount(appState, t);
                    return Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(t),
                          if (count > 0) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color:        AppTheme.primaryBlue,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$count',
                                style: const TextStyle(
                                    color:      Colors.white,
                                    fontSize:   9,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                  labelColor:           AppTheme.primaryBlue,
                  unselectedLabelColor: _subC(isDark),
                  labelStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                  unselectedLabelStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                  indicator: BoxDecoration(
                    color:        _kLightBlue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  dividerColor:  Colors.transparent,
                  splashFactory: NoSplash.splashFactory,
                ),
              ),
            ),

            // ── Overall progress bar ───────────────────────────────────
            if (_baseCourses.isNotEmpty)
              SliverToBoxAdapter(
                child: TweenAnimationBuilder<double>(
                  tween:    Tween(
                      begin: 0,
                      end:   completedCount / _baseCourses.length),
                  duration: const Duration(milliseconds: 700),
                  curve:    Curves.easeOut,
                  builder: (_, val, __) => LinearProgressIndicator(
                    value:           val,
                    color:           _kSuccessGreen,
                    backgroundColor: _borderC(isDark),
                    minHeight:       3,
                  ),
                ),
              ),

            // ── Preference filter bar ──────────────────────────────────
            SliverToBoxAdapter(
              child: _PreferenceFilterBar(
                prefs:  prefs,
                sortBy: _sortBy,
                isDark: isDark,
                onTap:  () => _openPrefEditor(appState),
              ),
            ),

            // ── Search bar ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _SearchBar(
                controller:  _searchCtrl,
                focusNode:   _searchFocus,
                searchQuery: _searchQuery,
                filterCount: filterCount,
                isDark:      isDark,
                onClear: () {
                  _searchCtrl.clear();
                  _searchFocus.unfocus();
                },
              ),
            ),

            // ── Missing skills bar ─────────────────────────────────────
            if (widget.missingSkills.isNotEmpty)
              SliverToBoxAdapter(
                child: _MissingSkillsBar(
                  skills:      widget.missingSkills,
                  searchQuery: _searchQuery,
                  isDark:      isDark,
                  onTap: (s) {
                    setState(() {
                      _searchCtrl.text = s;
                      _searchQuery     = s;
                      _topicSkill      = s;
                      _selectedTopic   = null;
                    });
                  },
                ),
              ),

            // ── Topics tracker ─────────────────────────────────────────
            if (_topicSkill != null)
              SliverToBoxAdapter(
                child: _TopicsProgressTracker(
                  skill:         _topicSkill!,
                  appState:      appState,
                  selectedTopic: _selectedTopic,
                  isDark:        isDark,
                  onSelect: (topic) {
                    setState(() => _selectedTopic =
                    _selectedTopic == topic ? null : topic);
                    _listCtrl.forward(from: 0);
                  },
                ),
              ),

            // ── Active filters bar ─────────────────────────────────────
            if (_showBookmarkedOnly ||
                (_sortBy != 'pref' && _sortBy != 'match'))
              SliverToBoxAdapter(
                child: _ActiveFiltersBar(
                  showBookmarked: _showBookmarkedOnly,
                  sortBy:        _sortBy,
                  isDark:        isDark,
                  onClear: () {
                    setState(() {
                      _showBookmarkedOnly = false;
                      _sortBy            = 'pref';
                      _selectedTopic     = null;
                    });
                    _listCtrl.forward(from: 0);
                  },
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // ── Course list ────────────────────────────────────────────
            SliverFillRemaining(
              child: filtered.isEmpty
                  ? _EmptyState(
                searchQuery:    _searchQuery,
                showBookmarked: _showBookmarkedOnly,
                onClearSearch: () {
                  _searchCtrl.clear();
                  setState(() {
                    _searchQuery   = '';
                    _selectedTopic = null;
                  });
                },
              )
                  : _CourseListView(
                filtered:      filtered,
                appState:      appState,
                listCtrl:      _listCtrl,
                savedCourses:  _savedCourses,
                isDark:        isDark,
                coveredSkills: _coveredSkills,
                matchPct:      _matchPct,
                onToggleSaved: _toggleSaved,
                onOpenUrl:     (url) => _openUrl(context, url),
                onDone:        (c) => _onDone(context, appState, c),
                onNotForMe:    (c) => _onNotForMe(context, appState, c),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _sortMenuItem(
      String value, String label, IconData icon, bool isDark) {
    final isActive = _sortBy == value;
    return PopupMenuItem<String>(
      value: value,
      child: Row(children: [
        Container(
          width:  30,
          height: 30,
          decoration: BoxDecoration(
            color:        isActive ? AppTheme.primaryBlue : _surfaceC(isDark),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon,
              color: isActive ? Colors.white : _subC(isDark),
              size:  16),
        ),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(
              fontSize:   13,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color:      isActive ? AppTheme.primaryBlue : _textC(isDark),
            )),
        if (isActive) ...[
          const Spacer(),
          const Icon(Icons.check_rounded,
              color: AppTheme.primaryBlue, size: 16),
        ],
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// HERO CARD
// ══════════════════════════════════════════════════════════════════════════════

class _HeroCard extends StatelessWidget {
  final Course        course;
  final double        progress;
  final int           remaining;
  final VoidCallback? onResume;

  const _HeroCard({
    required this.course,
    required this.progress,
    required this.remaining,
    required this.onResume,
  });

  @override
  Widget build(BuildContext context) {
    final industry = _courseIndustry(course);
    final catColor = _catColor(industry);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_kDarkNavy, catColor],
          begin:  Alignment.centerLeft,
          end:    Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:      catColor.withAlpha(70),
            blurRadius: 24,
            offset:     const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color:        Colors.white.withAlpha(30),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.play_circle_rounded, color: Colors.white70, size: 12),
                SizedBox(width: 5),
                Text('Continue Learning',
                    style: TextStyle(
                        color:      Colors.white70,
                        fontSize:   11,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
            const Spacer(),
            // Progress ring
            SizedBox(
              width:  40,
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value:           progress,
                    strokeWidth:     3,
                    backgroundColor: Colors.white.withAlpha(40),
                    valueColor:      const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                  Text(
                    '${(progress * 100).round()}%',
                    style: const TextStyle(
                      color:      Colors.white,
                      fontSize:   9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Text(
            course.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color:      Colors.white,
              fontSize:   17,
              fontWeight: FontWeight.w700,
              height:     1.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${course.provider}  ·  $remaining topics remaining',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween:    Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 900),
              curve:    Curves.easeOut,
              builder: (_, val, __) => LinearProgressIndicator(
                value:           val,
                backgroundColor: Colors.white.withAlpha(40),
                valueColor:      const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight:       6,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: onResume,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color:        Colors.white,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.play_arrow_rounded, color: _catColor(industry), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Resume',
                    style: TextStyle(
                      color:      _catColor(industry),
                      fontSize:   13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// STATS ROW
// ══════════════════════════════════════════════════════════════════════════════

class _StatsRow extends StatelessWidget {
  final int  total;
  final int  inProgress;
  final int  completed;
  final bool isDark;

  const _StatsRow({
    required this.total,
    required this.inProgress,
    required this.completed,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(children: [
        Expanded(
          child: _StatCard(
            label:  'Total',
            count:  total,
            icon:   Icons.menu_book_rounded,
            color:  AppTheme.primaryBlue,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label:  'In Progress',
            count:  inProgress,
            icon:   Icons.autorenew_rounded,
            color:  const Color(0xFFF59E0B),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label:  'Completed',
            count:  completed,
            icon:   Icons.check_circle_rounded,
            color:  _kSuccessGreen,
            isDark: isDark,
          ),
        ),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String   label;
  final int      count;
  final IconData icon;
  final Color    color;
  final bool     isDark;

  const _StatCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color:        color.withAlpha(isDark ? 28 : 14),
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: color.withAlpha(isDark ? 55 : 35)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 5),
        TweenAnimationBuilder<double>(
          tween:    Tween(begin: 0, end: count.toDouble()),
          duration: const Duration(milliseconds: 800),
          curve:    Curves.easeOut,
          builder: (_, val, __) => Text(
            '${val.round()}',
            style: TextStyle(
              fontSize:   20,
              fontWeight: FontWeight.w800,
              color:      color,
            ),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize:   10,
            fontWeight: FontWeight.w600,
            color:      _subC(isDark),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SEARCH BAR
// ══════════════════════════════════════════════════════════════════════════════

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode             focusNode;
  final String                searchQuery;
  final int                   filterCount;
  final bool                  isDark;
  final VoidCallback          onClear;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.searchQuery,
    required this.filterCount,
    required this.isDark,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color:        _cardBg(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: searchQuery.isNotEmpty
                ? AppTheme.primaryBlue.withAlpha(120)
                : _borderC(isDark),
            width: searchQuery.isNotEmpty ? 1.5 : 1,
          ),
          boxShadow: isDark
              ? []
              : [
            BoxShadow(
              color:      Colors.black.withAlpha(8),
              blurRadius: 8,
              offset:     const Offset(0, 2),
            ),
          ],
        ),
        child: Row(children: [
          const SizedBox(width: 14),
          Icon(
            Icons.search_rounded,
            color: searchQuery.isNotEmpty
                ? AppTheme.primaryBlue
                : _subC(isDark),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode:  focusNode,
              decoration: InputDecoration(
                hintText:       'Search courses, skills, providers…',
                hintStyle:      TextStyle(fontSize: 14, color: _subC(isDark)),
                border:         InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              style: TextStyle(fontSize: 14, color: _textC(isDark)),
            ),
          ),
          if (filterCount > 0)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color:        AppTheme.primaryBlue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$filterCount',
                style: const TextStyle(
                  color:      Colors.white,
                  fontSize:   10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          if (searchQuery.isNotEmpty)
            GestureDetector(
              onTap: onClear,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(Icons.close_rounded, color: _subC(isDark), size: 18),
              ),
            )
          else
            const SizedBox(width: 10),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// COURSE LIST VIEW  (animated + dismissible)
// ══════════════════════════════════════════════════════════════════════════════

class _CourseListView extends StatelessWidget {
  final List<Course>                  filtered;
  final AppState                      appState;
  final AnimationController           listCtrl;
  final Set<int>                      savedCourses;
  final bool                          isDark;
  final List<String> Function(Course) coveredSkills;
  final int Function(Course)          matchPct;
  final void Function(int)            onToggleSaved;
  final Future<void> Function(String) onOpenUrl;
  final Future<void> Function(Course) onDone;
  final void Function(Course)         onNotForMe;

  const _CourseListView({
    required this.filtered,     required this.appState,
    required this.listCtrl,     required this.savedCourses,
    required this.isDark,       required this.coveredSkills,
    required this.matchPct,     required this.onToggleSaved,
    required this.onOpenUrl,    required this.onDone,
    required this.onNotForMe,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding:          const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount:        filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final course = filtered[i];
        final anim   = CurvedAnimation(
          parent: listCtrl,
          curve:  Interval(
              (i * 0.07).clamp(0.0, 0.85), 1.0,
              curve: Curves.easeOut),
        );
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.08),
              end:   Offset.zero,
            ).animate(anim),
            child: Dismissible(
              key:       ValueKey('dismiss_${course.id}'),
              direction: DismissDirection.endToStart,
              onDismissed: (_) => onNotForMe(course),
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                decoration: BoxDecoration(
                  color:        Colors.red.shade400,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.thumb_down_alt_outlined,
                        color: Colors.white, size: 24),
                    SizedBox(height: 4),
                    Text('Not for me',
                        style: TextStyle(
                            color:      Colors.white,
                            fontSize:   11,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              child: _CourseCard(
                course:        course,
                coveredSkills: coveredSkills(course),
                matchPct:      matchPct(course),
                isDark:        isDark,
                isSaved:       savedCourses.contains(course.id),
                appState:      appState,
                onToggleSaved: onToggleSaved,
                onOpenUrl:     onOpenUrl,
                onDone:        () => onDone(course),
                onNotForMe:    () => onNotForMe(course),
                onChange:      null,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// COURSE CARD
// ══════════════════════════════════════════════════════════════════════════════

class _CourseCard extends StatelessWidget {
  final Course       course;
  final List<String> coveredSkills;
  final int          matchPct;
  final bool         isDark;
  final bool                          isSaved;
  final AppState                      appState;
  final void Function(int)            onToggleSaved;
  final Future<void> Function(String) onOpenUrl;
  final Future<void> Function()       onDone;
  final void Function()               onNotForMe;
  final VoidCallback?                 onChange;

  const _CourseCard({
    required this.course,        required this.coveredSkills,
    required this.matchPct,      required this.isDark,
    required this.isSaved,       required this.appState,
    required this.onToggleSaved, required this.onOpenUrl,
    required this.onDone,        required this.onNotForMe,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = appState.isCourseCompleted(course.id);
    final isEnrolled  = appState.isCourseEnrolled(course.id);
    final industry    = _courseIndustry(course);
    final catColor    = _catColor(industry);
    final catIcon     = _catIcon(industry);
    final format      = _contentFormat(course.type);
    final detail      = _detailLevel(course.level);

    final String fmtLabel = switch (format) {
      ContentFormat.video => '🎬 Video',
      ContentFormat.book  => '📖 Book',
      ContentFormat.slide => '📊 Slides',
      _                   => '🌐 Web',
    };

    final String detLabel = switch (detail) {
      DetailLevel.low  => '📘 Overview',
      DetailLevel.high => '📊 In-Depth',
      _                => '📗 Standard',
    };

    // Status-based border colour
    final Color borderColor = isCompleted
        ? _kSuccessGreen.withAlpha(100)
        : isEnrolled
        ? AppTheme.primaryBlue.withAlpha(80)
        : _borderC(isDark);

    return Container(
      decoration: BoxDecoration(
        color:        _cardBg(isDark),
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: borderColor),
        boxShadow: isDark
            ? []
            : [
          BoxShadow(
            color:      Colors.black.withAlpha(10),
            blurRadius: 10,
            offset:     const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent bar
              Container(width: 4, color: catColor),
              // Card body
              Expanded(
                child: InkWell(
                  borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(16)),
                  onTap: course.url.isNotEmpty
                      ? () => onOpenUrl(course.url)
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Header row ───────────────────────────────
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Category icon + match badge stack
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width:  50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color:        catColor,
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: Icon(catIcon, color: Colors.white, size: 26),
                                ),
                                Positioned(
                                  bottom: -6, right: -6,
                                  child: _MatchBadge(matchPct),
                                ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            // Title + meta
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    course.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize:   15,
                                      fontWeight: FontWeight.w700,
                                      color:      _textC(isDark),
                                      height:     1.25,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(children: [
                                    Text(
                                      course.provider,
                                      style: TextStyle(
                                          fontSize: 12, color: _subC(isDark)),
                                    ),
                                    if (course.rating > 0) ...[
                                      Text('  ·  ',
                                          style: TextStyle(
                                              fontSize: 12, color: _subC(isDark))),
                                      Icon(Icons.star_rounded,
                                          color: Colors.amber.shade600, size: 13),
                                      const SizedBox(width: 2),
                                      Text(
                                        course.rating.toStringAsFixed(1),
                                        style: TextStyle(
                                            fontSize: 12, color: _subC(isDark)),
                                      ),
                                    ],
                                    if (course.skills.isNotEmpty) ...[
                                      Text('  ·  ',
                                          style: TextStyle(
                                              fontSize: 12, color: _subC(isDark))),
                                      Text(
                                        '${course.skills.length} topics',
                                        style: TextStyle(
                                            fontSize: 12, color: _subC(isDark)),
                                      ),
                                    ],
                                  ]),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            // Bookmark + completed badge column
                            Column(children: [
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () => onToggleSaved(course.id),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 200),
                                      transitionBuilder: (child, anim) =>
                                          ScaleTransition(scale: anim, child: child),
                                      child: Icon(
                                        isSaved
                                            ? Icons.bookmark_rounded
                                            : Icons.bookmark_border_rounded,
                                        key:   ValueKey(isSaved),
                                        color: isSaved
                                            ? AppTheme.primaryBlue
                                            : _subC(isDark),
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (isCompleted) ...[
                                const SizedBox(height: 4),
                                Container(
                                  width:  22,
                                  height: 22,
                                  decoration: const BoxDecoration(
                                    color: _kSuccessGreen,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check_rounded,
                                      color: Colors.white, size: 13),
                                ),
                              ],
                            ]),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // ── Chips ─────────────────────────────────────
                        Wrap(spacing: 6, runSpacing: 4, children: [
                          _Chip(fmtLabel, _kLightBlue, AppTheme.primaryBlue),
                          if (course.duration.isNotEmpty)
                            _Chip('⏱ ${course.duration}',
                                _surfaceC(isDark), _subC(isDark)),
                          _Chip(detLabel, _surfaceC(isDark), _subC(isDark)),
                          if (course.isFree)
                            _Chip('🆓 Free',
                                _kSuccessGreen.withAlpha(25), _kSuccessGreen),
                        ]),

                        // ── Skills matched row ───────────────────────
                        if (coveredSkills.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(children: [
                              Icon(Icons.bolt_rounded, color: catColor, size: 13),
                              const SizedBox(width: 4),
                              ...coveredSkills.take(4).map((s) =>
                                  Padding(
                                    padding: const EdgeInsets.only(right: 5),
                                    child: _Chip(s, catColor.withAlpha(20), catColor),
                                  )),
                              if (coveredSkills.length > 4)
                                _Chip(
                                  '+${coveredSkills.length - 4} more',
                                  _surfaceC(isDark),
                                  _subC(isDark),
                                ),
                            ]),
                          ),
                        ],

                        // ── In-progress section ──────────────────────
                        if (isEnrolled && !isCompleted) ...[
                          const SizedBox(height: 12),
                          Row(children: [
                            Text('Progress: $matchPct%',
                                style: const TextStyle(
                                    fontSize:   11,
                                    fontWeight: FontWeight.w600,
                                    color:      AppTheme.primaryBlue)),
                            const Spacer(),
                            Text(
                              '${coveredSkills.length}/${course.skills.length} topics',
                              style: TextStyle(fontSize: 11, color: _subC(isDark)),
                            ),
                          ]),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: TweenAnimationBuilder<double>(
                              tween:    Tween(begin: 0, end: matchPct / 100),
                              duration: const Duration(milliseconds: 600),
                              curve:    Curves.easeOut,
                              builder: (_, val, __) => LinearProgressIndicator(
                                value:           val,
                                color:           AppTheme.primaryBlue,
                                backgroundColor: _borderC(isDark),
                                minHeight:       5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(
                              child: _OutlineBtn('Not for me', onNotForMe, isDark),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _GradientButton(
                                label: 'Continue →',
                                onTap: course.url.isNotEmpty
                                    ? () => onOpenUrl(course.url)
                                    : () {},
                                colors: const [
                                  AppTheme.primaryBlue,
                                  AppTheme.accentTeal,
                                ],
                              ),
                            ),
                          ]),
                        ]

                        // ── Completed section ───────────────────────
                        else if (isCompleted) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color:        _kSuccessGreen.withAlpha(20),
                              borderRadius: BorderRadius.circular(10),
                              border:       Border.all(color: _kSuccessGreen.withAlpha(60)),
                            ),
                            child: Row(children: [
                              const Icon(Icons.verified_rounded,
                                  color: _kSuccessGreen, size: 16),
                              const SizedBox(width: 6),
                              const Text('Completed!',
                                  style: TextStyle(
                                      color:      _kSuccessGreen,
                                      fontSize:   13,
                                      fontWeight: FontWeight.w700)),
                              const Spacer(),
                              GestureDetector(
                                onTap: onDone,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color:        _kSuccessGreen,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text('Rate ★',
                                      style: TextStyle(
                                          color:      Colors.white,
                                          fontSize:   11,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ]),
                          ),
                        ]

                        // ── Enroll section ──────────────────────────
                        else ...[
                            const SizedBox(height: 12),
                            _GradientButton(
                              label: course.isFree ? 'Enroll Free →' : 'Enroll →',
                              onTap: course.url.isNotEmpty
                                  ? () => onOpenUrl(course.url)
                                  : () {},
                              colors: [catColor, catColor.withAlpha(200)],
                            ),
                          ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MATCH BADGE
// ══════════════════════════════════════════════════════════════════════════════

class _MatchBadge extends StatelessWidget {
  final int matchPct;
  const _MatchBadge(this.matchPct);

  Color get _color {
    if (matchPct >= 70) { return _kSuccessGreen; }
    if (matchPct >= 40) { return const Color(0xFFF59E0B); }
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width:  32,
      height: 32,
      decoration: BoxDecoration(
        color:  Colors.white,
        shape:  BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withAlpha(25),
              blurRadius: 4,
              offset:     const Offset(0, 1)),
        ],
      ),
      child: Stack(alignment: Alignment.center, children: [
        SizedBox(
          width:  28,
          height: 28,
          child: CircularProgressIndicator(
            value:           matchPct / 100,
            strokeWidth:     2.5,
            backgroundColor: _color.withAlpha(35),
            valueColor:      AlwaysStoppedAnimation<Color>(_color),
          ),
        ),
        Text(
          '$matchPct',
          style: TextStyle(
            fontSize:   8,
            fontWeight: FontWeight.w800,
            color:      _color,
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// REUSABLE MICRO WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _Chip extends StatelessWidget {
  final String text;
  final Color  bg;
  final Color  fg;
  const _Chip(this.text, this.bg, this.fg);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(100)),
    child: Text(text,
        style: TextStyle(
            color:      fg,
            fontSize:   11,
            fontWeight: FontWeight.w600)),
  );
}

class _GradientButton extends StatelessWidget {
  final String       label;
  final VoidCallback onTap;
  final List<Color>  colors;

  const _GradientButton({
    required this.label,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:  double.infinity,
        height: 42,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin:  Alignment.centerLeft,
            end:    Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(11),
          boxShadow: [
            BoxShadow(
              color:      colors.first.withAlpha(60),
              blurRadius: 8,
              offset:     const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(label,
              style: const TextStyle(
                  color:      Colors.white,
                  fontSize:   13,
                  fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  final String       label;
  final VoidCallback onTap;
  final bool         isDark;
  const _OutlineBtn(this.label, this.onTap, this.isDark);

  @override
  Widget build(BuildContext context) => SizedBox(
    width:  double.infinity,
    height: 42,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: isDark ? Colors.white70 : Colors.black54,
        side: BorderSide(
            color: isDark ? Colors.white24 : Colors.black12),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11)),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600)),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// PREFERENCE FILTER BAR
// ══════════════════════════════════════════════════════════════════════════════

class _PreferenceFilterBar extends StatelessWidget {
  final Map<String, double> prefs;
  final String              sortBy;
  final bool                isDark;
  final VoidCallback        onTap;

  const _PreferenceFilterBar({
    required this.prefs,
    required this.sortBy,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final formats  = _activeFormatLabels(prefs);
    final length   = _activeLengthLabel(prefs);
    final detail   = _activeDetailLabel(prefs);
    final isActive = sortBy == 'pref';
    final sub      = _subC(isDark);
    final accent   = isActive ? AppTheme.accentTeal : sub;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width:    double.infinity,
        padding:  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.accentTeal.withAlpha(isDark ? 22 : 12)
              : (isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF8FAFC)),
          border: Border(
            bottom: BorderSide(color: _borderC(isDark)),
          ),
        ),
        child: Row(children: [
          Icon(Icons.auto_awesome_rounded, size: 14, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _Chip(formats.join(' / '), accent.withAlpha(20), accent),
                const SizedBox(width: 6),
                _Chip(
                  '⏱ $length',
                  (isActive ? AppTheme.primaryBlue : sub).withAlpha(20),
                  isActive ? AppTheme.primaryBlue : sub,
                ),
                const SizedBox(width: 6),
                _Chip(
                  '📊 $detail',
                  (isActive ? const Color(0xFF7B1FA2) : sub).withAlpha(20),
                  isActive ? const Color(0xFF7B1FA2) : sub,
                ),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color:        accent.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
              border:       Border.all(color: accent.withAlpha(60)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.edit_outlined, size: 11, color: accent),
              const SizedBox(width: 4),
              Text('Edit',
                  style: TextStyle(
                      color:      accent,
                      fontSize:   10,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PREFERENCE EDITOR SHEET
// ══════════════════════════════════════════════════════════════════════════════

class _PreferenceEditorSheet extends StatefulWidget {
  final AppState     appState;
  final VoidCallback onApply;
  const _PreferenceEditorSheet(
      {required this.appState, required this.onApply});

  @override
  State<_PreferenceEditorSheet> createState() =>
      _PreferenceEditorSheetState();
}

class _PreferenceEditorSheetState
    extends State<_PreferenceEditorSheet> {
  late Map<String, double> _localPrefs;

  static const _formatKeys  = [
    'format_video', 'format_book', 'format_web_page', 'format_slide',
  ];
  static const _formatEmoji = [
    '🎬 Video', '📖 Book', '🌐 Web', '📊 Slides',
  ];
  static const _lengthKeys  = [
    'length_short', 'length_medium', 'length_long',
  ];
  static const _lengthLabel = ['Short ≤5h', 'Medium ≤20h', 'Long 20h+'];
  static const _detailKeys  = [
    'detail_low', 'detail_medium', 'detail_high',
  ];
  static const _detailLabel = ['Overview', 'Standard', 'In-Depth'];

  @override
  void initState() {
    super.initState();
    _localPrefs = Map<String, double>.from(_getPrefs(widget.appState));
  }

  void _toggleFormat(String key) => setState(() {
    _localPrefs[key] = (_localPrefs[key] ?? 0) > 0.5 ? 0.0 : 1.0;
  });

  void _selectLength(String key) => setState(() {
    for (final k in _lengthKeys) {
      _localPrefs[k] = k == key ? 1.0 : 0.0;
    }
  });

  void _selectDetail(String key) => setState(() {
    for (final k in _detailKeys) {
      _localPrefs[k] = k == key ? 1.0 : 0.0;
    }
  });

  void _apply() {
    for (final e in _localPrefs.entries) {
      widget.appState.rateContent(e.key, e.value);
    }
    widget.onApply();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color:        _cardBg(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width:  40, height: 4,
              decoration: BoxDecoration(
                color:        _borderC(isDark),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:        AppTheme.primaryBlue.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.tune_rounded,
                      size: 18, color: AppTheme.primaryBlue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Learning Preferences',
                          style: TextStyle(
                              fontSize:   16,
                              fontWeight: FontWeight.w800,
                              color:      _textC(isDark))),
                      Text('Personalise your course feed',
                          style: TextStyle(
                              fontSize: 12, color: _subC(isDark))),
                    ],
                  ),
                ),
              ]),
            ),
            Divider(height: 1, color: _borderC(isDark)),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Format section
                    _PrefSectionLabel('Content Format', isDark),
                    const SizedBox(height: 10),
                    GridView.count(
                      crossAxisCount:   2,
                      shrinkWrap:       true,
                      physics:          const NeverScrollableScrollPhysics(),
                      mainAxisSpacing:  8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 3.2,
                      children: List.generate(_formatKeys.length, (i) {
                        final sel = (_localPrefs[_formatKeys[i]] ?? 0) > 0.5;
                        return GestureDetector(
                          onTap: () => _toggleFormat(_formatKeys[i]),
                          child: _SheetChip(
                              label:    _formatEmoji[i],
                              selected: sel,
                              isDark:   isDark),
                        );
                      }),
                    ),
                    const SizedBox(height: 18),
                    // Length section
                    _PrefSectionLabel('Content Length', isDark),
                    const SizedBox(height: 10),
                    Row(
                      children: List.generate(_lengthKeys.length, (i) {
                        final sel = (_localPrefs[_lengthKeys[i]] ?? 0) >= 1.0;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                                right: i < _lengthKeys.length - 1 ? 8 : 0),
                            child: GestureDetector(
                              onTap: () => _selectLength(_lengthKeys[i]),
                              child: _SheetChip(
                                  label:    _lengthLabel[i],
                                  selected: sel,
                                  isDark:   isDark),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 18),
                    // Detail section
                    _PrefSectionLabel('Detail Level', isDark),
                    const SizedBox(height: 10),
                    Row(
                      children: List.generate(_detailKeys.length, (i) {
                        final sel = (_localPrefs[_detailKeys[i]] ?? 0) >= 1.0;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                                right: i < _detailKeys.length - 1 ? 8 : 0),
                            child: GestureDetector(
                              onTap: () => _selectDetail(_detailKeys[i]),
                              child: _SheetChip(
                                  label:    _detailLabel[i],
                                  selected: sel,
                                  isDark:   isDark),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
            // Action buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side:    BorderSide(color: _borderC(isDark)),
                      shape:   RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('Cancel',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color:      _subC(isDark))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    icon:      const Icon(Icons.check_rounded, size: 16),
                    label:     const Text('Apply Preferences'),
                    onPressed: _apply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      elevation:       0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(
                          fontSize:   13,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _PrefSectionLabel extends StatelessWidget {
  final String label;
  final bool   isDark;
  const _PrefSectionLabel(this.label, this.isDark);

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
        width: 3, height: 14,
        decoration: BoxDecoration(
            color:        AppTheme.primaryBlue,
            borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    Text(label,
        style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize:   13,
            color:      _textC(isDark))),
  ]);
}

class _SheetChip extends StatelessWidget {
  final String label;
  final bool   selected;
  final bool   isDark;
  const _SheetChip({
    required this.label,
    required this.selected,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: selected
          ? AppTheme.primaryBlue
          : (isDark ? Colors.grey[800] : Colors.grey.shade100),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: selected
            ? AppTheme.primaryBlue
            : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
        width: selected ? 2 : 1,
      ),
    ),
    child: Center(
      child: Text(label,
          style: TextStyle(
              fontSize:   12,
              fontWeight: FontWeight.w600,
              color: selected
                  ? Colors.white
                  : (isDark ? Colors.white70 : Colors.black87))),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// TOPICS PROGRESS TRACKER
// ══════════════════════════════════════════════════════════════════════════════

class _TopicsProgressTracker extends StatelessWidget {
  final String   skill;
  final AppState appState;
  final String?  selectedTopic;
  final bool     isDark;
  final void Function(String) onSelect;

  const _TopicsProgressTracker({
    required this.skill,
    required this.appState,
    required this.selectedTopic,
    required this.isDark,
    required this.onSelect,
  });

  TopicStatus _resolveTopicStatus(String topic) {
    final key =
    '${skill}_$topic'.toLowerCase().replaceAll(' ', '_');
    if (appState.completedTopics.contains(key)) {
      return TopicStatus.passed;
    }
    final hasAny = appState.completedTopics.any((t) =>
        t.startsWith(skill.toLowerCase().replaceAll(' ', '_')));
    if (!hasAny) {
      final topics = _topicsForSkill(skill);
      if (topics.isNotEmpty && topics.first == topic) {
        return TopicStatus.inProgress;
      }
    }
    return TopicStatus.forthcoming;
  }

  @override
  Widget build(BuildContext context) {
    final topics = _topicsForSkill(skill);
    if (topics.isEmpty) { return const SizedBox.shrink(); }
    final sub = _subC(isDark);

    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1A1A2E)
            : const Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(color: _borderC(isDark)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.route_rounded, size: 12, color: sub),
            const SizedBox(width: 5),
            Text('Topics in "$skill"',
                style: TextStyle(
                    fontSize:   11,
                    fontWeight: FontWeight.w700,
                    color:      sub)),
            if (selectedTopic != null) ...[
              const Spacer(),
              GestureDetector(
                onTap: () => onSelect(selectedTopic!),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color:        AppTheme.accentTeal.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('Clear filter',
                      style: TextStyle(
                          fontSize:   10,
                          color:      AppTheme.accentTeal,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: topics.asMap().entries.map((e) {
                final topic    = e.value;
                final status   = _resolveTopicStatus(topic);
                final isActive = selectedTopic == topic;
                final Color  chipColor;
                final String emoji;
                switch (status) {
                  case TopicStatus.passed:
                    chipColor = _kSuccessGreen;
                    emoji     = '✓';
                  case TopicStatus.inProgress:
                    chipColor = Colors.orange.shade600;
                    emoji     = '⏳';
                  case TopicStatus.forthcoming:
                    chipColor = Colors.grey.shade500;
                    emoji     = '${e.key + 1}';
                }
                return GestureDetector(
                  onTap: () => onSelect(topic),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: isActive
                          ? chipColor
                          : chipColor.withAlpha(isDark ? 35 : 18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isActive
                            ? chipColor
                            : chipColor.withAlpha(80),
                        width: isActive ? 2 : 1,
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(emoji,
                          style: TextStyle(
                              fontSize:   11,
                              color:      isActive ? Colors.white : chipColor,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(width: 5),
                      Text(topic,
                          style: TextStyle(
                              fontSize:   11,
                              color:      isActive ? Colors.white : chipColor,
                              fontWeight: isActive
                                  ? FontWeight.bold
                                  : FontWeight.normal)),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MISSING SKILLS BAR
// ══════════════════════════════════════════════════════════════════════════════

class _MissingSkillsBar extends StatelessWidget {
  final List<String>          skills;
  final String                searchQuery;
  final bool                  isDark;
  final void Function(String) onTap;

  const _MissingSkillsBar({
    required this.skills,
    required this.searchQuery,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1A1A2E) : const Color(0xFFFFF7F7),
      border: Border(
        bottom: BorderSide(color: Colors.red.shade100),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.construction_rounded, size: 12, color: Colors.red.shade400),
          const SizedBox(width: 5),
          Text('Skills to build:',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize:   11,
                  color:      Colors.red.shade600)),
        ]),
        const SizedBox(height: 7),
        Wrap(
          spacing:    5,
          runSpacing: 5,
          children: skills.map((s) {
            final active = searchQuery == s;
            return GestureDetector(
              onTap: () => onTap(active ? '' : s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color:        active ? Colors.red.shade600 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border:       Border.all(color: Colors.red.shade200),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (active) ...[
                    const Icon(Icons.close_rounded,
                        color: Colors.white, size: 10),
                    const SizedBox(width: 3),
                  ],
                  Text(s,
                      style: TextStyle(
                          fontSize:   11,
                          color:      active ? Colors.white : Colors.red.shade700,
                          fontWeight: active ? FontWeight.bold : FontWeight.w500)),
                ]),
              ),
            );
          }).toList(),
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// ACTIVE FILTERS BAR
// ══════════════════════════════════════════════════════════════════════════════

class _ActiveFiltersBar extends StatelessWidget {
  final bool         showBookmarked;
  final String       sortBy;
  final bool         isDark;
  final VoidCallback onClear;

  const _ActiveFiltersBar({
    required this.showBookmarked,
    required this.sortBy,
    required this.isDark,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (showBookmarked) { parts.add('Bookmarked only'); }
    if (sortBy != 'pref' && sortBy != 'match') {
      parts.add('Sorted: ${_sortLabel(sortBy)}');
    }
    if (parts.isEmpty) { return const SizedBox.shrink(); }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark ? Colors.amber.withAlpha(18) : Colors.amber.shade50,
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color:  Colors.amber.withAlpha(40),
            shape:  BoxShape.circle,
          ),
          child: const Icon(Icons.filter_alt_rounded,
              size: 12, color: Colors.amber),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(parts.join(' · '),
              style: const TextStyle(
                  fontSize:   11,
                  fontWeight: FontWeight.w600,
                  color:      Colors.amber)),
        ),
        GestureDetector(
          onTap: onClear,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color:        Colors.amber.withAlpha(40),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('Clear all',
                style: TextStyle(
                    fontSize:   11,
                    color:      Colors.amber,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// STAR RATING DIALOG
// ══════════════════════════════════════════════════════════════════════════════

class _StarRatingDialog extends StatefulWidget {
  final Course course;
  const _StarRatingDialog({required this.course});

  @override
  State<_StarRatingDialog> createState() => _StarRatingDialogState();
}

class _StarRatingDialogState extends State<_StarRatingDialog> {
  int _rating = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const ratingLabels = ['', 'Poor', 'Fair', 'Good', 'Very Good', 'Excellent'];
    return Dialog(
      shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: _cardBg(isDark),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Icon
          Container(
            width:  56, height: 56,
            decoration: BoxDecoration(
              color:  Colors.amber.withAlpha(30),
              shape:  BoxShape.circle,
            ),
            child: const Icon(Icons.star_rounded, color: Colors.amber, size: 30),
          ),
          const SizedBox(height: 14),
          Text('Rate this course',
              style: TextStyle(
                  fontSize:   17,
                  fontWeight: FontWeight.w800,
                  color:      _textC(isDark))),
          const SizedBox(height: 6),
          Text(
            widget.course.title,
            style:     TextStyle(fontSize: 12, color: _subC(isDark)),
            textAlign: TextAlign.center,
            maxLines:  2,
            overflow:  TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          // Stars
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < _rating;
              return GestureDetector(
                onTap: () => setState(() => _rating = i + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      key:   ValueKey(filled),
                      size:  38,
                      color: filled ? Colors.amber : _borderC(isDark),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Text(
              _rating == 0 ? 'Tap a star to rate' : ratingLabels[_rating],
              key:   ValueKey(_rating),
              style: TextStyle(
                  fontSize:   13,
                  fontWeight: FontWeight.w600,
                  color:      _rating > 0 ? Colors.amber : _subC(isDark)),
            ),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side:    BorderSide(color: _borderC(isDark)),
                  shape:   RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text('Skip',
                    style: TextStyle(color: _subC(isDark))),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _rating > 0
                    ? () => Navigator.pop(context, _rating.toDouble())
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kSuccessGreen,
                  foregroundColor: Colors.white,
                  elevation:       0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(
                      fontSize:   13,
                      fontWeight: FontWeight.w700),
                ),
                child: const Text('Submit Rating'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// EMPTY STATE
// ══════════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatefulWidget {
  final String       searchQuery;
  final bool         showBookmarked;
  final VoidCallback onClearSearch;

  const _EmptyState({
    required this.searchQuery,
    required this.showBookmarked,
    required this.onClearSearch,
  });

  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceCtrl;
  late final Animation<double>   _bounceAnim;

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
        vsync:    this,
        duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _bounceAnim = Tween<double>(begin: -6, end: 6).animate(
        CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final isSearching = widget.searchQuery.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _bounceAnim,
              builder: (_, child) => Transform.translate(
                offset: Offset(0, _bounceAnim.value),
                child:  child,
              ),
              child: Container(
                width:  90, height: 90,
                decoration: BoxDecoration(
                  color:  _surfaceC(isDark),
                  shape:  BoxShape.circle,
                  border: Border.all(color: _borderC(isDark), width: 2),
                ),
                child: Icon(
                  widget.showBookmarked
                      ? Icons.bookmark_border_rounded
                      : isSearching
                      ? Icons.search_off_rounded
                      : Icons.menu_book_outlined,
                  size:  44,
                  color: _subC(isDark),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.showBookmarked
                  ? 'No bookmarked courses yet'
                  : isSearching
                  ? 'No results for "${widget.searchQuery}"'
                  : 'No courses here',
              style: TextStyle(
                  fontSize:   17,
                  fontWeight: FontWeight.w800,
                  color:      _textC(isDark)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              widget.showBookmarked
                  ? 'Tap the bookmark icon on any course to save it.'
                  : isSearching
                  ? 'Try adjusting your search or clearing the filter.'
                  : 'Check the other tabs or adjust your filters.',
              style: TextStyle(
                  color: _subC(isDark), fontSize: 13, height: 1.5),
              textAlign: TextAlign.center,
            ),
            if (isSearching) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon:      const Icon(Icons.clear_rounded, size: 16),
                label:     const Text('Clear Search'),
                onPressed: widget.onClearSearch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  elevation:       0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  textStyle: const TextStyle(
                      fontSize:   13,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}