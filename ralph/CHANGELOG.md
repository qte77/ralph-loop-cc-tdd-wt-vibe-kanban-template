# Changelog

All notable changes to Ralph Loop are documented in this file.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Status enum (`"pending"`, `"in_progress"`, `"passed"`, `"failed"`) replacing
  `passes: boolean` in prd.json schema
- Wave computation (`compute_waves()`) for dependency-frontier tracking —
  assigns BFS wave numbers to stories based on dependency graph
- Teammate story verification (`verify_teammate_stories()`) — detects
  accidental modifications to other stories during execution
- Legacy guard in `ralph.sh` — blocks execution if prd.json uses old
  `passes` field, with migration instructions
- `generate_prd_json.py` — standalone PRD parser ported from upstream with
  status enum, wave fields, and `passes` -> `status` migration
- `ralph-in-worktree.sh` — git worktree launcher with configurable symlinks
  (`RALPH_WORKTREE_SYMLINKS`)
- `ralph_run_worktree` Makefile recipe for worktree-based Ralph execution
- Scoped linting/testing to prevent cross-story interference in teams mode
- Wave checkpoint validation for dependency tracking at wave boundaries
- Parallel worktree orchestration (`parallel_ralph.sh`) with scoring and
  merge of best result
- PRD parser (`generate_prd_json.py`) for structured project definition
  with automatic JSON generation from PRD.md
- Baseline-aware test validation (`baseline.sh`) — only new failures block
  progress, pre-existing failures are tolerated
- Claude-as-Judge evaluation for worktree selection (`judge.sh`,
  `judge.prompt.md`) — pairwise comparison for N_WT>1
- Vibe Kanban integration for real-time visual monitoring (`vibe.sh`)
- Compound engineering via `LEARNINGS.md` — agents auto-read before each
  story, append learnings after completion
- Bi-directional communication via `REQUESTS.md` — human-to-agent guidance
  channel, changes picked up next iteration
- Interactive UserStory.md generation skill
  (`generating-interactive-userstory-md`)
- PRD.md generation from UserStory.md skill
  (`generating-prd-md-from-userstory-md`)
- prd.json generation from PRD.md skill
  (`generating-prd-json-from-prd-md`)
- Security review skill integration (`RALPH_SECURITY_REVIEW`)
- Interactive merge approval (`RALPH_MERGE_INTERACTIVE`)
- DEBUG mode with auto-watch and worktree persistence
- Resume detection for paused worktrees
- Background process persistence via `disown`
- Double confirmation safety for `ralph_clean`
- Impact scan prompt instruction for rename detection
- Killed-process detection (exit 137/143 as hard failure)
- Pycache cleanup before test runs
- `prompt.md` upstream-compatible agent prompt template
- Runtime initialization of `docs/PRD.md` and `docs/UserStory.md` from
  templates via `init.sh` (no longer requires pre-existing files)
- `docs/NAMING.md` — CLI name candidates research with availability
  analysis, taglines, and elimination rationale

### Changed

- Raised default max iterations to 25
- Disabled mandatory refactor phase by default (`REQUIRE_REFACTOR=false`)
- Skills relocated to `.claude/skills/`
- Documentation reorganized: `ralph/docs/README.md` content moved to
  `ralph/README.md` (root of ralph module)
- Centralized configuration in `ralph/scripts/lib/config.sh`
- Model routing: sonnet for implementation, haiku for fixes and simple
  changes, configurable judge model
- `TEMPLATE_USAGE.md` consolidated into `ralph/README.md`
- `docs/PRD.md` removed as committed file — now generated from template
  at runtime by `init.sh`
- `docs/UserStory.md` rewritten for Go CLI rewrite specification
- Makefile `ralph_run` uses `env -u VIRTUAL_ENV` for clean subprocess
  environments

### Removed

- `ralph/TEMPLATE_USAGE.md` (merged into `ralph/README.md`)
- `docs/PRD.md` as tracked file (replaced by runtime template init)

### Fixed

- pytest collection errors now detected alongside test failures
- Proper handling of out-of-memory conditions (exit codes 137/143)
- Corrected file-conflict tracking in dependency graphs
- PRD parser: fixed 45 blank lines between section headers causing
  parser failures
- CC monitor log nesting: tracks byte offset between cycles to prevent
  `[CC] [INFO] [CC] [INFO] ...` chains
- Deduplicated log level in CC monitor output
- Scoped reset on red-green validation failure: only story-created files
  removed, not entire working tree
- TDD commit counter persistence across quality-failure resets
- Typos in `prd.json.template` (`desciption` → `description`)

## Known Issues

- TDD commit counter doesn't survive `git reset --hard` (Sisyphean loop
  in edge cases) — see `ralph/README.md` Known Failure Modes
- Teams mode cross-contamination when agent combines work across stories
- Complexity gate catches cross-story changes in teams mode
- Stale snapshot tests from other stories in same batch
- File-conflict dependencies not tracked in `depends_on`

## Sources

- [Ralph Wiggum technique](https://ghuntley.com/ralph/) — Geoffrey Huntley
- [Anthropic: Effective Harnesses](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
- [Compound Engineering](https://every.to/chain-of-thought/compound-engineering-how-every-codes-with-agents)
- [ACE-FCA](https://github.com/humanlayer/advanced-context-engineering-for-coding-agents/blob/main/ace-fca.md)
