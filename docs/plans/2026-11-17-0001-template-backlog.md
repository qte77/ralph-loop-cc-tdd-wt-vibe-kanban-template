---
created: 2026-11-17
status: open
replaces:
  - TODO.md (Everything-Agnostic Ecosystem, last updated 2026-03-13)
  - ralph/TODO.md (Ralph backlog, last updated 2026-03-14)
---

# Template backlog: ecosystem phases and Ralph engine

## Status (start here)

This plan is the template's single backlog. It replaces the two former backlog files, `TODO.md` (the
"Everything-Agnostic Ecosystem" phases) and `ralph/TODO.md` (Ralph engine bugs, cleanups and future work); both now
only point here. Line references were checked against `main` on 2026-11-17.

> **Projects generated from this template:** this file describes the template's own backlog. Keep the rows that
> concern the Ralph engine you copied, delete the rest, and start your own plan next to it.

**Shipped:**

- Ecosystem phases 1-5: adapter system (`adapter.sh`, Ralph lib scripts refactored), scaffold mechanism
  (`.scaffold`, Makefile cleanup), Python scaffold in the plugin, Python files stripped from the template, embedded
  scaffold in the plugin.
- Ralph engine: ad-hoc steering (`RALPH_INSTRUCTION`, `RALPH_MODEL`, `RALPH_DESLOPIFY`); live agent-log monitoring
  without nested prefixes; log-level deduplication (not confirmed in code on 2026-11-17);
  per-call cost cap `RALPH_COST_LIMIT` (#90); BATS test scaffold (`ralph/docs/prd.json` STORY-001).
- Removed 2026-11-17 (owner decision, see Decisions): `lib/teams.sh`, `lib/baseline.sh`, `lib/snapshot.sh` and
  `lib/extract_signatures.py` (teams verification, scoped and baseline-aware checks, codebase snapshot, AST signatures),
  which no script sourced or ran, and the uncalled `verify_teammate_stories()` in `ralph.sh`. The list above used to
  claim "scoped reset on validation failure" and "per-domain retry counters"; nothing on `main` does either
  (`git grep -i reset` and `git grep -i domain` in `ralph/scripts`), so both were dropped.

**What's next, in order:**

1. **Engine bugs, rows 4-5.** Each has a story in `ralph/docs/prd.json` (STORY-002, -003) with BATS
   acceptance criteria. Write the BATS test first (RED), then the fix (GREEN). Rows 4 and 5 are security-relevant
   and overlap #90, so they need the owner's go-ahead before work starts.
2. **Engine cleanups, rows 6-11** (STORY-007 to STORY-010 cover four of them).
3. **Ecosystem phases 6-7, rows 12-13.** Their work happens in the plugin repo (`qte77/claude-code-plugins`).
4. Everything else is future, monitored or deferred, each with its trigger in the table.

**The loop:** one row per branch and PR. Run `make test_bats` before pushing (and `make validate` once a scaffold is
set up; it fails without one); CI runs the BATS suites (`.github/workflows/bats.yaml`). Strike the row in the same PR that ships it and add a CHANGELOG entry.
Merge once CI is green and the owner has approved.

**Owner gates:** rows 4-5 (security, overlap #90), the CLI rewrite decision (row 15), and every row marked `owner`
below.

**Watch-outs:**

- `make test_bats` reports success when `bats` is missing; the CI job installs a pinned `bats` first.

## Source map

| Area | Files and refs |
| --- | --- |
| Adapter interface | Ralph scripts call `adapter_*` functions from `.scaffolds/<name>.sh`: `adapter_test`, `adapter_lint`, `adapter_typecheck`, `adapter_complexity`, `adapter_validate`, `adapter_coverage`, `adapter_signatures`, `adapter_file_pattern`, `adapter_env_setup`, `adapter_app_docs`. Plugin SessionStart hooks deploy scaffolds (copy if absent). Without `.scaffold/`, the calls fall back to no-ops and `make validate` still works. Since the teams libraries were deleted, nothing in this repo calls `adapter_signatures` (it stays as part of the scaffold interface). |
| Engine bug evidence | `docs/audits/quality-audit-2026-03.md` (findings D1-D3, R5, K1, K2, Y1, C2); `ralph/docs/prd.json` (bug-fix sprint, STORY-001 and 006 passed, 002-003 and 007-010 pending; 004-005 dropped with the teams libraries) |
| Row 3 (shipped) | `ralph/scripts/lib/vibe.sh` `kanban_update()` now builds its payload with `jq -n --arg`; `ralph/scripts/tests/test_vibe_json.bats` |
| Row 4 | `ralph/scripts/ralph.sh:377` and `:470` pipe the prompt into `eval claude -p ... $extra_flags` |
| Row 5 | `ralph/scripts/parallel_ralph.sh` worker exit codes (prd.json STORY-003) |
| Rows 6-11 | `ralph/scripts/ralph.sh` `get_next_story()` (line 168), `execute_story()` (334), `fix_validation_errors()` (412), quick-then-full validation (around 476-480); `ralph/scripts/lib/common.sh:71-85` `log_cc*`; `ralph/scripts/lib/vibe.sh` bare `echo "[DEBUG]"` at 112, 116, 126, 131, 133; `ralph/scripts/vibe.sh:22-23` unpinned `npx vibe-kanban` |
| Rows 14-20 | `docs/research/ralph-cli-rewrite.md` (CLI rewrite options; recommends Go), `docs/UserStory.md`, `docs/research/engine-model-ui-adapter-contracts.md`, `ralph/README.md` |

## Remaining work

| # | Section | Item | Gate | Done when |
| --- | --- | --- | --- | --- |
| 1 | Engine bugs | ~~`teams.sh` scoped checks are silent no-ops: they get a story ID where a commit is expected, so `git diff` is empty and every check passes (STORY-005)~~ — dropped: the code was deleted (owner decision 2026-11-17, see Decisions) | — | — |
| 2 | Engine bugs | ~~Two `verify_teammate_stories()` with different behaviour; rename the `ralph.sh` one to `verify_prd_isolation()` (STORY-004)~~ — dropped: the code was deleted (owner decision 2026-11-17, see Decisions) | — | — |
| 3 | Engine bugs | ~~`kanban_update` builds JSON by string concatenation; escaping misses backslashes and newlines. Use `jq --arg` like `kanban_init` (STORY-006)~~ — shipped in the STORY-006 PR (`test_vibe_json.bats`) | — | — |
| 4 | Engine bugs | `eval` expands `$extra_flags` in both `claude -p` calls, so shell metacharacters in a `RALPH_*` value run as commands (STORY-002) | owner (security; overlaps #90) | No `eval` in the claude invocations; flags passed as an array; BATS test with a metacharacter value |
| 5 | Engine bugs | Parallel runs report success when a worker fails: exit codes of disowned workers are not collected (STORY-003) | owner (overlaps #90) | A failing worker makes `parallel_ralph.sh` exit non-zero; BATS test |
| 6 | Engine cleanup | Prompt block duplicated in `execute_story()` and `fix_validation_errors()`; extract `build_story_prompt()` (STORY-010) | agent | One builder used by both; BATS green |
| 7 | Engine cleanup | `get_next_story()` spawns one `jq` per story and dependency; replace the loop with one `jq` query that resolves dependencies (STORY-007) | agent | One `jq` call per lookup; same story order in a BATS test |
| 8 | Engine cleanup | Intermediate fix attempts run quick validation, then full validation again on success (STORY-008) | agent | Intermediate attempts run quick validation only; the last attempt runs full |
| 9 | Engine cleanup | Delete the four unused `log_cc*` functions in `common.sh` (STORY-009) | agent | Functions removed after a repo-wide search confirms no callers; BATS green |
| 10 | Engine cleanup | `vibe.sh` debug lines bypass the `log_*` functions and always print; route them through `log_*` or gate them behind `DEBUG=1` (STORY-009) | agent | No unconditional `[DEBUG]` output |
| 11 | Engine cleanup | Pin the `vibe-kanban` version started by `ralph/scripts/vibe.sh` | agent | `npx vibe-kanban@<version>`; the version is documented |
| 12 | Ecosystem | Phase 6, skill protection: metadata, content hash, CODEOWNERS, CI (in the plugin repo) | agent | Protection checks run in the plugin repo's CI |
| 13 | Ecosystem | Phase 7, GTM market-research plugin: skills, rules, hook, config (in the plugin repo) | agent | Plugin published in the plugin marketplace |
| 14 | Ecosystem | Phase 8, improve `research-compare.py` and its feedback loop | owner (scope not set) | Scope written into this plan, then shipped |
| 15 | Engine future | Rewrite the engine as a standalone CLI (Go recommended in `docs/research/ralph-cli-rewrite.md`); Makefile calls `ralph <subcommand>` | owner (go/no-go) | Decision recorded under Decisions; if go, its own plan |
| 16 | Engine future | Agent Teams for parallel story execution (`make ralph_run TEAMS=true`), incl. the alternative where Claude Code's own team tools orchestrate (stories as tasks with `blockedBy` dependencies) | owner (experimental feature) | A wave of independent stories runs in parallel end to end on a sample PRD |
| 17 | Engine future | Cumulative cost tracking per story and run (per-call cap shipped in #90); needs `--output-format json` without losing the live log stream | agent | Total cost per story and run recorded in progress output; live tailing still works |
| 18 | Engine future | Optional PR per worktree (`RALPH_CREATE_PR=true`) instead of auto-merge; with judge mode, a PR for the best worktree | agent | Flag documented; a run with it opens a PR and leaves the branch unmerged |
| 19 | Engine future | Diff stats (`git diff --stat`) per worktree in `ralph_status` and in scoring output (display only) | agent | `ralph_status` shows insertions and deletions per worktree |
| 20 | Engine future | Streaming progress (WebSocket) for dashboards; PRD versioning with story carry-over | owner (no consumer yet) | A consumer exists and the design is written here |
| 21 | Monitor | Fast mode for the loop | data | Revisit when pricing drops or the loop becomes interactive |
| 22 | Monitor | Cloud sessions for the loop | data | Revisit when cloud sessions support custom images or MCP forwarding |
| 23 | Monitor | BDD workflow support (only TDD `[RED]`/`[GREEN]`/`[REFACTOR]` today) | data | Revisit when a BDD project needs Ralph |
| 24 | Monitor | Cross-layer validation commands | data | Revisit when a project becomes multi-layer |
| 25 | Deferred | Intra-story teams (test writer plus implementer on one story) | data | Revisit after inter-story teams are validated |
| 26 | Deferred | Git worktrees for teams isolation, merged at wave boundaries | data | Revisit after scoped checks and wave checkpoints are validated |
| 27 | Deferred | Automated impact-scope analysis after a story (removed identifiers still used in `tests/`) | data | Revisit after a second incident |
| 28 | Deferred | Inline-snapshot drift detection (`pytest --inline-snapshot=review`) | data | Revisit when its output is stable for non-interactive use |
| 29 | Deferred | Warn when a source module has tests in several directories | data | Revisit when it causes a real problem (YAGNI) |
| 30 | Setup | Optional: RTK output compression for Claude Code sessions (user-level hook, no Ralph changes) | owner (machine setup) | Installed on the machine that runs the loop, or dropped |
| 31 | Engine cleanup | `ralph/scripts/parallel_ralph.sh` (around line 358) loops `for _pat in $_file_pattern` unquoted, so the scaffold's file patterns are word-split and globbed against the current directory; the values only become `find -name` arguments, nothing is evaluated (decision (d) in #118) | agent (next change to `parallel_ralph.sh`) | The loop reads the patterns into an array; BATS green |

## Decisions

| Decision | Rationale | Date |
| --- | --- | --- |
| AST over grep for codebase-map signatures | AST captures return types, decorators and full argument annotations; grep misses them. Speed difference negligible (1.2x). Complexipy stays as a quality gate only. | 2026-03-08 |
| One plan file replaces both TODO files | One backlog with one remaining-work table can't drift between two files. | 2026-11-17 |
| Delete the unused teams libraries (owner: "Delete it") | `lib/teams.sh`, `lib/baseline.sh` and `lib/snapshot.sh` were sourced by no script, and neither `verify_teammate_stories()` had a caller (`git grep` on `main` at `a0680a4`, outside `docs/` and Markdown). Fixing them (old rows 1-2) would have fixed dead code. Deleted with `lib/extract_signatures.py`, which only `snapshot.sh` ran. Agent Teams (row 16) starts from scratch if picked up | 2026-11-17 |

## Sources

- [Codified Context Infrastructure](https://arxiv.org/abs/2602.20478): three-tier context architecture (constitution,
  specialist agents, cold-memory knowledge base); validates the AGENTS.md + skills + docs/ pattern.
- [tree-sitter](https://github.com/tree-sitter/tree-sitter) and
  [tree-sitter-python](https://www.npmjs.com/package/tree-sitter-python): relevant if the CLI rewrite picks Bun or
  Deno over Go.
- [PentAGI](https://github.com/vxcontrol/pentagi): Go multi-agent orchestration; supports Go for subprocess-heavy
  agent loops.
- [devteam](https://github.com/agent-era/devteam): inspiration for rows 18 and 19.
- [RTK](https://github.com/rtk-ai/rtk): shell-output compression (row 30).
