# Pack: Data (pandas / scikit-learn / ML)

> Rules and conventions for data scientists and ML engineers.

---

## Architecture Rules

- Separate data ingestion, transformation, and model training into distinct pipeline steps
- Use configuration files (YAML/TOML) for hyperparameters — never hardcode
- Keep notebooks for exploration only — production code goes in `.py` modules
- Version datasets and models alongside code

## Coding Standards

- Use pandas method chaining for readable transformations
- Use scikit-learn `Pipeline` + `ColumnTransformer` for reproducible preprocessing
- Always set random seeds for reproducibility
- Type-hint all function signatures
- Use `logging` module — never `print()` in production code

## Testing Standards

- Test data transformations with known input/output pairs
- Validate data schemas with pandera or Great Expectations
- Assert model metrics stay above defined thresholds (regression tests)
- Use pytest fixtures for sample DataFrames

## Naming Conventions

- Modules: `snake_case.py`
- Pipelines: `*_pipeline.py`
- Notebooks: `01_exploration.ipynb`, `02_modeling.ipynb` (numbered)
- Tests: `test_*.py`
- Models: `model_*.pkl` or `model_*.joblib`
