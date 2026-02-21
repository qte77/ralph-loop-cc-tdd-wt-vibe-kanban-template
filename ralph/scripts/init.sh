#!/bin/bash
#
# Ralph Loop Initialization Script
#
# Validates environment and sets up required state files for Ralph loop execution
#

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source libraries
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/validate_json.sh"

log_info "Initializing Ralph Loop environment..."

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    local missing=0

    # Check for claude command
    if ! command -v claude &> /dev/null; then
        log_error "claude command not found (Claude Code required)"
        missing=1
    else
        log_success "Claude Code CLI found"
    fi

    # Check for jq
    if ! command -v jq &> /dev/null; then
        log_error "jq not found (required for JSON processing)"
        log_info "Install: apt-get install jq (or brew install jq)"
        missing=1
    else
        log_success "jq found"
    fi

    # Check for git
    if ! command -v git &> /dev/null; then
        log_error "git not found"
        missing=1
    else
        log_success "git found"
    fi

    # Check for make
    if ! command -v make &> /dev/null; then
        log_error "make not found"
        missing=1
    else
        log_success "make found"
    fi

    if [ $missing -eq 1 ]; then
        log_error "Missing required dependencies"
        exit 1
    fi
}

# Verify project structure
check_project_structure() {
    log_info "Verifying project structure..."

    # Check for required files
    local required_files=(
        "AGENTS.md"
        "CONTRIBUTING.md"
        "docs/PRD.md"
        "Makefile"
        ".claude/skills/generating-prd-json-from-prd-md/SKILL.md"
        "ralph/scripts/ralph.sh"
        "$RALPH_PROMPT_FILE"
    )

    local missing=0
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            log_error "Required file missing: $file"
            missing=1
        fi
    done

    if [ $missing -eq 1 ]; then
        log_error "Project structure incomplete"
        exit 1
    fi

    log_success "Project structure validated"
}

# Create state directories
create_state_dirs() {
    log_info "Creating state directories..."

    mkdir -p "$RALPH_DOCS_DIR"

    log_success "State directories created"
}

# Initialize progress.txt from template if it doesn't exist
initialize_progress() {
    if [ ! -f "$RALPH_PROGRESS_FILE" ]; then
        log_info "Initializing progress.txt from template..."

        if [ -f "$RALPH_PROGRESS_TEMPLATE" ]; then
            # Copy from template and replace {{DATE}} placeholder
            sed "s/{{DATE}}/$(date)/" "$RALPH_PROGRESS_TEMPLATE" > "$RALPH_PROGRESS_FILE"
            log_success "progress.txt initialized from template"
        else
            log_warn "Template not found, creating default progress.txt..."
            cat > "$RALPH_PROGRESS_FILE" <<EOF
# Ralph Loop Progress Log

Started: $(date)
Project: [PROJECT NAME]

This file tracks the progress of Ralph loop autonomous execution.
Each iteration appends its results here.

---

EOF
            log_success "progress.txt initialized (default)"
        fi
    else
        log_info "progress.txt already exists"
    fi
}

# Initialize Vibe Kanban project config from template if it doesn't exist
initialize_vibe_config() {
    local vibe_dir=".vibe-kanban"
    local vibe_config="$vibe_dir/project.json"
    local vibe_template="$RALPH_TEMPLATES_DIR/vibe-project.json.template"

    if [ ! -f "$vibe_config" ]; then
        log_info "Initializing Vibe Kanban config from template..."

        if [ -f "$vibe_template" ]; then
            # Create directory and copy template (already populated by setup_project.sh)
            mkdir -p "$vibe_dir"
            cp "$vibe_template" "$vibe_config"

            log_success "Vibe Kanban config initialized"
        else
            log_warn "Vibe template not found: $vibe_template"
        fi
    else
        log_info "Vibe Kanban config already exists"
    fi
}

# Check if prd.json exists, create from template if not
check_prd_json() {
    if [ ! -f "$RALPH_PRD_JSON" ]; then
        log_warn "prd.json not found"

        if [ -f "$RALPH_PRD_TEMPLATE" ]; then
            log_info "Creating prd.json from template..."
            cp "$RALPH_PRD_TEMPLATE" "$RALPH_PRD_JSON"
            # Update timestamp
            sed -i "s/\"TEMPLATE\"/\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"/" "$RALPH_PRD_JSON"
            log_success "prd.json created from template"
        fi

        log_info ""
        log_info "To populate prd.json with real stories, run:"
        log_info "  claude -p '/generating-prd-json-from-prd-md'"
        log_info ""
        return 1
    else
        log_success "prd.json found"

        # Validate JSON format
        if validate_prd_json "$RALPH_PRD_JSON"; then
            local total=$(jq '.stories | length' "$RALPH_PRD_JSON")
            local passing=$(jq '[.stories[] | select(.passes == true)] | length' "$RALPH_PRD_JSON")
            log_info "Status: $passing/$total stories completed"
        else
            return 1
        fi
    fi
}

# Make scripts executable
make_executable() {
    log_info "Making scripts executable..."
    chmod +x ralph/scripts/ralph.sh
    chmod +x ralph/scripts/init.sh
    chmod +x ralph/scripts/parallel_ralph.sh
    chmod +x ralph/scripts/archive.sh
    chmod +x ralph/scripts/stop.sh
    chmod +x ralph/scripts/clean.sh
    chmod +x ralph/scripts/vibe.sh
    chmod +x ralph/scripts/lib/stop_ralph_processes.sh
    chmod +x ralph/scripts/lib/cleanup_worktrees.sh
    chmod +x ralph/scripts/reorganize_prd.sh
    log_success "Scripts are executable"
}


# Main
main() {
    check_prerequisites
    check_project_structure
    create_state_dirs
    initialize_progress
    initialize_vibe_config
    make_executable

    echo ""
    log_success "Ralph Loop environment initialized!"
    echo ""

    if ! check_prd_json; then
        log_warn "Run prd.json generation before starting Ralph loop"
        exit 1
    fi

    echo ""
    log_info "Ready to run Ralph loop:"
    log_info "  make ralph_run [ITERATIONS=25]"
    log_info "  or"
    log_info "  ./ralph/scripts/ralph.sh 5"
    echo ""
}

main
