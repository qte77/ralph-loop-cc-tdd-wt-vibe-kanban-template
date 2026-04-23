#!/bin/bash
# Vibe Kanban real-time integration via REST API

# Preserve exported values if already set
: ${VIBE_URL:=""}
: ${VIBE_PROJECT_ID:=""}
: ${KANBAN_MAP:=""}

# Get Vibe Kanban URL from config
get_vibe_url() {
    echo "http://127.0.0.1:$RALPH_VIBE_PORT"
}

# Get project ID from Vibe Kanban
get_project_id() {
    local url=$(get_vibe_url)
    curl -sf "$url/api/projects" | jq -r '.data[0].id'
}

# Detect running Vibe Kanban instance on configured port
_detect_vibe() {
    local url=$(get_vibe_url)
    if curl -sf -m 1 "$url/api/projects" >/dev/null 2>&1; then
        VIBE_URL="$url"
        return 0
    fi
    return 1
}

# Initialize Kanban integration
kanban_init() {
    local run_id=$1
    local n_wt=${2:-1}

    # Try to detect Vibe Kanban
    if ! _detect_vibe; then
        return 0  # Silent fail - Vibe not running
    fi

    export VIBE_URL
    log_info "Vibe Kanban detected at $VIBE_URL"

    # Get project ID
    VIBE_PROJECT_ID=$(get_project_id)

    if [ -z "$VIBE_PROJECT_ID" ]; then
        log_warn "No Vibe Kanban project found"
        return 0
    fi

    export VIBE_PROJECT_ID
    log_info "Using Vibe project: $VIBE_PROJECT_ID"

    # Create tasks from prd.json
    > "$KANBAN_MAP"  # Initialize map file
    export KANBAN_MAP

    for wt in $(seq 1 $n_wt); do
        while IFS= read -r story; do
            local id=$(echo "$story" | jq -r '.id')
            local title=$(echo "$story" | jq -r '.title')
            local story_status=$(echo "$story" | jq -r '.status')

            # Add [run_id] and [WTn] prefixes
            local task_title="[$run_id] [WT$wt] ${id}: $title"

            # Set initial status based on .status field (preserve already-completed stories)
            local initial_status="todo"
            if [ "$story_status" == "passed" ]; then
                initial_status="done"
            fi

            # Use jq to construct payload with description and acceptance criteria
            local payload=$(echo "$story" | jq -n \
                --arg project_id "$VIBE_PROJECT_ID" \
                --arg title "$task_title" \
                --arg status "$initial_status" \
                --argjson story "$(cat)" \
                '{
                    project_id: $project_id,
                    title: $title,
                    description: (
                        $story.description + "\n\nAcceptance Criteria:\n- " +
                        ($story.acceptance | join("\n- "))
                    ),
                    status: $status
                }')

            local task_resp=$(curl -sf -X POST "$VIBE_URL/api/tasks" \
                -H "Content-Type: application/json" \
                -d "$payload" 2>/dev/null)

            local task_id=$(echo "$task_resp" | jq -r '.data.id // empty')
            if [ -n "$task_id" ]; then
                echo "${wt}:${id}=$task_id" >> "$KANBAN_MAP"
                log_info "Created Vibe task: [$run_id] [WT$wt] ${id}"
            fi
        done < <(jq -c '.stories[]' "$RALPH_PRD_JSON")
    done

    log_info "Kanban sync active - created $(wc -l < "$KANBAN_MAP") tasks"
}

# Update task status
kanban_update() {
    local story_id=$1
    local status=$2
    local reason="${3:-}"  # Optional reason parameter

    # Check if Vibe Kanban was initialized
    if [ -z "$VIBE_URL" ]; then
        echo "[DEBUG] kanban_update: VIBE_URL not set" >&2
        return 0
    fi
    if [ ! -f "$KANBAN_MAP" ]; then
        echo "[DEBUG] kanban_update: KANBAN_MAP file not found: $KANBAN_MAP" >&2
        return 0
    fi

    # Use composite key with WORKTREE_NUM
    local key="${WORKTREE_NUM:-1}:${story_id}"

    # Get task ID from map
    local task_id=$(grep "^$key=" "$KANBAN_MAP" 2>/dev/null | cut -d= -f2)
    if [ -z "$task_id" ]; then
        echo "[DEBUG] kanban_update: task_id not found for key=$key in map=$KANBAN_MAP" >&2
        return 0
    fi

    if [ -n "$reason" ]; then
        echo "[DEBUG] kanban_update: Updating task_id=$task_id to status=$status (reason: $reason)" >&2
    else
        echo "[DEBUG] kanban_update: Updating task_id=$task_id to status=$status" >&2
    fi

    # Set attempt flags based on status
    local has_in_progress=false
    local last_failed=false
    case "$status" in
        "inprogress"|"inreview")
            has_in_progress=true
            ;;
        "done")
            has_in_progress=false
            last_failed=false
            ;;
        "todo")
            has_in_progress=false
            last_failed=true
            ;;
        "cancelled")
            has_in_progress=false
            last_failed=true
            ;;
    esac

    # Build JSON payload using jq --arg for safe escaping
    local json_payload
    json_payload=$(jq -n \
        --arg status "$status" \
        --argjson has_in_progress "$has_in_progress" \
        --argjson last_failed "$last_failed" \
        --arg executor "ralph-loop:${RALPH_RUN_ID:-unknown}:WT${WORKTREE_NUM:-1}" \
        --arg notes "$reason" \
        --argjson attempt_count "${STORY_ATTEMPT_NUM:-null}" \
        '{
            status: $status,
            has_in_progress_attempt: $has_in_progress,
            last_attempt_failed: $last_failed,
            executor: $executor
        } + if $attempt_count != null then {attempt_count: $attempt_count} else {} end + if $notes != "" then {notes: $notes} else {} end'
    )

    # Update task with status and attempt tracking
    curl -sf -X PUT "$VIBE_URL/api/tasks/$task_id" \
        -H "Content-Type: application/json" \
        -d "$json_payload" 2>&1
}
