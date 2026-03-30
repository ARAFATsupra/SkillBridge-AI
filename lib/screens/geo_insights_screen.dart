// lib/screens/geo_insights_screen.dart — SkillBridge AI
// ─────────────────────────────────────────────────────────────────────────────
// Refactored:
//  • Removed local _isDark field + _buildDarkToggle() — theme now driven by
//    global AppState via context.watch<AppState>().isDark so the single global
//    toggle in main_nav.dart applies here too (no duplicate button).
//  • All data, chart, filter, preference, and navigation logic is unchanged.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';

// ══════════════════════════════════════════════════════════════════════════════
// MODELS
// ══════════════════════════════════════════════════════════════════════════════

class _CityDemand {
  final String city;
  final String emoji;
  final Map<String, double> demandByCategory;
  final bool isTrending;

  const _CityDemand(
      this.city,
      this.emoji,
      this.demandByCategory, {
        this.isTrending = false,
      });

  double demand(String cat) => cat == 'All Jobs'
      ? demandByCategory.values.reduce((a, b) => a + b) /
      demandByCategory.length
      : (demandByCategory[cat] ?? 0);
}

class _EduLocation {
  final String   education;
  final String   topCity;
  final double   pct;
  final String   note;
  final IconData icon;
  final Color    color;

  const _EduLocation(
      this.education,
      this.topCity,
      this.pct,
      this.note,
      this.icon,
      this.color,
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// DATA
// ══════════════════════════════════════════════════════════════════════════════

const _categories = [
  'All Jobs', 'Data Science', 'Software', 'Marketing', 'Finance', 'Healthcare',
];

const List<_CityDemand> _cities = [
  _CityDemand(
    'Dhaka', '🏙️',
    {'Data Science': 62, 'Software': 70, 'Marketing': 55, 'Finance': 60, 'Healthcare': 48},
    isTrending: true,
  ),
  _CityDemand('Chittagong', '⚓',
      {'Data Science': 18, 'Software': 22, 'Marketing': 30, 'Finance': 25, 'Healthcare': 32}),
  _CityDemand('Sylhet', '🌿',
      {'Data Science': 8, 'Software': 10, 'Marketing': 14, 'Finance': 12, 'Healthcare': 18}),
  _CityDemand('Rajshahi', '🏛️',
      {'Data Science': 6, 'Software': 8, 'Marketing': 12, 'Finance': 9, 'Healthcare': 15}),
  _CityDemand('Khulna', '🌊',
      {'Data Science': 5, 'Software': 6, 'Marketing': 10, 'Finance': 8, 'Healthcare': 14}),
  _CityDemand('Comilla', '🏯',
      {'Data Science': 4, 'Software': 5, 'Marketing': 9, 'Finance': 7, 'Healthcare': 10}),
  _CityDemand('Barishal', '🚢',
      {'Data Science': 3, 'Software': 4, 'Marketing': 7, 'Finance': 5, 'Healthcare': 9}),
];

const List<_EduLocation> _eduLocations = [
  _EduLocation("Bachelor's", 'Dhaka', 45, 'Most entry-level demand',
      Icons.school_rounded, Color(0xFF6366F1)),
  _EduLocation("Master's", 'Dhaka + Remote', 30, 'Strong remote options',
      Icons.auto_stories_rounded, Color(0xFF8B5CF6)),
  _EduLocation('PhD', 'Dhaka', 18, 'Research & academia',
      Icons.science_rounded, Color(0xFFEC4899)),
  _EduLocation('Diploma', 'Chittagong', 28, 'Technical roles',
      Icons.build_rounded, Color(0xFFF59E0B)),
  _EduLocation('HSC', 'Dhaka', 35, 'Junior support roles',
      Icons.book_rounded, Color(0xFF10B981)),
  _EduLocation('Vocational', 'Khulna', 22, 'Trade & industrial',
      Icons.handyman_rounded, Color(0xFF14B8A6)),
];

const List<String> _allCities = [
  'Dhaka', 'Chittagong', 'Sylhet', 'Rajshahi', 'Khulna',
  'Comilla', 'Barishal', 'Mymensingh', 'Rangpur',
];

// ══════════════════════════════════════════════════════════════════════════════
// DESIGN TOKENS
// ══════════════════════════════════════════════════════════════════════════════

const _primaryBlue = Color(0xFF2563EB);
const _blue500     = Color(0xFF3B82F6);
const _blue200     = Color(0xFF93C5FD);
const _blue50      = Color(0xFFEFF6FF);
const _success     = Color(0xFF10B981);
const _successBg   = Color(0xFFECFDF5);
const _warning     = Color(0xFFF59E0B);
const _warningBg   = Color(0xFFFFFBEB);
const _purple      = Color(0xFF8B5CF6);

// Light
const _bgLight     = Color(0xFFF8FAFC);
const _cardLight   = Color(0xFFFFFFFF);
const _textLight   = Color(0xFF0F172A);
const _subLight    = Color(0xFF64748B);
const _borderLight = Color(0xFFE2E8F0);

// Dark
const _bgDark      = Color(0xFF0A0F1E);
const _cardDark    = Color(0xFF111827);
const _textDark    = Color(0xFFF1F5F9);
const _subDark     = Color(0xFF94A3B8);
const _borderDark  = Color(0xFF1E293B);

// ══════════════════════════════════════════════════════════════════════════════
// SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class GeoInsightsScreen extends StatefulWidget {
  const GeoInsightsScreen({super.key});

  @override
  State<GeoInsightsScreen> createState() => _GeoInsightsScreenState();
}

class _GeoInsightsScreenState extends State<GeoInsightsScreen> {

  // ── UI state ───────────────────────────────────────────────────────────────
  String _selectedCat    = 'All Jobs';
  int?   _tappedBarIdx;
  bool   _includeRemote  = true;
  bool   _filterRecs     = false;
  final Set<String> _preferredCities = {'Dhaka'};

  // ── Theme — driven by global AppState ─────────────────────────────────────
  // Stored as a field so helper methods can access it without context.
  bool _isDark = false;

  // ── Computed ───────────────────────────────────────────────────────────────
  List<_CityDemand> get _sorted {
    final list = List<_CityDemand>.from(_cities);
    list.sort(
            (a, b) => b.demand(_selectedCat).compareTo(a.demand(_selectedCat)));
    return list;
  }

  // ── Theme helpers ──────────────────────────────────────────────────────────
  Color get _bg        => _isDark ? _bgDark     : _bgLight;
  Color get _card      => _isDark ? _cardDark   : _cardLight;
  Color get _text      => _isDark ? _textDark   : _textLight;
  Color get _sub       => _isDark ? _subDark    : _subLight;
  Color get _border    => _isDark ? _borderDark : _borderLight;
  Color get _lightBlue => _isDark ? const Color(0xFF1E3A5F) : _blue50;

  // ── Typography ─────────────────────────────────────────────────────────────
  TextStyle _ts(double size, FontWeight weight, Color color,
      {double? letterSpacing}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      );

  // ── Shared component helpers ───────────────────────────────────────────────

  Widget _buildCard({
    required Widget child,
    EdgeInsets? padding,
    Color? bg,
  }) =>
      Container(
        decoration: BoxDecoration(
          color: bg ?? _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border, width: 1),
          boxShadow: [
            BoxShadow(
              color: _isDark
                  ? Colors.black.withValues(alpha: 0.45)
                  : const Color(0xFF0F172A).withValues(alpha: 0.05),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: padding ?? const EdgeInsets.all(20),
        child: child,
      );

  Widget _buildIconBox(IconData icon,
      {Color? iconColor, Color? bgColor}) =>
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: bgColor ?? _lightBlue,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor ?? _primaryBlue, size: 20),
      );

  Widget _buildSectionHeader(
      String title,
      IconData icon, {
        Color? iconColor,
        Color? iconBg,
      }) =>
      Row(children: [
        _buildIconBox(icon, iconColor: iconColor, bgColor: iconBg),
        const SizedBox(width: 12),
        Text(title, style: _ts(16, FontWeight.w700, _text)),
      ]);

  Widget _buildPrimaryBtn(String label, VoidCallback onTap) => SizedBox(
    width: double.infinity,
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _primaryBlue.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: Text(label,
                style: _ts(14, FontWeight.w700, Colors.white,
                    letterSpacing: 0.3)),
          ),
        ),
      ),
    ),
  );

  Widget _buildLegendDot(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(label, style: _ts(10, FontWeight.w500, _sub)),
    ],
  );

  Widget _buildToggleRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) =>
      Row(children: [
        Icon(icon, color: _sub, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _ts(14, FontWeight.w600, _text)),
                Text(subtitle, style: _ts(12, FontWeight.w400, _sub)),
              ]),
        ),
        Switch(
          value: value,
          onChanged: (v) {
            HapticFeedback.selectionClick();
            onChanged(v);
          },
          activeThumbColor: _primaryBlue,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ]);

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    // ── Sync theme from global AppState ─────────────────────────────────────
    _isDark = context.watch<AppState>().isDark;

    final sorted  = _sorted;
    final topCity = sorted.first;
    final isMatch = topCity.city == 'Dhaka';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      color: _bg,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _buildAppBar(),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(child: _buildSummaryStrip()),
            SliverToBoxAdapter(child: _buildCategoryFilter()),
            SliverToBoxAdapter(child: _buildCityChart(sorted)),
            SliverToBoxAdapter(
                child: _buildLocationMatch(topCity, isMatch)),
            SliverToBoxAdapter(child: _buildEduLocationGrid()),
            SliverToBoxAdapter(child: _buildTrendingCities()),
            SliverToBoxAdapter(child: _buildLocationPrefs()),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  // ── AppBar — no local theme toggle ─────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: _bg,
    elevation: 0,
    scrolledUnderElevation: 0.5,
    foregroundColor: _text,
    leading: IconButton(
      icon: Icon(Icons.arrow_back_ios_new_rounded,
          color: _text, size: 20),
      onPressed: () => Navigator.maybePop(context),
    ),
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Job Demand by Location',
            style: _ts(17, FontWeight.w700, _text)),
        Text('Bangladesh · Live Market Data',
            style: _ts(11, FontWeight.w500, _sub)),
      ],
    ),
    // ── No theme toggle here — it lives in the global main_nav AppBar ──
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: _border),
    ),
  );

  // ── Summary Strip ──────────────────────────────────────────────────────────

  Widget _buildSummaryStrip() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: Row(children: [
      _buildStatCard('${_cities.length}', 'Cities',
          Icons.location_city_rounded, _primaryBlue),
      const SizedBox(width: 10),
      _buildStatCard('Dhaka', 'Top City',
          Icons.trending_up_rounded, _success),
      const SizedBox(width: 10),
      _buildStatCard(
        '${_sorted.first.demand(_selectedCat).toInt()}%',
        'Peak Demand',
        Icons.bar_chart_rounded,
        _purple,
      ),
    ]),
  ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.06, end: 0);

  Widget _buildStatCard(
      String value,
      String label,
      IconData icon,
      Color color,
      ) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(height: 8),
                Text(value, style: _ts(16, FontWeight.w800, _text)),
                Text(label, style: _ts(11, FontWeight.w500, _sub)),
              ]),
        ),
      );

  // ── Category Filter ────────────────────────────────────────────────────────

  Widget _buildCategoryFilter() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _categories.map((cat) {
          final isActive = _selectedCat == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedCat  = cat;
                  _tappedBarIdx = null;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  color: isActive ? _primaryBlue : _card,
                  border: isActive
                      ? null
                      : Border.all(color: _border, width: 1),
                  boxShadow: isActive
                      ? [
                    BoxShadow(
                      color: _primaryBlue
                          .withValues(alpha: 0.32),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                      : null,
                ),
                child: Text(
                  cat,
                  style: _ts(13, FontWeight.w600,
                      isActive ? Colors.white : _text),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ),
  ).animate().fadeIn(duration: 350.ms).slideX(begin: -0.05, end: 0);

  // ── City Demand Chart ──────────────────────────────────────────────────────

  Widget _buildCityChart(List<_CityDemand> sorted) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: _buildCard(
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _buildIconBox(Icons.location_city_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Job Demand by City',
                          style: _ts(15, FontWeight.w700, _text)),
                      Text('Bangladesh · $_selectedCat',
                          style: _ts(12, FontWeight.w400, _sub)),
                    ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.trending_up_rounded,
                      color: _success, size: 13),
                  const SizedBox(width: 4),
                  Text(
                    '${sorted.first.demand(_selectedCat).toInt()}% peak',
                    style: _ts(11, FontWeight.w700, _success),
                  ),
                ]),
              ),
            ]),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 420),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.04),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                      parent: anim, curve: Curves.easeOut)),
                  child: child,
                ),
              ),
              child: SizedBox(
                key: ValueKey(_selectedCat),
                height: 280,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceBetween,
                    maxY: 100,
                    barTouchData: BarTouchData(
                      touchCallback:
                          (FlTouchEvent event, BarTouchResponse? resp) {
                        setState(() {
                          if (resp == null || resp.spot == null) {
                            _tappedBarIdx = null;
                          } else {
                            HapticFeedback.selectionClick();
                            _tappedBarIdx =
                                resp.spot!.touchedBarGroupIndex;
                          }
                        });
                      },
                      touchTooltipData: BarTouchTooltipData(
                        tooltipBorderRadius: BorderRadius.circular(10),
                        tooltipPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        getTooltipColor: (_) => _primaryBlue,
                        getTooltipItem: (group, _, rod, __) {
                          final idx = group.x;
                          if (idx < 0 || idx >= sorted.length) {
                            return null;
                          }
                          return BarTooltipItem(
                            '${sorted[idx].emoji} ${sorted[idx].city}\n',
                            _ts(11, FontWeight.w700, Colors.white),
                            children: [
                              TextSpan(
                                text: '${rod.toY.round()}% demand',
                                style: _ts(10, FontWeight.w500,
                                    Colors.white.withValues(alpha: 0.85)),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (v, meta) {
                            final idx = v.toInt();
                            if (idx < 0 || idx >= sorted.length) {
                              return const SizedBox.shrink();
                            }
                            final raw  = sorted[idx].city;
                            final name = raw.length > 5
                                ? raw.substring(0, 5)
                                : raw;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(name,
                                  textAlign: TextAlign.center,
                                  style:
                                  _ts(10, FontWeight.w500, _sub)),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          interval: 25,
                          getTitlesWidget: (v, _) => Text(
                            '${v.toInt()}%',
                            style: _ts(10, FontWeight.w400, _sub),
                          ),
                        ),
                      ),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 25,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: _border.withValues(alpha: 0.6),
                        strokeWidth: 1,
                        dashArray: [4, 4],
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: sorted.asMap().entries.map((e) {
                      final i   = e.key;
                      final val = e.value.demand(_selectedCat);
                      final isSel = _tappedBarIdx == i;
                      final isTop = i == 0;

                      final Color barColor = isSel
                          ? _warning
                          : isTop
                          ? _primaryBlue
                          : val > 30
                          ? _blue500
                          : _blue200;

                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: val,
                            width: 24,
                            color: barColor,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(8),
                            ),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: 100,
                              color: _border.withValues(alpha: 0.18),
                            ),
                          ),
                        ],
                        showingTooltipIndicators: isSel ? [0] : [],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _buildLegendDot(_primaryBlue, 'Top city'),
              const SizedBox(width: 14),
              _buildLegendDot(_blue500, 'High (>30%)'),
              const SizedBox(width: 14),
              _buildLegendDot(_blue200, 'Low (<30%)'),
              const SizedBox(width: 14),
              _buildLegendDot(_warning, 'Selected'),
            ]),
          ]),
    ),
  ).animate().fadeIn(duration: 450.ms, delay: 50.ms).slideY(begin: 0.03, end: 0);

  // ── Location Match ─────────────────────────────────────────────────────────

  Widget _buildLocationMatch(_CityDemand topCity, bool isMatch) {
    final accent = isMatch ? _success : _warning;
    final pct    = topCity.demand(_selectedCat);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isMatch ? _successBg : _warningBg,
          borderRadius: BorderRadius.circular(20),
          border:
          Border.all(color: accent.withValues(alpha: 0.35), width: 1),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isMatch
                          ? [_success, const Color(0xFF059669)]
                          : [_warning, const Color(0xFFD97706)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    isMatch
                        ? Icons.location_on_rounded
                        : Icons.location_searching_rounded,
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
                          isMatch
                              ? "📍 You're in Dhaka — Top city for $_selectedCat jobs ✓"
                              : '📍 $_selectedCat jobs are mostly in ${topCity.city}',
                          style: _ts(14, FontWeight.w700, _textLight),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isMatch
                              ? '${pct.toStringAsFixed(0)}% of all $_selectedCat job postings are here'
                              : '${pct.toStringAsFixed(0)}% of postings — consider remote or relocation',
                          style: _ts(12, FontWeight.w500, _subLight),
                        ),
                      ]),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: _subLight, size: 22),
              ]),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: TweenAnimationBuilder<double>(
                  key: ValueKey('$_selectedCat-progress'),
                  tween: Tween(begin: 0, end: pct / 100),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (_, val, __) => LinearProgressIndicator(
                    value: val,
                    minHeight: 6,
                    backgroundColor: Colors.black.withValues(alpha: 0.06),
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
              ),
              if (!isMatch) ...[
                const SizedBox(height: 14),
                _buildPrimaryBtn('View Remote Jobs →', () {}),
              ],
            ]),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
  }

  // ── Education × Location Grid ──────────────────────────────────────────────

  Widget _buildEduLocationGrid() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: _buildSectionHeader(
            'Education × Location', Icons.school_rounded),
      ),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.6,
          ),
          itemCount: _eduLocations.length,
          itemBuilder: (_, i) {
            final e = _eduLocations[i];
            return _buildCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: e.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(e.education,
                            style:
                            _ts(10, FontWeight.w700, e.color)),
                      ),
                      Icon(e.icon, color: e.color, size: 16),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.topCity,
                          style: _ts(12, FontWeight.w700, _text),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: e.pct / 100),
                          duration: Duration(
                              milliseconds: 600 + i * 80),
                          curve: Curves.easeOutCubic,
                          builder: (_, val, __) =>
                              LinearProgressIndicator(
                                value: val,
                                minHeight: 4,
                                backgroundColor:
                                e.color.withValues(alpha: 0.12),
                                valueColor:
                                AlwaysStoppedAnimation<Color>(
                                    e.color),
                              ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text('${e.pct}% of postings',
                          style: _ts(10, FontWeight.w500, _sub)),
                    ],
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(
              duration: 380.ms,
              delay: Duration(milliseconds: 120 + i * 45),
            )
                .scale(
              begin: const Offset(0.95, 0.95),
              end: const Offset(1, 1),
            );
          },
        ),
      ),
    ],
  );

  // ── Trending Cities ────────────────────────────────────────────────────────

  Widget _buildTrendingCities() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: Row(children: [
          _buildIconBox(
            Icons.local_fire_department_rounded,
            iconColor: _warning,
            bgColor: _warningBg,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Trending Cities',
                style: _ts(16, FontWeight.w700, _text)),
          ),
          Text('See all →',
              style: _ts(12, FontWeight.w600, _primaryBlue)),
        ]),
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 120,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _sorted.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final city   = _sorted[i];
            final demand = city.demand(_selectedCat);
            final isHot  = demand > 50;

            return GestureDetector(
              onTap: () => HapticFeedback.selectionClick(),
              child: Container(
                width: 130,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isHot
                        ? _primaryBlue.withValues(alpha: 0.4)
                        : _border,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isHot ? _primaryBlue : Colors.black)
                          .withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                      children: [
                        Text(city.emoji,
                            style:
                            const TextStyle(fontSize: 22)),
                        if (isHot)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _primaryBlue,
                              borderRadius:
                              BorderRadius.circular(6),
                            ),
                            child: Text('HOT',
                                style: _ts(8, FontWeight.w800,
                                    Colors.white)),
                          ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(city.city,
                            style:
                            _ts(13, FontWeight.w700, _text)),
                        Text('${demand.toInt()}% demand',
                            style:
                            _ts(11, FontWeight.w500, _sub)),
                      ],
                    ),
                  ],
                ),
              ),
            )
                .animate()
                .fadeIn(
              duration: 350.ms,
              delay: Duration(milliseconds: 100 + i * 50),
            )
                .slideX(begin: 0.1, end: 0);
          },
        ),
      ),
    ],
  );

  // ── Location Preferences ───────────────────────────────────────────────────

  Widget _buildLocationPrefs() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: _buildCard(
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
                'My Location Preferences', Icons.tune_rounded),
            const SizedBox(height: 18),
            Text('Preferred Cities', style: _ts(13, FontWeight.w600, _sub)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._preferredCities.map((city) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _lightBlue,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: _blue200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(city,
                          style: _ts(
                              12, FontWeight.w700, _primaryBlue)),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(
                                  () => _preferredCities.remove(city));
                        },
                        child: const Icon(Icons.close_rounded,
                            color: _primaryBlue, size: 14),
                      ),
                    ],
                  ),
                )),
                GestureDetector(
                  onTap: _showCityPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                          color: _primaryBlue, width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_rounded,
                            color: _primaryBlue, size: 14),
                        const SizedBox(width: 4),
                        Text('Add City',
                            style: _ts(
                                12, FontWeight.w600, _primaryBlue)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Divider(color: _border, height: 1),
            const SizedBox(height: 14),
            _buildToggleRow(
              icon: Icons.wifi_rounded,
              title: 'Include Remote Jobs',
              subtitle: 'Show jobs available from anywhere',
              value: _includeRemote,
              onChanged: (v) => setState(() => _includeRemote = v),
            ),
            const SizedBox(height: 10),
            _buildToggleRow(
              icon: Icons.filter_alt_rounded,
              title: 'Apply to All Recommendations',
              subtitle: 'Filter job matches by these locations',
              value: _filterRecs,
              onChanged: (v) => setState(() => _filterRecs = v),
            ),
            const SizedBox(height: 18),
            _buildPrimaryBtn('Save Preferences', () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    Text('Location preferences saved!',
                        style: _ts(13, FontWeight.w600, Colors.white)),
                  ]),
                  backgroundColor: _primaryBlue,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.all(16),
                  duration: const Duration(seconds: 2),
                ),
              );
            }),
          ]),
    ),
  ).animate().fadeIn(duration: 400.ms, delay: 150.ms);

  // ── City Picker ────────────────────────────────────────────────────────────

  void _showCityPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CityPickerSheet(
        isDark: _isDark,
        selectedCities: Set.from(_preferredCities),
        allCities: _allCities,
        onChanged: (cities) => setState(() => _preferredCities
          ..clear()
          ..addAll(cities)),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CITY PICKER SHEET (self-contained StatefulWidget — unchanged)
// ══════════════════════════════════════════════════════════════════════════════

class _CityPickerSheet extends StatefulWidget {
  final bool isDark;
  final Set<String> selectedCities;
  final List<String> allCities;
  final ValueChanged<Set<String>> onChanged;

  const _CityPickerSheet({
    required this.isDark,
    required this.selectedCities,
    required this.allCities,
    required this.onChanged,
  });

  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  late final Set<String>          _local;
  late final TextEditingController _searchCtrl;
  String _query = '';

  // ── Local theme helpers ────────────────────────────────────────────────────
  Color get _border => widget.isDark ? _borderDark : _borderLight;
  Color get _text   => widget.isDark ? _textDark   : _textLight;
  Color get _sub    => widget.isDark ? _subDark    : _subLight;
  Color get _lb     => widget.isDark ? const Color(0xFF1E3A5F) : _blue50;

  TextStyle _ts(double size, FontWeight w, Color c) =>
      GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: w, color: c);

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _local      = Set.from(widget.selectedCities);
    _searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Filtered list ──────────────────────────────────────────────────────────
  List<String> get _filtered => widget.allCities
      .where((c) => c.toLowerCase().contains(_query.toLowerCase()))
      .toList();

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle bar
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: _border,
            borderRadius: BorderRadius.circular(100),
          ),
        ),
        const SizedBox(height: 16),
        Text('Select Cities', style: _ts(16, FontWeight.w700, _text)),
        const SizedBox(height: 14),

        // Search field
        Container(
          decoration: BoxDecoration(
            color: _lb,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            style: _ts(13, FontWeight.w500, _text),
            decoration: InputDecoration(
              hintText: 'Search cities…',
              hintStyle: _ts(13, FontWeight.w400, _sub),
              prefixIcon:
              Icon(Icons.search_rounded, color: _sub, size: 18),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // City chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _filtered.map((city) {
            final isSel = _local.contains(city);
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  if (isSel) {
                    _local.remove(city);
                  } else {
                    _local.add(city);
                  }
                });
                widget.onChanged(Set.from(_local));
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSel ? _primaryBlue : _lb,
                  borderRadius: BorderRadius.circular(100),
                  border: isSel ? null : Border.all(color: _border),
                ),
                child: Text(
                  city,
                  style: _ts(13, FontWeight.w600,
                      isSel ? Colors.white : _text),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // Done button
        SizedBox(
          width: double.infinity,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(14),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: Text(
                    'Done (${_local.length} selected)',
                    style: _ts(14, FontWeight.w700, Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}