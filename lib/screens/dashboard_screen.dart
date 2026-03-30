// lib/screens/dashboard_screen.dart — SkillBridge AI
// ══════════════════════════════════════════════════════════════════════════════
//  EXECUTIVE CAREER DASHBOARD
//
//  Fix applied:
//  • _buildDarkToggle now calls context.read<AppState>().setThemeMode()
//    directly, toggling between ThemeMode.light and ThemeMode.dark.
//    No longer depends on the optional onToggleTheme callback being wired
//    by the parent — the button always works.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../data/jobs.dart' show allJobs, Job;
import '../models/career_profile.dart';
import '../models/job.dart' show industryColor;
import '../services/app_state.dart';
import '../theme/app_theme.dart' show AppTheme;
import 'cv_upload_screen.dart';
import 'job_result.dart';
import 'main_nav.dart';
import 'profile_input.dart';

// ══════════════════════════════════════════════════════════════════════════════
// FILE-PRIVATE UTILITIES
// ══════════════════════════════════════════════════════════════════════════════

Color _withA(Color color, double opacity) =>
    color.withValues(alpha: opacity.clamp(0.0, 1.0));

// ── Design tokens ─────────────────────────────────────────────────────────────

Color _bgC(bool d)       => d ? const Color(0xFF111827) : Colors.white;
Color _scaffoldC(bool d) => d ? const Color(0xFF0A0F1E) : const Color(0xFFF8FAFC);
Color _textC(bool d)     => d ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
Color _subC(bool d)      => d ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
Color _borderC(bool d)   => d ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

const Color _kAccentBlue = Color(0xFF0EA5E9);
const Color _kSuccess    = Color(0xFF10B981);
const Color _kWarning    = Color(0xFFF59E0B);
const Color _kError      = Color(0xFFEF4444);
const Color _kPurple     = Color(0xFF8B5CF6);

BoxDecoration _cardDeco(bool dark, {double r = 16, Color? bg}) => BoxDecoration(
  color: bg ?? _bgC(dark),
  borderRadius: BorderRadius.circular(r),
  border: Border.all(color: _borderC(dark)),
  boxShadow: dark
      ? [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.45),
      blurRadius: 14,
      offset: const Offset(0, 4),
    ),
  ]
      : [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.055),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ],
);

Color readinessColor(int pct) {
  if (pct >= 75) return _kSuccess;
  if (pct >= 45) return _kWarning;
  return _kError;
}

class SimScoreBadge extends StatelessWidget {
  final double score;

  const SimScoreBadge({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final int pct     = (score * 100).round().clamp(0, 100);
    final Color color = readinessColor(pct);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _withA(color, 0.1),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: _withA(color, 0.3)),
      ),
      child: Text(
        '$pct%',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MODELS
// ══════════════════════════════════════════════════════════════════════════════

enum EmploymentIntention {
  studyAbroad,
  furtherEducation,
  seekEmployment,
  startBusiness,
}

extension EmploymentIntentionX on EmploymentIntention {
  String get label {
    switch (this) {
      case EmploymentIntention.studyAbroad:      return 'Study Abroad';
      case EmploymentIntention.furtherEducation: return 'Further Education';
      case EmploymentIntention.seekEmployment:   return 'Seek Employment';
      case EmploymentIntention.startBusiness:    return 'Start a Business';
    }
  }

  String get emoji {
    switch (this) {
      case EmploymentIntention.studyAbroad:      return '✈️';
      case EmploymentIntention.furtherEducation: return '🎓';
      case EmploymentIntention.seekEmployment:   return '💼';
      case EmploymentIntention.startBusiness:    return '🚀';
    }
  }

  Color get color {
    switch (this) {
      case EmploymentIntention.studyAbroad:      return const Color(0xFF0288D1);
      case EmploymentIntention.furtherEducation: return const Color(0xFF7B1FA2);
      case EmploymentIntention.seekEmployment:   return const Color(0xFF2E7D32);
      case EmploymentIntention.startBusiness:    return const Color(0xFFE65100);
    }
  }
}

class _IntentionState {
  final EmploymentIntention intention;
  final int confidenceLevel;
  final DateTime updatedAt;

  const _IntentionState({
    required this.intention,
    required this.confidenceLevel,
    required this.updatedAt,
  });

  int get daysSinceUpdate => DateTime.now().difference(updatedAt).inDays;

  _IntentionState copyWith({
    EmploymentIntention? intention,
    int? confidenceLevel,
    DateTime? updatedAt,
  }) =>
      _IntentionState(
        intention:       intention ?? this.intention,
        confidenceLevel: confidenceLevel ?? this.confidenceLevel,
        updatedAt:       updatedAt ?? this.updatedAt,
      );
}

class _FairnessData {
  final int score;
  final String label;
  final Color color;
  final List<_FairnessItem> items;

  const _FairnessData({
    required this.score,
    required this.label,
    required this.color,
    required this.items,
  });

  factory _FairnessData.fromAppState(AppState s) {
    int score = 60;
    if (s.userSkills.isNotEmpty)         score += 12;
    if (s.cvUploaded)                    score += 10;
    if (s.careerGoal.isNotEmpty)         score += 8;
    if (s.userEmail.isNotEmpty)          score += 5;
    if (s.completedCourseIds.isNotEmpty) score += 5;
    score = score.clamp(0, 100);

    final String label;
    final Color  color;
    if (score >= 80) {
      label = 'Good';
      color = const Color(0xFF2E7D32);
    } else if (score >= 60) {
      label = 'Fair';
      color = const Color(0xFFF57F17);
    } else {
      label = 'Needs Review';
      color = const Color(0xFFC62828);
    }

    return _FairnessData(
      score: score,
      label: label,
      color: color,
      items: [
        _FairnessItem(
          'Skill Representation',
          s.userSkills.isNotEmpty ? 90 : 40,
          'Your skill profile reflects a diverse technical background.',
        ),
        const _FairnessItem(
          'Socioeconomic Diversity',
          75,
          'Job matches span multiple salary bands and industry tiers.',
        ),
        _FairnessItem(
          'Geographic Equity',
          s.cvUploaded ? 85 : 55,
          'Remote and hybrid roles are included in recommendations.',
        ),
        const _FairnessItem(
          'Gender Neutrality',
          95,
          'All recommendations are gender-neutral by design.',
        ),
        _FairnessItem(
          'Preference Alignment',
          s.completedCourseIds.isNotEmpty ? 88 : 50,
          'Content recommendations respect your stated preferences.',
        ),
      ],
    );
  }
}

class _FairnessItem {
  final String dimension;
  final int score;
  final String explanation;

  const _FairnessItem(this.dimension, this.score, this.explanation);
}

class _ProgressDimension {
  final String label;
  final double value;
  final Color color;

  const _ProgressDimension(this.label, this.value, this.color);
}

// ══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ══════════════════════════════════════════════════════════════════════════════

int _asInt(dynamic val) {
  if (val is int)    return val;
  if (val is double) return val.toInt();
  return int.tryParse(val.toString()) ?? 0;
}

int _idInt(dynamic id) => int.tryParse(id.toString()) ?? 0;

IconData _industryIcon(String industry) {
  const Map<String, IconData> icons = {
    'Software':      Icons.code_rounded,
    'Finance':       Icons.account_balance_outlined,
    'Healthcare':    Icons.local_hospital_outlined,
    'Marketing':     Icons.campaign_outlined,
    'Manufacturing': Icons.precision_manufacturing_outlined,
    'Retail':        Icons.storefront_outlined,
    'Education':     Icons.school_outlined,
  };
  return icons[industry] ?? Icons.work_outline_rounded;
}

String _formatSalary(dynamic salary) {
  if (salary == null) return 'Salary N/A';
  if (salary is num)  return 'RM ${salary.toStringAsFixed(0)}';
  return salary.toString();
}

int _profileScore(AppState s) {
  int score = 0;
  if (s.userName.isNotEmpty)   score += 20;
  if (s.userEmail.isNotEmpty)  score += 10;
  if (s.cvUploaded)            score += 30;
  if (s.userSkills.isNotEmpty) score += 25;
  if (s.careerGoal.isNotEmpty) score += 15;
  return score;
}

// ══════════════════════════════════════════════════════════════════════════════
// SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class DashboardScreen extends StatefulWidget {
  /// Kept for API compatibility but the toggle now works independently
  /// by reading AppState directly — this callback is optional.
  final VoidCallback? onToggleTheme;

  const DashboardScreen({super.key, this.onToggleTheme});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {

  late final AnimationController _ringCtrl;
  late final AnimationController _readinessCtrl;
  late final Animation<double>   _readinessAnim;
  late final AnimationController _fitCtrl;
  late final Animation<double>   _fitAnim;
  late final AnimationController _progressRingCtrl;
  late final Animation<double>   _progressRingAnim;

  bool _streakNudgeDismissed = false;

  _IntentionState _intention = _IntentionState(
    intention:       EmploymentIntention.seekEmployment,
    confidenceLevel: 3,
    updatedAt:       DateTime.now().subtract(const Duration(days: 2)),
  );

  @override
  void initState() {
    super.initState();

    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();

    _readinessCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
    _readinessAnim =
        CurvedAnimation(parent: _readinessCtrl, curve: Curves.easeOut);

    _fitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();
    _fitAnim = CurvedAnimation(parent: _fitCtrl, curve: Curves.easeOut);

    _progressRingCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();
    _progressRingAnim =
        CurvedAnimation(parent: _progressRingCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    _readinessCtrl.dispose();
    _fitCtrl.dispose();
    _progressRingCtrl.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    HapticFeedback.lightImpact();
    for (final c in [
      _ringCtrl,
      _readinessCtrl,
      _fitCtrl,
      _progressRingCtrl,
    ]) {
      c.reset();
    }
    await context.read<AppState>().loadFromPrefs();
    for (final c in [
      _ringCtrl,
      _readinessCtrl,
      _fitCtrl,
      _progressRingCtrl,
    ]) {
      c.forward();
    }
  }

  CareerProfile _defaultProfile(AppState s) => CareerProfile(
    name:         s.userName.isEmpty ? 'User' : s.userName,
    fieldOfStudy: FieldOfStudy.other,
    gpa:          0.0,
    yearOfStudy:  1,
    skills:       s.userSkills,
    careerInterests: const [],
    hasEntrepreneurialExperience: false,
    employmentType: ExperienceType.fullTime,
  );

  int _computePJFit(AppState s) {
    int score = 0;
    if (s.userSkills.isNotEmpty) {
      score += (s.userSkills.length.clamp(0, 10) * 4);
    }
    if (s.cvUploaded)            score += 20;
    if (s.careerGoal.isNotEmpty) score += 15;
    score += (_asInt(s.jobsMatchedCount).clamp(0, 5) * 3);
    return score.clamp(0, 100);
  }

  int _computePOFit(AppState s) {
    int score = 40;
    if (s.userName.isNotEmpty)           score += 10;
    if (s.userEmail.isNotEmpty)          score += 5;
    if (s.completedCourseIds.isNotEmpty) score += 20;
    if (s.careerGoal.isNotEmpty)         score += 15;
    if (s.userSkills.length > 3)         score += 10;
    return score.clamp(0, 100);
  }

  String _confidenceLabel(int v) {
    switch (v) {
      case 1:  return 'Just exploring options';
      case 2:  return 'Leaning in this direction';
      case 3:  return 'Fairly certain';
      case 4:  return 'Very confident';
      case 5:  return 'Fully committed';
      default: return '';
    }
  }

  Widget _dragHandle() => Container(
    width: 40,
    height: 4,
    decoration: BoxDecoration(
      color: Colors.grey.shade300,
      borderRadius: BorderRadius.circular(2),
    ),
  );

  Widget _primaryBtn(String label, VoidCallback onTap, Color color) =>
      SizedBox(
        width: double.infinity,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () {
              HapticFeedback.mediumImpact();
              onTap();
            },
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: _withA(color, 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  // ── FIX: toggle directly via AppState, ignoring the optional callback ──────
  /// [white] — true when rendered on the gradient header background.
  Widget _buildDarkToggle({bool white = false}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      icon: Icon(
        isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
        color: white ? Colors.white : _textC(isDark),
        size: 22,
      ),
      onPressed: () {
        HapticFeedback.selectionClick();
        context.read<AppState>().setThemeMode(
          isDark ? ThemeMode.light : ThemeMode.dark,
        );
      },
      tooltip: isDark ? 'Switch to light' : 'Switch to dark',
    );
  }

  Widget _sectionHeader(String title, bool isDark) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: _textC(isDark),
            ),
          ),
        ),
        Container(
          height: 1,
          width: 60,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_withA(AppTheme.primaryBlue, 0.5), Colors.transparent],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _miniStat(IconData icon, String value, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: Colors.white70, size: 14),
      const SizedBox(width: 6),
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(width: 3),
      Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 11),
      ),
    ],
  );

  Widget _quickStatCard(
      IconData icon,
      Color color,
      String value,
      String label,
      bool isDark,
      ) =>
      Container(
        width: 104,
        height: 98,
        padding: const EdgeInsets.all(12),
        decoration: _cardDeco(isDark),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _withA(color, 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _textC(isDark),
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: _subC(isDark)),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );

  Widget _quickActionCard(
      IconData icon,
      Color color,
      String label,
      String subtitle,
      bool isDark,
      VoidCallback onTap,
      ) =>
      Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: _cardDeco(isDark),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _withA(color, 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _textC(isDark),
                        ),
                      ),
                      Text(
                        subtitle,
                        style:
                        TextStyle(fontSize: 11, color: _subC(isDark)),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: _subC(isDark), size: 16),
              ],
            ),
          ),
        ),
      );

  Widget _fitMiniCard(
      String title,
      String subtitle,
      int score,
      Color color,
      bool isDark, {
        required VoidCallback onTap,
      }) =>
      Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: _cardDeco(isDark),
            child: Column(
              children: [
                Text(
                  title,
                  style:
                  TextStyle(fontSize: 13, color: _subC(isDark)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: score / 100),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeOut,
                  builder: (_, double val, __) => SizedBox(
                    width: 76,
                    height: 76,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: val,
                          strokeWidth: 7,
                          color: color,
                          backgroundColor: _borderC(isDark),
                          strokeCap: StrokeCap.round,
                        ),
                        Text(
                          '${(val * 100).round()}%',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _textC(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: _subC(isDark)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );

  // ══════════════════════════════════════════════════════════════════════════
  // DIALOGS & SHEETS
  // ══════════════════════════════════════════════════════════════════════════

  void _showIntentionPicker() {
    HapticFeedback.lightImpact();
    EmploymentIntention tempIntention  = _intention.intention;
    double              tempConfidence = _intention.confidenceLevel.toDouble();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            top:    24,
            left:   24,
            right:  24,
          ),
          decoration: BoxDecoration(
            color: Theme.of(ctx).scaffoldBackgroundColor,
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: _dragHandle()),
              const SizedBox(height: 20),
              const Text(
                "What's your current intention?",
                style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'This shapes your personalised job & course recommendations.',
                style:
                TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              ...EmploymentIntention.values.map((e) {
                final bool selected = e == tempIntention;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setSheetState(() => tempIntention = e);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? _withA(e.color, 0.09)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? e.color
                            : Colors.grey.shade200,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(e.emoji,
                            style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            e.label,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: selected ? e.color : null,
                            ),
                          ),
                        ),
                        if (selected)
                          Icon(Icons.check_circle_rounded,
                              color: e.color, size: 22),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
              Text(
                'Confidence Level: ${tempConfidence.round()} / 5',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _confidenceLabel(tempConfidence.round()),
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade600),
              ),
              Slider(
                value: tempConfidence,
                min: 1,
                max: 5,
                divisions: 4,
                activeColor: tempIntention.color,
                label: tempConfidence.round().toString(),
                onChanged: (double v) =>
                    setSheetState(() => tempConfidence = v),
              ),
              const SizedBox(height: 8),
              _primaryBtn('Save Intention', () {
                setState(() {
                  _intention = _IntentionState(
                    intention:       tempIntention,
                    confidenceLevel: tempConfidence.round(),
                    updatedAt:       DateTime.now(),
                  );
                });
                Navigator.pop(ctx);
              }, tempIntention.color),
            ],
          ),
        ),
      ),
    );
  }

  void _showFairnessReport(_FairnessData data, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.balance_rounded, color: data.color, size: 22),
            const SizedBox(width: 8),
            const Text('Fairness Report'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: _withA(data.color, 0.07),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _withA(data.color, 0.32)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${data.score}/100',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: data.color,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data.label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: data.color,
                            ),
                          ),
                          const Text(
                            'Overall Fairness Score',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ...data.items.asMap().entries.map((entry) {
                  final int i              = entry.key;
                  final _FairnessItem item = entry.value;
                  final Color barColor = item.score >= 80
                      ? const Color(0xFF2E7D32)
                      : item.score >= 60
                      ? const Color(0xFFF57F17)
                      : const Color(0xFFC62828);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.dimension,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '${item.score}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: barColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        TweenAnimationBuilder<double>(
                          key: ValueKey('fairness-$i'),
                          tween:
                          Tween(begin: 0, end: item.score / 100),
                          duration: Duration(
                              milliseconds: 600 + i * 100),
                          curve: Curves.easeOutCubic,
                          builder: (_, double val, __) => ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: val,
                              color: barColor,
                              backgroundColor: isDark
                                  ? Colors.grey[700]
                                  : Colors.grey.shade200,
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.explanation,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showFitDetail(
      String title,
      int score,
      String description,
      List<String> tips,
      bool isDark,
      ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (ctx, ScrollController scroll) => Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(ctx).scaffoldBackgroundColor,
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: scroll,
            children: [
              Center(child: _dragHandle()),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                    fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: score / 100),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutCubic,
                  builder: (_, double val, __) => SizedBox(
                    width: 120,
                    height: 120,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: val,
                          strokeWidth: 10,
                          color: readinessColor(score),
                          backgroundColor: isDark
                              ? Colors.grey[700]
                              : Colors.grey.shade200,
                          strokeCap: StrokeCap.round,
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${(val * 100).round()}%',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: readinessColor(score),
                              ),
                            ),
                            const Text(
                              'score',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'How to improve',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...tips.asMap().entries.map(
                    (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        margin: const EdgeInsets.only(top: 1),
                        decoration: BoxDecoration(
                          color: _withA(AppTheme.primaryBlue, 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${e.key + 1}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.primaryBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(e.value,
                            style: const TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();
    final bool isDark       = Theme.of(context).brightness == Brightness.dark;

    final List<Job> savedJobs = allJobs
        .where((j) => appState.savedJobIds.contains(_idInt(j.id)))
        .toList();

    final int score             = _profileScore(appState);
    final CareerProfile profile = _defaultProfile(appState);

    final List<Job> topMatches = (List<Job>.from(allJobs)
      ..sort((a, b) => b.simScore.compareTo(a.simScore)))
        .where((j) => j.simScore > 0)
        .take(3)
        .toList();

    final int pjFit  = _computePJFit(appState);
    final int poFit  = _computePOFit(appState);
    final int aiConf = _asInt(appState.readinessScore).clamp(0, 100);

    final int skillsHave   = appState.userSkills.length;
    const int skillsTarget = 10;

    final _FairnessData fairness = _FairnessData.fromAppState(appState);

    final int  readiness      = _asInt(appState.readinessScore).clamp(0, 100);
    final int  streak         = _asInt(appState.learningStreak);
    final int  skillCount     = appState.userSkills.length;
    final int  courseCount    = appState.completedCourseIds.length;
    final int  savedCount     = appState.savedJobIds.length;
    final int  missingCount   = _asInt(appState.skillsMissingCount);
    final int  completedCount = appState.completedCourseIds.length;
    final bool cvUploaded     = appState.cvUploaded;

    final String userName = appState.userName.isNotEmpty
        ? appState.userName
        : 'User';
    final String initials = userName.length >= 2
        ? '${userName[0]}${userName[1]}'.toUpperCase()
        : userName.isNotEmpty
        ? userName[0].toUpperCase()
        : 'U';

    final List<String> missingItems = [
      if (appState.userName.isEmpty)   'Add your name',
      if (appState.userEmail.isEmpty)  'Add your email',
      if (!cvUploaded)                 'Upload your CV',
      if (appState.userSkills.isEmpty) 'Add your skills',
      if (appState.careerGoal.isEmpty) 'Set a career goal',
    ];

    return Scaffold(
      backgroundColor: _scaffoldC(isDark),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: AppTheme.primaryBlue,
        displacement: 80,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [

            // ═══════════════════════════════════════════════════════════════
            // SLIVER APP BAR
            // ═══════════════════════════════════════════════════════════════
            SliverAppBar(
              pinned: true,
              expandedHeight: 160,
              backgroundColor: _bgC(isDark),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              automaticallyImplyLeading: false,
              title: Text(
                'Dashboard',
                style: TextStyle(
                  color: _textC(isDark),
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              // Intentionally empty — toggle lives in FlexibleSpaceBar
              actions: const [],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primaryBlue, _kAccentBlue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding:
                      const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Dashboard',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Welcome back, $userName 👋',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          // ── Dark toggle — calls AppState directly ────────
                          _buildDarkToggle(white: true),
                          const SizedBox(width: 10),
                          // Avatar
                          Material(
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
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _withA(Colors.white, 0.2),
                                  borderRadius:
                                  BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _withA(Colors.white, 0.3),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    initials,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
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

            // ═══════════════════════════════════════════════════════════════
            // SECTION 1 — Readiness Hero Card
            // ═══════════════════════════════════════════════════════════════
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: RepaintBoundary(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryBlue, _kAccentBlue],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: _withA(AppTheme.primaryBlue, 0.35),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 100,
                          height: 100,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: 1.0,
                                strokeWidth: 10,
                                color: _withA(Colors.white, 0.2),
                              ),
                              AnimatedBuilder(
                                animation: _readinessAnim,
                                builder: (_, __) =>
                                    CircularProgressIndicator(
                                      value: (readiness / 100) *
                                          _readinessAnim.value,
                                      strokeWidth: 10,
                                      color: Colors.white,
                                      backgroundColor: Colors.transparent,
                                      strokeCap: StrokeCap.round,
                                    ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedBuilder(
                                    animation: _readinessAnim,
                                    builder: (_, __) => Text(
                                      '${(readiness * _readinessAnim.value).round()}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        height: 1,
                                      ),
                                    ),
                                  ),
                                  const Text(
                                    '%',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Career Readiness',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              const Text(
                                'Score',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _miniStat(
                                Icons.check_circle_outline_rounded,
                                '$skillCount',
                                'Skills',
                              ),
                              const SizedBox(height: 5),
                              _miniStat(
                                Icons.school_rounded,
                                '$courseCount',
                                'Courses',
                              ),
                              const SizedBox(height: 5),
                              _miniStat(
                                Icons.local_fire_department_rounded,
                                '${streak}d',
                                'Streak',
                              ),
                              const SizedBox(height: 14),
                              Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(100),
                                child: InkWell(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const MainNav(
                                          initialTab: 1,
                                        ),
                                      ),
                                    );
                                  },
                                  borderRadius:
                                  BorderRadius.circular(100),
                                  child: Ink(
                                    padding:
                                    const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                      _withA(Colors.white, 0.15),
                                      borderRadius:
                                      BorderRadius.circular(100),
                                      border: Border.all(
                                        color: _withA(
                                            Colors.white, 0.2),
                                      ),
                                    ),
                                    child: const Text(
                                      'Improve Score →',
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
                        ),
                      ],
                    ),
                  ),
                ),
              ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1),
            ),

            // ═══════════════════════════════════════════════════════════════
            // SECTION 2 — Quick Stats Row
            // ═══════════════════════════════════════════════════════════════
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 16)
                      .copyWith(right: 16),
                  child: Row(
                    children: [
                      _quickStatCard(
                        Icons.bookmark_rounded,
                        AppTheme.primaryBlue,
                        '$savedCount',
                        'Saved Jobs',
                        isDark,
                      ),
                      const SizedBox(width: 10),
                      _quickStatCard(
                        Icons.trending_up_rounded,
                        _kWarning,
                        '$missingCount',
                        'Skill Gap',
                        isDark,
                      ),
                      const SizedBox(width: 10),
                      _quickStatCard(
                        Icons.school_rounded,
                        _kSuccess,
                        '$completedCount',
                        'Courses Done',
                        isDark,
                      ),
                      const SizedBox(width: 10),
                      _quickStatCard(
                        Icons.local_fire_department_rounded,
                        _kError,
                        '${streak}d',
                        'Streak 🔥',
                        isDark,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ═══════════════════════════════════════════════════════════════
            // SECTION 3 — P-J & P-O Fit Cards
            // ═══════════════════════════════════════════════════════════════
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _fitMiniCard(
                        'P-J Fit',
                        'Job Fit',
                        pjFit,
                        AppTheme.primaryBlue,
                        isDark,
                        onTap: () => _showFitDetail(
                          'Person-Job Fit (P-J)',
                          pjFit,
                          'How well your skills, experience, and goals match your target job profile.',
                          [
                            'Add more skills that appear in your target job descriptions.',
                            'Upload an updated CV reflecting your latest experience.',
                            'Set a specific career goal to improve role matching precision.',
                            'Complete skill gap courses under Learning Progress.',
                          ],
                          isDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _fitMiniCard(
                        'P-O Fit',
                        'Culture Fit',
                        poFit,
                        _kSuccess,
                        isDark,
                        onTap: () => _showFitDetail(
                          'Person-Org Fit (P-O)',
                          poFit,
                          'How well your values, work style, and preferences align with target organisations.',
                          [
                            'Complete the full career profile including employment preference.',
                            'Indicate your preferred work environment.',
                            'Explore company culture signals via the job detail cards.',
                            'Review organisational values in matched job descriptions.',
                          ],
                          isDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ═══════════════════════════════════════════════════════════════
            // SECTION 4 — Quick Actions Grid
            // ═══════════════════════════════════════════════════════════════
            SliverToBoxAdapter(child: _sectionHeader('Quick Actions', isDark)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.6,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _quickActionCard(
                      Icons.work_rounded,
                      AppTheme.primaryBlue,
                      'Find Jobs',
                      'Browse matches',
                      isDark,
                          () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MainNav(initialTab: 0),
                        ),
                      ),
                    ),
                    _quickActionCard(
                      Icons.school_rounded,
                      _kSuccess,
                      'My Courses',
                      'Continue learning',
                      isDark,
                          () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MainNav(initialTab: 1),
                        ),
                      ),
                    ),
                    _quickActionCard(
                      Icons.bar_chart_rounded,
                      _kWarning,
                      'Skill Gap',
                      '$missingCount missing',
                      isDark,
                          () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MainNav(initialTab: 1),
                        ),
                      ),
                    ),
                    _quickActionCard(
                      Icons.upload_file_rounded,
                      _kPurple,
                      'Upload CV',
                      cvUploaded ? 'Uploaded ✓' : 'Add CV',
                      isDark,
                          () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CvUploadScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ═══════════════════════════════════════════════════════════════
            // SECTION 5 — Profile Completion
            // ═══════════════════════════════════════════════════════════════
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: _cardDeco(isDark),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Profile Completion',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _textC(isDark),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '$score%',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: score / 100),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (_, double val, __) => ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: val,
                            color: AppTheme.primaryBlue,
                            backgroundColor: _borderC(isDark),
                            minHeight: 8,
                          ),
                        ),
                      ),
                      if (missingItems.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ...missingItems.map(
                              (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Row(
                              children: [
                                Icon(Icons.radio_button_unchecked,
                                    color: _subC(isDark), size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  item,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _subC(isDark),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // ═══════════════════════════════════════════════════════════════
            // Motivation Banner & Streak Nudge
            // ═══════════════════════════════════════════════════════════════
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: _MotivationBanner(
                  appState: appState,
                  isDark:   isDark,
                ),
              ),
            ),
            if (!_streakNudgeDismissed &&
                _asInt(appState.learningStreak) == 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _StreakNudge(
                    isDark:    isDark,
                    onDismiss: () =>
                        setState(() => _streakNudgeDismissed = true),
                  ),
                ),
              ),

            // ═══════════════════════════════════════════════════════════════
            // Top Job Matches
            // ═══════════════════════════════════════════════════════════════
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
                child: Row(
                  children: [
                    Text(
                      '🎯 Top Job Matches',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _textC(isDark),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.push(
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
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'View all',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _TopJobMatches(
                  jobs:     topMatches,
                  appState: appState,
                  isDark:   isDark,
                ),
              ),
            ),

            // ═══════════════════════════════════════════════════════════════
            // Learning Progress
            // ═══════════════════════════════════════════════════════════════
            SliverToBoxAdapter(
              child: _sectionHeader('📚 Learning Progress', isDark),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _LearningProgressCard(
                  appState: appState,
                  isDark:   isDark,
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: _sectionHeader('⚙️ Content Preferences', isDark),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _PreferenceSummaryCard(
                  appState: appState,
                  isDark:   isDark,
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: _sectionHeader('🕐 Recent Learning', isDark),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _RecentLearningHistory(
                  appState: appState,
                  isDark:   isDark,
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: _sectionHeader('📊 Skill Progress', isDark),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _SkillProgressCard(
                  appState: appState,
                  isDark:   isDark,
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: _sectionHeader('📅 Weekly Learning Goal', isDark),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _WeeklyTracker(
                  appState: appState,
                  isDark:   isDark,
                ),
              ),
            ),

            // ═══════════════════════════════════════════════════════════════
            // AI-Powered Sections
            // ═══════════════════════════════════════════════════════════════

            SliverToBoxAdapter(
              child: _sectionHeader('🎯 Employment Intention', isDark),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _EmploymentIntentionCard(
                  intention: _intention,
                  isDark:    isDark,
                  onTap:     _showIntentionPicker,
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.15),
              ),
            ),

            SliverToBoxAdapter(
              child: _sectionHeader('📐 Career Fit Scores', isDark),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _FitScoreRow(
                  pjFit:  pjFit,
                  poFit:  poFit,
                  aiConf: aiConf,
                  anim:   _fitAnim,
                  isDark: isDark,
                  onTapPJ: () => _showFitDetail(
                    'Person-Job Fit (P-J)',
                    pjFit,
                    'How well your skills, experience, and goals match your target job profile.',
                    [
                      'Add more skills that appear in your target job descriptions.',
                      'Upload an updated CV that reflects your latest experience.',
                      'Set a specific career goal to improve role matching precision.',
                      'Complete skill gap courses recommended under Learning Progress.',
                    ],
                    isDark,
                  ),
                  onTapPO: () => _showFitDetail(
                    'Person-Org Fit (P-O)',
                    poFit,
                    'How well your values, work style, and preferences align with target organisations.',
                    [
                      'Complete the full career profile including employment preference.',
                      'Indicate your preferred work environment (remote, hybrid, on-site).',
                      'Explore company culture signals via the job detail cards.',
                      'Review organisational values in matched job descriptions.',
                    ],
                    isDark,
                  ),
                  onTapConf: () => _showFitDetail(
                    'AI Confidence Score',
                    aiConf,
                    'How confident the SkillBridge AI is in your current recommendations.',
                    [
                      'Upload your CV for richer skill extraction.',
                      'Complete at least one quiz to calibrate your knowledge level.',
                      'Set your content format and detail-level preferences.',
                      'Update your employment intention to focus recommendations.',
                    ],
                    isDark,
                  ),
                ).animate().fadeIn(duration: 450.ms, delay: 60.ms),
              ),
            ),

            SliverToBoxAdapter(
              child: _sectionHeader("⚡ Today's Highlights", isDark),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _DailyHighlightsRow(
                  appState: appState,
                  isDark:   isDark,
                  profile:  profile,
                ).animate().fadeIn(duration: 450.ms, delay: 120.ms),
              ),
            ),

            SliverToBoxAdapter(
              child: _sectionHeader('🏆 Overall Readiness', isDark),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: RepaintBoundary(
                  child: _OverallProgressRing(
                    skillsHave:   skillsHave,
                    skillsTarget: skillsTarget,
                    anim:         _progressRingAnim,
                    appState:     appState,
                    isDark:       isDark,
                  ).animate().fadeIn(duration: 500.ms, delay: 180.ms),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _FairnessScoreBanner(
                  data:   fairness,
                  isDark: isDark,
                  onTap:  () => _showFairnessReport(fairness, isDark),
                ).animate().fadeIn(duration: 400.ms, delay: 240.ms),
              ),
            ),

            // ═══════════════════════════════════════════════════════════════
            // Saved Jobs
            // ═══════════════════════════════════════════════════════════════
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
                child: Row(
                  children: [
                    Text(
                      '❤️ Saved Jobs',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _textC(isDark),
                      ),
                    ),
                    const Spacer(),
                    if (savedJobs.isNotEmpty)
                      Text(
                        '${savedJobs.length} saved',
                        style:
                        TextStyle(fontSize: 12, color: _subC(isDark)),
                      ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: savedJobs.isEmpty
                    ? _EmptyCard(
                  message:
                  'Tap the bookmark icon on any job card to save it here.',
                  isDark: isDark,
                  icon:  Icons.bookmark_border_rounded,
                  title: 'No saved jobs yet',
                )
                    : _SavedJobsList(
                  jobs:     savedJobs,
                  appState: appState,
                  isDark:   isDark,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Employment Intention Card
// ══════════════════════════════════════════════════════════════════════════════

class _EmploymentIntentionCard extends StatelessWidget {
  final _IntentionState intention;
  final bool isDark;
  final VoidCallback onTap;

  const _EmploymentIntentionCard({
    required this.intention,
    required this.isDark,
    required this.onTap,
  });

  String _confidenceLabelShort(int v) {
    switch (v) {
      case 1:  return 'Exploring';
      case 2:  return 'Leaning';
      case 3:  return 'Fairly sure';
      case 4:  return 'Very confident';
      case 5:  return 'Committed';
      default: return '';
    }
  }

  String _intentionImpactLabel(EmploymentIntention e) {
    switch (e) {
      case EmploymentIntention.studyAbroad:      return 'Shows scholarships & programs';
      case EmploymentIntention.furtherEducation: return 'Prioritises postgrad paths';
      case EmploymentIntention.seekEmployment:   return 'Focuses on job matches';
      case EmploymentIntention.startBusiness:    return 'Highlights entrepreneurial paths';
    }
  }

  @override
  Widget build(BuildContext context) {
    final EmploymentIntention e = intention.intention;
    final int days              = intention.daysSinceUpdate;
    final int conf              = intention.confidenceLevel;
    final Color color           = e.color;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _bgC(isDark),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _withA(color, 0.4), width: 1.5),
            boxShadow: isDark
                ? null
                : [
              BoxShadow(
                color: _withA(color, 0.08),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _withA(color, 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(e.emoji,
                          style: const TextStyle(fontSize: 24)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Intention',
                          style: TextStyle(
                              fontSize: 12, color: _subC(isDark)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          e.label,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _withA(color, 0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _withA(color, 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_rounded, size: 13, color: _subC(isDark)),
                        const SizedBox(width: 4),
                        Text('Change',
                            style: TextStyle(fontSize: 11, color: _subC(isDark))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: _borderC(isDark)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.psychology_outlined, size: 14, color: _subC(isDark)),
                  const SizedBox(width: 6),
                  Text('Confidence: ',
                      style: TextStyle(fontSize: 12, color: _subC(isDark))),
                  ...List.generate(5, (i) => Padding(
                    padding: const EdgeInsets.only(right: 3),
                    child: Icon(
                      i < conf ? Icons.circle_rounded : Icons.circle_outlined,
                      size: 11,
                      color: i < conf ? color : _withA(_subC(isDark), 0.5),
                    ),
                  )),
                  const SizedBox(width: 4),
                  Text(
                    _confidenceLabelShort(conf),
                    style: TextStyle(
                        fontSize: 11, color: color, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.update_rounded, size: 14, color: _subC(isDark)),
                  const SizedBox(width: 6),
                  Text(
                    days == 0
                        ? 'Updated today'
                        : 'Updated $days day${days == 1 ? '' : 's'} ago',
                    style: TextStyle(fontSize: 12, color: _subC(isDark)),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _withA(color, 0.06),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _intentionImpactLabel(e),
                      style: TextStyle(
                          fontSize: 10, color: color, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Fit Score Row
// ══════════════════════════════════════════════════════════════════════════════

class _FitScoreRow extends StatelessWidget {
  final int pjFit;
  final int poFit;
  final int aiConf;
  final Animation<double> anim;
  final bool isDark;
  final VoidCallback onTapPJ;
  final VoidCallback onTapPO;
  final VoidCallback onTapConf;

  const _FitScoreRow({
    required this.pjFit,
    required this.poFit,
    required this.aiConf,
    required this.anim,
    required this.isDark,
    required this.onTapPJ,
    required this.onTapPO,
    required this.onTapConf,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 162,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        clipBehavior: Clip.none,
        children: [
          _FitCard(
            label:    'P-J Fit',
            subtitle: 'Skills ↔ Job',
            score:    pjFit,
            color:    const Color(0xFF0D47A1),
            icon:     Icons.work_history_rounded,
            anim:     anim,
            isDark:   isDark,
            onTap:    onTapPJ,
          ),
          const SizedBox(width: 12),
          _FitCard(
            label:    'P-O Fit',
            subtitle: 'Values ↔ Org',
            score:    poFit,
            color:    const Color(0xFF1B5E20),
            icon:     Icons.corporate_fare_rounded,
            anim:     anim,
            isDark:   isDark,
            onTap:    onTapPO,
          ),
          const SizedBox(width: 12),
          _FitCard(
            label:    'AI Confidence',
            subtitle: 'Career Readiness',
            score:    aiConf,
            color:    const Color(0xFF4A148C),
            icon:     Icons.auto_awesome_rounded,
            anim:     anim,
            isDark:   isDark,
            onTap:    onTapConf,
          ),
        ],
      ),
    );
  }
}

class _FitCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final int score;
  final Color color;
  final IconData icon;
  final Animation<double> anim;
  final bool isDark;
  final VoidCallback onTap;

  const _FitCard({
    required this.label,
    required this.subtitle,
    required this.score,
    required this.color,
    required this.icon,
    required this.anim,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String tierLabel = score >= 75
        ? 'Strong'
        : score >= 40
        ? 'Moderate'
        : 'Building';

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: 150,
          padding: const EdgeInsets.all(14),
          decoration: _cardDeco(isDark, r: 18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 16),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold, color: color),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 14, color: _subC(isDark)),
                ],
              ),
              RepaintBoundary(
                child: AnimatedBuilder(
                  animation: anim,
                  builder: (_, __) => SizedBox(
                    width: 72,
                    height: 72,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: 1.0,
                          strokeWidth: 7,
                          color: _borderC(isDark),
                        ),
                        CircularProgressIndicator(
                          value: (score / 100) * anim.value,
                          strokeWidth: 7,
                          color: color,
                          strokeCap: StrokeCap.round,
                        ),
                        Text(
                          '${(score * anim.value).round()}%',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: color),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Column(
                children: [
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _withA(color, 0.06),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tierLabel,
                      style: TextStyle(
                          fontSize: 10,
                          color: color,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: TextStyle(fontSize: 10, color: _subC(isDark)),
                      textAlign: TextAlign.center),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Daily Highlights Row
// ══════════════════════════════════════════════════════════════════════════════

class _DailyHighlightsRow extends StatelessWidget {
  final AppState appState;
  final bool isDark;
  final CareerProfile profile;

  const _DailyHighlightsRow({
    required this.appState,
    required this.isDark,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final List<Job> sortedJobs = List<Job>.from(allJobs)
      ..sort((a, b) => b.simScore.compareTo(a.simScore));
    final Job? topJob = sortedJobs.isNotEmpty ? sortedJobs.first : null;

    final String todayTopic = appState.userSkills.isNotEmpty
        ? '${appState.userSkills.first} Fundamentals'
        : 'Career Essentials';
    final String trendingSkill = appState.userSkills.length > 1
        ? appState.userSkills[1]
        : 'Prompt Engineering';

    return Column(
      children: [
        _HighlightTile(
          emoji:  '💼',
          label:  "Today's Top Match",
          value:  topJob?.title ?? 'Browse Job Matches',
          color:  AppTheme.primaryBlue,
          isDark: isDark,
          onTap: () => Navigator.push(
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
        ),
        const SizedBox(height: 8),
        _HighlightTile(
          emoji:  '📘',
          label:  "Today's Learning Topic",
          value:  todayTopic,
          color:  AppTheme.accentTeal,
          isDark: isDark,
          onTap: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const MainNav(initialTab: 1),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _HighlightTile(
          emoji:  '🔥',
          label:  'Trending Skill Alert',
          value:  trendingSkill,
          color:  Colors.deepOrange,
          isDark: isDark,
          badge:  'HOT',
          onTap: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const MainNav(initialTab: 1),
            ),
          ),
        ),
      ],
    );
  }
}

class _HighlightTile extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;
  final String? badge;

  const _HighlightTile({
    required this.emoji,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: _cardDeco(isDark),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _withA(color, 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 20))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(fontSize: 11, color: _subC(isDark))),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _textC(isDark)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(8)),
                  child: Text(badge!,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold)),
                ),
              ] else
                Icon(Icons.chevron_right_rounded,
                    color: _subC(isDark), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Overall Progress Ring
// ══════════════════════════════════════════════════════════════════════════════

class _OverallProgressRing extends StatelessWidget {
  final int skillsHave;
  final int skillsTarget;
  final Animation<double> anim;
  final AppState appState;
  final bool isDark;

  const _OverallProgressRing({
    required this.skillsHave,
    required this.skillsTarget,
    required this.anim,
    required this.appState,
    required this.isDark,
  });

  String _readinessInsight(int pct) {
    if (pct >= 80) return "🎉 Excellent! You're highly prepared. Start applying to top roles.";
    if (pct >= 60) return '📈 Good progress! Complete skill gap courses to reach the top tier.';
    if (pct >= 40) return '💪 You\'re on track. Add more skills and upload your CV to improve.';
    return '🌱 Early stage. Fill in your profile and start learning to build readiness.';
  }

  @override
  Widget build(BuildContext context) {
    final double pct      = (skillsHave / skillsTarget).clamp(0.0, 1.0);
    final int    pctInt   = (pct * 100).round();
    final Color ringColor = readinessColor(pctInt);

    final List<_ProgressDimension> dimensions = [
      _ProgressDimension('Skills',
          (skillsHave / skillsTarget).clamp(0.0, 1.0), AppTheme.primaryBlue),
      _ProgressDimension('Profile',
          _profileScore(appState) / 100.0, AppTheme.accentGreen),
      _ProgressDimension('Courses',
          (appState.completedCourseIds.length / 10.0).clamp(0.0, 1.0),
          AppTheme.accentTeal),
      _ProgressDimension('Preferences',
          appState.completedCourseIds.isNotEmpty ? 1.0 : 0.0, Colors.purple),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(isDark, r: 18),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: anim,
                      builder: (_, __) {
                        final double animPct   = pct * anim.value;
                        final double animEmpty = (1.0 - animPct).clamp(0.0, 1.0);
                        return PieChart(
                          PieChartData(
                            startDegreeOffset: -90,
                            sectionsSpace: 2,
                            centerSpaceRadius: 48,
                            sections: animPct <= 0.001
                                ? [
                              PieChartSectionData(
                                  value: 1,
                                  color: _borderC(isDark),
                                  radius: 18,
                                  showTitle: false),
                            ]
                                : [
                              PieChartSectionData(
                                  value: animPct,
                                  color: ringColor,
                                  radius: 20,
                                  showTitle: false),
                              if (animEmpty > 0.001)
                                PieChartSectionData(
                                    value: animEmpty,
                                    color: _borderC(isDark),
                                    radius: 18,
                                    showTitle: false),
                            ],
                          ),
                        );
                      },
                    ),
                    AnimatedBuilder(
                      animation: anim,
                      builder: (_, __) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(pctInt * anim.value).round()}%',
                            style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: ringColor),
                          ),
                          Text('Ready',
                              style: TextStyle(
                                  fontSize: 11, color: _subC(isDark))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Overall Readiness',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: _textC(isDark))),
                    const SizedBox(height: 4),
                    Text('$skillsHave of $skillsTarget skills for your dream job',
                        style: TextStyle(fontSize: 12, color: _subC(isDark))),
                    const SizedBox(height: 14),
                    ...dimensions.map((d) => Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: _ProgressDimensionRow(
                          d: d, anim: anim, isDark: isDark),
                    )),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: _borderC(isDark)),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Text(
              _readinessInsight(pctInt),
              key: ValueKey(pctInt ~/ 20),
              style: TextStyle(fontSize: 12, color: _subC(isDark)),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressDimensionRow extends StatelessWidget {
  final _ProgressDimension d;
  final Animation<double> anim;
  final bool isDark;

  const _ProgressDimensionRow({
    required this.d,
    required this.anim,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
              width: 8, height: 8,
              decoration: BoxDecoration(color: d.color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Expanded(
              child: Text(d.label,
                  style: TextStyle(fontSize: 11, color: _textC(isDark)))),
          AnimatedBuilder(
            animation: anim,
            builder: (_, __) => Text(
              '${((d.value * anim.value) * 100).round()}%',
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.bold, color: d.color),
            ),
          ),
        ],
      ),
      const SizedBox(height: 3),
      AnimatedBuilder(
        animation: anim,
        builder: (_, __) => ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (d.value * anim.value).clamp(0.0, 1.0),
            color: d.color,
            backgroundColor: _borderC(isDark),
            minHeight: 5,
          ),
        ),
      ),
    ],
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// Fairness Score Banner
// ══════════════════════════════════════════════════════════════════════════════

class _FairnessScoreBanner extends StatelessWidget {
  final _FairnessData data;
  final bool isDark;
  final VoidCallback onTap;

  const _FairnessScoreBanner({
    required this.data,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark
                ? _withA(data.color, 0.09)
                : _withA(data.color, 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _withA(data.color, 0.32)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: _withA(data.color, 0.08), shape: BoxShape.circle),
                child: Icon(Icons.balance_rounded, color: data.color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Recommendations Fairness Score',
                        style: TextStyle(fontSize: 12, color: _subC(isDark))),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '${data.score}/100',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: data.color),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                              color: data.color,
                              borderRadius: BorderRadius.circular(8)),
                          child: Text('✓ ${data.label}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Text('View report',
                      style: TextStyle(
                          fontSize: 11,
                          color: data.color,
                          fontWeight: FontWeight.w600)),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 12, color: data.color),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Top Job Matches
// ══════════════════════════════════════════════════════════════════════════════

class _TopJobMatches extends StatelessWidget {
  final List<Job> jobs;
  final AppState appState;
  final bool isDark;

  const _TopJobMatches({
    required this.jobs,
    required this.appState,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) {
      return _EmptyCard(
        message:
        'Run a job search to see your top matches here with similarity scores.',
        isDark: isDark,
        icon:  Icons.manage_search_rounded,
        title: 'No matches yet',
      );
    }
    return Column(
      children: jobs.asMap().entries.map((entry) {
        final int rank   = entry.key + 1;
        final Job j      = entry.value;
        final Color iColor = industryColor(j.industry);
        final Color medalColor = rank == 1
            ? Colors.amber
            : rank == 2
            ? Colors.grey.shade400
            : Colors.brown.shade300;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: _cardDeco(isDark),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(color: medalColor, shape: BoxShape.circle),
                child: Center(
                  child: Text('#$rank',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: _withA(iColor, 0.08),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(_industryIcon(j.industry), color: iColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(j.title,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _textC(isDark)),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('${j.company} • ${_formatSalary(j.salary)}',
                        style: TextStyle(fontSize: 11, color: _subC(isDark)),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SimScoreBadge(score: j.simScore),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Learning Progress Card
// ══════════════════════════════════════════════════════════════════════════════

class _LearningProgressCard extends StatelessWidget {
  final AppState appState;
  final bool isDark;

  const _LearningProgressCard({required this.appState, required this.isDark});

  @override
  Widget build(BuildContext context) {
    const int topicsTotal = 10;
    final int topicsDone =
    appState.completedCourseIds.length.clamp(0, topicsTotal);
    final double topicProgress = topicsDone / topicsTotal;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                    color: _withA(AppTheme.accentGreen, 0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.check_circle_outline_rounded,
                    size: 18, color: AppTheme.accentGreen),
              ),
              const SizedBox(width: 10),
              Text('$topicsDone of $topicsTotal topics completed',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _textC(isDark))),
            ],
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: topicProgress),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, double val, __) => ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                  value: val,
                  color: AppTheme.accentGreen,
                  backgroundColor: _borderC(isDark),
                  minHeight: 8),
            ),
          ),
          const SizedBox(height: 4),
          Text('${(topicProgress * 100).toInt()}% of curriculum complete',
              style: TextStyle(fontSize: 11, color: _subC(isDark))),
          const SizedBox(height: 12),
          Text('Complete quizzes to see your skill assessment scores here.',
              style: TextStyle(fontSize: 12, color: _subC(isDark))),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Preference Summary Card
// ══════════════════════════════════════════════════════════════════════════════

class _PreferenceSummaryCard extends StatelessWidget {
  final AppState appState;
  final bool isDark;

  const _PreferenceSummaryCard({required this.appState, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: _withA(AppTheme.accentTeal, 0.08),
                    shape: BoxShape.circle),
                child: const Icon(Icons.tune_rounded,
                    color: AppTheme.accentTeal, size: 18),
              ),
              const SizedBox(width: 10),
              Text('Your Learning Style',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _textC(isDark))),
            ],
          ),
          const SizedBox(height: 12),
          Text(
              'No preferences set yet. Edit your profile to personalise course recommendations.',
              style: TextStyle(fontSize: 12, color: _subC(isDark))),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ProfileInputScreen())),
              icon: const Icon(Icons.edit_rounded, size: 15),
              label: const Text('Edit preferences',
                  style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accentTeal,
                side: const BorderSide(color: AppTheme.accentTeal),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Recent Learning History
// ══════════════════════════════════════════════════════════════════════════════

class _RecentLearningHistory extends StatelessWidget {
  final AppState appState;
  final bool isDark;

  const _RecentLearningHistory({required this.appState, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final List<dynamic> history = appState.learningHistory.take(3).toList();

    if (history.isEmpty) {
      return _EmptyCard(
        message: 'Your completed courses and assessments will appear here.',
        isDark: isDark,
        icon:  Icons.history_edu_rounded,
        title: 'No learning history yet',
      );
    }

    return Container(
      decoration: _cardDeco(isDark),
      child: Column(
        children: history.asMap().entries.map((entry) {
          final int i        = entry.key;
          final dynamic item = entry.value;
          final String title = item is String && item.isNotEmpty ? item : 'Course';
          final bool isLast  = i == history.length - 1;
          return Column(
            children: [
              ListTile(
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                      color: _withA(AppTheme.primaryBlue, 0.07),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.menu_book_rounded,
                      color: AppTheme.primaryBlue, size: 18),
                ),
                title: Text(title,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _textC(isDark)),
                    overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.check_circle_rounded,
                    color: AppTheme.accentGreen, size: 20),
              ),
              if (!isLast)
                Divider(height: 1, indent: 14, endIndent: 14,
                    color: _borderC(isDark)),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Motivation Banner
// ══════════════════════════════════════════════════════════════════════════════

class _MotivationBanner extends StatelessWidget {
  final AppState appState;
  final bool isDark;

  const _MotivationBanner({required this.appState, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final int streak  = _asInt(appState.learningStreak);
    final int missing = _asInt(appState.skillsMissingCount);

    final String emoji;
    final String text;
    final Color color;

    if (streak >= 7) {
      emoji = '🔥';
      text  = '$streak-day streak — absolutely unstoppable!';
      color = Colors.deepOrange;
    } else if (streak >= 3) {
      emoji = '⚡';
      text  = '$streak days in a row! Keep the momentum going.';
      color = Colors.amber.shade700;
    } else if (missing <= 0) {
      emoji = '🚀';
      text  = 'Profile complete. Start applying today!';
      color = _kSuccess;
    } else {
      emoji = '💡';
      text  = '$missing more skill${missing == 1 ? '' : 's'} to reach your dream job!';
      color = Colors.amber.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: isDark ? _withA(color, 0.1) : _withA(color, 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _withA(color, 0.4)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _textC(isDark))),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Streak Nudge
// ══════════════════════════════════════════════════════════════════════════════

class _StreakNudge extends StatelessWidget {
  final bool isDark;
  final VoidCallback onDismiss;

  const _StreakNudge({required this.isDark, required this.onDismiss});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: isDark ? _withA(Colors.blue, 0.24) : Colors.blue.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.blue.shade200),
    ),
    child: Row(
      children: [
        const Icon(Icons.school_outlined,
            color: AppTheme.primaryBlue, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
              'Complete a course today to start your learning streak!',
              style: TextStyle(fontSize: 12, color: _textC(isDark))),
        ),
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onDismiss();
          },
          child: Icon(Icons.close_rounded, size: 16, color: _subC(isDark)),
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// Skill Progress Card
// ══════════════════════════════════════════════════════════════════════════════

class _SkillProgressCard extends StatelessWidget {
  final AppState appState;
  final bool isDark;

  static const List<Color> _chipColors = [
    AppTheme.primaryBlue,
    AppTheme.accentGreen,
    AppTheme.accentTeal,
    Colors.purple,
    Colors.orange,
    Colors.indigo,
    Colors.teal,
    Colors.pink,
  ];

  const _SkillProgressCard({required this.appState, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final List<String> skills = appState.userSkills;

    if (skills.isEmpty) {
      return _EmptyCard(
        message:
        'No skills added yet. Upload your CV or enter skills to see progress.',
        isDark: isDark,
        icon:  Icons.psychology_outlined,
      );
    }

    final List<String> preview = skills.take(8).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${skills.length} skills in your profile',
                  style: TextStyle(fontSize: 12, color: _subC(isDark))),
              const Spacer(),
              Text(
                '${((skills.length / 10) * 100).clamp(0, 100).toInt()}% of goal',
                style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: (skills.length / 10).clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, double val, __) => ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                  value: val,
                  color: AppTheme.primaryBlue,
                  backgroundColor: _borderC(isDark),
                  minHeight: 8),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: preview.asMap().entries.map((e) {
              final Color color = _chipColors[e.key % _chipColors.length];
              return Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _withA(color, 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _withA(color, 0.3)),
                ),
                child: Text(e.value,
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              );
            }).toList(),
          ),
          if (skills.length > 8)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('+${skills.length - 8} more skills',
                  style: TextStyle(fontSize: 11, color: _subC(isDark))),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Weekly Tracker
// ══════════════════════════════════════════════════════════════════════════════

class _WeeklyTracker extends StatelessWidget {
  final AppState appState;
  final bool isDark;

  static const List<String> _days     = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const List<String> _daysFull =
  ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  const _WeeklyTracker({required this.appState, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final int streak = _asInt(appState.learningStreak);
    final int active = streak.clamp(0, 7);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_fire_department_rounded,
                  color: Colors.orange, size: 20),
              const SizedBox(width: 6),
              Text(
                streak > 0
                    ? '$streak-day learning streak 🔥'
                    : 'Start your streak today!',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: _textC(isDark)),
              ),
              const Spacer(),
              if (streak > 0)
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: _withA(Colors.orange, 0.12),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    streak >= 7 ? '🏆 Week done!' : '$streak / 7',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final bool on      = i < active;
              final bool isToday = on && i == active - 1;
              return Tooltip(
                message: _daysFull[i],
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOut,
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: on
                            ? (isToday ? Colors.orange : AppTheme.primaryBlue)
                            : _borderC(isDark),
                        border: isToday
                            ? Border.all(color: Colors.orange, width: 2)
                            : null,
                        boxShadow: isToday
                            ? [
                          BoxShadow(
                              color: _withA(Colors.orange, 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 3))
                        ]
                            : null,
                      ),
                      child: Center(
                        child: on
                            ? Icon(
                          isToday
                              ? Icons.local_fire_department_rounded
                              : Icons.check_rounded,
                          color: Colors.white,
                          size: 16,
                        )
                            : Text(_days[i],
                            style: TextStyle(
                                fontSize: 11, color: _subC(isDark))),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(_daysFull[i],
                        style: TextStyle(
                            fontSize: 9,
                            color: on ? AppTheme.primaryBlue : _subC(isDark))),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Text(
            streak == 0
                ? 'Complete a course today to begin your streak!'
                : streak >= 7
                ? 'Amazing! Full week complete. Keep going next week!'
                : 'Complete a course today to keep your streak alive.',
            style: TextStyle(fontSize: 11, color: _subC(isDark)),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Saved Jobs List
// ══════════════════════════════════════════════════════════════════════════════

class _SavedJobsList extends StatelessWidget {
  final List<Job> jobs;
  final AppState appState;
  final bool isDark;

  const _SavedJobsList({
    required this.jobs,
    required this.appState,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: jobs.map((Job j) {
        return Dismissible(
          key: ValueKey(j.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
                color: _withA(Colors.redAccent, 0.7),
                borderRadius: BorderRadius.circular(14)),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bookmark_remove_rounded,
                    color: Colors.white, size: 22),
                SizedBox(height: 2),
                Text('Remove',
                    style: TextStyle(color: Colors.white, fontSize: 11)),
              ],
            ),
          ),
          confirmDismiss: (_) async {
            HapticFeedback.mediumImpact();
            return true;
          },
          onDismissed: (_) {
            appState.toggleSaveJob(_idInt(j.id));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${j.title} removed from saved jobs'),
                action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () => appState.toggleSaveJob(_idInt(j.id))),
                duration: const Duration(seconds: 3),
              ),
            );
          },
          child: _SavedJobCard(job: j, appState: appState, isDark: isDark),
        );
      }).toList(),
    );
  }
}

class _SavedJobCard extends StatelessWidget {
  final Job job;
  final AppState appState;
  final bool isDark;

  const _SavedJobCard({
    required this.job,
    required this.appState,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final Color iColor = industryColor(job.industry);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(isDark),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: _withA(iColor, 0.08),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(_industryIcon(job.industry), color: iColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(job.title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: _textC(isDark)),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('${job.company} • ${_formatSalary(job.salary)}',
                    style: TextStyle(fontSize: 12, color: _subC(isDark)),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: _withA(iColor, 0.08),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(job.industry,
                      style: TextStyle(
                          fontSize: 10,
                          color: iColor,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_rounded,
                color: AppTheme.primaryBlue),
            onPressed: () {
              HapticFeedback.lightImpact();
              appState.toggleSaveJob(_idInt(job.id));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${job.title} removed from saved jobs'),
                  action: SnackBarAction(
                      label: 'Undo',
                      onPressed: () => appState.toggleSaveJob(_idInt(job.id))),
                  duration: const Duration(seconds: 3),
                ),
              );
            },
            tooltip: 'Remove from saved',
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Empty Card
// ══════════════════════════════════════════════════════════════════════════════

class _EmptyCard extends StatelessWidget {
  final String message;
  final bool isDark;
  final IconData icon;
  final String? title;

  const _EmptyCard({
    required this.message,
    required this.isDark,
    required this.icon,
    this.title,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: _bgC(isDark),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _borderC(isDark)),
    ),
    child: Column(
      children: [
        Icon(icon,
            size: 38,
            color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
        const SizedBox(height: 8),
        if (title != null) ...[
          Text(title!,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: _subC(isDark))),
          const SizedBox(height: 4),
        ],
        Text(message,
            style: TextStyle(fontSize: 12, color: _subC(isDark)),
            textAlign: TextAlign.center),
      ],
    ),
  );
}