# Team AI Kit

[![CI](https://github.com/lazarogadiel93/team-ai-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/lazarogadiel93/team-ai-kit/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> [gentle-ai](https://github.com/Gentleman-Programming/gentle-ai) para equipos. Un comando, 3 preguntas, y todo tu equipo tiene la misma base de AI configurada.

## El problema

Hoy cada dev configura su asistente de AI por su cuenta. Las convenciones del equipo no llegan al AI, el conocimiento se pierde al cerrar cada sesion, y cada nuevo integrante arranca de cero.

**Sin estandarizar:**

```
Dev A → AI genera componentes con any y useEffect para fetching
Dev B → AI genera Server Components con tipos estrictos
Dev C → AI ni siquiera sabe que el equipo usa Zod
```

**Con Team AI Kit:**

```
Todos → AI genera Server Components, TypeScript estricto, Zod, patrones del equipo
         Porque los skills y reglas son los mismos para todos.
```

## Que resuelve

| Problema | Solucion |
|----------|----------|
| Cada dev tiene su AI configurado diferente | **Skills por rol** -- Frontend, Backend, DevOps, Python. Mismos patrones para todos |
| El conocimiento se pierde entre sesiones | **[Memoria compartida](docs/engram-guide.md)** -- engram sync entre devs. Lo que aprende uno, lo saben todos |
| Updates del equipo pisan configs locales | **Merge inteligente** -- updates NUNCA pisan tus customizaciones |
| Onboarding lento para nuevos integrantes | **Zero config** -- un setup, 2 minutos, listo |
| No hay forma de compartir convenciones | **[Team Knowledge Repo](docs/team-knowledge-repo.md)** -- repo centralizado con skills y reglas custom |

---

## Ejemplo rapido

Un dev de **Backend** escribe un controller. Asi cambia el comportamiento del AI:

<table>
<tr>
<th>❌ Sin estandarizar</th>
<th>✅ Con Team AI Kit</th>
</tr>
<tr>
<td>

```typescript
// Todo en el controller, SQL crudo
app.get('/users/:id', async (req, res) => {
  const user = await db.query(
    'SELECT * FROM users WHERE id = $1',
    [req.params.id]
  );
  res.json(user);
});
```

</td>
<td>

```typescript
// Controller: valida y delega
async getById(req: Request, res: Response) {
  const { id } = userIdSchema.parse(req.params);
  const user = await this.service.getById(id);
  res.json(user);
}

// Service: logica de negocio
async getById(id: string): Promise<User> {
  const user = await this.repo.findById(id);
  if (!user) throw new NotFoundError('User');
  return user;
}
```

</td>
</tr>
</table>

> 📖 Ejemplos para todos los roles (Frontend, Backend, DevOps, QA/Funcionales): **[docs/examples-by-role.md](docs/examples-by-role.md)**

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

En entornos con restricciones de PowerShell (Constrained Language Mode, GPO, AppLocker), Scoop no funciona. Clonar el repo directamente:

```powershell
# Instalar
git clone https://github.com/lazarogadiel93/team-ai-kit
cd team-ai-kit
.\setup.ps1

# Actualizar
cd team-ai-kit
git pull
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

## Roles y Skills

Cada rol recibe **5 skills compartidos** + **2 skills especificos**:

### Skills compartidos (todos los roles)

| Skill | Que hace | Trigger |
|-------|----------|---------|
| 🏗️ **architecture** | Patrones de estructura, modulos, dependencias | Disenar arquitectura |
| ✨ **code-quality** | Reglas de calidad, convenciones, clean code | Escribir o revisar codigo |
| 🔍 **debug** | Root cause analysis, narrowing sistematico | Investigar bugs |
| 🧠 **thinking** | Descomponer problemas, evaluar alternativas | Analizar antes de proponer |
| ⚡ **performance** | Optimizar bundle, rendering, tokens, queries | Mejorar rendimiento |

### Skills por rol

| Rol | Skills especificos | Ejemplo de impacto |
|-----|-------------------|-------------------|
| **frontend** | react, nextjs | Server Components por defecto, TypeScript estricto, cero `any` |
| **backend-node** | api-design, testing | Separacion en capas, Zod en el borde, DI para testing |
| **devops** | cicd, monitoring | Multi-stage Dockerfiles, pipelines fail-fast, logging JSON |
| **python** | api-design, testing | Estructura de API, testing patterns |

> 📖 Ejemplos detallados con codigo para cada rol: **[docs/examples-by-role.md](docs/examples-by-role.md)**

---

## Team Knowledge Repo

Un repo Git centralizado donde el Tech Lead define skills y reglas que **todo el equipo recibe automaticamente**:

```
team-knowledge/              # Repo mantenido por tech leads
├── skills/
│   ├── shared/              # Skills para TODOS los roles
│   │   └── logging/
│   │       └── SKILL.md     # Estandar de logging del equipo
│   └── roles/
│       └── frontend/
│           └── design-system.skill.md
└── rules/                   # Reglas cross-proyecto
    └── team-conventions.md
```

```powershell
# Setup con team repo
team-ai-kit setup -Ide vscode -Role frontend -TeamRepo https://dev.azure.com/equipo/team-knowledge

# Actualizar cuando el equipo publique cambios
team-ai-kit update
```

**Prioridad de merge** (lo local siempre gana):

1. 🟢 **Customizaciones locales** -- lo que vos modificaste → **nunca se pisa**
2. 🔵 **Team Knowledge Repo** -- skills del equipo → se agregan si son nuevos
3. ⚪ **Defaults del package** -- skills base → menor prioridad

> 📖 Guia completa con ejemplo real paso a paso: **[docs/team-knowledge-repo.md](docs/team-knowledge-repo.md)**

---

## engram -- Memoria del equipo

Lo que un dev aprende, todo el equipo lo sabe. Automatico, via git hooks:

```
Dev A resuelve bug → engram save → git push → Dev B hace pull → AI de Dev B ya sabe
```

El AI recuerda decisiones, bugs resueltos, patrones establecidos -- entre sesiones y entre devs. Sin hacer nada manual.

> 📖 Como funciona, flujo completo, ejemplo real: **[docs/engram-guide.md](docs/engram-guide.md)**

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

El tracking de merge se hace con SHA256 hashes en `~/.team-ai-kit/manifest.json`.

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
├── bin/
│   ├── team-ai-kit.ps1           CLI (Windows)
│   └── team-ai-kit               CLI (macOS/Linux)
├── lib/
│   ├── functions.ps1              Funciones (Windows)
│   └── functions.sh               Funciones (macOS/Linux)
├── skills/
│   ├── shared/                    5 skills compartidos
│   └── roles/                     2 skills por rol
├── packs/                         Reglas por rol
├── templates/                     Solo IntelliJ (MCP config)
├── tests/
│   ├── functions.Tests.ps1        135 unit tests (Pester)
│   ├── skills.Tests.ps1           19 validation tests (Pester)
│   └── e2e-bash.sh                9 E2E tests (bash)
├── docs/
│   ├── examples-by-role.md        Ejemplos detallados por rol
│   ├── team-knowledge-repo.md     Guia del Team Knowledge Repo
│   ├── engram-guide.md            Guia de engram
│   ├── onboarding.md              Guia de onboarding
│   └── presentation.html          Presentacion visual
├── scoop/team-ai-kit.json         Scoop manifest
├── setup.ps1                      Wrapper Windows
├── setup.sh                       Wrapper macOS/Linux
└── README.md
```

---

## Documentacion

| Documento | Contenido |
|-----------|-----------|
| **[Ejemplos por rol](docs/examples-by-role.md)** | Comparaciones antes/despues para Frontend, Backend, DevOps y QA/Funcionales |
| **[Team Knowledge Repo](docs/team-knowledge-repo.md)** | Como crear y mantener el repo de conocimiento del equipo |
| **[Guia de engram](docs/engram-guide.md)** | Memoria compartida: como funciona, flujo, ejemplo real |
| **[Guia de onboarding](docs/onboarding.md)** | Paso a paso para nuevos integrantes del equipo |
| **[Presentacion](docs/presentation.html)** | Presentacion visual de la herramienta |

---

## Licencia

MIT
