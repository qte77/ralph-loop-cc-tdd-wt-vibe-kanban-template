#!/usr/bin/env bats
# Cost-cap tests for issue #90 item 3:
# - RALPH_COST_LIMIT, when set, becomes --max-budget-usd on every claude -p call
# - unset RALPH_COST_LIMIT keeps today's behavior (no flag, no cap)
# Run from project root: bats ralph/scripts/tests/test_cost_cap.bats

setup() {
    export BATS_TEST_TMP_DIR="$(mktemp -d)"
}

teardown() {
    [ -d "$BATS_TEST_TMP_DIR" ] && rm -rf "$BATS_TEST_TMP_DIR"
}

@test "claude_budget_flags is empty when RALPH_COST_LIMIT is unset" {
    unset RALPH_COST_LIMIT
    source ralph/scripts/lib/common.sh
    run claude_budget_flags
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "claude_budget_flags is empty when RALPH_COST_LIMIT is blank" {
    export RALPH_COST_LIMIT=""
    source ralph/scripts/lib/common.sh
    run claude_budget_flags
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "claude_budget_flags emits --max-budget-usd when RALPH_COST_LIMIT is set" {
    export RALPH_COST_LIMIT="2.50"
    source ralph/scripts/lib/common.sh
    run claude_budget_flags
    [ "$status" -eq 0 ]
    [ "$output" = "--max-budget-usd 2.50" ]
}

@test "config.sh defaults RALPH_COST_LIMIT to unset (no cap)" {
    unset RALPH_COST_LIMIT
    SRC_PACKAGE_DIR="test" source ralph/scripts/lib/config.sh
    [ -z "${RALPH_COST_LIMIT:-}" ]
}

@test "ralph.sh execute_story/fix_validation_errors route the budget flag through build_claude_extra_flags" {
    grep -q 'claude_budget_flags' ralph/scripts/ralph.sh
}

@test "ralph.sh compress_progress call includes the budget flag" {
    grep -B2 -A2 'compress_prompt" | claude -p --model haiku' ralph/scripts/ralph.sh | grep -q 'claude_budget_flags'
}

@test "parallel_ralph.sh review-learnings call includes the budget flag" {
    grep -B2 -A2 'review-learnings" | claude -p' ralph/scripts/parallel_ralph.sh | grep -q 'claude_budget_flags'
}

@test "parallel_ralph.sh security-review call includes the budget flag" {
    grep -B2 -A2 "'/security-review'" ralph/scripts/parallel_ralph.sh | grep -q 'claude_budget_flags'
}

@test "judge.sh claude call includes the budget flag" {
    grep -q 'claude_budget_flags' ralph/scripts/lib/judge.sh
}
