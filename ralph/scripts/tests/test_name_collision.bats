#!/usr/bin/env bats
# STORY-004: ralph.sh and lib/teams.sh both defined verify_teammate_stories() with different
# behaviour, so whichever was sourced last won. The ralph.sh one (prd.json isolation check) is
# now verify_prd_isolation(). ralph.sh has no main guard, so its function is extracted with awk.
# Run from project root: bats ralph/scripts/tests/test_name_collision.bats

setup() {
    BATS_TEST_TMP_DIR="$(mktemp -d)"
    export BATS_TEST_TMP_DIR
    # shellcheck source=ralph/scripts/lib/common.sh
    source ralph/scripts/lib/common.sh
    eval "$(awk '/^verify_prd_isolation\(\)/{flag=1} flag{print} flag && /^}/{exit}' ralph/scripts/ralph.sh)"
    # shellcheck source=ralph/scripts/lib/teams.sh
    source ralph/scripts/lib/teams.sh
}

teardown() {
    [ -d "$BATS_TEST_TMP_DIR" ] && rm -rf "$BATS_TEST_TMP_DIR"
}

@test "each verify function is defined once across the Ralph scripts" {
    [ "$(cat ralph/scripts/*.sh ralph/scripts/lib/*.sh | grep -c '^verify_teammate_stories()')" -eq 1 ]
    [ "$(cat ralph/scripts/*.sh ralph/scripts/lib/*.sh | grep -c '^verify_prd_isolation()')" -eq 1 ]
}

@test "verify_teammate_stories is the teams.sh version" {
    declare -f verify_teammate_stories | grep -q 'primary_id'
}

@test "verify_prd_isolation is the ralph.sh prd.json isolation check" {
    declare -f verify_prd_isolation | grep -q 'PRD_JSON'
}
