# Contributing to Team AI Kit

Thanks for your interest in contributing! This project follows a straightforward workflow.

## Getting Started

1. Fork the repo
2. Clone your fork
3. Create a feature branch from `master`

```bash
git clone https://github.com/<your-user>/team-ai-kit
cd team-ai-kit
git checkout -b feat/your-feature
```

## Development

### Prerequisites

- **Windows**: PowerShell 5.1+ (built-in) and [Pester 5+](https://pester.dev/) for tests
- **macOS/Linux**: bash 4+, jq
- **Both**: [gentle-ai](https://github.com/Gentleman-Programming/gentle-ai) installed (for integration testing)

### Running Tests

```powershell
# PowerShell unit tests (Windows)
Invoke-Pester ./tests/functions.Tests.ps1 -Output Detailed
```

```bash
# Bash E2E tests (macOS/Linux)
bash tests/e2e-bash.sh
```

### Testing without Scoop

Run scripts directly from the clone:

```powershell
.\bin\team-ai-kit.ps1 setup
.\bin\team-ai-kit.ps1 init
.\bin\team-ai-kit.ps1 doctor
```

## Commit Convention

We use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add new role for data engineers
fix: correct skill path resolution on macOS
docs: update onboarding guide
test: add init command edge cases
chore: update CI workflow
refactor: extract template engine
```

## Pull Requests

1. One feature/fix per PR
2. All tests must pass (CI runs automatically)
3. Update docs if your change affects user-facing behavior
4. Fill out the PR template

## Adding a New Role

1. Create `packs/<role>/rules.md` with team conventions
2. Create `skills/roles/<role>/` with role-specific skills
3. Add the role to `VALID_ROLES` in both `lib/functions.ps1` and `lib/functions.sh`
4. Add tests in `tests/functions.Tests.ps1`

## Adding a New Skill

1. Create `skills/shared/<skill-name>/SKILL.md` (shared) or `skills/roles/<role>/<skill-name>/SKILL.md` (role-specific)
2. Follow the [SKILL.md format](https://github.com/Gentleman-Programming/gentle-ai/blob/main/docs/components.md) with YAML frontmatter

## Code Style

- **PowerShell**: PascalCase functions, camelCase locals, strict mode (`Set-StrictMode -Version Latest`)
- **Bash**: snake_case functions, UPPER_CASE constants, `set -euo pipefail` where appropriate
- **ASCII only** in `.ps1` and `.template` files (PS 5.1 encoding gotcha)

## Questions?

Open an issue with the `question` label. We're happy to help.
