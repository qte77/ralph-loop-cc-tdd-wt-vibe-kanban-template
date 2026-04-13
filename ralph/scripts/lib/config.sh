#!/bin/bash
# Ralph Loop - Shared configuration
# Source this file in Ralph scripts: source "$SCRIPT_DIR/lib/config.sh"
#
# Override hierarchy (highest to lowest priority):
#   1. CLI arguments (e.g., ./ralph.sh 25)
#   2. Environment variables (e.g., VALIDATION_TIMEOUT=500)
#   3. Config defaults (this file)
#
# Usage examples:
#   - Override iterations: ./ralph.sh 50
#   - Override timeout: VALIDATION_TIMEOUT=600 ./ralph.sh
#   - Override parallel N_WT: make ralph_run N_WT=5

# =================================================
# USER-EDITABLE STATIC VARIABLES
# Customize these for your project setup
# =================================================

# Project name (used for worktree prefix: ../${SRC_PACKAGE_DIR}-ralph-wt)
# Override via environment or change after setup_project.sh runs
SRC_PACKAGE_DIR="${SRC_PACKAGE_DIR:-your_project_name}"

# Base directory paths
DOCS_BASE_DIR="docs"
SRC_BASE_DIR="src"
TESTS_BASE_DIR="tests"

# Archive configuration
ARCHIVE_BASE_DIR="src_archive"
ARCHIVE_PREFIX="your_project_name_ralph_run"

# =================================================
# DERIVED DIRECTORY PATHS
# Calculated from base paths above - typically no need to edit
# =================================================

# Ralph documentation paths
RALPH_DOCS_DIR="ralph/docs"
RALPH_TEMPLATES_DIR="$RALPH_DOCS_DIR/templates"

# Source and archive paths
SRC_DIR="$SRC_BASE_DIR/$SRC_PACKAGE_DIR"
ARCHIVE_SRC_SUBDIR="$SRC_BASE_DIR"

# =================================================
# EXECUTION PARAMETERS
# All values support environment variable override (e.g., RALPH_MAX_ITERATIONS=50 make ralph_run)
# =================================================
RALPH_FIX_TIMEOUT=${RALPH_FIX_TIMEOUT:-300}
RALPH_MAX_FIX_ATTEMPTS=${RALPH_MAX_FIX_ATTEMPTS:-3}  # Max validation fix attempts
RALPH_MAX_ITERATIONS=${RALPH_MAX_ITERATIONS:-25}  # Default loop iterations
RALPH_VALIDATION_TIMEOUT=${RALPH_VALIDATION_TIMEOUT:-300}  # Validation timeout (5 min)
RALPH_VIBE_PORT=${RALPH_VIBE_PORT:-5173}  # Vibe Kanban port
RALPH_DRY_RUN=${RALPH_DRY_RUN:-false}  # Skip TDD verification and quality checks
RALPH_MODEL=${RALPH_MODEL:-}  # Override model for all story execution (bypasses classify_story)
RALPH_INSTRUCTION=${RALPH_INSTRUCTION:-}  # Free-text steering injected into story prompt
RALPH_DESLOPIFY=${RALPH_DESLOPIFY:-false}  # Append quality-enforcement system prompt to claude calls

# =================================================
# GIT BRANCH CONFIGURATION
# =================================================
RALPH_PARALLEL_BRANCH_PREFIX=${RALPH_PARALLEL_BRANCH_PREFIX:-"ralph/parallel"}
RALPH_STORY_BRANCH_PREFIX=${RALPH_STORY_BRANCH_PREFIX:-"ralph/story-"}

# =================================================
# LOGGING CONFIGURATION
# =================================================
RALPH_LOG_DIR="${RALPH_LOG_DIR:-/tmp}"
RALPH_LOG_PATTERN="ralph_*.log"
RALPH_LOOP_LOG_SUBDIR="ralph_logs"
RALPH_LOOP_LOG_DIR="$RALPH_LOG_DIR/$RALPH_LOOP_LOG_SUBDIR"
RALPH_MAX_LOG_FILES=20

# =================================================
# MODEL CONFIGURATION (AI ROUTING)
# =================================================
RALPH_DEFAULT_MODEL="sonnet"
RALPH_DOCS_PATTERNS="^(docs|documentation|readme|comment)"
RALPH_FIX_MODEL="haiku"
RALPH_FIX_ERROR_THRESHOLD=${RALPH_FIX_ERROR_THRESHOLD:-20}
RALPH_SIMPLE_MODEL="haiku"
RALPH_SIMPLE_PATTERNS="fix|typo|update.*doc|small.*change|minor|format|style|cleanup|remove.*unused"

# =================================================
# PARALLEL EXECUTION CONFIGURATION
# =================================================
RALPH_PARALLEL_LOCK_REASON=${RALPH_PARALLEL_LOCK_REASON:-"Parallel Ralph Loop execution"}
RALPH_PARALLEL_MERGE_LOG=${RALPH_PARALLEL_MERGE_LOG:-true}
RALPH_PARALLEL_MERGE_VERIFY_SIGNATURES=${RALPH_PARALLEL_MERGE_VERIFY_SIGNATURES:-false}
RALPH_PARALLEL_N_WT=${RALPH_PARALLEL_N_WT:-1}
RALPH_PARALLEL_USE_LOCK=${RALPH_PARALLEL_USE_LOCK:-true}
RALPH_PARALLEL_USE_NO_TRACK=${RALPH_PARALLEL_USE_NO_TRACK:-true}
RALPH_PARALLEL_WORKTREE_PREFIX=${RALPH_PARALLEL_WORKTREE_PREFIX:-"../${SRC_PACKAGE_DIR}-ralph-wt"}
RALPH_PARALLEL_WORKTREE_QUIET=${RALPH_PARALLEL_WORKTREE_QUIET:-false}
RALPH_PARALLEL_KEEP_WORKTREES=${RALPH_PARALLEL_KEEP_WORKTREES:-false}

# =================================================
# JUDGE CONFIGURATION (Claude-as-Judge for N_WT>1)
# =================================================
RALPH_JUDGE_ENABLED=${RALPH_JUDGE_ENABLED:-false}
RALPH_JUDGE_MODEL=${RALPH_JUDGE_MODEL:-"sonnet"}
RALPH_JUDGE_TIMEOUT=${RALPH_JUDGE_TIMEOUT:-120}
RALPH_JUDGE_MAX_WT=${RALPH_JUDGE_MAX_WT:-5}
RALPH_JUDGE_TEMPLATE="$RALPH_TEMPLATES_DIR/judge.prompt.md"
RALPH_SECURITY_REVIEW=${RALPH_SECURITY_REVIEW:-false}
RALPH_MERGE_INTERACTIVE=${RALPH_MERGE_INTERACTIVE:-false}

# =================================================
# STATE FILE PATHS
# Derived from Ralph docs directory
# =================================================
RALPH_PRD_JSON="$RALPH_DOCS_DIR/prd.json"
RALPH_PROGRESS_FILE="$RALPH_DOCS_DIR/progress.txt"
RALPH_PROMPT_FILE="$RALPH_TEMPLATES_DIR/story.prompt.md"
RALPH_LEARNINGS_FILE="ralph/LEARNINGS.md"
RALPH_REQUESTS_FILE="ralph/REQUESTS.md"
RALPH_METRICS_FILE="metrics.json"

# =================================================
# RUNTIME TEMPORARY FILES
# Used for inter-process coordination and logging
# =================================================
RALPH_TMP_DIR="${RALPH_TMP_DIR:-/tmp/ralph}"

# =================================================
# TEMPLATE PATHS
# Derived from Ralph templates directory
# =================================================
RALPH_PRD_TEMPLATE="$RALPH_TEMPLATES_DIR/prd.json.template"
RALPH_PROGRESS_TEMPLATE="$RALPH_TEMPLATES_DIR/progress.txt.template"
