// lib/screens/skill_trends_screen.dart //

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELS (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
class _SkillTrend {
  final String name;
  final double demandScore;
  final double demandPct;
  final double yoyChange;
  final String industry;
  final List<String> relatedJobs;

  const _SkillTrend({
    required this.name,
    required this.demandScore,
    required this.demandPct,
    required this.yoyChange,
    required this.industry,
    required this.relatedJobs,
  });
}

class _IndustryAI {
  final String name;
  final double aiScore;
  final int totalJobs;

  const _IndustryAI(this.name, this.aiScore, this.totalJobs);

  String get shortName {
    if (name.length <= 5) return name;
    const abbrev = {
      'Software': 'SW',
      'Finance': 'Fin',
      'Manufacturing': 'Mfg',
      'Healthcare': 'HC',
      'Marketing': 'Mktg',
      'Education': 'Edu',
      'Retail': 'Ret',
    };
    return abbrev[name] ?? name.substring(0, 4);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REAL DATA (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
final List<_SkillTrend> _allSkills = [
  const _SkillTrend(
    name: 'Python',
    demandScore: 98,
    demandPct: 12.3,
    yoyChange: 42.0,
    industry: 'Software',
    relatedJobs: ['Data Scientist', 'Backend Developer', 'ML Engineer'],
  ),
  const _SkillTrend(
    name: 'SQL',
    demandScore: 97,
    demandPct: 12.2,
    yoyChange: 18.0,
    industry: 'Software',
    relatedJobs: ['Data Analyst', 'Database Administrator', 'BI Developer'],
  ),
  const _SkillTrend(
    name: 'Java',
    demandScore: 75,
    demandPct: 5.2,
    yoyChange: 6.0,
    industry: 'Software',
    relatedJobs: ['Backend Engineer', 'Android Developer', 'Enterprise Dev'],
  ),
  const _SkillTrend(
    name: 'C++',
    demandScore: 75,
    demandPct: 5.2,
    yoyChange: -4.0,
    industry: 'Software',
    relatedJobs: ['Systems Programmer', 'Game Developer', 'Embedded Engineer'],
  ),
  const _SkillTrend(
    name: 'React',
    demandScore: 73,
    demandPct: 5.1,
    yoyChange: 28.0,
    industry: 'Software',
    relatedJobs: ['Frontend Developer', 'Full Stack Dev', 'UI Engineer'],
  ),
  const _SkillTrend(
    name: 'Machine Learning',
    demandScore: 71,
    demandPct: 5.1,
    yoyChange: 88.0,
    industry: 'Software',
    relatedJobs: ['ML Engineer', 'AI Researcher', 'Data Scientist'],
  ),
  const _SkillTrend(
    name: 'AWS',
    demandScore: 70,
    demandPct: 5.0,
    yoyChange: 35.0,
    industry: 'Software',
    relatedJobs: ['Cloud Architect', 'DevOps Engineer', 'Platform Eng'],
  ),
  const _SkillTrend(
    name: 'Excel',
    demandScore: 85,
    demandPct: 7.1,
    yoyChange: 5.0,
    industry: 'Finance',
    relatedJobs: ['Financial Analyst', 'Accountant', 'Operations Analyst'],
  ),
  const _SkillTrend(
    name: 'Risk Analysis',
    demandScore: 84,
    demandPct: 7.1,
    yoyChange: 22.0,
    industry: 'Finance',
    relatedJobs: ['Risk Manager', 'Compliance Officer', 'Credit Analyst'],
  ),
  const _SkillTrend(
    name: 'Financial Modeling',
    demandScore: 78,
    demandPct: 6.9,
    yoyChange: 14.0,
    industry: 'Finance',
    relatedJobs: ['Investment Banker', 'Financial Analyst', 'Quant Analyst'],
  ),
  const _SkillTrend(
    name: 'Production Planning',
    demandScore: 92,
    demandPct: 10.9,
    yoyChange: 12.0,
    industry: 'Manufacturing',
    relatedJobs: ['Production Manager', 'Operations Director', 'Plant Manager'],
  ),
  const _SkillTrend(
    name: 'Quality Control',
    demandScore: 91,
    demandPct: 10.8,
    yoyChange: 8.0,
    industry: 'Manufacturing',
    relatedJobs: ['QA Engineer', 'Quality Inspector', 'Process Engineer'],
  ),
  const _SkillTrend(
    name: 'Supply Chain',
    demandScore: 90,
    demandPct: 10.8,
    yoyChange: 28.0,
    industry: 'Manufacturing',
    relatedJobs: ['Supply Chain Analyst', 'Logistics Manager', 'Procurement Mgr'],
  ),
  const _SkillTrend(
    name: 'Customer Service',
    demandScore: 89,
    demandPct: 10.7,
    yoyChange: 4.0,
    industry: 'Retail',
    relatedJobs: ['Customer Success Rep', 'Retail Manager', 'Support Agent'],
  ),
  const _SkillTrend(
    name: 'Sales',
    demandScore: 88,
    demandPct: 10.6,
    yoyChange: 7.0,
    industry: 'Retail',
    relatedJobs: ['Sales Executive', 'Account Manager', 'Business Dev Rep'],
  ),
  const _SkillTrend(
    name: 'Merchandising',
    demandScore: 88,
    demandPct: 10.8,
    yoyChange: -2.0,
    industry: 'Retail',
    relatedJobs: ['Merchandiser', 'Visual Merchandiser', 'Category Manager'],
  ),
  const _SkillTrend(
    name: 'Patient Care',
    demandScore: 82,
    demandPct: 9.0,
    yoyChange: 15.0,
    industry: 'Healthcare',
    relatedJobs: ['Nurse', 'Healthcare Assistant', 'Clinical Coordinator'],
  ),
  const _SkillTrend(
    name: 'Medical Research',
    demandScore: 80,
    demandPct: 8.9,
    yoyChange: 32.0,
    industry: 'Healthcare',
    relatedJobs: ['Clinical Researcher', 'Medical Scientist', 'Pharmacologist'],
  ),
  const _SkillTrend(
    name: 'SEO',
    demandScore: 82,
    demandPct: 7.3,
    yoyChange: 20.0,
    industry: 'Marketing',
    relatedJobs: ['SEO Specialist', 'Content Marketer', 'Digital Marketer'],
  ),
  const _SkillTrend(
    name: 'Content Writing',
    demandScore: 82,
    demandPct: 7.3,
    yoyChange: 12.0,
    industry: 'Marketing',
    relatedJobs: ['Content Writer', 'Copywriter', 'Brand Strategist'],
  ),
  const _SkillTrend(
    name: 'Google Ads',
    demandScore: 81,
    demandPct: 7.2,
    yoyChange: 25.0,
    industry: 'Marketing',
    relatedJobs: ['Paid Media Specialist', 'PPC Manager', 'Growth Marketer'],
  ),
  const _SkillTrend(
    name: 'Social Media',
    demandScore: 80,
    demandPct: 7.0,
    yoyChange: 10.0,
    industry: 'Marketing',
    relatedJobs: ['Social Media Manager', 'Community Manager', 'Influencer Mgr'],
  ),
  const _SkillTrend(
    name: 'Market Research',
    demandScore: 81,
    demandPct: 7.1,
    yoyChange: 18.0,
    industry: 'Marketing',
    relatedJobs: ['Market Research Analyst', 'Brand Manager', 'Insights Analyst'],
  ),
  const _SkillTrend(
    name: 'Teaching',
    demandScore: 79,
    demandPct: 9.0,
    yoyChange: 3.0,
    industry: 'Education',
    relatedJobs: ['Teacher', 'Curriculum Developer', 'Education Coordinator'],
  ),
  const _SkillTrend(
    name: 'EdTech',
    demandScore: 78,
    demandPct: 9.0,
    yoyChange: 45.0,
    industry: 'Education',
    relatedJobs: ['EdTech Specialist', 'LMS Administrator', 'E-learning Developer'],
  ),
  const _SkillTrend(
    name: 'Curriculum Design',
    demandScore: 77,
    demandPct: 9.0,
    yoyChange: 12.0,
    industry: 'Education',
    relatedJobs: ['Instructional Designer', 'Course Developer', 'Training Manager'],
  ),
];

const List<_IndustryAI> _industryAI = [
  _IndustryAI('Software', 100.0, 7302),
  _IndustryAI('Finance', 75.4, 7017),
  _IndustryAI('Manufacturing', 75.3, 7169),
  _IndustryAI('Healthcare', 42.0, 7104),
  _IndustryAI('Marketing', 38.0, 7158),
  _IndustryAI('Education', 32.0, 7144),
  _IndustryAI('Retail', 18.0, 7106),
];

const List<String> _filterOptions = [
  'All',
  'Software',
  'Finance',
  'Manufacturing',
  'Healthcare',
  'Marketing',
  'Education',
  'Retail',
];

const List<String> _userSkills = [
  'Python',
  'SQL',
  'Excel',
  'Market Research',
  'Teaching',
];

// ─────────────────────────────────────────────────────────────────────────────
// DESIGN SYSTEM (kept for visual fidelity — now driven by global Theme)
// ─────────────────────────────────────────────────────────────────────────────
class _T {
  // Blues
  static const blue400 = Color(0xFF60A5FA);
  static const blue500 = Color(0xFF3B82F6);
  static const blue600 = Color(0xFF2563EB);
  static const blue700 = Color(0xFF1D4ED8);

  // Greens
  static const green400 = Color(0xFF4ADE80);
  static const green500 = Color(0xFF22C55E);
  static const green600 = Color(0xFF16A34A);
  static const green100 = Color(0xFFDCFCE7);

  // Reds
  static const red500 = Color(0xFFEF4444);
  static const red600 = Color(0xFFDC2626);
  static const red100 = Color(0xFFFEE2E2);

  // Amber
  static const amber400 = Color(0xFFFBBF24);
  static const amber500 = Color(0xFFF59E0B);
  static const amber100 = Color(0xFFFEF3C7);

  // Violet
  static const violet400 = Color(0xFFA78BFA);
  static const violet500 = Color(0xFF8B5CF6);
  static const violet600 = Color(0xFF7C3AED);

  // Slate (dark-mode base)
  static const slate900 = Color(0xFF0F172A);
  static const slate800 = Color(0xFF1E293B);
  static const slate750 = Color(0xFF1A2332);
  static const slate700 = Color(0xFF334155);
  static const slate600 = Color(0xFF475569);
  static const slate500 = Color(0xFF64748B);
  static const slate400 = Color(0xFF94A3B8);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate50 = Color(0xFFF8FAFC);
}

// Semantic aliases — now driven by global Theme.of(context).brightness
Color _bg(bool d) => d ? _T.slate900 : _T.slate50;
Color _card(bool d) => d ? _T.slate800 : Colors.white;
Color _border(bool d) => d ? _T.slate700 : _T.slate200;
Color _text(bool d) => d ? Colors.white : _T.slate900;
Color _sub(bool d) => d ? _T.slate400 : _T.slate500;

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS (minor padding & shadow consistency improvements)
// ─────────────────────────────────────────────────────────────────────────────
/// Glass-morphism card with optional top-edge gradient accent line.
class _GCard extends StatelessWidget {
  const _GCard({
    required this.child,
    required this.isDark,
    this.accent,
    this.padding = const EdgeInsets.all(18),
    this.radius = 20.0,
  });

  final Widget child;
  final bool isDark;
  final Color? accent;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _card(isDark),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: isDark ? _T.slate700.withValues(alpha: 0.5) : _T.slate200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 16,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          ),
          if (accent != null)
            BoxShadow(
              color: accent!.withValues(alpha: isDark ? 0.07 : 0.04),
              blurRadius: 20,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            if (accent != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 2.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent!.withValues(alpha: 0.0),
                        accent!.withValues(alpha: 0.9),
                        accent!.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

/// Animated gradient progress bar.
class _GradBar extends StatelessWidget {
  const _GradBar({
    required this.value,
    required this.colors,
    this.height = 7.0,
    this.isDark = false,
    this.duration = const Duration(milliseconds: 900),
  });

  final double value;
  final List<Color> colors;
  final double height;
  final bool isDark;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: duration,
      curve: Curves.easeOut,
      builder: (_, v, __) => ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: Stack(
          children: [
            Container(
              height: height,
              color: isDark ? _T.slate700 : _T.slate100,
            ),
            FractionallySizedBox(
              widthFactor: v,
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(height / 2),
                  boxShadow: [
                    BoxShadow(
                      color: colors.last.withValues(alpha: 0.38),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section header: coloured icon box + title/subtitle stack.
class _SectionHead extends StatelessWidget {
  const _SectionHead({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconBg,
    required this.iconColor,
    required this.isDark,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconBg;
  final Color iconColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _text(isDark),
                letterSpacing: -0.2,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11.5, color: _sub(isDark)),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class SkillTrendsScreen extends StatefulWidget {
  const SkillTrendsScreen({super.key});

  @override
  State<SkillTrendsScreen> createState() => _SkillTrendsScreenState();
}

class _SkillTrendsScreenState extends State<SkillTrendsScreen> with TickerProviderStateMixin {
  // ── Original state (unchanged) ────────────────────────────────────────────
  String _query = '';
  String _filterIndustry = 'All';
  final TextEditingController _searchCtrl = TextEditingController();

  // ── UI state (local dark removed — now uses global Theme) ──────────────────
  final Set<String> _addedSkills = {};

  // ── Animation controllers ─────────────────────────────────────────────────
  late final AnimationController _headerCtrl;
  late final Animation<double> _headerFade;

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _headerFade = CurvedAnimation(
      parent: _headerCtrl,
      curve: Curves.easeOut,
    );
    _headerCtrl.forward();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _headerCtrl.dispose();
    super.dispose();
  }

  // ── Original filter logic (unchanged) ─────────────────────────────────────
  List<_SkillTrend> get _filtered => _allSkills.where((s) {
    final q = _query.isEmpty || s.name.toLowerCase().contains(_query.toLowerCase());
    final ind = _filterIndustry == 'All' || s.industry == _filterIndustry;
    return q && ind;
  }).toList()
    ..sort((a, b) => b.demandScore.compareTo(a.demandScore));

  List<_SkillTrend> get _top10 => (List.of(_allSkills)..sort((a, b) => b.demandScore.compareTo(a.demandScore)))
      .take(10)
      .toList();

  // ── Original show-detail logic (unchanged except isDark source) ───────────
  void _showSkillDetail(BuildContext ctx, _SkillTrend skill) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SkillDetailSheet(
        skill: skill,
        // Now driven by global Theme (consistent with app_theme.dart)
        isDark: Theme.of(ctx).brightness == Brightness.dark,
        isAdded: _addedSkills.contains(skill.name),
        onAdd: () {
          setState(() {
            if (_addedSkills.contains(skill.name)) {
              _addedSkills.remove(skill.name);
            } else {
              _addedSkills.add(skill.name);
            }
          });
          Navigator.pop(ctx);
        },
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    // Global theme integration — fixes toggle bug, persistence, and instant updates
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: _bg(isDark),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Animated SliverAppBar (toggle button removed — only global toggle remains)
          SliverAppBar(
            pinned: true,
            expandedHeight: 180,
            backgroundColor: isDark ? _T.slate900 : Colors.white,
            surfaceTintColor: Colors.transparent,
            systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: _text(isDark)),
              onPressed: () => Navigator.maybePop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark ? [_T.slate900, _T.slate800] : [Colors.white, _T.slate50],
                  ),
                ),
                child: FadeTransition(
                  opacity: _headerFade,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 52, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Label pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _T.blue500.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _T.blue500.withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.trending_up_rounded, size: 11, color: _T.blue500),
                                SizedBox(width: 5),
                                Text(
                                  'Live Market Data · 50k Jobs',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: _T.blue500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Skill Trends',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: _text(isDark),
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Google Trends — but for your career.',
                            style: TextStyle(
                              fontSize: 13,
                              color: _sub(isDark),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Quick stats row
                          Row(
                            children: [
                              _HeaderStatPill(
                                icon: Icons.work_rounded,
                                label: '${_allSkills.length} skills',
                                color: _T.blue500,
                                isDark: isDark,
                              ),
                              const SizedBox(width: 8),
                              _HeaderStatPill(
                                icon: Icons.business_rounded,
                                label: '7 industries',
                                color: _T.violet500,
                                isDark: isDark,
                              ),
                              const SizedBox(width: 8),
                              _HeaderStatPill(
                                icon: Icons.check_circle_rounded,
                                label: '${_userSkills.length} you have',
                                color: _T.green500,
                                isDark: isDark,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            title: Text(
              'Skill Trends',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _text(isDark),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(height: 1, thickness: 1, color: _border(isDark)),
            ),
          ),

          // ── Search bar (consistent padding)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _GCard(
                isDark: isDark,
                accent: _T.blue500,
                padding: EdgeInsets.zero,
                radius: 16,
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    const Icon(Icons.search_rounded, color: _T.blue500, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        style: TextStyle(fontSize: 14, color: _text(isDark)),
                        decoration: InputDecoration(
                          hintText: 'Search a skill...',
                          hintStyle: TextStyle(fontSize: 14, color: _sub(isDark)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        onChanged: (v) => setState(() => _query = v),
                      ),
                    ),
                    if (_query.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(right: 14),
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: _sub(isDark).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.close_rounded, color: _sub(isDark), size: 13),
                          ),
                        ),
                      ),
                  ],
                ),
              ).animate().fadeIn(duration: 350.ms),
            ),
          ),

          // ── Category filter chips
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: _filterOptions.map((cat) {
                      final isActive = _filterIndustry == cat;
                      return _FilterChip(
                        label: cat,
                        isActive: isActive,
                        isDark: isDark,
                        onTap: () => setState(() => _filterIndustry = cat),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),

          // ── Word-cloud card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: _GCard(
                isDark: isDark,
                accent: _T.blue500,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHead(
                      icon: Icons.whatshot_rounded,
                      title: 'Trending Skills',
                      subtitle: 'Tap any skill chip to explore details',
                      iconBg: _T.blue500.withValues(alpha: 0.1),
                      iconColor: _T.blue500,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 18),
                    filtered.isEmpty
                        ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(Icons.search_off_rounded, size: 36, color: _sub(isDark).withValues(alpha: 0.5)),
                            const SizedBox(height: 8),
                            Text(
                              'No skills match your search.',
                              style: TextStyle(color: _sub(isDark)),
                            ),
                          ],
                        ),
                      ),
                    )
                        : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: filtered.take(20).map((s) {
                        return _CloudChip(
                          skill: s,
                          isDark: isDark,
                          onTap: () => _showSkillDetail(context, s),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    // Legend
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Low', style: TextStyle(fontSize: 10.5, color: _sub(isDark))),
                        const SizedBox(width: 8),
                        Container(
                          height: 6,
                          width: 110,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFDBEAFE), _T.blue600],
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('High Demand', style: TextStyle(fontSize: 10.5, color: _sub(isDark))),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 60.ms),
            ),
          ),

          // ── Top 10 list (consistent card spacing)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 22,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_T.blue500, _T.blue700],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: _T.blue500.withValues(alpha: 0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Top 10 Trending Skills',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _text(isDark),
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (_, i) {
                  final skill = _top10[i];
                  final isAdded = _addedSkills.contains(skill.name);
                  return _Top10Card(
                    skill: skill,
                    rank: i + 1,
                    isDark: isDark,
                    isAdded: isAdded,
                    delay: Duration(milliseconds: i * 45),
                    onAdd: () => setState(() {
                      if (isAdded) {
                        _addedSkills.remove(skill.name);
                      } else {
                        _addedSkills.add(skill.name);
                      }
                    }),
                    onTap: () => _showSkillDetail(context, skill),
                  );
                },
                childCount: _top10.length,
              ),
            ),
          ),

          // ── AI Adoption bar chart
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: _GCard(
                isDark: isDark,
                accent: _T.violet500,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHead(
                      icon: Icons.psychology_rounded,
                      title: 'AI Adoption by Industry',
                      subtitle: 'How fast AI is entering each sector',
                      iconBg: _T.violet500.withValues(alpha: 0.1),
                      iconColor: _T.violet500,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 270,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          barTouchData: BarTouchData(
                            enabled: true,
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipColor: (_) => isDark ? _T.slate700 : Colors.white,
                              tooltipBorderRadius: BorderRadius.circular(10),
                              getTooltipItem: (group, _, rod, __) {
                                final i = group.x;
                                if (i < 0 || i >= _industryAI.length) return null;
                                return BarTooltipItem(
                                  '${_industryAI[i].name}\n',
                                  TextStyle(
                                    color: _text(isDark),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: '${rod.toY.round()}% AI demand',
                                      style: const TextStyle(
                                        color: _T.violet500,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          barGroups: _industryAI.asMap().entries.map((e) {
                            return BarChartGroupData(
                              x: e.key,
                              barRods: [
                                BarChartRodData(
                                  toY: e.value.aiScore,
                                  width: 20,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                  gradient: const LinearGradient(
                                    colors: [_T.violet400, _T.violet600],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 42,
                                getTitlesWidget: (v, _) {
                                  final i = v.toInt();
                                  if (i < 0 || i >= _industryAI.length) return const SizedBox.shrink();
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      _industryAI[i].shortName,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        color: _sub(isDark),
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  );
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 32,
                                interval: 25,
                                getTitlesWidget: (v, _) => Text(
                                  '${v.toInt()}',
                                  style: TextStyle(fontSize: 10, color: _sub(isDark)),
                                ),
                              ),
                            ),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (_) => FlLine(
                              color: _border(isDark).withValues(alpha: 0.5),
                              strokeWidth: 1,
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          maxY: 110,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Score 0–100: higher = more AI skills demanded in job posts',
                        style: TextStyle(fontSize: 11, color: _sub(isDark)),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 450.ms, delay: 80.ms),
            ),
          ),

          // ── Your Skills vs Market
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: _GCard(
                isDark: isDark,
                accent: _T.green500,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHead(
                      icon: Icons.compare_arrows_rounded,
                      title: 'Your Skills vs Market',
                      subtitle: 'Matching your profile against market demand',
                      iconBg: _T.green500.withValues(alpha: 0.1),
                      iconColor: _T.green500,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 18),
                    _SkillMatchSection(isDark: isDark),
                  ],
                ),
              ).animate().fadeIn(duration: 450.ms, delay: 120.ms),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 88)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header stat pill
// ─────────────────────────────────────────────────────────────────────────────
class _HeaderStatPill extends StatelessWidget {
  const _HeaderStatPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: _text(isDark),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter chip (micro-interaction kept)
// ─────────────────────────────────────────────────────────────────────────────
class _FilterChip extends StatefulWidget {
  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 110));
    _scale = Tween<double>(begin: 1.0, end: 0.93).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _tap() async {
    await _ctrl.forward();
    await _ctrl.reverse();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _tap,
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: widget.isActive
                ? const LinearGradient(colors: [_T.blue500, _T.blue700], begin: Alignment.topLeft, end: Alignment.bottomRight)
                : null,
            color: widget.isActive ? null : _card(widget.isDark),
            borderRadius: BorderRadius.circular(100),
            border: widget.isActive ? null : Border.all(color: _border(widget.isDark), width: 1.5),
            boxShadow: widget.isActive
                ? [
              BoxShadow(
                color: _T.blue500.withValues(alpha: 0.38),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ]
                : null,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: widget.isActive ? Colors.white : _text(widget.isDark),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Word-cloud chip
// ─────────────────────────────────────────────────────────────────────────────
class _CloudChip extends StatefulWidget {
  const _CloudChip({
    required this.skill,
    required this.isDark,
    required this.onTap,
  });

  final _SkillTrend skill;
  final bool isDark;
  final VoidCallback onTap;

  @override
  State<_CloudChip> createState() => _CloudChipState();
}

class _CloudChipState extends State<_CloudChip> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.89).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _tap() async {
    HapticFeedback.selectionClick();
    await _ctrl.forward();
    await _ctrl.reverse();
    widget.onTap();
  }

  Color _chipColor(double d) {
    if (d >= 90) return _T.blue700;
    if (d >= 75) return _T.blue600;
    if (d >= 60) return _T.blue500;
    if (d >= 45) return _T.blue400;
    return const Color(0xFF93C5FD);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.skill;
    final fontSize = 10.0 + (s.demandScore / 20).clamp(0.0, 10.0);
    final chipColor = _chipColor(s.demandScore);
    final fgColor = s.demandScore > 60 ? Colors.white : _T.blue700;
    final hPad = 12.0 + s.demandScore / 20;

    return GestureDetector(
      onTap: _tap,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 7),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [chipColor, chipColor.withValues(alpha: 0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(100),
            boxShadow: [
              BoxShadow(
                color: chipColor.withValues(alpha: 0.28),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            s.name,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: s.demandScore > 70 ? FontWeight.w800 : FontWeight.w600,
              color: fgColor,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top-10 card (refined spacing & shadow consistency)
// ─────────────────────────────────────────────────────────────────────────────
class _Top10Card extends StatelessWidget {
  const _Top10Card({
    required this.skill,
    required this.rank,
    required this.isDark,
    required this.isAdded,
    required this.delay,
    required this.onAdd,
    required this.onTap,
  });

  final _SkillTrend skill;
  final int rank;
  final bool isDark;
  final bool isAdded;
  final Duration delay;
  final VoidCallback onAdd;
  final VoidCallback onTap;

  Widget _changeBadge(double yoy) {
    final isPos = yoy > 0;
    final isFlat = yoy == 0;
    final bg = isFlat ? _T.slate200 : isPos ? _T.green100 : _T.red100;
    final fg = isFlat ? _T.slate500 : isPos ? _T.green600 : _T.red600;
    final label = isFlat ? '→ stable' : isPos ? '↑ +${yoy.toStringAsFixed(0)}%' : '↓ ${yoy.toStringAsFixed(0)}%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: _card(isDark),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border(isDark)),
          boxShadow: isDark
              ? []
              : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Gradient rank badge
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: rank <= 3
                      ? LinearGradient(
                    colors: [
                      [const Color(0xFFFFD700), const Color(0xFFFFA500)],
                      [_T.slate400, _T.slate600],
                      [const Color(0xFFCD7F32), const Color(0xFF8B4513)],
                    ][rank - 1],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                      : null,
                  color: rank > 3 ? (isDark ? _T.slate750 : _T.slate100) : null,
                  border: rank > 3 ? Border.all(color: _border(isDark)) : null,
                  boxShadow: rank <= 3
                      ? [
                    BoxShadow(
                      color: [
                        const Color(0xFFFFD700),
                        _T.slate400,
                        const Color(0xFFCD7F32),
                      ][rank - 1].withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: rank <= 3 ? Colors.white : _sub(isDark),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Skill info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      skill.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _text(isDark),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: _T.blue500.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            skill.industry,
                            style: const TextStyle(
                              fontSize: 10,
                              color: _T.blue500,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Demand bar + pct
              SizedBox(
                width: 76,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _GradBar(
                      value: skill.demandScore / 100,
                      colors: const [_T.blue400, _T.blue700],
                      height: 6,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${skill.demandScore.round()}%',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _T.blue500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _changeBadge(skill.yoyChange),
              const SizedBox(width: 10),
              _AddToggle(
                isAdded: isAdded,
                isDark: isDark,
                onTap: onAdd,
              ),
            ],
          ),
        ),
      ).animate(delay: delay).fadeIn(duration: 350.ms).slideX(begin: 0.04, end: 0),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add-skill toggle button
// ─────────────────────────────────────────────────────────────────────────────
class _AddToggle extends StatefulWidget {
  const _AddToggle({
    required this.isAdded,
    required this.isDark,
    required this.onTap,
  });

  final bool isAdded;
  final bool isDark;
  final VoidCallback onTap;

  @override
  State<_AddToggle> createState() => _AddToggleState();
}

class _AddToggleState extends State<_AddToggle> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 110));
    _scale = Tween<double>(begin: 1.0, end: 0.85).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _tap() async {
    HapticFeedback.selectionClick();
    await _ctrl.forward();
    await _ctrl.reverse();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _tap,
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            gradient: widget.isAdded
                ? const LinearGradient(colors: [_T.green400, _T.green600], begin: Alignment.topLeft, end: Alignment.bottomRight)
                : null,
            color: widget.isAdded ? null : _card(widget.isDark),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.isAdded ? Colors.transparent : _border(widget.isDark),
            ),
            boxShadow: widget.isAdded
                ? [
              BoxShadow(
                color: _T.green500.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ]
                : null,
          ),
          child: Icon(
            widget.isAdded ? Icons.check_rounded : Icons.add_rounded,
            color: widget.isAdded ? Colors.white : _sub(widget.isDark),
            size: 18,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SKILL MATCH SECTION (all logic unchanged)
// ─────────────────────────────────────────────────────────────────────────────
class _SkillMatchSection extends StatelessWidget {
  const _SkillMatchSection({required this.isDark});

  final bool isDark;

  static final Set<String> _topNames = _allSkills.where((s) => s.demandScore >= 75).map((s) => s.name).toSet();

  @override
  Widget build(BuildContext context) {
    final inDemandHave = _userSkills.where((s) => _topNames.contains(s)).toList();
    final inDemandMissing = _topNames.where((s) => !_userSkills.contains(s)).take(5).toList();
    final haveButLess = _userSkills.where((s) => !_topNames.contains(s)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (inDemandHave.isNotEmpty) ...[
          _MatchGroupHeader(emoji: '✅', label: 'You have these in-demand skills', isDark: isDark),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: inDemandHave.map((s) {
              final trend = _allSkills.firstWhere(
                    (t) => t.name == s,
                orElse: () => _SkillTrend(
                  name: s,
                  demandScore: 0,
                  demandPct: 0,
                  yoyChange: 0,
                  industry: '',
                  relatedJobs: [],
                ),
              );
              return _MatchChip(
                label: s,
                bgColor: _T.green100,
                fgColor: _T.green600,
                borderColor: _T.green500.withValues(alpha: 0.35),
                icon: Icons.check_circle_rounded,
                progress: trend.demandScore / 100,
                progressColors: const [_T.green400, _T.green600],
                isDark: isDark,
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
        ],
        if (inDemandMissing.isNotEmpty) ...[
          _MatchGroupHeader(emoji: '🔥', label: "In-demand skills you're missing", isDark: isDark),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: inDemandMissing.map((s) {
              final trend = _allSkills.firstWhere(
                    (t) => t.name == s,
                orElse: () => _SkillTrend(
                  name: s,
                  demandScore: 0,
                  demandPct: 0,
                  yoyChange: 0,
                  industry: '',
                  relatedJobs: [],
                ),
              );
              return _MatchChip(
                label: s,
                bgColor: _T.red100,
                fgColor: _T.red600,
                borderColor: _T.red500.withValues(alpha: 0.35),
                icon: Icons.add_circle_outline_rounded,
                progress: trend.demandScore / 100,
                progressColors: const [_T.red500, _T.red600],
                isDark: isDark,
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
        ],
        if (haveButLess.isNotEmpty) ...[
          _MatchGroupHeader(emoji: '📉', label: 'Skills you have that are losing demand', isDark: isDark),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: haveButLess
                .map((s) => _MatchChip(
              label: s,
              bgColor: _T.amber100,
              fgColor: _T.amber500,
              borderColor: _T.amber400.withValues(alpha: 0.35),
              icon: Icons.trending_down_rounded,
              progress: 0.35,
              progressColors: const [_T.amber400, _T.amber500],
              isDark: isDark,
            ))
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _MatchGroupHeader extends StatelessWidget {
  const _MatchGroupHeader({
    required this.emoji,
    required this.label,
    required this.isDark,
  });

  final String emoji;
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _sub(isDark),
          ),
        ),
      ],
    );
  }
}

class _MatchChip extends StatelessWidget {
  const _MatchChip({
    required this.label,
    required this.bgColor,
    required this.fgColor,
    required this.borderColor,
    required this.icon,
    required this.progress,
    required this.progressColors,
    required this.isDark,
  });

  final String label;
  final Color bgColor;
  final Color fgColor;
  final Color borderColor;
  final IconData icon;
  final double progress;
  final List<Color> progressColors;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: fgColor, size: 13),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: fgColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 80,
            child: _GradBar(
              value: progress,
              colors: progressColors,
              height: 4,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SKILL DETAIL BOTTOM SHEET (padding & alignment refined for consistency)
// ─────────────────────────────────────────────────────────────────────────────
class _SkillDetailSheet extends StatelessWidget {
  const _SkillDetailSheet({
    required this.skill,
    required this.isDark,
    required this.isAdded,
    required this.onAdd,
  });

  final _SkillTrend skill;
  final bool isDark;
  final bool isAdded;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final isPos = skill.yoyChange >= 0;
    final trendColor = isPos ? _T.green500 : _T.red500;
    final demandRatio = skill.demandScore / 100;

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).padding.bottom + 28,
      ),
      decoration: BoxDecoration(
        color: _card(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 30,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: _border(isDark),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      skill.name,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: _text(isDark),
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: _T.blue500.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        skill.industry,
                        style: const TextStyle(
                          fontSize: 11,
                          color: _T.blue500,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _sub(isDark).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close_rounded, color: _sub(isDark), size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Demand meter
          Row(
            children: [
              Text(
                'Market Demand',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _sub(isDark),
                ),
              ),
              const Spacer(),
              Text(
                '${skill.demandScore.round()}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _T.blue500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _GradBar(
            value: demandRatio,
            colors: const [_T.blue400, _T.blue700],
            height: 10,
            isDark: isDark,
            duration: const Duration(milliseconds: 700),
          ),
          const SizedBox(height: 18),
          // Stat boxes
          Row(
            children: [
              _StatBox(
                label: 'Demand',
                value: '${skill.demandScore.round()}%',
                color: _T.blue500,
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _StatBox(
                label: 'YoY',
                value: isPos ? '+${skill.yoyChange.round()}%' : '${skill.yoyChange.round()}%',
                color: trendColor,
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _StatBox(
                label: 'Job Posts',
                value: '${(skill.demandPct * 500).round()}+',
                color: _T.violet500,
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Trend momentum indicator
          _MomentumBar(yoyChange: skill.yoyChange, isDark: isDark),
          const SizedBox(height: 18),
          // Related jobs
          Text(
            'Related Jobs',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _sub(isDark),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: skill.relatedJobs
                .map((j) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: _T.blue500.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _T.blue500.withValues(alpha: 0.25)),
              ),
              child: Text(
                j,
                style: const TextStyle(
                  fontSize: 12,
                  color: _T.blue500,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ))
                .toList(),
          ),
          const SizedBox(height: 22),
          // CTA button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isAdded ? [_T.green400, _T.green600] : [_T.blue500, _T.blue700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: (isAdded ? _T.green500 : _T.blue500).withValues(alpha: 0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: onAdd,
                icon: Icon(
                  isAdded ? Icons.check_rounded : Icons.add_circle_outline_rounded,
                  size: 18,
                ),
                label: Text(
                  isAdded ? 'Added to Learning List ✓' : 'Add to My Learning List',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stat box ──────────────────────────────────────────────────────────────────
class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  final String label;
  final String value;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: _sub(isDark))),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Momentum bar ──────────────────────────────────────────────────────────────
class _MomentumBar extends StatelessWidget {
  const _MomentumBar({
    required this.yoyChange,
    required this.isDark,
  });

  final double yoyChange;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final isPos = yoyChange >= 0;
    final color = isPos ? _T.green500 : _T.red500;
    final label = isPos
        ? '🚀 Strong momentum · +${yoyChange.round()}% YoY growth'
        : '⚠️ Declining · ${yoyChange.round()}% YoY change';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPos ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                color: color,
                size: 15,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (_, constraints) {
              final w = constraints.maxWidth;
              final mid = w / 2;
              final fill = (yoyChange.abs().clamp(0.0, 100.0) / 100) * mid;
              return Stack(
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: isDark ? _T.slate700 : _T.slate100,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Positioned(
                    left: isPos ? mid : mid - fill,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: fill),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOut,
                      builder: (_, v, __) => Container(
                        width: v,
                        height: 6,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              color.withValues(alpha: 0.6),
                              color,
                            ],
                            begin: isPos ? Alignment.centerLeft : Alignment.centerRight,
                            end: isPos ? Alignment.centerRight : Alignment.centerLeft,
                          ),
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.35),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: mid - 1,
                    child: Container(
                      width: 2,
                      height: 6,
                      color: _sub(isDark).withValues(alpha: 0.4),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Declining', style: TextStyle(fontSize: 9, color: _T.red500)),
              Text('Stable', style: TextStyle(fontSize: 9, color: _sub(isDark))),
              const Text('Growing', style: TextStyle(fontSize: 9, color: _T.green500)),
            ],
          ),
        ],
      ),
    );
  }
}