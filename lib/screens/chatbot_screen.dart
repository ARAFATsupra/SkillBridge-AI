// lib/screens/chatbot_screen.dart
//
// FIXED:
//   • _isDark is now a getter that reads the global MaterialApp theme —
//     no more local bool state / duplicate toggle button.
//   • Removed _buildDarkToggle() and its AppBar entry.
//   • All original logic, models, bot engine, and cards preserved exactly.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Models — PRESERVED EXACTLY ───────────────────────────────────────────────

enum _Sender { user, bot }

class _Message {
  final String id;
  final _Sender sender;
  final String text;
  final DateTime time;
  final List<_InlineCard>? cards;
  final String? actionLabel;
  final VoidCallback? onAction = null;

  _Message({
    required this.id,
    required this.sender,
    required this.text,
    required this.time,
    this.cards,
    this.actionLabel,
  });
}

abstract class _InlineCard {
  String get title;
}

class _JobCard implements _InlineCard {
  @override final String title;
  final String company, location;
  final int matchPct;
  final String salary;

  const _JobCard({
    required this.title,
    required this.company,
    required this.location,
    required this.matchPct,
    required this.salary,
  });
}

class _CourseCard implements _InlineCard {
  @override final String title;
  final String provider, format, duration;
  final double rating;

  const _CourseCard({
    required this.title,
    required this.provider,
    required this.format,
    required this.duration,
    required this.rating,
  });
}

class _SkillGapCard implements _InlineCard {
  @override final String title;
  final String priority;
  final double importance;

  const _SkillGapCard({
    required this.title,
    required this.priority,
    required this.importance,
  });
}

// ── Bot Response Engine — PRESERVED EXACTLY ──────────────────────────────────

_Message _botResponse(String input, int idx) {
  final lower = input.toLowerCase();
  final now   = DateTime.now();

  if (lower.contains('top job') || lower.contains('job for me')) {
    return _Message(
      id: 'b$idx', sender: _Sender.bot, time: now,
      text: 'Based on your profile as a Data Analyst, here are your top matches:',
      actionLabel: 'View All Jobs →',
      cards: const [
        _JobCard(title: 'Data Scientist',  company: 'Chaldal', location: 'Dhaka',  matchPct: 92, salary: '90k–120k BDT'),
        _JobCard(title: 'BI Developer',    company: 'bKash',   location: 'Dhaka',  matchPct: 87, salary: '80k–100k BDT'),
        _JobCard(title: 'ML Engineer',     company: 'Pathao',  location: 'Remote', matchPct: 81, salary: '100k–130k BDT'),
      ],
    );
  }

  if (lower.contains('missing') || lower.contains('skill gap') || lower.contains('what skill')) {
    return _Message(
      id: 'b$idx', sender: _Sender.bot, time: now,
      text: 'Based on your target role (Data Scientist), here are your top skill gaps:',
      cards: const [
        _SkillGapCard(title: 'Machine Learning',            priority: '🔴 Must Learn',   importance: 0.95),
        _SkillGapCard(title: 'Python (Advanced)',           priority: '🔴 Must Learn',   importance: 0.92),
        _SkillGapCard(title: 'Statistical Modeling',        priority: '🟠 Learn Soon',   importance: 0.80),
        _SkillGapCard(title: 'Deep Learning (TF/PyTorch)',  priority: '🟠 Learn Soon',   importance: 0.75),
        _SkillGapCard(title: 'Feature Engineering',         priority: '🟡 Nice to Have', importance: 0.65),
      ],
    );
  }

  if (lower.contains('course') || lower.contains('recommend course')) {
    return _Message(
      id: 'b$idx', sender: _Sender.bot, time: now,
      text: 'Here are top-rated courses matched to your skill gaps:',
      actionLabel: 'Browse All Courses →',
      cards: const [
        _CourseCard(
          title: 'Machine Learning Specialization',
          provider: 'Coursera (Stanford)',
          format: 'Video + Quizzes',
          duration: '3 months',
          rating: 4.9,
        ),
        _CourseCard(
          title: 'Python for Data Science',
          provider: 'DataCamp',
          format: 'Interactive Coding',
          duration: '6 weeks',
          rating: 4.7,
        ),
      ],
    );
  }

  if (lower.contains('career path') || lower.contains('path advice')) {
    return _Message(
      id: 'b$idx', sender: _Sender.bot, time: now,
      text: 'Here\'s your recommended career transition path:\n\n'
          '📍 Data Analyst\n'
          '     ↓ Learn: Machine Learning, Python (Advanced)\n'
          '🔷 Junior Data Scientist  (~3 months)\n'
          '     ↓ Learn: Deep Learning, Feature Engineering\n'
          '🏆 Data Scientist  (~6 months)\n\n'
          'Estimated total time: 6–9 months with consistent effort.',
      actionLabel: 'See Full Roadmap →',
    );
  }

  if (lower.contains('confidence')) {
    return _Message(
      id: 'b$idx', sender: _Sender.bot, time: now,
      text: '📊 Your current career confidence score:\n\n'
          '   Overall: 59.4% — Moderate\n\n'
          '   💡 Tip: Your Salary Negotiation score is lowest (42%). '
          'Research market rates before your next interview — this alone can boost offers by 10–20%.',
    );
  }

  if (lower.contains('explain') || lower.contains('why match')) {
    return _Message(
      id: 'b$idx', sender: _Sender.bot, time: now,
      text: '🔍 Why Data Scientist matches you (92%):\n\n'
          '✅ You have: SQL, Tableau, Excel, Python (Basic)\n'
          '📈 Strong match: Statistics background\n'
          '🎯 Gap: Machine Learning, Advanced Python\n'
          '💰 Salary uplift: +₺30k BDT vs current\n\n'
          'This is a Medium difficulty transition (~6 months).',
    );
  }

  return _Message(
    id: 'b$idx', sender: _Sender.bot, time: now,
    text: "I'm not sure about that, but I can help with:\n"
        "• 💼 Job recommendations — try 'top jobs for me'\n"
        "• 📊 Skill gap analysis — try 'what skills am I missing?'\n"
        "• 📚 Course suggestions — try 'recommend a course'\n"
        "• 🛤️ Career path — try 'give me career path advice'",
  );
}

// Quick replies — PRESERVED EXACTLY
const List<({String emoji, String text})> _quickReplies = [
  (emoji: '💼', text: 'Top Jobs'),
  (emoji: '📊', text: 'Skill Gap'),
  (emoji: '📚', text: 'Course Rec.'),
  (emoji: '🛤️', text: 'Career Path'),
  (emoji: '💪', text: 'My Confidence'),
];

const Map<String, String> _quickReplyFull = {
  'Top Jobs':      'Top jobs for me',
  'Skill Gap':     'What skills am I missing?',
  'Course Rec.':   'Recommend a course',
  'Career Path':   'Career path advice',
  'My Confidence': 'My confidence score',
};

// ── Design Tokens — PRESERVED EXACTLY ────────────────────────────────────────

const _primaryBlue  = Color(0xFF2563EB);
const _accentBlue   = Color(0xFF3B82F6);
const _blue50       = Color(0xFFEFF6FF);
const _success      = Color(0xFF10B981);
const _warning      = Color(0xFFF59E0B);

const _bgLight     = Color(0xFFFFFFFF);
const _cardLight   = Color(0xFFFFFFFF);
const _textLight   = Color(0xFF0F172A);
const _subLight    = Color(0xFF64748B);
const _borderLight = Color(0xFFE2E8F0);

const _bgDark     = Color(0xFF0F172A);
const _cardDark   = Color(0xFF1E293B);
const _textDark   = Color(0xFFF1F5F9);
const _subDark    = Color(0xFF94A3B8);
const _borderDark = Color(0xFF334155);

// ── Priority colour helper ────────────────────────────────────────────────────

Color _priorityColor(String priority) {
  if (priority.contains('🔴')) return const Color(0xFFDC2626);
  if (priority.contains('🟠')) return const Color(0xFFEA580C);
  if (priority.contains('🟡')) return const Color(0xFFD97706);
  return _primaryBlue;
}

// ══════════════════════════════════════════════════════════════════════════════
// ANIMATION HELPERS
// ══════════════════════════════════════════════════════════════════════════════

/// Tactile press-scale wrapper: 0.97× on TapDown, restores on TapUp.
class _PressScaleWidget extends StatefulWidget {
  final Widget       child;
  final VoidCallback onTap;

  const _PressScaleWidget({required this.child, required this.onTap});

  @override
  State<_PressScaleWidget> createState() => _PressScaleWidgetState();
}

class _PressScaleWidgetState extends State<_PressScaleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown:   (_) => _ctrl.forward(),
    onTapUp:     (_) {
      _ctrl.reverse();
      HapticFeedback.lightImpact();
      widget.onTap();
    },
    onTapCancel: ()  => _ctrl.reverse(),
    child: ScaleTransition(scale: _scale, child: widget.child),
  );
}

/// Animated horizontal progress bar (0 → value) on first mount.
class _AnimatedLinearBar extends StatelessWidget {
  final double value;
  final Color  barColor;
  final Color  bgColor;
  final double height;

  const _AnimatedLinearBar({
    required this.value,
    required this.barColor,
    required this.bgColor,
    this.height = 6.0,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween:    Tween<double>(begin: 0.0, end: value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 900),
      curve:    Curves.easeOutCubic,
      builder:  (_, v, __) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value:           v,
          minHeight:       height,
          backgroundColor: bgColor,
          valueColor:      AlwaysStoppedAnimation<Color>(barColor),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final List<_Message>        _messages   = [];
  final TextEditingController _inputCtrl  = TextEditingController();
  final ScrollController      _scroll     = ScrollController();
  final FocusNode             _inputFocus = FocusNode();

  bool _isTyping      = false;
  bool _inputFocused  = false;
  bool _showScrollFab = false;
  int  _msgIdx        = 0;

  // ── Theme — reads from the global MaterialApp theme ───────────────────────
  // FIX: Was a mutable local bool with a duplicate toggle button.
  //      Now reads the app-wide theme so the global toggle controls this screen.
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  // ── Color getters — unchanged ──────────────────────────────────────────────
  Color get _bg           => _isDark ? _bgDark                    : _bgLight;
  Color get _card         => _isDark ? _cardDark                  : _cardLight;
  Color get _text         => _isDark ? _textDark                  : _textLight;
  Color get _sub          => _isDark ? _subDark                   : _subLight;
  Color get _border       => _isDark ? _borderDark                : _borderLight;
  Color get _lightBlue    => _isDark ? const Color(0xFF1E3A5F)    : _blue50;
  Color get _inlineSurface => _isDark ? const Color(0xFF0F172A)   : const Color(0xFFF8FAFF);

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _messages.add(_Message(
      id: 'welcome', sender: _Sender.bot, time: DateTime.now(),
      text: "Hi! I'm your SkillBridge AI career assistant. I can help you with:\n\n"
          "• Job recommendations 💼\n"
          "• Skill gap analysis 📊\n"
          "• Course suggestions 📚\n"
          "• Career path advice 🛤️\n\n"
          "What would you like to explore?",
    ));

    _inputCtrl.addListener(() => setState(() {}));

    _inputFocus.addListener(() {
      if (mounted) setState(() => _inputFocused = _inputFocus.hasFocus);
    });

    _scroll.addListener(() {
      if (!_scroll.hasClients) return;
      final atBottom =
          _scroll.offset >= (_scroll.position.maxScrollExtent - 120);
      if (mounted && _showScrollFab == atBottom) {
        setState(() => _showScrollFab = !atBottom);
      }
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scroll.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  // ── Send — PRESERVED EXACTLY ───────────────────────────────────────────────
  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    _inputCtrl.clear();
    _inputFocus.unfocus();
    HapticFeedback.mediumImpact();

    final userMsg = _Message(
      id:     'u${_msgIdx++}',
      sender: _Sender.user,
      text:   text.trim(),
      time:   DateTime.now(),
    );
    setState(() {
      _messages.add(userMsg);
      _isTyping = true;
    });
    _scrollToBottom();

    await Future.delayed(const Duration(milliseconds: 800));

    final botMsg = _botResponse(text, _msgIdx++);
    setState(() {
      _isTyping = false;
      _messages.add(botMsg);
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: 300.ms,
          curve:    Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final hasText   = _inputCtrl.text.trim().isNotEmpty;
    final charCount = _inputCtrl.text.length;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: _bg,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _buildAppBar(),
        floatingActionButton:
        _showScrollFab ? _buildScrollFab() : null,
        floatingActionButtonLocation:
        FloatingActionButtonLocation.endFloat,
        body: Column(children: [
          Expanded(child: _buildChatArea()),
          _buildQuickReplies(),
          _buildInputRow(hasText, charCount),
        ]),
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────
  // FIX: Removed duplicate _buildDarkToggle() from actions.
  //      The global toggle in main_nav / AppBar handles theme switching.
  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor:        _bg,
    elevation:              0,
    scrolledUnderElevation: 0,
    foregroundColor:        _text,
    leading: IconButton(
      icon:      Icon(Icons.arrow_back_rounded, color: _text, size: 22),
      onPressed: () => Navigator.maybePop(context),
    ),
    titleSpacing: 0,
    title: Row(children: [
      // AI avatar
      Container(
        width:  38,
        height: 38,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_primaryBlue, _accentBlue],
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(
            color:      _primaryBlue.withValues(alpha: 0.40),
            blurRadius: 12,
            offset:     const Offset(0, 3),
          )],
        ),
        child: Center(
          child: Text(
            'AI',
            style: GoogleFonts.plusJakartaSans(
              color:      Colors.white,
              fontSize:   13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SkillBridge Assistant',
            style: GoogleFonts.plusJakartaSans(
              fontSize:   15,
              fontWeight: FontWeight.w700,
              color:      _text,
            ),
          ),
          Row(children: [
            Container(
              width:  8,
              height: 8,
              decoration: const BoxDecoration(
                  color: _success, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(
              'Online · Powered by AI',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _sub),
            ),
          ]),
        ],
      ),
    ]),
    actions: [
      IconButton(
        icon:      Icon(Icons.more_vert_rounded, color: _sub, size: 22),
        onPressed: () {},
      ),
    ],
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: _border),
    ),
  );

  // ── Scroll-to-bottom FAB ───────────────────────────────────────────────────
  Widget _buildScrollFab() => Padding(
    padding: const EdgeInsets.only(bottom: 130),
    child: Semantics(
      label: 'Scroll to latest message',
      button: true,
      child: _PressScaleWidget(
        onTap: _scrollToBottom,
        child: Container(
          width:  40,
          height: 40,
          decoration: BoxDecoration(
            color:  _card,
            shape:  BoxShape.circle,
            border: Border.all(color: _border),
            boxShadow: [BoxShadow(
              color:      _isDark
                  ? Colors.black.withValues(alpha: 0.4)
                  : Colors.black.withValues(alpha: 0.10),
              blurRadius: 12,
              offset:     const Offset(0, 4),
            )],
          ),
          child: Icon(Icons.keyboard_arrow_down_rounded, color: _sub, size: 22),
        ),
      ),
    ),
  );

  // ── Chat Area ──────────────────────────────────────────────────────────────
  Widget _buildChatArea() => ListView.builder(
    controller: _scroll,
    padding:    const EdgeInsets.all(16),
    itemCount:  _messages.length + (_isTyping ? 1 : 0),
    itemBuilder: (_, i) {
      if (_isTyping && i == _messages.length) {
        return _buildTypingIndicator();
      }
      final msg = _messages[i];
      return _buildMessageBubble(msg)
          .animate()
          .fadeIn(duration: 300.ms)
          .slideY(begin: 0.06, end: 0, curve: Curves.easeOut);
    },
  );

  // ── Message Bubble ─────────────────────────────────────────────────────────
  Widget _buildMessageBubble(_Message msg) {
    final isUser = msg.sender == _Sender.user;
    return Semantics(
      label: '${isUser ? "You" : "SkillBridge AI"}: ${msg.text}. '
          'Sent at ${_formatTime(msg.time)}.',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment:
          isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              _buildBotAvatar(size: 32),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.72,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: isUser
                          ? const LinearGradient(
                        colors: [_primaryBlue, _accentBlue],
                        begin:  Alignment.topLeft,
                        end:    Alignment.bottomRight,
                      )
                          : null,
                      color:        isUser ? null : _card,
                      borderRadius: BorderRadius.only(
                        topLeft:     const Radius.circular(18),
                        topRight:    const Radius.circular(18),
                        bottomLeft:  Radius.circular(isUser ? 18 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 18),
                      ),
                      border: isUser
                          ? null
                          : Border.all(color: _border, width: 1),
                      boxShadow: isUser
                          ? [BoxShadow(
                        color:      _primaryBlue.withValues(alpha: 0.30),
                        blurRadius: 14,
                        offset:     const Offset(0, 5),
                      )]
                          : [BoxShadow(
                        color:      _isDark
                            ? Colors.black.withValues(alpha: 0.25)
                            : const Color(0xFF0F172A).withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset:     const Offset(0, 2),
                      )],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.text,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize:   14,
                            fontWeight: FontWeight.w500,
                            height:     1.6,
                            color:      isUser ? Colors.white : _text,
                          ),
                        ),
                        if (msg.cards != null) ...[
                          const SizedBox(height: 12),
                          ...msg.cards!.map((c) => _buildInlineCard(c)),
                        ],
                        if (msg.actionLabel != null) ...[
                          const SizedBox(height: 12),
                          _PressScaleWidget(
                            onTap: msg.onAction ?? () {},
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 9),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [_primaryBlue, _accentBlue],
                                  begin:  Alignment.centerLeft,
                                  end:    Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [BoxShadow(
                                  color:      _primaryBlue.withValues(alpha: 0.30),
                                  blurRadius: 8,
                                  offset:     const Offset(0, 3),
                                )],
                              ),
                              child: Text(
                                msg.actionLabel!,
                                style: GoogleFonts.plusJakartaSans(
                                  color:      Colors.white,
                                  fontSize:   13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(msg.time),
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 10, color: _sub),
                      ),
                      if (isUser) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.done_all_rounded,
                            size: 13, color: _accentBlue),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (isUser) ...[
              const SizedBox(width: 8),
              Container(
                width:  32,
                height: 32,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primaryBlue, _accentBlue],
                    begin:  Alignment.topLeft,
                    end:    Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    'ME',
                    style: GoogleFonts.plusJakartaSans(
                      color:      Colors.white,
                      fontSize:   10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Bot Avatar ─────────────────────────────────────────────────────────────
  Widget _buildBotAvatar({required double size}) => Container(
    width:  size,
    height: size,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF1E3A5F), _primaryBlue],
        begin:  Alignment.topLeft,
        end:    Alignment.bottomRight,
      ),
      shape: BoxShape.circle,
      boxShadow: [BoxShadow(
        color:      _primaryBlue.withValues(alpha: 0.25),
        blurRadius: 8,
        offset:     const Offset(0, 2),
      )],
    ),
    child: Center(
      child: Text(
        'AI',
        style: GoogleFonts.plusJakartaSans(
          color:      Colors.white,
          fontSize:   size * 0.34,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );

  // ── Inline Card Router ─────────────────────────────────────────────────────
  Widget _buildInlineCard(_InlineCard card) {
    if (card is _JobCard)      return _buildJobCard(card);
    if (card is _CourseCard)   return _buildCourseCard(card);
    if (card is _SkillGapCard) return _buildSkillGapCard(card);
    return Text(card.title,
        style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _text));
  }

  // ── Job Card ───────────────────────────────────────────────────────────────
  Widget _buildJobCard(_JobCard card) {
    final matchColor = card.matchPct >= 90
        ? _success
        : card.matchPct >= 80
        ? _primaryBlue
        : _sub;

    return Container(
      margin:  const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        _inlineSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: _primaryBlue.withValues(alpha: 0.20), width: 1),
        boxShadow: [BoxShadow(
          color:      _isDark
              ? Colors.black.withValues(alpha: 0.2)
              : Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset:     const Offset(0, 2),
        )],
      ),
      child: Row(children: [
        Container(
          width:  40,
          height: 40,
          decoration: BoxDecoration(
            color:        _lightBlue,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: _primaryBlue.withValues(alpha: 0.15)),
          ),
          child: const Icon(Icons.business_rounded,
              color: _primaryBlue, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                card.title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize:   13,
                  fontWeight: FontWeight.w700,
                  color:      _text,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(children: [
                Icon(Icons.location_on_outlined, size: 10, color: _sub),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    '${card.company} · ${card.location}',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, color: _sub),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color:        _success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  card.salary,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize:   10,
                    fontWeight: FontWeight.w600,
                    color:      _success,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          children: [
            Container(
              width:  46,
              height: 46,
              decoration: BoxDecoration(
                color:  matchColor.withValues(alpha: 0.10),
                shape:  BoxShape.circle,
                border: Border.all(
                    color: matchColor.withValues(alpha: 0.35),
                    width: 1.5),
              ),
              child: Center(
                child: Text(
                  '${card.matchPct}%',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize:   11,
                    fontWeight: FontWeight.w800,
                    color:      matchColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text('match',
                style: GoogleFonts.plusJakartaSans(fontSize: 9, color: _sub)),
          ],
        ),
      ]),
    );
  }

  // ── Course Card ────────────────────────────────────────────────────────────
  Widget _buildCourseCard(_CourseCard card) {
    final fullStars = card.rating.floor();
    final halfStar  = (card.rating - fullStars) >= 0.5;

    return Container(
      margin:  const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        _inlineSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: _primaryBlue.withValues(alpha: 0.20), width: 1),
        boxShadow: [BoxShadow(
          color:      _isDark
              ? Colors.black.withValues(alpha: 0.2)
              : Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset:     const Offset(0, 2),
        )],
      ),
      child: Row(children: [
        Container(
          width:  40,
          height: 40,
          decoration: BoxDecoration(
            color:        _lightBlue,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: _primaryBlue.withValues(alpha: 0.15)),
          ),
          child: const Icon(Icons.play_circle_outline_rounded,
              color: _primaryBlue, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                card.title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize:   13,
                  fontWeight: FontWeight.w700,
                  color:      _text,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${card.provider} · ${card.duration}',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, color: _sub),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 5),
              Row(children: [
                ...List.generate(5, (i) {
                  final IconData ico;
                  if (i < fullStars) {
                    ico = Icons.star_rounded;
                  } else if (i == fullStars && halfStar) {
                    ico = Icons.star_half_rounded;
                  } else {
                    ico = Icons.star_outline_rounded;
                  }
                  return Icon(ico, size: 12, color: _warning);
                }),
                const SizedBox(width: 4),
                Text(
                  card.rating.toStringAsFixed(1),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize:   11,
                    fontWeight: FontWeight.w700,
                    color:      _text,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color:        _lightBlue,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    card.format,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize:   9,
                      fontWeight: FontWeight.w600,
                      color:      _primaryBlue,
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ]),
    );
  }

  // ── Skill Gap Card ─────────────────────────────────────────────────────────
  Widget _buildSkillGapCard(_SkillGapCard card) {
    final priorityColor = _priorityColor(card.priority);
    final barBg = _isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.grey.shade200;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Container(
            width:  8,
            height: 8,
            margin: const EdgeInsets.only(right: 8, top: 2),
            decoration: BoxDecoration(
              color:  priorityColor,
              shape:  BoxShape.circle,
              boxShadow: [BoxShadow(
                color:      priorityColor.withValues(alpha: 0.40),
                blurRadius: 4,
              )],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      card.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize:   13,
                        fontWeight: FontWeight.w600,
                        color:      _text,
                      ),
                    ),
                  ),
                  Text(
                    '${(card.importance * 100).round()}%',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize:   11,
                      fontWeight: FontWeight.w700,
                      color:      priorityColor,
                    ),
                  ),
                ]),
                const SizedBox(height: 3),
                Text(
                  card.priority,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, color: _sub),
                ),
                const SizedBox(height: 6),
                _AnimatedLinearBar(
                  value:    card.importance,
                  barColor: priorityColor,
                  bgColor:  barBg,
                  height:   6,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Typing Indicator ───────────────────────────────────────────────────────
  Widget _buildTypingIndicator() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      _buildBotAvatar(size: 32),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: const BorderRadius.only(
            topLeft:     Radius.circular(4),
            topRight:    Radius.circular(18),
            bottomLeft:  Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(color: _border, width: 1),
          boxShadow: [BoxShadow(
            color:      _isDark
                ? Colors.black.withValues(alpha: 0.20)
                : const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 10,
            offset:     const Offset(0, 2),
          )],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width:  8,
              height: 8,
              decoration: const BoxDecoration(
                  color: _primaryBlue, shape: BoxShape.circle),
            )
                .animate(onPlay: (c) => c.repeat())
                .scaleXY(
              delay:    Duration(milliseconds: i * 180),
              duration: const Duration(milliseconds: 400),
              begin:    0.6,
              end:      1.0,
              curve:    Curves.easeInOut,
            )
                .then()
                .scaleXY(
              duration: const Duration(milliseconds: 400),
              begin:    1.0,
              end:      0.6,
              curve:    Curves.easeInOut,
            );
          }),
        ),
      ),
    ]),
  );

  // ── Quick Replies ──────────────────────────────────────────────────────────
  Widget _buildQuickReplies() => Container(
    color: _bg,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: _border, width: 1)),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _quickReplies.map((chip) {
          return Semantics(
            label:  chip.text,
            button: true,
            child: _PressScaleWidget(
              onTap: () => _send(_quickReplyFull[chip.text] ?? chip.text),
              child: Container(
                margin:  const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color:        _card,
                  borderRadius: BorderRadius.circular(100),
                  border:       Border.all(color: _border, width: 1.5),
                  boxShadow: [BoxShadow(
                    color:      _isDark
                        ? Colors.black.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset:     const Offset(0, 2),
                  )],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(chip.emoji, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 5),
                    Text(
                      chip.text,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize:   13,
                        fontWeight: FontWeight.w600,
                        color:      _text,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ),
  );

  // ── Input Row ──────────────────────────────────────────────────────────────
  Widget _buildInputRow(bool hasText, int charCount) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPad   = (bottomInset + 16).clamp(16.0, double.infinity);

    return Container(
      color:   _bg,
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPad),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _border, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (charCount >= 80)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, right: 56),
              child: Text(
                '$charCount chars',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  color:    charCount > 300 ? Colors.red : _sub,
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color:        _card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _inputFocused ? _primaryBlue : _border,
                      width: 1.5,
                    ),
                    boxShadow: _inputFocused
                        ? [BoxShadow(
                      color:      _primaryBlue.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset:     const Offset(0, 2),
                    )]
                        : [],
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Semantics(
                          label:     'Type your message',
                          textField: true,
                          child: TextField(
                            controller:        _inputCtrl,
                            focusNode:         _inputFocus,
                            minLines:          1,
                            maxLines:          4,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 14, color: _text),
                            textCapitalization:
                            TextCapitalization.sentences,
                            onSubmitted: _send,
                            decoration: InputDecoration(
                              hintText:  'Ask me anything...',
                              hintStyle: GoogleFonts.plusJakartaSans(
                                  fontSize: 14, color: _sub),
                              border:   InputBorder.none,
                              isDense:  true,
                            ),
                          ),
                        ),
                      ),
                      Icon(Icons.mic_rounded,
                          color: _sub.withValues(alpha: 0.5),
                          size:  20),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Semantics(
                label:  hasText ? 'Send message' : 'Send disabled',
                button: true,
                child: _PressScaleWidget(
                  onTap: () => _send(_inputCtrl.text),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width:  48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: hasText
                          ? const LinearGradient(
                        colors: [_primaryBlue, _accentBlue],
                        begin:  Alignment.topLeft,
                        end:    Alignment.bottomRight,
                      )
                          : null,
                      color:        hasText ? null : _card,
                      borderRadius: BorderRadius.circular(16),
                      border: hasText
                          ? null
                          : Border.all(color: _border, width: 1.5),
                      boxShadow: hasText
                          ? [BoxShadow(
                        color:      _primaryBlue.withValues(alpha: 0.40),
                        blurRadius: 14,
                        offset:     const Offset(0, 5),
                      )]
                          : [],
                    ),
                    child: Icon(
                      Icons.send_rounded,
                      color: hasText ? Colors.white : _sub,
                      size:  20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}