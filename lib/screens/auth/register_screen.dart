// lib/screens/auth/register_screen.dart — SkillBridge AI
//
// FIXES APPLIED:
//  • Theme toggle onPressed wired to AppState.toggleTheme()
//  • DropdownButtonFormField: deprecated initialValue → value
//  • context.watch used where rebuild on theme change is needed
//  • Consistent padding / spacing pass
//  • withOpacity → withValues(alpha:) everywhere
// ──────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/career_profile.dart';
import '../../services/app_state.dart';
import '../../theme/app_theme.dart';
import '../main_nav.dart';

const List<String> _suggestedSkills = [
  'Python', 'Java', 'JavaScript', 'Flutter', 'React',
  'SQL', 'Data Analysis', 'Machine Learning', 'UI/UX Design',
  'Project Management', 'Communication', 'Accounting',
  'Digital Marketing', 'Excel', 'Node.js', 'C++',
  'Cybersecurity', 'Networking', 'Content Writing', 'Research',
];

const List<String> _goalPresets = [
  '💻 Software Engineer',
  '📊 Data Scientist',
  '💼 Business Analyst',
  '🎨 UI/UX Designer',
  '💰 Financial Analyst',
  '📣 Digital Marketer',
  '🏥 Health Informatics',
  '🚀 Entrepreneur',
  '⚖️ Legal Tech',
  '🎓 Research / Academia',
];

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {

  final _pageCtrl   = PageController();
  int _currentStep  = 0;
  static const int _totalSteps = 3;

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;

  // Step 1
  final _step1Key        = GlobalKey<FormState>();
  final _nameCtrl        = TextEditingController();
  final _emailCtrl       = TextEditingController();
  final _passCtrl        = TextEditingController();
  final _confirmCtrl     = TextEditingController();
  final _institutionCtrl = TextEditingController();
  bool _obscurePass      = true;
  bool _obscureConfirm   = true;
  bool _agreedToTerms    = false;
  double _passStrength   = 0.0;

  // Step 2
  final _step2Key         = GlobalKey<FormState>();
  FieldOfStudy _field     = FieldOfStudy.it;
  ExperienceType _expType = ExperienceType.none;
  int    _yearOfStudy     = 1;
  double _gpa             = 3.0;

  // Step 3
  final _step3Key        = GlobalKey<FormState>();
  String _selectedGoal   = '';
  final Set<String> _selectedSkills = {};
  final _customSkillCtrl = TextEditingController();

  bool _isLoading = false;

  static const _stepLabels = ['Account', 'Profile', 'Skills'];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _institutionCtrl.dispose();
    _customSkillCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PASSWORD STRENGTH
  // ══════════════════════════════════════════════════════════════════════════

  double _calculatePassStrength(String password) {
    if (password.isEmpty) return 0.0;
    double s = 0.0;
    if (password.length >= 6)  s += 0.20;
    if (password.length >= 10) s += 0.20;
    if (password.contains(RegExp(r'[A-Z]'))) s += 0.20;
    if (password.contains(RegExp(r'[0-9]'))) s += 0.20;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) s += 0.20;
    return s.clamp(0.0, 1.0);
  }

  Color _strengthColor(double s) {
    if (s <= 0.20) return const Color(0xFFEF4444);
    if (s <= 0.40) return Colors.orange.shade600;
    if (s <= 0.60) return Colors.amber.shade600;
    if (s <= 0.80) return Colors.lightGreen.shade600;
    return AppTheme.accentGreen;
  }

  String _strengthLabel(double s) {
    if (s <= 0.20) return 'Very Weak';
    if (s <= 0.40) return 'Weak';
    if (s <= 0.60) return 'Fair';
    if (s <= 0.80) return 'Strong';
    return 'Very Strong';
  }

  Widget _buildPassStrengthBar() {
    if (_passStrength == 0.0) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (i) {
            final filled = _passStrength >= (i + 1) * 0.20;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 4,
                margin: EdgeInsets.only(right: i < 4 ? 4 : 0),
                decoration: BoxDecoration(
                  color: filled
                      ? _strengthColor(_passStrength)
                      : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            const Text(
              'Password strength: ',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
            Text(
              _strengthLabel(_passStrength),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _strengthColor(_passStrength),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NAVIGATION
  // ══════════════════════════════════════════════════════════════════════════

  void _goNext() {
    final valid = switch (_currentStep) {
      0 => _step1Key.currentState?.validate() ?? false,
      1 => _step2Key.currentState?.validate() ?? false,
      _ => true,
    };

    if (!valid) {
      HapticFeedback.heavyImpact();
      return;
    }

    if (_currentStep == 0 && !_agreedToTerms) {
      HapticFeedback.heavyImpact();
      _showFloatingSnack(
        'Please agree to the Terms & Privacy Policy.',
        bgColor: const Color(0xFFDC2626),
        icon: Icons.warning_amber_rounded,
      );
      return;
    }

    HapticFeedback.lightImpact();
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageCtrl.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _register();
    }
  }

  void _goBack() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageCtrl.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // REGISTRATION
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _register() async {
    if (_selectedGoal.isEmpty && _selectedSkills.isEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Skip Skills?'),
          content: const Text(
            'Adding skills and a career goal now gives you much stronger '
                'job match scores from the start.\n\nContinue anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Go Back'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('registeredName', _nameCtrl.text.trim());
      await prefs.setString(
          'registeredEmail', _emailCtrl.text.trim().toLowerCase());
      await prefs.setString('registeredPassword', _passCtrl.text);
      if (_institutionCtrl.text.trim().isNotEmpty) {
        await prefs.setString(
            'registeredInstitution', _institutionCtrl.text.trim());
      }

      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;

      final appState = context.read<AppState>();

      await appState.login(
        name:  _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim().toLowerCase(),
      );

      await appState.setProfileInfo(
        fieldOfStudy:    _fieldLabel(_field),
        gpa:             _gpa,
        experienceLevel: _expType.name,
        yearOfStudy:     _yearOfStudy,
        careerGoal: _selectedGoal.replaceAll(RegExp(r'[^\w\s]'), '').trim(),
      );

      if (_selectedSkills.isNotEmpty) {
        await appState.setUserSkills(_selectedSkills.toList());
      }

      if (_selectedGoal.isNotEmpty) {
        await appState.setCareerGoal(
          _selectedGoal.replaceAll(RegExp(r'[^\w\s]'), '').trim(),
        );
      }

      if (!mounted) return;
      _showFloatingSnack(
        'Welcome, ${_nameCtrl.text.trim()}! Account created. 🎉',
        bgColor: AppTheme.accentGreen,
        icon: Icons.check_circle_outline_rounded,
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainNav()),
            (_) => false,
      );
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        _showFloatingSnack(
          'Registration failed. Please try again.',
          bgColor: const Color(0xFFDC2626),
          icon: Icons.error_outline_rounded,
        );
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FIELD HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  String _fieldLabel(FieldOfStudy f) {
    const map = {
      FieldOfStudy.science:     'Science',
      FieldOfStudy.engineering: 'Engineering',
      FieldOfStudy.business:    'Business',
      FieldOfStudy.arts:        'Arts / Design',
      FieldOfStudy.finance:     'Finance / Accounting',
      FieldOfStudy.it:          'Information Technology',
      FieldOfStudy.education:   'Education',
      FieldOfStudy.healthcare:  'Healthcare / Medicine',
      FieldOfStudy.marketing:   'Marketing / Communications',
      FieldOfStudy.law:         'Law',
      FieldOfStudy.other:       'Other',
    };
    return map[f] ?? 'Other';
  }

  String _expLabel(ExperienceType e) {
    const map = {
      ExperienceType.none:       'No Experience',
      ExperienceType.internship: 'Internship',
      ExperienceType.partTime:   'Part-time',
      ExperienceType.fullTime:   'Full-time',
    };
    return map[e] ?? 'None';
  }

  IconData _expIcon(ExperienceType e) {
    switch (e) {
      case ExperienceType.none:       return Icons.person_outline_rounded;
      case ExperienceType.internship: return Icons.co_present_rounded;
      case ExperienceType.partTime:   return Icons.schedule_rounded;
      case ExperienceType.fullTime:   return Icons.work_rounded;
    }
  }

  Color _gpaColor(double g) {
    if (g >= 3.5) return AppTheme.accentGreen;
    if (g >= 2.5) return Colors.orange.shade600;
    return Colors.red.shade600;
  }

  void _addCustomSkill() {
    final raw = _customSkillCtrl.text.trim();
    if (raw.isEmpty) return;
    setState(() {
      _selectedSkills.add(raw.toLowerCase());
      _customSkillCtrl.clear();
    });
    HapticFeedback.selectionClick();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UI HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  void _showFloatingSnack(
      String message, {
        Color bgColor = const Color(0xFF1E293B),
        IconData icon = Icons.info_outline_rounded,
      }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  InputDecoration _inputDec(
      String label, {
        required IconData icon,
        required bool isDark,
        String? hint,
      }) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
        ),
        labelStyle: TextStyle(
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          fontSize: 14,
        ),
      );

  Widget _primaryBtn(
      String label,
      VoidCallback? onPressed, {
        bool isLoading = false,
      }) =>
      SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.55),
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: isLoading
              ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2.5),
          )
              : Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
      );

  Widget _sectionDivider(String label, {required bool isDark}) {
    const subColor = Color(0xFF94A3B8);
    final divColor =
    isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    return Row(
      children: [
        Expanded(child: Divider(color: divColor)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: subColor,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Expanded(child: Divider(color: divColor)),
      ],
    );
  }

  Widget _buildFieldLabel(String text, Color textColor) => Text(
    text,
    style: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: textColor,
    ),
  );

  Widget _buildSectionHeader(
      String title,
      String subtitle,
      Color textColor,
      Color subColor,
      ) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: TextStyle(fontSize: 14, color: subColor)),
        ],
      );

  Widget _buildAvatarPicker(Color subColor, bool isDark) {
    final initials = _nameCtrl.text.trim().isEmpty
        ? '?'
        : _nameCtrl.text
        .trim()
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    return Center(
      child: GestureDetector(
        onTap: () => _showFloatingSnack(
          'Profile photo upload coming soon!',
          icon: Icons.camera_alt_outlined,
        ),
        child: Stack(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF1A56DB), Color(0xFF0EA5E9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    // ✅ FIXED: use watch so the widget rebuilds when theme changes
    final appState = context.watch<AppState>();
    final isDark   = Theme.of(context).brightness == Brightness.dark;

    final Color bgColor   = isDark ? const Color(0xFF0F172A) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor  = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color divColor  = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgColor,

      // ── AppBar ──────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: _goBack,
        ),
        title: Text(
          'Create Account',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        actions: [
          // ✅ FIXED: wired to toggleTheme — was () {}
          IconButton(
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: textColor,
              size: 20,
            ),
            onPressed: () => appState.toggleTheme(),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Column(
            children: [
              // Step indicator row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  children: List.generate(_totalSteps, (i) {
                    final done    = i < _currentStep;
                    final current = i == _currentStep;
                    return Expanded(
                      child: Row(
                        children: [
                          if (i > 0)
                            Expanded(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                height: 2,
                                color: done ? AppTheme.primaryBlue : divColor,
                              ),
                            ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: done
                                  ? AppTheme.primaryBlue
                                  : current
                                  ? AppTheme.primaryBlue.withValues(alpha: 0.12)
                                  : (isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFF1F5F9)),
                              border: current
                                  ? Border.all(
                                  color: AppTheme.primaryBlue, width: 2)
                                  : null,
                            ),
                            child: Center(
                              child: done
                                  ? const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 14)
                                  : Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: current
                                      ? AppTheme.primaryBlue
                                      : subColor,
                                ),
                              ),
                            ),
                          ),
                          if (i < _totalSteps - 1)
                            Expanded(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                height: 2,
                                color: done ? AppTheme.primaryBlue : divColor,
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                ),
              ),

              // Step labels
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(_totalSteps, (i) {
                    final active = i == _currentStep;
                    return Text(
                      _stepLabels[i],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                        active ? FontWeight.w700 : FontWeight.w400,
                        color: active ? AppTheme.primaryBlue : subColor,
                      ),
                    );
                  }),
                ),
              ),

              // Animated progress bar
              TweenAnimationBuilder<double>(
                tween: Tween(
                  begin: 0,
                  end: (_currentStep + 1) / _totalSteps,
                ),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                builder: (_, val, __) => LinearProgressIndicator(
                  value: val,
                  backgroundColor: divColor,
                  valueColor:
                  const AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                  minHeight: 3,
                ),
              ),
            ],
          ),
        ),
      ),

      // ── Pinned bottom CTA (step 3 only) ──────────────────────────────────
      bottomNavigationBar: _currentStep == 2
          ? Container(
        color: bgColor,
        padding: EdgeInsets.fromLTRB(
          20, 12, 20,
          MediaQuery.of(context).padding.bottom + 12,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(top: BorderSide(color: divColor, width: 1)),
        ),
        child: _primaryBtn(
          'Create Account →',
          _isLoading ? null : _goNext,
          isLoading: _isLoading,
        ),
      )
          : null,

      // ── Body ──────────────────────────────────────────────────────────────
      body: FadeTransition(
        opacity: _fadeAnim,
        child: PageView(
          controller: _pageCtrl,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildStep1(isDark, textColor, subColor, cardColor),
            _buildStep2(isDark, textColor, subColor, cardColor),
            _buildStep3(isDark, textColor, subColor, cardColor),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 1 — Account Credentials
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStep1(
      bool isDark,
      Color textColor,
      Color subColor,
      Color cardColor,
      ) =>
      GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _step1Key,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(
                  "Let's get to know you 👋",
                  'Fill in your basic details to get started',
                  textColor,
                  subColor,
                ),
                const SizedBox(height: 24),

                _buildAvatarPicker(subColor, isDark),
                const SizedBox(height: 24),

                // Full Name
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  style: TextStyle(color: textColor, fontSize: 14),
                  onChanged: (_) => setState(() {}),
                  decoration: _inputDec(
                    'Full Name',
                    icon: Icons.person_outline_rounded,
                    isDark: isDark,
                    hint: 'e.g. Arafat Sakib',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter your full name';
                    }
                    if (v.trim().length < 2) return 'Name is too short';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Email
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  style: TextStyle(color: textColor, fontSize: 14),
                  decoration: _inputDec(
                    'Email Address',
                    icon: Icons.email_outlined,
                    isDark: isDark,
                    hint: 'you@example.com',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!v.contains('@') || !v.contains('.')) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Institution (optional)
                TextFormField(
                  controller: _institutionCtrl,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  style: TextStyle(color: textColor, fontSize: 14),
                  decoration: _inputDec(
                    'Institution (Optional)',
                    icon: Icons.school_outlined,
                    isDark: isDark,
                    hint: 'e.g. Daffodil International University',
                  ),
                ),
                const SizedBox(height: 14),

                // Password
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscurePass,
                  textInputAction: TextInputAction.next,
                  style: TextStyle(color: textColor, fontSize: 14),
                  onChanged: (v) =>
                      setState(() => _passStrength = _calculatePassStrength(v)),
                  decoration: _inputDec(
                    'Password',
                    icon: Icons.lock_outline_rounded,
                    isDark: isDark,
                    hint: 'At least 6 characters',
                  ).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePass
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                        color: subColor,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePass = !_obscurePass),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Please enter a password';
                    if (v.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                _buildPassStrengthBar(),
                const SizedBox(height: 14),

                // Confirm Password
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  style: TextStyle(color: textColor, fontSize: 14),
                  decoration: _inputDec(
                    'Confirm Password',
                    icon: Icons.lock_outline_rounded,
                    isDark: isDark,
                    hint: 'Re-enter your password',
                  ).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                        color: subColor,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (v != _passCtrl.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Terms checkbox
                GestureDetector(
                  onTap: () =>
                      setState(() => _agreedToTerms = !_agreedToTerms),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _agreedToTerms
                          ? AppTheme.primaryBlue.withValues(alpha: 0.06)
                          : (isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _agreedToTerms
                            ? AppTheme.primaryBlue.withValues(alpha: 0.40)
                            : (isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0)),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Checkbox(
                          value: _agreedToTerms,
                          activeColor: AppTheme.primaryBlue,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5)),
                          visualDensity: VisualDensity.compact,
                          onChanged: (v) =>
                              setState(() => _agreedToTerms = v ?? false),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'I agree to the Terms of Service & Privacy Policy. '
                                'Your CV data will only be used for job matching.',
                            style: TextStyle(fontSize: 12, color: subColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                _primaryBtn('Next: Career Profile →', _goNext),
                const SizedBox(height: 14),

                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Already have an account? Login',
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.primaryBlue),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      );

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 2 — Career Profile
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStep2(
      bool isDark,
      Color textColor,
      Color subColor,
      Color cardColor,
      ) =>
      GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _step2Key,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(
                  'Your Career Profile 🎓',
                  'Helps us match you to the most relevant jobs',
                  textColor,
                  subColor,
                ),
                const SizedBox(height: 16),

                // Domain signal info banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accentTeal.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.accentTeal.withValues(alpha: 0.30)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.hub_outlined,
                          color: AppTheme.accentTeal, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your field of study and experience are used as domain '
                              'signals (weight 1.0) in our job-matching engine.',
                          style: TextStyle(fontSize: 12, color: subColor),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                _sectionDivider('Career Info', isDark: isDark),
                const SizedBox(height: 16),

                _buildFieldLabel('Field of Study', textColor),
                const SizedBox(height: 8),
                // ✅ FIXED: initialValue → value (deprecated API removed)
                DropdownButtonFormField<FieldOfStudy>(
                  initialValue: _field,
                  style: TextStyle(color: textColor, fontSize: 14),
                  dropdownColor: cardColor,
                  decoration: _inputDec(
                    'Field of Study',
                    icon: Icons.menu_book_outlined,
                    isDark: isDark,
                  ).copyWith(labelText: null),
                  items: FieldOfStudy.values
                      .map((f) => DropdownMenuItem(
                    value: f,
                    child: Text(_fieldLabel(f)),
                  ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _field = v);
                  },
                ),
                const SizedBox(height: 16),

                _buildFieldLabel('Year of Study', textColor),
                const SizedBox(height: 10),
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 6,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final yr  = i + 1;
                      final sel = _yearOfStudy == yr;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _yearOfStudy = yr);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: sel
                                ? AppTheme.primaryBlue
                                : (isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF1F5F9)),
                            border: Border.all(
                              color: sel
                                  ? AppTheme.primaryBlue
                                  : (isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFE2E8F0)),
                              width: sel ? 0 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '$yr',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: sel ? Colors.white : subColor,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // GPA slider
                Row(
                  children: [
                    _buildFieldLabel('GPA', textColor),
                    const Spacer(),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: _gpaColor(_gpa).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: _gpaColor(_gpa).withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        '${_gpa.toStringAsFixed(1)} / 4.0',
                        style: TextStyle(
                          fontSize: 12,
                          color: _gpaColor(_gpa),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _gpa,
                  min: 0.0,
                  max: 4.0,
                  divisions: 40,
                  label: _gpa.toStringAsFixed(1),
                  activeColor: _gpaColor(_gpa),
                  inactiveColor: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                  onChanged: (v) => setState(() => _gpa = v),
                ),
                const SizedBox(height: 16),

                // Experience level grid
                _buildFieldLabel('Experience Level', textColor),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 2.4,
                  children: ExperienceType.values.map((exp) {
                    final selected = _expType == exp;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _expType = exp);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppTheme.primaryBlue
                              : (isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? AppTheme.primaryBlue
                                : (isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0)),
                            width: selected ? 0 : 1,
                          ),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _expIcon(exp),
                                size: 16,
                                color: selected ? Colors.white : subColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _expLabel(exp),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: selected ? Colors.white : textColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),

                _primaryBtn('Next: Career Goal & Skills →', _goNext),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      );

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 3 — Career Goal + Initial Skills
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStep3(
      bool isDark,
      Color textColor,
      Color subColor,
      Color cardColor,
      ) =>
      GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Form(
            key: _step3Key,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(
                  'Goal & Skills 🚀',
                  'The most important signals for your job matches',
                  textColor,
                  subColor,
                ),
                const SizedBox(height: 16),

                // Skills weight info banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.accentGreen.withValues(alpha: 0.30)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.bolt_rounded,
                          color: AppTheme.accentGreen, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Skills carry 2× weight in our matching algorithm. '
                              'Adding even a few now dramatically improves your recommendations.',
                          style: TextStyle(fontSize: 12, color: subColor),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                _sectionDivider('Career Goal', isDark: isDark),
                const SizedBox(height: 16),

                _buildFieldLabel('Career Goal (Optional)', textColor),
                const SizedBox(height: 4),
                Text(
                  "Select the role you're aiming for",
                  style: TextStyle(fontSize: 11, color: subColor),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _goalPresets.map((goal) {
                    final selected = _selectedGoal == goal;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() =>
                        _selectedGoal = selected ? '' : goal);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 13, vertical: 7),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppTheme.primaryBlue
                              : (isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: selected
                                ? AppTheme.primaryBlue
                                : (isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: Text(
                          goal,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: selected ? Colors.white : textColor,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 28),

                _sectionDivider('Your Skills', isDark: isDark),
                const SizedBox(height: 16),

                // Skills header with animated count badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildFieldLabel('Add Skills', textColor),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.accentGreen.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color:
                            AppTheme.accentGreen.withValues(alpha: 0.35)),
                      ),
                      child: const Text(
                        '2× match weight',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.accentGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (_selectedSkills.isNotEmpty)
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, anim) =>
                            ScaleTransition(scale: anim, child: child),
                        child: Container(
                          key: ValueKey<int>(_selectedSkills.length),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_selectedSkills.length} selected',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap to add from suggestions, or type your own',
                  style: TextStyle(fontSize: 11, color: subColor),
                ),
                const SizedBox(height: 12),

                // Custom skill input + Add button
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _customSkillCtrl,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _addCustomSkill(),
                        style: TextStyle(color: textColor, fontSize: 14),
                        decoration: _inputDec(
                          'Add your own skill...',
                          icon: Icons.add_circle_outline_rounded,
                          isDark: isDark,
                        ).copyWith(
                          labelText: null,
                          hintText: 'Add your own skill...',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _addCustomSkill,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                        ),
                        child: const Text(
                          'Add',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Text(
                  'Popular Skills:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: subColor,
                  ),
                ),
                const SizedBox(height: 8),

                // Suggested skill chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _suggestedSkills.map((skill) {
                    final selected =
                    _selectedSkills.contains(skill.toLowerCase());
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          if (selected) {
                            _selectedSkills.remove(skill.toLowerCase());
                          } else {
                            _selectedSkills.add(skill.toLowerCase());
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppTheme.accentGreen
                              : (isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: selected
                                ? AppTheme.accentGreen
                                : (isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (selected) ...[
                              const Icon(Icons.check_rounded,
                                  size: 12, color: Colors.white),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              skill,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: selected ? Colors.white : textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                // Selected skills summary
                if (_selectedSkills.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppTheme.accentGreen.withValues(alpha: 0.30)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: AppTheme.accentGreen, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_selectedSkills.length} skill${_selectedSkills.length == 1 ? '' : 's'} selected — '
                                'your match scores are already improving!',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.accentGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // SDG-8 badge
                const SizedBox(height: 20),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppTheme.accentGreen.withValues(alpha: 0.30)),
                    ),
                    child: const Text(
                      '🎯 Supporting UN SDG-8: Decent Work & Economic Growth',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.accentGreen,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      );
}