"""
SkillBridge AI — Flask REST API  v2.1
Serves: /health, /recommend, /cv_recommend, /career_predict

Changes from v2.0:
  - All endpoints now return the full Flutter contract:
      { jobs, confidence, skills_gap, courses, status }
  - Added _COURSE_CATALOG (embedded, no extra .pkl needed)
  - Added _skill_gap() to compute missing skills vs top-job requirements
  - Added _courses_for_gap() to map gaps → course recommendations
  - Fixed predict_salary() to pass all 4 features (was missing soft_count)
  - /cv_recommend retains cv_summary alongside the new fields
"""

from __future__ import annotations

import io
import logging
import os
import re
import warnings
from pathlib import Path
from typing import Any

import numpy as np
from flask import Flask, jsonify, request
from flask_cors import CORS

import pickle

knn_model = pickle.load(open('knn_career.pkl', 'rb'))
lr_multi = pickle.load(open('lr_multi.pkl', 'rb'))
lr_simple = pickle.load(open('lr_simple.pkl', 'rb'))
rf_model = pickle.load(open('rf_regressor.pkl', 'rb'))
tfidf = pickle.load(open('tfidf_model.pkl', 'rb'))

warnings.filterwarnings("ignore")

# ── logging ───────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(message)s",
)
log = logging.getLogger(__name__)

# ── app ───────────────────────────────────────────────────────────────────────
app = Flask(__name__)
CORS(app)

# ── paths ─────────────────────────────────────────────────────────────────────
MODEL_DIR = Path(os.environ.get("MODEL_DIR", "models"))

# ── NLP config ────────────────────────────────────────────────────────────────
STOPWORDS: set[str] = {
    "i", "me", "my", "we", "our", "you", "your", "he", "him", "his",
    "she", "her", "it", "its", "they", "them", "this", "that", "these",
    "those", "am", "is", "are", "was", "were", "be", "been", "have",
    "has", "had", "do", "does", "did", "a", "an", "the", "and", "but",
    "or", "of", "at", "by", "for", "with", "to", "in", "on", "not",
    "will", "can", "just",
}

TECH_SKILLS: list[str] = [
    "python", "java", "javascript", "typescript", "c++", "c#", "go", "rust",
    "php", "swift", "sql", "mysql", "postgresql", "mongodb", "redis",
    "firebase", "react", "angular", "vue", "django", "flask", "spring",
    "nodejs", "express", "machine learning", "deep learning", "tensorflow",
    "pytorch", "keras", "scikit-learn", "data science", "data analysis",
    "pandas", "numpy", "matplotlib", "aws", "azure", "gcp", "docker",
    "kubernetes", "terraform", "git", "github", "linux", "bash", "rest api",
    "graphql", "html", "css", "bootstrap", "tailwind", "flutter", "dart",
    "tableau", "power bi", "excel", "spark", "hadoop",
    "natural language processing", "nlp", "computer vision",
    "reinforcement learning",
]

SOFT_SKILLS: list[str] = [
    "leadership", "communication", "teamwork", "problem solving",
    "critical thinking", "project management", "time management",
    "adaptability", "creativity", "collaboration", "analytical",
    "presentation", "negotiation", "mentoring", "decision making",
]

DOMAIN_WEIGHTS: dict[str, float] = {
    "python": 1.5, "machine learning": 1.5, "deep learning": 1.5,
    "tensorflow": 1.4, "pytorch": 1.4, "data science": 1.3,
    "sql": 1.3, "aws": 1.3, "docker": 1.3, "kubernetes": 1.3,
    "react": 1.2, "java": 1.2, "javascript": 1.2, "nodejs": 1.2,
    "communication": 1.1, "leadership": 1.1, "teamwork": 1.1,
}

MAX_CV_TEXT_LEN = 15_000
TOP_K_DEFAULT = 5

# ── embedded course catalog (Tavakoli et al., 2022 — personalized learning) ──
# Maps skill keyword → free/freemium course.  No extra .pkl file needed.
_COURSE_CATALOG: dict[str, dict[str, str]] = {
    "python":                   {"name": "Python for Everybody",                   "url": "https://www.coursera.org/specializations/python",                          "platform": "Coursera"},
    "machine learning":         {"name": "Machine Learning Specialization",        "url": "https://www.coursera.org/specializations/machine-learning-introduction",   "platform": "Coursera"},
    "deep learning":            {"name": "Deep Learning Specialization",           "url": "https://www.coursera.org/specializations/deep-learning",                   "platform": "Coursera"},
    "tensorflow":               {"name": "TensorFlow Developer Certificate",       "url": "https://www.coursera.org/professional-certificates/tensorflow-in-practice","platform": "Coursera"},
    "pytorch":                  {"name": "PyTorch for Deep Learning (freeCodeCamp)","url": "https://www.youtube.com/watch?v=V_xro1bcAuA",                            "platform": "YouTube"},
    "data science":             {"name": "IBM Data Science Professional Cert",     "url": "https://www.coursera.org/professional-certificates/ibm-data-science",     "platform": "Coursera"},
    "sql":                      {"name": "SQL for Data Science",                   "url": "https://www.coursera.org/learn/sql-for-data-science",                      "platform": "Coursera"},
    "aws":                      {"name": "AWS Cloud Practitioner Essentials",      "url": "https://www.coursera.org/learn/aws-cloud-practitioner-essentials",         "platform": "Coursera"},
    "docker":                   {"name": "Docker Mastery",                         "url": "https://www.udemy.com/course/docker-mastery/",                             "platform": "Udemy"},
    "kubernetes":               {"name": "Kubernetes for Beginners",               "url": "https://www.udemy.com/course/learn-kubernetes/",                           "platform": "Udemy"},
    "react":                    {"name": "React – The Complete Guide",             "url": "https://www.udemy.com/course/react-the-complete-guide-incl-redux/",        "platform": "Udemy"},
    "java":                     {"name": "Java Programming & Software Engineering","url": "https://www.coursera.org/specializations/java-programming",                "platform": "Coursera"},
    "javascript":               {"name": "JavaScript Algorithms & Data Structures","url": "https://www.freecodecamp.org/learn/javascript-algorithms-and-data-structures/","platform": "freeCodeCamp"},
    "git":                      {"name": "Git & GitHub Crash Course",              "url": "https://www.youtube.com/watch?v=RGOj5yH7evk",                             "platform": "YouTube"},
    "flutter":                  {"name": "The Complete Flutter Development Bootcamp","url": "https://www.udemy.com/course/flutter-bootcamp-with-dart/",               "platform": "Udemy"},
    "dart":                     {"name": "Dart & Flutter – Zero to Mastery",       "url": "https://www.udemy.com/course/flutter-made-easy-zero-to-mastery/",         "platform": "Udemy"},
    "nlp":                      {"name": "Natural Language Processing Specialization","url": "https://www.coursera.org/specializations/natural-language-processing",  "platform": "Coursera"},
    "natural language processing": {"name": "NLP with Classification & Vector Spaces","url": "https://www.coursera.org/learn/classification-vector-spaces-in-nlp", "platform": "Coursera"},
    "computer vision":          {"name": "Computer Vision Basics",                 "url": "https://www.coursera.org/learn/computer-vision-basics",                   "platform": "Coursera"},
    "data analysis":            {"name": "Google Data Analytics Certificate",      "url": "https://www.coursera.org/professional-certificates/google-data-analytics","platform": "Coursera"},
    "mongodb":                  {"name": "MongoDB Basics",                         "url": "https://learn.mongodb.com/learning-paths/introduction-to-mongodb",        "platform": "MongoDB University"},
    "postgresql":               {"name": "PostgreSQL Tutorial",                    "url": "https://www.postgresqltutorial.com/",                                      "platform": "Free"},
    "linux":                    {"name": "Linux Command Line Basics",              "url": "https://www.coursera.org/learn/unix",                                      "platform": "Coursera"},
    "communication":            {"name": "Improve Your English Communication Skills","url": "https://www.coursera.org/specializations/improve-english",              "platform": "Coursera"},
    "leadership":               {"name": "Leadership & Management Specialization", "url": "https://www.coursera.org/specializations/wharton-leadership-motivation",  "platform": "Coursera"},
    "project management":       {"name": "Google Project Management Certificate",  "url": "https://www.coursera.org/professional-certificates/google-project-management","platform": "Coursera"},
    "teamwork":                 {"name": "Inspiring and Motivating Individuals",   "url": "https://www.coursera.org/learn/motivate-people-teams",                    "platform": "Coursera"},
    "problem solving":          {"name": "Critical Thinking & Problem Solving",    "url": "https://www.coursera.org/learn/critical-thinking-skills-for-university-success","platform": "Coursera"},
    "azure":                    {"name": "Microsoft Azure Fundamentals (AZ-900)",  "url": "https://learn.microsoft.com/en-us/training/paths/az-900-describe-cloud-concepts/","platform": "Microsoft Learn"},
    "gcp":                      {"name": "Google Cloud Fundamentals",              "url": "https://www.coursera.org/learn/gcp-fundamentals",                         "platform": "Coursera"},
    "spark":                    {"name": "Big Data with Spark & Hadoop",           "url": "https://www.coursera.org/learn/scala-spark-big-data",                     "platform": "Coursera"},
    "tableau":                  {"name": "Data Visualization with Tableau",        "url": "https://www.coursera.org/specializations/data-visualization",            "platform": "Coursera"},
    "rest api":                 {"name": "APIs and Web Services Fundamentals",     "url": "https://www.udemy.com/course/api-and-web-service-introduction/",          "platform": "Udemy"},
}

# ── model globals ─────────────────────────────────────────────────────────────
vocab: list[str] = []
vocab_index: dict[str, int] = {}
idf: np.ndarray = np.array([])
job_tfidf: np.ndarray = np.array([])
jobs_pool: list[dict[str, Any]] = []
V: int = 0

knn_model: Any = None
knn_scaler: Any = None
knn_label_encoder: Any = None
knn_features: list[str] = []

lr_simple_model: Any = None
lr_salary_model: Any = None
lr_salary_scaler: Any = None
lr_salary_features: list[str] = []

MODELS_LOADED = False

# ── NLP helpers ───────────────────────────────────────────────────────────────
_NON_WORD = re.compile(r"[^\w\s]")


def preprocess(text: str) -> str:
    text = str(text).lower()
    text = _NON_WORD.sub(" ", text)
    return " ".join(w for w in text.split() if w not in STOPWORDS and len(w) > 1)


def tfidf_vec(text: str) -> np.ndarray:
    tf = np.zeros(V, dtype=np.float32)
    words = text.split()
    if not words:
        return tf
    for w in words:
        if w in vocab_index:
            tf[vocab_index[w]] += 1
    tf /= len(words)
    return tf * idf


def _cosine_scores(user_vec: np.ndarray) -> np.ndarray:
    dots = np.dot(job_tfidf, user_vec)
    norms = np.linalg.norm(job_tfidf, axis=1)
    u_norm = np.linalg.norm(user_vec)
    return dots / (norms * u_norm + 1e-8)


def _build_job_result(i: int, score: float) -> dict[str, Any]:
    j = jobs_pool[i]
    return {
        "title":            j.get("job_title", ""),
        "industry":         j.get("industry", ""),
        "salary":           int(j.get("salary", 0)),
        "experience_level": j.get("experience_level", ""),
        "similarity_score": round(float(score), 4),
    }


def recommend(skills_text: str, top_k: int = TOP_K_DEFAULT) -> tuple[list[dict[str, Any]], list[float]]:
    """
    Returns (job_list, confidence_list).
    confidence values are similarity scores normalised to [0, 1] then rounded to 2dp.
    """
    user_vec = tfidf_vec(preprocess(skills_text))
    sims = _cosine_scores(user_vec)
    top_idx = np.argsort(sims)[::-1][:top_k]
    jobs = [_build_job_result(int(i), sims[i]) for i in top_idx]
    # Confidence: normalise within the result set so top job ≈ 0.9 max
    raw_scores = [float(sims[i]) for i in top_idx]
    max_s = max(raw_scores) if raw_scores else 1.0
    confidence = [round(min(s / (max_s + 1e-8) * 0.90, 0.99), 4) for s in raw_scores]
    return jobs, confidence


def extract_skills(text: str) -> tuple[list[str], list[str]]:
    lower = text.lower()
    tech = [s for s in TECH_SKILLS if s in lower]
    soft = [s for s in SOFT_SKILLS if s in lower]
    return tech, soft


def estimate_experience(text: str) -> int:
    matches = re.findall(r"(\d+)\s*(?:\+)?\s*year", text.lower())
    if matches:
        return min(int(max(matches, key=int)), 40)
    years = re.findall(r"\b(20\d{2}|19\d{2})\b", text)
    return max(len(set(years)) - 1, 0)


def predict_salary(
        tech_count: int,
        soft_count: int,
        exp: int,
        edu_level: int,
) -> float | None:
    """
    Matches training feature order from notebook Cell 50:
        [num_skills, soft_skills_count, experience_years, education_level]
    Previously soft_count was omitted — caused a dimension mismatch at runtime.
    """
    if lr_salary_model is None:
        return None
    try:
        import pandas as pd
        features = {
            "num_skills":        tech_count,
            "soft_skills_count": soft_count,
            "experience_years":  exp,
            "education_level":   edu_level,
        }
        row = pd.DataFrame([features])
        if lr_salary_features:
            cols = [f for f in lr_salary_features if f in row.columns]
            if cols:
                row = row[cols]
        if lr_salary_scaler:
            row = lr_salary_scaler.transform(row)
        return float(lr_salary_model.predict(row)[0])
    except Exception as exc:
        log.warning("Salary prediction failed: %s", exc)
        return None


# ── skill-gap & course helpers (Tavakoli et al., 2022) ───────────────────────

def _skill_gap(user_skills: set[str], top_jobs: list[dict[str, Any]]) -> list[str]:
    """
    For each top-recommended job find its required skills in jobs_pool,
    union them, subtract what the user already has → skill gap list.
    Capped at 8 items so the Flutter UI stays readable.
    """
    required: set[str] = set()
    all_skills = TECH_SKILLS + SOFT_SKILLS

    for job in top_jobs:
        title_lower = job["title"].lower()
        # Locate matching job in the pool
        pool_match = next(
            (j for j in jobs_pool if j.get("job_title", "").lower() == title_lower),
            None,
        )
        if pool_match is None:
            continue
        job_text = pool_match.get("skills_clean", "") or pool_match.get("required_skills", "")
        for skill in all_skills:
            if skill in job_text.lower():
                required.add(skill)

    gap = sorted(required - user_skills)
    return gap[:8]


def _courses_for_gap(gap: list[str]) -> list[dict[str, str]]:
    """
    Map skill gaps → course recommendations using the embedded catalog.
    Returns at most 5 courses, skipping duplicates.
    """
    courses: list[dict[str, str]] = []
    seen: set[str] = set()
    for skill in gap:
        if skill in _COURSE_CATALOG and skill not in seen:
            courses.append({"skill": skill, **_COURSE_CATALOG[skill]})
            seen.add(skill)
        if len(courses) >= 5:
            break
    return courses


# ── model loading ─────────────────────────────────────────────────────────────
def load_models() -> None:
    global vocab, vocab_index, idf, job_tfidf, jobs_pool, V, MODELS_LOADED
    global knn_model, knn_scaler, knn_label_encoder, knn_features
    global lr_simple_model
    global lr_salary_model, lr_salary_scaler, lr_salary_features

    import pickle

    def _load(name: str) -> Any | None:
        p = MODEL_DIR / name
        if not p.exists():
            log.warning("Model file not found: %s", p)
            return None
        with open(p, "rb") as f:
            obj = pickle.load(f)
        log.info("Loaded %s", name)
        return obj

    # TF-IDF
    tfidf_data = _load("tfidf_model.pkl")
    if tfidf_data:
        vocab       = tfidf_data["vocab"]
        vocab_index = tfidf_data["vocab_index"]
        idf         = np.array(tfidf_data["idf"],      dtype=np.float32)
        job_tfidf   = np.array(tfidf_data["job_tfidf"], dtype=np.float32)
        jobs_pool   = tfidf_data["jobs_pool"]
        V           = len(vocab)
        log.info("TF-IDF ready: %d vocab, %d jobs", V, len(jobs_pool))

    # KNN career
    knn_data = _load("knn_career.pkl")
    if knn_data:
        knn_model         = knn_data["model"]
        knn_scaler        = knn_data.get("scaler")
        knn_label_encoder = knn_data.get("label_encoder")
        knn_features      = knn_data.get("features", [])

    # LR simple (GPA → success probability)
    lr_s = _load("lr_simple.pkl")
    if lr_s:
        lr_simple_model = lr_s["model"]

    # LR salary
    lr_sal = _load("lr_salary.pkl")
    if lr_sal:
        lr_salary_model    = lr_sal["model"]
        lr_salary_scaler   = lr_sal.get("scaler")
        lr_salary_features = lr_sal.get("features", [])

    # Word2Vec — optional; skip gracefully
    try:
        from gensim.models import Word2Vec
        w2v_path = MODEL_DIR / "word2vec.model"
        if w2v_path.exists():
            Word2Vec.load(str(w2v_path))
            log.info("Word2Vec loaded (optional)")
        else:
            log.info("Word2Vec not found — skipping (non-critical)")
    except Exception as exc:
        log.warning("Word2Vec load skipped: %s", exc)

    MODELS_LOADED = True
    log.info("All available models loaded.")


# ── routes ────────────────────────────────────────────────────────────────────

@app.get("/health")
def health():
    return jsonify({
        "status":        "SkillBridge AI API is running",
        "version":       "2.1",
        "models_loaded": MODELS_LOADED,
        "jobs_in_pool":  len(jobs_pool),
    })


@app.post("/recommend")
def recommend_endpoint():
    """
    Input  (JSON): { "skills": "python machine learning sql", "top_k": 5 }
    Output (JSON): {
        "jobs":       [ { title, industry, salary, experience_level, similarity_score } ],
        "confidence": [ 0.90, 0.85, ... ],   // per-job, parallel to jobs[]
        "skills_gap": [ "docker", "aws", ... ],
        "courses":    [ { skill, name, url, platform } ],
        "status":     "success"
    }
    """
    if not jobs_pool:
        return jsonify({"status": "error", "message": "TF-IDF model not loaded"}), 503

    body = request.get_json(silent=True) or {}
    skills_raw: str = str(body.get("skills", "")).strip()
    if not skills_raw:
        return jsonify({"status": "error", "message": "'skills' field is required"}), 400

    raw_k = body.get("top_k", TOP_K_DEFAULT)
    try:
        top_k = max(1, min(int(raw_k), 20))
    except (TypeError, ValueError):
        top_k = TOP_K_DEFAULT

    try:
        jobs, confidence = recommend(skills_raw, top_k)

        # Skill gap: derive user skill set from the input text
        tech_skills, soft_skills = extract_skills(skills_raw)
        user_skill_set = set(tech_skills + soft_skills)
        gap     = _skill_gap(user_skill_set, jobs)
        courses = _courses_for_gap(gap)

        return jsonify({
            "jobs":       jobs,
            "confidence": confidence,
            "skills_gap": gap,
            "courses":    courses,
            "status":     "success",
        })
    except Exception as exc:
        log.exception("Error in /recommend")
        return jsonify({"status": "error", "message": str(exc)}), 500


@app.post("/cv_recommend")
def cv_recommend_endpoint():
    """
    Input  (multipart/form-data): cv_file=<file>, top_k=5
    Output (JSON): {
        "jobs":       [ ... ],
        "confidence": [ ... ],
        "skills_gap": [ ... ],
        "courses":    [ ... ],
        "cv_summary": {
            "tech_skills_found": [...],
            "soft_skills_found": [...],
            "experience_years":  int,
            "predicted_salary":  float | null
        },
        "status": "success"
    }
    """
    if not jobs_pool:
        return jsonify({"status": "error", "message": "TF-IDF model not loaded"}), 503

    if "cv_file" not in request.files:
        return jsonify({"status": "error", "message": "cv_file is required"}), 400

    file     = request.files["cv_file"]
    filename = (file.filename or "").lower()

    raw_k = request.form.get("top_k", str(TOP_K_DEFAULT))
    try:
        top_k = max(1, min(int(raw_k), 20))
    except (TypeError, ValueError):
        top_k = TOP_K_DEFAULT

    # ── extract text ──────────────────────────────────────────────────────────
    cv_text = ""
    try:
        file_bytes = file.read()

        if filename.endswith(".pdf"):
            import pdfplumber
            with pdfplumber.open(io.BytesIO(file_bytes)) as pdf:
                cv_text = "\n".join((p.extract_text() or "") for p in pdf.pages)

        elif filename.endswith(".docx"):
            import docx
            doc     = docx.Document(io.BytesIO(file_bytes))
            cv_text = "\n".join(p.text for p in doc.paragraphs)

        elif filename.endswith((".png", ".jpg", ".jpeg", ".bmp", ".tiff", ".webp")):
            import pytesseract
            from PIL import Image
            img     = Image.open(io.BytesIO(file_bytes))
            cv_text = pytesseract.image_to_string(img)

        elif filename.endswith(".txt"):
            cv_text = file_bytes.decode("utf-8", errors="ignore")

        else:
            return jsonify({
                "status":  "error",
                "message": "Unsupported file type. Use PDF, DOCX, image, or TXT",
            }), 415

    except Exception as exc:
        log.exception("CV text extraction failed")
        return jsonify({"status": "error", "message": f"Could not parse CV: {exc}"}), 422

    cv_text = cv_text[:MAX_CV_TEXT_LEN]

    # ── skill extraction ──────────────────────────────────────────────────────
    tech_skills, soft_skills = extract_skills(cv_text)
    exp_years  = estimate_experience(cv_text)

    edu_map    = {"phd": 3, "doctorate": 3, "master": 2, "msc": 2, "bachelor": 1, "bsc": 1}
    edu_level  = 0
    for key, val in edu_map.items():
        if key in cv_text.lower():
            edu_level = max(edu_level, val)

    # Fixed: now passes all 4 features matching training (soft_count was missing)
    predicted_salary = predict_salary(
        tech_count=len(tech_skills),
        soft_count=len(soft_skills),
        exp=exp_years,
        edu_level=edu_level,
    )

    # ── recommend ─────────────────────────────────────────────────────────────
    combined_skills = " ".join(tech_skills + soft_skills)
    if not combined_skills.strip():
        combined_skills = preprocess(cv_text[:500])

    try:
        jobs, confidence = recommend(combined_skills, top_k)
    except Exception as exc:
        log.exception("Recommendation failed during CV flow")
        return jsonify({"status": "error", "message": str(exc)}), 500

    # ── skill gap & courses ───────────────────────────────────────────────────
    user_skill_set = set(tech_skills + soft_skills)
    gap     = _skill_gap(user_skill_set, jobs)
    courses = _courses_for_gap(gap)

    return jsonify({
        "jobs":       jobs,
        "confidence": confidence,
        "skills_gap": gap,
        "courses":    courses,
        "cv_summary": {
            "tech_skills_found": tech_skills,
            "soft_skills_found": soft_skills,
            "experience_years":  exp_years,
            "predicted_salary":  round(predicted_salary, 2) if predicted_salary is not None else None,
        },
        "status": "success",
    })


@app.post("/career_predict")
def career_predict_endpoint():
    """
    Input  (JSON): { gpa, year_of_study, prior_employment, ... }
    Output (JSON): { predicted_career_path, job_success_probability,
                     confidence_note, status }
    """
    if knn_model is None:
        return jsonify({"status": "error", "message": "KNN model not loaded"}), 503

    body = request.get_json(silent=True) or {}

    defaults: dict[str, float] = {
        "gpa":                          3.0,
        "year_of_study":                2,
        "prior_employment":             0,
        "entrepreneurial_experience":   0,
        "startup_participation":        0,
        "career_guidance_satisfaction": 5,
        "entrepreneurship_score":       10,
    }
    features: dict[str, float] = {}
    for key, default in defaults.items():
        try:
            features[key] = float(body.get(key, default))
        except (TypeError, ValueError):
            features[key] = default

    features["gpa"] = max(0.0, min(features["gpa"], 4.0))

    try:
        import pandas as pd
        row = pd.DataFrame([features])
        if knn_features:
            row = row[[f for f in knn_features if f in row.columns]]
        if knn_scaler:
            row = knn_scaler.transform(row)

        label_idx = knn_model.predict(row)[0]
        label = (
            knn_label_encoder.inverse_transform([label_idx])[0]
            if knn_label_encoder else str(label_idx)
        )

        success_prob: float | None = None
        if lr_simple_model is not None:
            try:
                gpa_arr    = np.array([[features["gpa"]]])
                raw        = float(lr_simple_model.predict(gpa_arr)[0])
                success_prob = round(max(0.0, min(raw, 1.0)), 4)
            except Exception as exc:
                log.warning("LR simple predict failed: %s", exc)

        return jsonify({
            "predicted_career_path":   label,
            "job_success_probability": success_prob,
            "confidence_note":         "Based on KNN classifier + Linear Regression",
            "status":                  "success",
        })

    except Exception as exc:
        log.exception("Error in /career_predict")
        return jsonify({"status": "error", "message": str(exc)}), 500


# ── startup ───────────────────────────────────────────────────────────────────
load_models()

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port, debug=False)