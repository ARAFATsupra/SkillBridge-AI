// lib/main.dart — SkillBridge AI

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'services/app_state.dart';
import 'theme/app_theme.dart';
import 'models/career_profile.dart';
import 'ml/recommender.dart';

// ── Screen imports ────────────────────────────────────────────────────────────
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/main_nav.dart';
import 'screens/home.dart';
import 'screens/profile_input.dart';
import 'screens/cv_upload_screen.dart';
import 'screens/skill_input.dart';
import 'screens/job_result.dart';
import 'screens/skill_gap.dart';
import 'screens/learning.dart';
import 'screens/browse_courses_screen.dart';
import 'screens/career_guide.dart';
import 'screens/dashboard_screen.dart';
import 'screens/job_transition_screen.dart';
import 'screens/confidence_tracker_screen.dart';
import 'screens/skill_trends_screen.dart' as trends;
import 'screens/assessment_hub_screen.dart' as assessment;
import 'screens/geo_insights_screen.dart';
import 'screens/workforce_insights_screen.dart';
import 'screens/application_tracker_screen.dart';
import 'screens/chatbot_screen.dart';
import 'screens/privacy_settings_screen.dart';
import 'screens/job_alerts_screen.dart';

// =============================================================================
// ENTRY POINT
// =============================================================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppTheme.bgDark,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  final appState = AppState();
  await appState.loadFromPrefs();

  runApp(
    ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: const SkillBridgeApp(),
    ),
  );
}

// =============================================================================
// ROUTE OBSERVER
// =============================================================================

class _AppRouteObserver extends RouteObserver<ModalRoute<dynamic>> {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    final name = route.settings.name;
    if (name != null) debugPrint('[Nav] push → $name');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    final name = previousRoute?.settings.name;
    if (name != null) debugPrint('[Nav] pop  → $name');
  }
}

final _routeObserver = _AppRouteObserver();

// =============================================================================
// ROOT WIDGET
// =============================================================================

class SkillBridgeApp extends StatelessWidget {
  const SkillBridgeApp({super.key});

  static Map<String, WidgetBuilder> get _routes => {
    '/':              (_) => const SplashOrAuthCheck(),
    '/login':         (_) => const LoginScreen(),
    '/register':      (_) => const RegisterScreen(),
    '/main':          (_) => const MainNav(),
    '/home':          (_) => const HomeScreen(),
    '/profile_input': (_) => const ProfileInputScreen(),
    '/cv_upload':     (_) => const CvUploadScreen(),
    '/browse_courses':(_) => const BrowseCoursesScreen(),
    '/dashboard':     (_) => const DashboardScreen(),
    '/job_transition':(_) => const JobTransitionScreen(),
    '/confidence':    (_) => const ConfidenceTrackerScreen(),
    '/skill_trends':  (_) => const trends.SkillTrendsScreen(),
    '/assessment_hub':(_) => const assessment.AssessmentHubScreen(),
    '/geo_insights':  (_) => const GeoInsightsScreen(),
    '/workforce':     (_) => const WorkforceInsightsScreen(),
    '/applications':  (_) => const ApplicationTrackerScreen(),
    '/chatbot':       (_) => const ChatbotScreen(),
    '/privacy':       (_) => const PrivacySettingsScreen(),
    '/job_alerts':    (_) => const JobAlertsScreen(),
  };

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<AppState, ThemeMode>(
          (state) => state.themeMode,
    );

    return MaterialApp(
      title: 'SkillBridge AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      themeAnimationDuration: const Duration(milliseconds: 350),
      themeAnimationCurve: Curves.easeInOut,
      scaffoldMessengerKey: AppTheme.messengerKey,
      navigatorObservers: [_routeObserver],
      initialRoute: '/',
      routes: _routes,
      onGenerateRoute: _generateRoute,
      onUnknownRoute: (settings) => _buildErrorRoute(
        settings,
        'No route defined for "${settings.name}".',
      ),
      scrollBehavior: const _NoGlowScrollBehavior(),
    );
  }

  static Route<void>? _generateRoute(RouteSettings settings) {
    final args = (settings.arguments as Map<String, dynamic>?) ?? const {};

    switch (settings.name) {
      case '/skill_input':
        final profile = args['profile'];
        if (profile is! CareerProfile) {
          return _buildErrorRoute(
            settings,
            '/skill_input requires a CareerProfile argument.',
          );
        }
        return _buildPageRoute(
          settings: settings,
          screen: SkillInputScreen(profile: profile),
        );

      case '/learning':
        return _buildPageRoute(
          settings: settings,
          screen: LearningScreen(
            missingSkills: (args['missingSkills'] as List<String>?) ?? const [],
            industry: (args['industry'] as String?) ?? 'General',
          ),
        );

      case '/career_guide':
        final profile = args['profile'];
        if (profile is! CareerProfile) {
          return _buildErrorRoute(
            settings,
            '/career_guide requires a CareerProfile argument.',
          );
        }
        return _buildPageRoute(
          settings: settings,
          screen: CareerGuideScreen(profile: profile),
        );

      case '/job_result':
        final profile = args['profile'];
        if (profile is! CareerProfile) {
          return _buildErrorRoute(
            settings,
            '/job_result requires a CareerProfile argument.',
          );
        }
        return _buildPageRoute(
          settings: settings,
          screen: JobResultScreen(
            profile: profile,
            selectedIndustry: (args['selectedIndustry'] as String?) ?? 'All',
            selectedLevel:    (args['selectedLevel'] as String?) ?? 'All',
            remoteOnly:       (args['remoteOnly'] as bool?) ?? false,
          ),
        );

      case '/skill_gap':
        final job = args['job'];
        if (job is! JobRecommendation) {
          return _buildErrorRoute(
            settings,
            '/skill_gap requires a JobRecommendation argument.',
          );
        }
        return _buildPageRoute(
          settings: settings,
          screen: SkillGapScreen(
            job: job,
            userSkills: (args['userSkills'] as List<String>?) ?? const [],
          ),
        );

      default:
        return null;
    }
  }

  static MaterialPageRoute<void> _buildPageRoute({
    required RouteSettings settings,
    required Widget screen,
  }) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => screen,
    );
  }

  static MaterialPageRoute<void> _buildErrorRoute(
      RouteSettings settings,
      String message,
      ) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => _ErrorScreen(message: message),
    );
  }
}

// ── Removes Android over-scroll glow ─────────────────────────────────────────
class _NoGlowScrollBehavior extends ScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
      BuildContext context,
      Widget child,
      ScrollableDetails details,
      ) => child;
}

// ── Full-screen navigation error widget ──────────────────────────────────────
class _ErrorScreen extends StatelessWidget {
  final String message;

  const _ErrorScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Navigation Error'),
        leading: BackButton(
          onPressed: () {
            if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          },
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.31),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.error_outline,
                  size: 40,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Oops! Something went wrong.',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    Navigator.of(context).pushReplacementNamed('/main');
                  }
                },
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SPLASH / AUTH CHECK
// =============================================================================

class SplashOrAuthCheck extends StatefulWidget {
  const SplashOrAuthCheck({super.key});

  @override
  State<SplashOrAuthCheck> createState() => _SplashOrAuthCheckState();
}

class _SplashOrAuthCheckState extends State<SplashOrAuthCheck>
    with TickerProviderStateMixin {
  late final AnimationController _entranceCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<double>   _scaleAnim;
  late final Animation<Offset>   _taglineSlide;

  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;

  late final AnimationController _dotCtrl;

  static const Duration _holdDuration = Duration(milliseconds: 1250);

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    _fadeAnim = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
    );

    _scaleAnim = Tween<double>(begin: 0.78, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack),
      ),
    );

    _taglineSlide = Tween<Offset>(
      begin: const Offset(0, 0.6),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.35, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.85, end: 1.12).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _entranceCtrl.forward().then((_) => _navigateAfterDelay());
  }

  Future<void> _navigateAfterDelay() async {
    await Future.delayed(_holdDuration);
    if (!mounted) return;

    final isLoggedIn = context.read<AppState>().isLoggedIn;
    Navigator.of(context).pushReplacementNamed(
      isLoggedIn ? '/main' : '/login',
    );
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _pulseCtrl.dispose();
    _dotCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppTheme.primaryBlue,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Pulsing logo ───────────────────────────────────
                      AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (_, child) => Transform.scale(
                          scale: _pulseAnim.value,
                          child: child,
                        ),
                        child: Container(
                          width: 104,
                          height: 104,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.11),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.27),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.16),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.hub_rounded,
                              size: 56,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      const Text(
                        'SkillBridge AI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          fontFamily: 'PlusJakartaSans',
                        ),
                      ),

                      const SizedBox(height: 10),

                      SlideTransition(
                        position: _taglineSlide,
                        child: Text(
                          'Your AI-powered career companion',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.76),
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ── SDG-8 badge ────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.09),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.20),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.eco_outlined,
                              size: 13,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'UN SDG-8 Aligned',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.78),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 64),

                      _DotLoader(controller: _dotCtrl),

                      const SizedBox(height: 18),

                      Text(
                        'Preparing your experience…',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Three-dot animated loading indicator ─────────────────────────────────────
class _DotLoader extends StatelessWidget {
  final AnimationController controller;

  const _DotLoader({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final start = i * 0.25;
        final end   = (start + 0.5).clamp(0.0, 1.0);
        final anim  = Tween<double>(begin: 0.3, end: 1.0).animate(
          CurvedAnimation(
            parent: controller,
            curve: Interval(start, end, curve: Curves.easeInOut),
          ),
        );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: AnimatedBuilder(
            animation: anim,
            builder: (_, __) => Opacity(
              opacity: anim.value,
              child: Transform.translate(
                offset: Offset(0, -4 * anim.value + 2),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// =============================================================================
// INDUSTRY COLOUR MAP
// =============================================================================

const Map<String, Color> industryColors = {
  'Software':      Color(0xFF1565C0),
  'Finance':       Color(0xFF2E7D32),
  'Healthcare':    Color(0xFFC62828),
  'Marketing':     Color(0xFFE65100),
  'Manufacturing': Color(0xFF4527A0),
  'Retail':        Color(0xFF00695C),
  'Education':     Color(0xFF283593),
  'General':       Color(0xFF37474F),
};

Color industryColor(String industry) =>
    industryColors[industry] ?? const Color(0xFF37474F);

// =============================================================================
// LEARNER PREFERENCE ENUMS  [TAV22 §3.5.1, Table 4]
// =============================================================================

enum ContentLength { short, medium, long }

extension ContentLengthExt on ContentLength {
  String get label {
    switch (this) {
      case ContentLength.short:  return 'Short (< 10 min)';
      case ContentLength.medium: return 'Medium (10–20 min)';
      case ContentLength.long:   return 'Long (> 20 min)';
    }
  }

  String get key {
    switch (this) {
      case ContentLength.short:  return PreferenceKeys.lengthShort;
      case ContentLength.medium: return PreferenceKeys.lengthMedium;
      case ContentLength.long:   return PreferenceKeys.lengthLong;
    }
  }

  IconData get icon {
    switch (this) {
      case ContentLength.short:  return Icons.timer_outlined;
      case ContentLength.medium: return Icons.schedule_outlined;
      case ContentLength.long:   return Icons.hourglass_bottom_outlined;
    }
  }
}

enum DetailLevel { low, medium, high }

extension DetailLevelExt on DetailLevel {
  String get label {
    switch (this) {
      case DetailLevel.low:    return 'Overview';
      case DetailLevel.medium: return 'Standard';
      case DetailLevel.high:   return 'In-Depth';
    }
  }

  String get key {
    switch (this) {
      case DetailLevel.low:    return PreferenceKeys.detailLow;
      case DetailLevel.medium: return PreferenceKeys.detailMedium;
      case DetailLevel.high:   return PreferenceKeys.detailHigh;
    }
  }

  Color get color {
    switch (this) {
      case DetailLevel.low:    return const Color(0xFF78909C);
      case DetailLevel.medium: return const Color(0xFF1565C0);
      case DetailLevel.high:   return const Color(0xFF4527A0);
    }
  }
}

enum LearningStrategy { theoryOnly, exampleOnly, both }

extension LearningStrategyExt on LearningStrategy {
  String get label {
    switch (this) {
      case LearningStrategy.theoryOnly:  return 'Theory';
      case LearningStrategy.exampleOnly: return 'Examples';
      case LearningStrategy.both:        return 'Mixed';
    }
  }

  String get key {
    switch (this) {
      case LearningStrategy.theoryOnly:  return PreferenceKeys.strategyTheory;
      case LearningStrategy.exampleOnly: return PreferenceKeys.strategyExample;
      case LearningStrategy.both:        return PreferenceKeys.strategyBoth;
    }
  }
}

enum ContentFormat { video, book, webpage, slide, classroomBased }

extension ContentFormatExt on ContentFormat {
  String get label {
    switch (this) {
      case ContentFormat.video:          return 'Video';
      case ContentFormat.book:           return 'Book / PDF';
      case ContentFormat.webpage:        return 'Web Article';
      case ContentFormat.slide:          return 'Slides';
      case ContentFormat.classroomBased: return 'Lecture';
    }
  }

  String get key {
    switch (this) {
      case ContentFormat.video:          return PreferenceKeys.contentVideo;
      case ContentFormat.book:           return PreferenceKeys.contentBook;
      case ContentFormat.webpage:        return PreferenceKeys.contentWebpage;
      case ContentFormat.slide:          return PreferenceKeys.contentSlide;
      case ContentFormat.classroomBased: return PreferenceKeys.classBased;
    }
  }

  IconData get icon {
    switch (this) {
      case ContentFormat.video:          return Icons.play_circle_outline;
      case ContentFormat.book:           return Icons.menu_book_outlined;
      case ContentFormat.webpage:        return Icons.language_outlined;
      case ContentFormat.slide:          return Icons.slideshow_outlined;
      case ContentFormat.classroomBased: return Icons.school_outlined;
    }
  }
}

// =============================================================================
// TOPIC PROGRESS STATUS  [TAV22 §3.6.2]
// =============================================================================

enum TopicStatus { passed, inProgress, forthcoming }

extension TopicStatusExt on TopicStatus {
  Color get color {
    switch (this) {
      case TopicStatus.passed:      return AppTheme.topicPassed;
      case TopicStatus.inProgress:  return AppTheme.topicInProgress;
      case TopicStatus.forthcoming: return AppTheme.topicForthcoming;
    }
  }

  IconData get icon {
    switch (this) {
      case TopicStatus.passed:      return Icons.check_circle_rounded;
      case TopicStatus.inProgress:  return Icons.play_circle_filled_rounded;
      case TopicStatus.forthcoming: return Icons.radio_button_unchecked_rounded;
    }
  }

  String get label {
    switch (this) {
      case TopicStatus.passed:      return 'Completed';
      case TopicStatus.inProgress:  return 'In Progress';
      case TopicStatus.forthcoming: return 'Upcoming';
    }
  }
}

// =============================================================================
// SKILL CHIP VARIANT  [TAV22 §4]
// =============================================================================

enum SkillChipVariant { present, gap, target }

// =============================================================================
// SEMANTIC-SCORE HELPERS  [AJJ26 §4]
// =============================================================================

Color simScoreColor(double score) {
  if (score >= 0.70) return AppTheme.scoreStrong;
  if (score >= 0.40) return AppTheme.scoreModerate;
  return AppTheme.scoreWeak;
}

String simScoreLabel(double score) {
  if (score >= 0.70) return 'Strong Match';
  if (score >= 0.40) return 'Moderate Match';
  return 'Weak Match';
}

const double kSkillWeight  = 2.0;
const double kDomainWeight = 1.0;

// =============================================================================
// CAREER-READINESS HELPERS  [ALS22 §4]
// =============================================================================

Color readinessColor(int score) {
  if (score >= 70) return AppTheme.readinessHigh;
  if (score >= 40) return AppTheme.readinessMedium;
  return AppTheme.readinessLow;
}

String readinessLabel(int score) {
  if (score >= 70) return 'Job Ready';
  if (score >= 40) return 'Developing';
  return 'Needs Work';
}