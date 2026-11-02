#!/usr/bin/env bats
# Quality-gate tests for issue #90:
# - `make validate` must fail when the scaffold's checks fail (no recipe override)
# - parallel worker exit codes come from a per-worktree file, not a hardcoded 0
# Run from project root: bats ralph/scripts/tests/test_validate_gate.bats

setup() {
    export BATS_TEST_TMP_DIR="$(mktemp -d)"
    cp Makefile "$BATS_TEST_TMP_DIR/Makefile"
}

teardown() {
    [ -d "$BATS_TEST_TMP_DIR" ] && rm -rf "$BATS_TEST_TMP_DIR"
}

# Write a stub scaffold Makefile whose validate recipe exits with $1
write_fake_scaffold() {
    echo "fake" > "$BATS_TEST_TMP_DIR/.scaffold"
    printf 'validate:\n\techo "fake validate ran"\n\texit %s\n' "$1" \
        > "$BATS_TEST_TMP_DIR/Makefile.fake"
}

@test "make validate fails when the scaffold validate fails" {
    write_fake_scaffold 1
    run make -C "$BATS_TEST_TMP_DIR" validate
    [ "$status" -ne 0 ]
    [[ "$output" == *"fake validate ran"* ]]
}

@test "make validate passes and delegates when the scaffold validate passes" {
    write_fake_scaffold 0
    run make -C "$BATS_TEST_TMP_DIR" validate
    [ "$status" -eq 0 ]
    [[ "$output" == *"fake validate ran"* ]]
}

@test "make validate does not override the scaffold recipe" {
    write_fake_scaffold 0
    run make -C "$BATS_TEST_TMP_DIR" validate
    [[ "$output" != *"overriding recipe"* ]]
}

@test "make validate fails without a scaffold" {
    run make -C "$BATS_TEST_TMP_DIR" validate
    [ "$status" -ne 0 ]
}

@test "make validate fails when .scaffold names a language without a Makefile" {
    echo "nolang" > "$BATS_TEST_TMP_DIR/.scaffold"
    run make -C "$BATS_TEST_TMP_DIR" validate
    [ "$status" -ne 0 ]
}

@test "run_and_record_exit stores the worker's real exit code" {
    source ralph/scripts/lib/worker_exit.sh
    run_and_record_exit "$BATS_TEST_TMP_DIR" bash -c 'exit 4' || true
    run read_worktree_exit_code "$BATS_TEST_TMP_DIR"
    [ "$output" = "4" ]
}

@test "run_and_record_exit stores 0 for a successful worker" {
    source ralph/scripts/lib/worker_exit.sh
    run_and_record_exit "$BATS_TEST_TMP_DIR" true
    run read_worktree_exit_code "$BATS_TEST_TMP_DIR"
    [ "$output" = "0" ]
}

@test "read_worktree_exit_code reports failure when the worker left no status" {
    source ralph/scripts/lib/worker_exit.sh
    run read_worktree_exit_code "$BATS_TEST_TMP_DIR"
    [ "$output" = "1" ]
}

@test "read_worktree_exit_code reports failure for a corrupt status file" {
    source ralph/scripts/lib/worker_exit.sh
    echo "garbage" > "$BATS_TEST_TMP_DIR/$RALPH_EXIT_FILE"
    run read_worktree_exit_code "$BATS_TEST_TMP_DIR"
    [ "$output" = "1" ]
}

@test "parallel_ralph.sh no longer hardcodes worker exit code 0" {
    ! grep -q 'WORKTREE_EXIT_CODES\[\$i\]=0' ralph/scripts/parallel_ralph.sh
}
