#!/usr/bin/env bats
# execute_story() and fix_validation_errors() build the `claude -p` command
# line. Values from the environment (RALPH_MODEL, RALPH_PERMISSION_MODE,
# RALPH_COST_LIMIT) must reach claude as plain arguments and never run as
# shell code, and the RALPH_DESLOPIFY system prompt must stay one argument.
#
# The functions are extracted from ralph.sh and evaluated in isolation:
# sourcing ralph.sh would run its main loop. `claude` is a stub on PATH that
# records its arguments; injection is detected by a marker file in the test's
# temp dir, never by a real command.
# Run from project root: bats ralph/scripts/tests/test_claude_args.bats
# shellcheck disable=SC2034,SC2317  # the stubs and settings are used by the functions extracted from ralph.sh

setup() {
    BATS_TEST_TMP_DIR="$(mktemp -d)"
    export BATS_TEST_TMP_DIR
    export MARK="$BATS_TEST_TMP_DIR/injected"
    export ARGS_FILE="$BATS_TEST_TMP_DIR/claude-args"
    mkdir -p "$BATS_TEST_TMP_DIR/bin"
    cat > "$BATS_TEST_TMP_DIR/bin/claude" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$ARGS_FILE"
cat > /dev/null
STUB
    chmod +x "$BATS_TEST_TMP_DIR/bin/claude"
    export PATH="$BATS_TEST_TMP_DIR/bin:$PATH"

    # shellcheck source=ralph/scripts/lib/common.sh
    source ralph/scripts/lib/common.sh
    for fn in build_claude_args execute_story fix_validation_errors; do
        func_src=$(sed -n "/^${fn}() {/,/^}/p" ralph/scripts/ralph.sh)
        [ -n "$func_src" ] || fail "could not extract $fn from ralph.sh"
        eval "$func_src"
    done

    # Collaborators of the two functions, stubbed
    log_info() { :; }
    log_warn() { :; }
    log_error() { :; }
    kanban_update() { :; }
    compound_aggregate() { :; }
    classify_story() { echo "sonnet"; }
    inject_shared_prompt_sections() { :; }
    adapter_env_setup() { :; }
    count_validation_errors() { echo 1; }
    run_quality_checks() { return 0; }

    RALPH_TMP_DIR="$BATS_TEST_TMP_DIR"
    PROMPT_FILE="$BATS_TEST_TMP_DIR/prompt.md"
    echo "prompt" > "$PROMPT_FILE"
    echo "error" > "$BATS_TEST_TMP_DIR/validate.log"
    FIX_TIMEOUT=30
    FIX_ERROR_THRESHOLD=10
    DEFAULT_MODEL="sonnet"
    FIX_MODEL="haiku"
    unset RALPH_MODEL RALPH_PERMISSION_MODE RALPH_COST_LIMIT RALPH_DESLOPIFY
}

teardown() {
    [ -d "$BATS_TEST_TMP_DIR" ] && rm -rf "$BATS_TEST_TMP_DIR"
}

# Value of the argument that follows $1 in the recorded claude call
arg_after() {
    grep -A1 -xF -- "$1" "$ARGS_FILE" | sed -n 2p
}

@test "execute_story passes RALPH_MODEL and RALPH_PERMISSION_MODE to claude as plain arguments" {
    RALPH_MODEL="sonnet;touch $MARK;true"
    RALPH_PERMISSION_MODE="auto;touch $MARK;true"

    execute_story "STORY-001" "Title|Description" >/dev/null 2>&1 || true

    [ ! -e "$MARK" ] || fail "an environment value ran as shell code"
    [ "$(arg_after --model)" = "$RALPH_MODEL" ]
    # The helper's output is split on whitespace only, like every other
    # claude call that uses claude_permission_flags: the ';' stays literal
    [ "$(arg_after --permission-mode)" = "${RALPH_PERMISSION_MODE%% *}" ]
}

@test "fix_validation_errors passes RALPH_MODEL and RALPH_PERMISSION_MODE to claude as plain arguments" {
    RALPH_MODEL="haiku;touch $MARK;true"
    RALPH_PERMISSION_MODE="auto;touch $MARK;true"

    fix_validation_errors "STORY-001" "Title|Description" "$BATS_TEST_TMP_DIR/validate.log" 1 \
        >/dev/null 2>&1 || true

    [ ! -e "$MARK" ] || fail "an environment value ran as shell code"
    [ "$(arg_after --model)" = "$RALPH_MODEL" ]
    # The helper's output is split on whitespace only, like every other
    # claude call that uses claude_permission_flags: the ';' stays literal
    [ "$(arg_after --permission-mode)" = "${RALPH_PERMISSION_MODE%% *}" ]
}

@test "RALPH_COST_LIMIT reaches claude as plain arguments in both calls" {
    RALPH_COST_LIMIT="1;touch $MARK;true"

    execute_story "STORY-001" "Title|Description" >/dev/null 2>&1 || true
    [ ! -e "$MARK" ] || fail "execute_story ran RALPH_COST_LIMIT as shell code"
    [ "$(arg_after --max-budget-usd)" = "1;touch" ]

    rm -f "$ARGS_FILE"
    fix_validation_errors "STORY-001" "Title|Description" "$BATS_TEST_TMP_DIR/validate.log" 1 \
        >/dev/null 2>&1 || true
    [ ! -e "$MARK" ] || fail "fix_validation_errors ran RALPH_COST_LIMIT as shell code"
    [ "$(arg_after --max-budget-usd)" = "1;touch" ]
}

@test "RALPH_DESLOPIFY system prompt reaches claude as one argument in both calls" {
    RALPH_DESLOPIFY=true
    RALPH_COST_LIMIT=2

    execute_story "STORY-001" "Title|Description" >/dev/null 2>&1
    [[ "$(arg_after --append-system-prompt)" == "Produce clean, production-quality code."* ]]
    [ "$(arg_after --max-budget-usd)" = "2" ]

    fix_validation_errors "STORY-001" "Title|Description" "$BATS_TEST_TMP_DIR/validate.log" 1 \
        >/dev/null 2>&1
    [[ "$(arg_after --append-system-prompt)" == "Produce clean, production-quality code."* ]]
    [ "$(arg_after --max-budget-usd)" = "2" ]
}

@test "judge_worktrees passes RALPH_JUDGE_MODEL, RALPH_PERMISSION_MODE and RALPH_COST_LIMIT to claude as plain arguments" {
    # shellcheck source=ralph/scripts/lib/judge.sh
    source ralph/scripts/lib/judge.sh
    log_info() { :; }
    log_warn() { :; }
    get_worktree_path() { echo "$BATS_TEST_TMP_DIR/no-such-worktree"; }
    RALPH_JUDGE_ENABLED=true
    RALPH_JUDGE_TEMPLATE="$BATS_TEST_TMP_DIR/judge.md"
    echo "template" > "$RALPH_JUDGE_TEMPLATE"
    RALPH_JUDGE_MODEL="sonnet\$(touch $MARK)"
    RALPH_PERMISSION_MODE="auto;touch $MARK;true"
    RALPH_COST_LIMIT="1;touch $MARK;true"

    judge_worktrees "run1" 1 >/dev/null 2>&1 || true

    [ ! -e "$MARK" ] || fail "an environment value ran as shell code"
    [ "$(arg_after --model)" = "$RALPH_JUDGE_MODEL" ]
    [ "$(arg_after --permission-mode)" = "${RALPH_PERMISSION_MODE%% *}" ]
    [ "$(arg_after --max-budget-usd)" = "1;touch" ]
}

# The scripts that call claude: ralph.sh, parallel_ralph.sh and the libraries
claude_scripts=(ralph/scripts/ralph.sh ralph/scripts/parallel_ralph.sh ralph/scripts/lib/*.sh)

# eval lines in those scripts, minus comments and the one known eval: the
# find command in generate_app_docs.sh, which builds no claude call
unexpected_eval_lines() {
    grep -nwE 'eval' "${claude_scripts[@]}" \
        | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' \
        | grep -vF 'generate_app_docs.sh:49:'
}

@test "no claude-calling script runs a command string through bash -c" {
    # A bash -c string can span lines, so any use fails, not only one that
    # names claude on the same line
    run grep -nwF -- 'bash -c' "${claude_scripts[@]}"
    [ "$status" -eq 1 ]
}

@test "no claude-calling script uses eval, apart from the find in generate_app_docs.sh" {
    run unexpected_eval_lines
    [ "$status" -eq 1 ]
}
