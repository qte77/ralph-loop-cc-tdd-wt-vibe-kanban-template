#!/bin/bash
# Cleanup all Ralph worktrees and branches
# Can be sourced or called directly

# Get script directory for sourcing dependencies
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source dependencies if not already loaded
if ! command -v log_info &> /dev/null; then
    source "$_LIB_DIR/common.sh"
fi

if [ -z "${RALPH_PARALLEL_WORKTREE_PREFIX:-}" ]; then
    source "$_LIB_DIR/config.sh"
fi

cleanup_worktrees() {
    log_info "Cleaning up worktrees..."

    # Find all ralph worktrees and clean them
    local worktree_list=$(git worktree list | grep "$RALPH_PARALLEL_WORKTREE_PREFIX" || true)

    if [ -z "$worktree_list" ]; then
        log_info "No worktrees found to clean"
    else
        echo "$worktree_list" | awk '{print $1}' | while read worktree_path; do
            # Extract worktree number from path
            # Format: ${PREFIX}-${RUN_ID} (N_WT=1) or ${PREFIX}-${RUN_ID}-${NUM} (N_WT>1)
            # Examples: ../your_project_name-ralph-wt-41adf4 → 1
            #           ../your_project_name-ralph-wt-41adf4-2 → 2
            local basename_wt=$(basename "$worktree_path")
            local wt_num

            # Check if path ends with -${NUM} (N_WT>1 case)
            if [[ "$basename_wt" =~ -([0-9]+)$ ]]; then
                wt_num="${BASH_REMATCH[1]}"
            else
                # No number suffix, must be N_WT=1 case
                wt_num="1"
            fi

            local branch_name="${RALPH_PARALLEL_BRANCH_PREFIX}-${wt_num}"

            # Remove sentinel file if it exists
            [ -f "$worktree_path/.ralph-exit-code" ] && rm "$worktree_path/.ralph-exit-code" 2>/dev/null || true

            log_info "Removing worktree $wt_num at $worktree_path..."
            git worktree unlock "$worktree_path" 2>/dev/null || true
            git worktree remove "$worktree_path" --force 2>/dev/null || true
            git branch -D "$branch_name" 2>/dev/null || true
        done
    fi

    # Cleanup orphaned branches (branches without worktrees - e.g., from failed creation)
    local orphaned_branches=$(git branch --list "${RALPH_PARALLEL_BRANCH_PREFIX}-*" | sed 's/^[* ]*//' || true)
    if [ -n "$orphaned_branches" ]; then
        log_info "Removing orphaned branches..."
        echo "$orphaned_branches" | while read branch; do
            [ -z "$branch" ] && continue
            git branch -D "$branch" 2>/dev/null && log_info "  Removed: $branch" || true
        done
    fi

    log_info "Cleanup completed"
}

# If called directly (not sourced), run cleanup
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    cleanup_worktrees
fi
