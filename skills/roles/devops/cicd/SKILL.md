---
name: devops-cicd
description: >
  CI/CD pipeline patterns: GitHub Actions, Azure Pipelines, Dockerfiles, deployment strategies, and environment management.
  Trigger: When creating pipelines, writing Dockerfiles, configuring deployments, or defining CI/CD stages.
globs:
  - "**/Dockerfile*"
  - "**/.github/workflows/**"
  - "**/azure-pipelines*.yml"
  - "**/docker-compose*.yml"
  - "**/.dockerignore"
metadata:
  author: team-ai-kit
  version: "1.0"
---

## When to Use

Load this skill when:

- Creating or modifying CI/CD pipelines (GitHub Actions, Azure Pipelines)
- Writing or reviewing Dockerfiles
- Configuring deployment strategies (blue-green, canary, rolling)
- Designing environment promotion workflows
- Setting up caching, artifacts, or matrix builds

---

## Critical Patterns

### Pattern 1: Pipeline with Clear Stages (Azure Pipelines)

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

### Pattern 2: Pipeline with Clear Stages (GitHub Actions)

```yaml
# .github/workflows/ci.yml
name: CI/CD
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'npm'
      - run: npm ci
      - run: npm run lint
      - run: npm run test -- --coverage

  build:
    needs: validate
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - uses: docker/build-push-action@v5
        with:
          context: .
          push: false
          tags: myapp:${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  deploy:
    needs: build
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: production
    steps:
      - run: echo "Deploy to production"
```

### Pattern 3: Multi-stage Dockerfile

```dockerfile
# Stage 1: Build
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force
COPY . .
RUN npm run build

# Stage 2: Runtime (minimal image)
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

### Pattern 4: Secrets — Never in the Repo

```yaml
# ✅ GOOD — Azure DevOps variable groups or Key Vault
variables:
  - group: production-secrets

# ✅ GOOD — GitHub Actions secrets
env:
  DB_PASSWORD: ${{ secrets.DB_PASSWORD }}

# ❌ BAD — hardcoded secrets
variables:
  DB_PASSWORD: 'my-secret-password'  # NEVER do this
```

### Pattern 5: Health Check Endpoints

```typescript
// health.ts — standard liveness and readiness probes
app.get('/health', (_req, res) => {
    res.json({
        status: 'ok',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
    })
})

app.get('/ready', async (_req, res) => {
    try {
        await db.$queryRaw`SELECT 1` // verify database connection
        res.json({ status: 'ready' })
    } catch {
        res.status(503).json({ status: 'not ready' })
    }
})
```

### Pattern 6: Caching Strategies

```yaml
# GitHub Actions — npm cache
- uses: actions/setup-node@v4
  with:
    node-version: 20
    cache: 'npm'

# GitHub Actions — Docker layer caching with BuildKit
- uses: docker/build-push-action@v5
  with:
    cache-from: type=gha
    cache-to: type=gha,mode=max

# Azure Pipelines — cache task
- task: Cache@2
  inputs:
    key: 'npm | "$(Agent.OS)" | package-lock.json'
    path: $(npm_config_cache)
    restoreKeys: |
      npm | "$(Agent.OS)"
```

### Pattern 7: Matrix Builds

```yaml
# GitHub Actions — test across multiple versions
jobs:
  test:
    strategy:
      fail-fast: true
      matrix:
        node-version: [18, 20, 22]
        os: [ubuntu-latest, windows-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
      - run: npm ci
      - run: npm test
```

### Pattern 8: Artifact Management

```yaml
# GitHub Actions — upload/download build artifacts
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci && npm run build
      - uses: actions/upload-artifact@v4
        with:
          name: dist
          path: dist/
          retention-days: 5

  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: dist
          path: dist/
      - run: echo "Deploy from artifact"
```

### Pattern 9: Container Registry Push

```yaml
# GitHub Actions — build and push to GHCR
jobs:
  publish:
    runs-on: ubuntu-latest
    permissions:
      packages: write
    steps:
      - uses: actions/checkout@v4
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - uses: docker/build-push-action@v5
        with:
          push: true
          tags: |
            ghcr.io/${{ github.repository }}:${{ github.sha }}
            ghcr.io/${{ github.repository }}:latest
```

### Pattern 10: Environment Promotion

```yaml
# GitHub Actions — staging → production with manual approval
jobs:
  deploy-staging:
    environment: staging
    runs-on: ubuntu-latest
    steps:
      - run: echo "Deploy to staging"

  deploy-production:
    needs: deploy-staging
    environment:
      name: production
      url: https://myapp.com
    runs-on: ubuntu-latest
    steps:
      - run: echo "Deploy to production"
```

Configure environment protection rules in GitHub Settings → Environments → production → Required reviewers.

### Pattern 11: Rollback Strategy

```yaml
# GitHub Actions — rollback on failure
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy new version
        id: deploy
        run: |
          kubectl set image deployment/myapp myapp=myapp:${{ github.sha }}
          kubectl rollout status deployment/myapp --timeout=120s

      - name: Rollback on failure
        if: failure() && steps.deploy.outcome == 'failure'
        run: |
          kubectl rollout undo deployment/myapp
          echo "::error::Deployment failed — rolled back to previous version"
```

---

## Anti-Patterns

### Anti-Pattern 1: Use `latest` as Image Tag

```dockerfile
# ❌ BAD — not reproducible, breaks caching
FROM node:latest

# ✅ GOOD — explicit version, deterministic builds
FROM node:20.11-alpine
```

### Anti-Pattern 2: Pipeline Without Fail-Fast

```yaml
# ❌ BAD — deploys even if tests fail
stages:
  - stage: Deploy
    # no dependsOn or condition

# ✅ GOOD — deploy only when validation passes
stages:
  - stage: Deploy
    dependsOn: Validate
    condition: succeeded()
```

### Anti-Pattern 3: Install Dev Dependencies in Production Image

```dockerfile
# ❌ BAD — image includes test/build tools
RUN npm install

# ✅ GOOD — production dependencies only
RUN npm ci --only=production
```

### Anti-Pattern 4: Run Containers as Root

```dockerfile
# ❌ BAD — runs as root (security risk)
CMD ["node", "dist/index.js"]

# ✅ GOOD — non-root user
RUN adduser -D appuser
USER appuser
CMD ["node", "dist/index.js"]
```

### Anti-Pattern 5: Skip .dockerignore

```
# .dockerignore — always include one
node_modules
.git
.env*
dist
*.md
coverage
.github
```

### Anti-Pattern 6: Hardcode Environment-Specific Values

```yaml
# ❌ BAD — environment baked into pipeline
- run: curl https://api.production.myapp.com/deploy

# ✅ GOOD — use environment variables
- run: curl ${{ vars.DEPLOY_URL }}/deploy
```

---

## Quick Reference

| Situation                      | Action                                                 |
| ------------------------------ | ------------------------------------------------------ |
| Secret needed in pipeline      | Variable group, Key Vault, or GitHub Secrets — NEVER in code |
| Docker image too large         | Multi-stage build + alpine base + .dockerignore        |
| Pipeline is slow               | Parallelize independent jobs, cache dependencies       |
| Deployment failed              | Automatic rollback + check health endpoints            |
| New environment needed         | Reproduce with IaC — never configure manually          |
| Need to test multiple versions | Matrix builds with `fail-fast: true`                   |
| Build artifacts needed later   | Upload/download artifacts between jobs                 |
| Push image to registry         | Authenticate → build → tag with SHA → push             |
| Promote across environments    | staging → manual approval → production                 |
| Rollback required              | `kubectl rollout undo` or redeploy previous SHA        |
