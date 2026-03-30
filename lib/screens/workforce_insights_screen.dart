// lib/screens/workforce_insights_screen.dart
// UI UPGRADE v2.0 — "Workforce Intelligence Dashboard"
// ── ALL LOGIC, DATA, MODELS AND STATE UNCHANGED ─────────────────────────────

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Models (unchanged) ───────────────────────────────────────────────────────

class _Generation {
  final String name;
  final String yearRange;
  final String emoji;
  final Color color;
  final List<String> traits;
  final List<String> topSkills;
  final List<String> bestRoles;
  final List<String> industries;
  final String bridgeSkill;
  const _Generation({
    required this.name,
    required this.yearRange,
    required this.emoji,
    required this.color,
    required this.traits,
    required this.topSkills,
    required this.bestRoles,
    this.industries  = const [],
    this.bridgeSkill = '',
  });
}

class _AIAlert {
  final String emoji;
  final String industry;
  final String headline;
  final List<String> upskillIn;
  final Color color;
  final bool urgent;
  final String badge;
  const _AIAlert({
    required this.emoji,
    required this.industry,
    required this.headline,
    required this.upskillIn,
    required this.color,
    required this.urgent,
    required this.badge,
  });
}

// ─── Mock Data (unchanged) ────────────────────────────────────────────────────

const List<_Generation> _generations = [
  _Generation(
    name: 'Gen Z', yearRange: '1995–2009', emoji: '🚀',
    color: Color(0xFF6366F1),
    traits: ['Digital native', 'Entrepreneurial', 'Value work-life balance'],
    topSkills: ['Social Media', 'AI Tools', 'UX Design', 'Python', 'Content'],
    bestRoles: ['UX Designer', 'Social Media Mgr', 'Data Analyst'],
    industries: ['Tech', 'Creative', 'Startups'],
    bridgeSkill: 'AI Tools',
  ),
  _Generation(
    name: 'Millennials', yearRange: '1980–1994', emoji: '💡',
    color: Color(0xFF2563EB),
    traits: ['Tech-savvy', 'Purpose-driven', 'Collaborative'],
    topSkills: ['Project Mgmt', 'Digital Marketing', 'SQL', 'Leadership', 'Cloud'],
    bestRoles: ['Product Manager', 'Marketing Lead', 'Data Scientist'],
    industries: ['Finance', 'Tech', 'Consulting'],
    bridgeSkill: 'Python',
  ),
  _Generation(
    name: 'Gen X', yearRange: '1965–1979', emoji: '⚡',
    color: Color(0xFF0D9488),
    traits: ['Independent', 'Adaptable', 'Results-oriented'],
    topSkills: ['Strategic Planning', 'Finance', 'Operations', 'Mentoring'],
    bestRoles: ['Operations Manager', 'Senior Analyst', 'HR Director'],
    industries: ['Manufacturing', 'Finance', 'Healthcare'],
    bridgeSkill: 'Data Analysis',
  ),
  _Generation(
    name: 'Baby Boomers', yearRange: '1946–1964', emoji: '🌟',
    color: Color(0xFFF59E0B),
    traits: ['Strong work ethic', 'Institutional knowledge', 'Face-to-face comm'],
    topSkills: ['Executive Leadership', 'Compliance', 'Finance', 'Consulting'],
    bestRoles: ['C-Suite', 'Board Advisor', 'Senior Consultant'],
    industries: ['Government', 'Finance', 'Healthcare'],
    bridgeSkill: 'Strategic Planning',
  ),
];

const Map<String, List<double>> _aiTimeline = {
  'Software':      [30, 42, 55, 65, 78, 88, 96, 100],
  'Finance':       [18, 25, 35, 45, 55, 65, 72,  75],
  'Manufacturing': [12, 18, 25, 35, 48, 58, 68,  75],
  'Healthcare':    [ 8, 12, 18, 25, 33, 42, 52,  58],
  'Marketing':     [15, 22, 30, 38, 45, 52, 58,  65],
  'Retail':        [ 5,  8, 14, 22, 30, 38, 46,  52],
};

const List<Color> _lineColors = [
  Color(0xFF2563EB), Color(0xFF10B981), Color(0xFF8B5CF6),
  Color(0xFFEF4444), Color(0xFFF59E0B), Color(0xFF06B6D4),
];

const List<String> _xLabels = [
  '2018','2019','2020','2021','2022','2023','2024','2025',
];

const List<_AIAlert> _aiAlerts = [
  _AIAlert(
    emoji: '⚠️', industry: 'Retail',
    headline: '+407% AI skill demand since 2020. Traditional retail roles at risk.',
    upskillIn: ['Python', 'Data Analysis', 'Inventory AI', 'Customer Analytics'],
    color: Color(0xFFEF4444), urgent: true, badge: 'High Risk',
  ),
  _AIAlert(
    emoji: '✅', industry: 'Healthcare',
    headline: 'Steady AI growth. High demand for human + AI hybrid skills.',
    upskillIn: ['Medical AI', 'Health Data', 'NLP', 'Clinical Analytics'],
    color: Color(0xFF10B981), urgent: false, badge: 'Opportunity',
  ),
  _AIAlert(
    emoji: '🔄', industry: 'Finance',
    headline: '+210% in algorithmic/AI roles. Risk analysts evolving fast.',
    upskillIn: ['Financial ML', 'Risk AI', 'Python', 'RegTech'],
    color: Color(0xFFF59E0B), urgent: true, badge: 'Evolving',
  ),
];

const List<String> _collabTips = [
  'Reverse mentoring: Share digital skills with senior colleagues to build visibility across generations.',
  'Adapt communication: Gen Z prefers async messaging; Boomers value direct conversation — flex your style.',
  'Find shared values: All generations want meaningful work. Lead with impact, not just process.',
];

// ─── Workforce stats (new) ────────────────────────────────────────────────────

const _workforcePct = <String, double>{
  'Gen Z':        24.0,
  'Millennials':  35.0,
  'Gen X':        28.0,
  'Baby Boomers': 13.0,
};

const _salaryRanges = <String, (double, double)>{
  'Gen Z':        (45000, 72000),
  'Millennials':  (68000, 110000),
  'Gen X':        (75000, 130000),
  'Baby Boomers': (85000, 150000),
};

// ─── Design Tokens ────────────────────────────────────────────────────────────

const _primaryBlue  = Color(0xFF2563EB);
const _blue50       = Color(0xFFEFF6FF);
const _success      = Color(0xFF10B981);
const _error        = Color(0xFFEF4444);
const _errorBg      = Color(0xFFFEF2F2);
const _warning      = Color(0xFFF59E0B);
const _warningBg    = Color(0xFFFFFBEB);

const _bgLight      = Color(0xFFF8FAFF);
const _cardLight    = Color(0xFFFFFFFF);
const _surfaceLight = Color(0xFFF1F5F9);
const _textLight    = Color(0xFF0F172A);
const _subLight     = Color(0xFF64748B);
const _borderLight  = Color(0xFFE2E8F0);

const _bgDark       = Color(0xFF0B1120);
const _cardDark     = Color(0xFF141E2E);
const _surfaceDark  = Color(0xFF1A2640);
const _textDark     = Color(0xFFF1F5F9);
const _subDark      = Color(0xFF8BA3C0);
const _borderDark   = Color(0xFF1E3A5A);

// ─── Custom Painters ──────────────────────────────────────────────────────────

/// Arc painter for circular workforce share gauge
class _ArcGaugePainter extends CustomPainter {
  final double progress;
  final Color  fgColor;
  final Color  trackColor;
  final double strokeWidth;

  const _ArcGaugePainter({
    required this.progress,
    required this.fgColor,
    required this.trackColor,
    this.strokeWidth = 6.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c      = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - strokeWidth / 2;

    final track = Paint()
      ..color      = trackColor
      ..strokeWidth = strokeWidth
      ..style      = PaintingStyle.stroke
      ..strokeCap  = StrokeCap.round;
    canvas.drawCircle(c, radius, track);

    if (progress > 0) {
      final fg = Paint()
        ..color      = fgColor
        ..strokeWidth = strokeWidth
        ..style      = PaintingStyle.stroke
        ..strokeCap  = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        fg,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcGaugePainter old) =>
      old.progress != progress ||
          old.fgColor  != fgColor  ||
          old.trackColor != trackColor;
}

/// Risk thermometer painter for alert cards
class _RiskBarPainter extends CustomPainter {
  final double level;   // 0.0 – 1.0
  final Color  color;
  final Color  track;

  const _RiskBarPainter({
    required this.level,
    required this.color,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const rr = Radius.circular(4);
    final trackR = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height), rr,
    );
    canvas.drawRRect(trackR, Paint()..color = track);

    if (level > 0) {
      final fgR = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width * level.clamp(0.0, 1.0), size.height), rr,
      );
      canvas.drawRRect(fgR, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_RiskBarPainter old) =>
      old.level != level || old.color != color || old.track != track;
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class WorkforceInsightsScreen extends StatefulWidget {
  const WorkforceInsightsScreen({super.key});
  @override
  State<WorkforceInsightsScreen> createState() => _WorkforceInsightsScreenState();
}

class _WorkforceInsightsScreenState extends State<WorkforceInsightsScreen>
    with TickerProviderStateMixin {
  // Unchanged state
  final int _userGenIndex = 1; // Millennials
  bool      _isDark       = false;

  // New UI state
  bool   _showScrollTop    = false;
  int    _activeGenIndex   = 1;
  int    _activeTab        = 0;   // 0 = Generational, 1 = AI Disruption
  late final ScrollController      _scrollCtrl;
  late final AnimationController   _pulseCtrl;
  late final AnimationController   _staggerCtrl;
  late final Animation<double>     _pulseAnim;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController()..addListener(_onScroll);
    _pulseCtrl  = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
    _staggerCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  void _onScroll() {
    final show = _scrollCtrl.offset > 420;
    if (show != _showScrollTop) setState(() => _showScrollTop = show);
  }

  @override
  void dispose() {
    _scrollCtrl
      ..removeListener(_onScroll)
      ..dispose();
    _pulseCtrl.dispose();
    _staggerCtrl.dispose();
    super.dispose();
  }

  // ── Theme tokens ───────────────────────────────────────────────────────────

  Color get _bg       => _isDark ? _bgDark      : _bgLight;
  Color get _card     => _isDark ? _cardDark    : _cardLight;
  Color get _surface  => _isDark ? _surfaceDark : _surfaceLight;
  Color get _text     => _isDark ? _textDark    : _textLight;
  Color get _sub      => _isDark ? _subDark     : _subLight;
  Color get _border   => _isDark ? _borderDark  : _borderLight;
  Color get _lightBlue => _isDark ? const Color(0xFF1A2E50) : _blue50;

  // ── Typography helper ──────────────────────────────────────────────────────

  TextStyle _ts(double sz, FontWeight fw, Color c, {double ls = 0}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: sz, fontWeight: fw, color: c, letterSpacing: ls,
      );

  // ── Shared widgets ─────────────────────────────────────────────────────────

  Widget _card_(Widget child, {EdgeInsets? padding, BorderRadius? radius}) =>
      Container(
        decoration: BoxDecoration(
          color:        _card,
          borderRadius: radius ?? BorderRadius.circular(20),
          border:       Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: _isDark
                  ? Colors.black.withValues(alpha: 0.42)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius:   20,
              spreadRadius: 0,
              offset:       const Offset(0, 6),
            ),
            BoxShadow(
              color:      Colors.black.withValues(alpha: _isDark ? 0.18 : 0.03),
              blurRadius: 4,
              offset:     const Offset(0, 1),
            ),
          ],
        ),
        padding: padding ?? const EdgeInsets.all(20),
        child:   child,
      );

  Widget _iconBox(IconData icon, Color bg, Color fg, {double size = 36}) =>
      Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color:        bg,
          borderRadius: BorderRadius.circular(size * 0.28),
        ),
        child: Icon(icon, color: fg, size: size * 0.54),
      );

  Widget _sectionHeader(
      String title, {
        String?   subtitle,
        IconData? icon,
        Color?    iconBg,
        Color?    iconFg,
      }) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
        child: Row(children: [
          if (icon != null) ...[
            _iconBox(
              icon,
              iconBg ?? _lightBlue,
              iconFg ?? _primaryBlue,
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: _ts(16, FontWeight.w800, _text, ls: -0.3)),
                if (subtitle != null)
                  Text(subtitle, style: _ts(12, FontWeight.w400, _sub)),
              ],
            ),
          ),
        ]),
      );

  Widget _skillTag(String skill, {bool urgent = false, Color? customColor}) {
    final fg = customColor ?? (urgent ? _error : _primaryBlue);
    final bg = customColor?.withValues(alpha: _isDark ? 0.18 : 0.1) ??
        (urgent ? _errorBg : _lightBlue);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(100),
        border:       Border.all(color: fg.withValues(alpha: 0.28)),
      ),
      child: Text(skill, style: _ts(11, FontWeight.w600, fg)),
    );
  }

  Widget _outlineBtn(String label, VoidCallback onTap, {IconData? icon}) =>
      GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border:       Border.all(color: _primaryBlue.withValues(alpha: 0.5), width: 1.5),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: _primaryBlue),
              const SizedBox(width: 6),
            ],
            Text(label, style: _ts(13, FontWeight.w700, _primaryBlue)),
          ]),
        ),
      );

  Widget _buildDarkToggle() => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _isDark = !_isDark);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve:    Curves.easeOut,
        width: 50, height: 28,
        decoration: BoxDecoration(
          color:        _isDark ? _primaryBlue : _border,
          borderRadius: BorderRadius.circular(100),
          boxShadow: _isDark
              ? [BoxShadow(
            color:      _primaryBlue.withValues(alpha: 0.38),
            blurRadius: 10, offset: const Offset(0, 2),
          )]
              : [],
        ),
        child: AnimatedAlign(
          duration:  const Duration(milliseconds: 280),
          curve:     Curves.easeOut,
          alignment: _isDark ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(3),
            width: 22, height: 22,
            decoration: BoxDecoration(
              color:     Colors.white,
              shape:     BoxShape.circle,
              boxShadow: [BoxShadow(
                color:      Colors.black.withValues(alpha: 0.2),
                blurRadius: 4, offset: const Offset(0, 1),
              )],
            ),
            child: Icon(
              _isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              size: 13,
              color: _isDark ? _primaryBlue : _warning,
            ),
          ),
        ),
      ),
    ),
  );

  // ── Section tab switcher (NEW) ─────────────────────────────────────────────

  Widget _buildTabSwitcher() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color:        _surface,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: _border),
      ),
      child: Row(
        children: [
          _tabItem(0, 'Generational',   Icons.people_alt_rounded),
          _tabItem(1, 'AI Disruption',  Icons.smart_toy_rounded),
        ],
      ),
    ),
  );

  Widget _tabItem(int idx, String label, IconData icon) {
    final isActive = _activeTab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _activeTab = idx);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color:        isActive ? _card : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive
                ? [BoxShadow(
              color:      _primaryBlue.withValues(alpha: 0.12),
              blurRadius: 8, offset: const Offset(0, 2),
            )]
                : [],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 14,
                color: isActive ? _primaryBlue : _sub),
            const SizedBox(width: 6),
            Text(label,
                style: _ts(12, isActive ? FontWeight.w700 : FontWeight.w500,
                    isActive ? _primaryBlue : _sub)),
          ]),
        ),
      ),
    );
  }

  // ── Workforce Stats Banner (NEW) ───────────────────────────────────────────

  Widget _buildStatsBanner() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
    child: _card_(
      Row(children: [
        _statCell('4', 'Generations\nAt Work', Icons.groups_rounded, _primaryBlue),
        _vDivider(),
        _statCell('60k+', 'Job Listings\nAnalyzed', Icons.analytics_rounded, _success),
        _vDivider(),
        _statCell('35%', 'Workforce is\nMillennial', Icons.bar_chart_rounded, _warning),
      ]),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  )
      .animate()
      .fadeIn(duration: 380.ms)
      .slideY(begin: -0.08, end: 0, curve: Curves.easeOut);

  Widget _statCell(String value, String label, IconData icon, Color color) =>
      Expanded(
        child: Column(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color:        color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(height: 6),
          Text(value,
              style: _ts(18, FontWeight.w900, color, ls: -0.5)),
          Text(label,
              style: _ts(9, FontWeight.w500, _sub),
              textAlign: TextAlign.center),
        ]),
      );

  Widget _vDivider() => Container(
    width: 1, height: 52,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    color: _border,
  );

  // ── SECTION 1: Generation Cards ────────────────────────────────────────────

  Widget _buildGenerationCards() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionHeader(
        'Generational Workforce',
        subtitle: 'Tap a card for deep insights',
        icon:     Icons.people_alt_rounded,
      ),
      SizedBox(
        height: 220,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding:         const EdgeInsets.symmetric(horizontal: 16),
          itemCount:       _generations.length,
          itemBuilder: (_, i) {
            final g      = _generations[i];
            final isUser = i == _userGenIndex;
            final isActive = i == _activeGenIndex;
            final pct    = _workforcePct[g.name] ?? 25.0;

            final List<List<Color>> gradPairs = [
              [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
              [const Color(0xFF1D4ED8), const Color(0xFF3B82F6)],
              [const Color(0xFF0D9488), const Color(0xFF10B981)],
              [const Color(0xFFD97706), const Color(0xFFF59E0B)],
            ];
            final gColors = gradPairs[i.clamp(0, 3)];

            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _activeGenIndex = i);
                _showGenDetailSheet(g, gColors);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width:  isActive ? 215 : 205,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color:        _card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive ? g.color : _border,
                    width: isActive ? 2.0 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isActive
                          ? g.color.withValues(alpha: 0.22)
                          : Colors.black.withValues(alpha: _isDark ? 0.28 : 0.07),
                      blurRadius: isActive ? 18 : 12,
                      offset:     const Offset(0, 5),
                    ),
                  ],
                ),
                clipBehavior: Clip.hardEdge,
                child: Column(children: [
                  // Gradient header
                  Container(
                    height: 75, width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gColors,
                        begin: Alignment.topLeft,
                        end:   Alignment.bottomRight,
                      ),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(g.emoji, style: const TextStyle(fontSize: 26)),
                      const Spacer(),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        if (isUser)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color:        Colors.white.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(100),
                              border:       Border.all(
                                  color: Colors.white.withValues(alpha: 0.5)),
                            ),
                            child: Text('You', style: _ts(10, FontWeight.w800, Colors.white)),
                          ),
                        const SizedBox(height: 4),
                        Text('${pct.round()}% workforce',
                            style: _ts(10, FontWeight.w600,
                                Colors.white.withValues(alpha: 0.82))),
                      ]),
                    ]),
                  ),

                  // Content + mini gauge
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(g.name, style: _ts(14, FontWeight.w800, _text)),
                                Text(g.yearRange, style: _ts(11, FontWeight.w400, _sub)),
                              ],
                            )),
                            // Mini arc gauge for workforce %
                            SizedBox(
                              width: 38, height: 38,
                              child: Stack(alignment: Alignment.center, children: [
                                TweenAnimationBuilder<double>(
                                  tween:    Tween(begin: 0, end: pct / 100),
                                  duration: const Duration(milliseconds: 1000),
                                  curve:    Curves.easeOutCubic,
                                  builder: (_, val, __) => CustomPaint(
                                    size: const Size(38, 38),
                                    painter: _ArcGaugePainter(
                                      progress:    val,
                                      fgColor:     g.color,
                                      trackColor:  _isDark
                                          ? Colors.white.withValues(alpha: 0.07)
                                          : Colors.black.withValues(alpha: 0.07),
                                      strokeWidth: 4.0,
                                    ),
                                  ),
                                ),
                                Text('${pct.round()}',
                                    style: _ts(9, FontWeight.w800, g.color)),
                              ]),
                            ),
                          ]),
                          const SizedBox(height: 8),
                          Text('TOP SKILLS', style: _ts(9, FontWeight.w700, _sub, ls: 0.7)),
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 4, runSpacing: 4,
                            children: g.topSkills.take(2).map((s) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color:        g.color.withValues(
                                    alpha: _isDark ? 0.18 : 0.09),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(s,
                                  style: _ts(9, FontWeight.w700, g.color)),
                            )).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ]),
              )
                  .animate()
                  .fadeIn(delay: Duration(milliseconds: i * 70), duration: 350.ms)
                  .slideX(begin: 0.08, end: 0, curve: Curves.easeOut),
            );
          },
        ),
      ),
      // Scroll dots indicator
      const SizedBox(height: 10),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_generations.length, (i) {
          final isActive = i == _activeGenIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width:  isActive ? 18 : 6,
            height: 6,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color:        isActive
                  ? _generations[i].color
                  : _border,
              borderRadius: BorderRadius.circular(100),
            ),
          );
        }),
      ),
    ],
  );

  // ── Gen Detail Bottom Sheet (NEW) ──────────────────────────────────────────

  void _showGenDetailSheet(_Generation g, List<Color> gColors) {
    final salaryRange = _salaryRanges[g.name];
    showModalBottomSheet<void>(
      context:       context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _GenDetailSheet(
        gen:        g,
        gColors:    gColors,
        salaryRange: salaryRange,
        isDark:     _isDark,
        ts:         _ts,
        card:       _card,
        surface:    _surface,
        text:       _text,
        sub:        _sub,
        border:     _border,
        lightBlue:  _lightBlue,
      ),
    );
  }

  // ── SECTION 2: Your Generation Card ───────────────────────────────────────

  Widget _buildYourGenCard(_Generation gen) {
    final salaryRange = _salaryRanges[gen.name];
    const maxSalary   = 160000.0;
    final lowPct  = salaryRange != null ? salaryRange.$1 / maxSalary : 0.4;
    final highPct = salaryRange != null ? salaryRange.$2 / maxSalary : 0.7;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF0F2756),
              _primaryBlue,
              Color(0xFF3B82F6),
            ],
            begin: Alignment.topLeft,
            end:   Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color:      _primaryBlue.withValues(alpha: 0.42),
              blurRadius: 30, offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(children: [
          // Decorative blobs
          Positioned(right: -30, top: -30, child: _blob(180, 0.04)),
          Positioned(left: -15, bottom: -40, child: _blob(130, 0.035)),

          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Header row
              Row(children: [
                Text(gen.emoji, style: const TextStyle(fontSize: 36)),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your Generation',
                        style: _ts(12, FontWeight.w600,
                            Colors.white.withValues(alpha: 0.65))),
                    Text(gen.name,
                        style: _ts(20, FontWeight.w900, Colors.white, ls: -0.5)),
                    Text(gen.yearRange,
                        style: _ts(12, FontWeight.w500,
                            Colors.white.withValues(alpha: 0.55))),
                  ],
                )),
                // Workforce ring
                SizedBox(
                  width: 58, height: 58,
                  child: Stack(alignment: Alignment.center, children: [
                    TweenAnimationBuilder<double>(
                      tween:    Tween(begin: 0, end: (_workforcePct[gen.name] ?? 25) / 100),
                      duration: const Duration(milliseconds: 1200),
                      curve:    Curves.easeOutCubic,
                      builder: (_, val, __) => CustomPaint(
                        size: const Size(58, 58),
                        painter: _ArcGaugePainter(
                          progress:    val,
                          fgColor:     Colors.white,
                          trackColor:  Colors.white.withValues(alpha: 0.15),
                          strokeWidth: 5.0,
                        ),
                      ),
                    ),
                    Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(
                        '${(_workforcePct[gen.name] ?? 0).round()}%',
                        style: _ts(14, FontWeight.w900, Colors.white),
                      ),
                      Text('workforce',
                          style: _ts(8, FontWeight.w500,
                              Colors.white.withValues(alpha: 0.6))),
                    ]),
                  ]),
                ),
              ]),

              const SizedBox(height: 18),
              Divider(color: Colors.white.withValues(alpha: 0.12)),
              const SizedBox(height: 14),

              // Skills + Industries row
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('COMPETITIVE SKILLS',
                        style: _ts(10, FontWeight.w700,
                            Colors.white.withValues(alpha: 0.6), ls: 0.6)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6,
                      children: gen.topSkills.take(4).map((s) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color:        Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(100),
                          border:       Border.all(
                              color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Text(s,
                            style: _ts(11, FontWeight.w600, Colors.white)),
                      )).toList(),
                    ),
                  ],
                )),
                const SizedBox(width: 18),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('INDUSTRIES',
                      style: _ts(10, FontWeight.w700,
                          Colors.white.withValues(alpha: 0.6), ls: 0.6)),
                  const SizedBox(height: 8),
                  ...gen.industries.take(3).map((ind) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 5, height: 5,
                        decoration: const BoxDecoration(
                          color: Colors.white60, shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(ind, style: _ts(12, FontWeight.w500, Colors.white)),
                    ]),
                  )),
                ]),
              ]),

              const SizedBox(height: 16),

              // Salary bar (NEW)
              Text('SALARY RANGE',
                  style: _ts(10, FontWeight.w700,
                      Colors.white.withValues(alpha: 0.6), ls: 0.6)),
              const SizedBox(height: 8),
              if (salaryRange != null) ...[
                Row(children: [
                  Text(
                    '\$${(salaryRange.$1 / 1000).round()}k',
                    style: _ts(12, FontWeight.w600,
                        Colors.white.withValues(alpha: 0.7)),
                  ),
                  const Spacer(),
                  Text(
                    '\$${(salaryRange.$2 / 1000).round()}k',
                    style: _ts(12, FontWeight.w700, Colors.white),
                  ),
                ]),
                const SizedBox(height: 5),
                Stack(children: [
                  Container(
                    height: 7,
                    decoration: BoxDecoration(
                      color:        Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  TweenAnimationBuilder<double>(
                    tween:    Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 1100),
                    curve:    Curves.easeOutCubic,
                    builder: (_, val, __) => FractionallySizedBox(
                      widthFactor: (lowPct + (highPct - lowPct) * val)
                          .clamp(0.0, 1.0),
                      child: Container(
                        height: 7,
                        decoration: BoxDecoration(
                          color:        Colors.white,
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                    ),
                  ),
                ]),
              ],

              const SizedBox(height: 16),

              // Bridge skill tip
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color:        Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(13),
                  border:       Border.all(
                      color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Row(children: [
                  const Icon(Icons.tips_and_updates_rounded,
                      color: Colors.white70, size: 16),
                  const SizedBox(width: 9),
                  Expanded(child: Text(
                    'Bridge skill: ${gen.bridgeSkill} connects you to Gen Z opportunities',
                    style: _ts(12, FontWeight.w500,
                        Colors.white.withValues(alpha: 0.75)),
                  )),
                ]),
              ),

              const SizedBox(height: 14),

              // Traits row
              Wrap(spacing: 7, runSpacing: 7,
                children: gen.traits.map((t) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color:        Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(t,
                      style: _ts(11, FontWeight.w500,
                          Colors.white.withValues(alpha: 0.82))),
                )).toList(),
              ),
            ]),
          ),
        ]),
      ),
    )
        .animate()
        .fadeIn(duration: 420.ms, delay: 60.ms)
        .slideY(begin: 0.06, end: 0, curve: Curves.easeOut);
  }

  Widget _blob(double size, double opacity) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: opacity),
    ),
  );

  // ── SECTION 3: AI Adoption Timeline ───────────────────────────────────────

  Widget _buildAITimeline(List<String> industries) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: _card_(
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        Row(children: [
          _iconBox(Icons.smart_toy_rounded, const Color(0xFFEDE9FE), const Color(0xFF8B5CF6),
              size: 42),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AI Adoption Timeline',
                  style: _ts(16, FontWeight.w800, _text, ls: -0.3)),
              Text('2018 – 2025 across 6 industries',
                  style: _ts(12, FontWeight.w400, _sub)),
            ],
          )),
          // Current year badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color:        _success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border:       Border.all(color: _success.withValues(alpha: 0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 6, height: 6,
                decoration: const BoxDecoration(
                  color: _success, shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text('2025', style: _ts(11, FontWeight.w700, _success)),
            ]),
          ),
        ]),

        const SizedBox(height: 20),

        SizedBox(
          height: 230,
          child: LineChart(LineChartData(
            minX: 0, maxX: 7, minY: 0, maxY: 110,
            clipData: const FlClipData.all(),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 25,
              getDrawingHorizontalLine: (_) => FlLine(
                color:       _border.withValues(alpha: 0.45),
                strokeWidth: 1,
                dashArray:   [4, 4],
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(
                showTitles:    true,
                interval:      25,
                reservedSize:  30,
                getTitlesWidget: (v, _) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text('${v.toInt()}%',
                      style: _ts(9, FontWeight.w500, _sub)),
                ),
              )),
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles:    true,
                reservedSize:  26,
                getTitlesWidget: (v, _) {
                  final idx = v.round();
                  if (idx < 0 || idx >= _xLabels.length) {
                    return const SizedBox.shrink();
                  }
                  final isCurrent = idx == _xLabels.length - 1;
                  return Text(
                    _xLabels[idx],
                    style: _ts(9,
                        isCurrent ? FontWeight.w800 : FontWeight.w500,
                        isCurrent ? _primaryBlue : _sub),
                  );
                },
              )),
              topTitles:   const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
            ),
            lineBarsData: industries.asMap().entries.map((e) {
              final scores = _aiTimeline[e.value]!;
              final color  = _lineColors[e.key % _lineColors.length];
              return LineChartBarData(
                spots: scores.asMap().entries
                    .map((s) => FlSpot(s.key.toDouble(), s.value))
                    .toList(),
                isCurved:  true,
                color:     color,
                barWidth:  2.5,
                dotData:   FlDotData(
                  show: true,
                  checkToShowDot: (spot, _) =>
                  spot.x == scores.length - 1,
                  getDotPainter: (_, __, ___, ____) =>
                      FlDotCirclePainter(
                        radius:          4,
                        color:           color,
                        strokeColor:     _card,
                        strokeWidth:     2,
                      ),
                ),
                belowBarData: BarAreaData(
                  show:  true,
                  color: color.withValues(alpha: 0.05),
                ),
              );
            }).toList(),
          )),
        ),

        const SizedBox(height: 14),
        Divider(color: _border, height: 1),
        const SizedBox(height: 12),

        // Legend grid
        GridView.count(
          crossAxisCount:   3,
          shrinkWrap:       true,
          physics:          const NeverScrollableScrollPhysics(),
          mainAxisSpacing:  6,
          crossAxisSpacing: 6,
          childAspectRatio: 4.0,
          children: industries.asMap().entries.map((e) {
            final color = _lineColors[e.key % _lineColors.length];
            final latest = _aiTimeline[e.value]?.last ?? 0;
            return Row(children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  color: color, shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(e.value,
                    style: _ts(10, FontWeight.w600, _sub),
                    overflow: TextOverflow.ellipsis),
              ),
              Text('${latest.round()}%',
                  style: _ts(10, FontWeight.w800, color)),
            ]);
          }).toList(),
        ),
      ]),
    ),
  )
      .animate()
      .fadeIn(duration: 400.ms, delay: 80.ms)
      .slideY(begin: 0.06, end: 0, curve: Curves.easeOut);

  // ── SECTION 4: AI Alert Cards ──────────────────────────────────────────────

  Widget _buildAIAlerts() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionHeader(
        'AI Disruption Alerts',
        subtitle: '${_aiAlerts.length} industries monitored',
        icon:     Icons.warning_amber_rounded,
        iconBg:   _errorBg,
        iconFg:   _error,
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: _aiAlerts.asMap().entries.map((e) {
            final alert  = e.value;
            final isUrgent = alert.urgent;
            // Risk level derived from badge
            final riskLevel = switch (alert.badge) {
              'High Risk'   => 0.88,
              'Evolving'    => 0.56,
              _             => 0.28,
            };

            return _AIAlertCard(
              alert:      alert,
              riskLevel:  riskLevel,
              isDark:     _isDark,
              card:       _card,
              surface:    _surface,
              text:       _text,
              sub:        _sub,
              border:     _border,
              lightBlue:  _lightBlue,
              ts:         _ts,
              skillTagBuilder: _skillTag,
              outlineBtn:      _outlineBtn,
              pulseAnim:  isUrgent ? _pulseAnim : null,
            ).animate().fadeIn(
              delay: Duration(milliseconds: e.key * 90), duration: 380.ms,
            );
          }).toList(),
        ),
      ),
    ],
  );

  // ── SECTION 5: Collaboration Tips ─────────────────────────────────────────

  Widget _buildCollabTips() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
    child: _card_(
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _iconBox(Icons.groups_rounded, _warningBg, _warning, size: 42),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Multi-Gen Collaboration',
                  style: _ts(16, FontWeight.w800, _text, ls: -0.3)),
              Text('Tips that work across every generation',
                  style: _ts(12, FontWeight.w400, _sub)),
            ],
          )),
        ]),
        const SizedBox(height: 16),

        // Timeline style with connecting line
        Stack(children: [
          // Vertical connector
          Positioned(
            left: 14, top: 0, bottom: 16,
            child: Container(width: 1.5, color: _border),
          ),
          Column(
            children: _collabTips.asMap().entries.map((e) {
              final isLast = e.key == _collabTips.length - 1;
              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Circle marker
                    Container(
                      width: 29, height: 29,
                      decoration: BoxDecoration(
                        color:        _primaryBlue,
                        shape:        BoxShape.circle,
                        border:       Border.all(color: _card, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color:      _primaryBlue.withValues(alpha: 0.3),
                            blurRadius: 8, offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text('${e.key + 1}',
                            style: _ts(10, FontWeight.w800, Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color:        _surface,
                          borderRadius: BorderRadius.circular(13),
                          border:       Border.all(color: _border),
                        ),
                        child: Text(
                          e.value,
                          style: _ts(13, FontWeight.w500, _text),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ]),
      ]),
    ),
  )
      .animate()
      .fadeIn(duration: 400.ms, delay: 100.ms)
      .slideY(begin: 0.06, end: 0, curve: Curves.easeOut);

  // ── Personalized Insight Banner (NEW) ──────────────────────────────────────

  Widget _buildInsightBanner(_Generation gen) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        _lightBlue,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: _primaryBlue.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color:        _primaryBlue.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.lightbulb_outline_rounded,
              color: _primaryBlue, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: _ts(12, FontWeight.w400, _sub),
              children: [
                TextSpan(
                  text: 'As a ${gen.name}, ',
                  style: _ts(12, FontWeight.w700, _primaryBlue),
                ),
                TextSpan(
                  text: 'your top bridge skill is ',
                  style: _ts(12, FontWeight.w400, _text),
                ),
                TextSpan(
                  text: gen.bridgeSkill,
                  style: _ts(12, FontWeight.w700, _primaryBlue),
                ),
                TextSpan(
                  text: '. Tap a generation card to compare.',
                  style: _ts(12, FontWeight.w400, _text),
                ),
              ],
            ),
          ),
        ),
      ]),
    ),
  ).animate().fadeIn(duration: 350.ms);

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final userGen    = _generations[_userGenIndex];
    final industries = _aiTimeline.keys.toList();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color:    _bg,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: AnimatedSlide(
          offset:   _showScrollTop ? Offset.zero : const Offset(0, 2),
          duration: const Duration(milliseconds: 300),
          curve:    Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity:  _showScrollTop ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: FloatingActionButton.small(
              onPressed: () {
                HapticFeedback.selectionClick();
                _scrollCtrl.animateTo(
                  0,
                  duration: const Duration(milliseconds: 500),
                  curve:    Curves.easeOutCubic,
                );
              },
              backgroundColor: _primaryBlue,
              foregroundColor: Colors.white,
              elevation:       8,
              child: const Icon(Icons.keyboard_arrow_up_rounded),
            ),
          ),
        ),
        appBar: _buildAppBar(),
        body: CustomScrollView(
          controller: _scrollCtrl,
          slivers: [
            SliverToBoxAdapter(child: _buildTabSwitcher()),
            SliverToBoxAdapter(child: _buildStatsBanner()),
            SliverToBoxAdapter(child: _buildInsightBanner(userGen)),

            if (_activeTab == 0) ...[
              SliverToBoxAdapter(child: _buildGenerationCards()),
              SliverToBoxAdapter(child: _buildYourGenCard(userGen)),
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: _buildAITimeline(industries),
              )),
              SliverToBoxAdapter(child: _buildCollabTips()),
            ] else ...[
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _buildAITimeline(industries),
              )),
              SliverToBoxAdapter(child: _buildAIAlerts()),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor:        _bg,
    elevation:               0,
    scrolledUnderElevation:  0,
    surfaceTintColor:        Colors.transparent,
    foregroundColor:         _text,
    leading: IconButton(
      icon:      Icon(Icons.arrow_back_ios_new_rounded, color: _text, size: 20),
      onPressed: () {
        HapticFeedback.selectionClick();
        Navigator.maybePop(context);
      },
    ),
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Workforce Insights',
            style: _ts(17, FontWeight.w800, _text, ls: -0.3)),
        Text('60k+ listings · Live data', style: _ts(11, FontWeight.w400, _sub)),
      ],
    ),
    actions: [_buildDarkToggle()],
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: _border),
    ),
  );
}

// ─── AI Alert Card (extracted stateful for expand toggle) ─────────────────────

class _AIAlertCard extends StatefulWidget {
  final _AIAlert   alert;
  final double     riskLevel;
  final bool       isDark;
  final Color      card;
  final Color      surface;
  final Color      text;
  final Color      sub;
  final Color      border;
  final Color      lightBlue;
  final Animation<double>? pulseAnim;
  final TextStyle Function(double, FontWeight, Color, {double ls}) ts;
  final Widget Function(String, {bool urgent, Color? customColor}) skillTagBuilder;
  final Widget Function(String, VoidCallback, {IconData? icon}) outlineBtn;

  const _AIAlertCard({
    required this.alert,
    required this.riskLevel,
    required this.isDark,
    required this.card,
    required this.surface,
    required this.text,
    required this.sub,
    required this.border,
    required this.lightBlue,
    required this.ts,
    required this.skillTagBuilder,
    required this.outlineBtn,
    this.pulseAnim,
  });

  @override
  State<_AIAlertCard> createState() => _AIAlertCardState();
}

class _AIAlertCardState extends State<_AIAlertCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final alert    = widget.alert;
    final isUrgent = alert.urgent;
    final ac       = alert.color;

    Widget content = Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color:        widget.card,
        borderRadius: BorderRadius.circular(18),
        border:       Border.all(
          color: _expanded ? ac.withValues(alpha: 0.4) : widget.border,
          width: _expanded ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(
                alpha: widget.isDark ? 0.32 : 0.06),
            blurRadius: 14, offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Left accent bar + header row
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Colored accent bar
            Container(width: 4, color: ac),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Icon
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color:        ac.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border:       Border.all(color: ac.withValues(alpha: 0.22)),
                    ),
                    child: Icon(
                      isUrgent
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_outline_rounded,
                      color: ac, size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(alert.industry,
                              style: widget.ts(15, FontWeight.w800, widget.text, ls: -0.2)),
                        ),
                        // Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color:        ac.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(100),
                            border:       Border.all(
                                color: ac.withValues(alpha: 0.35)),
                          ),
                          child: Text(alert.badge,
                              style: widget.ts(10, FontWeight.w800, ac)),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      Text(alert.headline,
                          style: widget.ts(12, FontWeight.w400, widget.sub),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  )),
                ]),
              ),
            ),
          ]),
        ),

        // Risk thermometer (NEW)
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Risk Level',
                  style: widget.ts(10, FontWeight.w600, widget.sub, ls: 0.4)),
              const Spacer(),
              Text('${(widget.riskLevel * 100).round()}%',
                  style: widget.ts(11, FontWeight.w800, ac)),
            ]),
            const SizedBox(height: 5),
            TweenAnimationBuilder<double>(
              tween:    Tween(begin: 0, end: widget.riskLevel),
              duration: const Duration(milliseconds: 950),
              curve:    Curves.easeOutCubic,
              builder: (_, val, __) => CustomPaint(
                size: const Size(double.infinity, 6),
                painter: _RiskBarPainter(
                  level: val,
                  color: ac,
                  track: widget.isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 12),

        // Skills row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('REQUIRED SKILLS',
                style: widget.ts(10, FontWeight.w700, widget.sub, ls: 0.6)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: alert.upskillIn
                  .map((s) => widget.skillTagBuilder(
                  s, urgent: isUrgent, customColor: isUrgent ? null : ac))
                  .toList(),
            ),
          ]),
        ),

        // Expand section
        AnimatedCrossFade(
          duration:       const Duration(milliseconds: 260),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox(height: 0),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:        widget.surface,
                borderRadius: BorderRadius.circular(11),
                border:       Border.all(color: widget.border),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline_rounded, size: 14, color: widget.sub),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isUrgent
                        ? 'Act now: AI is rapidly replacing traditional roles in ${alert.industry}. Workers who upskill in the listed areas have a 3× higher chance of career longevity.'
                        : '${alert.industry} presents a growing opportunity for professionals who blend human empathy with AI tooling. Early movers will command a premium.',
                    style: widget.ts(12, FontWeight.w400, widget.sub),
                  ),
                ),
              ]),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Actions row
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
          child: Row(children: [
            Expanded(
              child: widget.outlineBtn(
                'Learn Required Skills →',
                    () {},
                icon: Icons.school_outlined,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _expanded = !_expanded);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color:        _expanded
                      ? ac.withValues(alpha: 0.12)
                      : widget.lightBlue,
                  borderRadius: BorderRadius.circular(11),
                  border:       Border.all(
                    color: _expanded
                        ? ac.withValues(alpha: 0.3)
                        : widget.border,
                  ),
                ),
                child: AnimatedRotation(
                  turns:    _expanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 240),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size:  20,
                    color: _expanded ? ac : widget.sub,
                  ),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );

    // Wrap urgent cards in a pulsing glow
    if (isUrgent && widget.pulseAnim != null) {
      return AnimatedBuilder(
        animation: widget.pulseAnim!,
        builder: (_, child) => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color:      ac.withValues(
                    alpha: 0.08 + widget.pulseAnim!.value * 0.1),
                blurRadius: 12 + widget.pulseAnim!.value * 10,
                spreadRadius: widget.pulseAnim!.value * 2,
              ),
            ],
          ),
          child: child,
        ),
        child: content,
      );
    }
    return content;
  }
}

// ─── Gen Detail Bottom Sheet (NEW) ────────────────────────────────────────────

class _GenDetailSheet extends StatelessWidget {
  final _Generation gen;
  final List<Color> gColors;
  final (double, double)? salaryRange;
  final bool  isDark;
  final Color card;
  final Color surface;
  final Color text;
  final Color sub;
  final Color border;
  final Color lightBlue;
  final TextStyle Function(double, FontWeight, Color, {double ls}) ts;

  const _GenDetailSheet({
    required this.gen,
    required this.gColors,
    required this.salaryRange,
    required this.isDark,
    required this.card,
    required this.surface,
    required this.text,
    required this.sub,
    required this.border,
    required this.lightBlue,
    required this.ts,
  });

  @override
  Widget build(BuildContext context) {
    final pct = _workforcePct[gen.name] ?? 25.0;

    return Container(
      decoration: BoxDecoration(
        color:        isDark ? const Color(0xFF141E2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle bar
        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 40, height: 4,
          decoration: BoxDecoration(
            color:        isDark
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(100),
          ),
        ),

        // Gradient header
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gColors,
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color:      gColors.first.withValues(alpha: 0.35),
                blurRadius: 20, offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(children: [
            Text(gen.emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(width: 16),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(gen.name,
                    style: ts(20, FontWeight.w900, Colors.white, ls: -0.5)),
                Text(gen.yearRange,
                    style: ts(13, FontWeight.w500,
                        Colors.white.withValues(alpha: 0.7))),
                const SizedBox(height: 6),
                Text(
                  '${pct.round()}% of the current workforce',
                  style: ts(12, FontWeight.w600,
                      Colors.white.withValues(alpha: 0.82)),
                ),
              ],
            )),
          ]),
        ),

        // Scrollable body
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Traits
                Text('TRAITS', style: ts(11, FontWeight.w700, sub, ls: 0.7)),
                const SizedBox(height: 8),
                Wrap(spacing: 7, runSpacing: 7,
                  children: gen.traits.map((t) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 11, vertical: 5),
                    decoration: BoxDecoration(
                      color:        surface,
                      borderRadius: BorderRadius.circular(8),
                      border:       Border.all(color: border),
                    ),
                    child: Text(t, style: ts(12, FontWeight.w500, text)),
                  )).toList(),
                ),

                const SizedBox(height: 16),

                // Best roles
                Text('BEST ROLES', style: ts(11, FontWeight.w700, sub, ls: 0.7)),
                const SizedBox(height: 8),
                ...gen.bestRoles.map((r) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 13, vertical: 10),
                  decoration: BoxDecoration(
                    color:        lightBlue,
                    borderRadius: BorderRadius.circular(10),
                    border:       Border.all(
                        color: gen.color.withValues(alpha: 0.25)),
                  ),
                  child: Row(children: [
                    Icon(Icons.work_outline_rounded,
                        size: 15, color: gen.color),
                    const SizedBox(width: 8),
                    Text(r, style: ts(13, FontWeight.w600, text)),
                  ]),
                )),

                const SizedBox(height: 16),

                // Salary range
                if (salaryRange != null) ...[
                  Text('SALARY RANGE',
                      style: ts(11, FontWeight.w700, sub, ls: 0.7)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Entry',
                          style: ts(10, FontWeight.w600, sub)),
                      Text(
                        '\$${(salaryRange!.$1 / 1000).round()}k',
                        style: ts(18, FontWeight.w800, text),
                      ),
                    ]),
                    const Spacer(),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('Senior', style: ts(10, FontWeight.w600, sub)),
                      Text(
                        '\$${(salaryRange!.$2 / 1000).round()}k',
                        style: ts(18, FontWeight.w800, gen.color),
                      ),
                    ]),
                  ]),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: TweenAnimationBuilder<double>(
                      tween:    Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 900),
                      curve:    Curves.easeOutCubic,
                      builder: (_, val, __) => LinearProgressIndicator(
                        value:           (salaryRange!.$2 / 160000 * val)
                            .clamp(0.0, 1.0),
                        minHeight:       8,
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.07)
                            : Colors.black.withValues(alpha: 0.06),
                        valueColor:      AlwaysStoppedAnimation(gen.color),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // All skills
                Text('ALL SKILLS',
                    style: ts(11, FontWeight.w700, sub, ls: 0.7)),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6,
                  children: gen.topSkills.map((s) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color:        gen.color.withValues(
                          alpha: isDark ? 0.18 : 0.09),
                      borderRadius: BorderRadius.circular(100),
                      border:       Border.all(
                          color: gen.color.withValues(alpha: 0.28)),
                    ),
                    child: Text(s,
                        style: ts(11, FontWeight.w600, gen.color)),
                  )).toList(),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}