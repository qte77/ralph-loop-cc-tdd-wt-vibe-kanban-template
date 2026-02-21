# Ralph Loop - Template Usage Guide

Quick reference for using Ralph Loop in your project.

## Initial Setup

```bash
# 1. Clone and customize (for template projects)
git clone <your-repo-url> && cd <your-repo>
bash ralph/scripts/setup_project.sh    # Interactive project customization

# 2. Install dependencies
make setup_dev                         # Python deps, tooling
```

## Workflow

### Option A: Manual PRD

1. Edit `docs/PRD.md` with your requirements
2. Run Ralph:

   ```bash
   make ralph_init_loop                # PRD.md -> prd.json + validate env
   make ralph_run ITERATIONS=25        # Start autonomous loop
   ```

### Option B: Assisted PRD (Interactive)

```bash
make ralph_create_userstory_md         # Interactive Q&A -> UserStory.md
make ralph_create_prd_md               # UserStory.md -> PRD.md
make ralph_init_loop                   # PRD.md -> prd.json + validate env
make ralph_run ITERATIONS=25           # Start autonomous loop
```

### Option C: One Command (init + run)

```bash
make ralph_init_and_run ITERATIONS=25  # Initialize and run in one step
```

### Story Dependencies

In `docs/PRD.md` story breakdown, use `(depends: STORY-XXX)` syntax:

```markdown
- **Feature 2** -> STORY-002: Create API, STORY-003: Integrate API (depends: STORY-002)
```

The parser generates `prd.json` with dependency tracking. Ralph skips
stories with unmet dependencies until prerequisites complete.

### Sprint-Specific PRD Management

Each sprint gets its own PRD file. The parser reads `docs/PRD.md`:

```bash
# Switch to a new sprint
cd docs && ln -sf sprints/PRD-SprintN.md PRD.md && cd ..
make ralph_init_loop
make ralph_run
```

## Parallel Worktrees

All execution uses git worktrees for isolation (even `N_WT=1`):

```bash
# Single loop (default)
make ralph_run ITERATIONS=25               # 1 worktree, no scoring

# Parallel loops
make ralph_run N_WT=3 ITERATIONS=25        # 3 worktrees, scores, merges best

# With judge evaluation
RALPH_JUDGE_ENABLED=true make ralph_run N_WT=3

# Debug mode (watch + persist)
make ralph_run DEBUG=1 N_WT=3
```

## Vibe Kanban Integration

Real-time visual monitoring of Ralph progress:

```bash
make vibe_start                            # Start UI on port 5173
make ralph_run N_WT=3                      # Auto-syncs to Vibe Kanban
make vibe_status                           # Check if running
make vibe_cleanup                          # Remove all tasks
make vibe_stop_all                         # Stop all instances
```

## Monitoring

```bash
make ralph_status                          # Show progress
make ralph_watch                           # Live output (all worktrees)
make ralph_get_log WT=2                    # Specific worktree log
make validate                              # Run linters + tests
```

## Reset / Iterate

```bash
make ralph_archive ARCHIVE_LOGS=1          # Archive state + logs
make ralph_clean                           # Reset state (double confirmation)
make ralph_reorganize_prd NEW_PRD=docs/PRD-v2.md VERSION=2
```

## Commands Reference

| Command | Description |
|---------|-------------|
| `make ralph_create_userstory_md` | Create `docs/UserStory.md` interactively |
| `make ralph_create_prd_md` | Generate `docs/PRD.md` from UserStory.md |
| `make ralph_init_loop` | Generate prd.json + validate environment |
| `make ralph_init_and_run` | Initialize and run in one command |
| `make ralph_run` | Run autonomous loop (`N_WT=`, `ITERATIONS=`, `DEBUG=1`) |
| `make ralph_reorganize_prd` | Archive current PRD, activate new one |
| `make ralph_status` | Show progress summary |
| `make ralph_watch` | Live-watch all worktree logs |
| `make ralph_get_log` | View specific worktree log (`WT=`) |
| `make ralph_stop` | Stop all running Ralph loops |
| `make ralph_clean` | Reset state (worktrees + local, double confirmation) |
| `make ralph_archive` | Archive current run state (`ARCHIVE_LOGS=1`) |
| `make validate` | Run quality checks (ruff, pyright, pytest) |

## Configuration

Environment variables (set in shell or pass to make):

```bash
# Parallel execution
N_WT=3 make ralph_run                      # 3 worktrees
ITERATIONS=50 make ralph_run               # Override default (25)

# Judge evaluation (N_WT>1)
RALPH_JUDGE_ENABLED=true make ralph_run N_WT=3
RALPH_JUDGE_MODEL=opus make ralph_run N_WT=3
RALPH_SECURITY_REVIEW=true make ralph_run N_WT=2
RALPH_MERGE_INTERACTIVE=true make ralph_run N_WT=2

# Debug mode
DEBUG=1 make ralph_run N_WT=3              # Auto-watch, persist worktrees
```

See `ralph/scripts/lib/config.sh` for all configuration variables.

## Directory Structure

```text
your-project/
├── .claude/                    # Claude Code configuration
│   ├── skills/                 # Agent capabilities
│   ├── rules/                  # Behavioral guidelines
│   └── settings.json           # Claude Code settings
├── docs/
│   ├── PRD.md                  # Product Requirements Document
│   └── UserStory.md            # User stories (optional)
├── ralph/
│   ├── CHANGELOG.md            # Ralph version history
│   ├── CONTRIBUTING.md         # Command reference
│   ├── LEARNINGS.md            # Accumulated agent knowledge
│   ├── README.md               # Methodology overview
│   ├── REQUESTS.md             # Human-to-agent communication
│   ├── TEMPLATE_USAGE.md       # This file
│   ├── docs/
│   │   ├── prd.json            # Story tracking (gitignored)
│   │   ├── progress.txt        # Execution log (gitignored)
│   │   └── templates/
│   │       ├── prompt.md            # Upstream agent prompt
│   │       ├── story.prompt.md      # Local agent prompt
│   │       ├── judge.prompt.md      # Judge evaluation prompt
│   │       ├── prd.json.template
│   │       ├── prd.md.template
│   │       ├── progress.txt.template
│   │       └── userstory.md.template
│   └── scripts/
│       ├── parallel_ralph.sh   # Orchestrator (worktrees, scoring, merge)
│       ├── ralph.sh            # Worker (TDD loop per worktree)
│       ├── init.sh             # Environment initialization
│       ├── archive.sh          # Archive current run state
│       ├── clean.sh            # Clean Ralph state
│       ├── stop.sh             # Stop running loops
│       ├── vibe.sh             # Vibe Kanban management
│       └── lib/
│           ├── config.sh            # Centralized configuration
│           ├── common.sh            # Shared utilities (logging, colors)
│           ├── baseline.sh          # Baseline-aware test validation
│           ├── colors.sh            # Legacy logging (kept for compat)
│           ├── judge.sh             # Claude-as-Judge evaluation
│           ├── vibe.sh              # Vibe Kanban REST API
│           ├── validate_json.sh     # JSON validation
│           └── generate_app_docs.sh # README/example generation
├── src/                        # Source code
├── tests/                      # Tests
├── logs/ralph/                 # Execution logs (gitignored)
└── Makefile                    # Build automation
```

## TDD Workflow

Ralph enforces Test-Driven Development with commit markers:

1. **RED Phase**: Write failing tests
   - Commit with `[RED]` marker
2. **GREEN Phase**: Implement features
   - Commit with `[GREEN]` marker
3. **REFACTOR Phase** (optional): Clean up code
   - Commit with `[REFACTOR]` or `[BLUE]` marker

Ralph verifies commits are in chronological order (RED before GREEN).

## Quality Checks (Baseline-Aware)

Ralph uses baseline-aware validation:

- **Baseline capture**: Test failures snapshot before each story starts
- **Regression detection**: Only new failures block progress
- **Teams scoping**: In teams mode, checks scoped to story files
- **Wave checkpoints**: Full `make validate` at wave boundaries
- **Impact diagnostics**: Agent greps for consumers before renames

## Troubleshooting

**Ralph skips stories:**

- Check dependencies in `prd.json` (unmet `depends_on`)
- Verify `passes: false` for stories to execute

**TDD verification fails:**

- Ensure commit messages have `[RED]`, `[GREEN]` markers
- Commits must be in order (RED before GREEN)
- Check `logs/ralph/` for details

**Quality checks fail:**

- Run `make validate` manually
- Fix linting: `make ruff`
- Fix types: `make type_check`

**Reset and retry:**

```bash
make ralph_clean                       # Clear state (double confirmation)
make ralph_init_loop                   # Regenerate from PRD.md
make ralph_run                         # Start fresh
```
