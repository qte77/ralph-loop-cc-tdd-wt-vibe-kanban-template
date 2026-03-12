#!/bin/bash
#
# Ralph Loop - Autonomous iteration script
#
# Usage: ./ralph/scripts/ralph.sh [MAX_ITERATIONS]
#        make ralph_run [ITERATIONS=25]
#
# This script orchestrates autonomous task execution by:
# 1. Reading prd.json for incomplete stories
# 2. Executing single story via Claude Code (with TDD workflow)
# 3. Verifying TDD commits (RED + GREEN phases)
# 4. Running quality checks (make validate)
# 5. Updating prd.json status on success
# 6. Appending learnings to progress.txt
# 7. Generating application documentation (README.md, example.py)
#
# TDD Workflow Enforcement:
# - Agent must make separate commits for RED (tests) and GREEN (implementation)
# - Script verifies at least 2 commits were made during execution
# - Checks for [RED] and [GREEN] markers in commit messages
#
# Commit Architecture:
# - Agent commits (story.prompt.md): tests [RED], implementation [GREEN], refactoring [REFACTOR]
# - Script commits (commit_story_state): prd.json, progress.txt, README.md, example.py
# - Both required: Agent commits prove TDD compliance, script commits track progress
#

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source libraries
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/validate_json.sh"
source "$SCRIPT_DIR/lib/generate_app_docs.sh"

# Load Vibe Kanban environment using specific RUN_ID
if [ -n "${RALPH_RUN_ID:-}" ] && [ -f "$RALPH_TMP_DIR/vibe-${RALPH_RUN_ID}.env" ]; then
    source "$RALPH_TMP_DIR/vibe-${RALPH_RUN_ID}.env"
fi

source "$SCRIPT_DIR/lib/vibe.sh"

# Configuration (import from config.sh with CLI/env overrides)
MAX_ITERATIONS=${1:-$RALPH_MAX_ITERATIONS}
MAX_FIX_ATTEMPTS="$RALPH_MAX_FIX_ATTEMPTS"
VALIDATION_TIMEOUT=${VALIDATION_TIMEOUT:-$RALPH_VALIDATION_TIMEOUT}
FIX_TIMEOUT=${FIX_TIMEOUT:-$RALPH_FIX_TIMEOUT}
MAX_LOG_FILES="$RALPH_MAX_LOG_FILES"

# Convenience aliases (used frequently: PRD_JSON 16x, PROGRESS_FILE 9x, PROMPT_FILE 2x)
PRD_JSON="$RALPH_PRD_JSON"
PROGRESS_FILE="$RALPH_PROGRESS_FILE"
PROMPT_FILE="$RALPH_PROMPT_FILE"
BRANCH_PREFIX="$RALPH_STORY_BRANCH_PREFIX"
LOG_DIR="$RALPH_LOOP_LOG_DIR"

# Model configuration (local aliases for readability)
DEFAULT_MODEL="$RALPH_DEFAULT_MODEL"
SIMPLE_MODEL="$RALPH_SIMPLE_MODEL"
FIX_MODEL="$RALPH_FIX_MODEL"
FIX_ERROR_THRESHOLD="$RALPH_FIX_ERROR_THRESHOLD"
SIMPLE_PATTERNS="$RALPH_SIMPLE_PATTERNS"
DOCS_PATTERNS="$RALPH_DOCS_PATTERNS"

# Initialize log directory
init_log_dir() {
    mkdir -p "$LOG_DIR"
    # Rotate old logs (keep last MAX_LOG_FILES)
    local old_logs=$(ls -t "$LOG_DIR"/validate_*.log 2>/dev/null | tail -n +$((MAX_LOG_FILES + 1)))
    if [ -n "$old_logs" ]; then
        rm -f $old_logs
    fi
}

# Generate timestamped log filename
get_log_filename() {
    local story_id="$1"
    local phase="$2"  # "validate" or "fix_N"
    echo "$LOG_DIR/${story_id}_${phase}_$(date +%Y%m%d_%H%M%S).log"
}

# Extract error count from validation log (tool-specific parsing)
count_validation_errors() {
    local log_file="$1"
    local type_errors=0
    local test_failures=0

    # Pyright format: "506 errors, 0 warnings, 0 informations"
    if grep -q "errors.*warnings.*informations" "$log_file" 2>/dev/null; then
        type_errors=$(grep -oE "^[0-9]+ errors" "$log_file" | grep -oE "[0-9]+" | tail -1)
    fi

    # Pytest format: "X failed" or "FAILED" markers
    if grep -q "FAILED\|failed" "$log_file" 2>/dev/null; then
        test_failures=$(grep -cE "^FAILED |pytest.*failed" "$log_file" || echo 0)
    fi

    echo "$((${type_errors:-0} + ${test_failures:-0}))"
}

# Smart model selection router - classify story complexity
# Returns model based on configuration (DEFAULT_MODEL or SIMPLE_MODEL)
classify_story() {
    local title="$1"
    local description="$2"
    local combined="$title $description"

    # Use SIMPLE_MODEL for simple tasks
    if echo "$combined" | grep -qiE "$SIMPLE_PATTERNS"; then
        echo "$SIMPLE_MODEL"
        return 0
    fi

    # Use SIMPLE_MODEL for documentation-only changes
    if echo "$combined" | grep -qiE "$DOCS_PATTERNS"; then
        echo "$SIMPLE_MODEL"
        return 0
    fi

    # Use DEFAULT_MODEL for everything else (new features, refactoring, tests)
    echo "$DEFAULT_MODEL"
}

# Validate environment
validate_environment() {
    log_info "Validating environment..."

    if [ ! -f "$PRD_JSON" ]; then
        log_error "prd.json not found at $PRD_JSON"
        log_info "Run 'claude -p /generating-prd-json-from-prd-md' or 'make ralph_init_loop'"
        exit 1
    fi

    if [ ! -f "$PROGRESS_FILE" ]; then
        log_warn "progress.txt not found, creating..."
        mkdir -p "$(dirname "$PROGRESS_FILE")"
        echo "# Ralph Loop Progress" > "$PROGRESS_FILE"
        echo "Started: $(date)" >> "$PROGRESS_FILE"
        echo "" >> "$PROGRESS_FILE"
    fi

    if ! command -v jq &> /dev/null; then
        log_error "jq is required but not installed"
        exit 1
    fi

    # Git state check - prevents conflicts
    if ! git diff --quiet 2>/dev/null || ! git diff --staged --quiet 2>/dev/null; then
        log_warn "Uncommitted changes detected - consider committing first"
    fi

    # Branch protection - prevents accidents on main/master
    current_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
    if [ "$current_branch" = "main" ] || [ "$current_branch" = "master" ]; then
        log_error "Running on protected branch: $current_branch"
        log_info "Create a feature branch: git checkout -b feat/your-feature"
        exit 1
    fi

    log_info "Environment validated successfully"
}

# Get next story with resolved dependencies (execute deps first)
get_next_story() {
    # Get all incomplete stories
    local incomplete=$(jq -r '.stories[] | select(.status != "passed") | .id' "$PRD_JSON")

    for story_id in $incomplete; do
        # Check if all dependencies are complete
        local deps=$(jq -r --arg id "$story_id" \
            '.stories[] | select(.id == $id) | .depends_on // [] | .[]' \
            "$PRD_JSON" 2>/dev/null)

        local deps_met=true
        for dep in $deps; do
            local dep_status=$(jq -r --arg id "$dep" \
                '.stories[] | select(.id == $id) | .status' "$PRD_JSON")
            if [ "$dep_status" != "passed" ]; then
                deps_met=false
                break
            fi
        done

        # Return first story with all deps satisfied
        if [ "$deps_met" = "true" ]; then
            echo "$story_id"
            return 0
        fi
    done

    # No story with satisfied deps found
    echo ""
}

# Get story details
get_story_details() {
    local story_id="$1"
    jq -r --arg id "$story_id" '.stories[] | select(.id == $id) | "\(.title)|\(.description)"' "$PRD_JSON"
}

# Update story status in prd.json
update_story_status() {
    local story_id="$1"
    local new_status="$2"  # "passed" or "failed"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    jq --arg id "$story_id" \
       --arg status "$new_status" \
       --arg timestamp "$timestamp" \
       '(.stories[] | select(.id == $id) | .status) = $status |
        (.stories[] | select(.id == $id) | .completed_at) = (if $status == "passed" then $timestamp else null end)' \
       "$PRD_JSON" > "${PRD_JSON}.tmp"

    if ! validate_prd_json "${PRD_JSON}.tmp"; then
        rm -f "${PRD_JSON}.tmp"
        return 1
    fi
    mv "${PRD_JSON}.tmp" "$PRD_JSON"
}

# Verify that only the current story was modified in prd.json
verify_teammate_stories() {
    local story_id="$1"
    local base_commit="$2"
    # Diff prd.json between base_commit and HEAD
    # Extract changed story IDs — only $story_id should appear
    local changed_ids=$(git diff "$base_commit" HEAD -- "$PRD_JSON" | \
        grep -oE '"id":\s*"STORY-[0-9a-z]+"' | \
        grep -oE 'STORY-[0-9a-z]+' | sort -u)
    for cid in $changed_ids; do
        if [ "$cid" != "$story_id" ]; then
            log_warn "Story $cid was modified during $story_id execution"
            return 1
        fi
    done
    return 0
}

# Append to progress log
log_progress() {
    local iteration="$1"
    local story_id="$2"
    local status="$3"
    local notes="$4"

    {
        echo "## Iteration $iteration - $(date)"
        echo "Story: $story_id"
        echo "Status: $status"
        echo "Notes: $notes"
        echo ""
    } >> "$PROGRESS_FILE"
}

# Build extra claude CLI flags from config (RALPH_DESLOPIFY)
build_claude_extra_flags() {
    local flags=""
    if [ "${RALPH_DESLOPIFY}" = "true" ]; then
        flags='--append-system-prompt "Produce clean, production-quality code. No shortcuts, no placeholders, no TODOs. Every function must have proper error handling, types, and docstrings."'
    fi
    echo "$flags"
}

# Execute single story via Claude Code
execute_story() {
    local story_id="$1"
    local details="$2"
    local title=$(echo "$details" | cut -d'|' -f1)
    local description=$(echo "$details" | cut -d'|' -f2)

    log_info "Executing story: $story_id - $title"
    kanban_update "$story_id" "inprogress"

    # Model selection: explicit override or smart classification
    local model
    if [ -n "${RALPH_MODEL}" ]; then
        model="$RALPH_MODEL"
        log_info "Using model: $model (explicit override via RALPH_MODEL)"
    else
        model=$(classify_story "$title" "$description")
        log_info "Using model: $model (based on story complexity)"
    fi

    # Create prompt for this iteration
    local iteration_prompt=$(mktemp)
    cat "$PROMPT_FILE" > "$iteration_prompt"
    {
        echo ""
        echo "## Current Story"
        echo "**ID**: $story_id"
        echo "**Title**: $title"
        echo "**Description**: $description"
        echo ""
        echo "Read prd.json for full acceptance criteria and expected files."

        # Inject accumulated learnings
        if [[ -f "$RALPH_LEARNINGS_FILE" ]]; then
            echo ""
            echo "## Agent Learnings"
            echo ""
            cat "$RALPH_LEARNINGS_FILE"
        fi

        # Inject human requests
        if [[ -f "$RALPH_REQUESTS_FILE" ]]; then
            echo ""
            echo "## Human Requests"
            echo ""
            cat "$RALPH_REQUESTS_FILE"
        fi

        # Inject ad-hoc steering instruction
        if [ -n "${RALPH_INSTRUCTION}" ]; then
            echo ""
            echo "## Steering Instruction"
            echo ""
            echo "$RALPH_INSTRUCTION"
        fi
    } >> "$iteration_prompt"

    # Execute via Claude Code with selected model
    # Set PYTHONPATH to worktree's src/ for proper module isolation
    local extra_flags=$(build_claude_extra_flags)
    log_info "Running Claude Code with story context..."
    if PYTHONPATH="$(pwd)/src:${PYTHONPATH:-}" cat "$iteration_prompt" | eval claude -p --model "$model" --dangerously-skip-permissions $extra_flags 2>&1 | tee "$RALPH_TMP_DIR/execute_${story_id}.log"; then
        log_info "Execution log saved: $RALPH_TMP_DIR/execute_${story_id}.log"
        rm "$iteration_prompt"
        return 0
    else
        log_error "Execution failed, log saved: $RALPH_TMP_DIR/execute_${story_id}.log"
        rm "$iteration_prompt"
        return 1
    fi
}

# Run quality checks
run_quality_checks() {
    local error_log="${1:-$RALPH_TMP_DIR/validate.log}"
    > "$error_log"  # Truncate file first (defensive)
    log_info "Running quality checks (timeout: ${VALIDATION_TIMEOUT}s)..."

    # Set PYTHONPATH to worktree's src/ for proper module isolation
    if PYTHONPATH="$(pwd)/src:${PYTHONPATH:-}" timeout "$VALIDATION_TIMEOUT" make validate 2>&1 | tee "$error_log"; then
        log_info "Quality checks passed"
        return 0
    else
        local exit_code=$?
        if [ "$exit_code" -eq 124 ]; then
            log_error "Validation timed out after ${VALIDATION_TIMEOUT}s"
        else
            log_error "Quality checks failed (exit code: $exit_code)"
        fi
        cat "$error_log"
        return 1
    fi
}

# Fix validation errors by re-invoking agent with error details
fix_validation_errors() {
    local story_id="$1"
    local details="$2"
    local error_log="$3"
    local max_attempts="$4"

    log_info "Attempting to fix validation errors (max $max_attempts attempts)..."

    local title=$(echo "$details" | cut -d'|' -f1)
    local description=$(echo "$details" | cut -d'|' -f2)

    # Track error count for trend monitoring
    local prev_error_count=$(count_validation_errors "$error_log")
    log_info "Initial error count: $prev_error_count"

    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        log_info "Fix attempt $attempt/$max_attempts"

        # Model selection: explicit override or smart fix routing
        local model
        if [ -n "${RALPH_MODEL}" ]; then
            model="$RALPH_MODEL"
            log_info "Using model: $model (explicit override via RALPH_MODEL)"
        elif [ "$prev_error_count" -gt "$FIX_ERROR_THRESHOLD" ]; then
            model="$DEFAULT_MODEL"
            log_info "Using $model for complex fixes (error count: $prev_error_count, threshold: $FIX_ERROR_THRESHOLD)"
        else
            model="$FIX_MODEL"
            log_info "Using model: $model (validation fix)"
        fi

        # Reuse main prompt with story details + validation errors
        local fix_prompt=$(mktemp)
        cat "$PROMPT_FILE" > "$fix_prompt"
        {
            echo ""
            echo "## Current Story"
            echo "**ID**: $story_id"
            echo "**Title**: $title"
            echo "**Description**: $description"
            echo ""
            echo "## VALIDATION ERRORS TO FIX"
            echo ""
            echo "The story implementation has validation errors. Fix them:"
            echo ""
            echo '```'
            cat "$error_log"
            echo '```'
            echo ""
            echo "Fix all errors and run \`make validate\` to verify."

            # Inject accumulated learnings
            if [[ -f "$RALPH_LEARNINGS_FILE" ]]; then
                echo ""
                echo "## Agent Learnings"
                echo ""
                cat "$RALPH_LEARNINGS_FILE"
            fi

            # Inject human requests
            if [[ -f "$RALPH_REQUESTS_FILE" ]]; then
                echo ""
                echo "## Human Requests"
                echo ""
                cat "$RALPH_REQUESTS_FILE"
            fi

            # Inject ad-hoc steering instruction
            if [ -n "${RALPH_INSTRUCTION}" ]; then
                echo ""
                echo "## Steering Instruction"
                echo ""
                echo "$RALPH_INSTRUCTION"
            fi
        } >> "$fix_prompt"

        # Execute fix via Claude Code with timeout (set PYTHONPATH for worktree isolation)
        local extra_flags=$(build_claude_extra_flags)
        if timeout "$FIX_TIMEOUT" bash -c "PYTHONPATH=\"\$(pwd)/src:\${PYTHONPATH:-}\" cat \"$fix_prompt\" | eval claude -p --model \"$model\" --dangerously-skip-permissions $extra_flags" 2>&1 | tee "$RALPH_TMP_DIR/fix_${story_id}_${attempt}.log"; then
            log_info "Fix attempt log saved: $RALPH_TMP_DIR/fix_${story_id}_${attempt}.log"
            rm "$fix_prompt"

            # Use quick validation (no coverage) for intermediate attempts to save time, full validation on last attempt
            local retry_log="$RALPH_TMP_DIR/validate_fix_${attempt}.log"
            if [ $attempt -lt $max_attempts ]; then
                log_info "Running quick validation (attempt $attempt/$max_attempts)..."
                if make validate_quick 2>&1 | tee "$retry_log"; then
                    # Quick validation passed, run full validation to confirm
                    if run_quality_checks "$retry_log"; then
                        log_info "Full validation passed after fix attempt $attempt"
                        return 0
                    fi
                else
                    log_warn "Quick validation still failing after fix attempt $attempt"
                    # Check error trend
                    local current_errors=$(count_validation_errors "$retry_log")
                    if [ "$current_errors" -ge "$prev_error_count" ]; then
                        log_warn "Errors not decreasing ($prev_error_count -> $current_errors)"
                    fi
                    prev_error_count=$current_errors
                    error_log="$retry_log"  # Use new errors for next attempt
                fi
            else
                # Last attempt - run full validation directly
                log_info "Running full validation (final attempt)..."
                if run_quality_checks "$retry_log"; then
                    log_info "Validation passed after fix attempt $attempt"
                    return 0
                else
                    log_warn "Validation still failing after fix attempt $attempt"
                    error_log="$retry_log"  # Use new errors for next attempt
                fi
            fi
        else
            log_error "Fix execution failed, log saved: $RALPH_TMP_DIR/fix_${story_id}_${attempt}.log"
            rm "$fix_prompt"
            return 1
        fi

        attempt=$((attempt + 1))
    done

    log_error "Failed to fix validation errors after $max_attempts attempts"
    return 1
}

# Commit story state files after successful completion
commit_story_state() {
    local story_id="$1"
    local message="$2"

    # Generate/update application documentation
    local app_readme=$(generate_app_readme)
    local app_example=$(generate_app_example)

    # Commit state files (prd.json, progress.txt, README.md, example.py)
    log_info "Committing state files..."
    git add "$PRD_JSON" "$PROGRESS_FILE"
    [ -n "$app_readme" ] && git add "$app_readme"
    [ -n "$app_example" ] && git add "$app_example"

    if ! git commit -m "docs($story_id): $message"; then
        log_warn "No state changes to commit"
        return 1
    fi

    return 0
}

# Check that TDD commits were made during story execution
# Verify TDD commit order: [RED] must be committed BEFORE [GREEN]
# In git log output, older commits appear on higher line numbers
# Sets TDD_ERROR_MSG global variable with detailed error message
check_tdd_commits() {
    local story_id="$1"
    local commits_before="$2"

    # Skip TDD verification for first story being executed to allow ramp-up
    local completed_stories=$(jq '[.stories[] | select(.status == "passed")] | length' "$PRD_JSON")
    if [ "$completed_stories" -eq 0 ]; then
        log_info "Skipping TDD verification for first story (ramp-up)"
        return 0
    fi

    # Skip TDD verification for STORY-000 (foundation story - establishes baseline)
    if [ "$story_id" = "STORY-000" ]; then
        log_info "Skipping TDD verification for STORY-000 (foundation story)"
        return 0
    fi

    log_info "Checking TDD commits..."
    TDD_ERROR_MSG=""  # Reset error message

    # Count commits made during story execution
    local commits_after=$(git rev-list --count HEAD)
    local new_commits=$((commits_after - commits_before))

    # If no commits made during this execution, skip verification
    if [ $new_commits -eq 0 ]; then
        log_warn "No commits made - skipping TDD verification"
        TDD_ERROR_MSG="No commits made during execution"
        return 2  # Return code 2 = skip (not fail)
    fi

    # Verify commits mention the story ID or phases
    local recent_commits=$(git log --oneline -n $new_commits)
    log_info "Recent commits:"
    echo "$recent_commits"

    # Check if commits are verification-only (chore/docs commits for already-complete stories)
    # Pattern: commits that mark stories complete without new implementation
    if echo "$recent_commits" | grep -qE "^[a-f0-9]+ (chore|docs)\(${story_id}\): (mark|update|verify)"; then
        log_info "Detected verification commits for already-complete story - skipping TDD check"
        return 0
    fi

    if [ $new_commits -lt 2 ]; then
        TDD_ERROR_MSG="Found $new_commits commit(s), need 2+ (RED + GREEN)"
        log_error "TDD check failed: $TDD_ERROR_MSG"
        return 1
    fi

    # Get commits in chronological order (oldest first), extract phase markers
    local phases=$(git log --oneline -n $new_commits --reverse | grep -o "\[RED\]\|\[GREEN\]\|\[BLUE\]" | tr '\n' ' ')

    # Check required phases exist
    if ! echo "$phases" | grep -q "\[RED\]" || ! echo "$phases" | grep -q "\[GREEN\]"; then
        TDD_ERROR_MSG="Missing [RED] or [GREEN] markers"
        log_error "TDD check failed: $TDD_ERROR_MSG"
        return 1
    fi

    # Verify chronological order: RED → GREEN (→ BLUE optional)
    if echo "$phases" | grep -q "\[BLUE\]"; then
        if ! echo "$phases" | grep -qE "\[RED\].*\[GREEN\].*\[BLUE\]"; then
            TDD_ERROR_MSG="Invalid phase order: must be RED → GREEN → BLUE"
            log_error "TDD check failed: $TDD_ERROR_MSG"
            return 1
        fi
        log_info "TDD phases verified: RED → GREEN → BLUE"
    else
        if ! echo "$phases" | grep -qE "\[RED\].*\[GREEN\]"; then
            TDD_ERROR_MSG="Invalid phase order: must be RED → GREEN"
            log_error "TDD check failed: $TDD_ERROR_MSG"
            return 1
        fi
        log_info "TDD phases verified: RED → GREEN"
    fi

    return 0
}

# Main loop
main() {
    log_info "Starting Ralph Loop (max iterations: $MAX_ITERATIONS)"

    # Legacy guard: detect old "passes" boolean schema
    if jq -e '.stories[0] | has("passes")' "$PRD_JSON" &>/dev/null; then
        log_error "prd.json uses legacy 'passes' field. Run: python3 ralph/scripts/generate_prd_json.py"
        exit 1
    fi

    validate_environment
    init_log_dir

    local iteration=0
    # Track attempts per story (associative array)
    declare -A story_attempts

    while [ $iteration -lt $MAX_ITERATIONS ]; do
        iteration=$((iteration + 1))
        log_info "===== Iteration $iteration/$MAX_ITERATIONS ====="

        # Get next incomplete story
        local story_id=$(get_next_story)

        if [ -z "$story_id" ]; then
            log_info "No incomplete stories found"
            log_info "<promise>COMPLETE</promise>"
            break
        fi

        local details=$(get_story_details "$story_id")
        local title=$(echo "$details" | cut -d'|' -f1)

        # Track story attempts
        story_attempts[$story_id]=$((${story_attempts[$story_id]:-0} + 1))
        local attempt_num=${story_attempts[$story_id]}
        export STORY_ATTEMPT_NUM="$attempt_num"  # Make available to kanban_update
        log_info "Story attempt $attempt_num"

        # Record commit count before execution
        local commits_before=$(git rev-list --count HEAD)

        # Execute story
        if execute_story "$story_id" "$details"; then
            log_info "Story execution completed"

            if [ "${RALPH_DRY_RUN}" = "true" ]; then
                # Dry-run: skip TDD verification and quality checks
                log_info "DRY_RUN: skipping TDD verification and quality checks"
                update_story_status "$story_id" "passed"
                kanban_update "$story_id" "done"
                log_progress "$iteration" "$story_id" "PASS" "Completed (dry-run, no validation)"
                commit_story_state "$story_id" "dry-run completion (no validation)"
            else
                # Verify TDD commits were made (capture return code without triggering set -e)
                local tdd_check_result=0
                check_tdd_commits "$story_id" "$commits_before" || tdd_check_result=$?

                if [ $tdd_check_result -eq 2 ]; then
                    # No commits made - check if story was already complete
                    local current_status=$(jq -r --arg sid "$story_id" '.stories[] | select(.id == $sid) | .status' "$PRD_JSON")
                    if [ "$current_status" == "passed" ]; then
                        # Story was verified as complete (no new work needed)
                        kanban_update "$story_id" "done"
                        log_progress "$iteration" "$story_id" "PASS" "Verified as already complete"
                        log_info "Story $story_id was already complete - marked as PASSING"

                        # Commit state files
                        commit_story_state "$story_id" "verified story was already complete"
                        continue
                    else
                        # Story incomplete, retry
                        log_info "No commits - retrying story"
                        log_progress "$iteration" "$story_id" "RETRY" "$TDD_ERROR_MSG"
                        continue
                    fi
                elif [ $tdd_check_result -ne 0 ]; then
                    # TDD verification failed
                    kanban_update "$story_id" "todo" "TDD verification failed: $TDD_ERROR_MSG"
                    log_progress "$iteration" "$story_id" "FAIL" "TDD verification failed: $TDD_ERROR_MSG"
                    continue
                fi

                # Run quality checks
                kanban_update "$story_id" "inreview"
                local validation_log="$RALPH_TMP_DIR/validate_${story_id}.log"
                if run_quality_checks "$validation_log"; then
                    # Mark as passing
                    update_story_status "$story_id" "passed"
                    kanban_update "$story_id" "done"
                    log_progress "$iteration" "$story_id" "PASS" "Completed successfully with TDD commits"
                    log_info "Story $story_id marked as PASSING"

                    # Commit state files with documentation
                    commit_story_state "$story_id" "update state and documentation after completion"
                else
                    log_warn "Story completed but quality checks failed - attempting fixes"

                    # Attempt to fix validation errors
                    if fix_validation_errors "$story_id" "$details" "$validation_log" "$MAX_FIX_ATTEMPTS"; then
                        # Mark as passing after successful fixes
                        update_story_status "$story_id" "passed"
                        kanban_update "$story_id" "done"
                        log_progress "$iteration" "$story_id" "PASS" "Completed after fixing validation errors"
                        log_info "Story $story_id marked as PASSING after fixes"

                        # Commit state files with documentation
                        commit_story_state "$story_id" "update state and documentation after fixing validation errors"
                    else
                        kanban_update "$story_id" "todo" "Quality checks failed after $MAX_FIX_ATTEMPTS fix attempts"
                        log_error "Failed to fix validation errors"
                        log_progress "$iteration" "$story_id" "FAIL" "Quality checks failed after $MAX_FIX_ATTEMPTS fix attempts"
                    fi
                fi
            fi
        else
            kanban_update "$story_id" "todo" "Story execution failed - Claude returned error"
            log_error "Story execution failed"
            log_progress "$iteration" "$story_id" "FAIL" "Execution error"
        fi

        echo ""
    done

    if [ $iteration -eq $MAX_ITERATIONS ]; then
        log_warn "Reached maximum iterations ($MAX_ITERATIONS)"

        # Mark incomplete stories as cancelled (preserve 'done' status for passing stories)
        while IFS= read -r story; do
            local id=$(echo "$story" | jq -r '.id')
            local status=$(echo "$story" | jq -r '.status')

            # Skip stories that passed - they're already marked "done"
            if [ "$status" == "passed" ]; then
                continue
            fi

            local reason="Max iterations ($MAX_ITERATIONS) reached - story incomplete"
            kanban_update "$id" "cancelled" "$reason"
            log_warn "Story $id cancelled: $reason"
        done < <(jq -c '.stories[]' "$PRD_JSON")
    fi

    # Commit any remaining uncommitted tracking files
    if ! git diff --quiet "$PRD_JSON" "$PROGRESS_FILE" 2>/dev/null; then
        log_info "Committing final tracking file changes..."
        git add "$PRD_JSON" "$PROGRESS_FILE"

        local total=$(jq '.stories | length' "$PRD_JSON")
        local passing=$(jq '[.stories[] | select(.status == "passed")] | length' "$PRD_JSON")

        git commit -m "docs(ralph): update progress after loop completion

Summary: $passing/$total stories passing"
    fi

    # Summary
    local total=$(jq '.stories | length' "$PRD_JSON")
    local passing=$(jq '[.stories[] | select(.status == "passed")] | length' "$PRD_JSON")

    log_info "Summary: $passing/$total stories passing"
}

# Run main
main
