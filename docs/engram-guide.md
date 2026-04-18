# engram -- Memoria del equipo

> Lo que un dev aprende en una sesion de AI, todo el equipo lo sabe. Automatico, via git hooks.

## El problema sin memoria

Cada sesion de AI empieza en blanco. El dev explica el contexto, el AI trabaja, y al cerrar -- todo desaparece. La siguiente sesion arranca de cero.

Es como si cada vez que usas una calculadora, tuvieras que cargar los numeros de nuevo. No hay memoria, no hay historial.

**Ejemplos de lo que se pierde:**

- Un dev investiga un bug de produccion durante 2 horas. Encuentra la causa raiz (race condition en el cache de Redis). Cierra la sesion. La proxima vez que alguien tenga un problema similar, nadie sabe que esto ya se investigo.
- El equipo decide usar pino para logging con JSON estructurado. La decision se toma en un meeting. Tres meses despues, un dev nuevo usa `console.log` porque nadie le dijo.
- Un dev descubre que una dependencia tiene un bug sutil con cierto input. Lo resuelve, pero el conocimiento queda solo en su cabeza.

---

## Que resuelve engram

engram es una base de datos local (SQLite) que el AI usa para guardar y consultar conocimiento. Funciona en 3 niveles:

### 1. Memoria individual

El AI guarda automaticamente:
- **Decisiones**: "Elegimos Zustand sobre Redux porque..."
- **Bugfixes**: "El error era una race condition en el cache, se resolvio con..."
- **Patrones**: "El equipo usa este patron para error handling..."
- **Gotchas**: "Cuidado con la dependencia X cuando el input es Y..."

Esto pasa **sin intervencion del dev**. El AI detecta cuando algo es relevante y lo guarda.

**Entre sesiones**: La proxima vez que el dev abre una sesion, el AI consulta engram y tiene contexto de todo lo que se hizo antes.

### 2. Memoria compartida

Lo que aprende un dev se sincroniza con el equipo via git:

```
Dev A resuelve bug → engram save → git push → Dev B hace pull → AI de Dev B ya sabe
```

**¿Como?** Git hooks automaticos:
- **Pre-commit hook**: Antes de cada commit, exporta las observaciones de engram a `.engram/` y las incluye en el commit
- **Post-merge hook**: Despues de cada pull/merge, importa las observaciones nuevas a la base local de engram

El dev no tiene que hacer nada. Los hooks se instalan automaticamente con `team-ai-kit init`.

### 3. Conocimiento acumulado

Con el tiempo, el equipo construye una base de conocimiento que el AI de cada dev puede consultar:

- Decisiones arquitectonicas con contexto y razonamiento
- Root causes de bugs con la solucion aplicada
- Gotchas y edge cases descubiertos en produccion
- Patrones que el equipo establecio y por que

---

## Flujo completo

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  Dev A      │    │  engram     │    │  git push   │    │  Dev B pull │    │  AI de      │
│  trabaja    │───▶│  save       │───▶│  pre-commit │───▶│  post-merge │───▶│  Dev B      │
│             │    │  (auto)     │    │  hook       │    │  hook       │    │  ya sabe    │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
   Resuelve           Guarda en         Exporta a          Importa            Tiene contexto
   bug, toma          SQLite local      .engram/ y         observaciones      del bug, la
   decision           automatico        commitea           nuevas             decision, etc.
```

### Que se guarda

Cada observacion tiene:
- **Titulo**: Corto y buscable (ej: "Fixed race condition in Redis cache")
- **Tipo**: bugfix, decision, architecture, discovery, pattern, config
- **Contenido**: Que se hizo, por que, donde, que se aprendio
- **Scope**: `project` (visible para el equipo) o `personal` (solo el dev)

### Que se sincroniza

Solo las observaciones con scope `project` se sincronizan. Las personales quedan en la base local del dev.

---

## Ejemplo real

### El escenario

**Dev A** esta trabajando en el servicio de pagos. Descubre un bug: bajo carga, algunas transacciones fallan con un error de "connection pool exhausted".

**La investigacion:**

1. Dev A le pregunta al AI: "Las transacciones de pago fallan intermitentemente bajo carga"
2. El AI (con skill de debug) hace narrowing sistematico: ¿que capa? ¿que funcion? ¿que input?
3. Identifican la causa raiz: el pool de conexiones a la base de datos esta configurado con un maximo de 5 conexiones, y bajo carga se agota
4. Solucion: pool size dinamico basado en carga, con circuit breaker

**engram guarda automaticamente:**

```
Titulo:   "Fixed connection pool exhaustion in payment service"
Tipo:     bugfix
Contenido:
  What: Pool de conexiones con max fijo de 5 causaba fallos bajo carga
  Why:  Transacciones de pago fallaban intermitentemente en horarios pico
  Where: services/payment/db.ts -- pool configuration
  Learned: Siempre configurar pool size dinamico en servicios con carga variable.
           Circuit breaker previene cascading failures.
```

### Semanas despues

**Dev B** esta construyendo un nuevo servicio de notificaciones. Tambien tiene conexion a base de datos. Empieza a configurar el pool de conexiones.

El AI de Dev B, al buscar en engram, encuentra la observacion de Dev A:

> "En el servicio de pagos tuvimos un problema con pool size fijo de 5 conexiones bajo carga. Recomiendo configurar pool size dinamico y circuit breaker. Ver services/payment/db.ts para la implementacion de referencia."

**Dev B evita el mismo bug antes de que ocurra.** Sin hablar con Dev A, sin buscar en Slack, sin revisar PRs viejos. El AI ya sabia.

---

## Setup

engram se configura automaticamente con `team-ai-kit setup`. Para habilitarlo en un proyecto:

```bash
# Inicializar en el proyecto (instala git hooks)
cd mi-proyecto
team-ai-kit init
```

Esto:
1. Crea el directorio `.engram/` en el proyecto
2. Instala los git hooks (pre-commit + post-merge)
3. Configura la base local de engram

### Archivos relevantes

```
mi-proyecto/
├── .engram/
│   ├── observations.json    # Observaciones exportadas (commiteado)
│   └── ...
├── .git/hooks/
│   ├── pre-commit           # Exporta engram antes de commit
│   └── post-merge           # Importa engram despues de pull
└── .team-ai-kit.json        # Config del proyecto
```

El directorio `.engram/` se commitea al repo. Asi es como las observaciones viajan entre devs.

---

## Preguntas frecuentes

### ¿El dev tiene que hacer algo para que funcione?

No. Todo es automatico:
- engram guarda observaciones automaticamente durante el trabajo
- Los git hooks exportan/importan sin intervencion
- El AI consulta engram automaticamente al inicio de cada sesion

### ¿Se puede ver que hay guardado?

Si. engram tiene comandos para buscar y ver observaciones:
- El AI puede buscar con `mem_search` y `mem_context`
- Las observaciones exportadas estan en `.engram/observations.json` (es JSON legible)

### ¿Que pasa si dos devs guardan algo contradictorio?

Las observaciones no se sobreescriben entre si -- se acumulan. El AI tiene el criterio para evaluar cual es mas reciente o relevante. Si hay un conflicto real, el AI lo menciona y pregunta.

### ¿Puedo guardar algo que solo sea para mi?

Si. Las observaciones con scope `personal` no se exportan al repo. Solo quedan en tu base local.

### ¿Esto funciona con cualquier AI/IDE?

engram funciona con cualquier IDE que soporte team-ai-kit: VS Code + Copilot, IntelliJ + Copilot, Cursor, OpenCode (CLI).

---

← [Volver al README](../README.md)
