#!/bin/bash
#
# JSON validation utilities for Ralph scripts
#

# Get script directory for sourcing dependencies
if [ -z "${RALPH_LIB_DIR:-}" ]; then
    RALPH_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# Source colors for logging (if not already sourced)
if ! command -v log_error &> /dev/null; then
    source "$RALPH_LIB_DIR/common.sh"
fi

# Validate prd.json file exists and contains valid JSON
# Usage: validate_prd_json [path/to/file.json]
# Returns: 0 on success, 1 on failure
validate_prd_json() {
    local json_file="${1:-ralph/docs/prd.json}"

    if [ ! -f "$json_file" ]; then
        log_error "prd.json not found: $json_file"
        return 1
    fi

    if ! jq empty "$json_file" 2>/dev/null; then
        log_error "Invalid JSON: $json_file"
        return 1
    fi

    return 0
}

# If script is executed directly (not sourced), run validation
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    validate_prd_json "$@"
fi
