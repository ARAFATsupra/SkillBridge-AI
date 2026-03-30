// lib/ml/tfidf.dart — SkillBridge AI
// TF-IDF Calculator with Domain Keyword Boosting, Attention Weighting,
// Stateful Corpus Engine, BM25 Scoring, and Multi-Word Phrase Detection.
//
// Research foundations:
//   - Ajjam & Al-Raweshidy (2026): TF-IDF vectorisation, smooth IDF,
//     stopword removal — outperforms SBERT on Precision@10 & Recall@10
//     (Cohen's D = 2.727).
//   - Huang (2022): Attention mechanism to amplify the most salient features.
//     High-signal terms ('python', 'machine learning', 'sql') take more weight.
//   - Alsaif et al. (2022): Tokenisation, lemmatisation, stopword removal
//     pipeline; skill-weighted cosine similarity
//     (kSkillWeight = 2.0, kDomainWeight = 1.0).
//   - Tavakoli et al. (2022): Labour-market driven feature extraction from
//     job postings.
//   - Robertson & Zaragoza (2009): BM25 ranking function (Okapi BM25)
//     as a complementary retrieval baseline.
//
// Refactor notes vs previous version:
//   • TfIdfCorpus._buildVecFromTokens: replaced `_attentionWeights?[term]`
//     (redundant null-conditional inside an already null-checked branch) with
//     `_attentionWeights![term]` (non-null assertion). Same fix applied to
//     `_boostTerms?[term]`. The `final skillTerms = _skillTerms` local alias
//     is also removed in favour of the direct non-null assertion pattern for
//     consistency.
//   • bm25Rank: sort parameter renamed from `b_` to `bb` — avoids the
//     trailing-underscore convention, which is typically reserved for
//     overriding reserved words, while still preventing shadowing of the `b`
//     parameter.
//   • All constants, formulas, weight tables, phrase sets, synonym maps, and
//     public APIs are unchanged.

import 'dart:math' show log, sqrt;

// ─────────────────────────────────────────────────────────────────────────────
// WEIGHT CONSTANTS  [Alsaif et al. §4.3]
// ─────────────────────────────────────────────────────────────────────────────

/// Weight multiplier for recognised skill keywords.
///
/// Skills receive 2.0; domain-generic terms receive [kDomainWeight] = 1.0.
/// [Alsaif et al. §4.3] — "we assigned higher weights to job skills when
/// compared to the job domain of the user while computing similarity scores."
const double kSkillWeight = 2.0;

/// Weight multiplier for domain terms that are not explicit skill keywords.
/// [Alsaif et al. §4.3]
const double kDomainWeight = 1.0;

/// Default BM25 term-saturation parameter k₁.
///
/// Controls how quickly term-frequency saturation is reached.
/// Standard value from Robertson & Zaragoza (2009) §3.
const double kBm25K1 = 1.5;

/// Default BM25 length-normalisation parameter b.
///
/// 0 = no length normalisation; 1 = full normalisation.
/// Standard value from Robertson & Zaragoza (2009) §3.
const double kBm25B = 0.75;

// ─────────────────────────────────────────────────────────────────────────────
// SYNONYM MAP  [Alsaif et al. §4.2]
// ─────────────────────────────────────────────────────────────────────────────

/// Common skill abbreviations normalised to their canonical form.
///
/// Applied during tokenisation so all downstream TF-IDF computations operate
/// on a consistent vocabulary.  [Alsaif et al. §4.2]
///
/// Entries are lower-cased; callers need not pre-lowercase keys.
const Map<String, String> skillSynonyms = {
  // Programming / data
  'js': 'javascript',
  'ts': 'typescript',
  'py': 'python',
  'ml': 'machine learning',
  'dl': 'deep learning',
  'nlp': 'natural language processing',
  'cv': 'computer vision',
  'db': 'database',
  'dbs': 'database',
  // Engineering practices
  'oop': 'object oriented',
  'fp': 'functional programming',
  'tdd': 'test driven development',
  'ci': 'continuous integration',
  'cd': 'continuous delivery',
  'cicd': 'continuous integration',
  // UI / UX
  'ui': 'user interface',
  'ux': 'user experience',
  // Web
  'css': 'cascading style sheets',
  'html': 'hypertext markup language',
  'http': 'hypertext transfer protocol',
  'rest': 'restful api',
  'gql': 'graphql',
  // Cloud / infra
  'k8s': 'kubernetes',
  'gcp': 'google cloud platform',
  'az': 'azure',
  'iac': 'infrastructure as code',
  // Data
  'etl': 'extract transform load',
  'bi': 'business intelligence',
  'kpi': 'key performance indicator',
  // Soft skills
  'pm': 'project management',
  'mgmt': 'management',
};

/// Canonical multi-word phrases recognised during bigram/trigram detection.
///
/// Keys must be space-joined, lowercase token sequences.
/// When the tokeniser detects a consecutive sequence matching a key, it
/// replaces the individual tokens with the single phrase token, ensuring
/// that [kDefaultAttentionWeights] entries like `'machine learning'` are
/// scored as a unit rather than as two separate low-IDF tokens.
const Set<String> kKnownPhrases = {
  'machine learning',
  'deep learning',
  'natural language processing',
  'computer vision',
  'data science',
  'data analysis',
  'data engineering',
  'neural network',
  'neural networks',
  'restful api',
  'object oriented',
  'test driven development',
  'continuous integration',
  'continuous delivery',
  'extract transform load',
  'business intelligence',
  'project management',
  'user interface',
  'user experience',
  'cascading style sheets',
  'hypertext markup language',
  'infrastructure as code',
  'google cloud platform',
  'key performance indicator',
  'software development',
  'software engineering',
  'product management',
  'technical leadership',
  'communication skills',
  'problem solving',
  'critical thinking',
  'team collaboration',
  'version control',
};

// ─────────────────────────────────────────────────────────────────────────────
// ATTENTION WEIGHTS  [Huang 2022; Ajjam & Al-Raweshidy 2026]
// ─────────────────────────────────────────────────────────────────────────────

/// Default domain-critical keyword attention weights for tech / labour-market
/// context.
///
/// Organised into tiers:
///   Tier-1 (2.0): Core technical differentiators
///   Tier-2 (1.6): Strong domain signals
///   Tier-3 (1.3): Valuable but frequent skills
///
/// Weights are multiplicative scalars applied on top of TF-IDF values
/// [Huang, 2022; Ajjam & Al-Raweshidy, 2026 p. 7].
const Map<String, double> kDefaultAttentionWeights = <String, double>{
  // ── Tier-1: Core technical skills ──────────────────────────────────────────
  'python': 2.0,
  'machine learning': 2.0,
  'deep learning': 2.0,
  'sql': 2.0,
  'data science': 2.0,
  'neural network': 2.0,
  'neural networks': 2.0,
  'natural language processing': 2.0,
  'computer vision': 2.0,
  'tensorflow': 2.0,
  'pytorch': 2.0,
  'llm': 2.0,
  'large language model': 2.0,
  'reinforcement learning': 2.0,

  // ── Tier-2: Strong domain signals ──────────────────────────────────────────
  'flutter': 1.6,
  'dart': 1.6,
  'react': 1.6,
  'node.js': 1.6,
  'docker': 1.6,
  'kubernetes': 1.6,
  'aws': 1.6,
  'azure': 1.6,
  'google cloud platform': 1.6,
  'cloud': 1.6,
  'restful api': 1.6,
  'graphql': 1.6,
  'git': 1.6,
  'java': 1.6,
  'kotlin': 1.6,
  'swift': 1.6,
  'c++': 1.6,
  'rust': 1.6,
  'go': 1.6,
  'data analysis': 1.6,
  'data engineering': 1.6,
  'extract transform load': 1.6,
  'cybersecurity': 1.6,
  'blockchain': 1.6,
  'devops': 1.6,
  'infrastructure as code': 1.6,
  'continuous integration': 1.6,
  'continuous delivery': 1.6,

  // ── Tier-3: Valuable but frequent ──────────────────────────────────────────
  'javascript': 1.3,
  'typescript': 1.3,
  'hypertext markup language': 1.3,
  'cascading style sheets': 1.3,
  'communication skills': 1.3,
  'leadership': 1.3,
  'project management': 1.3,
  'product management': 1.3,
  'agile': 1.3,
  'scrum': 1.3,
  'excel': 1.3,
  'research': 1.3,
  'problem solving': 1.3,
  'team collaboration': 1.3,
  'version control': 1.3,
  'software engineering': 1.3,
  'software development': 1.3,
};

// ─────────────────────────────────────────────────────────────────────────────
// DEFAULT STOPWORDS
// ─────────────────────────────────────────────────────────────────────────────

/// Extended English stopword list used as the default in all processing steps.
///
/// Stored as a top-level constant so it is allocated once at programme start.
const List<String> kDefaultStopwords = <String>[
  'a', 'an', 'the', 'and', 'or', 'for', 'to', 'of', 'in', 'on',
  'at', 'by', 'with', 'from', 'as', 'is', 'was', 'are', 'were',
  'be', 'been', 'being', 'have', 'has', 'had', 'do', 'does', 'did',
  'will', 'would', 'should', 'could', 'may', 'might', 'must', 'shall',
  'it', 'its', 'this', 'that', 'these', 'those', 'i', 'we', 'you',
  'he', 'she', 'they', 'them', 'our', 'your', 'their', 'my', 'his', 'her',
  'not', 'no', 'nor', 'so', 'yet', 'both', 'either', 'neither',
  'than', 'then', 'when', 'where', 'how', 'all', 'each', 'every',
  'about', 'above', 'after', 'also', 'among', 'any', 'because', 'before',
  'between', 'but', 'can', 'even', 'ever', 'just', 'like', 'many',
  'more', 'most', 'much', 'now', 'only', 'other', 'own', 'same',
  'such', 'through', 'too', 'under', 'up', 'use', 'used', 'using',
  'very', 'well', 'while', 'who', 'whom', 'whose', 'why', 'within',
  'work', 'year', 'years',
];

// ─────────────────────────────────────────────────────────────────────────────
// PUBLIC TYPES
// ─────────────────────────────────────────────────────────────────────────────

/// Immutable TF-IDF vector with its source document length and L2 norm.
///
/// Carrying the norm allows [cosineBetween] to avoid recomputing it on
/// every similarity call, which is significant during batch ranking.
class TfIdfVector {
  /// Sparse term → weight map. All values are ≥ 0.
  final Map<String, double> weights;

  /// Number of tokens in the source document **after** stopword filtering
  /// and synonym normalisation (used for BM25 length normalisation).
  final int tokenCount;

  /// Pre-computed L2 norm of [weights]. 0.0 when the vector is empty.
  final double l2Norm;

  const TfIdfVector({
    required this.weights,
    required this.tokenCount,
    required this.l2Norm,
  });

  /// Returns `true` when all weights are zero or the vector has no terms.
  bool get isEmpty => weights.isEmpty || l2Norm == 0.0;

  /// Returns the weight for [term], or 0.0 if the term is absent.
  double operator [](String term) => weights[term] ?? 0.0;

  @override
  String toString() =>
      'TfIdfVector(terms: ${weights.length}, '
          'tokenCount: $tokenCount, '
          'l2Norm: ${l2Norm.toStringAsFixed(4)})';
}

/// Pre-computed corpus IDF statistics.
///
/// Built once from a reference corpus and reused for fast online vectorisation
/// of new documents.  [Ajjam & Al-Raweshidy, 2026 — online evaluation]
class CorpusIdfStats {
  /// Smooth IDF value per normalised term.
  /// IDF(t) = log((N+1)/(df(t)+1)) + 1  [Ajjam & Al-Raweshidy 2026]
  final Map<String, double> idf;

  /// Number of documents in the corpus.
  final int documentCount;

  /// Average document length (token count after filtering), used for BM25.
  final double avgDocLength;

  const CorpusIdfStats({
    required this.idf,
    required this.documentCount,
    required this.avgDocLength,
  });

  /// IDF for [term]; returns the minimum IDF (smoothed floor) for OOV terms.
  ///
  /// Floor = log((N+1)/N) + 1 — the IDF a term present in every document
  /// would receive, ensuring OOV terms don't silently score 0 in the
  /// dot-product.  Callers may override by passing [oovIdf].
  double idfFor(String term, {double? oovIdf}) {
    final double? val = idf[term];
    if (val != null) return val;
    if (oovIdf != null) return oovIdf;
    // Smoothed floor: treat OOV as if it appeared in every document.
    if (documentCount == 0) return 1.0;
    return log((documentCount + 1) / documentCount) + 1.0;
  }

  @override
  String toString() =>
      'CorpusIdfStats(docs: $documentCount, '
          'terms: ${idf.length}, '
          'avgLen: ${avgDocLength.toStringAsFixed(1)})';
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. SYNONYM & PHRASE NORMALISATION  [Alsaif et al. §4.2]
// ─────────────────────────────────────────────────────────────────────────────

/// Normalises a single token by applying [skillSynonyms] substitution.
///
/// Processing order:
///   1. Trim whitespace.
///   2. Lowercase.
///   3. Strip punctuation (preserving hyphens, dots, and plus signs for
///      compound tokens such as `node.js` and `c++`).
///   4. Apply synonym map.
///
/// Apply this before tokenisation to ensure consistent vocabulary.
/// [Alsaif et al. §4.2]
///
/// ```dart
/// normaliseTerm('ML')      // → 'machine learning'
/// normaliseTerm('Py')      // → 'python'
/// normaliseTerm('Node.js') // → 'node.js'
/// ```
String normaliseTerm(String term) {
  final String cleaned = term
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s\-+.]'), '');
  return skillSynonyms[cleaned] ?? cleaned;
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. TOKENISATION WITH MULTI-WORD PHRASE DETECTION
// ─────────────────────────────────────────────────────────────────────────────

/// Tokenises and normalises [rawTerms], extracting multi-word phrases via a
/// sliding-window scan over bigrams and trigrams.
///
/// **Pipeline** (Alsaif et al. 2022 §4.2; Ajjam & Al-Raweshidy 2026):
///   1. Synonym-normalise each raw token via [normaliseTerm].
///   2. Strip empty tokens and stopwords.
///   3. Sliding-window scan (window sizes 3 → 2 → 1, greedy left-to-right):
///      when a consecutive n-gram matches a phrase in [knownPhrases], emit
///      the phrase as a single token and advance past all consumed tokens.
///   4. Return the final token list (unigrams + detected phrases).
///
/// Multi-word phrase detection ensures that compound attention-weighted terms
/// like `"machine learning"` are scored as a single unit rather than as two
/// separate low-IDF tokens.
///
/// [stopwords] defaults to [kDefaultStopwords].
/// [knownPhrases] defaults to [kKnownPhrases]; pass a custom set to extend or
/// override the phrase vocabulary.
List<String> tokeniseDocument(
    List<String> rawTerms, {
      List<String> stopwords = kDefaultStopwords,
      Set<String> knownPhrases = kKnownPhrases,
    }) {
  if (rawTerms.isEmpty) return const <String>[];

  final Set<String> stopSet = stopwords.toSet();

  // Step 1 + 2: normalise and filter.
  final List<String> normed = rawTerms
      .map(normaliseTerm)
      .where((String t) => t.isNotEmpty && !stopSet.contains(t))
      .toList();

  if (normed.isEmpty) return const <String>[];
  if (knownPhrases.isEmpty) return normed;

  // Step 3: greedy sliding-window phrase detection (3-gram → 2-gram → 1-gram).
  final List<String> tokens = <String>[];
  int i = 0;
  while (i < normed.length) {
    bool matched = false;
    // Try longest windows first (greedy).
    for (int w = 3; w >= 2; w--) {
      if (i + w > normed.length) continue;
      final String candidate = normed.sublist(i, i + w).join(' ');
      if (knownPhrases.contains(candidate)) {
        tokens.add(candidate);
        i += w;
        matched = true;
        break;
      }
    }
    if (!matched) {
      tokens.add(normed[i]);
      i++;
    }
  }
  return tokens;
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. TERM FREQUENCY  [Ajjam & Al-Raweshidy 2026; Alsaif et al. 2022]
// ─────────────────────────────────────────────────────────────────────────────

/// Computes the Term Frequency (TF) map for a document.
///
/// **Pipeline**:
///   1. Tokenise via [tokeniseDocument] (synonym normalisation + phrase
///      detection + stopword filtering).
///   2. Count raw term occurrences.
///   3. Apply TF formula:
///        - Raw mode:  TF(t) = count(t) / Σ count(*)
///        - Log mode:  TF(t) = 1 + log₁₀(count(t))  [sublinear scaling]
///   4. Apply attention weights (Huang, 2022).
///   5. Apply skill/domain weight multipliers (Alsaif et al. §4.3).
///
/// ### Log scaling vs raw TF
/// Both variants normalise their output consistently:
///   - Raw TF sums to 1 across all terms; comparable across documents.
///   - Log TF suppresses the dominance of very frequent terms; document length
///     is not normalised — use L2 normalisation downstream for cosine
///     similarity.  [Ajjam & Al-Raweshidy, 2026]
///
/// Returns an empty map for empty or all-stopword documents.
Map<String, double> termFrequency(
    List<String> document, {
      List<String> stopwords = kDefaultStopwords,
      Set<String> knownPhrases = kKnownPhrases,
      bool useLogScaling = false,
      Map<String, double>? attentionWeights,
      Set<String>? skillTerms,
    }) {
  if (document.isEmpty) return const <String, double>{};

  // Step 1: tokenise (normalise + phrase detection + stopword filter).
  final List<String> tokens = tokeniseDocument(
    document,
    stopwords: stopwords,
    knownPhrases: knownPhrases,
  );
  if (tokens.isEmpty) return const <String, double>{};

  // Step 2: count.
  final Map<String, int> counts = <String, int>{};
  for (final String t in tokens) {
    counts[t] = (counts[t] ?? 0) + 1;
  }

  final int totalTokens = tokens.length;

  // Step 3 + 4 + 5: TF formula → attention → skill/domain weight.
  final Map<String, double> tf = <String, double>{};
  for (final MapEntry<String, int> e in counts.entries) {
    final String term = e.key;
    final int count = e.value;

    // Step 3: TF value.
    double value = useLogScaling
        ? 1.0 + (log(count.toDouble()) / _ln10)
        : count / totalTokens;

    // Step 4: attention weight (Huang, 2022).
    if (attentionWeights != null) {
      value *= attentionWeights[term] ?? 1.0;
    }

    // Step 5: skill vs. domain weight (Alsaif et al. §4.3).
    if (skillTerms != null) {
      value *= skillTerms.contains(term) ? kSkillWeight : kDomainWeight;
    }

    tf[term] = value;
  }

  return tf;
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. CORPUS IDF PRE-COMPUTATION  [Ajjam & Al-Raweshidy 2026]
// ─────────────────────────────────────────────────────────────────────────────

/// Pre-computes [CorpusIdfStats] from a corpus of documents.
///
/// **Formula** — smooth IDF (Ajjam & Al-Raweshidy, 2026):
/// ```
/// IDF(t) = log((N + 1) / (df(t) + 1)) + 1
/// ```
/// The +1 bias prevents zero IDF for universal terms and avoids
/// divide-by-zero for unseen terms.
///
/// Synonym normalisation and phrase detection are applied to each document
/// before building the vocabulary, ensuring the IDF map is consistent with
/// vectors produced by [vectoriseWithCorpusIdf].
///
/// Call once on startup (e.g. over all job postings) and pass the result to
/// [vectoriseWithCorpusIdf] for fast online vectorisation.
CorpusIdfStats buildCorpusIdf(
    List<List<String>> documents, {
      List<String> stopwords = kDefaultStopwords,
      Set<String> knownPhrases = kKnownPhrases,
    }) {
  final int n = documents.length;
  if (n == 0) {
    return const CorpusIdfStats(
      idf: <String, double>{},
      documentCount: 0,
      avgDocLength: 0.0,
    );
  }

  final Map<String, int> df = <String, int>{};
  int totalTokens = 0;

  for (final List<String> doc in documents) {
    final List<String> tokens = tokeniseDocument(
      doc,
      stopwords: stopwords,
      knownPhrases: knownPhrases,
    );
    totalTokens += tokens.length;
    // Count each unique term once per document for DF.
    for (final String term in tokens.toSet()) {
      df[term] = (df[term] ?? 0) + 1;
    }
  }

  // IDF(t) = log((N+1)/(df(t)+1)) + 1
  final Map<String, double> idf = <String, double>{};
  for (final MapEntry<String, int> e in df.entries) {
    idf[e.key] = log((n + 1) / (e.value + 1)) + 1.0;
  }

  return CorpusIdfStats(
    idf: idf,
    documentCount: n,
    avgDocLength: totalTokens / n,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. FULL CORPUS TF-IDF  [Ajjam & Al-Raweshidy 2026]
// ─────────────────────────────────────────────────────────────────────────────

/// Computes TF-IDF vectors for an entire corpus in one pass.
///
/// **Steps**:
///   1. Compute per-document TF via [termFrequency].
///   2. Compute smooth IDF from document frequencies.
///   3. Multiply TF × IDF; apply optional post-boost.
///   4. Optionally L2-normalise each vector (default `true`).
///
/// [normalise]: when `true` (default), each output vector is L2-normalised so
/// that dot-product equals cosine similarity — required by [cosineSimilarity].
///
/// [boostTerms]: extra multiplicative scalars applied **after** IDF
/// multiplication (Ajjam & Al-Raweshidy, 2026 — "certain keywords take more
/// weight").
///
/// Returns a parallel list of TF-IDF maps with the same indexing as
/// [documents].
List<Map<String, double>> computeTfIdf(
    List<List<String>> documents, {
      List<String> stopwords = kDefaultStopwords,
      Set<String> knownPhrases = kKnownPhrases,
      bool useLogScaling = false,
      bool normalise = true,
      Map<String, double>? attentionWeights,
      Map<String, double>? boostTerms,
      Set<String>? skillTerms,
    }) {
  if (documents.isEmpty) return const <Map<String, double>>[];

  // Step 1: TF for all documents.
  final List<Map<String, double>> tfList = documents
      .map((List<String> doc) => termFrequency(
    doc,
    stopwords: stopwords,
    knownPhrases: knownPhrases,
    useLogScaling: useLogScaling,
    attentionWeights: attentionWeights,
    skillTerms: skillTerms,
  ))
      .toList();

  // Step 2: document frequency (each term counted once per document).
  final int n = documents.length;
  final Map<String, int> df = <String, int>{};
  for (final Map<String, double> tf in tfList) {
    for (final String term in tf.keys) {
      df[term] = (df[term] ?? 0) + 1;
    }
  }

  // Smooth IDF.
  final Map<String, double> idf = <String, double>{};
  for (final MapEntry<String, int> e in df.entries) {
    idf[e.key] = log((n + 1) / (e.value + 1)) + 1.0;
  }

  // Step 3 (+4): TF × IDF × optional boost; optional L2 normalisation.
  return tfList.map((Map<String, double> tf) {
    final Map<String, double> vec = <String, double>{};
    for (final MapEntry<String, double> e in tf.entries) {
      double w = e.value * (idf[e.key] ?? 0.0);
      if (boostTerms != null) {
        final double? boost = boostTerms[e.key];
        if (boost != null) w *= boost;
      }
      if (w > 0.0) vec[e.key] = w;
    }
    return normalise ? l2Normalise(vec) : vec;
  }).toList();
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. ONLINE VECTORISATION  [Ajjam & Al-Raweshidy 2026]
// ─────────────────────────────────────────────────────────────────────────────

/// Vectorises a single document using pre-computed [CorpusIdfStats].
///
/// Use for **online / query-time** scoring: build [CorpusIdfStats] once from
/// the job-posting corpus, then vectorise incoming CVs at query time without
/// reprocessing the entire corpus.  [Ajjam & Al-Raweshidy, 2026]
///
/// Out-of-vocabulary terms receive the smoothed IDF floor from
/// [CorpusIdfStats.idfFor] rather than silently scoring 0.
///
/// [normalise]: L2-normalises the output (default `true`).
Map<String, double> vectoriseWithCorpusIdf(
    List<String> document,
    CorpusIdfStats stats, {
      List<String> stopwords = kDefaultStopwords,
      Set<String> knownPhrases = kKnownPhrases,
      bool useLogScaling = false,
      bool normalise = true,
      Map<String, double>? attentionWeights,
      Map<String, double>? boostTerms,
      Set<String>? skillTerms,
      double? oovIdf,
    }) {
  final Map<String, double> tf = termFrequency(
    document,
    stopwords: stopwords,
    knownPhrases: knownPhrases,
    useLogScaling: useLogScaling,
    attentionWeights: attentionWeights,
    skillTerms: skillTerms,
  );

  if (tf.isEmpty) return const <String, double>{};

  final Map<String, double> vec = <String, double>{};
  for (final MapEntry<String, double> e in tf.entries) {
    double w = e.value * stats.idfFor(e.key, oovIdf: oovIdf);
    if (boostTerms != null) {
      final double? boost = boostTerms[e.key];
      if (boost != null) w *= boost;
    }
    if (w > 0.0) vec[e.key] = w;
  }

  return normalise ? l2Normalise(vec) : vec;
}

/// Typed variant of [vectoriseWithCorpusIdf] returning a [TfIdfVector].
///
/// Pre-computes and stores the L2 norm and token count so callers can perform
/// cosine similarity and BM25 scoring without redundant computation.
TfIdfVector vectoriseToTyped(
    List<String> document,
    CorpusIdfStats stats, {
      List<String> stopwords = kDefaultStopwords,
      Set<String> knownPhrases = kKnownPhrases,
      bool useLogScaling = false,
      bool normalise = true,
      Map<String, double>? attentionWeights,
      Map<String, double>? boostTerms,
      Set<String>? skillTerms,
      double? oovIdf,
    }) {
  final List<String> tokens = tokeniseDocument(
    document,
    stopwords: stopwords,
    knownPhrases: knownPhrases,
  );

  final Map<String, double> weights = vectoriseWithCorpusIdf(
    document,
    stats,
    stopwords: stopwords,
    knownPhrases: knownPhrases,
    useLogScaling: useLogScaling,
    normalise: normalise,
    attentionWeights: attentionWeights,
    boostTerms: boostTerms,
    skillTerms: skillTerms,
    oovIdf: oovIdf,
  );

  return TfIdfVector(
    weights: weights,
    tokenCount: tokens.length,
    l2Norm: _l2Norm(weights),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 7. L2 NORMALISATION  [Ajjam & Al-Raweshidy 2026]
// ─────────────────────────────────────────────────────────────────────────────

/// Returns a copy of [vector] normalised to unit L2 length.
///
/// Required before cosine similarity via dot product
/// [Ajjam & Al-Raweshidy 2026].
/// Returns the original map unchanged when all weights are 0 (zero vector).
Map<String, double> l2Normalise(Map<String, double> vector) {
  if (vector.isEmpty) return vector;
  final double norm = _l2Norm(vector);
  if (norm == 0.0) return vector;
  final Map<String, double> out = <String, double>{};
  for (final MapEntry<String, double> e in vector.entries) {
    out[e.key] = e.value / norm;
  }
  return out;
}

// ─────────────────────────────────────────────────────────────────────────────
// 8. COSINE SIMILARITY (vector-level)
// ─────────────────────────────────────────────────────────────────────────────

/// Computes cosine similarity between two sparse TF-IDF maps.
///
/// When [preNormalised] is `true` (default), assumes both vectors are already
/// L2-normalised — the dot product **is** the cosine.  Set `false` when
/// passing raw (un-normalised) maps.
///
/// Returns a value in [0.0, 1.0]; returns 0.0 for empty or zero vectors.
double cosineSimilarity(
    Map<String, double> a,
    Map<String, double> b, {
      bool preNormalised = true,
    }) {
  if (a.isEmpty || b.isEmpty) return 0.0;

  // Iterate the smaller map for minimum key lookups.
  final Map<String, double> small = a.length <= b.length ? a : b;
  final Map<String, double> large = a.length <= b.length ? b : a;

  double dot = 0.0;
  for (final MapEntry<String, double> e in small.entries) {
    final double? bVal = large[e.key];
    if (bVal != null) dot += e.value * bVal;
  }
  if (dot == 0.0) return 0.0;

  if (preNormalised) return dot.clamp(0.0, 1.0);

  final double normA = _l2Norm(a);
  final double normB = _l2Norm(b);
  if (normA == 0.0 || normB == 0.0) return 0.0;
  return (dot / (normA * normB)).clamp(0.0, 1.0);
}

/// Cosine similarity between two [TfIdfVector] objects.
///
/// Uses the pre-stored [TfIdfVector.l2Norm] to avoid recomputation.
double cosineBetween(TfIdfVector a, TfIdfVector b) {
  if (a.isEmpty || b.isEmpty) return 0.0;

  final Map<String, double> small =
  a.weights.length <= b.weights.length ? a.weights : b.weights;
  final Map<String, double> large =
  a.weights.length <= b.weights.length ? b.weights : a.weights;

  double dot = 0.0;
  for (final MapEntry<String, double> e in small.entries) {
    final double? bVal = large[e.key];
    if (bVal != null) dot += e.value * bVal;
  }
  if (dot == 0.0) return 0.0;

  final double denom = a.l2Norm * b.l2Norm;
  return denom == 0.0 ? 0.0 : (dot / denom).clamp(0.0, 1.0);
}

// ─────────────────────────────────────────────────────────────────────────────
// 9. BM25 SCORING  [Robertson & Zaragoza 2009]
// ─────────────────────────────────────────────────────────────────────────────

/// Computes BM25 relevance score between a [queryTokens] and [documentTokens].
///
/// **Formula** (Okapi BM25, Robertson & Zaragoza 2009 §3):
/// ```
/// BM25(q, d) = Σ_t IDF(t) ×
///              [tf(t,d) × (k₁+1)] / [tf(t,d) + k₁×(1−b+b×(|d|/avgdl))]
/// ```
///
/// BM25 complements TF-IDF cosine for short resume snippets where document
/// length normalisation matters more than vector direction.
///
/// [queryTokens]: pre-tokenised query terms (call [tokeniseDocument] first).
/// [documentTokens]: pre-tokenised document terms.
/// [stats]: [CorpusIdfStats] for IDF values and [avgDocLength].
/// [k1]: term-saturation parameter (default [kBm25K1] = 1.5).
/// [b]: length-normalisation parameter (default [kBm25B] = 0.75).
///
/// Returns a non-negative score; higher = more relevant.
double bm25Score(
    List<String> queryTokens,
    List<String> documentTokens,
    CorpusIdfStats stats, {
      double k1 = kBm25K1,
      double b = kBm25B,
    }) {
  if (queryTokens.isEmpty || documentTokens.isEmpty) return 0.0;

  // Build document term-frequency map.
  final Map<String, int> docTf = <String, int>{};
  for (final String t in documentTokens) {
    docTf[t] = (docTf[t] ?? 0) + 1;
  }

  final double docLen = documentTokens.length.toDouble();
  final double avgdl = stats.avgDocLength > 0.0 ? stats.avgDocLength : docLen;

  double score = 0.0;
  for (final String term in queryTokens.toSet()) {
    final int tf = docTf[term] ?? 0;
    if (tf == 0) continue;

    final double idfVal = stats.idfFor(term);
    final double tfNorm =
        (tf * (k1 + 1.0)) / (tf + k1 * (1.0 - b + b * (docLen / avgdl)));
    score += idfVal * tfNorm;
  }
  return score;
}

/// Ranks [docTokensList] against [queryTokens] using BM25 and returns entries
/// sorted by score descending.
///
/// [docTokensList]: each entry is the pre-tokenised token list for one
/// document; must have the same length and ordering as the corresponding
/// document list.
List<({int index, double score})> bm25Rank(
    List<String> queryTokens,
    List<List<String>> docTokensList,
    CorpusIdfStats stats, {
      double k1 = kBm25K1,
      double b = kBm25B,
    }) {
  if (queryTokens.isEmpty || docTokensList.isEmpty) {
    return const <({int index, double score})>[];
  }

  final List<({int index, double score})> ranked =
  <({int index, double score})>[];

  for (int i = 0; i < docTokensList.length; i++) {
    ranked.add((
    index: i,
    score: bm25Score(queryTokens, docTokensList[i], stats, k1: k1, b: b),
    ));
  }

  // `bb` avoids shadowing the `b` parameter (length-normalisation scalar).
  ranked.sort(
        (({int index, double score}) a, ({int index, double score}) bb) =>
        bb.score.compareTo(a.score),
  );
  return ranked;
}

// ─────────────────────────────────────────────────────────────────────────────
// 10. STATEFUL CORPUS ENGINE
// ─────────────────────────────────────────────────────────────────────────────

/// Stateful TF-IDF corpus engine with lazy IDF recomputation, incremental
/// document management, and integrated BM25 support.
///
/// ### Typical usage
/// ```dart
/// final corpus = TfIdfCorpus();
/// corpus.addDocuments(allJobSkillLists);
///
/// final jobVec = corpus.vectorise(jobSkills);
/// final cvVec  = corpus.vectorise(cvSkills);
/// final sim    = cosineBetween(jobVec, cvVec);
/// ```
///
/// Call [rebuild] explicitly after bulk updates if the lazy rebuild latency
/// is unacceptable in a hot path.
class TfIdfCorpus {
  // ── Configuration ──────────────────────────────────────────────────────────

  final List<String> _stopwords;
  final Set<String> _knownPhrases;
  final bool _useLogScaling;
  final Map<String, double>? _attentionWeights;
  final Map<String, double>? _boostTerms;
  final Set<String>? _skillTerms;
  final bool _normaliseVectors;

  // ── Internal state ─────────────────────────────────────────────────────────

  /// Normalised token lists, parallel to the raw document list.
  final List<List<String>> _docTokens = <List<String>>[];

  /// Cached IDF statistics. `null` when the corpus has been mutated since
  /// the last [rebuild] call (i.e. the cache is "dirty").
  CorpusIdfStats? _idfStats;

  // ── Constructor ────────────────────────────────────────────────────────────

  /// Creates an empty [TfIdfCorpus].
  ///
  /// All parameters mirror the equivalents on [computeTfIdf] and
  /// [vectoriseWithCorpusIdf].
  TfIdfCorpus({
    List<String> stopwords = kDefaultStopwords,
    Set<String> knownPhrases = kKnownPhrases,
    bool useLogScaling = false,
    bool normaliseVectors = true,
    Map<String, double>? attentionWeights,
    Map<String, double>? boostTerms,
    Set<String>? skillTerms,
  })  : _stopwords = stopwords,
        _knownPhrases = knownPhrases,
        _useLogScaling = useLogScaling,
        _normaliseVectors = normaliseVectors,
        _attentionWeights = attentionWeights,
        _boostTerms = boostTerms,
        _skillTerms = skillTerms;

  // ── Document management ────────────────────────────────────────────────────

  /// Adds [document] to the corpus and marks the IDF cache as dirty.
  void addDocument(List<String> document) {
    _docTokens.add(
      tokeniseDocument(
        document,
        stopwords: _stopwords,
        knownPhrases: _knownPhrases,
      ),
    );
    _idfStats = null; // Invalidate cache.
  }

  /// Adds multiple [documents] in one call (more efficient than repeated
  /// [addDocument] calls since the cache is invalidated only once).
  void addDocuments(List<List<String>> documents) {
    for (final List<String> doc in documents) {
      _docTokens.add(
        tokeniseDocument(
          doc,
          stopwords: _stopwords,
          knownPhrases: _knownPhrases,
        ),
      );
    }
    if (documents.isNotEmpty) _idfStats = null;
  }

  /// Removes the document at [index] and marks the IDF cache as dirty.
  ///
  /// Throws [RangeError] for out-of-bounds indices.
  void removeAt(int index) {
    _docTokens.removeAt(index);
    _idfStats = null;
  }

  /// Removes all documents and clears the IDF cache.
  void clear() {
    _docTokens.clear();
    _idfStats = null;
  }

  /// Number of documents currently in the corpus.
  int get documentCount => _docTokens.length;

  /// `true` when the IDF cache is up to date.
  bool get isBuilt => _idfStats != null;

  // ── Corpus building ────────────────────────────────────────────────────────

  /// Explicitly rebuilds the IDF statistics from the current document set.
  ///
  /// Called automatically on first use; call explicitly after bulk mutations
  /// when predictable latency is required.
  ///
  /// Returns the computed [CorpusIdfStats] for inspection.
  CorpusIdfStats rebuild() {
    if (_docTokens.isEmpty) {
      _idfStats = const CorpusIdfStats(
        idf: <String, double>{},
        documentCount: 0,
        avgDocLength: 0.0,
      );
      return _idfStats!;
    }

    final int n = _docTokens.length;
    final Map<String, int> df = <String, int>{};
    int totalTokens = 0;

    for (final List<String> tokens in _docTokens) {
      totalTokens += tokens.length;
      for (final String term in tokens.toSet()) {
        df[term] = (df[term] ?? 0) + 1;
      }
    }

    final Map<String, double> idf = <String, double>{};
    for (final MapEntry<String, int> e in df.entries) {
      idf[e.key] = log((n + 1) / (e.value + 1)) + 1.0;
    }

    _idfStats = CorpusIdfStats(
      idf: idf,
      documentCount: n,
      avgDocLength: totalTokens / n,
    );
    return _idfStats!;
  }

  /// Returns the current [CorpusIdfStats], rebuilding if the cache is dirty.
  CorpusIdfStats get stats => _idfStats ?? rebuild();

  // ── Vectorisation ──────────────────────────────────────────────────────────

  /// Vectorises [document] against the corpus IDF, returning a [TfIdfVector].
  ///
  /// The IDF index is rebuilt lazily if the corpus has been mutated since the
  /// last vectorisation.
  TfIdfVector vectorise(List<String> document) {
    return vectoriseToTyped(
      document,
      stats,
      stopwords: _stopwords,
      knownPhrases: _knownPhrases,
      useLogScaling: _useLogScaling,
      normalise: _normaliseVectors,
      attentionWeights: _attentionWeights,
      boostTerms: _boostTerms,
      skillTerms: _skillTerms,
    );
  }

  /// Vectorises all corpus documents and returns a parallel list of
  /// [TfIdfVector] objects.
  ///
  /// Triggers a single rebuild if the cache is dirty before iterating.
  List<TfIdfVector> vectoriseAll() {
    final CorpusIdfStats s = stats; // Ensure one rebuild at most.
    return _docTokens.map((List<String> tokens) {
      final Map<String, double> vec = _buildVecFromTokens(tokens, s);
      return TfIdfVector(
        weights: vec,
        tokenCount: tokens.length,
        l2Norm: _l2Norm(vec),
      );
    }).toList();
  }

  // ── Top-K term extraction ──────────────────────────────────────────────────

  /// Returns the [topN] most-weighted terms in [document] after vectorisation,
  /// sorted by TF-IDF weight descending.
  ///
  /// Useful for keyword extraction and explainability UI panels.
  List<({String term, double weight})> topTerms(
      List<String> document, {
        int topN = 10,
      }) {
    if (topN <= 0 || document.isEmpty) {
      return const <({String term, double weight})>[];
    }

    final Map<String, double> vec = vectorise(document).weights;
    if (vec.isEmpty) return const <({String term, double weight})>[];

    final List<MapEntry<String, double>> entries = vec.entries.toList()
      ..sort(
            (MapEntry<String, double> a, MapEntry<String, double> b) =>
            b.value.compareTo(a.value),
      );

    return entries
        .take(topN)
        .map((MapEntry<String, double> e) => (term: e.key, weight: e.value))
        .toList();
  }

  // ── BM25 ───────────────────────────────────────────────────────────────────

  /// Scores [queryDocument] against all corpus documents using BM25.
  ///
  /// Returns entries sorted by score descending.  Use as an alternative or
  /// complement to cosine-similarity ranking for short documents.
  List<({int index, double score})> bm25RankAll(
      List<String> queryDocument, {
        double k1 = kBm25K1,
        double b = kBm25B,
      }) {
    final List<String> qTokens = tokeniseDocument(
      queryDocument,
      stopwords: _stopwords,
      knownPhrases: _knownPhrases,
    );
    return bm25Rank(qTokens, _docTokens, stats, k1: k1, b: b);
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Builds a TF-IDF weight vector from pre-tokenised [tokens] using [s].
  ///
  /// Fix: replaced `_attentionWeights?[term]` and `_boostTerms?[term]` (null-
  /// conditional inside an already null-checked branch) with non-null
  /// assertions `_attentionWeights![term]` and `_boostTerms![term]`.
  Map<String, double> _buildVecFromTokens(
      List<String> tokens,
      CorpusIdfStats s,
      ) {
    // Count.
    final Map<String, int> counts = <String, int>{};
    for (final String t in tokens) {
      counts[t] = (counts[t] ?? 0) + 1;
    }
    final int total = tokens.length;

    // TF × IDF × optional boosts.
    final Map<String, double> vec = <String, double>{};
    for (final MapEntry<String, int> e in counts.entries) {
      final String term = e.key;

      // TF.
      double w = _useLogScaling
          ? 1.0 + (log(e.value.toDouble()) / _ln10)
          : e.value / total;

      // Attention weight (Huang, 2022).
      if (_attentionWeights != null) {
        w *= _attentionWeights![term] ?? 1.0;
      }

      // Skill vs. domain weight (Alsaif et al. §4.3).
      if (_skillTerms != null) {
        w *= _skillTerms!.contains(term) ? kSkillWeight : kDomainWeight;
      }

      // IDF.
      w *= s.idfFor(term);

      // Optional post-IDF boost.
      if (_boostTerms != null) {
        final double? boost = _boostTerms![term];
        if (boost != null) w *= boost;
      }

      if (w > 0.0) vec[term] = w;
    }

    return _normaliseVectors ? l2Normalise(vec) : vec;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRIVATE HELPERS
// ─────────────────────────────────────────────────────────────────────────────

/// Pre-computed natural log of 10 — avoids repeated `log(10)` calls.
const double _ln10 = 2.302585092994046; // ln(10)

/// L2 (Euclidean) norm of a sparse weight map.
double _l2Norm(Map<String, double> v) {
  double sumSq = 0.0;
  for (final double w in v.values) {
    sumSq += w * w;
  }
  return sumSq == 0.0 ? 0.0 : sqrt(sumSq);
}