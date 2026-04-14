---
name: backend-node-api
description: >
  Patrones de diseño de APIs REST con Node.js/Express/Fastify: rutas, controllers, middleware, validación.
  Trigger: Al crear endpoints, definir rutas, implementar middleware, manejar errores HTTP.
metadata:
  author: team-ai-kit
  version: "1.0"
---

## When to Use

Carga este skill cuando:

- Creas o modificas endpoints REST
- Implementas middleware (auth, logging, error handling)
- Diseñas la estructura de controllers y routes
- Manejas validación de request/response

---

## Critical Patterns

### Pattern 1: Controller delgado — lógica en services

```typescript
// ❌ MAL — controller hace todo
router.post('/users', async (req, res) => {
    const { email, password } = req.body
    const existing = await db.users.findByEmail(email)
    if (existing) return res.status(409).json({ error: 'Email exists' })
    const hashed = await bcrypt.hash(password, 10)
    const user = await db.users.create({ email, password: hashed })
    const token = jwt.sign({ id: user.id }, SECRET)
    res.status(201).json({ user, token })
})

// ✅ BIEN — controller delega a service
router.post('/users', async (req, res, next) => {
    try {
        const dto = CreateUserSchema.parse(req.body)
        const result = await userService.register(dto)
        res.status(201).json(result)
    } catch (error) {
        next(error)
    }
})
```

### Pattern 2: Validación en el borde con Zod

```typescript
import { z } from 'zod'

export const CreateUserSchema = z.object({
    email: z.string().email(),
    password: z.string().min(8),
    name: z.string().min(2).max(100),
})

export type CreateUserDto = z.infer<typeof CreateUserSchema>

// Middleware de validación reutilizable
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
```

### Pattern 3: Error handling centralizado

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

// middleware/error-handler.ts
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
    console.error('Unhandled error:', err)
    res.status(500).json({ error: { code: 'INTERNAL', message: 'Internal server error' } })
}
```

### Pattern 4: Repository abstrae la DB

```typescript
// contracts/user.repository.ts
export interface UserRepository {
    findById(id: string): Promise<User | null>
    findByEmail(email: string): Promise<User | null>
    create(data: CreateUserDto): Promise<User>
    update(id: string, data: Partial<User>): Promise<User>
}

// repositories/prisma-user.repository.ts
export class PrismaUserRepository implements UserRepository {
    constructor(private readonly prisma: PrismaClient) {}

    async findById(id: string): Promise<User | null> {
        return this.prisma.user.findUnique({ where: { id } })
    }
    // ...
}
```

---

## Anti-Patterns

### Don't: SQL crudo en services

```typescript
// ❌ MAL
async function getUser(id: string) {
    return db.query('SELECT * FROM users WHERE id = $1', [id])
}

// ✅ BIEN — a través del repository
async function getUser(id: string) {
    return userRepository.findById(id)
}
```

### Don't: Try/catch en cada función

```typescript
// ❌ MAL — try/catch repetido en cada handler
router.get('/users/:id', async (req, res) => {
    try { ... } catch (error) { res.status(500).json({ error }) }
})

// ✅ BIEN — wrapper o middleware centralizado
const asyncHandler = (fn: RequestHandler) =>
    (req: Request, res: Response, next: NextFunction) =>
        Promise.resolve(fn(req, res, next)).catch(next)

router.get('/users/:id', asyncHandler(async (req, res) => {
    const user = await userService.getById(req.params.id)
    res.json(user)
}))
```

---

## Quick Reference

| Capa          | Responsabilidad                          |
| ------------- | ---------------------------------------- |
| Routes        | Definir paths y métodos HTTP             |
| Controllers   | Parsear request, delegar, enviar response |
| Services      | Lógica de negocio                        |
| Repositories  | Acceso a datos                           |
| Middleware     | Cross-cutting concerns (auth, logging)   |
