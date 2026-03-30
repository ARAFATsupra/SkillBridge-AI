// lib/screens/profile_input.dart — SkillBridge AI
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  MAXIMUM UPGRADE: "Immersive Guided Profile Setup"                      ║
// ║  REFACTOR: Removed no-op theme toggle. Dark/light now driven globally   ║
// ║  by Theme.of(context).brightness — no local state needed.               ║
// ║  All original logic, Provider writes & validation preserved 100 %.      ║
// ╚══════════════════════════════════════════════════════════════════════════╝

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens — aligned with main.dart's primaryBlue / accentGreen palette
// ─────────────────────────────────────────────────────────────────────────────
class _Pal {
  // Primary (matches main.dart primaryBlue #1565C0 family)
  static const blue500 = Color(0xFF1E88E5);
  static const blue700 = Color(0xFF1565C0);

  // Accent greens
  static const green500 = Color(0xFF22C55E);
  static const green600 = Color(0xFF16A34A);

  // Semantics
  static const red400   = Color(0xFFF87171);
  static const red500   = Color(0xFFEF4444);
  static const amber400 = Color(0xFFFBBF24);

  // Neutral scale — dark mode
  static const slate900 = Color(0xFF0F172A);
  static const slate800 = Color(0xFF1E293B);
  static const slate700 = Color(0xFF334155);
  static const slate600 = Color(0xFF475569);
  static const slate500 = Color(0xFF64748B);
  static const slate400 = Color(0xFF94A3B8);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate50  = Color(0xFFF8FAFC);
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Screen
// ─────────────────────────────────────────────────────────────────────────────
class ProfileInputScreen extends StatefulWidget {
  const ProfileInputScreen({super.key});

  @override
  State<ProfileInputScreen> createState() => _ProfileInputScreenState();
}

class _ProfileInputScreenState extends State<ProfileInputScreen>
    with TickerProviderStateMixin {

  // ── Form ──────────────────────────────────────────────────────────────────
  final _formKey        = GlobalKey<FormState>();
  final _fieldCtrl      = TextEditingController();
  final _gpaCtrl        = TextEditingController();
  final _careerGoalCtrl = TextEditingController();

  int    _yearOfStudy = 1;
  String _expLevel    = 'No Experience';
  double _gpaValue    = 0.0;
  bool   _saving      = false;
  bool   _saved       = false;

  // ── Animation controllers ─────────────────────────────────────────────────
  late final AnimationController _entranceCtrl;
  late final AnimationController _btnCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _progressCtrl;

  late final Animation<double>  _progressAnim;
  late final Animation<double>  _pulseAnim;
  late final Animation<double>  _btnScaleAnim;

  // Per-card stagger animations
  late final List<Animation<double>>  _cardFade;
  late final List<Animation<Offset>>  _cardSlide;

  // ── Experience options ────────────────────────────────────────────────────
  static const _expOptions = [
    'No Experience',
    'Internship',
    'Part-time',
    'Full-time',
  ];

  static const Map<String, IconData> _expIcons = {
    'No Experience': Icons.person_outline_rounded,
    'Internship':    Icons.co_present_rounded,
    'Part-time':     Icons.schedule_rounded,
    'Full-time':     Icons.work_rounded,
  };

  static const Map<String, Color> _expColors = {
    'No Experience': Color(0xFF8B5CF6),
    'Internship':    Color(0xFF0EA5E9),
    'Part-time':     Color(0xFFF59E0B),
    'Full-time':     Color(0xFF10B981),
  };

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _setupAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSavedState();
      _entranceCtrl.forward();
      _progressCtrl.forward();
      _pulseCtrl.repeat(reverse: true);
    });
  }

  void _setupAnimations() {
    // Staggered entrance — 3 cards over 900 ms
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _cardFade = List.generate(3, (i) {
      final start = i * 0.18;
      final end   = start + 0.55;
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _entranceCtrl,
          curve: Interval(
              start.clamp(0.0, 1.0), end.clamp(0.0, 1.0),
              curve: Curves.easeOut),
        ),
      );
    });

    _cardSlide = List.generate(3, (i) {
      final start = i * 0.18;
      final end   = start + 0.55;
      return Tween<Offset>(
        begin: const Offset(0, 0.12),
        end:   Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _entranceCtrl,
          curve: Interval(
              start.clamp(0.0, 1.0), end.clamp(0.0, 1.0),
              curve: Curves.easeOutCubic),
        ),
      );
    });

    // Progress bar
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _progressAnim = Tween<double>(begin: 0, end: 2 / 3).animate(
      CurvedAnimation(parent: _progressCtrl, curve: Curves.easeOut),
    );

    // Step badge pulse
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Save button scale
    _btnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _btnScaleAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _btnCtrl, curve: Curves.easeIn),
    );
  }

  void _loadSavedState() {
    final s = context.read<AppState>();
    _fieldCtrl.text      = s.fieldOfStudy;
    _gpaCtrl.text        = s.gpa > 0 ? s.gpa.toStringAsFixed(1) : '';
    _careerGoalCtrl.text = s.careerGoal;
    if (s.yearOfStudy >= 1 && s.yearOfStudy <= 5) {
      setState(() => _yearOfStudy = s.yearOfStudy);
    }
    _gpaCtrl.addListener(() {
      final v = double.tryParse(_gpaCtrl.text.trim()) ?? 0.0;
      setState(() => _gpaValue = v.clamp(0.0, 4.0));
    });
  }

  @override
  void dispose() {
    _fieldCtrl.dispose();
    _gpaCtrl.dispose();
    _careerGoalCtrl.dispose();
    _entranceCtrl.dispose();
    _btnCtrl.dispose();
    _pulseCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  // ── Save logic (unchanged) ────────────────────────────────────────────────
  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      HapticFeedback.heavyImpact();
      return;
    }
    HapticFeedback.lightImpact();

    // Capture AppState BEFORE any await to avoid using BuildContext
    // across async gaps (use_build_context_synchronously lint).
    final appState = context.read<AppState>();

    await _btnCtrl.forward();
    await _btnCtrl.reverse();

    setState(() => _saving = true);
    final gpa = double.tryParse(_gpaCtrl.text.trim()) ?? 0.0;
    await appState.setProfileInfo(
      fieldOfStudy:    _fieldCtrl.text.trim(),
      gpa:             gpa,
      experienceLevel: _expLevel,
      yearOfStudy:     _yearOfStudy,
      careerGoal:      _careerGoalCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _saving = false;
      _saved  = true;
    });
    HapticFeedback.mediumImpact();

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text(
              'Profile saved successfully!',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: _Pal.green600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
    Navigator.pop(context);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Derive dark mode from the GLOBAL app theme — no local state needed.
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final bgColor     = isDark ? _Pal.slate900 : _Pal.slate50;
    final textColor   = isDark ? Colors.white  : _Pal.slate900;
    final subColor    = isDark ? _Pal.slate400  : _Pal.slate600;
    final borderColor = isDark ? _Pal.slate700  : _Pal.slate200;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildAppBar(isDark, bgColor, textColor, borderColor),
      bottomNavigationBar: _buildBottomBar(isDark, bgColor, borderColor),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Form(
          key: _formKey,
          child: _buildScrollBody(isDark, textColor, subColor, borderColor),
        ),
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────
  // No theme toggle action here — controlled globally from main_nav.
  PreferredSizeWidget _buildAppBar(
      bool isDark, Color bg, Color text, Color border) {
    return AppBar(
      backgroundColor:  bg,
      surfaceTintColor: Colors.transparent,
      elevation:        0,
      systemOverlayStyle: isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      leading: IconButton(
        icon:    Icon(Icons.arrow_back_rounded, color: text),
        tooltip: 'Back',
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width:  28,
            height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_Pal.blue500, _Pal.blue700],
                begin:  Alignment.topLeft,
                end:    Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.person_rounded,
                color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Text(
            'My Profile',
            style: TextStyle(
              fontSize:   17,
              fontWeight: FontWeight.w800,
              color:      text,
            ),
          ),
        ],
      ),
      // Step badge — purely informational, no theme toggle
      actions: [
        ScaleTransition(
          scale: _pulseAnim,
          child: Container(
            margin:  const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_Pal.blue500, _Pal.blue700],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color:      _Pal.blue500.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset:     const Offset(0, 3),
                ),
              ],
            ),
            child: const Text(
              'Step 2 / 3',
              style: TextStyle(
                fontSize:      11,
                fontWeight:    FontWeight.w700,
                color:         Colors.white,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(4),
        child: AnimatedBuilder(
          animation: _progressAnim,
          builder: (_, __) {
            return Stack(
              children: [
                Container(height: 4, color: border),
                FractionallySizedBox(
                  widthFactor: _progressAnim.value,
                  child: Container(
                    height: 4,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_Pal.blue500, _Pal.blue700],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Bottom save bar ───────────────────────────────────────────────────────
  Widget _buildBottomBar(bool isDark, Color bg, Color border) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? _Pal.slate800.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        border: Border(top: BorderSide(color: border)),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 20,
            offset:     const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      child: ScaleTransition(
        scale: _btnScaleAnim,
        child: _SaveButton(
          saving: _saving,
          saved:  _saved,
          onTap:  _save,
        ),
      ),
    );
  }

  // ── Scroll body ───────────────────────────────────────────────────────────
  Widget _buildScrollBody(
      bool isDark, Color text, Color sub, Color border) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      physics: const BouncingScrollPhysics(),
      children: [
        _buildProfileHeader(isDark, text, sub),
        const SizedBox(height: 20),
        _buildAnimatedCard(
          index: 0,
          child: _AcademicCard(
            isDark:      isDark,
            textColor:   text,
            subColor:    sub,
            borderColor: border,
            fieldCtrl:   _fieldCtrl,
            gpaCtrl:     _gpaCtrl,
            gpaValue:    _gpaValue,
            yearOfStudy: _yearOfStudy,
            onYearTap:   (yr) => setState(() => _yearOfStudy = yr),
            inputDec:    _inputDec,
          ),
        ),
        const SizedBox(height: 16),
        _buildAnimatedCard(
          index: 1,
          child: _CareerCard(
            isDark:     isDark,
            textColor:  text,
            subColor:   sub,
            borderColor: border,
            careerCtrl: _careerGoalCtrl,
            expLevel:   _expLevel,
            expOptions: _expOptions,
            expIcons:   _expIcons,
            expColors:  _expColors,
            onExpTap:   (opt) => setState(() => _expLevel = opt),
            inputDec:   _inputDec,
          ),
        ),
        const SizedBox(height: 16),
        _buildAnimatedCard(
          index: 2,
          child: _TipsCard(isDark: isDark, subColor: sub),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildProfileHeader(bool isDark, Color text, Color sub) {
    return FadeTransition(
      opacity: _cardFade[0],
      child: SlideTransition(
        position: _cardSlide[0],
        child: Row(
          children: [
            Container(
              width:  56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_Pal.blue500, _Pal.blue700],
                  begin:  Alignment.topLeft,
                  end:    Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color:      _Pal.blue500.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset:     const Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(Icons.person_rounded,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tell us about yourself',
                    style: TextStyle(
                      fontSize:      18,
                      fontWeight:    FontWeight.w800,
                      color:         text,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Your profile powers AI-matched skills & goals',
                    style: TextStyle(
                      fontSize: 12.5,
                      color:    sub,
                      height:   1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedCard({required int index, required Widget child}) {
    final fade  = _cardFade [index.clamp(0, _cardFade.length - 1)];
    final slide = _cardSlide[index.clamp(0, _cardSlide.length - 1)];
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  }

  // ── Shared input decoration ───────────────────────────────────────────────
  InputDecoration _inputDec(
      String label, {
        required IconData icon,
        required bool     isDark,
        Color?            iconColor,
        String?           hint,
      }) =>
      InputDecoration(
        labelText: label,
        hintText:  hint,
        prefixIcon: Icon(
          icon,
          size:  20,
          color: iconColor ??
              (isDark ? _Pal.slate400 : _Pal.slate600),
        ),
        filled:    true,
        fillColor: isDark ? _Pal.slate900 : _Pal.slate50,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? _Pal.slate700 : _Pal.slate200,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
          const BorderSide(color: _Pal.blue500, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
          const BorderSide(color: _Pal.red500, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
          const BorderSide(color: _Pal.red500, width: 2),
        ),
        labelStyle: TextStyle(
          color:    isDark ? _Pal.slate400 : _Pal.slate600,
          fontSize: 14,
        ),
        hintStyle: TextStyle(
          color:    isDark ? _Pal.slate600 : _Pal.slate400,
          fontSize: 14,
        ),
        errorStyle: const TextStyle(
          color:      _Pal.red500,
          fontSize:   12,
          fontWeight: FontWeight.w500,
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable Card Shell
// ─────────────────────────────────────────────────────────────────────────────
class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.isDark,
    required this.child,
    this.accentColor = _Pal.blue500,
  });

  final bool   isDark;
  final Widget child;
  final Color  accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? _Pal.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? _Pal.slate700.withValues(alpha: 0.6)
              : _Pal.slate200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color:        Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
            blurRadius:   20,
            spreadRadius: -2,
            offset:       const Offset(0, 6),
          ),
          BoxShadow(
            color:        accentColor.withValues(alpha: isDark ? 0.08 : 0.04),
            blurRadius:   24,
            spreadRadius: -4,
            offset:       const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Subtle top-edge gradient accent
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.0),
                      accentColor.withValues(alpha: 0.8),
                      accentColor.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header row
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.textColor,
    required this.accentColor,
  });

  final IconData icon;
  final String   title;
  final Color    textColor;
  final Color    accentColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width:  34,
          height: 34,
          decoration: BoxDecoration(
            color:        accentColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: accentColor, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize:      15,
            fontWeight:    FontWeight.w800,
            color:         textColor,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Academic Background Card
// ─────────────────────────────────────────────────────────────────────────────
class _AcademicCard extends StatelessWidget {
  const _AcademicCard({
    required this.isDark,
    required this.textColor,
    required this.subColor,
    required this.borderColor,
    required this.fieldCtrl,
    required this.gpaCtrl,
    required this.gpaValue,
    required this.yearOfStudy,
    required this.onYearTap,
    required this.inputDec,
  });

  final bool                  isDark;
  final Color                 textColor;
  final Color                 subColor;
  final Color                 borderColor;
  final TextEditingController fieldCtrl;
  final TextEditingController gpaCtrl;
  final double                gpaValue;
  final int                   yearOfStudy;
  final ValueChanged<int>     onYearTap;
  final InputDecoration Function(
      String, {
      required IconData icon,
      required bool isDark,
      Color? iconColor,
      String? hint,
      }) inputDec;

  Color get _gpaColor {
    if (gpaValue >= 3.5) return _Pal.green500;
    if (gpaValue >= 2.5) return _Pal.amber400;
    return _Pal.red400;
  }

  String get _gpaLabel {
    if (gpaValue >= 3.7) return 'Excellent';
    if (gpaValue >= 3.3) return 'Great';
    if (gpaValue >= 2.7) return 'Good';
    if (gpaValue >  0  ) return 'Fair';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      isDark:      isDark,
      accentColor: _Pal.blue500,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon:        Icons.school_rounded,
            title:       'Academic Background',
            textColor:   textColor,
            accentColor: _Pal.blue500,
          ),
          Divider(
            color:  isDark ? _Pal.slate700 : _Pal.slate100,
            height: 28,
          ),

          // Field of Study
          TextFormField(
            controller: fieldCtrl,
            style: TextStyle(
              color:      textColor,
              fontSize:   14,
              fontWeight: FontWeight.w500,
            ),
            decoration: inputDec(
              'Field of Study',
              icon:   Icons.auto_stories_rounded,
              isDark: isDark,
              hint:   'e.g. Computer Science',
            ),
            textInputAction:    TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Please enter your field of study'
                : null,
          ),
          const SizedBox(height: 14),

          // GPA field + live bar
          TextFormField(
            controller: gpaCtrl,
            style: TextStyle(
              color:      textColor,
              fontSize:   14,
              fontWeight: FontWeight.w500,
            ),
            decoration: inputDec(
              'GPA  (0.0 – 4.0)',
              icon:   Icons.grade_rounded,
              isDark: isDark,
              hint:   '3.5',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null;
              final g = double.tryParse(v.trim());
              if (g == null || g < 0 || g > 4.0) {
                return 'Enter a valid GPA between 0.0 and 4.0';
              }
              return null;
            },
          ),

          // GPA feedback bar
          if (gpaValue > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (gpaValue / 4.0).clamp(0.0, 1.0),
                      minHeight:       5,
                      backgroundColor: isDark ? _Pal.slate700 : _Pal.slate100,
                      valueColor:
                      AlwaysStoppedAnimation<Color>(_gpaColor),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _gpaLabel,
                  style: TextStyle(
                    fontSize:      11,
                    fontWeight:    FontWeight.w700,
                    color:         _gpaColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 22),

          // Year of Study
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Year of Study',
                style: TextStyle(
                  fontSize:   13,
                  fontWeight: FontWeight.w700,
                  color:      subColor,
                ),
              ),
              _YearBadge(year: yearOfStudy),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (i) {
              final yr  = i + 1;
              final sel = yearOfStudy == yr;
              return _YearChip(
                year:     yr,
                selected: sel,
                isDark:   isDark,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onYearTap(yr);
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Year Chip
// ─────────────────────────────────────────────────────────────────────────────
class _YearChip extends StatefulWidget {
  const _YearChip({
    required this.year,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });
  final int        year;
  final bool       selected;
  final bool       isDark;
  final VoidCallback onTap;

  @override
  State<_YearChip> createState() => _YearChipState();
}

class _YearChipState extends State<_YearChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.88).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
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
    final sel = widget.selected;
    return GestureDetector(
      onTap: _tap,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve:    Curves.easeOutBack,
          width:    44,
          height:   44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: sel
                ? const LinearGradient(
              colors: [_Pal.blue500, _Pal.blue700],
              begin:  Alignment.topLeft,
              end:    Alignment.bottomRight,
            )
                : null,
            color: sel
                ? null
                : (widget.isDark ? _Pal.slate900 : Colors.white),
            border: sel
                ? null
                : Border.all(
              color: widget.isDark ? _Pal.slate700 : _Pal.slate200,
              width: 1.5,
            ),
            boxShadow: sel
                ? [
              BoxShadow(
                color:      _Pal.blue500.withValues(alpha: 0.42),
                blurRadius: 10,
                offset:     const Offset(0, 4),
              ),
            ]
                : null,
          ),
          child: Center(
            child: Text(
              '${widget.year}',
              style: TextStyle(
                fontSize:   15,
                fontWeight: FontWeight.w800,
                color: sel
                    ? Colors.white
                    : (widget.isDark ? _Pal.slate400 : _Pal.slate600),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Year Badge
// ─────────────────────────────────────────────────────────────────────────────
class _YearBadge extends StatelessWidget {
  const _YearBadge({required this.year});
  final int year;

  static const _suffixes = ['st', 'nd', 'rd', 'th', 'th'];

  String get _label {
    final s = _suffixes[(year - 1).clamp(0, 4)];
    return '$year$s Year';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) =>
          ScaleTransition(scale: anim, child: child),
      child: Container(
        key: ValueKey(year),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color:        _Pal.blue500.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          _label,
          style: const TextStyle(
            fontSize:   11,
            fontWeight: FontWeight.w700,
            color:      _Pal.blue500,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Career Goal Card
// ─────────────────────────────────────────────────────────────────────────────
class _CareerCard extends StatelessWidget {
  const _CareerCard({
    required this.isDark,
    required this.textColor,
    required this.subColor,
    required this.borderColor,
    required this.careerCtrl,
    required this.expLevel,
    required this.expOptions,
    required this.expIcons,
    required this.expColors,
    required this.onExpTap,
    required this.inputDec,
  });

  final bool                              isDark;
  final Color                             textColor;
  final Color                             subColor;
  final Color                             borderColor;
  final TextEditingController             careerCtrl;
  final String                            expLevel;
  final List<String>                      expOptions;
  final Map<String, IconData>             expIcons;
  final Map<String, Color>                expColors;
  final ValueChanged<String>              onExpTap;
  final InputDecoration Function(
      String, {
      required IconData icon,
      required bool isDark,
      Color? iconColor,
      String? hint,
      }) inputDec;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      isDark:      isDark,
      accentColor: _Pal.green500,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon:        Icons.rocket_launch_rounded,
            title:       'Career Goal',
            textColor:   textColor,
            accentColor: _Pal.green500,
          ),
          Divider(
            color:  isDark ? _Pal.slate700 : _Pal.slate100,
            height: 28,
          ),

          TextFormField(
            controller: careerCtrl,
            style: TextStyle(
              color:      textColor,
              fontSize:   14,
              fontWeight: FontWeight.w500,
            ),
            decoration: inputDec(
              'Dream job title',
              icon:   Icons.work_outline_rounded,
              isDark: isDark,
              hint:   'e.g. Senior Software Engineer',
            ),
            textInputAction:    TextInputAction.done,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 22),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Experience Level',
                style: TextStyle(
                  fontSize:   13,
                  fontWeight: FontWeight.w700,
                  color:      subColor,
                ),
              ),
              // Active chip badge
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: Container(
                  key: ValueKey(expLevel),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (expColors[expLevel] ?? _Pal.blue500)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    expLevel,
                    style: TextStyle(
                      fontSize:   11,
                      fontWeight: FontWeight.w700,
                      color:      expColors[expLevel] ?? _Pal.blue500,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          GridView.count(
            crossAxisCount:   2,
            shrinkWrap:       true,
            physics:          const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing:  10,
            childAspectRatio: 2.5,
            children: expOptions.map((opt) {
              final sel   = expLevel == opt;
              final color = expColors[opt] ?? _Pal.blue500;
              return _ExpChip(
                label:    opt,
                icon:     expIcons[opt] ?? Icons.work_outline_rounded,
                color:    color,
                isDark:   isDark,
                selected: sel,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onExpTap(opt);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Experience Chip
// ─────────────────────────────────────────────────────────────────────────────
class _ExpChip extends StatefulWidget {
  const _ExpChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.selected,
    required this.onTap,
  });

  final String     label;
  final IconData   icon;
  final Color      color;
  final bool       isDark;
  final bool       selected;
  final VoidCallback onTap;

  @override
  State<_ExpChip> createState() => _ExpChipState();
}

class _ExpChipState extends State<_ExpChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 110));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.93).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
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
    final sel   = widget.selected;
    final color = widget.color;

    return GestureDetector(
      onTap: _tap,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve:    Curves.easeOutCubic,
          padding:  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: sel
                ? color.withValues(alpha: 0.12)
                : (widget.isDark ? _Pal.slate900 : Colors.white),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: sel
                  ? color
                  : (widget.isDark ? _Pal.slate700 : _Pal.slate200),
              width: sel ? 2 : 1,
            ),
            boxShadow: sel
                ? [
              BoxShadow(
                color:      color.withValues(alpha: 0.2),
                blurRadius: 10,
                offset:     const Offset(0, 3),
              ),
            ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                width:  28,
                height: 28,
                decoration: BoxDecoration(
                  color: sel
                      ? color.withValues(alpha: 0.18)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  widget.icon,
                  color: sel
                      ? color
                      : (widget.isDark ? _Pal.slate400 : _Pal.slate500),
                  size: 17,
                ),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize:   12.5,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w600,
                    color: sel
                        ? color
                        : (widget.isDark ? _Pal.slate300 : _Pal.slate700),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tips Card
// ─────────────────────────────────────────────────────────────────────────────
class _TipsCard extends StatelessWidget {
  const _TipsCard({required this.isDark, required this.subColor});
  final bool  isDark;
  final Color subColor;

  static const _tips = [
    (Icons.bolt_rounded,       'Accurate data improves AI skill recommendations'),
    (Icons.trending_up_rounded,'Update your profile as you progress each year'),
    (Icons.star_rounded,       'Add a career goal to unlock personalised roadmaps'),
  ];

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      isDark:      isDark,
      accentColor: _Pal.amber400,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_rounded, color: _Pal.amber400, size: 18),
              SizedBox(width: 8),
              Text(
                'Pro Tips',
                style: TextStyle(
                  fontSize:      13,
                  fontWeight:    FontWeight.w800,
                  color:         _Pal.amber400,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ..._tips.map(
                (t) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(t.$1,
                      size:  15,
                      color: isDark ? _Pal.slate400 : _Pal.slate500),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.$2,
                      style: TextStyle(
                        fontSize: 12.5,
                        color:    subColor,
                        height:   1.45,
                      ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Animated Save Button
// ─────────────────────────────────────────────────────────────────────────────
class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.saving,
    required this.saved,
    required this.onTap,
  });

  final bool         saving;
  final bool         saved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width:  double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: saved
                ? [_Pal.green500, _Pal.green600]
                : [_Pal.blue500, _Pal.blue700],
            begin: Alignment.topLeft,
            end:   Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color:      (saved ? _Pal.green500 : _Pal.blue500)
                  .withValues(alpha: 0.38),
              blurRadius: 16,
              offset:     const Offset(0, 5),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: (saving || saved) ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor:        Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor:             Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: saving
                ? const SizedBox(
              key:    ValueKey('loading'),
              width:  22,
              height: 22,
              child:  CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
                : saved
                ? const Row(
              key:             ValueKey('saved'),
              mainAxisSize:    MainAxisSize.min,
              children: [
                Icon(Icons.check_rounded,
                    color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Saved!',
                  style: TextStyle(
                    fontSize:   15,
                    fontWeight: FontWeight.w700,
                    color:      Colors.white,
                  ),
                ),
              ],
            )
                : const Row(
              key:          ValueKey('idle'),
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.save_rounded,
                    color: Colors.white, size: 19),
                SizedBox(width: 8),
                Text(
                  'Save Profile',
                  style: TextStyle(
                    fontSize:      15,
                    fontWeight:    FontWeight.w700,
                    color:         Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}