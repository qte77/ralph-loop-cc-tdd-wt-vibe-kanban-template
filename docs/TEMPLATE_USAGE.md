# Template Usage

Python project template with Ralph Loop autonomous development.

## DevContainer

- **`template/`** - Template dev (Alpine ~10MB)
- **`project/`** - Project dev (Python + Node + Docker ~1GB+)

See `.devcontainer/README.md`.

## Setup Steps

### 1. Setup Development Environment

```bash
# Clone this template
git clone <your-repo-url>
cd <your-repo>

# Customize the template
make setup_project

# Install dependencies and tooling
make setup_dev
```

### 2. Write Requirements

**Option A (Manual)**: Edit **`docs/PRD.md`** with your product requirements.

**Option B (Assisted)**: Use interactive workflow:

```bash
make ralph_create_userstory_md  # Create UserStory.md via Q&A
make ralph_create_prd_md        # Generate PRD.md from UserStory.md
```

### 3. Run Ralph Loop

```bash
make ralph_init_loop              # Initialize (creates prd.json)
make ralph_run ITERATIONS=10      # Run autonomous development
make ralph_run DEBUG=1            # Watch logs in real-time (optional)
make ralph_status                 # Check progress (with timestamp)
```

- To generate prd.json: Run `claude -p '/generating-prd-json-from-prd-md'` skill.
- For DEBUG mode and advanced options see [Ralph README.md](../ralph/README.md).

### Starting New Product Iteration

When PRD.md changes significantly, reorganize and archive:

```bash
make ralph_archive NEW_PRD=docs/PRD-v2.md VERSION=2
```

Archives current PRD, prd.json, and progress to `ralph/docs/archive/`, then
activates new PRD.

## Optional: MCP Servers

Template includes `context7` and `exa` MCP servers. Remove from
`.claude/settings.json` if not needed.

## Optional: Vibe Kanban UI

Ralph can sync status to Vibe Kanban for real-time visual monitoring:

```bash
# Terminal 1: Start Vibe Kanban
npx vibe-kanban

# Terminal 2: Run Ralph (auto-syncs!)
make ralph_run N_WT=3
```

Ralph auto-detects Vibe Kanban and displays live task updates. See
[ralph/docs/UI.md](../ralph/docs/UI.md) for details.

**Configuration**: `make ralph_init_loop` creates `.vibe-kanban/project.json`
from template automatically.

## Directory Structure

```text
your-project/
├── .claude/              # Claude Code configuration
├── .devcontainer/        # DevContainer configs (template/ & project/)
├── docs/
│   ├── PRD.md           # Product requirements (edit this!)
│   └── archive/         # Previous iterations
├── ralph/               # Ralph Loop automation
│   ├── scripts/         # Ralph automation scripts
│   └── docs/            # Ralph state (gitignored)
├── src/                 # Your source code
├── tests/               # Your tests
├── Makefile             # Build automation
└── pyproject.toml       # Python project config
```

## Common Commands

```bash
make setup_project     # Customize template
make setup_dev         # Setup environment
make validate          # Run all checks

# Ralph (Optional assisted workflow)
make ralph_create_userstory_md   # [Optional] Create UserStory.md interactively
make ralph_create_prd_md         # [Optional] Generate PRD.md from UserStory.md

# Ralph (Core workflow)
make ralph_init_loop   # Initialize Ralph (creates prd.json)
make ralph_run         # Run autonomous dev
make ralph_run DEBUG=1 # Watch logs (optional)
make ralph_status      # Check progress (with timestamp)
make ralph_clean       # Reset state (removes prd.json, progress.txt)
make ralph_archive     # Archive and start new iteration

make help              # Show all commands
```

## Next Steps

1. Delete `TEMPLATE_USAGE.md`
2. Write requirements in `docs/PRD.md`
3. Run `make ralph_run` for autonomous implementation

See `.claude/skills/` for available skills and `make help` for all commands.

For adding Ralph to an **existing project** (submodule), see
[Consumption Approaches](../README.md#consumption-approaches).
