# Pack: Data (pandas / scikit-learn / ML)

> Rules and conventions for data scientists and ML engineers.

---

## Architecture Rules

- Separate data ingestion, transformation, and model training into distinct pipeline steps
- Use configuration files (YAML/TOML) for hyperparameters — never hardcode
- Keep notebooks for exploration only — production code goes in `.py` modules
- Version datasets and models alongside code

## Code Quality Rules

- Use pandas method chaining for readable transformations
- Use scikit-learn `Pipeline` + `ColumnTransformer` for reproducible preprocessing
- Always set random seeds for reproducibility
- Type-hint all function signatures
- Use `logging` module — never `print()` in production code

## Testing

- Test data transformations with known input/output pairs
- Validate data schemas with pandera or Great Expectations
- Assert model metrics stay above defined thresholds (regression tests)
- Use pytest fixtures for sample DataFrames

## Naming

- Modules: `snake_case.py`
- Pipelines: `*_pipeline.py`
- Notebooks: `01_exploration.ipynb`, `02_modeling.ipynb` (numbered)
- Tests: `test_*.py`
- Models: `model_*.pkl` or `model_*.joblib`

## Thinking Rules

- Prefer the most readable solution over the most clever one
- Think about data lineage and reproducibility before implementing
- Think about the function contract (inputs/outputs) before implementing
- Validate type assumptions at the system boundary, not in every internal function
- Consider the execution context: batch vs streaming, memory constraints
