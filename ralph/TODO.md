---
title: Ralph TODO
purpose: Consolidated backlog for Ralph loop — bugs, enhancements, and deferred items.
created: 2026-03-08
updated: 2026-03-08
---

## Adopt Now (zero cost)

None.

<!-- markdownlint-disable MD013 -->

## Backlog

## Future Work

- [ ] **Agent Teams for parallel story execution**: Enable with `make ralph_run TEAMS=true` (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`). Lead agent orchestrates teammates with skill-specific delegation. **Terminology**: a **wave** is the set of currently unblocked stories (all `depends_on` satisfied) — i.e., the frontier of the dependency graph. Stories within a wave run in parallel (one teammate each); the next wave starts after the current one completes.
  - [ ] **CC Agent Teams as alternative orchestrator**: Instead of Ralph's bash loop driving `claude -p` with bolted-on teams support, the CC main orchestrator agent directly spawns a team via `TeamCreate` + `Task` tool. Each story becomes a `TaskCreate` entry with `blockedBy` dependencies (both logical and file-conflict). Addresses Ralph failure modes structurally: isolated teammate contexts prevent cross-contamination (#2), `blockedBy` prevents stale snapshots (#4), no external reset eliminates Sisyphean loops (#1), lead-scoped validation prevents cross-story complexity failures (#3), and file-conflict deps in `blockedBy` prevent parallel edits to the same file (#5). Requires self-contained story descriptions in the PRD Story Breakdown (usable as `TaskCreate(description=...)`).

- [ ] **Ad-hoc steering instructions**: Accept a free-text `INSTRUCTION` parameter via CLI/Make to inject user guidance into the prompt without editing tracked files. Usage: `make ralph_run INSTRUCTION="focus on error handling"`. The instruction would be appended to the story prompt so the agent factors it in during implementation.

- [ ] **Rewrite Ralph engine as standalone CLI**: The bash script engine (~3k lines across 13 files) is brittle, untestable, and diverges when the template is forked. Rewrite as a standalone binary distributed as a single executable. Makefile stays as the user-facing interface, calling `ralph <subcommand>` instead of `bash ralph/scripts/*.sh`. Includes language adapter system for TDD/BDD validation across Python, Go, TypeScript, Rust, C++, and C. **Candidates** (choose one):
  - **Go**: Static binary (10-15 MB, zero runtime deps), goroutines map directly to N-worker pattern, trivial cross-compilation. Key deps: Cobra (CLI), Viper (config). See [`docs/UserStory.md`](../docs/UserStory.md) for full requirements.
  - **Bun/Deno**: Scripting feel + types + native JSON. Biggest wins: eliminates jq, typed story/prd interfaces, async process spawning. Maps cleanly: jq queries → JSON.parse, background monitor → async/await + AbortController, `claude -p` piping → Bun.spawn/Deno.Command. Python signature extraction via [tree-sitter](https://www.npmjs.com/package/tree-sitter) + [tree-sitter-python](https://www.npmjs.com/package/tree-sitter-python) (WASM variant works without native compilation). Needs investigation: `exec > >(tee)` dual logging, signal/trap handling, `ralph-in-worktree.sh` git coupling.

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
- [tree-sitter](https://github.com/tree-sitter/tree-sitter) — incremental parser generator (C + WASM); [tree-sitter-python](https://www.npmjs.com/package/tree-sitter-python) grammar. npm alternative for Python signature extraction in Bun/Deno CLI rewrite.

