---
name: python-testing
description: >
  Python testing patterns with pytest: fixtures, mocking, API testing, factories, parametrize, and async test strategies.
  Trigger: When writing tests, configuring pytest, mocking dependencies, or testing FastAPI endpoints.
globs:
  - "**/test_*.py"
  - "**/*_test.py"
  - "**/tests/**"
  - "**/conftest.py"
  - "**/pytest.ini"
  - "**/pyproject.toml"
metadata:
  author: team-ai-kit
  version: "1.0"
---

## When to Use

Load this skill when:

- Writing tests with pytest
- Mocking services or external dependencies
- Testing FastAPI endpoints
- Configuring fixtures, factories, or conftest.py
- Setting up async tests with anyio or pytest-asyncio
- Managing test databases with transaction rollback
- Writing parametrized or property-based tests

---

## Critical Patterns

### Pattern 1: conftest.py organization

Keep conftest.py files scoped to their directory. Place shared fixtures in the root `tests/conftest.py` and domain-specific fixtures in subdirectories.

```
tests/
├── conftest.py              # shared: app, client, db, settings overrides
├── users/
│   ├── conftest.py          # user-specific: sample_user, user_factory
│   ├── test_router.py
│   └── test_service.py
├── products/
│   ├── conftest.py
│   └── test_router.py
```

```python
# tests/conftest.py — shared fixtures
import pytest
from httpx import AsyncClient, ASGITransport
from main import create_app

@pytest.fixture
async def app():
    app = create_app(testing=True)
    yield app

@pytest.fixture
async def client(app):
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        yield client
```

```python
# ❌ BAD — one massive conftest.py with 50 fixtures for all domains
# ✅ GOOD — split conftest.py per domain, share only cross-cutting fixtures at root
```

### Pattern 2: Fixtures for reusable setup

```python
@pytest.fixture
def sample_user() -> dict:
    return {
        "email": "test@example.com",
        "password": "secure12345",
        "name": "Test User",
    }

@pytest.fixture
async def created_user(client: AsyncClient, sample_user: dict) -> dict:
    """Create a user and return the response data."""
    response = await client.post("/api/users", json=sample_user)
    assert response.status_code == 201
    return response.json()
```

```python
# ❌ BAD — repeating setup in every test
async def test_get_user(client):
    await client.post("/api/users", json={"email": "a@b.com", ...})
    await client.post("/api/users", json={"email": "a@b.com", ...})  # duplicated

# ✅ GOOD — use fixtures for setup, tests stay focused on assertions
async def test_get_user(client, created_user):
    response = await client.get(f"/api/users/{created_user['id']}")
    assert response.status_code == 200
```

### Pattern 3: Full endpoint test

```python
import pytest

@pytest.mark.anyio
async def test_create_user_returns_201(client: AsyncClient, sample_user: dict):
    response = await client.post("/api/users", json=sample_user)

    assert response.status_code == 201
    data = response.json()
    assert data["email"] == sample_user["email"]
    assert "id" in data
    assert "password" not in data  # never expose the password

@pytest.mark.anyio
async def test_create_user_duplicate_returns_409(client: AsyncClient, sample_user: dict):
    await client.post("/api/users", json=sample_user)
    response = await client.post("/api/users", json=sample_user)

    assert response.status_code == 409
```

### Pattern 4: Mocking with dependency overrides

```python
from unittest.mock import AsyncMock

@pytest.fixture
def mock_user_service():
    service = AsyncMock(spec=UserService)
    service.register.return_value = User(id="1", email="test@test.com", name="Test")
    return service

@pytest.fixture
def app_with_mocks(mock_user_service):
    app = create_app()
    app.dependency_overrides[UserService] = lambda: mock_user_service
    yield app
    app.dependency_overrides.clear()
```

```python
# ❌ BAD — patching internal imports instead of using DI
@patch("users.service.UserRepository")
async def test_register(mock_repo):
    ...  # fragile, breaks on refactor

# ✅ GOOD — override the dependency via FastAPI's DI system
app.dependency_overrides[UserService] = lambda: mock_service
```

### Pattern 5: Arrange-Act-Assert (AAA)

```python
async def test_get_user_raises_not_found():
    # Arrange
    repository = AsyncMock(spec=UserRepository)
    repository.find_by_id.return_value = None
    service = UserService(repository)

    # Act & Assert
    with pytest.raises(NotFoundError):
        await service.get_by_id("nonexistent")
```

```python
# ❌ BAD — test does setup, action, and assertion all interleaved
async def test_something(client):
    user = await client.post("/users", json=data)
    assert user.status_code == 201
    updated = await client.patch(f"/users/{user.json()['id']}", json={"name": "New"})
    assert updated.status_code == 200
    deleted = await client.delete(f"/users/{user.json()['id']}")
    assert deleted.status_code == 204
    # This is testing 3 different things in one test

# ✅ GOOD — one test, one behavior, clear AAA sections
async def test_update_user_name(client, created_user):
    # Arrange — done by fixture

    # Act
    response = await client.patch(
        f"/api/users/{created_user['id']}",
        json={"name": "Updated Name"},
    )

    # Assert
    assert response.status_code == 200
    assert response.json()["name"] == "Updated Name"
```

### Pattern 6: Parametrize for multiple cases

```python
import pytest

@pytest.mark.parametrize("invalid_email", [
    "",
    "not-an-email",
    "@missing-local.com",
    "missing-domain@",
])
@pytest.mark.anyio
async def test_create_user_rejects_invalid_email(client: AsyncClient, invalid_email: str):
    response = await client.post("/api/users", json={
        "email": invalid_email,
        "password": "secure12345",
        "name": "Test",
    })
    assert response.status_code == 422

@pytest.mark.parametrize("password,expected_status", [
    ("short", 422),         # too short
    ("a" * 8, 201),         # minimum valid
    ("a" * 128, 201),       # long but valid
])
@pytest.mark.anyio
async def test_create_user_password_validation(client, password, expected_status):
    response = await client.post("/api/users", json={
        "email": "valid@example.com",
        "password": password,
        "name": "Test",
    })
    assert response.status_code == expected_status
```

### Pattern 7: Test data factories with polyfactory

```python
from polyfactory.factories.pydantic_factory import ModelFactory
from users.schemas import CreateUserRequest, UserResponse

class UserRequestFactory(ModelFactory):
    __model__ = CreateUserRequest

class UserResponseFactory(ModelFactory):
    __model__ = UserResponse

# Usage in tests
def test_user_factory():
    user = UserRequestFactory.build()
    assert user.email  # random valid email
    assert len(user.password) >= 8

    # Override specific fields
    custom = UserRequestFactory.build(name="Alice")
    assert custom.name == "Alice"

    # Generate a batch
    users = UserRequestFactory.batch(size=10)
    assert len(users) == 10
```

```python
# ❌ BAD — hardcoded test data everywhere
def test_a():
    user = {"email": "a@b.com", "password": "12345678", "name": "Test"}

def test_b():
    user = {"email": "a@b.com", "password": "12345678", "name": "Test"}  # duplicated

# ✅ GOOD — factories generate valid data, override only what matters
def test_a():
    user = UserRequestFactory.build()

def test_b():
    user = UserRequestFactory.build(email="specific@test.com")
```

### Pattern 8: Async test configuration

```toml
# pyproject.toml
[tool.pytest.ini_options]
asyncio_mode = "auto"  # or use markers: @pytest.mark.anyio
testpaths = ["tests"]
markers = [
    "slow: marks tests as slow (deselect with '-m \"not slow\"')",
]
```

```python
# With anyio (recommended — works with both asyncio and trio)
import pytest

@pytest.mark.anyio
async def test_async_operation():
    result = await some_async_function()
    assert result is not None

# With pytest-asyncio
import pytest

@pytest.mark.asyncio
async def test_async_operation():
    result = await some_async_function()
    assert result is not None
```

### Pattern 9: Test database with transaction rollback

```python
import pytest
from sqlalchemy.ext.asyncio import AsyncSession

@pytest.fixture
async def db_session(app) -> AsyncGenerator[AsyncSession, None]:
    """Each test runs in a transaction that is rolled back after."""
    async with app.state.db_engine.begin() as conn:
        session = AsyncSession(bind=conn)
        yield session
        await session.rollback()

@pytest.fixture
async def client(app, db_session):
    """Override the db dependency so all requests use the test transaction."""
    app.dependency_overrides[get_db] = lambda: db_session
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        yield client
    app.dependency_overrides.clear()
```

```python
# ❌ BAD — tests leave data behind, causing flaky failures
@pytest.fixture
async def db_session():
    session = async_session_factory()
    yield session
    await session.close()  # data persists!

# ✅ GOOD — wrap in transaction, rollback after each test
@pytest.fixture
async def db_session():
    async with engine.begin() as conn:
        session = AsyncSession(bind=conn)
        yield session
        await session.rollback()
```

### Pattern 10: monkeypatch patterns

```python
def test_external_api_failure(monkeypatch):
    """Simulate an external API being down."""
    async def mock_fetch(*args, **kwargs):
        raise ConnectionError("Service unavailable")

    monkeypatch.setattr("users.service.fetch_external_profile", mock_fetch)

    with pytest.raises(ServiceUnavailableError):
        await service.enrich_profile("user-123")

def test_settings_override(monkeypatch):
    """Override environment variable for a single test."""
    monkeypatch.setenv("DATABASE_URL", "sqlite:///test.db")
    settings = Settings()
    assert "test.db" in settings.database_url
```

```python
# ❌ BAD — modifying global state without cleanup
import mymodule
original = mymodule.API_KEY
mymodule.API_KEY = "test-key"
# ... test ...
mymodule.API_KEY = original  # easy to forget

# ✅ GOOD — monkeypatch auto-reverts after test
def test_with_api_key(monkeypatch):
    monkeypatch.setattr("mymodule.API_KEY", "test-key")
    # automatically reverted after test
```

### Pattern 11: Coverage configuration

```toml
# pyproject.toml
[tool.coverage.run]
source = ["src"]
omit = ["*/tests/*", "*/migrations/*"]
branch = true

[tool.coverage.report]
fail_under = 80
show_missing = true
exclude_lines = [
    "pragma: no cover",
    "if TYPE_CHECKING:",
    "if __name__ == .__main__.",
]
```

### Pattern 12: Property-based testing with Hypothesis

```python
from hypothesis import given, strategies as st

@given(name=st.text(min_size=2, max_size=100))
def test_user_name_round_trips(name: str):
    """Any valid name should be accepted and returned unchanged."""
    request = CreateUserRequest(
        email="test@example.com",
        password="secure12345",
        name=name,
    )
    assert request.name == name

@given(password=st.text(max_size=7))
def test_short_password_rejected(password: str):
    """Passwords under 8 chars should always fail validation."""
    with pytest.raises(ValidationError):
        CreateUserRequest(
            email="test@example.com",
            password=password,
            name="Test",
        )
```

### Pattern 13: Testing background tasks

```python
from unittest.mock import patch, AsyncMock

@pytest.mark.anyio
async def test_welcome_email_sent_after_registration(client, sample_user):
    with patch("users.router.send_welcome_email", new_callable=AsyncMock) as mock_email:
        response = await client.post("/api/users", json=sample_user)

        assert response.status_code == 201
        mock_email.assert_called_once_with(sample_user["email"])
```

---

## Anti-Patterns

### Don't: Tests that depend on execution order

```python
# ❌ BAD — test_b depends on test_a having run first
created_id = None

def test_a():
    global created_id
    created_id = create_user()

def test_b():
    user = get_user(created_id)  # fails if test_a didn't run

# ✅ GOOD — each test is independent
async def test_get_user(client, sample_user):
    create_response = await client.post("/users", json=sample_user)
    user_id = create_response.json()["id"]
    response = await client.get(f"/users/{user_id}")
    assert response.status_code == 200
```

### Don't: Test implementation details

```python
# ❌ BAD — asserting on internal method calls
async def test_register_calls_hash(mock_repo):
    await service.register(dto)
    mock_repo._internal_hash.assert_called_once()  # fragile

# ✅ GOOD — assert on observable behavior
async def test_register_creates_user(client, sample_user):
    response = await client.post("/api/users", json=sample_user)
    assert response.status_code == 201
    assert response.json()["email"] == sample_user["email"]
```

### Don't: Ignore test isolation

```python
# ❌ BAD — shared mutable state between tests
cache = {}

def test_a():
    cache["key"] = "value"

def test_b():
    assert cache.get("key") is None  # FAILS — polluted by test_a

# ✅ GOOD — use fixtures that reset state
@pytest.fixture(autouse=True)
def clear_cache():
    cache.clear()
    yield
    cache.clear()
```

---

## Quick Reference

| Type            | What it tests                    | Speed  | Fixture                |
| --------------- | -------------------------------- | ------ | ---------------------- |
| Unit test       | Isolated function/class          | Fast   | Mocks                  |
| Integration     | Endpoint + DB                    | Medium | Test DB + client       |
| E2E             | Full flow                        | Slow   | Real app               |
| Property-based  | Invariants over random input     | Medium | Hypothesis strategies  |

| Tool            | Purpose                          | When to use                          |
| --------------- | -------------------------------- | ------------------------------------ |
| `monkeypatch`   | Override attrs/env vars          | External config, globals             |
| `dependency_overrides` | Replace FastAPI deps      | Service/repo mocking in integration  |
| `AsyncMock`     | Mock async callables             | Async services and repos             |
| `polyfactory`   | Generate valid test data         | When you need varied realistic data  |
| `parametrize`   | Run same test with many inputs   | Validation, edge cases               |
| `hypothesis`    | Property-based random testing    | Invariants, serialization roundtrips |
