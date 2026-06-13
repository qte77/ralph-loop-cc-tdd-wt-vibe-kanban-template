#!/usr/bin/env bats

# Test vibe.sh JSON payload construction
# Tests acceptance criteria for STORY-006

setup() {
    # Create isolated tmp directory for this test
    export BATS_TEST_TMP_DIR="$(mktemp -d)"
    export RALPH_TMP_DIR="$BATS_TEST_TMP_DIR"
}

teardown() {
    # Clean up test tmp directory
    [ -d "$BATS_TEST_TMP_DIR" ] && rm -rf "$BATS_TEST_TMP_DIR"
}

# Helper to test kanban_update JSON payload by extracting it
_test_kanban_update_json() {
    local status=$1
    local reason="${2:-}"

    # Setup environment
    export RALPH_VIBE_PORT=5173
    export RALPH_RUN_ID="test-run"
    export WORKTREE_NUM=1
    export STORY_ATTEMPT_NUM=1
    export VIBE_URL="http://localhost:5173"
    export KANBAN_MAP="$BATS_TEST_TMP_DIR/kanban_map"

    # Create kanban map
    echo "1:STORY-001=task-123" > "$KANBAN_MAP"

    # Create a test script that sources vibe.sh and calls kanban_update
    # We'll capture the curl call's -d argument
    local test_script="$BATS_TEST_TMP_DIR/test_kanban.sh"
    cat > "$test_script" << 'TESTEOF'
#!/bin/bash
source "ralph/scripts/lib/vibe.sh"

# Mock curl to capture the payload
curl() {
    # Find and output the JSON payload from -d argument
    local in_payload=0
    for arg in "$@"; do
        if [ "$in_payload" = "1" ]; then
            echo "$arg"
            return 0
        fi
        if [ "$arg" = "-d" ]; then
            in_payload=1
        fi
    done
    return 0
}
export -f curl

# Call kanban_update with the provided arguments
kanban_update "$@"
TESTEOF
    chmod +x "$test_script"

    # Run the test script
    bash "$test_script" "STORY-001" "$status" "$reason"
}

@test "kanban_update: builds valid JSON with double quotes in reason" {
    local json_output=$(_test_kanban_update_json "done" 'reason with "quotes"')

    # Validate it's valid JSON
    echo "$json_output" | jq . >/dev/null 2>&1
    [ $? -eq 0 ] || {
        echo "Invalid JSON: $json_output"
        return 1
    }
}

@test "kanban_update: builds valid JSON with newlines in reason" {
    local json_output=$(_test_kanban_update_json "done" $'line1\nline2\nline3')

    # Validate it's valid JSON
    echo "$json_output" | jq . >/dev/null 2>&1
    [ $? -eq 0 ] || {
        echo "Invalid JSON: $json_output"
        return 1
    }
}

@test "kanban_update: builds valid JSON with backslashes in reason" {
    local json_output=$(_test_kanban_update_json "done" 'path\\with\\backslashes')

    # Validate it's valid JSON
    echo "$json_output" | jq . >/dev/null 2>&1
    [ $? -eq 0 ] || {
        echo "Invalid JSON: $json_output"
        return 1
    }
}

@test "kanban_update: builds valid JSON with mixed special characters" {
    local json_output=$(_test_kanban_update_json "done" $'reason with "quotes", \\backslashes, and\nnewlines')

    # Validate it's valid JSON
    echo "$json_output" | jq . >/dev/null 2>&1
    [ $? -eq 0 ] || {
        echo "Invalid JSON: $json_output"
        return 1
    }
}

@test "kanban_update: preserves required payload fields" {
    local json_output=$(_test_kanban_update_json "done" "test reason")

    # Verify required fields exist and have correct types
    local status=$(echo "$json_output" | jq -r '.status')
    [ "$status" = "done" ]

    # Verify boolean fields
    echo "$json_output" | jq '.has_in_progress_attempt' | grep -q "false"
    echo "$json_output" | jq '.last_attempt_failed' | grep -q "false"

    # Verify executor field
    local executor=$(echo "$json_output" | jq -r '.executor')
    [[ "$executor" == *"ralph-loop:test-run:WT1"* ]]

    # Verify notes field
    echo "$json_output" | jq '.notes' | grep -q "test reason"
}
