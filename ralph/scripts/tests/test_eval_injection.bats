#!/usr/bin/env bats
# BATS tests for eval injection vulnerability fix
# Tests acceptance criteria for STORY-002

# Source test helpers
load test_helper/common-setup

# Stub helper to track command execution
setup() {
    export BATS_TEST_TMP_DIR="$(mktemp -d)"
    export RALPH_TMP_DIR="$BATS_TEST_TMP_DIR"
    export RALPH_LEARNINGS_FILE="$BATS_TEST_TMP_DIR/learnings.md"
    export RALPH_REQUESTS_FILE="$BATS_TEST_TMP_DIR/requests.md"
    export RALPH_PROGRESS_FILE="$BATS_TEST_TMP_DIR/progress.txt"
    export RALPH_PRD_JSON="$BATS_TEST_TMP_DIR/prd.json"
    export RALPH_PROMPT_FILE="$BATS_TEST_TMP_DIR/prompt.md"
    export RALPH_LOOP_LOG_DIR="$BATS_TEST_TMP_DIR/logs"

    # Create basic setup files
    touch "$RALPH_LEARNINGS_FILE" "$RALPH_REQUESTS_FILE" "$RALPH_PROGRESS_FILE" "$RALPH_PROMPT_FILE"
    create_mock_prd "$RALPH_PRD_JSON"
    mkdir -p "$RALPH_LOOP_LOG_DIR"

    # Use test tmp dir in PATH so our stubs are found
    export PATH="$BATS_TEST_TMP_DIR:${PATH}"
}

teardown() {
    [ -d "$BATS_TEST_TMP_DIR" ] && rm -rf "$BATS_TEST_TMP_DIR"
}

@test "execute_story does not execute shell metacharacters in RALPH_INSTRUCTION" {
    source ralph/scripts/lib/common.sh
    source ralph/scripts/lib/config.sh
    source ralph/scripts/lib/adapter.sh
    source ralph/scripts/lib/validate_json.sh
    source ralph/scripts/lib/generate_app_docs.sh
    source ralph/scripts/lib/vibe.sh

    # Create canary file path
    local canary_file="$BATS_TEST_TMP_DIR/canary_execute.txt"

    # Create a stub claude that would execute the injection if eval is used
    # If eval expands the semicolon, it would execute: touch $canary_file
    cat > "$BATS_TEST_TMP_DIR/claude" << 'EOF'
#!/usr/bin/env bash
# Stub that checks if it's being called with injected commands
exit 0
EOF
    chmod +x "$BATS_TEST_TMP_DIR/claude"

    # Set RALPH_INSTRUCTION with shell metacharacters
    export RALPH_INSTRUCTION='; touch '"$canary_file"'; echo injection'

    # Source ralph.sh and call execute_story
    source ralph/scripts/ralph.sh

    # Create required mock prd.json with test story
    create_mock_prd "$RALPH_PRD_JSON"

    # Mock the functions that would fail in test environment
    build_claude_extra_flags() { echo ""; }
    adapter_env_setup() { true; }

    # Get story details
    local details=$(jq -r '.stories[0] | "\(.title)|\(.description)"' "$RALPH_PRD_JSON")

    # Call execute_story with mocked details
    (
        # This will fail because we don't have a full environment,
        # but the key test is whether the canary file gets created
        execute_story "TEST-001" "$details" || true
    ) 2>/dev/null || true

    # The canary file should NOT exist if eval is not being used to expand RALPH_INSTRUCTION
    # (The canary would only be created if eval executed the injected command)
    [ ! -f "$canary_file" ] || fail "Shell metacharacters in RALPH_INSTRUCTION were executed!"
}

@test "fix_validation_errors does not execute shell metacharacters in RALPH_INSTRUCTION" {
    source ralph/scripts/lib/common.sh
    source ralph/scripts/lib/config.sh
    source ralph/scripts/lib/adapter.sh
    source ralph/scripts/lib/validate_json.sh
    source ralph/scripts/lib/generate_app_docs.sh
    source ralph/scripts/lib/vibe.sh

    # Create canary file path
    local canary_file="$BATS_TEST_TMP_DIR/canary_fix.txt"

    # Create a stub claude
    cat > "$BATS_TEST_TMP_DIR/claude" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$BATS_TEST_TMP_DIR/claude"

    # Create a stub error log
    local error_log="$BATS_TEST_TMP_DIR/error.log"
    echo "Test error" > "$error_log"

    # Set RALPH_INSTRUCTION with shell metacharacters that would create a file if eval'd
    export RALPH_INSTRUCTION='; touch '"$canary_file"'; echo injection'

    # Source ralph.sh
    source ralph/scripts/ralph.sh

    # Create required setup
    create_mock_prd "$RALPH_PRD_JSON"

    # Mock helper functions
    build_claude_extra_flags() { echo ""; }
    adapter_env_setup() { true; }
    count_validation_errors() { echo "1"; }

    # Get story details
    local details=$(jq -r '.stories[0] | "\(.title)|\(.description)"' "$RALPH_PRD_JSON")

    # Call fix_validation_errors
    (
        fix_validation_errors "TEST-001" "$details" "$error_log" 1 || true
    ) 2>/dev/null || true

    # Canary should NOT exist if metacharacters weren't executed
    [ ! -f "$canary_file" ] || fail "Shell metacharacters in RALPH_INSTRUCTION were executed in fix_validation_errors!"
}

@test "execute_story with backticks in RALPH_INSTRUCTION does not execute them" {
    source ralph/scripts/lib/common.sh
    source ralph/scripts/lib/config.sh
    source ralph/scripts/lib/adapter.sh
    source ralph/scripts/lib/validate_json.sh
    source ralph/scripts/lib/generate_app_docs.sh
    source ralph/scripts/lib/vibe.sh

    # Create files that would be created if backticks are executed
    local marker_file="$BATS_TEST_TMP_DIR/marker_backticks"

    # Create stub claude
    cat > "$BATS_TEST_TMP_DIR/claude" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$BATS_TEST_TMP_DIR/claude"

    # Set RALPH_INSTRUCTION with backticks and command substitution
    export RALPH_INSTRUCTION="\$(touch $marker_file) command substitution test"

    # Source and mock
    source ralph/scripts/ralph.sh
    create_mock_prd "$RALPH_PRD_JSON"
    build_claude_extra_flags() { echo ""; }
    adapter_env_setup() { true; }

    local details=$(jq -r '.stories[0] | "\(.title)|\(.description)"' "$RALPH_PRD_JSON")

    (
        execute_story "TEST-001" "$details" || true
    ) 2>/dev/null || true

    # Marker file should not be created
    [ ! -f "$marker_file" ] || fail "Backticks/command substitution in RALPH_INSTRUCTION were executed!"
}

@test "build_claude_extra_flags returns space-separated string" {
    source ralph/scripts/ralph.sh

    # Export required env vars
    export RALPH_DESLOPIFY="false"

    # Call function
    local result=$(build_claude_extra_flags)

    # Should be empty string (no flags when DESLOPIFY is false)
    [ -z "$result" ] || [ "$result" = "" ] || fail "Expected empty string, got: $result"
}

@test "build_claude_extra_flags with RALPH_DESLOPIFY returns safe flags" {
    source ralph/scripts/ralph.sh

    # Export required env vars
    export RALPH_DESLOPIFY="true"

    # Call function
    local result=$(build_claude_extra_flags)

    # Should contain flag text (not just empty)
    [[ "$result" == *"append-system-prompt"* ]] || fail "Expected DESLOPIFY flags, got: $result"
}
