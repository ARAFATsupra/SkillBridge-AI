# SkillBridge AI
### AI-Based Job and Skill Recommendation System

**Course:** ITM 328 — Introduction to Machine Learning Lab  
**Institution:** Daffodil International University, Department of Information Technology and Management  
**Submitted to:** Moni Akter, Lecturer  
**Date:** 25th April 2026  

---

## Overview

SkillBridge AI is an AI-powered career guidance and job recommendation system aligned with **UN Sustainable Development Goal 8 (Decent Work and Economic Growth)**. The system analyses a user's skill profile — entered manually or extracted from an uploaded CV — and returns ranked job recommendations in real time.

The project spans a full ML training pipeline built in Google Colab, a Flask/Python backend API, and a Flutter Android frontend application. This repository contains all Colab training notebooks and the official ML Lab Report.

---

## Repository Contents

| File | Description |
|---|---|
| `job_skill_recommendation_colab_V1.ipynb` | Version 1 — foundational notebook integrating TF-IDF, Cosine Similarity, and KNN for job-skill matching |
| `job_skill_recommendation_hybrid.ipynb` | Hybrid recommendation notebook combining TF-IDF, Word2Vec, Jaccard, and KNN in a weighted ensemble |
| `SkillBridge_Combined_V3.ipynb` | Version 3 — combined pipeline with CV upload support (PDF, DOCX, OCR) and Flask API integration |
| `SkillBridge_AI_ML_other_models_comparison.ipynb` | 7-model industry classification benchmark (Random Forest, Logistic Regression, Gradient Boosting, Naive Bayes, SVM, ANN, KNN) |
| `SkillBridge_Final_With_PKL.ipynb` | Final production notebook — generates serialised `.pkl` model files for Flask API deployment |
| `SkillBridge_AI_ML_Lab_Report.pdf` | Official ML Training Lab Report submitted for ITM 328 |

---

## System Architecture

The recommendation engine operates as a four-stage ensemble pipeline:

1. **Pre-processing** — Lowercasing, punctuation removal, stopword elimination, tokenisation, and WordNet lemmatisation
2. **Vectorisation** — TF-IDF (3,000-term vocabulary with domain-specific skill weights) or Sentence-BERT (`all-MiniLM-L6-v2`) embeddings
3. **Similarity Scoring** — Weighted ensemble of TF-IDF Cosine (40%), KNN (30%), Word2Vec (20%), and Jaccard Coefficient (10%)
4. **Re-ranking** — SBERT semantic re-ranking for improved precision on paraphrased skill descriptions

---

## Dataset

**Source:** Kaggle — `job_recommendation_dataset.csv`

| Property | Value |
|---|---|
| Total records | 50,000 (49,999 after deduplication) |
| Industry classes | 7 (Education, Finance, Healthcare, Manufacturing, Marketing, Retail, Software) |
| Unique job titles | 639 |
| Train / Test split | 80% / 20% stratified, `random_state=42` |

**Features used:** Required Skills (primary NLP feature), Job Title, Experience Level, Salary, Location, Company

---

## ML Techniques Implemented

- TF-IDF Vectorisation with domain-specific skill weighting
- Cosine Similarity
- Jaccard Coefficient
- K-Nearest Neighbours (KNN)
- Word2Vec Semantic Embeddings
- Sentence-BERT (`all-MiniLM-L6-v2`) Contextual Embeddings
- Gated Recurrent Unit (GRU) for career tracking
- Latent Dirichlet Allocation (LDA) for topic modelling
- VADER Sentiment Analysis
- BM25 Retrieval
- Binary Genetic Algorithm for feature selection
- Inverse Probability Weighting (IPW) for causal analysis
- Stratified K-Fold Cross-Validation with bootstrap confidence intervals
- ANOVA, Wilcoxon, and Cohen's D statistical significance tests

---

## Results Summary

### Primary Recommendation Models

| Model | Train Accuracy | Test Accuracy | Precision | Recall | F1 Score |
|---|---|---|---|---|---|
| TF-IDF + Cosine + Jaccard | 81.68% | 82.33% | 0.847 | 0.823 | 0.830 |
| Sentence-BERT + Cosine + Jaccard | 84.57% | **85.05%** | 0.860 | 0.851 | 0.855 |

Both models demonstrate stable generalisation (test accuracy >= train accuracy), confirming no overfitting. The Sentence-BERT model achieves the 85% target threshold, improving on the TF-IDF baseline by 2.72 percentage points.

### 7-Model Industry Classification Benchmark

| Classifier | Train Accuracy | Test Accuracy | Variance |
|---|---|---|---|
| **Random Forest (Best)** | 78.59% | **78.33%** | 0.0026 |
| Logistic Regression | 78.37% | 78.28% | 0.0009 |
| Gradient Boosting | 79.70% | 78.26% | 0.0144 |
| Naive Bayes (GNB) | 78.52% | 78.23% | 0.0029 |
| SVM (LinearSVC) | 78.29% | 78.21% | 0.0008 |
| ANN (MLP) | 78.63% | 78.20% | 0.0043 |
| KNN (k=7) | 83.52% | 76.91% | 0.0661 |

Random Forest achieves the highest test accuracy. KNN shows the highest overfitting risk (variance: 0.0661).

### Stratified 5-Fold Cross-Validation

| Model | Avg. Accuracy | Avg. Precision | Avg. Recall | Avg. F1 |
|---|---|---|---|---|
| TF-IDF + Cosine | 81.81% | 0.8427 | 0.8181 | 0.8252 |
| Sentence-BERT Proxy | 84.18% | 0.8563 | 0.8418 | 0.8466 |

---

## Key Findings

- Healthcare, Manufacturing, and Retail are classified with 100% accuracy by both models, indicating highly discriminative TF-IDF features for these industries.
- The primary confusion occurs between Finance and Software categories, reflecting genuine semantic overlap in FinTech skill vocabulary.
- Sentence-BERT reduces Marketing misclassifications from 505 (TF-IDF) to 233, demonstrating superior handling of varied business language.
- All five engineered numeric features (Salary, Experience, Location, Skill Count, Industry Encoding) show near-zero pairwise correlations, confirming feature independence and validating joint use in classification.

---

## Supporting Modules

| Module | Description |
|---|---|
| CV Parser | Accepts PDF, DOCX, and OCR image inputs; extracts skill text for direct pipeline injection |
| Personalised Learning Pathway | Maps identified skill gaps to curated course recommendations (Tavakoli et al., 2022) |
| Employment Confidence Scoring | Quantifies causal impact of AI tool use on job-seeking confidence via IPW (Xiao & Zheng, 2025) |
| LDA Topic Modelling | Discovers macro labour market parameters from the dataset (Alaql et al., 2023) |
| Job Title Classifier | RandomForestClassifier + TF-IDF trained on 50,000 rows across 639 job title classes |

---

## How to Run the Notebooks

1. Open any `.ipynb` file in this repository.
2. Click the **Open in Colab** badge at the top of the notebook, or go to [colab.research.google.com](https://colab.research.google.com), select **File > Open notebook > GitHub**, and paste this repository URL.
3. Upload the dataset `job_recommendation_dataset.csv` to the Colab session storage when prompted (available on Kaggle).
4. Run all cells in order from top to bottom using **Runtime > Run all**.

For the final notebook (`SkillBridge_Final_With_PKL.ipynb`), the generated `.pkl` files must be downloaded and placed in the Flask API directory for backend deployment.

---

## Flask API Endpoints

| Endpoint | Method | Description |
|---|---|---|
| `/health` | GET | API health check |
| `/recommend` | POST | Returns top job recommendations from manual skill input |
| `/cv_recommend` | POST | Accepts CV file upload and returns recommendations |
| `/career_predict` | POST | Predicts industry category from skill profile |
| `/job_title_predict` | POST | Predicts specific job title from skill and context features |

---

## References

1. Ajjam, M., & Al-Raweshidy, H. (2026). TF-IDF + Cosine Similarity + Greedy Matching for job-skill alignment.
2. Alsaif, Y., et al. (2022). Weighted Cosine Similarity + Jaccard Coefficient + Word2Vec for candidate-job matching.
3. Tavakoli, M., et al. (2022). eDoer: Personalised education recommender system for skill-to-job alignment.
4. Huang, L. (2022). GRU-based career tracking with attention mechanism and negative sampling for employment recommendation.
5. Chen, Z. (2022). Six-stage AI recruitment pipeline with bias detection, P-J Fit, P-O Fit, and resume scoring.
6. Xiao, Y., & Zheng, Q. (2025). ChatGPT use and employment confidence: OLS regression, IPW robustness, and SEM mediation analysis.
7. Dawson, S., et al. (2021). SKILLS SPACE: Quantifying career transition pathways via skill set similarity.
8. Alaql, A., et al. (2023). Big data and LDA for multi-generational labour market parameter discovery.

---

## SDG-8 Alignment

This project directly supports **UN Sustainable Development Goal 8 — Decent Work and Economic Growth** by democratising access to personalised career guidance. The CV upload module removes the technical barrier for non-expert users, the learning pathway module bridges the gap between current and target skill sets, and the employment confidence scoring module provides measurable evidence that AI-assisted career preparation improves candidate readiness for the job market.

---

*Section A | Batch 8th | B.Sc. in ITM | Daffodil International University*
