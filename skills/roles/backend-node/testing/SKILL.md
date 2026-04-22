---
name: backend-node-testing
description: >
  Testing patterns for Node.js backends: unit tests, integration tests, mocking, test doubles, and API testing with Vitest.
  Trigger: When writing tests, mocking dependencies, testing APIs, or configuring test suites.
globs:
  - "**/*.test.ts"
  - "**/*.spec.ts"
  - "**/tests/**"
  - "**/__tests__/**"
  - "**/vitest.config.*"
metadata:
  author: team-ai-kit
  version: "1.0"
---

## When to Use

Load this skill when:

- Writing unit or integration tests for a Node.js backend
- Mocking external services, databases, or APIs
- Configuring test suites with Vitest
- Testing HTTP endpoints with Supertest
- Setting up test databases or factories
- Defining coverage strategies

---

## Critical Patterns

### Pattern 1: Test Behavior, Not Implementation

Test observable outcomes. If the implementation changes but the behavior stays the same, the test should still pass.

```typescript
// ❌ BAD — tests internal implementation details
it('should call bcrypt.hash with rounds=10', async () => {
    await userService.register(dto)
    expect(bcrypt.hash).toHaveBeenCalledWith(dto.password, 10)
})

// ✅ GOOD — tests observable behavior
it('should create user with hashed password (not plaintext)', async () => {
    const result = await userService.register(dto)
    const saved = await userRepository.findById(result.id)
    expect(saved?.password).not.toBe(dto.password)
    expect(saved?.password).toBeDefined()
})
```

```typescript
// ❌ BAD — asserting on internal method calls
it('should call logger.info twice', async () => {
    await orderService.place(orderDto)
    expect(logger.info).toHaveBeenCalledTimes(2)
})

// ✅ GOOD — assert on the result
it('should return the created order with status pending', async () => {
    const order = await orderService.place(orderDto)
    expect(order.status).toBe('pending')
    expect(order.items).toHaveLength(2)
})
```

### Pattern 2: Clear Test Doubles

Know the difference: **stub** returns data, **spy** records calls, **mock** = stub + spy with assertions.

```typescript
import { vi } from 'vitest'

// Stub — returns predefined data
const userRepository: UserRepository = {
    findById: vi.fn().mockResolvedValue({ id: '1', name: 'Test', email: 'test@test.com' }),
    findByEmail: vi.fn().mockResolvedValue(null),
    create: vi.fn().mockImplementation(async (data) => ({ id: '1', ...data })),
    update: vi.fn(),
    delete: vi.fn(),
}

// Inject stub via constructor (Dependency Injection)
const userService = new UserService(userRepository)
```

```typescript
// ❌ BAD — mocking the module you're testing
vi.mock('./user.service')

// ✅ GOOD — mock only the dependencies, test the real service
const mockRepo = { findById: vi.fn(), create: vi.fn() } as unknown as UserRepository
const service = new UserService(mockRepo)
```

### Pattern 3: Integration Tests with Supertest

Test the full HTTP layer: routing, middleware, validation, and response shape.

```typescript
import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import request from 'supertest'
import { createApp } from '../app'

describe('POST /api/users', () => {
    let app: Express

    beforeAll(async () => {
        app = await createApp({ database: 'test' })
    })

    afterAll(async () => {
        await cleanupTestDatabase()
    })

    it('should create a user and return 201', async () => {
        const response = await request(app)
            .post('/api/users')
            .send({ email: 'test@test.com', password: 'secure123', name: 'Test User' })

        expect(response.status).toBe(201)
        expect(response.body.data).toMatchObject({
            email: 'test@test.com',
            name: 'Test User',
        })
        expect(response.body.data).toHaveProperty('id')
        expect(response.body.data).not.toHaveProperty('password')
    })

    it('should return 400 for invalid email', async () => {
        const response = await request(app)
            .post('/api/users')
            .send({ email: 'not-an-email', password: 'secure123', name: 'Test' })

        expect(response.status).toBe(400)
        expect(response.body.error.code).toBe('VALIDATION_ERROR')
    })

    it('should return 409 for duplicate email', async () => {
        const payload = { email: 'dupe@test.com', password: 'secure123', name: 'Test' }
        await request(app).post('/api/users').send(payload)
        const response = await request(app).post('/api/users').send(payload)

        expect(response.status).toBe(409)
    })
})
```

### Pattern 4: Arrange-Act-Assert (AAA)

Every test follows three clear phases. Separate them with comments or blank lines.

```typescript
it('should throw NotFoundError when user does not exist', async () => {
    // Arrange
    userRepository.findById.mockResolvedValue(null)

    // Act & Assert
    await expect(userService.getById('nonexistent'))
        .rejects.toThrow(NotFoundError)
})

it('should update user name', async () => {
    // Arrange
    const existing = { id: '1', name: 'Old', email: 'a@b.com' }
    userRepository.findById.mockResolvedValue(existing)
    userRepository.update.mockResolvedValue({ ...existing, name: 'New' })

    // Act
    const result = await userService.updateName('1', 'New')

    // Assert
    expect(result.name).toBe('New')
    expect(userRepository.update).toHaveBeenCalledWith('1', { name: 'New' })
})
```

### Pattern 5: Test Database Management

Use transactions or truncation to isolate tests. Never leave dirty state.

```typescript
// ❌ BAD — leaves dirty data, tests leak into each other
it('creates user', async () => {
    await db.users.create({ email: 'test@test.com', name: 'Test', password: 'hashed' })
    // no cleanup — affects other tests
})

// ✅ GOOD — transaction rollback strategy
import { beforeEach } from 'vitest'

let tx: PrismaClient

beforeEach(async () => {
    // Start a transaction that will be rolled back
    tx = await startTestTransaction()
})

afterEach(async () => {
    await rollbackTestTransaction(tx)
})

// ✅ GOOD — truncate between tests
beforeEach(async () => {
    await db.$executeRaw`TRUNCATE TABLE users, orders, products CASCADE`
})
```

```typescript
// Helper for test transaction isolation
export async function withTestTransaction<T>(
    prisma: PrismaClient,
    fn: (tx: PrismaClient) => Promise<T>,
): Promise<void> {
    try {
        await prisma.$transaction(async (tx) => {
            await fn(tx as PrismaClient)
            throw new Error('__ROLLBACK__')
        })
    } catch (e) {
        if ((e as Error).message !== '__ROLLBACK__') throw e
    }
}
```

### Pattern 6: Factory Pattern for Test Data

Use factories to generate realistic test data without boilerplate. [fishery](https://github.com/thoughtbot/fishery) is a great library for this.

```typescript
import { Factory } from 'fishery'

// Define a factory
const userFactory = Factory.define<User>(({ sequence }) => ({
    id: `user-${sequence}`,
    email: `user${sequence}@test.com`,
    name: `Test User ${sequence}`,
    password: 'hashed-password',
    createdAt: new Date(),
    role: 'user',
}))

// Usage in tests
it('should list only active users', async () => {
    // Arrange — readable, minimal boilerplate
    const active = userFactory.build({ role: 'user' })
    const admin = userFactory.build({ role: 'admin' })
    userRepository.findAll.mockResolvedValue([active, admin])

    // Act
    const result = await userService.listByRole('user')

    // Assert
    expect(result).toHaveLength(1)
    expect(result[0].id).toBe(active.id)
})

// Build multiple
const users = userFactory.buildList(5)

// Build with traits (if using fishery transient params)
const userWithOrders = userFactory.build({ role: 'premium' })
```

```typescript
// ❌ BAD — inline object literals everywhere
it('test 1', async () => {
    const user = { id: '1', email: 'a@b.com', name: 'Test', password: 'x', createdAt: new Date(), role: 'user' }
    // ...
})
it('test 2', async () => {
    const user = { id: '2', email: 'b@c.com', name: 'Test2', password: 'x', createdAt: new Date(), role: 'admin' }
    // ...
})

// ✅ GOOD — factories keep tests focused on what matters
it('test 1', async () => {
    const user = userFactory.build()
    // ...
})
it('test 2', async () => {
    const admin = userFactory.build({ role: 'admin' })
    // ...
})
```

### Pattern 7: Snapshot Testing for API Responses

Use snapshots to catch unexpected changes in response shape. Update snapshots intentionally.

```typescript
it('should return user profile in expected shape', async () => {
    const response = await request(app)
        .get('/api/users/1')
        .set('Authorization', `Bearer ${token}`)

    expect(response.status).toBe(200)
    // Snapshot catches any accidental shape changes
    expect(response.body).toMatchSnapshot()
})

// For dynamic fields, use inline snapshots with matchers
it('should return created user with dynamic fields', async () => {
    const response = await request(app)
        .post('/api/users')
        .send(validPayload)

    expect(response.body.data).toMatchObject({
        id: expect.any(String),
        email: 'test@test.com',
        name: 'Test',
        createdAt: expect.any(String),
    })
})
```

```typescript
// ❌ BAD — snapshot includes timestamps and IDs that always change
expect(response.body).toMatchSnapshot()
// This snapshot will break on every run

// ✅ GOOD — mask dynamic fields
expect(response.body).toMatchSnapshot({
    data: {
        id: expect.any(String),
        createdAt: expect.any(String),
        updatedAt: expect.any(String),
    },
})
```

### Pattern 8: Test Coverage Strategy

Don't chase 100%. Cover the right things.

```typescript
// vitest.config.ts
export default defineConfig({
    test: {
        coverage: {
            provider: 'v8',
            include: ['src/**/*.ts'],
            exclude: [
                'src/**/*.d.ts',
                'src/**/*.test.ts',
                'src/**/index.ts',        // barrel files
                'src/generated/**',        // auto-generated code
            ],
            thresholds: {
                statements: 80,
                branches: 75,
                functions: 80,
                lines: 80,
            },
        },
    },
})
```

**What to prioritize:**

| Priority | What to test                         | Why                              |
| -------- | ------------------------------------ | -------------------------------- |
| High     | Business logic in services           | Core value, most bugs live here  |
| High     | Validation schemas                   | Prevents bad data entering system|
| Medium   | API endpoints (integration)          | Verifies the full HTTP contract  |
| Medium   | Error paths and edge cases           | Most overlooked, most impactful  |
| Low      | Simple CRUD repositories             | Low logic, high maintenance cost |
| Low      | DTOs and type mappings               | TypeScript already validates     |

### Pattern 9: Contract Testing Basics

Verify your API honors its contract. Useful when multiple consumers depend on response shape.

```typescript
import { describe, it, expect } from 'vitest'

// Define the contract — what consumers expect
const UserResponseContract = z.object({
    data: z.object({
        id: z.string(),
        email: z.string().email(),
        name: z.string(),
        createdAt: z.string().datetime(),
    }),
})

describe('User API Contract', () => {
    it('GET /api/users/:id should match the contract', async () => {
        const response = await request(app)
            .get('/api/users/1')
            .set('Authorization', `Bearer ${token}`)

        expect(response.status).toBe(200)

        // If this fails, you're breaking a consumer contract
        const parsed = UserResponseContract.safeParse(response.body)
        expect(parsed.success).toBe(true)
    })

    it('LIST /api/users should return array matching contract', async () => {
        const response = await request(app).get('/api/users')

        const ListContract = z.object({
            data: z.array(UserResponseContract.shape.data),
            meta: z.object({ page: z.number(), total: z.number() }),
        })

        expect(ListContract.safeParse(response.body).success).toBe(true)
    })
})
```

---

## Anti-Patterns

### Anti-Pattern 1: Test Everything Through the HTTP Layer

```typescript
// ❌ BAD — testing business logic via HTTP (slow, brittle)
it('should reject password shorter than 8 chars', async () => {
    const res = await request(app).post('/api/users').send({ ...dto, password: '123' })
    expect(res.status).toBe(400)
})

// ✅ GOOD — test the schema directly (fast, focused)
it('should reject password shorter than 8 chars', () => {
    const result = CreateUserSchema.safeParse({ ...dto, password: '123' })
    expect(result.success).toBe(false)
})
```

### Anti-Pattern 2: Share Mutable State Across Tests

```typescript
// ❌ BAD — shared mutable state causes flaky tests
let sharedUser: User

beforeAll(async () => {
    sharedUser = await createUser()
})

it('test 1 modifies shared user', async () => {
    await userService.updateName(sharedUser.id, 'Changed')
})

it('test 2 depends on original name — FLAKY', async () => {
    const user = await userService.getById(sharedUser.id)
    expect(user.name).toBe('Original') // fails because test 1 mutated it
})

// ✅ GOOD — each test creates its own data
it('test 1', async () => {
    const user = userFactory.build()
    // ...
})
it('test 2', async () => {
    const user = userFactory.build()
    // ...
})
```

### Anti-Pattern 3: Skip Error Path Tests

```typescript
// ❌ BAD — only testing the happy path
describe('UserService', () => {
    it('should create user', async () => { /* ... */ })
    it('should get user', async () => { /* ... */ })
})

// ✅ GOOD — also test failure cases
describe('UserService', () => {
    it('should create user', async () => { /* ... */ })
    it('should throw ConflictError for duplicate email', async () => { /* ... */ })
    it('should throw NotFoundError for missing user', async () => { /* ... */ })
    it('should throw ForbiddenError when non-admin updates role', async () => { /* ... */ })
})
```

---

## Quick Reference

| Test Type    | What It Tests                    | Speed  | Mocks            |
| ------------ | -------------------------------- | ------ | ---------------- |
| Unit         | Single function/class in isolation | Fast  | All dependencies |
| Integration  | Full endpoint with real DB        | Medium | Only externals   |
| Contract     | Response shape matches spec       | Fast   | Depends          |
| E2E          | Complete user flow                | Slow   | Nothing          |

| Tool        | Purpose                                      |
| ----------- | -------------------------------------------- |
| Vitest      | Test runner, assertions, mocking             |
| Supertest   | HTTP assertions for Express/Fastify          |
| fishery     | Test data factories                          |
| @faker-js   | Realistic fake data generation               |
| v8 coverage | Built-in Vitest coverage provider            |
