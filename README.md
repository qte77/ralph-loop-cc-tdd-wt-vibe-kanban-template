# Ralph-Loop Template

> What a time to be alive

Language-agnostic project template using Ralph Loop autonomous development with plugin-based scaffold architecture

![Version](https://img.shields.io/badge/version-0.0.0-58f4c2.svg)
[![License](https://img.shields.io/badge/license-BSD3Clause-58f4c2.svg)](LICENSE.md)
[![CodeQL](https://github.com/YOUR-ORG/YOUR-PROJECT-NAME/actions/workflows/codeql.yaml/badge.svg)](https://github.com/YOUR-ORG/YOUR-PROJECT-NAME/actions/workflows/codeql.yaml)
[![CodeFactor](https://www.codefactor.io/repository/github/YOUR-ORG/YOUR-PROJECT-NAME/badge)](https://www.codefactor.io/repository/github/YOUR-ORG/YOUR-PROJECT-NAME)
[![ruff](https://github.com/YOUR-ORG/YOUR-PROJECT-NAME/actions/workflows/ruff.yaml/badge.svg)](https://github.com/YOUR-ORG/YOUR-PROJECT-NAME/actions/workflows/ruff.yaml)
[![pyright](https://github.com/YOUR-ORG/YOUR-PROJECT-NAME/actions/workflows/pyright.yaml/badge.svg)](https://github.com/YOUR-ORG/YOUR-PROJECT-NAME/actions/workflows/pyright.yaml)
[![pytest](https://github.com/YOUR-ORG/YOUR-PROJECT-NAME/actions/workflows/pytest.yaml/badge.svg)](https://github.com/YOUR-ORG/YOUR-PROJECT-NAME/actions/workflows/pytest.yaml)
[![Link Checker](https://github.com/YOUR-ORG/YOUR-PROJECT-NAME/actions/workflows/links-fail-fast.yaml/badge.svg)](https://github.com/YOUR-ORG/YOUR-PROJECT-NAME/actions/workflows/links-fail-fast.yaml)
[![Deploy Docs](https://github.com/YOUR-ORG/YOUR-PROJECT-NAME/actions/workflows/generate-deploy-mkdocs-ghpages.yaml/badge.svg)](https://github.com/YOUR-ORG/YOUR-PROJECT-NAME/actions/workflows/generate-deploy-mkdocs-ghpages.yaml)

## Features

- **Ralph Loop** - Autonomous development using a shell loop
- **Claude Code** - Pre-configured skills, plugins, rules, and commands for
  AI-assisted development
- **Plugin-based Scaffold** - Language-agnostic core; language toolchain installed
  on demand via `make setup_scaffold LANG=<lang>`
- **Makefile** - Split architecture: core recipes in `Makefile`,
  language-specific recipes in `Makefile.<lang>` (auto-included from `.scaffold`)
- **MkDocs** - Auto-generated documentation with GitHub Pages deployment
- **GitHub Actions** - CI/CD workflows (CodeQL, ruff, pyright, pytest, link
  checking, docs deployment)
- **DevContainers** - Template (Alpine ~10MB) and actual project
  (Python/Node/Docker ~1GB+)
- **VS Code** - Workspace settings, tasks, and extensions for development
- **Configurable Model routing** - Use different models for hard or easy tasks.
  See [Ralph README.md](./ralph/README.md#configuration).

## Scaffold Workflow

The scaffold system writes a `.scaffold` file (gitignored) that controls which
`Makefile.<lang>` is auto-included at build time:

```bash
# Initialize scaffold for your language (run once after cloning)
make setup_scaffold LANG=python     # Python: ruff, pyright, pytest, mkdocs
make setup_scaffold LANG=embedded   # Embedded C: cmake build + flash

# Install the toolchain for the active scaffold
make setup_toolchain

# Validate — dispatches to the active scaffold's validate recipe
make validate
```

Supported languages:

| `LANG` | Toolchain | Validate |
|--------|-----------|---------|
| `python` | uv, ruff, pyright, pytest | ruff + pyright + complexipy + pytest |
| `embedded` | cmake, C compiler | cmake build |

Language-specific Claude Code skills are **not** checked into the template.
Install them from [claude-code-utils-plugin](https://github.com/qte77/claude-code-utils-plugin)
as needed for your language.

## Quick Start

```bash
# 1. Choose your language scaffold (written to .scaffold, gitignored)
make setup_scaffold LANG=python

# 2. Install toolchain (also runs automatically in devcontainer via onCreateCommand)
make setup_toolchain

# 3. Customize template with your project details
make setup_project

# Optional
make ralph_create_userstory_md            # Interactive User Story using CC
make ralph_create_prd_md                  # Generate PRD.md from UserStory.md

# 4. Write requirements in docs/PRD.md, then run Ralph
make ralph_init_loop             # Initialize (creates prd.json)
make ralph_run [ITERATIONS=25]   # Run autonomous development
make ralph_run                   # Resume if paused (auto-detects existing worktrees)
make ralph_status                # Check progress (with timestamp)

# 5. Post-run options
# Reset state (removes prd.json, progress.txt)
make ralph_clean
# Archive and start new iteration
make ralph_archive NEW_PRD=docs/PRD-v2.md [VERSION=2]
```

For detailed setup and usage, see
[docs/TEMPLATE_USAGE.md](docs/TEMPLATE_USAGE.md). For Ralph Loop details see
[Ralph README.md](./ralph/README.md).

## Workflow

```text
Document Flow:
  UserStory.md (Why) → PRD.md (What) → prd.json → Implementation → progress.txt

Human Workflow (Manual):
  Write PRD.md → make ralph_init_loop → make ralph

Human Workflow (Assisted - Optional):
  make ralph_create_userstory_md → make ralph_create_prd_md → make ralph_init_loop → make ralph

Agent Workflow:
  PRD.md → prd.json (generating-prd-json-from-prd-md skill) → Ralph Loop → src/ + tests/
  Uses: .claude/skills/, .claude/rules/

Mandatory for Both:
  CONTRIBUTING.md - Core principles (KISS, DRY, YAGNI)
  Makefile        - Build automation and validation
  .gitmessage     - Commit message format
```

## Consumption Approaches

### 1. GitHub Template (default)

Use "Use this template" on GitHub. Full project scaffold with `ralph/`,
`.claude/`, CI workflows, devcontainer, etc.

### 2. Git Submodule (existing project)

Add Ralph as a submodule at `ralph/`. Scripts update automatically
via `git submodule update --remote`. Local state files (`prd.json`,
`progress.txt`, `LEARNINGS.md`, `archive/`) are gitignored in the
template so they survive updates.

```bash
# Add submodule
git submodule add --branch main \
  https://github.com/qte77/ralph-loop-cc-tdd-wt-vibe-kanban-template.git \
  ralph

# Initialize local state files (gitignored, never overwritten)
cp ralph/LEARNINGS.md.example ralph/LEARNINGS.md
cp ralph/REQUESTS.md.example ralph/REQUESTS.md
mkdir -p ralph/docs/archive

# Include ralph's Makefile from your project root Makefile
echo '-include ralph/Makefile' >> Makefile

# Ignore dirty submodule state (local files)
git config -f .gitmodules submodule.ralph.ignore dirty
```

**Update:**

```bash
git submodule update --remote ralph
git add ralph
git commit -m "chore: update ralph submodule"
```

**Makefile integration:** Ralph ships a scoped `Makefile` with all
`ralph_*` recipes using relative paths. Include it from your
project root:

```makefile
# Project root Makefile
-include ralph/Makefile
```

**CI (required):** Add `submodules: recursive` to all
`actions/checkout` steps. Without this, CI clones the repo but
leaves `ralph/` empty — any workflow running `make validate`,
`make test`, or ralph commands will fail.

```yaml
- uses: actions/checkout@v4
  with:
    submodules: recursive
```

**`.claude/`** can be symlinked (read-only) or copied (overrides).
Claude Code merges `.claude/settings.local.json` over
`.claude/settings.json`.

### 3. Standalone CLI (planned)

Install Ralph as a standalone binary. No git integration needed.
Candidates: Go (static binary, zero deps), Bun/Deno (scripting feel +
native JSON). See [Ralph README.md TODO](./ralph/README.md#todo--future-work)
for scope analysis.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development workflow, core
principles, and contribution guidelines.
