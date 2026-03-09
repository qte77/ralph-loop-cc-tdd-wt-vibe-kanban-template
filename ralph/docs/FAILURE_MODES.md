---
title: Ralph Known Failure Modes
scope: Teams mode cross-story interference — root cause analysis
status: 6 modes documented, recommended solutions identified
created: 2026-02-18
updated: 2026-03-08
---

<!-- markdownlint-disable MD013 -->

Root cause analysis from production log forensics. Stories implemented
correctly but Ralph rejected them repeatedly due to cross-story interference.

## 1. TDD commit counter doesn't survive reset (Sisyphean loop)

RED+GREEN commits made in iteration N pass TDD but fail complexity. Ralph runs
`git reset --hard HEAD~N`, erasing them. In iteration N+1 the agent sees work already
exists in reflog/history, makes only a REFACTOR commit. `check_tdd_commits` searches
`git log --grep="[RED]" --grep="STORY-ID" --all-match` but reset commits are
gone from the log. Ralph rejects for missing RED+GREEN. Repeats until max retries.

**Root cause in code**: `ralph.sh` resets commits on TDD failure and on quality
failure. Neither persists which TDD phases passed. The `RETRY_CONTEXT_FILE` only
works for quality retries after TDD already passed — not for TDD failures that
require re-verification.

**Solutions (pick one):**

- **A. Persist verified phases to state file** (recommended): After
  `check_tdd_commits` passes but quality fails, write `RED=<hash> GREEN=<hash>`
  to a temp file. On retry, skip phase requirements already satisfied.

  ```bash
  # In quality-failure handler:
  echo "RED=$red_commit GREEN=$green_commit" > "/tmp/claude/ralph_tdd_verified_${story_id}"

  # In check_tdd_commits:
  local verified_file="/tmp/claude/ralph_tdd_verified_${story_id}"
  if [ -f "$verified_file" ]; then
      log_info "Prior TDD phases verified — accepting REFACTOR-only"
      return 0
  fi
  ```

- **B. Don't reset on quality failure** (simpler, less clean): Keep the commits when
  only complexity/tests fail. Append retry context. Agent adds a REFACTOR commit on top.
  Quality re-runs on the full stack. Avoids the reset-then-redo cycle entirely.

- **C. Cherry-pick surviving commits**: After reset, if prior RED+GREEN are in reflog,
  `git cherry-pick` them back before re-running quality. More fragile (merge conflicts).

## 2. Teams mode cross-contamination

When Ralph delegates multiple stories in one batch, the agent combines work across
stories. `check_tdd_commits` filters by `grep "$story_id"` but if the agent makes a
single commit covering multiple stories, or uses a different story ID in the message,
the filter finds nothing.

**Root cause in code**: Simple grep on commit messages. A commit like
`feat(STORY-009,STORY-010): implement features [GREEN]` matches both stories, while
`feat: implement paper selection and settings [GREEN]` matches neither.

**Solutions (pick one):**

- **A. File-scoped commit attribution** (recommended): Check which files each commit
  touches against the story's `files` array from prd.json.

  ```bash
  story_files=$(jq -r ".stories[] | select(.id==\"$story_id\") | .files[]" "$PRD_FILE")
  story_commits=""
  for commit in $(git log --format="%h" -n $new_commits); do
      changed=$(git diff-tree --no-commit-id --name-only -r "$commit")
      if echo "$changed" | grep -qFf <(echo "$story_files"); then
          story_commits="$story_commits $commit"
      fi
  done
  ```

- **B. Sequential execution with shared baseline**: Don't batch stories. Execute one at
  a time. Slower but eliminates cross-contamination entirely. Use `TEAMS=false`.

- **C. Require story-scoped commits in prompt**: Fragile (depends on agent compliance)
  but zero harness changes.

## 3. Complexity gate catches cross-story changes

One story's complexity increase fails another story's quality gate.
`run_quality_checks` runs `make complexity` against the entire `src/` tree, not just
story-scoped files.

**Root cause in code**: `baseline.sh` compares test results before/after but the
complexity check has no baseline — it's a global pass/fail on the whole codebase.

**Solutions (pick one):**

- **A. Complexity baseline with delta scoping** (recommended): Before story execution,
  snapshot complexity results per function. After execution, only fail if functions in
  the story's `files` list have increased complexity. Cross-story increases are
  permitted (they'll be caught when that story is verified).

  ```bash
  # Capture complexity baseline:
  make complexity 2>&1 | grep "FAILED" > "/tmp/claude/ralph_complexity_baseline_${story_id}"

  # After execution, diff:
  make complexity 2>&1 | grep "FAILED" > "/tmp/claude/ralph_complexity_after"
  new_failures=$(comm -13 "$baseline" "$after" | grep -F "$story_files")
  ```

- **B. Per-file complexity check**: Run complexipy only on files changed by the current
  story's commits: `complexipy $(git diff --name-only HEAD~N) --max-complexity 10`.

- **C. Complexity allowlist in prd.json**: Optional `complexity_exceptions` field per
  story. Heavy-handed but explicit.

## 4. Stale snapshot tests from other stories

In teams mode, new failures from other stories in the same batch appear as regressions
for the current story. `baseline.sh` captures failing tests BEFORE the batch, so new
failures from other stories appear as regressions introduced by the current story.

**Root cause in code**: `capture_test_baseline` runs once per story start, but in teams
mode all stories share the same codebase state. Story A's baseline doesn't account for
story B's changes that were applied in the same batch.

**Solutions (pick one):**

- **A. Rolling baseline per story** (recommended): After each story's commits are
  verified and kept, re-capture the baseline before verifying the next story.

  ```bash
  # After successful story completion:
  capture_test_baseline "$BASELINE_FILE" "post-${story_id}"
  ```

- **B. Test-to-source mapping**: Map each failing test to the source files it imports.
  Only flag a failure as a regression if it imports a file from the current story's
  `files` list. Requires parsing Python imports (brittle) or using a naming convention.

- **C. Accept known cross-story failures**: After detecting new failures, check if those
  failures exist in ANY story's test file list from the batch. Only block on truly
  orphaned regressions.

## 5. File-conflict dependencies not tracked

`depends_on` tracks logical dependencies but not file-overlap conflicts. In teams mode,
two unrelated stories editing the same file produce merge conflicts or silently
overwrite each other's changes.

**Root cause in code**: `get_unblocked_stories` checks only `depends_on` — it has no
file-overlap awareness. Two stories with `depends_on: []` and overlapping `files`
arrays both appear unblocked and get delegated to different teammates.

**Solutions (pick one):**

- **A. File-conflict deps in prd.json** (recommended): Add file-overlap dependencies
  during PRD generation. `generate_prd_json.py` can detect overlapping `files` arrays
  and auto-inject `depends_on` edges. These deps are only needed for teams mode —
  sequential mode ignores them harmlessly.

- **B. Runtime file-lock check**: Before delegating a story, check if any in-progress
  story shares files. Skip overlapping stories until the conflicting story completes.

## 6. Incomplete PRD file lists

Stories passed quality checks but left stale tests because the PRD `files` arrays
missed secondary consumers of renamed interfaces. All failures were from tests
*outside* the story's scope.

**Mitigations implemented:**

- Impact scan prompt instruction: agent greps test tree for old symbol names before
  implementation
- Wave checkpoint: full `make validate` runs at wave boundaries to catch cross-story
  breakage
- Killed-process detection: exit 137/143 is a hard failure, not a silent pass
- Scoped ruff/tests: teams mode only checks story files, preventing cross-story false
  positives
- Pycache cleanup: removes stale `.pyc` files before test runs

## Key Structural Issue

The fundamental problem is **cross-story interference in teams mode**: quality gates for
story X catch regressions introduced by stories Y and Z. The validation checks the
entire test suite against a baseline that predates all stories in the batch.

**Recommended combined approach**: Implement solutions 1A + 2A + 3B + 4A + 5A. This gives:

- Phase persistence across resets (1A) — eliminates Sisyphean loops
- File-scoped commit attribution (2A) — correct story ownership
- Per-file complexity (3B) — scoped complexity checks
- Rolling baseline (4A) — simplest baseline fix
- File-conflict deps in prd.json (5A) — prevents parallel edits to same file

All five are backward-compatible with single-story mode (`TEAMS=false`).
