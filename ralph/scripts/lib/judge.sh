#!/bin/bash
# Claude-as-Judge evaluation library for parallel Ralph
# Uses LLM-based pairwise comparison to select best worktree

# Source dependencies
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_LIB_DIR/common.sh"

# Evaluate worktrees using Claude-as-Judge
# Args: $1=run_id, $2=n_wt
# Outputs: winner worktree index (echoed)
# Returns: 0 on success, 1 if judge disabled/failed (caller should fall back to metrics)
judge_worktrees() {
    local run_id="$1"
    local n_wt="$2"

    # Check if enabled
    if [ "${RALPH_JUDGE_ENABLED:-false}" != "true" ]; then
        return 1
    fi

    # Check worktree count limit
    if [ "$n_wt" -gt "${RALPH_JUDGE_MAX_WT:-5}" ]; then
        log_warn "Too many worktrees ($n_wt > ${RALPH_JUDGE_MAX_WT:-5}) - falling back to metrics"
        return 1
    fi

    log_info "Running Claude-as-Judge evaluation for $n_wt worktrees..."

    # Build prompt from template
    local judge_prompt=$(mktemp)
    local judge_output=$(mktemp)

    if [ ! -f "$RALPH_JUDGE_TEMPLATE" ]; then
        log_error "Judge template not found: $RALPH_JUDGE_TEMPLATE"
        rm -f "$judge_prompt" "$judge_output"
        return 1
    fi

    cat "$RALPH_JUDGE_TEMPLATE" > "$judge_prompt"
    echo "" >> "$judge_prompt"

    # Append worktree data for each worktree
    for i in $(seq 1 $n_wt); do
        local worktree_path=$(get_worktree_path "$i" "$run_id" "$n_wt")
        local metrics_file="$worktree_path/metrics.json"

        # Read pre-calculated metrics from score_worktree()
        if [ ! -f "$metrics_file" ]; then
            log_warn "Metrics file not found for worktree $i - skipping"
            continue
        fi

        local stories_passed=$(jq -r '.stories_passed' "$metrics_file" 2>/dev/null || echo 0)
        local total_stories=$(jq -r '.total_stories' "$metrics_file" 2>/dev/null || echo 0)
        local test_count=$(jq -r '.test_count' "$metrics_file" 2>/dev/null || echo 0)
        local coverage=$(jq -r '.coverage' "$metrics_file" 2>/dev/null || echo 0)
        local ruff_violations=$(jq -r '.ruff_violations' "$metrics_file" 2>/dev/null || echo 0)
        local pyright_errors=$(jq -r '.pyright_errors' "$metrics_file" 2>/dev/null || echo 0)

        # Get changed files (excluding tracking/config files)
        local changed_files=$(cd "$worktree_path" && git diff --name-only $(git merge-base HEAD origin/main 2>/dev/null || echo HEAD~20)..HEAD 2>/dev/null | \
            grep -E '\.(py|sh)$' | \
            grep -v -E '(prd\.json|progress\.txt|__pycache__|\.pyc|__init__\.py)' | \
            head -15)  # Limit to 15 files to control token usage

        # Append to prompt
        cat <<EOF >> "$judge_prompt"

## Worktree $i

**Metrics:**
- stories_passed: $stories_passed/$total_stories
- test_count: $test_count
- coverage: ${coverage}%
- ruff_violations: $ruff_violations
- pyright_errors: $pyright_errors

**Implementation (actual code):**
EOF

        # Show actual file contents (limited by size and count)
        if [ -n "$changed_files" ]; then
            echo "$changed_files" | while IFS= read -r file; do
                if [ -f "$worktree_path/$file" ]; then
                    local file_size=$(wc -l < "$worktree_path/$file" 2>/dev/null || echo 0)
                    # Skip files over 200 lines to control token usage
                    if [ "$file_size" -le 200 ]; then
                        cat <<EOF >> "$judge_prompt"

\`$file\` ($file_size lines):
\`\`\`python
$(cat "$worktree_path/$file" 2>/dev/null || echo "Unable to read file")
\`\`\`
EOF
                    else
                        cat <<EOF >> "$judge_prompt"

\`$file\` ($file_size lines): [File too large, skipped]
EOF
                    fi
                fi
            done
        else
            echo "No implementation files found" >> "$judge_prompt"
        fi
    done

    # Invoke Claude with timeout
    local timeout_val="${RALPH_JUDGE_TIMEOUT:-120}"
    local model="${RALPH_JUDGE_MODEL:-sonnet}"

    if timeout "$timeout_val" bash -c \
        "cat \"$judge_prompt\" | claude -p --model \"$model\" --dangerously-skip-permissions" \
        > "$judge_output" 2>&1; then

        # Parse JSON response (extract from markdown code blocks if present)
        local json_content=$(sed -n '/^```json/,/^```/p' "$judge_output" | sed '1d;$d' 2>/dev/null)
        if [ -z "$json_content" ]; then
            # Try without code blocks
            json_content=$(grep -E '^\s*\{' "$judge_output" 2>/dev/null || cat "$judge_output")
        fi

        local winner=$(echo "$json_content" | jq -r '.winner' 2>/dev/null || \
                      grep -oP '"winner"\s*:\s*\K\d+' <<< "$json_content" 2>/dev/null | head -1)
        local reason=$(echo "$json_content" | jq -r '.reason' 2>/dev/null || echo "No reason provided")

        if [ -n "$winner" ] && [ "$winner" -ge 1 ] && [ "$winner" -le "$n_wt" ]; then
            log_info "Judge selected worktree $winner: $reason"
            rm -f "$judge_prompt" "$judge_output"
            echo "$winner"
            return 0
        else
            log_warn "Judge returned invalid winner ($winner) - falling back to metrics"
            rm -f "$judge_prompt" "$judge_output"
            return 1
        fi
    else
        log_warn "Judge evaluation timed out or failed - falling back to metrics"
        rm -f "$judge_prompt" "$judge_output"
        return 1
    fi
}
