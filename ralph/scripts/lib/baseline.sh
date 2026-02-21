#!/bin/bash
#
# Ralph Loop - Baseline-aware test validation
#
# Captures pre-existing test failures and only blocks progress on NEW
# failures (regressions). Prevents unrelated issues from blocking story
# advancement.
#
# Anti-contamination: Baseline is automatically refreshed after successful
# validation to prevent failures from leaking between stories.
#
# Anti-absorption: Baselines persist per-story, so restarting doesn't
# absorb a story's own prior failures into the baseline.
#
# Source this file after common.sh:
#   source "$SCRIPT_DIR/lib/common.sh"
#   source "$SCRIPT_DIR/lib/baseline.sh"

# =================================================
# Story Base Commit
# =================================================

# Get the commit hash from before the current story started.
# Used for scoped diffs (only check files changed by this story).
#
# Usage: base=$(get_story_base_commit "$story_id")
get_story_base_commit() {
  local story_id="$1"
  local base_commit=""

  # Look for the last state commit before this story
  base_commit=$(git log --format="%H" --grep="docs(${story_id}):" -1 2>/dev/null)

  if [ -z "$base_commit" ]; then
    # Fall back to the commit before any story work
    base_commit=$(git log --format="%H" --grep="\[RED\]\|\[GREEN\]\|\[REFACTOR\]" \
      --invert-grep -1 2>/dev/null)
  fi

  if [ -z "$base_commit" ]; then
    # Last resort: use HEAD~10 or root
    base_commit=$(git rev-parse HEAD~10 2>/dev/null || git rev-list --max-parents=0 HEAD)
  fi

  echo "$base_commit"
}

# =================================================
# Baseline Capture and Comparison
# =================================================

# Snapshot current failing tests to a baseline file.
# The baseline records test names that are already failing
# before the story starts, so they can be excluded from
# regression checks.
#
# Usage: capture_test_baseline "/tmp/ralph/baseline_STORY-001.txt" "pre-story"
capture_test_baseline() {
  local baseline_file="$1"
  local label="${2:-baseline}"

  local baseline_dir
  baseline_dir="$(dirname "$baseline_file")"
  mkdir -p "$baseline_dir"

  log_info "Capturing test baseline ($label) -> $baseline_file"

  # Run pytest in dry-fail mode: collect failures without stopping
  local test_output
  test_output=$(uv run pytest --tb=no -q 2>&1 || true)

  # Extract FAILED test names (pytest format: "FAILED tests/test_foo.py::test_bar")
  echo "$test_output" \
    | grep -E "^FAILED " \
    | sed 's/^FAILED //' \
    | sort \
    > "$baseline_file"

  local count
  count=$(wc -l < "$baseline_file" | tr -d ' ')
  log_info "Baseline captured: $count pre-existing failure(s)"
}

# Refresh baseline after successful validation to prevent
# failures from leaking between stories.
#
# Usage: refresh_baseline_on_success "$baseline_file" "$story_id"
refresh_baseline_on_success() {
  local baseline_file="$1"
  local story_id="$2"

  log_info "Refreshing baseline after successful $story_id validation"
  capture_test_baseline "$baseline_file" "post-${story_id}"
}

# Compare current test failures against the stored baseline.
# Returns 0 if no NEW failures (only pre-existing ones).
# Returns 1 if new regressions are detected.
#
# Usage: compare_test_failures "$baseline_file"
compare_test_failures() {
  local baseline_file="$1"
  local current_failures_file
  current_failures_file="$(mktemp)"

  # Capture current failures
  local test_output
  test_output=$(uv run pytest --tb=no -q 2>&1 || true)

  echo "$test_output" \
    | grep -E "^FAILED " \
    | sed 's/^FAILED //' \
    | sort \
    > "$current_failures_file"

  local current_count
  current_count=$(wc -l < "$current_failures_file" | tr -d ' ')

  # If no baseline exists, all failures are new
  if [ ! -f "$baseline_file" ]; then
    log_warn "No baseline file found — all $current_count failure(s) treated as new"
    rm -f "$current_failures_file"
    if [ "$current_count" -gt 0 ]; then
      return 1
    fi
    return 0
  fi

  # Find new failures (in current but not in baseline)
  local new_failures
  new_failures=$(comm -23 "$current_failures_file" "$baseline_file")
  rm -f "$current_failures_file"

  if [ -z "$new_failures" ]; then
    local baseline_count
    baseline_count=$(wc -l < "$baseline_file" | tr -d ' ')
    if [ "$current_count" -gt 0 ]; then
      log_info "All $current_count failure(s) are pre-existing (baseline: $baseline_count)"
    else
      log_success "All tests passing"
    fi
    return 0
  else
    local new_count
    new_count=$(echo "$new_failures" | wc -l | tr -d ' ')
    log_error "Found $new_count NEW test failure(s) (regression):"
    echo "$new_failures" | while read -r line; do
      log_error "  - $line"
    done
    return 1
  fi
}

# =================================================
# Scoped Quality Checks (Teams Mode)
# =================================================

# Run ruff only on files changed by the current story.
# Prevents cross-story lint failures from blocking progress.
#
# Usage: run_ruff_scoped "$base_commit"
run_ruff_scoped() {
  local base_commit="$1"

  local changed_files
  changed_files=$(git diff --name-only "$base_commit" HEAD -- '*.py' 2>/dev/null)

  # Include untracked Python files
  local untracked
  untracked=$(git ls-files --others --exclude-standard -- '*.py' 2>/dev/null)

  local all_files
  all_files=$(echo -e "${changed_files}\n${untracked}" | sort -u | grep -v '^$')

  if [ -z "$all_files" ]; then
    log_info "No Python files changed — skipping ruff"
    return 0
  fi

  log_info "Running ruff on $(echo "$all_files" | wc -l | tr -d ' ') changed file(s)"
  echo "$all_files" | xargs uv run ruff format
  echo "$all_files" | xargs uv run ruff check --fix
}

# Run complexity check only on files changed by the current story.
#
# Usage: run_complexity_scoped "$base_commit"
run_complexity_scoped() {
  local base_commit="$1"

  local changed_files
  changed_files=$(git diff --name-only "$base_commit" HEAD -- 'src/*.py' 2>/dev/null)

  if [ -z "$changed_files" ]; then
    log_info "No src files changed — skipping complexity check"
    return 0
  fi

  log_info "Running complexity check on $(echo "$changed_files" | wc -l | tr -d ' ') file(s)"
  echo "$changed_files" | xargs uv run complexipy --max-complexity 10
}

# Run tests scoped to the current story's test files.
#
# Usage: run_tests_scoped "$base_commit"
run_tests_scoped() {
  local base_commit="$1"

  local changed_tests
  changed_tests=$(git diff --name-only "$base_commit" HEAD -- 'tests/*.py' 2>/dev/null)

  local untracked_tests
  untracked_tests=$(git ls-files --others --exclude-standard -- 'tests/*.py' 2>/dev/null)

  local all_tests
  all_tests=$(echo -e "${changed_tests}\n${untracked_tests}" | sort -u | grep -v '^$')

  if [ -z "$all_tests" ]; then
    log_info "No test files changed — running full test suite"
    uv run pytest --tb=short -q
    return $?
  fi

  log_info "Running $(echo "$all_tests" | wc -l | tr -d ' ') changed test file(s)"
  echo "$all_tests" | xargs uv run pytest --tb=short -q
}

# =================================================
# Orchestrated Quality Check
# =================================================

# Run complete quality checks with baseline awareness.
# Phase 1: lint + type + complexity (fail-fast)
# Phase 2: tests with baseline comparison
#
# In teams mode, Phase 1 checks are scoped to story files.
# In solo mode, Phase 1 runs against the full codebase.
#
# Usage: run_quality_checks_baseline "$baseline_file" "$story_id" ["teams"]
run_quality_checks_baseline() {
  local baseline_file="$1"
  local story_id="$2"
  local mode="${3:-solo}"

  log_info "Running quality checks for $story_id (mode: $mode)"

  # Phase 1: Lint, type check, complexity
  if [ "$mode" = "teams" ]; then
    local base_commit
    base_commit=$(get_story_base_commit "$story_id")

    log_info "Phase 1: Scoped lint + type + complexity"
    run_ruff_scoped "$base_commit" || return 1
    uv run pyright || return 1
    run_complexity_scoped "$base_commit" || return 1
  else
    log_info "Phase 1: Full lint + type + complexity"
    uv run ruff format --exclude tests || return 1
    uv run ruff check --fix --exclude tests || return 1
    uv run pyright || return 1
    uv run complexipy || return 1
  fi

  log_success "Phase 1 passed"

  # Phase 2: Tests with baseline comparison
  log_info "Phase 2: Tests with baseline comparison"
  if ! compare_test_failures "$baseline_file"; then
    log_error "Phase 2 failed: new test regressions detected"
    return 1
  fi

  log_success "All quality checks passed for $story_id"

  # Refresh baseline after success
  refresh_baseline_on_success "$baseline_file" "$story_id"

  return 0
}
