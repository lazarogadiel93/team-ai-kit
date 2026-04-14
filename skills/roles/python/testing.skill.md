---
name: python-testing
description: >
  Patrones de testing para Python: pytest, fixtures, mocking y test de APIs.
  Trigger: Al escribir tests en Python, configurar pytest, mockear dependencias, testear endpoints.
metadata:
  author: team-ai-kit
  version: "1.0"
---

## When to Use

Carga este skill cuando:

- Escribes tests con pytest
- Necesitas mockear servicios o dependencias externas
- Testeas endpoints de FastAPI/Flask
- Configuras fixtures y factories

---

## Critical Patterns

### Pattern 1: Fixtures para setup reutilizable

```python
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

@pytest.fixture
def sample_user() -> dict:
    return {
        "email": "test@example.com",
        "password": "secure123",
        "name": "Test User",
    }
```

### Pattern 2: Test de endpoint completo

```python
import pytest

@pytest.mark.anyio
async def test_create_user_returns_201(client: AsyncClient, sample_user: dict):
    response = await client.post("/api/users", json=sample_user)

    assert response.status_code == 201
    data = response.json()
    assert data["email"] == sample_user["email"]
    assert "id" in data
    assert "password" not in data  # nunca exponer el password

@pytest.mark.anyio
async def test_create_user_duplicate_returns_409(client: AsyncClient, sample_user: dict):
    await client.post("/api/users", json=sample_user)
    response = await client.post("/api/users", json=sample_user)

    assert response.status_code == 409
```

### Pattern 3: Mocking con dependency override

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

### Pattern 4: Arrange-Act-Assert

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

---

## Anti-Patterns

### Don't: Tests que dependen de orden de ejecución

```python
# ❌ MAL — test_b depende de que test_a haya corrido antes
def test_a():
    global created_id
    created_id = create_user()

def test_b():
    user = get_user(created_id)  # falla si test_a no corrió

# ✅ BIEN — cada test es independiente
def test_get_user(client, sample_user):
    create_response = client.post("/users", json=sample_user)
    user_id = create_response.json()["id"]
    response = client.get(f"/users/{user_id}")
    assert response.status_code == 200
```

---

## Quick Reference

| Tipo            | Qué testea                       | Velocidad | Fixture          |
| --------------- | -------------------------------- | --------- | ---------------- |
| Unit test       | Función/clase aislada            | Rápido    | Mocks            |
| Integration     | Endpoint + DB                    | Medio     | Test DB + client |
| E2E             | Flujo completo                   | Lento     | App real         |
