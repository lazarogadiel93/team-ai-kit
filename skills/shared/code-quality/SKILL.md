---
name: code-quality
description: >
  Code quality patterns: naming, pure functions, type safety, contracts, and conventions for any language.
  Trigger: When writing or reviewing code, during code review, refactoring, or defining conventions.
globs:
  - "src/**"
  - "app/**"
  - "internal/**"
  - "pkg/**"
  - "lib/**"
  - "**/*.ts"
  - "**/*.py"
  - "**/*.java"
  - "**/*.go"
  - "**/*.cs"
metadata:
  author: team-ai-kit
  version: "1.0"
---

## When to Use

Load this skill when:

- Writing or reviewing code in any language
- Doing code review or refactoring
- Naming variables, functions, classes, or modules
- Identifying hidden side effects
- Defining or enforcing coding conventions

---

## Critical Patterns

### Pattern 1: Names That Document

Names should reveal intent. If a name requires a comment, the name is wrong.

```typescript
// ❌ BAD
const d = new Date();
const fn = (x: string) => x.split(" ");
function doStuff(data: any) { ... }

// ✅ GOOD
const createdAt = new Date();
const splitBySpace = (text: string) => text.split(" ");
function parseUserInput(rawInput: string): ParsedInput { ... }
```

```python
# ❌ BAD
def proc(d, f):
    return [f(x) for x in d if x]

# ✅ GOOD
def filter_and_transform(items: list[Item], transform: Callable[[Item], Result]) -> list[Result]:
    return [transform(item) for item in items if item.is_active]
```

```java
// ❌ BAD
List<String> list1 = getList();
void handle(Object o) { ... }

// ✅ GOOD
List<String> activeUserEmails = getActiveUserEmails();
void processPayment(PaymentRequest request) { ... }
```

```go
// ❌ BAD
func do(s string) string { ... }

// ✅ GOOD
func sanitizeHTML(raw string) string { ... }
```

### Pattern 2: No Untyped Data — Explicit Types Always

Every language has a way to express types or contracts. Use them.

```typescript
// ❌ BAD
function processData(data: any): any { ... }

// ✅ GOOD
function processData(data: UserInput): ProcessedResult { ... }

// ✅ When type is unknown at compile time, use guards
function processData(data: unknown): ProcessedResult {
  if (!isUserInput(data)) throw new TypeError("Invalid input");
  // TypeScript now knows it's UserInput
}
```

```python
# ❌ BAD
def calculate_total(items):
    return sum(i["price"] for i in items)

# ✅ GOOD
def calculate_total(items: list[LineItem]) -> Decimal:
    return sum(item.price for item in items)
```

```java
// ❌ BAD
public Object process(Map data) { ... }

// ✅ GOOD
public InvoiceResult process(InvoiceRequest request) { ... }
```

```go
// ❌ BAD
func process(data interface{}) interface{} { ... }

// ✅ GOOD
func process(data InvoiceRequest) (InvoiceResult, error) { ... }
```

### Pattern 3: Small, Pure Functions

A function does ONE thing. No hidden side effects. Easy to test.

```typescript
// ❌ BAD — does 3 things: validates, transforms, and saves
function handleUserData(raw: string) {
  const valid = raw.length > 0;
  const user = JSON.parse(raw);
  db.save(user);
}

// ✅ GOOD — separated and testable
function isValidInput(raw: string): boolean {
  return raw.length > 0;
}
function parseUser(raw: string): User {
  return JSON.parse(raw);
}
async function saveUser(user: User): Promise<void> {
  await db.save(user);
}
```

```python
# ❌ BAD — validates, parses, emails, and logs all in one
def register_user(form_data):
    if not form_data.get("email"):
        raise ValueError("no email")
    user = User(email=form_data["email"], name=form_data["name"])
    db.session.add(user)
    db.session.commit()
    send_welcome_email(user.email)
    logger.info(f"User {user.id} registered")
    return user

# ✅ GOOD — each step is a separate, testable function
def validate_registration(form_data: dict) -> RegistrationInput:
    ...

def create_user(input: RegistrationInput) -> User:
    ...

def send_welcome_email(email: str) -> None:
    ...
```

```go
// ❌ BAD — does validation + business logic + persistence
func CreateOrder(w http.ResponseWriter, r *http.Request) {
    var req OrderRequest
    json.NewDecoder(r.Body).Decode(&req)
    if req.Total <= 0 { http.Error(w, "bad total", 400); return }
    tax := req.Total * 0.21
    db.Exec("INSERT INTO orders ...")
    json.NewEncoder(w).Encode(map[string]float64{"total": req.Total + tax})
}

// ✅ GOOD — handler delegates to focused functions
func (h *OrderHandler) Create(w http.ResponseWriter, r *http.Request) {
    req, err := decodeOrderRequest(r)
    if err != nil { respondError(w, http.StatusBadRequest, err); return }
    order, err := h.service.CreateOrder(req)
    if err != nil { respondError(w, http.StatusInternalServerError, err); return }
    respondJSON(w, http.StatusCreated, order)
}
```

### Pattern 4: Contracts First — Interfaces Before Implementations

Define what you need BEFORE deciding how to build it.

```typescript
// First the contract
export interface StorageAdapter {
  get(key: string): Promise<string | null>;
  set(key: string, value: string): Promise<void>;
}

// Then the implementation
export class LocalStorageAdapter implements StorageAdapter {
  async get(key: string): Promise<string | null> { ... }
  async set(key: string, value: string): Promise<void> { ... }
}
```

```python
# First the contract
from abc import ABC, abstractmethod

class NotificationSender(ABC):
    @abstractmethod
    def send(self, recipient: str, message: str) -> None: ...

# Then the implementation
class EmailSender(NotificationSender):
    def send(self, recipient: str, message: str) -> None:
        self._smtp_client.send_email(to=recipient, body=message)
```

```java
// First the contract
public interface PaymentGateway {
    PaymentResult charge(Money amount, PaymentMethod method);
}

// Then the implementation
public class StripeGateway implements PaymentGateway {
    @Override
    public PaymentResult charge(Money amount, PaymentMethod method) { ... }
}
```

```go
// First the contract
type Logger interface {
    Info(msg string, fields ...Field)
    Error(msg string, err error, fields ...Field)
}

// Then the implementation
type ZapLogger struct { logger *zap.Logger }

func (z *ZapLogger) Info(msg string, fields ...Field) { ... }
func (z *ZapLogger) Error(msg string, err error, fields ...Field) { ... }
```

### Pattern 5: Guard Clauses — Early Returns Over Deep Nesting

```python
# ❌ BAD — deep nesting
def process_order(order):
    if order is not None:
        if order.is_valid():
            if order.has_items():
                return calculate_total(order)
            else:
                raise ValueError("No items")
        else:
            raise ValueError("Invalid order")
    else:
        raise ValueError("No order")

# ✅ GOOD — guard clauses with early returns
def process_order(order):
    if order is None:
        raise ValueError("No order")
    if not order.is_valid():
        raise ValueError("Invalid order")
    if not order.has_items():
        raise ValueError("No items")
    return calculate_total(order)
```

```go
// ❌ BAD
func getUser(id string) (*User, error) {
    if id != "" {
        user, err := db.Find(id)
        if err == nil {
            if user != nil {
                return user, nil
            }
        }
        return nil, err
    }
    return nil, errors.New("empty id")
}

// ✅ GOOD
func getUser(id string) (*User, error) {
    if id == "" {
        return nil, errors.New("empty id")
    }
    user, err := db.Find(id)
    if err != nil {
        return nil, fmt.Errorf("finding user %s: %w", id, err)
    }
    if user == nil {
        return nil, ErrNotFound
    }
    return user, nil
}
```

### Pattern 6: Don't Repeat Yourself — But Don't Abstract Prematurely Either

```typescript
// ❌ BAD — same validation in 3 places
if (text.length > 0 && text.trim() !== "") { ... }

// ✅ GOOD — extract once
function isNonEmpty(text: string): boolean {
  return text.length > 0 && text.trim() !== "";
}
```

```python
# ❌ BAD — premature abstraction with 1 use case
class BaseRepository(Generic[T]):
    def find_by_id(self, id: str) -> T: ...
    def find_all(self) -> list[T]: ...
    def save(self, entity: T) -> None: ...
    def delete(self, id: str) -> None: ...

# ✅ GOOD — just implement what you need now
class UserRepository:
    def find_by_email(self, email: str) -> User | None: ...
    def save(self, user: User) -> None: ...
# Extract a base class only when you have 2+ repositories with shared behavior
```

---

## Anti-Patterns

### Anti-Pattern 1: Non-null Assertions Without Context

```typescript
// ❌ BAD
const value = map.get(key)!;

// ✅ GOOD
const value = map.get(key);
if (!value) throw new Error(`Key not found: ${key}`);
```

### Anti-Pattern 2: Swallow Errors Silently

```python
# ❌ BAD
try:
    process_payment()
except Exception:
    pass  # total silence

# ✅ GOOD
try:
    process_payment()
except PaymentError as e:
    logger.error("Payment failed", exc_info=e)
    raise
```

### Anti-Pattern 3: Boolean Parameters That Change Behavior

```java
// ❌ BAD — what does `true` mean here?
generateReport(data, true, false, true);

// ✅ GOOD — use named parameters, enums, or config objects
generateReport(data, new ReportOptions(
    includeHeader: true,
    landscape: false,
    colorized: true
));
```

### Anti-Pattern 4: Magic Numbers and Strings

```go
// ❌ BAD
if retries > 3 {
    time.Sleep(5 * time.Second)
}

// ✅ GOOD
const maxRetries = 3
const retryBackoff = 5 * time.Second

if retries > maxRetries {
    time.Sleep(retryBackoff)
}
```

---

## Quick Reference

| Rule                                   | Example                                                |
| -------------------------------------- | ------------------------------------------------------ |
| No untyped data                        | Use explicit types, `unknown` + guard, or generics     |
| Descriptive names                      | `createUserSession` not `doStuff`                      |
| One function = one responsibility      | If the name has "and" → split it                       |
| Contracts before implementations       | `interface X` → `class Y implements X`                 |
| Don't repeat logic                     | Extract to a utility function                          |
| Guard clauses over deep nesting        | Early returns keep code flat and readable              |
| No magic numbers                       | Define constants with meaningful names                 |
| No boolean params that change behavior | Use enums, config objects, or separate functions       |
| Abstract after 2+ concrete cases       | Don't create `Base<T>` for a single use case           |
