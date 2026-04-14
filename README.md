# Team AI Kit

Herramienta que funciona como capa encima de [gentle-ai](https://github.com/Gentleman-Programming/gentle-ai) para estandarizar el uso de AI en equipos de desarrollo.

## El problema

`gentle-ai` es genial para el dev individual, pero no resuelve:

- **Memoria compartida de equipo** — cada dev tiene su propio engram aislado
- **Onboarding estandarizado** — cada dev configura su AI de manera diferente
- **Skills por rol** — un dev Frontend necesita patrones distintos que un DevOps

## La solución

Team AI Kit agrega una capa de equipo sobre gentle-ai con una arquitectura de 3 capas:

```
┌─────────────────────────────────────┐
│  Capa Equipo                        │
│  engram compartido via Azure DevOps │
├─────────────────────────────────────┤
│  Capa Rol                           │
│  skills + rules por perfil          │
│  (FE / BE / DevOps / Python)        │
├─────────────────────────────────────┤
│  Capa Proyecto                      │
│  copilot-instructions.md por repo   │
└─────────────────────────────────────┘
```

## Quick Start

```powershell
git clone <tu-repo>/team-ai-kit
cd team-ai-kit
.\setup.ps1
```

El setup te hace 4 preguntas (IDE, Rol, Provider, API key) y configura todo automáticamente.

→ [Guía completa de onboarding](docs/onboarding.md)

## Estructura del proyecto

```
team-ai-kit/
├── setup.ps1                    # Entry point — ejecuta esto
├── lib/
│   └── functions.ps1            # Funciones testables del setup
├── skills/
│   ├── shared/                  # 5 skills para TODOS los roles
│   │   ├── architecture/
│   │   ├── code-quality/
│   │   ├── debug/
│   │   ├── thinking/
│   │   └── performance/
│   └── roles/                   # 2 skills por rol
│       ├── frontend/
│       ├── backend-node/
│       ├── devops/
│       └── python/
├── packs/                       # Reglas consolidadas por rol
│   ├── frontend/rules.md
│   ├── backend-node/rules.md
│   ├── devops/rules.md
│   └── python/rules.md
├── templates/                   # Configs de IDE pre-armadas
│   ├── vscode-copilot/
│   ├── intellij-copilot/
│   └── opencode/
├── shared-engram/               # Dir para engram sync del equipo
├── tests/                       # Tests Pester 5
│   ├── functions.Tests.ps1
│   └── skills.Tests.ps1
└── docs/
    └── onboarding.md
```

## IDEs soportados

| IDE | Copilot | MCP | Skills |
|-----|---------|-----|--------|
| VS Code | ✅ | ✅ engram + context7 | ✅ |
| IntelliJ | ✅ | ✅ engram + context7 | ✅ |
| OpenCode (CLI) | — | ✅ engram + context7 | ✅ |

## Roles soportados

| Rol | Skills compartidos | Skills específicos |
|-----|-------------------|-------------------|
| Frontend | 5 | react, nextjs |
| Backend Node | 5 | api-design, testing |
| DevOps | 5 | cicd, monitoring |
| Python | 5 | api-design, testing |

## Tests

```powershell
# Correr toda la suite
Invoke-Pester tests/ -Output Detailed

# Solo tests de funciones
Invoke-Pester tests/functions.Tests.ps1

# Solo validación de skills
Invoke-Pester tests/skills.Tests.ps1
```

## Agregar skills

Crear un archivo `.md` en:
- `skills/shared/<nombre>/SKILL.md` — para todos los roles
- `skills/roles/<rol>/<nombre>.skill.md` — para un rol específico

Ver [docs/onboarding.md](docs/onboarding.md) para la estructura requerida.

## Requisitos

- Windows 10/11
- PowerShell 5.1+
- Scoop (el setup lo instala si falta)

## Dependencias

- [gentle-ai](https://github.com/Gentleman-Programming/gentle-ai) — plataforma AI para devs
- [engram](https://github.com/Gentleman-Programming/engram) — memoria persistente
- [context7](https://context7.com) — documentación contextual via MCP

## Licencia

MIT
