// lib/screens/auth/login_screen.dart — SkillBridge AI
//
// FIXES APPLIED:
//  • Theme toggle onPressed wired to AppState.toggleTheme()
//  • DropdownButtonFormField: no changes needed here
//  • Consistent padding / spacing pass
//  • withOpacity → withValues(alpha:) everywhere
// ──────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/app_state.dart';
import '../../theme/app_theme.dart';
import '../main_nav.dart';
import 'register_screen.dart';

const String _defaultEmail    = 'arafat@skillbridge.com';
const String _defaultPassword = 'skill123';
const String _defaultName     = 'Arafat Sakib';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {

  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController(text: _defaultEmail);
  final _passCtrl  = TextEditingController(text: _defaultPassword);
  bool _obscurePass  = true;
  bool _isLoading    = false;
  bool _rememberMe   = false;
  bool _showDemoCreds = false;

  late AnimationController _animCtrl;
  late AnimationController _shakeCtrl;
  late AnimationController _pulseCtrl;

  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _shakeAnim;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _shakeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _animCtrl.forward();
    _loadRememberMe();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _animCtrl.dispose();
    _shakeCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Remember-me ───────────────────────────────────────────────────────────
  Future<void> _loadRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    final remembered = prefs.getBool('rememberMe') ?? false;
    if (!remembered) return;
    final savedEmail = prefs.getString('rememberedEmail') ?? '';
    if (savedEmail.isNotEmpty && mounted) {
      setState(() {
        _emailCtrl.text = savedEmail;
        _rememberMe     = true;
      });
    }
  }

  Future<void> _saveRememberMe(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rememberMe', true);
    await prefs.setString('rememberedEmail', email);
  }

  Future<void> _clearRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rememberMe', false);
    await prefs.remove('rememberedEmail');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  void _triggerShake() {
    HapticFeedback.heavyImpact();
    _shakeCtrl.forward(from: 0.0);
  }

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

  // ── Auth logic ────────────────────────────────────────────────────────────
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      _triggerShake();
      return;
    }
    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    final enteredEmail = _emailCtrl.text.trim().toLowerCase();
    final enteredPass  = _passCtrl.text;

    bool   isValid    = (enteredEmail == _defaultEmail && enteredPass == _defaultPassword);
    String loginName  = _defaultName;
    String loginEmail = _defaultEmail;

    if (!isValid) {
      final prefs       = await SharedPreferences.getInstance();
      final storedEmail = prefs.getString('registeredEmail')    ?? '';
      final storedPass  = prefs.getString('registeredPassword') ?? '';
      final storedName  = prefs.getString('registeredName')     ?? '';
      if (enteredEmail == storedEmail.toLowerCase() && enteredPass == storedPass) {
        isValid    = true;
        loginName  = storedName;
        loginEmail = storedEmail;
      }
    }

    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    if (isValid) {
      if (_rememberMe) {
        await _saveRememberMe(enteredEmail);
      } else {
        await _clearRememberMe();
      }
      HapticFeedback.mediumImpact();
      await context.read<AppState>().login(name: loginName, email: loginEmail);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNav()),
        );
      }
    } else {
      setState(() => _isLoading = false);
      _triggerShake();
      _showFloatingSnack(
        'Incorrect email or password. Please try again.',
        bgColor: const Color(0xFFDC2626),
        icon: Icons.error_outline_rounded,
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UI HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  InputDecoration _inputDec(
      String label, {
        required IconData icon,
        bool isDark = false,
      }) =>
      InputDecoration(
        labelText: label,
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

  Widget _primaryBtn(String label, VoidCallback? onPressed) => SizedBox(
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
      child: _isLoading
          ? const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
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

  Widget _outlineBtn(String label, VoidCallback? onTap) => SizedBox(
    width: double.infinity,
    height: 52,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.primaryBlue,
        side: const BorderSide(color: AppTheme.primaryBlue, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
  );

  Widget _buildDemoCredCard(Color subColor, bool isDark) => GestureDetector(
    onTap: () => setState(() => _showDemoCreds = !_showDemoCreds),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: AppTheme.primaryBlue, size: 16),
              const SizedBox(width: 8),
              const Text(
                'Demo Credentials',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const Spacer(),
              Icon(
                _showDemoCreds
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                color: AppTheme.primaryBlue,
                size: 18,
              ),
            ],
          ),
          if (_showDemoCreds) ...[
            const SizedBox(height: 10),
            _credRow('Email', _defaultEmail, subColor),
            const SizedBox(height: 4),
            _credRow('Password', _defaultPassword, subColor),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _emailCtrl.text = _defaultEmail;
                    _passCtrl.text  = _defaultPassword;
                    _showDemoCreds  = false;
                  });
                  HapticFeedback.selectionClick();
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text(
                  'Auto-fill Demo Credentials',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _credRow(String label, String value, Color subColor) => Row(
    children: [
      Text('$label: ', style: TextStyle(fontSize: 11, color: subColor)),
      Expanded(
        child: Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryBlue,
            fontFamily: 'monospace',
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );

  Widget _buildSocialRow(Color subColor, bool isDark) => Row(
    children: [
      Expanded(
        child: _socialBtn(
          icon: Icons.g_mobiledata_rounded,
          label: 'Google',
          isDark: isDark,
          subColor: subColor,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _socialBtn(
          icon: Icons.work_outline_rounded,
          label: 'LinkedIn',
          isDark: isDark,
          subColor: subColor,
        ),
      ),
    ],
  );

  Widget _socialBtn({
    required IconData icon,
    required String label,
    required bool isDark,
    required Color subColor,
  }) =>
      OutlinedButton.icon(
        onPressed: () => _showFloatingSnack(
          '$label login coming soon!',
          icon: Icons.info_outline_rounded,
        ),
        icon: Icon(icon, size: 20),
        label: Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        style: OutlinedButton.styleFrom(
          foregroundColor: subColor,
          padding: const EdgeInsets.symmetric(vertical: 13),
          side: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

  Widget _buildBiometricBtn(Color subColor) => Center(
    child: TextButton.icon(
      onPressed: () => _showFloatingSnack(
        'Biometric authentication coming soon!',
        icon: Icons.fingerprint_rounded,
      ),
      icon: Icon(Icons.fingerprint_rounded, size: 20, color: subColor),
      label: Text(
        'Sign in with Biometrics',
        style: TextStyle(
            fontSize: 13, color: subColor, fontWeight: FontWeight.w500),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    ),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark   = Theme.of(context).brightness == Brightness.dark;

    final Color bgColor   = isDark ? const Color(0xFF0F172A) : Colors.white;
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor  = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color divColor  = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final double topH     = MediaQuery.of(context).size.height * 0.40;

    return Scaffold(
      backgroundColor: bgColor,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Form(
          key: _formKey,
          child: Stack(
            children: [

              // ── HERO GRADIENT ──────────────────────────────────────────
              Positioned(
                top: 0, left: 0, right: 0,
                height: topH,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Stack(
                    children: [
                      // Gradient background
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF1A56DB), Color(0xFF0EA5E9)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),

                      // Decorative bubbles
                      Positioned(
                        top: -40, right: -40,
                        child: Container(
                          width: 180, height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.07),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 8, left: -30,
                        child: Container(
                          width: 120, height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 24,
                        left: MediaQuery.of(context).size.width * 0.42,
                        child: Container(
                          width: 60, height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.04),
                          ),
                        ),
                      ),

                      // Logo + tagline
                      SafeArea(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ScaleTransition(
                                scale: _pulseAnim,
                                child: Container(
                                  width: 68, height: 68,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF1A56DB).withValues(alpha: 0.50),
                                        blurRadius: 28,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.work_rounded,
                                    color: Colors.white,
                                    size: 34,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'SkillBridge AI',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Your career starts here',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── THEME TOGGLE (FIXED) ──────────────────────────
                      Positioned(
                        top: 48, right: 16,
                        child: SafeArea(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                                width: 1,
                              ),
                            ),
                            child: IconButton(
                              tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                              icon: Icon(
                                isDark
                                    ? Icons.light_mode_rounded
                                    : Icons.dark_mode_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              // ✅ FIXED: was () {} — now calls toggleTheme
                              onPressed: () => appState.toggleTheme(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── BOTTOM CARD ────────────────────────────────────────────
              Positioned(
                top: topH - 28,
                left: 0, right: 0, bottom: 0,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(32)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 30,
                          offset: const Offset(0, -8),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          // Headline
                          Text(
                            'Welcome back 👋',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Sign in to continue your journey',
                            style: TextStyle(
                              fontSize: 14,
                              color: subColor,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Shake wrapper
                          AnimatedBuilder(
                            animation: _shakeAnim,
                            builder: (context, child) {
                              final offset =
                                  math.sin(_shakeAnim.value * math.pi * 6) * 9.0;
                              return Transform.translate(
                                offset: Offset(offset, 0),
                                child: child,
                              );
                            },
                            child: Column(
                              children: [
                                // Email
                                TextFormField(
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  style: TextStyle(color: textColor, fontSize: 14),
                                  decoration: _inputDec(
                                    'Email',
                                    icon: Icons.email_outlined,
                                    isDark: isDark,
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Please enter your email';
                                    }
                                    if (!v.contains('@')) return 'Enter a valid email';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),

                                // Password
                                TextFormField(
                                  controller: _passCtrl,
                                  obscureText: _obscurePass,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _login(),
                                  style: TextStyle(color: textColor, fontSize: 14),
                                  decoration: _inputDec(
                                    'Password',
                                    icon: Icons.lock_outline_rounded,
                                    isDark: isDark,
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
                                    if (v == null || v.isEmpty) {
                                      return 'Please enter your password';
                                    }
                                    if (v.length < 6) {
                                      return 'Password must be at least 6 characters';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Remember me + Forgot password
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _rememberMe = !_rememberMe),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: Checkbox(
                                        value: _rememberMe,
                                        activeColor: AppTheme.primaryBlue,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(5)),
                                        materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: VisualDensity.compact,
                                        onChanged: (v) =>
                                            setState(() => _rememberMe = v ?? false),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Remember me',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: subColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () => _showFloatingSnack(
                                  'Password reset coming soon!',
                                  icon: Icons.lock_reset_rounded,
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 2),
                                ),
                                child: const Text(
                                  'Forgot password?',
                                  style: TextStyle(
                                    color: AppTheme.primaryBlue,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          _primaryBtn('Sign In →', _isLoading ? null : _login),
                          const SizedBox(height: 12),

                          _buildBiometricBtn(subColor),
                          const SizedBox(height: 4),

                          // OR divider
                          Row(
                            children: [
                              Expanded(child: Divider(color: divColor)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'OR',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: subColor,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: divColor)),
                            ],
                          ),
                          const SizedBox(height: 14),

                          _buildSocialRow(subColor, isDark),
                          const SizedBox(height: 14),

                          _outlineBtn(
                            'Create New Account',
                                () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const RegisterScreen()),
                            ),
                          ),
                          const SizedBox(height: 24),

                          _buildDemoCredCard(subColor, isDark),
                          const SizedBox(height: 16),

                          Center(
                            child: Text(
                              'By signing in, you agree to our Terms & Privacy Policy',
                              style: TextStyle(
                                fontSize: 11,
                                color: subColor,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // SDG-8 badge
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.accentGreen.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppTheme.accentGreen.withValues(alpha: 0.30),
                                ),
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
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}