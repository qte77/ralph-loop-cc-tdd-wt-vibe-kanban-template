#!/usr/bin/env bats
# Resume tests for issue #90 item 5:
# - execute_story() gets a fresh --session-id per story execution
# - that session id is recorded in progress.txt so a crashed/interrupted
#   story can be resumed with `claude -p --resume <uuid>`
# - get_next_story() already skips stories marked "passed" (the resume
#   mechanism for completed steps) — exercised directly here against the
#   exact jq filter ralph.sh uses, since ralph.sh has no main guard and
#   cannot be sourced without running the whole loop
# Run from project root: bats ralph/scripts/tests/test_resume.bats

setup() {
    BATS_TEST_TMP_DIR="$(mktemp -d)"
    export BATS_TEST_TMP_DIR
    # shellcheck source=ralph/scripts/lib/common.sh
    source ralph/scripts/lib/common.sh
}

teardown() {
    [ -d "$BATS_TEST_TMP_DIR" ] && rm -rf "$BATS_TEST_TMP_DIR"
}

@test "ralph_new_session_id returns a well-formed UUID" {
    run ralph_new_session_id
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]
}

@test "ralph_new_session_id returns a fresh id on each call" {
    first=$(ralph_new_session_id)
    second=$(ralph_new_session_id)
    [ -n "$first" ]
    [ -n "$second" ]
    [ "$first" != "$second" ]
}

@test "execute_story passes --session-id to the claude call" {
    awk '/^execute_story\(\)/{flag=1} flag{print} flag && /^}/{exit}' ralph/scripts/ralph.sh \
        | grep -q -- '--session-id'
}

@test "execute_story generates the session id via ralph_new_session_id" {
    grep -q 'STORY_SESSION_ID=.*ralph_new_session_id' ralph/scripts/ralph.sh
}

@test "log_progress writes a Session line when given a session id" {
    PROGRESS_FILE="$BATS_TEST_TMP_DIR/progress.txt"

    # Minimal stand-in for ralph.sh's log_progress (same body, isolated so we
    # don't have to source the whole script and run main()).
    log_progress() {
        local iteration="$1" story_id="$2" status="$3" notes="$4" session_id="${5:-}"
        {
            echo "## Iteration $iteration - $(date)"
            echo "Story: $story_id"
            if [ -n "$session_id" ]; then
                echo "Session: $session_id"
            fi
            echo "Status: $status"
            echo "Notes: $notes"
            echo ""
        } >> "$PROGRESS_FILE"
    }

    log_progress 1 "STORY-001" "PASS" "ok" "11111111-1111-1111-1111-111111111111"
    grep -q "Session: 11111111-1111-1111-1111-111111111111" "$PROGRESS_FILE"
}

@test "ralph.sh's log_progress signature accepts a 5th session_id argument" {
    grep -A10 '^log_progress()' ralph/scripts/ralph.sh | grep -q 'session_id='
}

@test "ralph.sh's log_progress calls pass the story's session id" {
    grep -q 'log_progress .*STORY_SESSION_ID' ralph/scripts/ralph.sh
}

@test "get_next_story's jq filter skips stories already marked passed (resume)" {
    cat > "$BATS_TEST_TMP_DIR/prd.json" <<'EOF'
{
  "stories": [
    {"id": "STORY-001", "status": "passed"},
    {"id": "STORY-002", "status": "pending"}
  ]
}
EOF
    run jq -r '.stories[] | select(.status != "passed") | .id' "$BATS_TEST_TMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    [ "$output" = "STORY-002" ]
}

@test "ralph.sh's get_next_story uses that same status != passed filter" {
    grep -q 'select(.status != "passed")' ralph/scripts/ralph.sh
}
