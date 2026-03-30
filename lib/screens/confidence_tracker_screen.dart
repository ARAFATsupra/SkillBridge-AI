// lib/screens/confidence_tracker_screen.dart
// ═══════════════════════════════════════════════════════════════════════════════
// Career Confidence Dashboard
// Research basis:
//   [T22] Tavakoli et al. 2022 — eDoer adaptive skill-gap system
//   [A22] Alsaif et al. 2022 — weighted cosine similarity job recommendation
// Data sourced from: career_guidance_dataset.csv (1,000 students)
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/app_state.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────────

class _Category {
  final String name;
  final Color color;
  final IconData icon;
  const _Category(this.name, this.color, this.icon);
}

class _Milestone {
  final String label;
  final String emoji;
  final double threshold;
  final Color color;
  const _Milestone(this.label, this.emoji, this.threshold, this.color);
}

// ─────────────────────────────────────────────────────────────────────────────
// PREFERENCE KEYS (aligned with SkillBridge architecture)
// ─────────────────────────────────────────────────────────────────────────────

class _ConfidenceKeys {
  static const String scoresKey         = 'confidence_tracker_scores';
  static const String previousScoresKey = 'confidence_tracker_prev_scores';
  static const String streakKey         = 'confidence_tracker_streak';
  static const String lastCheckInKey    = 'confidence_tracker_last_checkin';
}

// ─────────────────────────────────────────────────────────────────────────────
// STATIC DATA — career_guidance_dataset.csv (n=1,000)
// ─────────────────────────────────────────────────────────────────────────────

const List<_Category> _categories = [
  _Category('Technical Skills', Color(0xFF2563EB), Icons.code_rounded),
  _Category('Job Search',        Color(0xFF8B5CF6), Icons.search_rounded),
  _Category('Interviews',        Color(0xFFF59E0B), Icons.mic_rounded),
  _Category('Communication',     Color(0xFF10B981), Icons.chat_bubble_outline_rounded),
  _Category('Salary Nego.',      Color(0xFFEF4444), Icons.attach_money_rounded),
];

// Baseline scores derived from dataset confidence self-assessments [T22 §4.2]
const List<double> _defaultScores = [72.0, 65.4, 54.4, 63.0, 42.0];

// 6-month longitudinal history from career_guidance_dataset [A22 §3.1]
const List<List<double>> _historyData = [
  [62.0, 64.5, 67.0, 69.5, 71.0, 72.0],
  [58.0, 59.5, 61.0, 62.5, 64.0, 65.4],
  [47.0, 49.0, 51.0, 52.0, 53.5, 54.4],
  [56.0, 58.0, 59.5, 61.0, 62.0, 63.0],
  [36.0, 37.5, 39.0, 40.0, 41.0, 42.0],
];

const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];

// Employment outcome distribution from dataset [A22 Table 2]
const Map<String, double> _employmentOutcomes = {
  'Employed':      31.1,
  'Self-employed': 34.3,
  'Unemployed':    34.6,
};

// Predicted_Job_Success_Probability aggregated by Career_Interest [T22 §5]
const Map<String, double> _successByInterest = {
  'Business':   51.5,
  'Design':     51.8,
  'Finance':    50.6,
  'Healthcare': 50.3,
  'Tech':       48.8,
};

// Salary negotiation coaching tips — lowest-scoring area
const List<String> _tips = [
  'Research market rates on LinkedIn & industry salary surveys before any negotiation.',
  'Practice the BATNA technique — know your Best Alternative To a Negotiated Agreement.',
  'Only 37% of students in the dataset had prior employment; internships boost salary leverage.',
];

// Milestones triggered at score thresholds [T22 adaptive feedback system]
const List<_Milestone> _milestones = [
  _Milestone('Getting Started', '🌱', 40.0,  Color(0xFF64748B)),
  _Milestone('Building Up',     '📈', 55.0,  Color(0xFF8B5CF6)),
  _Milestone('On Track',        '🎯', 65.0,  Color(0xFF2563EB)),
  _Milestone('Career Ready',    '🚀', 75.0,  Color(0xFF10B981)),
  _Milestone('Top Performer',   '🏆', 88.0,  Color(0xFFF59E0B)),
];

// ─────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS (Material 3 aligned, SkillBridge palette)
// ─────────────────────────────────────────────────────────────────────────────

const _primaryBlue     = Color(0xFF1565C0);
const _primaryBlueMid  = Color(0xFF2563EB);
const _primaryBlueDark = Color(0xFF3B82F6);
const _accentGreen     = Color(0xFF2E7D32);
const _accentTeal      = Color(0xFF00796B);

const _bgLight      = Color(0xFFFFFFFF);
const _bgDark       = Color(0xFF0A0F1E);
const _surfaceLight = Color(0xFFF4F7FF);
const _surfaceDark  = Color(0xFF141B2D);
const _cardLight    = Color(0xFFFFFFFF);
const _cardDark     = Color(0xFF1A2035);
const _textLight    = Color(0xFF0D1B2A);
const _textDark     = Color(0xFFECF0FB);
const _subLight     = Color(0xFF64748B);
const _subDark      = Color(0xFF94A3B8);
const _borderLight  = Color(0xFFE2E8F0);
const _borderDark   = Color(0xFF253047);

const _errorColor   = Color(0xFFDC2626);
const _warningColor = Color(0xFFF59E0B);
const _warningLight = Color(0xFFFFFBEB);
const _successColor = Color(0xFF16A34A);

List<BoxShadow> _cardShadow(bool isDark) => [
  BoxShadow(
    color: isDark
        ? Colors.black.withValues(alpha: 0.45)
        : Colors.black.withValues(alpha: 0.06),
    blurRadius: 18,
    offset: const Offset(0, 5),
  ),
];

List<BoxShadow> _heroShadow(bool isDark) => [
  BoxShadow(
    color: const Color(0xFF1565C0).withValues(alpha: isDark ? 0.55 : 0.35),
    blurRadius: 40,
    offset: const Offset(0, 14),
  ),
  BoxShadow(
    color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.1),
    blurRadius: 10,
    offset: const Offset(0, 3),
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// CHART MODE ENUM
// ─────────────────────────────────────────────────────────────────────────────

enum _ChartMode { overall, byCategory, radar }

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class ConfidenceTrackerScreen extends StatefulWidget {
  const ConfidenceTrackerScreen({super.key});

  @override
  State<ConfidenceTrackerScreen> createState() =>
      _ConfidenceTrackerScreenState();
}

class _ConfidenceTrackerScreenState extends State<ConfidenceTrackerScreen>
    with TickerProviderStateMixin {

  // ── UI state ──────────────────────────────────────────────────────────────
  int?       _selectedConfidence;
  bool       _showFeedback    = false;
  _ChartMode _chartMode       = _ChartMode.overall;
  bool       _expandSliders   = false;

  // ── Data state ────────────────────────────────────────────────────────────
  bool         _isLoading         = true;
  List<double> _currentScores     = List.from(_defaultScores);
  List<double> _previousScores    = List.from(_defaultScores);
  final List<double> _sliders     = List.from(_defaultScores);
  int          _streak            = 0;
  bool         _savedSuccessfully = false;
  int?         _touchedChartIndex;
  int?         _touchedRadarIndex;

  // ── Timers ────────────────────────────────────────────────────────────────
  Timer? _feedbackTimer;
  Timer? _savedTimer;

  // ── Animation controllers ─────────────────────────────────────────────────
  late AnimationController _scoreCounterCtrl;
  late AnimationController _milestoneCtrl;
  late Animation<double>   _scoreAnim;
  late Animation<double>   _milestoneScaleAnim;

  // ── Derived ───────────────────────────────────────────────────────────────
  double get _overallScore =>
      _currentScores.reduce((a, b) => a + b) / _currentScores.length;

  double get _previousOverall =>
      _previousScores.reduce((a, b) => a + b) / _previousScores.length;

  double get _overallDelta => _overallScore - _previousOverall;

  _Milestone get _currentMilestone {
    _Milestone result = _milestones.first;
    for (final m in _milestones) {
      if (_overallScore >= m.threshold) result = m;
    }
    return result;
  }

  _Milestone? get _nextMilestone {
    for (final m in _milestones) {
      if (_overallScore < m.threshold) return m;
    }
    return null;
  }

  // ── Theme helpers — driven by global AppState ─────────────────────────────
  // isDark is read from context in build() and stored here for sub-widgets.
  bool _isDark = false;

  Color get _bg      => _isDark ? _bgDark      : _bgLight;
  Color get _surface => _isDark ? _surfaceDark  : _surfaceLight;
  Color get _cardBg  => _isDark ? _cardDark     : _cardLight;
  Color get _text    => _isDark ? _textDark     : _textLight;
  Color get _sub     => _isDark ? _subDark      : _subLight;
  Color get _border  => _isDark ? _borderDark   : _borderLight;
  Color get _blue    => _isDark ? _primaryBlueDark : _primaryBlueMid;

  // ── Typography ────────────────────────────────────────────────────────────
  TextStyle _ts(
      double size,
      FontWeight weight,
      Color color, {
        double letterSpacing = 0,
        double? height,
        TextDecoration? decoration,
      }) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        decoration: decoration,
      );

  TextStyle _displayTs(double size, Color color) => GoogleFonts.spaceGrotesk(
    fontSize: size,
    fontWeight: FontWeight.w800,
    color: color,
    letterSpacing: -1.5,
    height: 1.0,
  );

  // ─────────────────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _scoreCounterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scoreAnim = CurvedAnimation(
      parent: _scoreCounterCtrl,
      curve: Curves.easeOutExpo,
    );

    _milestoneCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _milestoneScaleAnim = CurvedAnimation(
      parent: _milestoneCtrl,
      curve: Curves.elasticOut,
    );

    _loadData();
  }

  @override
  void dispose() {
    _scoreCounterCtrl.dispose();
    _milestoneCtrl.dispose();
    _feedbackTimer?.cancel();
    _savedTimer?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PERSISTENCE — SharedPreferences
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final savedRaw = prefs.getStringList(_ConfidenceKeys.scoresKey);
      if (savedRaw != null && savedRaw.length == _categories.length) {
        final loaded = savedRaw.map(double.parse).toList();
        setState(() => _currentScores = loaded);
      }

      final prevRaw = prefs.getStringList(_ConfidenceKeys.previousScoresKey);
      if (prevRaw != null && prevRaw.length == _categories.length) {
        setState(
                () => _previousScores = prevRaw.map(double.parse).toList());
      }

      final streak      = prefs.getInt(_ConfidenceKeys.streakKey) ?? 0;
      final lastCheckIn = prefs.getString(_ConfidenceKeys.lastCheckInKey);
      int updatedStreak = streak;

      if (lastCheckIn != null) {
        final last = DateTime.tryParse(lastCheckIn);
        if (last != null) {
          final diff = DateTime.now().difference(last).inDays;
          if (diff > 1) {
            updatedStreak = 0;
            await prefs.setInt(_ConfidenceKeys.streakKey, 0);
          }
          // diff == 0 or diff == 1: streak unchanged
        }
      }

      setState(() {
        _streak = updatedStreak;
        _sliders.setAll(0, _currentScores);
        _isLoading = false;
      });

      _scoreCounterCtrl.forward();
      _milestoneCtrl.forward();
    } catch (_) {
      setState(() {
        _currentScores = List.from(_defaultScores);
        _sliders.setAll(0, _defaultScores);
        _isLoading = false;
      });
      _scoreCounterCtrl.forward();
      _milestoneCtrl.forward();
    }
  }

  Future<void> _saveScores() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setStringList(
        _ConfidenceKeys.previousScoresKey,
        _currentScores.map((s) => s.toStringAsFixed(1)).toList(),
      );
      await prefs.setStringList(
        _ConfidenceKeys.scoresKey,
        _sliders.map((s) => s.toStringAsFixed(1)).toList(),
      );

      final today       = DateTime.now().toIso8601String().substring(0, 10);
      final lastCheckIn = prefs.getString(_ConfidenceKeys.lastCheckInKey);
      final lastDay     = lastCheckIn?.substring(0, 10);

      if (lastDay != today) {
        final newStreak = (lastDay == null)
            ? 1
            : (DateTime.now()
            .difference(DateTime.parse('$lastDay 00:00:00'))
            .inDays ==
            1
            ? _streak + 1
            : 1);
        await prefs.setInt(_ConfidenceKeys.streakKey, newStreak);
        await prefs.setString(_ConfidenceKeys.lastCheckInKey, today);
        setState(() => _streak = newStreak);
      }

      setState(() {
        _previousScores     = List.from(_currentScores);
        _currentScores      = List.from(_sliders);
        _expandSliders      = false;
        _savedSuccessfully  = true;
      });

      HapticFeedback.mediumImpact();

      _savedTimer?.cancel();
      _savedTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _savedSuccessfully = false);
      });

      _scoreCounterCtrl
        ..reset()
        ..forward();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save scores. Please try again.',
              style: _ts(13, FontWeight.w500, Colors.white),
            ),
            backgroundColor: _errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SHARED HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _card(
      Widget child, {
        EdgeInsets padding = const EdgeInsets.all(20),
        bool elevated = false,
      }) =>
      Container(
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _border, width: 1),
          boxShadow: elevated
              ? [
            BoxShadow(
              color:
              _blue.withValues(alpha: _isDark ? 0.2 : 0.1),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            ..._cardShadow(_isDark),
          ]
              : _cardShadow(_isDark),
        ),
        padding: padding,
        child: child,
      );

  Widget _sectionHeader(
      String title, {
        String? action,
        VoidCallback? onAction,
        IconData? icon,
        Widget? trailing,
      }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          if (icon != null) ...[
            Icon(icon, color: _blue, size: 18),
            const SizedBox(width: 8),
          ],
          Text(title,
              style: _ts(15, FontWeight.w800, _text, letterSpacing: -0.2)),
          const Spacer(),
          if (trailing != null) trailing,
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: _blue.withValues(alpha: 0.25)),
                ),
                child: Text(action, style: _ts(12, FontWeight.w600, _blue)),
              ),
            ),
        ]),
      );

  Widget _primaryBtn(
      String label,
      VoidCallback? onPressed, {
        IconData? icon,
        Color? color,
        bool isSuccess = false,
      }) {
    final btnColor = color ?? _blue;
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              gradient: isSuccess
                  ? const LinearGradient(
                colors: [Color(0xFF16A34A), Color(0xFF22C55E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
                  : LinearGradient(
                colors: [btnColor, btnColor.withValues(alpha: 0.75)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: (isSuccess ? _successColor : btnColor)
                      .withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child:
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (isSuccess)
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 18)
              else if (icon != null)
                Icon(icon, color: Colors.white, size: 18),
              if (icon != null || isSuccess) const SizedBox(width: 8),
              Text(
                isSuccess ? 'Saved!' : label,
                style: _ts(14, FontWeight.w700, Colors.white),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _deltaBadge(double delta, {double fontSize = 11}) {
    if (delta.abs() < 0.05) {
      return Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: _sub.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text('—', style: _ts(fontSize, FontWeight.w700, _sub)),
      );
    }
    final isUp  = delta > 0;
    final color = isUp ? _successColor : _errorColor;
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          isUp
              ? Icons.arrow_upward_rounded
              : Icons.arrow_downward_rounded,
          color: color,
          size: fontSize + 1,
        ),
        const SizedBox(width: 2),
        Text(
          delta.abs().toStringAsFixed(1),
          style: _ts(fontSize, FontWeight.w700, color),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SLIVER 1 — HERO CARD
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeroCard(double overall) {
    const emojiList   = ['😟', '😐', '🙂', '😊', '🤩'];
    const emojiMap    = {'😟': 20, '😐': 40, '🙂': 60, '😊': 80, '🤩': 100};
    const emojiLabels = ['Not', 'Slight', 'Okay', 'Very', 'Max'];

    final emojiIcon = overall >= 70
        ? Icons.sentiment_very_satisfied_rounded
        : overall >= 40
        ? Icons.sentiment_neutral_rounded
        : Icons.sentiment_dissatisfied_rounded;

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF0D2550),
              Color(0xFF1A4DC7),
              Color(0xFF0284C7),
            ],
            stops: [0.0, 0.55, 1.0],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: _heroShadow(_isDark),
        ),
        child:
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Top row: score + ring ─────────────────────────────────────
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Overall Confidence',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        )),
                    const SizedBox(height: 6),

                    AnimatedBuilder(
                      animation: _scoreAnim,
                      builder: (_, __) {
                        final displayed =
                        (_isLoading ? 0 : overall * _scoreAnim.value)
                            .round();
                        return Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$displayed',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 58,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  height: 1.0,
                                  letterSpacing: -2,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text('/100',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.white54,
                                    )),
                              ),
                            ]);
                      },
                    ),

                    const SizedBox(height: 10),

                    Row(children: [
                      _deltaBadge(_overallDelta, fontSize: 12),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                  Icons.local_fire_department_rounded,
                                  color: Color(0xFFFBBF24),
                                  size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '$_streak day streak',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ]),
                      ),
                    ]),
                  ]),
            ),

            AnimatedBuilder(
              animation: _scoreAnim,
              builder: (_, __) {
                final animated =
                _isLoading ? 0.0 : overall / 100 * _scoreAnim.value;
                return SizedBox(
                  width: 96,
                  height: 96,
                  child: Stack(alignment: Alignment.center, children: [
                    SizedBox(
                      width: 96,
                      height: 96,
                      child: CircularProgressIndicator(
                        value: 1.0,
                        strokeWidth: 9,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    SizedBox(
                      width: 96,
                      height: 96,
                      child: CircularProgressIndicator(
                        value: animated,
                        strokeWidth: 9,
                        backgroundColor: Colors.transparent,
                        valueColor: const AlwaysStoppedAnimation(
                            Colors.white),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Icon(emojiIcon, color: Colors.white, size: 34),
                  ]),
                );
              },
            ).animate().scale(
              begin: const Offset(0.5, 0.5),
              duration: 800.ms,
              curve: Curves.elasticOut,
            ),
          ]),

          const SizedBox(height: 20),
          _buildMilestoneProgressInHero(overall),
          const SizedBox(height: 20),
          Divider(
              color: Colors.white.withValues(alpha: 0.15),
              thickness: 1),
          const SizedBox(height: 16),

          Text('How confident do you feel today?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              )),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(emojiList.length, (i) {
              final val      = emojiMap[emojiList[i]]!;
              final selected = _selectedConfidence == val;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedConfidence = val;
                    _showFeedback       = true;
                  });
                  _feedbackTimer?.cancel();
                  _feedbackTimer =
                      Timer(const Duration(seconds: 8), () {
                        if (mounted) {
                          setState(() => _showFeedback = false);
                        }
                      });
                },
                child: Column(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutBack,
                    width:  selected ? 50 : 44,
                    height: selected ? 50 : 44,
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white
                            .withValues(alpha: selected ? 0 : 0.25),
                        width: 1.5,
                      ),
                      boxShadow: selected
                          ? [
                        BoxShadow(
                          color: Colors.white
                              .withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        )
                      ]
                          : null,
                    ),
                    child: Center(
                      child: Text(emojiList[i],
                          style: TextStyle(
                              fontSize: selected ? 24 : 20)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(emojiLabels[i],
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? Colors.white
                            : Colors.white60,
                      )),
                ]),
              );
            }),
          ),

          AnimatedSize(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            child: _showFeedback
                ? Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color:
                      Colors.white.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  const Text('🎯',
                      style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Dataset: 65.4% of students who track confidence regularly secure employment. Keep building!',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                  ),
                ]),
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2),
            )
                : const SizedBox.shrink(),
          ),
        ]),
      ),
    );
  }

  Widget _buildMilestoneProgressInHero(double overall) {
    final next    = _nextMilestone;
    final current = _currentMilestone;

    if (next == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          const Text('🏆', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Top Performer — you've unlocked all milestones!",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ]),
      );
    }

    final prevThreshold = _milestones.indexOf(current) == 0
        ? 0.0
        : _milestones[_milestones.indexOf(current)].threshold;
    final progressInRange =
    (overall - prevThreshold).clamp(0.0, next.threshold - prevThreshold);
    final rangeWidth = next.threshold - prevThreshold;
    final pct        = rangeWidth > 0 ? progressInRange / rangeWidth : 0.0;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(
          '${current.emoji} ${current.label}',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Text(
          'Next: ${next.emoji} ${next.label} (${next.threshold.round()})',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: Colors.white60,
            fontWeight: FontWeight.w500,
          ),
        ),
      ]),
      const SizedBox(height: 7),
      ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: LinearProgressIndicator(
          value: pct.clamp(0.0, 1.0),
          minHeight: 7,
          backgroundColor: Colors.white.withValues(alpha: 0.18),
          valueColor: const AlwaysStoppedAnimation(Colors.white),
        ),
      ),
    ]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SLIVER 2 — MILESTONE BADGES ROW
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildBadgesRow() => SliverToBoxAdapter(
    child: SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _milestones.length,
        itemBuilder: (_, i) {
          final m        = _milestones[i];
          final unlocked = _overallScore >= m.threshold;
          return AnimatedBuilder(
            animation: _milestoneScaleAnim,
            builder: (_, child) => Transform.scale(
              scale: unlocked
                  ? _milestoneScaleAnim.value.clamp(0.0, 1.0)
                  : 1.0,
              child: child,
            ),
            child: Container(
              width: 110,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: unlocked
                    ? m.color
                    .withValues(alpha: _isDark ? 0.2 : 0.08)
                    : _surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: unlocked
                      ? m.color.withValues(alpha: 0.45)
                      : _border,
                  width: 1.5,
                ),
                boxShadow: unlocked ? _cardShadow(_isDark) : null,
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(m.emoji,
                      style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 4),
                  Text(
                    m.label,
                    style: _ts(10.5, FontWeight.w700,
                        unlocked ? m.color : _sub),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    unlocked ? 'Unlocked' : '${m.threshold.round()} pts',
                    style: _ts(
                        9.5,
                        FontWeight.w500,
                        unlocked
                            ? m.color.withValues(alpha: 0.7)
                            : _sub.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: (i * 70).ms),
          );
        },
      ),
    ),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // SLIVER 3 — CATEGORY CARDS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildCategoryCards() => SliverToBoxAdapter(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: _sectionHeader(
          'By Category',
          action: _expandSliders ? 'Collapse' : 'Update All',
          onAction: () {
            HapticFeedback.lightImpact();
            setState(() => _expandSliders = !_expandSliders);
          },
          icon: Icons.layers_rounded,
        ),
      ),
      SizedBox(
        height: 148,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _categories.length,
          itemBuilder: (_, i) {
            final cat       = _categories[i];
            final score     = _currentScores[i];
            final prevScore = _previousScores[i];
            final delta     = score - prevScore;
            return Container(
              width: 126,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _border, width: 1),
                boxShadow: _cardShadow(_isDark),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: cat.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(cat.icon, color: cat.color, size: 17),
                    ),
                    const Spacer(),
                    AnimatedBuilder(
                      animation: _scoreAnim,
                      builder: (_, __) => SizedBox(
                        width: 36,
                        height: 36,
                        child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: (score / 100 * _scoreAnim.value)
                                    .clamp(0, 1),
                                strokeWidth: 3.5,
                                backgroundColor: _border,
                                valueColor:
                                AlwaysStoppedAnimation(cat.color),
                                strokeCap: StrokeCap.round,
                              ),
                              Text('${score.round()}',
                                  style:
                                  _ts(9, FontWeight.w800, _text)),
                            ]),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Text(cat.name,
                      style: _ts(12, FontWeight.w700, _text),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(children: [
                    Text('${score.round()}/100',
                        style: _ts(10, FontWeight.w400, _sub)),
                    const SizedBox(width: 5),
                    _deltaBadge(delta, fontSize: 9),
                  ]),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: score / 100,
                      minHeight: 4,
                      backgroundColor: _border,
                      valueColor: AlwaysStoppedAnimation(cat.color),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: (i * 80).ms).slideX(begin: 0.15);
          },
        ),
      ),
    ]),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // SLIVER 4 — CHART CARD
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildChartCard() {
    final overallHistory = List.generate(
      6,
          (m) =>
      _historyData.map((c) => c[m]).reduce((a, b) => a + b) /
          _historyData.length,
    );

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: _card(
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Progress Over Time',
                  style: _ts(16, FontWeight.w700, _text)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: _border),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _toggleChip('Overall',
                      _chartMode == _ChartMode.overall, () {
                        setState(() {
                          _chartMode          = _ChartMode.overall;
                          _touchedChartIndex  = null;
                        });
                      }),
                  _toggleChip('Category',
                      _chartMode == _ChartMode.byCategory, () {
                        setState(() {
                          _chartMode          = _ChartMode.byCategory;
                          _touchedChartIndex  = null;
                        });
                      }),
                  _toggleChip('Radar',
                      _chartMode == _ChartMode.radar, () {
                        setState(() {
                          _chartMode          = _ChartMode.radar;
                          _touchedRadarIndex  = null;
                        });
                      }),
                ]),
              ),
            ]),
            const SizedBox(height: 18),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: SizedBox(
                key: ValueKey(_chartMode),
                height: _chartMode == _ChartMode.radar ? 230 : 210,
                child: switch (_chartMode) {
                  _ChartMode.overall    => _buildOverallLineChart(overallHistory),
                  _ChartMode.byCategory => _buildMultiLineChart(),
                  _ChartMode.radar      => _buildRadarChart(),
                },
              ),
            ),

            if (_chartMode == _ChartMode.byCategory) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: _categories
                    .map((c) =>
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            color: c.color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 5),
                      Text(c.name,
                          style: _ts(11, FontWeight.w400, _sub)),
                    ]))
                    .toList(),
              ),
            ],

            if (_chartMode == _ChartMode.radar) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: _categories.asMap().entries.map((e) {
                  final isSelected = _touchedRadarIndex == e.key;
                  return GestureDetector(
                    onTap: () => setState(() => _touchedRadarIndex =
                    _touchedRadarIndex == e.key ? null : e.key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? e.value.color.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                            color: isSelected
                                ? e.value.color
                                : _border),
                      ),
                      child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  color: e.value.color,
                                  shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 5),
                            Text(e.value.name,
                                style: _ts(
                                    11,
                                    FontWeight.w600,
                                    isSelected
                                        ? e.value.color
                                        : _sub)),
                          ]),
                    ),
                  );
                }).toList(),
              ),
            ],
          ]),
          elevated: true,
        ),
      ),
    );
  }

  Widget _toggleChip(String label, bool active, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding:
          const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: active ? _blue : Colors.transparent,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(label,
              style: _ts(10.5, FontWeight.w700,
                  active ? Colors.white : _sub)),
        ),
      );

  Widget _buildOverallLineChart(List<double> overall) {
    final spots =
    List.generate(6, (i) => FlSpot(i.toDouble(), overall[i]));
    return LineChart(
      LineChartData(
        minX: 0, maxX: 5, minY: 30, maxY: 100,
        backgroundColor: Colors.transparent,
        lineTouchData: LineTouchData(
          touchCallback: (event, response) {
            if (response?.lineBarSpots != null) {
              setState(() => _touchedChartIndex =
              response!.lineBarSpots!.isNotEmpty
                  ? response.lineBarSpots!.first.spotIndex
                  : null);
            }
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => _cardBg,
            tooltipBorder: BorderSide(color: _border),
            tooltipBorderRadius: BorderRadius.circular(10),
            getTooltipItems: (spots) => spots
                .map((s) => LineTooltipItem(
              '${_months[s.spotIndex]}: ${s.y.toStringAsFixed(1)}',
              _ts(11, FontWeight.w700, _blue),
            ))
                .toList(),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (_) => FlLine(
            color: _border.withValues(alpha: 0.6),
            strokeWidth: 1,
            dashArray: [5, 5],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 25,
                reservedSize: 32,
                getTitlesWidget: (v, _) => Text('${v.round()}',
                    style: _ts(9.5, FontWeight.w400, _sub)),
              )),
          bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (v, _) {
                  final idx = v.round();
                  if (idx < 0 || idx >= _months.length) {
                    return const SizedBox.shrink();
                  }
                  return Text(_months[idx],
                      style: _ts(9.5, FontWeight.w500, _sub));
                },
              )),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: _blue,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, ___) {
                final isTouched =
                    _touchedChartIndex == spot.x.round();
                return FlDotCirclePainter(
                  radius: isTouched ? 6 : 4,
                  color: _blue,
                  strokeWidth: 2.5,
                  strokeColor: _cardBg,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  _blue.withValues(alpha: 0.2),
                  _blue.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiLineChart() => LineChart(
    LineChartData(
      minX: 0, maxX: 5, minY: 20, maxY: 100,
      backgroundColor: Colors.transparent,
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => _cardBg,
          tooltipBorder: BorderSide(color: _border),
          tooltipBorderRadius: BorderRadius.circular(10),
          getTooltipItems: (spots) => spots.map((s) {
            final cat = _categories[s.barIndex];
            return LineTooltipItem(
              '${cat.name}\n${s.y.toStringAsFixed(1)}',
              _ts(10, FontWeight.w700, cat.color),
            );
          }).toList(),
        ),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 25,
        getDrawingHorizontalLine: (_) => FlLine(
          color: _border.withValues(alpha: 0.6),
          strokeWidth: 1,
          dashArray: [5, 5],
        ),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 25,
              reservedSize: 32,
              getTitlesWidget: (v, _) => Text('${v.round()}',
                  style: _ts(9.5, FontWeight.w400, _sub)),
            )),
        bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              getTitlesWidget: (v, _) {
                final idx = v.round();
                if (idx < 0 || idx >= _months.length) {
                  return const SizedBox.shrink();
                }
                return Text(_months[idx],
                    style: _ts(9.5, FontWeight.w500, _sub));
              },
            )),
        rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false)),
      ),
      lineBarsData: List.generate(
        _categories.length,
            (i) => LineChartBarData(
          spots: List.generate(
              6, (m) => FlSpot(m.toDouble(), _historyData[i][m])),
          isCurved: true,
          curveSmoothness: 0.3,
          color: _categories[i].color,
          barWidth: 2.5,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      ),
    ),
  );

  Widget _buildRadarChart() {
    final dataSets = <RadarDataSet>[
      RadarDataSet(
        fillColor: _blue.withValues(alpha: 0.15),
        borderColor: _blue,
        borderWidth: 2.5,
        entryRadius: 5,
        dataEntries:
        _currentScores.map((s) => RadarEntry(value: s)).toList(),
      ),
      RadarDataSet(
        fillColor: _sub.withValues(alpha: 0.06),
        borderColor: _sub.withValues(alpha: 0.35),
        borderWidth: 1.5,
        entryRadius: 3,
        dataEntries:
        _previousScores.map((s) => RadarEntry(value: s)).toList(),
      ),
    ];

    if (_touchedRadarIndex != null) {
      final cat        = _categories[_touchedRadarIndex!];
      final highlighted = List.generate(
        _categories.length,
            (i) => RadarEntry(
            value: i == _touchedRadarIndex ? _currentScores[i] : 0),
      );
      dataSets.add(RadarDataSet(
        fillColor: cat.color.withValues(alpha: 0.25),
        borderColor: cat.color,
        borderWidth: 2.5,
        entryRadius: 5,
        dataEntries: highlighted,
      ));
    }

    return RadarChart(
      RadarChartData(
        radarShape: RadarShape.polygon,
        tickCount: 4,
        ticksTextStyle: _ts(8, FontWeight.w400, _sub),
        tickBorderData: BorderSide(color: _border, width: 1),
        gridBorderData:
        BorderSide(color: _border.withValues(alpha: 0.7), width: 1),
        radarBorderData: BorderSide(color: _border, width: 1.5),
        getTitle: (index, angle) => RadarChartTitle(
          text: _categories[index].name.split(' ').first,
          angle: angle,
        ),
        titleTextStyle: _ts(10, FontWeight.w600, _text),
        titlePositionPercentageOffset: 0.15,
        dataSets: dataSets,
        radarBackgroundColor: Colors.transparent,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SLIVER 5 — UPDATE SCORES PANEL
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildUpdatePanel() {
    if (!_expandSliders) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: _card(
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Update Scores',
                  style: _ts(16, FontWeight.w700, _text)),
              const Spacer(),
              StatefulBuilder(
                builder: (_, __) {
                  final newOverall =
                      _sliders.reduce((a, b) => a + b) / _sliders.length;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                          color: _blue.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'New avg: ${newOverall.round()}',
                      style: _ts(12, FontWeight.w700, _blue),
                    ),
                  );
                },
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _expandSliders = false);
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: _border),
                  ),
                  child:
                  Icon(Icons.close_rounded, color: _sub, size: 17),
                ),
              ),
            ]),
            const SizedBox(height: 20),

            ...List.generate(_categories.length, (i) {
              final cat   = _categories[i];
              final delta = _sliders[i] - _currentScores[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: cat.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child:
                          Icon(cat.icon, color: cat.color, size: 17),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(cat.name,
                                style: _ts(13, FontWeight.w600, _text))),
                        _deltaBadge(delta),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 36,
                          child: Text(
                            '${_sliders[i].round()}',
                            style: _ts(14, FontWeight.w800, _blue),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ]),
                      SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: cat.color,
                          thumbColor: cat.color,
                          inactiveTrackColor: _border,
                          overlayColor: cat.color.withValues(alpha: 0.12),
                          trackHeight: 5,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 9),
                        ),
                        child: Slider(
                          value: _sliders[i],
                          min: 0,
                          max: 100,
                          onChanged: (v) {
                            HapticFeedback.selectionClick();
                            setState(() => _sliders[i] = v);
                          },
                        ),
                      ),
                      Padding(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(children: [
                          Text('0',
                              style: _ts(9, FontWeight.w400,
                                  _sub.withValues(alpha: 0.6))),
                          const Spacer(),
                          Text('50',
                              style: _ts(9, FontWeight.w400,
                                  _sub.withValues(alpha: 0.6))),
                          const Spacer(),
                          Text('100',
                              style: _ts(9, FontWeight.w400,
                                  _sub.withValues(alpha: 0.6))),
                        ]),
                      ),
                      const SizedBox(height: 8),
                    ]),
              );
            }),

            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(
                            () => _sliders.setAll(0, _currentScores));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _border),
                    ),
                    child: Center(
                        child: Text('Reset',
                            style:
                            _ts(14, FontWeight.w600, _sub))),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _primaryBtn(
                  'Save All Scores',
                  _saveScores,
                  icon: Icons.save_rounded,
                  isSuccess: _savedSuccessfully,
                ),
              ),
            ]),
          ]),
          elevated: true,
        ).animate().slideY(
          begin: 0.1,
          duration: 350.ms,
          curve: Curves.easeOutCubic,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SLIVER 6 — EMPLOYMENT OUTCOMES
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildOutcomesCard() => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: _card(
        Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(Icons.people_outline_rounded,
                      color: _blue, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Graduate Employment Outcomes',
                            style: _ts(14, FontWeight.w700, _text)),
                        Text(
                            'n=1,000 · career_guidance_dataset [A22]',
                            style: _ts(11, FontWeight.w400, _sub)),
                      ]),
                ),
              ]),
              const SizedBox(height: 20),
              Row(
                children: _employmentOutcomes.entries.map((e) {
                  final color = e.key == 'Employed'
                      ? _successColor
                      : e.key == 'Self-employed'
                      ? _blue
                      : _errorColor;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Column(children: [
                        AnimatedBuilder(
                          animation: _scoreAnim,
                          builder: (_, __) => Text(
                            '${(e.value * _scoreAnim.value).toStringAsFixed(1)}%',
                            style: _displayTs(19, color),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(e.key,
                            textAlign: TextAlign.center,
                            style: _ts(10, FontWeight.w500, _sub)),
                        const SizedBox(height: 8),
                        AnimatedBuilder(
                          animation: _scoreAnim,
                          builder: (_, __) => ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: LinearProgressIndicator(
                              value: (e.value / 100 * _scoreAnim.value)
                                  .clamp(0, 1),
                              minHeight: 7,
                              backgroundColor: _border,
                              valueColor:
                              AlwaysStoppedAnimation(color),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ]),
      ),
    ),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // SLIVER 7 — SUCCESS BY INTEREST
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSuccessCard() => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: _card(
        Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _accentGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.insights_rounded,
                      color: _accentGreen, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Success Rate by Career Interest',
                            style: _ts(14, FontWeight.w700, _text)),
                        Text(
                            'Predicted_Job_Success_Probability [T22 §5]',
                            style: _ts(11, FontWeight.w400, _sub)),
                      ]),
                ),
              ]),
              const SizedBox(height: 18),
              ..._successByInterest.entries
                  .toList()
                  .asMap()
                  .entries
                  .map((entry) {
                final i = entry.key;
                final e = entry.value;
                const colors = [
                  _primaryBlueMid,
                  _accentTeal,
                  _accentGreen,
                  Color(0xFF8B5CF6),
                  Color(0xFFF59E0B),
                ];
                final color = colors[i % colors.length];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    SizedBox(
                      width: 90,
                      child: Text(e.key,
                          style: _ts(12.5, FontWeight.w600, _text)),
                    ),
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _scoreAnim,
                        builder: (_, __) => ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: (e.value / 100 * _scoreAnim.value)
                                .clamp(0, 1),
                            minHeight: 10,
                            backgroundColor: _border,
                            valueColor: AlwaysStoppedAnimation(color),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 42,
                      child: Text(
                          '${e.value.toStringAsFixed(1)}%',
                          style: _ts(12, FontWeight.w800, color),
                          textAlign: TextAlign.right),
                    ),
                  ]),
                );
              }),
            ]),
      ),
    ),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // SLIVER 8 — SALARY NEGOTIATION TIPS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTipsCard() => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: _card(
        Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _isDark
                        ? _warningColor.withValues(alpha: 0.18)
                        : _warningLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.lightbulb_rounded,
                      color: _warningColor, size: 22),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Boost Salary Negotiation',
                            style: _ts(15, FontWeight.w700, _text)),
                        Text(
                          'Lowest area · ${_currentScores.last.round()}/100 — gap: ${(100 - _currentScores.last).round()} pts',
                          style: _ts(12, FontWeight.w400, _sub),
                        ),
                      ]),
                ),
              ]),
              const SizedBox(height: 18),
              ..._tips.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_blue, _blue.withValues(alpha: 0.75)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text('${e.key + 1}',
                              style: _ts(
                                  11, FontWeight.w800, Colors.white)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(e.value,
                            style: _ts(13, FontWeight.w400, _sub,
                                height: 1.6)),
                      ),
                    ]),
              )),
              const SizedBox(height: 4),
              _primaryBtn('Take Action →', () {},
                  icon: Icons.arrow_forward_rounded),
            ]),
      ),
    ),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // LOADING SHIMMER
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildShimmerCard(double height) => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
    height: height,
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: _border),
    ),
  )
      .animate(onPlay: (ctrl) => ctrl.repeat())
      .shimmer(
      duration: 1400.ms,
      color: _border.withValues(alpha: 0.5));

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // ── Sync theme from global AppState ─────────────────────────────────────
    // This ensures dark/light mode changes made anywhere in the app are
    // reflected here immediately and persistently via AppState.
    _isDark = context.watch<AppState>().isDark!;

    final overall = _overallScore;

    return Theme(
      data: ThemeData(
        brightness: _isDark ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: _bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primaryBlue,
          brightness: _isDark ? Brightness.dark : Brightness.light,
        ),
      ),
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          surfaceTintColor: Colors.transparent,
          shadowColor: _border,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: _text, size: 22),
            onPressed: () => Navigator.maybePop(context),
            tooltip: 'Back',
          ),
          title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Career Confidence',
                    style: _ts(17, FontWeight.w800, _text,
                        letterSpacing: -0.3)),
                Text('SkillBridge AI · SDG-8',
                    style: _ts(10, FontWeight.w500, _sub)),
              ]),
          // ── Streak badge only — theme toggle is the global one ──────────
          actions: [
            if (_streak > 0)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                      color: _warningColor.withValues(alpha: 0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.local_fire_department_rounded,
                      color: _warningColor, size: 14),
                  const SizedBox(width: 3),
                  Text('$_streak',
                      style:
                      _ts(12, FontWeight.w800, _warningColor)),
                ]),
              ),
            const SizedBox(width: 12),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(color: _border, thickness: 1, height: 1),
          ),
        ),
        body: _isLoading
            ? CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: Column(children: [
              const SizedBox(height: 16),
              _buildShimmerCard(280),
              const SizedBox(height: 20),
              _buildShimmerCard(90),
              const SizedBox(height: 20),
              _buildShimmerCard(148),
              const SizedBox(height: 20),
              _buildShimmerCard(280),
            ]),
          ),
        ])
            : CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 1. Hero ──────────────────────────────────────────────
            _buildHeroCard(overall),

            // 2. Milestone badges ───────────────────────────────────
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            _buildBadgesRow(),

            // 3. Category cards ─────────────────────────────────────
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            _buildCategoryCards(),

            // 4. Chart card ─────────────────────────────────────────
            _buildChartCard(),

            // 5. Employment outcomes ────────────────────────────────
            _buildOutcomesCard(),

            // 6. Success by interest ────────────────────────────────
            _buildSuccessCard(),

            // 7. Update scores panel ────────────────────────────────
            _buildUpdatePanel(),

            // 8. Tips card ──────────────────────────────────────────
            _buildTipsCard(),

            // Bottom safe area ──────────────────────────────────────
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}