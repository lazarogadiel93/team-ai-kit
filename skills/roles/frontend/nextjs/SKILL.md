---
name: frontend-nextjs
description: >
  Next.js App Router patterns: Server Components, Client Components, Server Actions, routing, caching, and streaming.
  Trigger: When creating pages, layouts, server actions, optimizing data fetching, or deciding component boundaries.
globs:
  - "**/app/**/*.tsx"
  - "**/app/**/*.ts"
  - "**/middleware.ts"
  - "**/next.config.*"
metadata:
  author: team-ai-kit
  version: "1.0"
---

## When to Use

Load this skill when you:

- Create or modify pages, layouts, or route segments
- Decide whether a component should be a Server or Client Component
- Implement mutations or forms with Server Actions
- Optimize data fetching or configure caching/revalidation
- Set up middleware, parallel routes, or intercepting routes
- Configure metadata for SEO

---

## Critical Patterns

### Pattern 1: Server Components by default

Every component in the `app/` directory is a Server Component unless you add `'use client'`. Fetch data directly — no API layer needed.

```typescript
// app/dashboard/page.tsx
// ✅ GOOD — Server Component, async data fetching at the top
import { getUser } from '@/features/auth/services/userService'

export default async function DashboardPage() {
  const user = await getUser()
  return <DashboardView user={user} />
}
```

```typescript
// ❌ BAD — unnecessary client-side fetching
'use client'
import { useState, useEffect } from 'react'

export default function DashboardPage() {
  const [user, setUser] = useState(null)
  useEffect(() => {
    fetch('/api/user').then(r => r.json()).then(setUser)
  }, [])
  return user ? <DashboardView user={user} /> : <Spinner />
}
```

### Pattern 2: `'use client'` only when required

Valid reasons: `useState`, `useEffect`, event handlers, browser APIs, third-party client libraries.

```typescript
'use client'
import { useState } from 'react'

// ✅ GOOD — needs state for interactivity
export function SearchBar({ onSearch }: { onSearch: (q: string) => void }) {
  const [query, setQuery] = useState('')
  return (
    <input
      value={query}
      onChange={e => setQuery(e.target.value)}
      onKeyDown={e => e.key === 'Enter' && onSearch(query)}
    />
  )
}
```

**Key rule**: Push `'use client'` as far down the tree as possible. Keep the page/layout as Server Components and only wrap the interactive leaf.

```typescript
// ✅ GOOD — Server Component page with a small Client island
// app/products/page.tsx (Server Component)
export default async function ProductsPage() {
  const products = await getProducts()
  return (
    <div>
      <h1>Products</h1>
      <SearchBar />                            {/* Client Component handles its own state */}
      <ProductGrid products={products} />      {/* Server Component */}
    </div>
  )
}
```

### Pattern 3: App Router file conventions

```
app/
  layout.tsx       — Root layout (wraps entire app, renders once)
  page.tsx         — Home page (/)
  loading.tsx      — Suspense fallback for the route segment
  error.tsx        — Error boundary for the route segment (must be 'use client')
  not-found.tsx    — Custom 404 UI (triggered by notFound())
  template.tsx     — Like layout but remounts on navigation (rare)
  route.ts         — API Route Handler (GET, POST, etc.)
  
  dashboard/
    page.tsx       — /dashboard
    loading.tsx    — Skeleton while dashboard loads
    error.tsx      — Error UI for dashboard segment
    layout.tsx     — Persistent layout for dashboard section

  @modal/          — Parallel route (named slot)
    (.)photo/[id]/ — Intercepting route
      page.tsx
```

### Pattern 4: Server Actions for mutations

```typescript
// ✅ GOOD — Server Action in a separate file
// app/posts/actions.ts
"use server"

import { revalidatePath } from "next/cache"

export async function createPost(formData: FormData): Promise<ActionResult> {
  const title = formData.get("title") as string

  if (!title || title.length < 3) {
    return { success: false, error: "Title must be at least 3 characters" }
  }

  await db.posts.create({ data: { title } })
  revalidatePath("/posts")
  return { success: true }
}
```

```typescript
// ❌ BAD — using an API route for a simple mutation
// app/api/posts/route.ts
export async function POST(req: Request) {
  const body = await req.json()
  await db.posts.create({ data: body })
  return Response.json({ ok: true })
}
// Then calling fetch('/api/posts', { method: 'POST' }) from client
// This is unnecessary indirection when Server Actions exist
```

**When to use Route Handlers vs Server Actions:**

| Use case                        | Choose              |
| ------------------------------- | ------------------- |
| Form submissions / mutations    | Server Action       |
| Webhooks from external services | Route Handler       |
| Public API consumed by others   | Route Handler       |
| Client-side data mutation       | Server Action       |
| File uploads with progress      | Route Handler       |

### Pattern 5: Streaming with Suspense

Wrap slow parts of the page in Suspense so the shell renders immediately.

```typescript
// app/dashboard/page.tsx
// ✅ GOOD — shell renders instantly, slow sections stream in
import { Suspense } from 'react'

export default function DashboardPage() {
  return (
    <div>
      <h1>Dashboard</h1>
      <Suspense fallback={<StatsSkeleton />}>
        <StatsPanel />  {/* async Server Component — can be slow */}
      </Suspense>
      <Suspense fallback={<FeedSkeleton />}>
        <ActivityFeed />  {/* async Server Component — can be slow */}
      </Suspense>
    </div>
  )
}

async function StatsPanel() {
  const stats = await getStats() // slow query
  return <StatsGrid stats={stats} />
}
```

```typescript
// ❌ BAD — no Suspense boundaries, entire page waits for slowest query
export default async function DashboardPage() {
  const stats = await getStats()      // 2s
  const feed = await getActivityFeed() // 3s — total: 5s before anything renders
  return (
    <div>
      <StatsGrid stats={stats} />
      <Feed items={feed} />
    </div>
  )
}
```

### Pattern 6: Caching and revalidation strategies

```typescript
// Time-based revalidation (ISR)
// Revalidate this fetch every 60 seconds
const data = await fetch('https://api.example.com/data', {
  next: { revalidate: 60 }
})

// Tag-based revalidation
const posts = await fetch('https://api.example.com/posts', {
  next: { tags: ['posts'] }
})

// In a Server Action after mutation:
import { revalidateTag, revalidatePath } from 'next/cache'

export async function createPost() {
  "use server"
  await db.posts.create(...)
  revalidateTag('posts')      // invalidate all fetches tagged 'posts'
  revalidatePath('/posts')    // revalidate a specific path
}
```

```typescript
// ❌ BAD — no-store on everything "just in case"
const data = await fetch(url, { cache: 'no-store' }) // kills all caching benefits

// ✅ GOOD — opt out of cache only when data must be real-time
const balance = await fetch(url, { cache: 'no-store' }) // user balance — must be fresh
```

### Pattern 7: Metadata API for SEO

```typescript
// Static metadata
// app/about/page.tsx
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'About Us',
  description: 'Learn about our company',
  openGraph: { title: 'About Us', description: 'Learn about our company' },
}

// Dynamic metadata (Next.js 15: params is a Promise)
// app/posts/[slug]/page.tsx
export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params
  const post = await getPost(slug)
  return {
    title: post.title,
    description: post.excerpt,
    openGraph: { images: [post.coverImage] },
  }
}
```

### Pattern 8: Parallel routes

Render multiple pages simultaneously in the same layout using named slots.

```typescript
// app/dashboard/layout.tsx
export default function DashboardLayout({
  children,
  analytics,
  notifications,
}: {
  children: React.ReactNode
  analytics: React.ReactNode    // @analytics/page.tsx
  notifications: React.ReactNode // @notifications/page.tsx
}) {
  return (
    <div className="grid grid-cols-3">
      <main className="col-span-2">{children}</main>
      <aside>
        {analytics}
        {notifications}
      </aside>
    </div>
  )
}
```

### Pattern 9: Intercepting routes for modals

Show a modal on navigation but full page on direct URL access.

```
app/
  feed/
    page.tsx                    — /feed
    @modal/
      (..)photo/[id]/page.tsx   — intercepts /photo/[id] when navigating from /feed
  photo/
    [id]/
      page.tsx                  — /photo/[id] (direct access — full page)
```

### Pattern 10: Middleware

```typescript
// middleware.ts (project root)
import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

export function middleware(request: NextRequest) {
  const token = request.cookies.get('session')

  // Redirect unauthenticated users
  if (!token && request.nextUrl.pathname.startsWith('/dashboard')) {
    return NextResponse.redirect(new URL('/login', request.url))
  }

  return NextResponse.next()
}

export const config = {
  matcher: ['/dashboard/:path*', '/settings/:path*'],
}
```

```typescript
// ❌ BAD — heavy logic in middleware (it runs on EVERY matched request at the edge)
export function middleware(request: NextRequest) {
  const user = await db.users.findOne(...) // NO — can't do DB queries in edge middleware
  // Keep middleware thin: check cookies/headers, redirect, rewrite
}
```

### Pattern 11: loading.tsx and error.tsx segments

```typescript
// app/dashboard/loading.tsx
// Automatically wraps page.tsx in a Suspense boundary
export default function DashboardLoading() {
  return <DashboardSkeleton />
}
```

```typescript
// app/dashboard/error.tsx
// Must be a Client Component
'use client'

export default function DashboardError({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  return (
    <div>
      <h2>Something went wrong</h2>
      <p>{error.message}</p>
      <button onClick={reset}>Try again</button>
    </div>
  )
}
```

---

## Anti-Patterns

### Don't: Client-side fetch when Server Components can do it

```typescript
// ❌ BAD — useEffect fetch in a Client Component
'use client'
export function ProductList() {
  const [products, setProducts] = useState([])
  useEffect(() => {
    fetch('/api/products').then(r => r.json()).then(setProducts)
  }, [])
  return products.map(p => <ProductCard key={p.id} product={p} />)
}

// ✅ GOOD — Server Component fetches directly
export default async function ProductList() {
  const products = await getProducts()
  return products.map(p => <ProductCard key={p.id} product={p} />)
}
```

### Don't: `'use client'` at the page level

```typescript
// ❌ BAD — entire page is a Client Component
'use client'
export default function SettingsPage() { ... }

// ✅ GOOD — page is Server Component, only interactive parts are Client
export default async function SettingsPage() {
  const settings = await getSettings()
  return (
    <div>
      <h1>Settings</h1>
      <SettingsForm defaultValues={settings} /> {/* 'use client' */}
    </div>
  )
}
```

### Don't: Await sequential fetches without streaming

```typescript
// ❌ BAD — waterfall: total time = sum of all fetches
export default async function Page() {
  const user = await getUser()          // 1s
  const posts = await getPosts()        // 1s
  const comments = await getComments()  // 1s → total: 3s
}

// ✅ GOOD — parallel fetches
export default async function Page() {
  const [user, posts, comments] = await Promise.all([
    getUser(),
    getPosts(),
    getComments(),
  ]) // total: ~1s (max of all three)
}

// ✅ BETTER — Suspense streaming (each section renders independently)
export default function Page() {
  return (
    <>
      <Suspense fallback={<UserSkeleton />}><UserSection /></Suspense>
      <Suspense fallback={<PostsSkeleton />}><PostsSection /></Suspense>
    </>
  )
}
```

---

## Quick Reference

| Question                            | Decision                                      |
| ----------------------------------- | --------------------------------------------- |
| Needs state or event handlers?      | `'use client'`                                |
| Only displays data?                 | Server Component                              |
| Mutates data / form submission?     | Server Action                                 |
| Loading UX for a route?             | `loading.tsx` in the segment                  |
| Error boundary per route?           | `error.tsx` in the segment (must be 'use client') |
| Custom 404?                         | `not-found.tsx` + `notFound()` call           |
| SEO metadata?                       | `export metadata` or `generateMetadata()`     |
| Protect routes?                     | `middleware.ts` with matcher                  |
| Multiple panels in one layout?      | Parallel routes (`@slot`)                     |
| Modal on nav, full page on direct?  | Intercepting routes (`(.)`, `(..)`)           |
| Cache API response?                 | `fetch()` with `next: { revalidate, tags }`   |
| Invalidate after mutation?          | `revalidatePath()` or `revalidateTag()`       |
| External webhook / public API?      | Route Handler (`route.ts`)                    |
| Slow section in a page?             | Wrap in `<Suspense>` for streaming            |
