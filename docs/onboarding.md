# Team AI Kit — Guía de Onboarding

> Todo lo que necesitás saber para arrancar con tu entorno de desarrollo asistido por AI.

---

## Requisitos previos

| Herramienta | ¿Para qué? | Instalación |
|-------------|-------------|-------------|
| **Windows 10/11** | SO del equipo | — |
| **PowerShell 5.1+** | Ejecutar el setup | Incluido en Windows |
| **Scoop** | Package manager | El setup lo instala si falta |
| **Git** | Control de versiones | `scoop install git` |
| **Tu IDE** | VS Code, IntelliJ o OpenCode | Instalado por vos |

> **Nota**: Si ya tenés Scoop y Git, no necesitás hacer nada manual. El setup se encarga del resto.

---

## Paso 1: Clonar el kit

```powershell
git clone <tu-repo-azure-devops>/team-ai-kit
cd team-ai-kit
```

---

## Paso 2: Ejecutar el setup

```powershell
.\setup.ps1
```

El setup te hace **4 preguntas**:

1. **IDE** — ¿Qué usás? (VS Code, IntelliJ, OpenCode)
2. **Rol** — ¿Qué hacés? (Frontend, Backend Node, DevOps, Python)
3. **Provider** — ¿Qué proveedor de AI? (OpenAI, Azure OpenAI, Anthropic)
4. **API Key** — Tu clave de API (solo se almacena localmente)

Y después **automáticamente**:

- Instala `gentle-ai` y `engram` via Scoop
- Copia los skills de equipo a tu IDE (5 compartidos + 2 de tu rol)
- Genera la config MCP (engram + context7)
- Genera las instrucciones de Copilot con las reglas de tu rol

---

## Paso 3: Verificar la instalación

Después del setup, verificá que todo esté en orden:

```powershell
# Verificar gentle-ai
gentle-ai --version

# Verificar engram
engram --version

# Verificar skills instalados (VS Code / IntelliJ)
ls ~/.github/copilot-skills/team-skills/

# Verificar skills instalados (OpenCode)
ls ~/.config/opencode/skills/team-skills/
```

---

## Paso 4: Configurar engram sync (opcional)

Para compartir conocimiento con el equipo, configurá engram sync apuntando al repo de Azure DevOps:

```powershell
engram sync --repo <tu-repo-azure-devops>/shared-engram
```

Esto permite que las decisiones, descubrimientos y bug fixes que guardes se sincronicen con el equipo.

---

## ¿Qué se instaló?

### Skills compartidos (todos los roles)

| Skill | Descripción |
|-------|-------------|
| **architecture** | Clean Architecture, estructura feature-based, dependencias entre capas |
| **code-quality** | Patrones de calidad de código, naming, estructura |
| **debug** | Debugging sistemático, análisis de errores, root cause |
| **thinking** | Análisis cognitivo, definición de problemas, evaluación de alternativas |
| **performance** | Optimización de bundle, rendering, token economics |

### Skills por rol

| Rol | Skills |
|-----|--------|
| **Frontend** | react, nextjs |
| **Backend Node** | api-design, testing |
| **DevOps** | cicd, monitoring |
| **Python** | api-design, testing |

### Pack rules

Cada rol tiene reglas específicas en `packs/<rol>/rules.md` que se inyectan en las instrucciones de Copilot.

---

## Actualizar el kit

Cuando el equipo publique una nueva versión del kit:

```powershell
cd team-ai-kit
git pull
.\setup.ps1 --update
```

El flag `--update` además actualiza `gentle-ai` a la última versión via Scoop.

---

## Agregar un skill nuevo al equipo

1. Creá un archivo `.md` en la carpeta correcta:
   - **Compartido** (todos los roles): `skills/shared/<nombre>/SKILL.md`
   - **Por rol**: `skills/roles/<rol>/<nombre>.skill.md`

2. Seguí la estructura de frontmatter:
   ```yaml
   ---
   name: nombre-del-skill
   description: >
     Descripción del skill.
     Trigger: Cuándo debe cargarse este skill.
   metadata:
     author: team-ai-kit
     version: "1.0"
   ---
   ```

3. Incluí las secciones obligatorias:
   - `## When to Use` — Cuándo activar el skill
   - `## Critical Patterns` — Patrones y reglas concretas

4. Ejecutá los tests para validar:
   ```powershell
   Invoke-Pester tests/skills.Tests.ps1
   ```

5. Hacé commit y push. Los demás lo obtienen con `git pull` + `.\setup.ps1`.

---

## Troubleshooting

### "gentle-ai no se encuentra"

```powershell
scoop bucket add gentleman https://github.com/Gentleman-Programming/scoop-bucket
scoop install gentle-ai
```

### "engram no se encuentra"

```powershell
# Verificar si está en AppData (gentle-ai lo instala ahí)
ls $env:LOCALAPPDATA\engram\bin\
```

### "Los skills no aparecen en mi IDE"

Verificá que la carpeta de destino es correcta:
- **VS Code/IntelliJ**: `~/.github/copilot-skills/team-skills/`
- **OpenCode**: `~/.config/opencode/skills/team-skills/`

### "Los tests fallan"

```powershell
# Correr toda la suite con output detallado
Invoke-Pester tests/ -Output Detailed
```

---

## Contacto

¿Dudas? Preguntale al equipo o abrí un issue en el repo.
