---
name: python-api
description: >
  Patrones de diseño de APIs con Python: FastAPI, estructura de proyecto, validación y testing.
  Trigger: Al crear endpoints, diseñar la estructura del proyecto Python, implementar validación o tests.
metadata:
  author: team-ai-kit
  version: "1.0"
---

## When to Use

Carga este skill cuando:

- Creas o modificas endpoints en FastAPI/Flask/Django
- Diseñas la estructura de un proyecto Python backend
- Implementas validación de datos con Pydantic
- Escribes tests para la API

---

## Critical Patterns

### Pattern 1: Estructura por dominio

```
src/
├── main.py                  # entry point
├── config.py                # settings con pydantic-settings
├── dependencies.py          # dependency injection
├── users/
│   ├── __init__.py
│   ├── router.py            # endpoints
│   ├── service.py           # lógica de negocio
│   ├── repository.py        # acceso a datos
│   ├── schemas.py           # Pydantic models (request/response)
│   └── models.py            # ORM models (SQLAlchemy/Prisma)
├── products/
│   ├── ...
└── shared/
    ├── errors.py            # excepciones de dominio
    └── middleware.py         # cross-cutting concerns
```

### Pattern 2: Schemas de entrada/salida con Pydantic

```python
from pydantic import BaseModel, EmailStr, Field

class CreateUserRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8)
    name: str = Field(min_length=2, max_length=100)

class UserResponse(BaseModel):
    id: str
    email: str
    name: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
```

### Pattern 3: Router delgado — lógica en service

```python
# users/router.py
from fastapi import APIRouter, Depends
from .service import UserService
from .schemas import CreateUserRequest, UserResponse

router = APIRouter(prefix="/users", tags=["users"])

@router.post("/", response_model=UserResponse, status_code=201)
async def create_user(
    dto: CreateUserRequest,
    service: UserService = Depends(),
) -> UserResponse:
    return await service.register(dto)
```

### Pattern 4: Dependency Injection con FastAPI

```python
# dependencies.py
from functools import lru_cache
from .config import Settings

@lru_cache
def get_settings() -> Settings:
    return Settings()

async def get_db(settings: Settings = Depends(get_settings)) -> AsyncSession:
    async with async_session(settings.database_url) as session:
        yield session

# users/service.py
class UserService:
    def __init__(self, db: AsyncSession = Depends(get_db)):
        self.repository = UserRepository(db)

    async def register(self, dto: CreateUserRequest) -> User:
        existing = await self.repository.find_by_email(dto.email)
        if existing:
            raise ConflictError(f"Email {dto.email} already registered")
        return await self.repository.create(dto)
```

---

## Anti-Patterns

### Don't: Lógica de negocio en el router

```python
# ❌ MAL — router hace todo
@router.post("/users/")
async def create_user(dto: CreateUserRequest, db: Session = Depends(get_db)):
    existing = db.query(User).filter(User.email == dto.email).first()
    if existing:
        raise HTTPException(409, "Email exists")
    hashed = bcrypt.hash(dto.password)
    user = User(email=dto.email, password=hashed)
    db.add(user)
    db.commit()
    return user

# ✅ BIEN — router delega
@router.post("/users/")
async def create_user(dto: CreateUserRequest, service: UserService = Depends()):
    return await service.register(dto)
```

### Don't: Bare except

```python
# ❌ MAL
try:
    result = await risky_operation()
except:
    pass

# ✅ BIEN
try:
    result = await risky_operation()
except SpecificError as e:
    logger.warning("Operation failed: %s", e)
    raise
```

---

## Quick Reference

| Capa          | Responsabilidad                          | Archivo       |
| ------------- | ---------------------------------------- | ------------- |
| Router        | Definir endpoints, parsear HTTP          | `router.py`   |
| Service       | Lógica de negocio                        | `service.py`  |
| Repository    | Acceso a datos (ORM)                     | `repository.py` |
| Schemas       | Validación entrada/salida (Pydantic)     | `schemas.py`  |
| Models        | Definición de tablas (SQLAlchemy)        | `models.py`   |
