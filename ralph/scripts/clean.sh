#!/bin/bash
# Cleans Ralph state (worktrees + local state files)
set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source libraries
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/cleanup_worktrees.sh"

# Check for worktrees
worktree_count=$(git worktree list | grep "$RALPH_PARALLEL_WORKTREE_PREFIX" | wc -l || true)

# Check for local state files
STATE_FILES=("$RALPH_DOCS_DIR/prd.json" "$RALPH_DOCS_DIR/progress.txt")
state_count=0
for file in "${STATE_FILES[@]}"; do
    if [ -f "$file" ]; then
        state_count=$((state_count + 1))
    fi
done

# If nothing to clean
if [ "$worktree_count" -eq 0 ] && [ "$state_count" -eq 0 ]; then
    log_info "No Ralph state found to clean."
    exit 0
fi

# Show what can be cleaned
log_warn "Ralph cleanup detected:"
if [ "$worktree_count" -gt 0 ]; then
    echo "  - $worktree_count git worktree(s)"
fi

# Step 1: Ask if cleanup should proceed
echo ""
echo -n "Do you want to proceed with cleanup? (yes/no): "
read confirm_cleanup

if [ "$confirm_cleanup" != "yes" ]; then
    log_info "Cleanup cancelled."
    exit 0
fi

# Step 2: Ask about state files (if they exist)
include_state_files=false
if [ "$state_count" -gt 0 ]; then
    echo ""
    log_warn "Include state files on current branch (prd.json, progress.txt)? (yes/no): "
    read confirm_state_files

    if [ "$confirm_state_files" = "yes" ]; then
        include_state_files=true
    fi
fi

# Step 3: Final confirmation
echo ""
log_warn "Final confirmation required."
echo "This will clean:"
if [ "$worktree_count" -gt 0 ]; then
    echo "  - $worktree_count git worktree(s) and branches"
fi
if [ "$include_state_files" = true ]; then
    echo "  - State files (prd.json, progress.txt)"
fi
echo ""
echo -n "Type 'YES' (uppercase) to proceed: "
read final_confirm

if [ "$final_confirm" != "YES" ]; then
    log_info "Cleanup cancelled."
    exit 0
fi

echo ""
log_info "Proceeding with cleanup..."

# Clean worktrees
if [ "$worktree_count" -gt 0 ]; then
    cleanup_worktrees
    log_success "Worktrees cleaned"
fi

# Clean local state files (if user opted in)
if [ "$include_state_files" = true ]; then
    echo ""
    log_info "Cleaning local state files..."
    for file in "${STATE_FILES[@]}"; do
        if [ -f "$file" ]; then
            rm -f "$file"
            log_info "  Removed: $file"
        fi
    done
    log_success "Local state cleaned"
fi

log_success "Clean complete!"
