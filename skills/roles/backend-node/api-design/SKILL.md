---
name: backend-node-api
description: >
  Node.js REST API design patterns: routes, controllers, middleware, validation, error handling with Express.
  Trigger: When creating endpoints, defining routes, implementing middleware, or handling HTTP errors.
globs:
  - "**/*.controller.ts"
  - "**/*.route.ts"
  - "**/*.router.ts"
  - "**/*.middleware.ts"
  - "**/routes/**"
  - "**/controllers/**"
metadata:
  author: team-ai-kit
  version: "1.0"
---

## When to Use

Load this skill when:

- Creating or modifying REST endpoints
- Implementing middleware (auth, logging, rate limiting, error handling)
- Designing the structure of controllers and routes
- Handling request/response validation
- Setting up API versioning or pagination
- Configuring CORS or security headers

---

## Critical Patterns

### Pattern 1: Thin Controllers — Logic Lives in Services

Controllers parse the request, delegate to a service, and send the response. Nothing else.

```typescript
// ❌ BAD — controller does everything
router.post('/users', async (req, res) => {
    const { email, password } = req.body
    const existing = await db.users.findByEmail(email)
    if (existing) return res.status(409).json({ error: 'Email exists' })
    const hashed = await bcrypt.hash(password, 10)
    const user = await db.users.create({ email, password: hashed })
    const token = jwt.sign({ id: user.id }, SECRET)
    res.status(201).json({ user, token })
})

// ✅ GOOD — controller delegates to service
router.post(
    '/users',
    validate(CreateUserSchema),
    asyncHandler(async (req, res) => {
        const result = await userService.register(req.body)
        res.status(201).json(result)
    }),
)
```

### Pattern 2: Edge Validation with Zod

Validate at the boundary. Never trust incoming data past the middleware layer.

```typescript
import { z } from 'zod'
import type { Request, Response, NextFunction } from 'express'

// --- Schema definition ---
export const CreateUserSchema = z.object({
    email: z.string().email(),
    password: z.string().min(8).max(128),
    name: z.string().min(2).max(100),
})

export type CreateUserDto = z.infer<typeof CreateUserSchema>

// --- Reusable validation middleware ---
export function validate<T>(schema: z.ZodSchema<T>) {
    return (req: Request, _res: Response, next: NextFunction) => {
        try {
            req.body = schema.parse(req.body)
            next()
        } catch (error) {
            next(error)
        }
    }
}

// --- Validate query params separately ---
export function validateQuery<T>(schema: z.ZodSchema<T>) {
    return (req: Request, _res: Response, next: NextFunction) => {
        try {
            req.query = schema.parse(req.query) as any
            next()
        } catch (error) {
            next(error)
        }
    }
}
```

```typescript
// ❌ BAD — manual validation scattered in handler
router.post('/users', async (req, res) => {
    if (!req.body.email) return res.status(400).json({ error: 'Email required' })
    if (!req.body.email.includes('@')) return res.status(400).json({ error: 'Invalid email' })
    if (!req.body.password || req.body.password.length < 8) return res.status(400).json({ error: 'Password too short' })
    // ... handler logic
})

// ✅ GOOD — declarative schema, single middleware
router.post('/users', validate(CreateUserSchema), asyncHandler(userController.create))
```

### Pattern 3: Centralized Error Handling

Define domain errors as classes. Handle them in ONE place.

```typescript
// errors/domain-errors.ts
export class AppError extends Error {
    constructor(
        message: string,
        public readonly statusCode: number,
        public readonly code: string,
    ) {
        super(message)
        this.name = this.constructor.name
    }
}

export class NotFoundError extends AppError {
    constructor(resource: string, id: string) {
        super(`${resource} with id ${id} not found`, 404, 'NOT_FOUND')
    }
}

export class ConflictError extends AppError {
    constructor(message: string) {
        super(message, 409, 'CONFLICT')
    }
}

export class ForbiddenError extends AppError {
    constructor(message = 'Insufficient permissions') {
        super(message, 403, 'FORBIDDEN')
    }
}

// middleware/error-handler.ts
import { ZodError } from 'zod'

export function errorHandler(err: Error, _req: Request, res: Response, _next: NextFunction) {
    if (err instanceof AppError) {
        return res.status(err.statusCode).json({
            error: { code: err.code, message: err.message },
        })
    }
    if (err instanceof ZodError) {
        return res.status(400).json({
            error: { code: 'VALIDATION_ERROR', details: err.errors },
        })
    }
    // Never leak internal errors to the client
    console.error('Unhandled error:', err)
    res.status(500).json({
        error: { code: 'INTERNAL', message: 'Internal server error' },
    })
}
```

### Pattern 4: Repository Abstracts the Database

Services depend on an interface, not a concrete ORM. This enables testing and swapping storage.

```typescript
// contracts/user.repository.ts
export interface UserRepository {
    findById(id: string): Promise<User | null>
    findByEmail(email: string): Promise<User | null>
    create(data: CreateUserDto): Promise<User>
    update(id: string, data: Partial<User>): Promise<User>
    delete(id: string): Promise<void>
}

// repositories/prisma-user.repository.ts
export class PrismaUserRepository implements UserRepository {
    constructor(private readonly prisma: PrismaClient) {}

    async findById(id: string): Promise<User | null> {
        return this.prisma.user.findUnique({ where: { id } })
    }

    async create(data: CreateUserDto): Promise<User> {
        return this.prisma.user.create({ data })
    }
    // ...
}
```

### Pattern 5: Response Envelope

Wrap all API responses in a consistent structure. Clients should never guess the shape.

```typescript
// ❌ BAD — inconsistent response shapes
res.json(user)                           // GET returns raw object
res.json({ users, total })               // LIST returns different shape
res.json({ error: 'Not found' })         // Error is a plain string

// ✅ GOOD — consistent envelope
interface ApiResponse<T> {
    data: T
    meta?: { page: number; pageSize: number; total: number }
}

interface ApiError {
    error: { code: string; message: string; details?: unknown }
}

// Helper functions
function success<T>(res: Response, data: T, status = 200) {
    return res.status(status).json({ data })
}

function paginated<T>(res: Response, data: T[], meta: PaginationMeta) {
    return res.json({ data, meta })
}
```

### Pattern 6: Middleware Composition

Compose middleware as arrays for readability and reuse.

```typescript
// ❌ BAD — long chains of inline middleware
router.post('/admin/users', authenticateToken, requireRole('admin'), rateLimit(10), validate(CreateUserSchema), handler)

// ✅ GOOD — named compositions
const adminOnly = [authenticateToken, requireRole('admin')]
const withRateLimit = (max: number) => [authenticateToken, rateLimit({ windowMs: 60_000, max })]

router.post('/admin/users', ...adminOnly, validate(CreateUserSchema), asyncHandler(userController.create))
router.get('/search', ...withRateLimit(30), asyncHandler(searchController.query))
```

### Pattern 7: Async Handler Wrapper

Eliminate repetitive try/catch in every route handler.

```typescript
// ❌ BAD — try/catch repeated in every handler
router.get('/users/:id', async (req, res, next) => {
    try {
        const user = await userService.getById(req.params.id)
        res.json({ data: user })
    } catch (error) {
        next(error)
    }
})

// ✅ GOOD — wrapper catches and forwards to error middleware
const asyncHandler = (fn: RequestHandler) =>
    (req: Request, res: Response, next: NextFunction) =>
        Promise.resolve(fn(req, res, next)).catch(next)

router.get('/users/:id', asyncHandler(async (req, res) => {
    const user = await userService.getById(req.params.id)
    res.json({ data: user })
}))
```

### Pattern 8: Pagination

Always paginate list endpoints. Never return unbounded collections.

```typescript
const PaginationSchema = z.object({
    page: z.coerce.number().int().min(1).default(1),
    pageSize: z.coerce.number().int().min(1).max(100).default(20),
})

router.get(
    '/users',
    validateQuery(PaginationSchema),
    asyncHandler(async (req, res) => {
        const { page, pageSize } = req.query as z.infer<typeof PaginationSchema>
        const { items, total } = await userService.list({ page, pageSize })
        res.json({
            data: items,
            meta: { page, pageSize, total, totalPages: Math.ceil(total / pageSize) },
        })
    }),
)
```

### Pattern 9: API Versioning

Prefix routes by version. Keep old versions working until clients migrate.

```typescript
// ❌ BAD — no versioning, breaking changes affect everyone
app.use('/api/users', userRoutes)

// ✅ GOOD — versioned routes
import { userRoutesV1 } from './v1/user.routes'
import { userRoutesV2 } from './v2/user.routes'

app.use('/api/v1/users', userRoutesV1)
app.use('/api/v2/users', userRoutesV2)

// Version via header (alternative approach)
function apiVersion(version: string) {
    return (req: Request, res: Response, next: NextFunction) => {
        if (req.headers['api-version'] !== version) return next('route')
        next()
    }
}
```

### Pattern 10: Rate Limiting

Protect endpoints from abuse. Apply different limits by route sensitivity.

```typescript
import rateLimit from 'express-rate-limit'

// Global limiter — generous
const globalLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 500,
    standardHeaders: true,
    legacyHeaders: false,
})

// Auth limiter — strict
const authLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 10,
    message: { error: { code: 'RATE_LIMITED', message: 'Too many attempts, try again later' } },
})

app.use('/api', globalLimiter)
app.use('/api/auth/login', authLimiter)
app.use('/api/auth/register', authLimiter)
```

### Pattern 11: CORS Configuration

Be explicit about allowed origins. Never use `*` in production.

```typescript
import cors from 'cors'

// ❌ BAD — allows everything
app.use(cors())

// ✅ GOOD — explicit allow-list
const allowedOrigins = process.env.ALLOWED_ORIGINS?.split(',') ?? []

app.use(cors({
    origin: (origin, callback) => {
        if (!origin || allowedOrigins.includes(origin)) {
            callback(null, true)
        } else {
            callback(new Error('Not allowed by CORS'))
        }
    },
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
    credentials: true,
    maxAge: 86400, // preflight cache 24h
}))
```

---

## Anti-Patterns

### Anti-Pattern 1: Raw SQL in Services

```typescript
// ❌ BAD — service coupled to raw SQL
async function getUser(id: string) {
    return db.query('SELECT * FROM users WHERE id = $1', [id])
}

// ✅ GOOD — through the repository
async function getUser(id: string) {
    return userRepository.findById(id)
}
```

### Anti-Pattern 2: Leaking Internal State in Responses

```typescript
// ❌ BAD — exposes password hash and internal fields
res.json(user)

// ✅ GOOD — explicit response shape
const { password, internalNotes, ...safeUser } = user
res.json({ data: safeUser })

// ✅ BETTER — DTO/serializer function
function toUserResponse(user: User): UserResponse {
    return { id: user.id, email: user.email, name: user.name, createdAt: user.createdAt }
}
res.json({ data: toUserResponse(user) })
```

### Anti-Pattern 3: God Router Files

```typescript
// ❌ BAD — one file with 50+ routes
// routes/index.ts with ALL endpoints

// ✅ GOOD — split by domain
// routes/user.routes.ts
// routes/product.routes.ts
// routes/order.routes.ts
app.use('/api/v1/users', userRoutes)
app.use('/api/v1/products', productRoutes)
app.use('/api/v1/orders', orderRoutes)
```

---

## Quick Reference

| Layer        | Responsibility                                    |
| ------------ | ------------------------------------------------- |
| Routes       | Define paths, HTTP methods, attach middleware      |
| Controllers  | Parse request, delegate to service, send response  |
| Services     | Business logic, orchestration                      |
| Repositories | Data access, query building                        |
| Middleware   | Cross-cutting concerns (auth, logging, validation) |
| Schemas      | Request/response validation with Zod               |
| Errors       | Domain error classes, centralized handler           |

| Concern       | Pattern                          |
| ------------- | -------------------------------- |
| Validation    | Zod schemas + `validate()` middleware |
| Error handling| `AppError` subclasses + `errorHandler` middleware |
| Async safety  | `asyncHandler` wrapper           |
| Pagination    | Query params with Zod + `meta` envelope |
| Rate limiting | `express-rate-limit` per-route   |
| CORS          | Explicit origin allow-list       |
| Versioning    | URL prefix (`/api/v1/...`)       |
