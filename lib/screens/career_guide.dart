// lib/screens/career_guide.dart — SkillBridge AI
//
// FIXED:
//   • Local build() variables renamed from _bg/_card/… to bg/card/… so they
//     shadow nothing and are clearly referenced — eliminates "declaration not
//     referenced" warnings.
//   • Removed phantom `_surface` declaration.
//   • Every for / for-in body is now enclosed in braces.
//   • All original logic, models, services, and SDG copy preserved exactly.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:skillbridge_ai/screens/skill_input.dart';

import '../main.dart' hide industryColor;
import '../models/career_profile.dart';
import '../models/job.dart' show industryColor;
import '../services/app_state.dart';
import '../theme/app_theme.dart';

extension _GpaTierColorExt on GpaTier {
  Color get badgeColor {
    const palette = <Color>[
      Color(0xFF2E7D32), // index 0 — highest tier
      Color(0xFF1565C0), // index 1
      Color(0xFFF57F17), // index 2
      Color(0xFFD32F2F), // index 3 — lowest tier
    ];
    return palette[index.clamp(0, palette.length - 1)];
  }
}

// ─── Industry skill-frequency map ────────────────────────────────────────────

const Map<String, double> _skillImportance = {
  // Software
  'python':               1.00, 'java':                0.98, 'c++':                0.98,
  'sql':                  0.97, 'react':               0.97, 'machine learning':   0.96,
  'aws':                  0.96, 'git':                 0.92, 'docker':             0.88,
  'cloud computing':      0.88, 'javascript':          0.94, 'node.js':            0.82,
  // Finance
  'excel':                1.00, 'risk analysis':       0.99, 'financial modeling': 0.96,
  'statistics':           0.90, 'reporting':           0.88, 'accounting':         0.84,
  'bloomberg terminal':   0.72,
  // Healthcare
  'patient care':         1.00, 'pharmaceuticals':     0.99, 'nursing':            0.99,
  'medical research':     0.99, 'emr systems':         0.80, 'clinical documentation': 0.78,
  // Manufacturing
  'production planning':  1.00, 'quality control':     0.99, 'supply chain':       0.99,
  'erp systems':          0.85, 'logistics':           0.84, 'inventory management': 0.82,
  // Marketing
  'seo':                  1.00, 'content writing':     0.99, 'google ads':         0.97,
  'market research':      0.96, 'social media':        0.95, 'copywriting':        0.88,
  'analytics':            0.86, 'ux design':           0.90, 'figma':              0.88,
  // Retail
  'merchandising':        1.00, 'customer service':    0.99, 'sales':              0.98,
  'negotiation':          0.82, 'vendor management':   0.80,
  // Education
  'teaching':             1.00, 'edtech':              0.99, 'curriculum design':  0.99,
  'research':             0.98, 'lms platforms':       0.80, 'assessment design':  0.78,
  // Cross-industry
  'communication skills': 0.94, 'project management':  0.88, 'leadership':         0.86,
  'data analysis':        0.95, 'problem solving':     0.88, 'presentation skills': 0.80,
};

double _importance(String skill) =>
    _skillImportance[skill.toLowerCase()] ?? 0.65;

// ─── Readiness checklist ──────────────────────────────────────────────────────

class _ReadinessItem {
  final String   label;
  final IconData icon;
  final String   detail;

  const _ReadinessItem({
    required this.label,
    required this.icon,
    required this.detail,
  });
}

const List<_ReadinessItem> _readinessItems = [
  _ReadinessItem(
    label:  'Profile complete',
    icon:   Icons.person_outline_rounded,
    detail: 'Name, field, and year of study saved',
  ),
  _ReadinessItem(
    label:  'Skills added',
    icon:   Icons.psychology_outlined,
    detail: 'At least 3 skills added to your profile',
  ),
  _ReadinessItem(
    label:  'CV uploaded',
    icon:   Icons.upload_file_rounded,
    detail: 'Resume or CV uploaded to SkillBridge',
  ),
  _ReadinessItem(
    label:  'Course started',
    icon:   Icons.play_circle_outline_rounded,
    detail: 'Enrolled in at least one learning resource',
  ),
  _ReadinessItem(
    label:  'Job saved',
    icon:   Icons.bookmark_border_rounded,
    detail: 'Saved a job you want to apply for',
  ),
];

List<bool> _readinessTicks(CareerProfile profile, AppState appState) => [
  profile.name.isNotEmpty && profile.fieldOfStudy != FieldOfStudy.other,
  profile.skills.length >= 3,
  appState.cvUploaded,
  appState.enrolledCourseIds.isNotEmpty,
  appState.savedJobIds.isNotEmpty,
];

int computeReadinessScore(CareerProfile profile, AppState appState) {
  final ticks = _readinessTicks(profile, appState);
  final done  = ticks.where((t) => t).length;
  return ((done / ticks.length) * 100).round();
}

// ─── SDG-8 contribution copy ──────────────────────────────────────────────────

String _sdgContribution(FieldOfStudy field) {
  switch (field) {
    case FieldOfStudy.engineering:
    case FieldOfStudy.it:
      return 'Software and engineering careers drive productivity growth '
          '(SDG-8.2) and create quality tech jobs aligned with '
          'full, productive employment (SDG-8.5).';
    case FieldOfStudy.business:
      return 'Business graduates support economic growth (SDG-8.1), '
          'promote decent work conditions (SDG-8.5), and often found '
          'SMEs that generate inclusive employment (SDG-8.3).';
    case FieldOfStudy.finance:
      return 'Finance professionals enable access to banking and financial '
          'services (SDG-8.10), support sustainable economic growth '
          '(SDG-8.1), and reduce informal employment (SDG-8.3).';
    case FieldOfStudy.science:
      return 'Science careers advance research & innovation (SDG-8.2), '
          'support green economic growth (SDG-8.4), and contribute to '
          'health and technology sectors (SDG-8.6).';
    case FieldOfStudy.healthcare:
      return 'Healthcare is a pillar of decent work (SDG-8.5). Clinical '
          'and public-health careers protect workers (SDG-8.8) and '
          'directly advance health as a dimension of economic growth.';
    case FieldOfStudy.marketing:
      return 'Marketing drives business growth (SDG-8.1), fuels SME '
          'visibility (SDG-8.3), and promotes fair tourism, artisan '
          'products, and sustainable consumption (SDG-8.9).';
    case FieldOfStudy.education:
      return 'Teaching and instructional-design roles develop youth skills '
          '(SDG-8.6), reduce youth unemployment (SDG-8.6), and build '
          'the vocational training capacity SDG-8 calls for.';
    case FieldOfStudy.arts:
      return 'Creative careers support cultural and creative industries '
          '(SDG-8.9), provide decent self-employment (SDG-8.3), and '
          'contribute to inclusive cities and sustainable tourism.';
    case FieldOfStudy.law:
      return 'Legal professionals uphold labour rights (SDG-8.8), fight '
          'forced labour and trafficking (SDG-8.7), and advance '
          'regulatory frameworks for safe, fair workplaces (SDG-8.5).';
    default:
      return 'Every career path, when pursued with skill and purpose, '
          'contributes to SDG-8: Decent Work and Economic Growth — '
          'supporting productive employment and inclusive prosperity.';
  }
}

List<String> _sdgTargets(FieldOfStudy field) {
  switch (field) {
    case FieldOfStudy.engineering:
    case FieldOfStudy.it:
      return ['8.2 Productivity', '8.5 Full employment', '8.6 Youth NEET'];
    case FieldOfStudy.finance:
      return ['8.1 Growth', '8.10 Financial access', '8.3 Decent jobs'];
    case FieldOfStudy.healthcare:
      return ['8.5 Decent work', '8.8 Safe workplaces', '8.6 Youth'];
    case FieldOfStudy.education:
      return ['8.6 Youth skills', '8.5 Employment', '8.3 Informality'];
    case FieldOfStudy.arts:
      return ['8.9 Tourism & culture', '8.3 Self-employment', '8.5 Decent work'];
    case FieldOfStudy.law:
      return ['8.7 End forced labour', '8.8 Labour rights', '8.5 Fair work'];
    default:
      return ['8.1 Economic growth', '8.5 Decent work', '8.3 Entrepreneurship'];
  }
}

// ─── Industry skill corpus ────────────────────────────────────────────────────

const Map<String, List<String>> _industryCorpus = {
  'Software':      ['python', 'java', 'c++', 'sql', 'react', 'machine learning',
    'aws', 'git', 'javascript', 'docker', 'cloud computing', 'oop'],
  'Finance':       ['excel', 'risk analysis', 'sql', 'python', 'financial modeling',
    'reporting', 'statistics', 'accounting', 'data analysis'],
  'Healthcare':    ['patient care', 'pharmaceuticals', 'nursing', 'medical research',
    'clinical documentation', 'data analysis', 'reporting'],
  'Marketing':     ['seo', 'content writing', 'google ads', 'market research',
    'social media', 'analytics', 'copywriting', 'ux design', 'figma'],
  'Manufacturing': ['production planning', 'quality control', 'supply chain',
    'logistics', 'erp systems', 'inventory management', 'reporting'],
  'Retail':        ['merchandising', 'customer service', 'sales', 'negotiation',
    'vendor management', 'communication skills', 'market research'],
  'Education':     ['teaching', 'edtech', 'curriculum design', 'research',
    'communication skills', 'lms platforms', 'assessment design'],
};

double _industrySimilarity(List<String> userSkills, String industry) {
  final corpus = _industryCorpus[industry] ?? [];
  if (corpus.isEmpty || userSkills.isEmpty) return 0.0;
  final lower = userSkills.map((s) => s.toLowerCase()).toSet();
  final hits  = corpus.where((s) => lower.contains(s.toLowerCase())).length;
  return (hits / corpus.length).clamp(0.0, 1.0);
}

// ─── UI presentation helpers ──────────────────────────────────────────────────

(IconData, Color, Color, String, String) _industryCardInfo(String industry) {
  switch (industry) {
    case 'Software':
      return (Icons.code_rounded,
      const Color(0xFF1565C0), const Color(0xFF42A5F5), '1,200+', '65');
    case 'Finance':
      return (Icons.account_balance_outlined,
      const Color(0xFF2E7D32), const Color(0xFF66BB6A), '850+', '72');
    case 'Healthcare':
      return (Icons.local_hospital_outlined,
      const Color(0xFFC62828), const Color(0xFFEF5350), '600+', '60');
    case 'Marketing':
      return (Icons.campaign_outlined,
      const Color(0xFF6A1B9A), const Color(0xFFBA68C8), '700+', '55');
    case 'Manufacturing':
      return (Icons.precision_manufacturing_outlined,
      const Color(0xFFBF360C), const Color(0xFFFF7043), '500+', '50');
    case 'Retail':
      return (Icons.storefront_outlined,
      const Color(0xFF00695C), const Color(0xFF26A69A), '900+', '45');
    case 'Education':
      return (Icons.school_outlined,
      const Color(0xFF0277BD), const Color(0xFF29B6F6), '400+', '42');
    default:
      return (Icons.work_outline_rounded,
      const Color(0xFF37474F), const Color(0xFF78909C), '300+', '50');
  }
}

(String, String, Color) _industryInsightInfo(String industry) {
  switch (industry) {
    case 'Software':      return ('💻', '+18%', const Color(0xFF1565C0));
    case 'Finance':       return ('💰', '+12%', const Color(0xFF2E7D32));
    case 'Healthcare':    return ('🏥', '+15%', const Color(0xFFC62828));
    case 'Marketing':     return ('📢', '+10%', const Color(0xFF6A1B9A));
    case 'Manufacturing': return ('🏭', '+8%',  const Color(0xFFBF360C));
    case 'Retail':        return ('🛍️', '+6%',  const Color(0xFF00695C));
    case 'Education':     return ('📚', '+9%',  const Color(0xFF0277BD));
    default:              return ('💼', '+7%',  AppTheme.primaryBlue);
  }
}

// ─── Theme helpers ────────────────────────────────────────────────────────────

Color _bgColor(bool isDark)     => isDark ? const Color(0xFF0F172A) : Colors.white;
Color _cardColor(bool isDark)   => isDark ? const Color(0xFF1E293B) : Colors.white;
Color _textColor(bool isDark)   => isDark ? Colors.white            : const Color(0xFF0F172A);
Color _subColor(bool isDark)    => isDark ? Colors.white54          : Colors.grey.shade600;
Color _borderColor(bool isDark) => isDark ? Colors.white12          : Colors.grey.shade200;

// ══════════════════════════════════════════════════════════════════════════════
// ANIMATION HELPERS
// ══════════════════════════════════════════════════════════════════════════════

/// Animated linear progress bar — value animates from 0 → target on first build.
class _AnimatedLinearBar extends StatelessWidget {
  final double value;
  final Color  barColor;
  final Color? bgColor;
  final double minHeight;

  const _AnimatedLinearBar({
    required this.value,
    required this.barColor,
    this.bgColor,
    this.minHeight = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final bg = bgColor ??
        (Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withAlpha(20)
            : Colors.grey.shade100);
    return TweenAnimationBuilder<double>(
      tween:    Tween<double>(begin: 0.0, end: value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 900),
      curve:    Curves.easeOutCubic,
      builder:  (_, v, __) => ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value:           v,
          minHeight:       minHeight,
          backgroundColor: bg,
          valueColor:      AlwaysStoppedAnimation<Color>(barColor),
        ),
      ),
    );
  }
}

/// Animated circular progress ring — value animates from 0 → target on first build.
class _AnimatedCircularRing extends StatelessWidget {
  final double   value;
  final Color    ringColor;
  final Widget   label;
  final double   size;
  final double   strokeWidth;
  final Duration duration;

  const _AnimatedCircularRing({
    required this.value,
    required this.ringColor,
    required this.label,
    this.size        = 72.0,
    this.strokeWidth = 6.0,
    this.duration    = const Duration(milliseconds: 1000),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween:    Tween<double>(begin: 0.0, end: value.clamp(0.0, 1.0)),
      duration: duration,
      curve:    Curves.easeOutCubic,
      builder:  (_, v, __) => SizedBox(
        width:  size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value:           v,
              strokeWidth:     strokeWidth,
              backgroundColor: ringColor.withAlpha(25),
              valueColor:      AlwaysStoppedAnimation<Color>(ringColor),
            ),
            label,
          ],
        ),
      ),
    );
  }
}

/// Press-scale wrapper — 0.97× scale on tap-down, snaps back on release.
class _PressScaleCard extends StatefulWidget {
  final Widget child;

  const _PressScaleCard({required this.child});

  @override
  State<_PressScaleCard> createState() => _PressScaleCardState();
}

class _PressScaleCardState extends State<_PressScaleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 110));
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => _ctrl.forward(),
      onTapUp:     (_) {
        _ctrl.reverse();
        HapticFeedback.lightImpact();
      },
      onTapCancel: ()  => _ctrl.reverse(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// CAREER GUIDE SCREEN
// ──────────────────────────────────────────────────────────────────────────────

class CareerGuideScreen extends StatelessWidget {
  final CareerProfile profile;

  const CareerGuideScreen({super.key, required this.profile});

  IconData _industryIcon(String industry) {
    const map = {
      'Software':      Icons.code_rounded,
      'Finance':       Icons.account_balance_outlined,
      'Healthcare':    Icons.local_hospital_outlined,
      'Marketing':     Icons.campaign_outlined,
      'Manufacturing': Icons.precision_manufacturing_outlined,
      'Retail':        Icons.storefront_outlined,
      'Education':     Icons.school_outlined,
    };
    return map[industry] ?? Icons.work_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final appState   = context.watch<AppState>();
    final guidance   = getCareerGuidance(profile);
    final interests  = getCareerInterests(profile.fieldOfStudy);
    final successPct = (profile.successProbability * 100).round();
    final tier       = profile.gpaTier;
    final readiness  = computeReadinessScore(profile, appState);

    // FIX: Local vars use plain names (bg / card / text / sub / border),
    //      not underscore-prefixed names, to avoid shadowing and lint warnings.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = _bgColor(isDark);
    final card   = _cardColor(isDark);
    final text   = _textColor(isDark);
    final sub    = _subColor(isDark);
    final border = _borderColor(isDark);

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        slivers: [

          // ════════════════════════════════════════════════════════
          // SLIVER APP BAR
          // ════════════════════════════════════════════════════════
          SliverAppBar(
            expandedHeight:         220,
            pinned:                 true,
            backgroundColor:        bg,
            foregroundColor:        text,
            elevation:              0,
            scrolledUnderElevation: 1,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              titlePadding: const EdgeInsets.only(
                  left: 56, bottom: 14, right: 16),
              title: Text(
                'Career Guide',
                style: TextStyle(
                  color:         text,
                  fontWeight:    FontWeight.bold,
                  fontSize:      17,
                  letterSpacing: 0.2,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF06184A),
                          Color(0xFF0A2E6E),
                          Color(0xFF1565C0),
                        ],
                        stops: [0.0, 0.5, 1.0],
                        begin:  Alignment.topLeft,
                        end:    Alignment.bottomRight,
                      ),
                    ),
                  ),
                  Positioned(
                    right: -40, top: -30,
                    child: Container(
                      width: 190, height: 190,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withAlpha(10),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 28, bottom: -28,
                    child: Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withAlpha(14),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -20, bottom: 20,
                    child: Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withAlpha(7),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment:  MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color:        Colors.white.withAlpha(45),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.white.withAlpha(40)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.public_rounded,
                                    size: 11, color: Colors.white),
                                SizedBox(width: 5),
                                Text(
                                  'SDG 8 · Decent Work & Growth',
                                  style: TextStyle(
                                    color:         Colors.white,
                                    fontSize:      11,
                                    fontWeight:    FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Career Guide 🗺️',
                            style: TextStyle(
                              color:         Colors.white,
                              fontSize:      26,
                              fontWeight:    FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Your personalized roadmap to success',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ════════════════════════════════════════════════════════
          // BODY
          // ════════════════════════════════════════════════════════
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),

                // ── Profile summary card ──────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _ProfileCard(profile: profile, tier: tier),
                ),
                const SizedBox(height: 32),

                // ── Career Paths ──────────────────────────────────
                _MagSectionHeader(
                  icon:   Icons.route_rounded,
                  title:  'Career Paths',
                  isDark: isDark,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 218,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding:         const EdgeInsets.symmetric(horizontal: 20),
                    itemCount:       guidance.keySkillsToLearn.length,
                    itemBuilder: (ctx, i) {
                      final industry = guidance.topIndustries?[i] ?? '';
                      final info     = _industryCardInfo(industry);
                      return _IndustryPathCard(
                        industry:    industry,
                        pathIcon:    info.$1,
                        color1:      info.$2,
                        color2:      info.$3,
                        jobCount:    info.$4,
                        salary:      info.$5,
                        cardColor:   card,
                        textColor:   text,
                        subColor:    sub,
                        borderColor: border,
                        isDark:      isDark,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 32),

                // ── Skill Roadmap ─────────────────────────────────
                _MagSectionHeader(
                  icon:   Icons.map_outlined,
                  title:  'Your Skill Roadmap',
                  isDark: isDark,
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Path to: ${guidance.recommendedCareerPath}',
                    style: TextStyle(
                        fontSize:   13,
                        color:      sub,
                        fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _SkillRoadmapSection(
                    skills:      guidance.keySkillsToLearn,
                    userSkills:  profile.skills,
                    cardColor:   card,
                    textColor:   text,
                    subColor:    sub,
                    borderColor: border,
                    isDark:      isDark,
                  ),
                ),
                const SizedBox(height: 32),

                // ── Industry Insights ─────────────────────────────
                _MagSectionHeader(
                  icon:   Icons.insights_rounded,
                  title:  'Industry Insights',
                  isDark: isDark,
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.count(
                    crossAxisCount:   2,
                    mainAxisSpacing:  12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.55,
                    shrinkWrap:       true,
                    physics:          const NeverScrollableScrollPhysics(),
                    children: _industryCorpus.keys.take(6).map((industry) {
                      final topSkill =
                      (_industryCorpus[industry] ?? []).isNotEmpty
                          ? _industryCorpus[industry]!.first
                          : '';
                      final info = _industryInsightInfo(industry);
                      return _IndustryInsightCard(
                        industry:    industry,
                        emoji:       info.$1,
                        growth:      info.$2,
                        topSkill:    topSkill,
                        accentColor: info.$3,
                        cardColor:   card,
                        textColor:   text,
                        subColor:    sub,
                        borderColor: border,
                        isDark:      isDark,
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 32),

                // ── Recommended career path ───────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _CareerPathCard(
                      path: guidance.recommendedCareerPath),
                ),
                const SizedBox(height: 20),

                // ── Success probability ───────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _SuccessCard(
                    probability: profile.successProbability,
                    pct:         successPct,
                    gpa:         profile.gpa,
                  ),
                ),
                const SizedBox(height: 32),

                // ── Career Readiness ──────────────────────────────
                _MagSectionHeader(
                  icon:   Icons.checklist_rounded,
                  title:  'Career Readiness',
                  isDark: isDark,
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _ReadinessCard(
                    profile:  profile,
                    appState: appState,
                    score:    readiness,
                  ),
                ),
                const SizedBox(height: 32),

                // ── Recommended industries ────────────────────────
                _MagSectionHeader(
                  icon:   Icons.factory_outlined,
                  title:  'Recommended Industries',
                  isDark: isDark,
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Wrap(
                    spacing:    8,
                    runSpacing: 8,
                    children: (guidance.topIndustries ?? []).map((ind) {
                      return Semantics(
                        label: '$ind industry',
                        child: Chip(
                          label: Text(
                            ind,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          backgroundColor: industryColor(ind),
                          avatar: Icon(
                            _industryIcon(ind),
                            color: Colors.white,
                            size: 14,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 32),

                // ── Industry match chart ──────────────────────────
                _MagSectionHeader(
                  icon:   Icons.bar_chart_rounded,
                  title:  'Your Industry Match',
                  isDark: isDark,
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Cosine similarity of your skills vs each industry '
                        'skill corpus.  [Alsaif et al. §4.3]',
                    style: TextStyle(fontSize: 11, color: sub),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _IndustryMatchChart(
                    userSkills:    profile.skills,
                      topIndustries: guidance.topIndustries ?? [],
                  ),
                ),
                const SizedBox(height: 32),

                // ── Key skills to develop ─────────────────────────
                _MagSectionHeader(
                  icon:   Icons.auto_awesome_outlined,
                  title:  'Key Skills to Develop',
                  isDark: isDark,
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: guidance.keySkillsToLearn
                        .asMap()
                        .entries
                        .map((e) {
                      final hasSkill = profile.skills
                          .map((s) => s.toLowerCase())
                          .contains(e.value.toLowerCase());
                      return _SkillRow(
                        index:    e.key + 1,
                        skill:    e.value,
                        hasSkill: hasSkill,
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 32),

                // ── Skill importance chart ────────────────────────
                _MagSectionHeader(
                  icon:   Icons.analytics_outlined,
                  title:  'Skill Importance in Your Field',
                  isDark: isDark,
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Bar width = skill occurrence frequency in 50,000-row '
                        'job dataset.  [Tavakoli §3.1.4 Service_3]',
                    style: TextStyle(fontSize: 11, color: sub),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _SkillImportanceChart(
                    skills:     guidance.keySkillsToLearn,
                    userSkills: profile.skills,
                  ),
                ),
                const SizedBox(height: 32),

                // ── Missing core skills ───────────────────────────
                if (profile.missingCoreSkills.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _MagSectionHeader(
                      icon:   Icons.playlist_add_check_outlined,
                      title:  'Core Skills Gap (${profile.fieldOfStudy.label})',
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      width:   double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.orange.withAlpha(20)
                            : const Color(0xFFFFF8F0),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.orange.withAlpha(100)),
                      ),
                      child: Wrap(
                        spacing:    8,
                        runSpacing: 8,
                        children: profile.missingCoreSkills.map((s) {
                          return Semantics(
                            label: 'Missing skill: $s',
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color:        Colors.orange.withAlpha(20),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: Colors.orange.withAlpha(80)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_circle_outline_rounded,
                                      size:  12,
                                      color: Colors.orange.shade700),
                                  const SizedBox(width: 4),
                                  Text(
                                    s,
                                    style: TextStyle(
                                      fontSize:   12,
                                      color:      Colors.orange.shade800,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],

                // ── Career interests ──────────────────────────────
                _MagSectionHeader(
                  icon:   Icons.interests_outlined,
                  title:  'Career Interests in Your Field',
                  isDark: isDark,
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Wrap(
                    spacing:    8,
                    runSpacing: 8,
                    children: interests.map((interest) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.primaryBlue.withAlpha(28)
                              : const Color(0xFFEEF4FF),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppTheme.primaryBlue.withAlpha(60)),
                        ),
                        child: Text(
                          interest,
                          style: const TextStyle(
                            fontSize:   12,
                            color:      AppTheme.primaryBlue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 32),

                // ── SDG-8 Contribution ────────────────────────────
                _MagSectionHeader(
                  icon:   Icons.public_rounded,
                  title:  'SDG-8 Contribution',
                  isDark: isDark,
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _SdgImpactCard(field: profile.fieldOfStudy),
                ),
                const SizedBox(height: 32),

                // ── Career Tips & Articles ────────────────────────
                _MagSectionHeader(
                  icon:   Icons.tips_and_updates_outlined,
                  title:  'Career Tips',
                  isDark: isDark,
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _TipCard(tip: guidance.careerTip),
                ),
                const SizedBox(height: 14),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _ArticleTipItem(
                    icon:      Icons.edit_document,
                    iconColor: const Color(0xFF1565C0),
                    title:     'Craft a stand-out CV for Bangladeshi employers',
                    desc:      'Tailored to local market expectations',
                    readTime:  '3',
                    isDark:    isDark,
                    card:      card,
                    text:      text,
                    sub:       sub,
                    border:    border,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _ArticleTipItem(
                    icon:      Icons.handshake_outlined,
                    iconColor: const Color(0xFF2E7D32),
                    title:     'LinkedIn & Shomvob: networking for SDG-8 careers',
                    desc:      'Build connections that open doors',
                    readTime:  '4',
                    isDark:    isDark,
                    card:      card,
                    text:      text,
                    sub:       sub,
                    border:    border,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _ArticleTipItem(
                    icon:      Icons.quiz_outlined,
                    iconColor: const Color(0xFF6A1B9A),
                    title:     'Ace your next technical interview with AI prep',
                    desc:      'Mock tests aligned to your skill gaps',
                    readTime:  '5',
                    isDark:    isDark,
                    card:      card,
                    text:      text,
                    sub:       sub,
                    border:    border,
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<String> getCareerInterests(FieldOfStudy fieldOfStudy) {
    switch (fieldOfStudy) {
      case FieldOfStudy.engineering:
        return ['Software Development', 'Embedded Systems', 'Robotics',
          'DevOps', 'Cloud Architecture', 'Cybersecurity'];
      case FieldOfStudy.it:
        return ['Web Development', 'Mobile Apps', 'Database Administration',
          'Network Engineering', 'AI & Machine Learning', 'IT Support'];
      case FieldOfStudy.business:
        return ['Entrepreneurship', 'Management Consulting', 'Operations',
          'Human Resources', 'Business Analysis', 'Supply Chain'];
      case FieldOfStudy.finance:
        return ['Investment Banking', 'Financial Analysis', 'Accounting',
          'Risk Management', 'Fintech', 'Wealth Management'];
      case FieldOfStudy.science:
        return ['Research & Development', 'Biotechnology', 'Data Science',
          'Environmental Science', 'Pharmaceuticals', 'Academia'];
      case FieldOfStudy.healthcare:
        return ['Clinical Practice', 'Medical Research', 'Public Health',
          'Health Informatics', 'Nursing', 'Healthcare Management'];
      case FieldOfStudy.marketing:
        return ['Digital Marketing', 'Brand Management', 'Content Strategy',
          'Market Research', 'Advertising', 'E-commerce'];
      case FieldOfStudy.education:
        return ['Teaching', 'Curriculum Design', 'EdTech', 'Corporate Training',
          'Educational Research', 'Academic Administration'];
      case FieldOfStudy.arts:
        return ['Graphic Design', 'UX/UI Design', 'Creative Direction',
          'Multimedia', 'Animation', 'Illustration'];
      case FieldOfStudy.law:
        return ['Corporate Law', 'Human Rights', 'Litigation',
          'Legal Consulting', 'Compliance', 'Public Policy'];
      default:
        return ['Project Management', 'Communication', 'Leadership',
          'Problem Solving', 'Data Analysis', 'Critical Thinking'];
    }
  }
}

// ══════════════════════════════════════════════════════════
// _MagSectionHeader
// ══════════════════════════════════════════════════════════

class _MagSectionHeader extends StatelessWidget {
  final IconData icon;
  final String   title;
  final bool     isDark;

  const _MagSectionHeader({
    required this.icon,
    required this.title,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            width:  36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryBlue.withAlpha(30),
                  AppTheme.primaryBlue.withAlpha(18),
                ],
                begin: Alignment.topLeft,
                end:   Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                  color: AppTheme.primaryBlue.withAlpha(40)),
            ),
            child: Icon(icon, size: 17, color: AppTheme.primaryBlue),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize:      16,
              fontWeight:    FontWeight.bold,
              color:         _textColor(isDark),
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// _IndustryPathCard
// ══════════════════════════════════════════════════════════

class _IndustryPathCard extends StatelessWidget {
  final String   industry;
  final IconData pathIcon;
  final Color    color1;
  final Color    color2;
  final String   jobCount;
  final String   salary;
  final Color    cardColor;
  final Color    textColor;
  final Color    subColor;
  final Color    borderColor;
  final bool     isDark;

  const _IndustryPathCard({
    required this.industry,
    required this.pathIcon,
    required this.color1,
    required this.color2,
    required this.jobCount,
    required this.salary,
    required this.cardColor,
    required this.textColor,
    required this.subColor,
    required this.borderColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return _PressScaleCard(
      child: Container(
        width:  182,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color:        cardColor,
          borderRadius: BorderRadius.circular(20),
          border:       Border.all(color: borderColor),
          boxShadow: isDark
              ? const []
              : [
            BoxShadow(
              color:      color1.withAlpha(20),
              blurRadius: 14,
              offset:     const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width:  double.infinity,
              height: 94,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20)),
                gradient: LinearGradient(
                  colors: [color1, color2],
                  begin:  Alignment.topLeft,
                  end:    Alignment.bottomRight,
                ),
              ),
              child: Stack(children: [
                Positioned(
                  right: -16, top: -16,
                  child: Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withAlpha(18),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Icon(pathIcon, color: Colors.white, size: 36),
                  ),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    industry,
                    style: TextStyle(
                      fontSize:      15,
                      fontWeight:    FontWeight.w700,
                      color:         textColor,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.work_outline_rounded,
                        size: 11, color: subColor),
                    const SizedBox(width: 4),
                    Text('$jobCount jobs',
                        style: TextStyle(fontSize: 11, color: subColor)),
                  ]),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color:        AppTheme.primaryBlue.withAlpha(14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Avg ৳${salary}K/mo',
                      style: const TextStyle(
                        fontSize:   12,
                        fontWeight: FontWeight.w700,
                        color:      AppTheme.primaryBlue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Row(
                    children: [
                      Text(
                        'Explore',
                        style: TextStyle(
                          fontSize:   12,
                          fontWeight: FontWeight.w600,
                          color:      AppTheme.primaryBlue,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.arrow_forward_rounded,
                          size: 14, color: AppTheme.primaryBlue),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// _SkillRoadmapSection
// ══════════════════════════════════════════════════════════

class _SkillRoadmapSection extends StatelessWidget {
  final List<String> skills;
  final List<String> userSkills;
  final Color        cardColor;
  final Color        textColor;
  final Color        subColor;
  final Color        borderColor;
  final bool         isDark;

  const _SkillRoadmapSection({
    required this.skills,
    required this.userSkills,
    required this.cardColor,
    required this.textColor,
    required this.subColor,
    required this.borderColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final lowerUser = userSkills.map((s) => s.toLowerCase()).toSet();
    int currentIdx  =
    skills.indexWhere((s) => !lowerUser.contains(s.toLowerCase()));
    if (currentIdx == -1) currentIdx = skills.length;

    return Semantics(
      label: 'Skill roadmap with ${skills.length} steps. '
          'Current step: ${currentIdx < skills.length ? skills[currentIdx] : "All complete"}.',
      child: Container(
        width:   double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color:        cardColor,
          borderRadius: BorderRadius.circular(18),
          border:       Border.all(color: borderColor),
          boxShadow: isDark
              ? const []
              : [
            BoxShadow(
              color:      Colors.black.withAlpha(12),
              blurRadius: 10,
              offset:     const Offset(0, 4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: skills.asMap().entries.map((entry) {
              final i         = entry.key;
              final skill     = entry.value;
              final completed = lowerUser.contains(skill.toLowerCase());
              final isCurrent = i == currentIdx;
              final isLast    = i == skills.length - 1;

              final Color    nodeColor;
              final Color    nodeTextColor;
              final IconData nodeIcon;

              if (completed) {
                nodeColor     = AppTheme.accentGreen;
                nodeTextColor = Colors.white;
                nodeIcon      = Icons.check_rounded;
              } else if (isCurrent) {
                nodeColor     = AppTheme.primaryBlue;
                nodeTextColor = Colors.white;
                nodeIcon      = Icons.play_arrow_rounded;
              } else {
                nodeColor     = borderColor;
                nodeTextColor = subColor;
                nodeIcon      = Icons.lock_outline_rounded;
              }

              final double nodeSize = isCurrent ? 50 : 44;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width:  nodeSize,
                        height: nodeSize,
                        decoration: BoxDecoration(
                          shape:  BoxShape.circle,
                          color:  nodeColor,
                          border: isCurrent
                              ? Border.all(
                              color: AppTheme.primaryBlue.withAlpha(70),
                              width: 3)
                              : null,
                          boxShadow: isCurrent
                              ? [
                            BoxShadow(
                              color:        AppTheme.primaryBlue.withAlpha(60),
                              blurRadius:   14,
                              spreadRadius: 2,
                            ),
                          ]
                              : completed
                              ? [
                            BoxShadow(
                              color:      AppTheme.accentGreen.withAlpha(40),
                              blurRadius: 8,
                            ),
                          ]
                              : null,
                        ),
                        child: Icon(nodeIcon, color: nodeTextColor, size: 20),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 70,
                        child: Column(children: [
                          Text(
                            skill,
                            style: TextStyle(
                              fontSize:   10,
                              fontWeight: completed || isCurrent
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                              color: completed
                                  ? AppTheme.accentGreen
                                  : isCurrent
                                  ? AppTheme.primaryBlue
                                  : subColor,
                            ),
                            textAlign: TextAlign.center,
                            maxLines:  2,
                            overflow:  TextOverflow.ellipsis,
                          ),
                          if (isCurrent) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryBlue.withAlpha(18),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Next',
                                style: TextStyle(
                                  fontSize:   8,
                                  color:      AppTheme.primaryBlue,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ]),
                      ),
                    ],
                  ),
                  if (!isLast)
                    Padding(
                      padding: const EdgeInsets.only(top: 22),
                      child: Container(
                        width:  32,
                        height: 2.5,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: completed
                                ? [
                              AppTheme.accentGreen,
                              AppTheme.accentGreen.withAlpha(140),
                            ]
                                : [
                              borderColor,
                              borderColor.withAlpha(80),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// _IndustryInsightCard
// ══════════════════════════════════════════════════════════

class _IndustryInsightCard extends StatelessWidget {
  final String industry;
  final String emoji;
  final String growth;
  final String topSkill;
  final Color  accentColor;
  final Color  cardColor;
  final Color  textColor;
  final Color  subColor;
  final Color  borderColor;
  final bool   isDark;

  const _IndustryInsightCard({
    required this.industry,
    required this.emoji,
    required this.growth,
    required this.topSkill,
    required this.accentColor,
    required this.cardColor,
    required this.textColor,
    required this.subColor,
    required this.borderColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return _PressScaleCard(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:        cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withAlpha(50)),
          boxShadow: isDark
              ? const []
              : [
            BoxShadow(
              color:      accentColor.withAlpha(14),
              blurRadius: 10,
              offset:     const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 22)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color:        AppTheme.accentGreen.withAlpha(24),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.trending_up_rounded,
                          size: 10, color: AppTheme.accentGreen),
                      const SizedBox(width: 3),
                      Text(
                        growth,
                        style: const TextStyle(
                          fontSize:   10,
                          fontWeight: FontWeight.w700,
                          color:      AppTheme.accentGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              industry,
              style: TextStyle(
                fontSize:      13,
                fontWeight:    FontWeight.w700,
                color:         textColor,
                letterSpacing: -0.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '⚡ $topSkill',
              style: TextStyle(fontSize: 11, color: subColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// _ArticleTipItem
// ══════════════════════════════════════════════════════════

class _ArticleTipItem extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final String   title;
  final String   desc;
  final String   readTime;
  final bool     isDark;
  final Color    card;
  final Color    text;
  final Color    sub;
  final Color    border;

  const _ArticleTipItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.desc,
    required this.readTime,
    required this.isDark,
    required this.card,
    required this.text,
    required this.sub,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:  '$title. $desc. $readTime minute read.',
      button: true,
      child: _PressScaleCard(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:        card,
            borderRadius: BorderRadius.circular(16),
            border:       Border.all(color: border),
            boxShadow: isDark
                ? const []
                : [
              BoxShadow(
                color:      Colors.black.withAlpha(10),
                blurRadius: 8,
                offset:     const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width:  46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      iconColor.withAlpha(30),
                      iconColor.withAlpha(18),
                    ],
                    begin: Alignment.topLeft,
                    end:   Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: iconColor.withAlpha(40)),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize:   13,
                        fontWeight: FontWeight.w700,
                        color:      text,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      desc,
                      style: TextStyle(fontSize: 11, color: sub),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color:        AppTheme.primaryBlue.withAlpha(18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$readTime min',
                      style: const TextStyle(
                        fontSize:   10,
                        fontWeight: FontWeight.w600,
                        color:      AppTheme.primaryBlue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(Icons.chevron_right_rounded, size: 18, color: sub),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// _ReadinessCard
// ══════════════════════════════════════════════════════════

class _ReadinessCard extends StatelessWidget {
  final CareerProfile profile;
  final AppState      appState;
  final int           score;

  const _ReadinessCard({
    required this.profile,
    required this.appState,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    final ticks = _readinessTicks(profile, appState);

    final Color  ringColor;
    final String ringLabel;

    if (score >= 80) {
      ringColor = AppTheme.accentGreen;
      ringLabel = 'Job-Ready';
    } else if (score >= 50) {
      ringColor = const Color(0xFFF57F17);
      ringLabel = 'In Progress';
    } else {
      ringColor = const Color(0xFF1565C0);
      ringLabel = 'Getting Started';
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card   = _cardColor(isDark);
    final border = _borderColor(isDark);
    final text   = _textColor(isDark);
    final sub    = _subColor(isDark);

    return Semantics(
      label: 'Career readiness: $score%. Status: $ringLabel.',
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color:        card,
          borderRadius: BorderRadius.circular(18),
          border:       Border.all(color: border),
          boxShadow: isDark
              ? const []
              : [
            BoxShadow(
              color:      Colors.black.withAlpha(12),
              blurRadius: 14,
              offset:     const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                _AnimatedCircularRing(
                  value:       score / 100,
                  ringColor:   ringColor,
                  size:        74,
                  strokeWidth: 6,
                  duration:    const Duration(milliseconds: 1100),
                  label: Text(
                    '$score%',
                    style: TextStyle(
                      fontSize:   14,
                      fontWeight: FontWeight.bold,
                      color:      ringColor,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color:        ringColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: ringColor.withAlpha(50)),
                  ),
                  child: Text(
                    ringLabel,
                    style: TextStyle(
                      fontSize:   10,
                      color:      ringColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                // FIX: for-in body enclosed in braces via List.generate
                children: List.generate(_readinessItems.length, (i) {
                  final item   = _readinessItems[i];
                  final ticked = ticks[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width:  26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: ticked
                                ? AppTheme.accentGreen
                                : (isDark
                                ? Colors.white12
                                : const Color(0xFFF0F3F8)),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: ticked
                                  ? AppTheme.accentGreen
                                  : Colors.grey.shade300,
                            ),
                            boxShadow: ticked
                                ? [
                              BoxShadow(
                                color:      AppTheme.accentGreen.withAlpha(40),
                                blurRadius: 6,
                              ),
                            ]
                                : null,
                          ),
                          child: Icon(
                            ticked ? Icons.check_rounded : item.icon,
                            size:  13,
                            color: ticked
                                ? Colors.white
                                : Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.label,
                                style: TextStyle(
                                  fontSize:   12,
                                  fontWeight: FontWeight.w600,
                                  color: ticked ? AppTheme.accentGreen : text,
                                ),
                              ),
                              Text(
                                item.detail,
                                style: TextStyle(fontSize: 10, color: sub),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// _IndustryMatchChart
// ══════════════════════════════════════════════════════════

class _IndustryMatchChart extends StatelessWidget {
  final List<String> userSkills;
  final List<String> topIndustries;

  const _IndustryMatchChart({
    required this.userSkills,
    required this.topIndustries,
  });

  @override
  Widget build(BuildContext context) {
    final all = _industryCorpus.keys
        .map((ind) => (
    industry: ind,
    score:    _industrySimilarity(userSkills, ind),
    ))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final top5   = all.take(5).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card   = _cardColor(isDark);
    final border = _borderColor(isDark);
    final text   = _textColor(isDark);
    final sub    = _subColor(isDark);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:        card,
        borderRadius: BorderRadius.circular(18),
        border:       Border.all(color: border),
        boxShadow: isDark
            ? const []
            : [
          BoxShadow(
            color:      Colors.black.withAlpha(12),
            blurRadius: 14,
            offset:     const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...top5.asMap().entries.map((entry) {
            final rank     = entry.key + 1;
            final e        = entry.value;
            final barColor = simScoreColor(e.score);
            final label    = simScoreLabel(e.score);
            final isTop    = topIndustries.contains(e.industry);

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width:  22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: rank == 1
                              ? barColor.withAlpha(30)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                          border: rank == 1
                              ? Border.all(color: barColor.withAlpha(80))
                              : null,
                        ),
                        child: Text(
                          '#$rank',
                          style: TextStyle(
                            fontSize:   9,
                            fontWeight: FontWeight.bold,
                            color: rank == 1 ? barColor : sub,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 86,
                        child: Text(
                          e.industry,
                          style: TextStyle(
                            fontSize:   12,
                            fontWeight: isTop
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isTop ? text : sub,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        child: _AnimatedLinearBar(
                          value:     e.score,
                          barColor:  barColor,
                          minHeight: 10,
                          bgColor: isDark
                              ? Colors.white.withAlpha(15)
                              : Colors.grey.shade100,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 36,
                        child: Text(
                          '${(e.score * 100).round()}%',
                          style: TextStyle(
                            fontSize:   11,
                            fontWeight: FontWeight.bold,
                            color:      barColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Padding(
                    padding: const EdgeInsets.only(left: 114),
                    child: Text(
                      label,
                      style: TextStyle(
                          fontSize: 9,
                          color: barColor.withAlpha(190)),
                    ),
                  ),
                ],
              ),
            );
          }),

          Divider(height: 20, color: border),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _LegendDot(color: simScoreColor(0.80), label: 'Strong ≥75%'),
              _LegendDot(color: simScoreColor(0.55), label: 'Moderate 40–74%'),
              _LegendDot(color: simScoreColor(0.20), label: 'Weak <40%'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color  color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width:  8,
          height: 8,
          decoration:
          BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(fontSize: 9, color: _subColor(isDark)),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
// _SkillImportanceChart
// ══════════════════════════════════════════════════════════

class _SkillImportanceChart extends StatelessWidget {
  final List<String> skills;
  final List<String> userSkills;

  const _SkillImportanceChart({
    required this.skills,
    required this.userSkills,
  });

  @override
  Widget build(BuildContext context) {
    final lowerUser = userSkills.map((s) => s.toLowerCase()).toSet();
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final card      = _cardColor(isDark);
    final border    = _borderColor(isDark);
    final text      = _textColor(isDark);
    final sub       = _subColor(isDark);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:        card,
        borderRadius: BorderRadius.circular(18),
        border:       Border.all(color: border),
        boxShadow: isDark
            ? const []
            : [
          BoxShadow(
            color:      Colors.black.withAlpha(12),
            blurRadius: 14,
            offset:     const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...skills.map((skill) {
            final owned      = lowerUser.contains(skill.toLowerCase());
            final importance = _importance(skill);
            final barColor   =
            owned ? AppTheme.topicPassed : AppTheme.primaryBlue;

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 132,
                    child: Row(
                      children: [
                        Icon(
                          owned
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size:  13,
                          color: barColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            skill,
                            style: TextStyle(
                              fontSize:   11,
                              fontWeight: owned
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: owned ? barColor : text,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _AnimatedLinearBar(
                      value:    importance,
                      barColor: barColor.withAlpha(owned ? 220 : 140),
                      bgColor: isDark
                          ? Colors.white.withAlpha(15)
                          : Colors.grey.shade100,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 34,
                    child: Text(
                      '${(importance * 100).round()}%',
                      style: TextStyle(
                        fontSize:   10,
                        color:      barColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (owned)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color:        AppTheme.topicPassed.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '✓ You',
                        style: TextStyle(
                          fontSize:   9,
                          color:      AppTheme.topicPassed,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),

          Divider(height: 18, color: border),
          Row(
            children: [
              Container(
                width:  10,
                height: 10,
                decoration: const BoxDecoration(
                    color: AppTheme.topicPassed, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Text('Skills you own',
                  style: TextStyle(fontSize: 9, color: sub)),
              const SizedBox(width: 16),
              Container(
                width:  10,
                height: 10,
                decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withAlpha(140),
                    shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Text('Skills to learn',
                  style: TextStyle(fontSize: 9, color: sub)),
              const Spacer(),
              Text(
                'Bar = occurrence in 50k dataset',
                style: TextStyle(
                    fontSize: 9,
                    color: isDark
                        ? Colors.white24
                        : Colors.grey.shade400),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// SdgBadge
// ══════════════════════════════════════════════════════════

class SdgBadge extends StatelessWidget {
  final String target;
  final Color? color;

  const SdgBadge({super.key, required this.target, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primaryBlue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color:        c.withAlpha(18),
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: c.withAlpha(70)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.public_rounded, size: 11, color: c),
          const SizedBox(width: 4),
          Text(
            'SDG $target',
            style: TextStyle(
              fontSize:      10,
              color:         c,
              fontWeight:    FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// _SdgImpactCard
// ══════════════════════════════════════════════════════════

class _SdgImpactCard extends StatelessWidget {
  final FieldOfStudy field;
  const _SdgImpactCard({required this.field});

  @override
  Widget build(BuildContext context) {
    final copy    = _sdgContribution(field);
    final targets = _sdgTargets(field);
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final text    = _textColor(isDark);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.primaryBlue.withAlpha(20)
            : const Color(0xFFEEF6FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryBlue.withAlpha(60)),
        boxShadow: isDark
            ? const []
            : [
          BoxShadow(
            color:      Colors.blue.withAlpha(20),
            blurRadius: 14,
            offset:     const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width:  48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1565C0), Color(0xFF0891B2)],
                    begin:  Alignment.topLeft,
                    end:    Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.public_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SDG-8: Decent Work & Economic Growth',
                      style: TextStyle(
                        fontSize:   13,
                        fontWeight: FontWeight.bold,
                        color:      AppTheme.primaryBlue,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'United Nations Sustainable Development Goal',
                      style: TextStyle(
                          fontSize: 10,
                          color:    AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Text(
            copy,
            style: TextStyle(fontSize: 13, color: text, height: 1.65),
          ),
          const SizedBox(height: 14),

          Wrap(
            spacing:    6,
            runSpacing: 6,
            children: targets.map((t) {
              final Color c;
              if (t.contains('Youth')) {
                c = const Color(0xFF00796B);
              } else if (t.contains('growth') || t.contains('Growth')) {
                c = AppTheme.accentGreen;
              } else if (t.contains('labour') || t.contains('forced')) {
                c = const Color(0xFFD32F2F);
              } else {
                c = AppTheme.primaryBlue;
              }
              return SdgBadge(target: t, color: c);
            }).toList(),
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:        AppTheme.primaryBlue.withAlpha(12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppTheme.primaryBlue.withAlpha(30)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size:  15,
                  color: AppTheme.primaryBlue.withAlpha(180),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'SkillBridge AI aligns all recommendations with SDG-8 '
                        'to promote productive employment and inclusive growth '
                        'for Bangladeshi graduates.',
                    style: TextStyle(
                      fontSize: 11,
                      color:    AppTheme.textSecondary,
                      height:   1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// _ProfileCard
// ══════════════════════════════════════════════════════════

class _ProfileCard extends StatelessWidget {
  final CareerProfile profile;
  final GpaTier       tier;

  const _ProfileCard({required this.profile, required this.tier});

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color:        color.withAlpha(60),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: color.withAlpha(100)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color:      Colors.white,
          fontSize:   10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Profile: ${profile.name.isNotEmpty ? profile.name : "Your Profile"}. '
          '${profile.fieldOfStudy.label}, Year ${profile.yearOfStudy}. '
          'GPA ${profile.gpa.toStringAsFixed(1)}.',
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF06184A),
              Color(0xFF0A2E6E),
              Color(0xFF1E88E5),
            ],
            stops: [0.0, 0.45, 1.0],
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color:      AppTheme.primaryBlue.withAlpha(55),
              blurRadius: 18,
              offset:     const Offset(0, 7),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20, top: -20,
              child: Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(10),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width:  62,
                  height: 62,
                  decoration: BoxDecoration(
                    color:  Colors.white.withAlpha(35),
                    shape:  BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withAlpha(60), width: 2),
                  ),
                  child: const Icon(Icons.person_outline_rounded,
                      color: Colors.white, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name.isNotEmpty
                            ? profile.name
                            : 'Your Profile',
                        style: const TextStyle(
                          color:         Colors.white,
                          fontSize:      18,
                          fontWeight:    FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${profile.fieldOfStudy.label}  ·  '
                            'Year ${profile.yearOfStudy}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _badge(
                            'GPA ${profile.gpa.toStringAsFixed(1)}',
                            tier.badgeColor,
                          ),
                          const SizedBox(width: 6),
                          _badge(profile.experienceLabel, Colors.white38),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// _CareerPathCard
// ══════════════════════════════════════════════════════════

class _CareerPathCard extends StatelessWidget {
  final String path;
  const _CareerPathCard({required this.path});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card   = _cardColor(isDark);

    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:        card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryBlue.withAlpha(60)),
        boxShadow: isDark
            ? const []
            : [
          BoxShadow(
            color:      Colors.blue.withAlpha(14),
            blurRadius: 14,
            offset:     const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width:  34,
                height: 34,
                decoration: BoxDecoration(
                  color:        AppTheme.primaryBlue.withAlpha(18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppTheme.primaryBlue.withAlpha(40)),
                ),
                child: Icon(
                  Icons.compass_calibration_outlined,
                  color: AppTheme.primaryBlue.withAlpha(200),
                  size:  17,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Recommended Career Path',
                style: TextStyle(
                  fontSize:   12,
                  color:      _subColor(isDark),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            path,
            style: const TextStyle(
              fontSize:      23,
              fontWeight:    FontWeight.bold,
              color:         AppTheme.primaryBlue,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Row(children: [
            Icon(Icons.arrow_forward_rounded,
                size: 14, color: AppTheme.primaryBlue),
            SizedBox(width: 4),
            Text(
              'See learning plan',
              style: TextStyle(
                fontSize:   12,
                color:      AppTheme.primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// _SuccessCard
// ══════════════════════════════════════════════════════════

class _SuccessCard extends StatelessWidget {
  final double probability;
  final int    pct;
  final double gpa;

  const _SuccessCard({
    required this.probability,
    required this.pct,
    required this.gpa,
  });

  @override
  Widget build(BuildContext context) {
    final (Color color, String label, String subtitle) =
    switch (probability) {
      >= 0.75 => (
      AppTheme.accentGreen,
      'High Success Probability',
      "You're on a strong path. Keep building your portfolio.",
      ),
      >= 0.55 => (
      Colors.orange,
      'Moderate Success Probability',
      'Good foundation — add projects and certifications to stand out.',
      ),
      _ => (
      const Color(0xFFD32F2F),
      'Build More Skills First',
      'Focus on core skills and internship experience to boost your profile.',
      ),
    };

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      label: '$label. $subtitle',
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? color.withAlpha(20) : color.withAlpha(12),
          borderRadius: BorderRadius.circular(18),
          border:       Border.all(color: color.withAlpha(70)),
          boxShadow: isDark
              ? const []
              : [
            BoxShadow(
              color:      color.withAlpha(20),
              blurRadius: 14,
              offset:     const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            _AnimatedCircularRing(
              value:       probability,
              ringColor:   color,
              size:        78,
              strokeWidth: 7,
              duration:    const Duration(milliseconds: 1100),
              label: Text(
                '$pct%',
                style: TextStyle(
                  fontSize:   15,
                  fontWeight: FontWeight.bold,
                  color:      color,
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize:   14,
                      fontWeight: FontWeight.bold,
                      color:      color,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 12,
                        color:    AppTheme.textSecondary,
                        height:   1.5),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'GPA · Experience · Skills counted',
                    style: TextStyle(
                        fontSize: 12,
                        color:    AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// _SkillRow
// ══════════════════════════════════════════════════════════

class _SkillRow extends StatelessWidget {
  final int    index;
  final String skill;
  final bool   hasSkill;

  const _SkillRow({
    required this.index,
    required this.skill,
    required this.hasSkill,
  });

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final card     = _cardColor(isDark);
    final border   = _borderColor(isDark);
    final text     = _textColor(isDark);
    final impScore = _importance(skill);

    return Semantics(
      label: '$skill skill. '
          '${hasSkill ? "You already have this skill." : "Skill to learn."} '
          'Importance: ${(impScore * 100).round()}%.',
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: hasSkill
              ? AppTheme.accentGreen.withAlpha(isDark ? 25 : 12)
              : card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasSkill
                ? AppTheme.accentGreen.withAlpha(80)
                : border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width:     32,
              height:    32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: hasSkill
                    ? AppTheme.accentGreen
                    : AppTheme.primaryBlue.withAlpha(18),
                shape: BoxShape.circle,
                boxShadow: hasSkill
                    ? [
                  BoxShadow(
                      color:      AppTheme.accentGreen.withAlpha(50),
                      blurRadius: 6),
                ]
                    : null,
              ),
              child: hasSkill
                  ? const Icon(Icons.check_rounded,
                  color: Colors.white, size: 16)
                  : Text(
                '$index',
                style: const TextStyle(
                  fontSize:   11,
                  fontWeight: FontWeight.bold,
                  color:      AppTheme.primaryBlue,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                skill,
                style: TextStyle(
                  fontSize:   14,
                  fontWeight: FontWeight.w500,
                  color: hasSkill ? AppTheme.accentGreen : text,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color:        Colors.grey.withAlpha(isDark ? 30 : 20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${(impScore * 100).round()}%',
                style: TextStyle(
                  fontSize:   10,
                  color:      _subColor(isDark),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: hasSkill
                    ? AppTheme.accentGreen.withAlpha(20)
                    : AppTheme.primaryBlue.withAlpha(14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                hasSkill ? '✓ You have this' : 'Learn →',
                style: TextStyle(
                  fontSize:   11,
                  color: hasSkill
                      ? AppTheme.accentGreen
                      : AppTheme.primaryBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// _TipCard
// ══════════════════════════════════════════════════════════

class _TipCard extends StatelessWidget {
  final String tip;
  const _TipCard({required this.tip});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.amber.withAlpha(14)
            : const Color(0xFFFFFBF0),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: Colors.amber.withAlpha(isDark ? 60 : 120)),
        boxShadow: isDark
            ? const []
            : [
          BoxShadow(
            color:      Colors.amber.withAlpha(22),
            blurRadius: 12,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width:  46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.amber.withAlpha(60),
                  Colors.orange.withAlpha(40),
                ],
                begin: Alignment.topLeft,
                end:   Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.amber.withAlpha(80)),
            ),
            child: const Icon(Icons.tips_and_updates_outlined,
                color: Colors.amber, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Expert Career Tip',
                  style: TextStyle(
                    fontWeight:    FontWeight.bold,
                    color:         Colors.amber,
                    fontSize:      13,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tip,
                  style: TextStyle(
                    fontSize: 13,
                    color:    _textColor(isDark),
                    height:   1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}