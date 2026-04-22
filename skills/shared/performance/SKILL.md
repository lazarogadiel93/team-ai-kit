---
name: performance
description: >
  Performance analysis and optimization patterns: profiling, caching, query optimization, and resource management.
  Trigger: When optimizing response times, reducing resource usage, fixing N+1 queries, or analyzing bottlenecks.
globs:
  - "src/**"
  - "app/**"
  - "internal/**"
  - "**/*.sql"
metadata:
  author: team-ai-kit
  version: "1.0"
---

## When to Use

Load this skill when:

- API response time is too high
- Database queries are slow or excessive
- Memory or CPU usage is abnormally high
- Bundle size is larger than expected (frontend)
- UI renders are slow or janky (frontend)
- You need to decide on a caching strategy
- System doesn't scale under load

---

## Critical Patterns

### Pattern 1: Measure Before You Optimize

```
Hypothesis → Measure → Identify bottleneck → Optimize → Verify improvement

❌ BAD: Optimize without data — guessing where the problem is
✅ GOOD: Profile first, optimize the REAL bottleneck
```

**Profiling tools by context:**

| Context         | Tools                                                    |
| --------------- | -------------------------------------------------------- |
| SQL queries     | `EXPLAIN ANALYZE`, query logs, slow query log            |
| Python          | `cProfile`, `py-spy`, `memory_profiler`                  |
| Go              | `pprof` (CPU, memory, goroutines, mutex)                 |
| Java/.NET       | JProfiler, dotTrace, VisualVM, `async-profiler`          |
| Node.js         | `--prof`, `clinic.js`, Chrome DevTools                   |
| Frontend        | Lighthouse, Chrome DevTools Performance tab              |
| HTTP APIs       | `k6`, `wrk`, `ab`, `vegeta`                              |

### Pattern 2: Fix N+1 Queries

The single most common backend performance problem.

```python
# ❌ BAD — N+1: 1 query for orders + N queries for users
orders = Order.objects.all()
for order in orders:
    print(order.user.name)  # each access triggers a separate query

# ✅ GOOD — eager loading: 2 queries total
orders = Order.objects.select_related("user").all()
for order in orders:
    print(order.user.name)  # already loaded
```

```java
// ❌ BAD — N+1 with JPA
List<Order> orders = orderRepository.findAll();
for (Order order : orders) {
    order.getUser().getName(); // lazy load → N extra queries
}

// ✅ GOOD — fetch join
@Query("SELECT o FROM Order o JOIN FETCH o.user")
List<Order> findAllWithUsers();
```

```typescript
// ❌ BAD — N+1 in a GraphQL resolver or API handler
const orders = await db.query("SELECT * FROM orders");
for (const order of orders) {
  order.user = await db.query("SELECT * FROM users WHERE id = $1", [order.userId]);
}

// ✅ GOOD — batch load with a single query or DataLoader
const orders = await db.query(`
  SELECT o.*, u.name as user_name
  FROM orders o
  JOIN users u ON u.id = o.user_id
`);
```

### Pattern 3: Caching Strategy

Cache the RIGHT thing at the RIGHT level.

```
Level 1: Application memory (fastest, process-local, lost on restart)
Level 2: Distributed cache — Redis/Memcached (shared across instances)
Level 3: CDN / HTTP cache (edge, for static or semi-static content)
Level 4: Database query cache (usually last resort)
```

```python
# ✅ GOOD — cache expensive computation (note: lru_cache has no TTL — use cachetools.TTLCache if expiry is needed)
from functools import lru_cache
import time

@lru_cache(maxsize=256)
def get_exchange_rate(currency: str) -> Decimal:
    return external_api.fetch_rate(currency)

# ✅ GOOD — Redis cache for shared state across instances
async def get_user_profile(user_id: str) -> UserProfile:
    cached = await redis.get(f"user:{user_id}")
    if cached:
        return UserProfile.model_validate_json(cached)
    profile = await db.fetch_user_profile(user_id)
    await redis.setex(f"user:{user_id}", 300, profile.model_dump_json())  # 5 min TTL
    return profile
```

```go
// ✅ GOOD — in-memory cache with expiration
type Cache struct {
    mu    sync.RWMutex
    items map[string]cacheEntry
}

type cacheEntry struct {
    value     interface{}
    expiresAt time.Time
}

func (c *Cache) Get(key string) (interface{}, bool) {
    c.mu.RLock()
    defer c.mu.RUnlock()
    entry, ok := c.items[key]
    if !ok || time.Now().After(entry.expiresAt) {
        return nil, false
    }
    return entry.value, true
}
```

**Cache invalidation rules:**
- Use TTL (time-to-live) as the default strategy
- Event-based invalidation for write-heavy data
- NEVER cache without an expiration unless you have an explicit invalidation path

### Pattern 4: Connection Pooling

```python
# ❌ BAD — new connection per request
def get_user(user_id: str):
    conn = psycopg2.connect(DATABASE_URL)  # expensive!
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))
    return cursor.fetchone()

# ✅ GOOD — connection pool
from psycopg2.pool import ThreadedConnectionPool

pool = ThreadedConnectionPool(minconn=5, maxconn=20, dsn=DATABASE_URL)

def get_user(user_id: str):
    conn = pool.getconn()
    try:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))
        return cursor.fetchone()
    finally:
        pool.putconn(conn)
```

```yaml
# ✅ GOOD — HikariCP connection pool (Spring Boot application.yml)
spring:
  datasource:
    hikari:
      maximum-pool-size: 20
      minimum-idle: 5
      connection-timeout: 30000
```

### Pattern 5: Database Query Optimization

```sql
-- ❌ BAD — full table scan
SELECT * FROM orders WHERE YEAR(created_at) = 2024;

-- ✅ GOOD — index-friendly range query
SELECT * FROM orders
WHERE created_at >= '2024-01-01' AND created_at < '2025-01-01';

-- ❌ BAD — SELECT * when you only need 2 columns
SELECT * FROM users;

-- ✅ GOOD — select only what you need
SELECT id, email FROM users;

-- ✅ GOOD — add indexes for frequent queries
CREATE INDEX idx_orders_customer_date ON orders (customer_id, created_at);
```

**Index rules of thumb:**
- Index columns used in WHERE, JOIN ON, and ORDER BY
- Composite indexes: put high-cardinality columns first
- Don't over-index: each index slows down writes
- Use `EXPLAIN ANALYZE` to verify the index is actually used

### Pattern 6: Pagination — Never Load Everything

```python
# ❌ BAD — loads ALL records into memory
def get_all_users():
    return User.objects.all()  # 10 million rows? enjoy your OOM

# ✅ GOOD — cursor-based pagination
def get_users(after_id: str | None = None, limit: int = 50) -> list[User]:
    query = User.objects.order_by("id")
    if after_id:
        query = query.filter(id__gt=after_id)
    return list(query[:limit])
```

```go
// ✅ GOOD — keyset pagination
func GetUsers(ctx context.Context, afterID string, limit int) ([]User, error) {
    query := "SELECT id, name FROM users WHERE id > $1 ORDER BY id LIMIT $2"
    rows, err := db.QueryContext(ctx, query, afterID, limit)
    // ...
}
```

### Pattern 7: Async and Concurrency

```python
# ❌ BAD — sequential HTTP calls (3 seconds total)
user = await fetch_user(user_id)        # 1s
orders = await fetch_orders(user_id)    # 1s
profile = await fetch_profile(user_id)  # 1s

# ✅ GOOD — parallel calls (1 second total)
user, orders, profile = await asyncio.gather(
    fetch_user(user_id),
    fetch_orders(user_id),
    fetch_profile(user_id),
)
```

```go
// ✅ GOOD — parallel with errgroup
g, ctx := errgroup.WithContext(ctx)
var user *User
var orders []Order

g.Go(func() error {
    var err error
    user, err = fetchUser(ctx, userID)
    return err
})
g.Go(func() error {
    var err error
    orders, err = fetchOrders(ctx, userID)
    return err
})

if err := g.Wait(); err != nil {
    return err
}
```

```typescript
// ❌ BAD — sequential awaits
const user = await fetchUser(userId);
const orders = await fetchOrders(userId);
const profile = await fetchProfile(userId);

// ✅ GOOD — parallel
const [user, orders, profile] = await Promise.all([
  fetchUser(userId),
  fetchOrders(userId),
  fetchProfile(userId),
]);
```

---

## Anti-Patterns

### Anti-Pattern 1: Premature Optimization

```
❌ BAD: "Let me add Redis caching to every endpoint just in case"
✅ GOOD: Profile → find the actual bottleneck → cache only what's slow
```

### Anti-Pattern 2: Load Entire Datasets Into Memory

```java
// ❌ BAD — loads everything
List<Transaction> all = transactionRepo.findAll(); // 5M rows → OutOfMemoryError

// ✅ GOOD — stream or paginate
try (Stream<Transaction> stream = transactionRepo.streamAll()) {
    stream.filter(t -> t.getAmount() > 1000)
          .forEach(this::processTransaction);
}
```

### Anti-Pattern 3: Ignore Resource Cleanup

```go
// ❌ BAD — response body never closed → connection leak
resp, _ := http.Get(url)
body, _ := io.ReadAll(resp.Body)

// ✅ GOOD — always close resources
resp, err := http.Get(url)
if err != nil { return err }
defer resp.Body.Close()
body, err := io.ReadAll(resp.Body)
```

```python
# ❌ BAD — file never closed
data = open("large.csv").read()

# ✅ GOOD — context manager ensures cleanup
with open("large.csv") as f:
    data = f.read()
```

### Anti-Pattern 4: Cache Without Invalidation Strategy

```
❌ BAD: cache.set("user:123", user_data)  // no TTL, no invalidation → stale forever

✅ GOOD: cache.setex("user:123", 300, user_data)  // 5 min TTL
         # AND invalidate on write:
         # on user update → cache.delete("user:123")
```

---

## Quick Reference

| Problem                   | Tool / Approach                                     |
| ------------------------- | --------------------------------------------------- |
| Slow API response         | Profile → check queries, N+1, missing indexes       |
| High memory usage         | Check unclosed resources, large collections, caching |
| Slow database queries     | `EXPLAIN ANALYZE` → add indexes, fix N+1            |
| High CPU usage            | CPU profiler → find hot paths                       |
| Large frontend bundle     | Bundle analyzer → code split, lazy load, tree shake |
| Slow UI rendering         | Performance profiler → reduce re-renders, virtualize |
| Too many HTTP calls       | Batch requests, use DataLoader pattern, parallelize  |
| Connection exhaustion     | Connection pooling, check for leaks                 |
| Doesn't scale under load  | Load test → identify bottleneck → horizontal/vertical|
