#!/bin/bash
#
# Ralph Loop - Shared utilities library
#
# Provides ANSI colors, UTC timestamps, elapsed time formatting,
# logging with timestamps, CC-prefixed variants, and command checking.
#
# Source this file in Ralph scripts:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$SCRIPT_DIR/lib/common.sh"
#
# Note: colors.sh is a subset of this file and is kept for backward
# compatibility. New scripts should source common.sh instead.

# =================================================
# ANSI Color Codes
# =================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# =================================================
# Utility Functions
# =================================================

# Returns current UTC timestamp in ISO 8601 format
_ts() {
  date -u '+%Y-%m-%dT%H:%M:%SZ'
}

# Convert seconds to human-readable "Xm Ys" format
# Usage: fmt_elapsed 125  # => "2m 5s"
fmt_elapsed() {
  local total_seconds="${1:-0}"
  local minutes=$((total_seconds / 60))
  local seconds=$((total_seconds % 60))
  if [ "$minutes" -gt 0 ]; then
    echo "${minutes}m ${seconds}s"
  else
    echo "${seconds}s"
  fi
}

# =================================================
# Standard Logging Functions
# All output goes to stderr with timestamps
# =================================================

log_info() {
  echo -e "${GREEN}[INFO]${NC} $(_ts) $1" >&2
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $(_ts) $1" >&2
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $(_ts) $1" >&2
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $(_ts) $1" >&2
}

# =================================================
# CC-Prefixed Logging (Claude Code agent output)
# Used when relaying agent log lines to avoid
# double-prefixing with standard log levels
# =================================================

log_cc() {
  echo -e "${MAGENTA}[CC]${NC} $(_ts) $1" >&2
}

log_cc_warn() {
  echo -e "${MAGENTA}[CC]${NC} ${YELLOW}[WARN]${NC} $(_ts) $1" >&2
}

log_cc_error() {
  echo -e "${MAGENTA}[CC]${NC} ${RED}[ERROR]${NC} $(_ts) $1" >&2
}

log_cc_success() {
  echo -e "${MAGENTA}[CC]${NC} ${GREEN}[SUCCESS]${NC} $(_ts) $1" >&2
}

# =================================================
# Command Checker
# =================================================

# Verify a command exists in PATH. Exits with error if missing.
# Usage: require_command "jq" "apt-get install jq"
require_command() {
  local cmd="$1"
  local install_hint="${2:-}"

  if ! command -v "$cmd" &>/dev/null; then
    log_error "Required command not found: $cmd"
    if [ -n "$install_hint" ]; then
      log_error "Install with: $install_hint"
    fi
    return 1
  fi
}

# =================================================
# String Utilities
# =================================================

# Escape string for sed replacement (handles &, \, delimiter)
escape_sed() {
  printf '%s' "$1" | sed 's/[&\\/]/\\&/g'
}
