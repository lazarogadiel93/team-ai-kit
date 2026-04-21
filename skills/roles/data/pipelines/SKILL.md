---
name: data-pipelines
description: >
  Data pipeline and ML workflow patterns: pandas, scikit-learn, data validation, feature engineering, model training.
  Trigger: When building data pipelines, transforming data, training models, or setting up ML workflows.
globs:
  - "**/*.py"
  - "**/*.ipynb"
  - "**/requirements.txt"
  - "**/pyproject.toml"
metadata:
  author: team-ai-kit
  version: "1.0"
---

# Data — Pipelines & ML

> Placeholder skill. Full content coming in a follow-up PR.

## When to Use

- Building ETL / data transformation pipelines
- Feature engineering and data validation
- Training and evaluating ML models
- Setting up reproducible experiments

## Critical Patterns

- Use method chaining with pandas for readable transformations
  - ❌ Mutating DataFrames in-place across multiple statements
  - ✅ `df.pipe(clean).pipe(transform).pipe(validate)` chaining
- Validate data schemas at pipeline boundaries with pandera
- Use scikit-learn `Pipeline` to prevent train/test leakage

## Quick Reference

| Topic | Pattern |
|-------|---------|
| DataFrames | pandas with method chaining |
| Validation | pandera or Great Expectations |
| ML pipeline | scikit-learn Pipeline + ColumnTransformer |
| Experiments | MLflow or Weights & Biases |
