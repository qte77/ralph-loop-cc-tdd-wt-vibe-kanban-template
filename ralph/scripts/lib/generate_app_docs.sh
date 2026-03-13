#!/bin/bash
#
# Application Documentation Generator
# Delegates to scaffold adapter for language-specific doc generation.
# Falls back to generic README if no adapter is loaded.
# NOTE: This file is sourced, not executed. Requires config.sh and adapter.sh to be loaded first.

# Safety check: Verify config.sh is loaded
if [ -z "$RALPH_PRD_JSON" ] || [ -z "$SRC_BASE_DIR" ] || [ -z "$TESTS_BASE_DIR" ]; then
    echo "Error: config.sh not loaded. Source config.sh before sourcing this file." >&2
    return 1 2>/dev/null || exit 1
fi

# Generate/update README.md in src directory
# Returns the path to the generated README (empty if not generated)
generate_app_readme() {
    log_info "Generating application README.md..."

    # Find src directory (first dir in src/)
    local src_dir=$(find "$SRC_BASE_DIR" -mindepth 1 -maxdepth 1 -type d | head -1)
    if [ -z "$src_dir" ]; then
        log_warn "No src directory found, skipping README generation"
        echo ""
        return 0
    fi

    local app_name=$(basename "$src_dir")
    local readme_path="$src_dir/README.md"

    # Extract metadata from prd.json
    local title=$(jq -r '.title // "Application"' "$RALPH_PRD_JSON")
    local description=$(jq -r '.description // "Application description"' "$RALPH_PRD_JSON")

    # Build actual architecture from filesystem
    local architecture=""
    local _file_pattern
    _file_pattern=$(adapter_file_pattern)

    # Generate tree structure for src and tests
    if command -v tree &> /dev/null; then
        architecture=$(tree -L 3 --noreport "$src_dir" "$TESTS_BASE_DIR/" 2>/dev/null || echo "$src_dir/ and $TESTS_BASE_DIR/")
    else
        # Fallback: list source files matching scaffold pattern
        local _find_args=""
        for _pat in $_file_pattern; do
            [ -n "$_find_args" ] && _find_args="$_find_args -o"
            _find_args="$_find_args -name $_pat"
        done
        architecture=$(eval "find \"$src_dir\" \"$TESTS_BASE_DIR/\" -type f \( $_find_args \)" 2>/dev/null | sort | sed 's|^|  |' || echo "No files found")
    fi

    # Generate concise README with actual information
    cat > "$readme_path" <<EOF
# $title

## What

$description

## Why

$(jq -r '.stories[] | select(.status == "passed") | .description' "$RALPH_PRD_JSON" | head -5 | sed 's/^/- /')

## Quick Start

\`\`\`bash
# Run validation
make validate

# Run tests
make test_all
\`\`\`

## Architecture

\`\`\`text
$architecture
\`\`\`

## Development

Built with Ralph Loop autonomous development using TDD.
EOF

    log_info "README.md created at $readme_path"
    echo "$readme_path"
}

# Generate/update example file in src directory via scaffold adapter.
# Returns the path to the generated example (empty if not generated)
generate_app_example() {
    log_info "Generating application example..."

    # Find src directory (first dir in src/)
    local src_dir=$(find "$SRC_BASE_DIR" -mindepth 1 -maxdepth 1 -type d | head -1)
    if [ -z "$src_dir" ]; then
        log_warn "No src directory found, skipping example generation"
        echo ""
        return 0
    fi

    # Delegate to adapter for language-specific example generation
    adapter_app_docs "$src_dir"
    local result=$?

    # Return path to example file if adapter created one
    if [ $result -eq 0 ]; then
        # Check common example file names
        for candidate in "$src_dir/example.py" "$src_dir/example.c" "$src_dir/main.c" "$src_dir/example.ts"; do
            if [ -f "$candidate" ]; then
                echo "$candidate"
                return 0
            fi
        done
    fi

    echo ""
    return 0
}
