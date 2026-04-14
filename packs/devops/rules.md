# Pack: DevOps

> Reglas y convenciones para ingenieros DevOps/SRE del equipo.

---

## Architecture Rules

- Separar configuración del entorno del código de la aplicación (12-factor)
- Pipelines CI/CD con etapas claras: lint → test → build → deploy
- Ambientes reproducibles: dev == staging == prod en comportamiento
- Secrets nunca en repositorios Git, siempre en vault o env vars del CI
- Imágenes de contenedor inmutables: no modificar en tiempo de ejecución
- Health checks y readiness probes obligatorios en servicios
- Rollback automatizado si los health checks fallan post-deploy

## Code Quality Rules

- Scripts con manejo explícito de errores (set -euo pipefail en bash)
- Variables nombradas descriptivamente (no $1, $2 sin asignar)
- Linting de IaC: tflint para Terraform, hadolint para Dockerfiles
- Dockerfiles con imagen base explícita (con versión, no latest)
- Pipelines idempotentes: se pueden re-ejecutar sin efectos duplicados
- Logs estructurados (JSON) para integrarse con sistemas de observabilidad
- Usar --dry-run / plan antes de apply/destroy en producción

## Thinking Rules

- Pensar primero en la reversibilidad: todo cambio debe poder deshacerse
- Automatizar lo que se hace más de dos veces
- Infraestructura como código: nada configurado manualmente en producción
- Pensar en el blast radius antes de aplicar cambios
- Preferir cambios incrementales sobre big-bang deployments
