---
name: backend-node-testing
description: >
  Patrones de testing para backend Node.js: unit tests, integration tests, mocking y test doubles.
  Trigger: Al escribir tests, mockear dependencias, testear APIs, configurar test suites.
metadata:
  author: team-ai-kit
  version: "1.0"
---

## When to Use

Carga este skill cuando:

- Escribes tests unitarios o de integración para backend
- Necesitas mockear servicios externos, DB o APIs
- Configuras test suites con Vitest o Jest
- Testeas endpoints HTTP

---

## Critical Patterns

### Pattern 1: Test lo que importa — comportamiento, no implementación

```typescript
// ❌ MAL — testea implementación interna
it('should call bcrypt.hash with rounds=10', async () => {
    await userService.register(dto)
    expect(bcrypt.hash).toHaveBeenCalledWith(dto.password, 10)
})

// ✅ BIEN — testea comportamiento observable
it('should create user with hashed password (not plaintext)', async () => {
    const result = await userService.register(dto)
    const saved = await userRepository.findById(result.id)
    expect(saved?.password).not.toBe(dto.password)
})
```

### Pattern 2: Test doubles claros

```typescript
// Stub: retorna datos predefinidos
const userRepository: UserRepository = {
    findById: vi.fn().mockResolvedValue({ id: '1', name: 'Test' }),
    findByEmail: vi.fn().mockResolvedValue(null),
    create: vi.fn().mockImplementation(async (data) => ({ id: '1', ...data })),
    update: vi.fn(),
}

// El service recibe el stub por constructor (DI)
const userService = new UserService(userRepository)
```

### Pattern 3: Integration tests con supertest

```typescript
import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import request from 'supertest'
import { createApp } from '../app'

describe('POST /api/users', () => {
    let app: Express

    beforeAll(async () => {
        app = await createApp({ database: 'test' })
    })

    it('should create a user and return 201', async () => {
        const response = await request(app)
            .post('/api/users')
            .send({ email: 'test@test.com', password: 'secure123', name: 'Test' })

        expect(response.status).toBe(201)
        expect(response.body).toHaveProperty('id')
        expect(response.body.email).toBe('test@test.com')
    })

    it('should return 400 for invalid email', async () => {
        const response = await request(app)
            .post('/api/users')
            .send({ email: 'not-an-email', password: 'secure123', name: 'Test' })

        expect(response.status).toBe(400)
    })
})
```

### Pattern 4: Arrange-Act-Assert

```typescript
it('should throw NotFoundError when user does not exist', async () => {
    // Arrange
    userRepository.findById.mockResolvedValue(null)

    // Act & Assert
    await expect(userService.getById('nonexistent'))
        .rejects.toThrow(NotFoundError)
})
```

---

## Anti-Patterns

### Don't: Tests acoplados a la DB real sin cleanup

```typescript
// ❌ MAL — deja datos sucios
it('creates user', async () => {
    await db.users.create({ email: 'test@test.com', ... })
    // no cleanup — afecta otros tests
})

// ✅ BIEN — transacción que se revierte
it('creates user', async () => {
    await db.$transaction(async (tx) => {
        const user = await userService.register(dto, tx)
        expect(user).toBeDefined()
        throw new Error('rollback') // fuerza rollback
    }).catch(() => {})
})
```

---

## Quick Reference

| Tipo            | Qué testea                       | Velocidad | Mocks         |
| --------------- | -------------------------------- | --------- | ------------- |
| Unit test       | Una función/clase aislada        | Rápido    | Todo mockeado |
| Integration     | Endpoint completo con DB         | Medio     | Solo externos |
| E2E             | Flujo completo del usuario       | Lento     | Nada          |
