---
name: architecture
description: >
  Clean Architecture and feature-based structure for any language or framework.
  Trigger: When designing feature structure, defining modules, reviewing layer dependencies, or organizing code.
globs:
  - "src/**"
  - "app/**"
  - "internal/**"
  - "pkg/**"
  - "lib/**"
metadata:
  author: team-ai-kit
  version: "1.0"
---

## When to Use

Load this skill when:

- Designing or reviewing the structure of a feature or module
- Analyzing dependencies between layers (UI → Domain → Data)
- Detecting or fixing cross-feature imports
- Deciding where a new component, service, handler, or adapter belongs
- Setting up a new project or microservice structure

---

## Critical Patterns

### Pattern 1: Scope Rule — Global vs Local

A component/function is **global** if used by 2+ features.
A component/function is **local** if used by 1 feature only.

```
shared/              ← global (used by 2+ features)
  utils/
  contracts/

features/
  auth/              ← local to auth
    handlers/
    services/
    repository/
  checkout/          ← local to checkout
    handlers/
    services/
    repository/
```

### Pattern 2: No Cross-Feature Imports

Features must NEVER import directly from other features.

```typescript
// ❌ BAD — auth imports directly from dashboard
import { DashboardLayout } from "../dashboard/components/DashboardLayout";

// ✅ GOOD — use shared module or communicate via contracts
import { DashboardLayout } from "../../shared/layouts/DashboardLayout";
```

```python
# ❌ BAD — orders imports directly from users feature
from features.users.services import get_user_profile

# ✅ GOOD — use shared contract or dependency injection
from shared.contracts import UserService
```

```java
// ❌ BAD — checkout package imports from inventory internals
import com.app.features.inventory.internal.StockCalculator;

// ✅ GOOD — depend on the public API of inventory
import com.app.features.inventory.api.InventoryService;
```

```go
// ❌ BAD — orders package imports billing internals
import "myapp/features/billing/internal/calculator"

// ✅ GOOD — import the public package
import "myapp/features/billing"
```

### Pattern 3: Screaming Architecture — Structure Reveals Intent

The folder structure should scream what the application DOES, not what framework it uses.

```
# ❌ BAD — screams "framework"
controllers/
models/
views/
helpers/

# ✅ GOOD — screams "business domain"
features/
  checkout/
    handlers/
    services/
    repository/
    models/
  auth/
    handlers/
    services/
    repository/
    models/
```

### Pattern 4: Layers and Dependency Direction

```
UI / Handlers Layer  →  Domain Layer  →  Data Layer
  controllers/           services/        repositories/
  handlers/              entities/        adapters/
  views/                 use_cases/       gateways/

Rule: Outer layers depend on inner layers. NEVER the reverse.
Domain layer knows NOTHING about UI, HTTP, databases, or frameworks.
```

```python
# ❌ BAD — domain layer depends on Flask (framework)
class OrderService:
    def create_order(self, request: flask.Request):
        ...

# ✅ GOOD — domain layer uses plain data structures
class OrderService:
    def create_order(self, items: list[OrderItem], customer_id: str) -> Order:
        ...
```

```java
// ❌ BAD — domain depends on Spring annotations
public class InvoiceService {
    @Autowired private JdbcTemplate db;
    public Invoice create(HttpServletRequest req) { ... }
}

// ✅ GOOD — domain depends on abstractions only
public class InvoiceService {
    private final InvoiceRepository repository;
    public InvoiceService(InvoiceRepository repository) {
        this.repository = repository;
    }
    public Invoice create(CreateInvoiceCommand cmd) { ... }
}
```

### Pattern 5: Barrel Exports — Public API per Feature

Each feature exposes a public API. Internal details are hidden.

```typescript
// features/auth/index.ts
export { LoginForm } from "./components/LoginForm";
export { useAuth } from "./hooks/useAuth";
export type { AuthUser } from "./types";
// Do NOT export internal implementations
```

```python
# features/auth/__init__.py
from .services import AuthService
from .models import AuthUser
# Do NOT expose internal repository implementations
```

```go
// features/auth/auth.go — exported functions are the public API
package auth

func NewService(repo UserRepository) *Service { ... }
func (s *Service) Authenticate(email, password string) (*User, error) { ... }
// unexported helpers stay private automatically
```

### Pattern 6: Clean Adapter Pattern

Adapters implement contracts defined by the domain. The domain never knows the concrete implementation.

```typescript
// core/contracts/storage.contract.ts
export interface StorageAdapter {
  get(key: string): Promise<string | null>;
  set(key: string, value: string): Promise<void>;
}

// adapters/redis-storage.ts
export class RedisStorageAdapter implements StorageAdapter {
  constructor(private readonly client: RedisClient) {}
  async get(key: string): Promise<string | null> {
    return this.client.get(key);
  }
  async set(key: string, value: string): Promise<void> {
    await this.client.set(key, value);
  }
}
```

```python
# core/contracts.py
from abc import ABC, abstractmethod

class StorageAdapter(ABC):
    @abstractmethod
    def get(self, key: str) -> str | None: ...
    @abstractmethod
    def set(self, key: str, value: str) -> None: ...

# adapters/redis_storage.py
class RedisStorageAdapter(StorageAdapter):
    def __init__(self, client):
        self._client = client
    def get(self, key: str) -> str | None:
        return self._client.get(key)
    def set(self, key: str, value: str) -> None:
        self._client.set(key, value)
```

```go
// core/contracts.go
type StorageAdapter interface {
    Get(key string) (string, error)
    Set(key string, value string) error
}

// adapters/redis.go
type RedisStorage struct {
    client *redis.Client
}

func (r *RedisStorage) Get(key string) (string, error) {
    return r.client.Get(ctx, key).Result()
}

func (r *RedisStorage) Set(key string, value string) error {
    return r.client.Set(ctx, key, value, 0).Err()
}
```

---

## Anti-Patterns

### Don't: Business Logic in UI/Handler Layer

```typescript
// ❌ BAD — discount calculation in a UI component
function ProductCard({ product }) {
  const discount = product.price * 0.15; // business logic here
  return <div>{discount}</div>;
}

// ✅ GOOD — UI only presents
function ProductCard({ product }) {
  return <div>{product.discountedPrice}</div>;
}
```

```python
# ❌ BAD — business logic in HTTP handler
@app.route("/orders", methods=["POST"])
def create_order():
    total = sum(item["price"] * item["qty"] for item in request.json["items"])
    tax = total * 0.21
    # ... 50 more lines of business logic
    return jsonify({"total": total + tax})

# ✅ GOOD — handler delegates to domain service
@app.route("/orders", methods=["POST"])
def create_order():
    cmd = CreateOrderCommand.from_dict(request.json)
    order = order_service.create(cmd)
    return jsonify(order.to_dict())
```

### Don't: Framework Lock-in in Domain

```java
// ❌ BAD — domain entity tied to JPA
@Entity @Table(name = "users")
public class User {
    @Id @GeneratedValue private Long id;
    @Column private String name;
}

// ✅ GOOD — plain domain entity + separate persistence mapping
public class User {
    private final String id;
    private final String name;
    public User(String id, String name) { ... }
}
// JPA mapping lives in the data layer, not in domain
```

### Don't: God Modules

```
# ❌ BAD — one file/module does everything
utils.py (2000 lines: auth, email, payments, formatting, logging)

# ✅ GOOD — cohesive, focused modules
auth/service.py
email/sender.py
payments/gateway.py
formatting/currency.py
```

---

## Quick Reference

| Question                                 | Rule                                                |
| ---------------------------------------- | --------------------------------------------------- |
| Does this belong in shared/ or features/? | 1 feature → local; 2+ features → shared            |
| Can I import from another feature?       | No — use shared/ or communicate via contracts       |
| Where does business logic go?            | In services/ or domain/ — NEVER in handlers or UI   |
| What should a barrel export expose?      | Only the public API — never internal implementations |
| Can domain depend on a framework?        | No — domain depends only on abstractions            |
| When to create an abstraction?           | After 2+ concrete use cases — not before            |
