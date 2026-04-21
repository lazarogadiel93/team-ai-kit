---
name: data-testing
description: >
  Testing patterns for data and ML projects: pytest, data validation, model evaluation, pipeline testing.
  Trigger: When writing tests for data transformations, model accuracy, or pipeline correctness.
globs:
  - "**/test_*.py"
  - "**/*_test.py"
  - "**/tests/**/*.py"
metadata:
  author: team-ai-kit
  version: "1.0"
---

# Data — Testing

> Placeholder skill. Full content coming in a follow-up PR.

## When to Use

- Testing data transformations and pipeline steps
- Validating data schemas and quality
- Testing model performance and regressions
- Property-based testing for data functions

## Critical Patterns

- Use pytest fixtures for reusable sample DataFrames
  - ❌ Recreating test data in every test function
  - ✅ `@pytest.fixture` returning a canonical DataFrame
- Assert model metrics against minimum thresholds, not exact values
- Use pandera schema tests to validate pipeline output shapes

## Quick Reference

| Topic | Pattern |
|-------|---------|
| Framework | pytest + pytest-cov |
| Data validation | pandera schema tests |
| Model testing | Assert metrics above thresholds |
| Fixtures | pytest fixtures for sample DataFrames |
