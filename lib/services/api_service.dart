// lib/services/api_service.dart — SkillBridge AI
//
// HTTP layer between Flutter and the SkillBridge backend (Render.com).
//
// Contract:
//   POST /predict  { skills?: [...], cv_text?: string }
//                → { jobs: [...], confidence: [...],
//                    skills_gap: [...], courses: [...] }
//   GET  /health  → { status: "ok" }
//
// All models support both object and plain-string backend responses
// so the Flutter app stays compatible if the backend evolves.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// =============================================================================
// CONFIGURATION
// =============================================================================

class ApiConfig {
  ApiConfig._();

  /// ⚠️  Replace with your actual Render.com service URL before deploying.
  static const String baseUrl = 'https://skillbridge-ai.onrender.com';

  /// Predict endpoint — POST, JSON body.
  static const String predictPath = '/predict';

  /// Health endpoint — GET, no body.
  static const String healthPath = '/health';

  /// Total time budget per request (Render free tier cold-starts ~15 s).
  static const Duration timeout = Duration(seconds: 45);

  /// Health-check timeout (fast ping only).
  static const Duration healthTimeout = Duration(seconds: 12);
}

// =============================================================================
// EXCEPTION
// =============================================================================

class ApiException implements Exception {
  final String message;
  final int?   statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException(${statusCode ?? "—"}): $message';
}

// =============================================================================
// REQUEST MODEL
// =============================================================================

class PredictionRequest {
  final List<String>? skills;
  final String?       cvText;

  const PredictionRequest({this.skills, this.cvText})
      : assert(
  (skills != null && skills.length > 0) || (cvText != null),
  'PredictionRequest requires either skills or cvText.',
  );

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (skills != null && skills!.isNotEmpty) map['skills']  = skills;
    if (cvText  != null && cvText!.isNotEmpty) map['cv_text'] = cvText;
    return map;
  }
}

// =============================================================================
// RESPONSE MODELS
// =============================================================================

/// A single job returned by the backend.
/// Handles both structured objects and plain title strings.
class ApiJob {
  final String  title;
  final String? industry;
  final String? level;
  final double? matchScore;

  const ApiJob({
    required this.title,
    this.industry,
    this.level,
    this.matchScore,
  });

  /// Parse from a full JSON object.
  factory ApiJob.fromJson(Map<String, dynamic> json) => ApiJob(
    title:      (json['title']  as String?)
        ?? (json['job']    as String?)
        ?? '',
    industry:   json['industry']   as String?,
    level:      json['level']      as String?,
    matchScore: (json['match_score'] as num?)?.toDouble()
        ?? (json['score']       as num?)?.toDouble(),
  );

  /// Parse from either a JSON object or a plain string.
  factory ApiJob.fromDynamic(dynamic raw) {
    if (raw is Map<String, dynamic>) return ApiJob.fromJson(raw);
    return ApiJob(title: raw.toString());
  }
}

/// A single course recommendation returned by the backend.
class ApiCourse {
  final String  title;
  final String? url;
  final String? provider;
  final String? skill;

  const ApiCourse({
    required this.title,
    this.url,
    this.provider,
    this.skill,
  });

  factory ApiCourse.fromJson(Map<String, dynamic> json) => ApiCourse(
    title:    (json['title']  as String?)
        ?? (json['course'] as String?)
        ?? '',
    url:      json['url']      as String?,
    provider: json['provider'] as String?,
    skill:    json['skill']    as String?,
  );

  factory ApiCourse.fromDynamic(dynamic raw) {
    if (raw is Map<String, dynamic>) return ApiCourse.fromJson(raw);
    return ApiCourse(title: raw.toString());
  }
}

/// Full prediction response from the backend.
class PredictionResult {
  final List<ApiJob>    jobs;
  final List<double>    confidence;
  final List<String>    skillsGap;
  final List<ApiCourse> courses;

  const PredictionResult({
    required this.jobs,
    required this.confidence,
    required this.skillsGap,
    required this.courses,
  });

  bool get isEmpty =>
      jobs.isEmpty && courses.isEmpty && skillsGap.isEmpty;

  bool get isNotEmpty => !isEmpty;

  /// Top confidence value (0.0 – 1.0), or null when empty.
  double? get topConfidence =>
      confidence.isEmpty ? null : confidence.reduce((a, b) => a > b ? a : b);

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    final rawJobs    = json['jobs']       as List<dynamic>? ?? [];
    final rawConf    = json['confidence'] as List<dynamic>? ?? [];
    final rawGap     = json['skills_gap'] as List<dynamic>? ?? [];
    final rawCourses = json['courses']    as List<dynamic>? ?? [];

    return PredictionResult(
      jobs:       rawJobs.map(ApiJob.fromDynamic).toList(),
      confidence: rawConf
          .map((e) => (e as num?)?.toDouble() ?? 0.0)
          .toList(),
      skillsGap: rawGap.map((e) => e.toString()).toList(),
      courses:   rawCourses.map(ApiCourse.fromDynamic).toList(),
    );
  }

  factory PredictionResult.empty() => const PredictionResult(
    jobs:       [],
    confidence: [],
    skillsGap:  [],
    courses:    [],
  );
}

// =============================================================================
// SERVICE
// =============================================================================

/// Singleton HTTP service — use [ApiService.instance] everywhere.
class ApiService {
  ApiService._();

  static final ApiService instance = ApiService._();

  /// Internal client — kept alive for connection pooling.
  final http.Client _client = http.Client();

  // ── Health check ──────────────────────────────────────────────────────────

  /// Returns `true` if the backend responds with HTTP 200.
  /// Safe to call before heavy operations to detect cold-start.
  Future<bool> healthCheck() async {
    try {
      final response = await _client
          .get(Uri.parse('${ApiConfig.baseUrl}${ApiConfig.healthPath}'))
          .timeout(ApiConfig.healthTimeout);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[ApiService] healthCheck failed: $e');
      return false;
    }
  }

  // ── Predict ───────────────────────────────────────────────────────────────

  /// Calls POST /predict and returns a typed [PredictionResult].
  ///
  /// Throws [ApiException] on any non-200 response or network error.
  Future<PredictionResult> predict(PredictionRequest request) async {
    final uri  = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.predictPath}');
    final body = jsonEncode(request.toJson());

    debugPrint('[ApiService] POST /predict → $body');

    try {
      final response = await _client
          .post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: body,
      )
          .timeout(ApiConfig.timeout);

      _logResponse(response);

      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(
        'The request timed out. '
            'The server may be starting up — please try again in a moment.',
      );
    } on http.ClientException catch (e) {
      throw ApiException('Network error: ${e.message}');
    } catch (e) {
      throw ApiException('Unexpected error: $e');
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  PredictionResult _handleResponse(http.Response response) {
    switch (response.statusCode) {
      case 200:
        return _parseBody(response.body);

      case 400:
        throw const ApiException(
          'Invalid request. Please check your input and try again.',
          statusCode: 400,
        );

      case 422:
        throw const ApiException(
          'Validation error — please provide valid skills or CV text.',
          statusCode: 422,
        );

      case 429:
        throw const ApiException(
          'Too many requests. Please wait a moment before trying again.',
          statusCode: 429,
        );

      case 503:
        throw const ApiException(
          'The server is temporarily unavailable. Please try again shortly.',
          statusCode: 503,
        );

      default:
        if (response.statusCode >= 500) {
          throw ApiException(
            'Server error (${response.statusCode}). Please try again later.',
            statusCode: response.statusCode,
          );
        }
        throw ApiException(
          'Unexpected response: ${response.statusCode}',
          statusCode: response.statusCode,
        );
    }
  }

  PredictionResult _parseBody(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return PredictionResult.fromJson(decoded);
      }
      throw const ApiException('Unexpected response format from server.');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to parse server response: $e');
    }
  }

  void _logResponse(http.Response r) {
    if (!kDebugMode) return;
    final preview = r.body.length > 300
        ? '${r.body.substring(0, 300)}…'
        : r.body;
    debugPrint('[ApiService] ← ${r.statusCode} $preview');
  }

  // ── Dispose ───────────────────────────────────────────────────────────────

  void dispose() => _client.close();
}