# Team AI Kit

> gentle-ai para equipos. Una capa sobre [gentle-ai](https://github.com/Gentleman-Programming/gentle-ai) que estandariza el uso de AI en equipos de desarrollo.

---

## El problema

[gentle-ai](https://github.com/Gentleman-Programming/gentle-ai) es excelente para el dev individual: SDD workflow, engram, persona, skills, context7. Pero cuando trabajas en equipo, faltan piezas:

- **Memoria compartida** -- cada dev tiene su propio engram aislado, lo que aprende uno no lo saben los demas
- **Onboarding estandarizado** -- cada dev configura (o no configura) su AI de manera diferente
- **Skills por rol** -- un dev Frontend necesita patrones distintos que un DevOps
- **Reglas de equipo** -- convenciones que todos deben seguir, no solo sugerencias

## La solucion

Team AI Kit agrega una capa de equipo sobre gentle-ai. Un comando, 3 preguntas, y todo tu equipo tiene la misma base de AI configurada con skills y reglas especificas para su rol.

---

## Arquitectura de 3 capas

```
+-------------------------------------------+
|  USER level (gentle-ai)                   |
|  SDD workflow, engram, persona, context7  |
+-------------------------------------------+
|  TEAM level (team-ai-kit)                 |
|  Role skills + pack rules + shared memory |
+-------------------------------------------+
|  PROJECT level (committed to each repo)   |
|  copilot-instructions.md + .engram/       |
+-------------------------------------------+
```

### Como se distribuye el conocimiento

```
Scoop package (team-ai-kit)            Azure DevOps: team-knowledge/
|  CLI tool + default skills            |  Skills custom del equipo
|  Se instala una vez por dev           |  Reglas cross-project
                                        |  Engram cross-project
         |                                       |
         +------------- merge ------+------------+
                                    |
                                    v
                           IDE del dev
                           ~/.copilot/skills/team-skills/
                           (defaults + team + custom)

Azure DevOps: frontend-app/           Azure DevOps: backend-api/
|  .engram/ (conocimiento FE)          |  .engram/ (conocimiento BE)
|  copilot-instructions.md             |  copilot-instructions.md
```

---

## Quick Start

### Opcion A: Instalar via Scoop (recomendado)

```powershell
# 1. Instalar
scoop bucket add gentleman https://github.com/Gentleman-Programming/scoop-bucket
scoop install team-ai-kit

# 2. Configurar
team-ai-kit setup
```

### Opcion B: Clonar y ejecutar (desarrollo/testing)

```powershell
git clone <tu-repo>/team-ai-kit
cd team-ai-kit
.\setup.ps1
```

### Que te pregunta

El setup te hace **3 preguntas** (VS Code / IntelliJ) o **4** (OpenCode):

1. **IDE** -- VS Code + Copilot, IntelliJ + Copilot, u OpenCode
2. **Rol** -- Frontend, Backend Node, DevOps, Python
3. **Provider** -- Solo OpenCode (Copilot IDEs auto-detectan `github-copilot`)

Despues, automaticamente:

- Instala Scoop, gentle-ai y engram si faltan
- Ejecuta `gentle-ai install` con la config optima para tu IDE
- Copia 5 skills compartidos + 2 skills de tu rol
- Genera instrucciones de Copilot con las reglas de tu equipo
- Guarda la configuracion en `~/.team-ai-kit/config.json`

**Tiempo total: ~2 minutos.**

---

## CLI: Comandos disponibles

```
team-ai-kit setup     Primera configuracion (IDE, rol, team repo)
team-ai-kit update    Pull del team repo + merge sin overwrite
team-ai-kit status    Mostrar config actual y skills instalados
team-ai-kit doctor    Verificar prerequisitos e instalacion
team-ai-kit help      Mostrar ayuda
```

### Setup: modo no interactivo

```powershell
# VS Code + Frontend (provider se auto-detecta como github-copilot)
team-ai-kit setup -Ide vscode -Role frontend

# IntelliJ + Backend
team-ai-kit setup -Ide intellij -Role backend-node

# OpenCode + DevOps (provider obligatorio)
team-ai-kit setup -Ide opencode -Role devops -Provider anthropic

# Con team repo
team-ai-kit setup -Ide vscode -Role frontend -TeamRepo https://dev.azure.com/equipo/team-knowledge

# Con directorio de salida custom (util para testing)
team-ai-kit setup -Ide vscode -Role frontend -TargetDir C:\temp\test-setup

# Saltear prerequisitos o gentle-ai
team-ai-kit setup -Ide vscode -Role frontend -SkipPrerequisites
team-ai-kit setup -Ide vscode -Role frontend -SkipGentleAi
```

### Parametros disponibles

| Parametro | Valores | Descripcion |
|-----------|---------|-------------|
| `-Ide` | `vscode`, `intellij`, `opencode` | IDE a configurar |
| `-Role` | `frontend`, `backend-node`, `devops`, `python` | Rol del desarrollador |
| `-Provider` | `openai`, `azure-openai`, `anthropic`, `github-copilot` | Proveedor AI (solo OpenCode) |
| `-TeamRepo` | URL | Repo de contenido del equipo |
| `-TargetDir` | ruta | Directorio de salida custom |
| `-SkipPrerequisites` | switch | No verificar/instalar Scoop, gentle-ai, engram |
| `-SkipGentleAi` | switch | No ejecutar `gentle-ai install` |
| `-Update` | switch | Actualizar gentle-ai via Scoop |

---

## Que hace el setup (5 pasos)

### Paso 1: Prerequisites

Verifica e instala si es necesario:
- **Scoop** -- package manager para Windows
- **gentle-ai** -- via `scoop bucket add gentleman` + `scoop install gentle-ai`
- **engram** -- verificacion (gentle-ai lo instala)

### Paso 2: IDE Selection

Determina donde instalar skills y que tipo de config generar.

### Paso 3: Role + Provider

- **VS Code / IntelliJ**: provider se auto-detecta como `github-copilot`
- **OpenCode**: pregunta el provider (acceso directo a la API)

### Paso 4: Base Configuration

| IDE | Accion |
|-----|--------|
| **VS Code** | `gentle-ai install --agent vscode-copilot --preset ecosystem-only --persona gentleman` |
| **OpenCode** | `gentle-ai install --agent opencode --preset ecosystem-only --persona gentleman` |
| **IntelliJ** | Genera config MCP desde template (gentle-ai no tiene adapter para IntelliJ) |

### Paso 5: Team Layer

1. Copia skills al directorio del IDE (5 compartidos + 2 del rol)
2. Genera instrucciones de proyecto con reglas del pack
3. Guarda la configuracion

---

## IDEs soportados

| IDE | gentle-ai | MCP (engram + context7) | Team Skills |
|-----|-----------|------------------------|-------------|
| **VS Code + Copilot** | Nativo (`vscode-copilot`) | Via gentle-ai | 7 skills |
| **IntelliJ + Copilot** | No soportado | Via template MCP | 7 skills |
| **OpenCode (CLI)** | Nativo (`opencode`) | Via gentle-ai | 7 skills |

> **IntelliJ**: gentle-ai no tiene adapter, pero IntelliJ SI soporta MCP servers. Team AI Kit genera la config MCP directamente.

---

## Roles y Skills

### Skills compartidos (todos los roles reciben estos 5)

| Skill | Descripcion | Trigger |
|-------|-------------|---------|
| **architecture** | Clean Architecture, estructura feature-based, dependencias entre capas | Al disenar estructura, definir modulos, revisar dependencias |
| **code-quality** | Patrones de calidad, naming, estructura | Al escribir o revisar codigo |
| **debug** | Debugging sistematico, analisis de errores, root cause | Al investigar bugs |
| **thinking** | Analisis cognitivo, problemas, alternativas | Al analizar o tomar decisiones |
| **performance** | Bundle, rendering, token economics | Al optimizar rendimiento |

### Skills por rol (2 adicionales segun tu perfil)

| Rol | Skills | Descripcion |
|-----|--------|-------------|
| **Frontend** | `react`, `nextjs` | Componentes, hooks, App Router, Server/Client split |
| **Backend Node** | `api-design`, `testing` | APIs REST/GraphQL, testing patterns |
| **DevOps** | `cicd`, `monitoring` | Pipelines CI/CD, observabilidad |
| **Python** | `api-design`, `testing` | FastAPI/Django, pytest |

### Pack Rules

Cada rol tiene reglas en `packs/<rol>/rules.md` que se inyectan en las instrucciones de Copilot:
- **frontend**: No cross-feature imports, CERO `any`, componentes presentacionales puros
- **backend-node**: API contracts, error handling, testing patterns
- **devops**: IaC conventions, pipeline patterns, monitoring standards
- **python**: PEP compliance, typing, FastAPI/Django patterns

---

## Conocimiento compartido del equipo

### Engram por proyecto (dia a dia)

Cada repo del equipo tiene su propio `.engram/`:

```
frontend-app/.engram/     Lo que el equipo aprende sobre ESTE proyecto
backend-api/.engram/      Lo que el equipo aprende sobre ESTE proyecto
```

```powershell
# Al terminar de trabajar: exportar lo aprendido
cd frontend-app
engram sync

# Al empezar: importar conocimiento del equipo
engram sync --import
```

### Engram cross-project (team knowledge repo)

Para decisiones que cruzan proyectos ("usamos Zustand", "naming convention para APIs"):

```
Azure DevOps: team-knowledge/
|-- skills/           Skills custom del equipo
|-- rules/            Reglas cross-project
+-- .engram/          Decisiones que aplican a TODOS los repos
```

El team repo es mantenido por los **funcionales** (tech leads, seniors, arquitectos). Los devs lo consumen via `team-ai-kit update`.

---

## Crear un skill nuevo

### Skill compartido (TODOS los roles)

Crear archivo en `skills/shared/<nombre>/SKILL.md`:

```markdown
---
name: nombre-del-skill
description: >
  Descripcion del skill.
  Trigger: Cuando debe cargarse este skill.
metadata:
  author: team-ai-kit
  version: "1.0"
---

## When to Use

Carga este skill cuando:
- Situacion 1
- Situacion 2

---

## Critical Patterns

### Pattern 1: Nombre del patron

Explicacion y ejemplos concretos.
```

### Skill de rol

Crear archivo en `skills/roles/<rol>/<nombre>.skill.md` (misma estructura).

### Requisitos (validados por tests)

- Frontmatter YAML: `name`, `description` (con Trigger), `metadata` (con `author` y `version`)
- Seccion `## When to Use`: obligatoria
- Seccion `## Critical Patterns`: obligatoria

### Validar

```powershell
Invoke-Pester tests/skills.Tests.ps1 -Output Detailed
```

---

## Crear un rol nuevo

1. Crear skills: `skills/roles/<nuevo-rol>/`
2. Crear pack rules: `packs/<nuevo-rol>/rules.md`
3. Agregar a validaciones en `lib/functions.ps1`:
   ```powershell
   $script:VALID_ROLES = @('frontend', 'backend-node', 'devops', 'python', 'nuevo-rol')
   ```
4. Agregar opcion en menu interactivo de `bin/team-ai-kit.ps1`
5. Actualizar tests

---

## Actualizar

```powershell
# Actualizar el tool + gentle-ai
scoop update team-ai-kit
team-ai-kit update

# O si clonaste el repo
git pull
.\setup.ps1 -Update
```

### Logica de update (merge sin overwrite)

```
Prioridad (gana el mas especifico):
  1. Lo que el dev modifico localmente     -> NUNCA se pisa
  2. Skills/rules del team repo            -> se agregan si son nuevos
  3. Defaults del package                  -> base, menor prioridad
```

---

## Desinstalar

```powershell
# Remover team skills
Remove-Item -Recurse -Force "$env:USERPROFILE\.copilot\skills\team-skills"    # VS Code/IntelliJ
Remove-Item -Recurse -Force "$env:USERPROFILE\.config\opencode\skills\team-skills"  # OpenCode

# Remover config
Remove-Item -Recurse -Force "$env:USERPROFILE\.team-ai-kit"

# Remover el tool
scoop uninstall team-ai-kit

# Remover gentle-ai + engram (opcional)
scoop uninstall gentle-ai
scoop uninstall engram
```

---

## Tests

```powershell
# Instalar Pester 5
Install-Module Pester -Force -SkipPublisherCheck

# Toda la suite (103 tests)
Invoke-Pester tests/ -Output Detailed

# Solo funciones (84 tests)
Invoke-Pester tests/functions.Tests.ps1 -Output Detailed

# Solo skills (19 tests)
Invoke-Pester tests/skills.Tests.ps1 -Output Detailed
```

---

## Estructura del proyecto

```
team-ai-kit/
|-- bin/
|   +-- team-ai-kit.ps1               CLI entry point (setup, update, status, doctor)
|-- lib/
|   +-- functions.ps1                  Funciones testables
|-- skills/
|   |-- shared/                        5 skills para TODOS los roles
|   |   |-- architecture/SKILL.md
|   |   |-- code-quality/SKILL.md
|   |   |-- debug/SKILL.md
|   |   |-- thinking/SKILL.md
|   |   +-- performance/SKILL.md
|   +-- roles/                         2 skills por rol
|       |-- frontend/                  react.skill.md, nextjs.skill.md
|       |-- backend-node/              api-design.skill.md, testing.skill.md
|       |-- devops/                    cicd.skill.md, monitoring.skill.md
|       +-- python/                    api-design.skill.md, testing.skill.md
|-- packs/                             Reglas del equipo por rol
|   |-- frontend/rules.md
|   |-- backend-node/rules.md
|   |-- devops/rules.md
|   +-- python/rules.md
|-- templates/                         Solo IntelliJ (gentle-ai no tiene adapter)
|   +-- intellij-copilot/
|       +-- mcp.json.template
|-- scoop/
|   +-- team-ai-kit.json              Scoop manifest
|-- tests/
|   |-- functions.Tests.ps1            84 tests
|   +-- skills.Tests.ps1              19 tests
|-- shared-engram/                     Dir para engram sync del equipo
|-- docs/
|   +-- onboarding.md                  Guia de onboarding
|-- setup.ps1                          Wrapper (backward compat -> bin/team-ai-kit.ps1)
+-- README.md                          Este archivo
```

### Config del usuario

```
~/.team-ai-kit/
+-- config.json                        IDE, rol, provider, team repo URL, timestamps
```

---

## Troubleshooting

### "gentle-ai no se encuentra"

```powershell
scoop bucket add gentleman https://github.com/Gentleman-Programming/scoop-bucket
scoop install gentle-ai
```

### "engram no se encuentra"

```powershell
Test-Path "$env:LOCALAPPDATA\engram\bin\engram.exe"
Test-Path "$env:USERPROFILE\scoop\shims\engram.exe"
```

### "Los skills no aparecen en mi IDE"

```powershell
# VS Code / IntelliJ
ls "$env:USERPROFILE\.copilot\skills\team-skills"

# OpenCode
ls "$env:USERPROFILE\.config\opencode\skills\team-skills"
```

### "IntelliJ no detecta MCP servers"

1. Verificar que el Copilot plugin esta actualizado
2. La config MCP se muestra durante el setup -- copiarla a la config de MCP de IntelliJ
3. Verificar engram: `engram --version`

### "team-ai-kit no se reconoce como comando"

```powershell
# Si instalaste via Scoop
scoop which team-ai-kit

# Si clonaste el repo, usar el script directamente
.\bin\team-ai-kit.ps1 help
```

### Verificar estado de la instalacion

```powershell
team-ai-kit doctor
```

---

## Requisitos

| Requisito | Version | Nota |
|-----------|---------|------|
| Windows | 10 / 11 | SO principal del equipo |
| PowerShell | 5.1+ | Incluido en Windows |
| Scoop | latest | El setup lo instala si falta |
| Git | latest | Para clonar y sincronizar |
| Tu IDE | VS Code, IntelliJ o OpenCode | Instalado por vos |

## Dependencias

| Dependencia | Que hace | Link |
|-------------|----------|------|
| **gentle-ai** | Plataforma AI para devs: SDD, persona, skills, backups | [GitHub](https://github.com/Gentleman-Programming/gentle-ai) |
| **engram** | Memoria persistente para AI agents via MCP | [GitHub](https://github.com/Gentleman-Programming/engram) |
| **context7** | Documentacion contextual de librerias via MCP | [Website](https://context7.com) |

---

## Roadmap

- [x] Phase 1: CLI entry point + config persistence + Scoop manifest
- [x] Phase 2: `--team-repo` support + git clone/pull + 3-layer merge logic
- [x] Phase 3: Hash tracking para no-overwrite inteligente en updates
- [ ] Phase 4: `setup.sh` para macOS/Linux

---

## Licencia

MIT
