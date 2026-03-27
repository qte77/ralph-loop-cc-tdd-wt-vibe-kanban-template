#!/usr/bin/env bats
# BATS tests for double validation fix
# Tests acceptance criteria for STORY-008
# These tests verify the optimization to skip full validation on intermediate attempts

load test_helper/common-setup

setup() {
    export BATS_TEST_TMP_DIR="$(mktemp -d)"
}

teardown() {
    [ -d "$BATS_TEST_TMP_DIR" ] && rm -rf "$BATS_TEST_TMP_DIR"
}

@test "fix_validation_errors returns 0 immediately after quick validation passes on intermediate attempt" {
    # The fix: when attempt < max_attempts and make validate_quick passes,
    # return 0 WITHOUT calling run_quality_checks
    #
    # Current buggy code pattern (should NOT exist after fix):
    #     if make validate_quick 2>&1 | tee "$retry_log"; then
    #         # Quick validation passed, run full validation to confirm
    #         if run_quality_checks "$retry_log"; then  # <-- BUG: unconditional call
    #
    # Fixed pattern (should exist after fix):
    #     if make validate_quick 2>&1 | tee "$retry_log"; then
    #         return 0  # Return without full validation on intermediate attempt
    #     else

    local fn_body
    fn_body=$(awk '/^fix_validation_errors\(\)/,/^}$/' ralph/scripts/ralph.sh)

    # Extract the intermediate attempt block (when attempt < max_attempts)
    local intermediate_block
    intermediate_block=$(echo "$fn_body" | sed -n '/if \[ \$attempt -lt \$max_attempts \]/,/^[ \t]*else$/p')

    # After "if make validate_quick" passes (then clause), next should be "return 0"
    # NOT "if run_quality_checks"
    # We check: the bug pattern is "then" followed eventually by "run_quality_checks" in the same block

    # Look for the pattern where quick validation success leads to run_quality_checks
    ! echo "$intermediate_block" | sed -n '/make validate_quick/,/else/p' | grep -q "run_quality_checks" \
        || (echo "ERROR: intermediate block calls run_quality_checks after quick validation" && false)
}

@test "fix_validation_errors calls run_quality_checks only on final attempt" {
    # Verify the code pattern for final attempt handling

    local fn_body
    fn_body=$(awk '/^fix_validation_errors\(\)/,/^}$/' ralph/scripts/ralph.sh)

    # Extract the final attempt block (attempt == max_attempts or else clause)
    local final_block
    final_block=$(echo "$fn_body" | awk '/else$/,/^[ \t]*fi$/' | tail -20)

    # On final attempt, we should call run_quality_checks directly
    echo "$final_block" | grep -q 'run_quality_checks' \
        || fail "Final attempt block should call run_quality_checks"
}

@test "make validate_quick is called before run_quality_checks in intermediate attempts" {
    # Verify the order: quick validation (fast) runs before full validation

    local fn_body
    fn_body=$(awk '/^fix_validation_errors\(\)/,/^}$/' ralph/scripts/ralph.sh)

    # In intermediate block, quick comes before full (if both present)
    local quick_line=$(echo "$fn_body" | grep -n 'make validate_quick' | head -1 | cut -d: -f1)
    local full_line=$(echo "$fn_body" | grep -n 'run_quality_checks' | head -1 | cut -d: -f1)

    if [ -n "$quick_line" ] && [ -n "$full_line" ]; then
        # Both exist - quick should come first (in intermediate block)
        [ "$quick_line" -lt "$full_line" ] || fail "make validate_quick should be checked before run_quality_checks"
    fi
}
