#!/bin/bash
# Archives current run (source, tests, docs, ralph state)
set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source libraries
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/config.sh"

# Script-specific configuration
DOC_FILES=("PRD.md" "UserStory.md")
STATE_FILES=("prd.json" "progress.txt")

# Usage info
usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Archives current run state (source, tests, docs, ralph state).

Options:
  -h              Show this help message
  -l              Archive logs to logs/ (default: delete)

Examples:
  $0                              # Archive without logs
  $0 -l                           # Archive with logs
EOF
    exit 1
}

# Parse options
ARCHIVE_LOGS=false
while getopts "hl" opt; do
    case $opt in
        h) usage ;;
        l) ARCHIVE_LOGS=true ;;
        *) usage ;;
    esac
done
shift $((OPTIND-1))

# Validate source directory exists and has content
if [ ! -d "$SRC_DIR" ]; then
    log_error "Source directory not found: $SRC_DIR"
    log_info "Cannot create archive without source files"
    exit 1
fi

if [ -z "$(ls -A "$SRC_DIR" 2>/dev/null)" ]; then
    log_error "Source directory is empty: $SRC_DIR"
    log_info "Cannot create archive from empty directory"
    exit 1
fi

# Auto-detect next run number based on existing archives
NEXT_RUN=$(ls -d "$ARCHIVE_BASE_DIR/${ARCHIVE_PREFIX}"* 2>/dev/null | wc -l)
NEXT_RUN=$((NEXT_RUN + 1))

# Create archive directory following existing pattern
ARCHIVE_DIR="$ARCHIVE_BASE_DIR/${ARCHIVE_PREFIX}${NEXT_RUN}"
log_info "Creating archive: $ARCHIVE_DIR"
mkdir -p "$ARCHIVE_DIR/$DOCS_BASE_DIR"

# Archive source and tests
# Create src/ subdirectory for organized archive structure
mkdir -p "$ARCHIVE_DIR/$ARCHIVE_SRC_SUBDIR"

for dir in "$SRC_DIR" "$TESTS_BASE_DIR"; do
    [ ! -d "$dir" ] && continue
    if [ "$dir" = "$SRC_DIR" ]; then
        # Move source files into src/ subdirectory (matching archive structure)
        mv "$dir"/* "$ARCHIVE_DIR/$ARCHIVE_SRC_SUBDIR/" 2>/dev/null && rmdir "$dir"
    else
        # Move tests directory as-is
        mv "$dir" "$ARCHIVE_DIR/"
    fi
    log_info "Archived $dir/"
done

# Copy docs to archive (keep originals)
for doc in "${DOC_FILES[@]}"; do
    if [ -f "$DOCS_BASE_DIR/$doc" ]; then
        cp "$DOCS_BASE_DIR/$doc" "$ARCHIVE_DIR/$DOCS_BASE_DIR/$doc"
        log_info "Archived $DOCS_BASE_DIR/$doc"
    fi
done

# Archive ralph directory (copy templates, move state files)
if [ -d "$RALPH_DOCS_DIR" ]; then
    mkdir -p "$ARCHIVE_DIR/$RALPH_DOCS_DIR"
    # Copy all files first
    cp -r "$RALPH_DOCS_DIR"/* "$ARCHIVE_DIR/$RALPH_DOCS_DIR/"
    # Remove only state files from source
    for file in "${STATE_FILES[@]}"; do
        rm -f "$RALPH_DOCS_DIR/$file"
    done
    log_info "Archived $RALPH_DOCS_DIR/"
fi

# Handle ralph logs
if [ "$ARCHIVE_LOGS" = true ]; then
    mkdir -p "$ARCHIVE_DIR/logs"
    mv "$RALPH_LOG_DIR/$RALPH_LOG_PATTERN" "$ARCHIVE_DIR/logs/" 2>/dev/null && log_info "Archived logs/" || true
else
    log_info "Cleaning up ralph logs..."
    rm -f "$RALPH_LOG_DIR/$RALPH_LOG_PATTERN"
fi

log_info "Archive complete!"
echo ""
log_info "Archived to: $ARCHIVE_DIR"
echo ""
log_info "Next step: Create a new $DOCS_BASE_DIR/PRD.md, then run 'make ralph_init_loop'"
