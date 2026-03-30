// lib/screens/job_alerts_screen.dart — SkillBridge AI v2.0
// ─────────────────────────────────────────────────────────────────────────────
// FIX SUMMARY (v2.0 → v2.1):
//  · Removed local `_isDark` bool field + _buildDarkToggle() — was disconnected
//    from the global theme, causing the duplicate-button and persistence bugs.
//  · _isDark is now a computed getter reading Theme.of(context) so the screen
//    automatically responds to the app-wide ThemeMode without any local state.
//  · Removed AppBar actions dark toggle (handled globally in main_nav / AppBar).
//  · Replaced hardcoded _primaryBlue constant with AppTheme.primaryBlue.
//  · Added import for app_theme.dart.
//  · Minor: added missing `const` qualifiers, fixed inconsistent padding.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENUMS
// ─────────────────────────────────────────────────────────────────────────────

enum _AlertFrequency { instant, daily, weekly }

enum _AlertSort {
  matchCount('Most Matches'),
  name('A – Z'),
  activity('Recent');

  const _AlertSort(this.label);
  final String label;
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────────

class _JobAlert {
  String id;
  String name;
  String jobTitle;
  List<String> skills;
  String location;
  double minSalary;
  double maxSalary;
  bool isActive;
  _AlertFrequency frequency;
  DateTime lastTriggered;
  int newMatchCount;

  _JobAlert({
    required this.id,
    required this.name,
    required this.jobTitle,
    required this.skills,
    required this.location,
    required this.minSalary,
    required this.maxSalary,
    this.isActive = true,
    this.frequency = _AlertFrequency.instant,
    required this.lastTriggered,
    this.newMatchCount = 0,
  });
}

class _MatchCard {
  final String company;
  final String title;
  final int matchPct;
  final String timeAgo;
  final String location;
  final String salary;
  bool dismissed;

  _MatchCard({
    required this.company,
    required this.title,
    required this.matchPct,
    required this.timeAgo,
    required this.location,
    required this.salary,
  }) : dismissed = false;
}

class _TrendingJob {
  final String title;
  final int companyCount;
  final String avgSalary;
  final String growth;
  final List<String> topSkills;

  const _TrendingJob(
      this.title,
      this.companyCount,
      this.avgSalary,
      this.growth,
      this.topSkills,
      );
}

class _MatchFilter {
  final int minMatchPct;
  final String? locationFilter;

  const _MatchFilter({this.minMatchPct = 0, this.locationFilter});

  bool get isActive => minMatchPct > 0 || locationFilter != null;

  bool test(_MatchCard m) {
    if (m.matchPct < minMatchPct) return false;
    if (locationFilter != null && m.location != locationFilter) return false;
    return true;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MOCK DATA
// ─────────────────────────────────────────────────────────────────────────────

List<_JobAlert> _buildAlerts() {
  final now = DateTime.now();
  return [
    _JobAlert(
      id: '1',
      name: 'Data Science in Dhaka',
      jobTitle: 'Data Scientist',
      skills: ['Python', 'ML', 'SQL'],
      location: 'Dhaka',
      minSalary: 80000,
      maxSalary: 130000,
      isActive: true,
      frequency: _AlertFrequency.instant,
      lastTriggered: now.subtract(const Duration(hours: 2)),
      newMatchCount: 3,
    ),
    _JobAlert(
      id: '2',
      name: 'Remote Software Roles',
      jobTitle: 'Software Engineer',
      skills: ['React', 'Node.js', 'AWS'],
      location: 'Remote',
      minSalary: 100000,
      maxSalary: 180000,
      isActive: true,
      frequency: _AlertFrequency.daily,
      lastTriggered: now.subtract(const Duration(hours: 8)),
      newMatchCount: 2,
    ),
    _JobAlert(
      id: '3',
      name: 'Finance Analyst Roles',
      jobTitle: 'Financial Analyst',
      skills: ['Excel', 'Risk Analysis', 'Python'],
      location: 'Dhaka',
      minSalary: 60000,
      maxSalary: 100000,
      isActive: false,
      frequency: _AlertFrequency.weekly,
      lastTriggered: now.subtract(const Duration(days: 3)),
      newMatchCount: 0,
    ),
  ];
}

List<_MatchCard> _buildMatches() => [
  _MatchCard(
    company: 'Chaldal',
    title: 'Data Scientist',
    matchPct: 94,
    timeAgo: '2 hours ago',
    location: 'Dhaka',
    salary: '90k–120k BDT',
  ),
  _MatchCard(
    company: 'bKash',
    title: 'ML Engineer',
    matchPct: 89,
    timeAgo: '3 hours ago',
    location: 'Dhaka',
    salary: '100k–130k BDT',
  ),
  _MatchCard(
    company: 'Pathao',
    title: 'Data Analyst',
    matchPct: 85,
    timeAgo: '5 hours ago',
    location: 'Dhaka',
    salary: '70k–90k BDT',
  ),
  _MatchCard(
    company: 'BRAC IT',
    title: 'Python Developer',
    matchPct: 82,
    timeAgo: '6 hours ago',
    location: 'Remote',
    salary: '80k–100k BDT',
  ),
  _MatchCard(
    company: 'Shohoz',
    title: 'Backend Engineer',
    matchPct: 79,
    timeAgo: '1 day ago',
    location: 'Dhaka',
    salary: '90k–110k BDT',
  ),
  _MatchCard(
    company: 'Nagad',
    title: 'BI Developer',
    matchPct: 76,
    timeAgo: '1 day ago',
    location: 'Dhaka',
    salary: '75k–95k BDT',
  ),
  _MatchCard(
    company: 'Robi',
    title: 'Data Engineer',
    matchPct: 74,
    timeAgo: '2 days ago',
    location: 'Chittagong',
    salary: '80k–100k BDT',
  ),
];

const List<_TrendingJob> _trending = [
  _TrendingJob('Data Scientist', 24, '95k–130k BDT', '+42%', ['Python', 'ML', 'SQL']),
  _TrendingJob('ML Engineer', 18, '110k–150k BDT', '+88%', ['PyTorch', 'Python']),
  _TrendingJob('Product Manager', 31, '100k–140k BDT', '+22%', ['Agile', 'Roadmapping']),
];

const List<String> _allSkills = [
  'Python', 'SQL', 'Machine Learning', 'React', 'Node.js', 'AWS', 'Excel',
  'Power BI', 'Tableau', 'Java', 'C++', 'Data Visualization', 'SEO',
  'Google Ads', 'Market Research', 'Risk Analysis', 'Supply Chain',
  'Financial Modeling', 'Content Writing', 'Social Media',
];

const List<String> _allCities = [
  'Dhaka', 'Chittagong', 'Sylhet', 'Rajshahi', 'Khulna', 'Comilla',
  'Barishal', 'Remote',
];

const List<String> _jobTitles = [
  'Data Scientist', 'Software Engineer', 'Data Analyst', 'ML Engineer',
  'Product Manager', 'Financial Analyst', 'UX/UI Designer',
  'Digital Marketing Specialist', 'Backend Developer', 'Data Engineer',
];

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

const Map<_AlertFrequency, String> _freqLabel = {
  _AlertFrequency.instant: 'Instant',
  _AlertFrequency.daily: 'Daily Digest',
  _AlertFrequency.weekly: 'Weekly Digest',
};

const Map<_AlertFrequency, IconData> _freqIcon = {
  _AlertFrequency.instant: Icons.notifications_active_rounded,
  _AlertFrequency.daily: Icons.today_rounded,
  _AlertFrequency.weekly: Icons.calendar_view_week_rounded,
};

String _formatSalary(double v) {
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
  return v.toStringAsFixed(0);
}

// ─────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS
// ─────────────────────────────────────────────────────────────────────────────

// NOTE: _primaryBlue removed — use AppTheme.primaryBlue for consistency.

const _darkBg       = Color(0xFF0F172A);
const _darkSurface  = Color(0xFF1E293B);
const _darkCard     = Color(0xFF1E293B);
const _darkBorder   = Color(0xFF334155);
const _lightCard    = Color(0xFFFFFFFF);
const _lightSurface = Color(0xFFF1F5F9);
const _lightBorder  = Color(0xFFE2E8F0);
const _lightBlue    = Color(0xFFEFF6FF);
const _successColor = Color(0xFF16A34A);
const _warningColor = Color(0xFFD97706);
const _errorColor   = Color(0xFFDC2626);
const _purpleColor  = Color(0xFF7C3AED);

// ─────────────────────────────────────────────────────────────────────────────
// CUSTOM PAINTER — SCORE ARC
// ─────────────────────────────────────────────────────────────────────────────

class _ScoreArcPainter extends CustomPainter {
  final double progress;
  final Color arcColor;
  final Color trackColor;

  const _ScoreArcPainter({
    required this.progress,
    required this.arcColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 3;
    const stroke = 4.0;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..strokeWidth = stroke
        ..style = PaintingStyle.stroke,
    );

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        Paint()
          ..color = arcColor
          ..strokeWidth = stroke
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_ScoreArcPainter old) =>
      old.progress != progress || old.arcColor != arcColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class JobAlertsScreen extends StatefulWidget {
  const JobAlertsScreen({super.key});

  @override
  State<JobAlertsScreen> createState() => _JobAlertsScreenState();
}

class _JobAlertsScreenState extends State<JobAlertsScreen> {
  late List<_JobAlert> _alerts;
  late List<_MatchCard> _matches;

  String     _alertSearch = '';
  _AlertSort _alertSort   = _AlertSort.matchCount;
  _MatchFilter _matchFilter = const _MatchFilter();

  @override
  void initState() {
    super.initState();
    _alerts  = _buildAlerts();
    _matches = _buildMatches();
  }

  // ── Theme — reads global Theme; no local bool, no duplicate toggle ─────────
  //
  // FIX: Previously `bool _isDark = false` was a local state field with its
  // own toggle button, completely disconnected from the app-wide ThemeMode.
  // Now _isDark is a computed getter backed by Theme.of(context) so the
  // screen automatically reflects any global theme change without storing
  // or toggling its own copy.
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  // ── Computed ──────────────────────────────────────────────────────────────

  int get _activeCount => _alerts.where((a) => a.isActive).length;

  int get _newMatchesTotal =>
      _alerts.where((a) => a.isActive).fold(0, (s, a) => s + a.newMatchCount);

  List<_MatchCard> get _visibleMatches =>
      _matches.where((m) => !m.dismissed && _matchFilter.test(m)).toList();

  List<_JobAlert> get _filteredAlerts {
    var list = _alerts.where((a) {
      if (_alertSearch.isEmpty) return true;
      final q = _alertSearch.toLowerCase();
      return a.name.toLowerCase().contains(q) ||
          a.jobTitle.toLowerCase().contains(q);
    }).toList();

    switch (_alertSort) {
      case _AlertSort.matchCount:
        list.sort((a, b) => b.newMatchCount.compareTo(a.newMatchCount));
      case _AlertSort.name:
        list.sort((a, b) => a.name.compareTo(b.name));
      case _AlertSort.activity:
        list.sort((a, b) => b.lastTriggered.compareTo(a.lastTriggered));
    }
    return list;
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void _deleteAlert(String id) {
    HapticFeedback.mediumImpact();
    final alert = _alerts.firstWhere((a) => a.id == id);
    final index = _alerts.indexOf(alert);
    setState(() => _alerts.removeWhere((a) => a.id == id));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Alert "${alert.name}" removed'),
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.white,
          onPressed: () {
            HapticFeedback.selectionClick();
            setState(
                  () => _alerts.insert(math.min(index, _alerts.length), alert),
            );
          },
        ),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _toggleAlert(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      final a = _alerts.firstWhere((a) => a.id == id);
      a.isActive = !a.isActive;
    });
  }

  void _dismissMatch(_MatchCard m) {
    HapticFeedback.lightImpact();
    setState(() => m.dismissed = true);
  }

  void _markAllRead() {
    HapticFeedback.mediumImpact();
    setState(() {
      for (final m in _matches) {
        m.dismissed = true;
      }
    });
  }

  void _cycleSort() {
    HapticFeedback.selectionClick();
    setState(() {
      const vals = _AlertSort.values;
      _alertSort = vals[(_alertSort.index + 1) % vals.length];
    });
  }

  void _showCreateSheet() => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CreateAlertSheet(
      isDark: _isDark,
      onSave: (alert) {
        setState(() => _alerts.add(alert));
        Navigator.pop(context);
        HapticFeedback.mediumImpact();
      },
    ),
  );

  void _showEditSheet(_JobAlert alert) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CreateAlertSheet(
      isDark: _isDark,
      existing: alert,
      onSave: (updated) {
        setState(() {
          final idx = _alerts.indexWhere((a) => a.id == updated.id);
          if (idx != -1) _alerts[idx] = updated;
        });
        Navigator.pop(context);
        HapticFeedback.mediumImpact();
      },
    ),
  );

  void _showMatchFilterSheet() => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MatchFilterSheet(
      initial: _matchFilter,
      isDark: _isDark,
      onApply: (filter) {
        setState(() => _matchFilter = filter);
        Navigator.pop(context);
      },
    ),
  );

  // ── Theme helpers ─────────────────────────────────────────────────────────

  Color get _bg      => _isDark ? _darkBg      : const Color(0xFFF8FAFC);
  Color get _card    => _isDark ? _darkCard    : _lightCard;
  Color get _surface => _isDark ? _darkSurface : _lightSurface;
  Color get _border  => _isDark ? _darkBorder  : _lightBorder;
  Color get _text    => _isDark ? Colors.white  : const Color(0xFF0F172A);
  Color get _sub     => _isDark
      ? const Color(0xFF94A3B8)
      : const Color(0xFF64748B);

  Widget _sectionHeader(String title, {String? action, VoidCallback? onAction}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Text(title,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: _text)),
          const Spacer(),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryBlue)),
            ),
        ]),
      );

  Color _companyColor(String company) {
    const colors = [
      _purpleColor,
      Color(0xFF0891B2),
      _warningColor,
      _successColor,
      _errorColor,
      Color(0xFF0284C7),
      Color(0xFFBE185D),
    ];
    return colors[company.hashCode.abs() % colors.length];
  }

  // ── Insights card ─────────────────────────────────────────────────────────

  Widget _buildInsightsCard() {
    final total  = _matches.length;
    final avgPct = total == 0
        ? 0
        : (_matches.fold(0, (s, m) => s + m.matchPct) / total).round();
    final bestPct =
    total == 0 ? 0 : _matches.map((m) => m.matchPct).reduce(math.max);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: _isDark
            ? const []
            : const [
          BoxShadow(
            color: Color(0x0A1565C0),
            blurRadius: 12,
            offset: Offset(0, 3),
          )
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _lightBlue,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.insights_rounded,
                color: AppTheme.primaryBlue, size: 17),
          ),
          const SizedBox(width: 10),
          Text("This Week's Insights",
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: _text)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          _statCell('Active Alerts', '$_activeCount', AppTheme.primaryBlue),
          _statDivider(),
          _statCell('Total Matches', '$total', _successColor),
          _statDivider(),
          _statCell('Avg Score', '$avgPct%', _warningColor),
          _statDivider(),
          _statCell('Best Match', '$bestPct%', _successColor),
        ]),
      ]),
    );
  }

  Widget _statCell(String label, String value, Color color) => Expanded(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(value,
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w800, color: color)),
      const SizedBox(height: 2),
      Text(label,
          style: TextStyle(fontSize: 10, color: _sub),
          textAlign: TextAlign.center,
          maxLines: 2),
    ]),
  );

  Widget _statDivider() => Container(width: 1, height: 36, color: _border);

  // ── Search + sort bar ─────────────────────────────────────────────────────

  Widget _buildSearchSortBar() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(children: [
      Expanded(
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: TextField(
            onChanged: (v) => setState(() => _alertSearch = v),
            style: TextStyle(color: _text, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search alerts…',
              hintStyle:
              TextStyle(color: _sub.withValues(alpha: 0.7), fontSize: 13),
              prefixIcon:
              Icon(Icons.search_rounded, color: _sub, size: 19),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: _cycleSort,
        child: AnimatedContainer(
          duration: 200.ms,
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primaryBlue.withValues(alpha: 0.45),
              width: 1.5,
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.sort_rounded,
                color: AppTheme.primaryBlue, size: 16),
            const SizedBox(width: 6),
            Text(_alertSort.label,
                style: const TextStyle(
                    color: AppTheme.primaryBlue,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    ]),
  );

  // ── Filter chip bar ───────────────────────────────────────────────────────

  Widget _buildFilterChipBar() {
    if (!_matchFilter.isActive) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Row(children: [
        const Icon(Icons.filter_alt_rounded, color: AppTheme.primaryBlue, size: 14),
        const SizedBox(width: 6),
        if (_matchFilter.minMatchPct > 0)
          _activeChip('≥${_matchFilter.minMatchPct}% match'),
        if (_matchFilter.locationFilter != null)
          _activeChip(_matchFilter.locationFilter!),
        const Spacer(),
        GestureDetector(
          onTap: () => setState(() => _matchFilter = const _MatchFilter()),
          child: const Text('Clear',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _errorColor)),
        ),
      ]),
    );
  }

  Widget _activeChip(String label) => Container(
    margin: const EdgeInsets.only(right: 6),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(100),
      border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.35)),
    ),
    child: Text(label,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryBlue)),
  );

  // ── Empty states ──────────────────────────────────────────────────────────

  Widget _emptyAlerts() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    padding: const EdgeInsets.symmetric(vertical: 40),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _border),
    ),
    child: Column(children: [
      Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: _lightBlue,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.add_alert_outlined,
            color: AppTheme.primaryBlue, size: 32),
      ),
      const SizedBox(height: 16),
      Text('No alerts yet',
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700, color: _text)),
      const SizedBox(height: 6),
      Text(
        'Create your first alert to get notified\nof matching jobs instantly',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: _sub),
      ),
      const SizedBox(height: 20),
      GestureDetector(
        onTap: _showCreateSheet,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue,
            borderRadius: BorderRadius.circular(100),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add_rounded, color: Colors.white, size: 16),
            SizedBox(width: 6),
            Text('Create Alert',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    ]),
  );

  Widget _emptyMatches() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    padding: const EdgeInsets.symmetric(vertical: 36),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.inbox_outlined,
            size: 40, color: _sub.withValues(alpha: 0.4)),
        const SizedBox(height: 12),
        Text(
          _matchFilter.isActive
              ? 'No matches for current filters'
              : 'No new matches yet',
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: _sub),
        ),
        if (_matchFilter.isActive) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () =>
                setState(() => _matchFilter = const _MatchFilter()),
            child: const Text('Clear filters',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryBlue)),
          ),
        ],
      ],
    ),
  );

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final vm     = _visibleMatches;
    final alerts = _filteredAlerts;

    // _isDark is now a getter — no local state, reads Theme.of(context).
    // The AppBar no longer carries a dark-mode toggle; the global toggle
    // in main_nav / the app shell handles theme switching for the entire app.
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _isDark ? _darkSurface : Colors.white,
        foregroundColor: _isDark ? Colors.white : const Color(0xFF0F172A),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: _border.withValues(alpha: 0.5),
        leading: const BackButton(),
        title: Text('Job Alerts',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: _isDark ? Colors.white : const Color(0xFF0F172A))),
        // FIX: Dark toggle removed from here — use the global theme button.
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSheet,
        backgroundColor: AppTheme.primaryBlue,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add_alert_rounded, color: Colors.white),
        label: const Text('New Alert',
            style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
      ),
      body: CustomScrollView(
        slivers: [
          // ── Hero Banner ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A5F), AppTheme.primaryBlue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_activeCount Active Alert${_activeCount != 1 ? 's' : ''}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        const Text('Monitoring your job market 24/7',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                  Icons.notifications_active_rounded,
                                  color: Colors.white,
                                  size: 16),
                              const SizedBox(width: 6),
                              Text(
                                '$_newMatchesTotal new matches today ✨',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.notifications_active_rounded,
                        color: Colors.white60, size: 32),
                  ),
                ]),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.06, end: 0),
            ),
          ),

          // ── Insights Card ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _buildInsightsCard()
                .animate()
                .fadeIn(delay: 100.ms, duration: 350.ms)
                .slideY(begin: 0.05, end: 0),
          ),

          // ── My Alerts ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                _sectionHeader('My Alerts',
                    action: 'New Alert', onAction: _showCreateSheet),
                const SizedBox(height: 10),
                _buildSearchSortBar(),
                const SizedBox(height: 10),
                if (alerts.isEmpty)
                  _emptyAlerts()
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: alerts.asMap().entries.map((e) {
                        final alert = e.value;
                        return Dismissible(
                          key: ValueKey('alert_${alert.id}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: _errorColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.delete_rounded,
                                    color: Colors.white, size: 24),
                                SizedBox(height: 4),
                                Text('Delete',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                          onDismissed: (_) => _deleteAlert(alert.id),
                          child: _AlertRow(
                            alert: alert,
                            isDark: _isDark,
                            card: _card,
                            border: _border,
                            surface: _surface,
                            text: _text,
                            sub: _sub,
                            onToggle: () => _toggleAlert(alert.id),
                            onEdit: () => _showEditSheet(alert),
                            onDelete: () => _deleteAlert(alert.id),
                          )
                              .animate()
                              .fadeIn(delay: (e.key * 80).ms)
                              .slideY(begin: 0.05, end: 0),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),

          // ── Recent Matches ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                _sectionHeader('Recent Matches',
                    action: vm.isNotEmpty ? 'Mark All Read' : null,
                    onAction: _markAllRead),
                const SizedBox(height: 8),
                // Filter row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    GestureDetector(
                      onTap: _showMatchFilterSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: _matchFilter.isActive
                              ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                              : _card,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                              color: _matchFilter.isActive
                                  ? AppTheme.primaryBlue.withValues(alpha: 0.5)
                                  : _border),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.tune_rounded,
                              color: _matchFilter.isActive
                                  ? AppTheme.primaryBlue
                                  : _sub,
                              size: 14),
                          const SizedBox(width: 5),
                          Text('Filter',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _matchFilter.isActive
                                      ? AppTheme.primaryBlue
                                      : _sub)),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_matchFilter.isActive)
                      Expanded(child: _buildFilterChipBar()),
                  ]),
                ),
                const SizedBox(height: 10),
                if (vm.isEmpty)
                  _emptyMatches()
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: vm.asMap().entries.map((e) {
                        final match = e.value;
                        return Dismissible(
                          key: ValueKey('match_${e.key}_${match.company}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: _errorColor,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.delete_rounded,
                                color: Colors.white, size: 24),
                          ),
                          onDismissed: (_) => _dismissMatch(match),
                          child: _MatchRow(
                            match: match,
                            isDark: _isDark,
                            card: _card,
                            border: _border,
                            text: _text,
                            sub: _sub,
                            companyColor: _companyColor(match.company),
                          ).animate().fadeIn(delay: (e.key * 60).ms),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),

          // ── Trending ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                _sectionHeader('🔥 Trending This Week'),
                const SizedBox(height: 10),
                SizedBox(
                  height: 194,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _trending.length,
                    itemBuilder: (_, i) => _TrendingRow(
                      job: _trending[i],
                      isDark: _isDark,
                      card: _card,
                      border: _border,
                      text: _text,
                      sub: _sub,
                      onSetAlert: _showCreateSheet,
                    ).animate().fadeIn(delay: (i * 100).ms),
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ALERT ROW
// ─────────────────────────────────────────────────────────────────────────────

class _AlertRow extends StatelessWidget {
  final _JobAlert alert;
  final bool isDark;
  final Color card, border, surface, text, sub;
  final VoidCallback onToggle, onEdit, onDelete;

  const _AlertRow({
    required this.alert,
    required this.isDark,
    required this.card,
    required this.border,
    required this.surface,
    required this.text,
    required this.sub,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  String get _lastLabel {
    final diff = DateTime.now().difference(alert.lastTriggered);
    if (!alert.isActive) return 'Alert paused';
    if (alert.newMatchCount == 0) return 'No new matches recently';
    if (diff.inHours < 1) {
      return '${alert.newMatchCount} new match${alert.newMatchCount != 1 ? 'es' : ''} just now';
    }
    if (diff.inHours < 24) {
      return '${alert.newMatchCount} new match${alert.newMatchCount != 1 ? 'es' : ''} ${diff.inHours}h ago';
    }
    return '${alert.newMatchCount} new match${alert.newMatchCount != 1 ? 'es' : ''} ${diff.inDays}d ago';
  }

  Widget _iconContainer(Color bg, Color iconColor, bool pulse) {
    final child = Container(
      width: 40,
      height: 40,
      decoration:
      BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Icon(Icons.notifications_rounded, color: iconColor, size: 20),
    );
    if (pulse) {
      return child
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
        begin: const Offset(1.0, 1.0),
        end: const Offset(1.1, 1.1),
        duration: 900.ms,
        curve: Curves.easeInOut,
      );
    }
    return child;
  }

  @override
  Widget build(BuildContext context) {
    final isActive = alert.isActive;
    final hasPulse = isActive && alert.newMatchCount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? AppTheme.primaryBlue.withValues(alpha: 0.35)
              : border,
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: isDark
            ? const []
            : [
          BoxShadow(
            color: isActive
                ? AppTheme.primaryBlue.withValues(alpha: 0.06)
                : const Color(0x08000000),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Row 1: icon + name + switch
          Row(children: [
            _iconContainer(
              isActive
                  ? _lightBlue
                  : isDark
                  ? const Color(0xFF0F172A)
                  : const Color(0xFFF8FAFC),
              isActive ? AppTheme.primaryBlue : sub,
              hasPulse,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(alert.name,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: text)),
                  if (hasPulse)
                    Row(children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: const BoxDecoration(
                            color: _successColor, shape: BoxShape.circle),
                      ),
                      Text(
                        '${alert.newMatchCount} new match${alert.newMatchCount != 1 ? 'es' : ''}',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _successColor),
                      ),
                    ]),
                ],
              ),
            ),
            Switch(
              value: isActive,
              onChanged: (_) => onToggle(),
              activeThumbColor: Colors.white,
              activeTrackColor: AppTheme.primaryBlue,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor:
              isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
            ),
          ]),

          const SizedBox(height: 10),

          // Row 2: criteria chips
          Wrap(spacing: 6, runSpacing: 6, children: [
            _cChip(Icons.work_outline_rounded, alert.jobTitle),
            _cChip(Icons.location_on_outlined, alert.location),
            _cChip(
              Icons.payments_outlined,
              '${_formatSalary(alert.minSalary)}–${_formatSalary(alert.maxSalary)} BDT',
            ),
            ...alert.skills.take(3).map((s) => _cChip(Icons.code_rounded, s)),
            _cChip(_freqIcon[alert.frequency]!, _freqLabel[alert.frequency]!),
          ]),

          const SizedBox(height: 10),

          // Row 3: last triggered + actions
          Row(children: [
            Icon(Icons.history_rounded, color: sub, size: 13),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                _lastLabel,
                style: TextStyle(
                    fontSize: 11,
                    color: sub,
                    fontWeight:
                    hasPulse ? FontWeight.w600 : FontWeight.normal),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _iconAction(Icons.edit_outlined, sub, onEdit),
            _iconAction(Icons.delete_outline_rounded, _errorColor, onDelete),
          ]),
        ]),
      ),
    );
  }

  Widget _cChip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      border: Border.all(color: border),
      borderRadius: BorderRadius.circular(100),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: sub, size: 12),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: sub)),
    ]),
  );

  Widget _iconAction(IconData icon, Color color, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: color),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// MATCH ROW
// ─────────────────────────────────────────────────────────────────────────────

class _MatchRow extends StatelessWidget {
  final _MatchCard match;
  final bool isDark;
  final Color card, border, text, sub, companyColor;

  const _MatchRow({
    required this.match,
    required this.isDark,
    required this.card,
    required this.border,
    required this.text,
    required this.sub,
    required this.companyColor,
  });

  @override
  Widget build(BuildContext context) {
    final pct      = match.matchPct;
    final isHigh   = pct >= 85;
    final isMed    = pct >= 70;
    final scoreFg  = isHigh
        ? _successColor
        : (isMed ? _warningColor : _errorColor);
    final progress = pct / 100.0;
    final initials = match.company
        .substring(0, match.company.length >= 2 ? 2 : 1)
        .toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: isDark
            ? const []
            : const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            // Company avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: companyColor,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Center(
                child: Text(initials,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(match.title,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: text),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    // Animated score arc
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: CustomPaint(
                        painter: _ScoreArcPainter(
                          progress: progress,
                          arcColor: scoreFg,
                          trackColor: border,
                        ),
                        child: Center(
                          child: Text(
                            '$pct%',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: scoreFg),
                          ),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text(match.company,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: sub)),
                    Text(' · ', style: TextStyle(fontSize: 12, color: sub)),
                    Text(match.timeAgo,
                        style: TextStyle(fontSize: 12, color: sub)),
                  ]),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _chip(match.location, _lightBlue, AppTheme.primaryBlue),
            const SizedBox(width: 6),
            _chip(
              match.salary,
              isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              sub,
            ),
            const Spacer(),
            GestureDetector(
              onTap: () {},
              child: const Text('View Job →',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryBlue)),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _chip(String label, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration:
    BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
    child: Text(label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// TRENDING ROW
// ─────────────────────────────────────────────────────────────────────────────

class _TrendingRow extends StatelessWidget {
  final _TrendingJob job;
  final bool isDark;
  final Color card, border, text, sub;
  final VoidCallback onSetAlert;

  const _TrendingRow({
    required this.job,
    required this.isDark,
    required this.card,
    required this.border,
    required this.text,
    required this.sub,
    required this.onSetAlert,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.trending_up_rounded, color: _successColor, size: 16),
          const SizedBox(width: 4),
          Text('${job.companyCount} openings',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _successColor)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: _successColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(job.growth,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _successColor)),
          ),
        ]),
        const SizedBox(height: 8),
        Text(job.title,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: text),
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text('Avg ${job.avgSalary}/mo',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryBlue)),
        const SizedBox(height: 8),
        // Skill demand tags
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: job.topSkills.map((s) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(s, style: TextStyle(fontSize: 10, color: sub)),
            );
          }).toList(),
        ),
        const Spacer(),
        GestureDetector(
          onTap: onSetAlert,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: _lightBlue,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.4)),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add_alert_rounded,
                  color: AppTheme.primaryBlue, size: 14),
              SizedBox(width: 4),
              Text('Set Alert',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryBlue)),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MATCH FILTER SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _MatchFilterSheet extends StatefulWidget {
  final _MatchFilter initial;
  final bool isDark;
  final void Function(_MatchFilter) onApply;

  const _MatchFilterSheet({
    required this.initial,
    required this.isDark,
    required this.onApply,
  });

  @override
  State<_MatchFilterSheet> createState() => _MatchFilterSheetState();
}

class _MatchFilterSheetState extends State<_MatchFilterSheet> {
  late double _minMatch;
  late String? _location;

  bool  get _isDark  => widget.isDark;
  Color get _card    => _isDark ? _darkCard   : _lightCard;
  Color get _border  => _isDark ? _darkBorder : _lightBorder;
  Color get _text    => _isDark ? Colors.white : const Color(0xFF0F172A);
  Color get _sub     => _isDark
      ? const Color(0xFF94A3B8)
      : const Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _minMatch = widget.initial.minMatchPct.toDouble();
    _location = widget.initial.locationFilter;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 20),
          Text('Filter Matches',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: _text)),
          const SizedBox(height: 4),
          Text('Show only matches that meet your criteria',
              style: TextStyle(fontSize: 13, color: _sub)),
          const SizedBox(height: 24),

          // Min match score
          Row(children: [
            Text('Minimum Match Score',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: _sub)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text('${_minMatch.round()}%',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryBlue)),
            ),
          ]),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppTheme.primaryBlue,
              thumbColor: AppTheme.primaryBlue,
              inactiveTrackColor: _border,
              overlayColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
              trackHeight: 4,
            ),
            child: Slider(
              value: _minMatch,
              min: 0,
              max: 100,
              divisions: 20,
              onChanged: (v) => setState(() => _minMatch = v),
            ),
          ),
          Row(children: [
            Text('Any', style: TextStyle(fontSize: 11, color: _sub)),
            const Spacer(),
            Text('100%', style: TextStyle(fontSize: 11, color: _sub)),
          ]),

          const SizedBox(height: 20),

          // Location
          Text('Location',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: _sub)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _locChip(null, 'All Locations'),
              ..._allCities.map((c) => _locChip(c, c)),
            ],
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => widget.onApply(_MatchFilter(
                minMatchPct: _minMatch.round(),
                locationFilter: _location,
              )),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Apply Filters',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => widget.onApply(const _MatchFilter()),
              child: Text('Reset Filters',
                  style: TextStyle(color: _sub, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _locChip(String? value, String label) {
    final selected = _location == value;
    return GestureDetector(
      onTap: () => setState(() => _location = value),
      child: AnimatedContainer(
        duration: 180.ms,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryBlue : _card,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
              color: selected ? AppTheme.primaryBlue : _border),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : _sub)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CREATE / EDIT SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _CreateAlertSheet extends StatefulWidget {
  final _JobAlert? existing;
  final bool isDark;
  final void Function(_JobAlert) onSave;

  const _CreateAlertSheet({
    this.existing,
    required this.isDark,
    required this.onSave,
  });

  @override
  State<_CreateAlertSheet> createState() => _CreateAlertSheetState();
}

class _CreateAlertSheetState extends State<_CreateAlertSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _titleCtrl;
  late String _location;
  late Set<String> _selectedSkills;
  late double _minSalary;
  late double _maxSalary;
  late _AlertFrequency _frequency;

  bool _showTitleDropdown = false;
  List<String> _titleSuggestions = [];

  bool  get _isDark   => widget.isDark;
  Color get _card     => _isDark ? _darkCard    : _lightCard;
  Color get _surface  => _isDark ? _darkSurface : _lightSurface;
  Color get _border   => _isDark ? _darkBorder  : _lightBorder;
  Color get _text     => _isDark ? Colors.white  : const Color(0xFF0F172A);
  Color get _sub      => _isDark
      ? const Color(0xFF94A3B8)
      : const Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    final e        = widget.existing;
    _nameCtrl      = TextEditingController(text: e?.name ?? '');
    _titleCtrl     = TextEditingController(text: e?.jobTitle ?? '');
    _location      = e?.location ?? 'Dhaka';
    _selectedSkills = Set.from(e?.skills ?? []);
    _minSalary     = e?.minSalary ?? 40000;
    _maxSalary     = e?.maxSalary ?? 200000;
    _frequency     = e?.frequency ?? _AlertFrequency.instant;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  void _onTitleChanged(String v) {
    setState(() {
      _titleSuggestions = _jobTitles
          .where(
              (t) => t.toLowerCase().contains(v.toLowerCase()) && v.isNotEmpty)
          .take(4)
          .toList();
      _showTitleDropdown = _titleSuggestions.isNotEmpty;
    });
  }

  void _saveAlert() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      HapticFeedback.heavyImpact();
      return;
    }
    if (_minSalary >= _maxSalary) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Min salary must be less than max salary'),
        backgroundColor: _errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
      return;
    }
    final alert = _JobAlert(
      id: widget.existing?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name:          _nameCtrl.text.trim(),
      jobTitle:      _titleCtrl.text.trim(),
      skills:        _selectedSkills.toList(),
      location:      _location,
      minSalary:     _minSalary,
      maxSalary:     _maxSalary,
      frequency:     _frequency,
      isActive:      widget.existing?.isActive ?? true,
      lastTriggered: widget.existing?.lastTriggered ?? DateTime.now(),
      newMatchCount: widget.existing?.newMatchCount ?? 0,
    );
    widget.onSave(alert);
  }

  InputDecoration _inputDec(String label, {String? hint, IconData? icon}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, color: _sub, size: 20) : null,
        filled: true,
        fillColor: _surface,
        labelStyle: TextStyle(color: _sub, fontSize: 13),
        hintStyle:
        TextStyle(color: _sub.withValues(alpha: 0.6), fontSize: 13),
        errorStyle: const TextStyle(
            color: _errorColor, fontSize: 11, height: 1.2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          const BorderSide(color: AppTheme.primaryBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _errorColor, width: 1.5),
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t,
        style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: _sub)),
  );

  Widget _buildNotifPreview() {
    if (_nameCtrl.text.isEmpty || _titleCtrl.text.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.preview_rounded, color: _sub, size: 13),
          const SizedBox(width: 5),
          Text('Notification Preview',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: _sub)),
        ]),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.work_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('SkillBridge',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _text)),
                  const Spacer(),
                  Text('now', style: TextStyle(fontSize: 10, color: _sub)),
                ]),
                Text('New ${_titleCtrl.text} match! 🎯',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _text)),
                Text(
                  '$_location · ৳${_formatSalary(_minSalary)}–${_formatSalary(_maxSalary)}/mo',
                  style: TextStyle(fontSize: 10, color: _sub),
                ),
              ],
            ),
          ),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: _border,
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 20),

              // Header
              Text(isEdit ? 'Edit Alert' : 'Create Job Alert',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _text)),
              const SizedBox(height: 4),
              Text("We'll notify you when matching jobs are posted",
                  style: TextStyle(fontSize: 13, color: _sub)),
              const SizedBox(height: 20),

              // Alert name
              TextFormField(
                controller: _nameCtrl,
                onChanged: (_) => setState(() {}),
                validator: (v) =>
                (v?.trim().isEmpty ?? true) ? 'Alert name is required' : null,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                style: TextStyle(color: _text, fontSize: 14),
                decoration: _inputDec('Alert Name',
                    hint: 'e.g. Data Science in Dhaka',
                    icon: Icons.label_outline_rounded),
              ),
              const SizedBox(height: 12),

              // Job title
              TextFormField(
                controller: _titleCtrl,
                onChanged: (v) {
                  _onTitleChanged(v);
                  setState(() {});
                },
                validator: (v) =>
                (v?.trim().isEmpty ?? true) ? 'Job title is required' : null,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                style: TextStyle(color: _text, fontSize: 14),
                decoration: _inputDec('Job Title',
                    hint: 'e.g. Data Analyst',
                    icon: Icons.work_outline_rounded),
              ),
              if (_showTitleDropdown) ...[
                const SizedBox(height: 4),
                Container(
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Column(
                    children: _titleSuggestions.map((t) {
                      return InkWell(
                        onTap: () {
                          _titleCtrl.text = t;
                          setState(() => _showTitleDropdown = false);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child: Row(children: [
                            const Icon(Icons.search_rounded,
                                color: AppTheme.primaryBlue, size: 15),
                            const SizedBox(width: 10),
                            Text(t,
                                style:
                                TextStyle(fontSize: 13, color: _text)),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // Skills
              _label('Skills (optional)'),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _allSkills.map((s) {
                    final sel = _selectedSkills.contains(s);
                    return GestureDetector(
                      onTap: () => setState(() {
                        sel
                            ? _selectedSkills.remove(s)
                            : _selectedSkills.add(s);
                      }),
                      child: AnimatedContainer(
                        duration: 180.ms,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: sel ? AppTheme.primaryBlue : _card,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                              color:
                              sel ? AppTheme.primaryBlue : _border),
                        ),
                        child: Text(s,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: sel ? Colors.white : _sub)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),

              // Location
              _label('Location'),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _location,
                    isExpanded: true,
                    dropdownColor: _card,
                    style: TextStyle(color: _text, fontSize: 14),
                    icon: Icon(Icons.keyboard_arrow_down_rounded,
                        color: _sub),
                    items: _allCities
                        .map((c) =>
                        DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _location = v!),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Salary range (dual thumb)
              Row(children: [
                Expanded(child: _label('Salary Range (BDT/month)')),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    '৳${_formatSalary(_minSalary)} – ৳${_formatSalary(_maxSalary)}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryBlue),
                  ),
                ),
              ]),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: AppTheme.primaryBlue,
                  thumbColor: AppTheme.primaryBlue,
                  inactiveTrackColor: _border,
                  overlayColor:
                  AppTheme.primaryBlue.withValues(alpha: 0.1),
                  rangeThumbShape: const RoundRangeSliderThumbShape(
                      enabledThumbRadius: 9),
                  trackHeight: 4,
                ),
                child: RangeSlider(
                  values: RangeValues(_minSalary, _maxSalary),
                  min: 0,
                  max: 500000,
                  divisions: 50,
                  onChanged: (vals) => setState(() {
                    _minSalary = vals.start;
                    _maxSalary = vals.end;
                  }),
                ),
              ),
              const SizedBox(height: 12),

              // Frequency
              _label('Notification Frequency'),
              Row(
                children: _AlertFrequency.values.asMap().entries.map((e) {
                  final f      = e.value;
                  final sel    = _frequency == f;
                  final isLast =
                      e.key == _AlertFrequency.values.length - 1;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _frequency = f),
                      child: AnimatedContainer(
                        duration: 200.ms,
                        margin: EdgeInsets.only(right: isLast ? 0 : 8),
                        padding:
                        const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: sel ? _lightBlue : _card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: sel ? AppTheme.primaryBlue : _border,
                            width: sel ? 2 : 1,
                          ),
                        ),
                        child: Column(children: [
                          Icon(_freqIcon[f]!,
                              color: sel ? AppTheme.primaryBlue : _sub,
                              size: 20),
                          const SizedBox(height: 4),
                          Text(
                            _freqLabel[f]!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: sel
                                    ? AppTheme.primaryBlue
                                    : _text),
                          ),
                        ]),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // Notification preview
              AnimatedSize(
                duration: 300.ms,
                curve: Curves.easeOut,
                child: _buildNotifPreview(),
              ),
              if (_nameCtrl.text.isNotEmpty &&
                  _titleCtrl.text.isNotEmpty)
                const SizedBox(height: 16),

              // Save button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saveAlert,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  child: Text(
                    isEdit ? 'Update Alert ✓' : 'Create Alert 🔔',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _sub,
                    side: BorderSide(color: _border),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}