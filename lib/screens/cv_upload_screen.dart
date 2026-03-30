// lib/screens/cv_upload_screen.dart — SkillBridge AI
// ═══════════════════════════════════════════════════════════════════════════════
// UI REDESIGN — "Precision Upload Experience — Maximum Level"
// ALL logic, file picking, analysis, skill extraction, and Provider writes
// are preserved exactly. Only Widget build() and visual layer upgraded.
//
// Research citations (unchanged):
// • [Alsaif §4.2] CV skill extraction — tokenise, stopword-filter, synonyms
// • [Alsaif §4.3] Match Strength Preview — weighted cosine similarity
// • [Tavakoli §3.6.1] computeReadinessScore() on upload
//
// PHASE 4 INTEGRATION (added):
// • _proceed() now calls ApiService.predict() and navigates to JobResultScreen
// • _isCallingApi + _apiError state fields added
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../models/career_profile.dart';
import '../services/app_state.dart';
import '../services/api_service.dart';
import '../data/jobs.dart';
import 'job_result.dart';
import 'main_nav.dart';

// ─── Analysis step model (unchanged) ─────────────────────────────────────────
class _Step {
  final double   progress;
  final String   label;
  final IconData icon;
  const _Step(this.progress, this.label, this.icon);
}

const _kSteps = [
  _Step(0.20, 'Reading your CV...',              Icons.find_in_page_outlined),
  _Step(0.45, 'Extracting text content...',      Icons.text_snippet_outlined),
  _Step(0.65, 'Identifying skills & experience...',Icons.psychology_outlined),
  _Step(0.85, 'Running TF-IDF analysis...',      Icons.auto_graph_outlined),
  _Step(1.00, 'Analysis complete!',              Icons.check_circle_outline_rounded),
];

// ─── [Alsaif §4.2] Skill synonym table (unchanged) ───────────────────────────
const Map<String, String> _kSkillSynonyms = {
  'py': 'python', 'python3': 'python',
  'js': 'javascript', 'es6': 'javascript', 'es2015': 'javascript',
  'ts': 'typescript',
  'c#': 'csharp', 'c sharp': 'csharp',
  'c++': 'cpp', 'cplusplus': 'cpp',
  'golang': 'go',
  'kotlin': 'kotlin',
  'swift': 'swift',
  'r language': 'r', 'r programming': 'r',
  'reactjs': 'react', 'react.js': 'react',
  'vuejs': 'vue', 'vue.js': 'vue',
  'nodejs': 'node.js', 'node js': 'node.js',
  'nextjs': 'next.js',
  'angular2': 'angular',
  'expressjs': 'express',
  'django rest': 'django',
  'flask api': 'flask',
  'flutter sdk': 'flutter',
  'react native': 'react native',
  'machine learning': 'machine learning', 'ml': 'machine learning',
  'deep learning': 'deep learning', 'dl': 'deep learning',
  'artificial intelligence': 'ai', 'a.i.': 'ai',
  'natural language processing': 'nlp',
  'computer vision': 'computer vision', 'cv': 'computer vision',
  'tensorflow2': 'tensorflow',
  'scikit': 'scikit-learn', 'sklearn': 'scikit-learn',
  'pandas df': 'pandas',
  'numpy arrays': 'numpy',
  'power bi': 'power bi', 'powerbi': 'power bi',
  'tableau desktop': 'tableau',
  'postgresql': 'sql', 'mysql': 'sql', 'sqlite': 'sql',
  'ms sql': 'sql', 'mssql': 'sql', 'oracle db': 'sql',
  'nosql': 'nosql', 'mongodb': 'mongodb', 'mongo': 'mongodb',
  'elastic search': 'elasticsearch',
  'apache kafka': 'kafka',
  'apache spark': 'spark',
  'amazon web services': 'aws', 'amazon aws': 'aws',
  'google cloud': 'gcp', 'google cloud platform': 'gcp',
  'microsoft azure': 'azure',
  'kubernetes': 'kubernetes', 'k8s': 'kubernetes',
  'docker containers': 'docker',
  'ci/cd': 'ci/cd', 'cicd': 'ci/cd',
  'github actions': 'ci/cd',
  'jenkins pipeline': 'ci/cd',
  'financial modelling': 'financial modeling',
  'risk mgmt': 'risk analysis',
  'ms excel': 'excel', 'microsoft excel': 'excel',
  'quickbooks online': 'quickbooks',
  'sap erp': 'sap',
  'communication skills': 'communication',
  'problem solving': 'problem solving',
  'team work': 'teamwork', 'team player': 'teamwork',
  'project mgmt': 'project management',
  'agile scrum': 'agile',
  'data driven': 'data analysis',
};

const Set<String> _kStopwords = {
  'a', 'an', 'the', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for',
  'of', 'with', 'by', 'from', 'as', 'is', 'was', 'are', 'were', 'be',
  'been', 'being', 'have', 'has', 'had', 'do', 'does', 'did', 'will',
  'would', 'could', 'should', 'may', 'might', 'must', 'can', 'this',
  'that', 'these', 'those', 'i', 'me', 'my', 'we', 'our', 'you', 'your',
  'he', 'she', 'it', 'its', 'they', 'their', 'which', 'who', 'whom',
  'work', 'worked', 'working', 'experience', 'experienced', 'year',
  'years', 'month', 'months', 'time', 'good', 'strong', 'excellent',
  'also', 'able', 'ability', 'knowledge', 'use', 'used', 'using',
  'including', 'include', 'such', 'other', 'various', 'different',
  'team', 'teams', 'company', 'university', 'course', 'degree',
};

// ─── [Alsaif §4.2] CV Skill Extractor (unchanged) ────────────────────────────
class _CvSkillExtractor {
  static List<String> extract(String text) {
    final cleaned =
    text.toLowerCase().replaceAll(RegExp(r'[^\w\s+./]'), ' ');
    final tokens = cleaned
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 1 && !_kStopwords.contains(t))
        .toList();
    final Set<String> results = {};
    for (final t in tokens) {
      results.add(_kSkillSynonyms[t] ?? t);
    }
    for (int i = 0; i < tokens.length - 1; i++) {
      final bigram   = '${tokens[i]} ${tokens[i + 1]}';
      final resolved = _kSkillSynonyms[bigram];
      if (resolved != null) results.add(resolved);
    }
    return results.where((s) => s.length > 2).toList();
  }
}

// ─── [Alsaif §4.3] Weighted cosine similarity (unchanged) ────────────────────
class _CosineSim {
  static double compute(List<String> cvSkills, List<String> jobSkills) {
    if (cvSkills.isEmpty || jobSkills.isEmpty) return 0.0;
    final cvSet  = cvSkills.map((s) => s.toLowerCase()).toSet();
    final jobSet = jobSkills.map((s) => s.toLowerCase()).toSet();
    double dotProduct = 0.0;
    for (final skill in cvSet) {
      if (jobSet.contains(skill)) dotProduct += kSkillWeight;
    }
    final cvMag  = math.sqrt(cvSet.length  * kSkillWeight * kSkillWeight);
    final jobMag = math.sqrt(jobSet.length * kSkillWeight * kSkillWeight);
    if (cvMag == 0 || jobMag == 0) return 0.0;
    return (dotProduct / (cvMag * jobMag)).clamp(0.0, 1.0);
  }
}

class _JobPreview {
  final String title;
  final String company;
  final double simScore;
  final int    matchedSkills;
  final int    totalJobSkills;
  const _JobPreview({
    required this.title,
    required this.company,
    required this.simScore,
    required this.matchedSkills,
    required this.totalJobSkills,
  });
}

// ─── Local sim-score helpers ──────────────────────────────────────────────────
Color _localSimScoreColor(double score) {
  if (score >= 0.65) return const Color(0xFF16A34A);
  if (score >= 0.35) return const Color(0xFFF59E0B);
  return const Color(0xFFDC2626);
}

String _localSimScoreLabel(double score) {
  if (score >= 0.65) return 'Strong';
  if (score >= 0.35) return 'Moderate';
  return 'Weak';
}

// ─────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS (SkillBridge-aligned)
// ─────────────────────────────────────────────────────────────────────────────
const _kPrimaryBlue = Color(0xFF1565C0);
const _kAccentGreen = Color(0xFF2E7D32);
const _kAccentTeal  = Color(0xFF00796B);
const _kWarning     = Color(0xFFF59E0B);
const _kError       = Color(0xFFDC2626);

// Light palette
const _kBgLight     = Color(0xFFF4F7FF);
const _kCardLight   = Color(0xFFFFFFFF);
const _kBorderLight = Color(0xFFE2E8F0);
const _kTextLight   = Color(0xFF0D1B2A);
const _kSubLight    = Color(0xFF64748B);

// Dark palette
const _kBgDark      = Color(0xFF0A0F1E);
const _kCardDark    = Color(0xFF141B2D);
const _kBorderDark  = Color(0xFF253047);
const _kTextDark    = Color(0xFFECF0FB);
const _kSubDark     = Color(0xFF94A3B8);

// ─── Screen ──────────────────────────────────────────────────────────────────
class CvUploadScreen extends StatefulWidget {
  const CvUploadScreen({super.key});

  @override
  State<CvUploadScreen> createState() => _CvUploadScreenState();
}

class _CvUploadScreenState extends State<CvUploadScreen>
    with TickerProviderStateMixin {

  // ── Data state (unchanged) ────────────────────────────────────────────────
  String? _fileName;
  int?    _fileBytes;
  bool    _isAnalyzing      = false;
  double  _progress         = 0.0;
  int     _currentStepIndex = -1;

  List<String>       _extractedSkills  = [];
  final Set<String>  _removedExtracted = {};

  final _skillCtrl  = TextEditingController();
  final _skillFocus = FocusNode();
  final List<String> _manualSkills = [];
  bool _showManual = false;

  final _goalCtrl = TextEditingController();

  List<_JobPreview> _matchPreviews = [];

  // ── API state ─────────────────────────────────────────────────────────────
  bool    _isCallingApi = false;
  String? _apiError;

  // ── Theme state — driven by global AppState ───────────────────────────────
  bool _isDark = false;

  // ── Animation controllers ─────────────────────────────────────────────────
  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;
  late final AnimationController _uploadSuccessCtrl;

  // ── Upload-zone press state ───────────────────────────────────────────────
  bool _isUploadHovered = false;

  // ── Theme token getters ───────────────────────────────────────────────────
  Color get _bg        => _isDark ? _kBgDark      : _kBgLight;
  Color get _cardBg    => _isDark ? _kCardDark     : _kCardLight;
  Color get _border    => _isDark ? _kBorderDark   : _kBorderLight;
  Color get _textColor => _isDark ? _kTextDark     : _kTextLight;
  Color get _subColor  => _isDark ? _kSubDark      : _kSubLight;

  // ── Typography ────────────────────────────────────────────────────────────
  TextStyle _ts(
      double size,
      FontWeight weight,
      Color color, {
        double letterSpacing = 0,
        double? height,
        TextDecoration? decoration,
      }) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        decoration: decoration,
      );

  TextStyle _displayTs(double size, Color color) => GoogleFonts.dmSans(
    fontSize: size,
    fontWeight: FontWeight.w800,
    color: color,
    letterSpacing: -0.8,
    height: 1.1,
  );

  // ─────────────────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseAnim =
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);

    _uploadSuccessCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _skillCtrl.dispose();
    _skillFocus.dispose();
    _goalCtrl.dispose();
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    _uploadSuccessCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOGIC (unchanged except _proceed)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type:              FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
      withData:          false,
    );
    if (result == null || !mounted) return;
    final file = result.files.first;
    if (file.size > 10 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'File is too large (max 10 MB). Please use a smaller CV.',
            style: _ts(13, FontWeight.w500, Colors.white),
          ),
          backgroundColor: _kError,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    _uploadSuccessCtrl.forward(from: 0);
    setState(() {
      _fileName         = file.name;
      _fileBytes        = file.size;
      _extractedSkills  = [];
      _matchPreviews    = [];
      _removedExtracted.clear();
      _isAnalyzing      = false;
      _progress         = 0.0;
      _currentStepIndex = -1;
      _apiError         = null;
    });
    _fadeCtrl.reset();
  }

  Future<void> _analyzeCV() async {
    if (_fileName == null && _manualSkills.isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.info_outline_rounded,
                color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              'Please upload your CV or enter skills manually.',
              style: _ts(13, FontWeight.w500, Colors.white),
            ),
          ]),
          action: SnackBarAction(
            label: 'Add Skills',
            onPressed: () => setState(() => _showManual = true),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _isAnalyzing      = true;
      _progress         = 0.0;
      _currentStepIndex = 0;
      _extractedSkills  = [];
      _matchPreviews    = [];
      _removedExtracted.clear();
      _apiError         = null;
    });
    _fadeCtrl.reset();

    for (int i = 0; i < _kSteps.length; i++) {
      await Future.delayed(const Duration(milliseconds: 520));
      if (!mounted) return;
      setState(() {
        _progress         = _kSteps[i].progress;
        _currentStepIndex = i;
      });
    }

    final name     = (_fileName ?? '').toLowerCase();
    final mockText = _buildMockCvText(name);
    final List<String> synonymResolved = _CvSkillExtractor.extract(mockText);
    final merged   = {...synonymResolved, ..._manualSkills}.toList();
    final previews = _computeMatchPreviews(merged);

    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _extractedSkills = merged;
      _matchPreviews   = previews;
      _isAnalyzing     = false;
    });
    _fadeCtrl.forward();

    final appState = context.read<AppState>();
    await appState.setCvUploaded(fileName: _fileName ?? 'manual_entry');
    await appState.setUserSkills(merged);
    if (_goalCtrl.text.trim().isNotEmpty) {
      await appState.setCareerGoal(_goalCtrl.text.trim());
    }
    // [Tavakoli §3.6.1] Recompute readiness after upload
    final readiness = appState.computeReadinessScore();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.stars_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'CV uploaded! Your readiness score is now $readiness/100',
                style: _ts(13, FontWeight.w600, Colors.white),
              ),
            ),
          ]),
          backgroundColor: _kAccentGreen,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  String _buildMockCvText(String name) {
    if (name.contains('data') || name.contains('analyst')) {
      return 'python sql excel data analysis pandas reporting tableau numpy scikit-learn machine learning data driven powerbi communication problem solving research statistical analysis';
    } else if (name.contains('web') || name.contains('dev') || name.contains('front')) {
      return 'html css javascript react typescript git responsive design nodejs rest api agile scrum teamwork communication vue next.js webpack testing ci/cd';
    } else if (name.contains('flutter') || name.contains('mobile')) {
      return 'dart flutter firebase rest api state management android ios kotlin swift git agile mobile development ui ux design testing problem solving';
    } else if (name.contains('finance') || name.contains('account')) {
      return 'excel financial modeling risk analysis sql reporting quickbooks sap accounting communication teamwork data analysis budgeting forecasting';
    } else if (name.contains('market') || name.contains('digital')) {
      return 'seo google ads social media content writing analytics canva communication email marketing crm excel data analysis research project management';
    } else if (name.contains('nurse') || name.contains('health') || name.contains('medical')) {
      return 'patient care clinical documentation communication emr first aid teamwork problem solving data analysis research reporting';
    } else if (name.contains('teach') || name.contains('edu')) {
      return 'curriculum design classroom management lesson planning communication lms research excel teamwork problem solving project management';
    } else if (name.contains('backend') || name.contains('server')) {
      return 'python java spring boot docker kubernetes aws rest api postgresql mongodb redis microservices ci/cd agile git communication problem solving';
    } else if (name.contains('design') || name.contains('ui') || name.contains('ux')) {
      return 'figma adobe xd sketch photoshop illustrator ui ux design prototyping wireframing user research communication html css javascript teamwork';
    } else if (name.contains('security') || name.contains('cyber')) {
      return 'cybersecurity networking linux python penetration testing firewall vpn encryption communication problem solving research teamwork risk analysis';
    } else {
      return 'communication skills excel research data analysis sql problem solving teamwork project management python microsoft office reporting';
    }
  }

  List<_JobPreview> _computeMatchPreviews(List<String> cvSkills) {
    try {
      final jobs  = allJobs;
      final cvSet = cvSkills.map((s) => s.toLowerCase()).toSet();
      final previews = jobs.map((job) {
        final jobSkillList = job.skills.map((s) => s.toLowerCase()).toList();
        final jobSkillSet  = jobSkillList.toSet();
        final sim          = _CosineSim.compute(cvSkills, jobSkillList);
        final matchedCount = cvSet.intersection(jobSkillSet).length;
        return _JobPreview(
          title:          job.title,
          company:        job.company,
          simScore:       sim,
          matchedSkills:  matchedCount,
          totalJobSkills: jobSkillList.length,
        );
      }).toList();
      previews.sort((a, b) => b.simScore.compareTo(a.simScore));
      return previews.take(3).toList();
    } catch (e) {
      debugPrint('[CvUploadScreen] _computeMatchPreviews error: $e');
      return [];
    }
  }

  void _addManualSkill(String raw) {
    final parts = raw
        .toLowerCase()
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && !_manualSkills.contains(s))
        .toList();
    if (parts.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _manualSkills.addAll(parts);
      _skillCtrl.clear();
    });
  }

  void _removeManualSkill(String skill) {
    HapticFeedback.selectionClick();
    setState(() => _manualSkills.remove(skill));
  }

  void _toggleExtractedSkill(String skill) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_removedExtracted.contains(skill)) {
        _removedExtracted.remove(skill);
      } else {
        _removedExtracted.add(skill);
      }
    });
  }

  List<String> get _visibleExtracted =>
      _extractedSkills.where((s) => !_removedExtracted.contains(s)).toList();

  // ── FIXED: _proceed now calls the backend API ─────────────────────────────
  Future<void> _proceed() async {
    final finalSkills = {..._visibleExtracted, ..._manualSkills}.toList();

    if (finalSkills.isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.info_outline_rounded,
                color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'No skills selected. Please analyse your CV or add skills manually.',
                style: _ts(13, FontWeight.w500, Colors.white),
              ),
            ),
          ]),
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isCallingApi = true;
      _apiError     = null;
    });

    try {
      final result = await ApiService.instance.predict(
        PredictionRequest(skills: finalSkills),
      );

      // Persist final skill set
      if (mounted) {
        await context.read<AppState>().setUserSkills(finalSkills);
      }

      if (!mounted) return;

      // Convert PredictionResult to CareerProfile
      final profile = CareerProfile.fromPredictionResult(result);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => JobResultScreen(profile: profile),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _apiError = e.message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                e.message,
                style: _ts(13, FontWeight.w500, Colors.white),
              ),
            ),
          ]),
          backgroundColor: _kError,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _proceed,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isCallingApi = false);
    }
  }

  void _skipToManual() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainNav()),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024)         return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _fileExtension(String name) =>
      name.contains('.') ? name.split('.').last.toUpperCase() : 'FILE';

  // ─────────────────────────────────────────────────────────────────────────
  // UI HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _card(
      Widget child, {
        EdgeInsets padding = const EdgeInsets.all(20),
        Color? borderColor,
        Color? bgColor,
        bool elevated = false,
      }) =>
      Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: bgColor ?? _cardBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderColor ?? _border, width: 1.5),
          boxShadow: elevated
              ? [
            BoxShadow(
              color: _kPrimaryBlue
                  .withValues(alpha: _isDark ? 0.25 : 0.1),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black
                  .withValues(alpha: _isDark ? 0.4 : 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ]
              : [
            BoxShadow(
              color: Colors.black
                  .withValues(alpha: _isDark ? 0.3 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      );

  Widget _sectionLabel(
      String title, {
        String? subtitle,
        IconData? icon,
      }) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (icon != null) ...[
            Icon(icon, color: _kPrimaryBlue, size: 17),
            const SizedBox(width: 7),
          ],
          Text(title,
              style: _ts(14, FontWeight.w800, _textColor,
                  letterSpacing: -0.2)),
        ]),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(subtitle, style: _ts(11.5, FontWeight.w400, _subColor)),
        ],
      ]);

  // ── FIXED: _primaryBtn with safe onPressed call ───────────────────────────
  Widget _primaryBtn(
      String label,
      VoidCallback? onPressed, {
        IconData? icon,
        Color? color,
        bool isLoading = false,
      }) {
    final btnColor   = color ?? _kPrimaryBlue;
    final isDisabled = onPressed == null || isLoading;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled
              ? null
              : () {
            HapticFeedback.mediumImpact();
            // FIXED: Safe call pattern instead of null-assertion
            onPressed.call();
          },
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            decoration: BoxDecoration(
              gradient: isDisabled
                  ? LinearGradient(colors: [
                btnColor.withValues(alpha: 0.5),
                btnColor.withValues(alpha: 0.4),
              ])
                  : LinearGradient(
                colors: [btnColor, btnColor.withValues(alpha: 0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: isDisabled
                  ? null
                  : [
                BoxShadow(
                  color: btnColor.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (isLoading) ...[
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                Text('Sending to AI...', style: _ts(15, FontWeight.w700, Colors.white)),
              ] else ...[
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(label, style: _ts(15, FontWeight.w700, Colors.white)),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  Widget _styledField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    String? helperText,
    FocusNode? focusNode,
    TextInputAction? textInputAction,
    void Function(String)? onFieldSubmitted,
  }) =>
      TextFormField(
        controller: controller,
        focusNode: focusNode,
        style: _ts(14, FontWeight.w500, _textColor),
        textInputAction: textInputAction,
        onFieldSubmitted: onFieldSubmitted,
        decoration: InputDecoration(
          hintText: hintText,
          helperText: helperText,
          prefixIcon: Icon(prefixIcon, size: 19, color: _subColor),
          filled: true,
          fillColor: _isDark
              ? _kBorderDark.withValues(alpha: 0.5)
              : const Color(0xFFF8FAFF),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _border, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _kPrimaryBlue, width: 2),
          ),
          hintStyle: _ts(13, FontWeight.w400, _subColor),
          helperStyle: _ts(11, FontWeight.w400, _subColor),
        ),
      );

  // ─────────────────────────────────────────────────────────────────────────
  // UPLOAD ZONE
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildUploadZone() {
    final hasFile = _fileName != null;

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, __) {
        final pulseScale = hasFile ? 1.0 : 1.0 + _pulseAnim.value * 0.012;
        return GestureDetector(
          onTap: _pickFile,
          onTapDown:   (_) => setState(() => _isUploadHovered = true),
          onTapUp:     (_) => setState(() => _isUploadHovered = false),
          onTapCancel: ()  => setState(() => _isUploadHovered = false),
          child: Transform.scale(
            scale: _isUploadHovered ? 0.975 : 1.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              width: double.infinity,
              height: 230,
              decoration: BoxDecoration(
                color: hasFile
                    ? _kAccentGreen
                    .withValues(alpha: _isDark ? 0.12 : 0.05)
                    : (_isDark
                    ? _kPrimaryBlue.withValues(alpha: 0.08)
                    : const Color(0xFFEEF4FF)),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: hasFile
                      ? _kAccentGreen.withValues(alpha: 0.55)
                      : _isUploadHovered
                      ? _kPrimaryBlue
                      : _kPrimaryBlue.withValues(alpha: 0.45),
                  width: 2,
                ),
                boxShadow: hasFile
                    ? [
                  BoxShadow(
                    color: _kAccentGreen.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
                    : [
                  BoxShadow(
                    color: _kPrimaryBlue
                        .withValues(alpha: pulseScale * 0.12),
                    blurRadius: 20 + pulseScale * 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(children: [
                if (!hasFile) ...[
                  Positioned(
                      top: 16, left: 16,
                      child: _dotDecor(
                          _kPrimaryBlue.withValues(alpha: 0.25))),
                  Positioned(
                      top: 16, right: 16,
                      child: _dotDecor(
                          _kPrimaryBlue.withValues(alpha: 0.25))),
                  Positioned(
                      bottom: 16, left: 16,
                      child: _dotDecor(
                          _kPrimaryBlue.withValues(alpha: 0.25))),
                  Positioned(
                      bottom: 16, right: 16,
                      child: _dotDecor(
                          _kPrimaryBlue.withValues(alpha: 0.25))),
                ],
                Center(
                  child: hasFile
                      ? _buildUploadedState()
                      : _buildEmptyUploadState(),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _dotDecor(Color color) => Container(
    width: 6,
    height: 6,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  Widget _buildEmptyUploadState() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, child) => Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _kPrimaryBlue,
                const Color(0xFF0EA5E9).withValues(alpha: 0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _kPrimaryBlue.withValues(
                    alpha: 0.3 + _pulseAnim.value * 0.2),
                blurRadius: 20 + _pulseAnim.value * 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
        child: const Icon(Icons.upload_file_rounded,
            color: Colors.white, size: 34),
      ),
      const SizedBox(height: 18),
      Text(
        'Tap to upload your CV',
        style: GoogleFonts.dmSans(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: _textColor,
          letterSpacing: -0.3,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        'PDF · DOC · DOCX · Max 10 MB',
        style: _ts(12.5, FontWeight.w500, _subColor),
      ),
    ],
  );

  Widget _buildUploadedState() {
    final ext      = _fileExtension(_fileName ?? '');
    final extColor = ext == 'PDF'
        ? const Color(0xFFDC2626)
        : const Color(0xFF1565C0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: _kAccentGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: _kAccentGreen.withValues(alpha: 0.4), width: 1.5),
              ),
              child: const Icon(Icons.description_rounded,
                  color: _kAccentGreen, size: 34),
            ),
            Positioned(
              top: -8, right: -8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: extColor,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: extColor.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(ext,
                    style: GoogleFonts.dmMono(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    )),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: 200,
          child: Text(
            _fileName ?? '',
            style: _ts(14, FontWeight.w700, _kAccentGreen),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 4),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
                color: _kAccentGreen, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            _fileBytes != null
                ? '${_formatBytes(_fileBytes!)} · Tap to change'
                : 'Tap to change',
            style: _ts(12, FontWeight.w500, _subColor),
          ),
        ]),
      ],
    ).animate().scale(
      begin: const Offset(0.8, 0.8),
      duration: 500.ms,
      curve: Curves.elasticOut,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FEATURE PILLS ROW
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildFeaturePills() {
    const features = [
      (icon: Icons.radar_rounded,    label: 'Better Matches'),
      (icon: Icons.bolt_rounded,     label: 'Auto-fill'),
      (icon: Icons.verified_rounded, label: 'ATS Ready'),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: features.asMap().entries.map((e) {
        final f = e.value;
        return Container(
          margin: EdgeInsets.only(
              right: e.key < features.length - 1 ? 8 : 0),
          padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: _border, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(f.icon, size: 13, color: _kPrimaryBlue),
            const SizedBox(width: 5),
            Text(f.label, style: _ts(11.5, FontWeight.w600, _textColor)),
          ]),
        ).animate().fadeIn(delay: (e.key * 80).ms).slideX(begin: 0.1);
      }).toList(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UPLOADED FILE BANNER
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildUploadedFileBanner() {
    final ext      = _fileExtension(_fileName ?? '');
    final extColor = ext == 'PDF'
        ? const Color(0xFFDC2626)
        : const Color(0xFF1565C0);

    return FadeTransition(
      opacity: _fadeAnim,
      child: _card(
        Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _kAccentGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                  color: _kAccentGreen.withValues(alpha: 0.35), width: 1.5),
            ),
            child: Stack(alignment: Alignment.center, children: [
              const Icon(Icons.description_rounded,
                  color: _kAccentGreen, size: 22),
              Positioned(
                bottom: 1, right: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    color: extColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(ext,
                      style: GoogleFonts.dmMono(
                        fontSize: 6,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      )),
                ),
              ),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _fileName ?? 'Uploaded',
                    style: _ts(14, FontWeight.w700, _textColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                          color: _kAccentGreen, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Text('Analysed successfully',
                        style: _ts(12, FontWeight.w600, _kAccentGreen)),
                    if (_fileBytes != null) ...[
                      const SizedBox(width: 8),
                      Text('·',
                          style: _ts(12, FontWeight.w400, _subColor)),
                      const SizedBox(width: 8),
                      Text(_formatBytes(_fileBytes!),
                          style: _ts(12, FontWeight.w400, _subColor)),
                    ],
                  ]),
                ]),
          ),
          GestureDetector(
            onTap: _pickFile,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _kPrimaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                    color: _kPrimaryBlue.withValues(alpha: 0.3)),
              ),
              child: Text('Change',
                  style: _ts(12, FontWeight.w700, _kPrimaryBlue)),
            ),
          ),
        ]),
        elevated: true,
        borderColor: _kAccentGreen.withValues(alpha: 0.4),
        bgColor: _kAccentGreen
            .withValues(alpha: _isDark ? 0.08 : 0.04),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ANALYSIS PROGRESS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildAnalysisProgress() {
    final step =
    _currentStepIndex >= 0 && _currentStepIndex < _kSteps.length
        ? _kSteps[_currentStepIndex]
        : null;

    return _card(
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kPrimaryBlue, Color(0xFF0EA5E9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.manage_search_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Analysing Profile',
                      style: _ts(14, FontWeight.w700, _textColor)),
                  if (step != null)
                    Text(step.label,
                        style: _ts(11.5, FontWeight.w500, _subColor))
                        .animate(key: ValueKey(_currentStepIndex))
                        .fadeIn(duration: 300.ms),
                ]),
          ),
          Text(
            '${(_progress * 100).round()}%',
            style: _displayTs(18, _kPrimaryBlue),
          ),
        ]),

        const SizedBox(height: 18),

        Row(
          children: List.generate(_kSteps.length, (i) {
            final isDone    = i < _currentStepIndex;
            final isCurrent = i == _currentStepIndex;
            return Expanded(
              child: Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutBack,
                  width:  isCurrent ? 36 : 32,
                  height: isCurrent ? 36 : 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone
                        ? _kAccentGreen
                        : isCurrent
                        ? _kPrimaryBlue
                        : (_isDark
                        ? _kBorderDark
                        : const Color(0xFFF1F5F9)),
                    boxShadow: (isDone || isCurrent)
                        ? [
                      BoxShadow(
                        color: (isDone
                            ? _kAccentGreen
                            : _kPrimaryBlue)
                            .withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                        : null,
                  ),
                  child: Icon(
                    isDone ? Icons.check_rounded : _kSteps[i].icon,
                    size: isCurrent ? 17 : 15,
                    color: (isDone || isCurrent) ? Colors.white : _subColor,
                  ),
                ),
                if (i < _kSteps.length - 1)
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      height: 2,
                      decoration: BoxDecoration(
                        color: isDone ? _kAccentGreen : _border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ]),
            );
          }),
        ),

        const SizedBox(height: 16),

        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: _progress),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            builder: (_, val, __) => LinearProgressIndicator(
              value: val,
              minHeight: 8,
              backgroundColor: _border,
              valueColor: AlwaysStoppedAnimation(
                _progress >= 1.0 ? _kAccentGreen : _kPrimaryBlue,
              ),
            ),
          ),
        ),

        if (_progress >= 1.0) ...[
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.check_circle_rounded,
                color: _kAccentGreen, size: 16),
            const SizedBox(width: 7),
            Text('Profile analysis complete',
                style: _ts(12.5, FontWeight.w700, _kAccentGreen)),
          ]).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1),
        ],
      ]),
      elevated: true,
      borderColor: _kPrimaryBlue.withValues(alpha: 0.3),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SKILL STATS SUMMARY
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSkillStats() {
    final total    = _extractedSkills.length;
    final selected = _visibleExtracted.length;
    final removed  = _removedExtracted.length;
    final manual   = _manualSkills.length;

    final stats = [
      (label: 'Total',   value: total,    color: _kPrimaryBlue),
      (label: 'Active',  value: selected, color: _kAccentGreen),
      (label: 'Removed', value: removed,  color: _kError),
      (label: 'Manual',  value: manual,   color: _kWarning),
    ];

    return Row(
      children: stats.asMap().entries.map((e) {
        final s = e.value;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(
                right: e.key < stats.length - 1 ? 8 : 0),
            padding: const EdgeInsets.symmetric(
                vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: s.color.withValues(alpha: _isDark ? 0.12 : 0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: s.color.withValues(alpha: 0.3), width: 1.5),
            ),
            child: Column(children: [
              Text('${s.value}', style: _displayTs(20, s.color)),
              const SizedBox(height: 3),
              Text(s.label,
                  style: _ts(10, FontWeight.w600, s.color)),
            ]),
          ).animate().fadeIn(delay: (e.key * 60).ms).slideY(begin: 0.15),
        );
      }).toList(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EXTRACTED SKILLS PANEL
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildExtractedSkillsPanel() {
    final visible = _visibleExtracted.length;
    final total   = _extractedSkills.length;

    return FadeTransition(
      opacity: _fadeAnim,
      child: _card(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _kAccentGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                    color: _kAccentGreen.withValues(alpha: 0.4), width: 1.5),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: _kAccentGreen, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$visible of $total skills selected',
                        style: _ts(14, FontWeight.w800, _kAccentGreen)),
                    Text('Tap a skill chip to toggle it on/off',
                        style: _ts(11, FontWeight.w400, _subColor)),
                  ]),
            ),
          ]),
          const SizedBox(height: 16),
          Wrap(
            spacing: 7,
            runSpacing: 8,
            children: _extractedSkills.asMap().entries.map((e) {
              final skill   = e.value;
              final removed = _removedExtracted.contains(skill);
              return GestureDetector(
                onTap: () => _toggleExtractedSkill(skill),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: removed
                        ? (_isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.withValues(alpha: 0.1))
                        : _kAccentGreen,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: removed
                          ? _subColor.withValues(alpha: 0.3)
                          : _kAccentGreen,
                      width: 1,
                    ),
                    boxShadow: removed
                        ? null
                        : [
                      BoxShadow(
                        color: _kAccentGreen.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      removed ? Icons.add_rounded : Icons.check_rounded,
                      size: 12,
                      color: removed ? _subColor : Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      skill,
                      style: _ts(
                        11,
                        FontWeight.w600,
                        removed ? _subColor : Colors.white,
                        decoration: removed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ]),
                ),
              ).animate().fadeIn(delay: (e.key * 30).ms);
            }).toList(),
          ),
        ]),
        borderColor: _kAccentGreen.withValues(alpha: 0.4),
        bgColor: _kAccentGreen
            .withValues(alpha: _isDark ? 0.07 : 0.04),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MANUAL SKILLS SECTION
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildManualSkillsSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _card(
        Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.edit_note_rounded,
                    color: _kAccentTeal, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: _sectionLabel(
                    'Manual Skill Entry',
                    subtitle: 'Add skills not found in your CV',
                  ),
                ),
                Transform.scale(
                  scale: 0.85,
                  child: Switch(
                    value: _showManual,
                    activeTrackColor: _kPrimaryBlue,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      setState(() => _showManual = v);
                    },
                  ),
                ),
              ]),

              if (_showManual) ...[
                const SizedBox(height: 16),
                Divider(color: _border, height: 1),
                const SizedBox(height: 16),
                Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _styledField(
                          controller: _skillCtrl,
                          focusNode: _skillFocus,
                          hintText: 'e.g. python, sql, communication',
                          prefixIcon: Icons.add_circle_outline_rounded,
                          helperText: 'Separate multiple skills with commas',
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (v) {
                            _addManualSkill(v);
                            _skillFocus.requestFocus();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 52,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              _addManualSkill(_skillCtrl.text);
                              _skillFocus.requestFocus();
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: 52,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [_kPrimaryBlue, Color(0xFF0EA5E9)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: _kPrimaryBlue.withValues(alpha: 0.35),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.add_rounded,
                                  color: Colors.white, size: 22),
                            ),
                          ),
                        ),
                      ),
                    ]),

                if (_manualSkills.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 7, runSpacing: 8,
                    children: _manualSkills.asMap().entries.map((e) {
                      final s = e.value;
                      return GestureDetector(
                        onTap: () => _removeManualSkill(s),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 6),
                          decoration: BoxDecoration(
                            color: _kAccentTeal,
                            borderRadius: BorderRadius.circular(100),
                            boxShadow: [
                              BoxShadow(
                                color: _kAccentTeal.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(s,
                                    style:
                                    _ts(11, FontWeight.w600, Colors.white)),
                                const SizedBox(width: 5),
                                const Icon(Icons.close_rounded,
                                    size: 12, color: Colors.white70),
                              ]),
                        ),
                      ).animate().fadeIn(delay: (e.key * 40).ms).slideX(begin: 0.2);
                    }).toList(),
                  ),
                ],
              ],
            ]),
      ),
    ],
  );

  // ─────────────────────────────────────────────────────────────────────────
  // MATCH STRENGTH SECTION
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildMatchStrengthSection() => FadeTransition(
    opacity: _fadeAnim,
    child:
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel(
        'Match Strength Preview',
        subtitle:
        'How your skills align with top job listings · [Alsaif §4.3]',
        icon: Icons.leaderboard_rounded,
      ),
      const SizedBox(height: 4),
      Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _kPrimaryBlue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
              color: _kPrimaryBlue.withValues(alpha: 0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.functions_rounded,
              size: 12, color: _kPrimaryBlue),
          const SizedBox(width: 5),
          Text('Weighted cosine similarity · skills 2×',
              style: _ts(10, FontWeight.w700, _kPrimaryBlue)),
        ]),
      ),
      const SizedBox(height: 14),
      ..._matchPreviews.asMap().entries.map(
            (e) => Padding(
          padding: EdgeInsets.only(
              bottom: e.key < _matchPreviews.length - 1 ? 12 : 0),
          child: _MatchCard(
            preview:   e.value,
            rank:      e.key + 1,
            isDark:    _isDark,
            textColor: _textColor,
            subColor:  _subColor,
            border:    _border,
            tsHelper:  _ts,
          ).animate().fadeIn(delay: (e.key * 100).ms).slideY(begin: 0.1),
        ),
      ),
    ]),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // API ERROR BANNER — FIXED: Now using _apiError field
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildApiErrorBanner() {
    if (_apiError == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kError.withValues(alpha: _isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _kError.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _kError.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: _kError,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connection Error',
                  style: _ts(13, FontWeight.w700, _kError),
                ),
                const SizedBox(height: 2),
                Text(
                  _apiError!,
                  style: _ts(12, FontWeight.w400, _subColor),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _apiError = null),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _kError.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: _kError,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TIPS CARD
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTipsCard() {
    const tips = [
      (
      icon: Icons.straighten_rounded,
      tip: 'Keep it to 1–2 pages for best results with ATS systems.'
      ),
      (
      icon: Icons.star_outline_rounded,
      tip: 'List specific tools, technologies, and measurable achievements.'
      ),
      (
      icon: Icons.picture_as_pdf_rounded,
      tip: 'Use PDF format for maximum compatibility across platforms.'
      ),
    ];
    return _card(
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _kWarning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.lightbulb_rounded,
                color: _kWarning, size: 20),
          ),
          const SizedBox(width: 12),
          _sectionLabel('CV Tips',
              subtitle: 'Best practices for SkillBridge AI'),
        ]),
        const SizedBox(height: 16),
        ...tips.asMap().entries.map(
              (e) {
            final t = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: _kWarning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _kWarning.withValues(alpha: 0.3), width: 1),
                      ),
                      child: Icon(t.icon, color: _kWarning, size: 15),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(t.tip,
                          style: _ts(13, FontWeight.w400, _subColor,
                              height: 1.6)),
                    ),
                  ]).animate().fadeIn(delay: (e.key * 80).ms).slideX(begin: 0.05),
            );
          },
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    _isDark = context.watch<AppState>().isDark;

    final hasResult    = _extractedSkills.isNotEmpty;
    final showProgress =
        _isAnalyzing || (_progress > 0 && _progress < 1.0);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0.5,
        shadowColor: _border,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: _textColor, size: 22),
          onPressed: () => Navigator.maybePop(context),
          tooltip: 'Back',
        ),
        title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Upload CV',
                  style:
                  _ts(17, FontWeight.w800, _textColor, letterSpacing: -0.3)),
              Text('SkillBridge AI · SDG-8',
                  style: _ts(10, FontWeight.w500, _subColor)),
            ]),
        actions: [
          if (hasResult)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _kAccentGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                    color: _kAccentGreen.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_circle_rounded,
                    color: _kAccentGreen, size: 12),
                const SizedBox(width: 4),
                Text(
                  '${_visibleExtracted.length} skills',
                  style: _ts(11, FontWeight.w700, _kAccentGreen),
                ),
              ]),
            ),
          TextButton(
            onPressed: _skipToManual,
            child: Text('Skip',
                style: _ts(13, FontWeight.w600, _subColor)),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(color: _border, thickness: 1, height: 1),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── API Error Banner (FIXED: uses _apiError) ───────────────
              _buildApiErrorBanner(),

              // ── Hero header ────────────────────────────────────────────
              if (!hasResult) ...[
                Text(
                  'Let\'s build your\ncareer profile',
                  style: GoogleFonts.dmSans(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: _textColor,
                    letterSpacing: -1.0,
                    height: 1.2,
                  ),
                ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.1),
                const SizedBox(height: 6),
                Text(
                  'Upload your CV for AI-powered job matching [Alsaif §4.3]',
                  style: _ts(13, FontWeight.w400, _subColor, height: 1.5),
                ).animate().fadeIn(delay: 100.ms, duration: 500.ms),
                const SizedBox(height: 20),
              ],

              // ── Upload zone / uploaded banner ──────────────────────────
              if (!hasResult) ...[
                _buildUploadZone()
                    .animate()
                    .fadeIn(delay: 150.ms, duration: 500.ms)
                    .slideY(begin: 0.08),
                const SizedBox(height: 14),
                _buildFeaturePills(),
              ] else ...[
                _buildUploadedFileBanner(),
                const SizedBox(height: 14),
                _primaryBtn(
                  'Continue with ${_visibleExtracted.length} skills  →',
                  _isCallingApi ? null : _proceed,
                  icon: Icons.arrow_forward_rounded,
                  color: _kAccentGreen,
                  isLoading: _isCallingApi,
                ).animate().fadeIn(duration: 400.ms),
              ],

              // ── Analysis progress ──────────────────────────────────────
              if (showProgress) ...[
                const SizedBox(height: 20),
                _buildAnalysisProgress()
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.1),
              ],

              // ── Job role preference ────────────────────────────────────
              const SizedBox(height: 24),
              _sectionLabel(
                'Preferred Job Role',
                subtitle: 'Optional — helps refine your match results',
                icon: Icons.flag_rounded,
              ),
              const SizedBox(height: 10),
              _styledField(
                controller: _goalCtrl,
                hintText: 'e.g. Data Analyst, Flutter Developer',
                prefixIcon: Icons.work_outline_rounded,
              ),

              // ── Manual skill toggle ────────────────────────────────────
              const SizedBox(height: 20),
              _buildManualSkillsSection(),

              // ── Analyse button ─────────────────────────────────────────
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isAnalyzing ? null : _analyzeCV,
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      decoration: BoxDecoration(
                        gradient: _isAnalyzing
                            ? LinearGradient(colors: [
                          _kPrimaryBlue.withValues(alpha: 0.5),
                          _kPrimaryBlue.withValues(alpha: 0.4),
                        ])
                            : const LinearGradient(
                          colors: [_kPrimaryBlue, Color(0xFF1A56DB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: _isAnalyzing
                            ? null
                            : [
                          BoxShadow(
                            color: _kPrimaryBlue.withValues(alpha: 0.4),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isAnalyzing)
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: const AlwaysStoppedAnimation(
                                    Colors.white),
                                value: _progress,
                              ),
                            )
                          else
                            Icon(
                              hasResult
                                  ? Icons.refresh_rounded
                                  : Icons.auto_awesome_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          const SizedBox(width: 10),
                          Text(
                            _isAnalyzing
                                ? 'Analysing... ${(_progress * 100).round()}%'
                                : hasResult
                                ? 'Re-Analyse Profile'
                                : 'Analyse My Profile',
                            style:
                            _ts(15, FontWeight.w700, Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Results section ────────────────────────────────────────
              if (hasResult) ...[
                const SizedBox(height: 24),
                _buildSkillStats(),
                const SizedBox(height: 16),
                _buildExtractedSkillsPanel(),
                if (_matchPreviews.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildMatchStrengthSection(),
                ],
                const SizedBox(height: 20),
                FadeTransition(
                  opacity: _fadeAnim,
                  child: _primaryBtn(
                    'Continue with ${_visibleExtracted.length} skills  →',
                    _isCallingApi ? null : _proceed,
                    icon: Icons.arrow_forward_rounded,
                    isLoading: _isCallingApi,
                  ),
                ),
              ],

              // ── Tips ──────────────────────────────────────────────────
              const SizedBox(height: 24),
              _buildTipsCard(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MATCH CARD — [Alsaif §4.3] tiered similarity display
// ─────────────────────────────────────────────────────────────────────────────
class _MatchCard extends StatelessWidget {
  final _JobPreview preview;
  final int         rank;
  final bool        isDark;
  final Color       textColor;
  final Color       subColor;
  final Color       border;
  final TextStyle Function(
      double,
      FontWeight,
      Color, {
      double letterSpacing,
      double? height,
      TextDecoration? decoration,
      }) tsHelper;

  const _MatchCard({
    required this.preview,
    required this.rank,
    required this.isDark,
    required this.textColor,
    required this.subColor,
    required this.border,
    required this.tsHelper,
  });

  static const _rankColors = [
    Color(0xFFF59E0B), // Gold
    Color(0xFF94A3B8), // Silver
    Color(0xFFB45309), // Bronze
  ];

  @override
  Widget build(BuildContext context) {
    final score     = preview.simScore;
    final tierColor = _localSimScoreColor(score);
    final tierLabel = _localSimScoreLabel(score);
    final rankColor = rank <= 3
        ? _rankColors[rank - 1]
        : const Color(0xFF64748B);

    final cardColor = isDark ? const Color(0xFF141B2D) : Colors.white;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: tierColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: tierColor.withValues(alpha: isDark ? 0.15 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: rankColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: rankColor.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text('#$rank',
                      style: GoogleFonts.dmMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      )),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preview.title,
                        style: tsHelper(14, FontWeight.w700, textColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(preview.company,
                          style: tsHelper(12, FontWeight.w400, subColor)),
                    ]),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: tierColor.withValues(alpha: 0.4), width: 1.5),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    '${(score * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: tierColor,
                    ),
                  ),
                  Text(tierLabel,
                      style: tsHelper(9, FontWeight.w600, tierColor)),
                ]),
              ),
            ]),

            const SizedBox(height: 14),

            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: score),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (_, val, __) => Stack(
                  children: [
                    Container(
                      height: 9,
                      color: isDark
                          ? const Color(0xFF253047)
                          : const Color(0xFFE2E8F0),
                    ),
                    FractionallySizedBox(
                      widthFactor: val.clamp(0.0, 1.0),
                      child: Container(
                        height: 9,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              tierColor,
                              tierColor.withValues(alpha: 0.7),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 9),

            Row(children: [
              Icon(Icons.check_circle_outline_rounded,
                  color: tierColor, size: 13),
              const SizedBox(width: 5),
              Text(
                '${preview.matchedSkills} of ${preview.totalJobSkills} skills matched',
                style: tsHelper(10.5, FontWeight.w500, subColor),
              ),
              const Spacer(),
              Text(
                '${(score * 100).toStringAsFixed(1)}% similarity',
                style: tsHelper(10.5, FontWeight.w700, tierColor),
              ),
            ]),
          ]),
    );
  }
}