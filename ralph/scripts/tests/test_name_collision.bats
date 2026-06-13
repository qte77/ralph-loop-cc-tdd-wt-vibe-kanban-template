#!/usr/bin/env bats
# BATS tests for function name collision fix
# Tests acceptance criteria for STORY-004

load test_helper/common-setup

setup() {
    export BATS_TEST_TMP_DIR="$(mktemp -d)"
    export RALPH_TMP_DIR="$BATS_TEST_TMP_DIR"
    export RALPH_LEARNINGS_FILE="$BATS_TEST_TMP_DIR/learnings.md"
    export RALPH_REQUESTS_FILE="$BATS_TEST_TMP_DIR/requests.md"
    export RALPH_PROGRESS_FILE="$BATS_TEST_TMP_DIR/progress.txt"
    export RALPH_PRD_JSON="$BATS_TEST_TMP_DIR/prd.json"
    export RALPH_PROMPT_FILE="$BATS_TEST_TMP_DIR/prompt.md"
    export RALPH_LOOP_LOG_DIR="$BATS_TEST_TMP_DIR/logs"

    touch "$RALPH_LEARNINGS_FILE" "$RALPH_REQUESTS_FILE" "$RALPH_PROGRESS_FILE" "$RALPH_PROMPT_FILE"
    create_mock_prd "$RALPH_PRD_JSON"
    mkdir -p "$RALPH_LOOP_LOG_DIR"

    export PATH="$BATS_TEST_TMP_DIR:${PATH}"
}

teardown() {
    [ -d "$BATS_TEST_TMP_DIR" ] && rm -rf "$BATS_TEST_TMP_DIR"
}

@test "verify_teammate_stories resolves to teams.sh version when both are sourced" {
    source ralph/scripts/lib/common.sh
    source ralph/scripts/lib/config.sh
    source ralph/scripts/lib/adapter.sh
    source ralph/scripts/lib/validate_json.sh
    source ralph/scripts/lib/generate_app_docs.sh
    source ralph/scripts/lib/vibe.sh

    # Source ralph.sh first, then teams.sh (teams.sh must win)
    source ralph/scripts/ralph.sh
    source ralph/scripts/lib/teams.sh

    # verify_teammate_stories should resolve to teams.sh version
    # Teams.sh version accepts $1=primary_id, $2=commits_before, $3=teammate_stories
    # We check the function signature by inspecting its definition
    local fn_def
    fn_def=$(declare -f verify_teammate_stories)

    # The teams.sh version uses "primary_id" and "commits_before" parameters
    [[ "$fn_def" == *"primary_id"* ]] || fail "verify_teammate_stories should be teams.sh version (uses primary_id)"
    [[ "$fn_def" == *"commits_before"* ]] || fail "verify_teammate_stories should be teams.sh version (uses commits_before)"
}

@test "verify_prd_isolation exists and is the ralph.sh isolation check" {
    source ralph/scripts/lib/common.sh
    source ralph/scripts/lib/config.sh
    source ralph/scripts/lib/adapter.sh
    source ralph/scripts/lib/validate_json.sh
    source ralph/scripts/lib/generate_app_docs.sh
    source ralph/scripts/lib/vibe.sh

    source ralph/scripts/ralph.sh
    source ralph/scripts/lib/teams.sh

    # verify_prd_isolation should exist (ralph.sh version renamed)
    declare -f verify_prd_isolation > /dev/null 2>&1 || fail "verify_prd_isolation not defined — ralph.sh version was not renamed"

    # The ralph.sh version checks prd.json isolation (uses story_id and base_commit)
    local fn_def
    fn_def=$(declare -f verify_prd_isolation)
    [[ "$fn_def" == *"story_id"* ]] || fail "verify_prd_isolation should contain story_id param"
    [[ "$fn_def" == *"base_commit"* ]] || fail "verify_prd_isolation should contain base_commit param"
}
