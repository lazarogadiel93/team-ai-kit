---
name: devops-monitoring
description: >
  Patrones de observabilidad, logging estructurado y alertas para servicios en producción.
  Trigger: Al configurar logging, métricas, alertas, o diagnosticar problemas en producción.
metadata:
  author: team-ai-kit
  version: "1.0"
---

## When to Use

Carga este skill cuando:

- Configuras logging en una aplicación
- Defines métricas y alertas
- Diagnosticas problemas en producción
- Diseñas dashboards de observabilidad

---

## Critical Patterns

### Pattern 1: Logging estructurado (JSON)

```typescript
// ❌ MAL — logs no parseables
console.log('User created: ' + user.email)

// ✅ BIEN — JSON estructurado, parseable por cualquier sistema
import pino from 'pino'

const logger = pino({ level: 'info' })

logger.info({ userId: user.id, email: user.email }, 'User created')
// Output: {"level":30,"time":1234,"userId":"abc","email":"x@y.com","msg":"User created"}
```

### Pattern 2: Request ID para trazabilidad

```typescript
// middleware/request-id.ts
import { randomUUID } from 'node:crypto'

export function requestId(req: Request, res: Response, next: NextFunction) {
    const id = req.headers['x-request-id'] as string || randomUUID()
    req.requestId = id
    res.setHeader('x-request-id', id)
    next()
}

// En cada log incluir el request ID
logger.info({ requestId: req.requestId, path: req.path }, 'Request received')
```

### Pattern 3: Métricas RED (Rate, Errors, Duration)

```
Para cada servicio, medir:
- Rate:     requests por segundo
- Errors:   porcentaje de errores (4xx, 5xx)
- Duration: latencia (p50, p95, p99)

Estas tres métricas cubren el 80% de los problemas en producción.
```

### Pattern 4: Alertas accionables

```
✅ BUENA alerta:
  "Error rate > 5% en /api/payments durante 5 minutos"
  → Acción clara: revisar logs de payments, verificar dependencia de pago

❌ MALA alerta:
  "CPU > 80%"
  → Demasiado genérica, puede no ser un problema real
```

---

## Anti-Patterns

### Don't: Loguear datos sensibles

```typescript
// ❌ MAL
logger.info({ password: user.password, token }, 'Auth attempt')

// ✅ BIEN — redactar datos sensibles
logger.info({ userId: user.id, hasToken: !!token }, 'Auth attempt')
```

---

## Quick Reference

| Pilar           | Herramientas comunes                    |
| --------------- | --------------------------------------- |
| Logs            | Pino, Winston → ELK, Azure Monitor     |
| Métricas        | Prometheus, Azure App Insights          |
| Traces          | OpenTelemetry, Jaeger, Zipkin           |
| Alertas         | Grafana Alerts, Azure Monitor Alerts    |
| Dashboards      | Grafana, Azure Dashboards               |
