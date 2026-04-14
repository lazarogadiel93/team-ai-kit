# Pack: Backend Node.js

> Reglas y convenciones para desarrolladores backend del equipo.

---

## Architecture Rules

- Separación en capas: routes → controllers → services → repositories
- Lógica de negocio solo en services, no en controllers ni routes
- Repositories abstraen el acceso a base de datos (sin SQL crudo en services)
- Inyección de dependencias sobre imports directos para facilitar testing
- Error handling centralizado con middleware de errores
- No mezclar lógica de autenticación con lógica de negocio
- Módulos agrupados por dominio (user/, product/, order/)

## Code Quality Rules

### TypeScript Estricto (NO NEGOCIABLE)

- CERO `any` — siempre tipar explícitamente
- CERO `unknown` como escape — usar genéricos o discriminated unions
- Todas las funciones con tipos de retorno explícitos
- Non-null assertion (`!`) prohibido

### Convenciones

- Nombres descriptivos: `getUserById()`, no `getUser()`
- Funciones puras en la capa de dominio — máximo ~30 líneas
- Validación de inputs con Zod en el borde de entrada (controllers, handlers)
- Imports ordenados: 1) node:*, 2) externos, 3) internos

### Seguridad

- Nunca loguear datos sensibles (passwords, tokens, PII)
- Variables de entorno para configuración, nunca hardcodear credenciales
- Sanitizar inputs antes de queries/operaciones

### Error Handling

- Manejo explícito de errores — nunca swallow silencioso
- Errores de dominio con clases tipadas (`class NotFoundError extends Error`)
- Try/catch solo en boundaries (controllers, handlers), no en cada función

## Thinking Rules

- Diseñar la API contract antes de la implementación (API-first)
- Pensar en idempotencia y casos de error antes del happy path
- No acoplar el transporte (HTTP) con la lógica de dominio
- Validar inputs en el borde del sistema, no en el interior
- Pensar en consistencia de datos ante fallos parciales

## PROHIBIDO

- No generar archivos de scripts o tooling que NO se pidió
- No crear archivos fuera del scope de la tarea
- No `console.log` en producción — usar logger estructurado
