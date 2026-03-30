// lib/screens/assessment_hub_screen.dart — SkillBridge AI v2.1
// ─────────────────────────────────────────────────────────────────────────────
// Upgrades: Per-question countdown timer · Streak tracking · Confetti
// celebration · Custom score-ring painter · Grade system (S/A/B/C/F)
// · Review mode · Haptic feedback · Best-score tracking · Question dots
// · Gradient history chart · Difficulty badge · Staggered list animations
// ─────────────────────────────────────────────────────────────────────────────
//
// FIXES vs v2.0:
//  • FIX-1  Removed local _isDark bool, _toggleDark(), and didChangeDependencies().
//           Theme is now sourced exclusively from AppThemeProvider so the entire
//           app flips in sync when the global toggle is pressed.
//  • FIX-2  _buildDarkToggle() now calls AppThemeProvider.toggle() and reads
//           isDark from the provider — no more stale local bool.
//  • FIX-3  _isDark kept as a cached field (set at the top of build()) so all
//           existing helper methods that reference it compile unchanged.
//  • FIX-4  No duplicate theme button — one Consumer<AppThemeProvider> in the
//           AppBar actions.

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import 'application_tracker_screen.dart'; // AppThemeProvider lives here

// ─────────────────────────────────────────────────────────────────────────────
// ENUMS
// ─────────────────────────────────────────────────────────────────────────────

enum Difficulty { easy, medium, hard }

enum _HubView { topicList, assessment, result, review }

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

class McqQuestion {
  final String        question;
  final List<String>  options;
  final int           correctIndex;
  final String        subtopic;
  final Difficulty    difficulty;
  final String?       explanation;

  const McqQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.subtopic,
    this.difficulty   = Difficulty.medium,
    this.explanation,
  });
}

class AssessmentTopic {
  final String            id;
  final String            name;
  final List<McqQuestion> questions;
  final String            icon;

  AssessmentTopic({
    required this.id,
    required this.name,
    required this.questions,
    this.icon = '📝',
  });
}

class SkillAssessmentData {
  final String                 skillName;
  final String                 emoji;
  final List<AssessmentTopic>  topics;

  SkillAssessmentData({
    required this.skillName,
    required this.topics,
    this.emoji = '💡',
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// PARTICLE SYSTEM
// ─────────────────────────────────────────────────────────────────────────────

class _Particle {
  final double startX;
  final double startY;
  final double vx;
  final double vy;
  final double size;
  final Color  color;
  final double startRotation;
  final double rotationSpeed;

  const _Particle({
    required this.startX,
    required this.startY,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.startRotation,
    required this.rotationSpeed,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double t; // 0.0 → 1.0 maps to 0 → 2.5 seconds

  const _ConfettiPainter({required this.particles, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final paint  = Paint()..style = PaintingStyle.fill;
    final realT  = t * 2.5;
    for (final p in particles) {
      final x       = p.startX * size.width + p.vx * realT * size.width;
      final y       = p.startY * size.height +
          p.vy * realT * size.height +
          0.5 * 180 * realT * realT;
      final opacity = math.max(0.0, 1.0 - realT * 0.6);
      if (opacity <= 0.01) continue;
      paint.color = p.color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.startRotation + p.rotationSpeed * realT);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset.zero, width: p.size, height: p.size * 0.45),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

// ─────────────────────────────────────────────────────────────────────────────
// CUSTOM PAINTERS
// ─────────────────────────────────────────────────────────────────────────────

class _ScoreRingPainter extends CustomPainter {
  final double progress;
  final Color  progressColor;
  final Color  trackColor;

  const _ScoreRingPainter({
    required this.progress,
    required this.progressColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 6;
    const stroke = 9.0;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color       = trackColor
        ..strokeWidth = stroke
        ..style       = PaintingStyle.stroke,
    );

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        Paint()
          ..color       = progressColor
          ..strokeWidth = stroke
          ..style       = PaintingStyle.stroke
          ..strokeCap   = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_ScoreRingPainter old) =>
      old.progress != progress || old.progressColor != progressColor;
}

class _TimerRingPainter extends CustomPainter {
  final double progress;
  final Color  color;

  const _TimerRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 3;
    const stroke = 3.5;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color       = color.withValues(alpha: 0.18)
        ..strokeWidth = stroke
        ..style       = PaintingStyle.stroke,
    );

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        Paint()
          ..color       = color
          ..strokeWidth = stroke
          ..style       = PaintingStyle.stroke
          ..strokeCap   = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_TimerRingPainter old) =>
      old.progress != progress || old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// MOCK DATA
// ─────────────────────────────────────────────────────────────────────────────

final List<SkillAssessmentData> _mockSkills = [
  SkillAssessmentData(
    skillName: 'Python',
    emoji: '🐍',
    topics: [
      AssessmentTopic(
          id: 'py_basics',
          name: 'Variables & Data Types',
          icon: '🔤',
          questions: [
            const McqQuestion(
              question: 'Which of the following is a mutable data type in Python?',
              options: ['Tuple', 'String', 'List', 'Integer'],
              correctIndex: 2,
              subtopic: 'Data Types',
              difficulty: Difficulty.easy,
              explanation:
              'Lists are mutable — you can add, remove, or change elements. Tuples, strings, and integers are immutable.',
            ),
            const McqQuestion(
              question: 'What is the output of: type(3.14)?',
              options: [
                "<class 'float'>",
                "<class 'int'>",
                "<class 'double'>",
                "<class 'number'>"
              ],
              correctIndex: 0,
              subtopic: 'Data Types',
              difficulty: Difficulty.easy,
              explanation:
              'Python has no "double" type. Decimal numbers are represented as float.',
            ),
            const McqQuestion(
              question:
              'Which keyword is used to declare a variable in Python?',
              options: ['var', 'let', 'dim', 'No keyword needed'],
              correctIndex: 3,
              subtopic: 'Variables',
              difficulty: Difficulty.easy,
              explanation:
              'Python uses dynamic typing — variables are created by simple assignment (x = 5) with no declaration keyword.',
            ),
            const McqQuestion(
              question: 'What does len("Hello") return?',
              options: ['4', '5', '6', 'Error'],
              correctIndex: 1,
              subtopic: 'Built-ins',
              difficulty: Difficulty.easy,
              explanation: '"Hello" has 5 characters: H, e, l, l, o.',
            ),
            const McqQuestion(
              question: 'Which is NOT a valid Python integer literal?',
              options: ['0x1A', '0b1010', '0o17', '0d12'],
              correctIndex: 3,
              subtopic: 'Data Types',
              difficulty: Difficulty.medium,
              explanation:
              'Python supports hex (0x), binary (0b), and octal (0o) literals. "0d" is not a valid prefix.',
            ),
          ]),
      AssessmentTopic(
          id: 'py_control',
          name: 'Control Flow',
          icon: '🔀',
          questions: [
            const McqQuestion(
              question: 'Which statement is used to exit a loop early?',
              options: ['exit', 'break', 'stop', 'end'],
              correctIndex: 1,
              subtopic: 'Loops',
              difficulty: Difficulty.easy,
            ),
            const McqQuestion(
              question: 'What is the output of list(range(2, 10, 3))?',
              options: ['[2, 5, 8]', '[2, 4, 6, 8]', '[3, 6, 9]', '[2, 5, 8, 11]'],
              correctIndex: 0,
              subtopic: 'Loops',
              difficulty: Difficulty.medium,
              explanation:
              'range(start, stop, step): starts at 2, steps by 3 → 2, 5, 8. 11 would exceed stop=10.',
            ),
            const McqQuestion(
              question:
              'Which keyword skips the rest of the loop body for the current iteration?',
              options: ['skip', 'pass', 'continue', 'next'],
              correctIndex: 2,
              subtopic: 'Loops',
              difficulty: Difficulty.easy,
            ),
            const McqQuestion(
              question: 'In Python, elif stands for:',
              options: ['else if', 'else ignore', 'end if', 'else loop'],
              correctIndex: 0,
              subtopic: 'Conditionals',
              difficulty: Difficulty.easy,
            ),
            const McqQuestion(
              question: 'What does "pass" do in Python?',
              options: [
                'Exits the function',
                'Does nothing (no-op)',
                'Skips an iteration',
                'Ends the program'
              ],
              correctIndex: 1,
              subtopic: 'Syntax',
              difficulty: Difficulty.easy,
              explanation:
              '"pass" is a null statement used as a placeholder where a statement is syntactically required.',
            ),
          ]),
      AssessmentTopic(
          id: 'py_funcs',
          name: 'Functions & Scope',
          icon: '⚙️',
          questions: [
            const McqQuestion(
              question: 'Which keyword defines a function in Python?',
              options: ['function', 'func', 'def', 'define'],
              correctIndex: 2,
              subtopic: 'Functions',
              difficulty: Difficulty.easy,
            ),
            const McqQuestion(
              question: 'What is a lambda function?',
              options: [
                'A named function',
                'An anonymous one-expression function',
                'A class method',
                'A built-in function'
              ],
              correctIndex: 1,
              subtopic: 'Functions',
              difficulty: Difficulty.medium,
              explanation:
              'Lambdas are anonymous functions defined with "lambda args: expression". They\'re limited to a single expression.',
            ),
            const McqQuestion(
              question: 'What does *args allow in a function?',
              options: [
                'Keyword arguments',
                'Variable positional arguments',
                'Default arguments',
                'Type hints'
              ],
              correctIndex: 1,
              subtopic: 'Arguments',
              difficulty: Difficulty.medium,
            ),
            const McqQuestion(
              question:
              'Which scope has the highest priority in Python (LEGB rule)?',
              options: ['Global', 'Local', 'Enclosing', 'Built-in'],
              correctIndex: 1,
              subtopic: 'Scope',
              difficulty: Difficulty.hard,
              explanation:
              'LEGB: Local → Enclosing → Global → Built-in. Local scope is checked first.',
            ),
            const McqQuestion(
              question:
              'What does a function return if no return statement is used?',
              options: ['0', 'False', 'None', 'Empty string'],
              correctIndex: 2,
              subtopic: 'Functions',
              difficulty: Difficulty.easy,
            ),
          ]),
      AssessmentTopic(
          id: 'py_oop',
          name: 'OOP Basics',
          icon: '🏗️',
          questions: [
            const McqQuestion(
              question: 'Which method is called when an object is created?',
              options: ['__start__', '__init__', '__new__', '__create__'],
              correctIndex: 1,
              subtopic: 'Classes',
              difficulty: Difficulty.easy,
            ),
            const McqQuestion(
              question: 'What does "self" refer to in a class method?',
              options: [
                'The class itself',
                'The current instance',
                'The parent class',
                'The module'
              ],
              correctIndex: 1,
              subtopic: 'Classes',
              difficulty: Difficulty.easy,
            ),
            const McqQuestion(
              question:
              'Which OOP principle hides internal implementation details?',
              options: [
                'Inheritance',
                'Polymorphism',
                'Encapsulation',
                'Abstraction'
              ],
              correctIndex: 2,
              subtopic: 'Principles',
              difficulty: Difficulty.medium,
              explanation:
              'Encapsulation bundles data and methods and restricts direct access to internal state.',
            ),
            const McqQuestion(
              question: 'How do you inherit from a parent class in Python?',
              options: [
                'class Child extends Parent',
                'class Child(Parent)',
                'class Child : Parent',
                'class Child inherits Parent'
              ],
              correctIndex: 1,
              subtopic: 'Inheritance',
              difficulty: Difficulty.easy,
            ),
            const McqQuestion(
              question: 'What is method overriding?',
              options: [
                'Adding new methods to a class',
                'Redefining a parent class method in a subclass',
                'Calling a method twice',
                'Deleting a method'
              ],
              correctIndex: 1,
              subtopic: 'Inheritance',
              difficulty: Difficulty.medium,
            ),
          ]),
      AssessmentTopic(
          id: 'py_ds',
          name: 'Data Structures',
          icon: '🗂️',
          questions: [
            const McqQuestion(
              question:
              'Which data structure uses LIFO (Last-In, First-Out) order?',
              options: ['Queue', 'Stack', 'Linked List', 'Tree'],
              correctIndex: 1,
              subtopic: 'Structures',
              difficulty: Difficulty.easy,
            ),
            const McqQuestion(
              question:
              'How do you add an element to the end of a Python list?',
              options: [
                'list.add()',
                'list.append()',
                'list.push()',
                'list.insert(0,x)'
              ],
              correctIndex: 1,
              subtopic: 'Lists',
              difficulty: Difficulty.easy,
            ),
            const McqQuestion(
              question: 'A Python dictionary stores data as:',
              options: [
                'Ordered index pairs',
                'Key-value pairs',
                'Indexed items only',
                'Unique set elements'
              ],
              correctIndex: 1,
              subtopic: 'Dictionaries',
              difficulty: Difficulty.easy,
            ),
            const McqQuestion(
              question:
              'Which data structure has O(1) average-case lookup time?',
              options: [
                'List',
                'Tuple',
                'Dictionary',
                'Both Dictionary and Set'
              ],
              correctIndex: 3,
              subtopic: 'Complexity',
              difficulty: Difficulty.hard,
              explanation:
              'Both dict and set use hash tables under the hood, giving O(1) average lookup, insert, and delete.',
            ),
            const McqQuestion(
              question: 'What does set() remove from a collection?',
              options: [
                'None values',
                'Duplicate elements',
                'Negative numbers',
                'String elements'
              ],
              correctIndex: 1,
              subtopic: 'Sets',
              difficulty: Difficulty.easy,
            ),
          ]),
    ],
  ),
  SkillAssessmentData(
    skillName: 'SQL',
    emoji: '🗄️',
    topics: [
      AssessmentTopic(
          id: 'sql_basics',
          name: 'Basic Queries',
          icon: '🔍',
          questions: [
            const McqQuestion(
              question:
              'Which SQL statement retrieves data from a table?',
              options: ['GET', 'FETCH', 'SELECT', 'READ'],
              correctIndex: 2,
              subtopic: 'DQL',
              difficulty: Difficulty.easy,
            ),
            const McqQuestion(
              question: 'What does the WHERE clause do in a SQL query?',
              options: [
                'Sorts results',
                'Filters rows by condition',
                'Groups rows',
                'Joins tables'
              ],
              correctIndex: 1,
              subtopic: 'Filtering',
              difficulty: Difficulty.easy,
            ),
            const McqQuestion(
              question:
              'Which keyword removes duplicate rows from query results?',
              options: ['UNIQUE', 'DISTINCT', 'FILTER', 'NODUPE'],
              correctIndex: 1,
              subtopic: 'DQL',
              difficulty: Difficulty.easy,
            ),
            const McqQuestion(
              question: 'What does ORDER BY col ASC do?',
              options: [
                'Sorts descending',
                'Sorts ascending',
                'Filters nulls',
                'Groups results'
              ],
              correctIndex: 1,
              subtopic: 'Sorting',
              difficulty: Difficulty.easy,
            ),
            const McqQuestion(
              question:
              'Which SQL clause limits the number of returned rows?',
              options: [
                'TOP (SQL Server)',
                'LIMIT (MySQL/PostgreSQL)',
                'MAX',
                'Both A and B depending on DB'
              ],
              correctIndex: 3,
              subtopic: 'DQL',
              difficulty: Difficulty.medium,
              explanation:
              'LIMIT is standard SQL / MySQL / PostgreSQL. TOP is used in SQL Server / MS Access.',
            ),
          ]),
      AssessmentTopic(
          id: 'sql_joins',
          name: 'Joins & Relations',
          icon: '🔗',
          questions: [
            const McqQuestion(
              question:
              'Which JOIN returns all rows from both tables regardless of match?',
              options: [
                'INNER JOIN',
                'LEFT JOIN',
                'FULL OUTER JOIN',
                'CROSS JOIN'
              ],
              correctIndex: 2,
              subtopic: 'Joins',
              difficulty: Difficulty.medium,
              explanation:
              'FULL OUTER JOIN returns all rows from both tables, filling NULLs where no match exists.',
            ),
            const McqQuestion(
              question: 'INNER JOIN returns rows that:',
              options: [
                'Exist in left table only',
                'Have no matching rows',
                'Match in both tables',
                'Exist in right table only'
              ],
              correctIndex: 2,
              subtopic: 'Joins',
              difficulty: Difficulty.easy,
            ),
            const McqQuestion(
              question: 'What does a FOREIGN KEY reference?',
              options: [
                'A PRIMARY KEY in another table',
                'Any column in the same table',
                'An index in another table',
                'A NULL column'
              ],
              correctIndex: 0,
              subtopic: 'Keys',
              difficulty: Difficulty.medium,
            ),
            const McqQuestion(
              question: 'LEFT JOIN includes:',
              options: [
                'Only matching rows',
                'All left rows + matching right rows (NULLs where no match)',
                'All right table rows',
                'All rows from both tables'
              ],
              correctIndex: 1,
              subtopic: 'Joins',
              difficulty: Difficulty.medium,
            ),
            const McqQuestion(
              question: 'What is a self-join?',
              options: [
                'Joining two different tables',
                'Joining a table to itself',
                'Joining a view to a table',
                'Joining on multiple conditions'
              ],
              correctIndex: 1,
              subtopic: 'Joins',
              difficulty: Difficulty.hard,
              explanation:
              'A self-join uses aliases to join a table with itself — useful for hierarchical or comparative queries.',
            ),
          ]),
      AssessmentTopic(
          id: 'sql_agg',
          name: 'Aggregation & Grouping',
          icon: '📊',
          questions: [
            const McqQuestion(
              question:
              'Which function counts the number of rows in SQL?',
              options: ['SUM()', 'COUNT()', 'TOTAL()', 'NUM()'],
              correctIndex: 1,
              subtopic: 'Aggregation',
              difficulty: Difficulty.easy,
            ),
            const McqQuestion(
              question: 'GROUP BY is used to:',
              options: [
                'Sort results',
                'Filter individual rows',
                'Group rows sharing column values',
                'Remove duplicates'
              ],
              correctIndex: 2,
              subtopic: 'Grouping',
              difficulty: Difficulty.easy,
            ),
            const McqQuestion(
              question: 'The HAVING clause filters:',
              options: [
                'Individual rows (before grouping)',
                'Grouped results (after GROUP BY)',
                'Joined tables',
                'NULL values'
              ],
              correctIndex: 1,
              subtopic: 'Grouping',
              difficulty: Difficulty.medium,
              explanation:
              'WHERE filters rows before grouping; HAVING filters after. Use HAVING with aggregate functions.',
            ),
            const McqQuestion(
              question: 'What does AVG() return?',
              options: [
                'Maximum value',
                'Minimum value',
                'Arithmetic mean',
                'Median value'
              ],
              correctIndex: 2,
              subtopic: 'Aggregation',
              difficulty: Difficulty.easy,
            ),
            const McqQuestion(
              question:
              'In SQL order of execution, which clause runs AFTER GROUP BY?',
              options: ['WHERE', 'HAVING', 'FROM', 'SELECT'],
              correctIndex: 1,
              subtopic: 'Order of Execution',
              difficulty: Difficulty.hard,
              explanation:
              'SQL logical order: FROM → WHERE → GROUP BY → HAVING → SELECT → ORDER BY → LIMIT.',
            ),
          ]),
    ],
  ),
  SkillAssessmentData(
    skillName: 'Data Analysis',
    emoji: '📈',
    topics: [
      AssessmentTopic(
          id: 'da_stats',
          name: 'Descriptive Statistics',
          icon: '📐',
          questions: [
            const McqQuestion(
              question:
              'Which measure of central tendency is LEAST affected by outliers?',
              options: ['Mean', 'Mode', 'Median', 'Range'],
              correctIndex: 2,
              subtopic: 'Central Tendency',
              difficulty: Difficulty.easy,
              explanation:
              'The median is the middle value and is resistant to extreme outliers. The mean is heavily skewed by them.',
            ),
            const McqQuestion(
              question: 'Standard deviation measures:',
              options: [
                'Central tendency',
                'Spread / dispersion of data',
                'Correlation between variables',
                'Distribution skew'
              ],
              correctIndex: 1,
              subtopic: 'Dispersion',
              difficulty: Difficulty.easy,
            ),
            const McqQuestion(
              question: 'A Pearson correlation of -1 means:',
              options: [
                'No correlation',
                'Perfect positive correlation',
                'Perfect negative correlation',
                'Weak negative correlation'
              ],
              correctIndex: 2,
              subtopic: 'Correlation',
              difficulty: Difficulty.medium,
              explanation:
              'Correlation ranges from -1 (perfect negative) through 0 (none) to +1 (perfect positive).',
            ),
            const McqQuestion(
              question: 'Variance is the square of:',
              options: ['Mean', 'Standard deviation', 'Range', 'Mode'],
              correctIndex: 1,
              subtopic: 'Dispersion',
              difficulty: Difficulty.medium,
            ),
            const McqQuestion(
              question:
              'Which chart type best shows the frequency distribution of a continuous variable?',
              options: ['Pie chart', 'Histogram', 'Line chart', 'Scatter plot'],
              correctIndex: 1,
              subtopic: 'Visualization',
              difficulty: Difficulty.easy,
            ),
          ]),
      AssessmentTopic(
          id: 'da_viz',
          name: 'Data Visualization',
          icon: '🎨',
          questions: [
            const McqQuestion(
              question:
              'Which chart type is best for showing trends over time?',
              options: ['Bar chart', 'Pie chart', 'Line chart', 'Scatter plot'],
              correctIndex: 2,
              subtopic: 'Chart Types',
              difficulty: Difficulty.easy,
            ),
            const McqQuestion(
              question: 'What does a scatter plot primarily show?',
              options: [
                'Part-to-whole proportions',
                'Frequency distribution',
                'Relationship between two continuous variables',
                'Time series trend'
              ],
              correctIndex: 2,
              subtopic: 'Chart Types',
              difficulty: Difficulty.easy,
            ),
            const McqQuestion(
              question: 'Which is a BAD practice in data visualization?',
              options: [
                'Using clear axis labels',
                'Truncating the Y-axis to exaggerate differences',
                'Using a consistent color palette',
                'Adding a descriptive legend'
              ],
              correctIndex: 1,
              subtopic: 'Best Practices',
              difficulty: Difficulty.medium,
              explanation:
              'Truncating the Y-axis distorts perception of magnitude and can mislead viewers.',
            ),
            const McqQuestion(
              question: 'A heatmap is best used for visualizing:',
              options: [
                'Trends over time',
                'Part-to-whole ratios',
                'Correlation matrices or 2D density',
                'Geographic data'
              ],
              correctIndex: 2,
              subtopic: 'Chart Types',
              difficulty: Difficulty.medium,
            ),
            const McqQuestion(
              question: 'What is the primary purpose of data visualization?',
              options: [
                'To impress stakeholders with complexity',
                'To communicate insights clearly and efficiently',
                'To replace raw data tables',
                'To hide underlying complexity'
              ],
              correctIndex: 1,
              subtopic: 'Purpose',
              difficulty: Difficulty.easy,
            ),
          ]),
    ],
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class AssessmentHubScreen extends StatefulWidget {
  const AssessmentHubScreen({super.key});

  @override
  State<AssessmentHubScreen> createState() => _AssessmentHubScreenState();
}

class _AssessmentHubScreenState extends State<AssessmentHubScreen>
    with TickerProviderStateMixin {

  // ── FIX-3: _isDark is a cached field refreshed at the top of build().
  //    All helper methods that reference it remain unchanged.
  //    Source of truth is always AppThemeProvider — no local toggle needed.
  bool _isDark = false;

  // ── Design tokens ────────────────────────────────────────────────────
  static const Color _primary   = Color(0xFF1A56DB);
  static const Color _success   = Color(0xFF10B981);
  static const Color _warning   = Color(0xFFF59E0B);
  static const Color _error     = Color(0xFFEF4444);
  static const Color _purple    = Color(0xFF8B5CF6);
  static const Color _lightBlue = Color(0xFFEFF6FF);
  static const Color _successLt = Color(0xFFD1FAE5);
  static const Color _errorLt   = Color(0xFFFEE2E2);
  static const Color _warningLt = Color(0xFFFFFBEB);

  // ── Theme colour helpers (use cached _isDark) ─────────────────────────
  Color get _bg     => _isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
  Color get _card   => _isDark ? const Color(0xFF1E293B) : Colors.white;
  Color get _border => _isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
  Color get _text   => _isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
  Color get _sub    => _isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

  // ── Assessment config ─────────────────────────────────────────────────
  static const int _timerDuration = 30;

  // ── Data ──────────────────────────────────────────────────────────────
  final List<SkillAssessmentData> _skills      = _mockSkills;
  final Map<String, int>          _topicScores = {};
  final Map<String, int>          _bestScores  = {};
  final Map<String, List<int>>    _history     = {};
  final Map<int, _HubView>        _tabViews    = {};

  // ── Session state ─────────────────────────────────────────────────────
  int              _activeSkillIdx  = 0;
  AssessmentTopic? _activeTopic;
  int              _currentQuestion = 0;
  int?             _selectedAnswer;
  bool             _showResult      = false;
  bool             _isSkillLevel    = false;
  bool             _timedOut        = false;

  final Map<String, List<int>> _subtopicScores = {};
  final Map<int, int?>         _sessionAnswers = {};

  int    _resultScore   = 0;
  int    _resultCorrect = 0;
  String _grade         = 'F';

  // ── Streak ────────────────────────────────────────────────────────────
  int _currentStreak = 0;
  int _maxStreak     = 0;

  // ── Timer ─────────────────────────────────────────────────────────────
  Timer? _questionTimer;
  int    _timeLeft = _timerDuration;

  // ── Particles ─────────────────────────────────────────────────────────
  List<_Particle> _particles = [];

  // ── Controllers ───────────────────────────────────────────────────────
  late TabController       _tabController;
  late AnimationController _scoreAnimCtrl;
  late AnimationController _confettiCtrl;
  late AnimationController _listAnimCtrl;
  late Animation<double>   _scoreAnim;
  late Animation<double>   _ringAnim;

  // ──────────────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ──────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: _skills.length, vsync: this)
      ..addListener(() {
        if (!_tabController.indexIsChanging) {
          setState(() => _activeSkillIdx = _tabController.index);
        }
      });

    _scoreAnimCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _scoreAnim =
        CurvedAnimation(parent: _scoreAnimCtrl, curve: Curves.elasticOut);
    _ringAnim =
        CurvedAnimation(parent: _scoreAnimCtrl, curve: Curves.easeInOut);

    _confettiCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3000));

    _listAnimCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));

    for (final skill in _skills) {
      for (final topic in skill.topics) {
        _history[topic.id] = [];
      }
    }

    _listAnimCtrl.forward();
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
    _tabController.dispose();
    _scoreAnimCtrl.dispose();
    _confettiCtrl.dispose();
    _listAnimCtrl.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────
  // HELPERS
  // ──────────────────────────────────────────────────────────────────────

  bool _isTopicPassed(String topicId) =>
      (_bestScores[topicId] ?? 0) >= 70;

  bool _isTopicUnlocked(SkillAssessmentData skill, int topicIdx) {
    if (topicIdx == 0) return true;
    return _isTopicPassed(skill.topics[topicIdx - 1].id);
  }

  bool _allTopicsPassed(SkillAssessmentData skill) =>
      skill.topics.every((t) => _isTopicPassed(t.id));

  int _passedCount(SkillAssessmentData skill) =>
      skill.topics.where((t) => _isTopicPassed(t.id)).length;

  _HubView _viewFor(int idx) => _tabViews[idx] ?? _HubView.topicList;

  String _calculateGrade(int score) {
    if (score >= 95) return 'S';
    if (score >= 85) return 'A';
    if (score >= 70) return 'B';
    if (score >= 50) return 'C';
    return 'F';
  }

  Color _gradeColor(String grade) {
    switch (grade) {
      case 'S': return _purple;
      case 'A': return _primary;
      case 'B': return _success;
      case 'C': return _warning;
      default:  return _error;
    }
  }

  Color _difficultyColor(Difficulty d) {
    switch (d) {
      case Difficulty.easy:   return _success;
      case Difficulty.medium: return _warning;
      case Difficulty.hard:   return _error;
    }
  }

  String _difficultyLabel(Difficulty d) {
    switch (d) {
      case Difficulty.easy:   return 'Easy';
      case Difficulty.medium: return 'Medium';
      case Difficulty.hard:   return 'Hard';
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // TIMER
  // ──────────────────────────────────────────────────────────────────────

  void _startTimer() {
    _questionTimer?.cancel();
    _timeLeft = _timerDuration;
    _timedOut = false;
    _questionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_showResult) return;
      setState(() => _timeLeft--);
      if (_timeLeft <= 0) {
        _questionTimer?.cancel();
        _onTimeExpired();
      }
    });
  }

  void _onTimeExpired() {
    HapticFeedback.heavyImpact();
    setState(() => _timedOut = true);
    _handleSubmit(forced: true);
  }

  // ──────────────────────────────────────────────────────────────────────
  // CONFETTI
  // ──────────────────────────────────────────────────────────────────────

  void _spawnConfetti() {
    final rng = math.Random();
    const colors = [
      Color(0xFF1A56DB), Color(0xFF10B981), Color(0xFFF59E0B),
      Color(0xFFEF4444), Color(0xFF8B5CF6), Color(0xFFEC4899),
      Color(0xFF06B6D4), Color(0xFFF97316),
    ];
    _particles = List.generate(70, (i) {
      final angle = -math.pi / 2 + (rng.nextDouble() - 0.5) * math.pi * 1.2;
      final speed = 0.08 + rng.nextDouble() * 0.28;
      return _Particle(
        startX:        0.15 + rng.nextDouble() * 0.7,
        startY:        0.05 + rng.nextDouble() * 0.1,
        vx:            math.cos(angle) * speed,
        vy:            math.sin(angle) * speed,
        size:          5 + rng.nextDouble() * 9,
        color:         colors[rng.nextInt(colors.length)],
        startRotation: rng.nextDouble() * math.pi * 2,
        rotationSpeed: (rng.nextDouble() - 0.5) * 12,
      );
    });
    _confettiCtrl.forward(from: 0);
  }

  // ──────────────────────────────────────────────────────────────────────
  // ASSESSMENT CONTROL
  // ──────────────────────────────────────────────────────────────────────

  void _startAssessment(AssessmentTopic topic, {bool skillLevel = false}) {
    _questionTimer?.cancel();
    setState(() {
      _activeTopic      = topic;
      _currentQuestion  = 0;
      _selectedAnswer   = null;
      _showResult       = false;
      _isSkillLevel     = skillLevel;
      _timedOut         = false;
      _currentStreak    = 0;
      _subtopicScores.clear();
      _sessionAnswers.clear();
      _particles        = [];
      _tabViews[_activeSkillIdx] = _HubView.assessment;
    });
    _startTimer();
  }

  void _startSkillAssessment(int skillIdx) {
    final skill = _skills[skillIdx];
    final allQ  = skill.topics.expand((t) => t.questions).toList();
    _startAssessment(
      AssessmentTopic(
        id:        '${skill.skillName}_full',
        name:      '${skill.skillName} — Full Assessment',
        icon:      '🏆',
        questions: allQ,
      ),
      skillLevel: true,
    );
  }

  void _selectAnswer(int idx) {
    if (_showResult || _timedOut) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedAnswer = idx);
  }

  void _handleSubmit({bool forced = false}) {
    final topic = _activeTopic;
    if (topic == null) return;
    _questionTimer?.cancel();

    final q         = topic.questions[_currentQuestion];
    final isCorrect = !_timedOut && _selectedAnswer == q.correctIndex;

    if (isCorrect) {
      _currentStreak++;
      if (_currentStreak > _maxStreak) _maxStreak = _currentStreak;
      if (!forced) HapticFeedback.mediumImpact();
    } else {
      if (_currentStreak > 0 && !forced) HapticFeedback.heavyImpact();
      _currentStreak = 0;
    }

    final sub = q.subtopic;
    _subtopicScores[sub] ??= [0, 0];
    _subtopicScores[sub]![1]++;
    if (isCorrect) _subtopicScores[sub]![0]++;

    _sessionAnswers[_currentQuestion] = _timedOut ? null : _selectedAnswer;

    final isLast = _currentQuestion == topic.questions.length - 1;

    if (!isLast) {
      setState(() => _showResult = true);
      Future.delayed(Duration(milliseconds: forced ? 500 : 700), () {
        if (!mounted) return;
        setState(() {
          _currentQuestion++;
          _selectedAnswer = null;
          _showResult     = false;
          _timedOut       = false;
        });
        _startTimer();
      });
    } else {
      final correct = _subtopicScores.values.fold(0, (s, v) => s + v[0]);
      final totalQ  = topic.questions.length;
      final score   = ((correct / totalQ) * 100).round();

      _topicScores[topic.id] = score;
      _bestScores[topic.id]  =
          math.max(score, _bestScores[topic.id] ?? 0);
      (_history[topic.id] ??= []).add(score);

      try {
        context.read<AppState>().recordQuizScore(topic.id, score);
      } catch (_) {}

      _grade = _calculateGrade(score);

      if (score >= 70) {
        _spawnConfetti();
        Future.delayed(const Duration(milliseconds: 200),
                () => HapticFeedback.heavyImpact());
      }

      setState(() {
        _showResult    = true;
        _resultScore   = score;
        _resultCorrect = correct;
        _tabViews[_activeSkillIdx] = _HubView.result;
      });
      _scoreAnimCtrl.forward(from: 0);
    }
  }

  void _backToHub() {
    _questionTimer?.cancel();
    setState(() {
      _particles     = [];
      _activeTopic   = null;
      _selectedAnswer = null;
      _showResult    = false;
      _timedOut      = false;
      _currentStreak = 0;
      _sessionAnswers.clear();
      _tabViews[_activeSkillIdx] = _HubView.topicList;
    });
    _listAnimCtrl.forward(from: 0);
  }

  // ──────────────────────────────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // FIX-1 & FIX-3: Source _isDark from AppThemeProvider so the whole app
    // responds to the global toggle. Cached into the field so all existing
    // getter helpers (_bg, _card, etc.) continue to work unchanged.
    _isDark = context.watch<AppThemeProvider>().isDark;

    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: _viewFor(_activeSkillIdx) != _HubView.topicList
                  ? const NeverScrollableScrollPhysics()
                  : null,
              children: List.generate(_skills.length, (i) {
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.04),
                        end:   Offset.zero,
                      ).animate(CurvedAnimation(
                          parent: anim, curve: Curves.easeOut)),
                      child: child,
                    ),
                  ),
                  child: _buildTabContent(i),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ── App Bar ───────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    final view = _viewFor(_activeSkillIdx);
    String title = 'Assessment Hub';
    if (view == _HubView.assessment) title = _activeTopic?.name ?? 'Assessment';
    if (view == _HubView.result)     title = 'Results';
    if (view == _HubView.review)     title = 'Review Answers';

    return AppBar(
      backgroundColor:        _bg,
      elevation:              0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_rounded, color: _text),
        onPressed: () {
          if (view == _HubView.review) {
            setState(() => _tabViews[_activeSkillIdx] = _HubView.result);
          } else if (view != _HubView.topicList) {
            _backToHub();
          } else {
            Navigator.pop(context);
          }
        },
      ),
      title: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
            fontSize: 17, fontWeight: FontWeight.w700, color: _text),
      ),
      centerTitle: true,
      actions: [
        if (view == _HubView.assessment && _currentStreak >= 2)
          _buildStreakBadge(),
        // FIX-2 & FIX-4: Single theme toggle wired to AppThemeProvider.
        //  No duplicate — only this button exists on this screen.
        _buildDarkToggle(),
      ],
    );
  }

  Widget _buildStreakBadge() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(right: 4, top: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color:  _warningLt,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: _warning.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            '$_currentStreak',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 13, fontWeight: FontWeight.w800, color: _warning),
          ),
        ],
      ),
    );
  }

  // FIX-2: Uses Consumer<AppThemeProvider> — calls provider.toggle() instead
  // of the removed local _toggleDark(). Visual state driven by provider.isDark
  // which is already mirrored into _isDark at the top of build().
  Widget _buildDarkToggle() {
    return Consumer<AppThemeProvider>(
      builder: (_, themeProvider, __) => GestureDetector(
        onTap: themeProvider.toggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _isDark ? const Color(0xFF334155) : _lightBlue,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
            color: _isDark ? const Color(0xFFFBBF24) : _primary,
            size:  18,
          ),
        ),
      ),
    );
  }

  // ── Tab Bar ───────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: _bg,
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: _border, width: 1))),
      child: TabBar(
        controller:              _tabController,
        isScrollable:            true,
        labelColor:              _primary,
        unselectedLabelColor:    _sub,
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: _primary, width: 3),
          insets:     EdgeInsets.symmetric(horizontal: 8),
        ),
        labelStyle: GoogleFonts.plusJakartaSans(
            fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(
            fontSize: 13, fontWeight: FontWeight.w500),
        padding:       EdgeInsets.zero,
        tabAlignment:  TabAlignment.start,
        tabs: _skills.map((skill) {
          final passed  = _passedCount(skill);
          final total   = skill.topics.length;
          final allDone = passed == total;
          return Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(skill.emoji),
                const SizedBox(width: 6),
                Text(skill.skillName),
                const SizedBox(width: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color:        allDone ? _successLt : _lightBlue,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    '$passed/$total',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: allDone ? _success : _primary),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Content router ────────────────────────────────────────────────────
  Widget _buildTabContent(int skillIdx) {
    switch (_viewFor(skillIdx)) {
      case _HubView.topicList:  return _buildTopicList(skillIdx);
      case _HubView.assessment: return _buildAssessmentView(skillIdx);
      case _HubView.result:     return _buildResultView(skillIdx);
      case _HubView.review:     return _buildReviewView(skillIdx);
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // VIEW A — TOPIC LIST
  // ──────────────────────────────────────────────────────────────────────

  Widget _buildTopicList(int skillIdx) {
    final skill  = _skills[skillIdx];
    final passed = _passedCount(skill);
    final total  = skill.topics.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProgressCard(passed, total),
          const SizedBox(height: 16),

          ...skill.topics.asMap().entries.map((entry) {
            final idx      = entry.key;
            final topic    = entry.value;
            final unlocked = _isTopicUnlocked(skill, idx);
            final score    = _topicScores[topic.id];
            final best     = _bestScores[topic.id];
            final isPassed = _isTopicPassed(topic.id);

            return AnimatedBuilder(
              animation: _listAnimCtrl,
              builder: (context, child) {
                final delay    = idx * 0.12;
                final progress =
                ((_listAnimCtrl.value - delay) / (1 - delay))
                    .clamp(0.0, 1.0);
                final curved   = Curves.easeOut.transform(progress);
                return Opacity(
                  opacity: curved,
                  child: Transform.translate(
                    offset: Offset(0, 24 * (1 - curved)),
                    child: child,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: unlocked ? () => _startAssessment(topic) : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isPassed
                            ? _success.withValues(alpha: 0.45)
                            : (unlocked && !isPassed)
                            ? _primary.withValues(alpha: 0.35)
                            : _border,
                        width: 1.5,
                      ),
                      boxShadow: _isDark
                          ? []
                          : [
                        BoxShadow(
                          color: isPassed
                              ? _success.withValues(alpha: 0.06)
                              : const Color(0x0A1A56DB),
                          blurRadius: 14,
                          offset:     const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width:  46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: isPassed
                                ? _successLt
                                : unlocked
                                ? _lightBlue
                                : (_isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Center(
                            child: isPassed
                                ? const Icon(Icons.check_circle_rounded,
                                color: _success, size: 22)
                                : unlocked
                                ? Text(topic.icon,
                                style:
                                const TextStyle(fontSize: 20))
                                : Icon(Icons.lock_rounded,
                                color: _sub, size: 20),
                          ),
                        ),
                        const SizedBox(width: 14),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                topic.name,
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize:   14,
                                    fontWeight: FontWeight.w700,
                                    color:      _text),
                              ),
                              const SizedBox(height: 4),
                              if (isPassed &&
                                  (score != null || best != null))
                                Row(children: [
                                  const Icon(Icons.star_rounded,
                                      color: _warning, size: 13),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Best: ${best ?? score}%  ·  Latest: ${score ?? best}%',
                                    style: GoogleFonts.plusJakartaSans(
                                        fontSize:   11,
                                        fontWeight: FontWeight.w600,
                                        color:      _success),
                                  ),
                                ])
                              else if (!unlocked && idx > 0)
                                Row(children: [
                                  Icon(Icons.lock_outline_rounded,
                                      color: _sub, size: 12),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      "Complete '${skill.topics[idx - 1].name}' first",
                                      style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11, color: _sub),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ])
                              else
                                Text(
                                  '${topic.questions.length} questions · ~${(topic.questions.length * _timerDuration / 60).ceil()} min',
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize:   11,
                                      fontWeight: FontWeight.w500,
                                      color:      _primary),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),

                        if (isPassed)
                          _chipButton('Retake', _success, _successLt)
                        else if (unlocked)
                          _chipButton('Start →', Colors.white, _primary)
                        else
                          Container(
                            width:  34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: _isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.lock_rounded,
                                color: _sub, size: 15),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),

          if (_allTopicsPassed(skill)) ...[
            const SizedBox(height: 8),
            _buildSkillUnlockCard(skillIdx),
          ],

          const SizedBox(height: 20),
          _buildHistoryChart(skill),
        ],
      ),
    );
  }

  Widget _chipButton(String label, Color labelColor, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
            fontSize: 12, fontWeight: FontWeight.w700, color: labelColor),
      ),
    );
  }

  Widget _buildProgressCard(int passed, int total) {
    final pct = total > 0 ? passed / total : 0.0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:        _card,
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: _border),
        boxShadow: _isDark
            ? []
            : [
          const BoxShadow(
              color:      Color(0x0D1A56DB),
              blurRadius: 20,
              offset:     Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your Progress',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 13, color: _sub)),
                const SizedBox(height: 4),
                Text(
                  '$passed of $total topics passed',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize:   18,
                      fontWeight: FontWeight.w800,
                      color:      _text),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value:           pct,
                    backgroundColor: _border,
                    color:           pct == 1.0 ? _success : _primary,
                    minHeight:       7,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          SizedBox(
            width:  68,
            height: 68,
            child: CustomPaint(
              painter: _ScoreRingPainter(
                progress:      pct,
                progressColor: pct == 1.0 ? _success : _primary,
                trackColor:    _border,
              ),
              child: Center(
                child: Text(
                  '${(pct * 100).round()}%',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize:   13,
                      fontWeight: FontWeight.w800,
                      color:      _text),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillUnlockCard(int skillIdx) {
    final skill = _skills[skillIdx];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors:  [Color(0xFF1E3A5F), Color(0xFF1A56DB)],
          begin:   Alignment.topLeft,
          end:     Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color:      _primary.withValues(alpha: 0.35),
              blurRadius: 20,
              offset:     const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width:  50,
              height: 50,
              decoration: BoxDecoration(
                color:        Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                  child: Text('🏆', style: TextStyle(fontSize: 26))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Skill Assessment Unlocked!',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize:   16,
                        fontWeight: FontWeight.w700,
                        color:      Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'All topics cleared for ${skill.skillName}. Take the final test.',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color:    Colors.white.withValues(alpha: 0.75)),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => _startSkillAssessment(skillIdx),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color:        Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color:      Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset:     const Offset(0, 3)),
                ],
              ),
              child: Text(
                'Begin Skill Assessment →',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 14, fontWeight: FontWeight.w700, color: _primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryChart(SkillAssessmentData skill) {
    const lineColors = [_primary, _success, _warning, _error, _purple];

    final lines = <LineChartBarData>[];
    for (int i = 0; i < skill.topics.length; i++) {
      final history = _history[skill.topics[i].id] ?? [];
      if (history.isEmpty) continue;
      final color = lineColors[i % lineColors.length];
      final spots = history
          .asMap()
          .entries
          .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
          .toList();
      lines.add(LineChartBarData(
        spots:   spots,
        isCurved: true,
        color:   color,
        barWidth: 2.5,
        dotData: FlDotData(
          show: true,
          getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
            radius:      3.5,
            color:       color,
            strokeWidth: 2,
            strokeColor: _card,
          ),
        ),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            begin:  Alignment.topCenter,
            end:    Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.15),
              color.withValues(alpha: 0.0),
            ],
          ),
        ),
      ));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        _card,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: _border),
        boxShadow: _isDark
            ? []
            : [
          const BoxShadow(
              color:      Color(0x0A1A56DB),
              blurRadius: 12,
              offset:     Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width:  36,
              height: 36,
              decoration: BoxDecoration(
                  color:        _lightBlue,
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.show_chart_rounded,
                  color: _primary, size: 19),
            ),
            const SizedBox(width: 10),
            Text('Score History',
                style: GoogleFonts.plusJakartaSans(
                    fontSize:   15,
                    fontWeight: FontWeight.w700,
                    color:      _text)),
          ]),
          const SizedBox(height: 14),
          if (lines.isEmpty)
            Container(
              height:    110,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bar_chart_outlined,
                      color: _sub.withValues(alpha: 0.35), size: 34),
                  const SizedBox(height: 8),
                  Text('Complete a topic to see your history',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 13, color: _sub)),
                ],
              ),
            )
          else
            SizedBox(
              height: 140,
              child: LineChart(
                LineChartData(
                  lineBarsData: lines,
                  gridData: FlGridData(
                    show:              true,
                    drawVerticalLine:  false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color:       _border,
                      strokeWidth: 1,
                      dashArray:   [4, 4],
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval:   50,
                        getTitlesWidget: (value, _) => Text(
                          '${value.toInt()}',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 9, color: _sub),
                        ),
                        reservedSize: 28,
                      ),
                    ),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  minY: 0,
                  maxY: 100,
                ),
              ),
            ),
          if (lines.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing:    14,
              runSpacing: 6,
              children: skill.topics.asMap().entries.map((e) {
                final hist = _history[e.value.id] ?? [];
                if (hist.isEmpty) return const SizedBox.shrink();
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width:  9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: lineColors[e.key % lineColors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(e.value.name,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 11, color: _sub)),
                  ],
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // VIEW B — ASSESSMENT
  // ──────────────────────────────────────────────────────────────────────

  Widget _buildAssessmentView(int skillIdx) {
    final topic = _activeTopic;
    if (topic == null) return const SizedBox.shrink();

    final q       = topic.questions[_currentQuestion];
    final total   = topic.questions.length;
    final current = _currentQuestion + 1;
    final isLast  = _currentQuestion == total - 1;
    final skill   = _skills[skillIdx];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isSkillLevel
                          ? '${skill.emoji} ${skill.skillName} · Full Assessment'
                          : '${topic.icon} ${topic.name}',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize:   12,
                          fontWeight: FontWeight.w600,
                          color:      _primary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Question $current of $total',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 13, color: _sub),
                    ),
                  ],
                ),
              ),
              _buildTimerWidget(),
            ],
          ),
          const SizedBox(height: 10),

          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value:           _currentQuestion / total,
              backgroundColor: _border,
              color:           _primary,
              minHeight:       5,
            ),
          ),
          const SizedBox(height: 10),

          _buildQuestionDots(total),
          const SizedBox(height: 20),

          // Question card
          Container(
            width:   double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color:        _card,
              borderRadius: BorderRadius.circular(18),
              border:       Border.all(color: _border),
              boxShadow: _isDark
                  ? []
                  : [
                const BoxShadow(
                    color:      Color(0x0A1A56DB),
                    blurRadius: 14,
                    offset:     Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color:        _lightBlue,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(q.subtopic,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize:   11,
                              fontWeight: FontWeight.w700,
                              color:      _primary)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _difficultyColor(q.difficulty)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        _difficultyLabel(q.difficulty),
                        style: GoogleFonts.plusJakartaSans(
                            fontSize:   10,
                            fontWeight: FontWeight.w700,
                            color:      _difficultyColor(q.difficulty)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  q.question,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize:   17,
                      fontWeight: FontWeight.w700,
                      color:      _text,
                      height:     1.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Answer options
          ...q.options.asMap().entries.map((entry) {
            final i            = entry.key;
            final option       = entry.value;
            final isSelected   = _selectedAnswer == i;
            final isCorrectAns = i == q.correctIndex;
            final showFeedback = _showResult || _timedOut;

            Color borderColor = _border;
            Color bgColor     = _card;

            if (showFeedback && isCorrectAns) {
              borderColor = _success;
              bgColor     = _successLt;
            } else if (showFeedback && isSelected && !isCorrectAns) {
              borderColor = _error;
              bgColor     = _errorLt;
            } else if (isSelected && !showFeedback) {
              borderColor = _primary;
              bgColor     = _lightBlue;
            }

            return GestureDetector(
              onTap: () => _selectAnswer(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin:   const EdgeInsets.only(bottom: 10),
                padding:  const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color:        bgColor,
                  borderRadius: BorderRadius.circular(14),
                  border:       Border.all(color: borderColor, width: 1.5),
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width:    32,
                      height:   32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: showFeedback && isCorrectAns
                            ? _success
                            : showFeedback && isSelected && !isCorrectAns
                            ? _error
                            : isSelected
                            ? _primary
                            : (_isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFF1F5F9)),
                      ),
                      child: Center(
                        child: Text(
                          ['A', 'B', 'C', 'D'][i],
                          style: GoogleFonts.plusJakartaSans(
                            fontSize:   13,
                            fontWeight: FontWeight.w700,
                            color: isSelected ||
                                (showFeedback &&
                                    (isCorrectAns ||
                                        (isSelected && !isCorrectAns)))
                                ? Colors.white
                                : _sub,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        option,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize:   14,
                            fontWeight: FontWeight.w600,
                            color:      _text),
                      ),
                    ),
                    if (showFeedback && isCorrectAns)
                      const Icon(Icons.check_circle_rounded,
                          color: _success, size: 20),
                    if (showFeedback && isSelected && !isCorrectAns)
                      const Icon(Icons.cancel_rounded,
                          color: _error, size: 20),
                  ],
                ),
              ),
            );
          }),

          if (_timedOut && !_showResult)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color:  _warningLt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _warning.withValues(alpha: 0.5)),
              ),
              child: Row(children: [
                const Icon(Icons.timer_off_rounded,
                    color: _warning, size: 16),
                const SizedBox(width: 8),
                Text("Time's up! Moving on…",
                    style: GoogleFonts.plusJakartaSans(
                        fontSize:   13,
                        fontWeight: FontWeight.w600,
                        color:      _warning)),
              ]),
            ),

          const SizedBox(height: 20),

          GestureDetector(
            onTap: (_selectedAnswer != null && !_showResult && !_timedOut)
                ? _handleSubmit
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: (_selectedAnswer != null &&
                    !_showResult &&
                    !_timedOut)
                    ? const LinearGradient(
                  colors: [Color(0xFF1A56DB), Color(0xFF3B82F6)],
                  begin:  Alignment.topLeft,
                  end:    Alignment.bottomRight,
                )
                    : null,
                color: (_selectedAnswer == null || _showResult || _timedOut)
                    ? _border
                    : null,
                borderRadius: BorderRadius.circular(14),
                boxShadow: (_selectedAnswer != null &&
                    !_showResult &&
                    !_timedOut)
                    ? [
                  const BoxShadow(
                      color:      Color(0x401A56DB),
                      blurRadius: 18,
                      offset:     Offset(0, 8)),
                ]
                    : [],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isLast ? 'Submit Answers' : 'Next Question →',
                    style: GoogleFonts.plusJakartaSans(
                      color: (_selectedAnswer != null &&
                          !_showResult &&
                          !_timedOut)
                          ? Colors.white
                          : _sub,
                      fontSize:   15,
                      fontWeight: FontWeight.w700,
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

  Widget _buildTimerWidget() {
    final progress = _timerDuration > 0
        ? (_timeLeft / _timerDuration).clamp(0.0, 1.0)
        : 0.0;
    final timerColor = _timeLeft > 15
        ? _primary
        : _timeLeft > 8
        ? _warning
        : _error;

    return SizedBox(
      width:  54,
      height: 54,
      child: CustomPaint(
        painter: _TimerRingPainter(progress: progress, color: timerColor),
        child: Center(
          child: Text(
            '$_timeLeft',
            style: GoogleFonts.plusJakartaSans(
                fontSize:   15,
                fontWeight: FontWeight.w800,
                color:      timerColor),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionDots(int total) {
    return Center(
      child: Wrap(
        spacing: 5,
        children: List.generate(total, (i) {
          Color  color;
          double width = 8;

          if (i == _currentQuestion) {
            color = _primary;
            width = 18;
          } else if (i < _currentQuestion) {
            final answered = _sessionAnswers[i];
            final q        = _activeTopic!.questions[i];
            color = (answered == q.correctIndex) ? _success : _error;
          } else {
            color = _border;
          }

          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width:  width,
            height: 8,
            decoration: BoxDecoration(
              color:        color,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // VIEW C — RESULT
  // ──────────────────────────────────────────────────────────────────────

  Widget _buildResultView(int skillIdx) {
    final passed  = _resultScore >= 70;
    final total   = _activeTopic?.questions.length ?? 5;
    final correct = _resultCorrect;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          child: Column(
            children: [
              ScaleTransition(
                scale: _scoreAnim,
                child: AnimatedBuilder(
                  animation: _ringAnim,
                  builder: (context, child) => SizedBox(
                    width:  150,
                    height: 150,
                    child: CustomPaint(
                      painter: _ScoreRingPainter(
                        progress:      _ringAnim.value * _resultScore / 100,
                        progressColor: passed ? _success : _error,
                        trackColor:    _border,
                      ),
                      child: child,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$_resultScore%',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize:   30,
                              fontWeight: FontWeight.w900,
                              color:      passed ? _success : _error),
                        ),
                        _buildGradeBadge(_grade),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
              Text(
                passed ? '🎉 Excellent Work!' : '📚 Keep Pushing!',
                style: GoogleFonts.plusJakartaSans(
                    fontSize:   22,
                    fontWeight: FontWeight.w800,
                    color:      _text),
              ),
              const SizedBox(height: 8),
              Text(
                passed
                    ? 'You passed! The next topic is now unlocked.'
                    : 'Score at least 70% to unlock the next topic.',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 14, color: _sub, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color:        _card,
                  borderRadius: BorderRadius.circular(16),
                  border:       Border.all(color: _border),
                  boxShadow: _isDark
                      ? []
                      : [
                    const BoxShadow(
                        color:      Color(0x0A1A56DB),
                        blurRadius: 12,
                        offset:     Offset(0, 3)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _resultStat('Correct', '$correct/$total', _success),
                    Container(width: 1, height: 40, color: _border),
                    _resultStat('Score', '$_resultScore%',
                        _resultScore >= 70 ? _success : _error),
                    Container(width: 1, height: 40, color: _border),
                    _resultStat('Best Streak', '🔥$_maxStreak', _warning),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              if (_subtopicScores.isNotEmpty) ...[
                _buildSubtopicBreakdown(),
                const SizedBox(height: 16),
              ],

              GestureDetector(
                onTap: passed
                    ? _backToHub
                    : () {
                  final t = _activeTopic;
                  if (t != null) {
                    _startAssessment(t, skillLevel: _isSkillLevel);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A56DB), Color(0xFF3B82F6)],
                      begin:  Alignment.topLeft,
                      end:    Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                          color:      Color(0x401A56DB),
                          blurRadius: 18,
                          offset:     Offset(0, 8)),
                    ],
                  ),
                  child: Text(
                    passed ? 'Continue to Next Topic →' : '↺  Try Again',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                        color:      Colors.white,
                        fontSize:   15,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              GestureDetector(
                onTap: () => setState(
                        () => _tabViews[_activeSkillIdx] = _HubView.review),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    border:       Border.all(color: _primary, width: 1.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.rate_review_rounded,
                          color: _primary, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Review Answers',
                        style: GoogleFonts.plusJakartaSans(
                            color:      _primary,
                            fontSize:   15,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              GestureDetector(
                onTap: _backToHub,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Back to Hub',
                    style: GoogleFonts.plusJakartaSans(
                        color:      _sub,
                        fontSize:   14,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),

        if (_particles.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _confettiCtrl,
                builder: (context, _) => CustomPaint(
                  painter: _ConfettiPainter(
                    particles: _particles,
                    t:         _confettiCtrl.value,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGradeBadge(String grade) {
    final color = _gradeColor(grade);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(100),
        border:       Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        'Grade $grade',
        style: GoogleFonts.plusJakartaSans(
            fontSize:   11,
            fontWeight: FontWeight.w800,
            color:      color),
      ),
    );
  }

  Widget _buildSubtopicBreakdown() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        _card,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width:  34,
              height: 34,
              decoration: BoxDecoration(
                  color:        _lightBlue,
                  borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.analytics_outlined,
                  color: _primary, size: 18),
            ),
            const SizedBox(width: 10),
            Text('Score by Subtopic',
                style: GoogleFonts.plusJakartaSans(
                    fontSize:   15,
                    fontWeight: FontWeight.w700,
                    color:      _text)),
          ]),
          const SizedBox(height: 14),
          ..._subtopicScores.entries.map((entry) {
            final subtopic = entry.key;
            final c        = entry.value[0];
            final t        = entry.value[1];
            final pct      = t > 0 ? c / t : 0.0;
            final color    = pct >= 0.7
                ? _success
                : pct >= 0.4
                ? _warning
                : _error;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(subtopic,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize:   13,
                              fontWeight: FontWeight.w600,
                              color:      _text)),
                    ),
                    Text('$c/$t correct',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize:   12,
                            fontWeight: FontWeight.w700,
                            color:      color)),
                  ]),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value:           pct,
                      backgroundColor: _border,
                      color:           color,
                      minHeight:       7,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _resultStat(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
              fontSize: 19, fontWeight: FontWeight.w800, color: color),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _sub)),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // VIEW D — REVIEW
  // ──────────────────────────────────────────────────────────────────────

  Widget _buildReviewView(int skillIdx) {
    final topic = _activeTopic;
    if (topic == null) return const SizedBox.shrink();

    final correctTotal = _sessionAnswers.entries
        .where((e) =>
    e.value != null &&
        e.value == topic.questions[e.key].correctIndex)
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:        _card,
              borderRadius: BorderRadius.circular(14),
              border:       Border.all(color: _border),
            ),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Answer Review',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize:   16,
                            fontWeight: FontWeight.w800,
                            color:      _text)),
                    const SizedBox(height: 4),
                    Text(
                      '$correctTotal of ${topic.questions.length} correct',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 13, color: _sub),
                    ),
                  ],
                ),
              ),
              _buildGradeBadge(_grade),
            ]),
          ),
          const SizedBox(height: 16),

          ...topic.questions.asMap().entries.map((entry) {
            final idx        = entry.key;
            final q          = entry.value;
            final userAnswer = _sessionAnswers[idx];
            final isCorrect  =
                userAnswer != null && userAnswer == q.correctIndex;
            final skipped    = userAnswer == null;
            return _buildReviewCard(idx, q, userAnswer, isCorrect, skipped);
          }),
        ],
      ),
    );
  }

  Widget _buildReviewCard(
      int idx,
      McqQuestion q,
      int? userAnswer,
      bool isCorrect,
      bool skipped,
      ) {
    final statusColor = isCorrect
        ? _success
        : skipped
        ? _warning
        : _error;
    final statusLabel = isCorrect
        ? 'Correct'
        : skipped
        ? 'Timed Out'
        : 'Incorrect';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color:        _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: statusColor.withValues(alpha: 0.4), width: 1.5),
        boxShadow: _isDark
            ? []
            : [
          BoxShadow(
              color:      statusColor.withValues(alpha: 0.05),
              blurRadius: 10,
              offset:     const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.07),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:        statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'Q${idx + 1} · $statusLabel',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize:   11,
                      fontWeight: FontWeight.w700,
                      color:      statusColor),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _difficultyColor(q.difficulty)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '${_difficultyLabel(q.difficulty)} · ${q.subtopic}',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize:   10,
                      fontWeight: FontWeight.w600,
                      color:      _difficultyColor(q.difficulty)),
                ),
              ),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  q.question,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize:   14,
                      fontWeight: FontWeight.w700,
                      color:      _text,
                      height:     1.45),
                ),
                const SizedBox(height: 12),

                ...q.options.asMap().entries.map((e) {
                  final i            = e.key;
                  final isCorrectOpt = i == q.correctIndex;
                  final isUserOpt    = i == userAnswer;

                  Color bg     = _isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF8FAFC);
                  Color border = _border;

                  if (isCorrectOpt) {
                    bg     = _successLt;
                    border = _success;
                  } else if (isUserOpt && !isCorrect) {
                    bg     = _errorLt;
                    border = _error;
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 7),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color:        bg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: border,
                          width: isCorrectOpt || isUserOpt ? 1.5 : 1),
                    ),
                    child: Row(children: [
                      Container(
                        width:  24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCorrectOpt
                              ? _success
                              : (isUserOpt && !isCorrect)
                              ? _error
                              : _border,
                        ),
                        child: Center(
                          child: Text(
                            ['A', 'B', 'C', 'D'][i],
                            style: GoogleFonts.plusJakartaSans(
                              fontSize:   11,
                              fontWeight: FontWeight.w700,
                              color: (isCorrectOpt ||
                                  (isUserOpt && !isCorrect))
                                  ? Colors.white
                                  : _sub,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(e.value,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize:   13,
                                fontWeight: FontWeight.w500,
                                color:      _text)),
                      ),
                      if (isCorrectOpt)
                        const Icon(Icons.check_circle_rounded,
                            color: _success, size: 18),
                      if (isUserOpt && !isCorrect)
                        const Icon(Icons.cancel_rounded,
                            color: _error, size: 18),
                    ]),
                  );
                }),

                if (q.explanation != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isDark
                          ? const Color(0xFF1E3A2F)
                          : const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: _success.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lightbulb_rounded,
                              color: _warning, size: 15),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(q.explanation!,
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color:    _sub,
                                    height:   1.5)),
                          ),
                        ]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}