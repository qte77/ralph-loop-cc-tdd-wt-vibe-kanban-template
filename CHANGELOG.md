<!-- markdownlint-disable MD024 no-duplicate-heading -->

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

**Types of changes**: `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, `Security`

## [Unreleased]

### Added

- Compound learning, ported from `feat/compound-learning` (#75): `ralph/scripts/lib/compound.sh` appends story-relevant lines from operator-set Markdown directories (`COMPOUND_LEARNINGS_PATH`, `COMPOUND_MEMORY_PATH`, `COMPOUND_PLANS_PATH`; all unset by default, so nothing is read) to each story prompt under `## Compound Learnings`, capped at `COMPOUND_MAX_LINES` (50), each line quoted with a leading `>` and cut at 500 bytes after control characters are removed, and labelled as reference data, not instructions. `COMPOUND_ENABLED=false` removes a context file left by an earlier run. Opt-in write-back (`COMPOUND_WRITEBACK_ENABLED`) appends new patterns from `ralph/LEARNINGS.md` to `COMPOUND_WRITEBACK_TARGET` every `COMPOUND_WRITEBACK_INTERVAL` passed stories (a value that is not a positive integer falls back to 5); the extraction runs with no tools (`--tools ""`, `--strict-mcp-config`) instead of the branch's `--dangerously-skip-permissions`, and its input is framed as data, not instructions. The flags go in an argument array; nothing is appended when the call fails, a failed append is logged without stopping the loop, and the target is named after the main repository rather than the run's worktree directory. Fixed on the way in: the branch piped the content-hash assignment instead of its contents, so the hash was always empty and every story reused the first story's cached context. Config documented in `ralph/README.md`; tests in `ralph/scripts/tests/test_compound.bats`
- `docs/plans/2026-11-17-0001-template-backlog.md`: one backlog plan with a single remaining-work table, holding the ecosystem phases (from `TODO.md`) and the Ralph engine backlog (from `ralph/TODO.md`), line references re-checked against `main`. Both TODO files now only point to it; `ralph/README.md` and `llms.txt` link the plan
- `RALPH_COST_LIMIT` config: USD cap per `claude -p` call, passed as `--max-budget-usd` via a new `claude_budget_flags()` helper in `ralph/scripts/lib/common.sh`; wired into every claude invocation in `ralph.sh`, `parallel_ralph.sh`, and `lib/judge.sh`. Unset means no cap (unchanged behavior). Per-story/per-run cumulative cost tracking is still open — logging `total_cost_usd` needs `--output-format json`, which would replace the human-readable stream the loop currently tees to its logs (#90)
- Per-story `--session-id` for every `claude -p` story execution, recorded as `Session: <uuid>` in `ralph/docs/progress.txt`: an interrupted story's exact conversation can be continued with `claude -p --resume <uuid>` instead of starting over. `get_next_story()` already skipped stories marked `"passed"`, so a resumed `make ralph_run` already continued from the next pending story — documented in `ralph/README.md` (#90)
- `.github/workflows/bats.yaml`: CI job running the Ralph `ralph/scripts/tests/*.bats` suites via `make test_bats` on push/PR to `main`. Installs a pinned `bats@1.13.0` and verifies the install before running, since `make test_bats` otherwise silently reports success when `bats` is missing

### Changed

- Claude Code `.claude/settings.json` sets `BASH_MAX_OUTPUT_LENGTH` to `15000` and
  `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` to `50` ([env vars](https://code.claude.com/docs/en/env-vars));
  `.claude/scripts/statusline.sh` is refreshed from claude-code-plugins 60388b9e: it shows context
  used and the autocompact point, and guards non-numeric input
- Compound learning (`ralph/scripts/lib/config.sh`, `ralph/scripts/lib/compound.sh`), the deferred design items from #115: the context file and its cache hash in `RALPH_TMP_DIR` are named per worktree (`compound-context-<worktree-dir>.md`), so parallel workers no longer share them; write-back bounds each of `ralph/LEARNINGS.md` and the hub file to 32 KB in the extraction prompt, keeping every heading and entry title plus the newest lines of each section (a file within 32 KB goes in whole); the hub file is named after `remote.origin.url` when it is set (falling back to the main repository's directory name), so checkouts in differently named directories agree. Documented in `ralph/README.md` (git 2.31+ for the fallback; two repositories with the same name share one hub file); tests in `ralph/scripts/tests/test_compound.bats`

### Security

- `execute_story()` and `fix_validation_errors()` in `ralph/scripts/ralph.sh` ran their `claude -p` command line through `eval` (and `bash -c` for the fix call), so a `;` in `RALPH_MODEL`, `RALPH_PERMISSION_MODE` or `RALPH_COST_LIMIT` ran as a shell command. Both calls now pass an argument array built by `build_claude_args()` (replacing `build_claude_extra_flags()`), and `timeout` runs `claude` directly. `judge_worktrees()` in `ralph/scripts/lib/judge.sh` had the same defect in its `bash -c` call (`RALPH_JUDGE_MODEL`, `RALPH_PERMISSION_MODE`, `RALPH_COST_LIMIT`) and now passes an argument array too. This also fixes the fix call splitting the `RALPH_DESLOPIFY` system prompt into separate words. Tests in `ralph/scripts/tests/test_claude_args.bats`, which also fail on any `bash -c`, or any `eval` other than the `find` in `lib/generate_app_docs.sh`, in `ralph.sh`, `parallel_ralph.sh` or `lib/*.sh`
- `generate_app_readme()` in `ralph/scripts/lib/generate_app_docs.sh` built its `find` fallback (used when `tree` is missing) as a string and ran it through `eval`, so a source directory name holding `$(...)` ran as shell code, and the scaffold's file patterns were globbed against the current directory first, which could list the wrong files. `find` now gets an argument array. `compress_progress()` in `ralph.sh` and the learnings-review and security-review calls in `parallel_ralph.sh` passed the permission and budget flags unquoted (word-split and globbed); they now use an argument array like `build_claude_args()`. The guard tests in `ralph/scripts/tests/test_claude_args.bats` now cover every script under `ralph/scripts`, allow no `eval`, match any `sh`/`bash`/`zsh`/`dash` call with `-c` in its options (`sh -c`, `bash -lc`), and fail on an unquoted expansion of the flag helpers
- Replaced `--dangerously-skip-permissions` on every `claude -p` call in `ralph.sh`, `parallel_ralph.sh`, and `lib/judge.sh` with `--permission-mode ${RALPH_PERMISSION_MODE:-auto} --permission-prompts none` (new `claude_permission_flags()` helper in `lib/common.sh`; `RALPH_PERMISSION_MODE` override, e.g. back to `bypassPermissions`). `.claude/settings.json` now ships `permissions.deny` for `git push`, `gh pr merge`, `git reset --hard`, `git rebase`, and `git commit --amend` — these apply in every permission mode, including bypass, but are not a full security boundary (#90)
- `watch.sh` and `lib/stop_ralph_processes.sh` matched running claude processes via `ps aux | grep "...dangerously-skip-permissions"`; updated the sentinel to `--permission-prompts none` so `ralph_watch`/`ralph_stop` keep finding Ralph's claude processes after the flag swap (#90)

- `uv.lock` regenerated from the template `pyproject.toml` (it was left over from another project and pinned by a fixed `exclude-newer` date); unused `observability` group (logfire, weave) dropped. `pyproject.toml` now carries valid defaults so uv and Dependabot can resolve it; Dependabot uses a 7-day `cooldown` instead (#92)

### Removed

- `ralph/scripts/lib/teams.sh`, `lib/baseline.sh`, `lib/snapshot.sh` and `lib/extract_signatures.py`, and the uncalled `verify_teammate_stories()` in `ralph/scripts/ralph.sh` (owner decision 2026-11-17). No script sourced these libraries or called the function, so teams verification, scoped and baseline-aware checks, the codebase snapshot and AST signature extraction never ran. `ralph/README.md` no longer describes them; prd.json drops STORY-004 and STORY-005, and STORY-007 no longer relies on `get_unblocked_stories`

### Fixed

- Compound learning (`ralph/scripts/lib/compound.sh`): `COMPOUND_WRITEBACK_INTERVAL` and `COMPOUND_MAX_LINES` must be positive integers of at most six digits, matched without a locale-dependent range; anything else is logged and replaced by 5 and 50 (a non-numeric `COMPOUND_MAX_LINES` used to stop the loop, and a non-ASCII digit or a 20-digit interval passed the old check). Injected lines also lose U+2028, U+2029 and U+0085. A source path that is a symlink to a directory is followed (`find -H`). The cap no longer pipes into `head`, which could exit 141 under `pipefail`. The context cache key now includes the story title and description. Write-back creates a missing `RALPH_TMP_DIR` before redirecting to it instead of silently skipping
- Bats tests: `fail` was undefined, so a failing assertion reported `fail: command not found`. A local helper, `ralph/scripts/tests/test_helper/fail.bash`, is loaded by every test file that calls it, and a test checks that
- `kanban_update` (`ralph/scripts/lib/vibe.sh`) built its JSON payload by string concatenation and escaped only `"`, so a failure reason with a backslash or a newline produced invalid JSON and the Vibe Kanban update failed. It now builds the payload with `jq --arg`, like `kanban_init`; same keys and values. Tested in `ralph/scripts/tests/test_vibe_json.bats` (STORY-006)

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
- `write-llms-txt` workflow pushed straight to `main` and was rejected by main's branch rules on every run (#103). Replaced the `uithub.com` curl-and-push step with [`qte77/gha-llms-txt-action`](https://github.com/qte77/gha-llms-txt-action) (pinned to v0.1.0), which renders `docs/llms.txt` from a new curated template at `.github/templates/llms.txt.tpl` and opens a PR instead of pushing directly
- `ralph.sh`: extracted the duplicated "Agent Learnings / Human Requests / Recent Run History / Steering Instruction" prompt-building code (previously built separately in `execute_story()` and `fix_validation_errors()`) into a single `inject_shared_prompt_sections()` function, fixing a CodeFactor-flagged duplication
- `ralph/scripts/tests/test_helper/common-setup.bash`'s `_setup_git_config()` no longer writes to the machine's real global git config: it now redirects `GIT_CONFIG_GLOBAL` to a file inside the test's isolated tmp dir before calling `git config --global` (#90)
- `parallel_ralph.sh` records each worker's real exit code from `.ralph_exit` in its worktree instead of hardcoding 0 (#90)
