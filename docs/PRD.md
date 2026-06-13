---
title: "Ralph Bug-Fix + Self-Evolving Loop Sprint"
created: 2026-03-25
status: in-progress
stories: 14
approach: "BATS TDD — strictly bash/shell, no Go rewrite"
source: "ralph/TODO.md + docs/audits/quality-audit-2026-03.md"
---

# Product Requirements Document: Ralph Bug-Fix + Self-Evolving Loop Sprint

## Project Overview

Fix 8 confirmed bugs from the quality audit using strict BATS test-driven development,
then add 4 self-evolving feedback mechanisms that enable ralph to learn from its own
execution history. All work is bash + BATS — the Go CLI rewrite is deferred to backlog.

## User Stories Reference

- Bug fixes: `ralph/TODO.md` Backlog section (8 bugs from `docs/audits/quality-audit-2026-03.md`)
- Self-evolving mechanisms: Plan file `fancy-jingling-hinton.md` (M1-M4)
- TDD approach: `ralph/scripts/tests/test_helper/common-setup.bash` (BATS infrastructure)

## Functional Requirements

### Wave 1 — Foundation

#### Feature 1: BATS Test Infrastructure Scaffold

**Description**: Set up BATS test framework for Ralph script testing. Create test directory structure, shared test helpers (setup/teardown with tmp dirs, mock claude binary, mock prd.json fixtures), and a Makefile recipe.

**Acceptance Criteria**:

- [ ] BATS installed and runnable: `bats --version` succeeds
- [ ] `ralph/scripts/tests/` contains `test_helper/` with `common-setup.bash`
- [ ] `common-setup.bash` creates isolated tmp dir per test, exports `RALPH_TMP_DIR`, stubs `claude` binary
- [ ] `common-setup.bash` provides `create_mock_prd()` helper for minimal valid prd.json
- [ ] `common-setup.bash` sets `git config user.name/email` for tests that create commits
- [ ] Makefile recipe `test_bats` runs `bats ralph/scripts/tests/` with TAP output
- [ ] Existing `test_parallel_ralph.sh` is NOT deleted
- [ ] At least one smoke test passes: `test_common_sh_sources_without_error`

**Files**:

- `ralph/scripts/tests/test_helper/common-setup.bash` (new)
- `ralph/scripts/tests/test_scaffold.bats` (new)
- `Makefile` (edit)

### Wave 2 — Critical and High Bug Fixes

#### Feature 2: Fix eval Injection in execute_story and fix_validation_errors

**Description**: CRITICAL SECURITY. `ralph.sh:330` and `ralph.sh:445` use `eval` to expand `$extra_flags` in `claude -p` invocations. If any `RALPH_*` env var contains shell metacharacters, arbitrary commands execute. Replace `eval` with safe array expansion.

**Acceptance Criteria**:

- [ ] [RED] BATS test `test_eval_injection.bats` asserts metacharacters in env vars are NOT executed
- [ ] [GREEN] `execute_story()` replaces `eval` with safe array expansion via `read -ra flags_array`
- [ ] [GREEN] `fix_validation_errors()` applies the same safe array expansion pattern
- [ ] All existing functionality preserved: RALPH_DESLOPIFY, RALPH_MODEL, teams flags still work

**Files**:

- `ralph/scripts/tests/test_eval_injection.bats` (new)
- `ralph/scripts/ralph.sh` (edit)

**Technical Requirements**:

- Use `local -a flags_array; read -ra flags_array <<< "$extra_flags"` pattern
- `build_claude_extra_flags()` returns space-separated string (no metacharacters needed)

#### Feature 3: Fix exit 0 Masking Worker Failures

**Description**: HIGH. `parallel_ralph.sh:264` hardcodes `WORKTREE_EXIT_CODES[$i]=0` for all completed disowned processes. Parallel runs always report success even when workers fail. Fix by using a sentinel file written by the worker subshell.

**Acceptance Criteria**:

- [ ] [RED] BATS test `test_parallel_exit_codes.bats` asserts non-zero exit codes are captured
- [ ] [GREEN] Worker subshell writes exit code to `$worktree_path/.ralph-exit-code`
- [ ] [GREEN] `wait_and_monitor()` reads sentinel file instead of hardcoding 0
- [ ] [GREEN] Missing sentinel file defaults to exit code 137 (SIGKILL)
- [ ] Final summary correctly reports failed worktrees

**Files**:

- `ralph/scripts/tests/test_parallel_exit_codes.bats` (new)
- `ralph/scripts/parallel_ralph.sh` (edit)

#### Feature 4: Rename verify_teammate_stories Collision

**Description**: HIGH. `ralph.sh:226` and `teams.sh:195` both define `verify_teammate_stories()` with completely different semantics. Whichever is sourced last wins silently.

**Acceptance Criteria**:

- [ ] [RED] BATS test `test_name_collision.bats` asserts both function names resolve correctly
- [ ] [GREEN] `ralph.sh:226` renamed from `verify_teammate_stories` to `verify_prd_isolation`
- [ ] [GREEN] All call sites in ralph.sh updated
- [ ] teams.sh `verify_teammate_stories` unchanged

**Files**:

- `ralph/scripts/tests/test_name_collision.bats` (new)
- `ralph/scripts/ralph.sh` (edit)

#### Feature 6: Fix kanban_update JSON Injection

**Description**: MEDIUM. `vibe.sh:158-175` builds JSON with string concatenation and sed-only escaping. `kanban_init` in the same file already uses `jq --arg` correctly.

**Acceptance Criteria**:

- [ ] [RED] BATS test `test_vibe_json.bats` asserts special characters produce valid JSON
- [ ] [GREEN] `kanban_update()` replaced with `jq -n --arg` construction
- [ ] [GREEN] `sed` escaping removed
- [ ] Payload structure unchanged

**Files**:

- `ralph/scripts/tests/test_vibe_json.bats` (new)
- `ralph/scripts/lib/vibe.sh` (edit)

#### Feature 7: Replace get_next_story O(n*d) Loop

**Description**: MEDIUM. `ralph.sh:168` spawns one jq per story plus one per dependency. `teams.sh` already solves this with `get_unblocked_stories` (single jq query).

**Acceptance Criteria**:

- [ ] [RED] BATS test `test_story_scheduling.bats` asserts correct story returned from dependency chain
- [ ] [GREEN] `get_next_story()` body replaced with `get_unblocked_stories | head -1`
- [ ] Dependency resolution correctness preserved

**Files**:

- `ralph/scripts/tests/test_story_scheduling.bats` (new)
- `ralph/scripts/ralph.sh` (edit)

#### Feature 8: Fix Double Validation on Intermediate Fix Attempts

**Description**: MEDIUM. `ralph.sh:449-458` runs quick validation then immediately runs full validation on success. Lint and type-check execute twice on intermediate attempts.

**Acceptance Criteria**:

- [ ] [RED] BATS test `test_fix_validation.bats` asserts `run_quality_checks` NOT called after quick passes
- [ ] [GREEN] When `attempt < max_attempts` and quick passes, return 0 without full validation
- [ ] [GREEN] Final attempt still runs full `run_quality_checks`

**Files**:

- `ralph/scripts/tests/test_fix_validation.bats` (new)
- `ralph/scripts/ralph.sh` (edit)

#### Feature 9: Delete Dead Code and Fix Unconditional Debug Echo

**Description**: LOW. `common.sh:71-85` defines 4 `log_cc*` functions with zero call sites. `vibe.sh` has 6 bare `echo "[DEBUG]"` statements that fire unconditionally.

**Acceptance Criteria**:

- [ ] [RED] BATS test `test_logging_cleanup.bats` asserts `log_cc` is NOT defined and no unconditional debug output
- [ ] [GREEN] `log_cc*` functions deleted from `common.sh:71-85`
- [ ] [GREEN] Bare debug echos replaced with `[ "${DEBUG:-}" = "1" ] && log_info` or deleted

**Files**:

- `ralph/scripts/tests/test_logging_cleanup.bats` (new)
- `ralph/scripts/lib/common.sh` (edit)
- `ralph/scripts/lib/vibe.sh` (edit)

### Wave 3 — Dependent Fix

#### Feature 5: Fix Scoped Checks Passing Story ID Instead of Commit Hash

**Description**: HIGH. `teams.sh:227-238` passes story ID to `run_ruff_scoped`/`run_complexity_scoped`/`run_tests_scoped`, but these functions expect a git commit hash. Scoped checks pass vacuously.

**Acceptance Criteria**:

- [ ] [RED] BATS test `test_scoped_checks.bats` asserts scoped check operates on changed files
- [ ] [GREEN] `verify_teammate_stories()` in teams.sh calls `get_story_base_commit` before scoped checks
- [ ] [GREEN] Scoped check functions receive a valid commit hash

**Files**:

- `ralph/scripts/tests/test_scoped_checks.bats` (new)
- `ralph/scripts/lib/teams.sh` (edit)

### Wave 4 — Refactor

#### Feature 10: Extract build_story_prompt to Deduplicate Execute and Fix

**Description**: LOW/REFACTOR. ~30-line prompt construction block is copy-pasted between `execute_story()` and `fix_validation_errors()`. Extract into `build_story_prompt()` function.

**Acceptance Criteria**:

- [ ] [RED] BATS test `test_prompt_construction.bats` asserts `build_story_prompt` produces expected sections
- [ ] [GREEN] New `build_story_prompt()` function in ralph.sh
- [ ] [GREEN] Both `execute_story()` and `fix_validation_errors()` call it
- [ ] Prompt content identical to pre-refactor output

**Files**:

- `ralph/scripts/tests/test_prompt_construction.bats` (new)
- `ralph/scripts/ralph.sh` (edit)

### Wave 5 — Self-Evolving Loop

#### Feature 11: Feed progress.txt into Story Prompts

**Description**: Close the feedback gap: inject recent run history into every story and fix prompt so the agent can see prior iteration outcomes and self-correct.

**Acceptance Criteria**:

- [ ] [RED] BATS test `test_progress_injection.bats` asserts prompt file contains "Recent Run History" section
- [ ] [GREEN] `execute_story()` injects `tail -50` of progress.txt after LEARNINGS injection
- [ ] [GREEN] `fix_validation_errors()` applies same injection
- [ ] Agent sees patterns like "STORY-003 failed 3x with same error"

**Files**:

- `ralph/scripts/tests/test_progress_injection.bats` (new)
- `ralph/scripts/ralph.sh` (edit)

**Technical Requirements**:

- Inject after LEARNINGS.md block, before INSTRUCTION block
- Use `tail -50` to limit context (~10 iterations at ~5 lines each)

#### Feature 12: LEARNINGS.md Update Check

**Description**: Enforce compound learning discipline by detecting when the agent skips writing to LEARNINGS.md after a story.

**Acceptance Criteria**:

- [ ] [RED] BATS test `test_learnings_check.bats` asserts warning emitted when LEARNINGS.md unchanged
- [ ] [GREEN] Hash LEARNINGS.md via `sha256sum` before and after `execute_story()`
- [ ] [GREEN] `log_warn` when hashes match (COMPOUND phase skipped)
- [ ] Warning surfaces in logs and feeds back via M1 into subsequent prompts

**Files**:

- `ralph/scripts/tests/test_learnings_check.bats` (new)
- `ralph/scripts/ralph.sh` (edit)

#### Feature 13: compress_progress Distillation

**Description**: The self-evolving mechanism. After every 3rd completed story, invoke a cheap `claude -p --model haiku` call to extract durable patterns from progress.txt into LEARNINGS.md. Combined with the compound learning promotion path (LEARNINGS -> rules -> skills), patterns discovered by ralph become permanent infrastructure.

**Acceptance Criteria**:

- [ ] [RED] BATS test `test_compress_progress.bats` asserts function skips when <3 stories completed
- [ ] [RED] BATS test asserts function triggers on exactly 3rd, 6th, 9th completion
- [ ] [GREEN] `compress_progress()` function reads progress.txt + LEARNINGS.md, invokes haiku
- [ ] [GREEN] Called at end of `main()` after the while loop
- [ ] Uses `|| true` to prevent blocking the main run on failure

**Files**:

- `ralph/scripts/tests/test_compress_progress.bats` (new)
- `ralph/scripts/ralph.sh` (edit)

**Technical Requirements**:

- Use `claude -p --model haiku --dangerously-skip-permissions`
- Guard with `[[ "$completed" -lt 3 ]] && return 0` and modulo check
- Log output to `$RALPH_TMP_DIR/compress_progress.log`

#### Feature 14: Remove TDD Ramp-Up Skip

**Description**: The generic "skip TDD for first story" bypass at `ralph.sh:523-527` masks real failures. STORY-000 foundation check already handles legitimate cases. Remove the bypass.

**Acceptance Criteria**:

- [ ] [RED] BATS test `test_tdd_skip_removal.bats` asserts TDD verification runs on first non-STORY-000 story
- [ ] [GREEN] 4-line bypass block deleted from `check_tdd_commits()`
- [ ] [GREEN] STORY-000 check remains unchanged
- [ ] Future first stories correctly fail TDD if no RED/GREEN commits exist

**Files**:

- `ralph/scripts/tests/test_tdd_skip_removal.bats` (new)
- `ralph/scripts/ralph.sh` (edit)

## Non-Functional Requirements

- All stories follow strict BATS TDD: [RED] test first, [GREEN] minimal fix, optional [REFACTOR]
- `make test_bats` must pass after each story
- `shellcheck ralph/scripts/**/*.sh` should pass (no new violations)
- No Go, Python, or other language dependencies for runtime (BATS + jq + bash only)

## Out of Scope

- Go CLI rewrite (deferred to backlog — see `docs/UserStory.md`)
- Vector memory or semantic search for LEARNINGS
- Per-run cost guardrails (`RALPH_COST_LIMIT`)
- Heavy observe/correct infrastructure
- Agent Teams parallel orchestration
- Vibe Kanban bi-directional sync

### Notes for Ralph Loop

### Story Breakdown (14 stories):

- **Feature 1** → STORY-001: Scaffold BATS test infrastructure
- **Feature 2** → STORY-002: Fix eval injection (depends: STORY-001)
- **Feature 3** → STORY-003: Fix exit 0 masking (depends: STORY-001)
- **Feature 4** → STORY-004: Rename verify_teammate_stories (depends: STORY-001)
- **Feature 5** → STORY-005: Fix scoped checks wrong arg (depends: STORY-001, STORY-004)
- **Feature 6** → STORY-006: Fix kanban_update JSON injection (depends: STORY-001)
- **Feature 7** → STORY-007: Replace get_next_story O(n*d) (depends: STORY-001)
- **Feature 8** → STORY-008: Fix double validation (depends: STORY-001)
- **Feature 9** → STORY-009: Delete dead code and fix debug echo (depends: STORY-001)
- **Feature 10** → STORY-010: Extract build_story_prompt (depends: STORY-002, STORY-008)
- **Feature 11** → STORY-011: Feed progress.txt into prompts (depends: STORY-001)
- **Feature 12** → STORY-012: Add LEARNINGS.md update check (depends: STORY-001)
- **Feature 13** → STORY-013: Add compress_progress distillation (depends: STORY-011, STORY-012)
- **Feature 14** → STORY-014: Remove TDD ramp-up skip (depends: STORY-001)
