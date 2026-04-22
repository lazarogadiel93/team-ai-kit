# Pack: Backend Node.js

> Rules and conventions for backend developers on the team.

---

## Architecture Rules

- Layer separation: routes → controllers → services → repositories
- Business logic only in services, not in controllers or routes
- Repositories abstract database access (no raw SQL in services)
- Dependency injection over direct imports to facilitate testing
- Centralized error handling with error middleware
- Do not mix authentication logic with business logic
- Modules grouped by domain (user/, product/, order/)

## Code Quality Rules

### Strict TypeScript (NON-NEGOTIABLE)

- ZERO `any` — always type explicitly
- ZERO `unknown` as an escape hatch — use generics or discriminated unions
- All functions with explicit return types
- Non-null assertion (`!`) forbidden

### Conventions

- Descriptive names: `getUserById()`, not `getUser()`
- Pure functions in the domain layer — ~30 lines max
- Input validation with Zod at the entry boundary (controllers, handlers)
- Ordered imports: 1) node:*, 2) external, 3) internal

### Security

- Never log sensitive data (passwords, tokens, PII)
- Environment variables for configuration, never hardcode credentials
- Sanitize inputs before queries/operations

### Error Handling

- Explicit error handling — never silently swallow errors
- Domain errors with typed classes (`class NotFoundError extends Error`)
- Try/catch only at boundaries (controllers, handlers), not in every function

## Thinking Rules

- Design the API contract before implementation (API-first)
- Think about idempotency and error cases before the happy path
- Do not couple the transport layer (HTTP) with domain logic
- Validate inputs at the system boundary, not deep inside
- Think about data consistency under partial failures

## PROHIBITED

- Do not generate script or tooling files that were NOT requested
- Do not create files outside the scope of the task
- No `console.log` in production — use a structured logger
