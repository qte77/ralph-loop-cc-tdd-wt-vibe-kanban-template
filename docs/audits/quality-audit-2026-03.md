---
title: Ralph Template Quality Audit
scope: ralph/scripts/ — all bash scripts and Python utilities
created: 2026-03-13
auditor: Claude Code (automated)
dimensions: DRY, KISS, YAGNI, Rigor, Coherence, Clarity, Simplicity
findings: 40
severity_breakdown: { high: 9, medium: 19, low: 12 }
---

# Ralph Template Quality Audit — March 2026

## Executive Summary

Audit of `ralph/scripts/` (25 files, ~5,300 lines) against core engineering
principles (KISS, DRY, YAGNI, Rigor, Coherence). Found **40 findings**: 9 High,
19 Medium, 12 Low. The 9 High findings include 1 bug (wrong function arguments
in teams mode), 2 name collisions, 1 copy-pasted prompt block, and 5 code
quality issues.

No security findings are included — those are tracked separately in the
[CLI rewrite research](../research/ralph-cli-rewrite.md) (eval injection,
JSON injection).

## Methodology

Each finding is tagged with:
- **ID**: `{Dimension initial}{sequence}` (e.g., D1 = DRY finding #1)
- **Severity**: High / Medium / Low
- **Dimension**: DRY, KISS, YAGNI, Rigor, Coherence, Clarity, Simplicity
- **Location**: `file:line` reference
- **Suggested fix**: Actionable remediation

---

## High Severity Findings

### D3: BUG — Scoped functions called with wrong arguments in teams mode

- **Dimension**: DRY (interface contract)
- **Location**: `teams.sh:227-238`
- **Description**: `verify_teammate_stories()` calls `run_ruff_scoped "$sid" "$PRD_JSON"`,
  `run_complexity_scoped "$sid" "$PRD_JSON"`, and `run_tests_scoped "$sid" "$PRD_JSON"`.
  But these functions in `baseline.sh:162,188,206` expect a **git commit hash** as
  `$1` (used in `git diff --name-only "$base_commit" HEAD`), not a story ID.
  Passing a story ID like `"STORY-003"` to `git diff --name-only` silently fails
  (git can't resolve it as a commit), returning no changed files, so the scoped
  checks skip everything and return success. **Teams mode quality checks are
  silently no-ops.**
- **Impact**: Stories pass teammate verification without any lint, complexity, or
  test checks.
- **Suggested fix**: Call `get_story_base_commit "$sid"` first, then pass the
  resulting commit hash to the scoped functions:
  ```bash
  local base=$(get_story_base_commit "$sid")
  run_ruff_scoped "$base"
  run_complexity_scoped "$base"
  run_tests_scoped "$base"
  ```

### D1: Two functions named `verify_teammate_stories` with different semantics

- **Dimension**: DRY (naming collision)
- **Location**: `ralph.sh:225` vs `teams.sh:195`
- **Description**: Both files define `verify_teammate_stories()`. In `ralph.sh` it
  takes `(story_id, base_commit)` and checks that only the current story's entries
  were modified in prd.json. In `teams.sh` it takes `(primary_id, commits_before,
  teammate_stories)` and runs TDD + scoped quality checks on all teammate stories.
  Since `ralph.sh` sources `teams.sh`, whichever is sourced last silently
  overwrites the other. The `ralph.sh` version is effectively dead code.
- **Impact**: Confusing for maintainers; the prd.json isolation check is silently
  disabled when teams.sh is sourced.
- **Suggested fix**: Rename `ralph.sh:225` to `verify_prd_isolation()` (which
  describes what it actually does).

### D2: Prompt construction block copy-pasted between execute and fix

- **Dimension**: DRY (code duplication)
- **Location**: `ralph.sh:289-322` vs `ralph.sh:396-437`
- **Description**: The ~30-line prompt construction block (story details, learnings
  injection, requests injection, steering instruction) is duplicated between
  `execute_story()` and `fix_validation_errors()`. The only difference is the fix
  version appends a "VALIDATION ERRORS TO FIX" section.
- **Impact**: Any change to prompt structure (e.g., adding a new context section)
  must be made in two places.
- **Suggested fix**: Extract a `build_story_prompt()` function that takes
  `story_id`, `details`, and an optional `error_log` path. Returns the path to
  the assembled prompt file.

### R2: jq arg name collision and empty-dep edge case in get_next_story

- **Dimension**: Rigor (correctness)
- **Location**: `ralph.sh:179`
- **Description**: `jq -r --arg id "$dep"` reuses the name `id` for the dependency
  variable, shadowing the outer `--arg id "$story_id"` from the same pipeline.
  Additionally, when `$deps` is empty (story has no dependencies), the `for dep in
  $deps` loop doesn't execute, so `deps_met` stays `true` — which is correct
  behavior, but fragile: if the jq query ever returns a single empty string
  instead of no output, the loop would execute once with `dep=""`, and
  `jq --arg id ""` would match no story, returning empty status, causing `deps_met`
  to become false and incorrectly blocking the story.
- **Impact**: Currently works by accident. A minor jq output format change could
  break dependency resolution.
- **Suggested fix**: Use `--arg dep_id "$dep"` to avoid shadowing. Add `[ -z "$dep" ] && continue` guard.

### K1: O(stories x deps) subprocess spawning in get_next_story

- **Dimension**: KISS (unnecessary complexity)
- **Location**: `ralph.sh:167-196`
- **Description**: `get_next_story()` spawns one `jq` subprocess per incomplete
  story to get dependencies, then one `jq` subprocess per dependency to check its
  status. For 20 stories with 3 deps each, that's up to 80 jq invocations.
  `teams.sh:15-25` already solves this with a single jq invocation using
  `--argjson completed` and set subtraction.
- **Impact**: Slow startup on large PRDs; inconsistent patterns between files.
- **Suggested fix**: Replace with the single-jq pattern from `teams.sh:get_unblocked_stories()`,
  then take the first result.

### K2: Double validation — quick then full on intermediate fix attempts

- **Dimension**: KISS (redundant work)
- **Location**: `ralph.sh:447-455`
- **Description**: On intermediate fix attempts (not the last), the code runs
  `make validate_quick` and if it passes, immediately runs `run_quality_checks`
  (full validation). This means lint + type-check runs twice in succession.
- **Impact**: Wasted time on every intermediate fix attempt that passes quick
  validation.
- **Suggested fix**: If quick validation passes on an intermediate attempt, skip
  directly to the next iteration. Run full validation only on the final attempt.

### Y1: Dead code — log_cc* family has zero call sites

- **Dimension**: YAGNI (dead code)
- **Location**: `common.sh:71-85`
- **Description**: Four functions (`log_cc`, `log_cc_warn`, `log_cc_error`,
  `log_cc_success`) are defined but never called anywhere in the codebase.
  They were likely intended for the CC monitor log feature (which uses
  `echo -e` directly instead).
- **Impact**: 15 lines of dead code; misleading documentation (comment says
  "Used when relaying agent log lines" but nothing uses them).
- **Suggested fix**: Delete all four functions and their section comment.

### C1: Scoped function interface contract violated (same root cause as D3)

- **Dimension**: Coherence (interface contract)
- **Location**: `baseline.sh:162,188,206` (definitions) vs `teams.sh:227-238` (calls)
- **Description**: `baseline.sh` documents `run_ruff_scoped`, `run_complexity_scoped`,
  and `run_tests_scoped` with usage comments like `Usage: run_ruff_scoped "$base_commit"`.
  The `run_quality_checks_baseline()` function in the same file calls them correctly
  with `get_story_base_commit()`. But `teams.sh:verify_teammate_stories()` calls
  them with a story ID, violating the documented interface.
- **Impact**: Same as D3 — silent no-op quality checks in teams mode.
- **Suggested fix**: Same fix as D3. Consider adding a guard at the top of each
  scoped function: `git rev-parse --verify "$1" 2>/dev/null || { log_error ".."; return 1; }`.

### C2: Debug logging bypasses log_* system

- **Dimension**: Coherence (logging)
- **Location**: `vibe.sh:112-133`
- **Description**: `kanban_update()` uses bare `echo "[DEBUG]"` statements (6
  instances) instead of the `log_*` functions from `common.sh`. These fire
  unconditionally (no debug flag check), polluting stderr with implementation
  details during normal operation.
- **Impact**: Noisy output; inconsistent log format; no way to silence debug
  output without editing the file.
- **Suggested fix**: Replace with `log_info` or gate behind `[ "$DEBUG" = "1" ]`.

---

## Medium Severity Findings

### D4: Stories-passed jq query repeated 8+ times with no helper

- **Dimension**: DRY (query duplication)
- **Location**: `ralph.sh:521,744,752`, `parallel_ralph.sh:334,437,543`, `teams.sh:16`
- **Description**: The jq expression `jq '[.stories[] | select(.status == "passed")] | length'`
  appears 8+ times across 3 files with no shared helper function.
- **Suggested fix**: Add `count_passed_stories()` to `common.sh`.

### D5: Prompt file assembly duplicated between execute and fix

- **Dimension**: DRY (duplication)
- **Location**: `ralph.sh:288-289` vs `ralph.sh:395-396`
- **Description**: Both `execute_story` and `fix_validation_errors` independently
  create a temp file, copy `$PROMPT_FILE` into it, then append story context.
  Subsumes D2.
- **Suggested fix**: Same as D2 — extract `build_story_prompt()`.

### D6: Coverage/ruff/pyright extraction functions tightly coupled to log format

- **Dimension**: DRY (fragile coupling)
- **Location**: `parallel_ralph.sh:277-305`
- **Description**: Four extract functions (`extract_coverage`, `extract_ruff_violations`,
  `extract_pyright_errors`, `extract_pyright_warnings`) each grep a specific log
  format. If any tool changes its output format, the extraction silently returns 0.
- **Suggested fix**: Add format validation (warn if expected pattern not found vs.
  returning 0).

### R1: MAX_WORKTREES hardcoded in parallel_ralph.sh, not in config.sh

- **Dimension**: Rigor (configuration)
- **Location**: `parallel_ralph.sh:76`
- **Description**: `MAX_WORKTREES=10` is hardcoded in `parallel_ralph.sh` while all
  other configuration lives in `config.sh`. The validation at line 694 also
  hardcodes `10`.
- **Suggested fix**: Move to `config.sh` as `RALPH_MAX_WORKTREES=${RALPH_MAX_WORKTREES:-10}`.

### R3: count_validation_errors fragile parsing

- **Dimension**: Rigor (parsing)
- **Location**: `ralph.sh:86-102`
- **Description**: `count_validation_errors` greps for pyright and pytest patterns.
  The pyright regex `^[0-9]+ errors` expects the count at line start, but pyright
  output may have leading whitespace. The pytest regex `^FAILED |pytest.*failed`
  mixes two patterns that could double-count.
- **Suggested fix**: Use more precise patterns; test against actual tool output samples.

### R4: Git rev-list count assumes linear history

- **Dimension**: Rigor (correctness)
- **Location**: `ralph.sh:537`
- **Description**: `git rev-list --count HEAD` counts all ancestors, not just
  commits on the current branch. After a merge, `commits_after - commits_before`
  may include merge-parent commits not made during story execution.
- **Suggested fix**: Use `git log --oneline $base_commit..HEAD | wc -l` for
  accurate per-branch counting.

### R5: JSON payloads via string concatenation — injection risk

- **Dimension**: Rigor (security)
- **Location**: `vibe.sh:158-175`
- **Description**: `kanban_update()` builds JSON via string concatenation with
  `sed`-based escaping. The `sed` only escapes double quotes but misses
  backslashes, newlines, and other JSON-special characters. A story title or
  reason containing `\n` or `\t` produces invalid JSON.
- **Suggested fix**: Use `jq --arg` for all user-controlled values (same pattern
  already used in `kanban_init` at line 74).

### R6: Temp file leaked on early exit

- **Dimension**: Rigor (resource management)
- **Location**: `ralph.sh:288,395`
- **Description**: `iteration_prompt=$(mktemp)` and `fix_prompt=$(mktemp)` are
  created but only cleaned up on the happy path (`rm "$iteration_prompt"`). If
  the function exits early (e.g., signal, `set -e` trigger), the temp file leaks.
- **Suggested fix**: Add `trap "rm -f '$iteration_prompt'" RETURN` after mktemp.

### R7: WORKTREE_EXIT_CODES always 0

- **Dimension**: Rigor (correctness)
- **Location**: `parallel_ralph.sh:263`
- **Description**: After `disown`, the actual exit code of the background process
  is not recoverable. `WORKTREE_EXIT_CODES[$i]=0` is hardcoded, so `score_worktree`
  always gives the 50-point `validation_bonus`. This is documented in the CLI
  rewrite research as a known bug.
- **Suggested fix**: Write exit code to a file from the subshell:
  `(cd ... && ralph.sh ...; echo $? > exit_code.txt) &`.

### C3: `kanban_init` uses jq for payload, `kanban_update` uses string concat

- **Dimension**: Coherence (inconsistency)
- **Location**: `vibe.sh:74` (jq) vs `vibe.sh:158` (string concat)
- **Description**: Two functions in the same file use different JSON construction
  methods. `kanban_init` correctly uses `jq -n --arg` for safe serialization.
  `kanban_update` uses string concatenation, which is the source of R5.
- **Suggested fix**: Convert `kanban_update` to use `jq --arg` (same as `kanban_init`).

### C4: get_next_story and get_unblocked_stories solve the same problem differently

- **Dimension**: Coherence (duplication)
- **Location**: `ralph.sh:167` vs `teams.sh:15`
- **Description**: Both functions find stories whose dependencies are satisfied.
  `get_next_story` returns the first one (serial mode), `get_unblocked_stories`
  returns all (teams mode). They use completely different algorithms (O(n*d) loops
  vs single jq query).
- **Suggested fix**: Implement `get_unblocked_stories` once (the efficient version),
  then define `get_next_story() { get_unblocked_stories | head -1; }`.

### C5: Source order dependency not enforced

- **Dimension**: Coherence (fragility)
- **Location**: `teams.sh:9` (comment), `ralph.sh:34-44` (source statements)
- **Description**: `teams.sh` header says "Source order: common.sh -> baseline.sh -> teams.sh"
  but `ralph.sh` sources `common.sh`, `config.sh`, `validate_json.sh`,
  `generate_app_docs.sh`, `vibe.sh` — and never sources `baseline.sh` or `teams.sh`.
  Only `parallel_ralph.sh` sources `baseline.sh` and `teams.sh`. The dependency
  chain is implicit and undocumented in the sourcing files.
- **Suggested fix**: Add a guard at the top of `teams.sh`:
  `type get_story_base_commit &>/dev/null || { echo "Error: source baseline.sh before teams.sh"; exit 1; }`.

### CL1: parallel_ralph.sh main() is 162 lines with dual responsibility

- **Dimension**: Clarity (function size)
- **Location**: `parallel_ralph.sh:688-850`
- **Description**: `main()` handles both resume detection (lines 688-757) and fresh
  start (lines 758-850). These are two distinct workflows mixed together.
- **Suggested fix**: Extract `resume_worktrees()` and `create_fresh_worktrees()`
  helper functions.

### CL2: Variable shadowing — local N_WT and MAX_ITERATIONS in main()

- **Dimension**: Clarity (scoping)
- **Location**: `parallel_ralph.sh:690-691`
- **Description**: `local N_WT=...` and `local MAX_ITERATIONS=...` shadow the
  global-scope variables used by other functions (e.g., `wait_and_monitor` references
  `$N_WT` without it being passed as a parameter). The locals are visible inside
  functions called from `main()` due to bash dynamic scoping, but this is
  confusing and fragile.
- **Suggested fix**: Remove `local` — these should be module-level variables set
  once in `main()` and used globally (which is how they're already used).

### CL3: Glob `tests/*.py` misses nested test directories

- **Dimension**: Clarity (correctness)
- **Location**: `baseline.sh:210,213`
- **Description**: `run_tests_scoped` uses `git diff --name-only ... -- 'tests/*.py'`
  which only matches files directly in `tests/`, not `tests/subdir/test_foo.py`.
- **Suggested fix**: Use `'tests/**/*.py'` or `'tests/'` (git pathspec supports
  recursive matching by default for directory paths).

### CL4: find_worktree_by_index uses pipe-into-while (subshell)

- **Dimension**: Clarity (fragility)
- **Location**: `parallel_ralph.sh:140-152`
- **Description**: `echo "$worktrees" | while read -r path; do ... done` runs in
  a subshell. The `echo "$path" && break` pattern works because it writes to stdout,
  but any variable assignment inside the loop would be lost.
- **Suggested fix**: Use `while ... done <<< "$worktrees"` for clarity and
  consistency with the project's own AGENT_LEARNINGS.md.

### S1: Config aliases in ralph.sh add no value

- **Dimension**: Simplicity (unnecessary indirection)
- **Location**: `ralph.sh:53-66`
- **Description**: 14 local aliases (`PRD_JSON`, `PROGRESS_FILE`, `DEFAULT_MODEL`,
  etc.) simply copy values from `RALPH_*` config variables. These add a layer of
  indirection without shortening names significantly or adding type safety.
- **Suggested fix**: Use `RALPH_*` names directly. The 16 references to `PRD_JSON`
  become `RALPH_PRD_JSON` — longer but unambiguous.

### S2: classify_story regex patterns are config vars but behave as constants

- **Dimension**: Simplicity (over-configurability)
- **Location**: `config.sh:80-84`, `ralph.sh:106-125`
- **Description**: `RALPH_SIMPLE_PATTERNS` and `RALPH_DOCS_PATTERNS` are defined in
  config.sh as if they're user-configurable, but changing them would break the
  model routing logic. They're implementation details, not configuration.
- **Suggested fix**: Define as local constants in `classify_story()` or mark with
  a comment "# Internal — do not override".

### S3: init.sh hardcodes chmod on 12 individual files

- **Dimension**: Simplicity (maintenance burden)
- **Location**: `init.sh:230-241`
- **Description**: `make_executable()` lists 12 files individually with `chmod +x`.
  Adding a new script requires editing this list.
- **Suggested fix**: `chmod +x ralph/scripts/*.sh ralph/scripts/lib/*.sh ralph/scripts/*.py 2>/dev/null || true`

---

## Low Severity Findings

### D7: `total`/`passing` jq queries at end of ralph.sh are duplicated

- **Location**: `ralph.sh:743-744` vs `ralph.sh:752-753`
- **Description**: Same two jq calls for total and passing stories appear twice
  within 10 lines — once inside the commit block and once for the summary.
- **Suggested fix**: Compute once, reuse.

### D8: `git log --format="%H" --grep=...` pattern repeated in baseline.sh

- **Location**: `baseline.sh:32,36`
- **Description**: Two similar grep-based git log queries with the same format string.
- **Suggested fix**: Minor; could extract but low impact.

### K3: escape_sed function unused after vibe.sh moved to jq

- **Location**: `common.sh:111-113`
- **Description**: `escape_sed()` is defined but grep finds no call sites.
- **Suggested fix**: Verify no usage and delete.

### K4: Legacy guard for "passes" field

- **Location**: `ralph.sh:600-603`
- **Description**: Checks for a legacy `passes` boolean field that was removed in
  an earlier version. If no legacy prd.json files exist, this is dead code.
- **Suggested fix**: Remove after confirming no consumers use the old schema.

### Y2: setup_project.sh and generate_app_docs.sh are template-specific

- **Location**: `ralph/scripts/setup_project.sh`, `ralph/scripts/lib/generate_app_docs.sh`
- **Description**: These files generate Python-specific scaffolding (README.md,
  example.py). They're useful for the template but won't apply to non-Python
  projects (Go, TypeScript targets in the CLI rewrite).
- **Suggested fix**: Document as Python-specific; plan for language adapter system.

### Y3: ARCHIVE_PREFIX in config.sh assumes project name

- **Location**: `config.sh:32`
- **Description**: `ARCHIVE_PREFIX="your_project_name_ralph_run"` hardcodes a
  placeholder that must be manually edited.
- **Suggested fix**: Derive from `SRC_PACKAGE_DIR`: `ARCHIVE_PREFIX="${SRC_PACKAGE_DIR}_ralph_run"`.

### R8: Unquoted variable expansion in log rotation

- **Location**: `ralph.sh:74`
- **Description**: `rm -f $old_logs` — if any log filename contains spaces, this
  breaks. Unlikely but technically a bug.
- **Suggested fix**: Use `xargs rm -f` or quote properly.

### R9: `grep -oP` used in parallel_ralph.sh (macOS incompatible)

- **Location**: `parallel_ralph.sh:728`
- **Description**: `grep -oP '(?<=-ralph-wt-)[a-z0-9]+(?=(-[0-9]+)?$)'` uses PCRE
  lookbehind, unavailable on macOS default grep.
- **Suggested fix**: Use `sed` or `grep -oE` with a simpler pattern.

### C6: RALPH_LOG_DIR set to /tmp in config but RALPH_TMP_DIR also /tmp/ralph

- **Location**: `config.sh:70,125`
- **Description**: Two overlapping temp directories. `RALPH_LOG_DIR="/tmp"` and
  `RALPH_TMP_DIR="/tmp/ralph"`. Log files go to `/tmp/ralph_logs/` while runtime
  files go to `/tmp/ralph/`. The separation is unclear.
- **Suggested fix**: Consolidate under `RALPH_TMP_DIR`.

### CL5: generate_run_id uses md5sum of timestamp

- **Location**: `parallel_ralph.sh:98-99`
- **Description**: `date +%s%N | md5sum | cut -c1-6` — piping nanoseconds through
  md5sum is overkill for a 6-char ID. `head -c6 /dev/urandom | xxd -p` or
  `$(date +%s | tail -c7)` would be simpler.
- **Suggested fix**: Simplify; low priority.

### S4: check_prerequisites repeats the same pattern 4 times

- **Location**: `init.sh:21-63`
- **Description**: Four nearly identical `if ! command -v X; then log_error; missing=1; else log_success; fi` blocks.
- **Suggested fix**: Loop over an array: `for cmd in claude jq git make; do ... done`.

### S5: fmt_elapsed could use printf arithmetic

- **Location**: `common.sh:33-42`
- **Description**: The `if/else` for minutes > 0 could be a single printf.
- **Suggested fix**: Minor; cosmetic.

---

## Summary by Dimension

| Dimension | High | Medium | Low | Total |
|-----------|------|--------|-----|-------|
| DRY | 3 | 3 | 2 | 8 |
| KISS | 2 | 0 | 2 | 4 |
| YAGNI | 1 | 0 | 2 | 3 |
| Rigor | 1 | 5 | 2 | 8 |
| Coherence | 2 | 3 | 1 | 6 |
| Clarity | 0 | 4 | 1 | 5 |
| Simplicity | 0 | 4 | 2 | 6 |
| **Total** | **9** | **19** | **12** | **40** |

## Priority Remediation Order

1. **D3/C1** (BUG): Fix scoped function arguments in `teams.sh:verify_teammate_stories` — teams mode quality checks are no-ops
2. **D1**: Rename `ralph.sh:verify_teammate_stories` to `verify_prd_isolation` — name collision
3. **R5/C3**: Convert `kanban_update` to use `jq --arg` — JSON injection risk
4. **D2**: Extract `build_story_prompt()` — reduces 60 lines to 1 call site each
5. **K1/C4**: Replace `get_next_story` with `get_unblocked_stories | head -1` — consistency + performance
6. **Y1**: Delete dead `log_cc*` functions
7. **C2**: Replace `echo "[DEBUG]"` with gated `log_info` calls

## References

- Source files: `ralph/scripts/` (all 25 files)
- Related: [CLI rewrite research](../research/ralph-cli-rewrite.md) (security bugs, rewrite rationale)
- Related: [ralph/TODO.md](../../ralph/TODO.md) (backlog items from this audit)
