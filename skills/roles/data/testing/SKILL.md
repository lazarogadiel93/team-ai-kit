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

## When to Use

Load this skill when:

- Writing tests for pandas/polars DataFrame transformations
- Validating data schemas at pipeline boundaries (ingestion, transform, export)
- Testing ML model performance against baseline thresholds
- Verifying individual pipeline steps in isolation
- Property-based testing of data functions with hypothesis
- Setting up shared test fixtures for tabular data in `conftest.py`

---

## Critical Patterns

### Pattern 1: pytest Fixtures for Sample DataFrames (`conftest.py`)

Share deterministic sample data across your entire test suite using fixtures.
Scope fixtures appropriately: `function` (default) for mutable data, `session` for expensive read-only resources.

```python
# ❌ BAD: Duplicating DataFrame creation in every test file
# test_transform.py
def test_normalize():
    df = pd.DataFrame({"price": [10.0, 20.0], "quantity": [1, 2]})
    result = normalize(df)
    assert result["price"].max() <= 1.0

# test_aggregate.py
def test_total():
    df = pd.DataFrame({"price": [10.0, 20.0], "quantity": [1, 2]})  # duplicated!
    result = compute_total(df)
    assert result["total"].sum() == 50.0
```

```python
# ✅ GOOD: Centralized fixtures in conftest.py
# tests/conftest.py
import pytest
import pandas as pd

@pytest.fixture
def sample_orders() -> pd.DataFrame:
    """Deterministic order data — small, covers edge cases."""
    return pd.DataFrame({
        "order_id": [1, 2, 3, 4],
        "price": [10.0, 0.0, 25.5, 100.0],
        "quantity": [1, 0, 3, 1],
        "category": ["electronics", "books", "electronics", "books"],
    })

@pytest.fixture
def empty_orders() -> pd.DataFrame:
    """Empty DataFrame with correct schema for edge-case tests."""
    return pd.DataFrame({
        "order_id": pd.Series([], dtype="int64"),
        "price": pd.Series([], dtype="float64"),
        "quantity": pd.Series([], dtype="int64"),
        "category": pd.Series([], dtype="str"),
    })

@pytest.fixture(scope="session")
def large_reference_dataset(tmp_path_factory) -> pd.DataFrame:
    """Session-scoped fixture for expensive data — created once, shared read-only."""
    path = tmp_path_factory.mktemp("data") / "reference.parquet"
    df = pd.DataFrame({
        "feature_a": range(10_000),
        "feature_b": [x * 0.1 for x in range(10_000)],
    })
    df.to_parquet(path)
    return pd.read_parquet(path)

# tests/test_transform.py
def test_normalize(sample_orders):
    result = normalize(sample_orders)
    assert result["price"].max() <= 1.0

def test_handles_empty(empty_orders):
    result = normalize(empty_orders)
    assert len(result) == 0
```

**Key rules:**
- Always include edge cases in fixtures: zeros, empty DataFrames, nulls
- Use `pytest.fixture(params=[...])` to run the same test against multiple datasets
- Never mutate a shared fixture — return a fresh copy or use `function` scope

---

### Pattern 2: Data Schema Validation Tests with pandera

Use pandera `DataFrameModel` classes to define contracts at pipeline boundaries.
Test that valid data passes and invalid data raises `SchemaError`.

```python
# ❌ BAD: Manual column checks scattered across tests
def test_output_has_right_columns():
    result = run_pipeline(raw_df)
    assert "revenue" in result.columns
    assert result["revenue"].dtype == "float64"
    assert (result["revenue"] >= 0).all()
    # Fragile, incomplete, no reuse
```

```python
# ✅ GOOD: Declarative schema as a DataFrameModel, tested explicitly
# src/schemas.py
import pandera.pandas as pa
from pandera.typing import Series, DataFrame

class RawOrderSchema(pa.DataFrameModel):
    order_id: Series[int] = pa.Field(unique=True)
    price: Series[float] = pa.Field(ge=0.0)
    quantity: Series[int] = pa.Field(ge=0)
    category: Series[str] = pa.Field(isin=["electronics", "books", "clothing"])

    class Config:
        strict = True  # Reject unexpected columns
        coerce = True  # Coerce types before validation

class ProcessedOrderSchema(RawOrderSchema):
    total: Series[float] = pa.Field(ge=0.0)
    processed_at: Series[pa.DateTime]

# src/pipeline.py
@pa.check_types
def process_orders(df: DataFrame[RawOrderSchema]) -> DataFrame[ProcessedOrderSchema]:
    return df.assign(
        total=df["price"] * df["quantity"],
        processed_at=pd.Timestamp.now(),
    )

# tests/test_schemas.py
import pytest
import pandas as pd
from pandera.errors import SchemaError
from src.schemas import RawOrderSchema, ProcessedOrderSchema

def test_valid_data_passes_schema(sample_orders):
    """Valid data should validate without errors."""
    validated = RawOrderSchema.validate(sample_orders)
    assert len(validated) == len(sample_orders)

def test_negative_price_rejected():
    """Schema must reject negative prices."""
    bad_df = pd.DataFrame({
        "order_id": [1],
        "price": [-5.0],
        "quantity": [1],
        "category": ["books"],
    })
    with pytest.raises(SchemaError, match="greater_than_or_equal_to"):
        RawOrderSchema.validate(bad_df)

def test_unknown_category_rejected():
    """Schema must reject categories outside the allowed set."""
    bad_df = pd.DataFrame({
        "order_id": [1],
        "price": [10.0],
        "quantity": [1],
        "category": ["furniture"],
    })
    with pytest.raises(SchemaError, match="isin"):
        RawOrderSchema.validate(bad_df)

def test_extra_columns_rejected_in_strict_mode():
    """Strict mode rejects columns not defined in schema."""
    bad_df = pd.DataFrame({
        "order_id": [1],
        "price": [10.0],
        "quantity": [1],
        "category": ["books"],
        "surprise": ["oops"],
    })
    with pytest.raises(SchemaError):
        RawOrderSchema.validate(bad_df)
```

**Key rules:**
- One schema class per pipeline boundary (raw input, cleaned, features, output)
- Use `strict=True` to catch column drift
- Use `@pa.check_types` on transform functions for runtime validation
- Test BOTH valid and invalid data — schemas are only useful if they reject bad input

---

### Pattern 3: Model Regression Tests

Assert that model metrics stay above known baselines. Store baselines in version-controlled JSON.
Fail loudly when performance degrades.

```python
# ❌ BAD: "It runs" test with no performance assertion
def test_model_trains():
    model = train_model(X_train, y_train)
    predictions = model.predict(X_test)
    assert predictions is not None  # This proves nothing
```

```python
# ✅ GOOD: Assert metrics against versioned baselines
# tests/baselines/model_baseline.json
# {
#     "accuracy": 0.85,
#     "f1_macro": 0.82,
#     "rmse_upper_bound": 0.15
# }

# tests/conftest.py
import json
from pathlib import Path

@pytest.fixture(scope="session")
def model_baseline() -> dict:
    baseline_path = Path(__file__).parent / "baselines" / "model_baseline.json"
    return json.loads(baseline_path.read_text())

@pytest.fixture(scope="session")
def trained_model(large_reference_dataset):
    """Train once per session — expensive fixture."""
    from src.model import train_model
    X = large_reference_dataset.drop(columns=["feature_b"])
    y = large_reference_dataset["feature_b"]
    return train_model(X, y)

# tests/test_model.py
from sklearn.metrics import accuracy_score, f1_score, mean_squared_error
import numpy as np

def test_accuracy_above_baseline(trained_model, X_test, y_test, model_baseline):
    predictions = trained_model.predict(X_test)
    accuracy = accuracy_score(y_test, predictions)
    assert accuracy >= model_baseline["accuracy"], (
        f"Accuracy {accuracy:.4f} dropped below baseline {model_baseline['accuracy']}"
    )

def test_f1_above_baseline(trained_model, X_test, y_test, model_baseline):
    predictions = trained_model.predict(X_test)
    f1 = f1_score(y_test, predictions, average="macro")
    assert f1 >= model_baseline["f1_macro"], (
        f"F1 {f1:.4f} dropped below baseline {model_baseline['f1_macro']}"
    )

def test_rmse_within_bounds(trained_model, X_test, y_test, model_baseline):
    predictions = trained_model.predict(X_test)
    rmse = np.sqrt(mean_squared_error(y_test, predictions))
    assert rmse <= model_baseline["rmse_upper_bound"], (
        f"RMSE {rmse:.4f} exceeds upper bound {model_baseline['rmse_upper_bound']}"
    )

# scripts/update_baseline.py (run manually when model improves)
# Generates a new baseline JSON after a verified improvement.
```

**Key rules:**
- Store baselines in `tests/baselines/*.json` — version-controlled, reviewable in PRs
- Use `scope="session"` for model training fixtures to avoid repeated training
- Separate metric assertions into individual tests for clear failure messages
- Provide a script to update baselines — never auto-update in CI

---

### Pattern 4: Pipeline Step Testing

Test each transform function independently with known inputs and expected outputs.
Never test the full pipeline end-to-end as your only test.

```python
# ❌ BAD: Only testing the entire pipeline as a black box
def test_full_pipeline():
    raw = load_raw_data("data/raw.csv")  # depends on file system
    result = run_full_pipeline(raw)       # no idea which step failed
    assert len(result) > 0               # meaningless assertion
```

```python
# ✅ GOOD: Each step tested in isolation with deterministic data
# src/pipeline.py
def clean_nulls(df: pd.DataFrame) -> pd.DataFrame:
    """Drop rows where all values are null, fill remaining nulls with 0."""
    return df.dropna(how="all").fillna(0)

def add_total_column(df: pd.DataFrame) -> pd.DataFrame:
    """Add total = price * quantity."""
    return df.assign(total=df["price"] * df["quantity"])

def filter_high_value(df: pd.DataFrame, threshold: float = 50.0) -> pd.DataFrame:
    """Keep only orders above a given total threshold."""
    return df[df["total"] >= threshold].reset_index(drop=True)

# tests/test_pipeline_steps.py
import pandas as pd
import numpy as np

def test_clean_nulls_drops_all_null_rows():
    df = pd.DataFrame({
        "price": [10.0, None, 30.0],
        "quantity": [1, None, 3],
    })
    result = clean_nulls(df)
    assert len(result) == 2
    assert result["quantity"].iloc[1] == 3

def test_clean_nulls_fills_partial_nulls():
    df = pd.DataFrame({
        "price": [10.0, None],
        "quantity": [1, 2],
    })
    result = clean_nulls(df)
    assert len(result) == 2
    assert result["price"].iloc[1] == 0.0

def test_add_total_column():
    df = pd.DataFrame({"price": [10.0, 25.0], "quantity": [2, 4]})
    result = add_total_column(df)
    assert "total" in result.columns
    assert list(result["total"]) == [20.0, 100.0]

def test_filter_high_value_default_threshold():
    df = pd.DataFrame({"total": [10.0, 50.0, 100.0]})
    result = filter_high_value(df)
    assert len(result) == 2
    assert list(result["total"]) == [50.0, 100.0]

def test_filter_high_value_custom_threshold():
    df = pd.DataFrame({"total": [10.0, 50.0, 100.0]})
    result = filter_high_value(df, threshold=80.0)
    assert len(result) == 1

@pytest.mark.parametrize("threshold,expected_count", [
    (0.0, 3),
    (50.0, 2),
    (200.0, 0),
])
def test_filter_high_value_parametrized(threshold, expected_count):
    df = pd.DataFrame({"total": [10.0, 50.0, 100.0]})
    result = filter_high_value(df, threshold=threshold)
    assert len(result) == expected_count
```

**Key rules:**
- Each transform is a pure function: DataFrame in, DataFrame out
- Test boundary conditions: empty input, all nulls, single row, large values
- Use `pytest.mark.parametrize` to cover threshold/config variations
- Integration tests (full pipeline) come AFTER unit tests for each step

---

## Anti-Patterns

### Anti-Pattern 1: Testing Against Production Data

Never load real CSVs, database dumps, or API responses in unit tests.
Production data is non-deterministic, large, changes over time, and may contain PII.

```python
# ❌ BAD: Reading from a real data file
def test_transform():
    df = pd.read_csv("s3://prod-bucket/orders_2024.csv")  # slow, flaky, PII risk
    result = transform(df)
    assert len(result) > 0  # what is "correct" here? nobody knows

# ❌ ALSO BAD: Committing large data files to the repo
# tests/data/big_dump.csv (500MB) — bloats the repo, hard to review
```

```python
# ✅ GOOD: Use fixtures with small, known, deterministic data
@pytest.fixture
def sample_orders():
    return pd.DataFrame({
        "order_id": [1, 2, 3],
        "price": [10.0, 0.0, 25.5],
        "quantity": [1, 0, 3],
        "category": ["electronics", "books", "electronics"],
    })

def test_transform(sample_orders):
    result = transform(sample_orders)
    expected_totals = [10.0, 0.0, 76.5]
    assert list(result["total"]) == expected_totals
```

**Why it matters:** Flaky tests erode trust in CI. If a test depends on external data, every failure requires investigating "did the data change or did the code break?" — that ambiguity is the enemy of velocity.

---

### Anti-Pattern 2: No Assertions on Model Performance ("It Runs" Tests)

A test that only checks `predictions is not None` or `len(predictions) > 0` is not a test.
It verifies the function signature, not the model quality.

```python
# ❌ BAD: "It runs" test
def test_model():
    model = train(X_train, y_train)
    preds = model.predict(X_test)
    assert preds is not None       # always true unless crash
    assert len(preds) == len(X_test)  # shape check, not quality check
```

```python
# ✅ GOOD: Assert on actual metrics against baselines
def test_model_accuracy(trained_model, X_test, y_test, model_baseline):
    preds = trained_model.predict(X_test)
    accuracy = accuracy_score(y_test, preds)
    assert accuracy >= model_baseline["accuracy"], (
        f"Model accuracy {accuracy:.4f} is below baseline {model_baseline['accuracy']}"
    )
```

**Why it matters:** A model that predicts the majority class for every input will pass "it runs" tests with flying colors. Without metric assertions, you cannot detect silent regressions — the most dangerous kind.

---

## Quick Reference

| Area | Tool / Pattern | Purpose |
|---|---|---|
| Fixtures | `conftest.py` + `@pytest.fixture` | Shared deterministic DataFrames |
| Fixture scope | `scope="session"` | Expensive resources (models, large data) |
| Parametrize | `@pytest.mark.parametrize` | Run same test with multiple inputs |
| Schema validation | `pandera.DataFrameModel` | Declarative column type/range contracts |
| Runtime validation | `@pa.check_types` | Validate function inputs/outputs at runtime |
| Strict schemas | `Config: strict = True` | Reject unexpected columns |
| Model baselines | `tests/baselines/*.json` | Version-controlled metric thresholds |
| Metric assertions | `assert metric >= baseline[key]` | Catch silent model regressions |
| Pipeline steps | Pure functions, tested independently | Isolate failures to a single transform |
| Property-based | `hypothesis.extra.pandas` | Generate random DataFrames to find edge cases |
| Edge cases | Empty DF, all-null rows, zero values | Cover boundary conditions in fixtures |

---

## Commands

```bash
# Run all data tests
pytest tests/ -v

# Run only schema validation tests
pytest tests/test_schemas.py -v

# Run model tests (slow, session-scoped fixtures)
pytest tests/test_model.py -v --timeout=300

# Run with hypothesis (increase examples for CI)
pytest tests/test_properties.py --hypothesis-seed=42

# Show fixture setup order (debugging)
pytest tests/ --setup-show
```
