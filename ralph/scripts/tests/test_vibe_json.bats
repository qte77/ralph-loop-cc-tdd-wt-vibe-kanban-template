#!/usr/bin/env bats
# STORY-006: kanban_update must send valid JSON whatever the reason text holds. It used to build
# the payload by string concatenation with sed escaping only `"`, so a backslash or a newline in
# the reason produced invalid JSON. curl is stubbed to capture the payload.
# Run from project root: bats ralph/scripts/tests/test_vibe_json.bats
# shellcheck disable=SC2034  # VIBE_URL, WORKTREE_NUM, RALPH_RUN_ID are read by kanban_update

setup() {
    BATS_TEST_TMP_DIR="$(mktemp -d)"
    export BATS_TEST_TMP_DIR
    mkdir -p "$BATS_TEST_TMP_DIR/bin"
    cat > "$BATS_TEST_TMP_DIR/bin/curl" <<'STUB'
#!/usr/bin/env bash
while [ $# -gt 0 ]; do
    if [ "$1" = "-d" ]; then printf '%s' "$2" > "$BATS_TEST_TMP_DIR/payload.json"; shift; fi
    shift
done
STUB
    chmod +x "$BATS_TEST_TMP_DIR/bin/curl"
    export PATH="$BATS_TEST_TMP_DIR/bin:$PATH"
    # shellcheck source=ralph/scripts/lib/vibe.sh
    source ralph/scripts/lib/vibe.sh
    VIBE_URL="http://127.0.0.1:1"
    KANBAN_MAP="$BATS_TEST_TMP_DIR/map"
    echo "1:STORY-001=task-42" > "$KANBAN_MAP"
    WORKTREE_NUM=1
    RALPH_RUN_ID=run7
    unset STORY_ATTEMPT_NUM
}

teardown() {
    [ -d "$BATS_TEST_TMP_DIR" ] && rm -rf "$BATS_TEST_TMP_DIR"
}

@test "a reason with quotes, backslashes and a newline gives valid JSON with the exact text" {
    reason=$'say "hi" to C:\\temp\nand it\'s done'
    kanban_update STORY-001 todo "$reason" 2>/dev/null
    jq -e . "$BATS_TEST_TMP_DIR/payload.json" > /dev/null
    [ "$(jq -r .notes "$BATS_TEST_TMP_DIR/payload.json")" = "$reason" ]
}

@test "payload keeps the same keys and values" {
    STORY_ATTEMPT_NUM=3 kanban_update STORY-001 todo "failed" 2>/dev/null
    run jq -c . "$BATS_TEST_TMP_DIR/payload.json"
    [ "$output" = '{"status":"todo","has_in_progress_attempt":false,"last_attempt_failed":true,"executor":"ralph-loop:run7:WT1","attempt_count":3,"notes":"failed"}' ]
}

@test "without a reason or attempt number the optional keys are left out" {
    kanban_update STORY-001 inprogress 2>/dev/null
    run jq -c . "$BATS_TEST_TMP_DIR/payload.json"
    [ "$output" = '{"status":"inprogress","has_in_progress_attempt":true,"last_attempt_failed":false,"executor":"ralph-loop:run7:WT1"}' ]
}
