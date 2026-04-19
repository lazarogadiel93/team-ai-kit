---
name: frontend-react
description: >
  Patrones React: componentes, hooks, estado y composición para proyectos feature-based.
  Trigger: Al crear componentes React, hooks personalizados, manejar estado o diseñar UI patterns.
metadata:
  author: team-ai-kit
  version: "1.0"
---

## When to Use

Carga este skill cuando:

- Creas o refactorizas componentes React
- Implementas custom hooks
- Diseñas el flujo de estado de una feature
- Organizas la estructura de componentes dentro de una feature

---

## Critical Patterns

### Pattern 1: Componentes presentacionales sin efectos

```typescript
interface UserCardProps {
    name: string
    email: string
    onEdit: () => void
}

export function UserCard({ name, email, onEdit }: UserCardProps) {
    return (
        <div className="card">
            <h3>{name}</h3>
            <p>{email}</p>
            <button onClick={onEdit}>Editar</button>
        </div>
    )
}
```

### Pattern 2: Custom hooks para encapsular lógica

```typescript
export function useUserSession() {
    const [user, setUser] = useState<User | null>(null)
    const [isLoading, setIsLoading] = useState(true)

    useEffect(() => {
        fetchCurrentUser()
            .then(setUser)
            .finally(() => setIsLoading(false))
    }, [])

    return { user, isLoading }
}

export function UserDashboard() {
    const { user, isLoading } = useUserSession()
    if (isLoading) return <Skeleton />
    return <UserProfile user={user} />
}
```

### Pattern 3: Estado lo más cerca posible de donde se usa

```typescript
// ❌ MAL — estado global para algo local
// store.ts → selectedTab (solo lo usa el componente Tabs)

// ✅ BIEN — estado local al componente
export function Tabs({ items }: TabsProps) {
    const [selected, setSelected] = useState(items[0].id)
    return (...)
}
```

### Pattern 4: Props drilling → Context o composición

Si el prop drilling supera 2 niveles, usa Context o composición.

```typescript
export function UserPage({ user }: { user: User }) {
    return (
        <UserLayout>
            <UserHeader user={user} />
            <UserContent user={user} />
        </UserLayout>
    )
}
```

---

## Anti-Patterns

### Don't: Efectos secundarios en render

```typescript
// ❌ MAL
export function List({ items }: ListProps) {
    localStorage.setItem('lastItems', JSON.stringify(items))
    return <ul>{items.map(i => <li key={i.id}>{i.name}</li>)}</ul>
}

// ✅ BIEN
export function List({ items }: ListProps) {
    useEffect(() => {
        localStorage.setItem('lastItems', JSON.stringify(items))
    }, [items])
    return <ul>{items.map(i => <li key={i.id}>{i.name}</li>)}</ul>
}
```

### Don't: Componentes con demasiadas responsabilidades

```typescript
// ❌ MAL — hace fetch, parsea, valida y renderiza
export function UserDashboard() { ... /* 200 líneas */ }

// ✅ BIEN — separado
export function UserDashboard() {
    const { user, isLoading } = useUserSession()
    return isLoading ? <DashboardSkeleton /> : <DashboardLayout user={user} />
}
```

---

## Quick Reference

| Patrón                     | Cuándo aplicar                                 |
| -------------------------- | ---------------------------------------------- |
| Componente presentacional  | Estado no necesario → solo props               |
| Custom hook                | Lógica reutilizable o compleja → extraer       |
| useState local             | Estado de 1 componente                         |
| Context                    | Estado compartido en 3+ niveles de profundidad |
| Composición sobre herencia | Siempre en React                               |
