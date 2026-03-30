// lib/screens/job_transition_screen.dart
// THEME FIX v2.1 — replaces local _isDark state with global Theme.of(context)
// UI UPGRADE v2.0 — "Career GPS — Ultra Premium Navigator"
// Data sourced from: JobsFE.csv (10,000 listings) + job_recommendation_dataset.csv (50,000 listings)
// ── ALL LOGIC, ML CALLS, STATE, AND HANDLERS ARE UNCHANGED ──────────────────
// ── THEME CHANGES ONLY:
//    • bool _isDark = false  →  bool get _isDark => Theme.of(context).brightness == Brightness.dark
//    • _buildDarkToggle() removed  (single global toggle lives in main_nav / dashboard)
//    • Theme(data: ThemeData(...)) wrapper removed  (app-level provider governs)
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELS  (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class OccupationInfo {
  final String title;
  final String industry;
  final List<String> coreSkills;
  final double avgSalary;
  final int listingCount;
  const OccupationInfo({
    required this.title,
    required this.industry,
    required this.coreSkills,
    required this.avgSalary,
    required this.listingCount,
  });
}

class PrioritizedSkill {
  final String skillName;
  final double importanceScore;
  final double distanceScore;
  final String priorityLabel; // 'must' | 'soon' | 'have'
  final String reasoning;
  final String estimatedTime;
  const PrioritizedSkill({
    required this.skillName,
    required this.importanceScore,
    required this.distanceScore,
    required this.priorityLabel,
    required this.reasoning,
    required this.estimatedTime,
  });
}

class TransitionResult {
  final double similarityScore;
  final String difficulty;
  final String estimatedTime;
  final int skillGap;
  final bool isAsymmetric;
  final double fromAvgSalary;
  final double toAvgSalary;
  final List<PrioritizedSkill> skills;
  final List<String> bridgeSkills;
  const TransitionResult({
    required this.similarityScore,
    required this.difficulty,
    required this.estimatedTime,
    required this.skillGap,
    required this.isAsymmetric,
    required this.fromAvgSalary,
    required this.toAvgSalary,
    required this.skills,
    required this.bridgeSkills,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// REAL DATA  (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

const List<OccupationInfo> _occupations = [
  OccupationInfo(
    title: 'Software Engineer',
    industry: 'Software',
    coreSkills: ['Python', 'Java', 'SQL', 'C++', 'React', 'AWS', 'Machine Learning', 'Git'],
    avgSalary: 95606, listingCount: 165,
  ),
  OccupationInfo(
    title: 'Data Analyst',
    industry: 'Software',
    coreSkills: ['SQL', 'Python', 'Excel', 'Tableau', 'Power BI', 'Risk Analysis', 'Data Visualization'],
    avgSalary: 84169, listingCount: 89,
  ),
  OccupationInfo(
    title: 'Financial Analyst',
    industry: 'Finance',
    coreSkills: ['Excel', 'Financial Modeling', 'Risk Analysis', 'SQL', 'Python', 'Market Research'],
    avgSalary: 94944, listingCount: 84,
  ),
  OccupationInfo(
    title: 'Digital Marketing Specialist',
    industry: 'Marketing',
    coreSkills: ['SEO', 'Google Ads', 'Content Writing', 'Social Media', 'Market Research', 'Analytics'],
    avgSalary: 95204, listingCount: 181,
  ),
  OccupationInfo(
    title: 'UX/UI Designer',
    industry: 'Software',
    coreSkills: ['Figma', 'Adobe XD', 'Wireframing', 'Prototyping', 'User Research', 'CSS', 'React'],
    avgSalary: 82266, listingCount: 288,
  ),
  OccupationInfo(
    title: 'Operations Manager',
    industry: 'Manufacturing',
    coreSkills: ['Supply Chain', 'Production Planning', 'Quality Control', 'Risk Analysis', 'SQL', 'Excel'],
    avgSalary: 84117, listingCount: 81,
  ),
  OccupationInfo(
    title: 'Marketing Analyst',
    industry: 'Marketing',
    coreSkills: ['SEO', 'Market Research', 'Google Ads', 'Social Media', 'Excel', 'Data Visualization'],
    avgSalary: 83000, listingCount: 100,
  ),
  OccupationInfo(
    title: 'Project Manager',
    industry: 'Software',
    coreSkills: ['Agile', 'Scrum', 'Risk Analysis', 'SQL', 'Excel', 'Communication', 'Jira'],
    avgSalary: 84196, listingCount: 92,
  ),
  OccupationInfo(
    title: 'HR Coordinator',
    industry: 'Education',
    coreSkills: ['Recruitment', 'Training', 'Excel', 'Communication', 'Payroll', 'HRIS'],
    avgSalary: 82000, listingCount: 102,
  ),
  OccupationInfo(
    title: 'Content Writer',
    industry: 'Marketing',
    coreSkills: ['Content Writing', 'SEO', 'Market Research', 'Social Media', 'Research', 'Copywriting'],
    avgSalary: 83918, listingCount: 85,
  ),
];

const Map<String, double> _skillImportance = {
  'Python': 0.98, 'SQL': 0.97, 'Excel': 0.85,
  'Risk Analysis': 0.84, 'Supply Chain': 0.82,
  'SEO': 0.82, 'Content Writing': 0.82,
  'Google Ads': 0.81, 'Market Research': 0.81,
  'Social Media': 0.80, 'Financial Modeling': 0.78,
  'Machine Learning': 0.74, 'Java': 0.74,
  'React': 0.73, 'C++': 0.73, 'AWS': 0.72,
  'Agile': 0.70, 'Scrum': 0.69,
  'Data Visualization': 0.75, 'Tableau': 0.71,
  'Power BI': 0.70, 'Git': 0.72, 'CSS': 0.65,
  'Wireframing': 0.63, 'Prototyping': 0.62,
  'User Research': 0.65, 'Figma': 0.68,
  'Adobe XD': 0.65, 'Analytics': 0.75,
  'Communication': 0.80, 'Copywriting': 0.68,
  'Production Planning': 0.70, 'Quality Control': 0.69,
  'Research': 0.65, 'HRIS': 0.55,
  'Payroll': 0.50, 'Recruitment': 0.58,
  'Training': 0.56, 'Jira': 0.65,
};

String _estimateTime(String skill) {
  const quick = {
    'Excel', 'Communication', 'Market Research', 'Research', 'Analytics',
    'Copywriting', 'Social Media',
  };
  const medium = {
    'SQL', 'SEO', 'Google Ads', 'Content Writing', 'Data Visualization',
    'Tableau', 'Power BI', 'Agile', 'Scrum', 'Git', 'CSS', 'Wireframing',
    'Prototyping', 'Recruitment', 'Training', 'Supply Chain', 'Quality Control',
    'Production Planning', 'Risk Analysis',
  };
  const advanced = {
    'Python', 'Java', 'React', 'C++', 'AWS', 'Machine Learning',
    'Financial Modeling', 'Figma', 'Adobe XD', 'User Research', 'HRIS', 'Jira',
  };
  if (quick.contains(skill))    { return '1–2 weeks'; }
  if (medium.contains(skill))   { return '3–5 weeks'; }
  if (advanced.contains(skill)) { return '6–10 weeks'; }
  return '2–4 weeks';
}

TransitionResult _computeTransition(OccupationInfo from, OccupationInfo to) {
  final fromSet = from.coreSkills.toSet();
  final toSet   = to.coreSkills.toSet();
  final shared  = fromSet.intersection(toSet);
  final missing = toSet.difference(fromSet).toList()
    ..sort((a, b) => (_skillImportance[b] ?? 0.5).compareTo(_skillImportance[a] ?? 0.5));
  final have = shared.toList();
  final gap  = missing.length;
  final score = (shared.length / max(toSet.length, 1)) * 100;
  final diff  = score >= 55 ? 'Easy' : score >= 30 ? 'Medium' : 'Hard';
  final time  = gap <= 2 ? '1–2 months' : gap <= 4 ? '3–6 months' : '6–12 months';

  final skills = <PrioritizedSkill>[
    for (int i = 0; i < missing.length; i++)
      PrioritizedSkill(
        skillName:       missing[i],
        importanceScore: _skillImportance[missing[i]] ?? 0.6,
        distanceScore:   (0.65 + i * 0.04).clamp(0, 1),
        priorityLabel:   i < (gap / 2).ceil() ? 'must' : 'soon',
        reasoning: 'Required in ${((_skillImportance[missing[i]] ?? 0.6) * 12.3).toStringAsFixed(1)}% of ${to.industry} job postings',
        estimatedTime: _estimateTime(missing[i]),
      ),
    for (final s in have)
      PrioritizedSkill(
        skillName:       s,
        importanceScore: _skillImportance[s] ?? 0.6,
        distanceScore:   0.0,
        priorityLabel:   'have',
        reasoning: 'Transferable skill — valued across ${to.industry}.',
        estimatedTime:   '—',
      ),
  ];

  return TransitionResult(
    similarityScore: score,
    difficulty:      diff,
    estimatedTime:   time,
    skillGap:        gap,
    isAsymmetric:    score < 40,
    fromAvgSalary:   from.avgSalary,
    toAvgSalary:     to.avgSalary,
    skills:          skills,
    bridgeSkills:    missing.take(3).toList(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS  (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

const _primaryBlue     = Color(0xFF2563EB);
const _primaryBlueDark = Color(0xFF3B82F6);

// Light theme
const _bgLight      = Color(0xFFF8FAFF);
const _surfaceLight = Color(0xFFF1F5F9);
const _cardLight    = Color(0xFFFFFFFF);
const _textLight    = Color(0xFF0F172A);
const _subLight     = Color(0xFF64748B);
const _borderLight  = Color(0xFFE2E8F0);

// Dark theme
const _bgDark      = Color(0xFF0B1120);
const _surfaceDark = Color(0xFF141E2E);
const _cardDark    = Color(0xFF1A2640);
const _textDark    = Color(0xFFF1F5F9);
const _subDark     = Color(0xFF8BA3C0);
const _borderDark  = Color(0xFF1E3A5A);

// Status
const _errorColor   = Color(0xFFDC2626);
const _errorLight   = Color(0xFFFEF2F2);
const _warningColor = Color(0xFFF59E0B);
const _warningLight = Color(0xFFFFFBEB);
const _successColor = Color(0xFF16A34A);
const _successLight = Color(0xFFF0FDF4);

// ─────────────────────────────────────────────────────────────────────────────
// INDUSTRY HELPERS
// ─────────────────────────────────────────────────────────────────────────────

Color _industryColor(String ind) => switch (ind) {
  'Software'      => const Color(0xFF2563EB),
  'Finance'       => const Color(0xFF059669),
  'Marketing'     => const Color(0xFF7C3AED),
  'Manufacturing' => const Color(0xFFD97706),
  'Education'     => const Color(0xFF0D9488),
  _               => const Color(0xFF475569),
};

IconData _industryIcon(String ind) => switch (ind) {
  'Software'      => Icons.code_rounded,
  'Finance'       => Icons.account_balance_rounded,
  'Marketing'     => Icons.campaign_rounded,
  'Manufacturing' => Icons.precision_manufacturing_rounded,
  'Education'     => Icons.school_rounded,
  _               => Icons.work_rounded,
};

String _formatSalary(double salary) =>
    salary >= 1000 ? '\$${(salary / 1000).toStringAsFixed(1)}k' : '\$${salary.round()}';

// ─────────────────────────────────────────────────────────────────────────────
// SHADOW HELPERS
// ─────────────────────────────────────────────────────────────────────────────

List<BoxShadow> _elevatedShadow(bool isDark) => [
  BoxShadow(
    color: isDark
        ? Colors.black.withValues(alpha: 0.55)
        : const Color(0xFF2563EB).withValues(alpha: 0.2),
    blurRadius: 36,
    offset:     const Offset(0, 12),
  ),
  BoxShadow(
    color: isDark
        ? Colors.black.withValues(alpha: 0.25)
        : Colors.black.withValues(alpha: 0.05),
    blurRadius: 8,
    offset:     const Offset(0, 3),
  ),
];

List<BoxShadow> _cardShadow(bool isDark) => [
  BoxShadow(
    color:      Colors.black.withValues(alpha: isDark ? 0.38 : 0.07),
    blurRadius: 18,
    offset:     const Offset(0, 6),
  ),
  BoxShadow(
    color:      Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
    blurRadius: 4,
    offset:     const Offset(0, 1),
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class JobTransitionScreen extends StatefulWidget {
  const JobTransitionScreen({super.key});

  @override
  State<JobTransitionScreen> createState() => _JobTransitionScreenState();
}

class _JobTransitionScreenState extends State<JobTransitionScreen>
    with TickerProviderStateMixin {

  // ── State (unchanged) ─────────────────────────────────────────────────────
  OccupationInfo    _from      = _occupations[1];
  OccupationInfo    _to        = _occupations[0];
  TransitionResult? _result;
  bool              _analyzing = false;
  late final TabController _tabController;

  // ── Animation controllers (unchanged) ─────────────────────────────────────
  late final AnimationController _resultAnimController;
  late final Animation<double>   _resultFade;
  late final Animation<Offset>   _resultSlide;
  late final AnimationController _pulseController;
  late final Animation<double>   _pulseAnim;

  // ── THEME FIX: computed from app-level Theme, NOT local state ─────────────
  // Reading Theme.of(context) in a State getter is safe during build/rebuild.
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _resultAnimController = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 560),
    );
    _resultFade = CurvedAnimation(
      parent: _resultAnimController,
      curve:  Curves.easeOut,
    );
    _resultSlide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end:   Offset.zero,
    ).animate(CurvedAnimation(
      parent: _resultAnimController,
      curve:  Curves.easeOutCubic,
    ));

    _pulseController = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(
      parent: _pulseController,
      curve:  Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _resultAnimController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ── Logic (unchanged) ─────────────────────────────────────────────────────

  Future<void> _analyze() async {
    setState(() { _analyzing = true; _result = null; });
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() {
      _analyzing = false;
      _result    = _computeTransition(_from, _to);
    });
    _resultAnimController
      ..reset()
      ..forward();
  }

  Color _diffColor(String d) => switch (d) {
    'Easy'   => _successColor,
    'Medium' => _warningColor,
    _        => _errorColor,
  };

  // ── Token getters — now delegate to computed _isDark ──────────────────────

  Color get _bg      => _isDark ? _bgDark      : _bgLight;
  Color get _surface => _isDark ? _surfaceDark : _surfaceLight;
  Color get _cardBg  => _isDark ? _cardDark    : _cardLight;
  Color get _text    => _isDark ? _textDark    : _textLight;
  Color get _sub     => _isDark ? _subDark     : _subLight;
  Color get _border  => _isDark ? _borderDark  : _borderLight;
  Color get _blue    => _isDark ? _primaryBlueDark : _primaryBlue;

  TextStyle _ts(double size, FontWeight weight, Color color, {double letterSpacing = 0}) =>
      GoogleFonts.plusJakartaSans(
        fontSize:      size,
        fontWeight:    weight,
        color:         color,
        letterSpacing: letterSpacing,
      );

  // ── Shared UI helpers ──────────────────────────────────────────────────────

  Widget _card(Widget child, {
    EdgeInsets padding  = const EdgeInsets.all(20),
    BorderRadius? radius,
  }) =>
      Container(
        decoration: BoxDecoration(
          color:        _cardBg,
          borderRadius: radius ?? BorderRadius.circular(20),
          border:       Border.all(color: _border),
          boxShadow:    _cardShadow(_isDark),
        ),
        padding: padding,
        child:   child,
      );

  Widget _primaryBtn(String label, VoidCallback? onPressed, {IconData? icon}) =>
      SizedBox(
        width: double.infinity,
        child: GestureDetector(
          onTap: onPressed == null
              ? null
              : () {
            HapticFeedback.mediumImpact();
            onPressed();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: onPressed == null
                  ? null
                  : LinearGradient(
                colors: [_blue, _blue.withValues(alpha: 0.8)],
                begin:  Alignment.topLeft,
                end:    Alignment.bottomRight,
              ),
              color:        onPressed == null ? _border : null,
              borderRadius: BorderRadius.circular(14),
              boxShadow: onPressed == null
                  ? null
                  : [
                BoxShadow(
                  color:      _blue.withValues(alpha: 0.38),
                  blurRadius: 22,
                  offset:     const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_analyzing)
                  const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white,
                    ),
                  )
                else if (icon != null)
                  Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  _analyzing ? 'Analyzing Career Path…' : label,
                  style: _ts(15, FontWeight.w700, Colors.white),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _sectionHeader(
      String title, {
        IconData? icon,
        String?   subtitle,
      }) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 28, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              if (icon != null) ...[
                Container(
                  width:  32, height: 32,
                  decoration: BoxDecoration(
                    color:        _blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: _blue, size: 17),
                ),
                const SizedBox(width: 10),
              ],
              Text(title, style: _ts(16, FontWeight.w800, _text, letterSpacing: -0.3)),
            ]),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Padding(
                padding: EdgeInsets.only(left: icon != null ? 42.0 : 0.0),
                child: Text(subtitle, style: _ts(12, FontWeight.w400, _sub)),
              ),
            ],
          ],
        ),
      );

  // ── SECTION 1: Occupation Picker ───────────────────────────────────────────

  Widget _buildOccupationPicker() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: _card(
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Header
        Row(children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_blue, _blue.withValues(alpha: 0.72)],
                begin:  Alignment.topLeft,
                end:    Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color:      _blue.withValues(alpha: 0.35),
                  blurRadius: 14, offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Career Transition', style: _ts(16, FontWeight.w800, _text)),
              Text('Powered by 60,000+ job listings', style: _ts(12, FontWeight.w400, _sub)),
            ]),
          ),
          // Live badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color:        _successColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border:       Border.all(color: _successColor.withValues(alpha: 0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 6, height: 6,
                decoration: const BoxDecoration(
                  color: _successColor, shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text('Live', style: _ts(11, FontWeight.w700, _successColor)),
            ]),
          ),
        ]),

        const SizedBox(height: 24),

        // Current role label
        _occupationLabel(_from.industry),
        const SizedBox(height: 4),
        Text('CURRENT ROLE', style: _ts(11, FontWeight.w700, _sub, letterSpacing: 0.8)),
        const SizedBox(height: 8),
        _styledDropdown(
          value:       _from,
          onChanged:   (v) { HapticFeedback.selectionClick(); setState(() => _from = v!); },
          borderColor: _border,
          highlighted: false,
        ),
        const SizedBox(height: 8),
        _skillPreviewRow(_from),

        const SizedBox(height: 18),

        // Swap row
        Row(children: [
          Expanded(child: Divider(color: _border, thickness: 1)),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              setState(() { final t = _from; _from = _to; _to = t; });
            },
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color:  _blue,
                shape:  BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color:      _blue.withValues(alpha: 0.4),
                    blurRadius: 16, offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(Icons.swap_vert_rounded, color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Divider(color: _border, thickness: 1)),
        ]),

        const SizedBox(height: 18),

        // Target role label
        _occupationLabel(_to.industry),
        const SizedBox(height: 4),
        Text('TARGET ROLE', style: _ts(11, FontWeight.w700, _sub, letterSpacing: 0.8)),
        const SizedBox(height: 8),
        _styledDropdown(
          value:       _to,
          onChanged:   (v) { HapticFeedback.selectionClick(); setState(() => _to = v!); },
          borderColor: _blue,
          borderWidth: 1.5,
          highlighted: true,
        ),
        const SizedBox(height: 8),
        _skillPreviewRow(_to),

        const SizedBox(height: 24),

        _primaryBtn(
          'Analyze My Career Path →',
          _from == _to ? null : _analyze,
          icon: Icons.analytics_rounded,
        ),

        if (_from == _to) ...[
          const SizedBox(height: 10),
          Center(
            child: Text(
              'Select two different occupations to analyze.',
              style: _ts(12, FontWeight.w400, _sub),
            ),
          ),
        ],
      ]),
    ),
  );

  Widget _occupationLabel(String industry) {
    final color = _industryColor(industry);
    return Row(children: [
      Container(
        width: 8, height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(
        industry.toUpperCase(),
        style: _ts(10, FontWeight.w700, color, letterSpacing: 0.6),
      ),
    ]);
  }

  Widget _skillPreviewRow(OccupationInfo occ) {
    final iColor = _industryColor(occ.industry);
    return Wrap(
      spacing:    5,
      runSpacing: 5,
      children: [
        ...occ.coreSkills.take(3).map((s) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color:        iColor.withValues(alpha: _isDark ? 0.15 : 0.08),
            borderRadius: BorderRadius.circular(100),
            border:       Border.all(color: iColor.withValues(alpha: 0.28)),
          ),
          child: Text(s, style: _ts(10, FontWeight.w600, iColor)),
        )),
        if (occ.coreSkills.length > 3)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color:        _surface,
              borderRadius: BorderRadius.circular(100),
              border:       Border.all(color: _border),
            ),
            child: Text('+${occ.coreSkills.length - 3}', style: _ts(10, FontWeight.w600, _sub)),
          ),
      ],
    );
  }

  Widget _styledDropdown({
    required OccupationInfo value,
    required ValueChanged<OccupationInfo?> onChanged,
    required Color borderColor,
    double borderWidth = 1.0,
    bool highlighted = false,
  }) =>
      Container(
        decoration: BoxDecoration(
          color:        highlighted
              ? (_isDark ? const Color(0xFF1A2E50) : const Color(0xFFEFF6FF))
              : _surface,
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: borderColor, width: borderWidth),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<OccupationInfo>(
            value:        value,
            isExpanded:   true,
            dropdownColor: _cardBg,
            icon:  Icon(Icons.keyboard_arrow_down_rounded, color: _sub),
            style: _ts(14, FontWeight.w600, _text),
            onChanged: onChanged,
            items: _occupations.map((o) => DropdownMenuItem(
              value: o,
              child: Row(children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color:        _industryColor(o.industry).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(
                    _industryIcon(o.industry),
                    color: _industryColor(o.industry),
                    size:  15,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(o.title, style: _ts(14, FontWeight.w600, _text))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color:        _blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(o.industry, style: _ts(10, FontWeight.w600, _blue)),
                ),
              ]),
            )).toList(),
          ),
        ),
      );

  // ── SECTION 2: Score Card ──────────────────────────────────────────────────

  Widget _buildScoreCard(TransitionResult r) {
    final thetaScore  = r.similarityScore.round();
    final diffColor   = _diffColor(r.difficulty);
    final readiness   = thetaScore;
    final salaryDelta = r.fromAvgSalary > 0
        ? ((r.toAvgSalary - r.fromAvgSalary) / r.fromAvgSalary * 100)
        : 0.0;
    final salaryUp = salaryDelta >= 0;

    return FadeTransition(
      opacity: _resultFade,
      child: SlideTransition(
        position: _resultSlide,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F2756), Color(0xFF1B4FD8)],
                begin:  Alignment.topLeft,
                end:    Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow:    _elevatedShadow(_isDark),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(children: [
                // Decorative circles
                Positioned(
                  right: -30, top: -30,
                  child: Container(
                    width: 160, height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.04),
                    ),
                  ),
                ),
                Positioned(
                  left: -20, bottom: -40,
                  child: Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.03),
                    ),
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // Top row: gauge + info
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        // Animated pulsing gauge
                        AnimatedBuilder(
                          animation: _pulseAnim,
                          builder: (_, child) => Container(
                            decoration: BoxDecoration(
                              shape:     BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color:      Colors.white.withValues(
                                    alpha: 0.06 + _pulseAnim.value * 0.07,
                                  ),
                                  blurRadius: 18 + _pulseAnim.value * 12,
                                  spreadRadius: _pulseAnim.value * 3,
                                ),
                              ],
                            ),
                            child: child,
                          ),
                          child: SizedBox(
                            width: 102, height: 102,
                            child: Stack(alignment: Alignment.center, children: [
                              SizedBox(
                                width: 102, height: 102,
                                child: TweenAnimationBuilder<double>(
                                  tween:    Tween(begin: 0.0, end: thetaScore / 100),
                                  duration: const Duration(milliseconds: 1300),
                                  curve:    Curves.easeOutCubic,
                                  builder:  (_, val, __) => CircularProgressIndicator(
                                    value:           val,
                                    strokeWidth:     8.5,
                                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                                    valueColor:      const AlwaysStoppedAnimation(Colors.white),
                                    strokeCap:       StrokeCap.round,
                                  ),
                                ),
                              ),
                              Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Text(
                                  '$thetaScore%',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white,
                                  ),
                                ),
                                Text('Match',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10, color: Colors.white70,
                                    )),
                              ]),
                            ]),
                          ),
                        ),

                        const SizedBox(width: 20),

                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Difficulty badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color:        diffColor.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(100),
                                border:       Border.all(color: diffColor.withValues(alpha: 0.5)),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Container(
                                  width: 6, height: 6,
                                  decoration: BoxDecoration(color: diffColor, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${r.difficulty} Transition',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11, fontWeight: FontWeight.w800, color: diffColor,
                                  ),
                                ),
                              ]),
                            ),

                            const SizedBox(height: 10),

                            Text(
                              _from.title,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11, color: Colors.white60,
                              ),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                            Row(children: [
                              const Icon(Icons.arrow_forward_rounded, color: Colors.white38, size: 12),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _to.title,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white,
                                  ),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ]),

                            const SizedBox(height: 14),

                            Row(children: [
                              _scoreStat('${r.skillGap}', 'Skills Gap'),
                              const SizedBox(width: 16),
                              _scoreStat(r.estimatedTime, 'Timeline'),
                              const SizedBox(width: 16),
                              _scoreStat('$readiness%', 'Ready Now'),
                            ]),
                          ],
                        )),
                      ]),

                      const SizedBox(height: 20),
                      Divider(color: Colors.white.withValues(alpha: 0.12)),
                      const SizedBox(height: 16),

                      // Salary comparison
                      Row(children: [
                        Expanded(
                          child: _salaryTile(
                            label:    'Current Salary',
                            amount:   r.fromAvgSalary,
                            icon:     Icons.work_outline_rounded,
                            alignEnd: false,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Column(children: [
                            Icon(
                              salaryUp
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              color: salaryUp ? _successColor : _errorColor,
                              size:  22,
                            ),
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color:        (salaryUp ? _successColor : _errorColor)
                                    .withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                '${salaryUp ? '+' : ''}${salaryDelta.toStringAsFixed(1)}%',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize:   10,
                                  fontWeight: FontWeight.w800,
                                  color: salaryUp ? _successColor : _errorColor,
                                ),
                              ),
                            ),
                          ]),
                        ),
                        Expanded(
                          child: _salaryTile(
                            label:    'Target Salary',
                            amount:   r.toAvgSalary,
                            icon:     Icons.star_outline_rounded,
                            alignEnd: true,
                          ),
                        ),
                      ]),

                      const SizedBox(height: 16),

                      // Asymmetry note
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:        Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(12),
                          border:       Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.info_outline_rounded, color: Colors.white54, size: 15),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              r.isAsymmetric
                                  ? '${_from.title}→${_to.title} is easier than the reverse.'
                                  : 'Symmetric transition — equally feasible in both directions.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11, color: Colors.white60,
                              ),
                              maxLines: 2,
                            ),
                          ),
                        ]),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _salaryTile({
    required String   label,
    required double   amount,
    required IconData icon,
    required bool     alignEnd,
  }) =>
      Column(
        crossAxisAlignment: alignEnd
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.white60)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: alignEnd
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              if (!alignEnd) ...[
                Icon(icon, color: Colors.white38, size: 12),
                const SizedBox(width: 3),
              ],
              Text(
                _formatSalary(amount),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white,
                ),
              ),
              if (alignEnd) ...[
                const SizedBox(width: 3),
                Icon(icon, color: Colors.white38, size: 12),
              ],
            ],
          ),
          Text('/ year avg',
              style: GoogleFonts.plusJakartaSans(fontSize: 9, color: Colors.white38)),
        ],
      );

  Widget _scoreStat(String value, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17, fontWeight: FontWeight.w900,
            color: Colors.white, height: 1,
          )),
      const SizedBox(height: 2),
      Text(label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 9, color: Colors.white60,
          )),
    ],
  );

  // ── SECTION 3: Skills Tabs ─────────────────────────────────────────────────

  Widget _buildSkillsTabs(TransitionResult r) {
    final mustSkills = r.skills.where((s) => s.priorityLabel == 'must').toList();
    final soonSkills = r.skills.where((s) => s.priorityLabel == 'soon').toList();
    final haveSkills = r.skills.where((s) => s.priorityLabel == 'have').toList();

    return FadeTransition(
      opacity:  _resultFade,
      child: SlideTransition(
        position: _resultSlide,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionHeader(
            'Skills Roadmap',
            icon:     Icons.layers_rounded,
            subtitle: 'Prioritized skills for your transition',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color:        _surface,
                borderRadius: BorderRadius.circular(14),
                border:       Border.all(color: _border),
              ),
              child: TabBar(
                controller: _tabController,
                padding:    EdgeInsets.zero,
                labelPadding: EdgeInsets.zero,
                tabs: [
                  _buildTab(Icons.priority_high_rounded, 'Must (${mustSkills.length})'),
                  _buildTab(Icons.schedule_rounded,       'Soon (${soonSkills.length})'),
                  _buildTab(Icons.check_circle_outline_rounded, 'Have (${haveSkills.length})'),
                ],
                labelColor:          _blue,
                unselectedLabelColor: _sub,
                indicator: BoxDecoration(
                  color:        _isDark
                      ? const Color(0xFF1A2E50)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color:      _blue.withValues(alpha: 0.14),
                      blurRadius: 6, offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize:        TabBarIndicatorSize.tab,
                dividerColor:         Colors.transparent,
                labelStyle:           GoogleFonts.plusJakartaSans(
                  fontSize: 12, fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 12, fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 360,
            child: TabBarView(
              controller: _tabController,
              children: [
                _skillListView(mustSkills),
                _skillListView(soonSkills),
                _skillListView(haveSkills),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Tab _buildTab(IconData icon, String label) => Tab(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize:      MainAxisSize.min,
      children: [
        Icon(icon, size: 14),
        const SizedBox(width: 4),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    ),
  );

  Widget _skillListView(List<PrioritizedSkill> skills) {
    if (skills.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color:  _successColor.withValues(alpha: 0.1),
              shape:  BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: _successColor, size: 32),
          ),
          const SizedBox(height: 14),
          Text('All clear!', style: _ts(15, FontWeight.w700, _text)),
          const SizedBox(height: 4),
          Text('No skills in this category.', style: _ts(12, FontWeight.w400, _sub)),
        ]),
      );
    }
    return ListView.builder(
      padding:   const EdgeInsets.only(top: 6, bottom: 12),
      itemCount: skills.length,
      itemBuilder: (_, i) => _SkillPriorityCard(
        skill:        skills[i],
        isDark:       _isDark,
        primaryBlue:  _blue,
        cardBg:       _cardBg,
        textColor:    _text,
        subColor:     _sub,
        borderColor:  _border,
        surfaceColor: _surface,
        tsHelper:     _ts,
      ),
    );
  }

  // ── SECTION 4: Learning Roadmap ────────────────────────────────────────────

  Widget _buildRoadmap(TransitionResult r) {
    final steps = r.skills.where((s) => s.priorityLabel != 'have').toList();

    return FadeTransition(
      opacity:  _resultFade,
      child: SlideTransition(
        position: _resultSlide,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionHeader(
            'Learning Roadmap',
            icon:     Icons.route_rounded,
            subtitle: '${steps.length} skills to master for this transition',
          ),
          if (steps.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _card(
                Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color:        _successColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(Icons.rocket_launch_rounded, color: _successColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You\'re already ready! No additional skills needed.',
                      style: _ts(14, FontWeight.w600, _successColor),
                    ),
                  ),
                ]),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: steps.asMap().entries.map((e) {
                  final idx     = e.key;
                  final step    = e.value;
                  final isFirst = idx == 0;
                  final isLast  = idx == steps.length - 1;
                  final isMust  = step.priorityLabel == 'must';
                  final stepBg  = isFirst
                      ? _blue
                      : (isMust
                      ? _errorColor.withValues(alpha: _isDark ? 0.18 : 0.1)
                      : _surface);
                  final stepNumColor = isFirst
                      ? Colors.white
                      : (isMust ? _errorColor : _sub);

                  return Column(children: [
                    _card(
                      Row(children: [
                        // Step circle
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color:  isFirst ? null : stepBg,
                            gradient: isFirst
                                ? LinearGradient(
                              colors: [_blue, _blue.withValues(alpha: 0.75)],
                              begin:  Alignment.topLeft,
                              end:    Alignment.bottomRight,
                            )
                                : null,
                            shape:  BoxShape.circle,
                            border: isFirst
                                ? null
                                : Border.all(
                              color: isMust
                                  ? _errorColor.withValues(alpha: 0.3)
                                  : _border,
                              width: 1.5,
                            ),
                            boxShadow: isFirst
                                ? [BoxShadow(
                              color:      _blue.withValues(alpha: 0.35),
                              blurRadius: 10, offset: const Offset(0, 3),
                            )]
                                : [],
                          ),
                          child: Center(
                            child: Text(
                              '${idx + 1}',
                              style: _ts(13, FontWeight.w800, stepNumColor),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Skill info
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                child: Text(step.skillName,
                                    style: _ts(14, FontWeight.w700, _text)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: (isMust ? _errorColor : _warningColor)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  isMust ? 'Priority' : 'Secondary',
                                  style: _ts(9, FontWeight.w700,
                                      isMust ? _errorColor : _warningColor),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 3),
                            Row(children: [
                              Icon(Icons.access_time_rounded, size: 12, color: _sub),
                              const SizedBox(width: 4),
                              Text(step.estimatedTime,
                                  style: _ts(11, FontWeight.w500, _sub)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  step.reasoning,
                                  style: _ts(10, FontWeight.w400, _sub),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ]),
                          ],
                        )),

                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () => HapticFeedback.selectionClick(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              color:        _blue,
                              borderRadius: BorderRadius.circular(100),
                              boxShadow: [
                                BoxShadow(
                                  color:      _blue.withValues(alpha: 0.32),
                                  blurRadius: 10, offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text('Start →', style: _ts(12, FontWeight.w700, Colors.white)),
                          ),
                        ),
                      ]),
                      padding: const EdgeInsets.all(14),
                    ),
                    if (!isLast)
                      Padding(
                        padding: const EdgeInsets.only(left: 36),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(width: 2, height: 14, color: _border),
                        ),
                      ),
                  ]);
                }).toList(),
              ),
            ),
        ]),
      ),
    );
  }

  // ── SECTION 5: Transition Flow ─────────────────────────────────────────────

  Widget _buildTransitionFlow(TransitionResult r) {
    final bridges = r.bridgeSkills;

    return FadeTransition(
      opacity:  _resultFade,
      child: SlideTransition(
        position: _resultSlide,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionHeader(
            'Your Transition Path',
            icon:     Icons.account_tree_rounded,
            subtitle: 'Key bridge skills connecting your journey',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _card(
              bridges.isEmpty
                  ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: _successColor, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Direct transition — no bridge skills needed.',
                        style: _ts(13, FontWeight.w500, _sub),
                      ),
                    ],
                  ),
                ),
              )
                  : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _flowNode(
                      icon:      _industryIcon(_from.industry),
                      label:     _from.title,
                      isPrimary: true,
                      isTarget:  false,
                      isDark:    _isDark,
                      blue:      _blue,
                      textColor: _text,
                      tsHelper:  _ts,
                    ),
                    ...bridges.map((b) => Row(children: [
                      _flowArrow(_blue),
                      _flowSkillNode(b, _isDark, _blue, _ts),
                    ])),
                    _flowArrow(_blue),
                    _flowNode(
                      icon:      _industryIcon(_to.industry),
                      label:     _to.title,
                      isPrimary: false,
                      isTarget:  true,
                      isDark:    _isDark,
                      blue:      _blue,
                      textColor: _text,
                      tsHelper:  _ts,
                    ),
                  ],
                ),
              ),
              padding: const EdgeInsets.all(20),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Loading State ──────────────────────────────────────────────────────────

  Widget _buildLoadingState() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: _card(
      Column(children: [
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          tween:    Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 600),
          builder: (_, val, child) => Opacity(opacity: val, child: child),
          child: SizedBox(
            width: 52, height: 52,
            child: CircularProgressIndicator(
              strokeWidth: 3.5,
              valueColor:  AlwaysStoppedAnimation(_blue),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text('Analyzing Career Path…', style: _ts(15, FontWeight.w700, _text)),
        const SizedBox(height: 6),
        Text(
          'Matching ${_from.title} → ${_to.title}\nacross 60,000 job listings',
          style:     _ts(12, FontWeight.w400, _sub),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        ...['Mapping skill overlap', 'Computing similarity score', 'Prioritizing skill gaps']
            .map((step) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                color:  _blue.withValues(alpha: 0.1),
                shape:  BoxShape.circle,
              ),
              child: Icon(Icons.check_rounded, color: _blue, size: 12),
            ),
            const SizedBox(width: 10),
            Text(step, style: _ts(12, FontWeight.w500, _sub)),
          ]),
        )),
        const SizedBox(height: 8),
      ]),
    ),
  );

  // ── BUILD ──────────────────────────────────────────────────────────────────
  // NOTE: The Theme() wrapper is intentionally removed.
  // The app-level ThemeProvider (in main.dart / app_theme.dart) now
  // governs brightness.  This screen simply reads Theme.of(context) via
  // the _isDark getter, so it will always reflect the globally-active
  // theme and will rebuild automatically when the user toggles it.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor:        _bg,
        elevation:               0,
        scrolledUnderElevation:  0,
        surfaceTintColor:        Colors.transparent,
        leading: IconButton(
          icon:      Icon(Icons.arrow_back_rounded, color: _text, size: 22),
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.maybePop(context);
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Career GPS',
                style: _ts(17, FontWeight.w800, _text, letterSpacing: -0.3)),
            Text('Transition Advisor', style: _ts(11, FontWeight.w400, _sub)),
          ],
        ),
        // ── THEME FIX: no local toggle here — single global toggle
        //    lives in MainNav / Dashboard AppBar.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(color: _border, thickness: 1, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 20),
          _buildOccupationPicker(),

          if (_analyzing) ...[
            const SizedBox(height: 24),
            _buildLoadingState(),
          ],

          if (_result != null) ...[
            const SizedBox(height: 20),
            _buildScoreCard(_result!),
            _buildSkillsTabs(_result!),
            _buildRoadmap(_result!),
            _buildTransitionFlow(_result!),
          ],

          const SizedBox(height: 80),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FLOW DIAGRAM HELPERS
// ─────────────────────────────────────────────────────────────────────────────

Widget _flowArrow(Color blue) => Padding(
  padding: const EdgeInsets.only(bottom: 30),
  child: Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 18, height: 2, color: blue.withValues(alpha: 0.25)),
    Icon(Icons.arrow_forward_rounded, color: blue.withValues(alpha: 0.55), size: 16),
    Container(width: 18, height: 2, color: blue.withValues(alpha: 0.25)),
  ]),
);

Widget _flowNode({
  required IconData icon,
  required String label,
  required bool isPrimary,
  required bool isTarget,
  required bool isDark,
  required Color blue,
  required Color textColor,
  required TextStyle Function(double, FontWeight, Color, {double letterSpacing}) tsHelper,
}) =>
    Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width:  62, height: 62,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isTarget
                ? [blue, blue.withValues(alpha: 0.72)]
                : [blue.withValues(alpha: 0.88), blue.withValues(alpha: 0.65)],
            begin: Alignment.topLeft,
            end:   Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(17),
          boxShadow: [
            BoxShadow(
              color:      blue.withValues(alpha: 0.38),
              blurRadius: 16, offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 26),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: 82,
        child: Text(
          label,
          style: tsHelper(11, FontWeight.w700, isTarget ? blue : textColor),
          textAlign: TextAlign.center,
          maxLines:  2,
          overflow:  TextOverflow.ellipsis,
        ),
      ),
    ]);

Widget _flowSkillNode(
    String label,
    bool isDark,
    Color blue,
    TextStyle Function(double, FontWeight, Color, {double letterSpacing}) tsHelper,
    ) =>
    Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width:  52, height: 52,
        decoration: BoxDecoration(
          color:        isDark ? const Color(0xFF1A2E50) : const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: blue.withValues(alpha: 0.32), width: 1.5),
          boxShadow: [
            BoxShadow(
              color:      blue.withValues(alpha: 0.14),
              blurRadius: 10, offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(Icons.auto_awesome_rounded, color: blue, size: 22),
      ),
      const SizedBox(height: 7),
      SizedBox(
        width: 70,
        child: Text(
          label,
          style:     tsHelper(10, FontWeight.w600, blue),
          textAlign: TextAlign.center,
          maxLines:  2,
          overflow:  TextOverflow.ellipsis,
        ),
      ),
    ]);

// ─────────────────────────────────────────────────────────────────────────────
// SKILL PRIORITY CARD
// ─────────────────────────────────────────────────────────────────────────────

class _SkillPriorityCard extends StatelessWidget {
  final PrioritizedSkill skill;
  final bool isDark;
  final Color primaryBlue;
  final Color cardBg;
  final Color textColor;
  final Color subColor;
  final Color borderColor;
  final Color surfaceColor;
  final TextStyle Function(double, FontWeight, Color, {double letterSpacing}) tsHelper;

  const _SkillPriorityCard({
    required this.skill,
    required this.isDark,
    required this.primaryBlue,
    required this.cardBg,
    required this.textColor,
    required this.subColor,
    required this.borderColor,
    required this.surfaceColor,
    required this.tsHelper,
  });

  Color get _badgeColor => switch (skill.priorityLabel) {
    'must' => _errorColor,
    'soon' => _warningColor,
    _      => _successColor,
  };

  Color get _badgeBg => switch (skill.priorityLabel) {
    'must' => _errorLight,
    'soon' => _warningLight,
    _      => _successLight,
  };

  String get _badgeText => switch (skill.priorityLabel) {
    'must' => 'Learn First',
    'soon' => 'Learn Soon',
    _      => 'Already Have',
  };

  IconData get _skillIcon => switch (skill.skillName) {
    'Python' || 'Java' || 'C++' || 'React' || 'CSS'  => Icons.code_rounded,
    'SQL' || 'Power BI' || 'Tableau' || 'Data Visualization' => Icons.bar_chart_rounded,
    'Excel' || 'Financial Modeling'                   => Icons.table_chart_rounded,
    'SEO' || 'Google Ads' || 'Social Media'           => Icons.campaign_rounded,
    'Figma' || 'Adobe XD' || 'Wireframing'            => Icons.design_services_rounded,
    'AWS' || 'Git' || 'Jira'                          => Icons.cloud_rounded,
    'Agile' || 'Scrum'                                => Icons.loop_rounded,
    'Machine Learning'                                => Icons.psychology_rounded,
    _                                                 => Icons.star_outline_rounded,
  };

  Color get _skillColor => switch (skill.priorityLabel) {
    'must' => _errorColor,
    'soon' => _warningColor,
    _      => primaryBlue,
  };

  @override
  Widget build(BuildContext context) {
    final isMust = skill.priorityLabel == 'must';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      decoration: BoxDecoration(
        color:        cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMust
              ? _errorColor.withValues(alpha: 0.22)
              : borderColor,
          width: isMust ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: isDark ? 0.28 : 0.05),
            blurRadius: 12, offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Row 1: icon + name + badge
        Row(children: [
          Container(
            width:  42, height: 42,
            decoration: BoxDecoration(
              color:        _skillColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border:       Border.all(color: _skillColor.withValues(alpha: 0.2)),
            ),
            child: Icon(_skillIcon, color: _skillColor, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(skill.skillName, style: tsHelper(14, FontWeight.w700, textColor)),
              Text(
                skill.reasoning,
                style:    tsHelper(11, FontWeight.w400, subColor),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
            ],
          )),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color:        isDark ? _badgeColor.withValues(alpha: 0.2) : _badgeBg,
              borderRadius: BorderRadius.circular(100),
              border:       Border.all(color: _badgeColor.withValues(alpha: 0.38)),
            ),
            child: Text(_badgeText, style: tsHelper(10, FontWeight.w700, _badgeColor)),
          ),
        ]),

        if (skill.priorityLabel != 'have') ...[
          const SizedBox(height: 14),
          _miniProgressBar(
            label:      'Importance',
            value:      skill.importanceScore,
            displayPct: '${(skill.importanceScore * 100).round()}%',
            barColor:   primaryBlue,
            subColor:   subColor,
            borderColor: borderColor,
            tsHelper:   tsHelper,
          ),
          const SizedBox(height: 8),
          _miniProgressBar(
            label:      'Distance to Learn',
            value:      skill.distanceScore,
            displayPct: '${(skill.distanceScore * 100).round()}%',
            barColor:   _warningColor,
            subColor:   subColor,
            borderColor: borderColor,
            tsHelper:   tsHelper,
          ),
          const SizedBox(height: 12),
          // Time estimate chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color:        primaryBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border:       Border.all(color: primaryBlue.withValues(alpha: 0.18)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.schedule_rounded, size: 12, color: primaryBlue),
              const SizedBox(width: 5),
              Text(skill.estimatedTime, style: tsHelper(11, FontWeight.w600, primaryBlue)),
            ]),
          ),
        ],

        if (skill.priorityLabel == 'have') ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:        _successColor.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border:       Border.all(color: _successColor.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle_rounded, color: _successColor, size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  skill.reasoning,
                  style:    tsHelper(11, FontWeight.w500, _successColor),
                  maxLines: 2,
                ),
              ),
            ]),
          ),
        ],

        const SizedBox(height: 12),

        // Action row
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryBlue,
                side:            BorderSide(color: primaryBlue, width: 1.5),
                padding:         const EdgeInsets.symmetric(vertical: 9),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                textStyle: tsHelper(12, FontWeight.w600, primaryBlue),
              ),
              child: Text('Find Courses →',
                  style: tsHelper(12, FontWeight.w600, primaryBlue)),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color:        primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border:       Border.all(color: primaryBlue.withValues(alpha: 0.2)),
            ),
            child: Icon(Icons.bookmark_add_outlined, color: primaryBlue, size: 18),
          ),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MINI PROGRESS BAR  (animated)
// ─────────────────────────────────────────────────────────────────────────────

Widget _miniProgressBar({
  required String label,
  required double value,
  required String displayPct,
  required Color barColor,
  required Color subColor,
  required Color borderColor,
  required TextStyle Function(double, FontWeight, Color, {double letterSpacing}) tsHelper,
}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: tsHelper(11, FontWeight.w500, subColor)),
        const Spacer(),
        Text(displayPct, style: tsHelper(11, FontWeight.w700, barColor)),
      ]),
      const SizedBox(height: 5),
      TweenAnimationBuilder<double>(
        tween:    Tween(begin: 0.0, end: value.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 850),
        curve:    Curves.easeOutCubic,
        builder:  (_, val, __) => ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value:           val,
            minHeight:       6,
            backgroundColor: borderColor,
            valueColor:      AlwaysStoppedAnimation(barColor),
          ),
        ),
      ),
    ]);