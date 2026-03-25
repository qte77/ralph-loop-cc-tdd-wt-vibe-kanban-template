#!/usr/bin/env bats
# BATS tests for scoped checks commit hash fix
# Tests acceptance criteria for STORY-005

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

@test "get_story_base_commit function exists in baseline.sh" {
    source ralph/scripts/lib/common.sh
    source ralph/scripts/lib/adapter.sh
    source ralph/scripts/lib/baseline.sh

    declare -f get_story_base_commit > /dev/null 2>&1 || fail "get_story_base_commit not found in baseline.sh"
}

@test "verify_teammate_stories calls get_story_base_commit before passing to scoped checks" {
    source ralph/scripts/lib/common.sh
    source ralph/scripts/lib/config.sh
    source ralph/scripts/lib/adapter.sh
    source ralph/scripts/lib/validate_json.sh
    source ralph/scripts/lib/generate_app_docs.sh
    source ralph/scripts/lib/vibe.sh
    source ralph/scripts/lib/baseline.sh
    source ralph/scripts/lib/teams.sh

    local fn_def
    fn_def=$(declare -f verify_teammate_stories)

    echo "$fn_def" | grep -q "get_story_base_commit" || fail "verify_teammate_stories should call get_story_base_commit"
}

@test "scoped checks receive commit hash not story ID from verify_teammate_stories" {
    source ralph/scripts/lib/common.sh
    source ralph/scripts/lib/config.sh
    source ralph/scripts/lib/adapter.sh
    source ralph/scripts/lib/validate_json.sh
    source ralph/scripts/lib/generate_app_docs.sh
    source ralph/scripts/lib/vibe.sh
    source ralph/scripts/lib/baseline.sh
    source ralph/scripts/lib/teams.sh

    local fn_def
    fn_def=$(declare -f verify_teammate_stories)

    echo "$fn_def" | grep -q 'run_ruff_scoped "$story_base_commit"' || fail "run_ruff_scoped should receive story_base_commit"
    echo "$fn_def" | grep -q 'run_complexity_scoped "$story_base_commit"' || fail "run_complexity_scoped should receive story_base_commit"
    echo "$fn_def" | grep -q 'run_tests_scoped "$story_base_commit"' || fail "run_tests_scoped should receive story_base_commit"
}
