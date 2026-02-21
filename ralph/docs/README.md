# Ralph Loop - Autonomous TDD development loop with Claude Code

Autonomous development loop that executes stories from prd.json using
Test-Driven Development with Claude Code.

## Prerequisites

Ralph Loop requires the following system dependencies:

- **Bash** - Shell interpreter (pre-installed on Linux/macOS)
- **Claude Code CLI** - `claude` command ([installation guide](https://github.com/anthropics/claude-code))
- **jq** - JSON processor
  - Linux: `apt-get install jq` or `yum install jq`
  - macOS: `brew install jq`
  - Verify: `jq --version`
- **git** - Version control (required for worktrees)
- **make** - Build automation tool

Run `make ralph_init_loop` to validate all prerequisites are installed.

## Quick Start

```bash
make ralph_run [ITERATIONS=25]              # Single loop (isolated via worktree)
make ralph_run N_WT=5 ITERATIONS=25         # 5 parallel loops
make ralph_run DEBUG=1 N_WT=3               # Debug mode (watch,
                                            # persist)
```

### Visual Monitoring with Vibe Kanban

```bash
# Start Vibe Kanban UI
make vibe_start          # Start on port 5173
make vibe_status         # Check if running
make vibe_cleanup        # Remove all tasks
make vibe_stop_all       # Stop all Vibe Kanban instances

# Run Ralph (auto-syncs in real-time)
make ralph_run N_WT=3
```

Ralph auto-detects Vibe Kanban on configured port and syncs status in real-time. See [UI.md](./UI.md) for details.

### Optional: Visual Workflow Design

[CC Workflow Studio](https://github.com/breaking-brake/cc-wf-studio) provides a drag-and-drop VS Code extension for designing Claude Code agent workflows visually. Useful for creating `.claude/skills/` and `.claude/commands/` files.

Install from VS Code Marketplace: `breaking-brake.cc-wf-studio`

### Compound Engineering - Knowledge Management

Ralph implements compound engineering: each solved problem makes future work easier through systematic knowledge capture.

```bash
# Agents automatically append learnings after each story completion
# LEARNINGS.md accumulates: validation fixes, code patterns, common mistakes

# Periodically review and prune (recommended: every 5-10 stories)
claude -p /review-learnings
```

**Files:**

- `ralph/docs/LEARNINGS.md` - Accumulated knowledge (read before each story)
- `ralph/docs/REQUESTS.md` - Human→agent guidance (edit while Ralph runs)

**Workflow:** Plan → Work (TDD) → Compound (append learning) → Review (prune/declutter)

## How It Works

```text
parallel_ralph.sh (orchestrator - always used, even N_WT=1)
  ├─> creates N_WT git worktrees (isolated environments)
  ├─> runs ralph.sh in each worktree (background jobs)
  │   └─> ralph.sh (worker):
  │       ├─> reads prd.json (incomplete stories)
  │       ├─> builds prompt from templates/story.prompt.md + story details
  │       ├─> invokes: claude -p --dangerously-skip-permissions
  │       │   └─> Agent follows TDD workflow:
  │       │       ├─ RED: write failing tests → commit [RED]
  │       │       ├─ GREEN: implement code → commit [GREEN]
  │       │       └─ REFACTOR: clean up → commit [REFACTOR]
  │       ├─> verifies TDD commits ([RED] and [GREEN] markers)
  │       ├─> runs: make validate
  │       │   ├─ If pass: mark story complete
  │       │   └─ If fail: invoke fix loop (max 3 attempts)
  │       ├─> generates docs (README.md, example.py)
  │       ├─> commits state: prd.json, progress.txt, docs
  │       └─> repeats until no incomplete stories or max iterations
  ├─> waits for all worktrees to complete
  ├─> N_WT=1: merges result (no scoring overhead)
  ├─> N_WT>1: scores all, merges best result
  └─> cleans up worktrees
```

## Architecture

Ralph leverages Claude Code features (rules, skills, prompts) for optimal agent guidance:

```text
┌─────────────────────────────────────────┐
│ .claude/rules/core-principles.md        │ ← Auto-applied globally (all sessions)
│ (KISS, DRY, YAGNI, user-centric)        │    Project-wide principles
└─────────────────────────────────────────┘
           ↓ References

┌─────────────────────────────────────────┐
│ .claude/skills/implementing-python/     │ ← Invokable by agents (contextual)
│ .claude/skills/reviewing-code/          │    Specialized workflows
│ .claude/skills/designing-backend/       │
└─────────────────────────────────────────┘
           ↓ Listed in

┌─────────────────────────────────────────┐
│ ralph/docs/templates/story.prompt.md    │ ← Piped to claude -p (dynamic)
│ + LEARNINGS.md (accumulated knowledge)  │    Ralph-specific instructions
│ + REQUESTS.md (human guidance)          │    Runtime content injection
│ + Story details (prd.json)              │
└─────────────────────────────────────────┘
```

**Design rationale:**

- **Rules**: Global principles (auto-applied, all Claude sessions)
- **Skills**: Invokable workflows (agent decides when to use)
- **Prompts**: Scoped instructions (Ralph-only, supports dynamic content)

## File Structure

```text
ralph/
├── docs/
│   ├── README.md              # This file
│   ├── prd.json              # Story definitions and status
│   ├── progress.txt          # Execution log
│   ├── LEARNINGS.md          # Accumulated agent knowledge (compound engineering)
│   ├── REQUESTS.md           # Human→agent communication channel
│   └── templates/
│       └── story.prompt.md   # Agent instructions (TDD workflow)
└── scripts/
    ├── parallel_ralph.sh     # Orchestrator: worktree management, scoring, merging
    ├── ralph.sh              # Worker: TDD loop execution (runs inside worktrees)
    ├── init.sh              # Environment initialization
    ├── archive.sh           # Archive current run state
    ├── abort.sh             # Terminate running loops
    ├── clean.sh             # Clean Ralph state (worktrees + local)
    ├── vibe.sh              # Vibe Kanban management (start/stop_all/status/cleanup)
    └── lib/
        ├── config.sh        # Centralized configuration
        ├── colors.sh        # Logging utilities
        ├── validate_json.sh # JSON validation utilities
        ├── vibe.sh          # Vibe Kanban REST API integration
        └── generate_app_docs.sh  # README/example generation
```

## Script Usage

- `init.sh` - Initialize environment (first time setup)
- `archive.sh` - Archive completed run before new iteration
- `abort.sh` - Emergency stop (kills loops + cleans worktrees)
- `clean.sh` - Reset to clean state (removes worktrees + local state)

## Commit Architecture

**Agent commits** (during story execution):

- `test(STORY-XXX): ... [RED]` - Failing tests
- `feat(STORY-XXX): ... [GREEN]` - Implementation
- `refactor(STORY-XXX): ... [REFACTOR]` - Cleanup

**Script commits** (after validation passes):

- `docs(STORY-XXX): update state and documentation` - State files

**Why both?** Agent commits prove TDD compliance. Script commits track progress.

## Validation & Fixes

1. **Initial validation**: `make validate` after story execution
2. **If fails**: Auto-retry loop (MAX_FIX_ATTEMPTS=3)
   - Re-invokes agent with error output
   - Re-runs `make validate`
   - Continues until pass or max attempts
3. **If passes**: Mark story complete, generate docs, commit state

## Configuration

Centralized in `ralph/scripts/lib/config.sh`:

**Execution:**

- `RALPH_MAX_ITERATIONS=10` - Loop iterations
- `RALPH_MAX_FIX_ATTEMPTS=3` - Fix attempts
- `RALPH_VALIDATION_TIMEOUT=300` - Validation timeout (5 min)
- `RALPH_FIX_TIMEOUT=600` - Fix timeout (10 min)

**Models (Automatic Routing):**

- `RALPH_DEFAULT_MODEL="sonnet"` - Story implementation (complex logic)
- `RALPH_SIMPLE_MODEL="haiku"` - Simple changes (docs, typos, formatting)
- `RALPH_FIX_MODEL="haiku"` - Validation error fixes
- `RALPH_JUDGE_MODEL="sonnet"` - Claude-as-Judge evaluation (quality assessment)

Story complexity detection: checks title/description for patterns like "fix", "typo", "doc", "format". Judge uses specified model for worktree comparison (N_WT>1).

**Override hierarchy:**

1. CLI: `./ralph.sh 50`
2. Env: `VALIDATION_TIMEOUT=600 ./ralph.sh`
3. Config: `ralph/scripts/lib/config.sh`

See `config.sh` header for complete list.

## Output Files

- `prd.json` - Updated with completion timestamps
- `progress.txt` - Iteration log (PASS/FAIL/RETRY status)
- `src/*/README.md` - Generated application documentation
- `src/*/example.py` - Generated usage example

## Quality Gates

All stories must pass:

- Code formatting (ruff)
- Type checking (pyright)
- All tests (pytest)

Via: `make validate`

## TDD Verification

Script enforces:

- Minimum 2 commits per story
- [RED] marker present (tests committed first)
- [GREEN] marker present (implementation committed second)
- Correct commit order (RED before GREEN)

Skipped for STORY-001 (ramp-up).

## Autonomous Operation

Runs without human approval:

- `--dangerously-skip-permissions` flag on all Claude invocations
- Auto-commits state files
- Auto-pushes to remote at completion
- No interactive prompts

## Execution Modes

**All execution uses git worktrees** (even N_WT=1) for safety and isolation.

### Create New Run

```bash
# Single loop (N_WT=1, default)
make ralph_run [ITERATIONS=25]      # Isolated in worktree, no scoring overhead

# Parallel loops (N_WT>1)
make ralph_run N_WT=5 ITERATIONS=25    # 5 worktrees, scores results, merges best
```

### Resume Paused Run

**Automatic resume detection**: If existing worktrees are found (not locked),
`make ralph_run` automatically resumes them:

```bash
# If paused worktrees exist:
make ralph_run                      # Auto-resumes all existing worktrees
                                # ITERATIONS parameter ignored (uses existing state)
                                # N_WT detected from existing worktrees
```

**Behavior:**

- Detects paused worktrees automatically
- Continues from last completed story
- Appends "Resumed:" marker to progress.txt
- Uses existing run_id and state

### Monitoring

```bash
make ralph_status               # Progress summary with timestamp
make ralph_watch                # Show process tree + live tail all logs
make ralph_get_log WT=2             # View specific worktree
```

**DEBUG Mode:**

```bash
make ralph_run DEBUG=1 N_WT=3       # Starts worktrees + watches logs
                                # Ctrl+C exits watch, worktrees continue
                                # No auto-merge (manual intervention required)
```

When DEBUG=1:

- Automatically starts log watching (like `make ralph_watch`)
- Worktrees run in background and persist after Ctrl+C
- No automatic scoring or merging
- Use `make ralph_status` to check progress later
- Use `make ralph_abort` to stop worktrees if needed

### Control

```bash
make ralph_abort                # Abort all loops + cleanup
make ralph_clean                # Clean worktrees + local state
                                # (requires double confirmation)
```

**Safety Features:**

- `ralph_clean` requires double confirmation:
  1. Type `'yes'` to confirm
  2. Type `'YES'` (uppercase) to proceed
- Shows what will be deleted before asking for confirmation
- Cannot be undone - use with caution

### Judge-Based Selection (Optional)

Enable LLM-based worktree evaluation for quality-focused selection.

**Environment variables** are passed through to the bash script:

```bash
# Basic judge mode (autonomous)
RALPH_JUDGE_ENABLED=true make ralph_run N_WT=3

# With security review
RALPH_JUDGE_ENABLED=true RALPH_SECURITY_REVIEW=true make ralph_run N_WT=2

# Human-in-the-loop (interactive merge approval)
RALPH_JUDGE_ENABLED=true RALPH_MERGE_INTERACTIVE=true make ralph_run N_WT=2

# Increase max worktrees for judge (default: 5)
RALPH_JUDGE_ENABLED=true RALPH_JUDGE_MAX_WT=10 make ralph_run N_WT=8

# Use opus for judge (higher quality evaluation)
RALPH_JUDGE_ENABLED=true RALPH_JUDGE_MODEL=opus make ralph_run N_WT=3
```

**How it works:**

- Judge evaluates: **correctness > test quality > code clarity**
- Falls back to metrics if N_WT > `RALPH_JUDGE_MAX_WT` or on timeout
- Autonomous by default (no human approval required)
- Optional security review via `/security-review` skill
- Optional interactive approval before final commit

**Execution States:**

- **Active (locked)**: Ralph loop running → `make ralph_run` aborts with
  error, use `make ralph_abort` first
- **Paused (unlocked)**: Ralph loop stopped/interrupted →
  `make ralph_run` auto-resumes
- **Clean**: No worktrees exist → `make ralph_run` creates new run

**Interrupt Handling:**

- **Ctrl+C during execution**: Background processes persist (detached via
  `disown`), worktrees unlocked but preserved for resume
- **Successful completion**: Worktrees are cleaned up automatically
  (after merging best result)
- **Merge failure**: Worktrees are unlocked but preserved (for debugging)

**Background Process Persistence:**

All worktrees run as detached background processes (via `disown`):

- Survive Ctrl+C interrupts
- Survive terminal disconnects
- Survive parent shell exit
- Check progress: `make ralph_status`
- Stop manually: `make ralph_abort`

**Scoring:**

(N_WT>1 only): `base + coverage_bonus - penalties`

- base = `(stories × 10) + test_count + validation_bonus`
- coverage_bonus = `coverage% / 2` (0-50 points)
- penalties = `(ruff × 2) + (pyright_err × 5) + (pyright_warn × 1) +
  (churn / 100)`

**Config:**

`RALPH_PARALLEL_*` variables in `ralph/scripts/lib/config.sh`

## Execution Flow Details

```text
make ralph_run [N_WT=1] [ITERATIONS=25]
  └─> parallel_ralph.sh
       ├─> creates N_WT worktrees
       ├─> for each worktree: ralph.sh (background) →
       │    └─> while stories incomplete:
       │         ├─ get_next_story() → story_id
       │         ├─ execute_story() → claude -p (TDD workflow)
       │         ├─ check_tdd_commits() → verify [RED]/[GREEN]
       │         ├─ run_quality_checks() → make validate
       │         │   └─ if fail: fix_validation_errors() (3 attempts)
       │         ├─ if pass: update_story_status() → prd.json
       │         ├─ commit_story_state() → git commit
       │         └─ repeat
       ├─> wait for all worktrees
       ├─> if N_WT=1: merge worktree 1
       ├─> if N_WT>1: score all, merge best
       └─> cleanup worktrees
```

## Troubleshooting

- **No commits made**: Agent didn't follow TDD workflow, story retries
- **TDD verification failed**: Missing [RED] or [GREEN] markers, story retries
- **Quality checks failed**: Fix loop invoked (3 attempts), then marked FAIL
- **Max iterations reached**: Loop stops, check progress.txt for failures

## TODO

### High Priority (High ROI)

- [x] **Claude Judge for Parallel Runs**: Implemented LLM-as-Judge using
  pairwise comparison for worktree selection. Judge evaluates code
  quality, test coverage, correctness using `claude -p`. Falls back to
  metrics if N_WT > `RALPH_JUDGE_MAX_WT` (default: 5). Includes optional
  security review (`/security-review`) and interactive merge approval.
  Autonomous by default. Config: `RALPH_JUDGE_ENABLED`,
  `RALPH_JUDGE_MAX_WT`, `RALPH_SECURITY_REVIEW`,
  `RALPH_MERGE_INTERACTIVE`. Files: `templates/judge.prompt.md`,
  `lib/judge.sh`.
- [x] **Directory Consolidation**: Consolidated `scripts/ralph/` and
  `docs/ralph/` into single `ralph/` root directory for cleaner ownership.
  Structure: `ralph/{scripts,docs}`.
- [ ] **Clean up intermediate files**: Remove `*_green.py`, `*_red.py`,
  `*_stub` after story completion
- [ ] **E2E tests**: Add end-to-end test coverage for full application paths

### Medium Priority

- [ ] **Smart Story Distribution**: Analyze dependency graph, run
  independent stories in parallel by spinning up a new worktree
- [x] **Memory/Lessons Learned**: Implemented `LEARNINGS.md` for compound
  engineering. Agents auto-read before each story, append learnings after
  completion. Tracks validation fixes, code patterns, common mistakes,
  testing strategies. Persistent across runs (git-tracked).
- [x] **Bi-directional Communication**: Implemented `REQUESTS.md` for
  human→agent communication. Edit while Ralph runs to communicate priority
  changes, style preferences, constraints. Changes picked up next iteration.
- [ ] **Auto-resolve Conflicts**: Programmatic merge conflict resolution
- [ ] **Plugin Integration**: Ralph commands as Claude Code skills on marketplace
- [ ] **Packaging for pypi and npm**: Provide as packages for python and node
- [x] **Vibe Kanban UI Integration**: Integrated Vibe Kanban for real-time visual monitoring. Auto-detects on port 5173, syncs task status (todo/inprogress/done), supports parallel worktrees. REST API integration via `lib/vibe.sh`. See [UI.md](./UI.md) for usage.

### Low Priority (Future Exploration)

- [x] **Real-time Dashboard**: Live monitoring UI via Vibe Kanban
  (vibekanban.com). Uni-directional REST API integration from Ralph.
  See `make vibe_*` targets and [UI.md](./UI.md).
- [ ] **JSON Status API Output** (Team/Enterprise quick win): Add
  `make ralph_status_json` for structured output. Foundation for
  dashboards, CI/CD hooks, monitoring. Enables Grafana, Datadog,
  custom UIs.
- [ ] **Slack/Teams Notifications** (Team/Enterprise quick win): Post
  completion/failure alerts to team channels. Hook into
  `parallel_ralph.sh` completion. Example: "Ralph completed STORY-005 ✅"
  → `#dev-alerts`.
- [ ] **Rippletide Eval Integration**: Add hallucination detection for
  generated docs/comments using
  [Rippletide Eval CLI](https://docs.rippletide.com). Scores agent
  outputs 1-4, flags unsupported claims.
- [ ] **Mobile/Remote Monitoring**: Options evaluated:
  - **Claude iOS App** (claude.ai/code): ❌ Incompatible - runs in cloud
    sandbox, can't access local worktrees/make commands
  - **Omnara**: ⚠️ Limited - wraps local Claude Code but no devcontainer
    support, legacy version deprecated
  - **Conductor.build**: ❌ Unusable - macOS-only, doesn't work in
    devcontainer/Linux
  - **Recommended**: SSH + Tailscale for mobile terminal access, or build
    JSON API for custom dashboards
