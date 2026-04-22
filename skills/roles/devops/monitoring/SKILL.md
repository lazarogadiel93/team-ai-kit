---
name: devops-monitoring
description: >
  Observability patterns: structured logging, metrics, distributed tracing, alerting, and dashboard design for production services.
  Trigger: When configuring logging, metrics, alerts, or diagnosing production issues.
globs:
  - "**/monitoring/**"
  - "**/observability/**"
  - "**/logging/**"
  - "**/prometheus*"
  - "**/grafana/**"
  - "**/*telemetry*"
metadata:
  author: team-ai-kit
  version: "1.0"
---

## When to Use

Load this skill when:

- Configuring structured logging in an application
- Defining metrics, alerts, or SLOs
- Diagnosing production issues
- Setting up distributed tracing (OpenTelemetry)
- Designing observability dashboards
- Writing alerting rules or runbooks

---

## Critical Patterns

### Pattern 1: Structured Logging (JSON)

#### TypeScript (pino)

```typescript
// ❌ BAD — unstructured, unparseable by log aggregators
console.log('User created: ' + user.email)

// ✅ GOOD — structured JSON, parseable by any log system
import pino from 'pino'

const logger = pino({
    level: process.env.LOG_LEVEL || 'info',
    formatters: {
        level: (label) => ({ level: label }),
    },
    // Redact sensitive fields automatically
    redact: ['req.headers.authorization', 'password', 'token'],
})

logger.info({ userId: user.id, email: user.email }, 'User created')
// Output: {"level":"info","time":1234,"userId":"abc","email":"x@y.com","msg":"User created"}
```

#### Python (structlog)

```python
# ❌ BAD — print statements, no structure
print(f"User created: {user.email}")

# ✅ GOOD — structured logging with structlog
import structlog

structlog.configure(
    processors=[
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.add_log_level,
        structlog.processors.JSONRenderer(),
    ],
)

logger = structlog.get_logger()
logger.info("user_created", user_id=user.id, email=user.email)
# Output: {"event":"user_created","user_id":"abc","email":"x@y.com","level":"info","timestamp":"2024-..."}
```

### Pattern 2: Log Levels Strategy

Use consistent log levels across all services:

| Level   | When to Use                                        | Example                              |
| ------- | -------------------------------------------------- | ------------------------------------ |
| `fatal` | Process cannot continue, about to crash            | Database connection pool exhausted   |
| `error` | Operation failed, requires attention               | Payment processing failed            |
| `warn`  | Unexpected but recoverable, may need investigation | Retry attempt 3/5 for external API   |
| `info`  | Normal business events worth recording             | Order placed, user signed up         |
| `debug` | Detailed diagnostic info for troubleshooting       | Cache hit/miss, query timing         |
| `trace` | Very fine-grained, only in dev or targeted debug   | Function entry/exit, variable values |

```typescript
// ❌ BAD — everything at the same level
logger.info('Error processing payment')  // This is an error, not info
logger.error('User logged in')           // This is info, not error

// ✅ GOOD — correct levels with context
logger.error({ orderId, error: err.message, stack: err.stack }, 'Payment processing failed')
logger.info({ userId, method: 'oauth' }, 'User authenticated')
```

### Pattern 3: Request ID for Traceability

```typescript
// middleware/request-id.ts
import { randomUUID } from 'node:crypto'

export function requestId(req: Request, res: Response, next: NextFunction) {
    const id = (req.headers['x-request-id'] as string) || randomUUID()
    req.requestId = id
    res.setHeader('x-request-id', id)
    next()
}

// Include request ID in every log within that request
logger.info({ requestId: req.requestId, path: req.path }, 'Request received')
```

### Pattern 4: OpenTelemetry Setup (Traces + Metrics + Logs)

```typescript
// instrumentation.ts — load BEFORE any other imports
import { NodeSDK } from '@opentelemetry/sdk-node'
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http'
import { OTLPMetricExporter } from '@opentelemetry/exporter-metrics-otlp-http'
import { PeriodicExportingMetricReader } from '@opentelemetry/sdk-metrics'
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node'
import { Resource } from '@opentelemetry/resources'
import { ATTR_SERVICE_NAME, ATTR_SERVICE_VERSION } from '@opentelemetry/semantic-conventions'

const sdk = new NodeSDK({
    resource: new Resource({
        [ATTR_SERVICE_NAME]: 'my-service',
        [ATTR_SERVICE_VERSION]: '1.0.0',
    }),
    traceExporter: new OTLPTraceExporter({
        url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://localhost:4318/v1/traces',
    }),
    metricReader: new PeriodicExportingMetricReader({
        exporter: new OTLPMetricExporter(),
        exportIntervalMillis: 15000,
    }),
    instrumentations: [getNodeAutoInstrumentations()],
})

sdk.start()

// Graceful shutdown
process.on('SIGTERM', () => sdk.shutdown())
```

#### Python (OpenTelemetry)

```python
# otel_setup.py
from opentelemetry import trace, metrics
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource

resource = Resource.create({"service.name": "my-service", "service.version": "1.0.0"})

# Traces
provider = TracerProvider(resource=resource)
provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
trace.set_tracer_provider(provider)

tracer = trace.get_tracer(__name__)

# Usage
with tracer.start_as_current_span("process_order") as span:
    span.set_attribute("order.id", order_id)
    # ... business logic
```

### Pattern 5: Prometheus Metric Types

```typescript
import { Counter, Gauge, Histogram, Registry } from 'prom-client'

const register = new Registry()

// Counter — monotonically increasing (requests, errors)
const httpRequestsTotal = new Counter({
    name: 'http_requests_total',
    help: 'Total HTTP requests',
    labelNames: ['method', 'route', 'status'],
    registers: [register],
})

// Gauge — value that goes up and down (connections, queue size)
const activeConnections = new Gauge({
    name: 'active_connections',
    help: 'Number of active connections',
    registers: [register],
})

// Histogram — distribution of values (latency, request size)
const httpRequestDuration = new Histogram({
    name: 'http_request_duration_seconds',
    help: 'HTTP request duration in seconds',
    labelNames: ['method', 'route'],
    buckets: [0.01, 0.05, 0.1, 0.5, 1, 2, 5],
    registers: [register],
})

// Middleware to record metrics
app.use((req, res, next) => {
    const end = httpRequestDuration.startTimer({ method: req.method, route: req.path })
    res.on('finish', () => {
        end()
        httpRequestsTotal.inc({ method: req.method, route: req.path, status: res.statusCode })
    })
    next()
})

// Expose metrics endpoint for Prometheus scraping
app.get('/metrics', async (_req, res) => {
    res.set('Content-Type', register.contentType)
    res.end(await register.metrics())
})
```

### Pattern 6: RED Metrics (Rate, Errors, Duration)

For every service, measure these three things — they cover ~80% of production issues:

| Metric   | What It Measures              | Prometheus Example                          |
| -------- | ----------------------------- | ------------------------------------------- |
| Rate     | Requests per second           | `rate(http_requests_total[5m])`             |
| Errors   | Error percentage (4xx, 5xx)   | `rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m])` |
| Duration | Latency (p50, p95, p99)       | `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))` |

### Pattern 7: Alerting Rules

```yaml
# prometheus/alerts.yml
groups:
  - name: service-alerts
    rules:
      # ✅ GOOD — actionable, scoped, with clear threshold and window
      - alert: HighErrorRate
        expr: |
          rate(http_requests_total{status=~"5.."}[5m])
          / rate(http_requests_total[5m]) > 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Error rate above 5% for {{ $labels.service }}"
          runbook: "https://wiki.internal/runbooks/high-error-rate"

      - alert: HighLatencyP95
        expr: |
          histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 2
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "P95 latency above 2s for {{ $labels.service }}"

      # ❌ BAD — too generic, no context, no runbook
      - alert: HighCPU
        expr: node_cpu_seconds_total > 80
        annotations:
          summary: "CPU is high"
```

### Pattern 8: Actionable Alerts Checklist

Every alert MUST have:

1. **Clear condition** — what metric, what threshold, what time window
2. **Severity level** — critical (page someone) vs warning (check next business day)
3. **Runbook link** — step-by-step instructions for the on-call engineer
4. **Context in annotations** — which service, which environment, current value

```
✅ GOOD alert:
  "Error rate > 5% on POST /api/payments for 5 minutes in production"
  → Action: Check payment service logs, verify payment provider status
  → Runbook: https://wiki.internal/runbooks/payments-errors

❌ BAD alert:
  "CPU > 80%"
  → Too generic. CPU spikes during deployments are normal. No runbook.
```

### Pattern 9: SLI/SLO Basics

```
SLI (Service Level Indicator) — the metric you measure
  Example: "Percentage of requests completing in < 200ms"

SLO (Service Level Objective) — the target for that metric
  Example: "99.9% of requests complete in < 200ms over 30 days"

Error Budget = 1 - SLO
  Example: 0.1% of requests (roughly 43 minutes/month) can be slow
```

```yaml
# Example SLO definition (tracked in Prometheus/Grafana)
# SLI: latency
- record: sli:latency:success_rate
  expr: |
    sum(rate(http_request_duration_seconds_bucket{le="0.2"}[5m]))
    / sum(rate(http_request_duration_seconds_count[5m]))

# Alert when error budget is burning too fast
- alert: ErrorBudgetBurnRate
  expr: sli:latency:success_rate < 0.999
  for: 1h
  labels:
    severity: warning
```

### Pattern 10: Grafana Dashboard Patterns

Structure dashboards in layers:

1. **Service overview** — RED metrics for all services at a glance
2. **Service detail** — deep dive into one service (endpoints, dependencies, resources)
3. **Infrastructure** — nodes, pods, database, cache

```json
// Grafana dashboard panel example (JSON model snippet)
{
  "title": "Request Rate by Status",
  "type": "timeseries",
  "targets": [
    {
      "expr": "sum(rate(http_requests_total[5m])) by (status)",
      "legendFormat": "{{status}}"
    }
  ]
}
```

### Pattern 11: Distributed Tracing Context Propagation

```typescript
// When calling downstream services, propagate trace context
import { context, propagation } from '@opentelemetry/api'

async function callDownstream(url: string) {
    const headers: Record<string, string> = {}
    // Inject current trace context into outgoing headers
    propagation.inject(context.active(), headers)

    const response = await fetch(url, { headers })
    return response.json()
}
```

---

## Anti-Patterns

### Anti-Pattern 1: Log Sensitive Data

```typescript
// ❌ BAD — leaks credentials into log aggregator
logger.info({ password: user.password, token }, 'Auth attempt')

// ✅ GOOD — redact sensitive fields
logger.info({ userId: user.id, hasToken: !!token }, 'Auth attempt')
```

### Anti-Pattern 2: Use String Interpolation in Log Messages

```typescript
// ❌ BAD — prevents log aggregation (every message is unique)
logger.info(`User ${userId} placed order ${orderId}`)

// ✅ GOOD — static message + structured fields (aggregatable)
logger.info({ userId, orderId }, 'Order placed')
```

### Anti-Pattern 3: High-Cardinality Labels

```typescript
// ❌ BAD — userId as label creates millions of time series, kills Prometheus
const counter = new Counter({
    name: 'requests_total',
    labelNames: ['userId'],  // unbounded cardinality
})

// ✅ GOOD — bounded labels only
const counter = new Counter({
    name: 'requests_total',
    labelNames: ['method', 'route', 'status'],  // finite set of values
})
```

### Anti-Pattern 4: Alert on Symptoms Without Context

```
❌ BAD: Alert on "disk usage > 80%" with no follow-up
✅ GOOD: Alert on "disk usage > 80% AND growth rate suggests full in < 4h"
         with a runbook link explaining how to expand or clean up
```

### Anti-Pattern 5: Ignore Log Correlation

```typescript
// ❌ BAD — logs from different services can't be correlated
logger.info('Processing order')

// ✅ GOOD — include traceId, spanId, requestId for cross-service correlation
logger.info({
    traceId: span.spanContext().traceId,
    spanId: span.spanContext().spanId,
    requestId: req.requestId,
    orderId,
}, 'Processing order')
```

---

## Quick Reference

| Pillar      | Tools                                          |
| ----------- | ---------------------------------------------- |
| Logs        | Pino, structlog → ELK, Loki, Azure Monitor    |
| Metrics     | Prometheus, prom-client, Azure App Insights    |
| Traces      | OpenTelemetry, Jaeger, Zipkin, Tempo           |
| Alerts      | Grafana Alerts, Alertmanager, Azure Monitor    |
| Dashboards  | Grafana, Azure Dashboards, Datadog             |

| Situation                       | Action                                              |
| ------------------------------- | --------------------------------------------------- |
| Can't find a request across services | Add request ID middleware + propagate in headers |
| Prometheus OOM / high cardinality    | Audit labels — remove unbounded values (userId, IP) |
| Alert fatigue (too many alerts)      | Consolidate, increase thresholds, require runbooks  |
| No idea where latency comes from    | Add distributed tracing with OpenTelemetry          |
| Need to define reliability targets  | Start with SLI/SLO on the most critical endpoint    |
| Logs are unreadable                 | Switch to structured JSON logging (pino / structlog)|
| Metrics endpoint not working        | Expose `/metrics` with prom-client, verify scrape config |
