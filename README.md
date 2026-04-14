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

---

## Quick Start

```powershell
# 1. Clonar el kit
git clone <tu-repo>/team-ai-kit
cd team-ai-kit

# 2. Ejecutar el setup
.\setup.ps1
```

El setup te hace **3 preguntas** (para VS Code / IntelliJ) o **4** (para OpenCode):

1. **IDE** -- VS Code + Copilot, IntelliJ + Copilot, u OpenCode
2. **Rol** -- Frontend, Backend Node, DevOps, Python
3. **Provider** -- Solo OpenCode (Copilot IDEs auto-detectan `github-copilot`)

Despues, automaticamente:

- Instala Scoop, gentle-ai y engram si faltan
- Ejecuta `gentle-ai install` con la config optima para tu IDE
- Copia 5 skills compartidos + 2 skills de tu rol
- Genera instrucciones de Copilot con las reglas de tu equipo

**Tiempo total: ~2 minutos.**

---

## Modo no interactivo

Para CI/CD, scripting o cuando ya sabes lo que queres:

```powershell
# VS Code + Frontend (provider se auto-detecta como github-copilot)
.\setup.ps1 -Ide vscode -Role frontend

# IntelliJ + Backend (provider se auto-detecta como github-copilot)
.\setup.ps1 -Ide intellij -Role backend-node

# OpenCode + DevOps (provider obligatorio)
.\setup.ps1 -Ide opencode -Role devops -Provider anthropic

# Con directorio de salida custom (util para testing)
.\setup.ps1 -Ide vscode -Role frontend -TargetDir C:\temp\test-setup

# Saltear prerequisitos (si ya tenes todo instalado)
.\setup.ps1 -Ide vscode -Role frontend -SkipPrerequisites

# Saltear gentle-ai install (solo instalar team layer)
.\setup.ps1 -Ide vscode -Role frontend -SkipGentleAi
```

### Parametros disponibles

| Parametro | Valores | Descripcion |
|-----------|---------|-------------|
| `-Ide` | `vscode`, `intellij`, `opencode` | IDE a configurar |
| `-Role` | `frontend`, `backend-node`, `devops`, `python` | Rol del desarrollador |
| `-Provider` | `openai`, `azure-openai`, `anthropic`, `github-copilot` | Proveedor de AI (solo OpenCode) |
| `-TargetDir` | ruta | Directorio de salida custom |
| `-SkipPrerequisites` | switch | No verificar/instalar Scoop, gentle-ai, engram |
| `-SkipGentleAi` | switch | No ejecutar `gentle-ai install` |
| `-Update` | switch | Actualizar gentle-ai a la ultima version via Scoop |

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

- **VS Code / IntelliJ**: provider se auto-detecta como `github-copilot` (Copilot maneja el LLM via la suscripcion de GitHub)
- **OpenCode**: pregunta el provider (acceso directo a la API)

### Paso 4: Base Configuration

Depende del IDE elegido:

| IDE | Accion |
|-----|--------|
| **VS Code** | `gentle-ai install --agent vscode-copilot --preset ecosystem-only --persona gentleman` |
| **OpenCode** | `gentle-ai install --agent opencode --preset ecosystem-only --persona gentleman` |
| **IntelliJ** | Genera config MCP desde template (gentle-ai no tiene adapter para IntelliJ) |

El preset `ecosystem-only` instala: engram, SDD workflow, skills, context7, persona -- sin modificar configs existentes.

### Paso 5: Team Layer

1. **Copia skills** al directorio del IDE:
   - VS Code / IntelliJ: `~/.copilot/skills/team-skills/`
   - OpenCode: `~/.config/opencode/skills/team-skills/`
2. **Genera instrucciones de proyecto** con las reglas del pack del rol

---

## IDEs soportados

| IDE | gentle-ai | MCP (engram + context7) | Team Skills |
|-----|-----------|------------------------|-------------|
| **VS Code + Copilot** | Nativo (`vscode-copilot`) | Via gentle-ai | 7 skills |
| **IntelliJ + Copilot** | No soportado | Via template MCP | 7 skills |
| **OpenCode (CLI)** | Nativo (`opencode`) | Via gentle-ai | 7 skills |

> **IntelliJ**: gentle-ai no tiene adapter, pero IntelliJ SI soporta MCP servers. Team AI Kit genera la config MCP directamente desde un template que configura engram y context7.

---

## Roles y Skills

### Skills compartidos (todos los roles reciben estos 5)

| Skill | Descripcion | Trigger |
|-------|-------------|---------|
| **architecture** | Clean Architecture, estructura feature-based, dependencias entre capas | Al disenar estructura, definir modulos, revisar dependencias |
| **code-quality** | Patrones de calidad de codigo, naming, estructura | Al escribir o revisar codigo |
| **debug** | Debugging sistematico, analisis de errores, root cause | Al investigar bugs o errores |
| **thinking** | Analisis cognitivo, definicion de problemas, alternativas | Al analizar un problema o tomar decisiones |
| **performance** | Optimizacion de bundle, rendering, token economics | Al optimizar rendimiento |

### Skills por rol (2 adicionales segun tu perfil)

| Rol | Skills | Descripcion |
|-----|--------|-------------|
| **Frontend** | `react`, `nextjs` | Componentes, hooks, App Router, Server/Client split |
| **Backend Node** | `api-design`, `testing` | Diseno de APIs REST/GraphQL, testing patterns |
| **DevOps** | `cicd`, `monitoring` | Pipelines CI/CD, observabilidad, alertas |
| **Python** | `api-design`, `testing` | FastAPI/Django patterns, pytest, testing strategies |

### Pack Rules

Cada rol tiene un archivo de reglas en `packs/<rol>/rules.md` que se inyecta automaticamente en las instrucciones de Copilot. Estas son las convenciones del equipo que el AI debe seguir SIEMPRE.

Ejemplo (frontend):
- No cross-feature imports
- CERO `any` en TypeScript
- Componentes presentacionales sin efectos secundarios
- Barrel exports por feature

---

## Engram: Memoria compartida del equipo

La propuesta de valor mas importante: **lo que aprende UN dev, lo saben TODOS**.

### Como funciona

Cada dev tiene su propio engram local. Para compartir conocimiento con el equipo:

```powershell
# Despues de una sesion de trabajo, exportar tu conocimiento
engram sync

# Al empezar a trabajar, importar conocimiento del equipo
engram sync --import
```

### Setup del repo compartido

El equipo necesita un repo (Azure DevOps, GitHub, etc.) para sincronizar engram:

```powershell
# Configurar el repo de sync (una sola vez)
engram sync --repo <url-del-repo>/shared-engram
```

> **Tip**: Podes automatizar el sync con pipelines de Azure DevOps para que se ejecute periodicamente.

### Que se comparte

- Decisiones de arquitectura
- Bug fixes con root cause
- Descubrimientos no obvios
- Patrones y convenciones
- Gotchas y edge cases

---

## Instrucciones de proyecto

El setup genera contenido para `copilot-instructions.md` (VS Code / IntelliJ) o `AGENTS.md` (OpenCode). Este archivo se commitea a cada repo del equipo.

Las instrucciones incluyen:
- Convenciones del equipo
- Reglas del pack del rol
- Directivas para usar engram

```powershell
# El contenido se muestra en la consola durante el setup.
# Copialo a tu repo en: .github/copilot-instructions.md
```

---

## Crear un skill nuevo

### Skill compartido (para TODOS los roles)

1. Crear carpeta y archivo:

```
skills/shared/<nombre>/SKILL.md
```

2. Usar esta estructura:

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

3. Validar con tests:

```powershell
Invoke-Pester tests/skills.Tests.ps1 -Output Detailed
```

4. Commit, push. Los demas lo obtienen con `git pull` + `.\setup.ps1`.

### Skill de rol (para un rol especifico)

Mismo proceso, pero el archivo va en:

```
skills/roles/<rol>/<nombre>.skill.md
```

### Requisitos del skill (validados por tests)

- **Frontmatter YAML**: `name`, `description` (con Trigger), `metadata` (con `author` y `version`)
- **Seccion `## When to Use`**: obligatoria
- **Seccion `## Critical Patterns`**: obligatoria

---

## Crear un rol nuevo

1. Crear la carpeta de skills:

```
skills/roles/<nuevo-rol>/
```

2. Agregar al menos un skill (archivo `.skill.md` o carpeta con `SKILL.md`)

3. Crear las pack rules:

```
packs/<nuevo-rol>/rules.md
```

4. Agregar el rol a las validaciones en `lib/functions.ps1`:

```powershell
$script:VALID_ROLES = @('frontend', 'backend-node', 'devops', 'python', 'nuevo-rol')
```

5. Agregar la opcion en el menu interactivo de `setup.ps1`

6. Actualizar los tests en `tests/functions.Tests.ps1`

---

## Actualizar el kit

```powershell
cd team-ai-kit
git pull
.\setup.ps1 -Update
```

El flag `-Update` ademas actualiza `gentle-ai` a la ultima version via Scoop.

Si solo queres reinstalar el team layer sin tocar gentle-ai:

```powershell
.\setup.ps1 -SkipPrerequisites -SkipGentleAi
```

---

## Desinstalar

### Remover team skills

```powershell
# VS Code / IntelliJ
Remove-Item -Recurse -Force "$env:USERPROFILE\.copilot\skills\team-skills"

# OpenCode
Remove-Item -Recurse -Force "$env:USERPROFILE\.config\opencode\skills\team-skills"
```

### Remover gentle-ai + engram

```powershell
scoop uninstall gentle-ai
scoop uninstall engram
```

### Remover instrucciones de proyecto

Eliminar `.github/copilot-instructions.md` (o `AGENTS.md`) de tus repos.

---

## Tests

El proyecto usa [Pester 5](https://pester.dev) para testing.

```powershell
# Instalar Pester 5 (si no lo tenes)
Install-Module Pester -Force -SkipPublisherCheck

# Correr toda la suite (90 tests)
Invoke-Pester tests/ -Output Detailed

# Solo tests de funciones (71 tests)
Invoke-Pester tests/functions.Tests.ps1 -Output Detailed

# Solo validacion de skills (19 tests)
Invoke-Pester tests/skills.Tests.ps1 -Output Detailed
```

### Que se testea

- **functions.Tests.ps1**: Validaciones de IDE/Role/Provider, skills management, IDE config paths, template engine, MCP config generation, gentle-ai agent mapping, instrucciones, summary
- **skills.Tests.ps1**: Estructura de archivos, frontmatter YAML, secciones obligatorias (When to Use, Critical Patterns), metadata requerida

---

## Estructura del proyecto

```
team-ai-kit/
|-- setup.ps1                          # Entry point (5 steps)
|-- lib/
|   +-- functions.ps1                  # Funciones testables
|-- skills/
|   |-- shared/                        # 5 skills para TODOS los roles
|   |   |-- architecture/SKILL.md
|   |   |-- code-quality/SKILL.md
|   |   |-- debug/SKILL.md
|   |   |-- thinking/SKILL.md
|   |   +-- performance/SKILL.md
|   +-- roles/                         # 2 skills por rol
|       |-- frontend/                  # react.skill.md, nextjs.skill.md
|       |-- backend-node/              # api-design.skill.md, testing.skill.md
|       |-- devops/                    # cicd.skill.md, monitoring.skill.md
|       +-- python/                    # api-design.skill.md, testing.skill.md
|-- packs/                             # Reglas del equipo por rol
|   |-- frontend/rules.md
|   |-- backend-node/rules.md
|   |-- devops/rules.md
|   +-- python/rules.md
|-- templates/                         # Solo IntelliJ (gentle-ai no tiene adapter)
|   +-- intellij-copilot/
|       +-- mcp.json.template
|-- shared-engram/                     # Dir para engram sync del equipo
|   +-- .engram/
|-- tests/                             # Pester 5 tests
|   |-- functions.Tests.ps1            # 71 tests
|   +-- skills.Tests.ps1              # 19 tests
|-- docs/
|   +-- onboarding.md                  # Guia de onboarding completa
|-- CONTEXT.md                         # Decisiones de diseno y arquitectura
+-- README.md                          # Este archivo
```

---

## Troubleshooting

### "gentle-ai no se encuentra"

```powershell
scoop bucket add gentleman https://github.com/Gentleman-Programming/scoop-bucket
scoop install gentle-ai
```

### "engram no se encuentra"

Engram se instala con gentle-ai. Si no aparece:

```powershell
# Verificar si esta en AppData
Test-Path "$env:LOCALAPPDATA\engram\bin\engram.exe"

# Verificar si esta en Scoop
Test-Path "$env:USERPROFILE\scoop\shims\engram.exe"
```

### "Los skills no aparecen en mi IDE"

Verificar que la carpeta de destino es correcta:

```powershell
# VS Code / IntelliJ
ls "$env:USERPROFILE\.copilot\skills\team-skills"

# OpenCode
ls "$env:USERPROFILE\.config\opencode\skills\team-skills"
```

### "IntelliJ no detecta MCP servers"

1. Verificar que IntelliJ Copilot plugin esta actualizado
2. La config MCP se muestra en la consola durante el setup -- copiarla manualmente a la configuracion de MCP de IntelliJ
3. Verificar que engram esta corriendo: `engram --version`

### "Los tests fallan"

```powershell
# Asegurar Pester 5+
Get-Module Pester -ListAvailable | Select-Object Version

# Correr con output detallado
Invoke-Pester tests/ -Output Detailed
```

### PowerShell 5.1 y encoding

Si ves caracteres raros como `a]"` en la consola, es un problema de encoding. Todos los archivos `.ps1` y `.template` del proyecto usan ASCII puro para evitar este problema. Si creas archivos nuevos, asegurate de usar solo caracteres ASCII.

---

## Requisitos

| Requisito | Version | Nota |
|-----------|---------|------|
| Windows | 10 / 11 | SO principal del equipo |
| PowerShell | 5.1+ | Incluido en Windows |
| Scoop | latest | El setup lo instala si falta |
| Git | latest | Para clonar y sincronizar |
| Tu IDE | VS Code, IntelliJ o OpenCode | Instalado por vos |

---

## Dependencias

| Dependencia | Que hace | Link |
|-------------|----------|------|
| **gentle-ai** | Plataforma AI para devs: SDD workflow, persona, skills, backups | [GitHub](https://github.com/Gentleman-Programming/gentle-ai) |
| **engram** | Memoria persistente para AI agents via MCP | [GitHub](https://github.com/Gentleman-Programming/engram) |
| **context7** | Documentacion contextual de librerias via MCP | [Website](https://context7.com) |

---

## Arquitectura: Path B (Hybrid)

Team AI Kit **no reemplaza** a gentle-ai. Se para encima.

- **gentle-ai** maneja: configs de IDE, SDD, engram MCP, persona, context7, skills del ecosistema
- **team-ai-kit** agrega: role skills, pack rules, memoria compartida de equipo, onboarding zero-friction

Esto significa:
- NO generamos configs que gentle-ai ya genera (eliminados templates de VS Code y OpenCode)
- Solo mantenemos template MCP para IntelliJ (gentle-ai no tiene adapter)
- Team skills se copian al MISMO directorio que gentle-ai ya usa
- Cuando gentle-ai se actualiza, el team layer sigue funcionando

```
Flujo de informacion:

                  +-----------------------------+
                  |      Azure DevOps Repo      |
                  |    (engram compartido)       |
                  +------+------+------+--------+
                         |      |      |
                  engram sync   |   engram sync
                         |      |      |
                  +------+  +---+---+  +------+
                  |Dev FE|  |Dev BE |  |DevOps|
                  |VSCode|  |IDEA   |  |VSCode|
                  |+CoPil|  |+CoPil |  |+CoPil|
                  |skills:|  |skills:|  |skills:|
                  |  FE   |  |  BE   |  |  Ops  |
                  +-------+  +-------+  +-------+
```

---

## Licencia

MIT
