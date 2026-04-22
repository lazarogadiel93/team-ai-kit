# Team AI Kit

[![CI](https://github.com/lazarogadiel93/team-ai-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/lazarogadiel93/team-ai-kit/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> [gentle-ai](https://github.com/Gentleman-Programming/gentle-ai) for teams. One command, 3 questions, and your entire team shares the same AI configuration.

## The Problem

Today every dev configures their AI assistant on their own. Team conventions never reach the AI, knowledge is lost when sessions close, and every new team member starts from scratch.

**Without standardization:**

```
Dev A → AI generates components with any and useEffect for fetching
Dev B → AI generates Server Components with strict types
Dev C → AI doesn't even know the team uses Zod
```

**With Team AI Kit:**

```
Everyone → AI generates Server Components, strict TypeScript, Zod, team patterns
           Because the skills and rules are the same for everyone.
```

## What It Solves

| Problem | Solution |
|---------|----------|
| Every dev has a different AI config | **Skills per role** — 8 roles covering Frontend, Backend, DevOps, Python, Mobile, Data. Same patterns for everyone |
| Knowledge is lost between sessions | **[Shared memory](docs/engram-guide.md)** — engram sync between devs. What one learns, everyone knows |
| Team updates overwrite local configs | **Smart merge** — updates NEVER overwrite your customizations |
| Slow onboarding for new members | **Zero config** — one setup, 2 minutes, done |
| No way to share conventions | **[Team Knowledge Repo](docs/team-knowledge-repo.md)** — centralized repo with custom skills and rules |

---

## Quick Example

A **Backend** dev writes a controller. Here's how the AI behavior changes:

<table>
<tr>
<th>❌ Without standardization</th>
<th>✅ With Team AI Kit</th>
</tr>
<tr>
<td>

```typescript
// Everything in the controller, raw SQL
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
// Controller: validates and delegates
async getById(req: Request, res: Response) {
  const { id } = userIdSchema.parse(req.params);
  const user = await this.service.getById(id);
  res.json(user);
}

// Service: business logic
async getById(id: string): Promise<User> {
  const user = await this.repo.findById(id);
  if (!user) throw new NotFoundError('User');
  return user;
}
```

</td>
</tr>
</table>

> 📖 Detailed examples with code for every role: **[docs/examples-by-role.md](docs/examples-by-role.md)**

---

## Why Not Just `.md` Files?

You could copy-paste `.md` files into each project. Here's why that breaks down at scale:

| Challenge | Raw `.md` files | Team AI Kit |
|-----------|----------------|-------------|
| **Keeping 10 repos in sync** | Manual copy-paste every time a pattern changes | `team-ai-kit update` — one command, all repos updated |
| **New team member onboarding** | "Read this wiki, copy these files, set up engram..." | `team-ai-kit setup` — 2 minutes, done |
| **Role-specific patterns** | Everyone gets everything or you maintain separate folders | Automatic role-based skill selection (8 roles) |
| **Local customizations** | Overwritten on every sync | Smart merge — your changes are NEVER overwritten |
| **Memory across sessions** | Lost every time the AI context resets | engram sync via git hooks — automatic, cross-dev |
| **IDE differences** | Different instruction paths for VS Code, Cursor, IntelliJ, OpenCode | Auto-detected and configured per IDE |
| **Knowing what's installed** | `ls` and hope for the best | `team-ai-kit status` — role, IDE, skills, versions |

**Team AI Kit is the difference between "we have docs" and "the AI actually follows our patterns."**

---

## Install

### Windows (Scoop)

```powershell
# Install Scoop (if you don't have it): https://scoop.sh
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression

# Install team-ai-kit
scoop bucket add team-ai-kit https://github.com/lazarogadiel93/scoop-bucket
scoop install team-ai-kit
team-ai-kit setup

# Update to latest version
scoop update team-ai-kit

# If Scoop doesn't pick up the latest version (cache), clear and retry
scoop cache rm team-ai-kit
scoop update team-ai-kit
```

### Windows (without Scoop — corporate environments)

In environments with PowerShell restrictions (Constrained Language Mode, GPO, AppLocker), Scoop won't work. Clone the repo directly:

```powershell
# Install
git clone https://github.com/lazarogadiel93/team-ai-kit
cd team-ai-kit
.\setup.ps1

# Update
cd team-ai-kit
git pull
.\setup.ps1
```

> **Note**: `setup.ps1` is a bootstrap wrapper that only runs `team-ai-kit setup`. For other commands (`init`, `update`, `doctor`, etc.) use `team-ai-kit <command>` directly.

The setup automatically detects that Scoop is unavailable and downloads `gentle-ai` and `engram` directly from GitHub Releases. Binaries are installed to `%LOCALAPPDATA%\team-ai-kit\bin` and added to PATH.

### macOS / Linux

```bash
# Install Homebrew (if you don't have it): https://brew.sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install jq (required)
brew install jq        # macOS
# sudo apt install jq  # Debian/Ubuntu

# Install team-ai-kit
git clone https://github.com/lazarogadiel93/team-ai-kit
cd team-ai-kit
./setup.sh

# Update to latest version
cd team-ai-kit
git pull
./setup.sh
```

### Clone and run (development)

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

## Usage

```
team-ai-kit setup          # First-time configuration (base skills to global)
team-ai-kit init           # Initialize project (team skills + instructions + hooks)
team-ai-kit init-knowledge # Create Team Knowledge Repo structure
team-ai-kit update         # Pull from team repo + update skills (global + project)
team-ai-kit sync           # Manually sync engram memories (export + import)
team-ai-kit status         # View config, global and project skills
team-ai-kit doctor         # Verify everything is set up correctly
team-ai-kit uninstall      # Remove team-ai-kit from current project
```

### Uninstall

Removes all team-ai-kit artifacts from the current project:

- `.team-ai-kit.json` (project config)
- Generated instructions file (`.github/copilot-instructions.md`, `.cursor/rules/team-ai-kit.md`, `AGENTS.md`)
- `team-skills/` directory with installed skills
- Injected git hook blocks (pre-commit, post-merge)
- `.gitattributes` rules for collapsing `.engram/` diffs in PRs
- Global skills manifest

```bash
team-ai-kit uninstall         # Asks for confirmation before deleting
team-ai-kit uninstall --force # No confirmation (for CI/scripts)
```

### Dry Run

Use `--dry-run` (bash) or `-DryRun` (PowerShell) to see what each command would do **without modifying anything**:

```bash
team-ai-kit init --dry-run       # Shows which files would be created
team-ai-kit update --dry-run     # Shows which skills/rules would be updated
team-ai-kit uninstall --dry-run  # Shows which files would be deleted
```

> **Note**: `.engram/` is not deleted automatically. If you no longer need memory sync, delete it manually.

### Full Workflow

```powershell
# 1. Global setup (once)
team-ai-kit setup

# 2. Initialize each project
cd my-project
team-ai-kit init

# 3. If a project uses a different role
cd my-backend-api
team-ai-kit init -Role backend-node   # override without changing global

# 4. If a project uses a different team repo than the global default
cd my-other-project
team-ai-kit init -TeamRepo https://github.com/other-team/knowledge
```

### Non-Interactive Setup

```powershell
# Windows (PowerShell)
team-ai-kit setup -Ide vscode -Role frontend
team-ai-kit setup -Ide opencode -Role devops -Provider anthropic
team-ai-kit setup -Ide vscode -Role frontend -TeamRepo https://dev.azure.com/team/team-knowledge
```

```bash
# macOS / Linux
team-ai-kit setup --ide vscode --role frontend
team-ai-kit setup --ide opencode --role devops --provider anthropic
team-ai-kit setup --ide vscode --role frontend --team-repo https://github.com/team/knowledge
```

---

## Roles and Skills

Each role receives **5 shared skills** + **2-4 role-specific skills** = **23 total skill files**.

### Shared Skills (all roles)

| Skill | What it does | Trigger |
|-------|-------------|---------|
| 🏗️ **architecture** | Structure patterns, modules, dependency direction | Designing architecture |
| ✨ **code-quality** | Quality rules, conventions, clean code | Writing or reviewing code |
| 🔍 **debug** | Root cause analysis, systematic narrowing | Investigating bugs |
| 🧠 **thinking** | Problem decomposition, evaluating alternatives | Analyzing before proposing |
| ⚡ **performance** | Optimize bundle, rendering, queries, caching | Improving performance |

### Role-Specific Skills

| Role | Skills | Example Impact |
|------|--------|---------------|
| **frontend** | react, nextjs, angular, vue | Server Components by default, strict TypeScript, zero `any` |
| **backend-node** | api-design, testing | Layered separation, Zod at the boundary, DI for testing |
| **backend-java** | api-design, testing | Spring Boot patterns, JUnit 5 + Mockito, hexagonal architecture |
| **backend-dotnet** | api-design, testing | ASP.NET Core minimal APIs, xUnit + NSubstitute, clean architecture |
| **devops** | cicd, monitoring | Multi-stage Dockerfiles, fail-fast pipelines, structured JSON logging |
| **python** | api-design, testing | FastAPI structure, pytest fixtures, Pydantic validation |
| **mobile** | architecture, testing | Feature modules, MVVM/MVI, platform testing patterns |
| **data** | pipelines, testing | ETL/ELT patterns, data quality, pipeline testing |

> 📖 Detailed examples with code for every role: **[docs/examples-by-role.md](docs/examples-by-role.md)**

---

## Team Knowledge Repo

A centralized Git repo where the Tech Lead defines skills and rules that **the whole team receives automatically**:

```
team-knowledge/              # Repo maintained by tech leads
├── skills/
│   ├── shared/              # Skills for ALL roles
│   │   └── logging/
│   │       └── SKILL.md     # Team logging standard
│   └── roles/
│       └── frontend/
│           └── design-system/
│               └── SKILL.md
└── rules/                   # Cross-project rules
    └── team-conventions.md
```

```powershell
# Create the team repo
mkdir team-knowledge; cd team-knowledge; git init
team-ai-kit init-knowledge

# Setup with team repo (global default)
team-ai-kit setup -Ide vscode -Role frontend -TeamRepo https://dev.azure.com/team/team-knowledge

# Or per-project (if you work across different teams)
cd my-project
team-ai-kit init -TeamRepo https://github.com/other-team/knowledge

# Update when the team publishes changes (skills + rules in instructions)
team-ai-kit update
```

**Merge priority** (local always wins):

1. 🟢 **Local customizations** — what you modified → **never overwritten**
2. 🔵 **Team Knowledge Repo** — team skills → added if new
3. ⚪ **Package defaults** — base skills → lowest priority

> 📖 Complete guide with real step-by-step example: **[docs/team-knowledge-repo.md](docs/team-knowledge-repo.md)**

---

## engram — Team Memory

What one dev learns, the whole team knows. Automatic, via git hooks:

```
Dev A fixes bug → engram save → git push → Dev B pulls → Dev B's AI already knows
```

The AI remembers decisions, fixed bugs, established patterns — across sessions and across devs. No manual effort.

For the AI to use engram **proactively** (save without being asked, search prior context, summarize on session close), team-ai-kit injects a **Memory Protocol** into project instructions. Without this protocol, the AI has the tools but never uses them on its own.

The `update` command keeps the protocol up to date automatically.

> 📖 How it works, full flow, real example: **[docs/engram-guide.md](docs/engram-guide.md)**

---

## Architecture

```
+-------------------------------------------+
|  GLOBAL layer  (~/.copilot/skills/)       |
|  Kit base skills (architecture, debug...) |
|  Installed by: setup / update             |
+-------------------------------------------+
|  PROJECT layer (.github/skills/)          |
|  Team-knowledge repo skills               |
|  Installed by: init / update              |
+-------------------------------------------+
|  PROJECT config (committed to each repo)  |
|  .team-ai-kit.json + instructions +       |
|  .engram/ + git hooks + .gitattributes    |
+-------------------------------------------+
```

Each project has its own team skills (different teams, different stacks). Base skills are global and shared across all projects.

---

## Creating a Skill

1. Create `skills/shared/<name>/SKILL.md` (shared) or `skills/roles/<role>/<name>/SKILL.md` (role-specific):

```markdown
---
name: skill-name
description: >
  What this skill does.
  Trigger: When it should be loaded.
metadata:
  author: team-ai-kit
  version: "1.0"
---

## When to Use

- Situation 1
- Situation 2

## Critical Patterns

### Pattern 1

Explanation and examples.
```

2. Validate: `Invoke-Pester tests/skills.Tests.ps1 -Output Detailed`

### Creating a New Role

1. `skills/roles/<new-role>/` — 2+ skill files
2. `packs/<new-role>/rules.md` — role rules
3. Add to `VALID_ROLES` in `lib/functions.ps1` and `lib/functions.sh`
4. Add option in interactive menus in `bin/team-ai-kit.ps1` and `bin/team-ai-kit`

---

## Supported IDEs

| IDE | gentle-ai | MCP | Notes |
|-----|-----------|-----|-------|
| **VS Code + Copilot** | Native | Via gentle-ai | Full support |
| **IntelliJ + Copilot** | No | Via template MCP | Manual MCP config |
| **Cursor** | Native | Via gentle-ai | Full support |
| **OpenCode (CLI)** | Native | Via gentle-ai | Full support |

---

## Tests

```powershell
# Windows: Pester (unit tests)
Invoke-Pester tests/ -Output Detailed

# macOS/Linux: E2E bash
bash tests/e2e-bash.sh
```

---

## Requirements

| | Windows | macOS / Linux |
|-|---------|---------------|
| **Shell** | PowerShell 5.1+ | Bash 4+ |
| **Package manager** | Scoop (auto-install) | Homebrew (recommended) |
| **JSON** | Built-in | jq (required) |
| **Hash** | Built-in | sha256sum / shasum |
| **Git** | Required | Required |

**Dependencies**: [gentle-ai](https://github.com/Gentleman-Programming/gentle-ai), [engram](https://github.com/Gentleman-Programming/engram), [context7](https://context7.com)

---

## Project Structure

```
team-ai-kit/
├── bin/
│   ├── team-ai-kit.ps1           CLI (Windows)
│   └── team-ai-kit               CLI (macOS/Linux)
├── lib/
│   ├── functions.ps1              Functions (Windows)
│   └── functions.sh               Functions (macOS/Linux)
├── skills/
│   ├── shared/                    5 shared skills
│   └── roles/                     2-4 skills per role (8 roles)
├── packs/                         Rules per role
├── templates/                     IntelliJ (MCP config)
├── tests/
│   ├── functions.Tests.ps1        Unit tests (Pester)
│   ├── skills.Tests.ps1           Skill validation tests (Pester)
│   ├── functions-bash.sh          Unit tests (bash)
│   └── e2e-bash.sh                E2E tests (bash)
├── docs/
│   ├── examples-by-role.md        Detailed examples per role
│   ├── team-knowledge-repo.md     Team Knowledge Repo guide
│   ├── engram-guide.md            engram guide
│   ├── onboarding.md              Onboarding guide
│   └── presentation.html          Visual presentation
├── scoop/team-ai-kit.json         Scoop manifest
├── setup.ps1                      Wrapper Windows
├── setup.sh                       Wrapper macOS/Linux
└── README.md
```

---

## Documentation

| Document | Content |
|----------|---------|
| **[Examples per role](docs/examples-by-role.md)** | Before/after comparisons for all 8 roles |
| **[Team Knowledge Repo](docs/team-knowledge-repo.md)** | How to create and maintain the team knowledge repo |
| **[engram guide](docs/engram-guide.md)** | Shared memory: how it works, flow, real example |
| **[Onboarding guide](docs/onboarding.md)** | Step by step for new team members |
| **[Presentation](docs/presentation.html)** | Visual presentation of the tool |

---

## License

MIT
