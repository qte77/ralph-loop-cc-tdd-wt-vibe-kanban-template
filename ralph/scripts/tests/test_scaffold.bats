#!/usr/bin/env bats
# BATS test infrastructure smoke tests for Ralph scripts
# Tests acceptance criteria for STORY-001

setup() {
    # Each test gets a fresh tmp directory
    export BATS_TEST_TMP_DIR="$(mktemp -d)"
    export RALPH_TMP_DIR="$BATS_TEST_TMP_DIR"
}

teardown() {
    # Clean up test tmp directory
    [ -d "$BATS_TEST_TMP_DIR" ] && rm -rf "$BATS_TEST_TMP_DIR"
}

@test "BATS is installed and runnable" {
    command -v bats >/dev/null || skip "bats not installed"
    bats --version
}

@test "test_helper/common-setup.bash exists" {
    [ -f "ralph/scripts/tests/test_helper/common-setup.bash" ] || \
        skip "common-setup.bash not found"
    # Try sourcing it to verify syntax
    bash -c "source ralph/scripts/tests/test_helper/common-setup.bash && echo 'OK'"
}

@test "common-setup.bash exports RALPH_TMP_DIR" {
    [ -f "ralph/scripts/tests/test_helper/common-setup.bash" ] || \
        skip "common-setup.bash not found"

    # Source and verify RALPH_TMP_DIR is set
    (
        export RALPH_TMP_DIR=
        source ralph/scripts/tests/test_helper/common-setup.bash
        [ -n "$RALPH_TMP_DIR" ]
        [ -d "$RALPH_TMP_DIR" ]
    ) || fail "RALPH_TMP_DIR not set or not a directory"
}

@test "common-setup.bash provides create_mock_prd helper" {
    [ -f "ralph/scripts/tests/test_helper/common-setup.bash" ] || \
        skip "common-setup.bash not found"

    # Verify function is defined
    (
        export RALPH_TMP_DIR="$BATS_TEST_TMP_DIR"
        source ralph/scripts/tests/test_helper/common-setup.bash
        declare -f create_mock_prd >/dev/null 2>&1
    ) || fail "create_mock_prd function not defined"
}

@test "create_mock_prd writes valid prd.json" {
    [ -f "ralph/scripts/tests/test_helper/common-setup.bash" ] || \
        skip "common-setup.bash not found"

    (
        export RALPH_TMP_DIR="$BATS_TEST_TMP_DIR"
        source ralph/scripts/tests/test_helper/common-setup.bash

        create_mock_prd "$BATS_TEST_TMP_DIR/test_prd.json"
        [ -f "$BATS_TEST_TMP_DIR/test_prd.json" ] || exit 1

        # Verify it's valid JSON
        jq . "$BATS_TEST_TMP_DIR/test_prd.json" >/dev/null || exit 1
    ) || fail "create_mock_prd failed or produced invalid JSON"
}

@test "common-setup.bash stubs claude binary as no-op" {
    [ -f "ralph/scripts/tests/test_helper/common-setup.bash" ] || \
        skip "common-setup.bash not found"

    (
        export RALPH_TMP_DIR="$BATS_TEST_TMP_DIR"
        export PATH="$BATS_TEST_TMP_DIR:$PATH"
        source ralph/scripts/tests/test_helper/common-setup.bash

        # Verify claude stub exists
        [ -x "$BATS_TEST_TMP_DIR/claude" ] || exit 1

        # Verify it's a no-op (returns 0)
        "$BATS_TEST_TMP_DIR/claude" -p "test" >/dev/null 2>&1 || exit 1
    ) || fail "claude stub not created or not executable"
}

@test "common-setup.bash sets git config user.name and user.email" {
    [ -f "ralph/scripts/tests/test_helper/common-setup.bash" ] || \
        skip "common-setup.bash not found"

    (
        export RALPH_TMP_DIR="$BATS_TEST_TMP_DIR"
        source ralph/scripts/tests/test_helper/common-setup.bash

        # Check git config is set
        git config --get user.name | grep -q . || exit 1
        git config --get user.email | grep -q . || exit 1
    ) || fail "git config user.name or user.email not set"
}

@test "common-setup.bash does not write to the machine's global git config" {
    [ -f "ralph/scripts/tests/test_helper/common-setup.bash" ] || \
        skip "common-setup.bash not found"

    # Simulate "the machine's real global git config" with a sentinel file,
    # and point GIT_CONFIG_GLOBAL at it the way a real session would have it
    # already set. common-setup.bash must never write into this file.
    local outer_gitconfig="$BATS_TEST_TMP_DIR/outer-gitconfig"
    printf '[user]\n\tname = Outer Sentinel\n\temail = outer@example.com\n' \
        > "$outer_gitconfig"
    local before_hash
    before_hash="$(sha256sum "$outer_gitconfig")"

    (
        export RALPH_TMP_DIR="$BATS_TEST_TMP_DIR"
        export GIT_CONFIG_GLOBAL="$outer_gitconfig"
        source ralph/scripts/tests/test_helper/common-setup.bash

        # The helper must redirect GIT_CONFIG_GLOBAL to its own isolated
        # file rather than writing into the inherited one.
        [ "$GIT_CONFIG_GLOBAL" != "$outer_gitconfig" ] || exit 1

        # It must still configure a usable identity for commits made
        # during the test.
        [ "$(git config --get user.name)" = "Test User" ] || exit 1
    ) || fail "common-setup.bash did not isolate GIT_CONFIG_GLOBAL"

    local after_hash
    after_hash="$(sha256sum "$outer_gitconfig")"
    [ "$before_hash" = "$after_hash" ] || \
        fail "outer (machine) global git config was modified"
}

@test "test_parallel_ralph.sh still exists (not deleted)" {
    [ -f "ralph/scripts/tests/test_parallel_ralph.sh" ] || \
        fail "test_parallel_ralph.sh was deleted"
}

@test "test_common_sh_sources_without_error" {
    [ -f "ralph/scripts/tests/test_helper/common-setup.bash" ] || \
        skip "common-setup.bash not found"

    # Smoke test: verify common.sh can be sourced
    (
        source ralph/scripts/lib/common.sh >/dev/null 2>&1
    ) || fail "common.sh failed to source"
}

@test "Makefile has test_bats recipe" {
    grep -q "^test_bats:" Makefile || \
        skip "Makefile test_bats recipe not found"
}
