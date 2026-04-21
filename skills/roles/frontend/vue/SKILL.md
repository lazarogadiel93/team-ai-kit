---
name: frontend-vue
description: >
  Vue.js development patterns: Composition API, composables, Pinia state management, Vue Router, SFC patterns.
  Trigger: When building Vue components, composables, stores, or configuring routing and state management.
globs:
  - "**/*.vue"
  - "**/composables/*.ts"
  - "**/stores/*.ts"
  - "**/vite.config.ts"
metadata:
  author: team-ai-kit
  version: "1.0"
---

## When to Use

- Building Vue 3 Single File Components (SFCs) with `<script setup>` syntax
- Creating reusable composables (`useXxx`) to extract and share stateful logic
- Setting up Pinia stores for global state management with the setup (composition) syntax
- Configuring Vue Router with typed routes, navigation guards, and lazy-loaded views
- Wiring up `defineProps`, `defineEmits`, `provide`/`inject` for component communication
- Working with reactivity primitives: `ref`, `reactive`, `computed`, `watch`, `watchEffect`

---

## Critical Patterns

### Pattern 1: Composition API with `<script setup>`

Use `<script setup>` for all new components. It removes boilerplate, enables automatic
component/directive registration, and provides compile-time optimizations.

**Reactivity primitives**

```vue
<script setup lang="ts">
import { ref, reactive, computed, watch } from 'vue'

// --- Refs for primitive/single values ---
const count = ref(0)
const label = ref('Clicks')

// --- Reactive for object state ---
const form = reactive({
  name: '',
  email: '',
})

// --- Computed (cached, auto-tracked) ---
const displayLabel = computed(() => `${label.value}: ${count.value}`)

// --- Watch a single ref ---
watch(count, (newVal, oldVal) => {
  console.log(`count changed: ${oldVal} -> ${newVal}`)
})

// --- Watch multiple sources ---
watch([count, label], ([newCount, newLabel]) => {
  console.log(newCount, newLabel)
})

function increment() {
  count.value++
}
</script>

<template>
  <button @click="increment">{{ displayLabel }}</button>
</template>
```

**Props and Emits (typed)**

```vue
<script setup lang="ts">
// --- Typed props with defaults ---
const props = withDefaults(
  defineProps<{
    title: string
    count?: number
    variant?: 'primary' | 'secondary'
  }>(),
  {
    count: 0,
    variant: 'primary',
  },
)

// --- Typed emits ---
const emit = defineEmits<{
  (e: 'update', value: number): void
  (e: 'close'): void
}>()

function handleClick() {
  emit('update', props.count + 1)
}
</script>

<template>
  <div :class="variant">
    <h2>{{ title }}</h2>
    <button @click="handleClick">Count: {{ count }}</button>
  </div>
</template>
```

**Provide / Inject (typed)**

```typescript
// keys.ts — shared injection key with type safety
import type { InjectionKey, Ref } from 'vue'

export const ThemeKey: InjectionKey<Ref<'light' | 'dark'>> = Symbol('theme')
```

```vue
<!-- Provider.vue -->
<script setup lang="ts">
import { provide, ref } from 'vue'
import { ThemeKey } from './keys'

const theme = ref<'light' | 'dark'>('light')
provide(ThemeKey, theme)
</script>
```

```vue
<!-- Consumer.vue -->
<script setup lang="ts">
import { inject } from 'vue'
import { ThemeKey } from './keys'

const theme = inject(ThemeKey) // Ref<'light' | 'dark'> | undefined
</script>

<template>
  <div :class="theme">Themed content</div>
</template>
```

---

### Pattern 2: Composables for Reusable Logic

Composables are functions prefixed with `use` that encapsulate reactive state and logic.
They return refs, computed values, and methods — never raw mutable objects.

```typescript
// composables/useFetch.ts
import { ref, shallowRef, type Ref } from 'vue'

interface UseFetchReturn<T> {
  data: Ref<T | null>
  error: Ref<string | null>
  isLoading: Ref<boolean>
  execute: () => Promise<void>
}

export function useFetch<T>(url: string | Ref<string>): UseFetchReturn<T> {
  const data = shallowRef<T | null>(null)
  const error = ref<string | null>(null)
  const isLoading = ref(false)

  async function execute() {
    isLoading.value = true
    error.value = null
    try {
      const resolvedUrl = typeof url === 'string' ? url : url.value
      const response = await fetch(resolvedUrl)
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      data.value = await response.json()
    } catch (e) {
      error.value = e instanceof Error ? e.message : 'Unknown error'
    } finally {
      isLoading.value = false
    }
  }

  execute()
  return { data, error, isLoading, execute }
}
```

```vue
<!-- Usage in component -->
<script setup lang="ts">
import { useFetch } from '@/composables/useFetch'

interface User {
  id: number
  name: string
}

const { data: users, isLoading, error } = useFetch<User[]>('/api/users')
</script>

<template>
  <p v-if="isLoading">Loading...</p>
  <p v-else-if="error">{{ error }}</p>
  <ul v-else>
    <li v-for="user in users" :key="user.id">{{ user.name }}</li>
  </ul>
</template>
```

**Composable rules:**
- Always prefix with `use`
- Return explicit refs and functions — never mutate external state directly
- Accept both raw values and refs as inputs (`MaybeRef<T>` pattern)
- Keep composables pure: no side effects in the function body except lifecycle hooks
- Use `shallowRef` for large non-primitive data that does not need deep reactivity

---

### Pattern 3: Pinia Stores with Setup Syntax

Use the **setup function** syntax for Pinia stores. It mirrors the Composition API directly:
`ref()` = state, `computed()` = getters, plain functions = actions.

```typescript
// stores/useAuthStore.ts
import { ref, computed } from 'vue'
import { defineStore } from 'pinia'

interface User {
  id: string
  email: string
  role: 'admin' | 'user'
}

export const useAuthStore = defineStore('auth', () => {
  // --- State (ref) ---
  const user = ref<User | null>(null)
  const token = ref<string | null>(null)

  // --- Getters (computed) ---
  const isAuthenticated = computed(() => !!token.value)
  const isAdmin = computed(() => user.value?.role === 'admin')

  // --- Actions (functions) ---
  async function login(email: string, password: string) {
    const res = await fetch('/api/login', {
      method: 'POST',
      body: JSON.stringify({ email, password }),
      headers: { 'Content-Type': 'application/json' },
    })
    if (!res.ok) throw new Error('Login failed')
    const data = await res.json()
    user.value = data.user
    token.value = data.token
  }

  function logout() {
    user.value = null
    token.value = null
  }

  return { user, token, isAuthenticated, isAdmin, login, logout }
})
```

```vue
<!-- Usage in component -->
<script setup lang="ts">
import { useAuthStore } from '@/stores/useAuthStore'
import { storeToRefs } from 'pinia'

const authStore = useAuthStore()

// Use storeToRefs to keep reactivity when destructuring state/getters
const { user, isAuthenticated } = storeToRefs(authStore)

// Actions can be destructured directly (they are plain functions)
const { login, logout } = authStore
</script>

<template>
  <div v-if="isAuthenticated">
    <p>Welcome, {{ user?.email }}</p>
    <button @click="logout">Logout</button>
  </div>
  <button v-else @click="login('test@example.com', 'pass')">Login</button>
</template>
```

**Store rules:**
- One store per domain concern (auth, cart, ui)
- Always use `storeToRefs()` when destructuring state or getters — direct destructuring loses reactivity
- Actions are plain functions; destructure them directly from the store instance
- Return ALL state from the setup function — Pinia cannot detect unreturned refs

---

### Pattern 4: Vue Router with Typed Routes and Navigation Guards

```typescript
// router/index.ts
import { createRouter, createWebHistory, type RouteRecordRaw } from 'vue-router'
import { useAuthStore } from '@/stores/useAuthStore'

const routes: RouteRecordRaw[] = [
  {
    path: '/',
    name: 'Home',
    component: () => import('@/views/HomeView.vue'),
  },
  {
    path: '/dashboard',
    name: 'Dashboard',
    component: () => import('@/views/DashboardView.vue'),
    meta: { requiresAuth: true },
  },
  {
    path: '/login',
    name: 'Login',
    component: () => import('@/views/LoginView.vue'),
  },
  {
    path: '/:pathMatch(.*)*',
    name: 'NotFound',
    component: () => import('@/views/NotFoundView.vue'),
  },
]

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes,
})

// Global navigation guard
router.beforeEach((to) => {
  const auth = useAuthStore()

  if (to.meta.requiresAuth && !auth.isAuthenticated) {
    return { name: 'Login', query: { redirect: to.fullPath } }
  }
})

export default router
```

**Augment route meta types globally:**

```typescript
// router/types.ts
import 'vue-router'

declare module 'vue-router' {
  interface RouteMeta {
    requiresAuth?: boolean
    roles?: Array<'admin' | 'user'>
  }
}
```

**Using router in components:**

```vue
<script setup lang="ts">
import { useRoute, useRouter } from 'vue-router'

const route = useRoute()
const router = useRouter()

// Access typed params and query
const id = route.params.id as string

async function goToDashboard() {
  await router.push({ name: 'Dashboard' })
}
</script>
```

**Per-route guard with `beforeEnter`:**

```typescript
{
  path: '/admin',
  name: 'Admin',
  component: () => import('@/views/AdminView.vue'),
  meta: { requiresAuth: true, roles: ['admin'] },
  beforeEnter: (to) => {
    const auth = useAuthStore()
    if (!auth.isAdmin) return { name: 'Home' }
  },
}
```

---

## Anti-Patterns

### Anti-Pattern 1: Options API in New Code

The Options API (`data`, `methods`, `computed` object syntax) fragments related logic
across multiple sections, making large components hard to follow and refactor.

```vue
<!-- ❌ BAD: Options API scatters related logic -->
<script lang="ts">
import { defineComponent } from 'vue'

export default defineComponent({
  data() {
    return { count: 0, label: 'Clicks' }
  },
  computed: {
    display(): string {
      return `${this.label}: ${this.count}`
    },
  },
  methods: {
    increment() {
      this.count++
    },
  },
})
</script>
```

```vue
<!-- ✅ GOOD: Composition API groups logic by concern -->
<script setup lang="ts">
import { ref, computed } from 'vue'

const count = ref(0)
const label = ref('Clicks')
const display = computed(() => `${label.value}: ${count.value}`)

function increment() {
  count.value++
}
</script>
```

**Why:** `<script setup>` + Composition API co-locates related state and logic, enables
full TypeScript inference without type gymnastics, and produces smaller compiled output.

---

### Anti-Pattern 2: Vuex in New Projects

Vuex requires verbose mutations/actions/getters boilerplate, has weak TypeScript support,
and does not align with the Composition API.

```typescript
// ❌ BAD: Vuex store — mutations, string-based commits, no type safety
const store = createStore({
  state: () => ({ count: 0 }),
  mutations: {
    INCREMENT(state) {
      state.count++
    },
  },
  actions: {
    increment({ commit }) {
      commit('INCREMENT') // string key, no type check
    },
  },
})
```

```typescript
// ✅ GOOD: Pinia setup store — typed, minimal, Composition API native
import { ref } from 'vue'
import { defineStore } from 'pinia'

export const useCounterStore = defineStore('counter', () => {
  const count = ref(0)
  function increment() {
    count.value++
  }
  return { count, increment }
})
```

**Why:** Pinia is the official Vue state management library (replacing Vuex). It has
first-class TypeScript support, no mutations concept, smaller bundle size, and uses
the same `ref`/`computed` patterns as your components.

---

## Quick Reference

| Concept            | API / Pattern                              | Notes                                             |
| ------------------ | ------------------------------------------ | ------------------------------------------------- |
| Component state    | `ref()`, `reactive()`                      | `ref` for primitives, `reactive` for objects       |
| Derived state      | `computed(() => ...)`                      | Cached, auto-tracked dependencies                  |
| Side effects       | `watch()`, `watchEffect()`                 | `watch` = explicit source; `watchEffect` = auto    |
| Props              | `defineProps<T>()`                         | Compile-time macro, no import needed               |
| Emits              | `defineEmits<T>()`                         | Type-safe event declarations                       |
| Dependency inject  | `provide(key, val)` / `inject(key)`        | Use typed `InjectionKey<T>` for safety             |
| Composable         | `function useXxx(): { refs, methods }`     | Return refs + functions, accept `MaybeRef` inputs  |
| Pinia store        | `defineStore('id', () => { ... })`         | Setup syntax; return all state                     |
| Store destructure  | `storeToRefs(store)`                       | Keeps reactivity on state/getters                  |
| Router access      | `useRoute()`, `useRouter()`                | Composables for route/router in `<script setup>`   |
| Route guard        | `router.beforeEach((to, from) => ...)`     | Return `false`, route object, or `undefined`       |
| Lazy routes        | `component: () => import('...')`           | Code-split views automatically                     |
| Route meta typing  | `declare module 'vue-router' { ... }`      | Augment `RouteMeta` interface globally             |
