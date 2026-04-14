---
name: frontend-nextjs
description: >
  Patrones Next.js App Router: Server Components, Client Components, Server Actions, layouts y caching.
  Trigger: Al crear páginas, layouts, server actions, al optimizar fetching, al decidir use client.
metadata:
  author: team-ai-kit
  version: "1.0"
---

## When to Use

Carga este skill cuando:

- Creas o modificas páginas, layouts o segmentos de ruta
- Decides si un componente debe ser Server o Client Component
- Implementas mutaciones o formularios con Server Actions
- Optimizas data fetching o configuras caché

---

## Critical Patterns

### Pattern 1: Server Components por defecto

```typescript
// app/dashboard/page.tsx
import { getUser } from '@/features/auth/services/userService'

export default async function DashboardPage() {
    const user = await getUser()
    return <DashboardView user={user} />
}
```

### Pattern 2: `use client` SOLO cuando es necesario

Razones válidas: `useState`, `useEffect`, event handlers, browser APIs.

```typescript
'use client'
import { useState } from 'react'

export function SearchBar({ onSearch }: { onSearch: (q: string) => void }) {
    const [query, setQuery] = useState('')
    return <input value={query} onChange={e => setQuery(e.target.value)} />
}
```

### Pattern 3: Server Actions para mutaciones

```typescript
"use server";
import { revalidatePath } from "next/cache";

export async function createPost(formData: FormData): Promise<ActionResult> {
  const title = formData.get("title") as string;
  await db.posts.create({ title });
  revalidatePath("/posts");
  return { success: true };
}
```

### Pattern 4: Segmentos de carga/error

```
app/
  dashboard/
    page.tsx       ← página principal
    loading.tsx    ← skeleton de carga (Suspense automático)
    error.tsx      ← boundary de error
    layout.tsx     ← layout persistente del segmento
```

---

## Anti-Patterns

### Don't: fetch en cliente cuando puede hacerse en servidor

```typescript
// ❌ MAL
'use client'
export function ProductList() {
    const [products, setProducts] = useState([])
    useEffect(() => {
        fetch('/api/products').then(r => r.json()).then(setProducts)
    }, [])
}

// ✅ BIEN — Server Component
export default async function ProductList() {
    const products = await fetchProducts()
    return products.map(p => <ProductCard key={p.id} product={p} />)
}
```

---

## Quick Reference

| Pregunta                    | Decisión                     |
| --------------------------- | ---------------------------- |
| ¿Necesita estado o eventos? | `use client`                 |
| ¿Solo muestra datos?        | Server Component             |
| ¿Muta datos / formularios?  | Server Action                |
| ¿Loading UX?                | `loading.tsx` en el segmento |
| ¿Error boundary por ruta?   | `error.tsx` en el segmento   |
