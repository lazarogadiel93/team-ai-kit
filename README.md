# Team AI Kit

[![CI](https://github.com/lazarogadiel93/team-ai-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/lazarogadiel93/team-ai-kit/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> [gentle-ai](https://github.com/Gentleman-Programming/gentle-ai) para equipos. Un comando, 3 preguntas, y todo tu equipo tiene la misma base de AI configurada.

## Que resuelve

gentle-ai es para el dev individual. Team AI Kit agrega lo que falta para equipos:

- **Skills por rol** -- Frontend, Backend, DevOps, Python. Cada uno recibe los patrones que necesita.
- **Memoria compartida** -- engram sync entre devs. Lo que aprende uno, lo saben todos.
- **Merge inteligente** -- updates del equipo NUNCA pisan tus customizaciones locales.
- **Zero config** -- un setup y listo. El dev no tiene que saber como funciona por dentro.

---

## Instalar

### Windows (Scoop)

```powershell
# Instalar Scoop (si no lo tenes): https://scoop.sh
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression

# Instalar team-ai-kit
scoop bucket add team-ai-kit https://github.com/lazarogadiel93/scoop-bucket
scoop install team-ai-kit
team-ai-kit setup
```

### Windows (sin Scoop -- entornos corporativos)

En entornos corporativos con restricciones de PowerShell (Constrained Language Mode, GPO, AppLocker), Scoop no funciona. Usa la instalacion directa:

```powershell
# 1. Descargar el release desde GitHub
#    https://github.com/lazarogadiel93/team-ai-kit/releases/latest

# 2. Extraer el zip en una ubicacion permanente, por ejemplo:
#    C:\tools\team-ai-kit

# 3. Ejecutar setup desde la carpeta extraida
cd C:\tools\team-ai-kit
.\setup.ps1
```

El setup detecta automaticamente que Scoop no esta disponible y descarga `gentle-ai` y `engram` directo desde GitHub Releases. Los binarios se instalan en `%LOCALAPPDATA%\team-ai-kit\bin` y se agregan al PATH.

### macOS / Linux

```bash
# Instalar Homebrew (si no lo tenes): https://brew.sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Instalar jq (requerido)
brew install jq        # macOS
# sudo apt install jq  # Debian/Ubuntu

# Instalar team-ai-kit
git clone https://github.com/lazarogadiel93/team-ai-kit
cd team-ai-kit
./setup.sh
```

### Clonar y ejecutar (desarrollo)

```powershell
# Windows
git clone https://github.com/lazarogadiel93/team-ai-kit
cd team-ai-kit
.\setup.ps1
```

```bash
# macOS / Linux
git clone https://github.com/lazarogadiel93/team-ai-kit
cd team-ai-kit
./setup.sh
```

---

## Usar

```
team-ai-kit setup     # Primera configuracion (3 preguntas, 2 minutos)
team-ai-kit init      # Inicializar en el proyecto actual
team-ai-kit update    # Pull del team repo + merge sin pisar lo tuyo
team-ai-kit status    # Ver config actual y skills instalados
team-ai-kit doctor    # Verificar que todo este bien
```

### Flujo completo

```bash
# 1. Setup global (una sola vez)
team-ai-kit setup

# 2. En cada proyecto, inicializar
cd mi-proyecto
team-ai-kit init

# 3. Si el proyecto usa otro rol
cd mi-api-backend
team-ai-kit init --role backend-node   # override sin cambiar el global
```

### Setup no interactivo

```powershell
# Windows (PowerShell)
team-ai-kit setup -Ide vscode -Role frontend
team-ai-kit setup -Ide opencode -Role devops -Provider anthropic
team-ai-kit setup -Ide vscode -Role frontend -TeamRepo https://dev.azure.com/equipo/team-knowledge
```

```bash
# macOS / Linux
team-ai-kit setup --ide vscode --role frontend
team-ai-kit setup --ide opencode --role devops --provider anthropic
team-ai-kit setup --ide vscode --role frontend --team-repo https://github.com/team/knowledge
```

---

## Arquitectura

```
+-------------------------------------------+
|  TOOL layer   (team-ai-kit package)       |
|  CLI + default skills + pack rules        |
+-------------------------------------------+
|  TEAM layer   (team-knowledge repo)       |
|  Custom skills + cross-project rules      |
+-------------------------------------------+
|  PROJECT layer (committed to each repo)   |
|  .team-ai-kit.json + instructions +       |
|  .engram/ + git hooks                     |
+-------------------------------------------+
```

**Merge sin overwrite**: cuando corres `update`, el merge sigue esta prioridad:

1. Lo que VOS modificaste localmente -- **NUNCA se pisa**
2. Skills/rules del team repo -- se agregan si son nuevos
3. Defaults del package -- base, menor prioridad

El tracking se hace con SHA256 hashes en `~/.team-ai-kit/manifest.json`.

---

## Roles y Skills

Todos los roles reciben 5 skills compartidos:

| Skill | Trigger |
|-------|---------|
| **architecture** | Disenar estructura, definir modulos, dependencias |
| **code-quality** | Escribir o revisar codigo |
| **debug** | Investigar bugs, root cause analysis |
| **thinking** | Analizar problemas, evaluar alternativas |
| **performance** | Optimizar bundle, rendering, tokens |

Mas 2 skills especificos del rol:

| Rol | Skills |
|-----|--------|
| **frontend** | react, nextjs |
| **backend-node** | api-design, testing |
| **devops** | cicd, monitoring |
| **python** | api-design, testing |

---

## Team Knowledge Repo

Para equipos que quieren compartir skills y reglas cross-proyecto:

```
team-knowledge/            # Repo mantenido por tech leads
|-- skills/
|   |-- shared/            # Skills para TODOS los roles
|   +-- roles/
|       +-- frontend/      # Skills solo para FE
+-- rules/                 # Reglas cross-proyecto
```

```powershell
# Setup con team repo
team-ai-kit setup -Ide vscode -Role frontend -TeamRepo https://dev.azure.com/equipo/team-knowledge

# Actualizar cuando el equipo publique cambios
team-ai-kit update
```

---

## Crear un skill

1. Crear `skills/shared/<nombre>/SKILL.md` (compartido) o `skills/roles/<rol>/<nombre>.skill.md` (por rol):

```markdown
---
name: nombre-del-skill
description: >
  Que hace este skill.
  Trigger: Cuando se carga.
metadata:
  author: team-ai-kit
  version: "1.0"
---

## When to Use

- Situacion 1
- Situacion 2

## Critical Patterns

### Pattern 1

Explicacion y ejemplos.
```

2. Validar: `Invoke-Pester tests/skills.Tests.ps1 -Output Detailed`

### Crear un rol nuevo

1. `skills/roles/<nuevo-rol>/` -- 2+ skill files
2. `packs/<nuevo-rol>/rules.md` -- reglas del rol
3. Agregar a `VALID_ROLES` en `lib/functions.ps1` y `lib/functions.sh`
4. Agregar opcion en menus interactivos de `bin/team-ai-kit.ps1` y `bin/team-ai-kit`

---

## IDEs soportados

| IDE | gentle-ai | MCP | Notas |
|-----|-----------|-----|-------|
| **VS Code + Copilot** | Nativo | Via gentle-ai | Full support |
| **IntelliJ + Copilot** | No | Via template MCP | Config MCP manual |
| **OpenCode (CLI)** | Nativo | Via gentle-ai | Full support |

---

## Tests

```powershell
# Windows: Pester (154 tests)
Invoke-Pester tests/ -Output Detailed

# macOS/Linux: E2E bash (9 tests)
bash tests/e2e-bash.sh
```

---

## Requisitos

| | Windows | macOS / Linux |
|-|---------|---------------|
| **Shell** | PowerShell 5.1+ | Bash 4+ |
| **Package manager** | Scoop (auto-install) | Homebrew (recomendado) |
| **JSON** | Built-in | jq (requerido) |
| **Hash** | Built-in | sha256sum / shasum |
| **Git** | Requerido | Requerido |

**Dependencias**: [gentle-ai](https://github.com/Gentleman-Programming/gentle-ai), [engram](https://github.com/Gentleman-Programming/engram), [context7](https://context7.com)

---

## Estructura

```
team-ai-kit/
|-- bin/
|   |-- team-ai-kit.ps1           CLI (Windows)
|   +-- team-ai-kit               CLI (macOS/Linux)
|-- lib/
|   |-- functions.ps1              Funciones (Windows)
|   +-- functions.sh               Funciones (macOS/Linux)
|-- skills/
|   |-- shared/                    5 skills compartidos
|   +-- roles/                     2 skills por rol
|-- packs/                         Reglas por rol
|-- templates/                     Solo IntelliJ (MCP config)
|-- tests/
|   |-- functions.Tests.ps1        135 unit tests (Pester)
|   |-- skills.Tests.ps1           19 validation tests (Pester)
|   +-- e2e-bash.sh                9 E2E tests (bash)
|-- scoop/team-ai-kit.json         Scoop manifest
|-- setup.ps1                      Wrapper Windows
|-- setup.sh                       Wrapper macOS/Linux
+-- README.md
```

---

## Licencia

MIT
