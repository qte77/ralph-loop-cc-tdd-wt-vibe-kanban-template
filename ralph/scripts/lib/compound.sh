#!/bin/bash
#
# Compound Learning Aggregation (CRLA) for Ralph Loop
#
# Aggregates cross-repo learnings from external sources (ai-agents-research,
# MEMORY.md, plan files) into a per-story context file injected into the
# agent prompt. Optionally writes novel Ralph learnings back to a shared hub.
#
# Source order: common.sh → config.sh → ... → compound.sh
# Requires globals from config.sh: COMPOUND_*, RALPH_TMP_DIR, RALPH_LEARNINGS_FILE, RALPH_SIMPLE_MODEL
#
# All functions are no-ops when COMPOUND_ENABLED=false or when required
# paths are unset/missing. Zero errors on unconfigured environments.

# Collect all source files from the configured paths.
# Outputs: newline-separated absolute file paths (empty if nothing configured)
compound_discover_sources() {
    if [ "${COMPOUND_ENABLED:-true}" != "true" ]; then
        return 0
    fi

    local sources=""

    # COMPOUND_LEARNINGS_PATH: all .md files (cross-repo learnings hub)
    if [ -n "${COMPOUND_LEARNINGS_PATH:-}" ] && [ -d "$COMPOUND_LEARNINGS_PATH" ]; then
        local learnings_files
        learnings_files=$(find "$COMPOUND_LEARNINGS_PATH" -type f -name "*.md" 2>/dev/null | sort)
        if [ -n "$learnings_files" ]; then
            sources="${sources:+$sources
}$learnings_files"
        fi
    fi

    # COMPOUND_MEMORY_PATH: MEMORY.md + topic files (CC auto-memory, read-only)
    if [ -n "${COMPOUND_MEMORY_PATH:-}" ] && [ -d "$COMPOUND_MEMORY_PATH" ]; then
        local memory_files
        memory_files=$(find "$COMPOUND_MEMORY_PATH" -type f -name "*.md" 2>/dev/null | sort)
        if [ -n "$memory_files" ]; then
            sources="${sources:+$sources
}$memory_files"
        fi
    fi

    # COMPOUND_PLANS_PATH: all .md plan files (architectural decisions, research synthesis)
    if [ -n "${COMPOUND_PLANS_PATH:-}" ] && [ -d "$COMPOUND_PLANS_PATH" ]; then
        local plan_files
        plan_files=$(find "$COMPOUND_PLANS_PATH" -maxdepth 1 -type f -name "*.md" 2>/dev/null | sort)
        if [ -n "$plan_files" ]; then
            sources="${sources:+$sources
}$plan_files"
        fi
    fi

    echo "$sources"
}

# Compute a SHA256 hash of all discovered source file contents + story_id.
# Used for cache invalidation: if sources haven't changed for the same story,
# skip re-aggregation.
# Args: $1 - story_id (included in hash to invalidate across stories)
# Outputs: hash string on stdout
compound_content_hash() {
    local story_id="$1"
    local sources
    sources=$(compound_discover_sources)

    if [ -z "$sources" ]; then
        # No sources: hash only the story_id so different stories still differ
        echo "$story_id" | sha256sum | cut -d' ' -f1
        return 0
    fi

    # Concatenate story_id + all source file contents, then hash
    # Reason: here-string keeps loop in current shell (avoids subshell variable loss)
    local combined_hash
    combined_hash=$(
        echo "$story_id"
        while IFS= read -r filepath; do
            [ -f "$filepath" ] && cat "$filepath" 2>/dev/null || true
        done <<< "$sources"
    ) | sha256sum | cut -d' ' -f1

    echo "$combined_hash"
}

# Extract story-relevant lines from all discovered sources using keyword matching.
# Keywords are extracted from the story title + description (4+ char words).
# Output is capped at COMPOUND_MAX_LINES to stay within context budget.
# Args:
#   $1 - story title
#   $2 - story description
# Outputs: filtered lines on stdout (empty if no matches or no sources)
compound_filter_relevant() {
    local title="$1"
    local description="$2"

    local sources
    sources=$(compound_discover_sources)
    if [ -z "$sources" ]; then
        return 0
    fi

    # Extract keywords: lowercase, 4+ char words, deduplicated, max 20
    local combined_text
    combined_text=$(echo "$title $description" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '\n')
    local keywords=""
    local kw_count=0
    # Reason: here-string keeps loop in current shell so kw_count propagates
    while IFS= read -r word; do
        [ ${#word} -lt 4 ] && continue
        # Skip if already in keywords (dedup)
        echo "$keywords" | grep -qxF "$word" && continue
        keywords="${keywords:+$keywords
}$word"
        kw_count=$((kw_count + 1))
        [ "$kw_count" -ge 20 ] && break
    done <<< "$combined_text"

    if [ -z "$keywords" ]; then
        return 0
    fi

    # Build grep pattern: keyword1|keyword2|...
    local pattern
    pattern=$(echo "$keywords" | tr '\n' '|' | sed 's/|$//')

    # Grep each source file for matching lines with +-2 lines context
    local matched_lines=""
    local line_count=0

    while IFS= read -r filepath; do
        [ -f "$filepath" ] || continue
        local file_matches
        file_matches=$(grep -i -C 2 -E "$pattern" "$filepath" 2>/dev/null || true)
        if [ -n "$file_matches" ]; then
            matched_lines="${matched_lines:+$matched_lines
}$file_matches"
            line_count=$(echo "$matched_lines" | wc -l)
            # Stop early if already at cap
            [ "$line_count" -ge "${COMPOUND_MAX_LINES:-50}" ] && break
        fi
    done <<< "$sources"

    if [ -z "$matched_lines" ]; then
        return 0
    fi

    # Cap at COMPOUND_MAX_LINES
    echo "$matched_lines" | head -"${COMPOUND_MAX_LINES:-50}"
}

# Main entry point: aggregate cross-repo context for a story.
# Checks cache (content hash) before re-aggregating. Writes compound-context.md
# with a labeled header. Removes the file if no relevant lines are found.
# Args:
#   $1 - story_id
#   $2 - story title
#   $3 - story description
compound_aggregate() {
    local story_id="$1"
    local title="$2"
    local description="$3"

    if [ "${COMPOUND_ENABLED:-true}" != "true" ]; then
        return 0
    fi

    # Ensure tmp dir exists
    mkdir -p "$RALPH_TMP_DIR" 2>/dev/null || true

    # Check if any sources are configured
    local sources
    sources=$(compound_discover_sources)
    if [ -z "$sources" ]; then
        # Nothing to aggregate — remove stale context file if present
        rm -f "${COMPOUND_CONTEXT_FILE:-}" 2>/dev/null || true
        return 0
    fi

    # Cache check: skip re-aggregation if sources + story unchanged
    local current_hash
    current_hash=$(compound_content_hash "$story_id")
    if [ -f "${COMPOUND_CONTEXT_SHA:-}" ] && [ -f "${COMPOUND_CONTEXT_FILE:-}" ]; then
        local stored_hash
        stored_hash=$(cat "$COMPOUND_CONTEXT_SHA" 2>/dev/null || true)
        if [ "$current_hash" = "$stored_hash" ]; then
            log_info "compound: context current (hash match for $story_id)"
            return 0
        fi
    fi

    log_info "compound: aggregating cross-repo context for $story_id..."

    # Filter for story-relevant content
    local relevant
    relevant=$(compound_filter_relevant "$title" "$description")

    if [ -z "$relevant" ]; then
        log_info "compound: no relevant entries found for $story_id"
        rm -f "${COMPOUND_CONTEXT_FILE:-}" 2>/dev/null || true
        # Still save hash so we don't retry on every iteration for this story
        echo "$current_hash" > "$COMPOUND_CONTEXT_SHA"
        return 0
    fi

    # Write compound-context.md with header
    {
        echo "## Compound Learnings (cross-repo, read-only)"
        echo ""
        echo "The following patterns from related projects may be relevant to this story."
        echo "These are informational — apply only if directly applicable."
        echo ""
        echo "$relevant"
    } > "$COMPOUND_CONTEXT_FILE"

    # Save hash for cache
    echo "$current_hash" > "$COMPOUND_CONTEXT_SHA"

    local line_count
    line_count=$(wc -l < "$COMPOUND_CONTEXT_FILE")
    log_info "compound: wrote $line_count lines to compound-context.md"
}

# Write novel patterns from ralph/LEARNINGS.md back to the shared learnings hub.
# Opt-in only: requires COMPOUND_WRITEBACK_ENABLED=true and COMPOUND_WRITEBACK_TARGET set.
# Uses COMPOUND_MODEL (default: haiku) to extract only patterns not already in target.
# Non-blocking: failures are logged but never abort the main loop.
# Args:
#   $1 - passed_count (used for log context only)
compound_writeback() {
    local passed_count="${1:-}"

    if [ "${COMPOUND_WRITEBACK_ENABLED:-false}" != "true" ]; then
        return 0
    fi

    if [ -z "${COMPOUND_WRITEBACK_TARGET:-}" ]; then
        log_warn "compound: writeback enabled but COMPOUND_WRITEBACK_TARGET not set — skipping"
        return 0
    fi

    if [ ! -d "$COMPOUND_WRITEBACK_TARGET" ]; then
        log_warn "compound: COMPOUND_WRITEBACK_TARGET does not exist: $COMPOUND_WRITEBACK_TARGET — skipping"
        return 0
    fi

    if [ ! -f "$RALPH_LEARNINGS_FILE" ]; then
        log_info "compound: no LEARNINGS.md found — skipping writeback"
        return 0
    fi

    # Derive target file: per-repo/<repo-name>.md
    local repo_name
    repo_name=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || echo "unknown")")
    local target_file="$COMPOUND_WRITEBACK_TARGET/${repo_name}.md"

    log_info "compound: writing back novel patterns to $target_file (passed: $passed_count)..."

    local writeback_prompt
    writeback_prompt=$(cat <<WRITEBACK_EOF
Extract novel patterns from these Ralph learnings that are NOT already in the target file.
Format as concise entries (Context/Problem/Solution, 3 lines each).
If no novel patterns exist, output nothing.

=== Ralph LEARNINGS.md ===
$(cat "$RALPH_LEARNINGS_FILE")

=== Target file (existing content) ===
$(cat "$target_file" 2>/dev/null || echo "(empty)")
WRITEBACK_EOF
    )

    # Run extraction — non-blocking, append under dated header
    local model="${COMPOUND_MODEL:-haiku}"
    local date_header
    date_header="### From Ralph ($(date +%Y-%m-%d))"

    local novel_output
    novel_output=$(echo "$writeback_prompt" | \
        claude -p --model "$model" --dangerously-skip-permissions \
        2>"$RALPH_TMP_DIR/compound_writeback.log" || true)

    if [ -n "$novel_output" ]; then
        {
            echo ""
            echo "$date_header"
            echo ""
            echo "$novel_output"
        } >> "$target_file"
        log_info "compound: wrote novel patterns to $target_file"
    else
        log_info "compound: no novel patterns found for writeback"
    fi
}
