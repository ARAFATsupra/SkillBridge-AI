// lib/screens/privacy_settings_screen.dart
// UI UPGRADE v3 — "Premium Privacy Dashboard"
// REFACTOR: Removed local _isDark state & duplicate theme toggle button.
//           Dark/light mode now driven by the global app theme via
//           Theme.of(context).brightness, so the whole app stays in sync.
//           All logic, models, mock data, dialogs, and feature behaviour
//           are preserved exactly.
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

// ══════════════════════════════════════════════════════════════════════════════
// MODELS  (unchanged)
// ══════════════════════════════════════════════════════════════════════════════

class _DataCategory {
  final String       title;
  final String       icon;
  final String       summary;
  final String       usage;
  final List<String> items;
  const _DataCategory({
    required this.title,   required this.icon,
    required this.summary, required this.usage,
    required this.items,
  });
}

class _AuditEvent {
  final String   action;
  final String   detail;
  final DateTime time;
  const _AuditEvent(this.action, this.detail, this.time);
}

// ══════════════════════════════════════════════════════════════════════════════
// MOCK DATA  (unchanged)
// ══════════════════════════════════════════════════════════════════════════════

const List<_DataCategory> _dataCategories = [
  _DataCategory(
    title: 'Profile Data', icon: '👤',
    summary: 'Name, email, skills, education',
    usage: 'Used to generate personalised job and skill recommendations.',
    items: [
      'Full name', 'Email address', 'Skills list', 'Education level',
      'Current job title', 'Target job title', 'Career interests',
    ],
  ),
  _DataCategory(
    title: 'Usage Activity', icon: '📱',
    summary: 'Screens visited, features used',
    usage: 'Used to personalise your learning path and content priority.',
    items: [
      'Screens visited', 'Features used', 'Time spent per section',
      'Feedback given', 'Assessment attempts', 'Course interactions',
    ],
  ),
  _DataCategory(
    title: 'Learning Preferences', icon: '🎓',
    summary: 'Content ratings, feedback',
    usage: 'Used to match courses to your learning style and skill level.',
    items: [
      'Content ratings', 'Preferred formats', 'Preferred length',
      'Difficulty preference', 'Feedback history', 'Completion rates',
    ],
  ),
];

final List<_AuditEvent> _auditLog = [
  _AuditEvent('Profile viewed', 'You viewed your career profile',
      DateTime.now().subtract(const Duration(hours: 1))),
  _AuditEvent('Assessment completed', 'Python — Variables & Data Types (85%)',
      DateTime.now().subtract(const Duration(hours: 3))),
  _AuditEvent('Job match generated', '3 new job recommendations created',
      DateTime.now().subtract(const Duration(hours: 5))),
  _AuditEvent('Data export requested', 'You requested a data export',
      DateTime.now().subtract(const Duration(days: 1))),
  _AuditEvent('Location updated', 'Preferred location set to Dhaka',
      DateTime.now().subtract(const Duration(days: 2))),
  _AuditEvent('Alert created', 'New job alert: Data Science in Dhaka',
      DateTime.now().subtract(const Duration(days: 3))),
  _AuditEvent('Course rated', 'ML Specialization rated 5 stars',
      DateTime.now().subtract(const Duration(days: 5))),
  _AuditEvent('Login', 'Account accessed via mobile app',
      DateTime.now().subtract(const Duration(days: 6))),
  _AuditEvent('Profile updated', 'Skills list updated (added Python)',
      DateTime.now().subtract(const Duration(days: 8))),
  _AuditEvent('Account created', 'SkillBridge AI account registered',
      DateTime.now().subtract(const Duration(days: 30))),
];

// ══════════════════════════════════════════════════════════════════════════════
// DESIGN TOKENS  (unchanged)
// ══════════════════════════════════════════════════════════════════════════════

const _primaryBlue  = Color(0xFF2563EB);
const _accentBlue   = Color(0xFF3B82F6);
const _blue50       = Color(0xFFEFF6FF);
const _success      = Color(0xFF10B981);
const _successBg    = Color(0xFFECFDF5);
const _error        = Color(0xFFEF4444);
const _warning      = Color(0xFFF59E0B);
const _warningBg    = Color(0xFFFFFBEB);
const _purple       = Color(0xFF8B5CF6);
const _purpleBg     = Color(0xFFF5F3FF);

const _bgLight      = Color(0xFFF1F5F9);
const _cardLight    = Color(0xFFFFFFFF);
const _surfaceLight = Color(0xFFF8FAFC);
const _textLight    = Color(0xFF0F172A);
const _subLight     = Color(0xFF64748B);
const _borderLight  = Color(0xFFE2E8F0);

const _bgDark       = Color(0xFF0A0F1E);
const _cardDark     = Color(0xFF141B2D);
const _surfaceDark  = Color(0xFF1A2234);
const _textDark     = Color(0xFFF1F5F9);
const _subDark      = Color(0xFF94A3B8);
const _borderDark   = Color(0xFF1E293B);

// ── Category configurations ───────────────────────────────────────────────────
const _catConfigs = [
  (Icons.person_rounded,    _blue50,     _primaryBlue, 'Identity'),
  (Icons.analytics_rounded, _warningBg,  _warning,     'Behaviour'),
  (Icons.tune_rounded,      _successBg,  _success,     'Learning'),
];

// ══════════════════════════════════════════════════════════════════════════════
// SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() =>
      _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen>
    with TickerProviderStateMixin {

  // ── State ──────────────────────────────────────────────────────────────────
  final Set<int> _expanded = {};
  bool _shareAnon          = true;
  bool _careerTrend        = true;
  bool _jobAlerts          = true;
  bool _assessHistory      = true;

  // NOTE: _isDark is NO longer mutable state. It is computed from the global
  // theme in build() and cached here so all helper methods can read it without
  // needing a BuildContext parameter. It is set once per frame at the top of
  // build() — do not call setState() on it.
  bool _isDark = false;

  late final AnimationController _headerCtrl;

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..forward();
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    super.dispose();
  }

  // ── Theme helpers (read-only — driven by global theme) ─────────────────────
  Color get _bg        => _isDark ? _bgDark      : _bgLight;
  Color get _cardColor => _isDark ? _cardDark    : _cardLight;
  Color get _surface   => _isDark ? _surfaceDark : _surfaceLight;
  Color get _text      => _isDark ? _textDark    : _textLight;
  Color get _sub       => _isDark ? _subDark     : _subLight;
  Color get _border    => _isDark ? _borderDark  : _borderLight;
  Color get _lightBlue =>
      _isDark ? const Color(0xFF172554) : _blue50;

  // ── Logic (unchanged) ─────────────────────────────────────────────────────

  void _showDownloadDialog() => showDialog<void>(
    context: context,
    builder: (_) => _StyledDialog(
      icon: Icons.download_rounded,
      iconColor: _primaryBlue,
      title: 'Data Export',
      message:
      'Your data export will be ready in 24 hours. '
          "We'll send a download link to your registered email address.",
      isDark: _isDark,
    ),
  );

  void _showDeleteDialog() {
    final ctrl      = TextEditingController();
    bool  confirmed = false;
    showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => _DeleteDialog(
          ctrl:      ctrl,
          confirmed: confirmed,
          isDark:    _isDark,
          onChanged: (v) => setSt(() => confirmed = v == 'DELETE'),
          onConfirm: () => Navigator.pop(ctx),
          onCancel:  () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  void _showAuditLog() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AuditLogSheet(
      isDark: _isDark,
      card:   _cardColor,
      border: _border,
      text:   _text,
      sub:    _sub,
    ),
  );

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  // ── Shared micro-widgets ───────────────────────────────────────────────────

  Widget _buildCard({required Widget child, EdgeInsets? padding}) => Container(
    decoration: BoxDecoration(
      color:        _cardColor,
      borderRadius: BorderRadius.circular(20),
      border:       Border.all(color: _border),
      boxShadow: [
        BoxShadow(
          color: _isDark
              ? Colors.black.withValues(alpha: 0.35)
              : const Color(0xFF0F172A).withValues(alpha: 0.06),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    padding: padding ?? const EdgeInsets.all(18),
    child: child,
  );

  Widget _iconBox(
      IconData icon,
      Color bg,
      Color fg, {
        double size = 40,
      }) =>
      Container(
        width:  size,
        height: size,
        decoration: BoxDecoration(
          color:        bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: fg, size: size * 0.48),
      );

  Widget _sectionLabel(String label, {Color? accentColor}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      Container(
        width:  3,
        height: 14,
        decoration: BoxDecoration(
          color:        accentColor ?? _primaryBlue,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize:      12,
          fontWeight:    FontWeight.w800,
          color:         _sub,
          letterSpacing: 1.4,
        ),
      ),
    ]),
  );

  Widget _chip(String label, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color:        bg,
      borderRadius: BorderRadius.circular(100),
      border: Border.all(color: fg.withValues(alpha: 0.25)),
    ),
    child: Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontSize:   11,
        fontWeight: FontWeight.w700,
        color:      fg,
      ),
    ),
  );

  Widget _divider() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Divider(height: 1, color: _border),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    // Sync _isDark with the GLOBAL app theme every frame.
    // This is the only place _isDark is assigned — no setState needed.
    _isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: _bg,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar:          _buildAppBar(),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child:
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // S1 — Trust banner
            _buildTrustBanner()
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.06, curve: Curves.easeOut),

            const SizedBox(height: 24),

            // S2 — Privacy Score
            _buildPrivacyScore()
                .animate()
                .fadeIn(duration: 400.ms, delay: 50.ms)
                .slideY(begin: 0.06, curve: Curves.easeOut),

            const SizedBox(height: 24),

            // S3 — What We Collect
            _sectionLabel('WHAT WE COLLECT'),
            ..._dataCategories.asMap().entries.map((e) =>
                _buildExpandableCard(e.key, e.value)
                    .animate()
                    .fadeIn(
                    delay: Duration(milliseconds: 80 + e.key * 70))
                    .slideY(begin: 0.05, curve: Curves.easeOut)),

            const SizedBox(height: 24),

            // S4 — Data Controls
            _sectionLabel('YOUR DATA CONTROLS'),
            _buildDataControls()
                .animate()
                .fadeIn(duration: 400.ms, delay: 200.ms)
                .slideY(begin: 0.05, curve: Curves.easeOut),

            const SizedBox(height: 24),

            // S5 — Retention Policy
            _sectionLabel('RETENTION POLICY'),
            _buildRetentionNotice()
                .animate()
                .fadeIn(duration: 400.ms, delay: 240.ms)
                .slideY(begin: 0.05, curve: Curves.easeOut),

            const SizedBox(height: 24),

            // S6 — Your Rights
            _sectionLabel('YOUR RIGHTS'),
            _buildRightsGrid()
                .animate()
                .fadeIn(duration: 400.ms, delay: 280.ms),

            const SizedBox(height: 24),

            // S7 — Compliance Footer
            _buildComplianceFooter()
                .animate()
                .fadeIn(duration: 400.ms, delay: 320.ms),
          ]),
        ),
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────
  // REMOVED: local _darkToggle() from actions. Theme is now controlled
  // globally by the single app-level toggle (wherever it lives in your nav).
  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor:        _bg,
    elevation:              0,
    scrolledUnderElevation: 0,
    foregroundColor:        _text,
    leading: IconButton(
      icon: Icon(Icons.arrow_back_ios_new_rounded, color: _text, size: 20),
      onPressed: () => Navigator.maybePop(context),
    ),
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Privacy & Data',
          style: GoogleFonts.plusJakartaSans(
            fontSize:   18,
            fontWeight: FontWeight.w800,
            color:      _text,
          ),
        ),
        Text(
          'Control how your data is used',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color:    _sub,
          ),
        ),
      ],
    ),
    // No actions — the global theme toggle lives in main_nav / app bar,
    // not duplicated on every screen.
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: _border),
    ),
  );

  // ── S1: Trust Banner ───────────────────────────────────────────────────────
  Widget _buildTrustBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isDark
              ? [const Color(0xFF1E3A5F), const Color(0xFF1A2E5A)]
              : [const Color(0xFFEFF6FF), const Color(0xFFE0EFFE)],
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: _primaryBlue.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width:  52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_primaryBlue, _accentBlue],
                begin:  Alignment.topLeft,
                end:    Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color:      _primaryBlue.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset:     const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.verified_user_rounded,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Privacy Matters',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize:   16,
                    fontWeight: FontWeight.w800,
                    color:      _text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'All your data is encrypted and under your full control. '
                      'You decide what we use and for how long.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color:    _sub,
                    height:   1.5,
                  ),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  _chip('AES-256', _lightBlue, _primaryBlue),
                  const SizedBox(width: 6),
                  _chip('TLS 1.3', _lightBlue, _primaryBlue),
                  const SizedBox(width: 6),
                  _chip('No Sale', _successBg, _success),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── S2: Privacy Score ──────────────────────────────────────────────────────
  Widget _buildPrivacyScore() {
    final activeCount =
        [_shareAnon, _careerTrend, _jobAlerts, _assessHistory]
            .where((v) => v)
            .length;
    final score = ((4 - activeCount) / 4 * 100).round();
    final Color scoreColor = score >= 75
        ? _success
        : score >= 50
        ? _warning
        : _error;

    return _buildCard(
      child: Row(children: [
        // Score ring
        SizedBox(
          width:  72,
          height: 72,
          child: Stack(alignment: Alignment.center, children: [
            TweenAnimationBuilder<double>(
              tween:    Tween(begin: 0, end: score / 100),
              duration: const Duration(milliseconds: 900),
              curve:    Curves.easeOut,
              builder: (_, val, __) => CircularProgressIndicator(
                value:      val,
                strokeWidth: 7,
                strokeCap:  StrokeCap.round,
                backgroundColor: _border,
                valueColor:
                AlwaysStoppedAnimation<Color>(scoreColor),
              ),
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                '$score',
                style: GoogleFonts.plusJakartaSans(
                  fontSize:   20,
                  fontWeight: FontWeight.w900,
                  color:      scoreColor,
                  height:     1,
                ),
              ),
              Text(
                '%',
                style: GoogleFonts.plusJakartaSans(
                  fontSize:   9,
                  fontWeight: FontWeight.w700,
                  color:      scoreColor,
                ),
              ),
            ]),
          ]),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Privacy Score',
                style: GoogleFonts.plusJakartaSans(
                  fontSize:   15,
                  fontWeight: FontWeight.w800,
                  color:      _text,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                score >= 75
                    ? 'Excellent — minimal data shared'
                    : score >= 50
                    ? 'Good — some sharing enabled'
                    : 'Open — most sharing enabled',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, color: _sub),
              ),
              const SizedBox(height: 10),
              // Mini bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: TweenAnimationBuilder<double>(
                  tween:    Tween(begin: 0, end: score / 100),
                  duration: const Duration(milliseconds: 900),
                  curve:    Curves.easeOut,
                  builder: (_, val, __) => LinearProgressIndicator(
                    value:           val,
                    color:           scoreColor,
                    backgroundColor: _border,
                    minHeight:       6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  // ── S3: Expandable Data Category Cards ────────────────────────────────────
  Widget _buildExpandableCard(int idx, _DataCategory cat) {
    final isExpanded = _expanded.contains(idx);
    final cfg        = _catConfigs[idx.clamp(0, 2)];
    final catColor   = cfg.$3;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color:        _cardColor,
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(
          color: isExpanded
              ? catColor.withValues(alpha: 0.4)
              : _border,
          width: isExpanded ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _isDark
                ? Colors.black.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset:     const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(children: [
        // ── Header ──────────────────────────────────────────────────
        GestureDetector(
          onTap: () => setState(() {
            if (_expanded.contains(idx)) {
              _expanded.remove(idx);
            } else {
              _expanded.add(idx);
            }
          }),
          child: Container(
            color:   Colors.transparent,
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              // Numbered icon
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  _iconBox(cfg.$1, cfg.$2, cfg.$3, size: 44),
                  Container(
                    width:  16,
                    height: 16,
                    decoration: BoxDecoration(
                      color:  catColor,
                      shape:  BoxShape.circle,
                      border: Border.all(
                          color: _cardColor, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        '${idx + 1}',
                        style: const TextStyle(
                          color:      Colors.white,
                          fontSize:   8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cat.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize:   15,
                        fontWeight: FontWeight.w700,
                        color:      _text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      cat.summary,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, color: _sub),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width:  30,
                height: 30,
                decoration: BoxDecoration(
                  color: isExpanded
                      ? catColor.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: AnimatedRotation(
                  turns:    isExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 220),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: isExpanded ? catColor : _sub,
                    size:  20,
                  ),
                ),
              ),
            ]),
          ),
        ),
        // ── Expanded body ────────────────────────────────────────────
        AnimatedCrossFade(
          duration:       const Duration(milliseconds: 250),
          crossFadeState: isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild:  const SizedBox.shrink(),
          secondChild: Container(
            width:   double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            color:   _surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 1, color: _border),
                const SizedBox(height: 14),
                // Usage description
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:        catColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: catColor.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: catColor, size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          cat.usage,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color:    _sub,
                            height:   1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Data points collected:',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize:   11,
                    fontWeight: FontWeight.w700,
                    color:      _sub,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing:    6,
                  runSpacing: 6,
                  children: cat.items
                      .map((item) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.08),
                      borderRadius:
                      BorderRadius.circular(100),
                      border: Border.all(
                        color: catColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      item,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize:   11,
                        fontWeight: FontWeight.w600,
                        color:      catColor,
                      ),
                    ),
                  ))
                      .toList(),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color:        _successBg,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_rounded,
                              color: _success, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            'Encrypted',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize:   11,
                              fontWeight: FontWeight.w700,
                              color:      _success,
                            ),
                          ),
                        ]),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.block_rounded,
                              color: _sub, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            'Never Sold',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize:   11,
                              fontWeight: FontWeight.w700,
                              color:      _sub,
                            ),
                          ),
                        ]),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  // ── S4: Data Controls ─────────────────────────────────────────────────────
  Widget _buildDataControls() => _buildCard(
    child: Column(children: [
      _toggleRow(
        icon:      Icons.share_outlined,
        iconBg:    _lightBlue,
        iconFg:    _primaryBlue,
        title:     'Improve Recommendations',
        desc:      'Share anonymous activity data to personalise results',
        value:     _shareAnon,
        onChanged: (v) => setState(() => _shareAnon = v),
      ),
      _divider(),
      _toggleRow(
        icon:      Icons.trending_up_rounded,
        iconBg:    _successBg,
        iconFg:    _success,
        title:     'Career Trend Analysis',
        desc:      'Use my activity for workforce insights',
        value:     _careerTrend,
        onChanged: (v) => setState(() => _careerTrend = v),
      ),
      _divider(),
      _toggleRow(
        icon:      Icons.notifications_outlined,
        iconBg:    _warningBg,
        iconFg:    _warning,
        title:     'Job Alerts',
        desc:      'Receive personalised job notifications',
        value:     _jobAlerts,
        onChanged: (v) => setState(() => _jobAlerts = v),
      ),
      _divider(),
      _toggleRow(
        icon:      Icons.history_rounded,
        iconBg:    _lightBlue,
        iconFg:    _primaryBlue,
        title:     'Assessment History',
        desc:      'Store quiz progress locally',
        value:     _assessHistory,
        onChanged: (v) => setState(() => _assessHistory = v),
      ),
    ]),
  );

  Widget _toggleRow({
    required IconData           icon,
    required Color              iconBg,
    required Color              iconFg,
    required String             title,
    required String             desc,
    required bool               value,
    required ValueChanged<bool> onChanged,
  }) =>
      Row(children: [
        _iconBox(icon, iconBg, iconFg, size: 42),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize:   14,
                  fontWeight: FontWeight.w600,
                  color:      _text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, color: _sub),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Switch.adaptive(
          value:                 value,
          onChanged:             onChanged,
          activeTrackColor:      _primaryBlue,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ]);

  // ── S5: Retention Notice ──────────────────────────────────────────────────
  Widget _buildRetentionNotice() {
    final stages = [
      (_primaryBlue, 'Active  ·  12 months',  'Stored and actively used'),
      (_warning,     'Archived  ·  24 months', 'Stored but not actively used'),
      (_success,     'Deleted',                'Permanently removed'),
    ];

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _iconBox(Icons.access_time_rounded,
                _lightBlue, _primaryBlue, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Data Retention Policy',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize:   15,
                      fontWeight: FontWeight.w700,
                      color:      _text,
                    ),
                  ),
                  Text(
                    'How long we keep your data',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, color: _sub),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 18),
          // Timeline
          ...stages.asMap().entries.map((e) {
            final isLast = e.key == stages.length - 1;
            final stage  = e.value;
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timeline connector
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width:  14,
                        height: 14,
                        decoration: BoxDecoration(
                          color:  stage.$1,
                          shape:  BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color:      stage.$1.withValues(alpha: 0.4),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: stage.$1.withValues(alpha: 0.25),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          bottom: isLast ? 0 : 18),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            stage.$2,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize:   14,
                              fontWeight: FontWeight.w700,
                              color:      _text,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            stage.$3,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 12, color: _sub),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color:        _surface,
              borderRadius: BorderRadius.circular(10),
              border:       Border.all(color: _border),
            ),
            child: Row(children: [
              const Icon(Icons.calendar_today_outlined,
                  color: _primaryBlue, size: 14),
              const SizedBox(width: 8),
              Text(
                'Last data review: ${_formatDate(DateTime.now().subtract(const Duration(days: 7)))}',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, color: _sub),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // ── S6: Rights Grid ───────────────────────────────────────────────────────
  Widget _buildRightsGrid() {
    final rights = [
      (Icons.download_rounded,       _primaryBlue, 'Download Data',
      'Export your info',       _showDownloadDialog),
      (Icons.edit_outlined,          _warning,     'Correct Data',
      'Update profile',         () {}),
      (Icons.delete_outline_rounded, _error,       'Delete Account',
      'Remove everything',      _showDeleteDialog),
      (Icons.list_alt_rounded,       _purple,      'Audit Log',
      'See access history',     _showAuditLog),
    ];

    return GridView.count(
      shrinkWrap:       true,
      physics:          const NeverScrollableScrollPhysics(),
      crossAxisCount:   2,
      crossAxisSpacing: 10,
      mainAxisSpacing:  10,
      childAspectRatio: 1.45,
      children: rights.map((r) {
        return _RightsTile(
          icon:     r.$1,
          color:    r.$2,
          label:    r.$3,
          subtitle: r.$4,
          onTap:    r.$5,
          isDark:   _isDark,
          card:     _cardColor,
          border:   _border,
          text:     _text,
          sub:      _sub,
        );
      }).toList(),
    );
  }

  // ── S7: Compliance Footer ─────────────────────────────────────────────────
  Widget _buildComplianceFooter() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:        _surface,
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width:  40,
              height: 40,
              decoration: BoxDecoration(
                color:        _lightBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.shield_rounded,
                  color: _primaryBlue, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Compliance & Standards',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize:   15,
                      fontWeight: FontWeight.w700,
                      color:      _text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'SkillBridge AI follows GDPR and PDPA data protection standards. '
                        'Your data is encrypted at rest (AES-256) and in transit (TLS 1.3).',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color:    _sub,
                      height:   1.55,
                    ),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _chip('GDPR',    _lightBlue, _primaryBlue),
            _chip('PDPA',    _lightBlue, _primaryBlue),
            _chip('AES-256', _successBg, _success),
            _chip('TLS 1.3', _successBg, _success),
            _chip('No Sale', _warningBg, _warning),
          ]),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () {},
            child: Row(children: [
              Text(
                'Read full Privacy Policy →',
                style: GoogleFonts.plusJakartaSans(
                  fontSize:   13,
                  fontWeight: FontWeight.w700,
                  color:      _primaryBlue,
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// EXTRACTED SUB-WIDGETS  (unchanged)
// ══════════════════════════════════════════════════════════════════════════════

// ── Rights grid tile ──────────────────────────────────────────────────────────
class _RightsTile extends StatefulWidget {
  final IconData     icon;
  final Color        color;
  final String       label;
  final String       subtitle;
  final VoidCallback onTap;
  final bool         isDark;
  final Color        card;
  final Color        border;
  final Color        text;
  final Color        sub;

  const _RightsTile({
    required this.icon,     required this.color,
    required this.label,    required this.subtitle,
    required this.onTap,    required this.isDark,
    required this.card,     required this.border,
    required this.text,     required this.sub,
  });

  @override
  State<_RightsTile> createState() => _RightsTileState();
}

class _RightsTileState extends State<_RightsTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) => setState(() => _pressed = false),
      onTapCancel: ()  => setState(() => _pressed = false),
      onTap:       widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: _pressed
              ? widget.color.withValues(alpha: 0.08)
              : widget.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _pressed
                ? widget.color.withValues(alpha: 0.4)
                : widget.border,
            width: _pressed ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.isDark
                  ? Colors.black.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset:     const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width:  46,
              height: 46,
              decoration: BoxDecoration(
                color:        widget.color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(widget.icon, color: widget.color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              widget.label,
              style: GoogleFonts.plusJakartaSans(
                fontSize:   13,
                fontWeight: FontWeight.w700,
                color:      widget.text,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              widget.subtitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                color:    widget.sub,
              ),
              textAlign: TextAlign.center,
              maxLines:  1,
              overflow:  TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Audit Log bottom sheet ────────────────────────────────────────────────────
class _AuditLogSheet extends StatelessWidget {
  final bool   isDark;
  final Color  card;
  final Color  border;
  final Color  text;
  final Color  sub;

  const _AuditLogSheet({
    required this.isDark,  required this.card,
    required this.border,  required this.text,
    required this.sub,
  });

  String _timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inHours < 1)  return 'Just now';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Color _eventColor(String action) {
    if (action.contains('deleted') || action.contains('Delete')) return _error;
    if (action.contains('Assessment') || action.contains('rated')) return _success;
    if (action.contains('export')     || action.contains('Export')) return _warning;
    return _primaryBlue;
  }

  IconData _eventIcon(String action) {
    if (action.contains('Profile'))    return Icons.person_rounded;
    if (action.contains('Assessment')) return Icons.quiz_rounded;
    if (action.contains('Job'))        return Icons.work_rounded;
    if (action.contains('export'))     return Icons.download_rounded;
    if (action.contains('Location'))   return Icons.location_on_rounded;
    if (action.contains('Alert'))      return Icons.notifications_rounded;
    if (action.contains('Course'))     return Icons.school_rounded;
    if (action.contains('Login'))      return Icons.lock_open_rounded;
    if (action.contains('created'))    return Icons.person_add_rounded;
    return Icons.history_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        expand:           false,
        initialChildSize: 0.62,
        maxChildSize:     0.92,
        builder: (_, scroll) => Column(children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width:  40,
              height: 4,
              decoration: BoxDecoration(
                color:        border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(children: [
              Container(
                width:  38,
                height: 38,
                decoration: BoxDecoration(
                  color:        _purpleBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.list_alt_rounded,
                    color: _purple, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Data Access Audit Log',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize:   16,
                        color:      text,
                      ),
                    ),
                    Text(
                      'Last ${_auditLog.length} events',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 11, color: sub),
                    ),
                  ],
                ),
              ),
            ]),
          ),
          Divider(height: 1, color: border),
          // List
          Expanded(
            child: ListView.separated(
              controller:  scroll,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount:   _auditLog.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (_, i) {
                final e     = _auditLog[i];
                final color = _eventColor(e.action);
                final icon  = _eventIcon(e.action);

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1A2234)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(children: [
                    Container(
                      width:  34,
                      height: 34,
                      decoration: BoxDecoration(
                        color:        color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(icon, color: color, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.action,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize:   13,
                              color:      text,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            e.detail,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 11, color: sub),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color:        color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _timeAgo(e.time),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize:   10,
                          fontWeight: FontWeight.w700,
                          color:      color,
                        ),
                      ),
                    ),
                  ]),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Generic styled dialog ─────────────────────────────────────────────────────
class _StyledDialog extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final String   title;
  final String   message;
  final bool     isDark;

  const _StyledDialog({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cardC = isDark ? _cardDark : _cardLight;
    final textC = isDark ? _textDark : _textLight;
    final subC  = isDark ? _subDark  : _subLight;

    return Dialog(
      backgroundColor: cardC,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width:  56,
            height: 56,
            decoration: BoxDecoration(
              color:        iconColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize:   17,
              fontWeight: FontWeight.w800,
              color:      textC,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 13, color: subC, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: iconColor,
                foregroundColor: Colors.white,
                elevation:       0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: GoogleFonts.plusJakartaSans(
                  fontSize:   14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Got it'),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Delete confirmation dialog ────────────────────────────────────────────────
class _DeleteDialog extends StatelessWidget {
  final TextEditingController ctrl;
  final bool                  confirmed;
  final bool                  isDark;
  final ValueChanged<String>  onChanged;
  final VoidCallback          onConfirm;
  final VoidCallback          onCancel;

  const _DeleteDialog({
    required this.ctrl,      required this.confirmed,
    required this.isDark,    required this.onChanged,
    required this.onConfirm, required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final cardC   = isDark ? _cardDark   : _cardLight;
    final textC   = isDark ? _textDark   : _textLight;
    final subC    = isDark ? _subDark    : _subLight;
    final borderC = isDark ? _borderDark : _borderLight;

    return Dialog(
      backgroundColor: cardC,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width:  56,
            height: 56,
            decoration: BoxDecoration(
              color:        _error.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delete_forever_rounded,
                color: _error, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            'Delete Account',
            style: GoogleFonts.plusJakartaSans(
              fontSize:   17,
              fontWeight: FontWeight.w800,
              color:      _error,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'This will permanently delete all your data. '
                'This action cannot be undone.',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 13, color: subC, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:        _error.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _error.withValues(alpha: 0.2)),
            ),
            child: TextField(
              controller: ctrl,
              onChanged:  onChanged,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 14, color: textC),
              decoration: InputDecoration(
                hintText:  'Type DELETE to confirm',
                hintStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 13, color: subC),
                border:         InputBorder.none,
                isDense:        true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: borderC),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: Text('Cancel',
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600, color: subC)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: confirmed ? onConfirm : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _error,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _error.withValues(alpha: 0.3),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  textStyle: GoogleFonts.plusJakartaSans(
                    fontSize:   14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Delete'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}