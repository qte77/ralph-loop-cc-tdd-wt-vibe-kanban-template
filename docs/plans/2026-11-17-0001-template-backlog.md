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
  without nested prefixes; inter-story Agent Teams; scoped reset on validation failure; log-level deduplication;
  AST-based signature extraction; codebase snapshot and context-drift detection; per-domain retry counters;
  per-call cost cap `RALPH_COST_LIMIT` (#90); BATS test scaffold (`ralph/docs/prd.json` STORY-001).

**What's next, in order:**

1. **Engine bugs, rows 1-5.** Each has a story in `ralph/docs/prd.json` (STORY-002 to STORY-006) with BATS
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

- `ralph/scripts/lib/teams.sh` and `ralph/scripts/lib/baseline.sh` are not sourced by any script on `main`, and
  `verify_teammate_stories()` / `verify_prd_isolation()` have no callers: teams mode is not wired yet (row 16).
  Tests source these files directly.
- `make test_bats` reports success when `bats` is missing; the CI job installs a pinned `bats` first.

## Source map

| Area | Files and refs |
| --- | --- |
| Adapter interface | Ralph scripts call `adapter_*` functions from `.scaffolds/<name>.sh`: `adapter_test`, `adapter_lint`, `adapter_typecheck`, `adapter_complexity`, `adapter_validate`, `adapter_coverage`, `adapter_signatures`, `adapter_file_pattern`, `adapter_env_setup`, `adapter_app_docs`. Plugin SessionStart hooks deploy scaffolds (copy if absent). Without `.scaffold/`, the calls fall back to no-ops and `make validate` still works. |
| Engine bug evidence | `docs/audits/quality-audit-2026-03.md` (findings D1-D3, R5, K1, K2, Y1, C2); `ralph/docs/prd.json` (bug-fix sprint, STORY-001 passed, 002-010 pending) |
| Row 1 | `ralph/scripts/lib/teams.sh:227`, `:232`, `:238` pass the story ID to `run_ruff_scoped`, `run_complexity_scoped`, `run_tests_scoped`; `ralph/scripts/lib/baseline.sh` expects a base commit for `git diff --name-only`; `get_story_base_commit()` is at `baseline.sh:29` (used at `baseline.sh:261`, not by `teams.sh`) |
| Row 2 (shipped) | `ralph/scripts/ralph.sh:226` `verify_prd_isolation()` (was a second `verify_teammate_stories()`); `ralph/scripts/lib/teams.sh:195` `verify_teammate_stories()` |
| Row 3 | `ralph/scripts/lib/vibe.sh` `kanban_update()` (from line 105; JSON built by concatenation around lines 157-174, `sed` escapes only `"`); `kanban_init` in the same file already uses `jq --arg` |
| Row 4 | `ralph/scripts/ralph.sh:395` and `:488` pipe the prompt into `eval claude -p ... $extra_flags` |
| Row 5 | `ralph/scripts/parallel_ralph.sh` worker exit codes (prd.json STORY-003) |
| Rows 6-11 | `ralph/scripts/ralph.sh` `get_next_story()` (line 168), `execute_story()` (352), `fix_validation_errors()` (430), quick-then-full validation (around 494-498); `ralph/scripts/lib/common.sh:71-85` `log_cc*`; `ralph/scripts/lib/vibe.sh` bare `echo "[DEBUG]"` at 112, 116, 126, 131, 133; `ralph/scripts/vibe.sh:22-23` unpinned `npx vibe-kanban` |
| Rows 14-20 | `docs/research/ralph-cli-rewrite.md` (CLI rewrite options; recommends Go), `docs/UserStory.md`, `docs/research/engine-model-ui-adapter-contracts.md`, `ralph/README.md` |

## Remaining work

| # | Section | Item | Gate | Done when |
| --- | --- | --- | --- | --- |
| 1 | Engine bugs | `teams.sh` scoped checks are silent no-ops: they get a story ID where a commit is expected, so `git diff` is empty and every check passes (STORY-005) | agent | BATS test fails on `main` and passes after the fix; `teams.sh` passes `get_story_base_commit "$sid"` |
| 2 | Engine bugs | ~~Two `verify_teammate_stories()` with different behaviour; rename the `ralph.sh` one to `verify_prd_isolation()` (STORY-004)~~ — shipped in the STORY-004 PR (neither function has a caller on `main`; see row 16) | — | — |
| 3 | Engine bugs | `kanban_update` builds JSON by string concatenation; escaping misses backslashes and newlines. Use `jq --arg` like `kanban_init` (STORY-006) | agent | A reason containing `"`, `\` and a newline produces valid JSON in a BATS test |
| 4 | Engine bugs | `eval` expands `$extra_flags` in both `claude -p` calls, so shell metacharacters in a `RALPH_*` value run as commands (STORY-002) | owner (security; overlaps #90) | No `eval` in the claude invocations; flags passed as an array; BATS test with a metacharacter value |
| 5 | Engine bugs | Parallel runs report success when a worker fails: exit codes of disowned workers are not collected (STORY-003) | owner (overlaps #90) | A failing worker makes `parallel_ralph.sh` exit non-zero; BATS test |
| 6 | Engine cleanup | Prompt block duplicated in `execute_story()` and `fix_validation_errors()`; extract `build_story_prompt()` (STORY-010) | agent | One builder used by both; BATS green |
| 7 | Engine cleanup | `get_next_story()` spawns one `jq` per story and dependency; use the single-query `get_unblocked_stories \| head -1` (STORY-007) | agent | One `jq` call per lookup; same story order in a BATS test |
| 8 | Engine cleanup | Intermediate fix attempts run quick validation, then full validation again on success (STORY-008) | agent | Intermediate attempts run quick validation only; the last attempt runs full |
| 9 | Engine cleanup | Delete the four unused `log_cc*` functions in `common.sh` (STORY-009) | agent | Functions removed after a repo-wide search confirms no callers; BATS green |
| 10 | Engine cleanup | `vibe.sh` debug lines bypass the `log_*` functions and always print; route them through `log_*` or gate them behind `DEBUG=1` (STORY-009) | agent | No unconditional `[DEBUG]` output |
| 11 | Engine cleanup | Pin the `vibe-kanban` version started by `ralph/scripts/vibe.sh` | agent | `npx vibe-kanban@<version>`; the version is documented |
| 12 | Ecosystem | Phase 6, skill protection: metadata, content hash, CODEOWNERS, CI (in the plugin repo) | agent | Protection checks run in the plugin repo's CI |
| 13 | Ecosystem | Phase 7, GTM market-research plugin: skills, rules, hook, config (in the plugin repo) | agent | Plugin published in the plugin marketplace |
| 14 | Ecosystem | Phase 8, improve `research-compare.py` and its feedback loop | owner (scope not set) | Scope written into this plan, then shipped |
| 15 | Engine future | Rewrite the engine as a standalone CLI (Go recommended in `docs/research/ralph-cli-rewrite.md`); Makefile calls `ralph <subcommand>` | owner (go/no-go) | Decision recorded under Decisions; if go, its own plan |
| 16 | Engine future | Agent Teams for parallel story execution (`make ralph_run TEAMS=true`), incl. the alternative where Claude Code's own team tools orchestrate (stories as tasks with `blockedBy` dependencies). Wiring it means sourcing `lib/baseline.sh` and `lib/teams.sh` (not sourced anywhere today) and calling `verify_teammate_stories()` and `verify_prd_isolation()` (no callers today). The isolation check then needs rework: it greps the whole `git diff` of prd.json, so context lines from neighbouring stories count as changes, while a status change in a multi-line story often carries no `id` line at all | owner (experimental feature) | A wave of independent stories runs in parallel end to end on a sample PRD |
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

## Decisions

| Decision | Rationale | Date |
| --- | --- | --- |
| AST over grep for codebase-map signatures | AST captures return types, decorators and full argument annotations; grep misses them. Speed difference negligible (1.2x). Complexipy stays as a quality gate only. | 2026-03-08 |
| One plan file replaces both TODO files | One backlog with one remaining-work table can't drift between two files. | 2026-11-17 |

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
