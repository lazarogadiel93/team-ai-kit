# Pack: Frontend (React / Next.js / Angular / Vue)

> Rules and conventions for frontend developers on the team.

---

## Architecture Rules

- No cross-feature imports: each feature is a closed module
- Each feature must be completely independent
- Strict separation between server and client logic (minimal use client)
- Avoid business logic in UI components
- Presentational components without side effects
- Custom hooks to encapsulate reusable logic
- Barrel exports (index.ts) per feature to control the public API
- Colocate state as close as possible to where it's used

## Code Quality Rules

### Strict TypeScript (NON-NEGOTIABLE)

- ZERO `any` — always type explicitly
- ZERO `unknown` as an escape hatch — use generics or discriminated unions
- All functions with explicit return types
- Interfaces for data objects, `type` for unions/intersections
- Enums: prefer `as const` objects over `enum`
- Non-null assertion (`!`) forbidden — use optional chaining or type guards

### Conventions

- Descriptive names required: `getUserById()`, not `getUser()`
- Small, pure functions — ~30 lines max
- Ordered imports: 1) external, 2) internal absolute (@/), 3) relative
- One export per file when it's the main component/hook

### React / UI

- Props typed with dedicated interfaces
- Unique and stable keys in lists (never array index)
- useMemo/useCallback only with evidence of a real problem
- Components: UI and binding only. Logic in hooks or services
- Typed event handlers

### Validation

- Zod for form and API data validation
- Schemas co-located with the feature that uses them

## Next.js Rules

- Prefer Server Components by default
- Minimize `use client`: only when state or events are needed
- Use Server Actions for mutations
- Avoid client-side fetch if it can be done on the server
- loading.tsx and error.tsx for per-segment UX
- cache() to deduplicate fetches within the same request

## Thinking Rules

- Question the problem before proposing a solution
- Avoid complex solutions if a simple one exists
- Prioritize validation speed over perfection
- Don't abstract without at least 2 real use cases
- UX first, technical implementation second
- Prefer composition over inheritance

## PROHIBITED

- Do not generate script or tooling files that were NOT requested
- Do not create files outside the scope of the task
- No `console.log` in production
- Do not hardcode magic strings
