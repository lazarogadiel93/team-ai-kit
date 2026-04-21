# Team AI Kit -- Guia de Onboarding

> Lo que necesitas para arrancar con tu entorno de AI configurado por el equipo.

---

## Requisitos

### Windows

| Herramienta | Nota |
|-------------|------|
| **PowerShell 5.1+** | Incluido en Windows |
| **Git** | `scoop install git` |
| **Tu IDE** | VS Code, IntelliJ, Cursor o OpenCode |

> Scoop, gentle-ai y engram los instala el setup si faltan.

### macOS / Linux

| Herramienta | Instalacion |
|-------------|-------------|
| **Bash 4+** | Incluido |
| **jq** | `brew install jq` / `apt install jq` |
| **Git** | Incluido o via package manager |
| **Tu IDE** | VS Code, IntelliJ, Cursor o OpenCode |

---

## Paso 1: Instalar

### Windows (Scoop)

```powershell
# Instalar Scoop (si no lo tenes): https://scoop.sh
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression

# Instalar team-ai-kit
scoop bucket add team-ai-kit https://github.com/lazarogadiel93/scoop-bucket
scoop install team-ai-kit
```

### macOS / Linux (o Windows sin Scoop)

```bash
# Instalar Homebrew (si no lo tenes): https://brew.sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Instalar jq (requerido)
brew install jq        # macOS
# sudo apt install jq  # Debian/Ubuntu

# Clonar team-ai-kit
git clone https://github.com/lazarogadiel93/team-ai-kit
cd team-ai-kit
```

---

## Paso 2: Ejecutar el setup

### Interactivo (recomendado para la primera vez)

```powershell
# Windows
team-ai-kit setup
# o si clonaste el repo:
.\setup.ps1
```

```bash
# macOS / Linux
./setup.sh
```

Te hace **2 preguntas** (VS Code / IntelliJ / Cursor / OpenCode) o **3** (OpenCode):

1. **IDE** -- VS Code + Copilot, IntelliJ + Copilot, Cursor, u OpenCode
2. **Rol** -- Frontend, Backend Node, DevOps, Python
3. **Provider** -- Solo si elegiste OpenCode (los demas IDEs auto-detectan el provider)

Despues, automaticamente:

- Instala gentle-ai y engram si faltan (Windows: via Scoop)
- Ejecuta `gentle-ai install` con la config optima para tu IDE
- Copia 5 skills compartidos + 2 de tu rol
- Genera instrucciones de Copilot con las reglas de tu equipo
- Guarda tu config en `~/.team-ai-kit/config.json`

### No interactivo (para CI o si ya sabes que queres)

```powershell
# Windows
team-ai-kit setup -Ide vscode -Role frontend
team-ai-kit setup -Ide vscode -Role frontend -TeamRepo https://dev.azure.com/equipo/team-knowledge
```

```bash
# macOS / Linux
team-ai-kit setup --ide vscode --role frontend
team-ai-kit setup --ide vscode --role frontend --team-repo https://github.com/team/knowledge
```

---

## Paso 3: Inicializar en tu proyecto

Despues del setup global, inicializa en cada proyecto donde trabajes:

```bash
cd mi-proyecto
team-ai-kit init
```

Esto genera:
- `.team-ai-kit.json` -- config del proyecto (rol, IDE, timestamps)
- `.github/copilot-instructions.md` (VS Code/IntelliJ) o `.cursor/rules/team-ai-kit.md` (Cursor) o `AGENTS.md` (OpenCode) -- reglas para el AI con las convenciones del equipo. El Memory Protocol de engram se incluye solo para IntelliJ (los demas IDEs lo reciben via gentle-ai)
- `.engram/` -- directorio nativo de engram sync para compartir conocimiento del proyecto con el equipo (via git hooks)

### Override de rol por proyecto

Si tu rol global es frontend pero este proyecto es backend:

```powershell
# Windows
team-ai-kit init -Role backend-node
```

```bash
# macOS / Linux
team-ai-kit init --role backend-node
```

Esto NO cambia tu config global. Solo aplica a este proyecto.

### Per-project team repo

Si trabajas en equipos distintos y cada proyecto usa un team knowledge repo diferente:

```bash
team-ai-kit init --team-repo https://github.com/otro-equipo/knowledge
```

El team repo se guarda en `.team-ai-kit.json` del proyecto y tiene prioridad sobre el global.

### Re-inicializar

Si corres `init` en un proyecto ya inicializado:
- **Interactivo**: te muestra la config actual y pregunta si queres re-inicializar
- **No interactivo**: falla con mensaje claro. Usa `--Force` / `--force` para forzar

---

## Paso 4: Verificar

```
team-ai-kit doctor
```

Esto verifica: gentle-ai, engram, jq (Unix), config, skills instalados (global + proyecto) y team repo.

Si queres ver tu config actual:

```
team-ai-kit status
```

### Verificar skills manualmente

**Skills base (globales):**

```powershell
# Windows: VS Code / IntelliJ
ls "$env:USERPROFILE\.copilot\skills\team-skills"

# Windows: Cursor
ls "$env:USERPROFILE\.cursor\skills\team-skills"

# Windows: OpenCode
ls "$env:USERPROFILE\.config\opencode\skills\team-skills"
```

```bash
# macOS/Linux: VS Code / IntelliJ
ls ~/.copilot/skills/team-skills/

# macOS/Linux: Cursor
ls ~/.cursor/skills/team-skills/

# macOS/Linux: OpenCode
ls ~/.config/opencode/skills/team-skills/
```

**Skills del team repo (en el proyecto):**

```powershell
# VS Code / IntelliJ
ls .github\skills\team-skills

# Cursor
ls .cursor\skills\team-skills

# OpenCode
ls .agents\skills\team-skills
```

---

## Paso 5: Engram sync

El `init` ejecuta el primer engram sync y instala git hooks (pre-commit + post-merge) automaticamente.

Para mantenerlo actualizado:

```bash
# Al terminar de trabajar: exportar lo aprendido
engram sync

# Al empezar: importar conocimiento del equipo
engram sync --import
```

Los git hooks se encargan del sync automatico: pre-commit exporta y agrega `.engram/`, post-merge importa. Comitea `.engram/` al repo para que todo el equipo lo tenga.

---

## Que se instalo

### 5 skills compartidos (todos los roles)

| Skill | Trigger |
|-------|---------|
| **architecture** | Al disenar estructura, definir modulos, dependencias |
| **code-quality** | Al escribir o revisar codigo |
| **debug** | Al investigar bugs, root cause analysis |
| **thinking** | Al analizar problemas, evaluar alternativas |
| **performance** | Al optimizar bundle, rendering, tokens |

### 2 skills de tu rol

| Rol | Skills |
|-----|--------|
| **Frontend** | react, nextjs |
| **Backend Node** | api-design, testing |
| **DevOps** | cicd, monitoring |
| **Python** | api-design, testing |

### Pack rules

Reglas especificas por rol (en `packs/<rol>/rules.md`) que se inyectan automaticamente en las instrucciones de Copilot.

---

## Actualizar

Cuando el equipo publique cambios en skills o reglas:

```
team-ai-kit update
```

Esto:
1. Hace pull del team-knowledge repo (si esta configurado)
2. Mergea skills nuevos o actualizados
3. Actualiza el **Memory Protocol** de engram en las instrucciones del proyecto
4. Sincroniza la version en el config
5. **NUNCA pisa** skills que vos modificaste localmente

---

## Agregar un skill al equipo

1. Crear archivo:
   - **Compartido**: `skills/shared/<nombre>/SKILL.md`
   - **Por rol**: `skills/roles/<rol>/<nombre>/SKILL.md`

2. Estructura minima:

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

3. Validar:

```powershell
# Windows
Invoke-Pester tests/skills.Tests.ps1 -Output Detailed
```

4. Commit y push. Los demas lo obtienen con `team-ai-kit update`.

---

## Troubleshooting

### Primero: correr doctor

```
team-ai-kit doctor
```

Si algo falla, te dice exactamente que.

### gentle-ai no se encuentra

```powershell
# Windows
scoop bucket add team-ai-kit https://github.com/lazarogadiel93/scoop-bucket
scoop install gentle-ai
```

```bash
# macOS
brew tap Gentleman-Programming/tap && brew install gentle-ai
```

### Los skills no aparecen en mi IDE

Verificar que la carpeta exista (ver Paso 3 arriba). Si no, correr:

```
team-ai-kit update
```

### IntelliJ no detecta MCP servers

1. Verificar que el Copilot plugin esta actualizado
2. La config MCP se muestra durante el setup -- copiarla a la config de MCP de IntelliJ
3. Verificar engram: `engram --version`

### Scoop no actualiza a la ultima version

Scoop cachea los archivos descargados. Si `scoop update gentle-ai` o `scoop update engram` no instala la version esperada:

```powershell
# Limpiar cache de Scoop y reintentar
scoop cache rm gentle-ai
scoop cache rm engram
scoop update gentle-ai
scoop update engram
```

Si persiste, forzar reinstalacion:

```powershell
scoop uninstall gentle-ai
scoop install gentle-ai
```

### Verificar versiones instaladas

Correr `team-ai-kit doctor` para ver las versiones instaladas y si hay updates disponibles. Tambien se puede verificar manualmente:

```powershell
gentle-ai version    # version de gentle-ai
engram version       # version de engram
```
