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

See [TEMPLATE_USAGE.md](../docs/TEMPLATE_USAGE.md) for full setup guide
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
│   ├── FAILURE_MODES.md       # Teams mode failure analysis
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
    ├── watch.sh               # Live log monitoring
    └── lib/
        ├── config.sh              # Centralized configuration
        ├── common.sh              # Shared utilities (logging, colors)
        ├── baseline.sh            # Baseline-aware test validation
        ├── snapshot.sh            # Codebase map + story context
        ├── teams.sh               # Teams-mode orchestration
        ├── extract_signatures.py  # AST-based Python signature extraction
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

**Snapshot:**

- `SNAPSHOT_SIG_LIMIT=100` — Max signature lines per file in codebase map
- `RALPH_SRC_PREFIX="src/"` — Source prefix for test path mapping
  (e.g., `"src/app/"` for projects with a nested package)
- `DOMAIN_RETRY_THRESHOLD=3` — Failures before suggesting skill creation

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

See [docs/FAILURE_MODES.md](docs/FAILURE_MODES.md) for detailed root
cause analysis of teams mode cross-story interference (6 failure modes
with recommended solutions).

Additional worktree-related failure modes:

- **Worktree lock contention**: Two workers claim same story if
  prd.json read+write is not atomic. Mitigated by file locking.
- **Stale worktree after crash**: Worker dies mid-story, worktree
  remains locked. `make ralph_clean` handles cleanup.
- **Claude rate limits**: Parallel workers hit API limits. Workers
  retry with exponential backoff (configured in `config.sh`).
- **Disk space exhaustion**: Each worktree is a full checkout. Monitor
  with `df -h` when running N_WT>3 on constrained environments.

## TODO / Future Work

See [TODO.md](TODO.md) for the consolidated backlog (bugs,
enhancements, deferred items, and done).

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
