#!/bin/bash
#
# Application Documentation Generator
# Generates README.md and example.py for the application
# NOTE: This file is sourced, not executed. Requires config.sh to be loaded first.

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

    # Generate tree structure for src and tests
    if command -v tree &> /dev/null; then
        architecture=$(tree -L 3 --noreport -I '__pycache__|*.pyc|*.pyo' "$src_dir" "$TESTS_BASE_DIR/" 2>/dev/null || echo "$src_dir/ and $TESTS_BASE_DIR/")
    else
        # Fallback: manual directory listing
        architecture=$(find "$src_dir" "$TESTS_BASE_DIR/" -type f -name "*.py" 2>/dev/null | sort | sed 's|^|  |' || echo "No files found")
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
# Run application
python -m $app_name

# Run example
python $src_dir/example.py

# Run tests
pytest $TESTS_BASE_DIR/
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

# Generate/update example.py in src directory
# Returns the path to the generated example (empty if not generated)
generate_app_example() {
    log_info "Generating application example.py..."

    # Find src directory (first dir in src/)
    local src_dir=$(find "$SRC_BASE_DIR" -mindepth 1 -maxdepth 1 -type d | head -1)
    if [ -z "$src_dir" ]; then
        log_warn "No src directory found, skipping example generation"
        echo ""
        return 0
    fi

    local app_name=$(basename "$src_dir")
    local example_path="$src_dir/example.py"

    # Generate minimal viable example
    cat > "$example_path" <<EOF
"""Minimal viable example demonstrating how to use this application."""

import $app_name


def main():
    """Run the application example."""
    # TODO: Add your example usage here
    print("Example: Running $app_name")


if __name__ == "__main__":
    main()
EOF

    log_info "example.py created at $example_path"
    echo "$example_path"
}