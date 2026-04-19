---
name: devops-cicd
description: >
  Patrones de CI/CD, Dockerfiles, pipelines y deployment para Azure DevOps y herramientas comunes.
  Trigger: Al crear pipelines, escribir Dockerfiles, configurar deploys, definir stages de CI/CD.
metadata:
  author: team-ai-kit
  version: "1.0"
---

## When to Use

Carga este skill cuando:

- Creas o modificas pipelines de CI/CD (Azure Pipelines, GitHub Actions)
- Escribes o revisas Dockerfiles
- Configuras estrategias de deployment
- Diseñas la infraestructura de ambientes

---

## Critical Patterns

### Pattern 1: Pipeline con stages claras

```yaml
# azure-pipelines.yml
trigger:
  branches:
    include: [main, develop]

stages:
  - stage: Validate
    jobs:
      - job: Lint
        steps:
          - script: npm run lint
      - job: Test
        steps:
          - script: npm run test -- --coverage

  - stage: Build
    dependsOn: Validate
    jobs:
      - job: BuildImage
        steps:
          - script: docker build -t $(imageName):$(Build.BuildId) .

  - stage: Deploy
    dependsOn: Build
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
    jobs:
      - deployment: Production
        environment: production
        strategy:
          runOnce:
            deploy:
              steps:
                - script: echo "Deploy to production"
```

### Pattern 2: Dockerfile multi-stage

```dockerfile
# Stage 1: Build
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force
COPY . .
RUN npm run build

# Stage 2: Runtime (imagen mínima)
FROM node:20-alpine AS runtime
WORKDIR /app
RUN addgroup -g 1001 appgroup && adduser -u 1001 -G appgroup -s /bin/sh -D appuser
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./
USER appuser
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://localhost:3000/health || exit 1
CMD ["node", "dist/index.js"]
```

### Pattern 3: Secrets nunca en el repo

```yaml
# ✅ BIEN — variables de grupo o Azure Key Vault
variables:
  - group: production-secrets  # referencia a variable group en Azure DevOps

# ❌ MAL — secrets hardcoded
variables:
  DB_PASSWORD: 'my-secret-password'  # NUNCA hacer esto
```

### Pattern 4: Health checks obligatorios

```typescript
// health.ts — endpoint estándar
app.get('/health', (_req, res) => {
    res.json({
        status: 'ok',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
    })
})

app.get('/ready', async (_req, res) => {
    try {
        await db.$queryRaw`SELECT 1`  // verificar DB
        res.json({ status: 'ready' })
    } catch {
        res.status(503).json({ status: 'not ready' })
    }
})
```

---

## Anti-Patterns

### Don't: latest como tag de imagen

```dockerfile
# ❌ MAL — no reproducible
FROM node:latest

# ✅ BIEN — versión explícita
FROM node:20.11-alpine
```

### Don't: Pipeline sin fail-fast

```yaml
# ❌ MAL — sigue desplegando aunque los tests fallen
stages:
  - stage: Deploy
    # sin dependsOn ni condition

# ✅ BIEN — deploy solo si validate pasa
stages:
  - stage: Deploy
    dependsOn: Validate
    condition: succeeded()
```

---

## Quick Reference

| Situación                     | Acción                                             |
| ----------------------------- | -------------------------------------------------- |
| Secret necesario en pipeline  | Variable group o Key Vault, NUNCA en código        |
| Imagen Docker grande          | Multi-stage build + alpine base                    |
| Pipeline tarda mucho          | Paralelizar jobs independientes, cachear deps      |
| Deploy falló                  | Rollback automático + revisar health checks        |
| Nuevo ambiente                | Reproducir con IaC, no configurar manualmente      |
