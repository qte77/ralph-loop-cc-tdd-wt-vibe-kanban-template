#!/bin/bash
# Script to reorganize PRD files for ralph-loop
# Archives current PRD and ralph state, then activates a new PRD.
set -euo pipefail

# Get script directory and source libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/config.sh"

# Usage info
usage() {
    cat <<EOF
Usage: $0 [OPTIONS] <new_prd_file>

Archives current PRD and ralph state, then activates a new PRD.

Arguments:
  new_prd_file    Path to new PRD file (relative to project root)

Options:
  -v VERSION      Archive version (default: auto-detected)
  -h              Show this help message

Examples:
  $0 docs/PRD-Benchmarking.md
  $0 -v 2 docs/PRD-Benchmarking.md

Auto-detection:
  Version is auto-detected by counting existing archives (v1, v2, v3, ...)
EOF
    exit 1
}

# Parse options
VERSION=""
while getopts "v:h" opt; do
    case $opt in
        v) VERSION="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done
shift $((OPTIND-1))

# Validate arguments
if [ $# -ne 1 ]; then
    log_error "Missing new PRD file argument"
    usage
fi

NEW_PRD="$1"

# Validate new PRD exists
if [ ! -f "$NEW_PRD" ]; then
    log_error "File not found: $NEW_PRD"
    exit 1
fi

# Auto-detect version if not provided
if [ -z "$VERSION" ]; then
    COUNT=$(find ralph/archive -maxdepth 1 -type d -name "v*" 2>/dev/null | wc -l)
    VERSION=$((COUNT + 1))
    log_info "Auto-detected version: v$VERSION"
fi

ARCHIVE_DIR="ralph/archive/v${VERSION}"
PRD_ARCHIVE="${ARCHIVE_DIR}/PRD.md"

log_info "Creating archive directory: $ARCHIVE_DIR"
mkdir -p "$ARCHIVE_DIR"

log_info "Archiving current PRD..."
if [ -f "docs/PRD.md" ]; then
    mv docs/PRD.md "$PRD_ARCHIVE"
    log_success "PRD archived: $PRD_ARCHIVE"
else
    log_warn "No current PRD.md to archive"
fi

log_info "Archiving ralph state..."
if [ -f "ralph/state/prd.json" ]; then
    mv ralph/state/prd.json "$ARCHIVE_DIR/prd.json"
fi
if [ -f "ralph/state/progress.txt" ]; then
    mv ralph/state/progress.txt "$ARCHIVE_DIR/progress.txt"
fi

log_info "Activating new PRD: $NEW_PRD -> docs/PRD.md"
cp "$NEW_PRD" docs/PRD.md
rm "$NEW_PRD"

log_success "Reorganization complete!"
echo ""
echo "Archived:"
echo "  - PRD: $PRD_ARCHIVE"
echo "  - Ralph state: $ARCHIVE_DIR"
echo ""
echo "Next step: Run 'make ralph_init_loop' to generate new prd.json"
