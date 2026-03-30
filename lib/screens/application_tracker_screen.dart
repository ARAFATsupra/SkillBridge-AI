// lib/screens/application_tracker_screen.dart

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// §0  THEME PROVIDER  — single source of truth for dark / light mode
// ═══════════════════════════════════════════════════════════════════════════════

/// Persists and exposes the app-wide dark-mode preference.
///
/// Register this in your root [MultiProvider] (main.dart):
/// ```dart
/// ChangeNotifierProvider(create: (_) => AppThemeProvider()),
/// ```
class AppThemeProvider extends ChangeNotifier {
  static const _kKey = 'skillbridge_is_dark';

  bool _isDark = true; // sensible default while prefs load

  bool get isDark => _isDark;

  AppThemeProvider() {
    _loadFromPrefs();
  }

  /// Reads the saved preference asynchronously on startup.
  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isDark = prefs.getBool(_kKey) ?? true;
    notifyListeners();
  }

  /// Toggles the theme and persists the new value.
  Future<void> toggle() async {
    _isDark = !_isDark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kKey, _isDark);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// §1  ENUMS
// ═══════════════════════════════════════════════════════════════════════════════

enum AppStatus { applied, screening, interview, offer, closed }
enum Priority  { hot, normal, low }
enum _SortBy   { date, company, priority }

// ═══════════════════════════════════════════════════════════════════════════════
// §2  MODELS
// ═══════════════════════════════════════════════════════════════════════════════

class _AppNote {
  final DateTime time;
  final String   text;
  _AppNote(this.time, this.text);
}

class _JobApp {
  final String id;
  String    company, title, location, salaryRange, notes, contactName;
  DateTime  appliedDate;
  DateTime? followUpDate;
  AppStatus status;
  Priority  priority;
  List<String>    tags;
  List<AppStatus> history;
  List<DateTime>  historyDates;
  List<_AppNote>  appNotes;

  _JobApp({
    required this.id,
    required this.company,
    required this.title,
    required this.location,
    required this.appliedDate,
    required this.status,
    this.salaryRange  = '',
    this.notes        = '',
    this.priority     = Priority.normal,
    this.contactName  = '',
    this.followUpDate,
    List<String>?    tags,
    List<AppStatus>? history,
    List<DateTime>?  historyDates,
    List<_AppNote>?  appNotes,
  })  : tags         = tags         ?? [],
        history      = history      ?? [AppStatus.applied],
        historyDates = historyDates ?? [appliedDate],
        appNotes     = appNotes     ?? [];
}

// ═══════════════════════════════════════════════════════════════════════════════
// §3  MOCK DATA
// ═══════════════════════════════════════════════════════════════════════════════

List<_JobApp> _buildMockApps() {
  final now = DateTime.now();

  _JobApp mk({
    required String id,
    required String co,
    required String title,
    required int daysAgo,
    required AppStatus st,
    String loc      = 'Dhaka',
    String salary   = '',
    String notes    = '',
    Priority pri    = Priority.normal,
    String contact  = '',
    int? followDays,
    List<String>? tags,
  }) =>
      _JobApp(
        id: id, company: co, title: title, location: loc,
        appliedDate: now.subtract(Duration(days: daysAgo)), status: st,
        salaryRange: salary, notes: notes, priority: pri,
        contactName: contact,
        followUpDate: followDays != null ? now.add(Duration(days: followDays)) : null,
        tags: tags,
      );

  return [
    mk(id: '1',  co: 'Pathao',       title: 'Data Analyst',       daysAgo: 3,  st: AppStatus.applied,   salary: '50k–70k BDT',   pri: Priority.hot,    contact: 'Rahim Uddin',  followDays: 2,  tags: ['Data', 'Analytics'],   notes: 'Applied via LinkedIn'),
    mk(id: '2',  co: 'Shohoz',       title: 'Software Engineer',  daysAgo: 8,  st: AppStatus.applied,   salary: '80k–100k BDT',  tags: ['Flutter', 'Backend']),
    mk(id: '3',  co: 'bKash',        title: 'Business Analyst',   daysAgo: 12, st: AppStatus.applied,   salary: '60k–80k BDT',   pri: Priority.low,    tags: ['Finance', 'BI']),
    mk(id: '4',  co: 'BRAC IT',      title: 'Python Developer',   daysAgo: 15, st: AppStatus.screening, salary: '70k–90k BDT',   pri: Priority.hot,    contact: 'Farida Islam', followDays: 1, tags: ['Python', 'ML'],  notes: 'HR called on Day 10'),
    mk(id: '5',  co: 'Shajgoj',      title: 'Marketing Analyst',  daysAgo: 18, st: AppStatus.screening, salary: '45k–65k BDT',   tags: ['Marketing', 'Analytics']),
    mk(id: '6',  co: 'Chaldal',      title: 'Data Scientist',     daysAgo: 22, st: AppStatus.interview, salary: '90k–120k BDT',  pri: Priority.hot,    contact: 'Karim Ahmed',  followDays: 3,  tags: ['ML', 'Python', 'SQL'], notes: 'Interview scheduled for next Monday'),
    mk(id: '7',  co: 'SSL Wireless', title: 'Product Manager',    daysAgo: 30, st: AppStatus.offer,     salary: '100k–130k BDT', pri: Priority.hot,    contact: 'Nadia Hassan',                tags: ['Product', 'Agile'],    notes: 'Offer received! Negotiating salary.'),
    mk(id: '8',  co: 'ACI Ltd',      title: 'Operations Analyst', daysAgo: 35, st: AppStatus.closed,    pri: Priority.low),
    mk(id: '9',  co: 'Robi',         title: 'Network Analyst',    daysAgo: 40, st: AppStatus.closed,    loc: 'Chittagong', pri: Priority.low),
    mk(id: '10', co: 'Grameenphone', title: 'Data Engineer',      daysAgo: 42, st: AppStatus.closed),
    mk(id: '11', co: 'Nagad',        title: 'BI Developer',       daysAgo: 45, st: AppStatus.closed),
  ];
}

// ═══════════════════════════════════════════════════════════════════════════════
// §4  LOOKUP MAPS
// ═══════════════════════════════════════════════════════════════════════════════

const _statusLabel = <AppStatus, String>{
  AppStatus.applied:   'Applied',
  AppStatus.screening: 'Screening',
  AppStatus.interview: 'Interview',
  AppStatus.offer:     'Offer',
  AppStatus.closed:    'Closed',
};

const _statusColor = <AppStatus, Color>{
  AppStatus.applied:   Color(0xFF3B82F6),
  AppStatus.screening: Color(0xFF8B5CF6),
  AppStatus.interview: Color(0xFFF59E0B),
  AppStatus.offer:     Color(0xFF10B981),
  AppStatus.closed:    Color(0xFF64748B),
};

const _priorityColor = <Priority, Color>{
  Priority.hot:    Color(0xFFEF4444),
  Priority.normal: Color(0xFF3B82F6),
  Priority.low:    Color(0xFF94A3B8),
};

const _priorityLabel = <Priority, String>{
  Priority.hot:    '🔥 Hot',
  Priority.normal: 'Normal',
  Priority.low:    'Low',
};

const _sortLabel = <_SortBy, String>{
  _SortBy.date:     'Date Applied',
  _SortBy.company:  'Company A–Z',
  _SortBy.priority: 'Priority',
};

// ═══════════════════════════════════════════════════════════════════════════════
// §5  DESIGN TOKENS
// ═══════════════════════════════════════════════════════════════════════════════

// Brand colours
const _indigo    = Color(0xFF6366F1);
const _indigoDim = Color(0xFF4F46E5);
const _amber     = Color(0xFFF59E0B);
const _emerald   = Color(0xFF10B981);
const _rose      = Color(0xFFEF4444);

// Theme colour pairs  [light, dark]
const _bgPair      = [Color(0xFFF4F6FB), Color(0xFF080C18)];
const _cardPair    = [Color(0xFFFFFFFF), Color(0xFF0F1629)];
const _surfacePair = [Color(0xFFEEF2FF), Color(0xFF141B2D)];
const _textPair    = [Color(0xFF0C0F1D), Color(0xFFEEF2FF)];
const _subPair     = [Color(0xFF64748B), Color(0xFF7986A3)];
const _borderPair  = [Color(0xFFDDE3F0), Color(0xFF1A2540)];

// Layout constants
const double _kPadH    = 14.0;
const double _kPadV    = 10.0;
const double _kRadCard = 14.0;
const double _kRadPage = 16.0;
const double _kKanbanW = 264.0;

// ═══════════════════════════════════════════════════════════════════════════════
// §6  COLOUR & TYPOGRAPHY HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

Color _cBg(bool d)      => d ? _bgPair[1]      : _bgPair[0];
Color _cCard(bool d)    => d ? _cardPair[1]    : _cardPair[0];
Color _cSurface(bool d) => d ? _surfacePair[1] : _surfacePair[0];
Color _cText(bool d)    => d ? _textPair[1]    : _textPair[0];
Color _cSub(bool d)     => d ? _subPair[1]     : _subPair[0];
Color _cBorder(bool d)  => d ? _borderPair[1]  : _borderPair[0];

TextStyle _syne(Color c, double sz, FontWeight fw) =>
    GoogleFonts.syne(color: c, fontSize: sz, fontWeight: fw);
TextStyle _dm(Color c, double sz, FontWeight fw) =>
    GoogleFonts.dmSans(color: c, fontSize: sz, fontWeight: fw);

// ═══════════════════════════════════════════════════════════════════════════════
// §7  UTILITY FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

const _avatarPalette = [
  Color(0xFF3B82F6), Color(0xFF7C3AED), Color(0xFFDB2777),
  Color(0xFFEA580C), Color(0xFF059669), Color(0xFF0891B2),
];

Color  _companyColor(String co) =>
    _avatarPalette[co.codeUnitAt(0) % _avatarPalette.length];

String _initials(String co) {
  final w = co.trim().split(' ');
  return w.length >= 2
      ? '${w[0][0]}${w[1][0]}'.toUpperCase()
      : co.substring(0, co.length.clamp(0, 2)).toUpperCase();
}

String _timeAgo(DateTime d) {
  final n = DateTime.now().difference(d).inDays;
  if (n == 0) return 'Today';
  if (n == 1) return '1 day ago';
  return '$n days ago';
}

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

bool _overdue(DateTime? dt) => dt != null && dt.isBefore(DateTime.now());

// ═══════════════════════════════════════════════════════════════════════════════
// §8  MAIN SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

class ApplicationTrackerScreen extends StatefulWidget {
  const ApplicationTrackerScreen({super.key});

  @override
  State<ApplicationTrackerScreen> createState() =>
      _ApplicationTrackerScreenState();
}

class _ApplicationTrackerScreenState extends State<ApplicationTrackerScreen> {
  // ── Data ────────────────────────────────────────────────────────────────────
  late List<_JobApp> _apps;

  // ── UI state ─────────────────────────────────────────────────────────────
  bool    _showSearch = false;
  _SortBy _sortBy     = _SortBy.date;
  String  _query      = '';

  // ── Scroll controllers ──────────────────────────────────────────────────
  final _kanbanScroll = ScrollController();
  final _colScrolls   =
  List.generate(AppStatus.values.length, (_) => ScrollController());
  final _searchCtrl   = TextEditingController();

  @override
  void initState() {
    super.initState();
    _apps = _buildMockApps();
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text));
  }

  @override
  void dispose() {
    _kanbanScroll.dispose();
    _searchCtrl.dispose();
    // FIX: wrap for-loop body in a block (lint: always_put_control_body_on_new_line)
    for (final c in _colScrolls) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Filtering & sorting ─────────────────────────────────────────────────
  List<_JobApp> _filtered(AppStatus s) {
    var list = _apps.where((a) => a.status == s).toList();
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where((a) =>
      a.company.toLowerCase().contains(q) ||
          a.title.toLowerCase().contains(q) ||
          a.location.toLowerCase().contains(q) ||
          a.tags.any((t) => t.toLowerCase().contains(q)))
          .toList();
    }
    switch (_sortBy) {
      case _SortBy.company:
        list.sort((a, b) => a.company.compareTo(b.company));
      case _SortBy.priority:
        list.sort((a, b) => a.priority.index.compareTo(b.priority.index));
      case _SortBy.date:
        list.sort((a, b) => b.appliedDate.compareTo(a.appliedDate));
    }
    return list;
  }

  // ── Mutations ────────────────────────────────────────────────────────────
  void _moveNext(_JobApp app) {
    final idx = AppStatus.values.indexOf(app.status);
    if (idx < AppStatus.values.length - 1) {
      setState(() {
        final next = AppStatus.values[idx + 1];
        app.history.add(next);
        app.historyDates.add(DateTime.now());
        app.status = next;
      });
      HapticFeedback.lightImpact();
    }
  }

  void _delete(_JobApp app) {
    setState(() => _apps.remove(app));
    HapticFeedback.mediumImpact();
    final isDark = context.read<AppThemeProvider>().isDark;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        backgroundColor: _cCard(isDark),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          '${app.title} at ${app.company} removed',
          style: _dm(_cText(isDark), 13, FontWeight.w500),
        ),
        action: SnackBarAction(
          label: 'Undo',
          textColor: _indigo,
          onPressed: () => setState(() => _apps.add(app)),
        ),
      ));
  }

  // ── Sheet helpers ────────────────────────────────────────────────────────
  void _showAdd()              => _openForm(null);
  void _showEdit(_JobApp app)  => _openForm(app);

  void _openForm(_JobApp? app) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AppFormSheet(
      editApp: app,
      onSave: (a) {
        setState(() {
          if (app == null) _apps.add(a);
        });
        Navigator.pop(context);
      },
    ),
  );

  void _showDetail(_JobApp app) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => _AppDetailScreen(
        app: app,
        onUpdate: () => setState(() {}),
      ),
    ),
  );

  void _showMenu(_JobApp app) => showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _CardMenuSheet(
      app: app,
      onView:   () { Navigator.pop(context); _showDetail(app); },
      onEdit:   () { Navigator.pop(context); _showEdit(app); },
      onDelete: () { Navigator.pop(context); _delete(app); },
    ),
  );

  // ── Stats ────────────────────────────────────────────────────────────────
  int    get _total => _apps.length;
  int    _cnt(AppStatus s)  => _apps.where((a) => a.status == s).length;
  double _rate(AppStatus s) => _total == 0 ? 0 : _cnt(s) / _total;

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    // Re-build whenever the theme provider changes.
    final isDark = context.watch<AppThemeProvider>().isDark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: _cBg(isDark),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _buildAppBar(isDark),
        floatingActionButton: _buildFAB(),
        body: Column(children: [
          if (_showSearch) _buildSearchBar(isDark),
          _buildPipelineSummary(isDark),
          Container(height: 1, color: _cBorder(isDark)),
          Expanded(child: _buildKanbanBoard(isDark)),
          _buildFooter(isDark),
        ]),
      ),
    );
  }

  // ── AppBar ──────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(bool isDark) {
    final text   = _cText(isDark);
    final sub    = _cSub(isDark);
    final border = _cBorder(isDark);
    final bg     = _cBg(isDark);

    return AppBar(
      backgroundColor: bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: text,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, color: text, size: 19),
        onPressed: () => Navigator.maybePop(context),
      ),
      title: Text('My Applications', style: _syne(text, 17, FontWeight.w700)),
      actions: [
        // ── Search toggle ────────────────────────────────────────────────
        IconButton(
          icon: Icon(
            _showSearch ? Icons.search_off_rounded : Icons.search_rounded,
            color: _showSearch ? _indigo : sub,
            size: 22,
          ),
          onPressed: () => setState(() {
            _showSearch = !_showSearch;
            if (!_showSearch) {
              _searchCtrl.clear();
              _query = '';
            }
          }),
        ),

        // ── Sort menu ────────────────────────────────────────────────────
        PopupMenuButton<_SortBy>(
          icon: Icon(Icons.sort_rounded, color: sub, size: 22),
          color: _cCard(isDark),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          onSelected: (v) => setState(() => _sortBy = v),
          itemBuilder: (_) => _SortBy.values
              .map((s) => PopupMenuItem(
            value: s,
            child: Row(children: [
              Icon(
                s == _sortBy
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: s == _sortBy ? _indigo : sub,
                size: 16,
              ),
              const SizedBox(width: 10),
              Text(
                _sortLabel[s]!,
                style: _dm(
                  s == _sortBy ? _indigo : text,
                  14,
                  s == _sortBy ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ]),
          ))
              .toList(),
        ),

        // ── Dark / Light mode toggle (SINGLE button — no duplicate) ──────
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Consumer<AppThemeProvider>(
            builder: (_, themeProvider, __) => IconButton(
              tooltip: themeProvider.isDark
                  ? 'Switch to Light mode'
                  : 'Switch to Dark mode',
              onPressed: themeProvider.toggle,
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) => RotationTransition(
                  turns: anim,
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Icon(
                  themeProvider.isDark
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  key: ValueKey(themeProvider.isDark),
                  color: themeProvider.isDark ? _indigo : _amber,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: border),
      ),
    );
  }

  // ── Search Bar ──────────────────────────────────────────────────────────
  Widget _buildSearchBar(bool isDark) {
    final sub     = _cSub(isDark);
    final text    = _cText(isDark);
    final border  = _cBorder(isDark);
    final surface = _cSurface(isDark);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      color: _cBg(isDark),
      padding: const EdgeInsets.fromLTRB(_kPadH, _kPadV, _kPadH, _kPadV),
      child: TextField(
        controller: _searchCtrl,
        autofocus: true,
        style: _dm(text, 14, FontWeight.w400),
        cursorColor: _indigo,
        decoration: InputDecoration(
          hintText: 'Search company, role, tag…',
          hintStyle: _dm(sub, 14, FontWeight.w400),
          prefixIcon: Icon(Icons.search_rounded, color: sub, size: 20),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.close_rounded, color: sub, size: 18),
            onPressed: () {
              _searchCtrl.clear();
              setState(() => _query = '');
            },
          )
              : null,
          filled: true,
          fillColor: surface,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_kRadCard),
            borderSide: BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_kRadCard),
            borderSide: BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_kRadCard),
            borderSide: const BorderSide(color: _indigo, width: 1.5),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.3, end: 0);
  }

  // ── Pipeline Summary ────────────────────────────────────────────────────
  Widget _buildPipelineSummary(bool isDark) {
    return Container(
      color: _cBg(isDark),
      padding: const EdgeInsets.fromLTRB(_kPadH, _kPadV, _kPadH, _kPadV),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: AppStatus.values.asMap().entries.map((e) {
            final s   = e.value;
            final col = _statusColor[s]!;
            final n   = _cnt(s);

            return GestureDetector(
              onTap: () => _kanbanScroll.animateTo(
                e.key * (_kKanbanW + 10),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
              ),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: col.withValues(alpha: isDark ? 0.10 : 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: col.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$n', style: _syne(col, 18, FontWeight.w800)),
                    const SizedBox(height: 1),
                    Text(_statusLabel[s]!,
                        style: _dm(_cSub(isDark), 11, FontWeight.w600)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  // ── FAB ─────────────────────────────────────────────────────────────────
  Widget _buildFAB() => FloatingActionButton.extended(
    onPressed: _showAdd,
    backgroundColor: _indigo,
    elevation: 6,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
    label:
    Text('Add Application', style: _dm(Colors.white, 14, FontWeight.w700)),
  );

  // ── Kanban Board ────────────────────────────────────────────────────────
  Widget _buildKanbanBoard(bool isDark) {
    final border = _cBorder(isDark);

    return ListView.builder(
      controller: _kanbanScroll,
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.zero,
      itemCount: AppStatus.values.length,
      itemBuilder: (_, ci) {
        final status    = AppStatus.values[ci];
        final col       = _statusColor[status]!;
        final apps      = _filtered(status);
        final nextIdx   = ci + 1;
        final nextLabel = nextIdx < AppStatus.values.length
            ? _statusLabel[AppStatus.values[nextIdx]]!
            : '';

        return Container(
          width: _kKanbanW,
          margin: EdgeInsets.fromLTRB(ci == 0 ? 12 : 10, 12, 0, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _KanbanHeader(
                status: status,
                hColor: col,
                count: apps.length,
                isDark: isDark,
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: col.withValues(alpha: isDark ? 0.03 : 0.02),
                    border: Border(
                      left:   BorderSide(color: border),
                      right:  BorderSide(color: border),
                      bottom: BorderSide(color: border),
                    ),
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(_kRadPage)),
                  ),
                  padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
                  child: apps.isEmpty
                      ? _EmptyColumn(
                    hColor: col,
                    hasQuery: _query.isNotEmpty,
                    sub: _cSub(isDark),
                  )
                      : ListView.builder(
                    controller: _colScrolls[ci],
                    physics: const BouncingScrollPhysics(),
                    itemCount: apps.length,
                    itemBuilder: (_, i) => _DismissibleCard(
                      app: apps[i],
                      hColor: col,
                      nextLabel: nextLabel,
                      colStatus: status,
                      index: i,
                      isDark: isDark,
                      onDelete: _delete,
                      onMove: _moveNext,
                      onTap: _showDetail,
                      onMenu: _showMenu,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Footer stats ────────────────────────────────────────────────────────
  Widget _buildFooter(bool isDark) {
    final text   = _cText(isDark);
    final sub    = _cSub(isDark);
    final border = _cBorder(isDark);
    final bg     = _cBg(isDark);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: border)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('$_total applications',
              style: _syne(text, 13, FontWeight.w700)),
          const Spacer(),
          Text(
            'Interview ${(_rate(AppStatus.interview) * 100).toStringAsFixed(0)}%'
                '  ·  Offer ${(_rate(AppStatus.offer) * 100).toStringAsFixed(0)}%',
            style: _dm(sub, 12, FontWeight.w400),
          ),
        ]),
        const SizedBox(height: 8),
        Row(
          children: AppStatus.values.map((s) {
            final col  = _statusColor[s]!;
            final frac = _total == 0 ? 0.0 : _cnt(s) / _total;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: frac,
                        minHeight: 7,
                        backgroundColor: col.withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation<Color>(col),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text('${_cnt(s)}',
                        style: _dm(col, 10, FontWeight.w700)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// §9  KANBAN COLUMN HEADER  (glassmorphism)
// ═══════════════════════════════════════════════════════════════════════════════

class _KanbanHeader extends StatelessWidget {
  final AppStatus status;
  final Color     hColor;
  final int       count;
  final bool      isDark;

  const _KanbanHeader({
    required this.status,
    required this.hColor,
    required this.count,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius:
    const BorderRadius.vertical(top: Radius.circular(_kRadPage)),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: hColor.withValues(alpha: isDark ? 0.14 : 0.08),
          border: Border(
            top: BorderSide(color: hColor.withValues(alpha: 0.3)),
            left:   BorderSide(color: _cBorder(isDark)),
            right:  BorderSide(color: _cBorder(isDark)),
            bottom: BorderSide(
                color: hColor.withValues(alpha: 0.5), width: 2),
          ),
        ),
        child: Row(children: [
          Container(
            width: 8,
            height: 8,
            decoration:
            BoxDecoration(color: hColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(_statusLabel[status]!,
              style: _syne(hColor, 13, FontWeight.w700)),
          const Spacer(),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: hColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text('$count',
                style: _dm(hColor, 12, FontWeight.w800)),
          ),
        ]),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// §10  EMPTY COLUMN PLACEHOLDER
// ═══════════════════════════════════════════════════════════════════════════════

class _EmptyColumn extends StatelessWidget {
  final Color hColor;
  final bool  hasQuery;
  final Color sub;

  const _EmptyColumn({
    required this.hColor,
    required this.hasQuery,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: hColor.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.inbox_outlined,
            color: hColor.withValues(alpha: 0.45), size: 24),
      ),
      const SizedBox(height: 10),
      Text(
        hasQuery ? 'No results' : 'Empty',
        style: GoogleFonts.dmSans(
            color: sub, fontSize: 13, fontWeight: FontWeight.w500),
      ),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// §11  DISMISSIBLE CARD WRAPPER
// ═══════════════════════════════════════════════════════════════════════════════

class _DismissibleCard extends StatelessWidget {
  final _JobApp   app;
  final Color     hColor;
  final String    nextLabel;
  final AppStatus colStatus;
  final int       index;
  final bool      isDark;
  final void Function(_JobApp) onDelete, onMove, onTap, onMenu;

  const _DismissibleCard({
    required this.app,
    required this.hColor,
    required this.nextLabel,
    required this.colStatus,
    required this.index,
    required this.isDark,
    required this.onDelete,
    required this.onMove,
    required this.onTap,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) => Dismissible(
    key: ValueKey('dismiss_${app.id}'),
    direction: DismissDirection.endToStart,
    confirmDismiss: (_) async {
      HapticFeedback.mediumImpact();
      return true;
    },
    onDismissed: (_) => onDelete(app),
    background: Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _rose.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(_kRadCard),
        border: Border.all(color: _rose.withValues(alpha: 0.3)),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      child: const Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.delete_outline_rounded, color: _rose, size: 22),
        SizedBox(height: 4),
        Text('Delete',
            style: TextStyle(
                color: _rose,
                fontSize: 10,
                fontWeight: FontWeight.w700)),
      ]),
    ),
    child: _AppCard(
      app: app,
      hColor: hColor,
      nextLabel: nextLabel,
      colStatus: colStatus,
      index: index,
      isDark: isDark,
      onMove: onMove,
      onTap: onTap,
      onMenu: onMenu,
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// §12  APP CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _AppCard extends StatelessWidget {
  final _JobApp   app;
  final Color     hColor;
  final String    nextLabel;
  final AppStatus colStatus;
  final int       index;
  final bool      isDark;
  final void Function(_JobApp) onMove, onTap, onMenu;

  const _AppCard({
    required this.app,
    required this.hColor,
    required this.nextLabel,
    required this.colStatus,
    required this.index,
    required this.isDark,
    required this.onMove,
    required this.onTap,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final text   = _cText(isDark);
    final sub    = _cSub(isDark);
    final card   = _cCard(isDark);
    final border = _cBorder(isDark);
    final isOvr  = _overdue(app.followUpDate);

    return GestureDetector(
      onTap: () => onTap(app),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(_kRadCard),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.35)
                  : const Color(0xFF0C0F1D).withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(children: [
          // Left accent bar
          Container(
            width: 4,
            height: double.infinity,
            decoration: BoxDecoration(
              color: hColor,
              borderRadius: const BorderRadius.only(
                topLeft:    Radius.circular(_kRadCard),
                bottomLeft: Radius.circular(_kRadCard),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header row ─────────────────────────────────────────
                  Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: _companyColor(app.company),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(_initials(app.company),
                                style: _syne(
                                    Colors.white, 12, FontWeight.w800)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(app.company,
                                  style: _dm(sub, 11, FontWeight.w500)),
                              Text(app.title,
                                  style: _dm(text, 13, FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => onMenu(app),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(Icons.more_vert_rounded,
                                color: sub, size: 18),
                          ),
                        ),
                      ]),
                  const SizedBox(height: 8),

                  // ── Meta row ───────────────────────────────────────────
                  Row(children: [
                    Icon(Icons.calendar_today_outlined,
                        color: sub, size: 11),
                    const SizedBox(width: 3),
                    Text(_timeAgo(app.appliedDate),
                        style: _dm(sub, 11, FontWeight.w400)),
                    const Spacer(),
                    Icon(Icons.location_on_outlined, color: sub, size: 11),
                    const SizedBox(width: 2),
                    Text(app.location,
                        style: _dm(sub, 11, FontWeight.w400)),
                  ]),

                  // ── Salary ─────────────────────────────────────────────
                  if (app.salaryRange.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _emerald.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(app.salaryRange,
                          style: _dm(_emerald, 11, FontWeight.w600)),
                    ),
                  ],

                  // ── Priority + follow-up ───────────────────────────────
                  if (app.priority != Priority.normal ||
                      app.followUpDate != null) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      if (app.priority != Priority.normal)
                        _PriorityBadge(
                            priority: app.priority, isDark: isDark),
                      if (app.priority != Priority.normal &&
                          app.followUpDate != null)
                        const SizedBox(width: 6),
                      if (app.followUpDate != null)
                        _FollowUpChip(
                            date: app.followUpDate!, overdue: isOvr),
                    ]),
                  ],

                  // ── Tags ───────────────────────────────────────────────
                  if (app.tags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: app.tags
                          .take(3)
                          .map((t) => _TagChip(
                        label: t,
                        isDark: isDark,
                        color: hColor,
                      ))
                          .toList(),
                    ),
                  ],

                  // ── Move-to-next button ────────────────────────────────
                  if (colStatus != AppStatus.closed) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => onMove(app),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: hColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                              color: hColor.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.arrow_forward_rounded,
                                  color: hColor, size: 13),
                              const SizedBox(width: 5),
                              Text('→ $nextLabel',
                                  style:
                                  _dm(hColor, 12, FontWeight.w700)),
                            ]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ]),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: index * 40));
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// §13  CARD MENU SHEET
// ═══════════════════════════════════════════════════════════════════════════════

class _CardMenuSheet extends StatelessWidget {
  final _JobApp      app;
  final VoidCallback onView, onEdit, onDelete;

  const _CardMenuSheet({
    required this.app,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.read<AppThemeProvider>().isDark;
    final card   = _cCard(isDark);
    final text   = _cText(isDark);
    final sub    = _cSub(isDark);
    final border = _cBorder(isDark);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: BoxDecoration(
        color: card,
        borderRadius:
        const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
              color: border, borderRadius: BorderRadius.circular(100)),
        ),
        const SizedBox(height: 20),
        ListTile(
          leading: const Icon(Icons.open_in_new_rounded, color: _indigo),
          title: Text('View Details',
              style: _dm(text, 14, FontWeight.w600)),
          onTap: onView,
        ),
        ListTile(
          leading: Icon(Icons.edit_outlined, color: sub),
          title: Text('Edit', style: _dm(text, 14, FontWeight.w600)),
          onTap: onEdit,
        ),
        ListTile(
          leading:
          const Icon(Icons.delete_outline_rounded, color: _rose),
          title: Text('Delete', style: _dm(_rose, 14, FontWeight.w600)),
          onTap: onDelete,
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// §14  APP FORM SHEET  (Add + Edit unified)
// ═══════════════════════════════════════════════════════════════════════════════

class _AppFormSheet extends StatefulWidget {
  final void Function(_JobApp) onSave;
  final _JobApp? editApp;

  const _AppFormSheet({required this.onSave, this.editApp});

  @override
  State<_AppFormSheet> createState() => _AppFormSheetState();
}

class _AppFormSheetState extends State<_AppFormSheet> {
  late final TextEditingController
  _company, _title, _loc, _salary, _notes, _contact, _tagCtrl;
  late AppStatus    _status;
  late Priority     _priority;
  late List<String> _tags;
  DateTime? _followUp;

  bool get _isEdit => widget.editApp != null;

  // ── Theme helpers — use context.read since _dec/_field are called from
  //    build which already watches the provider via isDark local variable.
  // FIX: removed unused `_card` getter; kept only what _dec/_field actually use.
  bool   get _d       => context.read<AppThemeProvider>().isDark;
  Color  get _text    => _cText(_d);
  Color  get _sub     => _cSub(_d);
  Color  get _border  => _cBorder(_d);
  Color  get _surface => _cSurface(_d);

  @override
  void initState() {
    super.initState();
    final e   = widget.editApp;
    _company  = TextEditingController(text: e?.company     ?? '');
    _title    = TextEditingController(text: e?.title       ?? '');
    _loc      = TextEditingController(text: e?.location    ?? '');
    _salary   = TextEditingController(text: e?.salaryRange ?? '');
    _notes    = TextEditingController(text: e?.notes       ?? '');
    _contact  = TextEditingController(text: e?.contactName ?? '');
    _tagCtrl  = TextEditingController();
    _status   = e?.status   ?? AppStatus.applied;
    _priority = e?.priority ?? Priority.normal;
    _tags     = List<String>.from(e?.tags ?? []);
    _followUp = e?.followUpDate;
  }

  @override
  void dispose() {
    for (final c in [
      _company, _title, _loc, _salary, _notes, _contact, _tagCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _addTag() {
    final t = _tagCtrl.text.trim();
    if (t.isNotEmpty && !_tags.contains(t)) {
      setState(() {
        _tags.add(t);
        _tagCtrl.clear();
      });
    }
  }

  void _save() {
    if (_company.text.trim().isEmpty || _title.text.trim().isEmpty) return;
    final loc = _loc.text.trim().isEmpty ? 'Dhaka' : _loc.text.trim();
    final e   = widget.editApp;

    if (e != null) {
      e
        ..company      = _company.text.trim()
        ..title        = _title.text.trim()
        ..location     = loc
        ..status       = _status
        ..salaryRange  = _salary.text.trim()
        ..notes        = _notes.text.trim()
        ..priority     = _priority
        ..contactName  = _contact.text.trim()
        ..followUpDate = _followUp;
      e.tags
        ..clear()
        ..addAll(_tags);
      widget.onSave(e);
    } else {
      widget.onSave(_JobApp(
        id:          DateTime.now().millisecondsSinceEpoch.toString(),
        company:     _company.text.trim(),
        title:       _title.text.trim(),
        location:    loc,
        appliedDate: DateTime.now(),
        status:      _status,
        salaryRange: _salary.text.trim(),
        notes:       _notes.text.trim(),
        priority:    _priority,
        contactName: _contact.text.trim(),
        followUpDate: _followUp,
        tags:        List<String>.from(_tags),
      ));
    }
  }

  InputDecoration _dec(String hint, {IconData? icon}) => InputDecoration(
    hintText:   hint,
    hintStyle:  _dm(_sub, 14, FontWeight.w400),
    prefixIcon: icon != null ? Icon(icon, color: _sub, size: 19) : null,
    filled:     true,
    fillColor:  _surface,
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _border)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _border)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _indigo, width: 1.5)),
  );

  Widget _field(
      TextEditingController ctrl,
      String hint, {
        IconData? icon,
        int maxLines = 1,
      }) =>
      TextField(
        controller: ctrl,
        maxLines:   maxLines,
        style:      _dm(_text, 14, FontWeight.w400),
        decoration: _dec(hint, icon: icon),
      );

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppThemeProvider>().isDark;

    return Padding(
      padding:
      EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
        decoration: BoxDecoration(
          color: _cCard(isDark),
          borderRadius:
          const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: _cBorder(isDark),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                _isEdit ? 'Edit Application' : 'Add Application',
                style: _syne(_cText(isDark), 18, FontWeight.w700),
              ),
              const SizedBox(height: 18),

              _field(_company, 'Company Name',
                  icon: Icons.business_outlined),
              const SizedBox(height: 10),
              _field(_title, 'Job Title',
                  icon: Icons.work_outline_rounded),
              const SizedBox(height: 10),
              _field(_loc, 'Location',
                  icon: Icons.location_on_outlined),
              const SizedBox(height: 10),
              _field(_contact, 'Contact Name (optional)',
                  icon: Icons.person_outline_rounded),
              const SizedBox(height: 10),
              _field(_salary, 'Salary Range',
                  icon: Icons.attach_money_rounded),
              const SizedBox(height: 10),

              // ── Status dropdown ──────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: _cSurface(isDark),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _cBorder(isDark)),
                ),
                child: _DropdownField<AppStatus>(
                  value:     _status,
                  items:     AppStatus.values,
                  labelOf:   (s) => _statusLabel[s]!,
                  isDark:    isDark,
                  onChanged: (v) => setState(() => _status = v!),
                ),
              ),
              const SizedBox(height: 10),

              // ── Priority selector ────────────────────────────────────
              Text('Priority',
                  style: _dm(_cSub(isDark), 12, FontWeight.w600)),
              const SizedBox(height: 6),
              Row(
                children: Priority.values.map((p) {
                  final sel = _priority == p;
                  final c   = _priorityColor[p]!;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _priority = p),
                      child: Container(
                        margin: EdgeInsets.only(
                            right: p != Priority.low ? 8 : 0),
                        padding:
                        const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: sel
                              ? c.withValues(alpha: 0.14)
                              : _cSurface(isDark),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: sel
                                ? c.withValues(alpha: 0.5)
                                : _cBorder(isDark),
                            width: sel ? 1.5 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _priorityLabel[p]!,
                            style: _dm(
                              sel ? c : _cSub(isDark),
                              12,
                              sel ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),

              // ── Follow-up date picker ───────────────────────────────
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _followUp ?? DateTime.now(),
                    firstDate:
                    DateTime.now().subtract(const Duration(days: 30)),
                    lastDate:
                    DateTime.now().add(const Duration(days: 180)),
                    builder: (ctx, child) => Theme(
                      data: ThemeData(
                        colorScheme: isDark
                            ? const ColorScheme.dark(primary: _indigo)
                            : const ColorScheme.light(primary: _indigo),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) setState(() => _followUp = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: _cSurface(isDark),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _cBorder(isDark)),
                  ),
                  child: Row(children: [
                    Icon(Icons.event_outlined,
                        color: _cSub(isDark), size: 19),
                    const SizedBox(width: 10),
                    Text(
                      _followUp != null
                          ? 'Follow-up: ${_fmtDate(_followUp!)}'
                          : 'Set follow-up date (optional)',
                      style: _dm(
                        _followUp != null
                            ? _cText(isDark)
                            : _cSub(isDark),
                        14,
                        FontWeight.w400,
                      ),
                    ),
                    const Spacer(),
                    if (_followUp != null)
                      GestureDetector(
                        onTap: () => setState(() => _followUp = null),
                        child: Icon(Icons.close_rounded,
                            color: _cSub(isDark), size: 16),
                      ),
                  ]),
                ),
              ),
              const SizedBox(height: 10),

              // ── Tags ────────────────────────────────────────────────
              Text('Tags',
                  style: _dm(_cSub(isDark), 12, FontWeight.w600)),
              const SizedBox(height: 6),
              if (_tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _tags
                        .map((t) => _RemovableTagChip(
                      label:    t,
                      isDark:   isDark,
                      onRemove: () =>
                          setState(() => _tags.remove(t)),
                    ))
                        .toList(),
                  ),
                ),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _tagCtrl,
                    style:      _dm(_cText(isDark), 14, FontWeight.w400),
                    onSubmitted: (_) => _addTag(),
                    decoration: _dec('Add tag…').copyWith(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _addTag,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color:        _indigo.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _indigo.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.add_rounded,
                        color: _indigo, size: 20),
                  ),
                ),
              ]),
              const SizedBox(height: 10),

              _field(_notes, 'Notes',
                  icon: Icons.note_outlined, maxLines: 2),
              const SizedBox(height: 20),

              // ── Save button ────────────────────────────────────────
              GestureDetector(
                onTap: _save,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [_indigoDim, _indigo]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: _indigo.withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _isEdit ? 'Save Changes' : 'Add Application',
                      style: _syne(Colors.white, 14, FontWeight.w700),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // ── Cancel button ──────────────────────────────────────
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: _cBorder(isDark), width: 1.5),
                  ),
                  child: Center(
                    child: Text('Cancel',
                        style: _dm(
                            _cSub(isDark), 14, FontWeight.w600)),
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

// ═══════════════════════════════════════════════════════════════════════════════
// §15  DETAIL SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

class _AppDetailScreen extends StatefulWidget {
  final _JobApp      app;
  final VoidCallback onUpdate;

  const _AppDetailScreen({
    required this.app,
    required this.onUpdate,
  });

  @override
  State<_AppDetailScreen> createState() => _AppDetailScreenState();
}

class _AppDetailScreenState extends State<_AppDetailScreen> {
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  void _addNote() {
    if (_noteCtrl.text.trim().isEmpty) return;
    setState(() {
      widget.app.appNotes
          .add(_AppNote(DateTime.now(), _noteCtrl.text.trim()));
      _noteCtrl.clear();
    });
    widget.onUpdate();
  }

  int get _daysApplied =>
      DateTime.now().difference(widget.app.appliedDate).inDays;

  int get _daysInStage => widget.app.historyDates.isEmpty
      ? 0
      : DateTime.now()
      .difference(widget.app.historyDates.last)
      .inDays;

  // FIX: _infoCard now accepts isDark so it does not need its own
  //      context.read call, eliminating all unused getter warnings.
  Widget _infoCard(bool isDark, Widget child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cCard(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cBorder(isDark)),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.28)
                : const Color(0xFF0C0F1D).withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  // FIX: _row also accepts isDark directly.
  Widget _row(bool isDark, IconData icon, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 15, color: _cSub(isDark)),
        const SizedBox(width: 10),
        Expanded(
            child: Text(val,
                style: _dm(_cText(isDark), 13, FontWeight.w400))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Single source of truth: watch so the whole screen redraws on toggle.
    final isDark = context.watch<AppThemeProvider>().isDark;
    final app    = widget.app;
    final hColor = _statusColor[app.status]!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: _cBg(isDark),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor:        _cBg(isDark),
          elevation:              0,
          scrolledUnderElevation: 0,
          foregroundColor:        _cText(isDark),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: _cText(isDark), size: 19),
            onPressed: () => Navigator.pop(context),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(app.company,
                  style: _syne(_cText(isDark), 16, FontWeight.w700)),
              Text(app.title,
                  style: _dm(_cSub(isDark), 12, FontWeight.w400)),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: _cBorder(isDark)),
          ),
          // NOTE: No theme toggle here — the single toggle lives on
          // ApplicationTrackerScreen's AppBar only.
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Job info card ────────────────────────────────────────────
            _infoCard(
              isDark,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: _companyColor(app.company),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(_initials(app.company),
                            style: _syne(
                                Colors.white, 14, FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(app.title,
                              style: _syne(
                                  _cText(isDark), 17, FontWeight.w700)),
                          Text(app.company,
                              style: _dm(
                                  _cSub(isDark), 13, FontWeight.w400)),
                        ],
                      ),
                    ),
                    _PriorityBadge(
                        priority: app.priority, isDark: isDark),
                  ]),
                  const SizedBox(height: 14),
                  _row(isDark, Icons.location_on_outlined, app.location),
                  _row(isDark, Icons.calendar_today_outlined,
                      _timeAgo(app.appliedDate)),
                  if (app.salaryRange.isNotEmpty)
                    _row(isDark, Icons.payments_outlined, app.salaryRange),
                  if (app.contactName.isNotEmpty)
                    _row(isDark, Icons.person_outline_rounded,
                        app.contactName),
                  if (app.followUpDate != null)
                    _row(
                      isDark,
                      Icons.event_available_outlined,
                      'Follow-up: ${_fmtDate(app.followUpDate!)}'
                          '${_overdue(app.followUpDate) ? ' ⚠ Overdue' : ''}',
                    ),
                  if (app.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: app.tags
                          .map((t) => _TagChip(
                          label: t, isDark: isDark, color: hColor))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 14),

                  // ── Analytics tiles ────────────────────────────────────
                  Row(children: [
                    Expanded(
                      child: _StatTile(
                        label:  'Days applied',
                        value:  '$_daysApplied',
                        color:  _indigo,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatTile(
                        label:  'Days in stage',
                        value:  '$_daysInStage',
                        color:  hColor,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatTile(
                        label:  'Notes',
                        value:  '${app.appNotes.length}',
                        color:  _emerald,
                        isDark: isDark,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),

                  // ── Inline status changer ──────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: _cSurface(isDark),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _cBorder(isDark)),
                    ),
                    child: _DropdownField<AppStatus>(
                      value:   app.status,
                      items:   AppStatus.values,
                      labelOf: (s) => _statusLabel[s]!,
                      isDark:  isDark,
                      onChanged: (v) {
                        if (v != null && v != app.status) {
                          setState(() {
                            app.history.add(v);
                            app.historyDates.add(DateTime.now());
                            app.status = v;
                            widget.onUpdate();
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms),

            // ── Status Timeline ──────────────────────────────────────────
            _infoCard(
              isDark,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status Timeline',
                      style: _syne(_cText(isDark), 15, FontWeight.w700)),
                  const SizedBox(height: 14),
                  ...app.history.asMap().entries.map((e) {
                    final isLast = e.key == app.history.length - 1;
                    final sc     = _statusColor[e.value]!;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(children: [
                          Container(
                            width:  14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: isLast
                                  ? sc
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isLast
                                    ? sc
                                    : _cSub(isDark)
                                    .withValues(alpha: 0.35),
                                width: 2,
                              ),
                            ),
                          ),
                          if (!isLast)
                            Container(
                                width: 2,
                                height: 30,
                                color: _cBorder(isDark)),
                        ]),
                        const SizedBox(width: 12),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _statusLabel[e.value]!,
                                style: _dm(
                                  isLast
                                      ? sc
                                      : _cSub(isDark),
                                  13,
                                  isLast
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                              if (e.key < app.historyDates.length)
                                Text(
                                  _timeAgo(app.historyDates[e.key]),
                                  style: _dm(_cSub(isDark), 11,
                                      FontWeight.w400),
                                ),
                              SizedBox(height: isLast ? 0 : 6),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms, delay: 80.ms),

            // ── Notes ────────────────────────────────────────────────────
            _infoCard(
              isDark,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Notes',
                      style: _syne(_cText(isDark), 15, FontWeight.w700)),
                  const SizedBox(height: 10),
                  if (app.appNotes.isEmpty)
                    Text('No notes yet.',
                        style:
                        _dm(_cSub(isDark), 13, FontWeight.w400)),
                  ...app.appNotes.map((n) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:        _cSurface(isDark),
                      borderRadius: BorderRadius.circular(10),
                      border:
                      Border.all(color: _cBorder(isDark)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_timeAgo(n.time),
                            style: _dm(_cSub(isDark), 10,
                                FontWeight.w500)),
                        const SizedBox(height: 3),
                        Text(n.text,
                            style: _dm(_cText(isDark), 13,
                                FontWeight.w400)),
                      ],
                    ),
                  )),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _noteCtrl,
                        style: _dm(
                            _cText(isDark), 14, FontWeight.w400),
                        onSubmitted: (_) => _addNote(),
                        decoration: InputDecoration(
                          hintText: 'Add a note…',
                          hintStyle: _dm(
                              _cSub(isDark), 14, FontWeight.w400),
                          filled:    true,
                          fillColor: _cSurface(isDark),
                          contentPadding:
                          const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                              borderRadius:
                              BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: _cBorder(isDark))),
                          enabledBorder: OutlineInputBorder(
                              borderRadius:
                              BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: _cBorder(isDark))),
                          focusedBorder: OutlineInputBorder(
                              borderRadius:
                              BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: _indigo, width: 1.5)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _addNote,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [_indigoDim, _indigo]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.add_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ),
                  ]),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms, delay: 160.ms),

            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// §16  REUSABLE SMALL WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _DropdownField<T> extends StatelessWidget {
  final T                  value;
  final List<T>            items;
  final String Function(T) labelOf;
  final bool               isDark;
  final void Function(T?)  onChanged;

  const _DropdownField({
    required this.value,
    required this.items,
    required this.labelOf,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => DropdownButtonHideUnderline(
    child: DropdownButton<T>(
      isExpanded:    true,
      value:         value,
      dropdownColor: _cCard(isDark),
      style:         _dm(_cText(isDark), 14, FontWeight.w500),
      items: items
          .map((s) => DropdownMenuItem<T>(
        value: s,
        child: Text(labelOf(s),
            style: _dm(
                _cText(isDark), 14, FontWeight.w500)),
      ))
          .toList(),
      onChanged: onChanged,
    ),
  );
}

class _PriorityBadge extends StatelessWidget {
  final Priority priority;
  final bool     isDark;

  const _PriorityBadge({required this.priority, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (priority == Priority.normal) return const SizedBox.shrink();
    final c = _priorityColor[priority]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
        border:       Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Text(_priorityLabel[priority]!,
          style: _dm(c, 10, FontWeight.w700)),
    );
  }
}

class _FollowUpChip extends StatelessWidget {
  final DateTime date;
  final bool     overdue;

  const _FollowUpChip({required this.date, required this.overdue});

  @override
  Widget build(BuildContext context) {
    final c = overdue ? _rose : _amber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(7),
        border:       Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          overdue ? Icons.warning_amber_rounded : Icons.event_outlined,
          color: c,
          size:  11,
        ),
        const SizedBox(width: 3),
        Text(_fmtDate(date), style: _dm(c, 10, FontWeight.w700)),
      ]),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final bool   isDark;
  final Color  color;

  const _TagChip({
    required this.label,
    required this.isDark,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color:        color.withValues(alpha: isDark ? 0.14 : 0.08),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: _dm(
        color.withValues(alpha: isDark ? 0.9 : 0.75),
        10,
        FontWeight.w600,
      ),
    ),
  );
}

class _RemovableTagChip extends StatelessWidget {
  final String       label;
  final bool         isDark;
  final VoidCallback onRemove;

  const _RemovableTagChip({
    required this.label,
    required this.isDark,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
    decoration: BoxDecoration(
      color:        _indigo.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(8),
      border:       Border.all(color: _indigo.withValues(alpha: 0.25)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: _dm(_indigo, 12, FontWeight.w600)),
      const SizedBox(width: 4),
      GestureDetector(
        onTap: onRemove,
        child: Icon(Icons.close_rounded,
            color: _cSub(isDark), size: 13),
      ),
    ]),
  );
}

class _StatTile extends StatelessWidget {
  final String label, value;
  final Color  color;
  final bool   isDark;

  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    decoration: BoxDecoration(
      color:        _cSurface(isDark),
      borderRadius: BorderRadius.circular(12),
      border:       Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child:
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: _syne(color, 18, FontWeight.w800)),
      const SizedBox(height: 2),
      Text(label, style: _dm(_cSub(isDark), 10, FontWeight.w500)),
    ]),
  );
}