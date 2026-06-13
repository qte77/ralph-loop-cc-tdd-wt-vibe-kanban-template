#!/usr/bin/env bats
# BATS tests for get_next_story O(n*d) → O(1) refactor
# Tests acceptance criteria for STORY-007

load test_helper/common-setup

setup() {
    export BATS_TEST_TMP_DIR="$(mktemp -d)"
    export RALPH_TMP_DIR="$BATS_TEST_TMP_DIR"
    export PRD_JSON="$BATS_TEST_TMP_DIR/prd.json"
    export RALPH_PRD_JSON="$PRD_JSON"
    export RALPH_LEARNINGS_FILE="$BATS_TEST_TMP_DIR/learnings.md"
    export RALPH_REQUESTS_FILE="$BATS_TEST_TMP_DIR/requests.md"
    export RALPH_PROGRESS_FILE="$BATS_TEST_TMP_DIR/progress.txt"
    export RALPH_PROMPT_FILE="$BATS_TEST_TMP_DIR/prompt.md"
    export RALPH_LOOP_LOG_DIR="$BATS_TEST_TMP_DIR/logs"
    touch "$RALPH_LEARNINGS_FILE" "$RALPH_REQUESTS_FILE" "$RALPH_PROGRESS_FILE" "$RALPH_PROMPT_FILE"
    mkdir -p "$RALPH_LOOP_LOG_DIR"
    export JQ_CALL_COUNT_FILE="$BATS_TEST_TMP_DIR/jq_call_count"
    echo 0 > "$JQ_CALL_COUNT_FILE"

    # Extract get_next_story function from ralph.sh (safe: no main execution)
    awk '/^get_next_story\(\)/,/^}$/' ralph/scripts/ralph.sh \
        > "$BATS_TEST_TMP_DIR/get_next_story.sh"
}

teardown() {
    [ -d "$BATS_TEST_TMP_DIR" ] && rm -rf "$BATS_TEST_TMP_DIR"
}

# Create a prd.json with 10 stories and a linear dependency chain
_create_10_story_prd() {
    cat > "$PRD_JSON" << 'EOF'
{
  "project": "Test Project",
  "description": "10-story PRD for scheduling tests",
  "source": "test",
  "generated": "2026-03-25T00:00:00Z",
  "stories": [
    {"id": "STORY-001", "title": "First",         "depends_on": [],             "status": "passed",  "wave": 1},
    {"id": "STORY-002", "title": "Dep on 001",    "depends_on": ["STORY-001"], "status": "passed",  "wave": 2},
    {"id": "STORY-003", "title": "Dep on 002",    "depends_on": ["STORY-002"], "status": "pending", "wave": 3},
    {"id": "STORY-004", "title": "Dep on 003",    "depends_on": ["STORY-003"], "status": "pending", "wave": 4},
    {"id": "STORY-005", "title": "Dep on 004",    "depends_on": ["STORY-004"], "status": "pending", "wave": 5},
    {"id": "STORY-006", "title": "Dep on 005",    "depends_on": ["STORY-005"], "status": "pending", "wave": 6},
    {"id": "STORY-007", "title": "Dep on 006",    "depends_on": ["STORY-006"], "status": "pending", "wave": 7},
    {"id": "STORY-008", "title": "Dep on 007",    "depends_on": ["STORY-007"], "status": "pending", "wave": 8},
    {"id": "STORY-009", "title": "Dep on 008",    "depends_on": ["STORY-008"], "status": "pending", "wave": 9},
    {"id": "STORY-010", "title": "Dep on 009",    "depends_on": ["STORY-009"], "status": "pending", "wave": 10}
  ]
}
EOF
}

@test "get_next_story returns first unblocked story in dependency chain" {
    _create_10_story_prd
    source ralph/scripts/lib/common.sh
    source ralph/scripts/lib/config.sh
    source ralph/scripts/lib/teams.sh
    source "$BATS_TEST_TMP_DIR/get_next_story.sh"

    run get_next_story
    [ "$status" -eq 0 ]
    [ "$output" = "STORY-003" ]
}

@test "get_next_story returns empty string when all stories passed" {
    cat > "$PRD_JSON" << 'EOF'
{
  "project": "Test",
  "stories": [
    {"id": "STORY-001", "depends_on": [], "status": "passed"},
    {"id": "STORY-002", "depends_on": ["STORY-001"], "status": "passed"}
  ]
}
EOF
    source ralph/scripts/lib/common.sh
    source ralph/scripts/lib/config.sh
    source ralph/scripts/lib/teams.sh
    source "$BATS_TEST_TMP_DIR/get_next_story.sh"

    run get_next_story
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "get_next_story never returns a blocked story" {
    cat > "$PRD_JSON" << 'EOF'
{
  "project": "Test",
  "stories": [
    {"id": "STORY-001", "depends_on": [],             "status": "pending"},
    {"id": "STORY-002", "depends_on": ["STORY-001"], "status": "pending"}
  ]
}
EOF
    source ralph/scripts/lib/common.sh
    source ralph/scripts/lib/config.sh
    source ralph/scripts/lib/teams.sh
    source "$BATS_TEST_TMP_DIR/get_next_story.sh"

    run get_next_story
    [ "$status" -eq 0 ]
    [ "$output" = "STORY-001" ]
    [[ "$output" != *"STORY-002"* ]]
}

@test "get_next_story uses O(1) jq invocations for 10-story dependency chain" {
    _create_10_story_prd

    # Instrument jq to count subprocess invocations
    local jq_stub="$BATS_TEST_TMP_DIR/jq"
    cat > "$jq_stub" << STUBEOF
#!/usr/bin/env bash
count=\$(cat "$JQ_CALL_COUNT_FILE")
echo \$((count + 1)) > "$JQ_CALL_COUNT_FILE"
exec /usr/bin/jq "\$@"
STUBEOF
    chmod +x "$jq_stub"
    export PATH="$BATS_TEST_TMP_DIR:$PATH"

    source ralph/scripts/lib/common.sh
    source ralph/scripts/lib/config.sh
    source ralph/scripts/lib/teams.sh
    source "$BATS_TEST_TMP_DIR/get_next_story.sh"

    # Reset counter after sourcing (sourcing may trigger jq calls)
    echo 0 > "$JQ_CALL_COUNT_FILE"

    run get_next_story
    [ "$status" -eq 0 ]
    [ "$output" = "STORY-003" ]

    local jq_calls
    jq_calls=$(cat "$JQ_CALL_COUNT_FILE")
    # O(1): get_unblocked_stories uses ≤2 jq calls total
    # O(n*d): old loop makes ≥10 calls for 10 stories (1 per story + 1 per dep)
    [ "$jq_calls" -le 2 ]
}

@test "get_next_story delegates to get_unblocked_stories in ralph.sh" {
    # Inspect the source of get_next_story in ralph.sh (no execution needed)
    local fn_body
    fn_body=$(awk '/^get_next_story\(\)/,/^}$/' ralph/scripts/ralph.sh)
    echo "$fn_body" | grep -q "get_unblocked_stories" \
        || { echo "get_next_story should call get_unblocked_stories but does not"; return 1; }
}
