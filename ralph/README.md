# Ralph Loop - Autonomous TDD Development with Claude Code

Autonomous AI development loop that iteratively implements stories
until all acceptance criteria pass.

## What is Ralph?

Named after Ralph Wiggum from The Simpsons, this technique by
Geoffrey Huntley implements self-referential AI development loops.
The agent sees its own previous work in files and git history,
iteratively improving until completion.

**Core Loop:**

```text
while stories remain:
  1. Read prd.json, pick next story (status: "pending"/"failed")
  2. Mark story "in_progress", implement (TDD: red → green → refactor)
  3. Run typecheck + tests
  4. If passing: mark "passed", commit, log learnings
  5. On max retries: mark "failed"
  6. In teams mode: verify teammate stories in same wave
  7. Repeat until all pass (or context limit)
```

**Memory persists only through:**

- `prd.json` — Task status and acceptance criteria
- `progress.txt` — Execution log
- `ralph/LEARNINGS.md` — Accumulated agent knowledge (compound engineering)
- `ralph/REQUESTS.md` — Human-to-agent communication channel
- Git commits — Code changes

## Prerequisites

Ralph Loop requires the following system dependencies:

- **Bash** — Shell interpreter (pre-installed on Linux/macOS)
- **Claude Code CLI** — `claude` command ([installation guide](https://github.com/anthropics/claude-code))
- **jq** — JSON processor
  - Linux: `apt-get install jq` or `yum install jq`
  - macOS: `brew install jq`
  - Verify: `jq --version`
- **git** — Version control (required for worktrees)
- **make** — Build automation tool

Run `make ralph_init_loop` to validate all prerequisites are installed.

## Quick Start

```bash
make ralph_run [ITERATIONS=25]              # Single loop (isolated via worktree)
make ralph_run N_WT=5 ITERATIONS=25         # 5 parallel loops
make ralph_run DEBUG=1 N_WT=3               # Debug mode (watch, persist)
```

See [TEMPLATE_USAGE.md](../../docs/TEMPLATE_USAGE.md) for full setup guide
and [CONTRIBUTING.md](CONTRIBUTING.md) for command reference.

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

Ralph auto-detects Vibe Kanban on configured port and syncs status in
real-time. See [docs/UI.md](docs/UI.md) for details.

### Optional: Visual Workflow Design

[CC Workflow Studio](https://github.com/breaking-brake/cc-wf-studio)
provides a drag-and-drop VS Code extension for designing Claude Code
agent workflows visually. Useful for creating `.claude/skills/` and
`.claude/commands/` files.

Install from VS Code Marketplace: `breaking-brake.cc-wf-studio`

### Compound Engineering - Knowledge Management

Ralph implements compound engineering: each solved problem makes future
work easier through systematic knowledge capture.

```bash
# Agents automatically append learnings after each story completion
# LEARNINGS.md accumulates: validation fixes, code patterns, common mistakes

# Periodically review and prune (recommended: every 5-10 stories)
claude -p /review-learnings
```

**Files:**

- `ralph/LEARNINGS.md` — Accumulated knowledge (read before each story)
- `ralph/REQUESTS.md` — Human-to-agent guidance (edit while Ralph runs)

**Workflow:** Plan -> Work (TDD) -> Compound (append learning) -> Review
(prune/declutter)

## Design Principles

### TDD Enforcement (Red-Green-Refactor)

1. **Red** — Write failing test (commit with `[RED]` marker)
2. **Green** — Implement until tests pass (commit with `[GREEN]` marker)
3. **Refactor** — Clean up (optional, commit with `[REFACTOR]` marker)

### Effective Agent Harnesses

Follows [Anthropic's production harness patterns](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents):

1. **Incremental Boundaries** — Story-by-story execution; one feature per
   session, commit before moving on
2. **State Management** — prd.json (task status) + progress.txt
   (learnings) + git history (code); each session reads prior context
   before acting
3. **Checkpointing** — Git commits per story enable resumption from
   known-good states
4. **Error Recovery** — `git reset --hard` recovers failed stories without
   manual intervention
5. **Human-in-the-Loop** — Structured prompts: read progress -> select
   story -> implement -> test -> commit

### Compound Engineering

Learnings compound over time: **Plan** -> **Work** -> **Assess** ->
**Compound**

Source: [Compound Engineering](https://every.to/chain-of-thought/compound-engineering-how-every-codes-with-agents)

### Context Engineering (ACE-FCA)

Context window management for quality output.
See `.claude/rules/context-management.md`.

Source: [ACE-FCA](https://github.com/humanlayer/advanced-context-engineering-for-coding-agents/blob/main/ace-fca.md)

## How It Works

```text
parallel_ralph.sh (orchestrator - always used, even N_WT=1)
  |-> creates N_WT git worktrees (isolated environments)
  |-> runs ralph.sh in each worktree (background jobs)
  |   +-> ralph.sh (worker):
  |       |-> reads prd.json (incomplete stories)
  |       |-> builds prompt from templates/story.prompt.md + story details
  |       |-> invokes: claude -p --dangerously-skip-permissions
  |       |   +-> Agent follows TDD workflow:
  |       |       |- RED: write failing tests -> commit [RED]
  |       |       |- GREEN: implement code -> commit [GREEN]
  |       |       +- REFACTOR: clean up -> commit [REFACTOR]
  |       |-> verifies TDD commits ([RED] and [GREEN] markers)
  |       |-> runs: make validate
  |       |   |- If pass: mark story complete
  |       |   +- If fail: invoke fix loop (max 3 attempts)
  |       |-> generates docs (README.md, example.py)
  |       |-> commits state: prd.json, progress.txt, docs
  |       +-> repeats until no incomplete stories or max iterations
  |-> waits for all worktrees to complete
  |-> N_WT=1: merges result (no scoring overhead)
  |-> N_WT>1: scores all, merges best result
  +-> cleans up worktrees
```

## Architecture

Ralph leverages Claude Code features (rules, skills, prompts) for
optimal agent guidance:

```text
+-------------------------------------------+
| .claude/rules/core-principles.md          | <- Auto-applied globally
| (KISS, DRY, YAGNI, user-centric)         |    Project-wide principles
+-------------------------------------------+
           | References

+-------------------------------------------+
| .claude/skills/implementing-python/       | <- Invokable by agents
| .claude/skills/reviewing-code/            |    Specialized workflows
| .claude/skills/designing-backend/         |
+-------------------------------------------+
           | Listed in

+-------------------------------------------+
| ralph/docs/templates/story.prompt.md      | <- Piped to claude -p
| + LEARNINGS.md (accumulated knowledge)    |    Ralph-specific instructions
| + REQUESTS.md (human guidance)            |    Runtime content injection
| + Story details (prd.json)                |
+-------------------------------------------+
```

**Design rationale:**

- **Rules**: Global principles (auto-applied, all Claude sessions)
- **Skills**: Invokable workflows (agent decides when to use)
- **Prompts**: Scoped instructions (Ralph-only, supports dynamic content)

## Structure

```text
ralph/
├── CHANGELOG.md               # Version history
├── CONTRIBUTING.md             # Command reference
├── LEARNINGS.md               # Accumulated agent knowledge
├── README.md                  # This file
├── REQUESTS.md                # Human-to-agent communication
├── docs/
│   ├── prd.json               # Story definitions and status
│   ├── progress.txt           # Execution log
│   ├── UI.md                  # Vibe Kanban documentation
│   └── templates/
│       ├── prompt.md              # Upstream agent prompt
│       ├── story.prompt.md        # Local agent prompt (TDD workflow)
│       ├── judge.prompt.md        # Judge evaluation prompt
│       ├── prd.json.template
│       ├── prd.md.template
│       ├── progress.txt.template
│       └── userstory.md.template
└── scripts/
    ├── parallel_ralph.sh      # Orchestrator: worktree management, scoring
    ├── ralph.sh               # Worker: TDD loop execution
    ├── ralph-in-worktree.sh   # Git worktree launcher
    ├── generate_prd_json.py   # PRD.md -> prd.json parser
    ├── init.sh                # Environment initialization
    ├── archive.sh             # Archive current run state
    ├── abort.sh               # Terminate running loops
    ├── clean.sh               # Clean Ralph state
    ├── stop.sh                # Stop running loops
    ├── vibe.sh                # Vibe Kanban management
    └── lib/
        ├── config.sh              # Centralized configuration
        ├── common.sh              # Shared utilities (logging, colors)
        ├── baseline.sh            # Baseline-aware test validation
        ├── judge.sh               # Claude-as-Judge evaluation
        ├── vibe.sh                # Vibe Kanban REST API
        ├── validate_json.sh       # JSON validation utilities
        ├── cleanup_worktrees.sh   # Worktree cleanup
        ├── stop_ralph_processes.sh # Process cleanup
        └── generate_app_docs.sh   # README/example generation
```

## Commit Architecture

**Agent commits** (during story execution):

- `test(STORY-XXX): ... [RED]` — Failing tests
- `feat(STORY-XXX): ... [GREEN]` — Implementation
- `refactor(STORY-XXX): ... [REFACTOR]` — Cleanup

**Script commits** (after validation passes):

- `docs(STORY-XXX): update state and documentation` — State files

**Why both?** Agent commits prove TDD compliance. Script commits track
progress.

## Validation & Fixes

1. **Initial validation**: `make validate` after story execution
2. **If fails**: Auto-retry loop (MAX_FIX_ATTEMPTS=3)
   - Re-invokes agent with error output
   - Re-runs `make validate`
   - Continues until pass or max attempts
3. **If passes**: Mark story complete, generate docs, commit state

### Baseline-Aware Validation

Ralph uses baseline-aware test validation (`baseline.sh`):

- **Baseline capture**: Failing tests snapshot before each story
- **Regression detection**: Only NEW failures block progress
- **Teams scoping**: Checks scoped to story files in teams mode
- **Wave checkpoints**: Full `make validate` at wave boundaries
- **Auto-refresh**: Baseline updated after each successful validation

## Configuration

Centralized in `ralph/scripts/lib/config.sh`:

**Execution:**

- `RALPH_MAX_ITERATIONS=25` — Loop iterations
- `RALPH_MAX_FIX_ATTEMPTS=3` — Fix attempts
- `RALPH_VALIDATION_TIMEOUT=300` — Validation timeout (5 min)
- `RALPH_FIX_TIMEOUT=300` — Fix timeout (5 min)

**Models (Automatic Routing):**

- `RALPH_DEFAULT_MODEL="sonnet"` — Story implementation (complex logic)
- `RALPH_SIMPLE_MODEL="haiku"` — Simple changes (docs, typos, formatting)
- `RALPH_FIX_MODEL="haiku"` — Validation error fixes
- `RALPH_JUDGE_MODEL="sonnet"` — Claude-as-Judge evaluation

Story complexity detection: checks title/description for patterns like
"fix", "typo", "doc", "format". Judge uses specified model for worktree
comparison (N_WT>1).

**Override hierarchy:**

1. CLI: `./ralph.sh 50`
2. Env: `VALIDATION_TIMEOUT=600 ./ralph.sh`
3. Config: `ralph/scripts/lib/config.sh`

See `config.sh` header for complete list.

## Execution Modes

**All execution uses git worktrees** (even N_WT=1) for safety and
isolation.

### Create New Run

```bash
# Single loop (N_WT=1, default)
make ralph_run [ITERATIONS=25]         # Isolated in worktree, no scoring

# Parallel loops (N_WT>1)
make ralph_run N_WT=5 ITERATIONS=25    # 5 worktrees, scores, merges best
```

### Resume Paused Run

**Automatic resume detection**: If existing worktrees are found (not
locked), `make ralph_run` automatically resumes them:

```bash
make ralph_run                         # Auto-resumes existing worktrees
```

### Monitoring

```bash
make ralph_status                      # Progress summary with timestamp
make ralph_watch                       # Process tree + live tail all logs
make ralph_get_log WT=2                # View specific worktree
```

**DEBUG Mode:**

```bash
make ralph_run DEBUG=1 N_WT=3          # Starts worktrees + watches logs
```

When DEBUG=1:

- Automatically starts log watching (like `make ralph_watch`)
- Worktrees run in background and persist after Ctrl+C
- No automatic scoring or merging
- Use `make ralph_status` to check progress later

### Control

```bash
make ralph_stop                        # Stop loops (keep worktrees)
make ralph_clean                       # Clean worktrees + local state
                                       # (requires double confirmation)
```

### Execution States

- **Active (locked)**: Ralph loop running — `make ralph_run` aborts with
  error, use `make ralph_stop` first
- **Paused (unlocked)**: Ralph loop stopped/interrupted —
  `make ralph_run` auto-resumes
- **Clean**: No worktrees exist — `make ralph_run` creates new run

### Interrupt Handling

- **Ctrl+C during execution**: Background processes persist (detached via
  `disown`), worktrees unlocked but preserved for resume
- **Successful completion**: Worktrees are cleaned up automatically
  (after merging best result)
- **Merge failure**: Worktrees are unlocked but preserved (for debugging)

### Background Process Persistence

All worktrees run as detached background processes (via `disown`):

- Survive Ctrl+C interrupts
- Survive terminal disconnects
- Survive parent shell exit
- Check progress: `make ralph_status`
- Stop manually: `make ralph_stop`

### Safety Features

- `ralph_clean` requires double confirmation:
  1. Type `'yes'` to confirm
  2. Type `'YES'` (uppercase) to proceed
- Shows what will be deleted before asking for confirmation
- Cannot be undone — use with caution

### Judge-Based Selection (Optional)

Enable LLM-based worktree evaluation for quality-focused selection:

```bash
# Basic judge mode (autonomous)
RALPH_JUDGE_ENABLED=true make ralph_run N_WT=3

# With security review
RALPH_JUDGE_ENABLED=true RALPH_SECURITY_REVIEW=true make ralph_run N_WT=2

# Human-in-the-loop (interactive merge approval)
RALPH_JUDGE_ENABLED=true RALPH_MERGE_INTERACTIVE=true make ralph_run N_WT=2
```

**How it works:**

- Judge evaluates: **correctness > test quality > code clarity**
- Falls back to metrics if N_WT > `RALPH_JUDGE_MAX_WT` or on timeout
- Autonomous by default (no human approval required)
- Optional security review via `/security-review` skill
- Optional interactive approval before final commit

**Scoring** (N_WT>1 only): `base + coverage_bonus - penalties`

- base = `(stories x 10) + test_count + validation_bonus`
- coverage_bonus = `coverage% / 2` (0-50 points)
- penalties = `(ruff x 2) + (pyright_err x 5) + (pyright_warn x 1) +
  (churn / 100)`

### Sprint-Specific PRD Management

Each sprint gets its own PRD file. Ralph reads only `prd.json` — the PRD
markdown is human-facing input to `generate_prd_json.py`.

```text
docs/PRD.md                    # Parser input (or symlink to active sprint)
ralph/docs/prd.json            # Ralph reads this
```

Optionally, symlink `docs/PRD.md` to the active sprint file so the
parser always reads the right one without arguments:

```bash
cd docs && ln -sf sprints/PRD-SprintN.md PRD.md
```

**Switching sprints:**

```bash
# Archive current sprint
git tag sprint-N-complete -a -m "Sprint N complete"
mkdir -p ralph/archive/sprintN/
cp ralph/docs/{prd.json,progress.txt} ralph/archive/sprintN/

# Point parser at next sprint and regenerate
make ralph_prd_json
make ralph_run
```

**Why separate files?**

- Single PRD with 50+ stories across sprints overwhelms Ralph's context
- Completed sprint details pollute active sprint focus
- Each sprint PRD stays at 10-20 stories (manageable scope)
- Historical PRDs preserved as immutable records

**Story IDs**: Sequential across sprints (STORY-001... STORY-011 in
Sprint 2, STORY-012... in Sprint 3). Unique IDs across project lifetime.

**prd.json**: Fresh start per sprint. Archive before transition.

### Git Worktree Workflow

Run Ralph in an isolated worktree to keep the source branch clean.

**Setup and run:**

```bash
make ralph_worktree BRANCH=ralph/<branch-name>
```

This creates a sibling worktree at `../<branch-basename>`, symlinks
`.venv` from the source repo, and starts Ralph. Reuses an existing
branch and worktree if one exists.

**Directory layout** (sibling pattern):

```text
parent-dir/
├── your-project/                   # Source repo (working branch)
│   ├── .venv/                      # Shared virtual environment
│   └── ralph/docs/prd.json
└── <branch-basename>/              # Worktree (ralph branch)
    ├── .venv → ../your-project/.venv   # Symlinked, not copied
    └── ralph/docs/prd.json
```

**Key practices:**

- **One worktree per sprint branch** — keeps TDD noise off the source
  branch
- **`.venv` is symlinked**, not duplicated — never run `uv sync` in the
  worktree
- **Don't edit overlapping files** in the source repo while Ralph runs —
  files listed in `prd.json` `files` arrays belong to the worktree
- **Clean up when done** — use `git worktree remove`, not `rm -rf`

**Configuration** (same env vars as `ralph_run`):

```bash
make ralph_worktree BRANCH=ralph/<name> TEAMS=true MAX_ITERATIONS=50 MODEL=opus
```

**Sandbox note:** If your environment restricts writes outside the repo
directory (e.g., DevContainers), add the parent directory to the sandbox
write allowlist so worktrees can be created as siblings.

### Merging Back

Squash merge from source repo (not worktree). TDD commits are
implementation noise — final state is what matters.

```bash
git merge --squash ralph/<branch>
git commit -m "feat(sprintN): implement stories via Ralph"
git worktree remove ../<worktree-dir>
git branch -d ralph/<branch>
```

**Conflict prevention**: Don't edit files in `prd.json` `files` arrays
on the source branch while Ralph runs.

**Conflict resolution**: Especially relevant for worktree branches that
diverge from the source branch during long-running Ralph sessions.
`-X ours`/`-X theirs` is relative to the checked-out branch
(`ours` = branch you're on, `theirs` = branch being merged in):

- On main, merging Ralph in: `-X theirs` keeps Ralph's version
- On feat branch, merging main in: `-X ours` keeps feat's version

**Protected main with conflicting PR** (only valid when feat branch is
the single source of truth and main's conflicting changes are already
incorporated or superseded):

```bash
# Merge main into feat, resolve conflicts keeping ours
git fetch origin
git checkout <branch>
git merge -X ours origin/main
git push origin <branch>
gh pr merge <pr-number> --squash
```

If the feat branch itself is blocked, create a new one as fallback:

```bash
git checkout -b <branch>-v2 origin/<branch>
git merge -X ours origin/main
git push -u origin <branch>-v2
gh pr close <old-number> -c "Superseded by new PR"
gh pr create --title "feat: ..." --body "Supersedes #<old>."
gh pr merge --squash
```

**`modify/delete` conflicts**: `-X ours` won't auto-resolve when ours
deleted a file that theirs modified. Fix with `git rm <files>` then
commit — ours (delete) wins. Untracked files blocking merge need
`rm -rf` before `git merge`.

**`-X ours` does NOT delete files added by theirs**: Files that exist
only on the branch being merged in (e.g., `main` added files that
`feat` never had) are not conflicts — git auto-merges them as
additions. After `git merge -X ours origin/main`, diff against the
pre-merge feat branch and `git rm` any files that shouldn't be there:

```bash
# After merge, find files main added that feat didn't have
git diff HEAD <feat-branch-pre-merge-sha> --name-only --diff-filter=A
# Delete them
git diff HEAD <feat-branch-pre-merge-sha> --name-only --diff-filter=A \
  | xargs git rm
git commit --amend --no-edit
```

## Security

**Ralph runs with `--dangerously-skip-permissions`** — all operations
execute without approval.

**Only use in:** Isolated environments (DevContainers, VMs).

For network isolation, see Claude Code's
[reference devcontainer](https://github.com/anthropics/claude-code/tree/main/.devcontainer)
with iptables firewall.

## Output Files

- `prd.json` — Updated with completion timestamps
- `progress.txt` — Iteration log (PASS/FAIL/RETRY status)
- `src/*/README.md` — Generated application documentation
- `src/*/example.py` — Generated usage example

## Quality Gates

All stories must pass:

- Code formatting (ruff)
- Type checking (pyright)
- Cognitive complexity (complexipy)
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

## Known Failure Modes

Root cause analysis from Sprint 7 log forensics. STORY-009/010/011
implemented correctly but Ralph rejected them repeatedly.

### 1. TDD commit counter doesn't survive reset (Sisyphean loop)

RED+GREEN commits made in iteration N pass TDD but fail complexity.
Ralph runs `git reset --hard HEAD~N`, erasing them. In iteration N+1
the agent sees work already exists in reflog/history, makes only a
REFACTOR commit. `check_tdd_commits` searches
`git log --grep="[RED]" --grep="STORY-ID" --all-match` but reset
commits are gone from the log. Ralph rejects for missing RED+GREEN.
Repeats until max retries.

**Root cause in code**: `ralph.sh` resets commits on TDD failure and
on quality failure. Neither persists which TDD phases passed. The
`RETRY_CONTEXT_FILE` only works for quality retries after TDD already
passed — not for TDD failures that require re-verification.

**Solutions (pick one):**

- **A. Persist verified phases to state file** (recommended): After
  `check_tdd_commits` passes but quality fails, write
  `RED=<hash> GREEN=<hash>` to a temp file. On retry, skip phase
  requirements already satisfied.
- **B. Don't reset on quality failure** (simpler): Keep commits when
  only complexity/tests fail. Agent adds a REFACTOR commit on top.
- **C. Cherry-pick surviving commits**: After reset, if prior RED+GREEN
  are in reflog, `git cherry-pick` them back. More fragile.

### 2. Teams mode cross-contamination

When Ralph delegates multiple stories in one batch, the agent combines
work across stories. `check_tdd_commits` filters by
`grep "$story_id"` but if the agent makes a single commit covering
multiple stories, or uses a different story ID in the message, the
filter finds nothing.

**Root cause in code**: Simple grep on commit messages. A commit like
`feat(STORY-009,STORY-010): implement features [GREEN]` matches both
stories, while `feat: implement paper selection and settings [GREEN]`
matches neither.

**Solutions (pick one):**

- **A. File-scoped commit attribution** (recommended): Check which files
  each commit touches against the story's `files` array from prd.json.
- **B. Sequential execution with shared baseline**: Don't batch stories.
  Execute one at a time. Slower but eliminates cross-contamination.
- **C. Require story-scoped commits in prompt**: Fragile (depends on
  agent compliance) but zero harness changes.

### 3. Complexity gate catches cross-story changes

One story's complexity increase fails another story's quality gate.
`run_quality_checks` runs `make complexity` against the entire `src/`
tree, not just story-scoped files.

**Root cause in code**: `baseline.sh` compares test results before/after
but the complexity check has no baseline — it's a global pass/fail on
the whole codebase.

**Solutions (pick one):**

- **A. Complexity baseline with delta scoping** (recommended): Snapshot
  complexity per function before execution. Only fail if functions in
  the story's `files` list increased complexity.
- **B. Per-file complexity check**: Run complexipy only on files changed
  by the current story's commits.
- **C. Complexity allowlist in prd.json**: Optional
  `complexity_exceptions` field per story. Heavy-handed but explicit.

### 4. Stale snapshot tests from other stories

In teams mode, new failures from other stories in the same batch
appear as regressions for the current story. `baseline.sh` captures
failing tests BEFORE the batch, so new failures from other stories
appear as regressions introduced by the current story.

**Root cause in code**: `capture_test_baseline` runs once per story
start, but in teams mode all stories share the same codebase state.
Story A's baseline doesn't account for story B's changes.

**Solutions (pick one):**

- **A. Rolling baseline per story** (recommended): After each story's
  commits are verified and kept, re-capture the baseline before
  verifying the next story.
- **B. Test-to-source mapping**: Map each failing test to the source
  files it imports. Only flag a failure as regression if it imports a
  file from the current story's `files` list.
- **C. Accept known cross-story failures**: After detecting new
  failures, check if they exist in ANY story's test file list from the
  batch. Only block on truly orphaned regressions.

### 5. File-conflict dependencies not tracked

`depends_on` tracks logical dependencies but not file-overlap conflicts.
In teams mode, two unrelated stories editing the same file (e.g., both
editing `run_cli.py`) produce merge conflicts or silently overwrite
each other's changes.

**Root cause in code**: `get_unblocked_stories` checks only
`depends_on` — it has no file-overlap awareness. Two stories with
`depends_on: []` and overlapping `files` arrays both appear unblocked.

**Solutions (pick one):**

- **A. File-conflict deps in prd.json** (recommended): Add file-overlap
  dependencies during PRD generation. `generate_prd_json.py` can detect
  overlapping `files` arrays and auto-inject `depends_on` edges.
- **B. Runtime file-lock check**: Before delegating a story, check if
  any in-progress story shares files. Skip overlapping stories until
  the conflicting story completes.

### 6. Incomplete PRD file lists (Sprint 8 post-mortem)

Three stories passed quality checks but left stale tests because the
PRD `files` arrays missed secondary consumers of renamed interfaces.
All three failures were from tests *outside* the story's scope.

**Mitigations implemented:**

- Impact scan prompt instruction: agent greps test tree for old symbol
  names before implementation
- Wave checkpoint: full `make validate` runs at wave boundaries to
  catch cross-story breakage
- Killed-process detection: exit 137/143 is a hard failure, not a
  silent pass
- Scoped ruff/tests: teams mode only checks story files, preventing
  cross-story false positives
- Pycache cleanup: removes stale `.pyc` files before test runs

### 7. Worktree lock contention

Two workers claim same story if prd.json read+write is not atomic.
Mitigated by file locking in `ralph.sh`.

### 8. Stale worktree after crash

If a worker process dies mid-story, the worktree remains locked.
`make ralph_clean` with double confirmation handles cleanup.

### 9. Claude rate limits

Parallel workers can hit API rate limits. Workers retry with
exponential backoff (configured in `config.sh`).

### 10. Disk space exhaustion

Each worktree is a full checkout. Monitor with `df -h` when running
N_WT>3 on constrained environments.

### Key Structural Issue

The fundamental problem is **cross-story interference in teams mode**:
quality gates for story X catch regressions introduced by stories Y
and Z. The validation checks the entire test suite against a baseline
that predates all stories in the batch.

**Recommended combined approach**: Implement solutions 1A + 2A + 3B +
4A + 5A. This gives:

- Phase persistence across resets (1A) — eliminates Sisyphean loops
- File-scoped commit attribution (2A) — correct story ownership
- Per-file complexity (3B) — scoped complexity checks
- Rolling baseline (4A) — simplest baseline fix
- File-conflict deps in prd.json (5A) — prevents parallel edits to
  same file

All five are backward-compatible with single-story mode
(`TEAMS=false`).

## TODO / Future Work

- [ ] **Agent Teams for parallel story execution**: Enable with
  `make ralph_run TEAMS=true`
  (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`). Lead agent orchestrates
  teammates with skill-specific delegation. **Terminology**: a **wave**
  is the set of currently unblocked stories (all `depends_on` satisfied)
  — i.e., the frontier of the dependency graph. Stories within a wave
  run in parallel (one teammate each); the next wave starts after the
  current one completes.
  - [ ] **CC Agent Teams as alternative orchestrator**: Instead of
    Ralph's bash loop driving `claude -p` with bolted-on teams support,
    the CC main orchestrator agent directly spawns a team via
    `TeamCreate` + `Task` tool. Each story becomes a `TaskCreate` entry
    with `blockedBy` dependencies (both logical and file-conflict).
    Addresses Ralph failure modes structurally: isolated teammate
    contexts prevent cross-contamination (#2), `blockedBy` prevents
    stale snapshots (#4), no external reset eliminates Sisyphean loops
    (#1), lead-scoped validation prevents cross-story complexity
    failures (#3), and file-conflict deps in `blockedBy` prevent
    parallel edits to the same file (#5). Requires self-contained story
    descriptions in the PRD Story Breakdown (usable as
    `TaskCreate(description=...)`).

- [ ] **Consolidate split test directories**: `tests/gui/` vs
  `tests/test_gui/` directly caused 2 of 3 Sprint 8 failures. Story
  authors found and updated tests in one directory but missed the other.
  Merging into a single `tests/gui/` eliminates the ambiguity.
  Independent of Ralph — codebase hygiene.

- [ ] **Ad-hoc steering instructions**: Accept a free-text `INSTRUCTION`
  parameter via CLI/Make to inject user guidance into the prompt without
  editing tracked files. Usage:
  `make ralph_run INSTRUCTION="focus on error handling"`. The
  instruction would be appended to the story prompt so the agent factors
  it in during implementation. Useful for nudging behavior (e.g.,
  "prefer small commits", "skip Tier 2 tests") without modifying
  tracked files.

- [ ] **Rewrite Ralph engine in Go**: The bash script engine
  (`ralph.sh` + `baseline.sh` + `common.sh`, ~3k lines across 13 files)
  is brittle, untestable, and diverges when the template is forked.
  Rewrite as a standalone Go binary (`ralph`) distributed as a single
  static executable (10-15 MB, zero runtime deps). Makefile stays as the
  user-facing interface, calling `ralph <subcommand>` instead of
  `bash ralph/scripts/*.sh`. Includes language adapter system for
  TDD/BDD validation across Python, Go, TypeScript, Rust, C++, and C.
  Go chosen over Rust (contributor onboarding days vs months, goroutines
  map directly to N-worker pattern, trivial cross-compilation) and
  TypeScript (135 MB deno compile binary, subprocess env pollution from
  bundled V8 runtime). Key deps: Cobra (CLI), Viper (config). See
  [`docs/UserStory.md`](../docs/UserStory.md) for full requirements
  and architecture.

- [ ] **Multi-instance worktree orchestration**: Run up to N independent
  Ralph instances (solo or teams) in separate git worktrees
  simultaneously. Each worktree gets its own branch, prd.json, and
  progress.txt. Merge results back at completion. Supersedes the
  single-worktree "Git worktrees for teams isolation" deferred item.
  Reference:
  [ralph-loop template](https://github.com/qte77/ralph-loop-cc-tdd-wt-vibe-kanban-template).

- [ ] **Merge with ralph-loop template**: Evaluate and port features
  from
  [ralph-loop template](https://github.com/qte77/ralph-loop-cc-tdd-wt-vibe-kanban-template)
  into this project, or merge both projects altogether. The template
  repo has diverged with its own worktree management, kanban tracking,
  and vibe coding workflow. Consolidate to avoid maintaining two
  separate Ralph implementations.

- [ ] **Streaming progress**: WebSocket-based real-time progress
  streaming for dashboard integrations (beyond REST polling).

- [ ] **PRD versioning**: First-class support for PRD iterations with
  diff-based story carry-over between versions.

### Deferred

- [ ] **Intra-story teams**: Multiple agents on one story (e.g., test
  writer + implementer). Requires shared-file coordination, merge
  conflict handling, and split TDD ownership. Deferred until inter-story
  mode is validated.

- [ ] **Git worktrees for teams isolation**: True filesystem isolation
  eliminates all cross-contamination (`__pycache__`, ruff/test
  cross-pollution). Each story in a wave gets its own `git worktree`.
  Merge at wave boundaries via `git merge --squash`. Deferred until
  scoped checks + wave checkpoints are validated.

- [ ] **Automated impact-scope analysis**: Post-story function that
  diffs removed identifiers in `src/`, filters to renamed-only (removed
  but not re-added), and greps `tests/` for out-of-scope consumers.
  Currently handled by the agent via prompt instruction. Automate if a
  second incident occurs where the prompt instruction is insufficient.

- [ ] **Inline snapshot drift detection**: Run
  `uv run pytest --inline-snapshot=review` after clean test passes to
  surface stale snapshots. Deferred until `--inline-snapshot=review`
  output format is confirmed stable for non-interactive use. Snapshot
  mismatches already show up as normal test failures.

- [ ] **Cross-directory test warning**: Flag when a source module has
  tests in multiple directories (e.g., `tests/gui/` and
  `tests/test_gui/`). Symptom of poor test directory hygiene —
  consolidating test dirs (above) is the structural fix. Deferred as
  YAGNI.

### Done

- [x] **Intermediate progress visibility** — Monitor now tails agent log
  output at 30s intervals with `[CC]` (magenta) prefix for agent
  activity and red for agent errors, alongside existing phase detection
  from git log.
  - [x] **CC monitor log nesting** — `monitor_story_progress` now
    tracks byte offset (`wc -c`) between 30s cycles and reads only new
    log content via `tail -c +$offset`, preventing
    `[CC] [INFO] [CC] [INFO] ...` nesting chains.
- [x] **Agent Teams inter-story** — `ralph.sh` appends unblocked
  independent stories to the prompt; `check_tdd_commits` filters by
  story ID in teams mode to prevent cross-story marker false positives.
  Completed stories caught by existing `detect_already_complete` path.
- [x] **Scoped reset on validation failure** — Untracked files are
  snapshot before story execution; on TDD failure, only story-created
  files are removed. Additionally, quality-failure retries skip TDD
  verification entirely (prior RED+GREEN already verified), and
  `check_tdd_commits` has a fallback that detects `refactor(` prefix
  when `[REFACTOR]` bracket marker is missing.
- [x] **Deduplicate log levels** — `monitor_story_progress` strips
  leading `[INFO]`/`[WARN]`/`[ERROR]` prefix from CC agent output
  before wrapping with `log_cc*`, preventing
  `[INFO] ... [CC] [INFO]` duplication.

## Troubleshooting

- **No commits made**: Agent didn't follow TDD workflow, story retries
- **TDD verification failed**: Missing [RED] or [GREEN] markers, retries
- **Quality checks failed**: Fix loop invoked (3 attempts), then FAIL
- **Max iterations reached**: Loop stops, check progress.txt
- **Ralph skips stories**: Check `depends_on` in prd.json

## Sources

- [Ralph Wiggum technique](https://ghuntley.com/ralph/) — Geoffrey Huntley
- [Anthropic: Effective Harnesses](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
- [Compound Engineering](https://every.to/chain-of-thought/compound-engineering-how-every-codes-with-agents)
- [ACE-FCA](https://github.com/humanlayer/advanced-context-engineering-for-coding-agents/blob/main/ace-fca.md)

---

See [CHANGELOG.md](CHANGELOG.md) for version history.
