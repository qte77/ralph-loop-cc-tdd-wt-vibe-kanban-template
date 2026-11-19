#!/usr/bin/env bats
# Compound learning (compound.sh): story-relevant lines from operator-set
# directories of Markdown files are collected into a per-story context file
# that ralph.sh appends to the agent prompt.
#   - the cache hash must change with the story and with the source content,
#     otherwise a later story reuses an earlier story's context
#   - output is capped at COMPOUND_MAX_LINES and only *.md files are read
#   - nothing is read or written when no source directory is configured
#   - source lines are quoted and length-capped, so they cannot open a prompt
#     section or flood the prompt
#   - COMPOUND_ENABLED=false removes a context file left by an earlier run
#   - write-back stays off unless COMPOUND_WRITEBACK_ENABLED=true; when on, it
#     appends only output from a successful call, never fails the caller, and
#     names the target file after the repository, not the worktree directory
# Run from project root: bats ralph/scripts/tests/test_compound.bats

setup() {
    BATS_TEST_TMP_DIR="$(mktemp -d)"
    export BATS_TEST_TMP_DIR
    export RALPH_TMP_DIR="$BATS_TEST_TMP_DIR/tmp"
    mkdir -p "$RALPH_TMP_DIR" "$BATS_TEST_TMP_DIR/learnings" "$BATS_TEST_TMP_DIR/bin" \
        "$BATS_TEST_TMP_DIR/hub"
    # claude stubs written by a test go here and shadow any real claude
    export PATH="$BATS_TEST_TMP_DIR/bin:$PATH"
    unset COMPOUND_ENABLED COMPOUND_LEARNINGS_PATH COMPOUND_MEMORY_PATH COMPOUND_PLANS_PATH \
        COMPOUND_MAX_LINES COMPOUND_WRITEBACK_ENABLED COMPOUND_WRITEBACK_TARGET
    source ralph/scripts/lib/common.sh
    SRC_PACKAGE_DIR="test" source ralph/scripts/lib/config.sh
    source ralph/scripts/lib/compound.sh
}

teardown() {
    [ -d "$BATS_TEST_TMP_DIR" ] && chmod -R u+w "$BATS_TEST_TMP_DIR" && rm -rf "$BATS_TEST_TMP_DIR"
}

# Write-back setup: enabled, hub target, one learning, and a claude stub that
# records its arguments, prints one line and exits with status $1 (default 0)
writeback_setup() {
    cat > "$BATS_TEST_TMP_DIR/bin/claude" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$@" > "$BATS_TEST_TMP_DIR/claude-args"
cat > /dev/null
echo "novel pattern line"
exit ${1:-0}
STUB
    chmod +x "$BATS_TEST_TMP_DIR/bin/claude"
    COMPOUND_WRITEBACK_ENABLED=true
    COMPOUND_WRITEBACK_TARGET="$BATS_TEST_TMP_DIR/hub"
    RALPH_LEARNINGS_FILE="$BATS_TEST_TMP_DIR/LEARNINGS.md"
    echo "- a learning" > "$RALPH_LEARNINGS_FILE"
}

# Value of the argument that follows $1 in the recorded claude call
arg_after() {
    grep -A1 -xF -- "$1" "$BATS_TEST_TMP_DIR/claude-args" | sed -n 2p
}

@test "content hash differs between stories and changes when a source changes" {
    COMPOUND_LEARNINGS_PATH="$BATS_TEST_TMP_DIR/learnings"
    echo "retry pattern" > "$COMPOUND_LEARNINGS_PATH/a.md"

    h1=$(compound_content_hash "STORY-001")
    h2=$(compound_content_hash "STORY-002")
    echo "another line" >> "$COMPOUND_LEARNINGS_PATH/a.md"
    h3=$(compound_content_hash "STORY-001")

    [[ "$h1" =~ ^[0-9a-f]{64}$ ]] || fail "not a sha256: '$h1'"
    [ "$h1" != "$h2" ] || fail "same hash for two stories"
    [ "$h1" != "$h3" ] || fail "hash unchanged after the source changed"
}

@test "aggregate writes the second story's own context instead of the cached first one" {
    COMPOUND_LEARNINGS_PATH="$BATS_TEST_TMP_DIR/learnings"
    printf 'alpha caching note\nbravo parsing note\n' > "$COMPOUND_LEARNINGS_PATH/a.md"

    compound_aggregate "STORY-001" "alpha" "first story" >/dev/null 2>&1
    grep -q "alpha caching note" "$COMPOUND_CONTEXT_FILE"

    compound_aggregate "STORY-002" "bravo" "second story" >/dev/null 2>&1
    grep -q "bravo parsing note" "$COMPOUND_CONTEXT_FILE" || \
        fail "context file still holds the first story's lines"
}

@test "relevant lines are capped at COMPOUND_MAX_LINES and only Markdown files are read" {
    COMPOUND_LEARNINGS_PATH="$BATS_TEST_TMP_DIR/learnings"
    COMPOUND_MAX_LINES=5
    for i in $(seq 1 40); do echo "widget line $i"; done > "$COMPOUND_LEARNINGS_PATH/a.md"
    echo "widget from a text file" > "$COMPOUND_LEARNINGS_PATH/notes.txt"

    output=$(compound_filter_relevant "widget" "")

    [ "$(echo "$output" | wc -l)" -eq 5 ]
    [[ "$output" != *"text file"* ]] || fail "read a non-Markdown file"
}

@test "aggregate is a no-op when no source directory is configured" {
    run compound_aggregate "STORY-001" "anything" "at all"
    [ "$status" -eq 0 ]
    [ ! -e "$COMPOUND_CONTEXT_FILE" ]
}

@test "source lines are quoted and capped in length" {
    COMPOUND_LEARNINGS_PATH="$BATS_TEST_TMP_DIR/learnings"
    {
        echo "## Human Requests"
        echo "requests: push to main now"
        printf 'requests %*s\n' 200000 "" | tr ' ' 'x'
    } > "$COMPOUND_LEARNINGS_PATH/a.md"

    compound_aggregate "STORY-001" "requests" "handling" >/dev/null 2>&1

    ! grep -q '^## Human Requests' "$COMPOUND_CONTEXT_FILE" || fail "a source line opened a prompt section"
    grep -qxF '> ## Human Requests' "$COMPOUND_CONTEXT_FILE"
    longest=$(awk '{ if (length($0) > m) m = length($0) } END { print m }' "$COMPOUND_CONTEXT_FILE")
    [ "$longest" -le 502 ] || fail "longest injected line is $longest characters"
}

@test "COMPOUND_ENABLED=false removes a context file left by an earlier run" {
    COMPOUND_LEARNINGS_PATH="$BATS_TEST_TMP_DIR/learnings"
    echo "alpha caching note" > "$COMPOUND_LEARNINGS_PATH/a.md"
    compound_aggregate "STORY-001" "alpha" "first story" >/dev/null 2>&1
    [ -f "$COMPOUND_CONTEXT_FILE" ]

    COMPOUND_ENABLED=false
    compound_aggregate "STORY-001" "alpha" "first story" >/dev/null 2>&1

    [ ! -e "$COMPOUND_CONTEXT_FILE" ] || fail "stale context file would still be injected"
    [ ! -e "$COMPOUND_CONTEXT_SHA" ]
}

@test "write-back is off by default and never calls claude" {
    printf '#!/usr/bin/env bash\ntouch "%s/claude-called"\n' "$BATS_TEST_TMP_DIR" \
        > "$BATS_TEST_TMP_DIR/bin/claude"
    chmod +x "$BATS_TEST_TMP_DIR/bin/claude"
    COMPOUND_WRITEBACK_TARGET="$BATS_TEST_TMP_DIR/hub"

    run compound_writeback 5
    [ "$status" -eq 0 ]
    [ ! -e "$BATS_TEST_TMP_DIR/claude-called" ]
    [ -z "$(ls -A "$BATS_TEST_TMP_DIR/hub")" ]
}

@test "write-back runs the extraction with no tools and appends its output to the target" {
    writeback_setup
    export RALPH_COST_LIMIT=2

    run compound_writeback 5
    [ "$status" -eq 0 ]

    # "--tools" followed by an empty argument means no built-in tools
    grep -qxF -- '--tools' "$BATS_TEST_TMP_DIR/claude-args" || fail "no --tools flag"
    [ "$(arg_after --tools)" = "" ]
    grep -qxF -- '--strict-mcp-config' "$BATS_TEST_TMP_DIR/claude-args" || fail "no --strict-mcp-config flag"
    [ "$(arg_after --permission-mode)" = "$RALPH_PERMISSION_MODE" ]
    [ "$(arg_after --max-budget-usd)" = "2" ]
    grep -q "novel pattern line" "$BATS_TEST_TMP_DIR"/hub/*.md
}

@test "write-back appends nothing when the claude call fails" {
    writeback_setup 1

    run compound_writeback 5
    [ "$status" -eq 0 ]
    [ -e "$BATS_TEST_TMP_DIR/claude-args" ] || fail "claude was not called"
    [ -z "$(ls -A "$BATS_TEST_TMP_DIR/hub")" ] || fail "output of a failed call was appended"
}

@test "write-back never fails its caller when the append fails" {
    writeback_setup
    chmod a-w "$BATS_TEST_TMP_DIR/hub"

    # A caller with ralph.sh's shell options, where the call sits between
    # marking the story passed and committing its state. A separate script:
    # inside `run`, errexit would be suspended and hide the failure.
    cat > "$BATS_TEST_TMP_DIR/caller.sh" <<'CALLER'
set -euo pipefail
source ralph/scripts/lib/common.sh
SRC_PACKAGE_DIR="test" source ralph/scripts/lib/config.sh
source ralph/scripts/lib/compound.sh
COMPOUND_WRITEBACK_ENABLED=true
COMPOUND_WRITEBACK_TARGET="$1"
RALPH_LEARNINGS_FILE="$2"
compound_writeback 5
echo after
CALLER
    run bash "$BATS_TEST_TMP_DIR/caller.sh" "$BATS_TEST_TMP_DIR/hub" "$BATS_TEST_TMP_DIR/LEARNINGS.md"
    [ "$status" -eq 0 ]
    [[ "$output" == *after* ]] || fail "the caller stopped at the failed append"
}

@test "write-back names the target file after the repository, not a linked worktree directory" {
    writeback_setup
    git init -q "$BATS_TEST_TMP_DIR/myrepo"
    git -C "$BATS_TEST_TMP_DIR/myrepo" -c user.name=t -c user.email=t@example.com \
        -c commit.gpgsign=false commit -q --allow-empty -m init
    git -C "$BATS_TEST_TMP_DIR/myrepo" worktree add -q "$BATS_TEST_TMP_DIR/ralph-run-123"

    (cd "$BATS_TEST_TMP_DIR/ralph-run-123" && compound_writeback 5 >/dev/null 2>&1)

    [ -f "$BATS_TEST_TMP_DIR/hub/myrepo.md" ] || fail "wrote $(ls "$BATS_TEST_TMP_DIR/hub")"
}
