---
name: debug
description: >
  Workflow sistemático de debugging: diagnóstico, aislamiento, fix y verificación.
  Trigger: Al diagnosticar errores, excepciones, comportamiento inesperado o tests que fallan.
metadata:
  author: team-ai-kit
  version: "1.0"
---

## When to Use

Carga este skill cuando:

- Un error aparece en runtime o tests
- El comportamiento del sistema es inesperado
- Necesitas aislar la causa raíz antes de proponer el fix
- Un test falla y no está claro por qué

---

## Critical Patterns

### Pattern 1: Reproducir antes de fijar

Antes de cambiar cualquier código, **reproduce el error de forma aislada**:

1. ¿El error ocurre siempre o intermitentemente?
2. ¿Qué input lo provoca?
3. ¿Qué versión de Node/deps está activa?

### Pattern 2: Narrowing sistemático

```
Error observado
    └── ¿En qué capa ocurre? (UI / Domain / Data / Infra)
            └── ¿Qué función exacta falla? (stack trace)
                    └── ¿Con qué input? (log de parámetros)
                            └── Causa raíz identificada
```

### Pattern 3: Fix mínimo — no refactor durante debug

```
❌ MAL: "Ya que estoy debuggeando, refactorizo también"

✅ BIEN:
  1. Fix mínimo que arregla el bug
  2. Test que verifica el fix
  3. Commit del fix
  4. Refactor en PR separado si es necesario
```

---

## Code Examples

### Type-safe error handling

```typescript
async function fetchData<T>(url: string, schema: ZodSchema<T>): Promise<T> {
  try {
    const response = await fetch(url);
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

### Structured error logging

```typescript
function logError(context: string, error: unknown): void {
  const message = error instanceof Error ? error.message : String(error);
  const stack = error instanceof Error ? error.stack : undefined;
  console.error(`[${context}] ${message}`, stack ? `\n${stack}` : '');
}
```

---

## Anti-Patterns

### Don't: Suprimir errores silenciosamente

```typescript
// ❌ MAL
try {
  await riskyOperation();
} catch {
  /* silencio total */
}

// ✅ BIEN
try {
  await riskyOperation();
} catch (error) {
  logError('riskyOperation', error);
  // decidir: re-throw, fallback, o log
}
```

---

## Quick Reference

| Situación                      | Acción                                              |
| ------------------------------ | --------------------------------------------------- |
| Error de validación (Zod)      | Schema no matchea → revisar el contrato             |
| Error de red / timeout         | Verificar URL, CORS, conectividad                   |
| Test falla intermitentemente   | Race condition → revisar async/await y cleanup       |
| Error solo en producción       | Verificar env vars, feature flags, datos reales      |
| Stack trace apunta a node_modules | Versión de dependencia → revisar lockfile          |
