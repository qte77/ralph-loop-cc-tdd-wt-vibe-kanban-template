<!-- markdownlint-disable MD024 no-duplicate-heading -->

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

**Types of changes**: `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, `Security`

## [Unreleased]

### Added

- `RALPH_COST_LIMIT` config: USD cap per `claude -p` call, passed as `--max-budget-usd` via a new `claude_budget_flags()` helper in `ralph/scripts/lib/common.sh`; wired into every claude invocation in `ralph.sh`, `parallel_ralph.sh`, and `lib/judge.sh`. Unset means no cap (unchanged behavior). Per-story/per-run cumulative cost tracking is still open — logging `total_cost_usd` needs `--output-format json`, which would replace the human-readable stream the loop currently tees to its logs (#90)
- Per-story `--session-id` for every `claude -p` story execution, recorded as `Session: <uuid>` in `ralph/docs/progress.txt`: an interrupted story's exact conversation can be continued with `claude -p --resume <uuid>` instead of starting over. `get_next_story()` already skipped stories marked `"passed"`, so a resumed `make ralph_run` already continued from the next pending story — documented in `ralph/README.md` (#90)

### Security

- Replaced `--dangerously-skip-permissions` on every `claude -p` call in `ralph.sh`, `parallel_ralph.sh`, and `lib/judge.sh` with `--permission-mode ${RALPH_PERMISSION_MODE:-auto} --permission-prompts none` (new `claude_permission_flags()` helper in `lib/common.sh`; `RALPH_PERMISSION_MODE` override, e.g. back to `bypassPermissions`). `.claude/settings.json` now ships `permissions.deny` for `git push`, `gh pr merge`, `git reset --hard`, `git rebase`, and `git commit --amend` — these apply in every permission mode, including bypass, but are not a full security boundary (#90)
- `watch.sh` and `lib/stop_ralph_processes.sh` matched running claude processes via `ps aux | grep "...dangerously-skip-permissions"`; updated the sentinel to `--permission-prompts none` so `ralph_watch`/`ralph_stop` keep finding Ralph's claude processes after the flag swap (#90)

- `uv.lock` regenerated from the template `pyproject.toml` (it was left over from another project and pinned by a fixed `exclude-newer` date); unused `observability` group (logfire, weave) dropped. `pyproject.toml` now carries valid defaults so uv and Dependabot can resolve it; Dependabot uses a 7-day `cooldown` instead (#92)

### Added

- `RALPH_DRY_RUN` config + one-shot mode in `ralph.sh`: skip TDD verification and quality checks (`DRY_RUN=true` via Makefile)
- `RALPH_MODEL` config: override model for all claude calls, bypassing `classify_story` routing (`MODEL=opus` via Makefile)
- `RALPH_INSTRUCTION` config: free-text steering injected into story and fix prompts (`INSTRUCTION="focus on X"` via Makefile)
- `RALPH_DESLOPIFY` config: append quality-enforcement system prompt to all claude calls (`DESLOPIFY=true` via Makefile)
- `ralph_create_prd_json` recipe with `DRY_RUN=1` support for parse-only validation
- `ralph_worktree` recipe for standalone worktree creation without running Ralph
- `RALPH_PARALLEL_KEEP_WORKTREES` config: preserve worktrees after successful runs and fatal errors for post-run inspection (`KEEP_WORKTREES=true` via Makefile)
- `make setup_scaffold LANG=<lang>` recipe: writes `.scaffold`, validates supported languages (python, embedded)
- `make setup_toolchain` recipe: reads `.scaffold` and installs the language-specific toolchain
- `Makefile.python`: language-specific recipes (ruff, type_check, test, validate, docs) — auto-included when `.scaffold` contains `python`
- `Makefile.embedded`: CMake build/flash recipes — auto-included when `.scaffold` contains `embedded`
- `-include Makefile.$(shell cat .scaffold 2>/dev/null)` directive in main `Makefile` for auto-dispatch
- `onCreateCommand` in `.devcontainer/project/devcontainer.json` runs `setup_scaffold LANG=python && setup_toolchain`
- `.scaffold` added to `.gitignore`
- `docs/research/ralph-cli-rewrite.md`: comprehensive research evaluating 5 rewrite options (bash hardening, Bun, Go, Deno, Python) with architecture sketches, Vibe Kanban integration analysis, and decision framework

### Removed

- Language-specific Claude Code skills from `.claude/skills/`: `implementing-python`, `testing-python`, `reviewing-code`, `designing-backend`, `designing-mas-plugins`, `securing-mas`, `auditing-website-usability`, `auditing-website-accessibility`, `researching-website-design`
- `.claude/settings.json` removed from repo (user-local config; use `.claude/settings.local.json` for overrides)
- Language-specific Makefile recipes moved out of main `Makefile` into `Makefile.python`

### Changed

- Standardized .claude (marketplace qte77-claude-code-plugins, estate rules incl. compound-learning, attribution); README to doc-structure canon; AGENTS.md Conventions section; documented the CodeQL pull_request-trigger estate exception.
- `ralph_run`, `ralph_init_and_run`: added TIMEOUT, MODEL, TEAMS, DRY_RUN, INSTRUCTION, DESLOPIFY pass-through params
- Removed unused `RALPH_TEAMS` env var passthrough from Makefile recipes (only `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` matters downstream)
- `ralph_run_worktree`: expanded from worktree-only to full run-in-worktree with all params
- Main `Makefile` is now language-agnostic: ralph, scaffold, setup, lint, and vibe-kanban recipes only
- `devcontainer.json` split `postCreateCommand` into `onCreateCommand` (toolchain) and `postCreateCommand` (CC/npm/lychee)
- README updated with scaffold workflow documentation

### Fixed

- `ralph/README.md` docs drift (#90): TDD verification is skipped for `STORY-000` (`check_tdd_commits()` in `ralph.sh`), not `STORY-001` as previously documented; "Autonomous Operation" said the loop auto-pushes to remote at completion, but `merge_best()` only merges the best worktree into the local branch and commits — there is no `git push` anywhere under `ralph/scripts/`
- `make validate` no longer always exits 0: the root fallback recipe overrode `Makefile.<scaffold>`'s `validate`, so the Ralph quality gate never failed. The fallback is now defined only when no scaffold Makefile is included, and it exits non-zero (#90)
- `ralph.sh`: extracted the duplicated "Agent Learnings / Human Requests / Recent Run History / Steering Instruction" prompt-building code (previously built separately in `execute_story()` and `fix_validation_errors()`) into a single `inject_shared_prompt_sections()` function, fixing a CodeFactor-flagged duplication
- `parallel_ralph.sh` records each worker's real exit code from `.ralph_exit` in its worktree instead of hardcoding 0 (#90)
