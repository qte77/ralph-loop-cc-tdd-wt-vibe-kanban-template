#!/bin/bash
# Vibe Kanban management script
# Usage: ./vibe.sh {start|stop_all|status|demo|cleanup}

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/config.sh"

VIBE_PORT="${RALPH_VIBE_PORT:-5173}"
VIBE_URL="http://127.0.0.1:$VIBE_PORT"

# Start Vibe Kanban
vibe_start() {
    local port="${2:-$VIBE_PORT}"  # Use arg if provided, else config.sh default
    local url="http://127.0.0.1:$port"

    if lsof -Pi :"$port" -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo "Port $port is already in use"
        echo "View at: $url"
    else
        # TODO: Pin vibe-kanban version (e.g., npx vibe-kanban@0.1.17) for reproducibility
        PORT="$port" npx vibe-kanban > /tmp/vibe-kanban-"$port".log 2>&1 &
        echo "Vibe Kanban started on port $port"
        echo "View at: $url"
    fi
}

# Stop all Vibe Kanban instances
vibe_stop_all() {
    pkill -f "vibe-kanban" 2>/dev/null && echo "All Vibe Kanban instances stopped" || echo "No Vibe Kanban instances running"
    return 0
}

# Check status of all instances
vibe_status() {
    local found_any=false
    for log in /tmp/vibe-kanban-*.log; do
        if [ -f "$log" ]; then
            local port=$(grep -oP 'Server running on http://127\.0\.0\.1:\K\d+' "$log" 2>/dev/null)
            if [ -n "$port" ]; then
                local pid=$(lsof -Pi :"$port" -sTCP:LISTEN -t 2>/dev/null)
                if [ -n "$pid" ]; then
                    if [ "$found_any" = "false" ]; then
                        echo "Vibe Kanban instances running:"
                        found_any=true
                    fi
                    echo "  - Port $port (PID: $pid) - http://127.0.0.1:$port"
                fi
            fi
        fi
    done
    if [ "$found_any" = "false" ]; then
        echo "Vibe Kanban is not running"
        return
    fi

    # Show projects and tasks
    echo ""
    echo "Projects and Tasks:"
    echo "==================="

    local projects=$(curl -sf "$VIBE_URL/api/projects" 2>/dev/null | jq -r '.data[]? | @json')
    if [ -z "$projects" ]; then
        echo "No projects found"
        return
    fi

    echo "$projects" | while IFS= read -r project; do
        local project_id=$(echo "$project" | jq -r '.id')
        local project_name=$(echo "$project" | jq -r '.name')

        echo ""
        echo "Project: $project_name (ID: $project_id)"

        local tasks=$(curl -sf "$VIBE_URL/api/tasks?project_id=$project_id" 2>/dev/null | jq -r '.data[]? | @json')
        if [ -z "$tasks" ]; then
            echo "  No tasks"
            continue
        fi

        # Count tasks by status
        local todo_count=$(echo "$tasks" | jq -s '[.[] | select(.status == "todo")] | length')
        local inprogress_count=$(echo "$tasks" | jq -s '[.[] | select(.status == "inprogress")] | length')
        local inreview_count=$(echo "$tasks" | jq -s '[.[] | select(.status == "inreview")] | length')
        local done_count=$(echo "$tasks" | jq -s '[.[] | select(.status == "done")] | length')
        local total_count=$(echo "$tasks" | wc -l)

        echo "  Summary: $total_count total ($todo_count todo, $inprogress_count in-progress, $inreview_count in-review, $done_count done)"
        echo ""

        echo "$tasks" | while IFS= read -r task; do
            local task_title=$(echo "$task" | jq -r '.title')
            local task_status=$(echo "$task" | jq -r '.status')
            local status_icon=""

            case "$task_status" in
                "todo") status_icon="⬜" ;;
                "inprogress") status_icon="🔄" ;;
                "inreview") status_icon="👀" ;;
                "done") status_icon="✅" ;;
                *) status_icon="❓" ;;
            esac

            echo "  $status_icon [$task_status] $task_title"
        done
    done
}

# Clean up all tasks
vibe_cleanup() {
    local project_id=$(curl -sf "$VIBE_URL/api/projects" | jq -r '.data[0].id')
    if [ -z "$project_id" ]; then
        echo "Error: No Vibe Kanban project found at $VIBE_URL"
        exit 1
    fi

    local tasks=$(curl -sf "$VIBE_URL/api/tasks?project_id=$project_id" | jq -r '.data[].id')
    if [ -z "$tasks" ]; then
        echo "No tasks to delete"
        exit 0
    fi

    echo "Deleting all tasks from project: $project_id"
    for task_id in $tasks; do
        curl -sf -X DELETE "$VIBE_URL/api/tasks/$task_id" >/dev/null
        echo "  Deleted task: $task_id"
    done

    echo "All tasks deleted"
}

# Main command dispatcher
case "${1:-}" in
    start)
        vibe_start "$@"
        ;;
    stop_all)
        vibe_stop_all
        ;;
    status)
        vibe_status
        ;;
    cleanup)
        vibe_cleanup
        ;;
    *)
        echo "Usage: $0 {start [PORT]|stop_all|status|cleanup}"
        exit 1
        ;;
esac
