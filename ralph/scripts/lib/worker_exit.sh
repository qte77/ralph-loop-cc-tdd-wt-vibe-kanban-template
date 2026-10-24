#!/bin/bash
#
# Worker exit-status handoff for parallel Ralph runs.
#
# Workers are disowned, so `wait` can't read their exit status. Each worker
# writes its status to a file in its worktree, and the poll loop reads it back.
#

RALPH_EXIT_FILE=".ralph_exit"

# Run a command and record its exit status in <worktree>/$RALPH_EXIT_FILE.
# Usage: run_and_record_exit <worktree_path> <cmd> [args...]
# Returns: the command's exit status
run_and_record_exit() {
    local worktree_path="$1"
    shift
    local rc=0
    "$@" || rc=$?
    echo "$rc" > "$worktree_path/$RALPH_EXIT_FILE"
    return "$rc"
}

# Print the exit status a worker recorded in its worktree.
# A missing or corrupt file means the worker died before reporting: prints 1.
# Usage: read_worktree_exit_code <worktree_path>
read_worktree_exit_code() {
    local code
    code=$(cat "$1/$RALPH_EXIT_FILE" 2>/dev/null || true)
    if [[ "$code" =~ ^[0-9]+$ ]]; then
        echo "$code"
    else
        echo 1
    fi
}
