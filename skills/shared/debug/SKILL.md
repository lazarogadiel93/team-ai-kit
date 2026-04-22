---
name: debug
description: >
  Systematic debugging workflow: diagnose, isolate, fix, and verify. Language-agnostic.
  Trigger: When diagnosing errors, exceptions, unexpected behavior, or failing tests.
globs:
  - "**/*.test.*"
  - "**/*_test.*"
  - "**/*Test.*"
  - "**/*.spec.*"
  - "**/*.log"
metadata:
  author: team-ai-kit
  version: "1.0"
---

## When to Use

Load this skill when:

- A runtime error or test failure occurs
- System behavior is unexpected or inconsistent
- You need to isolate the root cause before proposing a fix
- A test fails and the reason is not immediately clear
- Debugging production issues with limited information

---

## Critical Patterns

### Pattern 1: Reproduce Before You Fix

Before changing ANY code, **reproduce the error in isolation**:

1. Does the error happen consistently or intermittently?
2. What input triggers it?
3. What environment/runtime/dependency version is active?
4. Can you write a failing test that demonstrates it?

```python
# ✅ GOOD — write a failing test FIRST
def test_order_total_with_negative_discount():
    """Reproduces bug #342: negative discount causes overflow"""
    order = Order(items=[Item(price=100, qty=1)], discount=-50)
    # This should raise, but currently returns 150 (the bug)
    with pytest.raises(ValueError, match="Discount cannot be negative"):
        order.calculate_total()
```

```go
// ✅ GOOD — failing test first
func TestParseDate_InvalidFormat(t *testing.T) {
    // Reproduces: panic on malformed date string
    _, err := ParseDate("not-a-date")
    if err == nil {
        t.Fatal("expected error for invalid date format")
    }
}
```

### Pattern 2: Systematic Narrowing

```
Observed error
    └── Which layer? (UI / Domain / Data / Infrastructure)
            └── Which function exactly? (stack trace)
                    └── With what input? (log parameters)
                            └── Root cause identified
```

#### Binary Search Debugging

When you can't find the source, use binary search:

1. Find the last known good state (commit, input, config)
2. Find the first known bad state
3. Bisect between them

```bash
# Git bisect is your friend
git bisect start
git bisect bad HEAD
git bisect good v1.2.0
# Git will checkout midpoints — test each one
```

### Pattern 3: Minimal Fix — No Refactoring During Debug

```
❌ BAD: "While I'm debugging, let me also refactor this module"

✅ GOOD:
  1. Minimal fix that resolves the bug
  2. Test that verifies the fix
  3. Commit the fix
  4. Refactor in a separate PR if needed
```

### Pattern 4: Read the Error Message — All of It

```
❌ BAD: "I got a NullPointerException" → immediately starts guessing

✅ GOOD: Read the FULL stack trace:
  - Which line exactly?
  - What was null?
  - What called the method?
  - Is there a "Caused by" further down the trace?
```

### Pattern 5: Check the Boundaries First

Most bugs live at boundaries: between modules, between systems, between data formats.

```typescript
// ❌ BAD — debugging deep inside the algorithm
// when the real bug is in the INPUT

// ✅ GOOD — log/validate inputs at the boundary first
function processOrder(raw: unknown): OrderResult {
  console.log("[processOrder] input:", JSON.stringify(raw));
  const order = OrderSchema.parse(raw); // fails HERE → input is wrong
  return calculateResult(order);
}
```

```python
# ✅ GOOD — validate at the boundary
def handle_webhook(payload: dict) -> None:
    logger.debug("Webhook payload: %s", payload)
    # Validate first — most bugs are bad input
    event = WebhookEvent.model_validate(payload)
    process_event(event)
```

---

## Code Examples

### Type-Safe Error Handling (TypeScript)

```typescript
async function fetchData<T>(url: string, schema: ZodSchema<T>): Promise<T> {
  try {
    const response = await fetch(url);
    if (!response.ok) {
      throw new HttpError(response.status, `HTTP ${response.status}: ${url}`);
    }
    const json = await response.json();
    return schema.parse(json);
  } catch (error) {
    if (error instanceof ZodError) {
      throw new ParseError(`Response validation failed: ${error.message}`);
    }
    if (error instanceof SyntaxError) {
      throw new ParseError(`Invalid JSON response: ${error.message}`);
    }
    throw error; // re-throw unknown errors
  }
}
```

### Structured Error Handling (Python)

```python
import logging
from dataclasses import dataclass

logger = logging.getLogger(__name__)

@dataclass
class AppError(Exception):
    message: str
    context: dict
    original: Exception | None = None

def fetch_user(user_id: str) -> User:
    try:
        response = http_client.get(f"/users/{user_id}")
        response.raise_for_status()
        return User.model_validate(response.json())
    except httpx.HTTPStatusError as e:
        raise AppError(
            message=f"Failed to fetch user {user_id}",
            context={"user_id": user_id, "status": e.response.status_code},
            original=e,
        )
    except ValidationError as e:
        raise AppError(
            message=f"Invalid user data for {user_id}",
            context={"user_id": user_id, "errors": e.errors()},
            original=e,
        )
```

### Error Wrapping (Go)

```go
func GetUser(ctx context.Context, id string) (*User, error) {
    row := db.QueryRowContext(ctx, "SELECT id, name FROM users WHERE id = $1", id)
    var user User
    if err := row.Scan(&user.ID, &user.Name); err != nil {
        if errors.Is(err, sql.ErrNoRows) {
            return nil, fmt.Errorf("user %s not found: %w", id, ErrNotFound)
        }
        return nil, fmt.Errorf("querying user %s: %w", id, err)
    }
    return &user, nil
}

// Caller can check specific errors:
// if errors.Is(err, ErrNotFound) { ... }
```

### Structured Logging (Java)

```java
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class OrderService {
    private static final Logger log = LoggerFactory.getLogger(OrderService.class);

    public Order createOrder(CreateOrderRequest request) {
        log.info("Creating order for customer={} items={}",
            request.getCustomerId(), request.getItems().size());
        try {
            Order order = processOrder(request);
            log.info("Order created orderId={} total={}", order.getId(), order.getTotal());
            return order;
        } catch (InsufficientStockException e) {
            log.warn("Insufficient stock for order customer={} item={}",
                request.getCustomerId(), e.getItemId());
            throw e;
        } catch (Exception e) {
            log.error("Unexpected error creating order customer={}",
                request.getCustomerId(), e);
            throw e;
        }
    }
}
```

---

## Anti-Patterns

### Anti-Pattern 1: Swallow Errors Silently

```typescript
// ❌ BAD
try {
  await riskyOperation();
} catch {
  /* total silence */
}

// ✅ GOOD
try {
  await riskyOperation();
} catch (error) {
  logger.error("riskyOperation failed", { error });
  // decide: re-throw, fallback, or notify
}
```

```python
# ❌ BAD
try:
    process()
except Exception:
    pass

# ✅ GOOD
try:
    process()
except SpecificError as e:
    logger.warning("Process failed, using fallback", exc_info=e)
    return fallback_value
```

### Anti-Pattern 2: Log and Throw (Double Handling)

```java
// ❌ BAD — logs the error AND throws it → duplicate log entries
try {
    doSomething();
} catch (Exception e) {
    log.error("Failed", e);
    throw e; // caller will also log it
}

// ✅ GOOD — either log OR throw, not both
try {
    doSomething();
} catch (Exception e) {
    throw new ServiceException("Operation failed", e);
    // let the caller/global handler log it
}
```

### Anti-Pattern 3: Catch Generic Exceptions

```python
# ❌ BAD — catches everything including KeyboardInterrupt
try:
    process()
except Exception:
    return None

# ✅ GOOD — catch specific exceptions
try:
    process()
except (ConnectionError, TimeoutError) as e:
    logger.warning("Network issue: %s", e)
    return None
```

### Anti-Pattern 4: Use Print Debugging in Production Code

```go
// ❌ BAD — fmt.Println left in production code
func ProcessPayment(amount float64) error {
    fmt.Println("DEBUG: amount is", amount)
    // ...
}

// ✅ GOOD — use structured logging
func ProcessPayment(amount float64) error {
    log.Info("processing payment", slog.Float64("amount", amount))
    // ...
}
```

---

## Quick Reference

| Situation                          | Action                                               |
| ---------------------------------- | ---------------------------------------------------- |
| Validation error                   | Schema mismatch → check the contract/input           |
| Network error / timeout            | Verify URL, connectivity, DNS, firewall, TLS         |
| Test fails intermittently          | Race condition → check async, shared state, cleanup  |
| Error only in production           | Check env vars, feature flags, real data differences |
| Stack trace points to dependencies | Dependency version mismatch → check lockfile         |
| Error at system boundary           | Log raw input/output → validate at the edge          |
| Cannot reproduce locally           | Match environment exactly: OS, runtime, data, config |
| Null/nil pointer                   | Trace backwards: who should have set this value?     |
| Off-by-one error                   | Check loop bounds, array indices, pagination offsets |
| Memory leak                        | Check unclosed resources, growing collections, caches|
