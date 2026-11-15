#!/usr/bin/env bats
# CodeFactor duplication fix: ralph.sh built the "Agent Learnings / Human
# Requests / Recent Run History / Steering Instruction" prompt sections
# twice (once in execute_story(), once in fix_validation_errors()). This
# extracts a single inject_shared_prompt_sections() function and verifies:
#   - the section-building code exists exactly once in the file (no
#     duplication left behind)
#   - both call sites use the shared function
#   - the function itself produces the right output when invoked in
#     isolation (same approach test_resume.bats uses for execute_story:
#     ralph.sh has no main guard and cannot be sourced directly)
# Run from project root: bats ralph/scripts/tests/test_prompt_sections.bats

setup() {
    BATS_TEST_TMP_DIR="$(mktemp -d)"
    export BATS_TEST_TMP_DIR
}

teardown() {
    [ -d "$BATS_TEST_TMP_DIR" ] && rm -rf "$BATS_TEST_TMP_DIR"
}

@test "inject_shared_prompt_sections is defined exactly once in ralph.sh" {
    count=$(grep -c '^inject_shared_prompt_sections() {' ralph/scripts/ralph.sh)
    [ "$count" -eq 1 ]
}

@test "the four prompt sections are built in only one place (no duplication)" {
    # Each marker comment must appear exactly once now that both call sites
    # share one function, instead of twice (once per call site) before.
    for marker in \
        "# Inject accumulated learnings" \
        "# Inject human requests" \
        "# Inject recent run history for self-correction" \
        "# Inject ad-hoc steering instruction"
    do
        count=$(grep -c -- "$marker" ralph/scripts/ralph.sh)
        [ "$count" -eq 1 ] || \
            fail "marker '$marker' appears $count times, expected 1"
    done
}

@test "execute_story calls the shared prompt-section function" {
    awk '/^execute_story\(\)/{flag=1} flag{print} flag && /^}/{exit}' ralph/scripts/ralph.sh \
        | grep -q 'inject_shared_prompt_sections'
}

@test "fix_validation_errors calls the shared prompt-section function" {
    awk '/^fix_validation_errors\(\)/{flag=1} flag{print} flag && /^}/{exit}' ralph/scripts/ralph.sh \
        | grep -q 'inject_shared_prompt_sections'
}

@test "inject_shared_prompt_sections renders all four sections in order when sourced" {
    # Extract the real function body from ralph.sh and eval it in isolation,
    # same technique as test_resume.bats' log_progress test but against the
    # actual source instead of a hand-copied stand-in.
    func_src=$(sed -n '/^inject_shared_prompt_sections() {/,/^}/p' ralph/scripts/ralph.sh)
    [ -n "$func_src" ] || fail "could not extract inject_shared_prompt_sections from ralph.sh"

    RALPH_LEARNINGS_FILE="$BATS_TEST_TMP_DIR/LEARNINGS.md"
    RALPH_REQUESTS_FILE="$BATS_TEST_TMP_DIR/REQUESTS.md"
    PROGRESS_FILE="$BATS_TEST_TMP_DIR/progress.txt"
    echo "learning-marker" > "$RALPH_LEARNINGS_FILE"
    echo "request-marker" > "$RALPH_REQUESTS_FILE"
    echo "progress-marker" > "$PROGRESS_FILE"
    RALPH_INSTRUCTION="steering-marker"

    output=$(
        export RALPH_LEARNINGS_FILE RALPH_REQUESTS_FILE PROGRESS_FILE RALPH_INSTRUCTION
        eval "$func_src"
        inject_shared_prompt_sections
    )

    # All four markers present...
    [[ "$output" == *"learning-marker"* ]] || fail "missing learnings content"
    [[ "$output" == *"request-marker"* ]] || fail "missing requests content"
    [[ "$output" == *"progress-marker"* ]] || fail "missing progress content"
    [[ "$output" == *"steering-marker"* ]] || fail "missing steering instruction content"

    # ...in the documented order.
    order=$(echo "$output" | grep -nE '^## (Agent Learnings|Human Requests|Recent Run History|Steering Instruction)$' | cut -d: -f2)
    expected=$'## Agent Learnings\n## Human Requests\n## Recent Run History\n## Steering Instruction'
    [ "$order" = "$expected" ]
}
