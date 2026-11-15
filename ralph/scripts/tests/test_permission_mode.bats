#!/usr/bin/env bats
# Permission-mode + deny-rule tests for issue #90 item 2:
# - every claude -p call uses --permission-mode (RALPH_PERMISSION_MODE,
#   default "auto") + --permission-prompts none instead of
#   --dangerously-skip-permissions
# - the process-matching greps in watch.sh / stop_ralph_processes.sh are
#   updated to the new flag so `make ralph_watch`/`ralph_stop` still work
# - .claude/settings.json carries permissions.deny for git push / PR merge /
#   history-rewrite, in the space form that actually matches
# Run from project root: bats ralph/scripts/tests/test_permission_mode.bats

setup() {
    export BATS_TEST_TMP_DIR="$(mktemp -d)"
}

teardown() {
    [ -d "$BATS_TEST_TMP_DIR" ] && rm -rf "$BATS_TEST_TMP_DIR"
}

@test "claude_permission_flags defaults to --permission-mode auto --permission-prompts none" {
    unset RALPH_PERMISSION_MODE
    source ralph/scripts/lib/common.sh
    run claude_permission_flags
    [ "$status" -eq 0 ]
    [ "$output" = "--permission-mode auto --permission-prompts none" ]
}

@test "claude_permission_flags honors RALPH_PERMISSION_MODE override" {
    export RALPH_PERMISSION_MODE="bypassPermissions"
    source ralph/scripts/lib/common.sh
    run claude_permission_flags
    [ "$status" -eq 0 ]
    [ "$output" = "--permission-mode bypassPermissions --permission-prompts none" ]
}

@test "config.sh defaults RALPH_PERMISSION_MODE to auto" {
    unset RALPH_PERMISSION_MODE
    SRC_PACKAGE_DIR="test" source ralph/scripts/lib/config.sh
    [ "$RALPH_PERMISSION_MODE" = "auto" ]
}

@test "no --dangerously-skip-permissions left in ralph.sh, parallel_ralph.sh, or judge.sh" {
    ! grep -rn 'dangerously-skip-permissions' \
        ralph/scripts/ralph.sh ralph/scripts/parallel_ralph.sh ralph/scripts/lib/judge.sh
}

@test "ralph.sh claude calls route through claude_permission_flags" {
    count=$(grep -c 'claude_permission_flags' ralph/scripts/ralph.sh)
    [ "$count" -ge 3 ]
}

@test "parallel_ralph.sh claude calls route through claude_permission_flags" {
    count=$(grep -c 'claude_permission_flags' ralph/scripts/parallel_ralph.sh)
    [ "$count" -ge 2 ]
}

@test "judge.sh claude call routes through claude_permission_flags" {
    grep -q 'claude_permission_flags' ralph/scripts/lib/judge.sh
}

@test "watch.sh process match no longer depends on dangerously-skip-permissions" {
    ! grep -q 'dangerously-skip-permissions' ralph/scripts/watch.sh
    grep -q 'permission-prompts' ralph/scripts/watch.sh
}

@test "stop_ralph_processes.sh process match no longer depends on dangerously-skip-permissions" {
    ! grep -q 'dangerously-skip-permissions' ralph/scripts/lib/stop_ralph_processes.sh
    grep -q 'permission-prompts' ralph/scripts/lib/stop_ralph_processes.sh
}

@test ".claude/settings.json permissions.deny blocks git push" {
    run jq -r '.permissions.deny[]' .claude/settings.json
    [[ "$output" == *"Bash(git push:*)"* ]]
}

@test ".claude/settings.json permissions.deny blocks gh pr merge" {
    run jq -r '.permissions.deny[]' .claude/settings.json
    [[ "$output" == *"Bash(gh pr merge:*)"* ]]
}

@test ".claude/settings.json permissions.deny has no dead colon-form rules" {
    # Every entry must be Bash(<prefix with no colon>:*) — a colon anywhere
    # before the trailing ":*)" (e.g. Bash(git:push:*)) never matches a real
    # command and is dead.
    run bash -c "jq -r '.permissions.deny[]' .claude/settings.json | grep -vE '^Bash\([^:]+:\*\)\$'"
    [ "$status" -ne 0 ]
    [ -z "$output" ]
}

@test ".claude/settings.json is valid JSON" {
    run jq -e . .claude/settings.json
    [ "$status" -eq 0 ]
}
