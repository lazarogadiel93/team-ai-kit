---
name: python-api
description: >
  Python API design patterns with FastAPI: project structure, validation, dependency injection, error handling, and async patterns.
  Trigger: When creating endpoints, designing project structure, implementing validation, or configuring FastAPI.
globs:
  - "**/*.py"
  - "**/requirements*.txt"
  - "**/pyproject.toml"
  - "**/Pipfile"
metadata:
  author: team-ai-kit
  version: "1.0"
---

## When to Use

Load this skill when:

- Creating or modifying endpoints in FastAPI
- Designing a Python backend project structure
- Implementing data validation with Pydantic
- Configuring dependency injection, middleware, or error handling
- Setting up async database access with SQLAlchemy
- Adding pagination, CORS, or API versioning

---

## Critical Patterns

### Pattern 1: Domain-based project structure

```
src/
├── main.py                  # entry point, lifespan, app factory
├── config.py                # settings via pydantic-settings
├── dependencies.py          # shared dependency injection
├── users/
│   ├── __init__.py
│   ├── router.py            # endpoints (thin — delegates to service)
│   ├── service.py           # business logic
│   ├── repository.py        # data access layer
│   ├── schemas.py           # Pydantic models (request/response)
│   └── models.py            # ORM models (SQLAlchemy)
├── products/
│   ├── ...
└── shared/
    ├── errors.py            # domain exceptions
    ├── middleware.py         # cross-cutting concerns
    ├── pagination.py         # reusable pagination schemas
    └── database.py           # engine, session factory
```

### Pattern 2: Settings with pydantic-settings

```python
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    database_url: str
    redis_url: str = "redis://localhost:6379"
    debug: bool = False
    allowed_origins: list[str] = ["http://localhost:3000"]
    api_v1_prefix: str = "/api/v1"
```

```python
# ❌ BAD — hardcoded config scattered across modules
DATABASE_URL = "postgresql://localhost/mydb"

# ✅ GOOD — centralized, validated, env-driven
settings = Settings()  # reads from .env + environment
```

### Pattern 3: Input/output schemas with Pydantic

```python
from pydantic import BaseModel, ConfigDict, EmailStr, Field
from datetime import datetime

# Request schema — only what the client sends
class CreateUserRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8)
    name: str = Field(min_length=2, max_length=100)

# Response schema — only what the client receives
class UserResponse(BaseModel):
    id: str
    email: str
    name: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)

# Update schema — partial updates with Optional fields
class UpdateUserRequest(BaseModel):
    name: str | None = Field(None, min_length=2, max_length=100)
    email: EmailStr | None = None
```

```python
# ❌ BAD — reusing the same model for input and output
class User(BaseModel):
    id: str
    email: str
    password: str  # leaks password in responses!

# ✅ GOOD — separate request/response schemas
class CreateUserRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8)

class UserResponse(BaseModel):
    id: str
    email: str
    # password is never exposed
```

### Pattern 4: Discriminated unions for polymorphic responses

```python
from typing import Annotated, Literal, Union
from pydantic import BaseModel, Discriminator, Tag

class CardPayment(BaseModel):
    type: Literal["card"] = "card"
    card_last_four: str
    amount: int

class BankTransfer(BaseModel):
    type: Literal["bank_transfer"] = "bank_transfer"
    bank_name: str
    amount: int

PaymentResponse = Annotated[
    Union[
        Annotated[CardPayment, Tag("card")],
        Annotated[BankTransfer, Tag("bank_transfer")],
    ],
    Discriminator("type"),
]
```

### Pattern 5: Thin router — logic lives in service

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

```python
# ❌ BAD — business logic inside the router
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

# ✅ GOOD — router delegates everything
@router.post("/users/", response_model=UserResponse, status_code=201)
async def create_user(dto: CreateUserRequest, service: UserService = Depends()):
    return await service.register(dto)
```

### Pattern 6: Dependency injection with FastAPI

```python
# dependencies.py
from functools import lru_cache
from .config import Settings

@lru_cache
def get_settings() -> Settings:
    return Settings()

async def get_db(settings: Settings = Depends(get_settings)) -> AsyncGenerator[AsyncSession, None]:
    async with async_session_factory(settings.database_url)() as session:
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

### Pattern 7: Domain exceptions with centralized handler

```python
# shared/errors.py
class DomainError(Exception):
    """Base class for all domain errors."""
    def __init__(self, detail: str, code: str = "DOMAIN_ERROR"):
        self.detail = detail
        self.code = code

class NotFoundError(DomainError):
    def __init__(self, detail: str = "Resource not found"):
        super().__init__(detail=detail, code="NOT_FOUND")

class ConflictError(DomainError):
    def __init__(self, detail: str = "Resource already exists"):
        super().__init__(detail=detail, code="CONFLICT")

class ForbiddenError(DomainError):
    def __init__(self, detail: str = "Forbidden"):
        super().__init__(detail=detail, code="FORBIDDEN")
```

```python
# main.py — register exception handlers
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from shared.errors import NotFoundError, ConflictError, DomainError

def register_exception_handlers(app: FastAPI) -> None:
    status_map = {
        NotFoundError: 404,
        ConflictError: 409,
        ForbiddenError: 403,
    }

    @app.exception_handler(DomainError)
    async def domain_error_handler(request: Request, exc: DomainError) -> JSONResponse:
        status = status_map.get(type(exc), 400)
        return JSONResponse(
            status_code=status,
            content={"error": exc.code, "detail": exc.detail},
        )
```

```python
# ❌ BAD — raising HTTPException from service layer
class UserService:
    async def get_by_id(self, user_id: str) -> User:
        user = await self.repo.find_by_id(user_id)
        if not user:
            raise HTTPException(404, "Not found")  # couples service to HTTP
        return user

# ✅ GOOD — raise domain exception, handler maps to HTTP
class UserService:
    async def get_by_id(self, user_id: str) -> User:
        user = await self.repo.find_by_id(user_id)
        if not user:
            raise NotFoundError(f"User {user_id} not found")
        return user
```

### Pattern 8: Lifespan events and app factory

```python
from contextlib import asynccontextmanager
from fastapi import FastAPI

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: initialize resources
    engine = create_async_engine(settings.database_url)
    app.state.db_engine = engine
    yield
    # Shutdown: clean up resources
    await engine.dispose()

def create_app() -> FastAPI:
    app = FastAPI(
        title="My API",
        version="1.0.0",
        lifespan=lifespan,
    )
    register_exception_handlers(app)
    app.include_router(users_router, prefix="/api/v1")
    return app
```

```python
# ❌ BAD — using deprecated @app.on_event
@app.on_event("startup")
async def startup():
    ...

# ✅ GOOD — use lifespan context manager
@asynccontextmanager
async def lifespan(app: FastAPI):
    # startup
    yield
    # shutdown
```

### Pattern 9: Background tasks

```python
from fastapi import BackgroundTasks

@router.post("/users/", status_code=201)
async def create_user(
    dto: CreateUserRequest,
    service: UserService = Depends(),
    background_tasks: BackgroundTasks = BackgroundTasks(),
):
    user = await service.register(dto)
    background_tasks.add_task(send_welcome_email, user.email)
    return user
```

### Pattern 10: Pagination

```python
# shared/pagination.py
from pydantic import BaseModel, Field
from typing import Generic, TypeVar, Sequence

T = TypeVar("T")

class PaginationParams(BaseModel):
    page: int = Field(1, ge=1)
    size: int = Field(20, ge=1, le=100)

    @property
    def offset(self) -> int:
        return (self.page - 1) * self.size

class PaginatedResponse(BaseModel, Generic[T]):
    items: Sequence[T]
    total: int
    page: int
    size: int
    pages: int
```

```python
# Usage in router
@router.get("/", response_model=PaginatedResponse[UserResponse])
async def list_users(
    params: PaginationParams = Depends(),
    service: UserService = Depends(),
):
    return await service.list_users(params)
```

### Pattern 11: CORS configuration

```python
from fastapi.middleware.cors import CORSMiddleware

def create_app() -> FastAPI:
    app = FastAPI(...)

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.allowed_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    return app
```

```python
# ❌ BAD — allow_origins=["*"] with allow_credentials=True
# This is rejected by browsers and is a security risk

# ✅ GOOD — explicit origin list from settings
allow_origins=settings.allowed_origins  # ["https://myapp.com"]
```

### Pattern 12: API versioning via router prefix

```python
# main.py
from fastapi import FastAPI, APIRouter

v1_router = APIRouter(prefix="/api/v1")
v1_router.include_router(users_v1.router)
v1_router.include_router(products_v1.router)

v2_router = APIRouter(prefix="/api/v2")
v2_router.include_router(users_v2.router)

app.include_router(v1_router)
app.include_router(v2_router)
```

### Pattern 13: Async SQLAlchemy session

```python
# shared/database.py
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession

engine = create_async_engine(settings.database_url, echo=settings.debug)
async_session_factory = async_sessionmaker(engine, expire_on_commit=False)

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with async_session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
```

```python
# ❌ BAD — forgetting to commit/rollback
async def get_db():
    session = async_session_factory()
    yield session  # no commit, no rollback, no close

# ✅ GOOD — context manager with commit/rollback
async def get_db():
    async with async_session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
```

### Pattern 14: OpenAPI customization

```python
app = FastAPI(
    title="My Service",
    version="1.0.0",
    description="User management API",
    docs_url="/api/docs",
    redoc_url="/api/redoc",
    openapi_url="/api/openapi.json",
    openapi_tags=[
        {"name": "users", "description": "User management operations"},
        {"name": "products", "description": "Product catalog"},
    ],
)
```

---

## Anti-Patterns

### Don't: Bare except

```python
# ❌ BAD — swallows all errors silently
try:
    result = await risky_operation()
except:
    pass

# ✅ GOOD — catch specific exceptions, log, re-raise if needed
try:
    result = await risky_operation()
except SpecificError as e:
    logger.warning("Operation failed: %s", e)
    raise
```

### Don't: Use sync DB calls in async endpoints

```python
# ❌ BAD — blocks the event loop
@router.get("/users/{user_id}")
async def get_user(user_id: str, db: Session = Depends(get_sync_db)):
    return db.query(User).get(user_id)

# ✅ GOOD — use async session
@router.get("/users/{user_id}")
async def get_user(user_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.id == user_id))
    return result.scalar_one_or_none()
```

### Don't: Return ORM models directly

```python
# ❌ BAD — leaks internal fields and breaks if ORM changes
@router.get("/users/{user_id}")
async def get_user(user_id: str, db: AsyncSession = Depends(get_db)):
    return await db.get(User, user_id)

# ✅ GOOD — return a response schema
@router.get("/users/{user_id}", response_model=UserResponse)
async def get_user(user_id: str, service: UserService = Depends()):
    return await service.get_by_id(user_id)
```

---

## Quick Reference

| Layer      | Responsibility                        | File            |
| ---------- | ------------------------------------- | --------------- |
| Router     | Define endpoints, parse HTTP          | `router.py`     |
| Service    | Business logic, orchestration         | `service.py`    |
| Repository | Data access (ORM queries)             | `repository.py` |
| Schemas    | Input/output validation (Pydantic)    | `schemas.py`    |
| Models     | Table definitions (SQLAlchemy)        | `models.py`     |
| Config     | Settings from environment             | `config.py`     |
| Errors     | Domain exceptions                     | `errors.py`     |
| Database   | Engine, session factory               | `database.py`   |
