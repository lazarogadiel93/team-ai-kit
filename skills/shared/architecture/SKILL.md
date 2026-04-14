---
name: architecture
description: >
  Clean Architecture y estructura feature-based para proyectos TypeScript.
  Trigger: Al diseñar la estructura de una feature, al definir módulos, al revisar dependencias entre capas.
metadata:
  author: team-ai-kit
  version: "1.0"
---

## When to Use

Carga este skill cuando:

- Diseñas o revisas la estructura de un feature o módulo
- Analizas dependencias entre capas (ui → domain → data)
- Detectas o corregías cross-feature imports
- Defines dónde va un nuevo componente, hook, servicio o adapter

---

## Critical Patterns

### Pattern 1: Scope Rule — Global vs Local

Un componente/función es **global** si es usado por 2+ features.  
Un componente/función es **local** si es usado por 1 sola feature.

```
shared/          ← global (2+ features lo usan)
  components/Button.tsx
  hooks/useDebounce.ts

features/
  auth/          ← local a auth
    components/LoginForm.tsx
    hooks/useAuth.ts
    services/authService.ts
```

### Pattern 2: No Cross-Feature Imports

```typescript
// ❌ MAL — auth importa directo de dashboard
import { DashboardLayout } from "../dashboard/components/DashboardLayout";

// ✅ BIEN — usa el shared/ global o comunicación vía props/context
import { DashboardLayout } from "@/shared/layouts/DashboardLayout";
```

### Pattern 3: La estructura grita la funcionalidad

```
features/
  checkout/          ← el nombre dice TODO
    components/
      CheckoutForm.tsx
      OrderSummary.tsx
    hooks/
      useCheckout.ts
    services/
      checkoutService.ts
    index.ts         ← barrel export (API pública de la feature)
```

### Pattern 4: Capas y dirección de dependencias

```
UI Layer          → Domain Layer → Data Layer
components/        services/        repositories/
hooks/             entities/        adapters/
pages/

Regla: Las capas externas NUNCA importan las internas directamente.
Las capas internas (domain) no saben nada de UI ni Data.
```

---

## Code Examples

### Barrel Export (index.ts por feature)

```typescript
// features/auth/index.ts
export { LoginForm } from "./components/LoginForm";
export { useAuth } from "./hooks/useAuth";
export type { AuthUser } from "./types";
// No exportar implementaciones internas
```

### Clean Adapter

```typescript
// adapters/api-client/index.ts
import type { ApiClient } from "../../core/contracts/api-client.contract";

export class FetchApiClient implements ApiClient {
  constructor(private readonly baseUrl: string) {}

  async get<T>(path: string): Promise<T> {
    const response = await fetch(`${this.baseUrl}${path}`);
    return response.json();
  }
}
```

---

## Anti-Patterns

### Don't: Lógica de negocio en componentes UI

```typescript
// ❌ MAL
function ProductCard({ productId }: { productId: string }) {
    const [product, setProduct] = useState(null)
    useEffect(() => {
        fetch(`/api/products/${productId}`).then(r => r.json()).then(setProduct)
    }, [productId])
    const discount = product ? product.price * 0.15 : 0  // ← lógica de negocio aquí
    return <div>{discount}</div>
}

// ✅ BIEN
function ProductCard({ product }: { product: Product }) {
    return <div>{product.discountedPrice}</div>  // ← solo presentación
}
```

---

## Quick Reference

| Pregunta                                    | Regla                                              |
| ------------------------------------------- | -------------------------------------------------- |
| ¿Este componente va en shared/ o features/? | 1 feature → local; 2+ features → global            |
| ¿Puedo importar desde otra feature?         | No — usa shared/ o comunica vía props              |
| ¿Dónde va la lógica de negocio?             | En services/ o domain/ never en components/        |
| ¿Qué exporta un barrel?                     | Solo la API pública — no implementaciones internas |
