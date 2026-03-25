---
title: Ralph TODO
purpose: Consolidated backlog for Ralph loop — bugs, enhancements, and deferred items.
created: 2026-03-08
updated: 2026-03-14
---

## Adopt Now (zero cost)

- [ ] **RTK context compression for Claude Code sessions**: Install [RTK](https://github.com/rtk-ai/rtk) globally with `rtk init -g`. This adds a `PreToolUse` hook to `~/.claude/hooks/` that transparently compresses shell command output (git status/diff/log, make validate, pytest, ruff check) by 60-90% before it reaches Claude's context window. **No changes to Ralph scripts needed** — every `claude -p` session automatically benefits. RTK is complementary to Ralph (context compression, not orchestration). ~4.1 MB Rust binary.

<!-- markdownlint-disable MD013 -->

## Backlog

- [ ] **BUG: teams.sh scoped checks are silent no-ops (D3/C1)**: `verify_teammate_stories()` passes story ID to `run_ruff_scoped`/`run_complexity_scoped`/`run_tests_scoped`, but these functions expect a git commit hash. `git diff --name-only "STORY-003" HEAD` silently returns nothing, so all scoped quality checks pass without checking anything. **Fix**: call `get_story_base_commit "$sid"` first, pass the commit hash. See [`docs/audits/quality-audit-2026-03.md`](../docs/audits/quality-audit-2026-03.md) D3.
- [ ] **Name collision: two verify_teammate_stories functions (D1)**: `ralph.sh:225` and `teams.sh:195` both define `verify_teammate_stories()` with completely different semantics. Whichever is sourced last wins silently. **Fix**: rename `ralph.sh` version to `verify_prd_isolation()`.
- [ ] **Prompt construction duplicated between execute and fix (D2)**: ~30-line prompt block (story details + learnings + requests + steering) is copy-pasted between `execute_story()` and `fix_validation_errors()`. **Fix**: extract `build_story_prompt()` function.
- [ ] **kanban_update JSON injection via string concatenation (R5/C3)**: `vibe.sh:158-175` builds JSON with string concatenation + `sed`-only escaping (misses backslashes, newlines). `kanban_init` in the same file already uses `jq --arg` correctly. **Fix**: convert `kanban_update` to use `jq --arg`.
- [ ] **get_next_story O(n*d) subprocess spawning (K1/C4)**: `ralph.sh:167` spawns one jq per story + one per dependency. `teams.sh:15` already solves this with a single jq query. **Fix**: replace `get_next_story` with `get_unblocked_stories | head -1`.
- [ ] **Double validation on intermediate fix attempts (K2)**: `ralph.sh:447-455` runs quick validation, then immediately runs full validation on success — lint + type-check execute twice. **Fix**: if quick passes on intermediate attempt, proceed; run full only on final attempt.
- [ ] **Dead code: log_cc* functions (Y1)**: 4 functions in `common.sh:71-85` with zero call sites. **Fix**: delete.
- [ ] **vibe.sh debug logging bypasses log_* system (C2)**: 6 bare `echo "[DEBUG]"` statements fire unconditionally. **Fix**: replace with `log_info` or gate behind `[ "$DEBUG" = "1" ]`.

## Future Work

- [ ] **Agent Teams for parallel story execution**: Enable with `make ralph_run TEAMS=true` (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`). Lead agent orchestrates teammates with skill-specific delegation. **Terminology**: a **wave** is the set of currently unblocked stories (all `depends_on` satisfied) — i.e., the frontier of the dependency graph. Stories within a wave run in parallel (one teammate each); the next wave starts after the current one completes.
  - [ ] **CC Agent Teams as alternative orchestrator**: Instead of Ralph's bash loop driving `claude -p` with bolted-on teams support, the CC main orchestrator agent directly spawns a team via `TeamCreate` + `Task` tool. Each story becomes a `TaskCreate` entry with `blockedBy` dependencies (both logical and file-conflict). Addresses Ralph failure modes structurally: isolated teammate contexts prevent cross-contamination (#2), `blockedBy` prevents stale snapshots (#4), no external reset eliminates Sisyphean loops (#1), lead-scoped validation prevents cross-story complexity failures (#3), and file-conflict deps in `blockedBy` prevent parallel edits to the same file (#5). Requires self-contained story descriptions in the PRD Story Breakdown (usable as `TaskCreate(description=...)`).

- [ ] **Rewrite Ralph engine as standalone CLI** *(backlog — deferred until bug-fix + self-evolving sprint completes)*: The bash script engine (~4.1k lines across 25 files) is brittle, untestable, and diverges when the template is forked. Rewrite as a standalone binary distributed as a single executable. Makefile stays as the user-facing interface, calling `ralph <subcommand>` instead of `bash ralph/scripts/*.sh`. Includes language adapter system for TDD/BDD validation across Python, Go, TypeScript, Rust, C++, and C. **Research**: [`docs/research/ralph-cli-rewrite.md`](../docs/research/ralph-cli-rewrite.md) evaluates 5 options (bash hardening, Bun, Go, Deno, Python). **Recommendation: Go + Cobra/Viper** — smallest binary (10-15 MB), best cross-compilation, goroutines map to N-worker pattern, Viper replaces config.sh. See [`docs/UserStory.md`](../docs/UserStory.md) for full requirements and Go architecture.

- [ ] **Per-run cost guardrails**: Abort autonomous execution when token/cost threshold is exceeded. Track cumulative usage per story and per run. Configurable via `RALPH_COST_LIMIT` (e.g., USD cap or token cap). Prevents runaway API spend during unattended `make ralph_run`. Prior art: [Paperclip](https://github.com/paperclipai/paperclip) implements per-agent monthly budgets with throttling.

- [ ] **Optional PR creation per worktree**: Create a GitHub PR instead of auto-merging when `RALPH_CREATE_PR=true`. Auto-merge remains default. PR title from story ID + title, body from diff stats and story AC. When combined with judge mode (`RALPH_JUDGE_ENABLED=true`), judge scores worktrees and creates PR for the best one. Enables CI checks before merge. Inspired by [devteam](https://github.com/agent-era/devteam).

- [ ] **Diff stats in status and scoring**: Show insertions/deletions per worktree in `ralph_status` output via `git diff --stat`. Include as display metric in scoring phase (N_WT>1) for transparency — not as a scoring factor. Inspired by [devteam](https://github.com/agent-era/devteam).

- [ ] **Streaming progress**: WebSocket-based real-time progress streaming for dashboard integrations (beyond REST polling).

- [ ] **PRD versioning**: First-class support for PRD iterations with diff-based story carry-over between versions.

## Monitor (revisit on trigger)

| Item | Current Blocker | Trigger to Revisit |
| ---- | --------------- | ------------------ |
| **Fast mode for Ralph loop** | 2x+ cost increase; autonomous execution doesn't benefit from latency reduction | Pricing drops or Ralph becomes interactive |
| **Cloud Sessions for Ralph loop** | No local MCP servers or persistent state in cloud VMs; setup script complexity | Cloud sessions support custom images or MCP forwarding |
| **BDD workflow support** | Only TDD `[RED]/[GREEN]/[REFACTOR]` accepted | A BDD project needs Ralph |
| **Cross-layer validation commands** | Single-layer Python project | Project becomes multi-layer |

## Deferred

- [ ] **Intra-story teams**: Multiple agents on one story (e.g., test writer + implementer). Requires shared-file coordination, merge conflict handling, and split TDD ownership. Deferred until inter-story mode is validated.
- [ ] **Git worktrees for teams isolation**: True filesystem isolation eliminates all cross-contamination (`__pycache__`, ruff/test cross-pollution). Each story in a wave gets its own `git worktree`. Merge at wave boundaries via `git merge --squash`. Deferred until scoped checks + wave checkpoints are validated.
- [ ] **Automated impact-scope analysis**: Post-story function that diffs removed identifiers in `src/`, filters to renamed-only (removed but not re-added), and greps `tests/` for out-of-scope consumers. Currently handled by the agent via prompt instruction. Automate if a second incident occurs.
- [ ] **Inline snapshot drift detection**: Run `uv run pytest --inline-snapshot=review` after clean test passes to surface stale snapshots. Deferred until `--inline-snapshot=review` output format is confirmed stable for non-interactive use.
- [ ] **Cross-directory test warning**: Flag when a source module has tests in multiple directories (e.g., `tests/gui/` and `tests/test_gui/`). Consolidating test dirs is the structural fix. Deferred as YAGNI.

## Done

- [x] **Ad-hoc steering instructions**: `RALPH_INSTRUCTION` config injected into story and fix prompts. Usage: `make ralph_run INSTRUCTION="focus on error handling"`. Also: `RALPH_MODEL` overrides `classify_story` routing, `RALPH_DESLOPIFY` appends quality-enforcement system prompt.
- [x] **Intermediate progress visibility** — Monitor now tails agent log output at 30s intervals with `[CC]` (magenta) prefix for agent activity and red for agent errors, alongside existing phase detection from git log.
  - [x] **CC monitor log nesting** — `monitor_story_progress` now tracks byte offset (`wc -c`) between 30s cycles and reads only new log content via `tail -c +$offset`, preventing `[CC] [INFO] [CC] [INFO] ...` nesting chains.
- [x] **Agent Teams inter-story** — `ralph.sh` appends unblocked independent stories to the prompt; `check_tdd_commits` filters by story ID in teams mode to prevent cross-story marker false positives. Completed stories caught by existing `detect_already_complete` path.
- [x] **Scoped reset on validation failure** — Untracked files are snapshot before story execution; on TDD failure, only story-created files are removed. Additionally, quality-failure retries skip TDD verification entirely (prior RED+GREEN already verified), and `check_tdd_commits` has a fallback that detects `refactor(` prefix when `[REFACTOR]` bracket marker is missing.
- [x] **Deduplicate log levels** — `monitor_story_progress` strips leading `[INFO]`/`[WARN]`/`[ERROR]` prefix from CC agent output before wrapping with `log_cc*`, preventing `[INFO] ... [CC] [INFO]` duplication.
- [x] **AST-based signature extraction** — Replaced grep-based extraction in `lib/snapshot.sh` with `lib/extract_signatures.py` (Python `ast` module). Captures return types, decorators, and full arg annotations. Falls back to grep on syntax errors.
- [x] **Codebase snapshot system** — `lib/snapshot.sh` generates `codebase-map.md` (file tree + AST signatures) and `story-context.md` (AC, file contents, tests). Content-hash diffing skips regeneration when `src/` unchanged.
- [x] **Context drift detector** — `check_context_drift()` in `snapshot.sh` warns when `src/` content hash differs from stored `.codebase-map.sha` before regeneration.
- [x] **Agent creation heuristic** — Per-domain failure counters in `domain_retries.json` (ephemeral in `/tmp`). At threshold (`DOMAIN_RETRY_THRESHOLD`, default 3), logs warning and injects suggestion for skill creation into prompt.

## Decisions

| Decision | Rationale | Date |
| -------- | --------- | ---- |
| AST over grep for codebase map signatures | AST captures return types, decorators, full arg annotations; grep misses them. Speed negligible (1.2x). Complexipy stays as quality gate only. | 2026-03-08 |

## Sources

- [Codified Context Infrastructure](https://arxiv.org/abs/2602.20478) — three-tier context architecture (constitution + specialist agents + cold-memory knowledge base), 283-session empirical study, 108K LOC C# project. Validates AGENTS.md + Skills + docs/ pattern.
- [tree-sitter](https://github.com/tree-sitter/tree-sitter) — incremental parser generator (C + WASM); [tree-sitter-python](https://www.npmjs.com/package/tree-sitter-python) grammar. Relevant if Bun/Deno chosen over Go for CLI rewrite (see [`docs/research/ralph-cli-rewrite.md`](../docs/research/ralph-cli-rewrite.md)).
- [PentAGI](https://github.com/vxcontrol/pentagi) — Go-based multi-agent orchestration (Orchestrator → Researcher → Developer → Executor pipeline). Validates Go for subprocess-heavy agent loops. Notable patterns: chain summarization for context window management, Flow → Task → SubTask → Action hierarchy, vector-based memory for learning from past runs.

