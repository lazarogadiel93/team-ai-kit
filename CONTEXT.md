# Team AI Kit — Contexto y Decisiones

> Documento vivo que captura las decisiones de diseño, el análisis previo y la visión del proyecto.

---

## Origen

Este proyecto nace de **lazwork-agent-sys**, un sistema multi-agente con pipeline cognitivo de 6 fases (thinking → critic → decision → architect → execution → git-pr), 294 tests, Clean Architecture, MCP server y un adapter para Engram.

Tras evaluar lazwork contra **gentle-ai** (Gentleman-Programming/gentle-ai), se concluyó:

- Lazwork como **producto/infraestructura** es redundante — gentle-ai ya resuelve configuración de agentes, engram, SDD, skills, y soporta 9 agentes.
- Lazwork como **contenido** tiene valor: skills, rules por rol, y el concepto de "packs" (perfiles por tipo de developer).
- El gap real que nadie resuelve es: **gentle-ai para equipos**.

---

## Problema

Un equipo de desarrollo (FE, BE, DevOps) necesita usar AI de forma estructurada, pero:

1. **La mayoría usa VS Code + Copilot** (FE) o **IntelliJ + Copilot** (BE)
2. **Pocos usan CLI** como OpenCode o Claude Code
3. **No hay configuración estandarizada** — cada dev configura (o no) su AI diferente
4. **Dolores reales**: alucinaciones, pérdida de contexto, sin skills/reglas/agentes definidos
5. **Instalar gentle-ai en Windows es doloroso** — TUI interactivo con muchos pasos, engram server, actualizaciones

---

## Visión

**Fomentar el aprendizaje personal, resolver problemas más rápido, y hacer crecer al equipo.**

El valor diferencial está en:
- **Engram compartido**: lo que aprende UN dev, lo saben TODOS
- **SDD workflow**: planificación estructurada que reduce tokens y alucinaciones
- **Roles por perfil**: cada tipo de dev (FE/BE/DevOps) recibe configuración relevante

---

## Decisiones Clave

### 1. Gentle-ai como dependencia — SÍ

SDD + reducción de tokens son features esenciales. No se puede prescindir de gentle-ai.
Pero el dolor de configuración se resuelve con un **setup script que pre-configura todo**.

### 2. Setup automatizado — 4 preguntas máximo

El script pregunta solo:
1. ¿Qué IDE usás? (VS Code / IntelliJ / OpenCode)
2. ¿Cuál es tu rol? (Frontend / Backend / DevOps / Python)
3. ¿Provider? (OpenAI / Azure OpenAI / Anthropic)
4. ¿API key?

Todo lo demás se genera desde templates pre-configurados.

### 3. Engram compartido via Azure DevOps

- Cada dev sincroniza con `engram sync` a un repo Azure DevOps
- `engram sync --import` trae conocimiento del equipo
- Opcionalmente automatizable con pipelines de Azure DevOps

### 4. IntelliJ + Copilot soporta MCP

Confirmado: IntelliJ soporta MCP servers. Los devs de backend pueden usar engram.

### 5. Open source — sí, pero primero el equipo

Primero funciona para el equipo propio. Después se generaliza.
El concepto de "gentle-ai para equipos" llena un gap real en el mercado.

---

## Qué se rescata de lazwork

### RESCATABLE (contenido)

| Pieza | Archivos | Destino |
|-------|----------|---------|
| Skill: architecture | `.lazwork/skills/architecture/SKILL.md` | `skills/shared/architecture/` |
| Skill: code-quality | `.lazwork/skills/code-quality/SKILL.md` | `skills/shared/code-quality/` |
| Skill: debug | `.lazwork/skills/debug/SKILL.md` | `skills/shared/debug/` |
| Skill: thinking | `.lazwork/skills/thinking/SKILL.md` | `skills/shared/thinking/` |
| Skill: frontend | `.lazwork/skills/frontend/SKILL.md` | `skills/roles/frontend/` |
| Skill: nextjs | `.lazwork/skills/nextjs/SKILL.md` | `skills/roles/frontend/` |
| Skill: performance | `.lazwork/skills/performance/SKILL.md` | `skills/shared/performance/` |
| Pack rules: frontend | `core/packs/frontend/rules/*.md` | `packs/frontend/` |
| Pack rules: backend-node | `core/packs/backend-node/rules/*.md` | `packs/backend-node/` |
| Pack rules: devops | `core/packs/devops/rules/*.md` | `packs/devops/` |
| Pack rules: python | `core/packs/python/rules/*.md` | `packs/python/` |

### DESCARTABLE (código)

- Pipeline 6 agentes (reemplazado por SDD de gentle-ai)
- MCP Server (wrapper del pipeline)
- GentlemanEngramAdapter (gentle-ai ya integra engram via MCP)
- LLM Adapters (cada IDE maneja su propio LLM)
- CLI/TUI (se reemplaza por setup.ps1)
- 294 tests (testean el pipeline descartado)

---

## Arquitectura objetivo

```
team-ai-kit/
├── setup.ps1                    # Instalador Windows (4 preguntas)
├── setup.sh                     # Instalador macOS/Linux (futuro)
├── skills/
│   ├── shared/                  # Skills para TODOS los roles
│   │   ├── architecture/
│   │   ├── code-quality/
│   │   ├── debug/
│   │   ├── thinking/
│   │   └── performance/
│   └── roles/                   # Skills específicos por rol
│       ├── frontend/
│       ├── backend-node/
│       ├── devops/
│       └── python/
├── packs/                       # Rules por rol (instrucciones copilot)
│   ├── frontend/
│   ├── backend-node/
│   ├── devops/
│   └── python/
├── templates/                   # Config pre-generada por IDE
│   ├── vscode-copilot/
│   ├── intellij-copilot/
│   └── opencode/
├── shared-engram/               # Memoria compartida del equipo
│   └── .engram/
├── docs/
│   └── onboarding.md
├── CONTEXT.md                   # Este archivo
└── README.md
```

---

## Flujo del equipo

```
                    ┌─────────────────────────────┐
                    │      Azure DevOps Repo       │
                    │      (engram compartido)      │
                    └──────────┬──────────────────┘
                               │ engram sync
            ┌──────────────────┼──────────────────┐
            │                  │                   │
     ┌──────┴──────┐   ┌──────┴──────┐   ┌───────┴─────┐
     │   Dev FE    │   │   Dev BE    │   │  Dev DevOps │
     │ VS Code     │   │ IntelliJ   │   │  VS Code    │
     │ + Copilot   │   │ + Copilot  │   │  + Copilot  │
     │ + engram    │   │ + engram   │   │  + engram   │
     │ + SDD       │   │ + SDD      │   │  + SDD      │
     │             │   │            │   │             │
     │ skills: FE  │   │ skills: BE │   │ skills: Ops │
     └─────────────┘   └────────────┘   └─────────────┘
```

---

## Contexto técnico

- **SO del equipo**: Windows (mayoría)
- **IDEs**: VS Code + Copilot (FE), IntelliJ + Copilot (BE)
- **Repos/CI**: Azure DevOps
- **Docker**: NO disponible para todos
- **Gentle-ai**: v1.20.1, dependencia esencial para SDD + engram + tokens
- **Engram**: binario independiente, MCP server, soportado en VS Code e IntelliJ
