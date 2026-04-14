---
name: code-quality
description: >
  Patrones de calidad de código TypeScript: naming, funciones puras, tipos y convenciones.
  Trigger: Al escribir o revisar TypeScript/JavaScript, al hacer code review, refactoring.
metadata:
  author: team-ai-kit
  version: "1.0"
---

## When to Use

Carga este skill cuando:

- Escribes o revisas TypeScript
- Haces code review o refactoring
- Defines nombres de variables, funciones o clases
- Identificas efectos secundarios ocultos

---

## Critical Patterns

### Pattern 1: Nombres que documentan

```typescript
// ❌ MAL
const d = new Date()
const fn = (x: string) => x.split(' ')
function doStuff(data: any) { ... }

// ✅ BIEN
const createdAt = new Date()
const splitBySpace = (text: string) => text.split(' ')
function parseUserInput(rawInput: string): ParsedInput { ... }
```

### Pattern 2: Sin `any` — tipos explícitos siempre

```typescript
// ❌ MAL
function processData(data: any): any { ... }

// ✅ BIEN
function processData(data: UserInput): ProcessedResult { ... }

// ✅ Si el tipo es complejo, usa unknown + type guard
function processData(data: unknown): ProcessedResult {
    if (!isUserInput(data)) throw new TypeError('...')
    // ahora TypeScript sabe que es UserInput
}
```

### Pattern 3: Funciones pequeñas y puras

Una función hace UNA cosa. Sin efectos secundarios ocultos.

```typescript
// ❌ MAL — hace 3 cosas: valida, transforma y guarda
function handleUserData(raw: string) {
  const valid = raw.length > 0;
  const user = JSON.parse(raw);
  db.save(user);
}

// ✅ BIEN — separadas y testeables
function validateRawUser(raw: string): boolean {
  return raw.length > 0;
}
function parseUser(raw: string): User {
  return JSON.parse(raw);
}
async function saveUser(user: User): Promise<void> {
  await db.save(user);
}
```

### Pattern 4: Contratos primero (interfaces antes que implementaciones)

```typescript
// Primero el contrato
export interface StorageAdapter {
    get(key: string): Promise<string | null>
    set(key: string, value: string): Promise<void>
}

// Luego la implementación
export class LocalStorageAdapter implements StorageAdapter {
    async get(key: string): Promise<string | null> { ... }
    async set(key: string, value: string): Promise<void> { ... }
}
```

---

## Anti-Patterns

### Don't: Non-null assertions sin contexto

```typescript
// ❌ MAL
const value = map.get(key)!;

// ✅ BIEN
const value = map.get(key);
if (!value) throw new Error(`Key not found: ${key}`);
```

### Don't: Duplicar lógica

```typescript
// ❌ MAL — misma validación en 3 lugares
if (text.length > 0 && text.trim() !== '') { ... }

// ✅ BIEN — extraer una vez
function isNonEmpty(text: string): boolean {
    return text.length > 0 && text.trim() !== ''
}
```

---

## Quick Reference

| Regla                                | Ejemplo                                       |
| ------------------------------------ | --------------------------------------------- |
| Sin `any`                            | Usa tipos explícitos o `unknown` + type guard |
| Nombres descriptivos                 | `createUserSession` no `doStuff`              |
| Una función = una responsabilidad    | Si tiene "y" en el nombre → separar           |
| Contratos antes que implementaciones | `interface X` → `class Y implements X`        |
| No duplicar lógica                   | Extraer a función o utility                   |
