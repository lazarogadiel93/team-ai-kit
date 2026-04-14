# Pack: Frontend (React / Next.js)

> Reglas y convenciones para desarrolladores frontend del equipo.

---

## Architecture Rules

- No cross-feature imports: cada feature es un módulo cerrado
- Cada feature debe ser completamente independiente
- Separación estricta entre lógica de servidor y cliente (use client mínimo)
- Evitar lógica de negocio en componentes UI
- Componentes presentacionales sin efectos secundarios
- Custom hooks para encapsular lógica reutilizable
- Barrel exports (index.ts) por feature para controlar la API pública
- Colocar estado lo más cerca posible de donde se usa

## Code Quality Rules

### TypeScript Estricto (NO NEGOCIABLE)

- CERO `any` — siempre tipar explícitamente
- CERO `unknown` como escape — usar genéricos o discriminated unions
- Todas las funciones con tipos de retorno explícitos
- Interfaces para objetos de datos, `type` para uniones/intersecciones
- Enums: preferir `as const` objects sobre `enum`
- Non-null assertion (`!`) prohibido — usar optional chaining o type guards

### Convenciones

- Nombres descriptivos obligatorios: `getUserById()`, no `getUser()`
- Funciones pequeñas y puras — máximo ~30 líneas
- Imports ordenados: 1) externos, 2) internos absolutos (@/), 3) relativos
- Un export por archivo cuando es componente/hook principal

### React / UI

- Props tipadas con interfaces dedicadas
- Keys únicas y estables en listas (nunca índice del array)
- useMemo/useCallback solo con evidencia de problema real
- Componentes: solo UI y binding. Lógica en hooks o services
- Event handlers tipados

### Validación

- Zod para validación de forms y datos de API
- Schemas co-localizados con la feature que los usa

## Next.js Rules

- Preferir Server Components por defecto
- Minimizar `use client`: solo cuando se necesita estado o eventos
- Usar Server Actions para mutaciones
- Evitar fetch en cliente si puede hacerse en servidor
- loading.tsx y error.tsx para UX por segmento
- cache() para deduplicar fetches en el mismo request

## Thinking Rules

- Cuestionar el problema antes de proponer solución
- Evitar soluciones complejas si existe una simple
- Priorizar velocidad de validación sobre perfección
- No abstraer sin al menos 2 casos reales
- UX primero, implementación técnica después
- Preferir composición sobre herencia

## PROHIBIDO

- No generar archivos de scripts o tooling que NO se pidió
- No crear archivos fuera del scope de la tarea
- No `console.log` en producción
- No hardcodear strings mágicos
