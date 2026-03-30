// screens/skill_gap.dart — SkillBridge AI
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  MAXIMUM UPGRADE: "Immersive Skill Gap Analyzer"                        ║
// ║  • Gradient readiness ring via CustomPainter with glow layer            ║
// ║  • Glassmorphism cards with per-section accent colour gradient edge     ║
// ║  • Gradient-fill progress bars with box-shadow glow                     ║
// ║  • Staggered flutter_animate entrance effects on every section          ║
// ║  • Animated quiz dialog with slide question transitions                 ║
// ║  • Shimmer roadmap connector with step-glow circles                     ║
// ║  • Richer SliverAppBar with stats row in expanded space                 ║
// ║  • Full dark/light adaptive palette                                     ║
// ║  ⚠️  ALL ML calls, filtering logic, Provider reads, state logic: 100%   ║
// ║     UNCHANGED                                                           ║
// ╚══════════════════════════════════════════════════════════════════════════╝

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:skillbridge_ai/screens/learning.dart';
import '../main.dart';
import '../ml/recommender.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';

// ─── Helpers (UNCHANGED) ─────────────────────────────────────────────────────

Color _scoreColor(double score) {
  if (score >= 0.75) return AppTheme.accentGreen;
  if (score >= 0.45) return Colors.orange.shade700;
  return Colors.red.shade600;
}

String _scoreTip(double score) {
  if (score >= 0.80) return 'You are highly competitive for this role. Apply now!';
  if (score >= 0.65) return 'Strong candidate. A few more skills will seal the deal.';
  if (score >= 0.45) return 'Worth applying while learning the missing skills.';
  return 'Focus on learning the missing skills before applying.';
}

// ─── [Element B] Transition difficulty calculation (UNCHANGED) ────────────────

enum _TransitionDifficulty { easy, medium, hard }

_TransitionDifficulty _calcDifficulty(int missingCount, double simScore) {
  if (missingCount <= 2 && simScore >= 0.7) return _TransitionDifficulty.easy;
  if (missingCount <= 5 && simScore >= 0.45) return _TransitionDifficulty.medium;
  return _TransitionDifficulty.hard;
}

Color _difficultyColor(_TransitionDifficulty d) {
  switch (d) {
    case _TransitionDifficulty.easy:   return AppTheme.accentGreen;
    case _TransitionDifficulty.medium: return Colors.orange.shade700;
    case _TransitionDifficulty.hard:   return Colors.red.shade600;
  }
}

IconData _difficultyIcon(_TransitionDifficulty d) {
  switch (d) {
    case _TransitionDifficulty.easy:   return Icons.sentiment_very_satisfied_rounded;
    case _TransitionDifficulty.medium: return Icons.sentiment_neutral_rounded;
    case _TransitionDifficulty.hard:   return Icons.sentiment_dissatisfied_rounded;
  }
}

String _difficultyLabel(_TransitionDifficulty d) {
  switch (d) {
    case _TransitionDifficulty.easy:   return 'Easy Transition';
    case _TransitionDifficulty.medium: return 'Medium Transition';
    case _TransitionDifficulty.hard:   return 'Hard Transition';
  }
}

String _timeEstimate(int missingCount) {
  if (missingCount == 0)  return 'Ready to apply now';
  if (missingCount <= 2)  return '~1–2 months';
  if (missingCount <= 4)  return '~2–4 months';
  if (missingCount <= 7)  return '~3–6 months';
  return '~6–12 months';
}

// ─── [Element A] PrioritizedSkill local model (UNCHANGED) ─────────────────────

enum _SkillPriorityLabel { learnFirst, learnSoon, optional, alreadyHave }

class _PriorizedSkillData {
  final String              skillName;
  final double              importanceScore;
  final double              distanceScore;
  final double              acquisitionScore;
  final _SkillPriorityLabel priorityLabel;
  final String              reasoning;

  const _PriorizedSkillData({
    required this.skillName,
    required this.importanceScore,
    required this.distanceScore,
    required this.acquisitionScore,
    required this.priorityLabel,
    required this.reasoning,
  });
}

// ─── SkillPrioritizer (UNCHANGED) ─────────────────────────────────────────────

class _SkillPrioritizer {
  static List<_PriorizedSkillData> prioritise(
      JobRecommendation job,
      List<String>      userSkills,
      ) {
    final missing  = job.missing;
    final matching = job.matching;
    final results  = <_PriorizedSkillData>[];

    for (var i = 0; i < missing.length; i++) {
      final skill       = missing[i];
      final normalised  = i / missing.length.clamp(1, 999);
      final importance  = (1.0 - normalised * 0.6).clamp(0.3, 1.0);
      final distance    = (0.4 + normalised * 0.5).clamp(0.1, 0.9);
      final acquisition = (0.8 - normalised * 0.4).clamp(0.2, 0.9);
      final similarToOwned = _hasSimilarSkill(skill, userSkills);
      final label = i < 3
          ? _SkillPriorityLabel.learnFirst
          : (i < 6 ? _SkillPriorityLabel.learnSoon : _SkillPriorityLabel.optional);

      results.add(_PriorizedSkillData(
        skillName:        skill,
        importanceScore:  importance,
        distanceScore:    distance,
        acquisitionScore: acquisition,
        priorityLabel:    label,
        reasoning:        _buildReasoning(skill, job.title, similarToOwned, label, i),
      ));
    }

    for (final skill in matching) {
      results.add(_PriorizedSkillData(
        skillName:        skill,
        importanceScore:  0.8,
        distanceScore:    0.0,
        acquisitionScore: 1.0,
        priorityLabel:    _SkillPriorityLabel.alreadyHave,
        reasoning:        'You already have this skill. Great asset for the role.',
      ));
    }
    return results;
  }

  static List<String> generateLearningRoadmap(
      JobRecommendation job,
      List<String>      userSkills,
      ) {
    final all = prioritise(job, userSkills)
        .where((p) => p.priorityLabel != _SkillPriorityLabel.alreadyHave)
        .toList();
    all.sort((a, b) {
      final labelOrder = {
        _SkillPriorityLabel.learnFirst: 0,
        _SkillPriorityLabel.learnSoon:  1,
        _SkillPriorityLabel.optional:   2,
      };
      final lo = labelOrder[a.priorityLabel]!
          .compareTo(labelOrder[b.priorityLabel]!);
      if (lo != 0) return lo;
      return b.importanceScore.compareTo(a.importanceScore);
    });
    return all.map((p) => p.skillName).toList();
  }

  static bool _hasSimilarSkill(String target, List<String> owned) {
    final t = target.toLowerCase();
    return owned.any((s) {
      final o = s.toLowerCase();
      return t.contains(o) || o.contains(t) || _sharedPrefix(t, o, 4);
    });
  }

  static bool _sharedPrefix(String a, String b, int len) {
    if (a.length < len || b.length < len) return false;
    return a.substring(0, len) == b.substring(0, len);
  }

  static String _buildReasoning(
      String              skill,
      String              jobTitle,
      bool                bridgesFromOwned,
      _SkillPriorityLabel label,
      int                 rank,
      ) {
    final base = label == _SkillPriorityLabel.learnFirst
        ? 'High-importance skill for $jobTitle.'
        : (label == _SkillPriorityLabel.learnSoon
        ? 'Valued skill for $jobTitle; learn after top priorities.'
        : 'Nice-to-have for $jobTitle; build after core gaps are closed.');
    final bridge = bridgesFromOwned
        ? ' Bridges well with skills you already have.'
        : '';
    return '$base$bridge';
  }
}

// ─── Topic derivation (UNCHANGED) ────────────────────────────────────────────

List<String> _topicsForSkill(String skill) {
  final s = skill.toLowerCase().trim();
  const topicMap = <String, List<String>>{
    'python':             ['Python Basics', 'Functions & OOP', 'Libraries & APIs'],
    'sql':                ['SQL Fundamentals', 'Joins & Subqueries', 'Query Optimisation'],
    'excel':              ['Spreadsheet Basics', 'Formulas & Pivot Tables', 'Data Visualisation'],
    'javascript':         ['JS Fundamentals', 'DOM & Events', 'Async & APIs'],
    'react':              ['React Basics', 'Hooks & State', 'Component Patterns'],
    'dart':               ['Dart Language', 'OOP in Dart', 'Async Dart'],
    'flutter':            ['Flutter Basics', 'Widgets & Layouts', 'State Management'],
    'machine learning':   ['ML Foundations', 'Supervised Learning', 'Model Evaluation'],
    'deep learning':      ['Neural Networks', 'CNNs & RNNs', 'Training Strategies'],
    'data analysis':      ['Data Cleaning', 'Exploratory Analysis', 'Statistical Testing'],
    'tableau':            ['Tableau Desktop', 'Dashboard Design', 'Data Connections'],
    'power bi':           ['Power BI Basics', 'DAX Formulas', 'Report Publishing'],
    'docker':             ['Containerisation', 'Dockerfile', 'Docker Compose'],
    'kubernetes':         ['K8s Architecture', 'Pods & Services', 'Deployments'],
    'aws':                ['Cloud Fundamentals', 'EC2 & S3', 'IAM & Security'],
    'gcp':                ['GCP Overview', 'Compute & Storage', 'GCP Security'],
    'azure':              ['Azure Basics', 'Virtual Machines', 'Azure DevOps'],
    'git':                ['Git Basics', 'Branching & Merging', 'CI/CD Workflows'],
    'typescript':         ['TypeScript Basics', 'Types & Interfaces', 'Generics'],
    'communication':      ['Written Communication', 'Presentations', 'Active Listening'],
    'project management': ['PM Fundamentals', 'Agile & Scrum', 'Risk Management'],
    'agile':              ['Agile Manifesto', 'Sprint Planning', 'Retrospectives'],
    'financial modeling': ['Spreadsheet Models', 'DCF Analysis', 'Scenario Planning'],
    'risk analysis':      ['Risk Identification', 'Quantitative Risk', 'Mitigation'],
  };
  if (topicMap.containsKey(s)) return topicMap[s]!;
  for (final key in topicMap.keys) {
    if (s.contains(key) || key.contains(s)) return topicMap[key]!;
  }
  final cap =
  skill.isEmpty ? 'Skill' : skill[0].toUpperCase() + skill.substring(1);
  return ['$cap Fundamentals', '$cap Intermediate', '$cap Advanced'];
}

// ─── MCQ question bank (UNCHANGED) ───────────────────────────────────────────

const _topicQuestions = <String, List<Map<String, Object>>>{
  'Python Basics': [
    {'question': 'Which keyword is used to define a function in Python?', 'options': ['func', 'def', 'function', 'define'], 'correctIndex': 1},
    {'question': 'What data type does `type([])` return?', 'options': ['tuple', 'dict', 'list', 'set'], 'correctIndex': 2},
    {'question': 'Which operator is used for floor division in Python?', 'options': ['/', '//', '%', '**'], 'correctIndex': 1},
  ],
  'Functions & OOP': [
    {'question': 'Which method is automatically called when a Python object is created?', 'options': ['__new__', '__create__', '__init__', '__start__'], 'correctIndex': 2},
    {'question': 'What does `*args` allow in a function definition?', 'options': ['Keyword arguments only', 'A fixed number of arguments', 'Any number of positional arguments', 'No arguments'], 'correctIndex': 2},
    {'question': 'Which OOP principle hides internal state from outside access?', 'options': ['Inheritance', 'Polymorphism', 'Encapsulation', 'Abstraction'], 'correctIndex': 2},
  ],
  'Libraries & APIs': [
    {'question': 'Which Python library is most commonly used for HTTP requests?', 'options': ['http', 'requests', 'urllib2', 'fetch'], 'correctIndex': 1},
    {'question': 'What does `import numpy as np` achieve?', 'options': ['Installs numpy', 'Imports numpy with alias np', 'Creates a new module', 'Exports a function'], 'correctIndex': 1},
    {'question': 'Which format is most commonly used for REST API responses?', 'options': ['XML', 'CSV', 'JSON', 'YAML'], 'correctIndex': 2},
  ],
  'SQL Fundamentals': [
    {'question': 'Which SQL clause filters rows after grouping?', 'options': ['WHERE', 'HAVING', 'FILTER', 'GROUP BY'], 'correctIndex': 1},
    {'question': 'What does SELECT DISTINCT do?', 'options': ['Selects all rows', 'Removes duplicate rows from the result', 'Orders rows alphabetically', 'Filters NULL values'], 'correctIndex': 1},
    {'question': 'Which constraint ensures a column has no duplicate values?', 'options': ['PRIMARY KEY', 'FOREIGN KEY', 'UNIQUE', 'NOT NULL'], 'correctIndex': 2},
  ],
  'Joins & Subqueries': [
    {'question': 'Which JOIN returns all rows from both tables, filling NULLs where unmatched?', 'options': ['INNER JOIN', 'LEFT JOIN', 'FULL OUTER JOIN', 'CROSS JOIN'], 'correctIndex': 2},
    {'question': 'A correlated subquery differs from a regular subquery because it:', 'options': ['Returns multiple columns', 'References the outer query', 'Uses GROUP BY', 'Cannot use WHERE'], 'correctIndex': 1},
    {'question': 'Which keyword combines two SELECT results and removes duplicates?', 'options': ['INTERSECT', 'EXCEPT', 'UNION', 'MERGE'], 'correctIndex': 2},
  ],
  'Flutter Basics': [
    {'question': 'What is the root widget that most Flutter apps use?', 'options': ['Scaffold', 'MaterialApp', 'Container', 'Widget'], 'correctIndex': 1},
    {'question': 'Which widget is used for a scrollable list of items?', 'options': ['Column', 'Row', 'ListView', 'Stack'], 'correctIndex': 2},
    {'question': 'What does `hot reload` do in Flutter?', 'options': ['Restarts the entire app', 'Injects updated source code without losing state', 'Clears the build cache', 'Runs unit tests'], 'correctIndex': 1},
  ],
  'Widgets & Layouts': [
    {'question': 'Which widget positions children along the vertical axis?', 'options': ['Row', 'Stack', 'Column', 'Flex'], 'correctIndex': 2},
    {'question': 'What does `Expanded` do inside a Row or Column?', 'options': ['Adds padding around a widget', 'Makes a widget fill the remaining space', 'Centres a widget', 'Sets a fixed size'], 'correctIndex': 1},
    {'question': 'Which widget clips its child to a rounded rectangle?', 'options': ['ClipOval', 'ClipRect', 'ClipRRect', 'ClipPath'], 'correctIndex': 2},
  ],
  'State Management': [
    {'question': 'Which package is used for the Provider state management pattern?', 'options': ['bloc', 'riverpod', 'provider', 'redux'], 'correctIndex': 2},
    {'question': 'In the BLoC pattern, what does BLoC stand for?', 'options': ['Build, Layout, Output, Component', 'Business Logic Component', 'Basic Logic Observer Class', 'Bloc Layout Object Container'], 'correctIndex': 1},
    {'question': 'Which method must be called after changing state in a StatefulWidget?', 'options': ['build()', 'update()', 'setState()', 'refresh()'], 'correctIndex': 2},
  ],
  'ML Foundations': [
    {'question': 'Which type of learning uses labelled training data?', 'options': ['Unsupervised', 'Reinforcement', 'Supervised', 'Self-supervised'], 'correctIndex': 2},
    {'question': 'What is overfitting?', 'options': ['A model performs well on training data but poorly on new data', 'A model is too simple to learn patterns', 'A model is trained for too few epochs', 'A model uses too little data'], 'correctIndex': 0},
    {'question': 'Which technique splits data to estimate model generalisation?', 'options': ['Normalisation', 'Cross-validation', 'Regularisation', 'Bootstrapping'], 'correctIndex': 1},
  ],
  'Agile & Scrum': [
    {'question': 'How long is a typical Scrum sprint?', 'options': ['1 day', '1–4 weeks', '3 months', '6 months'], 'correctIndex': 1},
    {'question': 'Who is responsible for maximising the value of the product in Scrum?', 'options': ['Scrum Master', 'Development Team', 'Product Owner', 'Stakeholder'], 'correctIndex': 2},
    {'question': "What is the purpose of a Sprint Retrospective?", 'options': ['To plan the next sprint backlog', 'To demo the increment to stakeholders', "To inspect and adapt the team's process", 'To review acceptance criteria'], 'correctIndex': 2},
  ],
};

List<_QuizQuestion> _questionsForTopic(String topic) {
  if (_topicQuestions.containsKey(topic)) {
    return _topicQuestions[topic]!
        .map((q) => _QuizQuestion(
      question:     q['question']! as String,
      options:      List<String>.from(q['options']! as List),
      correctIndex: q['correctIndex']! as int,
    ))
        .toList();
  }
  final lower = topic.toLowerCase();
  for (final key in _topicQuestions.keys) {
    if (key.toLowerCase().contains(lower) ||
        lower.contains(key.toLowerCase())) {
      return _topicQuestions[key]!
          .map((q) => _QuizQuestion(
        question:     q['question']! as String,
        options:      List<String>.from(q['options']! as List),
        correctIndex: q['correctIndex']! as int,
      ))
          .toList();
    }
  }
  return [
    _QuizQuestion(
      question:     'What is the primary goal of $topic?',
      options:      ['To write documentation', 'To solve domain-specific problems effectively', 'To design user interfaces', 'To manage project timelines'],
      correctIndex: 1,
    ),
    _QuizQuestion(
      question:     'Which approach is considered a best practice in $topic?',
      options:      ['Skipping version control', 'Avoiding code review', 'Iterative development and testing', 'Ignoring user feedback'],
      correctIndex: 2,
    ),
    _QuizQuestion(
      question:     'When applying $topic, what should be prioritised first?',
      options:      ['Speed over correctness', 'Understanding the problem domain', 'Choosing the latest tools', 'Writing the most complex solution'],
      correctIndex: 1,
    ),
  ];
}

class _QuizQuestion {
  final String       question;
  final List<String> options;
  final int          correctIndex;
  const _QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Design System — Upgraded palette & shared helpers
// ─────────────────────────────────────────────────────────────────────────────

class _P {
  // Blues
  static const blue500 = Color(0xFF3B82F6);
  static const blue600 = Color(0xFF2563EB);
  static const blue700 = Color(0xFF1D4ED8);
  // Greens
  static const green500 = Color(0xFF22C55E);
  // Reds
  static const red500   = Color(0xFFEF4444);
  // Violet
  static const violet500 = Color(0xFF8B5CF6);
  // Slate (dark mode)
  static const slate900 = Color(0xFF0F172A);
  static const slate800 = Color(0xFF1E293B);
  static const slate700 = Color(0xFF334155);
  static const slate600 = Color(0xFF475569);
  static const slate500 = Color(0xFF64748B);
  static const slate400 = Color(0xFF94A3B8);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate50  = Color(0xFFF8FAFC);
}

// ── Adaptive colour helpers ───────────────────────────────────────────────────
Color _bgC(bool d)     => d ? _P.slate900  : Colors.white;
Color _cardC(bool d)   => d ? _P.slate800  : Colors.white;
Color _borderC(bool d) => d ? _P.slate700  : _P.slate200;
Color _textC(bool d)   => d ? Colors.white : _P.slate900;
Color _subC(bool d)    => d ? _P.slate400  : _P.slate500;

// ── Upgraded section header ───────────────────────────────────────────────────
Widget _sectionHeader(String title, {Color color = AppTheme.primaryBlue}) =>
    Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          Container(
            width:  4,
            height: 22,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.3)],
                begin:  Alignment.topCenter,
                end:    Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color:      color.withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset:     const Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize:   15,
              fontWeight: FontWeight.w800,
              color:      color,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );

// ── Outline action button ─────────────────────────────────────────────────────
Widget _outlineBtnW(String label, VoidCallback? onTap,
    {Color? color, Color? textColor}) {
  final c  = color ?? AppTheme.primaryBlue;
  final tc = textColor ?? c;
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.6), width: 1.5),
        color: c.withValues(alpha: 0.05),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color:      tc,
            fontSize:   13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared visual components
// ─────────────────────────────────────────────────────────────────────────────

/// Glassmorphism-style card with a coloured top-edge gradient accent line.
class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    required this.isDark,
    this.accentColor = AppTheme.primaryBlue,
    this.padding     = const EdgeInsets.all(16),
  });

  final Widget     child;
  final bool       isDark;
  final Color      accentColor;
  final EdgeInsets padding;

  static const double _kRadius = 18.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:         isDark ? _P.slate800 : Colors.white,
        borderRadius:  BorderRadius.circular(_kRadius),
        border: Border.all(
          color: isDark
              ? _P.slate700.withValues(alpha: 0.5)
              : _P.slate200,
        ),
        boxShadow: [
          BoxShadow(
            color:       Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius:  18,
            spreadRadius: -2,
            offset:      const Offset(0, 5),
          ),
          BoxShadow(
            color:       accentColor.withValues(alpha: isDark ? 0.07 : 0.04),
            blurRadius:  22,
            offset:      const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_kRadius),
        child: Stack(
          children: [
            // Top accent gradient line
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                height: 2.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.0),
                      accentColor.withValues(alpha: 0.85),
                      accentColor.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

/// Animated gradient progress bar (replaces LinearProgressIndicator).
class _AnimGradBar extends StatelessWidget {
  const _AnimGradBar({
    required this.value,
    required this.colors,
    this.height   = 8.0,
    this.isDark   = false,
    this.duration = const Duration(milliseconds: 900),
  });

  final double      value;     // target 0..1
  final List<Color> colors;
  final double      height;
  final bool        isDark;
  final Duration    duration;

  static const Curve _kCurve = Curves.easeOut;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween:    Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: duration,
      curve:    _kCurve,
      builder: (_, val, __) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: Stack(
            children: [
              Container(
                height: height,
                color: isDark ? _P.slate700 : _P.slate100,
              ),
              FractionallySizedBox(
                widthFactor: val,
                child: Container(
                  height: height,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: colors),
                    borderRadius: BorderRadius.circular(height / 2),
                    boxShadow: [
                      BoxShadow(
                        color:      colors.last.withValues(alpha: 0.35),
                        blurRadius: 6,
                        offset:     const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Readiness Ring — CustomPainter gradient glow arc
// ─────────────────────────────────────────────────────────────────────────────

class _ReadinessRing extends StatelessWidget {
  const _ReadinessRing({
    required this.progress,
    required this.percentage,
  });

  final double progress;   // 0..1 (animated)
  final int    percentage;

  static const double _kSize = 104.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width:  _kSize,
      height: _kSize,
      child: CustomPaint(
        painter: _RingPainter(progress: progress),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$percentage%',
                style: const TextStyle(
                  color:      Colors.white,
                  fontSize:   23,
                  fontWeight: FontWeight.w900,
                  height:     1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Ready',
                style: TextStyle(
                  color:      Colors.white.withValues(alpha: 0.65),
                  fontSize:   11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center      = Offset(size.width / 2, size.height / 2);
    final radius      = (size.width - 16) / 2;
    final rect        = Rect.fromCircle(center: center, radius: radius);
    const startAngle  = -math.pi / 2;
    final sweepAngle  = 2 * math.pi * progress.clamp(0.0, 1.0);

    // ── Background track ──
    canvas.drawArc(
      rect, 0, 2 * math.pi, false,
      Paint()
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 9
        ..color       = Colors.white.withValues(alpha: 0.15),
    );

    if (progress <= 0) return;

    // ── Glow layer ──
    canvas.drawArc(
      rect, startAngle, sweepAngle, false,
      Paint()
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 16
        ..strokeCap   = StrokeCap.round
        ..color       = Colors.white.withValues(alpha: 0.18)
        ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // ── Main arc (solid white) ──
    canvas.drawArc(
      rect, startAngle, sweepAngle, false,
      Paint()
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap   = StrokeCap.round
        ..color       = Colors.white,
    );

    // ── End-cap dot ──
    final endAngle = startAngle + sweepAngle;
    final dotPos   = center + Offset(
      math.cos(endAngle) * radius,
      math.sin(endAngle) * radius,
    );
    canvas.drawCircle(
      dotPos, 5,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class SkillGapScreen extends StatefulWidget {
  final JobRecommendation job;
  final List<String>      userSkills;

  const SkillGapScreen({
    super.key,
    required this.job,
    required this.userSkills,
  });

  @override
  State<SkillGapScreen> createState() => _SkillGapScreenState();
}

class _SkillGapScreenState extends State<SkillGapScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ringCtrl;
  late final Animation<double>   _ringAnim;
  late final Animation<double>   _fadeAnim;

  late final List<_PriorizedSkillData> _prioritised;
  late final List<String>              _roadmap;

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
    _ringAnim = CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOut);
    _fadeAnim = CurvedAnimation(parent: _ringCtrl, curve: Curves.easeIn);

    _prioritised = _SkillPrioritizer.prioritise(widget.job, widget.userSkills);
    _roadmap     = _SkillPrioritizer.generateLearningRoadmap(
        widget.job, widget.userSkills);
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    super.dispose();
  }

  void _shareJob() {
    final job  = widget.job;
    final text = '🎯 ${job.title} at ${job.company}\n'
        '📍 ${job.location} | ${job.formattedSalary}\n'
        '📊 Match: ${job.matchPercent}\n'
        'Found via SkillBridge AI';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(children: [
          Icon(Icons.copy_rounded, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text('Job details copied to clipboard!'),
        ]),
        duration:         const Duration(seconds: 2),
        backgroundColor:  _P.blue600,
        behavior:         SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin:           const EdgeInsets.all(16),
      ),
    );
  }

  void _navigateToLearning({List<String>? skills}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LearningScreen(
          missingSkills: skills ?? widget.job.missing,
          industry:      widget.job.industry,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final job         = widget.job;
    final totalSkills = job.matching.length + job.missing.length;
    final matchPct    = totalSkills > 0
        ? (job.matching.length / totalSkills * 100).round()
        : 0;
    final score      = job.score;
    final sColor     = _scoreColor(score);
    final simScore   = job.simScore;
    final difficulty = _calcDifficulty(job.missing.length, simScore);

    final strengths = _prioritised
        .where((p) =>
    p.priorityLabel == _SkillPriorityLabel.alreadyHave &&
        p.importanceScore >= 0.65)
        .toList();

    final missingPrioritised = _prioritised
        .where((p) => p.priorityLabel != _SkillPriorityLabel.alreadyHave)
        .toList();

    return Scaffold(
      backgroundColor: _bgC(isDark),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [

            // ── Upgraded SliverAppBar ──────────────────────────────────
            SliverAppBar(
              pinned:           true,
              expandedHeight:   190,
              backgroundColor:  AppTheme.primaryBlue,
              surfaceTintColor: Colors.transparent,
              systemOverlayStyle: SystemUiOverlayStyle.light,
              leading: IconButton(
                icon:    const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                Consumer<AppState>(
                  builder: (_, appState, __) {
                    final saved = appState.isJobSaved(job.id);
                    return IconButton(
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          key:   ValueKey(saved),
                          saved ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: saved ? Colors.amber : Colors.white,
                        ),
                      ),
                      tooltip:   saved ? 'Unsave job' : 'Save job',
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        appState.toggleSaveJob(job.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(saved
                                ? 'Removed from saved.'
                                : '${job.title} saved! ❤️'),
                            duration:        const Duration(seconds: 2),
                            behavior:        SnackBarBehavior.floating,
                            backgroundColor: saved ? _P.slate600 : _P.blue600,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            margin: const EdgeInsets.all(16),
                          ),
                        );
                      },
                    );
                  },
                ),
                IconButton(
                  icon:      const Icon(Icons.share_outlined, color: Colors.white),
                  tooltip:   'Copy job details',
                  onPressed: _shareJob,
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin:  Alignment.topLeft,
                      end:    Alignment.bottomRight,
                      colors: [AppTheme.primaryBlue, Color(0xFF7C3AED)],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 52, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment:  MainAxisAlignment.end,
                        children: [
                          // Section label
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color:        Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.analytics_rounded,
                                    color: Colors.white, size: 12),
                                SizedBox(width: 5),
                                Text('Skill Gap Analysis',
                                    style: TextStyle(
                                      color:      Colors.white,
                                      fontSize:   11,
                                      fontWeight: FontWeight.w600,
                                    )),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            job.title,
                            style: const TextStyle(
                              color:      Colors.white,
                              fontSize:   20,
                              fontWeight: FontWeight.w800,
                              height:     1.2,
                            ),
                            maxLines:  2,
                            overflow:  TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            job.company,
                            style: TextStyle(
                              color:    Colors.white.withValues(alpha: 0.75),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Stats pills row
                          Row(
                            children: [
                              _AppBarPill(
                                icon:  Icons.check_circle_rounded,
                                label: '${job.matching.length} matched',
                                color: _P.green500,
                              ),
                              const SizedBox(width: 8),
                              _AppBarPill(
                                icon:  Icons.school_rounded,
                                label: '${job.missing.length} to learn',
                                color: Colors.orange.shade400,
                              ),
                              const SizedBox(width: 8),
                              _AppBarPill(
                                icon:  Icons.bar_chart_rounded,
                                label: '${(score * 100).round()}% match',
                                color: sColor,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                collapseMode: CollapseMode.parallax,
              ),
              title: Text(
                job.title,
                style: const TextStyle(
                  color:      Colors.white,
                  fontSize:   16,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // ── Hero Summary Card ──────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: _HeroSummaryCard(
                  readiness:  matchPct,
                  matched:    job.matching.length,
                  missing:    job.missing.length,
                  jobMatch:   (score * 100).round(),
                  careerGoal: '${job.title} @ ${job.company}',
                  ringAnim:   _ringAnim,
                ),
              ),
            ),

            // ── Transition Difficulty Banner ───────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _TransitionDifficultyBanner(
                  job:        job,
                  difficulty: difficulty,
                  simScore:   simScore,
                  isDark:     isDark,
                ),
              ),
            ),

            // ── AI Tip Banner ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _TipBanner(
                    score: score, sColor: sColor, isDark: isDark),
              ),
            ),

            // ── Skill Gap Bar ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _SkillGapBar(
                  matched: job.matching.length,
                  total:   totalSkills,
                  sColor:  sColor,
                  isDark:  isDark,
                ),
              ),
            ),

            // ── Job Details Card ───────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _DetailsCard(job: job, isDark: isDark),
              ),
            ),

            // ── Gap Distance Indicator ─────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _GapDistanceIndicator(
                  matched:  job.matching.length,
                  total:    totalSkills,
                  simScore: simScore,
                  isDark:   isDark,
                ),
              ),
            ),

            // ── Strengths ──────────────────────────────────────────────
            if (strengths.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 24, 0, 0),
                  child: _sectionHeader('Your Strengths ✅',
                      color: AppTheme.accentGreen),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: _StrengthsSection(
                      strengths: strengths, isDark: isDark),
                ),
              ),
            ],

            // ── Skills to Learn ────────────────────────────────────────
            if (missingPrioritised.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 24, 0, 4),
                  child: _sectionHeader(
                    'Skills to Learn (${missingPrioritised.length})',
                    color: Colors.red.shade600,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (_, i) => _PrioritySkillCard(
                      item:          missingPrioritised[i],
                      rank:          i + 1,
                      isDark:        isDark,
                      delay:         Duration(milliseconds: i * 60),
                      onFindCourses: () => _navigateToLearning(
                          skills: [missingPrioritised[i].skillName]),
                    ),
                    childCount: missingPrioritised.length,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: _GradientButton(
                    icon:    Icons.school_outlined,
                    label:   'Learn ${job.missing.length} Missing '
                        'Skill${job.missing.length == 1 ? '' : 's'}',
                    colors:  const [_P.blue500, _P.violet500],
                    onTap:   () => _navigateToLearning(),
                  ),
                ),
              ),
            ] else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _PerfectMatchCard(isDark: isDark),
                ),
              ),
            ],

            // ── Matched Skills ─────────────────────────────────────────
            if (job.matching.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 24, 0, 4),
                  child: _sectionHeader(
                    '✅ Skills You Have (${job.matching.length})',
                    color: AppTheme.accentGreen,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _AnimatedSkillChips(
                    skills:   job.matching,
                    color:    AppTheme.accentGreen,
                    listAnim: _ringAnim,
                  ),
                ),
              ),
            ],

            // ── Topic Breakdowns ───────────────────────────────────────
            if (job.missing.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 24, 0, 4),
                  child: _sectionHeader('📚 Topic Breakdown per Skill'),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    'Expand each skill to see learning topics and take mini quizzes.',
                    style: TextStyle(
                      fontSize: 12,
                      color:    isDark ? _P.slate400 : _P.slate500,
                      height:   1.5,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (_, i) => _SkillGapTile(
                      skill:      job.missing[i],
                      rank:       i + 1,
                      isPriority: i < 3,
                      isDark:     isDark,
                    ),
                    childCount: job.missing.length,
                  ),
                ),
              ),
            ],

            // ── Learning Roadmap ───────────────────────────────────────
            if (_roadmap.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 24, 0, 4),
                  child: _sectionHeader('🗺️ Your Learning Roadmap',
                      color: AppTheme.accentTeal),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (_, i) {
                      final hue = (190.0 - i * 18.0).clamp(0.0, 360.0);
                      final stepColor =
                      HSLColor.fromAHSL(1.0, hue, 0.6, 0.45).toColor();
                      return _RoadmapStepTile(
                        step:      i + 1,
                        total:     _roadmap.length,
                        skill:     _roadmap[i],
                        stepColor: stepColor,
                        isDark:    isDark,
                        isLast:    i == _roadmap.length - 1,
                        delay:     Duration(milliseconds: i * 55),
                        onTap:     () =>
                            _navigateToLearning(skills: [_roadmap[i]]),
                      );
                    },
                    childCount: _roadmap.length,
                  ),
                ),
              ),
            ],

            // ── Bottom CTA ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _BottomCtaBanner(
                  onBrowse: () => _navigateToLearning(),
                ).animate().fadeIn(delay: 300.ms, duration: 500.ms)
                    .slideY(begin: 0.06, end: 0),
              ),
            ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
          ],
        ),
      ),
    );
  }
}

// ─── AppBar stats pill ────────────────────────────────────────────────────────

class _AppBarPill extends StatelessWidget {
  const _AppBarPill({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String   label;
  final Color    color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color:        Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color:      Colors.white,
              fontSize:   11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Gradient CTA button ──────────────────────────────────────────────────────

class _GradientButton extends StatefulWidget {
  const _GradientButton({
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
  });

  final IconData       icon;
  final String         label;
  final List<Color>    colors;
  final VoidCallback   onTap;

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
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
    return GestureDetector(
      onTap: _tap,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.colors,
              begin:  Alignment.topLeft,
              end:    Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color:      widget.colors.first.withValues(alpha: 0.4),
                blurRadius: 14,
                offset:     const Offset(0, 5),
              ),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: const TextStyle(
                    color:      Colors.white,
                    fontSize:   14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
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

// ─── Hero Summary Card ────────────────────────────────────────────────────────

class _HeroSummaryCard extends StatelessWidget {
  final int               readiness;
  final int               matched;
  final int               missing;
  final int               jobMatch;
  final String            careerGoal;
  final Animation<double> ringAnim;

  const _HeroSummaryCard({
    required this.readiness,
    required this.matched,
    required this.missing,
    required this.jobMatch,
    required this.careerGoal,
    required this.ringAnim,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors:  [AppTheme.primaryBlue, Color(0xFF3B82F6)],
          begin:   Alignment.topLeft,
          end:     Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color:      AppTheme.primaryBlue.withValues(alpha: 0.4),
            blurRadius: 24,
            offset:     const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Gradient ring
          AnimatedBuilder(
            animation: ringAnim,
            builder: (_, __) => _ReadinessRing(
              progress:   (readiness / 100) * ringAnim.value,
              percentage: readiness,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeroMetricRow(
                  icon:  Icons.check_circle_rounded,
                  label: '$matched skills matched',
                  bold:  true,
                ),
                const SizedBox(height: 7),
                _HeroMetricRow(
                  icon:    Icons.radio_button_unchecked_rounded,
                  label:   '$missing skills missing',
                  opacity: 0.7,
                ),
                const SizedBox(height: 7),
                _HeroMetricRow(
                  icon:  Icons.auto_graph_rounded,
                  label: '$jobMatch% job match',
                  bold:  true,
                ),
                const SizedBox(height: 14),
                // Career goal pill
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color:        Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'Dream Job: $careerGoal',
                    style: const TextStyle(
                      color:      Colors.white,
                      fontSize:   11.5,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.06, end: 0);
  }
}

class _HeroMetricRow extends StatelessWidget {
  const _HeroMetricRow({
    required this.icon,
    required this.label,
    this.bold    = false,
    this.opacity = 1.0,
  });
  final IconData icon;
  final String   label;
  final bool     bold;
  final double   opacity;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon,
            color: Colors.white.withValues(alpha: opacity), size: 16),
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(
            color:      Colors.white.withValues(alpha: opacity),
            fontSize:   13.5,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// ─── Transition Difficulty Banner ─────────────────────────────────────────────

class _TransitionDifficultyBanner extends StatelessWidget {
  final JobRecommendation     job;
  final _TransitionDifficulty difficulty;
  final double                simScore;
  final bool                  isDark;

  const _TransitionDifficultyBanner({
    required this.job,
    required this.difficulty,
    required this.simScore,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final color   = _difficultyColor(difficulty);
    final icon    = _difficultyIcon(difficulty);
    final label   = _difficultyLabel(difficulty);
    final timeEst = _timeEstimate(job.missing.length);
    final simPct  = (simScore * 100).round();

    return _GlassCard(
      isDark:      isDark,
      accentColor: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:        color.withValues(alpha: 0.12),
                  shape:        BoxShape.circle,
                ),
                child: Icon(Icons.compare_arrows_rounded,
                    size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Career Transition Analysis',
                  style: TextStyle(
                    fontSize:   13,
                    fontWeight: FontWeight.w800,
                    color:      _textC(isDark),
                  ),
                ),
              ),
              // Difficulty badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.8)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color:      color.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset:     const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 13, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(label,
                        style: const TextStyle(
                          color:      Colors.white,
                          fontSize:   11,
                          fontWeight: FontWeight.w700,
                        )),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Target row
          Row(
            children: [
              Icon(Icons.work_outline_rounded,
                  size: 14, color: _subC(isDark)),
              const SizedBox(width: 6),
              Text('Targeting: ',
                  style: TextStyle(fontSize: 12, color: _subC(isDark))),
              Expanded(
                child: Text(
                  '${job.title} @ ${job.company}',
                  style: TextStyle(
                      fontSize:   12,
                      fontWeight: FontWeight.w700,
                      color:      _textC(isDark)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _BannerMetric(
                  icon:   Icons.auto_graph_rounded,
                  label:  'θ Similarity',
                  value:  '$simPct%',
                  color:  color,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BannerMetric(
                  icon:    Icons.schedule_rounded,
                  label:   'Time Estimate',
                  value:   timeEst,
                  color:   AppTheme.accentTeal,
                  isDark:  isDark,
                  compact: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _AnimGradBar(
            value:  simScore.clamp(0.0, 1.0),
            colors: [color.withValues(alpha: 0.7), color],
            height: 7,
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${job.missing.length} skills to bridge',
                style: TextStyle(
                  fontSize:   11,
                  color:      color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${job.matching.length} already matched',
                style: TextStyle(fontSize: 11, color: _subC(isDark)),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0);
  }
}

class _BannerMetric extends StatelessWidget {
  const _BannerMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
    this.compact = false,
  });

  final IconData icon;
  final String   label;
  final String   value;
  final Color    color;
  final bool     isDark;
  final bool     compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: isDark ? 0.1 : 0.06),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                    TextStyle(fontSize: 10, color: _subC(isDark))),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize:   compact ? 11 : 14,
                    color:      color,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Strengths Section ────────────────────────────────────────────────────────

class _StrengthsSection extends StatefulWidget {
  final List<_PriorizedSkillData> strengths;
  final bool                      isDark;

  const _StrengthsSection({
    required this.strengths,
    required this.isDark,
  });

  @override
  State<_StrengthsSection> createState() => _StrengthsSectionState();
}

class _StrengthsSectionState extends State<_StrengthsSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      isDark:      widget.isDark,
      accentColor: AppTheme.accentGreen,
      padding:     EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toggle header
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:  AppTheme.accentGreen.withValues(alpha: 0.12),
                      shape:  BoxShape.circle,
                    ),
                    child: const Icon(Icons.emoji_events_rounded,
                        size: 16, color: AppTheme.accentGreen),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your Strengths for This Role ✓',
                          style: TextStyle(
                            fontSize:   13,
                            fontWeight: FontWeight.w800,
                            color:      AppTheme.accentGreen,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'These skills make you a strong candidate',
                          style: TextStyle(
                              fontSize: 11, color: _subC(widget.isDark)),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns:    _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size:  18,
                        color: AppTheme.accentGreen),
                  ),
                ],
              ),
            ),
          ),

          // Expandable content
          AnimatedCrossFade(
            duration:       const Duration(milliseconds: 300),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild:  const SizedBox(height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: widget.strengths.asMap().entries.map((e) {
                  return _StrengthTile(
                    item:   e.value,
                    isDark: widget.isDark,
                  )
                      .animate(delay: Duration(milliseconds: e.key * 60))
                      .fadeIn(duration: 300.ms)
                      .slideX(begin: -0.05, end: 0);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StrengthTile extends StatelessWidget {
  final _PriorizedSkillData item;
  final bool                isDark;

  const _StrengthTile({required this.item, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color:        isDark ? _P.slate900 : _P.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppTheme.accentGreen.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.accentGreen, Color(0xFF16A34A)],
              ),
              shape:    BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded,
                size: 11, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.skillName,
                  style: TextStyle(
                    fontSize:   13,
                    fontWeight: FontWeight.w700,
                    color:      _textC(isDark),
                  ),
                ),
                const SizedBox(height: 3),
                Text(item.reasoning,
                    style: TextStyle(
                        fontSize: 11, color: _subC(isDark))),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 52,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${(item.importanceScore * 100).round()}%',
                  style: const TextStyle(
                    fontSize:   11,
                    color:      AppTheme.accentGreen,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                _AnimGradBar(
                  value:    item.importanceScore,
                  colors:   const [AppTheme.accentGreen, Color(0xFF16A34A)],
                  height:   4,
                  isDark:   isDark,
                  duration: const Duration(milliseconds: 600),
                ),
                const SizedBox(height: 2),
                Text('importance',
                    style: TextStyle(fontSize: 8, color: _subC(isDark))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Priority Skill Card ──────────────────────────────────────────────────────

class _PrioritySkillCard extends StatelessWidget {
  final _PriorizedSkillData item;
  final int                 rank;
  final bool                isDark;
  final Duration            delay;
  final VoidCallback        onFindCourses;

  const _PrioritySkillCard({
    required this.item,
    required this.rank,
    required this.isDark,
    required this.delay,
    required this.onFindCourses,
  });

  Color get _priorityColor {
    switch (item.priorityLabel) {
      case _SkillPriorityLabel.learnFirst:  return Colors.red.shade600;
      case _SkillPriorityLabel.learnSoon:   return Colors.orange.shade700;
      case _SkillPriorityLabel.optional:    return Colors.grey.shade600;
      case _SkillPriorityLabel.alreadyHave: return AppTheme.accentGreen;
    }
  }

  String get _priorityLabelText {
    switch (item.priorityLabel) {
      case _SkillPriorityLabel.learnFirst:  return 'Learn First';
      case _SkillPriorityLabel.learnSoon:   return 'Learn Soon';
      case _SkillPriorityLabel.optional:    return 'Optional';
      case _SkillPriorityLabel.alreadyHave: return 'Already Have';
    }
  }

  IconData get _priorityIcon {
    switch (item.priorityLabel) {
      case _SkillPriorityLabel.learnFirst:  return Icons.priority_high_rounded;
      case _SkillPriorityLabel.learnSoon:   return Icons.arrow_upward_rounded;
      case _SkillPriorityLabel.optional:    return Icons.add_circle_outline_rounded;
      case _SkillPriorityLabel.alreadyHave: return Icons.check_circle_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pColor = _priorityColor;

    return _GlassCard(
      isDark:      isDark,
      accentColor: pColor,
      padding:     const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: rank + name + badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gradient rank circle
              Container(
                width:  38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      pColor.withValues(alpha: 0.25),
                      pColor.withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topLeft,
                    end:   Alignment.bottomRight,
                  ),
                  shape:  BoxShape.circle,
                  border: Border.all(
                      color: pColor.withValues(alpha: 0.4), width: 1.5),
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      color:      pColor,
                      fontSize:   14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    item.skillName,
                    style: TextStyle(
                      fontSize:   15,
                      fontWeight: FontWeight.w800,
                      color:      _textC(isDark),
                    ),
                  ),
                ),
              ),
              // Priority badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color:        pColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                      color: pColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_priorityIcon, size: 11, color: pColor),
                    const SizedBox(width: 4),
                    Text(
                      _priorityLabelText,
                      style: TextStyle(
                        fontSize:   11,
                        color:      pColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Reasoning
          Text(
            item.reasoning,
            style: TextStyle(fontSize: 12.5, color: _subC(isDark), height: 1.45),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          // Importance bar
          _SingleBar(
            label:   'Importance',
            score:   item.importanceScore,
            colors:  const [_P.blue500, _P.blue700],
            isDark:  isDark,
            tooltip: 'How critical this skill is for the target role',
          ),
          const SizedBox(height: 8),
          // Distance bar
          _SingleBar(
            label:   'Distance',
            score:   item.distanceScore,
            colors:  [Colors.orange.shade400, Colors.orange.shade700],
            isDark:  isDark,
            tooltip: 'How far your current skills are from mastery',
          ),
          const SizedBox(height: 14),
          // Actions row
          Row(
            children: [
              Expanded(
                child: _outlineBtnW('Find Courses →', onFindCourses,
                    color: AppTheme.primaryBlue),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onFindCourses,
                child: Container(
                  width:  38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_P.blue500, _P.blue700],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color:      _P.blue500.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset:     const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    )
        .animate(delay: delay)
        .fadeIn(duration: 350.ms)
        .slideY(begin: 0.07, end: 0);
  }
}

class _SingleBar extends StatelessWidget {
  final String       label;
  final double       score;
  final List<Color>  colors;
  final bool         isDark;
  final String       tooltip;

  const _SingleBar({
    required this.label,
    required this.score,
    required this.colors,
    required this.isDark,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Row(
        children: [
          SizedBox(
            width: 74,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color:    isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ),
          Expanded(
            child: _AnimGradBar(
              value:  score.clamp(0.0, 1.0),
              colors: colors,
              height: 7,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: Text(
              '${(score * 100).round()}%',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize:   11,
                color:      colors.last,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Roadmap Step Tile ────────────────────────────────────────────────────────

class _RoadmapStepTile extends StatelessWidget {
  final int          step;
  final int          total;
  final String       skill;
  final Color        stepColor;
  final bool         isDark;
  final bool         isLast;
  final Duration     delay;
  final VoidCallback onTap;

  const _RoadmapStepTile({
    required this.step,
    required this.total,
    required this.skill,
    required this.stepColor,
    required this.isDark,
    required this.isLast,
    required this.delay,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline column
          SizedBox(
            width: 40,
            child: Column(
              children: [
                // Step circle with glow
                Container(
                  width:  32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        stepColor,
                        stepColor.withValues(alpha: 0.7),
                      ],
                      begin: Alignment.topLeft,
                      end:   Alignment.bottomRight,
                    ),
                    shape:  BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:      stepColor.withValues(alpha: 0.45),
                        blurRadius: 8,
                        offset:     const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '$step',
                      style: const TextStyle(
                        color:      Colors.white,
                        fontSize:   13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                // Connector line
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            stepColor.withValues(alpha: 0.5),
                            stepColor.withValues(alpha: 0.1),
                          ],
                          begin: Alignment.topCenter,
                          end:   Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Card
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: Material(
                color:        _cardC(isDark),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: onTap,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? stepColor.withValues(alpha: 0.25)
                            : _borderC(isDark),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                skill,
                                style: TextStyle(
                                  fontSize:   13,
                                  fontWeight: FontWeight.w700,
                                  color:      _textC(isDark),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Step $step of $total',
                                style: TextStyle(
                                  fontSize: 10,
                                  color:    stepColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width:  28,
                          height: 28,
                          decoration: BoxDecoration(
                            color:        stepColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.arrow_forward_ios_rounded,
                              size: 13, color: stepColor),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    )
        .animate(delay: delay)
        .fadeIn(duration: 350.ms)
        .slideX(begin: 0.05, end: 0);
  }
}

// ─── Gap Distance Indicator ───────────────────────────────────────────────────

class _GapDistanceIndicator extends StatelessWidget {
  final int    matched;
  final int    total;
  final double simScore;
  final bool   isDark;

  const _GapDistanceIndicator({
    required this.matched,
    required this.total,
    required this.simScore,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final barColor  = simScoreColor(simScore);
    final tierLabel = simScoreLabel(simScore);
    final ratio     = total > 0 ? matched / total : 0.0;

    return _GlassCard(
      isDark:      isDark,
      accentColor: barColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_graph_rounded,
                  size: 15, color: barColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Gap Distance (Cosine Similarity)',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize:   13,
                    color:      _textC(isDark),
                  ),
                ),
              ),
              SimScoreBadge(score: simScore),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color:        barColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border:       Border.all(
                      color: barColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  tierLabel,
                  style: TextStyle(
                    fontSize:   9,
                    color:      barColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _AnimGradBar(
            value:  ratio,
            colors: [barColor.withValues(alpha: 0.7), barColor],
            height: 10,
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          Text(
            '$matched of $total required skills matched',
            style: TextStyle(
              fontSize:   11,
              color:      barColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Topic Breakdown Tile ─────────────────────────────────────────────────────

class _SkillGapTile extends StatefulWidget {
  final String skill;
  final int    rank;
  final bool   isPriority;
  final bool   isDark;

  const _SkillGapTile({
    required this.skill,
    required this.rank,
    required this.isPriority,
    required this.isDark,
  });

  @override
  State<_SkillGapTile> createState() => _SkillGapTileState();
}

class _SkillGapTileState extends State<_SkillGapTile>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _rotCtrl;
  late final Animation<double>   _rotAnim;

  @override
  void initState() {
    super.initState();
    _rotCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _rotAnim = Tween<double>(begin: 0.0, end: 0.5).animate(
        CurvedAnimation(parent: _rotCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _rotCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _rotCtrl.forward() : _rotCtrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final topics = _topicsForSkill(widget.skill);
    final pColor = widget.isPriority
        ? Colors.red.shade600
        : _subC(widget.isDark);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color:        _cardC(widget.isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isPriority
              ? Colors.red.withValues(alpha: 0.25)
              : _borderC(widget.isDark),
        ),
        boxShadow: widget.isDark
            ? []
            : [
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width:  28,
                    height: 28,
                    decoration: BoxDecoration(
                      color:  pColor.withValues(alpha: 0.1),
                      shape:  BoxShape.circle,
                      border: Border.all(
                          color: pColor.withValues(alpha: 0.4)),
                    ),
                    child: Center(
                      child: Text(
                        '${widget.rank}',
                        style: TextStyle(
                          color:      pColor,
                          fontSize:   11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.skill,
                      style: TextStyle(
                        fontSize:   13,
                        fontWeight: FontWeight.w600,
                        color:      widget.isPriority
                            ? Colors.red.shade700
                            : _textC(widget.isDark),
                      ),
                    ),
                  ),
                  if (widget.isPriority) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.red.shade500,
                            Colors.red.shade700,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: const Text(
                        'Priority',
                        style: TextStyle(
                          color:      Colors.white,
                          fontSize:   10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  RotationTransition(
                    turns: _rotAnim,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size:  18,
                      color: _subC(widget.isDark),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration:       const Duration(milliseconds: 280),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild:  const SizedBox(height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(height: 1, color: _borderC(widget.isDark)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Icon(Icons.topic_outlined,
                        size: 13, color: _subC(widget.isDark)),
                    const SizedBox(width: 5),
                    Text(
                      'Learning Topics',
                      style: TextStyle(
                        fontSize:   11,
                        fontWeight: FontWeight.w600,
                        color:      _subC(widget.isDark),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  ...topics.asMap().entries.map(
                        (te) => _TopicRow(
                      topic:  te.value,
                      index:  te.key,
                      skill:  widget.skill,
                      isDark: widget.isDark,
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

class _TopicRow extends StatelessWidget {
  final String topic;
  final int    index;
  final String skill;
  final bool   isDark;

  const _TopicRow({
    required this.topic,
    required this.index,
    required this.skill,
    required this.isDark,
  });

  TopicStatus _resolveStatus(AppState appState) {
    final topicKey =
    '${skill}_$topic'.toLowerCase().replaceAll(' ', '_');
    if (appState.completedTopics.contains(topicKey)) {
      return TopicStatus.passed;
    }
    final hasAnyCompleted = appState.completedTopics
        .any((t) => t.startsWith(
        skill.toLowerCase().replaceAll(' ', '_')));
    if (!hasAnyCompleted && index == 0) return TopicStatus.inProgress;
    return TopicStatus.forthcoming;
  }

  Future<void> _launchQuiz(
      BuildContext context, AppState appState) async {
    final questions = _questionsForTopic(topic);
    final topicKey  =
    '${skill}_$topic'.toLowerCase().replaceAll(' ', '_');
    await showDialog<void>(
      context:            context,
      barrierDismissible: false,
      builder:            (_) => _QuizDialog(
        topic:     topic,
        topicKey:  topicKey,
        questions: questions,
        appState:  appState,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final status   = _resolveStatus(appState);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color:        isDark ? _P.slate900 : _P.slate50,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: _borderC(isDark)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width:  24,
            height: 24,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_P.blue500, _P.blue700],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  fontSize:   9,
                  color:      Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              topic,
              style: TextStyle(
                fontSize:   12,
                fontWeight: FontWeight.w500,
                color:      _textC(isDark),
              ),
            ),
          ),
          const SizedBox(width: 8),
          TopicStatusChip(status: status),
          const SizedBox(width: 8),
          status != TopicStatus.passed
              ? GestureDetector(
            onTap: () => _launchQuiz(context, appState),
            child: Column(
              mainAxisSize:       MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const AssessmentTypeBadge(isSkillLevel: false),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.accentTeal.withValues(alpha: 0.8),
                        AppTheme.accentTeal,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Quiz',
                    style: TextStyle(
                      fontSize:   10,
                      color:      Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          )
              : Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color:  AppTheme.accentGreen.withValues(alpha: 0.1),
              shape:  BoxShape.circle,
            ),
            child: const Icon(Icons.verified_rounded,
                size: 18, color: AppTheme.accentGreen),
          ),
        ],
      ),
    );
  }
}

// ─── Missing definitions for SkillGapScreen ─────────────────────────────────────

enum TopicStatus { passed, inProgress, forthcoming }

class TopicStatusChip extends StatelessWidget {
  final TopicStatus status;
  const TopicStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    late Color color;
    late String label;
    switch (status) {
      case TopicStatus.passed:
        color = AppTheme.accentGreen;
        label = 'Passed';
        break;
      case TopicStatus.inProgress:
        color = Colors.orange.shade600;
        label = 'In Progress';
        break;
      case TopicStatus.forthcoming:
        color = isDark ? _P.slate400 : _P.slate500;
        label = 'Forthcoming';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class AssessmentTypeBadge extends StatelessWidget {
  final bool isSkillLevel;
  const AssessmentTypeBadge({super.key, required this.isSkillLevel});

  @override
  Widget build(BuildContext context) {
    // Use different icons for skill level vs quiz
    return Icon(
      isSkillLevel ? Icons.auto_awesome_rounded : Icons.quiz_rounded,
      size: 14,
      color: AppTheme.accentTeal,
    );
  }
}

// ─── MCQ Quiz Dialog ──────────────────────────────────────────────────────────

class _QuizDialog extends StatefulWidget {
  final String              topic;
  final String              topicKey;
  final List<_QuizQuestion> questions;
  final AppState            appState;

  const _QuizDialog({
    required this.topic,
    required this.topicKey,
    required this.questions,
    required this.appState,
  });

  @override
  State<_QuizDialog> createState() => _QuizDialogState();
}

class _QuizDialogState extends State<_QuizDialog>
    with SingleTickerProviderStateMixin {
  int  _currentQ   = 0;
  int  _correct    = 0;
  int? _selected;
  bool _answered   = false;
  bool _complete   = false;
  int  _finalScore = 0;

  late final AnimationController _slideCtrl;
  late final Animation<Offset>   _slideIn;
  late final Animation<double>   _fadeIn;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _slideIn = Tween<Offset>(
      begin: const Offset(0.08, 0),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (_answered) return;
    setState(() {
      _selected = index;
      _answered = true;
      if (index == widget.questions[_currentQ].correctIndex) _correct++;
    });
  }

  Future<void> _next() async {
    if (_currentQ < widget.questions.length - 1) {
      await _slideCtrl.reverse();
      setState(() {
        _currentQ++;
        _selected = null;
        _answered = false;
      });
      _slideCtrl.forward();
    } else {
      _finalScore = (_correct / widget.questions.length * 100).round();
      widget.appState.recordQuizScore(widget.topicKey, _finalScore);
      setState(() => _complete = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      shape:           RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24)),
      backgroundColor: _cardC(isDark),
      titlePadding:    const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding:  const EdgeInsets.fromLTRB(20, 16, 20, 8),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.accentTeal, _P.blue500],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.quiz_outlined,
                color: Colors.white, size: 15),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.topic,
              style: TextStyle(
                fontSize:   14,
                fontWeight: FontWeight.w800,
                color:      _textC(isDark),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: _complete
          ? _QuizResult(
        score:   _finalScore,
        correct: _correct,
        total:   widget.questions.length,
        isDark:  isDark,
      )
          : SlideTransition(
        position: _slideIn,
        child: FadeTransition(
          opacity: _fadeIn,
          child: _QuizQuestionPanel(
            question: widget.questions[_currentQ],
            qIndex:   _currentQ,
            total:    widget.questions.length,
            selected: _selected,
            answered: _answered,
            isDark:   isDark,
            onSelect: _select,
          ),
        ),
      ),
      actions: _complete
          ? [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done',
              style: TextStyle(
                color:      AppTheme.primaryBlue,
                fontWeight: FontWeight.w700,
              )),
        ),
      ]
          : [
        if (_answered)
          ElevatedButton(
            onPressed: _next,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              elevation:       0,
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              _currentQ < widget.questions.length - 1
                  ? 'Next →'
                  : 'Finish',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}

class _QuizQuestionPanel extends StatelessWidget {
  final _QuizQuestion      question;
  final int                qIndex;
  final int                total;
  final int?               selected;
  final bool               answered;
  final bool               isDark;
  final void Function(int) onSelect;

  const _QuizQuestionPanel({
    required this.question,
    required this.qIndex,
    required this.total,
    required this.selected,
    required this.answered,
    required this.isDark,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.maxFinite,
      child: Column(
        mainAxisSize:       MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Q${qIndex + 1} of $total',
                style: TextStyle(fontSize: 11, color: _subC(isDark)),
              ),
              Text(
                '${((qIndex + 1) / total * 100).round()}%',
                style: const TextStyle(
                  fontSize:   11,
                  color:      AppTheme.primaryBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          _AnimGradBar(
            value:    (qIndex + 1) / total,
            colors:   const [_P.blue500, _P.violet500],
            height:   4,
            isDark:   isDark,
            duration: const Duration(milliseconds: 400),
          ),
          const SizedBox(height: 14),
          Text(
            question.question,
            style: TextStyle(
              fontSize:   13,
              fontWeight: FontWeight.w700,
              color:      _textC(isDark),
              height:     1.45,
            ),
          ),
          const SizedBox(height: 12),
          ...question.options.asMap().entries.map((e) {
            final isSelected = selected == e.key;
            final isCorrect  = e.key == question.correctIndex;
            final Color borderColor;
            final Color bgColor;
            if (!answered) {
              borderColor = _borderC(isDark);
              bgColor     = Colors.transparent;
            } else if (isCorrect) {
              borderColor = AppTheme.accentGreen;
              bgColor     = AppTheme.accentGreen.withValues(alpha: 0.08);
            } else if (isSelected) {
              borderColor = _P.red500;
              bgColor     = _P.red500.withValues(alpha: 0.06);
            } else {
              borderColor = _borderC(isDark);
              bgColor     = Colors.transparent;
            }
            return GestureDetector(
              onTap: () => onSelect(e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                  color:        bgColor,
                  borderRadius: BorderRadius.circular(12),
                  border:       Border.all(
                      color: borderColor, width: 1.5),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.value,
                        style: TextStyle(
                          fontSize: 12.5,
                          color:    _textC(isDark),
                          height:   1.35,
                        ),
                      ),
                    ),
                    if (answered && isCorrect)
                      const Icon(Icons.check_circle_rounded,
                          size: 16, color: AppTheme.accentGreen),
                    if (answered && isSelected && !isCorrect)
                      const Icon(Icons.cancel_rounded,
                          size: 16, color: _P.red500),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _QuizResult extends StatelessWidget {
  final int  score;
  final int  correct;
  final int  total;
  final bool isDark;

  const _QuizResult({
    required this.score,
    required this.correct,
    required this.total,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final passed = score >= 70;
    final color  = passed ? AppTheme.accentGreen : Colors.orange.shade700;

    return Column(
      mainAxisSize:       MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: 0.2),
                color.withValues(alpha: 0.05),
              ],
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(
            passed ? Icons.emoji_events_rounded : Icons.refresh_rounded,
            size:  42,
            color: color,
          ),
        ).animate().scale(
          begin:    const Offset(0.5, 0.5),
          end:      const Offset(1.0, 1.0),
          duration: 400.ms,
          curve:    Curves.elasticOut,
        ),
        const SizedBox(height: 14),
        Text(
          passed ? 'Topic Passed! 🎉' : 'Keep Practising',
          style: TextStyle(
            fontSize:   17,
            fontWeight: FontWeight.w800,
            color:      color,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$correct of $total correct · $score%',
          style: TextStyle(fontSize: 13, color: _subC(isDark)),
        ),
        const SizedBox(height: 12),
        // Score bar
        _AnimGradBar(
          value:  score / 100,
          colors: passed
              ? const [AppTheme.accentGreen, Color(0xFF16A34A)]
              : [Colors.orange.shade400, Colors.orange.shade700],
          height: 8,
          isDark: isDark,
        ),
        const SizedBox(height: 10),
        Text(
          passed
              ? 'This topic is now marked as passed in your profile.'
              : 'Score ≥70% to pass and unlock the next topic.',
          style: TextStyle(
            fontSize: 11,
            color:    _subC(isDark),
            height:   1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ─── Tip Banner ───────────────────────────────────────────────────────────────

class _TipBanner extends StatelessWidget {
  final double score;
  final Color  sColor;
  final bool   isDark;

  const _TipBanner({
    required this.score,
    required this.sColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color:        sColor.withValues(alpha: isDark ? 0.1 : 0.06),
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: sColor.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color:  sColor.withValues(alpha: 0.12),
              shape:  BoxShape.circle,
            ),
            child: Icon(Icons.auto_awesome_rounded, color: sColor, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _scoreTip(score),
              style: TextStyle(
                fontSize: 12.5,
                color:    sColor,
                height:   1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Skill Gap Bar ────────────────────────────────────────────────────────────

class _SkillGapBar extends StatelessWidget {
  final int   matched;
  final int   total;
  final Color sColor;
  final bool  isDark;

  const _SkillGapBar({
    required this.matched,
    required this.total,
    required this.sColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      isDark:      isDark,
      accentColor: sColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Skill Coverage',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize:   13,
                  color:      _textC(isDark),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color:        sColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$matched / $total skills',
                  style: TextStyle(
                    fontSize:   11,
                    color:      sColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _AnimGradBar(
            value:  total > 0 ? matched / total : 0.0,
            colors: [sColor.withValues(alpha: 0.7), sColor],
            height: 10,
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          Row(children: [
            _LegendDot(color: sColor, label: 'You have'),
            const SizedBox(width: 16),
            _LegendDot(color: Colors.red.shade400, label: 'Need to learn'),
          ]),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width:  10,
          height: 10,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.7)],
            ),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 10.5, color: Colors.grey),
        ),
      ],
    );
  }
}

// ─── Details Card ─────────────────────────────────────────────────────────────

class _DetailsCard extends StatelessWidget {
  final JobRecommendation job;
  final bool              isDark;

  const _DetailsCard({required this.job, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final rows = [
      (Icons.business_outlined,        'Company',      job.company),
      (Icons.location_on_outlined,     'Location',     job.location),
      (Icons.monetization_on_outlined, 'Salary',       job.formattedSalary),
      (Icons.work_outline_rounded,     'Type',         job.type),
      (Icons.bar_chart_rounded,        'Level',        job.level),
      (Icons.wifi_outlined,            'Working Mode', job.workingMode),
      (Icons.category_outlined,        'Industry',     job.industry),
    ];

    return _GlassCard(
      isDark:      isDark,
      accentColor: AppTheme.primaryBlue,
      padding:     EdgeInsets.zero,
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(height: 1, color: _borderC(isDark)),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width:  30,
                    height: 30,
                    decoration: BoxDecoration(
                      color:        _P.blue500.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(rows[i].$1,
                        size: 15, color: _subC(isDark)),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    rows[i].$2,
                    style: TextStyle(
                        fontSize: 12, color: _subC(isDark)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      rows[i].$3,
                      style: TextStyle(
                        fontSize:   13,
                        fontWeight: FontWeight.w700,
                        color:      _textC(isDark),
                      ),
                      overflow:  TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Animated Skill Chips ─────────────────────────────────────────────────────

class _AnimatedSkillChips extends StatelessWidget {
  final List<String>      skills;
  final Color             color;
  final Animation<double> listAnim;

  const _AnimatedSkillChips({
    required this.skills,
    required this.color,
    required this.listAnim,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing:    8,
      runSpacing: 8,
      children: skills.asMap().entries.map((e) {
        final anim = CurvedAnimation(
          parent: listAnim,
          curve: Interval(
            (e.key * 0.06).clamp(0.0, 0.9),
            1.0,
            curve: Curves.easeOut,
          ),
        );
        return FadeTransition(
          opacity: anim,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color:        color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: color.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_rounded, size: 12, color: color),
                const SizedBox(width: 5),
                Text(
                  e.value,
                  style: TextStyle(
                    fontSize:   12,
                    color:      color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Perfect Match Card ───────────────────────────────────────────────────────

class _PerfectMatchCard extends StatelessWidget {
  final bool isDark;
  const _PerfectMatchCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accentGreen.withValues(alpha: isDark ? 0.15 : 0.08),
            AppTheme.accentTeal.withValues(alpha: isDark ? 0.1 : 0.05),
          ],
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: AppTheme.accentGreen.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color:      AppTheme.accentGreen.withValues(alpha: 0.12),
            blurRadius: 20,
            offset:     const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  AppTheme.accentGreen.withValues(alpha: 0.25),
                  AppTheme.accentGreen.withValues(alpha: 0.05),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.emoji_events_rounded,
                size: 44, color: AppTheme.accentGreen),
          ).animate()
              .scale(
            begin:    const Offset(0.6, 0.6),
            end:      const Offset(1.0, 1.0),
            duration: 500.ms,
            curve:    Curves.elasticOut,
          ),
          const SizedBox(height: 16),
          const Text(
            '🎉 You meet all requirements!',
            style: TextStyle(
              fontSize:   18,
              fontWeight: FontWeight.w800,
              color:      AppTheme.accentGreen,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Your skills perfectly match this job.\nGo ahead and apply!',
            style: TextStyle(
              color:     isDark ? _P.slate400 : _P.slate500,
              fontSize:  13,
              height:    1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Bottom CTA Banner ────────────────────────────────────────────────────────

class _BottomCtaBanner extends StatelessWidget {
  const _BottomCtaBanner({required this.onBrowse});
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryBlue, Color(0xFF3B82F6)],
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color:      AppTheme.primaryBlue.withValues(alpha: 0.35),
            blurRadius: 20,
            offset:     const Offset(0, 7),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ready to start learning?',
                  style: TextStyle(
                    color:      Colors.white,
                    fontSize:   16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Build your skills and land the job →',
                  style: TextStyle(
                    color:    Colors.white70,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: onBrowse,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color:        Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4)),
              ),
              child: const Text(
                'Browse',
                style: TextStyle(
                  color:      Colors.white,
                  fontSize:   13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}