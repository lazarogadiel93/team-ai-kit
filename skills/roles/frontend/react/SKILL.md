---
name: frontend-react
description: >
  React component patterns: hooks, state management, composition, performance, and TypeScript integration.
  Trigger: When creating React components, custom hooks, managing state, or designing UI patterns.
globs:
  - "**/*.tsx"
  - "**/*.jsx"
  - "**/hooks/**"
  - "**/components/**"
metadata:
  author: team-ai-kit
  version: "1.0"
---

## When to Use

Load this skill when you:

- Create or refactor React components
- Implement custom hooks
- Design state flow for a feature
- Organize component structure within a feature
- Need to decide on performance optimizations (memoization, code splitting)
- Work with TypeScript generics in component APIs

---

## Critical Patterns

### Pattern 1: Presentational components without side effects

Components that only receive props and render UI. No state, no effects, no logic.

```typescript
// ✅ GOOD — pure presentational component
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
      <button onClick={onEdit}>Edit</button>
    </div>
  )
}
```

```typescript
// ❌ BAD — side effects inside a presentational component
export function UserCard({ name, email, onEdit }: UserCardProps) {
  console.log("rendered") // side effect in render
  localStorage.setItem("lastViewed", name) // side effect in render
  return (
    <div className="card">
      <h3>{name}</h3>
      <p>{email}</p>
    </div>
  )
}
```

### Pattern 2: Custom hooks to encapsulate logic

Extract reusable or complex logic into custom hooks. The component stays thin.

```typescript
// ✅ GOOD — logic in hook, component only renders
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

```typescript
// ❌ BAD — all logic inlined in the component
export function UserDashboard() {
  const [user, setUser] = useState<User | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    fetchCurrentUser()
      .then(setUser)
      .catch(e => setError(e.message))
      .finally(() => setIsLoading(false))
  }, [])

  // 150+ lines of mixed logic and JSX...
}
```

### Pattern 3: State as close as possible to where it's used

```typescript
// ❌ BAD — global state for something local
// store.ts → selectedTab (only used by the Tabs component)

// ✅ GOOD — local state in the component that owns it
export function Tabs({ items }: TabsProps) {
  const [selected, setSelected] = useState(items[0].id)
  return (
    <div>
      {items.map(item => (
        <button key={item.id} onClick={() => setSelected(item.id)}>
          {item.label}
        </button>
      ))}
    </div>
  )
}
```

### Pattern 4: Props drilling — use Context or composition

When prop drilling exceeds 2 levels, prefer composition (children) or Context.

```typescript
// ❌ BAD — drilling user through 3+ levels
<Grandparent user={user}>
  <Parent user={user}>
    <Child user={user} />
  </Parent>
</Grandparent>

// ✅ GOOD — composition with children
export function UserPage({ user }: { user: User }) {
  return (
    <UserLayout>
      <UserHeader user={user} />
      <UserContent user={user} />
    </UserLayout>
  )
}

// ✅ GOOD — Context for deeply shared state
const UserContext = createContext<User | null>(null)

export function useUser() {
  const ctx = useContext(UserContext)
  if (!ctx) throw new Error("useUser must be used within UserProvider")
  return ctx
}
```

### Pattern 5: React 19 — `use` for async data

```typescript
// ✅ GOOD — React 19 `use` with Suspense
import { use, Suspense } from 'react'

function UserProfile({ userPromise }: { userPromise: Promise<User> }) {
  const user = use(userPromise)
  return <h1>{user.name}</h1>
}

// Create the promise OUTSIDE the component (e.g., in a route loader or parent)
// to avoid re-creating it on every render
const userPromise = fetchUser()

export function UserPage() {
  return (
    <Suspense fallback={<Skeleton />}>
      <UserProfile userPromise={userPromise} />
    </Suspense>
  )
}
```

### Pattern 6: React 19 — Actions and useActionState

```typescript
// ✅ GOOD — useActionState for form mutations
import { useActionState } from 'react'

function CreatePostForm() {
  const [state, formAction, isPending] = useActionState(createPost, {
    error: null,
  })

  return (
    <form action={formAction}>
      <input name="title" required />
      {state.error && <p className="error">{state.error}</p>}
      <button type="submit" disabled={isPending}>
        {isPending ? "Creating..." : "Create"}
      </button>
    </form>
  )
}
```

### Pattern 7: useOptimistic for instant UI feedback

```typescript
// ✅ GOOD — optimistic update while mutation is in flight
import { useOptimistic } from 'react'

function TodoList({ todos, addTodo }: Props) {
  const [optimisticTodos, addOptimistic] = useOptimistic(
    todos,
    (current, newTodo: Todo) => [...current, { ...newTodo, pending: true }]
  )

  async function handleAdd(formData: FormData) {
    const title = formData.get("title") as string
    addOptimistic({ id: crypto.randomUUID(), title, pending: true })
    await addTodo(title)
  }

  return (
    <form action={handleAdd}>
      <input name="title" />
      <ul>
        {optimisticTodos.map(t => (
          <li key={t.id} style={{ opacity: t.pending ? 0.5 : 1 }}>{t.title}</li>
        ))}
      </ul>
    </form>
  )
}
```

### Pattern 8: Suspense boundaries and Error Boundaries

```typescript
// ✅ GOOD — granular Suspense boundaries
export function Dashboard() {
  return (
    <div>
      <h1>Dashboard</h1>
      <ErrorBoundary fallback={<p>Failed to load stats</p>}>
        <Suspense fallback={<StatsSkeleton />}>
          <StatsPanel />
        </Suspense>
      </ErrorBoundary>
      <ErrorBoundary fallback={<p>Failed to load feed</p>}>
        <Suspense fallback={<FeedSkeleton />}>
          <ActivityFeed />
        </Suspense>
      </ErrorBoundary>
    </div>
  )
}
```

```typescript
// ❌ BAD — single Suspense wrapping everything (one slow component blocks all)
<Suspense fallback={<FullPageSpinner />}>
  <StatsPanel />
  <ActivityFeed />
  <Notifications />
</Suspense>
```

### Pattern 9: Code splitting with React.lazy

```typescript
// ✅ GOOD — lazy load heavy components
const AdminPanel = lazy(() => import('./AdminPanel'))
const ChartView = lazy(() => import('./ChartView'))

export function App() {
  return (
    <Suspense fallback={<Spinner />}>
      {isAdmin && <AdminPanel />}
      {showCharts && <ChartView />}
    </Suspense>
  )
}
```

### Pattern 10: key prop to reset component state

```typescript
// ✅ GOOD — key change forces full remount and state reset
export function ChatPage({ conversationId }: Props) {
  return <ChatPanel key={conversationId} id={conversationId} />
}

// ❌ BAD — useEffect to "reset" state manually
export function ChatPanel({ id }: Props) {
  const [messages, setMessages] = useState<Message[]>([])
  useEffect(() => {
    setMessages([]) // manual reset — fragile and easy to miss fields
  }, [id])
}
```

### Pattern 11: Controlled vs Uncontrolled inputs

```typescript
// ✅ Controlled — when you need real-time access to value
function SearchBar() {
  const [query, setQuery] = useState('')
  return <input value={query} onChange={e => setQuery(e.target.value)} />
}

// ✅ Uncontrolled — when you only need value on submit (simpler, better perf)
function LoginForm() {
  const formRef = useRef<HTMLFormElement>(null)
  function handleSubmit(e: FormEvent) {
    e.preventDefault()
    const data = new FormData(formRef.current!)
    login(data.get("email") as string, data.get("password") as string)
  }
  return (
    <form ref={formRef} onSubmit={handleSubmit}>
      <input name="email" />
      <input name="password" type="password" />
      <button type="submit">Login</button>
    </form>
  )
}
```

### Pattern 12: ref as prop (React 19 — no forwardRef needed)

```typescript
// ✅ GOOD — React 19: ref is a regular prop, no forwardRef wrapper needed
interface InputProps extends React.ComponentPropsWithoutRef<'input'> {
  label: string
  error?: string
  ref?: React.Ref<HTMLInputElement>
}

export function Input({ label, error, ref, ...rest }: InputProps) {
  return (
    <div>
      <label>{label}</label>
      <input ref={ref} {...rest} />
      {error && <span className="error">{error}</span>}
    </div>
  )
}

// Parent uses it naturally:
function LoginForm() {
  const emailRef = useRef<HTMLInputElement>(null)
  return <Input ref={emailRef} label="Email" />
}
```

### Pattern 13: useCallback and useMemo — when to use and when NOT to

```typescript
// ✅ USE useMemo — expensive computation
const sorted = useMemo(
  () => items.toSorted((a, b) => a.price - b.price),
  [items]
)

// ✅ USE useCallback — stable reference passed to memoized child
const handleDelete = useCallback((id: string) => {
  setItems(prev => prev.filter(item => item.id !== id))
}, [])

return <MemoizedList items={sorted} onDelete={handleDelete} />
```

```typescript
// ❌ BAD — useMemo for trivial operations (overhead > benefit)
const fullName = useMemo(() => `${first} ${last}`, [first, last])

// ❌ BAD — useCallback when the child is NOT memoized (no benefit)
const handleClick = useCallback(() => {
  setOpen(true)
}, [])
return <button onClick={handleClick}>Open</button> // button re-renders anyway
```

**Rule of thumb**: Only memoize when you can prove the cost of re-computation or re-render is real. Profile first, optimize second.

### Pattern 14: TypeScript generic components

```typescript
// ✅ GOOD — generic Select component works with any item type
interface SelectProps<T> {
  items: T[]
  value: T
  onChange: (item: T) => void
  getLabel: (item: T) => string
  getKey: (item: T) => string
}

export function Select<T>({ items, value, onChange, getLabel, getKey }: SelectProps<T>) {
  return (
    <select
      value={getKey(value)}
      onChange={e => {
        const item = items.find(i => getKey(i) === e.target.value)
        if (item) onChange(item)
      }}
    >
      {items.map(item => (
        <option key={getKey(item)} value={getKey(item)}>
          {getLabel(item)}
        </option>
      ))}
    </select>
  )
}

// Usage — TypeScript infers T as Country
<Select
  items={countries}
  value={selected}
  onChange={setSelected}
  getLabel={c => c.name}
  getKey={c => c.code}
/>
```

---

## Anti-Patterns

### Anti-Pattern 1: Side effects during render

```typescript
// ❌ BAD — runs on every render, blocks paint
export function List({ items }: ListProps) {
  localStorage.setItem('lastItems', JSON.stringify(items))
  return <ul>{items.map(i => <li key={i.id}>{i.name}</li>)}</ul>
}

// ✅ GOOD — effect runs after render, with dependency tracking
export function List({ items }: ListProps) {
  useEffect(() => {
    localStorage.setItem('lastItems', JSON.stringify(items))
  }, [items])
  return <ul>{items.map(i => <li key={i.id}>{i.name}</li>)}</ul>
}
```

### Anti-Pattern 2: Components with too many responsibilities

```typescript
// ❌ BAD — fetches, parses, validates, and renders all in one (200+ lines)
export function UserDashboard() { ... }

// ✅ GOOD — separated concerns
export function UserDashboard() {
  const { user, isLoading } = useUserSession()
  return isLoading ? <DashboardSkeleton /> : <DashboardLayout user={user} />
}
```

### Anti-Pattern 3: Array index as key for dynamic lists

```typescript
// ❌ BAD — index keys break state when items reorder or delete
{items.map((item, index) => <TodoItem key={index} item={item} />)}

// ✅ GOOD — stable unique ID
{items.map(item => <TodoItem key={item.id} item={item} />)}
```

### Anti-Pattern 4: Derive state that can be computed

```typescript
// ❌ BAD — syncing derived state with useEffect
const [items, setItems] = useState<Item[]>([])
const [filteredItems, setFilteredItems] = useState<Item[]>([])

useEffect(() => {
  setFilteredItems(items.filter(i => i.active))
}, [items])

// ✅ GOOD — compute during render
const [items, setItems] = useState<Item[]>([])
const filteredItems = items.filter(i => i.active)
```

---

## Quick Reference

| Pattern                    | When to apply                                         |
| -------------------------- | ----------------------------------------------------- |
| Presentational component   | No state needed — props in, JSX out                   |
| Custom hook                | Reusable or complex logic — extract from component    |
| Local useState             | State owned by a single component                     |
| Context                    | State shared across 3+ levels deep                    |
| Composition over inherit.  | Always in React                                       |
| `use` (React 19)           | Read a Promise or Context in render                   |
| `useActionState`           | Form mutations with pending + error state             |
| `useOptimistic`            | Instant UI feedback while mutation is in flight       |
| Suspense boundary          | Async component loading — granular per section        |
| Error Boundary             | Catch render errors — wrap per independent section    |
| React.lazy                 | Code split heavy/conditional components               |
| key prop reset             | Force remount when identity changes (e.g. chat ID)    |
| forwardRef                 | Reusable primitives that expose DOM ref (pre-React 19; React 19+ uses ref as prop directly) |
| useMemo                    | Expensive computations — profile first                |
| useCallback                | Stable ref for memoized children — profile first      |
| Generic components         | Reusable UI that works with multiple data types       |
