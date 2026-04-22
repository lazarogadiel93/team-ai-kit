# Pack: DevOps

> Rules and conventions for DevOps/SRE engineers on the team.

---

## Architecture Rules

- Separate environment configuration from application code (12-factor)
- CI/CD pipelines with clear stages: lint → test → build → deploy
- Reproducible environments: dev == staging == prod in behavior
- Secrets never in Git repositories, always in a vault or CI env vars
- Immutable container images: do not modify at runtime
- Health checks and readiness probes required for all services
- Automated rollback if health checks fail post-deploy

## Code Quality Rules

- Scripts with explicit error handling (set -euo pipefail in bash)
- Descriptively named variables (no bare $1, $2 without assignment)
- IaC linting: tflint for Terraform, hadolint for Dockerfiles
- Dockerfiles with explicit base image (with version, not latest)
- Idempotent pipelines: can be re-run without duplicate side effects
- Structured logs (JSON) to integrate with observability systems
- Use --dry-run / plan before apply/destroy in production

## Thinking Rules

- Think about reversibility first: every change must be undoable
- Automate anything done more than twice
- Infrastructure as code: nothing manually configured in production
- Think about the blast radius before applying changes
- Prefer incremental changes over big-bang deployments
