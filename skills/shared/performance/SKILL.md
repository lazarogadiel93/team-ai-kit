---
name: performance
description: >
  Análisis y optimización de performance: bundle size, rendering, caché y estrategias de optimización.
  Trigger: Al optimizar bundle, analizar renders innecesarios, mejorar tiempo de respuesta.
metadata:
  author: team-ai-kit
  version: "1.0"
---

## When to Use

Carga este skill cuando:

- El bundle de la app es mayor de lo esperado
- Hay renders innecesarios o freezes en la UI
- El tiempo de respuesta de la API es demasiado alto
- Necesitas optimizar queries o data fetching

---

## Critical Patterns

### Pattern 1: Medir antes de optimizar

```
Hipótesis → Medir → Identificar bottleneck → Optimizar → Verificar mejora

❌ MAL: optimizar sin datos
✅ BIEN: medir primero, optimizar el bottleneck real
```

### Pattern 2: Code splitting y lazy loading

```typescript
// ✅ BIEN — lazy load de componentes pesados
import dynamic from 'next/dynamic'

const HeavyChart = dynamic(() => import('./HeavyChart'), {
    loading: () => <ChartSkeleton />,
    ssr: false,  // solo si realmente es browser-only
})
```

### Pattern 3: Memoización con criterio

```typescript
// ✅ BIEN — memoizar solo cuando el cálculo es costoso y los inputs estables
const processedData = useMemo(
  () => expensiveTransformation(rawData),
  [rawData], // solo si rawData cambia raramente
);

// ❌ MAL — memoizar operaciones triviales (overhead mayor que el cálculo)
const name = useMemo(() => user.firstName + " " + user.lastName, [user]);
```

### Pattern 4: Server Components eliminan JS del cliente

```typescript
// ✅ BIEN — Server Component (zero JS al cliente)
export default async function Dashboard() {
    const data = await getData()
    return <DashboardView data={data} />
}

// ❌ MAL — fetch en cliente + useEffect
'use client'
export function Dashboard() {
    const [data, setData] = useState(null)
    useEffect(() => { fetch('/api/data').then(...).then(setData) }, [])
}
```

---

## Anti-Patterns

### Don't: `use client` innecesario

```typescript
// ❌ MAL — todo el módulo se envía al cliente
'use client'
export function StaticHeader() {
    return <header>Mi App</header>  // sin estado ni eventos
}

// ✅ BIEN — Server Component (zero JS al cliente)
export function StaticHeader() {
    return <header>Mi App</header>
}
```

---

## Quick Reference

| Problema             | Herramienta                                        |
| -------------------- | -------------------------------------------------- |
| Bundle grande        | `next build --analyze` (con @next/bundle-analyzer) |
| Renders innecesarios | React DevTools Profiler                            |
| API lenta            | Network tab + backend profiling                    |
| Memory leak          | Verificar cleanup en useEffect → return () => {}   |
| Queries lentas       | EXPLAIN ANALYZE + índices                          |
