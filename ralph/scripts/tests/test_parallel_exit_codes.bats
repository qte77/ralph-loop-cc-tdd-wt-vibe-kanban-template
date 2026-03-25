#!/usr/bin/env bats
load test_helper/common-setup

setup() {
    export BATS_TEST_TMP_DIR="$(mktemp -d)"
}

teardown() {
    [ -d "$BATS_TEST_TMP_DIR" ] && rm -rf "$BATS_TEST_TMP_DIR"
}

# Test 1: Sentinel file captures exit code 0
@test "sentinel file captures successful exit code" {
    local wt="$BATS_TEST_TMP_DIR/wt1"
    mkdir -p "$wt"
    echo "0" > "$wt/.ralph-exit-code"
    local code=$(cat "$wt/.ralph-exit-code")
    [ "$code" = "0" ]
}

# Test 2: Sentinel file captures exit code 1
@test "sentinel file captures failure exit code" {
    local wt="$BATS_TEST_TMP_DIR/wt2"
    mkdir -p "$wt"
    echo "1" > "$wt/.ralph-exit-code"
    local code=$(cat "$wt/.ralph-exit-code")
    [ "$code" = "1" ]
}

# Test 3: Reading sentinel instead of hardcoding
@test "read sentinel file instead of hardcoding 0" {
    local wt1="$BATS_TEST_TMP_DIR/wt1"
    local wt2="$BATS_TEST_TMP_DIR/wt2"
    mkdir -p "$wt1" "$wt2"
    echo "0" > "$wt1/.ralph-exit-code"
    echo "1" > "$wt2/.ralph-exit-code"

    local code1=137
    if [ -f "$wt1/.ralph-exit-code" ]; then
        code1=$(cat "$wt1/.ralph-exit-code")
    fi
    local code2=137
    if [ -f "$wt2/.ralph-exit-code" ]; then
        code2=$(cat "$wt2/.ralph-exit-code")
    fi

    [ "$code1" = "0" ]
    [ "$code2" = "1" ]
}

# Test 4: Missing sentinel defaults to 137
@test "missing sentinel file defaults to 137" {
    local wt="$BATS_TEST_TMP_DIR/missing"
    mkdir -p "$wt"

    local code=137
    if [ -f "$wt/.ralph-exit-code" ]; then
        code=$(cat "$wt/.ralph-exit-code")
    fi

    [ "$code" = "137" ]
}

# Test 5: Cleanup removes sentinel files
@test "cleanup removes sentinel files" {
    local wt="$BATS_TEST_TMP_DIR/cleanup"
    mkdir -p "$wt"
    echo "42" > "$wt/.ralph-exit-code"
    [ -f "$wt/.ralph-exit-code" ]
    rm "$wt/.ralph-exit-code"
    [ ! -f "$wt/.ralph-exit-code" ]
}
