#!/usr/bin/env bats
# generate_app_readme() in lib/generate_app_docs.sh lists the source and test
# files when `tree` is missing. The find command is built from the scaffold's
# file patterns and the source directory name; neither may be run as shell
# code or globbed against the current directory.
# The function is extracted and evaluated on its own; `command -v tree` is
# made to fail so the fallback runs.
# Run from project root: bats ralph/scripts/tests/test_app_docs.bats
# shellcheck disable=SC2034,SC2317  # the stubs and settings are used by the extracted function
load test_helper/fail

setup() {
    BATS_TEST_TMP_DIR="$(mktemp -d)"
    export BATS_TEST_TMP_DIR

    func_src=$(sed -n '/^generate_app_readme() {/,/^}/p' ralph/scripts/lib/generate_app_docs.sh)
    [ -n "$func_src" ] || fail "could not extract generate_app_readme"
    eval "$func_src"

    log_info() { :; }
    log_warn() { :; }
    adapter_file_pattern() { echo "*.py"; }
    # Reason: hide tree so the find fallback runs, whatever the machine has
    command() { if [ "$1" = "-v" ] && [ "$2" = "tree" ]; then return 1; fi; builtin command "$@"; }

    SRC_BASE_DIR="$BATS_TEST_TMP_DIR/src"
    TESTS_BASE_DIR="$BATS_TEST_TMP_DIR/tests"
    RALPH_PRD_JSON="$BATS_TEST_TMP_DIR/prd.json"
    echo '{"title":"T","description":"D"}' > "$RALPH_PRD_JSON"
}

teardown() {
    [ -d "$BATS_TEST_TMP_DIR" ] && rm -rf "$BATS_TEST_TMP_DIR"
}

@test "the find fallback runs no shell code from the source directory name" {
    # A directory name holds no "/", so the command uses a relative marker,
    # created in the directory the function runs from
    app="$SRC_BASE_DIR/app\$(touch injected)"
    mkdir -p "$app" "$TESTS_BASE_DIR" "$BATS_TEST_TMP_DIR/cwd"
    touch "$app/main.py" "$TESTS_BASE_DIR/test_main.py"

    (cd "$BATS_TEST_TMP_DIR/cwd" && generate_app_readme >/dev/null 2>&1) || true

    [ ! -e "$BATS_TEST_TMP_DIR/cwd/injected" ] || fail "the source directory name ran as shell code"
    grep -qF "main.py" "$app/README.md" || fail "main.py not listed"
}

@test "the find fallback does not glob the file patterns against the current directory" {
    mkdir -p "$SRC_BASE_DIR/app" "$TESTS_BASE_DIR" "$BATS_TEST_TMP_DIR/cwd"
    touch "$SRC_BASE_DIR/app/main.py" "$TESTS_BASE_DIR/test_main.py" "$BATS_TEST_TMP_DIR/cwd/other.py"

    (cd "$BATS_TEST_TMP_DIR/cwd" && generate_app_readme >/dev/null 2>&1) || true

    grep -qF "app/main.py" "$SRC_BASE_DIR/app/README.md" || fail "main.py not listed"
    grep -qF "tests/test_main.py" "$SRC_BASE_DIR/app/README.md" || fail "test_main.py not listed"
}
