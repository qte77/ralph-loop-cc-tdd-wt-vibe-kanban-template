#!/bin/bash
#
# Parallel Ralph Loop - Orchestrator for parallel execution
#
# Usage: ./ralph/scripts/parallel_ralph.sh [N_WT] [MAX_ITERATIONS]
#        make ralph_run N_WT=2 ITERATIONS=10
#
# Environment variables:
#   DEBUG=0 (default) - Enable debug mode (watch logs, no auto-merge)
#   USE_LOCK=true (default) - Lock worktrees to prevent pruning
#   USE_NO_TRACK=true (default) - Create local-only branches
#   LOCK_REASON="..." - Custom lock reason message
#   WORKTREE_QUIET=false (default) - Suppress worktree output
#   MERGE_VERIFY_SIGNATURES=false (default) - Verify GPG signatures
#   MERGE_LOG=true (default) - Include commit descriptions in merge
#
# Examples:
#   make ralph_run N_WT=3 ITERATIONS=25
#   make ralph_run DEBUG=1 N_WT=3
#   USE_LOCK=false make ralph_run N_WT=1
#   MERGE_VERIFY_SIGNATURES=true make ralph_run N_WT=2
#
# This script orchestrates parallel Ralph loop execution by:
# 1. Creating N_WT git worktrees (default=1, max=10)
# 2. Running ralph.sh in each worktree SIMULTANEOUSLY (background jobs)
# 3. Waiting for all to complete and scoring results
# 4. Merging the best result back to original branch
# 5. Cleaning up worktrees and branches
#
# Architecture:
# - N_WT=1: Single worktree isolation (security)
# - N_WT>1: True parallel execution via bash background jobs
# - Worktrees default to --lock (prevents pruning) and --no-track (local branches)
#   Both flags configurable via USE_LOCK and USE_NO_TRACK env vars
# - Best result selected by scoring algorithm
# - Merge via --no-ff --no-commit (dry-run test, then commit)
#
# Scoring Algorithm (N_WT>1 only):
# - Formula: base + coverage_bonus - penalties
#   base = (stories × 10) + test_count + validation_bonus
#   coverage_bonus = coverage% / 2 (0-50 points)
#   penalties = (ruff × 2) + (pyright_err × 5) + (pyright_warn × 1) + (churn / 100)
# - Higher score wins; N_WT=1 skips scoring overhead
#
# Worktree Naming:
# - N_WT=1: ${PREFIX}-${RUN_ID}        (e.g., ../your_project_name-ralph-wt-a3f5e2)
# - N_WT>1: ${PREFIX}-${RUN_ID}-${NUM} (e.g., ../your_project_name-ralph-wt-b9c4d1-1)
# - PREFIX: Dynamic, defaults to ../${SRC_PACKAGE_DIR}-ralph-wt (configurable)
# - RUN_ID: Unique 6-char alphanumeric ID generated per run
# - NUM: Worktree index (1 to N_WT)
# - Purpose: Distinguish different Ralph runs, prevent collisions
#

set -eEuo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source libraries
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/validate_json.sh"
source "$SCRIPT_DIR/lib/vibe.sh"
source "$SCRIPT_DIR/lib/cleanup_worktrees.sh"
source "$SCRIPT_DIR/lib/stop_ralph_processes.sh"

# Source judge library (conditional)
[ "${RALPH_JUDGE_ENABLED:-false}" = "true" ] && source "$SCRIPT_DIR/lib/judge.sh"

# Configuration (import from config.sh with CLI/env overrides)
# Note: N_WT and MAX_ITERATIONS are parsed in main() to avoid conflicts with subcommands
WORKTREE_PREFIX="$RALPH_PARALLEL_WORKTREE_PREFIX"
BRANCH_PREFIX="$RALPH_PARALLEL_BRANCH_PREFIX"

# System limit for parallel worktrees (validated in main)
MAX_WORKTREES=10

# Worktree flags (inherited from config.sh with env override support)
USE_LOCK="$RALPH_PARALLEL_USE_LOCK"
USE_NO_TRACK="$RALPH_PARALLEL_USE_NO_TRACK"
LOCK_REASON="$RALPH_PARALLEL_LOCK_REASON"
WORKTREE_QUIET="$RALPH_PARALLEL_WORKTREE_QUIET"

# Merge flags (inherited from config.sh with env override support)
MERGE_VERIFY_SIGNATURES="$RALPH_PARALLEL_MERGE_VERIFY_SIGNATURES"
MERGE_LOG="$RALPH_PARALLEL_MERGE_LOG"

# Debug mode (env override)
DEBUG="${DEBUG:-0}"

# PID tracking
declare -a WORKTREE_PIDS=()
declare -a WORKTREE_EXIT_CODES=()

# Generate unique 6-char alphanumeric run ID
generate_run_id() {
    # Use timestamp + random for uniqueness
    local timestamp=$(date +%s%N)
    echo "${timestamp}" | md5sum | cut -c1-6
}

# Helper: Get worktree path for given index, run ID, and total count
get_worktree_path() {
    local wt_num="$1"
    local run_id="${2:-}"
    local n_wt="${3:-}"

    if [ -n "$run_id" ]; then
        # If N_WT=1, omit the worktree number (cleaner, less confusing)
        if [ "$n_wt" = "1" ]; then
            echo "${WORKTREE_PREFIX}-${run_id}"
        else
            echo "${WORKTREE_PREFIX}-${run_id}-${wt_num}"
        fi
    else
        # For utility functions scanning existing worktrees
        # Match both patterns: with and without number suffix
        echo "${WORKTREE_PREFIX}-*"
    fi
}

# Helper: Get branch name for given index
get_branch_name() {
    echo "${BRANCH_PREFIX}-${1}"
}

# Helper: Find worktree for a given index using git worktree list (not filesystem)
find_worktree_by_index() {
    local wt_num="$1"
    local prefix_basename="$(basename "$WORKTREE_PREFIX")"

    # Get all registered worktrees from git, filtering by WORKTREE_PREFIX basename
    # Note: git worktree list returns absolute paths, so we match against basename
    local worktrees=$(git worktree list --porcelain | grep "^worktree " | cut -d' ' -f2 | grep "$prefix_basename")

    # For index 1, check both patterns: with number (N_WT>1) and without (N_WT=1)
    if [ "$wt_num" = "1" ]; then
        # Try pattern without number first (N_WT=1 case: ${WORKTREE_PREFIX}-RUNID)
        # Match lines ending with 6 hex chars (not followed by dash-digit)
        local wt=$(echo "$worktrees" | while read -r path; do
            basename "$path" | grep -qE "^$(basename "$WORKTREE_PREFIX")-[a-z0-9]{6}$" && echo "$path" && break
        done)
        if [ -n "$wt" ]; then
            echo "$wt"
            return
        fi
    fi

    # Standard pattern with number (N_WT>1 case: ${WORKTREE_PREFIX}-RUNID-N)
    echo "$worktrees" | while read -r path; do
        basename "$path" | grep -qE "^$(basename "$WORKTREE_PREFIX")-[a-z0-9]{6}-${wt_num}$" && echo "$path" && break
    done
}

# Create worktree with optimized flags
create_worktree() {
    local i="$1"
    local run_id="$2"
    local n_wt="$3"
    local worktree_path=$(get_worktree_path "$i" "$run_id" "$n_wt")
    local branch_name=$(get_branch_name "$i")

    log_info "Creating worktree $i at $worktree_path..."

    # Build worktree command with optional flags (defaults: both enabled)
    local wt_flags=()

    # --no-track: Creates local-only branch (no remote tracking = cleaner, no push conflicts)
    [ "$USE_NO_TRACK" = "true" ] && wt_flags+=(--no-track)

    # --lock: Prevents 'git worktree prune' from removing active worktrees during long runs
    if [ "$USE_LOCK" = "true" ]; then
        wt_flags+=(--lock --reason "$LOCK_REASON")
    fi

    # --quiet: Suppress feedback messages
    [ "$WORKTREE_QUIET" = "true" ] && wt_flags+=(--quiet)

    git worktree add "${wt_flags[@]}" -b "$branch_name" "$worktree_path" HEAD

    log_info "Worktree $i created $([ "$USE_LOCK" = "true" ] && echo "and locked" || echo "")"
}

# Initialize worktree state (copy current prd.json, fresh progress.txt)
init_worktree_state() {
    local i="$1"
    local run_id="$2"
    local n_wt="$3"
    local worktree_path=$(get_worktree_path "$i" "$run_id" "$n_wt")

    log_info "Initializing state for worktree $i..."

    # Copy prd.json as-is (preserves completed stories)
    # This allows resuming from current state
    # Use 'make ralph_clean' to reset state
    if [ -f "$RALPH_PRD_JSON" ]; then
        mkdir -p "$worktree_path/$(dirname "$RALPH_PRD_JSON")"
        cp "$RALPH_PRD_JSON" "$worktree_path/$RALPH_PRD_JSON"
    fi

    # Copy or create progress.txt (append mode - preserves history)
    mkdir -p "$worktree_path/$RALPH_DOCS_DIR"
    if [ -f "$RALPH_PROGRESS_FILE" ]; then
        # Copy existing progress (preserves history)
        cp "$RALPH_PROGRESS_FILE" "$worktree_path/$RALPH_PROGRESS_FILE"
        # Append resume marker
        cat >> "$worktree_path/$RALPH_PROGRESS_FILE" <<EOF

## Resumed: $(date)

EOF
    else
        # Create new progress file
        cat > "$worktree_path/$RALPH_PROGRESS_FILE" <<EOF
# Ralph Loop Progress - Worktree $i
Started: $(date)

EOF
    fi

    log_info "Worktree $i state initialized"
}

# Start parallel ralph.sh execution
start_parallel() {
    local i="$1"
    local run_id="$2"
    local n_wt="$3"
    local worktree_path=$(get_worktree_path "$i" "$run_id" "$n_wt")
    local log_file="$worktree_path/ralph.log"

    log_info "Starting ralph.sh in worktree $i (background)..."

    (
        cd "$worktree_path"
        export WORKTREE_NUM="$i"
        export RALPH_RUN_ID="$run_id"
        ./ralph/scripts/ralph.sh "$MAX_ITERATIONS" > "$log_file" 2>&1
    ) &

    WORKTREE_PIDS[$i]=$!
    disown ${WORKTREE_PIDS[$i]}  # Detach from shell - persist after abort
    log_info "Worktree $i running (PID: ${WORKTREE_PIDS[$i]})"
}

# Wait for all worktrees and monitor completion
wait_and_monitor() {
    log_info "Waiting for all $N_WT worktrees to complete..."

    # Poll for process completion (can't use wait on disowned PIDs)
    local all_done=false
    while [ "$all_done" = "false" ]; do
        all_done=true

        for i in $(seq 1 $N_WT); do
            local pid=${WORKTREE_PIDS[$i]}

            # Check if process still running
            if ps -p "$pid" > /dev/null 2>&1; then
                all_done=false
            elif [ -z "${WORKTREE_EXIT_CODES[$i]:-}" ]; then
                # Process finished, record exit code (can't get actual code from disowned process)
                WORKTREE_EXIT_CODES[$i]=0
                log_info "Worktree $i completed"
            fi
        done

        # Sleep briefly before next check
        [ "$all_done" = "false" ] && sleep 5
    done

    log_info "All worktrees completed"
}

# Extract test coverage % from validation log
# Returns: integer 0-100 (coverage percentage)
extract_coverage() {
    local log_file="$1"
    # pytest-cov format: "TOTAL    1234   123    90%"
    grep "TOTAL" "$log_file" 2>/dev/null | tail -1 | awk '{print $NF}' | tr -d '%' || echo 0
}

# Extract ruff violation count from validation log
# Returns: integer (violation count)
extract_ruff_violations() {
    local log_file="$1"
    # ruff format: path/file.py:line:col: CODE message
    grep -cE "\.py:[0-9]+:[0-9]+: [A-Z][0-9]+" "$log_file" 2>/dev/null || echo 0
}

# Extract pyright error count from validation log
# Returns: integer (error count)
extract_pyright_errors() {
    local log_file="$1"
    # pyright format: "X errors, Y warnings, Z informations"
    grep -oE "^[0-9]+ errors" "$log_file" 2>/dev/null | grep -oE "[0-9]+" | tail -1 || echo 0
}

# Extract pyright warning count from validation log
# Returns: integer (warning count)
extract_pyright_warnings() {
    local log_file="$1"
    # pyright format: "X errors, Y warnings, Z informations"
    grep -oE "[0-9]+ warnings" "$log_file" 2>/dev/null | grep -oE "[0-9]+" | tail -1 || echo 0
}

# Calculate code churn (total lines changed across all commits)
# Returns: integer (total insertions + deletions)
extract_code_churn() {
    local worktree_path="$1"
    # Sum all insertions+deletions from git log
    (cd "$worktree_path" && git log --shortstat --format="" 2>/dev/null | \
        awk '/files? changed/ {s+=$4+$6} END {print s+0}')
}

# Score worktree results using: base + coverage_bonus - penalties
# Returns: numeric score (0 if prd.json missing)
# Logs: detailed breakdown of scoring components
score_worktree() {
    local i="$1"
    local run_id="$2"
    local n_wt="$3"
    local worktree_path=$(get_worktree_path "$i" "$run_id" "$n_wt")
    local prd_json="$worktree_path/$RALPH_PRD_JSON"
    local log_file="$worktree_path/ralph.log"

    if [ ! -f "$prd_json" ]; then
        log_info "Worktree $i: No prd.json found (score: 0)"
        echo 0
        return
    fi

    # Base metrics
    local stories_passed=$(jq '[.stories[] | select(.passes == true)] | length' "$prd_json" 2>/dev/null || echo 0)
    local total_stories=$(jq '.stories | length' "$prd_json" 2>/dev/null || echo 0)
    local test_count=$(find "$worktree_path" -name "test_*.py" -type f 2>/dev/null | wc -l)

    # Validation bonus
    local validation_bonus=0
    local validation_status="failed"
    if [ "${WORKTREE_EXIT_CODES[$i]}" -eq 0 ]; then
        validation_bonus=50
        validation_status="passed"
    fi

    # New metrics (from validation log)
    local coverage=0
    local ruff_violations=0
    local pyright_errors=0
    local pyright_warnings=0
    local code_churn=0

    if [ -f "$log_file" ]; then
        coverage=$(extract_coverage "$log_file")
        ruff_violations=$(extract_ruff_violations "$log_file")
        pyright_errors=$(extract_pyright_errors "$log_file")
        pyright_warnings=$(extract_pyright_warnings "$log_file")
    fi
    code_churn=$(extract_code_churn "$worktree_path")

    # Calculate score with new formula
    local base_score=$((stories_passed * 10 + test_count + validation_bonus))
    local coverage_bonus=$((coverage / 2))  # 0-50 points
    local ruff_penalty=$((ruff_violations * 2))
    local pyright_error_penalty=$((pyright_errors * 5))
    local pyright_warning_penalty=$((pyright_warnings * 1))
    local churn_penalty=$((code_churn / 100))

    local score=$((base_score + coverage_bonus - ruff_penalty - pyright_error_penalty - pyright_warning_penalty - churn_penalty))

    # Ensure score doesn't go negative
    [ "$score" -lt 0 ] && score=0

    # Log breakdown
    log_info "Worktree $i: stories=$stories_passed/$total_stories tests=$test_count validation=$validation_status"
    log_info "  coverage=${coverage}% ruff=-${ruff_violations} pyright_err=-${pyright_errors} pyright_warn=-${pyright_warnings} churn=-${churn_penalty}"
    log_info "  score: $base_score + $coverage_bonus - $ruff_penalty - $pyright_error_penalty - $pyright_warning_penalty - $churn_penalty = $score"

    # Save metrics to file for judge consumption
    local metrics_file="$worktree_path/$RALPH_METRICS_FILE"
    cat > "$metrics_file" <<EOF
{
  "stories_passed": $stories_passed,
  "total_stories": $total_stories,
  "test_count": $test_count,
  "coverage": $coverage,
  "ruff_violations": $ruff_violations,
  "pyright_errors": $pyright_errors,
  "pyright_warnings": $pyright_warnings,
  "code_churn": $code_churn,
  "validation_status": "$validation_status",
  "score": $score
}
EOF

    echo "$score"
}

# Select best worktree by comparing scores
# Returns: worktree index with highest score
# Logs: decision with final score
select_best() {
    local run_id="$1"
    local n_wt="$2"
    log_info "Scoring all worktrees..."

    local best_wt=1
    local best_score=$(score_worktree 1 "$run_id" "$n_wt")

    for i in $(seq 2 $n_wt); do
        local score=$(score_worktree $i "$run_id" "$n_wt")

        if [ "$score" -gt "$best_score" ]; then
            best_wt=$i
            best_score=$score
        fi
    done

    log_info "Selected worktree $best_wt (score: $best_score)"
    echo "$best_wt"
}

# Merge best worktree back to original branch
merge_best() {
    local best_wt="$1"
    local n_wt="$2"
    local run_id="$3"
    local branch_name="${BRANCH_PREFIX}-${best_wt}"

    # Validate worktree has ALL stories passing before merging
    local worktree_path=$(get_worktree_path "$best_wt" "$run_id" "$n_wt")
    local prd_json="$worktree_path/$RALPH_PRD_JSON"
    local stories_passed=0
    local total_stories=0

    if [ -f "$prd_json" ]; then
        stories_passed=$(jq '[.stories[] | select(.passes == true)] | length' "$prd_json" 2>/dev/null || echo 0)
        total_stories=$(jq '.stories | length' "$prd_json" 2>/dev/null || echo 0)
    fi

    if [ "$stories_passed" -ne "$total_stories" ]; then
        log_error "Cannot merge worktree $best_wt: incomplete ($stories_passed/$total_stories stories passed)"
        log_info "No worktrees completed all stories - preserving worktrees for debugging"
        unlock_worktrees
        return 1
    fi

    log_info "Merging complete worktree $best_wt (all $total_stories stories passed)..."

    # Build merge command with configurable flags (use array for proper quoting)
    local merge_flags=(--no-ff --no-commit)

    # --verify-signatures: Verify GPG signatures (security)
    [ "$MERGE_VERIFY_SIGNATURES" = "true" ] && merge_flags+=(--verify-signatures)

    # --log: Include commit descriptions in merge commit
    [ "$MERGE_LOG" = "true" ] && merge_flags+=(--log)

    # Test merge (dry-run with --no-commit)
    if git merge "${merge_flags[@]}" "$branch_name" 2>/dev/null; then
        log_info "Merge succeeded - committing..."

        # Generate commit message based on N_WT (stories_passed and total_stories already retrieved above)
        local commit_msg
        if [ "$n_wt" -eq 1 ]; then
            # Single worktree - simpler message
            commit_msg="feat: complete Ralph loop (all $total_stories stories passed) [run:$run_id]"
        else
            # Parallel worktrees - mention which one was selected
            commit_msg="feat: merge best Ralph result from worktree $best_wt (all $total_stories stories passed) [run:$run_id]"
        fi

        # Optional interactive approval
        if [ "${RALPH_MERGE_INTERACTIVE:-false}" = "true" ]; then
            echo ""
            log_info "Merge staged (not yet committed). You can now:"
            log_info "  - Test the changes (run GUI, manual checks, etc.)"
            log_info "  - Review: git status, git diff --cached"
            echo ""
            read -p "Approve merge and commit? [y/N] " -r
            echo ""
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                git merge --abort
                log_warn "Merge aborted by user"
                return 1
            fi
        fi

        git commit -m "$commit_msg"

        log_info "Merge completed successfully"
        return 0
    else
        # Conflicts detected
        git merge --abort 2>/dev/null || true

        log_error "Merge conflicts detected!"
        log_info "Best worktree: ${WORKTREE_PREFIX}-${best_wt}/"
        log_info "Manual merge required: git merge --no-ff $branch_name"
        return 1
    fi
}

# Unlock worktrees (preserve state for resume)
unlock_worktrees() {
    log_info "Unlocking worktrees (preserving state for resume)..."

    for i in $(seq 1 $MAX_WORKTREES); do
        local worktree_path=$(find_worktree_by_index "$i")
        [ -z "$worktree_path" ] && continue

        # Unlock worktree to allow future operations
        if [ "$USE_LOCK" = "true" ]; then
            log_info "Unlocking worktree $i..."
            git worktree unlock "$worktree_path" 2>/dev/null || true
        fi
    done

    log_info "Worktrees unlocked - run 'make ralph_run' to resume"
}

# cleanup_worktrees() is provided by lib/cleanup_worktrees.sh

# Show status of all worktrees
show_all_status() {
    log_info "Parallel Ralph Status ($(date +%H:%M:%S)):"
    echo ""

    # Scan up to system max to find all existing worktrees
    # Subcommand must auto-detect since it doesn't know what N_WT was used
    local found_any=false
    for i in $(seq 1 $MAX_WORKTREES); do
        local worktree_path=$(find_worktree_by_index "$i")
        [ -z "$worktree_path" ] && continue
        found_any=true
        local prd_json="$worktree_path/$RALPH_PRD_JSON"
        local progress_file="$worktree_path/$RALPH_PROGRESS_FILE"

        echo "=== Worktree $i ==="

        if [ -f "$prd_json" ]; then
            local total=$(jq '.stories | length' "$prd_json" 2>/dev/null || echo 0)
            local passed=$(jq '[.stories[] | select(.passes == true)] | length' "$prd_json" 2>/dev/null || echo 0)
            echo "Stories: $passed/$total passed"
        fi

        if [ -f "$progress_file" ]; then
            local current_story=$(tail -10 "$progress_file" | grep "Story:" | tail -1 || echo "N/A")
            echo "Current: $current_story"
        fi

        # Check if still running
        if [ -n "${WORKTREE_PIDS[$i]:-}" ]; then
            if ps -p "${WORKTREE_PIDS[$i]}" > /dev/null 2>&1; then
                echo "Status: Running (PID: ${WORKTREE_PIDS[$i]})"
            else
                echo "Status: Completed"
            fi
        fi

        echo ""
    done

    if [ "$found_any" = false ]; then
        echo "No active Ralph worktrees found."
        echo "Hint: Run 'make ralph_run' to start a new loop"
    fi
}

# Watch all logs live
watch_all_logs() {
    log_info "Watching all parallel logs (Ctrl+C to exit)..."

    # Show ralph process tree if pstree is available
    if command -v pstree >/dev/null 2>&1; then
        echo ""
        echo "=== Ralph Process Tree ==="
        # Find all ralph-related PIDs and show their process trees
        # Match only actual ralph script processes, not just paths containing "ralph"
        local ralph_pids=$(pgrep -f "ralph\.sh" 2>/dev/null | grep -v "^$$\$")

        # Filter out current watch process and its parent
        ralph_pids=$(echo "$ralph_pids" | while read -r pid; do
            # Skip if this is the current script or contains "watch" subcommand
            local cmdline=$(ps -p "$pid" -o args= 2>/dev/null || echo "")
            if [[ ! "$cmdline" =~ parallel_ralph\.sh[[:space:]]+watch ]] && [[ ! "$cmdline" =~ parallel_ralph\.sh[[:space:]]+status ]] && [ "$pid" != "$$" ]; then
                echo "$pid"
            fi
        done)

        if [ -n "$ralph_pids" ]; then
            echo "$ralph_pids" | while read -r pid; do
                [ -z "$pid" ] && continue
                # Show full tree with command names (-a flag)
                local process_name=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")
                echo "--- PID $pid ($process_name) ---"
                pstree -a -p "$pid" 2>/dev/null || true
            done
        else
            echo "No active ralph loop processes found"
            echo "Hint: Run 'make ralph_run' to start Ralph loops"
        fi
        echo ""
    fi

    local log_files=""
    # Scan up to system max to find all log files
    for i in $(seq 1 $MAX_WORKTREES); do
        local worktree_path=$(find_worktree_by_index "$i")
        [ -z "$worktree_path" ] && continue

        local log_file="$worktree_path/ralph.log"
        if [ -f "$log_file" ]; then
            log_files="$log_files $log_file"
        fi
    done

    if [ -n "$log_files" ]; then
        tail -f $log_files
    else
        log_warn "No log files found yet"
    fi
}

# Show specific worktree log
show_worktree_log() {
    local wt_num="${1:-1}"
    local worktree_path=$(find_worktree_by_index "$wt_num")

    if [ -z "$worktree_path" ]; then
        log_error "No worktree found for index: $wt_num"
        exit 1
    fi

    local log_file="$worktree_path/ralph.log"
    if [ -f "$log_file" ]; then
        cat "$log_file"
    else
        log_error "Log file not found: $log_file"
        exit 1
    fi
}

# Abort all parallel loops
# Stop all processes (uses lib/stop.sh)
stop_parallel() {
    stop_ralph_processes
}


# Cleanup on fatal error (error 255 or worktree creation failure)
# Graceful shutdowns preserve worktrees for debugging; fatal errors during setup clean up broken state
cleanup_on_error() {
    local exit_code=$?

    # Exclude graceful shutdown signals from error cleanup (preserve worktrees)
    # 130 = SIGINT (Ctrl+C), 137 = SIGKILL (kill -9), 143 = SIGTERM (kill)
    if [ "$exit_code" -eq 130 ] || [ "$exit_code" -eq 137 ] || [ "$exit_code" -eq 143 ]; then
        return 0
    fi

    # Disable ERR trap to prevent recursive cleanup calls
    trap - ERR

    log_error "Fatal error detected (exit code: $exit_code). Running cleanup..."

    # Stop Ralph processes
    stop_ralph_processes || true

    # Cleanup worktrees and orphaned branches (bypass interactive prompts)
    cleanup_worktrees || true

    # Cleanup Vibe Kanban tasks
    if command -v bash &> /dev/null && [ -f "ralph/scripts/vibe.sh" ]; then
        bash ralph/scripts/vibe.sh cleanup 2>/dev/null || true
    fi

    log_info "Cleanup completed. Please run 'make ralph_run' to retry."
    exit $exit_code
}

# Main orchestration
main() {
    # Parse CLI arguments (or use config defaults)
    local N_WT=${1:-$RALPH_PARALLEL_N_WT}  # CLI arg or config default (1-10)
    local MAX_ITERATIONS=${2:-$RALPH_MAX_ITERATIONS}  # CLI arg or config default

    # Validate N_WT
    if [ "$N_WT" -lt 1 ] || [ "$N_WT" -gt 10 ]; then
        log_error "N_WT must be between 1 and 10 (got: $N_WT)"
        exit 1
    fi

    # Validate environment
    if ! validate_prd_json "$RALPH_PRD_JSON"; then
        exit 1
    fi

    # Check for existing worktrees and determine mode: resume or create new
    local found_active=false
    local found_paused=false
    local existing_worktrees=()
    local resume_run_id=""
    local resume_n_wt=0

    for i in $(seq 1 $MAX_WORKTREES); do
        local branch_name=$(get_branch_name "$i")
        if git show-ref --verify --quiet "refs/heads/$branch_name"; then
            local old_wt=$(find_worktree_by_index "$i")
            if [ -n "$old_wt" ] && [ -d "$old_wt" ]; then
                # Check if locked (active)
                if git worktree list --porcelain | grep -A 3 "^worktree $old_wt$" | grep -q "^locked"; then
                    log_error "Worktree $i is locked (active ralph loop running)"
                    found_active=true
                else
                    # Paused/stopped worktree found
                    found_paused=true
                    existing_worktrees+=("$i")
                    resume_n_wt=$i

                    # Extract run_id from worktree path (e.g., your_project_name-ralph-wt-41adf4-1 → 41adf4)
                    if [ -z "$resume_run_id" ]; then
                        resume_run_id=$(basename "$old_wt" | grep -oP '(?<=-ralph-wt-)[a-z0-9]+(?=(-[0-9]+)?$)')
                    fi
                fi
            fi
        fi
    done

    # If any active worktrees found, abort
    if [ "$found_active" = true ]; then
        log_error "Active Ralph loops detected. Run 'make ralph_abort' to stop them first."
        exit 1
    fi

    # Determine execution mode and set RUN_ID accordingly
    local resume_mode=false
    local RUN_ID=""

    if [ "$found_paused" = true ] && [ "${#existing_worktrees[@]}" -gt 0 ]; then
        # Resume mode: use existing RUN_ID from worktrees
        resume_mode=true
        N_WT=$resume_n_wt
        RUN_ID="$resume_run_id"
        log_info "Detected ${#existing_worktrees[@]} paused worktree(s) (run_id=$RUN_ID)"
        log_info "Resuming existing worktrees (ITERATIONS parameter ignored)"
    else
        # Fresh start: generate new RUN_ID
        RUN_ID=$(generate_run_id)
        log_info "Starting Parallel Ralph Loop (run_id=$RUN_ID, N_WT=$N_WT, iterations=$MAX_ITERATIONS)"
    fi

    # Initialize Kanban integration with correct RUN_ID
    mkdir -p $RALPH_TMP_DIR
    KANBAN_MAP="$RALPH_TMP_DIR/kb-${RUN_ID}.map"
    kanban_init "$RUN_ID" "$N_WT"

    # Write env vars to file for worktree subprocesses
    cat > "$RALPH_TMP_DIR/vibe-${RUN_ID}.env" <<EOF
export VIBE_URL="$VIBE_URL"
export VIBE_PROJECT_ID="$VIBE_PROJECT_ID"
export KANBAN_MAP="$KANBAN_MAP"
export RUN_ID="$RUN_ID"
EOF

    # Setup trap for interrupt: unlock but preserve state (allows resume)
    trap 'unlock_worktrees; exit 130' INT TERM

    # Setup trap for fatal errors (e.g., worktree creation failures)
    # This catches errors during worktree setup and runs cleanup automatically
    trap 'cleanup_on_error' ERR

    if [ "$resume_mode" = true ]; then
        # RESUME MODE: Use existing worktrees
        log_info "Resume mode: restarting ralph.sh in existing worktrees"

        # Update progress.txt in each worktree with resume marker
        for wt_num in "${existing_worktrees[@]}"; do
            local worktree_path=$(find_worktree_by_index "$wt_num")
            if [ -n "$worktree_path" ] && [ -d "$worktree_path" ]; then
                cat >> "$worktree_path/$RALPH_PROGRESS_FILE" <<EOF

## Resumed: $(date)

EOF
            fi
        done

        # Start ralph.sh in existing worktrees
        for wt_num in "${existing_worktrees[@]}"; do
            start_parallel "$wt_num" "$RUN_ID" "$N_WT"
        done

        log_info "Resumed ${#existing_worktrees[@]} worktree(s)"
    else
        # CREATE NEW MODE: Standard workflow
        log_info "Create new mode: initializing fresh worktrees"

        # Create and initialize all worktrees
        for i in $(seq 1 $N_WT); do
            create_worktree "$i" "$RUN_ID" "$N_WT"
            init_worktree_state "$i" "$RUN_ID" "$N_WT"
        done

        # Start all ralph.sh instances in parallel
        for i in $(seq 1 $N_WT); do
            start_parallel "$i" "$RUN_ID" "$N_WT"
        done

        log_info "All $N_WT worktrees started in parallel"
    fi

    # Normal mode: Fork completion handler to background, exit immediately
    # DEBUG mode: Watch logs and wait for completion in foreground
    if [ "$DEBUG" != "1" ]; then
        log_info "Ralph loops started in background"
        log_info "  - Watch logs: make ralph_watch"
        log_info "  - Check status: make ralph_status"
        log_info "  - Stop loops: make ralph_stop"

        # Fork completion handler to background
        {
            # Wait for all worktrees to complete
            wait_and_monitor

            # Complete the Ralph loop (merge, cleanup, etc.)
            complete_ralph_loop "$N_WT" "$RUN_ID"
        } >> "$RALPH_TMP_DIR/completion-${RUN_ID}.log" 2>&1 &

        disown
        log_info "Completion handler running in background (PID: $!)"
        log_info "View completion log: tail -f $RALPH_TMP_DIR/completion-${RUN_ID}.log"
        exit 0
    fi

    # DEBUG mode: watch logs in foreground
    log_info "DEBUG mode enabled - watching logs (Ctrl+C to exit, worktrees continue)..."
    watch_all_logs

    # Wait for completion
    wait_and_monitor

    # Complete the Ralph loop
    complete_ralph_loop "$N_WT" "$RUN_ID"
}

# Complete Ralph loop: review, score, merge, cleanup
complete_ralph_loop() {
    local N_WT="$1"
    local RUN_ID="$2"

    # Review LEARNINGS.md in all worktrees (compound engineering - cleanup before scoring/merge)
    log_info "Reviewing LEARNINGS.md in all worktrees..."
    for i in $(seq 1 $N_WT); do
        local worktree_path=$(get_worktree_path "$i" "$RUN_ID" "$N_WT")
        local learnings_file="$worktree_path/$RALPH_LEARNINGS_FILE"

        if [[ -f "$learnings_file" ]]; then
            log_info "Reviewing LEARNINGS.md in worktree $i..."
            (
                cd "$worktree_path"
                if echo "/review-learnings" | claude -p --model "$RALPH_DEFAULT_MODEL" --dangerously-skip-permissions 2>&1 | tee "$RALPH_TMP_DIR/review_learnings_wt${i}.log"; then
                    # Commit changes if any
                    if ! git diff --quiet "$RALPH_LEARNINGS_FILE" 2>/dev/null; then
                        git add "$RALPH_LEARNINGS_FILE"
                        git commit -m "docs(ralph): review and prune LEARNINGS.md"
                    fi
                fi
            ) || log_warn "LEARNINGS.md review failed in worktree $i (non-critical)"
        fi
    done

    # Select and merge best result
    local best_wt
    if [ "$N_WT" -eq 1 ]; then
        # N_WT=1: Skip scoring overhead, use the only worktree
        log_info "Single worktree mode - merging worktree 1..."
        best_wt=1
    else
        # N_WT>1: Try judge first, fall back to metrics
        if [ "${RALPH_JUDGE_ENABLED:-false}" = "true" ]; then
            # Get metrics baseline for transparency
            local metrics_winner=$(select_best "$RUN_ID" "$N_WT")
            log_info "Metrics selected worktree $metrics_winner"

            # Try judge evaluation
            local judge_winner=$(judge_worktrees "$RUN_ID" "$N_WT")
            if [ $? -ne 0 ] || [ -z "$judge_winner" ]; then
                log_info "Falling back to quantitative metrics..."
                best_wt="$metrics_winner"
            else
                # Use judge result
                best_wt="$judge_winner"
                if [ "$judge_winner" != "$metrics_winner" ]; then
                    log_warn "Judge ($judge_winner) disagrees with metrics ($metrics_winner)"
                fi
            fi
        else
            best_wt=$(select_best "$RUN_ID" "$N_WT")
        fi
    fi

    # Optional security review before merge
    if [ "${RALPH_SECURITY_REVIEW:-false}" = "true" ]; then
        log_info "Running security review on worktree $best_wt..."
        local worktree_path=$(get_worktree_path "$best_wt" "$RUN_ID" "$N_WT")
        (cd "$worktree_path" && claude -p '/security-review' --dangerously-skip-permissions 2>&1 | tee $RALPH_TMP_DIR/security_review.log) || \
            log_warn "Security review completed with findings - check $RALPH_TMP_DIR/security_review.log"
    fi

    if merge_best "$best_wt" "$N_WT" "$RUN_ID"; then
        log_info "Success! Best result merged from worktree $best_wt"
        # Cleanup worktrees after successful completion
        cleanup_worktrees
    else
        log_error "Merge failed - manual intervention required"
        # On merge failure, unlock but preserve worktrees for debugging
        unlock_worktrees
        exit 1
    fi
}

# Handle command-line actions
case "${1:-run}" in
    status)
        show_all_status
        ;;
    watch)
        watch_all_logs
        ;;
    log)
        show_worktree_log "${2:-1}"
        ;;
    stop)
        stop_parallel
        ;;
    clean)
        cleanup_worktrees
        ;;
    *)
        main "$1" "$2"
        ;;
esac
