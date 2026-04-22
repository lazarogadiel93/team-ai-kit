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

## When to Use

Load this skill when:
- Transforming or cleaning data with pandas (ETL pipelines, feature engineering)
- Building reproducible ML preprocessing with scikit-learn Pipeline and ColumnTransformer
- Adding runtime data validation with pandera schemas
- Tracking experiments, parameters, and models with MLflow
- Reviewing or writing code in `*.py` or `*.ipynb` files that involve data manipulation or model training

## Critical Patterns

### Pattern 1: Pandas Method Chaining for Readable Transformations

Use `assign`, `pipe`, `query`, and other chainable methods to build linear, readable
transformation pipelines. Each step returns a **new** DataFrame, making the flow explicit
and debuggable.

```python
# ❌ BAD: imperative mutations scattered across lines
df["revenue_usd"] = df["revenue"] * df["exchange_rate"]
df = df[df["revenue_usd"] > 0]
df["log_revenue"] = np.log1p(df["revenue_usd"])
df = df.drop(columns=["exchange_rate"])
df = df.sort_values("log_revenue", ascending=False)
```

```python
# ✅ GOOD: method chaining: each step is a pure transformation
def compute_log_revenue(df: pd.DataFrame) -> pd.DataFrame:
    """Custom transform compatible with .pipe()."""
    return df.assign(log_revenue=lambda d: np.log1p(d["revenue_usd"]))

clean_df = (
    raw_df
    .assign(revenue_usd=lambda d: d["revenue"] * d["exchange_rate"])
    .query("revenue_usd > 0")
    .pipe(compute_log_revenue)
    .drop(columns=["exchange_rate"])
    .sort_values("log_revenue", ascending=False)
    .reset_index(drop=True)
)
```

**Key rules:**
- Wrap the entire chain in parentheses for multi-line readability.
- Use `assign` for new/derived columns: it returns a new DataFrame.
- Use `pipe` to inject custom functions into the chain without breaking the flow.
- Use `query` instead of boolean indexing (`df[df["col"] > 0]`) inside chains.
- Every function passed to `pipe` MUST accept a DataFrame and return a DataFrame.

---

### Pattern 2: scikit-learn Pipeline + ColumnTransformer for Reproducible Preprocessing

Separate numeric and categorical preprocessing into sub-pipelines, combine them with
`ColumnTransformer`, then chain the result with an estimator via `Pipeline`. This
guarantees identical transformations at train and inference time.

```python
# ❌ BAD: manual, fragile, order-dependent preprocessing
from sklearn.preprocessing import StandardScaler, OneHotEncoder
from sklearn.impute import SimpleImputer

imputer = SimpleImputer(strategy="mean")
X_train[num_cols] = imputer.fit_transform(X_train[num_cols])
X_test[num_cols] = imputer.transform(X_test[num_cols])

scaler = StandardScaler()
X_train[num_cols] = scaler.fit_transform(X_train[num_cols])
X_test[num_cols] = scaler.transform(X_test[num_cols])

encoder = OneHotEncoder(handle_unknown="ignore", sparse_output=False)
X_train_cat = encoder.fit_transform(X_train[cat_cols])
X_test_cat = encoder.transform(X_test[cat_cols])
# Easy to forget a step or apply fit_transform on test data: data leakage
```

```python
# ✅ GOOD: declarative Pipeline + ColumnTransformer
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline
from sklearn.impute import SimpleImputer
from sklearn.preprocessing import StandardScaler, OneHotEncoder
from sklearn.ensemble import RandomForestClassifier

NUM_FEATURES = ["age", "income", "credit_score"]
CAT_FEATURES = ["state", "gender", "product_type"]

numeric_pipeline = Pipeline([
    ("imputer", SimpleImputer(strategy="median")),
    ("scaler", StandardScaler()),
])

categorical_pipeline = Pipeline([
    ("imputer", SimpleImputer(strategy="constant", fill_value="missing")),
    ("encoder", OneHotEncoder(handle_unknown="ignore", sparse_output=False)),
])

preprocessor = ColumnTransformer([
    ("num", numeric_pipeline, NUM_FEATURES),
    ("cat", categorical_pipeline, CAT_FEATURES),
])

model = Pipeline([
    ("preprocessor", preprocessor),
    ("classifier", RandomForestClassifier(n_estimators=200, random_state=42)),
])

# Single call: no leakage possible
model.fit(X_train, y_train)
predictions = model.predict(X_test)
```

**Key rules:**
- Define feature lists (`NUM_FEATURES`, `CAT_FEATURES`) as module-level constants.
- Never call `fit_transform` on test/validation data: the Pipeline handles this.
- Use `handle_unknown="ignore"` in `OneHotEncoder` to survive unseen categories at inference.
- Use `Pipeline` (not `make_pipeline`) when you need named steps for grid search: `"classifier__n_estimators"`.
- The entire pipeline is serializable with `joblib`: ship it as one artifact.

---

### Pattern 3: Data Validation with Pandera Schemas

Define explicit contracts for your data at pipeline boundaries. Use `DataFrameModel`
(class-based API) for type-annotated schemas and the `@check_types` decorator for
automatic runtime validation on function inputs and outputs.

```python
# ❌ BAD: ad-hoc assertions that miss edge cases and are hard to maintain
assert df["age"].dtype == int
assert df["age"].min() >= 0
assert df["email"].str.contains("@").all()
assert set(df.columns) == {"age", "email", "score"}
# No coercion, no clear error messages, no reuse across functions
```

```python
# ✅ GOOD: pandera DataFrameModel with typed fields and reusable checks
import pandera.pandas as pa
from pandera.typing import Series, DataFrame

class UserSchema(pa.DataFrameModel):
    age: Series[int] = pa.Field(ge=0, le=120, coerce=True)
    email: Series[str] = pa.Field(str_matches=r".+@.+\..+")
    score: Series[float] = pa.Field(ge=0.0, le=1.0, coerce=True)

    class Config:
        strict = True   # reject unexpected columns
        coerce = True   # auto-cast types before validation

class ScoredUserSchema(UserSchema):
    risk_label: Series[str] = pa.Field(isin=["low", "medium", "high"])

@pa.check_types
def enrich_users(df: DataFrame[UserSchema]) -> DataFrame[ScoredUserSchema]:
    """Validated input AND output: contract enforced at runtime."""
    return df.assign(
        risk_label=lambda d: pd.cut(
            d["score"], bins=[0, 0.33, 0.66, 1.0], labels=["low", "medium", "high"]
        )
    )

# Validation happens automatically on call
result = enrich_users(raw_df)
```

**Key rules:**
- Prefer `DataFrameModel` (class-based) over `DataFrameSchema` (dict-based) for type safety.
- Use `coerce=True` to auto-cast columns before checking (e.g., `"123"` to `123`).
- Use `strict=True` to reject unexpected columns: catches schema drift early.
- Use `@pa.check_types` on every function at a pipeline boundary (ingestion, transformation, export).
- Inherit schemas (`ScoredUserSchema(UserSchema)`) to extend contracts without duplication.

---

### Pattern 4: Experiment Tracking with MLflow

Wrap every training run in `mlflow.start_run()`, log parameters, metrics (with step),
and the final model. This makes every experiment reproducible and comparable.

```python
# ❌ BAD: results printed to console, lost after the session
model = RandomForestClassifier(n_estimators=200, max_depth=10)
model.fit(X_train, y_train)
print(f"Accuracy: {model.score(X_test, y_test)}")
# No record of hyperparameters, no way to compare runs, no model artifact
```

```python
# ✅ GOOD: structured experiment tracking with MLflow
import mlflow
from sklearn.metrics import accuracy_score, f1_score, roc_auc_score

mlflow.set_tracking_uri("http://localhost:5000")
mlflow.set_experiment("churn-prediction")

PARAMS = {
    "n_estimators": 200,
    "max_depth": 10,
    "min_samples_split": 5,
    "random_state": 42,
}

with mlflow.start_run(run_name="rf-baseline") as run:
    # Log all hyperparameters at once
    mlflow.log_params(PARAMS)
    mlflow.set_tag("model_type", "RandomForest")
    mlflow.set_tag("dataset_version", "v2.3")

    model = RandomForestClassifier(**PARAMS)
    model.fit(X_train, y_train)
    y_pred = model.predict(X_test)
    y_proba = model.predict_proba(X_test)[:, 1]

    # Log multiple metrics
    metrics = {
        "accuracy": accuracy_score(y_test, y_pred),
        "f1": f1_score(y_test, y_pred),
        "roc_auc": roc_auc_score(y_test, y_proba),
    }
    mlflow.log_metrics(metrics)

    # Log the model artifact: includes conda env and signature
    mlflow.sklearn.log_model(
        sk_model=model,
        artifact_path="model",
        input_example=X_test.iloc[:3],
    )

    print(f"Run ID: {run.info.run_id}")
    print(f"Metrics: {metrics}")
```

**Key rules:**
- Always use `mlflow.start_run()` as a context manager: guarantees the run is closed.
- Use `log_params` (plural) to log a dict of hyperparameters in one call.
- Use `log_metrics` (plural) to log all evaluation metrics together.
- Use `set_tag` for metadata not related to model performance (dataset version, author, etc.).
- Pass `input_example` to `log_model`: enables signature inference and serving validation.
- For iterative training (deep learning), use `log_metric("loss", value, step=epoch)`.
- For scikit-learn specifically, consider `mlflow.sklearn.autolog()` as a complementary tool.

---

## Anti-Patterns

### Anti-Pattern 1: Mutating DataFrames In-Place

In-place mutation makes pipelines fragile, non-deterministic, and impossible to debug.
A function that modifies its input silently corrupts upstream references.

```python
# ❌ DANGEROUS: in-place mutation
def prepare_features(df: pd.DataFrame) -> pd.DataFrame:
    df["age_bucket"] = pd.cut(df["age"], bins=[0, 18, 35, 65, 120])
    df.drop(columns=["raw_timestamp"], inplace=True)
    df.fillna(0, inplace=True)
    return df

# Caller's original DataFrame is now silently modified
clean = prepare_features(raw_df)
# raw_df has ALSO been mutated: "raw_timestamp" is gone
```

```python
# ✅ SAFE: method chaining returns new DataFrames
def prepare_features(df: pd.DataFrame) -> pd.DataFrame:
    return (
        df
        .assign(age_bucket=lambda d: pd.cut(d["age"], bins=[0, 18, 35, 65, 120]))
        .drop(columns=["raw_timestamp"])
        .fillna(0)
    )

clean = prepare_features(raw_df)
# raw_df is untouched
```

**Why it matters:** In-place operations break referential transparency. When two parts of
your code hold references to the same DataFrame, a mutation in one place causes silent bugs
in the other. Method chaining with immutable returns makes data flow explicit and testable.

---

### Anti-Pattern 2: Hardcoding Hyperparameters

Scattering magic numbers across training scripts makes experiments unreproducible and
comparison impossible.

```python
# ❌ FRAGILE: hyperparameters buried in code
model = GradientBoostingClassifier(
    n_estimators=150,
    learning_rate=0.05,
    max_depth=6,
    subsample=0.8,
)
model.fit(X_train, y_train)
# Which run used learning_rate=0.1? No one knows.
```

```python
# ✅ TRACEABLE: config dict + MLflow tracking
from dataclasses import dataclass, asdict

@dataclass(frozen=True)
class TrainingConfig:
    n_estimators: int = 150
    learning_rate: float = 0.05
    max_depth: int = 6
    subsample: float = 0.8

config = TrainingConfig()

with mlflow.start_run():
    mlflow.log_params(asdict(config))
    model = GradientBoostingClassifier(**asdict(config))
    model.fit(X_train, y_train)
```

**Why it matters:** Without a single source of truth for hyperparameters, you cannot
reproduce a result, compare runs, or do systematic tuning. Use a frozen dataclass (or
a YAML/TOML config file) as the canonical source and log it to MLflow on every run.

---

## Quick Reference

| Task | Tool | Key API | Import |
|------|------|---------|--------|
| Chain transformations | pandas | `df.assign().pipe().query()` | `import pandas as pd` |
| Custom transform in chain | pandas | `df.pipe(my_func, arg=val)` | `import pandas as pd` |
| Numeric preprocessing | scikit-learn | `Pipeline([("imp", SimpleImputer()), ("sc", StandardScaler())])` | `from sklearn.pipeline import Pipeline` |
| Categorical preprocessing | scikit-learn | `Pipeline([("imp", SimpleImputer()), ("enc", OneHotEncoder())])` | `from sklearn.preprocessing import OneHotEncoder` |
| Combine feature pipelines | scikit-learn | `ColumnTransformer([("num", num_pipe, cols), ...])` | `from sklearn.compose import ColumnTransformer` |
| Full train pipeline | scikit-learn | `Pipeline([("pre", preprocessor), ("clf", model)])` | `from sklearn.pipeline import Pipeline` |
| Schema definition | pandera | `class MySchema(pa.DataFrameModel)` | `import pandera.pandas as pa` |
| Runtime validation | pandera | `@pa.check_types` decorator | `from pandera.typing import DataFrame` |
| Field constraints | pandera | `pa.Field(ge=0, le=100, coerce=True)` | `import pandera.pandas as pa` |
| Start tracked run | MLflow | `with mlflow.start_run():` | `import mlflow` |
| Log hyperparameters | MLflow | `mlflow.log_params({"lr": 0.01})` | `import mlflow` |
| Log evaluation metrics | MLflow | `mlflow.log_metrics({"f1": 0.87})` | `import mlflow` |
| Save model artifact | MLflow | `mlflow.sklearn.log_model(model, "model")` | `import mlflow` |
| Auto-log everything | MLflow | `mlflow.sklearn.autolog()` | `import mlflow` |
