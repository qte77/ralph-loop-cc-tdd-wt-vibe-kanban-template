#!/bin/bash
#
# Ralph Loop - Scaffold Adapter System
#
# Loads language-specific adapter functions from .scaffolds/<name>.sh
# (deployed by scaffold plugin hooks). Provides no-op fallbacks when
# no adapter is present, so Ralph scripts work regardless of scaffold.
#
# Source order: common.sh → config.sh → adapter.sh (before baseline.sh, snapshot.sh)
#
# Adapter interface:
#   adapter_test [files...]          - Run tests (output must include "FAILED <name>" lines)
#   adapter_lint [files...]          - Format + lint (no args = full codebase)
#   adapter_typecheck                - Static type checking
#   adapter_complexity [files...]    - Cognitive complexity analysis
#   adapter_coverage                 - Run tests with coverage (output "TOTAL ... XX%")
#   adapter_validate                 - Full validation sequence
#   adapter_signatures <file>        - Extract function/class signatures from a file
#   adapter_file_pattern             - Print glob pattern for source files (e.g., "*.py")
#   adapter_env_setup                - Set up environment (e.g., PYTHONPATH, PATH)
#   adapter_app_docs <src_dir>       - Generate README.md + example file in src dir
#

_ADAPTER_LOADED=false

# Load adapter from .scaffolds/<name>.sh based on .scaffold selection.
# Safe to call multiple times (idempotent).
_load_adapter() {
    [ "$_ADAPTER_LOADED" = "true" ] && return 0

    local scaffold_file=".scaffold"
    if [ ! -f "$scaffold_file" ]; then
        log_info "No .scaffold file — adapter functions use no-op fallbacks"
        _ADAPTER_LOADED=true
        return 0
    fi

    local scaffold_name
    scaffold_name=$(cat "$scaffold_file" | tr -d '[:space:]')
    local adapter_file=".scaffolds/${scaffold_name}.sh"

    if [ -f "$adapter_file" ]; then
        # shellcheck source=/dev/null
        source "$adapter_file"
        log_info "Loaded scaffold adapter: $scaffold_name"
    else
        log_warn "Adapter not found: $adapter_file — using no-op fallbacks"
    fi

    _ADAPTER_LOADED=true
}

# =========================================================
# Adapter functions — overridden by .scaffolds/<name>.sh
# Default implementations are no-ops or delegate to make.
# =========================================================

# Run tests. Output must contain "FAILED <test_name>" lines for baseline comparison.
# Args: optional file list (empty = full suite)
adapter_test() {
    _load_adapter
    if type -t _scaffold_test &>/dev/null; then
        _scaffold_test "$@"
    else
        log_info "adapter_test: no scaffold — running 'make test_all' if available"
        make test_all 2>/dev/null || { log_warn "No test_all target"; return 0; }
    fi
}

# Format + lint source files.
# Args: optional file list (empty = full codebase)
adapter_lint() {
    _load_adapter
    if type -t _scaffold_lint &>/dev/null; then
        _scaffold_lint "$@"
    else
        log_info "adapter_lint: no scaffold — skipping"
        return 0
    fi
}

# Static type checking.
adapter_typecheck() {
    _load_adapter
    if type -t _scaffold_typecheck &>/dev/null; then
        _scaffold_typecheck "$@"
    else
        log_info "adapter_typecheck: no scaffold — skipping"
        return 0
    fi
}

# Cognitive complexity analysis.
# Args: optional file list (empty = full codebase)
adapter_complexity() {
    _load_adapter
    if type -t _scaffold_complexity &>/dev/null; then
        _scaffold_complexity "$@"
    else
        log_info "adapter_complexity: no scaffold — skipping"
        return 0
    fi
}

# Run tests with coverage. Output must include "TOTAL ... XX%" line.
adapter_coverage() {
    _load_adapter
    if type -t _scaffold_coverage &>/dev/null; then
        _scaffold_coverage "$@"
    else
        log_info "adapter_coverage: no scaffold — falling back to adapter_test"
        adapter_test "$@"
    fi
}

# Full validation sequence (lint + typecheck + complexity + test).
adapter_validate() {
    _load_adapter
    if type -t _scaffold_validate &>/dev/null; then
        _scaffold_validate "$@"
    else
        log_info "adapter_validate: no scaffold — running 'make validate'"
        make validate
    fi
}

# Extract function/class signatures from a source file.
# Args: $1 = file path
# Output: "lineno:signature_line" format, one per line
adapter_signatures() {
    _load_adapter
    if type -t _scaffold_signatures &>/dev/null; then
        _scaffold_signatures "$@"
    else
        log_info "adapter_signatures: no scaffold — skipping"
        return 0
    fi
}

# Print glob pattern for source files (e.g., "*.py", "*.c *.h")
adapter_file_pattern() {
    _load_adapter
    if type -t _scaffold_file_pattern &>/dev/null; then
        _scaffold_file_pattern
    else
        echo "*"
    fi
}

# Set up runtime environment variables (e.g., PYTHONPATH).
# Called before claude -p and make validate invocations.
adapter_env_setup() {
    _load_adapter
    if type -t _scaffold_env_setup &>/dev/null; then
        _scaffold_env_setup "$@"
    fi
    # No-op by default — nothing to set up
}

# Generate application documentation (README.md, example file) in src dir.
# Args: $1 = src directory path
adapter_app_docs() {
    _load_adapter
    if type -t _scaffold_app_docs &>/dev/null; then
        _scaffold_app_docs "$@"
    else
        log_info "adapter_app_docs: no scaffold — skipping doc generation"
        return 0
    fi
}
