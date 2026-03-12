<!-- markdownlint-disable MD024 no-duplicate-heading -->

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

**Types of changes**: `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, `Security`

## [Unreleased]

### Added

- `RALPH_DRY_RUN` config + one-shot mode in `ralph.sh`: skip TDD verification and quality checks (`DRY_RUN=true` via Makefile)
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

### Removed

- Language-specific Claude Code skills from `.claude/skills/`: `implementing-python`, `testing-python`, `reviewing-code`, `designing-backend`, `designing-mas-plugins`, `securing-mas`, `auditing-website-usability`, `auditing-website-accessibility`, `researching-website-design`
- `.claude/settings.json` removed from repo (user-local config; use `.claude/settings.local.json` for overrides)
- Language-specific Makefile recipes moved out of main `Makefile` into `Makefile.python`

### Changed

- `ralph_run`, `ralph_init_and_run`: added TIMEOUT, MODEL, TEAMS, DRY_RUN, INSTRUCTION, DESLOPIFY pass-through params
- `ralph_run_worktree`: expanded from worktree-only to full run-in-worktree with all params
- Main `Makefile` is now language-agnostic: ralph, scaffold, setup, lint, and vibe-kanban recipes only
- `devcontainer.json` split `postCreateCommand` into `onCreateCommand` (toolchain) and `postCreateCommand` (CC/npm/lychee)
- README updated with scaffold workflow documentation
