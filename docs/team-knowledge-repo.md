# Team Knowledge Repo

> Un repositorio Git centralizado donde el Tech Lead define los skills, reglas y convenciones que todo el equipo recibe automaticamente.

## Que es

El Team Knowledge Repo es un repo Git (GitHub, Azure DevOps, GitLab -- cualquier remote) mantenido por el Tech Lead. Contiene:

- **Skills custom**: instrucciones que el AI carga segun el contexto
- **Reglas cross-proyecto**: convenciones que aplican a todos los proyectos del equipo
- **Skills por rol**: instrucciones especificas para Frontend, Backend, DevOps, etc.

Cuando un dev corre `team-ai-kit setup` y apunta a este repo, los skills y reglas se descargan e inyectan en su AI. Cuando el Tech Lead actualiza algo, los devs corren `team-ai-kit update` y reciben los cambios.

**Per-project support:** Si un dev trabaja en proyectos de equipos distintos, cada proyecto puede tener su propio team repo. Se configura con `--team-repo` en `init` o `setup`, y se guarda en el `.team-ai-kit.json` del proyecto.

---

## Estructura

```
team-knowledge/
├── skills/
│   ├── shared/                    # Skills para TODOS los roles
│   │   ├── logging/
│   │   │   └── SKILL.md           # Estandar de logging del equipo
│   │   ├── error-handling/
│   │   │   └── SKILL.md           # Manejo de errores custom
│   │   └── api-naming/
│   │       └── SKILL.md           # Convenciones de naming para APIs
│   └── roles/                     # Skills por rol especifico
│       ├── frontend/
│       │   └── design-system.skill.md
│       └── devops/
│           └── azure-pipelines.skill.md
└── rules/                         # Reglas cross-proyecto
    └── team-conventions.md
```

**`skills/shared/`** -- Skills que reciben TODOS los roles. Ejemplo: estandar de logging, error handling, naming conventions.

**`skills/roles/<rol>/`** -- Skills que solo recibe un rol especifico. Ejemplo: el frontend recibe `design-system.skill.md`, devops recibe `azure-pipelines.skill.md`.

**`rules/`** -- Reglas generales del equipo que se inyectan automaticamente en las instrucciones del proyecto (el archivo `copilot-instructions.md` o equivalente). Se envuelven en marcadores `<!-- team-ai-kit:team-rules -->` para poder actualizarse sin tocar el resto del archivo.

---

## Como funciona

### 1. Tech Lead crea el repo

Crea el repo y usa `init-knowledge` para generar la estructura:

```bash
# Crear el repo
mkdir team-knowledge && cd team-knowledge
git init

# Generar la estructura
team-ai-kit init-knowledge
```

Esto crea automaticamente:

```
team-knowledge/
├── skills/
│   ├── shared/
│   └── roles/
└── rules/
```

Ahora agrega el primer skill:

```markdown
# skills/shared/logging/SKILL.md
---
name: team-logging
description: >
  Estandar de logging del equipo. Pino + JSON estructurado + request ID.
  Trigger: Al escribir codigo que involucra logging, console.log, o manejo de errores.
metadata:
  author: equipo
  version: "1.0"
---

## When to Use

- Al crear o modificar logging en cualquier servicio
- Al configurar un nuevo proyecto
- Al revisar codigo con console.log

## Critical Patterns

### Pattern 1: Siempre JSON estructurado con pino

\```typescript
import pino from 'pino'
const logger = pino({ level: 'info' })

// ✅ BIEN -- JSON parseable, con contexto
logger.info({ userId: user.id, action: 'login' }, 'User authenticated')

// ❌ MAL -- no parseable, sin contexto
console.log('User logged in: ' + user.email)
\```

### Pattern 2: Request ID obligatorio

\```typescript
logger.info({ requestId: req.requestId, path: req.path }, 'Request received')
\```

### Pattern 3: Nunca loguear datos sensibles

\```typescript
// ❌ MAL
logger.info({ password: user.password, token }, 'Auth attempt')

// ✅ BIEN
logger.info({ userId: user.id, hasToken: !!token }, 'Auth attempt')
\```
```

### 2. Dev hace setup con el repo

```powershell
# Windows -- setup global
team-ai-kit setup -Ide vscode -Role frontend -TeamRepo https://dev.azure.com/equipo/team-knowledge
```

```bash
# macOS / Linux -- setup global
team-ai-kit setup --ide vscode --role frontend --team-repo https://github.com/equipo/team-knowledge
```

O si el dev ya hizo setup y quiere un team repo **solo para este proyecto**:

```bash
# Per-project team repo (init)
team-ai-kit init --team-repo https://github.com/otro-equipo/knowledge
```

Los skills y reglas del team repo se descargan e inyectan. El dev recibe:
- Skills compartidos del team repo (logging, error-handling, etc.)
- Skills de su rol especifico (design-system para frontend)
- Reglas cross-proyecto inyectadas en las instrucciones del AI
- Todo esto **ademas** de los skills base de team-ai-kit

**Nota:** Cada URL de team repo se clona en una ubicacion unica (`~/.team-ai-kit/team-content/<hash>/`), asi que diferentes proyectos con diferentes team repos no se pisan.

### 3. Updates sin romper nada

El Tech Lead agrega un nuevo skill o actualiza uno existente. Los devs:

```
team-ai-kit update
```

El update:
1. Hace pull del team repo
2. Detecta skills nuevos o actualizados
3. Los instala respetando las customizaciones locales del dev
4. **Actualiza automaticamente las reglas** en las instrucciones del proyecto (si el proyecto esta inicializado)

### 4. Nuevo integrante = 2 minutos

Un dev nuevo entra al equipo:

```
team-ai-kit setup
# Elige IDE: vscode
# Elige rol: backend-node
# Team repo: https://dev.azure.com/equipo/team-knowledge
```

En 2 minutos tiene toda la configuracion del equipo sin leer documentacion, sin pedir configs a companeros, sin perder una semana configurando su entorno.

---

## Prioridad de merge

Cuando corres `team-ai-kit update`, las capas se resuelven asi:

```
┌─────────────────────────────────────────────┐
│  🟢  Customizaciones locales del dev        │  ← NUNCA se pisa
│      Skills o reglas que el dev modifico     │
├─────────────────────────────────────────────┤
│  🔵  Team Knowledge Repo                    │  ← Se agregan si son nuevos,
│      Skills y reglas del Tech Lead          │    se actualizan si no fueron modificados
├─────────────────────────────────────────────┤
│  ⚪  Defaults del package                   │  ← Base, menor prioridad
│      Skills base incluidos en team-ai-kit   │
└─────────────────────────────────────────────┘
```

**Como funciona el tracking:**

- Cada archivo tiene un hash SHA256 guardado en `~/.team-ai-kit/manifest.json`
- Si el hash actual del archivo coincide con el hash del ultimo update → el dev no lo toco → se puede actualizar
- Si el hash cambio → el dev lo personalizo → **no se toca**

Esto significa que un dev puede modificar cualquier skill para adaptarlo a su flujo, y los updates del equipo nunca van a pisar esos cambios.

---

## Ejemplo real: estandarizar logging en el equipo

### Situacion

El Tech Lead detecta un problema: cada dev loguea diferente. Unos usan `console.log`, otros pino, otros winston. Los logs de produccion son imposibles de parsear y el equipo de DevOps no puede armar dashboards consistentes.

### Paso 1: Crear el skill

El Tech Lead crea `skills/shared/logging/SKILL.md` en el team-knowledge repo con las reglas: pino como logger, JSON estructurado, request ID obligatorio, nunca loguear datos sensibles.

### Paso 2: Push y aviso

```bash
cd team-knowledge
git add skills/shared/logging/SKILL.md
git commit -m "feat: add team logging standard skill"
git push
```

Avisa al equipo por Slack/Teams: "Nuevo skill de logging, corran `team-ai-kit update`".

### Paso 3: Devs actualizan

```
team-ai-kit update
# → Descarga skill: logging (nuevo)
# → Instalado en skills compartidos
```

### Resultado

A partir de ahora, cuando **cualquier dev** del equipo escribe codigo que involucra logging, el AI automaticamente aplica:
- pino como logger (no console.log, no winston)
- JSON estructurado
- Request ID en cada log
- Redaccion de datos sensibles

**Sin que el dev tenga que recordarlo.** El AI lo hace porque tiene el skill inyectado.

---

## Que se puede poner en el Team Knowledge Repo

| Tipo | Ejemplo | Ubicacion |
|------|---------|-----------|
| Estandar de logging | Pino + JSON + request ID | `skills/shared/logging/SKILL.md` |
| Error handling | Clases de error tipadas, middleware centralizado | `skills/shared/error-handling/SKILL.md` |
| Naming conventions | Endpoints REST, variables, archivos | `skills/shared/api-naming/SKILL.md` |
| Design system | Componentes, tokens, spacing | `skills/roles/frontend/design-system.skill.md` |
| Pipeline standards | Stages, secrets, tags de imagen | `skills/roles/devops/azure-pipelines.skill.md` |
| Testing patterns | Que testear, como structurar tests | `skills/roles/backend-node/testing-standards.skill.md` |
| Reglas generales | Idioma de commits, branch naming, PR format | `rules/team-conventions.md` |

La clave es que **cualquier convencion del equipo que hoy vive en un wiki, un documento de Confluence, o en la cabeza de alguien** se puede convertir en un skill que el AI aplica automaticamente.

---

← [Volver al README](../README.md)
